#!/usr/bin/env python3
"""C-24 valuation + drainability classification pass over ci-out/*.json."""
import json, os, sys, time, urllib.request

OUT = os.environ.get("CI_OUT", "ci-out")
CHAIN_PRICE = {
    "bsc": "bsc", "eth": "ethereum", "poly": "polygon", "arb": "arbitrum",
    "avax": "avax", "gnosis": "xdai",
}
SEL = {
    "token0": "0x0dfe1681", "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd",
    "decimals": "0x313ce567", "symbol": "0x95d89b41",
}

def u256(h):
    if not h or not isinstance(h, str) or h.startswith(("REVERT", "RPC_FAIL")) or h == "0x":
        return None
    try: return int(h, 16)
    except Exception: return None

def llama_prices(chain, tokens):
    out = {}
    for i in range(0, len(tokens), 50):
        chunk = tokens[i:i + 50]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"{chain}:{t}" for t in chunk)
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url, timeout=45) as r:
                    out.update(json.load(r).get("coins", {}))
                break
            except Exception:
                time.sleep(2 + 3 * attempt)
    return out

class Rpc:
    def __init__(self, url, chunk=20, sleep=0.08, retries=4):
        self.url, self.chunk, self.sleep, self.retries = url, chunk, sleep, retries
    def batch(self, calls):
        out = [None] * len(calls)
        for s in range(0, len(calls), self.chunk):
            sub = calls[s:s + self.chunk]
            for attempt in range(self.retries):
                payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]}
                           for i, (to, data) in enumerate(sub)]
                try:
                    req = urllib.request.Request(self.url, data=json.dumps(payload).encode(),
                                                 headers={"Content-Type": "application/json",
                                                          "User-Agent": "zombie-research/1.0"})
                    with urllib.request.urlopen(req, timeout=120) as r:
                        res = json.load(r)
                    for x in res:
                        i = x.get("id")
                        out[s + i] = (x.get("result") if "result" in x
                                      else "REVERT:" + x.get("error", {}).get("message", "")[:100])
                    break
                except Exception as e:
                    if attempt == self.retries - 1:
                        for i in range(len(sub)):
                            out[s + i] = "RPC_FAIL:" + str(e)[:60]
                    time.sleep(1.5 + 2.5 * attempt)
            time.sleep(self.sleep)
        return out

RPC_URLS = {
    "bsc": os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com",
    "eth": os.environ.get("NODEREAL_ETH_RPC_URL") or os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com",
    "poly": os.environ.get("POLYGON_RPC_URL") or "https://polygon-bor-rpc.publicnode.com",
    "arb": os.environ.get("ARB_RPC_URL") or "https://arbitrum-one-rpc.publicnode.com",
    "avax": "https://avalanche-c-chain-rpc.publicnode.com",
    "gnosis": os.environ.get("GNOSIS_RPC_URL") or "https://gnosis-rpc.publicnode.com",
}

def value_lockers():
    files = [f for f in os.listdir(OUT) if f.startswith(("bsc_", "eth_", "poly_", "arb_", "avax_", "gnosis_")) and f.endswith(".json") and "v3" not in f]
    summary = {}
    for fn in sorted(files):
        d = json.load(open(f"{OUT}/{fn}"))
        meta, records, tokens = d["meta"], d["records"], d["tokens"]
        chain = fn.split("_")[0]
        llama_chain = CHAIN_PRICE.get(chain, "ethereum")
        now = int(time.time())
        nz = [t for t in tokens if int(t["balance"]) > 0]
        rpc = Rpc(RPC_URLS.get(chain, "https://ethereum-rpc.publicnode.com"))
        print(f"[{fn}] nonzero tokens: {len(nz)}", flush=True)
        # identify LP tokens via token0() probe on a sample; then all
        # price all token addresses first
        addrs = [t["lp"] for t in nz]
        prices = llama_prices(llama_chain, addrs)
        for t in nz:
            info = prices.get(f"{llama_chain}:{t['lp']}", {})
            t["symbol"] = info.get("symbol"); t["decimals"] = info.get("decimals", 18)
            t["price"] = info.get("price")
        # LP resolution: token0/token1/reserves/totalSupply for tokens whose symbol contains LP or unknown
        lp_candidates = [t for t in nz if (t.get("symbol") is None or "LP" in (t.get("symbol") or "").upper())]
        if lp_candidates:
            a = [t["lp"] for t in lp_candidates]
            r0 = rpc.batch([(x, SEL["token0"]) for x in a])
            r1 = rpc.batch([(x, SEL["token1"]) for x in a])
            rv = rpc.batch([(x, SEL["getReserves"]) for x in a])
            ts = rpc.batch([(x, SEL["totalSupply"]) for x in a])
            for t, v0, v1, rraw, tv in zip(lp_candidates, r0, r1, rv, ts):
                u0, u1 = u256(v0), u256(v1)
                if u0 is None or u1 is None:
                    continue
                t["token0"] = "0x" + hex(u0)[2:].rjust(40, "0")
                t["token1"] = "0x" + hex(u1)[2:].rjust(40, "0")
                if isinstance(rraw, str) and rraw.startswith("0x") and len(rraw) >= 130:
                    body = rraw[2:]
                    t["reserve0"] = str(int(body[0:64], 16))
                    t["reserve1"] = str(int(body[64:128], 16))
                t["totalSupply"] = str(u256(tv) or 0)
            under = list(dict.fromkeys([t.get("token0") for t in lp_candidates if t.get("token0")] +
                                       [t.get("token1") for t in lp_candidates if t.get("token1")]))
            up = llama_prices(llama_chain, under)
            for t in lp_candidates:
                def pinfo(addr):
                    i = up.get(f"{llama_chain}:{addr}", {})
                    return (i.get("price") or 0), (i.get("decimals") or 18)
                p0, d0 = pinfo(t.get("token0"))
                p1, d1 = pinfo(t.get("token1"))
                t["p0"], t["p1"], t["d0"], t["d1"] = p0, p1, d0, d1
                if t.get("totalSupply") and int(t["totalSupply"]) > 0 and t.get("reserve0"):
                    share = int(t["balance"]) / int(t["totalSupply"])
                    t["usd"] = share * (int(t["reserve0"]) / 10 ** d0 * p0 + int(t["reserve1"]) / 10 ** d1 * p1)
                    t["usd_kind"] = "lp_share"
                else:
                    t["usd"] = 0.0
                    t["usd_kind"] = "lp_unresolved"
        for t in nz:
            if "usd" not in t:
                p = t.get("price") or 0
                d = t.get("decimals") or 18
                t["usd"] = int(t["balance"]) / 10 ** d * p
                t["usd_kind"] = "erc20"
        total = sum(t["usd"] for t in nz)
        # classification
        owner = (meta.get("owner") or "").lower()
        rows = []
        for t in nz:
            recs = [r for r in records if r["lp"] == t["lp"] and r["locked"] and int(r["amount"]) > 0]
            nonowner = [r for r in recs if r["wallet"].lower() != owner]
            ownerrecs = [r for r in recs if r["wallet"].lower() == owner]
            future = [r for r in nonowner if r["lockedTime"] > now]
            expired = [r for r in nonowner if r["lockedTime"] <= now]
            bal = int(t["balance"])
            rows.append({
                "lp": t["lp"], "balance": str(bal), "usd": round(t["usd"], 2), "usd_kind": t.get("usd_kind"),
                "n_locked": len(recs), "n_locked_nonowner": len(nonowner), "n_future_nonowner": len(future),
                "n_expired_nonowner": len(expired), "n_owner": len(ownerrecs),
                "eu_replay_eligible": bool([r for r in future if int(r["amount"]) <= bal]),
                "any_nonowner_claim_eligible": bool([r for r in nonowner if int(r["amount"]) <= bal]),
                "p_owner_replay_eligible": bool([r for r in ownerrecs if int(r["amount"]) <= bal]),
            })
        summary[fn] = {"meta": meta, "nonzero_tokens": len(nz), "custody_usd": round(total, 2),
                       "rows": sorted(rows, key=lambda x: -x["usd"])}
        print(f"[{fn}] custody_usd={total:,.2f}", flush=True)
    json.dump(summary, open(f"{OUT}/valuation.json", "w"), indent=1)

def value_v3():
    fn = f"{OUT}/v3_bsc.json"
    if not os.path.exists(fn):
        return
    d = json.load(open(fn))
    recs = d["records"]
    nz = [r for r in recs if int(r["escrowBalance"]) > 0]
    rpc = Rpc(RPC_URLS["bsc"])
    # value the LP tokens at the escrows
    by_token = {}
    for r in nz:
        by_token.setdefault(r["lpToken"], []).append(r)
    tokens = list(by_token)
    prices = llama_prices("bsc", tokens)
    # LP resolution
    r0 = rpc.batch([(t, SEL["token0"]) for t in tokens])
    r1 = rpc.batch([(t, SEL["token1"]) for t in tokens])
    rv = rpc.batch([(t, SEL["getReserves"]) for t in tokens])
    ts = rpc.batch([(t, SEL["totalSupply"]) for t in tokens])
    meta = {}
    for t, v0, v1, rraw, tv in zip(tokens, r0, r1, rv, ts):
        u0, u1 = u256(v0), u256(v1)
        m = {}
        if u0 is not None and u1 is not None:
            m["token0"] = "0x" + hex(u0)[2:].rjust(40, "0")
            m["token1"] = "0x" + hex(u1)[2:].rjust(40, "0")
        if isinstance(rraw, str) and rraw.startswith("0x") and len(rraw) >= 130:
            body = rraw[2:]
            m["reserve0"] = int(body[0:64], 16)
            m["reserve1"] = int(body[64:128], 16)
        m["totalSupply"] = u256(tv) or 0
        meta[t] = m
    under = list(dict.fromkeys([m.get("token0") for m in meta.values() if m.get("token0")] +
                               [m.get("token1") for m in meta.values() if m.get("token1")]))
    up = llama_prices("bsc", under)
    total = 0.0
    rows = []
    now = int(time.time())
    for t in tokens:
        m = meta[t]
        escrows = by_token[t]
        esc_bal = sum(int(r["escrowBalance"]) for r in escrows)
        usd = 0.0
        if m.get("totalSupply") and m.get("reserve0") is not None:
            def pinfo(addr):
                i = up.get(f"bsc:{addr}", {})
                return (i.get("price") or 0), (i.get("decimals") or 18)
            p0, d0 = pinfo(m.get("token0"))
            p1, d1 = pinfo(m.get("token1"))
            share = esc_bal / m["totalSupply"]
            usd = share * (m["reserve0"] / 10 ** d0 * p0 + m["reserve1"] / 10 ** d1 * p1)
        total += usd
        rows.append({"lp": t, "escrow_balance": str(esc_bal), "n_locks": len(escrows),
                     "usd": round(usd, 2),
                     "locked_active": sum(1 for r in escrows if r["locked"]),
                     "future_locks": sum(1 for r in escrows if r["locked"] and r["lockTime"] > now)})
    json.dump({"registry": d["registry"], "count": d["count"], "records": len(recs),
               "nonzero_escrows": len(nz), "custody_usd": round(total, 2),
               "rows": sorted(rows, key=lambda x: -x["usd"])}, open(f"{OUT}/valuation_v3.json", "w"), indent=1)
    print(f"[v3_bsc] custody_usd={total:,.2f}", flush=True)

if __name__ == "__main__":
    value_lockers()
    value_v3()
    print("VALUE DONE", flush=True)
