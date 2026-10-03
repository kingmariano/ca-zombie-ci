#!/usr/bin/env python3
"""Dump live state of Sphere treasuries + tokens."""
import sys, json
sys.path.insert(0, '/home/heisenberg/CA/sphere-finance/analysis')
from rpc import batch, block_number, code

TREASURIES = {
    "T1_0x1a2ce4": "0x1a2ce410a034424b784d4b228f167a061b94cff4",
    "T2_0x826b8d": "0x826b8d2d523e7af40888754e3de64348c00b99f4",
    "T3_Inv_0x20d617": "0x20d61737f972eecb0af5f0a85ab358cd083dd56a",
}
TOKENS = {
    "WMATIC": "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    "miMATIC": "0xa3Fa99A148fA48D14Ed51d610c367C61876997F1",
    "USD+": "0x236eeC6359fb44CCe8f97E99387aa7F8cd5cdE1f",
    "USDC": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    "USDT": "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
    "WMATIC_SPHERE_LP": "0xf305242c46cfa2a07965efbd68b167c99173b496",
    "DYST": "0x39aB6574c289c3Ae4d88500eEc792AB5B947A5Eb",
    "PEN": "0x9008D70A5282a936552593f410AbcBcE2F891A97",
    "USDplus_SPHERE_LP": "0xb8E91631F348dD1F47Cb46f162df458a556c6f1e",
    "iWMATIC": "0xb880e6AdE8709969B9FD2501820e052581aC29Cf",
    "iDAI": "0xbE068B517e869f59778B3a8303DF2B8c13E05d06",
    "xIRON_LOAN_USDC": "0xeE3B4Ce32A6229ae15903CDa0A5Da92E739685f7",
    "xMULTI_WMATIC": "0xeF7B706cA139dBd9010031a50de5509D890CE527",
    "dxTETU": "0xAcEE7Bd17E7B04F7e48b29c0C91aF67758394f0f",
    "tetuQi": "0x4Cd44ced63d9a6FEF595f6AD3F7CED13fCEAc768",
    "SPHERE_v2": "0x62f594339830b90ae4c084ae7d223ffafd9658a7",
    "SPHERE_v1": "0x8d546026012bf75073d8a586f24a5d5ff75b9716",
}

def bal_of(token, who):
    return batch([("eth_call", [{"to": token, "data": "0x70a08231" + who[2:].rjust(64, "0")}, "latest"])])[0]

if __name__ == "__main__":
    bn = block_number()
    print("block", bn)
    out = {"block": bn, "treasuries": {}, "tokens": TOKENS}
    # code checks
    calls = [("eth_getCode", [a, "latest"]) for a in TREASURIES.values()]
    calls += [("eth_getBalance", [a, "latest"]) for a in TREASURIES.values()]
    res = batch(calls)
    codes = res[:len(TREASURIES)]
    bals = res[len(TREASURIES):]
    for i, (k, a) in enumerate(TREASURIES.items()):
        c = codes[i] or "0x"
        print(f"{k} {a} codelen={len(c)//2-1} matic={int(bals[i],16)/1e18:.6f}")
        out["treasuries"][k] = {"address": a, "is_contract": c != "0x", "code_size": len(c)//2-1,
                                "matic": int(bals[i],16)}
    # token balances per treasury
    for k, a in TREASURIES.items():
        out["treasuries"][k]["balances"] = {}
        for tk, ta in TOKENS.items():
            try:
                v = int(bal_of(ta, a), 16)
            except Exception as e:
                v = -1
            out["treasuries"][k]["balances"][tk] = v
            if v:
                print(f"  {k} {tk}: {v}")
    json.dump(out, open("/home/heisenberg/CA/sphere-finance/analysis/treasury_balances.json", "w"), indent=1)
    print("saved")
