#!/usr/bin/env python3
"""Background: fetch all LP-aToken Transfer logs (50k chunks, publicnode) -> holders JSON."""
import json, sys, time
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc
URL = "https://pulsechain-rpc.publicnode.com"
T = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
ATOKENS = {
 "0xE51C(PLSF/WPLS)": "0xE51C682e2b6Bb3cDEFab9E809e9B52b306624C7c",
 "0xeD6c(PDAIF/DAI)": "0xeD6cfd41888475F373dFee53aEAD5F2123C76e0A",
 "0xA756(PLSXF/PLSX)": "0xA7561ac1c68d93b3143595028545A9575c01116c",
 "0xb223(oldPLSF/WPLS)": "0xb2235cE3B6D55E8bc089b799e4B8Db1A8A1659Ea",
 "0x2960(oldPDAIF/DAI)": "0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2",
 "0xca23(oldPLSXF/PLSX)": "0xca23D03Fa0F62906e1079bfC641aB849391AF16E",
 "0x9603(EDAIFLP)": "0x9603E53129233d3767Af6C735c15166AD1aacc0d",
}
def logs(addr, frm, to):
    for a in range(5):
        try:
            r = rpc(URL, "eth_getLogs", [{"address": addr, "topics": [T], "fromBlock": hex(frm), "toBlock": hex(to)}])
            if isinstance(r, list):
                return r
        except Exception:
            pass
        time.sleep(1.2)
    return None
out = {}
for name, at in ATOKENS.items():
    all_logs = []; start = 24165000; fails = 0
    while start < 27720000:
        end = min(start + 49999, 27719999)
        r = logs(at, start, end)
        if r is None:
            fails += 1
            if fails > 5:
                print(f"{name} giving up at {start}", flush=True); break
        else:
            all_logs.extend(r); fails = 0
        start = end + 1
    bal = {}
    for l in all_logs:
        f = "0x" + l['topics'][1][-40:]; t = "0x" + l['topics'][2][-40:]
        v = int(l['data'], 16)
        bal[f] = bal.get(f, 0) - v; bal[t] = bal.get(t, 0) + v
    bal = {k: v for k, v in bal.items() if v > 0 and k != "0x" + "00"*20}
    out[name] = {"atoken": at, "n_logs": len(all_logs), "holders": bal}
    print(f"{name} {at}: {len(all_logs)} logs, {len(bal)} holders", flush=True)
    for k, v in sorted(bal.items(), key=lambda x: -x[1])[:6]:
        print("   ", k, v, flush=True)
    json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_atoken_holders_events.json', 'w'), indent=1)
print("DONE", flush=True)
