#!/usr/bin/env python3
"""Find variable-debt-token holders (borrowers) for BetterBank reserves -> health factors."""
import json, sys, time
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc
URL = "https://pulsechain-rpc.publicnode.com"
T = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
# variable debt tokens from reserve data (read from saved json)
d = json.load(open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_minters_debt.json'))
VD = {k: v.get("variableDebt") for k, v in d.items() if isinstance(v, dict) and v.get("variableDebt")}
print("VD tokens:", json.dumps(VD, indent=1), flush=True)
def logs(addr, frm, to):
    for a in range(5):
        try:
            r = rpc(URL, "eth_getLogs", [{"address": addr, "topics": [T], "fromBlock": hex(frm), "toBlock": hex(to)}])
            if isinstance(r, list): return r
        except Exception: pass
        time.sleep(1.2)
    return None
out = {}
for res, vd in VD.items():
    all_logs = []; start = 24165000; fails = 0
    while start < 27720000:
        end = min(start + 49999, 27719999)
        r = logs(vd, start, end)
        if r is None:
            fails += 1
            if fails > 5: print(res, "give up at", start, flush=True); break
        else:
            all_logs.extend(r); fails = 0
        start = end + 1
    bal = {}
    for l in all_logs:
        f = "0x" + l['topics'][1][-40:]; t = "0x" + l['topics'][2][-40:]
        v = int(l['data'], 16)
        bal[f] = bal.get(f, 0) - v; bal[t] = bal.get(t, 0) + v
    bal = {k: v for k, v in bal.items() if v > 0 and k != "0x" + "00"*20}
    out[res] = {"vd": vd, "n_logs": len(all_logs), "borrowers": bal}
    print(f"{res} {vd}: {len(all_logs)} logs, {len(bal)} borrowers", flush=True)
    for k, v in sorted(bal.items(), key=lambda x: -x[1])[:10]:
        print("   ", k, v, flush=True)
    json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_borrowers.json', 'w'), indent=1)
print("DONE", flush=True)
