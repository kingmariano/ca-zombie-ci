#!/usr/bin/env python3
"""BlueMove Phase-2: enumerate ALL pools + escrow balances + exploitability analysis (read-only).

Public Sui GraphQL only. No secrets. Writes ci-out/bluemove_state.json (+ summary.json).
Env: OUT_DIR (default ci-out), WORKERS (default 12), LIMIT (optional, for local testing).
"""
import json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

GQL = "https://graphql.mainnet.sui.io/graphql"
UA = {"User-Agent": "Mozilla/5.0 (research; bluemove-phase2)", "Content-Type": "application/json"}
AMM = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
STABLE = "0x5a7eca40df453efe6bb1feae99e5b8fc072d1252cbd1979eb187d625dc9b47c9"
OUT = os.environ.get("OUT_DIR", "ci-out")
LIMIT = int(os.environ.get("LIMIT", "0"))
os.makedirs(OUT, exist_ok=True)

SUI = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
USDC = "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC"
USDT = "0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN"
WETH = "0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade587435961f5450fe45::coin::COIN"
CETUS = "0x06864a6f921804860930db6ddbe2e16acdf8504495ea7481637a1c8b9a8fe54b::cetus::CETUS"
NAVX = "0xa99b8952d4f7d947ea77fe0ecdcc9e5fc0bcab2841d6e2a5aa00c3044e5544b5::navx::NAVX"
# name, decimals, USD price fallback (will be overridden by DefiLlama if reachable)
MAJ = {
    SUI: ("SUI", 9, 1.10),
    USDC: ("USDC", 6, 1.0),
    USDT: ("USDT", 6, 1.0),
    WETH: ("WETH", 8, 3000.0),
    CETUS: ("CETUS", 9, 0.03),
    NAVX: ("NAVX", 9, 0.01),
}
PRICE_SRC = "fallback (fixed)"

def fetch_prices():
    global PRICE_SRC
    try:
        keys = {"sui": "sui", "usdc": "usd-coin", "usdt": "tether", "weth": "weth",
                "cetus": "cetus-protocol", "navx": "navi-protocol"}
        ids = ",".join(f"coingecko:{v}" for v in keys.values())
        req = urllib.request.Request(f"https://coins.llama.fi/prices/current/{ids}", headers=UA)
        with urllib.request.urlopen(req, timeout=30) as r:
            d = json.loads(r.read())
        cmap = {"sui": SUI, "usdc": USDC, "usdt": USDT, "weth": WETH, "cetus": CETUS, "navx": NAVX}
        for k, v in keys.items():
            p = (d.get("coins") or {}).get(f"coingecko:{v}", {}).get("price")
            if p:
                name, dec, _ = MAJ[cmap[k]]
                MAJ[cmap[k]] = (name, dec, float(p))
        PRICE_SRC = "defillama coins-api"
    except Exception as e:
        print("price fetch failed:", e)

def gql(query, variables=None, timeout=60, retries=6):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(GQL, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read())
            if d.get("errors"):
                last = d["errors"]
                if any(x in str(e).lower() for e in d["errors"] for x in ("rate", "timeout", "too many", "try again")):
                    time.sleep(1.5 * (i + 1)); continue
                raise RuntimeError(json.dumps(d["errors"])[:300])
            return d.get("data")
        except Exception as e:
            last = e
            time.sleep(1.0 * (i + 1))
    raise RuntimeError(f"gql failed: {last}")

DF_Q = """query($addr: SuiAddress!, $after: String) {
  object(address: $addr) {
    dynamicFields(first: 50, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name { type { repr } json }
        value { __typename ... on MoveObject { address contents { type { repr } json } } }
      }
    }
  }
}"""

def page_fields(addr, cursor=None):
    return gql(DF_Q, {"addr": addr, "after": cursor})["object"]["dynamicFields"]

def enumerate_registry(addr):
    out, cursor, pages, t0 = [], None, 0, time.time()
    while True:
        df = page_fields(addr, cursor)
        for n in df.get("nodes") or []:
            v = n.get("value") or {}
            c = v.get("contents") or {}
            out.append({"name": (n.get("name") or {}).get("json"),
                        "value_addr": v.get("address"),
                        "type": (c.get("type") or {}).get("repr"),
                        "json": c.get("json")})
        pages += 1
        if pages % 50 == 0:
            print(f"  registry page {pages} fields={len(out)} t={time.time()-t0:.0f}s", flush=True)
        pi = df.get("pageInfo") or {}
        if not pi.get("hasNextPage"):
            break
        cursor = pi.get("endCursor")
    return out

def fetch_escrows(pool_addr):
    res = []
    try:
        df = page_fields(pool_addr)
        for n in df.get("nodes") or []:
            v = n.get("value") or {}
            c = v.get("contents") or {}
            t = (c.get("type") or {}).get("repr") or ""
            j = c.get("json") or {}
            if "::swap::EscownCoins<" in t:
                res.append({"kind": "vmid", "addr": v.get("address"), "x": int(j.get("token_x") or 0), "y": int(j.get("token_y") or 0)})
            elif "::swap::EscrowCoinsV2<" in t:
                res.append({"kind": "v2", "addr": v.get("address"), "x": int(j.get("token_x") or 0), "y": int(j.get("token_y") or 0)})
    except Exception as e:
        res.append({"error": str(e)[:200]})
    return pool_addr, res

def usd(amt, tok):
    if tok in MAJ:
        _, d, p = MAJ[tok]
        return amt / 10**d * p
    return 0.0

def main():
    t0 = time.time()
    ck = gql("{ checkpoint { sequenceNumber timestamp } }")["checkpoint"]
    print(f"checkpoint {ck['sequenceNumber']} {ck['timestamp']}", flush=True)
    fetch_prices()
    print(f"prices: {[(v[0], v[2]) for v in MAJ.values()]} src={PRICE_SRC}", flush=True)

    print("== enumerating Dex_Info pools ==", flush=True)
    fields = enumerate_registry(AMM)
    pools, other = [], []
    for pf in fields:
        t = pf.get("type") or ""
        j = pf.get("json") or {}
        if "::swap::Pool<" not in t:
            other.append({"name": pf.get("name"), "type": t})
            continue
        try:
            inner = t.split("<", 1)[1].rstrip(">")
            t0s, t1s = [x.strip() for x in inner.split(",", 1)]
        except Exception:
            continue
        pools.append({"addr": pf.get("value_addr"), "name": pf.get("name"), "t0": t0s, "t1": t1s,
                      "creator": j.get("creator"),
                      "token_x": int(j.get("token_x") or 0), "token_y": int(j.get("token_y") or 0),
                      "reserve_x": int(j.get("reserve_x") or 0), "reserve_y": int(j.get("reserve_y") or 0),
                      "lsp_supply": int((j.get("lsp_supply") or {}).get("value") or 0),
                      "is_freeze": bool(j.get("is_freeze")),
                      "fee_x": int(j.get("fee_x") or 0), "fee_y": int(j.get("fee_y") or 0),
                      "fee_amount": int(j.get("fee_amount") or 0)})
    if LIMIT:
        pools = pools[:LIMIT]
    print(f"pools: {len(pools)}; non-pool fields: {len(other)}", flush=True)

    print("== fetching escrows ==", flush=True)
    workers = int(os.environ.get("WORKERS", "12"))
    done = 0
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(fetch_escrows, p["addr"]): p for p in pools if p.get("addr")}
        for f in as_completed(futs):
            p = futs[f]
            try:
                _, esc = f.result()
            except Exception as e:
                esc = [{"error": str(e)[:200]}]
            p["escrows"] = esc
            done += 1
            if done % 1000 == 0:
                print(f"  escrows {done}/{len(pools)} t={time.time()-t0:.0f}s", flush=True)

    # analysis
    agg = {"T": 0.0, "EM": 0.0, "E2": 0.0, "r": 0.0, "fees": 0.0}
    counts = {"total": len(pools), "frozen": 0, "vmid_only": 0, "v2_only": 0, "both_escrows": 0,
              "no_escrow": 0, "T_only": 0, "r_eq_T": 0, "r_eq_EM": 0, "r_eq_E2": 0, "r_other": 0,
              "v2_extractable": 0, "t_extractable": 0}
    ex_usd = {"E2": 0.0, "T": 0.0, "EM_stuck": 0.0}
    ex_pools = []
    for p in pools:
        T = (p["token_x"], p["token_y"]); r = (p["reserve_x"], p["reserve_y"])
        EM = (0, 0); E2 = (0, 0)
        for e in p.get("escrows") or []:
            if e.get("kind") == "vmid": EM = (e.get("x", 0), e.get("y", 0))
            elif e.get("kind") == "v2": E2 = (e.get("x", 0), e.get("y", 0))
        if p["is_freeze"]: counts["frozen"] += 1
        if EM != (0, 0) and E2 == (0, 0): counts["vmid_only"] += 1
        elif E2 != (0, 0) and EM == (0, 0): counts["v2_only"] += 1
        elif E2 != (0, 0) and EM != (0, 0): counts["both_escrows"] += 1
        elif T == (0, 0): counts["no_escrow"] += 1
        else: counts["T_only"] += 1
        lw = "?"
        if r == T: lw = "T"; counts["r_eq_T"] += 1
        elif r == EM and EM != (0, 0): lw = "EM"; counts["r_eq_EM"] += 1
        elif r == E2 and E2 != (0, 0): lw = "E2"; counts["r_eq_E2"] += 1
        else: counts["r_other"] += 1
        p["lw"] = lw
        # extractability (componentwise dominance, strict, r>0 both sides, S>0, unfrozen)
        ok = (not p["is_freeze"]) and p["lsp_supply"] > 0 and r[0] > 0 and r[1] > 0
        v2x = ok and E2[0] > r[0] and E2[1] > r[1]
        tx = ok and T[0] > r[0] and T[1] > r[1]
        p["v2_extractable"] = bool(v2x); p["t_extractable"] = bool(tx)
        if v2x:
            counts["v2_extractable"] += 1
            v = usd(E2[0], p["t0"]) + usd(E2[1], p["t1"])
            ex_usd["E2"] += v
            ex_pools.append({"addr": p["addr"], "kind": "v2", "usd": v, "E2": E2, "r": r, "T": T, "S": p["lsp_supply"]})
        if tx:
            counts["t_extractable"] += 1
            v = usd(T[0], p["t0"]) + usd(T[1], p["t1"])
            ex_usd["T"] += v
            ex_pools.append({"addr": p["addr"], "kind": "T", "usd": v, "E2": E2, "r": r, "T": T, "S": p["lsp_supply"]})
        # stuck (vmid escrow not reachable by unprivileged paths)
        if EM != (0, 0):
            ex_usd["EM_stuck"] += usd(EM[0], p["t0"]) + usd(EM[1], p["t1"])
        agg["T"] += usd(T[0], p["t0"]) + usd(T[1], p["t1"])
        agg["EM"] += usd(EM[0], p["t0"]) + usd(EM[1], p["t1"])
        agg["E2"] += usd(E2[0], p["t0"]) + usd(E2[1], p["t1"])
        agg["r"] += usd(r[0], p["t0"]) + usd(r[1], p["t1"])
        agg["fees"] += usd(p["fee_x"], p["t0"]) + usd(p["fee_y"], p["t1"])

    # stable registry
    print("== stable registry ==", flush=True)
    sfields = enumerate_registry(STABLE)

    # faucet candidates: T imbalanced (one side > 1e6x the other), both > 0, unfrozen
    faucet = []
    for p in pools:
        Tx, Ty = p["token_x"], p["token_y"]
        if Tx > 0 and Ty > 0 and not p["is_freeze"]:
            ratio = max(Tx, Ty) / max(1, min(Tx, Ty))
            if ratio > 1e6:
                big_tok = p["t0"] if Tx > Ty else p["t1"]
                big_amt = max(Tx, Ty)
                faucet.append({"addr": p["addr"], "ratio": ratio, "big_tok": big_tok, "big_amt": big_amt,
                               "usd_big": usd(big_amt, big_tok), "T": (Tx, Ty), "t0": p["t0"], "t1": p["t1"]})

    state = {
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "checkpoint": ck["sequenceNumber"], "checkpoint_time": ck["timestamp"],
        "registry": AMM, "stable_registry": STABLE,
        "price_src": PRICE_SRC, "prices": {v[0]: v[2] for v in MAJ.values()},
        "pools_count": len(pools), "non_pool_fields": other,
        "counts": counts,
        "usd_totals": {k: round(v, 2) for k, v in agg.items()},
        "extractable_usd": {"E2_via_vlatest_mint": round(ex_usd["E2"], 2),
                            "T_via_v1_mint": round(ex_usd["T"], 2),
                            "EM_stuck_usd": round(ex_usd["EM_stuck"], 2)},
        "extractable_pools": sorted(ex_pools, key=lambda x: -x["usd"])[:100],
        "faucet_candidates": sorted(faucet, key=lambda x: -x["usd_big"])[:100],
        "faucet_candidates_count": len(faucet),
        "stable_fields": sfields,
        "pools": pools,
    }
    with open(f"{OUT}/bluemove_state.json", "w") as f:
        json.dump(state, f)
    print(f"WROTE {OUT}/bluemove_state.json ({os.path.getsize(f'{OUT}/bluemove_state.json')} bytes) t={time.time()-t0:.0f}s", flush=True)
    print(json.dumps({"counts": counts, "usd_totals": state["usd_totals"], "extractable_usd": state["extractable_usd"]}, indent=1), flush=True)

if __name__ == "__main__":
    main()
