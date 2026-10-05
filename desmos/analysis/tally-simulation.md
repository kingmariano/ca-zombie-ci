# C2-10 Desmos — governance tally simulation (cosmos-sdk v0.47.10 rules)

- bonded **82,888,768.073 DSM**, quorum **27,684,848.536 DSM**, CP **16,666,867.902 DSM** ($157,003.06 nominal)
- top-4 validators **68,804,250.596 DSM = 83.01%** of bonded
- DSM price $0.00942007; observable exit liquidity ≈ $7.35k; CP dump ≈ $7.18k

| scenario | attacker Yes (DSM) | cost at spot | outcome | net vs CP dump |
|---|---|---|---|---|
| S1 attacker quorum, validators silent | 27,684,849 | $260,793.21 | PASS (yes share 100.00%) | $-253,613.21 |
| S2 attacker quorum, top-4 vote No | 27,684,849 | $260,793.21 | FAIL (threshold; yes share 28.69%) | $-253,613.21 |
| S3 attacker outvotes top-4 (No), buys >68.8M | 68,900,000 | $649,042.82 | PASS (yes share 50.03%) | $-641,862.82 |
| S4 attacker 68.9M, top-4 NoWithVeto | 68,900,000 | $649,042.82 | VETOED (veto share 49.97%; deposit burned) | $-641,862.82 |
| S5 attacker 137.3M, top-4 NoWithVeto | 137,300,000 | $1,293,375.61 | PASS (yes share 66.62%) | $-1,286,195.61 |
| S6 attacker quorum, top-4 Abstain | 27,684,849 | $260,793.21 | PASS (yes share 100.00%) | $-253,613.21 |
| S7 attacker 0, validators as prop 52 | 0 | $0.00 | PASS (yes share 100.00%) | $7,180.00 |

Break-even acquisition price (S1) = **$0.000263/DSM = 2.79% of market price**.

Note: the entire liquid DSM supply outside bonded/CP/rewards pools is ~55M DSM, of which only ~41.3M sits on Osmosis; S3/S5 require acquiring more DSM than any observable liquid venue holds.
