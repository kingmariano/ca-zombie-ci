#!/usr/bin/env python3
"""
C2-10 Desmos — governance tally simulation with LIVE numbers.

Rules implemented exactly as cosmos-sdk v0.47.10 x/gov/keeper/tally.go:
  - quorum   : totalVotingPower / totalBonded >= quorum      (else FAIL, optionally burn)
  - veto     : NoWithVeto / totalVotingPower > vetoThreshold (else VETOED, deposit burned)
  - threshold: Yes / (totalVotingPower - Abstain) > threshold(else FAIL)
Inputs: bonded, quorum/threshold/veto params, DSM spot price.
"""
import json

B = 82_888_768.073014          # bonded DSM, h 30,863,237 (api.mainnet.desmos.network)
QUORUM, THRESHOLD, VETO = 0.334, 0.5, 0.334
CP = 16_666_867.902454         # community pool DSM
PRICE = 0.00942007             # USD/DSM (CoinGecko simple, 2026-10-05)
TOP4 = 20_041_501.534342 + 17_807_658.452022 + 16_029_929.210062 + 14_925_161.399968  # 68,804,250.596394
QUORUM_DSM = QUORUM * B

def outcome(a_yes, others):
    v = {"yes": a_yes, "no": 0.0, "veto": 0.0, "abstain": 0.0}
    for opt, amt in others:
        v[opt] += amt
    total = sum(v.values())
    if total < QUORUM_DSM:
        return "FAIL (quorum not met)"
    if total - v["abstain"] <= 0:
        return "FAIL (all abstain)"
    if v["veto"] / total > VETO:
        return f"VETOED (veto share {v['veto']/total:.2%}; deposit burned)"
    if v["yes"] / (total - v["abstain"]) > THRESHOLD:
        return f"PASS (yes share {v['yes']/(total-v['abstain']):.2%})"
    return f"FAIL (threshold; yes share {v['yes']/(total-v['abstain']):.2%})"

scenarios = [
    ("S1 attacker quorum, validators silent",           QUORUM_DSM, []),
    ("S2 attacker quorum, top-4 vote No",               QUORUM_DSM, [("no", TOP4)]),
    ("S3 attacker outvotes top-4 (No), buys >68.8M",    68_900_000, [("no", TOP4)]),
    ("S4 attacker 68.9M, top-4 NoWithVeto",             68_900_000, [("veto", TOP4)]),
    ("S5 attacker 137.3M, top-4 NoWithVeto",            137_300_000, [("veto", TOP4)]),
    ("S6 attacker quorum, top-4 Abstain",               QUORUM_DSM, [("abstain", TOP4)]),
    ("S7 attacker 0, validators as prop 52",            0, [("yes", 76_248_632.162956)]),
]

print(f"bonded={B:,.3f} DSM | quorum threshold={QUORUM_DSM:,.3f} DSM | CP={CP:,.3f} DSM (${CP*PRICE:,.2f})")
print(f"top-4={TOP4:,.3f} DSM ({TOP4/B:.2%} of bonded) | price=${PRICE}/DSM\n")
rows = []
for name, a, others in scenarios:
    res = outcome(a, others)
    cost = a * PRICE
    realizable = 7_180.0  # dump CP into observable pools (see COST-MODEL.md / capture-economics.md)
    net = realizable - cost
    rows.append((name, a, cost, res, net))
    print(f"{name:52s} A={a:>12,.0f} cost=${cost:>12,.2f} -> {res} | net(vs CP-dump ${realizable:,.0f}) = ${net:>12,.2f}")

# break-even OTC price for the cheapest passing scenario (S1)
be = 7_280.0 / QUORUM_DSM
print(f"\nBreak-even acquisition price for S1 = ${be:.6f}/DSM = {be/PRICE:.2%} of market price")
print(f"Observable DSM exit liquidity (Osmosis pools, counter value) ~ $7.35k")

with open("analysis/tally-simulation.md", "w") as f:
    f.write("# C2-10 Desmos — governance tally simulation (cosmos-sdk v0.47.10 rules)\n\n")
    f.write(f"- bonded **{B:,.3f} DSM**, quorum **{QUORUM_DSM:,.3f} DSM**, CP **{CP:,.3f} DSM** (${CP*PRICE:,.2f} nominal)\n")
    f.write(f"- top-4 validators **{TOP4:,.3f} DSM = {TOP4/B:.2%}** of bonded\n")
    f.write(f"- DSM price ${PRICE}; observable exit liquidity ≈ $7.35k; CP dump ≈ $7.18k\n\n")
    f.write("| scenario | attacker Yes (DSM) | cost at spot | outcome | net vs CP dump |\n|---|---|---|---|---|\n")
    for name, a, cost, res, net in rows:
        f.write(f"| {name} | {a:,.0f} | ${cost:,.2f} | {res} | ${net:,.2f} |\n")
    f.write(f"\nBreak-even acquisition price (S1) = **${be:.6f}/DSM = {be/PRICE:.2%} of market price**.\n")
    f.write("\nNote: the entire liquid DSM supply outside bonded/CP/rewards pools is ~55M DSM, of which only ~41.3M sits on Osmosis; S3/S5 require acquiring more DSM than any observable liquid venue holds.\n")
print("\nwrote analysis/tally-simulation.md")
