#!/usr/bin/env python3
"""Compute getUserAccountData for all material Moola holders. Read-only."""
import json, urllib.request, time, sys

RPCS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com", "https://rpc.ankr.com/celo"]
POOL = "0x970b12522CA9b4054807a2c5B736149a5BE6f670"

d = json.load(open("/home/heisenberg/CA/moola/analysis/holders.json"))
# materiality: debt > 0.05 token, collateral > 0.5 token (raw 18 dec)
mat = {}
for name, holders in d.items():
    for h in holders:
        v = int(h["value"] or 0)
        addr = h["addr"]
        debt = "_vDebt" in name or "_sDebt" in name
        thr = int(0.05e18) if debt else int(0.5e18)
        if v >= thr:
            mat[addr] = mat.get(addr, 0) + v
addrs = sorted(mat.keys())
print("material addresses:", len(addrs))

def rpc_batch(rpc, calls):
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call",
                "params":[{"to":POOL,"data":"0xbf92857c"+a[2:].rjust(64,"0")},"latest"]}
               for i,a in enumerate(calls)]
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
             headers={"Content-Type":"application/json","User-Agent":"moola-audit/1.0"})
    with urllib.request.urlopen(req, timeout=90) as r:
        out = json.load(r)
    res = [None]*len(calls)
    for item in out:
        res[item["id"]] = item.get("result")
    return res

def decode_acct(h):
    if not h or h == "0x": return None
    r = bytes.fromhex(h[2:])
    vals = [int.from_bytes(r[i*32:(i+1)*32], "big") for i in range(6)]
    return {"collateral_celo": vals[0]/1e18, "debt_celo": vals[1]/1e18,
            "available_borrows_celo": vals[2]/1e18, "liq_threshold_bps": vals[3],
            "ltv_bps": vals[4], "health_factor": vals[5]/1e18}

results = {}
rpc_i = 0
batch_sz = 8
for i in range(0, len(addrs), batch_sz):
    chunk = addrs[i:i+batch_sz]
    for attempt in range(5):
        rpc = RPCS[rpc_i % len(RPCS)]
        try:
            res = rpc_batch(rpc, chunk)
            break
        except Exception as e:
            print("batch fail", rpc, e); time.sleep(1.5); rpc_i += 1
    else:
        raise SystemExit("all rpc failed")
    for a, h in zip(chunk, res):
        results[a] = decode_acct(h)
    time.sleep(0.1)
    if i % 80 == 0:
        print(i, "/", len(addrs), flush=True)

json.dump(results, open("/home/heisenberg/CA/moola/analysis/account_data.json","w"), indent=1)

# report
lt = [(a, r) for a, r in results.items() if r and r["health_factor"] < 1.0]
print("\n== HF < 1.0 (liquidatable):", len(lt))
for a, r in sorted(lt, key=lambda x: x[1]["health_factor"]):
    print(f"  {a} HF={r['health_factor']:.6f} coll={r['collateral_celo']:.2f} CELO debt={r['debt_celo']:.2f} CELO")
lt2 = [(a, r) for a, r in results.items() if r and 1.0 <= r["health_factor"] < 1.15]
print("\n== 1.0 <= HF < 1.15:", len(lt2))
for a, r in sorted(lt2, key=lambda x: x[1]["health_factor"])[:40]:
    print(f"  {a} HF={r['health_factor']:.6f} coll={r['collateral_celo']:.2f} debt={r['debt_celo']:.2f}")
tot_coll = sum(r["collateral_celo"] for r in results.values() if r)
tot_debt = sum(r["debt_celo"] for r in results.values() if r)
print(f"\ncovered users={len(results)} total collateral={tot_coll:,.2f} CELO total debt={tot_debt:,.2f} CELO")
