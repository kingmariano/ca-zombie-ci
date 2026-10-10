#!/usr/bin/env python3
"""Enumerate IncrementFi borrowers across live markets and compute cross-market liquidity.
Read-only Flow mainnet scripts. Output: analysis/borrowers.json, analysis/liquidity.json
"""
import json, base64, urllib.request, urllib.error, time, sys, os

BASE = os.path.dirname(os.path.abspath(__file__))
ENDPOINT = "https://rest-mainnet.onflow.org/v1/scripts"
COMPTROLLER = "0xf80cb737bfe7c792"
POOLS = [
    "0x8334275bda13b2be",  # FiatToken (USDC)
    "0x67539e86cbe9b261",  # BloctoToken
    "0x1113980ca45d1d37",  # USDCFlow
    "0x44fe3d9157770b2d",  # stFlowToken
    "0x90f55b24a556ea45",  # FUSD
    "0x7492e2f9b4acea9a",  # FlowToken
]

def enc(v):
    return base64.b64encode(json.dumps(v).encode()).decode()

def run_script(path, args):
    code = open(path).read()
    body = json.dumps({"script": base64.b64encode(code.encode()).decode(),
                       "arguments": [enc(a) for a in args]}).encode()
    req = urllib.request.Request(ENDPOINT, data=body, headers={"Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
            if isinstance(data, str):
                return json.loads(base64.b64decode(data).decode())
            raise RuntimeError(json.dumps(data)[:500])
        except Exception as e:
            if attempt == 2: raise
            time.sleep(3)

def dec(v):
    if not isinstance(v, dict): return v
    t = v.get('type')
    if t == 'Optional': return None if v.get('value') is None else dec(v['value'])
    if t == 'Array': return [dec(x) for x in v.get('value', [])]
    if t == 'Dictionary':
        return {str(dec(p['key'])): dec(p['value']) for p in v.get('value', [])}
    if t in ('String','Bool','UInt256','UInt64','UFix64','Int','Address','Type','Int256','Word128','Word256'):
        return v.get('value')
    return v.get('value', v)

def sealed_height():
    with urllib.request.urlopen("https://rest-mainnet.onflow.org/v1/blocks?height=sealed", timeout=30) as r:
        return int(json.loads(r.read())[0]['header']['height'])

def main():
    h = sealed_height()
    print("sealed height:", h)
    # 1. borrower lists
    bl = run_script(os.path.join(BASE, "scripts/borrower_lists.cdc"),
                    [{"type": "Array", "value": [{"type": "Address", "value": p} for p in POOLS]}])
    borrowers = dec(bl)
    json.dump({"block_height": h, "borrowers_by_pool": borrowers}, open(os.path.join(BASE, "raw/borrowers.json"), "w"), indent=1)
    uniq = sorted({u.lower() for lst in borrowers.values() for u in lst})
    print("borrowers per pool:", {k: len(v) for k, v in borrowers.items()}, "unique:", len(uniq))
    # 2. liquidity in batches
    liq = {}
    B = 60
    for i in range(0, len(uniq), B):
        batch = uniq[i:i+B]
        res = run_script(os.path.join(BASE, "scripts/user_liquidity.cdc"),
                         [{"type": "Address", "value": COMPTROLLER},
                          {"type": "Array", "value": [{"type": "Address", "value": u} for u in batch]}])
        liq.update(dec(res))
        print(f"  liquidity batch {i//B+1}/{(len(uniq)+B-1)//B} done")
    json.dump({"block_height": h, "liquidity": liq}, open(os.path.join(BASE, "raw/liquidity.json"), "w"), indent=1)
    # 3. classify
    S = 10**18
    under = []
    for u, v in liq.items():
        col, bor, sup = int(v[0])/S, int(v[1])/S, int(v[2])/S
        if col < bor:
            under.append({"user": u, "collateral_usd": col, "borrow_usd": bor, "supply_usd": sup, "shortfall_usd": bor-col})
    under.sort(key=lambda x: -x["shortfall_usd"])
    json.dump({"block_height": h, "underwater": under, "count": len(under),
               "total_shortfall_usd": sum(x["shortfall_usd"] for x in under)},
              open(os.path.join(BASE, "raw/underwater.json"), "w"), indent=1)
    print("underwater accounts:", len(under), "total shortfall USD: %.6f" % sum(x["shortfall_usd"] for x in under))
    for x in under[:15]:
        print("  ", x["user"], "col=%.6f bor=%.6f short=%.6f" % (x["collateral_usd"], x["borrow_usd"], x["shortfall_usd"]))

if __name__ == "__main__":
    main()
