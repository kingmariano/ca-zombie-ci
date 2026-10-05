#!/usr/bin/env python3
"""Enumerate all JUNO liquidity on Osmosis (GAMM + CL) via public LCD. Read-only."""
import json, time, urllib.request, urllib.parse, base64, sys

LCD = "https://lcd.osmosis.zone"
UA = "Mozilla/5.0 (X11; Linux x86_64) verification-research"
JUNO = "ibc/46B44899322F3CD854D2D46DEEF881958467CDD4B3B10086DA49296BBED94BED"

def get(path, params=None):
    url = LCD + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(f"  retry {attempt+1} {path}: {e}", file=sys.stderr)
            time.sleep(2)
    raise RuntimeError(f"failed: {url}")

# ---------- GAMM ----------
pages = []
key = None
for i in range(10):
    params = {"pagination.limit": 1000}
    if key:
        params["pagination.key"] = key
    d = get("/osmosis/gamm/v1beta1/pools", params)
    pools = d.get("pools", [])
    pages.append(d)
    key = d.get("pagination", {}).get("next_key")
    print(f"gamm page {i+1}: {len(pools)} pools, next_key={key}", file=sys.stderr)
    if not key:
        break
    time.sleep(0.3)

all_pools = []
for d in pages:
    all_pools.extend(d.get("pools", []))
print(f"total gamm pools: {len(all_pools)}", file=sys.stderr)

gamm_hits = []
for p in all_pools:
    pools_arr = p.get("poolAssets") or p.get("pool_assets") or []
    found = False
    juno_amt = 0
    reserves = []
    for a in pools_arr:
        tok = a.get("token", {})
        reserves.append((tok.get("denom"), tok.get("amount")))
        if tok.get("denom") == JUNO:
            found = True
            juno_amt = int(tok.get("amount", 0))
    if found:
        gamm_hits.append({
            "id": p.get("id"),
            "@type": p.get("@type"),
            "address": p.get("address"),
            "juno_ujuno": juno_amt,
            "juno": juno_amt / 1e6,
            "reserves": reserves,
            "total_shares": (p.get("totalShares") or p.get("total_shares") or {}).get("amount"),
        })

gamm_hits.sort(key=lambda x: -x["juno_ujuno"])
gamm_total = sum(h["juno_ujuno"] for h in gamm_hits) / 1e6
print(f"gamm JUNO pools: {len(gamm_hits)}, total JUNO = {gamm_total:.6f}", file=sys.stderr)

with open("osmosis_gamm_all.json", "w") as f:
    json.dump({"pages": len(pages), "total_pools": len(all_pools), "juno_denom": JUNO,
               "juno_pools": gamm_hits, "juno_total": gamm_total}, f, indent=1)

# ---------- Concentrated liquidity ----------
cl_pools = []
key = None
for i in range(10):
    params = {"pagination.limit": 1000}
    if key:
        params["pagination.key"] = key
    d = get("/osmosis/concentratedliquidity/v1beta1/pools", params)
    pl = d.get("pools", [])
    cl_pools.extend(pl)
    key = d.get("pagination", {}).get("next_key")
    print(f"cl page {i+1}: {len(pl)} pools, next_key={key}", file=sys.stderr)
    if not key:
        break
    time.sleep(0.3)

cl_hits = []
for p in cl_pools:
    t0 = (p.get("token0") or "")
    t1 = (p.get("token1") or "")
    if t0 == JUNO or t1 == JUNO:
        cl_hits.append({
            "id": p.get("id"),
            "address": p.get("address"),
            "token0": t0, "token1": t1,
            "current_tick": p.get("current_tick"),
        })

# balances for each CL pool address
for h in cl_hits:
    bal = get(f"/cosmos/bank/v1beta1/balances/{h['address']}")
    j = 0
    others = []
    for b in bal.get("balances", []):
        if b["denom"] == JUNO:
            j = int(b["amount"])
        else:
            others.append((b["denom"], b["amount"]))
    h["juno_ujuno"] = j
    h["juno"] = j / 1e6
    h["other_balances"] = others
    time.sleep(0.2)

cl_total = sum(h["juno_ujuno"] for h in cl_hits) / 1e6
print(f"cl JUNO pools: {len(cl_hits)}, total JUNO = {cl_total:.6f}", file=sys.stderr)

with open("osmosis_cl_juno.json", "w") as f:
    json.dump({"total_pools": len(cl_pools), "juno_pools": cl_hits, "juno_total": cl_total}, f, indent=1)

print(f"OSMOSIS TOTAL JUNO = {gamm_total + cl_total:.6f}")
