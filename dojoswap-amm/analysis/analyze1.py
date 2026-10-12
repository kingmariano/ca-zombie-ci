#!/usr/bin/env python3
"""Analyze pairs-live.json: raw sums per denom, anomalies (zero-side pools, zero LP supply),
top pools by raw amounts. Output: analysis/summary-raw.json + printed table."""
import json, collections

d = json.load(open("pairs-live.json"))
pairs = {p["contract_addr"]: p for p in d["pairs"]}
pools = {}
for row in d["pools"]:
    if "pool" in row:
        pools[row["contract"]] = row["pool"]

print(f"height {d['height_start']} -> {d['height_end']}")
print(f"pairs: {len(pairs)}, pools read: {len(pools)}")
print("only_in_factory:", d["only_in_factory"])
print("only_in_code290:", d["only_in_code290"])

# raw sums per denom across all pools
sums = collections.Counter()
per_pair = []
for addr, pool in pools.items():
    pinfo = pairs.get(addr)
    if not pinfo:
        continue
    assets = pool["assets"]
    ts = int(pool["total_share"])
    a0, a1 = int(assets[0]["amount"]), int(assets[1]["amount"])
    i0, i1 = assets[0]["info"], assets[1]["info"]
    per_pair.append((addr, i0, a0, i1, a1, ts, pinfo.get("asset_decimals"), pinfo.get("liquidity_token")))
    sums[("native", i0["native_token"]["denom"]) if "native_token" in i0 else ("token", i0["token"]["contract_addr"])] += a0
    sums[("native", i1["native_token"]["denom"]) if "native_token" in i1 else ("token", i1["token"]["contract_addr"])] += a1

top = sums.most_common(40)
print("\n== top denoms by raw amount across pools (kind, denom, raw_sum) ==")
for (kind, denom), v in top:
    print(f"{kind:6s} {denom} {v}")

# anomalies
zero_side = [(a, i0, a0, i1, a1, ts) for (a, i0, a0, i1, a1, ts, *_ ) in per_pair if (a0 == 0) != (a1 == 0)]
zero_supply = [(a, i0, a0, i1, a1, ts) for (a, i0, a0, i1, a1, ts, *_ ) in per_pair if ts == 0 and (a0 > 0 or a1 > 0)]
zero_supply_res = [(a, i0, a0, i1, a1, ts) for (a, i0, a0, i1, a1, ts, *_ ) in per_pair if ts == 0]
print(f"\n== pools with exactly one zero side: {len(zero_side)} ==")
for r in zero_side[:20]:
    print(r)
print(f"\n== pools with total_share==0 (any reserves): {len(zero_supply_res)} ==")
for r in zero_supply_res[:20]:
    print(r)
print(f"\n== pools with total_share==0 and reserves>0: {len(zero_supply)} ==")
for r in zero_supply[:20]:
    print(r)

# tiny LP supply pools (<=1000 = only locked minimum)
tiny = [(a, i0, a0, i1, a1, ts) for (a, i0, a0, i1, a1, ts, *_ ) in per_pair if 0 < ts <= 1000 and (a0 > 0 or a1 > 0)]
print(f"\n== pools with 0<total_share<=1000 and reserves>0: {len(tiny)} ==")
for r in tiny[:20]:
    print(r)

json.dump({"height_start": d["height_start"], "height_end": d["height_end"],
           "pair_count": len(pairs), "pools_read": len(pools),
           "only_in_factory": d["only_in_factory"], "only_in_code290": d["only_in_code290"],
           "sums": {f"{k[0]}:{k[1]}": v for k, v in sums.items()},
           "zero_side": len(zero_side), "zero_supply": len(zero_supply_res),
           "tiny_supply": len(tiny)},
          open("summary-raw.json", "w"), indent=1)
