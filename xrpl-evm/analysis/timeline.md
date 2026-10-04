# Timeline — XRPL EVM vs the August 2026 cosmos/evm incidents

Sources: Cosmos post-mortem, XRPL EVM incident report, on-chain proposals/params
(all times UTC unless noted).

## Upstream

| Date | Event |
|---|---|
| 2026-04-25 | Underflow reported via bug bounty; initially assessed as not fund-loss on production configs |
| 2026-05-15 | Fix merged to cosmos/evm `main` (#1176) as a silent public patch |
| 2026-08-12 | Cosmos privately discloses the second (embargoed) advisory — ERC20 registration path |
| 2026-08-13 | Cosmos confirms all Cosmos EVM chains affected regardless of decimals |
| 2026-08-19 23:01 | cosmos/evm **v0.6.2 / v0.7.2** published (underflow + denom handling fix) |
| 2026-08-20 07:16 | Push Chain PR #40 publicly describes the exploit path |
| 2026-08-20 19:06 | MANTRA attack #1 |
| 2026-08-22 19:46 | TAC attack (2.986B TAC), later halts |
| 2026-08-22 ~21:00 | KiiChain attack (148.3M KII) |
| 2026-08-21..25 | Cosmos tells all chains to halt; 40 networks contacted; 6 exploited |
| 2026-09-03 | **GHSA-367m-g444-9mg3** "Non-atomic StateDB commit" + cosmos/evm **v0.6.3 / v0.7.3** |

## XRPL EVM

| Date | Event |
|---|---|
| 2026-07-16 | Proposal #33 passes — node v10.1.0 upgrade at height 6,856,000 (private July cosmos/evm fix; `evm-priv-jul2026 v0.6.1-xrplevm.1`). Mainnet runs this through August. |
| 2026-07-27 | `xrplevm/evm v0.6.1-xrplevm.1` public tag — **no SubBalance/AddBalance guards** |
| 2026-08-14/15 | Proposal #35 "ERC20 Registration Parameter Update" passes 16/16 — `permissionless_registration=false` (interim mitigation for the embargoed advisory) |
| 2026-08-21 morning | XRPL EVM exposure audit against live state (height ~7,333,096): staking precompile not enabled, zero vesting accounts, bond denom not mirrored — exploit path not reachable |
| 2026-08-23 ~04:30 | Precautionary halt triggered on Cosmos' escalated advice |
| **2026-08-23 05:02:22** | **Last block 7,360,028** |
| 2026-08-23 09:08 | Node v10.2.0 released (v10.1.0 baseline + combined v0.6.2 hotfix) |
| **2026-08-23 19:19:18** | **Resume at block 7,360,029** (14h17m halt) on patched binaries |
| 2026-08-25 15:20 | Global exploit window closes |
| 2026-09-08 | Node v11.1.1 released — pins `xrplevm/evm v0.6.1-xrplevm.2`, still **without** the guards. Never scheduled on mainnet. |
| 2026-09-15 | Node v10.2.1; `xrplevm/evm v0.6.3-xrplevm.1` (all guards) |
| 2026-09-21 | Proposal #38 passes — v11.2.0 upgrade scheduled at height 7,823,200 (ICA host lockdown, 1-week unbonding, stranded XRP recovery) |
| 2026-10-04 | This verification: mainnet `exrp v11.2.0` (commit 40336cc1…), fork `xrplevm/evm v0.6.3-xrplevm.1`, all exploit gates absent, supply unchanged since the halt |

## On-chain fingerprints used

- Halt: EVM block 7,360,028 timestamp `2026-08-23T05:02:22Z`; next block
  7,360,029 `2026-08-23T19:19:18Z` (eth_getBlockByNumber on rpc.xrplevm.org).
- axrp supply at halt height 7,360,028 = `1559956920994118191179874` =
  supply on 2026-10-04 (byte-identical; no mint around the incident).
- Proposals: #33 (v10.1.0), #35 (ERC20 params), #38 (v11.2.0) — full JSON in
  `analysis/gov_proposal_*.json`.
