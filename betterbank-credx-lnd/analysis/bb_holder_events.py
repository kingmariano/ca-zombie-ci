#!/usr/bin/env python3
"""Aggregate LP-aToken Transfer logs to identify current holders (read-only)."""
import json, sys, urllib.request, time
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak
URL = "https://rpc.pulsechain.com"
T = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
ATOKENS = {
 "bPlsPLP_0xE51C(PLSF/WPLS)": "0xE51C682e2b6Bb3cDEFab9E809e9B52b306624C7c",
 "bPlsPLP_0xeD6c(PDAIF/DAI)": "0xeD6cfd41888475F373dFee53aEAD5F2123C76e0A",
 "bPlsPLP_0xA756(PLSXF/PLSX)": "0xA7561ac1c68d93b3143595028545A9575c01116c",
 "bPlsPLP_0xb223(oldPLSF/WPLS)": "0xb2235cE3B6D55E8bc089b799e4B8Db1A8A1659Ea",
 "bPlsPLP_0x2960(oldPDAIF/DAI)": "0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2",
 "bPlsPLP_0xca23(oldPLSXF/PLSX)": "0xca23D03Fa0F62906e1079bfC641aB849391AF16E",
 "bPlsEDAIFLP_0x9603": "0x9603E53129233d3767Af6C735c15166AD1aacc0d",
}
def get_logs(addr, frm, to):
    for attempt in range(3):
        try:
            return rpc(URL, "eth_getLogs", [{"address": addr, "topics": [T], "fromBlock": hex(frm), "toBlock": hex(to)}])
        except Exception as e:
            time.sleep(2)
    return {"error": "fail"}
out = {}
for name, at in ATOKENS.items():
    logs = []
    start = 24160000
    step = 300000
    while start < 27711000:
        end = min(start + step - 1, 27710999)
        r = get_logs(at, start, end)
        if isinstance(r, dict):
            # reduce chunk
            step = step // 2
            if step < 100000:
                print(name, "FAILED at", start); break
            continue
        logs.extend(r)
        start = end + 1
    bal = {}
    for l in logs:
        frm = "0x" + l['topics'][1][-40:]
        to = "0x" + l['topics'][2][-40:]
        v = int(l['data'], 16)
        bal[frm] = bal.get(frm, 0) - v
        bal[to] = bal.get(to, 0) + v
    bal = {k: v for k, v in bal.items() if v > 0 and k != "0x" + "00"*20}
    out[name] = {"atoken": at, "n_logs": len(logs), "net_balances": bal}
    print(f"\n{name} {at}: {len(logs)} transfer logs, {len(bal)} holders")
    for k, v in sorted(bal.items(), key=lambda x: -x[1])[:8]:
        print(f"   {k} = {v}")
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_atoken_holders_events.json','w'), indent=1)
print("saved")
