#!/usr/bin/env python3
"""Price the live pool balances with DefiLlama and produce summary stats."""
import json, time, urllib.request

d = json.load(open("pools_latest.json"))
pools = d["pools"]
block = d["block"]

# collect tokens
tokens = set()
for p, st in pools.items():
    if "err" in st:
        continue
    tokens.add(st["t0"].lower()); tokens.add(st["t1"].lower())
tokens = sorted(tokens)
print("unique tokens:", len(tokens))

prices = {}
CH = 45
for i in range(0, len(tokens), CH):
    chunk = tokens[i:i+CH]
    ids = ",".join("gnosis:" + t for t in chunk)
    url = "https://coins.llama.fi/prices/current/" + ids
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "zombie/1.0"}), timeout=40) as r:
                out = json.loads(r.read())
            for k, v in out.get("coins", {}).items():
                prices[k.split(":")[-1].lower()] = v["price"]
            break
        except Exception as e:
            print("retry", e); time.sleep(2)
    time.sleep(0.3)

json.dump({"ts": int(time.time()), "prices": prices}, open("prices_latest.json", "w"))
print("priced tokens:", len(prices))

rows = []
total = 0.0
for p, st in pools.items():
    if "err" in st:
        continue
    usd0 = (st["b0"] or 0) / 1e18 * prices.get(st["t0"].lower(), 0)
    usd1 = (st["b1"] or 0) / 1e18 * prices.get(st["t1"].lower(), 0)
    usd = usd0 + usd1
    total += usd
    rows.append({"pool": p, **{k: st[k] for k in ("t0","t1","b0","b1","liquidity","tick","fee","activeIncentive","liquidityCooldown","tickSpacing","unlocked","price")}, "usd": usd})
rows.sort(key=lambda r: -r["usd"])
json.dump({"block": block, "total_usd": total, "rows": rows}, open("pools_priced.json", "w"))
print(f"TOTAL USD: {total:,.2f} at block {block}")

print("\nTOP 25 pools:")
for r in rows[:25]:
    print(f"{r['pool']} usd={r['usd']:>12,.2f} liq={r['liquidity']:<25} tick={r['tick']:>7} fee={r['fee']:>5} inc={r['activeIncentive']} cd={r['liquidityCooldown']} sp={r['tickSpacing']}")
print("\nvalue concentration: top10=%.2f%% top50=%.2f%%" % (
    100*sum(r['usd'] for r in rows[:10])/total, 100*sum(r['usd'] for r in rows[:50])/total))
nonzero = [r for r in rows if r["usd"] > 1]
print("pools with >$1:", len(nonzero), " >$100:", len([r for r in rows if r['usd']>100]), " >$1000:", len([r for r in rows if r['usd']>1000]))

# anomalies
print("\n== anomalies ==")
lz = [r for r in rows if r["liquidity"] == 0 and r["usd"] > 100]
print("liquidity==0 but usd>100:", len(lz))
for r in lz[:15]: print("   ", r["pool"], round(r["usd"],2))
inc = [r for r in rows if r["activeIncentive"] != "0x0000000000000000000000000000000000000000"]
print("activeIncentive set:", len(inc))
for r in inc[:20]: print("   ", r["pool"], r["activeIncentive"], round(r["usd"],2))
cd = [r for r in rows if r["liquidityCooldown"] != 0]
print("liquidityCooldown != 0:", len(cd))
for r in cd[:20]: print("   ", r["pool"], r["liquidityCooldown"])
unl = [r for r in rows if r["unlocked"] is False]
print("unlocked==false (stuck in swap):", len(unl))
for r in unl[:10]: print("   ", r["pool"], round(r["usd"],2))
sp = {}
for r in rows: sp[r["tickSpacing"]] = sp.get(r["tickSpacing"], 0) + 1
print("tickSpacing distribution:", sp)
fee_dist = {}
for r in rows: fee_dist[r["fee"]] = fee_dist.get(r["fee"], 0) + 1
print("fee distribution (top):", sorted(fee_dist.items(), key=lambda x: -x[1])[:8])
