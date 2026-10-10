#!/usr/bin/env python3
"""Compute per-account positions + max liquidation profit for the underwater set.
Read-only. Writes analysis/raw/positions.json and analysis/raw/liquidation_profit.json
"""
import json, base64, urllib.request, urllib.error, time, os

BASE = os.path.dirname(os.path.abspath(__file__))
ENDPOINT = "https://rest-mainnet.onflow.org/v1/scripts"
COMPTROLLER = "0xf80cb737bfe7c792"
POOLS = ["0x8334275bda13b2be","0x67539e86cbe9b261","0x1113980ca45d1d37",
         "0x44fe3d9157770b2d","0x90f55b24a556ea45","0x7492e2f9b4acea9a"]
# oracle prices USD (from market_info, scaled 1e18); penalties per collateral pool
PRICE = {"0x8334275bda13b2be":1.0,"0x67539e86cbe9b261":0.0001,"0x1113980ca45d1d37":1.0,
         "0x44fe3d9157770b2d":0.04669518,"0x90f55b24a556ea45":1.0,"0x7492e2f9b4acea9a":0.03241953}
PEN = {"0x8334275bda13b2be":0.1,"0x67539e86cbe9b261":0.2,"0x1113980ca45d1d37":0.1,
       "0x44fe3d9157770b2d":0.1,"0x90f55b24a556ea45":0.05,"0x7492e2f9b4acea9a":0.1}
S = 10**18

def enc(v): return base64.b64encode(json.dumps(v).encode()).decode()

def run_script(path, args):
    code = open(path).read()
    body = json.dumps({"script": base64.b64encode(code.encode()).decode(),
                       "arguments": [enc(a) for a in args]}).encode()
    req = urllib.request.Request(ENDPOINT, data=body, headers={"Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
            if isinstance(data, str): return json.loads(base64.b64decode(data).decode())
            raise RuntimeError(json.dumps(data)[:400])
        except Exception:
            if attempt == 2: raise
            time.sleep(3)

def dec(v):
    if not isinstance(v, dict): return v
    t = v.get('type')
    if t == 'Optional': return None if v.get('value') is None else dec(v['value'])
    if t == 'Array': return [dec(x) for x in v.get('value', [])]
    if t == 'Dictionary': return {str(dec(p['key'])): dec(p['value']) for p in v.get('value', [])}
    return v.get('value')

def main():
    under = json.load(open(os.path.join(BASE, "raw/underwater.json")))["underwater"]
    users = [u for u in (x["user"] for x in under)]
    pos = {}
    B = 10
    for i in range(0, len(users), B):
        batch = users[i:i+B]
        res = run_script(os.path.join(BASE, "scripts/user_positions.cdc"),
                         [{"type":"Address","value":COMPTROLLER},
                          {"type":"Array","value":[{"type":"Address","value":u} for u in batch]},
                          {"type":"Array","value":[{"type":"Address","value":p} for p in POOLS]}])
        pos.update(dec(res))
        print(f"  positions batch {i//B+1}/{(len(users)+B-1)//B}")
    json.dump(pos, open(os.path.join(BASE, "raw/positions.json"), "w"), indent=1)

    # profit model: for each account, for each (debt pool, collateral pool):
    #   repay_cap_usd = collateral_underlying_usd / (1+pen_c)
    #   repay = min(repay_cap_usd, closeFactor*debt_usd, debt_usd)  [cf unknown; report both cf=1 and cf=0.5]
    #   profit_usd = pen_c * repay
    rows = []
    for u, m in pos.items():
        debt = {p: int(m[p]["userBorrowScaled"])/S for p in POOLS if m[p] and int(m[p]["userBorrowScaled"])>0}
        coll = {p: int(m[p]["userSupplyScaled"])/S for p in POOLS if m[p] and int(m[p]["userSupplyScaled"])>0}
        best = None
        for bp, d in debt.items():
            for cp, c in coll.items():
                if bp == cp: continue
                cap = c * PRICE[cp] / (1 + PEN[cp])
                repay = min(cap, d)  # cf=1 upper bound
                profit = PEN[cp] * repay
                if best is None or profit > best["profit_usd"]:
                    best = {"user": u, "borrow_pool": bp, "collateral_pool": cp,
                            "debt_usd": d*PRICE[bp], "collateral_usd": c*PRICE[cp],
                            "repay_usd": repay, "profit_usd": profit}
        if best: rows.append(best)
    rows.sort(key=lambda r: -r["profit_usd"])
    tot = sum(r["profit_usd"] for r in rows)
    json.dump({"upper_bound_profit_usd": tot, "rows": rows}, open(os.path.join(BASE, "raw/liquidation_profit.json"), "w"), indent=1)
    print("accounts with liquidatable pairs:", len(rows), " total upper-bound profit USD: %.4f" % tot)
    for r in rows[:12]:
        print("  %s repay=%.4f profit=%.4f (debt %.4f, coll %.4f in %s)" % (r["user"], r["repay_usd"], r["profit_usd"], r["debt_usd"], r["collateral_usd"], r["collateral_pool"]))

if __name__ == "__main__":
    main()
