#!/usr/bin/env python3
"""C-21 live-state enumeration for Ekubo HuffRouter (HyperRouter) deployments.

Read-only. Reads allowance/balance/code/balance for the four routers and every
candidate (owner, token) pair from the incident report, plus token metadata.
Saves raw JSON to analysis/live_state_ethereum.json / live_state_arbitrum.json
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HUFF = "/tmp/opencode/huff-router"

ETH_RPC = os.environ.get("ETH_RPC", "https://ethereum-rpc.publicnode.com")
ARB_RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")

ROUTERS = {
    "ethereum": [
        ("8f52903d", "0x8F52903D17E2D8d6c77D1A1DE0Cc975b6b5a0D15", "V2"),
        ("8ccb1ffd", "0x8CCB1ffD5C2aa6Bd926473425Dea4c8c15DE60fd", "V2"),
        ("4f168f17", "0x4F168f17923435c999f5C8565ACAb52C2218EdF2", "V3"),
    ],
    "arbitrum": [
        ("c93c4ad1", "0xc93c4ad185ca48d66fefe80f906a67ef859fc47d", "V3"),
    ],
}
CORES = {
    "ethereum": [
        ("V2-core", "0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444"),
        ("V3-core", "0x00000000000014aA86C5d3c41765bb24e11bd701"),
    ],
}

_batch_id = 0

def rpc_batch(rpc, calls, retries=4):
    """calls: list of (method, params). Returns list of results (or None on error)."""
    global _batch_id
    out = []
    for i in range(0, len(calls), 5):
        chunk = calls[i:i+5]
        payload = []
        for j, (m, p) in enumerate(chunk):
            _batch_id += 1
            payload.append({"jsonrpc": "2.0", "id": _batch_id, "method": m, "params": p})
        body = json.dumps(payload).encode()
        req = urllib.request.Request(rpc, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c21-research"})
        last = None
        for attempt in range(retries):
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    data = json.loads(resp.read().decode())
                if isinstance(data, dict):
                    raise RuntimeError(f"rpc error: {data}")
                by_id = {d["id"]: d for d in data}
                results = []
                for item in payload:
                    d = by_id.get(item["id"], {})
                    results.append(d.get("result") if "error" not in d else {"__error__": d.get("error")})
                out.extend(results)
                break
            except Exception as e:  # noqa
                last = e
                time.sleep(2 + attempt * 3)
        else:
            raise RuntimeError(f"rpc batch failed: {last}")
    return out

def pad(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")

def enc_allowance(owner, spender):
    return "0xdd62ed3e" + pad(owner) + pad(spender)

def enc_balance(owner):
    return "0x70a08231" + pad(owner)

def get_pairs_from_incident():
    """Return list of (router_addr, token, owner, amount_tag) from incident JSON."""
    with open(os.path.join(HUFF, "incident-report/vulnerable-approvals.json")) as f:
        d = json.load(f)
    pairs = []
    for router, by_token in d.items():
        for token, entries in by_token.items():
            for e in entries:
                pairs.append((router, token, e["owner"], e["amount"], e["effective"]))
    return pairs

def eth_call(to, data, block="latest"):
    return ("eth_call", [{"to": to, "data": data}, block])

def main():
    chain = sys.argv[1] if len(sys.argv) > 1 else "ethereum"
    rpc = ETH_RPC if chain == "ethereum" else ARB_RPC
    routers = ROUTERS[chain]

    # 1. block number
    bn_hex = rpc_batch(rpc, [("eth_blockNumber", [])])[0]
    block = int(bn_hex, 16)
    print(f"[{chain}] latest block {block}")

    # 2. code + ETH balance for routers and cores
    meta_calls = []
    meta_keys = []
    for key, addr, gen in routers:
        meta_calls.append(("eth_getCode", [addr, "latest"])); meta_keys.append((key, addr, gen, "code"))
        meta_calls.append(("eth_getBalance", [addr, "latest"])); meta_keys.append((key, addr, gen, "eth"))
    for key, addr in CORES.get(chain, []):
        meta_calls.append(("eth_getCode", [addr, "latest"])); meta_keys.append((key, addr, "", "code"))
        meta_calls.append(("eth_getBalance", [addr, "latest"])); meta_keys.append((key, addr, "", "eth"))
    meta_results = rpc_batch(rpc, meta_calls)
    meta = {}
    for (key, addr, gen, kind), res in zip(meta_keys, meta_results):
        meta.setdefault(key, {"address": addr, "generation": gen})[kind] = res
        if kind == "code" and isinstance(res, str):
            meta[key]["code_size"] = (len(res) - 2) // 2
    for key, v in meta.items():
        print(f"  {key} {v['address']} codesize={v.get('code_size')} eth={int(v.get('eth','0x0'),16)/1e18 if v.get('eth') else '?'}")

    # 3. candidates
    if chain == "ethereum":
        pairs = get_pairs_from_incident()
    else:
        pairs = []
        pth = os.path.join(ROOT, "analysis", "arb_candidates.json")
        if os.path.exists(pth):
            pairs = [tuple(x) for x in json.load(open(pth))]

    calls = []
    index = []
    for (router, token, owner, amount_tag, effective) in pairs:
        calls.append(eth_call(token, enc_allowance(owner, router)))
        calls.append(eth_call(token, enc_balance(owner)))
        index.append((router, token, owner, str(amount_tag), str(effective)))

    print(f"[{chain}] reading {len(pairs)} pairs -> {len(calls)} calls")
    results = rpc_batch(rpc, calls) if calls else []

    out_pairs = []
    for i, (router, token, owner, amount_tag, effective) in enumerate(index):
        a_raw = results[i*2]
        b_raw = results[i*2+1]
        def to_int(x):
            if isinstance(x, str) and x.startswith("0x"):
                return int(x, 16)
            return None
        allowance = to_int(a_raw)
        balance = to_int(b_raw)
        out_pairs.append({
            "router": router, "token": token, "owner": owner,
            "incident_amount": amount_tag, "incident_effective": effective,
            "live_allowance": allowance, "live_balance": balance,
        })

    out = {"chain": chain, "block": block, "routers": meta, "pairs": out_pairs,
           "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    os.makedirs(os.path.join(ROOT, "analysis"), exist_ok=True)
    outp = os.path.join(ROOT, "analysis", f"live_state_{chain}.json")
    with open(outp, "w") as f:
        json.dump(out, f, indent=2)
    print(f"[{chain}] wrote {outp}")

    # summary
    live = [p for p in out_pairs if p["live_allowance"] and p["live_allowance"] > 0]
    live_bal = [p for p in live if p["live_balance"] and p["live_balance"] > 0]
    print(f"[{chain}] pairs={len(out_pairs)} with allowance>0: {len(live)}; with allowance>0 AND balance>0: {len(live_bal)}")
    for p in live_bal:
        print("   LIVE:", p["router"], p["token"], p["owner"], "allow", p["live_allowance"], "bal", p["live_balance"])
    for p in live:
        if p not in live_bal:
            print("   allowance-only:", p["router"], p["token"], p["owner"], "allow", p["live_allowance"], "bal", p["live_balance"])

if __name__ == "__main__":
    main()
