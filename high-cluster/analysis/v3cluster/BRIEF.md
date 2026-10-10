# BRIEF — V3-fork / small-chain cluster (parent-owned)

Chains: HyperEVM, BSC, XDC, MegaETH, Flow EVM, Abstract. Targets (DefiLlama 2026-10-10):
| Protocol | Chain | DefiLlama TVL | Notes |
|---|---|---|---|
| HyperSwap V3 | HyperEVM | $11.08M | Uni V3 fork |
| HyperSwap V2 | HyperEVM | $6.79M | Uni V2 fork (bonus, same team) |
| Kinza Finance | BSC/opBNB/ETH/Mantle | $2.94M | Aave-v3 fork lending |
| Kumbaya | MegaETH | $1.91M | DEX (V2/V3?) |
| KittyPunch StableKitty | Flow EVM | $1.78M | Curve NG fork (finding said Abstract — actually Flow) |
| KittyPunch PunchSwap / V3 | Flow EVM | $496k / $42k | |
| Aborean AMM / CL | Abstract | $281k / $180k | |
| Fathom Lending / CDP / AMM | XDC | $364k / $265k / $51k | lending + CDP |

Method: per protocol, verify live balances on-chain; identify factory/pools; check pool math (k invariant,
fee accounting, skim/sync) and admin (owner/pause/upgrade); check lending oracle/pause config for
Kinza/Fathom; look for stale-price or admin-misconfig extraction. Classify E-U/H-O/P/S with exact amounts.
Coverage may be "screened" for the smallest ones if fully audited is not feasible — say so explicitly.
PoC in `poc-v3cluster/test/`. Logs: `ci-out/poc-v3cluster.log`.
