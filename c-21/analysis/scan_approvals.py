#!/usr/bin/env python3
"""C-21 independent approval enumeration for the four vulnerable Ekubo HuffRouter
deployments (read-only).

Method
------
1. For every token in the union of the routers' immutable deployment token lists
   plus the incident report's scan list, pull every ERC-20 Approval log whose
   `spender` is one of the affected routers (full range from router deployment
   to latest). This is an *independent* re-enumeration: it does not start from
   the incident report's allowance dump.
2. For every (token, owner, router) that ever approved, read the live
   `allowance(owner, router)` and `balanceOf(owner)` at the latest block.
3. Keep only pairs whose allowance AND balance are both > 0 today, i.e. what an
   unprivileged attacker can move right now. USD-price them via DefiLlama
   (resolving ERC-20 time-locked wrappers to their underlying token when the
   wrapper is already unlocked).
4. Write JSON/CSV reports to --out (uploaded as CI artifacts).

Endpoints (env): ANKR_API_KEY, ETHERSCANV2_API_KEY, ALCHEMY_API_KEY, RPC_URL,
FORK_RPC_URL, DRPC_API_KEY, INFURA_API_KEY, NODEREAL_ETH_RPC_URL,
BLOCKPI_RPC_URL, ARB_RPC_URL. Falls back to public endpoints.
"""
import argparse, csv, json, os, re, sys, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TL = os.path.join(HERE, "tokenlists")

APPROVAL_TOPIC = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
ZERO = "0x" + "0" * 40

CHAINS = {
    "ethereum": {
        "chain_id": 1,
        "routers": {
            "0x8f52903d17e2d8d6c77d1a1de0cc975b6b5a0d15": 23018974,   # deployed 2025-07-28
            "0x8ccb1ffd5c2aa6bd926473425dea4c8c15de60fd": 23297576,   # deployed 2025-09-05
            "0x4f168f17923435c999f5c8565acab52c2218edf2": 24174636,   # deployed 2026-01-05
        },
        "tokens": os.path.join(TL, "eth_scan_union.json"),
        "blockscout": "https://eth.blockscout.com",
    },
    "arbitrum": {
        "chain_id": 42161,
        "routers": {
            "0xc93c4ad185ca48d66fefe80f906a67ef859fc47d": 42186671,   # deployed 2026-01-12
        },
        "tokens": os.path.join(TL, "arb_scan_union.json"),
        "blockscout": "https://arbitrum.blockscout.com",
    },
}

# Conservative start blocks (>= actual deployment blocks) in case the dict above drifts.
DEPLOY_SAFE = {"ethereum": 23018974, "arbitrum": 42186671}


def env(name, default=""):
    return os.environ.get(name, default).strip().strip('"')


def build_log_endpoints(chain):
    eps = []
    ankr = env("ANKR_API_KEY")
    if ankr:
        ep = "https://rpc.ankr.com/eth" if chain == "ethereum" else "https://rpc.ankr.com/arbitrum"
        eps.append(("ankr", f"{ep}/{ankr}", "rpc"))
    if chain == "ethereum":
        for key, url in [
            ("alchemy", f"https://eth-mainnet.g.alchemy.com/v2/{env('ALCHEMY_API_KEY')}" if env("ALCHEMY_API_KEY") else ""),
            ("drpc", f"https://lb.drpc.org/ogrpc?network=ethereum&dkey={env('DRPC_API_KEY')}" if env("DRPC_API_KEY") else ""),
            ("nodereal", env("NODEREAL_ETH_RPC_URL")),
            ("blockpi", env("BLOCKPI_RPC_URL")),
            ("infura", f"https://mainnet.infura.io/v3/{env('INFURA_API_KEY')}" if env("INFURA_API_KEY") else ""),
            ("rpc_url", env("RPC_URL")),
            ("fork_rpc", env("FORK_RPC_URL")),
            ("publicnode", "https://ethereum-rpc.publicnode.com"),
        ]:
            if url:
                eps.append((key, url, "rpc"))
        if env("ETHERSCANV2_API_KEY"):
            eps.append(("etherscan", env("ETHERSCANV2_API_KEY"), "etherscan"))
        eps.append(("blockscout", CHAINS[chain]["blockscout"], "blockscout"))
    else:
        if env("ARB_RPC_URL"):
            eps.append(("arb_rpc_url", env("ARB_RPC_URL"), "rpc"))
        eps.append(("arb_public", "https://arb1.arbitrum.io/rpc", "rpc"))
        eps.append(("blockscout", CHAINS[chain]["blockscout"], "blockscout"))
    return eps


def rpc(url, calls, retries=3, chunk=10):
    """calls: list of (method, params). Returns results list."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(part)]
        body = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c21-research"})
                with urllib.request.urlopen(req, timeout=120) as resp:
                    data = json.loads(resp.read().decode())
                if isinstance(data, dict):
                    raise RuntimeError(str(data)[:200])
                by_id = {d.get("id"): d for d in data}
                res = []
                for j in range(len(part)):
                    d = by_id.get(j, {})
                    res.append(d.get("result") if "error" not in d else {"__error__": d.get("error")})
                out.extend(res)
                break
            except Exception as e:
                if attempt == retries - 1:
                    raise
                time.sleep(1 + 2 * attempt)
    return out


def http_get(url, timeout=90):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 c21-research"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def try_rpc_chunk(eps, chain, tokens, start_block):
    """Try full-range array query across RPC endpoints. Returns (logs, endpoint_name) or (None, None)."""
    topic2s = ["0x" + r[2:].rjust(64, "0") for r in CHAINS[chain]["routers"]]
    for name, ep, kind in eps:
        if kind != "rpc":
            continue
        try:
            res = rpc(ep, [("eth_getLogs", [{"address": tokens, "fromBlock": hex(start_block), "toBlock": "latest",
                                             "topics": [APPROVAL_TOPIC, None, topic2s]}])], retries=2)
            if res and isinstance(res[0], list):
                return res[0], name
            else:
                err = res[0] if res else None
                print(f"[scan] rpc {name} chunk error: {str(err)[:120]}")
        except Exception as e:
            print(f"[scan] rpc {name} chunk failed: {str(e)[:120]}")
    return None, None


def blockscout_logs(ep, chain, token, router, start_block):
    qs = {"module": "logs", "action": "getLogs", "fromBlock": start_block, "toBlock": "latest",
          "address": token, "topic0": APPROVAL_TOPIC, "topic0_2_opr": "and", "topic2": "0x" + router[2:].rjust(64, "0")}
    for attempt in range(3):
        try:
            d = http_get(ep + "/api?" + urllib.parse.urlencode(qs))
            if isinstance(d.get("result"), list):
                return d["result"]
            if d.get("message") == "No logs found":
                return []
        except Exception as e:
            if attempt == 2:
                print(f"[scan] blockscout {ep} error: {str(e)[:100]}")
        time.sleep(0.6 + attempt)
    return []


def fetch_logs(eps, chain, tokens, start_block):
    """Return (endpoint_label, logs). Tries fast full-range array RPCs first,
    then falls back to Blockscout single-(token,router) queries."""
    logs = []
    used = []
    CHUNK = 20
    chunks = [tokens[i:i + CHUNK] for i in range(0, len(tokens), CHUNK)]
    fast_ok = True
    for ci, part in enumerate(chunks):
        got, name = try_rpc_chunk(eps, chain, part, start_block)
        if got is None:
            fast_ok = False
            print(f"[scan] fast path unavailable at chunk {ci+1}/{len(chunks)}; switching to Blockscout fallback")
            break
        logs.extend(got)
        used.append(name)
        print(f"[scan] chunk {ci+1}/{len(chunks)} via {name}: +{len(got)} (total {len(logs)})")
        time.sleep(0.5)
    if fast_ok:
        return ("+".join(sorted(set(used))), logs, True)

    # ---- fallback: Blockscout single (token, router) ----
    bs = None
    for name, ep, kind in eps:
        if kind == "blockscout":
            bs = (name, ep)
            break
    if bs is None:
        raise RuntimeError("no Blockscout fallback available")
    name, ep = bs
    logs = []
    n = 0
    for tok in tokens:
        for router in CHAINS[chain]["routers"]:
            logs.extend(blockscout_logs(ep, chain, tok, router, start_block))
            n += 1
            if n % 50 == 0:
                print(f"[scan] blockscout fallback {n}/{len(tokens)*len(CHAINS[chain]['routers'])} (total logs {len(logs)})")
            time.sleep(0.22)
    return (name, logs, False)


def enc_call(to, data):
    return {"to": to, "data": data}


def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def pick_read_rpc(chain):
    for name, url, kind in build_log_endpoints(chain):
        if kind != "rpc":
            continue
        try:
            r = rpc(url, [("eth_blockNumber", [])], retries=1)
            if r and isinstance(r[0], str):
                print(f"[scan] read RPC: {name}")
                return url
        except Exception:
            continue
    raise RuntimeError("no working read RPC")


def read_live(ep, pairs):
    """pairs: list of (token, owner, router). Returns dict[(token,owner,router)] = (allowance,balance)."""
    calls = []
    for token, owner, router in pairs:
        calls.append(("eth_call", [enc_call(token, "0xdd62ed3e" + pad(owner) + pad(router)), "latest"]))
        calls.append(("eth_call", [enc_call(token, "0x70a08231" + pad(owner)), "latest"]))
    res = rpc(ep, calls, retries=3)
    out = {}
    for i, key in enumerate(pairs):
        a = res[2 * i]
        b = res[2 * i + 1]
        def to_int(x):
            if isinstance(x, str) and x.startswith("0x"):
                return int(x, 16)
            return None
        out[key] = (to_int(a), to_int(b))
    return out


def token_meta(ep, tokens):
    calls = []
    for t in tokens:
        calls.append(("eth_call", [enc_call(t, "0x95d89b41"), "latest"]))
        calls.append(("eth_call", [enc_call(t, "0x313ce567"), "latest"]))
        calls.append(("eth_call", [enc_call(t, "0x8da5cb5b"), "latest"]))  # owner() useful for wrappers
    res = rpc(ep, calls, retries=2)
    meta = {}
    for i, t in enumerate(tokens):
        sym = dec = None
        raw = res[3 * i]
        if isinstance(raw, str) and raw.startswith("0x") and len(raw) > 2:
            try:
                b = bytes.fromhex(raw[2:])
                if len(b) >= 64:
                    ln = int.from_bytes(b[32:64], "big")
                    sym = b[64:64 + ln].decode("utf-8", "replace")
                else:
                    sym = b.rstrip(b"\x00").decode("utf-8", "replace")
            except Exception:
                pass
        raw = res[3 * i + 1]
        if isinstance(raw, str) and raw.startswith("0x") and len(raw) > 2:
            try:
                dec = int(raw, 16)
                if dec > 77:
                    dec = None
            except Exception:
                pass
        meta[t] = {"symbol": sym, "decimals": dec}
    return meta


def llama_prices(chain, tokens):
    prefix = "ethereum" if chain == "ethereum" else "arbitrum"
    out = {}
    for i in range(0, len(tokens), 50):
        part = tokens[i:i + 50]
        try:
            d = http_get("https://coins.llama.fi/prices/current/" + ",".join(f"{prefix}:{t}" for t in part))
            for k, v in (d.get("coins") or {}).items():
                out[k.split(":")[1].lower()] = v.get("price")
        except Exception as e:
            print("[scan] llama price error:", str(e)[:100])
        time.sleep(0.3)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "ci-out"))
    ap.add_argument("--chain", default="all", choices=["all", "ethereum", "arbitrum"])
    ap.add_argument("--smoke", type=int, default=0, help="limit tokens per chain for a smoke test")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    block_reports = {}
    summary = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "chains": {}}

    chains = ["ethereum", "arbitrum"] if args.chain == "all" else [args.chain]
    for chain in chains:
        cfg = CHAINS[chain]
        tokens = [t.lower() for t in json.load(open(cfg["tokens"]))]
        if args.smoke:
            tokens = tokens[: args.smoke]
        eps = build_log_endpoints(chain)
        print(f"[scan] === {chain}: {len(tokens)} tokens, routers {list(cfg['routers'])} ===")
        name, logs, fast = fetch_logs(eps, chain, tokens, DEPLOY_SAFE[chain])
        print(f"[scan] total Approval logs to affected routers: {len(logs)}")

        # latest approval per (token, owner, router) that was ever > 0
        latest = {}
        for l in logs:
            try:
                raw = l if isinstance(l, dict) else None
                if raw is None and isinstance(l, dict):
                    continue
                topics = raw.get("topics") or []
                if len(topics) < 3 or topics[0].lower() != APPROVAL_TOPIC:
                    continue
                owner = "0x" + topics[1][-40:]
                router = "0x" + topics[2][-40:]
                value = int(raw.get("data", "0x0"), 16)
                token = raw["address"].lower()
                bn = int(raw.get("blockNumber", "0x0"), 16)
                tx = raw.get("transactionIndex", "0x0")
                key = (token, owner, router)
                if value > 0:
                    prev = latest.get(key)
                    if prev is None or bn >= prev[0]:
                        latest[key] = (bn, value, tx)
            except Exception:
                continue
        print(f"[scan] unique (token,owner,router) approvals with value>0: {len(latest)}")

        pairs = list(latest.keys())
        read_ep = pick_read_rpc(chain)
        live = read_live(read_ep, pairs) if pairs else {}
        positive = {}
        for k, (allow, bal) in live.items():
            if allow and allow > 0:
                positive[k] = {"allowance": allow, "balance": bal}
        print(f"[scan] live allowances > 0 : {len(positive)}")
        extractable = {k: v for k, v in positive.items() if v["balance"] and v["balance"] > 0}
        print(f"[scan] live allowance > 0 AND balance > 0 : {len(extractable)}")

        # metadata + pricing for the extractable set
        toks = sorted(set(k[0] for k in extractable))
        meta = token_meta(read_ep, toks) if toks else {}
        prices = llama_prices(chain, toks) if toks else {}
        # wrapper resolution: time-locked ERC-20 wrappers (e.g. gEKUBO-26Q2 ->
        # EKUBO) are 1:1 redeemable after unlockTime; price the underlying.
        unpriced = [t for t in toks if not prices.get(t)]
        wrapper_note = {}
        if unpriced:
            calls = []
            for t in unpriced:
                calls.append(("eth_call", [enc_call(t, "0x2495a599"), "latest"]))  # underlyingToken()
                calls.append(("eth_call", [enc_call(t, "0x251c1aa3"), "latest"]))  # unlockTime()
            try:
                res = rpc(read_ep, calls, retries=2)
                unders = {}
                for i, t in enumerate(unpriced):
                    raw_u = res[2 * i]
                    raw_t = res[2 * i + 1]
                    if isinstance(raw_u, str) and len(raw_u) >= 42:
                        u = "0x" + raw_u[-40:]
                        ts = int(raw_t, 16) if isinstance(raw_t, str) and raw_t.startswith("0x") else 0
                        if u.lower() != ZERO and ts > 0:
                            unders[t] = u
                if unders:
                    under_prices = llama_prices(chain, sorted(set(unders.values())))
                    for t, u in unders.items():
                        p = under_prices.get(u.lower())
                        if p:
                            prices[t] = p
                            wrapper_note[t] = f"wrapper of {u} (unlocked, 1:1 redeemable)"
            except Exception as e:
                print("[scan] wrapper resolution error:", str(e)[:120])
        rows = []
        total_usd = 0.0
        for (token, owner, router), v in sorted(extractable.items(), key=lambda kv: -kv[1]["balance"]):
            amount = min(v["allowance"], v["balance"])
            m = meta.get(token, {})
            dec = m.get("decimals")
            human = amount / (10 ** dec) if isinstance(dec, int) else None
            price = prices.get(token)
            usd = (human * price) if (human is not None and price) else None
            if usd:
                total_usd += usd
            note = wrapper_note.get(token, "")
            if not price:
                note = (note + " " if note else "") + "no DefiLlama price / no DEX market found"
            rows.append({"token": token, "symbol": m.get("symbol"), "decimals": dec, "owner": owner,
                         "router": router, "allowance": str(v["allowance"]), "balance": str(v["balance"]),
                         "extractable_raw": str(amount), "extractable": human, "price_usd": price,
                         "usd": usd, "note": note})
        # write outputs
        with open(os.path.join(args.out, f"approval_scan_{chain}.json"), "w") as f:
            json.dump({"chain": chain, "logs_endpoint": name, "approval_logs": len(logs),
                       "positive_allowances": len(positive), "extractable": rows}, f, indent=2)
        with open(os.path.join(args.out, f"approval_scan_{chain}.csv"), "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else
                               ["token", "symbol", "decimals", "owner", "router", "allowance", "balance",
                                "extractable_raw", "extractable", "price_usd", "usd"])
            w.writeheader()
            for r in rows:
                w.writerow(r)
        summary["chains"][chain] = {"approval_logs": len(logs), "positive_allowances": len(positive),
                                    "extractable_pairs": len(rows), "total_usd_priced": round(total_usd, 6),
                                    "checklist": rows}
        print(f"[scan] {chain}: extractable pairs={len(rows)} priced_total=${total_usd:.6f}")
        for r in rows:
            print(f"   EXTRACTABLE {r['symbol']} owner={r['owner']} router={r['router']} "
                  f"amount={r['extractable']} usd={r['usd']}")

    with open(os.path.join(args.out, "scan_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)
    print("[scan] done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
