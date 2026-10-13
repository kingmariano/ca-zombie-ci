#!/usr/bin/env python3
"""Nile CL (Linea) heavy CI scan — read-only.

1. Enumerates every NFP position id 1..totalSupply (ownerOf + positions).
2. Aggregates owners (EOA vs contract), live liquidity, tokensOwed.
3. Checks NPM / FeeCollector / Voter / FeeDistributors / gauges balances for all pool tokens.
4. Prices held tokens with DefiLlama (keyless).
Writes ci-out/ci_state.json and prints a summary. Never prints RPC URLs.
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

FACTORY = "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42"
VOTER = "0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869"
NFP = "0xAAA78E8C4241990B4ce159E105dA08129345946A"
FEE_COLLECTOR = "0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f"
TIMELOCK = "0xbabe7a170A764C8367bFFB35EbDe8E97AA72c3aA"

def build_rpcs():
    urls = []
    a = os.environ.get("ALCHEMY_API_KEY")
    if a:
        urls.append(f"https://linea-mainnet.g.alchemy.com/v2/{a}")
    d = os.environ.get("DRPC_API_KEY")
    if d:
        urls.append(f"https://lb.drpc.live/linea/{d}")
    urls += ["https://rpc.linea.build", "https://linea.drpc.org", "https://linea-rpc.publicnode.com"]
    return urls

RPCS = build_rpcs()
UA = {"User-Agent": "Mozilla/5.0", "Content-Type": "application/json"}
_id = 0

def rpc_batch(calls, batch_label=""):
    """calls: [(method, params)] -> [result|None]. Failover across RPCs."""
    global _id
    payload, ids = [], []
    for m, p in calls:
        _id += 1
        ids.append(_id)
        payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(6):
        for url in RPCS:
            try:
                req = urllib.request.Request(url, data=body, headers=UA)
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.load(r)
                if isinstance(res, dict) and res.get("error"):
                    raise RuntimeError(str(res["error"])[:120])
                out = {x["id"]: x.get("result") for x in res}
                return [out.get(i) for i in ids]
            except Exception as e:
                last = e
                time.sleep(0.7)
    print(f"  [warn] batch failed ({batch_label}): {str(last)[:100]}")
    return [None] * len(calls)

def call(to, sel, arg=""):
    return ("eth_call", [{"to": to, "data": sel + arg}, "latest"])

def dec_addr(w):
    return "0x" + w[-40:].lower() if w else None

def dec_u(w):
    return int(w, 16) if w else 0

def pad_addr(a):
    return "0" * 24 + a[2:].lower()

S = {
    "ownerOf": "0x6352211e",
    "positions": "0x99fbab88",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "gauges": "0xb9a09fd5",
    "isAlive": "0x1703e5f9",
    "feeDistributors": "0x49e4974a",
    "treasury": "0x61d027b3",
    "feeProtocol": "0xd0c93a7c",
}

def main():
    sym = {}
    blk = rpc_batch([("eth_blockNumber", [])])[0]
    block = int(blk, 16)
    print(f"block: {block}")

    total = dec_u(rpc_batch([call(NFP, S["totalSupply"])])[0])
    limit = int(os.environ.get("SCAN_LIMIT", "0")) or total
    total_scan = min(total, limit)
    print(f"NFP totalSupply: {total} (scanning {total_scan} by enumeration index)")

    # ---- 0) enumerate existing token ids via ERC721Enumerable.tokenByIndex(i)
    # (ids are NOT 1..totalSupply: ~187k minted, only `total` survive)
    S_tokenByIndex = "0x4f6ccce7"
    ids_existing = []
    for i in range(0, total_scan, 20):
        chunk = list(range(i, min(i + 20, total_scan)))
        res = rpc_batch([call(NFP, S_tokenByIndex, hex(j)[2:].rjust(64, "0")) for j in chunk],
                        f"tokenByIndex {i}")
        for r in res:
            if r and len(r) >= 66:
                ids_existing.append(int(r, 16))
    ids_existing = sorted(set(ids_existing))
    print(f"enumerated existing ids: {len(ids_existing)} (min {ids_existing[0] if ids_existing else '-'}, max {ids_existing[-1] if ids_existing else '-'})")

    # ---- 1) positions scan over the real id set
    recs = []
    for start in range(0, len(ids_existing), 20):
        chunk = ids_existing[start:start + 20]
        res = rpc_batch([call(NFP, S["positions"], hex(i)[2:].rjust(64, "0")) for i in chunk],
                        f"pos {start}")
        for i, r in zip(chunk, res):
            if not r or len(r) < 2 + 64 * 12:
                continue
            w = [r[2:][k*64:(k+1)*64] for k in range(12)]
            rec = {
                "id": i,
                "token0": dec_addr(w[2]),
                "token1": dec_addr(w[3]),
                "fee": dec_u(w[4]),
                "tickLower": int(w[5], 16) - (1 << 256) if int(w[5], 16) >= (1 << 255) else int(w[5], 16),
                "tickUpper": int(w[6], 16) - (1 << 256) if int(w[6], 16) >= (1 << 255) else int(w[6], 16),
                "liquidity": dec_u(w[7]),
                "owed0": dec_u(w[10]),
                "owed1": dec_u(w[11]),
            }
            if rec["liquidity"] or rec["owed0"] or rec["owed1"]:
                recs.append(rec)
        if start % 400 == 0:
            print(f"  positions {start}/{len(ids_existing)}, live {len(recs)}", flush=True)
    print(f"non-empty positions: {len(recs)}")

    # ---- 2) owners for non-empty
    owners = {}
    ids = [r["id"] for r in recs]
    for j in range(0, len(ids), 20):
        chunk = ids[j:j+20]
        res = rpc_batch([call(NFP, S["ownerOf"], hex(i)[2:].rjust(64, "0")) for i in chunk],
                        f"owner {j}")
        for i, r in zip(chunk, res):
            if r and len(r) >= 42:
                owners[i] = dec_addr(r)
    for r in recs:
        r["owner"] = owners.get(r["id"])

    # owner aggregation
    agg = {}
    for r in recs:
        o = r.get("owner") or "0x" + "0" * 40
        a = agg.setdefault(o, {"count": 0, "with_liquidity": 0, "owed0": 0, "owed1": 0})
        a["count"] += 1
        if r["liquidity"]:
            a["with_liquidity"] += 1
        a["owed0"] += r["owed0"]
        a["owed1"] += r["owed1"]
    # code size of owners (contract vs EOA)
    uni_owners = list(agg.keys())[:400]
    for j in range(0, len(uni_owners), 20):
        chunk = uni_owners[j:j+20]
        res = rpc_batch([("eth_getCode", [o, "latest"]) for o in chunk], "codesize")
        for o, r in zip(chunk, res):
            agg[o]["code_size"] = (len(r) - 2) // 2 if r else 0
    top_owners = sorted(agg.items(), key=lambda kv: -kv[1]["with_liquidity"])[:25]

    # ---- 3) balances: NPM / FeeCollector / Voter over all pool tokens
    pools_state = []
    ps_path = os.path.join(ROOT, "analysis", "pools_state.json")
    if os.path.exists(ps_path):
        pools_state = json.load(open(ps_path))
    tokens = sorted({r["token0"] for r in pools_state} | {r["token1"] for r in pools_state})
    bal = {}
    holders = {"npm": NFP, "feeCollector": FEE_COLLECTOR, "voter": VOTER,
               "factory": FACTORY, "timelock": TIMELOCK}
    for j in range(0, len(tokens), 15):
        chunk = tokens[j:j+15]
        calls = []
        for t in chunk:
            for h in holders.values():
                calls.append(call(t, S["balanceOf"], pad_addr(h)))
        res = rpc_batch(calls, f"bal {j}")
        k = 0
        for t in chunk:
            for name, h in holders.items():
                v = dec_u(res[k]); k += 1
                if v:
                    bal.setdefault(t, {})[name] = v

    # ---- 4) price the held tokens + protocol fees (DefiLlama, keyless)
    price_tokens = set(bal.keys())
    for r in pools_state:
        price_tokens.add(r["token0"]); price_tokens.add(r["token1"])
    prices = {}
    pt = sorted(price_tokens)
    for j in range(0, len(pt), 8):
        chunk = pt[j:j+8]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"linea:{t}" for t in chunk)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            d = json.load(urllib.request.urlopen(req, timeout=30))
            for k, v in d.get("coins", {}).items():
                prices[k.split("linea:")[-1].lower()] = {"price": v["price"], "decimals": v.get("decimals", 18),
                                                         "symbol": v.get("symbol")}
        except Exception as e:
            print("price err", str(e)[:80])
        time.sleep(0.1)

    def usd(t, amt):
        p = prices.get(t.lower())
        if not p:
            return 0.0
        return amt / (10 ** p["decimals"]) * p["price"]

    holder_usd = {}
    for t, hs in bal.items():
        for name, v in hs.items():
            u = usd(t, v)
            holder_usd.setdefault(name, {})[t] = {"amount": v, "usd": round(u, 2)}
    holder_tot = {k: round(sum(x["usd"] for x in v.values()), 2) for k, v in holder_usd.items()}

    # protocol fees & principal totals
    pf_tot = sum(usd(r["token0"], r["protocolFees0"]) + usd(r["token1"], r["protocolFees1"]) for r in pools_state)
    prin_tot = sum(usd(r["token0"], r["balance0"]) + usd(r["token1"], r["balance1"]) for r in pools_state)

    result = {
        "block": block,
        "nfp_total_supply": total,
        "nfp_nonempty_positions": len(recs),
        "nfp_top_owners": [{"owner": o, "code_size": a.get("code_size", None), **{k: a[k] for k in ("count", "with_liquidity", "owed0", "owed1")}} for o, a in top_owners],
        "holder_balances": holder_usd,
        "holder_usd_totals": holder_tot,
        "pools_principal_usd": round(prin_tot, 2),
        "pools_protocol_fees_usd": round(pf_tot, 2),
        "prices_used": prices,
    }
    json.dump(result, open(os.path.join(OUT, "ci_state.json"), "w"), indent=1)
    print("\n=== SUMMARY ===")
    print("block", block)
    print("NFP non-empty:", len(recs), "of", total)
    print("holder USD totals:", json.dumps(holder_tot, indent=1))
    print("pools principal USD:", round(prin_tot, 2))
    print("pools protocol fees USD:", round(pf_tot, 2))
    print("\ntop owners by live positions:")
    for o, a in top_owners[:12]:
        print(f"  {o} code={a.get('code_size')} positions={a['count']} with_liq={a['with_liquidity']}")

if __name__ == "__main__":
    main()
