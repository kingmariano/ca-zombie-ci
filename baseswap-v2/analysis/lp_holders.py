#!/usr/bin/env python3
"""Read LP-token holdings of feeTo (FactoryManager) and MasterChefV2 for top pairs.

Local read-only; batched JSON-RPC against a keyless public Base RPC.
Writes analysis/lp_holders.json
"""
import json, os, time, urllib.request, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "analysis", "lp_holders.json")
RPC = "https://base-rpc.publicnode.com"
FEE_TO = "0x463112327576814f80DA8D3632f7bad23c853A29"
MASTERCHEF = "0x2B0A43DCcBD7d42c18F6A83F86D1a19fA58d541A"
BAL = "0x70a08231"

pairs = json.load(open(os.path.join(ROOT, "ci-out", "top_pairs.json")))[:40]

def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def batch(calls, chunk=40):
    out = []
    _id = 0
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = []
        for to, data in part:
            _id += 1
            payload.append({"jsonrpc": "2.0", "id": _id, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]})
        for attempt in range(5):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 research"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    res = json.loads(r.read().decode())
                byid = {x["id"]: x for x in res}
                for x in payload:
                    it = byid.get(x["id"], {})
                    out.append(it.get("result"))
                break
            except Exception:
                time.sleep(1 + attempt + random.random())
        time.sleep(0.05)
    return out

rows = []
calls = []
for p in pairs:
    calls.append((p["pair"], BAL + enc(FEE_TO)))
    calls.append((p["pair"], BAL + enc(MASTERCHEF)))
    calls.append((p["pair"], BAL + enc("0x0000000000000000000000000000000000000000")))
    calls.append((p["pair"], BAL + enc("0x000000000000000000000000000000000000dEaD")))
res = batch(calls)
for i, p in enumerate(pairs):
    fee_lp = int(res[4 * i], 16) if res[4 * i] else 0
    mc_lp = int(res[4 * i + 1], 16) if res[4 * i + 1] else 0
    zero_lp = int(res[4 * i + 2], 16) if res[4 * i + 2] else 0
    dead_lp = int(res[4 * i + 3], 16) if res[4 * i + 3] else 0
    ts = p["totalSupply"] or 0
    tvl = p["tvl_usd"]
    rows.append({
        "pair": p["pair"], "sym0": p.get("sym0"), "sym1": p.get("sym1"),
        "tvl_usd": tvl, "totalSupply": ts,
        "feeTo_lp": fee_lp, "feeTo_share_pct": round(100 * fee_lp / ts, 4) if ts else None,
        "feeTo_usd": round(tvl * fee_lp / ts, 2) if ts else None,
        "mc_lp": mc_lp, "mc_share_pct": round(100 * mc_lp / ts, 4) if ts else None,
        "mc_usd": round(tvl * mc_lp / ts, 2) if ts else None,
        "zero_lp": zero_lp, "dead_lp": dead_lp,
        "zero_dead_usd": round(tvl * (zero_lp + dead_lp) / ts, 2) if ts else None,
    })
tot_fee = sum(r["feeTo_usd"] or 0 for r in rows)
tot_mc = sum(r["mc_usd"] or 0 for r in rows)
tot_zd = sum(r["zero_dead_usd"] or 0 for r in rows)
json.dump({"rows": rows, "feeTo_total_usd_top40": round(tot_fee, 2),
           "masterchef_total_usd_top40": round(tot_mc, 2),
           "zero_dead_total_usd_top40": round(tot_zd, 2)}, open(OUT, "w"), indent=1)
print("feeTo LP value (top40): $%.2f" % tot_fee)
print("MasterChef LP value (top40): $%.2f" % tot_mc)
print("zero/dead-address LP value (top40): $%.2f" % tot_zd)
for r in rows[:15]:
    print(f"{r['pair']} {str(r['sym0'])}/{str(r['sym1']):<8} TVL ${r['tvl_usd']:>10,.0f} feeTo ${r['feeTo_usd'] or 0:>8,.2f} ({r['feeTo_share_pct']}%) MC ${r['mc_usd'] or 0:>9,.2f} ({r['mc_share_pct']}%) zero/dead ${r['zero_dead_usd'] or 0:>9,.2f}")
