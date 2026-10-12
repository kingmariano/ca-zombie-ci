#!/usr/bin/env python3
"""Scan the 15 factory-deployed farms that are missing from the curated registry."""
import json, urllib.request, time, subprocess

UA = {"User-Agent": "Mozilla/5.0 dfyn-research", "Content-Type": "application/json"}
RPCS = ["https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"]
cur = [0]

def batch(calls, timeout=90, tries=8):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode(); last = None
    for t in range(tries):
        try:
            req = urllib.request.Request(RPCS[cur[0] % len(RPCS)], data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for it in d:
                    if isinstance(it.get("id"), int) and 0 <= it["id"] < len(calls):
                        out[it["id"]] = it.get("result") or it.get("error")
                return out
        except Exception as e:
            last = str(e)[:80]; cur[0] += 1; time.sleep(1 + t)
    raise RuntimeError(last)

def pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def word(h):
    try: return int(h[2:66], 16) if isinstance(h, str) and len(h) >= 66 else None
    except: return None
def addrw(h):
    return ("0x" + h[2:66][-40:]) if isinstance(h, str) and len(h) >= 66 else None
def sel(sig): return subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()

MISSING = ["0x13a5dae25ca53ba189858ef59a11ed5a7f5ba203","0x1d5f09c8e0dcac6355338e94936d53df35e681b4",
"0x1eb6110490d72d9d9463648534432555faa11211","0x25bbff88e03a61920a6caf557addd083c1a682ee",
"0x3a2f9a7665f363d07faf9776067b80589f2cbc78","0x3e9a073cc93223a4d4fb75bc5dfc0a91d9f18bfa",
"0x432c89dab7df8917a233849aed9240ec40336f52","0x57aa426965a36e15c516b5c592dbd64df5105706",
"0x5c974377eb746de8b8a416171815f43889b9fcb6","0x668d23c1f253ad5b20a74aa535c82ca04c91d2d0",
"0x81315e2eade491479e7ee7617c08113e13b74d32","0xa60df42df58495bf8c7e3cbaeddb3cb346cf0db8",
"0xa6fa205167d60eb792f460165d47b46112ef3cb0","0xee3dddb92262d972a0e1f1b6685f5fbdee9e0594",
"0xfcbd5c629549a180cf470e68f2c2dd818b1fc8ed"]
DFYN = "0xc168e40227e4ebd8c1cae80f7a55a4f0e6d66c97"
ROUTE = "0x16eccfdbb4ee1a85a33f3a9b21175cd7ae753db4"
sel_st = sel("stakingToken()")
sel_rt = sel("rewardsToken()")
rows = {}
for i in range(0, len(MISSING), 5):
    chunk = MISSING[i:i+5]
    calls = []
    for f in chunk:
        calls += [("eth_call", [{"to": f, "data": sel_st}, "latest"]),
                  ("eth_call", [{"to": f, "data": sel_rt}, "latest"]),
                  ("eth_call", [{"to": f, "data": "0x18160ddd"}, "latest"])]
    r = batch(calls)
    for j, f in enumerate(chunk):
        st = addrw(r[3*j]); rt = addrw(r[3*j+1]); ts = word(r[3*j+2])
        rows[f] = {"stakingToken": st, "rewardsToken": rt, "ts": ts}
    # balances
    calls = []
    for f in chunk:
        st = rows[f]["stakingToken"]
        calls += [("eth_call", [{"to": st, "data": "0x70a08231" + pad(f)}, "latest"]) if st else ("eth_call", [{"to": "0x0000000000000000000000000000000000000000", "data": "0x"}, "latest"]),
                  ("eth_call", [{"to": DFYN, "data": "0x70a08231" + pad(f)}, "latest"]),
                  ("eth_call", [{"to": ROUTE, "data": "0x70a08231" + pad(f)}, "latest"])]
    r = batch(calls)
    for j, f in enumerate(chunk):
        rows[f]["staked"] = word(r[3*j])
        rows[f]["dfyn"] = word(r[3*j+1])
        rows[f]["route"] = word(r[3*j+2])
json.dump(rows, open("/home/heisenberg/CA/dfyn-network/analysis/missing-farms-scan.json", "w"), indent=1)
for f, v in rows.items():
    print(f, "stk", v["stakingToken"], "rew", v["rewardsToken"], "ts", (v["ts"] or 0)/1e18 if v["ts"] else 0,
          "staked", (v["staked"] or 0)/1e18 if v["staked"] else 0, "dfyn", (v["dfyn"] or 0)/1e18, "route", (v["route"] or 0)/1e18)
