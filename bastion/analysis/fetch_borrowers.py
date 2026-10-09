#!/usr/bin/env python3
"""Enumerate borrowers of Bastion markets via Blockscout logs; save addresses."""
import requests, json, time

BASE = "https://explorer.aurora.dev/api"
BORROW = "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"
LIQ    = "0x298637f684da70674f26509b10f07ec2fbc77a335ab1e7d6215a4b2484d8bb52"
REPAY  = "0x1a2a22cb034d26d1854bdc6666a5b91fe25efbbb5dcad3b0355478d6f5c362a1"
MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}

def get_logs(address, topic0):
    out=[]; page=1
    while True:
        for attempt in range(4):
            try:
                r = requests.get(BASE, params=dict(module="logs", action="getLogs", fromBlock=0,
                    toBlock="latest", address=address, topic0=topic0, offset=1000, page=page), timeout=90)
                res = r.json().get("result") or []
                break
            except Exception as e:
                print("retry", e); time.sleep(3)
        else:
            raise RuntimeError("logs fetch failed")
        out += res
        print(address, topic0[:10], "page", page, "got", len(res), "total", len(out))
        if len(res) < 1000: break
        page += 1
    return out

res = {}
for mn, addr in MARKETS.items():
    logs = get_logs(addr, BORROW)
    borrowers = {}
    for lg in logs:
        d = lg["data"][2:]
        borrower = "0x" + d[24:64]
        amt = int(d[64:128], 16)
        blk = int(lg["blockNumber"], 16)
        borrowers.setdefault(borrower, {"count":0,"last_block":0,"sum_borrow":0})
        borrowers[borrower]["count"] += 1
        borrowers[borrower]["last_block"] = max(borrowers[borrower]["last_block"], blk)
        borrowers[borrower]["sum_borrow"] += amt
    res[mn] = borrowers
    print(mn, "unique borrowers:", len(borrowers))
    # liquidations on this market
    liqs = get_logs(addr, LIQ)
    res[mn+"_liq_count"] = len(liqs)
    print(mn, "liquidation events:", len(liqs))

allb = sorted(set().union(*[set(v.keys()) for k,v in res.items() if isinstance(v,dict)]))
print("TOTAL unique borrower addresses:", len(allb))
json.dump(res, open("borrowers_raw.json","w"), indent=1)
json.dump(allb, open("borrowers_list.json","w"), indent=1)
