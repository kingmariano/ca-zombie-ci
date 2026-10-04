#!/usr/bin/env python3
"""Balancer V2 per-chain pool scanner (read-only).

- Enumerates every pool ever registered in a Balancer V2 Vault via PoolRegistered logs
  (Etherscan V2 API, paginated).
- Reads live Vault state: getPausedState().
- For every pool: getPoolTokens(poolId) via batched eth_call.
- For pools with non-zero balances: probes pool type selectors and saves everything.

Usage:
  python3 scan_chain.py --chain ethereum --chainid 1 --rpc https://ethereum-rpc.publicnode.com \
      --vault 0xBA12222222228d8Ba445958a75a0704d566BF2C8 --out chain-ethereum.json
"""
import argparse, json, os, sys, time, urllib.request, urllib.error

TOPIC_POOL_REGISTERED = "0x3c13bc30b8e878c53fd2a36b679409c073afd75950be43d8858768e956fbc20e"
SEL_GET_POOL_TOKENS = "0xf94d4668"   # getPoolTokens(bytes32)
SEL_RATE_PROVIDERS  = "0x238a2d59"   # getRateProviders()
SEL_BPT_INDEX       = "0x82687a56"   # getBptIndex()
SEL_NORM_WEIGHTS    = "0xf89f27ed"   # getNormalizedWeights()
SEL_MAIN_TOKEN      = "0x4de046d5"   # getMainToken()
SEL_AMP_PARAM       = "0x6daccffa"   # getAmplificationParameter()
SEL_RECOVERY_MODE   = "0xb35056b8"   # inRecoveryMode()
SEL_GET_POOL_ID     = "0x38fff2d0"   # getPoolId()
SEL_TOTAL_SUPPLY    = "0x18160ddd"   # totalSupply()
SEL_GET_OWNER       = "0x893d20e8"   # getOwner()
SEL_SWAP_FEE        = "0x55c67628"   # getSwapFeePercentage()
SEL_TARGETS         = "0x63fe3b56"   # getTargets() linear
SEL_WRAPPED_TOKEN   = "0xf174e241"   # getWrappedToken() linear
SEL_PAUSED_STATE    = "0x1c0de051"   # getPausedState()
SEL_AUTHORIZER      = "0xaaabadc5"   # getAuthorizer()


def http_json(url, payload, retries=4, timeout=90):
    body = json.dumps(payload).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(
                url, data=body,
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 bal-scan"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"http failed: {last}")


def rpc_batch(url, calls, chunk=20):
    """calls: list of (method, params). Returns list of results (None on error)."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(part)]
        res = http_json(url, payload)
        by_id = {r.get("id"): r for r in res}
        for j in range(len(part)):
            r = by_id.get(j, {})
            out.append(r.get("result") if "result" in r else None)
        time.sleep(0.05)
    return out


def eth_call(rpc, to, data):
    res = rpc_batch(rpc, [("eth_call", [{"to": to, "data": data}, "latest"])])
    return res[0]


def get_logs_blockscout(explorer, vault, max_pages=80):
    """Fetch PoolRegistered logs from a Blockscout-compatible explorer API.

    Used as a fallback where Etherscan V2 free tier refuses the chain.
    """
    logs = []
    page = 1
    while page <= max_pages:
        url = (f"{explorer}/api?module=logs&action=getLogs"
               f"&fromBlock=0&toBlock=latest&address={vault}&topic0={TOPIC_POOL_REGISTERED}"
               f"&offset=1000&page={page}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 bal-scan"})
        with urllib.request.urlopen(req, timeout=90) as r:
            d = json.load(r)
        if str(d.get("status")) == "0":
            msg = str(d.get("message", "")) + " " + str(d.get("result", ""))
            if "No logs found" in msg or "No records found" in msg:
                break
            raise RuntimeError(f"explorer error: {d.get('message')} {d.get('result')}")
        batch = d.get("result", [])
        if not isinstance(batch, list):
            raise RuntimeError(f"explorer unexpected result: {str(batch)[:200]}")
        logs.extend(batch)
        print(f"    page {page}: +{len(batch)} logs (total {len(logs)})", flush=True)
        if len(batch) < 1000:
            break
        page += 1
    return logs


def dec_words(hexstr):
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return [h[i:i + 64] for i in range(0, len(h), 64)]


def dec_address(word):
    return "0x" + word[-40:]


def dec_uint(word):
    return int(word, 16)


def dec_get_pool_tokens(hexstr):
    """Decode (address[] tokens, uint256[] balances, uint256 lastChangeBlock)."""
    if not hexstr or hexstr == "0x":
        return None
    w = dec_words(hexstr)
    off_tokens = dec_uint(w[0])
    off_balances = dec_uint(w[1])
    last_change = dec_uint(w[2])
    def read_arr(off):
        base = off // 32
        n = dec_uint(w[base])
        items = w[base + 1: base + 1 + n]
        return n, items
    n1, toks = read_arr(off_tokens)
    n2, bals = read_arr(off_balances)
    assert n1 == n2, f"len mismatch {n1} {n2}"
    tokens = [dec_address(t) for t in toks]
    balances = [dec_uint(b) for b in bals]
    return tokens, balances, last_change


def dec_address_array(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    w = dec_words(hexstr)
    # single dynamic return: w[0] = offset to array data, w[1] = length, then items
    base = dec_uint(w[0]) // 32
    n = dec_uint(w[base])
    return [dec_address(x) for x in w[base + 1:base + 1 + n]]


def dec_uint_array(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    w = dec_words(hexstr)
    base = dec_uint(w[0]) // 32
    n = dec_uint(w[base])
    return [dec_uint(x) for x in w[base + 1:base + 1 + n]]


def dec_bool(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return dec_uint(dec_words(hexstr)[0]) != 0


def dec_uint_single(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return dec_uint(dec_words(hexstr)[0])


def probe_pool(rpc, addr):
    """Batch-probe a pool contract; returns dict of raw selector results."""
    calls = [
        ("eth_call", [{"to": addr, "data": SEL_GET_POOL_ID}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_RATE_PROVIDERS}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_BPT_INDEX}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_NORM_WEIGHTS}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_MAIN_TOKEN}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_AMP_PARAM}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_RECOVERY_MODE}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_TOTAL_SUPPLY}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_GET_OWNER}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_SWAP_FEE}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_TARGETS}, "latest"]),
        ("eth_call", [{"to": addr, "data": SEL_WRAPPED_TOKEN}, "latest"]),
    ]
    res = rpc_batch(rpc, calls, chunk=12)
    pid, rates, bpt, weights, main, amp, rec, ts, owner, fee, targets, wrapped = res
    out = {
        "poolId_self": pid,
        "rateProviders": dec_address_array(rates) if rates else None,
        "bptIndex": dec_uint_single(bpt) if bpt else None,
        "normalizedWeights": dec_uint_array(weights) if weights else None,
        "mainToken": dec_address(main[2:]) if main and main != "0x" else None,
        "amplification": None,
        "recoveryMode": dec_bool(rec) if rec else None,
        "totalSupply": dec_uint_single(ts) if ts else None,
        "owner": dec_address(owner[2:]) if owner and owner != "0x" else None,
        "swapFee": dec_uint_single(fee) if fee else None,
        "targets": None,
        "wrappedToken": dec_address(wrapped[2:]) if wrapped and wrapped != "0x" else None,
    }
    if amp and amp != "0x":
        w = dec_words(amp)
        out["amplification"] = {"value": dec_uint(w[0]), "precision": dec_uint(w[1]), "isUpdating": dec_uint(w[2]) != 0}
    if targets and targets != "0x":
        w = dec_words(targets)
        out["targets"] = [dec_uint(x) for x in w[:2]]
    return out


def classify(p):
    if p.get("mainToken"):
        return "Linear"
    if p.get("bptIndex") is not None:
        return "ComposableStable"
    if p.get("normalizedWeights"):
        return "Weighted"
    if p.get("amplification") is not None and p.get("rateProviders") is not None:
        return "MetaStable"
    if p.get("amplification") is not None:
        return "Stable"
    if p.get("rateProviders") is not None:
        return "CSP-or-other-with-rates"
    return "Unknown"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", required=True)
    ap.add_argument("--chainid", type=int, required=True)
    ap.add_argument("--rpc", required=True)
    ap.add_argument("--vault", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--explorer", required=True, help="Blockscout-compatible explorer base URL")
    ap.add_argument("--min-usd", type=float, default=0.0)
    args = ap.parse_args()

    print(f"[{args.chain}] fetching PoolRegistered logs from {args.explorer}...", flush=True)
    logs = get_logs_blockscout(args.explorer, args.vault)
    print(f"[{args.chain}] pools registered: {len(logs)}", flush=True)

    pools = []
    seen = set()
    for lg in logs:
        topics = lg["topics"]
        pool_id = topics[1]
        pool_addr = "0x" + topics[2][-40:]
        if pool_id in seen:
            continue
        seen.add(pool_id)
        pools.append({"poolId": pool_id, "address": pool_addr, "regBlock": int(lg["blockNumber"], 16)})

    # Vault state
    vault_state = {}
    for name, data in [("pausedState", SEL_PAUSED_STATE), ("authorizer", SEL_AUTHORIZER)]:
        try:
            vault_state[name] = eth_call(args.rpc, args.vault, data)
        except Exception as e:
            vault_state[name] = f"err:{e}"

    # getPoolTokens for all pools
    print(f"[{args.chain}] reading getPoolTokens...", flush=True)
    calls = [("eth_call", [{"to": args.vault,
                            "data": SEL_GET_POOL_TOKENS + p["poolId"][2:]}, "latest"]) for p in pools]
    results = rpc_batch(args.rpc, calls, chunk=20)
    live = []
    for p, r in zip(pools, results):
        try:
            dec = dec_get_pool_tokens(r)
        except Exception as e:
            p["decode_error"] = str(e)
            dec = None
        if dec is None:
            p["tokens"], p["balances"] = [], []
            continue
        tokens, balances, last_change = dec
        p["tokens"] = tokens
        p["balances"] = balances
        p["lastChangeBlock"] = last_change
        if any(b > 0 for b in balances):
            live.append(p)
    print(f"[{args.chain}] pools with non-zero balances: {len(live)}", flush=True)

    # Probe live pools
    for i, p in enumerate(live):
        try:
            probe = probe_pool(args.rpc, p["address"])
            p["probe"] = probe
            p["type"] = classify(probe)
        except Exception as e:
            p["probe_error"] = str(e)
            p["type"] = "probe_failed"
        if (i + 1) % 25 == 0:
            print(f"[{args.chain}] probed {i+1}/{len(live)}", flush=True)

    out = {
        "chain": args.chain,
        "chainid": args.chainid,
        "vault": args.vault,
        "block": None,
        "vault_state_raw": vault_state,
        "pools_registered": len(pools),
        "pools_live": len(live),
        "pools": live,
        "all_pool_ids": [p["poolId"] for p in pools],
    }
    # latest block
    try:
        blk = rpc_batch(args.rpc, [("eth_blockNumber", [])])[0]
        out["block"] = int(blk, 16)
    except Exception:
        pass
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{args.chain}] wrote {args.out}", flush=True)


if __name__ == "__main__":
    main()
