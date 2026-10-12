#!/usr/bin/env python3
"""Compute protocol-fee value (P) and stuck value (S) per chain for Timeswap V2.
For every pool: read option totalPosition(Long0/Long1/Short) and positionOf(pool,Short),
then attribute:
  P_short_usd  = min(protocolFee_short, pool_short) / totalShort * pair_usd
  S_short_usd  = pair_usd * (1 - min(1, totalShort_outstanding/totalShort))  (no shorts left -> stuck)
Read-only.
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RPC = {
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "base": "https://mainnet.base.org",
    "optimism": "https://mainnet.optimism.io",
    "polygon": "https://polygon.drpc.org",
    "mantle": "https://rpc.mantle.xyz",
    "hyperliquid": "https://rpc.hyperliquid.xyz/evm",
    "xlayer": "https://rpc.xlayer.tech",
    "polygon-zkevm": "https://zkevm-rpc.com",
}
SEL = {"totalPosition": "0xb7fb542d", "positionOf": "0xaf2f91ea"}

def rpc(url, method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)

def batch(url, calls, retries=3):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        data = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                byid = {x["id"]: x for x in res}
                for j in range(len(chunk)):
                    x = byid.get(j, {})
                    out.append(x.get("result") if "result" in x else None)
                break
            except Exception:
                if attempt == retries - 1:
                    out.extend([None] * len(chunk))
                else:
                    time.sleep(1.5 * (attempt + 1))
        time.sleep(0.1)
    return out

def enc_uint(v): return format(v, "064x")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_uint(h): return int(h, 16) if h and h != "0x" else None

def main(chains):
    grand = {}
    for chain in chains:
        lf = os.path.join(HERE, f"live-priced-{chain}.json")
        pf = os.path.join(HERE, f"pools-{chain}.json")
        if not (os.path.exists(lf) and os.path.exists(pf)):
            print(f"[{chain}] skip"); continue
        lv = json.load(open(lf)); pl = json.load(open(pf))
        url = RPC[chain]
        pair_usd = {p["pair"].lower(): p["usd"]["total"] for p in lv["pairs"]}
        pools = pl["pools"]
        calls = []
        for p in pools:
            st = int(p["strike"]); mt = p["maturity"]
            for pos in (0, 1, 2):
                calls.append(("eth_call", [{"to": p["pair"], "data": SEL["totalPosition"] + enc_uint(st) + enc_uint(mt) + enc_uint(pos)}, "latest"]))
            calls.append(("eth_call", [{"to": p["pair"], "data": SEL["positionOf"] + enc_uint(st) + enc_uint(mt) + enc_addr(p["pool"]) + enc_uint(2)}, "latest"]))
        res = batch(url, calls)
        # aggregate per pair to avoid double counting the shared option balance across maturities
        agg = {}
        for i, p in enumerate(pools):
            l0 = dec_uint(res[4*i]) or 0
            l1 = dec_uint(res[4*i+1]) or 0
            ts = dec_uint(res[4*i+2]) or 0
            pool_short = dec_uint(res[4*i+3]) or 0
            fee_short = int(p["protocolFees"]["short"])
            key = p["pair"].lower()
            a = agg.setdefault(key, {"ts": 0, "fee": 0, "pool_short": 0, "pools": []})
            a["ts"] += ts
            a["fee"] += fee_short
            a["pool_short"] += pool_short
            a["pools"].append((p, ts, fee_short, pool_short))
        P = 0.0; S = 0.0; P_pools = []
        for key, a in agg.items():
            usd = pair_usd.get(key, 0.0)
            if a["fee"] > 0 and a["ts"] > 0:
                frac = min(a["fee"], a["pool_short"]) / a["ts"]
                p_usd = frac * usd
                P += p_usd
                if p_usd > 1:
                    P_pools.append({"pair": key, "usd": round(p_usd, 2), "feeShort": str(a["fee"]),
                                    "poolShort": str(a["pool_short"]), "totalShort": str(a["ts"])})
            if a["ts"] == 0 and usd > 1:
                S += usd
        grand[chain] = {"total_usd": lv["total_usd"], "P_short_usd": round(P, 2), "S_noShorts_usd": round(S, 2)}
        print(f"[{chain}] total=${lv['total_usd']:,.2f}  P(short fees)≈${P:,.2f}  S(pairs with no shorts left)≈${S:,.2f}")
        P_pools.sort(key=lambda x: x["usd"], reverse=True)
        for pp in P_pools[:5]:
            print("     P pair", pp["pair"][:12], "usd≈", pp["usd"], "feeShort", pp["feeShort"][:12])
        with open(os.path.join(HERE, f"fees-{chain}.json"), "w") as f:
            json.dump({"chain": chain, "P_short_usd": round(P, 2), "S_noShorts_usd": round(S, 2), "topP": P_pools}, f, indent=1)
    print("GRAND:", json.dumps(grand, indent=1))

if __name__ == "__main__":
    main(sys.argv[1:] or list(RPC.keys()))
