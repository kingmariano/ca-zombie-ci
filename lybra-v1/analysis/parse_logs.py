#!/usr/bin/env python3
"""Parse Lybra logs: borrower set + liquidation history."""
import json, datetime, collections

def load(name):
    return json.load(open(f"analysis/logs_{name}.json"))

liq = load("LiquidationRecord")
print(f"LiquidationRecord events: {len(liq)}")
rows = []
for e in liq:
    t = e["topics"]
    d = e["data"][2:]
    words = [d[i:i+64] for i in range(0, len(d), 64)]
    onbehalf = "0x" + t[1][-40:]
    provider = "0x" + words[0][-40:]
    keeper = "0x" + words[1][-40:]
    eusd = int(words[2], 16)
    eth_liq = int(words[3], 16)
    keeper_reward = int(words[4], 16)
    superliq = int(words[5], 16) == 1
    ts = int(words[6], 16)
    rows.append(dict(block=int(e["blockNumber"],16), ts=ts, provider=provider, keeper=keeper,
                     victim=onbehalf, eusd=eusd/1e18, eth=eth_liq/1e18,
                     keeper_reward=keeper_reward/1e18, super=superliq))
rows.sort(key=lambda r: r["block"])
last10 = rows[-10:]
print("\nLast 10 liquidations:")
for r in last10:
    print(f"  blk {r['block']} {datetime.datetime.utcfromtimestamp(r['ts'])} victim={r['victim']} provider={r['provider']} eusd={r['eusd']:.2f} eth={r['eth']:.4f} super={r['super']}")

now = int(datetime.datetime.now().timestamp())
print(f"\nLast liquidation was {(now - rows[-1]['ts'])/3600:.1f}h ago (wall clock)")
# count per 30-day window in last 180 days
cut = now - 180*86400
recent = [r for r in rows if r["ts"] >= cut]
print(f"Liquidations in last 180d: {len(recent)}")
# distinct providers in last 90d
cut90 = now - 90*86400
prov = collections.Counter(r["provider"].lower() for r in rows if r["ts"] >= cut90)
print("Distinct providers last 90d:", len(prov))
for p, c in prov.most_common(10):
    print(f"  {p}: {c}")
# total values
print(f"\nTotal eUSD repaid in liquidations (all time): {sum(r['eusd'] for r in rows):,.2f}")
print(f"Total ETH seized (all time): {sum(r['eth'] for r in rows):,.2f}")
print(f"Super liquidations: {sum(1 for r in rows if r['super'])}")

# borrower universe
dep = load("DepositEther")
mint = load("Mint")
users = set()
for e in dep:
    users.add("0x" + e["topics"][1][-40:].lower())
for e in mint:
    users.add("0x" + e["topics"][1][-40:].lower())
print(f"\nDepositEther events: {len(dep)}, unique onBehalfOf: {len(set('0x'+e['topics'][1][-40:].lower() for e in dep))}")
print(f"Mint events: {len(mint)}, unique onBehalfOf: {len(set('0x'+e['topics'][1][-40:].lower() for e in mint))}")
print(f"Union borrowers: {len(users)}")
json.dump(sorted(users), open("analysis/borrowers.json", "w"), indent=0)
json.dump(rows, open("analysis/liquidations_parsed.json", "w"))
