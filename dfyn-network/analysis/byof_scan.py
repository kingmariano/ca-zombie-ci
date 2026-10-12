#!/usr/bin/env python3
"""Enumerate BYOF farm factories (Dual + Popular/Launch) and scan farm holdings."""
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
def addr(h): return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None
def sel(sig): return subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()

FACS = {
    "dual":   {"addr": "0x34df3b41c2e48d73d912963d12675dc22f8bd352", "info": "stakingRewardsInfo(address)"},
    "pop":    {"addr": "0x57791b5257a8b95d6c0c0a6ad947ffecc5e77953", "info": "stakingRewardsInfoByStakingToken(address)"},
}
DFYN = "0xc168e40227e4ebd8c1cae80f7a55a4f0e6d66c97"
ROUTE = "0x16eccfdbb4ee1a85a33f3a9b21175cd7ae753db4"
out = {}
for name, cfg in FACS.items():
    fac = cfg["addr"]
    st_sel = sel("stakingTokens(uint256)")
    info_sel = sel(cfg["info"])
    tokens = []
    i = 0
    while True:
        idxs = list(range(i, i + 20))
        r = batch([("eth_call", [{"to": fac, "data": st_sel + hex(j)[2:].rjust(64, "0")}, "latest"]) for j in idxs])
        got = [addr(x) for x in r]
        stop = False
        for a in got:
            if a and int(a, 16) != 0:
                tokens.append(a)
            else:
                stop = True; break
        if stop or i > 500:
            break
        i += 20
    print(name, "stakingTokens:", len(tokens), flush=True)
    farms = {}
    for i in range(0, len(tokens), 30):
        chunk = tokens[i:i+30]
        r = batch([("eth_call", [{"to": fac, "data": info_sel + pad(t)}, "latest"]) for t in chunk])
        for t, x in zip(chunk, r):
            farm = ("0x" + x[2:66][-40:]) if isinstance(x, str) and len(x) >= 66 else None
            if farm and int(farm, 16) != 0 and farm != "0x0000000000000000000000000000000000000000":
                farms[t] = farm.lower()
    print(name, "farms:", len(farms), flush=True)
    rows = {}
    farms_list = list(farms.items())
    for i in range(0, len(farms_list), 15):
        chunk = farms_list[i:i+15]
        calls = []
        for t, f in chunk:
            calls += [("eth_call", [{"to": t, "data": "0x70a08231" + pad(f)}, "latest"]),
                      ("eth_call", [{"to": DFYN, "data": "0x70a08231" + pad(f)}, "latest"]),
                      ("eth_call", [{"to": ROUTE, "data": "0x70a08231" + pad(f)}, "latest"]),
                      ("eth_call", [{"to": f, "data": "0x18160ddd"}, "latest"])]
        r = batch(calls)
        for j, (t, f) in enumerate(chunk):
            rows[f] = {"stakingToken": t, "staked": word(r[4*j]), "dfyn": word(r[4*j+1]),
                       "route": word(r[4*j+2]), "ts": word(r[4*j+3])}
    out[name] = rows
json.dump(out, open("/home/heisenberg/CA/dfyn-network/analysis/byof-farm-balances.json", "w"), indent=1)
for name, rows in out.items():
    tot_d = sum(v["dfyn"] or 0 for v in rows.values()) / 1e18
    tot_r = sum(v["route"] or 0 for v in rows.values()) / 1e18
    nz = [v for v in rows.values() if (v["dfyn"] or 0) > 0 or (v["staked"] or 0) > 0]
    print(name, "farms", len(rows), "nonzero", len(nz), "DFYN", round(tot_d, 2), "ROUTE", round(tot_r, 2))
