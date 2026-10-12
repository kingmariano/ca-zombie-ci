# DeFi Franc (DCHF) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Ethereum (mainnet) · **Blocks:** 26,173,716 → 26,175,501 (fork pin: latest at run time)
**Status:** read-only audit; PoC fork-verified only; **no mainnet transactions**; no secrets in this folder.

DeFi Franc is a Liquity-style, multi-collateral CDP protocol (ETH + WBTC) issuing the CHF-pegged
stablecoin **DCHF**, launched 2022-09-25 by `0x7d7711efd844e5e204df29dc3e109d1af95a801c`, abandoned
since (~2023). Triage flagged **$286,773 live**. This deep dive re-verified every contract, measured
the full live balance sheet (**≈$680k**, 2.4× the triage figure), and fork-tested every unprivileged
extraction path.

---

## 1. TL;DR

| target | live value (USD) | extractable by unprivileged attacker (E-U) | why open/closed | latent risk |
|---|---|---|---|---|
| Trove collateral (ActivePool) | $273,975 | **$0** | troves at ICR 174% / 856% / 919% ≫ MCR 110%; liquidations revert | none until price crash < 110% CR |
| CollSurplusPool (liquidation/redemption surpluses) | $254,040 | **$0** | `claimColl` pays only the recorded trove owner (`BO.claimCollateral(msg.sender)`) — 21 EOAs hold all claims | keys lost → stuck |
| Stability pools (SP_ETH + SP_WBTC) | $61,493 | **$0** | collateral is claimable only by snapshot-holding depositors (503 + 282 EOAs); **44% is stranded with no claim** | key loss → stuck |
| MONStaking (staker rewards) | $16,930 + 14.6M MON | **$0** | rewards accrue only to pre-existing stakes; new staker pending gain = 0 (fork-verified) | none |
| AirdropMON aggregator | $53,361 | **$0** | users can claim only F-scaled shares (~$187); **~$53.2k is unattributed and unclaimable** (`sweep()` blocks DCHF/MON/ETH/WBTC) | permanently stuck |
| DCHF/USDC UniV3 pool (only DCHF market) | $1,190 | **$0 net** | buy+redeem arb exists on paper: $3.00 → 2.616 DCHF → redeem $3.126 → **gross +$0.126 max**; gas 643k @1 gwei = $1.64 → net ≈ **−$1.51** | pool sells only 4.74 DCHF ever |
| GasPool DCHF | $723 | **$0** | only liquidator/close can touch it; no liquidatable troves | frozen |
| MON vesting (LockedMON) | $2,170 | **$0** | team vesting (owner = Gnosis Safe) | privileged |
| **TOTAL** | **≈$679.8k** | **$0** | — | — |

### Total live extractable by an external unprivileged attacker right now: **$0**
Confidence: **high**. (Best-case theoretical gross on the dead V3 pool: $0.126 per $3 cycle, capped by
4.74 DCHF of sellable pool liquidity; always negative at ≥1 gwei gas. No other path exists.)

---

## 2. The protocol in exact terms (deployed code, re-verified)

Deployment map (all verified sources saved in `analysis/src/`):

| role | address | code |
|---|---|---|
| ActivePool | `0x77E034c8A1392d99a2C776A6C1593866fEE36a33` | ActivePool.sol (Liquity fork) |
| DefaultPool | `0xC1f785B74a01dd9FAc0dE6070bC583fe9eaC7Ab5` | DefaultPool |
| StabilityPool ETH | `0x6a9f9d6F5D672a9784c5E560a9648de6cbe2c548` | StabilityPool |
| StabilityPool WBTC | `0x04556d845f12Ff7D8Ff04a37F40387Dd1B454c4b` | StabilityPool |
| TroveManager | `0x99838142189adE67c1951f9c57c3333281334F7F` | TroveManager |
| TroveManagerHelpers | `0xaAACB8C39Bd5Acbb0A236112Df8d15411161e518` | custom helper (all setters guarded) |
| BorrowerOperations | `0x9eB2Ce1be2DD6947e4f5Aabe33106f48861DFD74` | BorrowerOperations |
| CollSurplusPool | `0xA622c3bdBFBE749B1984bc127bFB500e196F594b` | CollSurplusPool |
| StabilityPoolManager | `0x202FbFF035188f9f0525E144C8B3F8249a74aD21` | StabilityPoolManager |
| DCHF token | `0x045da4bFe02B320f4403674B3b7d121737727A36` | DCHFToken (1 BO, 1 TM registered) |
| MON token | `0x1EA48B9965bb5086F3b468E50ED93888a661fc17` | MONToken (100M supply) |
| MONStaking | `0x8Bc3702c35D33E5DF7cb0F06cb72a0c34Ae0C56F` | fee staking (unpaused) |
| AirdropMON | `0xff42ec1c83e0f4939c45ab4f6a027b44e5a3fc8f` | airdrop/vesting aggregator |
| CommunityIssuance | `0x0fa46e8cBCEff8468DB2Ec2fD77731D8a11d3D86` | MON issuance |
| GasPool | `0xc9a113c35f961af3526e6f016f6df9da0a4c7bfa` | 63-byte GasPool |
| PriceFeed | `0x09AB3C0ce6Cb41C13343879A667a6bDAd65ee9DA` | dual-Chainlink (price ÷ CHF index) |
| DfrancParameters | `0x6F9990B242873d7396511f2630412A3fcEcacc42` | params |
| HintHelpers / SortedTroves / MultiTroveGetter | `0x17244338034bea1fa940779bc769ff01833406c4` / `0x1Dd69453a685C735f2ab43E2169b57e9Edf72286` / `0xd4ecc372e99dabdbc0fabe02d2515a24388facca` | helpers |
| Gnosis Safe (owner/treasury) | `0x83737EAe72ba7597b36494D723fbF58cAfee8A69` | Safe v1.3.0, 2-of-3, no modules |
| AdminContract (controller) | `0x2748C55219DCa1D9D3c3a57505e99BB04e42F254` | owner = Gnosis Safe |

Mechanics re-verified on-chain/code:

- **Oracles:** `PriceFeed` = Chainlink **ETH/USD** (`0x5f4e…8419`) ÷ Chainlink **CHF/USD**
  (`0x449d…B13A`), i.e. ETH priced **in CHF** — correct for a CHF stablecoin. Live 2026-10-12:
  ETH/CHF `2,110.13`, WBTC/CHF `69,349.64`; consistency check: ETH/USD 2,541.98 × (1/1.20480842) =
  2,109.9 ≈ oracle ✓. `status()==chainlinkWorking`. **Note (latent):** the index oracle is only
  checked for "broken", **not** for staleness — the CHF/USD feed was 12 h old and still used (4 h
  TIMEOUT applies to the price oracle only). Not exploitable (no attacker-controlled input).
- **Troves:** exactly **1 ETH trove** (`0xaf534cf9…`, 26.3172 ETH coll, 31,994.01 DCHF debt,
  **ICR 174.35%**) and **2 WBTC troves** (`0xbcc26c10…` 8.6 k% … measured 856.3%,
  `0x9e0e1132…` 919.0%; the latter holds all redistributed pending rewards 0.08607 WBTC /
  6,684.13 DCHF). MCR 110%, CCR 150%, gas comp 200 DCHF, MIN_NET_DEBT 2,000 DCHF.
- **Liquidations:** impossible — every ICR ≫ MCR; `liquidate()` and `batchLiquidateTroves()` both
  revert (`0L`). No liquidator path.
- **Redemptions:** permissionless (`isRedemptionWhitelisted == false`, `redemptionBlock` = Oct-2022).
  Fee = `REDEMPTION_FEE_FLOOR (0.5%) + decayed baseRate`, and the fork charges the **post-update**
  rate. Fork's `BETA = 2` and `MINUTE_DECAY_FACTOR = 0.999037…` (half-life ≈ 7 min) mean the first
  redemption of a day pays 0.5–2 %+. **Redeeming at fair value is always a loss** (fork-verified:
  1,000 DCHF → 0.4597 ETH vs 0.4694 ETH fair; −$24.85 vs CHF face value).
- **`_requireMoreThanOneTroveInSystem` inside `_closeTrove`:** the **last trove of a collateral can
  never be closed** — the ETH trove is permanently unclosable (fork-verified, even when funded with
  DCHF). The two WBTC troves can be closed by their owners (fork-verified: owner recovered
  0.80396 WBTC). Ownership: 3 EOAs; the ETH-trove owner holds only **21.56 DCHF** (not 21.5k — a
  misread I corrected), the WBTC owners hold ~0 — so nobody can repay/close today without buying DCHF.
- **Stability pools:** both have **zero DCHF deposits** but hold collateral (`SP_ETH` 16.4839 ETH,
  `SP_WBTC` 0.2346 WBTC). Epochs: SP_ETH epoch 2 (two pool-emptying offsets), SP_WBTC epoch 1.
  `withdrawFromSP(0)` pays a depositor **exactly their snapshot gain**; a stranger reverts
  `"StabilityPool: User must have a non-zero deposit"`. 503 (ETH) + 282 (WBTC) depositors can claim
  **5.874166 ETH / 0.12952266 WBTC**; **10.60977 ETH / 0.10508884 WBTC is attributed to no one**
  (accounting loss in epoch/scale snapshots) → stuck.
- **CollSurplusPool:** holds **23.7054 ETH + 2.32048 WBTC** ($254,040) from recovery-mode
  liquidations & full-redemption closes. `claimColl` is only callable through
  `BorrowerOperations.claimCollateral(msg.sender)` → pays exactly the caller's recorded balance.
  21 EOA claimants hold 100% of it (largest: 0.9152 WBTC = `0xf78da622…`). Stranger reverts.
- **MONStaking:** fee staking (paused=false). Holds 1.60479 ETH + 0.06095 WBTC + 6,440.95 DCHF of
  staker fees + 14.605M MON principal. New stakers' snapshot is set at stake-time → zero historical
  rewards (fork-verified); unstake returns MON.
- **AirdropMON:** holds **21,339 DCHF + 5.288 ETH + 0.17017 WBTC** (~$53.4k) harvested from
  MONStaking on behalf of 28 "freezer" users — but the F_ASSETS/F_DCHF attribution only ever
  credited **~$187** to those users (verified per-user: pending = 27.17 DCHF + 0.0271 ETH +
  0.00103 WBTC). The residual is unattributable: `sweep()` explicitly protects DCHF/MON/ETH/WBTC
  (fork-verified revert), and claims require `stakes>0` + snapshots. **~$53.2k permanently stuck.**
- **CommunityIssuance / LockedMON:** 108,990 MON and 10M MON — owner/team-scoped (P).
- **V3 DCHF/USDC pool:** the only DCHF market. One active position (L=6.0059e13, ticks
  −277380…−273700) holding **4.744 DCHF + $5.94**; the pool's headline balances (981.24 DCHF,
  $8.36) are mostly direct donations that no position owns (uncollectable). Quote: $100 USDC →
  **4.744 DCHF max**; spot ≈ $1.094/DCHF vs redemption ≈ $1.199/DCHF → a paper 9 % discount, but
  exhausted after ~$5.

---

## 3. Live-state assessment (block 26,175,501, 2026-10-12)

Prices used: **ETH $2,541.98, WBTC $83,505.5** (DefiLlama/Chainlink ≈ same), **CHF/USD 1.20480842**
(Chainlink CHF/USD), DCHF at CHF face.

| contract / actor | asset | amount | USD |
|---|---|---|---|
| ActivePool | ETH / WBTC | 26.317196 / 2.4798069 | $66,898 / $207,077 |
| DefaultPool | WBTC | 0.08606625 | $7,187 |
| SP_ETH | ETH | 16.483936 | $41,902 |
| SP_WBTC | WBTC | 0.2346115 | $19,591 |
| CollSurplusPool | ETH / WBTC | 23.705418 / 2.3204820 | $60,268 / $193,772 |
| MONStaking | ETH / WBTC / DCHF | 1.60479 / 0.060953 / 6,440.95 | $4,080 / $5,090 / $7,760 |
| AirdropMON | DCHF / ETH / WBTC | 21,339.12 / 5.288 / 0.17017 | $25,709 / $13,442 / $14,210 |
| GasPool | DCHF | 600 | $723 |
| V3 pool | DCHF / USDC | 981.2408 / 8.36 | $1,182 / $8 |
| CommunityIssuance | MON | 108,989.84 | ~$24 |
| MONStaking staked | MON | 14,605,473.9 | ~$3,169 |
| LockedMON (`0x8eba1ad2`) | MON | 10,000,000 | ~$2,170 |
| **DCHF supply** | DCHF | **51,876.7523** | |

DCHF holders: 1,418 addresses >0 (1,121 in the captured set); top holders are AirdropMON
(21,339.1), MONStaking (6,440.9), `0xdcb11e81…` (3,807.5), `0x1815cddd…` EOA (2,351.2), V3 pool
(981.2), GasPool (600), CoW settlement (370.5). Sum of system-contract DCHF ≈ 29,600; the rest sits
in EOAs, so no contract with a public drain exists.

**Method note on the SP / AirdropMON gaps:** in both cases the physical balance exceeds the sum of
all claimable entitlements (SP: 10.61 ETH + 0.105 WBTC; AirdropMON: ~$53.2k). I verified the claim
gates empirically; the excess has **no call path** to any claimant — stuck (S), not extractable.

---

## 4. What an attacker can / cannot do (exact paths)

**Cannot (all fork-verified):**
- Liquidate any trove → revert (`0L`) — ICRs 174 %–919 % ≫ 110 %.
- Claim any SP gain / CollSurplusPool balance as a stranger → reverts
  (`User must have a non-zero deposit`; `No collateral available to claim`).
- Close the ETH trove → revert (`OO`, last-trove rule) — even with full DCHF funding.
- Capture MONStaking's accumulated fees by staking fresh MON → pending gain 0.
- Rescue AirdropMON's balances via `sweep()` → `ProtectedToken` revert; user claims bounded by
  F-accounting.
- Profit from redemption, or from mint→redeem (borrow fee 0.5 % + redemption fee 0.5–2 %+): always a
  loss — verified: 2,100 DCHF minted for 2 ETH collateral → redeem returns 0.9507 ETH.

**The only live E-U candidate (executed end-to-end on the fork, `test_07`):**
1. Swap **3.00 USDC → 2.61581 DCHF** on the UniV3 DCHF/USDC pool (`0x0b1debf6…`, fee 500).
2. `TroveManager.redeemCollateral(ETH, 2.6158e18, hints…)` → **0.00122628 ETH = $3.1258**.
3. Gross = **+$0.1259**; gas 643,492 → at the block basefee ($0.115) net **+$0.0105**; at **1 gwei**
   gas costs **$1.640** → net **−$1.51**. Total pool capacity 4.744 DCHF.
   ⇒ Breakeven only under sub-0.15 gwei, zero-priority-fee conditions; anything realistic is a loss.

**Holder-recoverable (H-O) — self-service, not E-U:**
- CollSurplusPool $254,040 (21 claimants) · SP claims $25,750 (785 depositors) · MONStaking rewards
  $16,930 + MON $3,169 · DefaultPool $7,187 (trove `0x9e0e…`) · ActivePool $273,975 (3 trove owners;
  they may withdraw collateral down to the 150 % system-TCR / 110 % trove limits — ≈$187k is
  withdrawable today across the 3 troves — or redeem/repay) · EOA DCHF ~$4.8k.

**Privileged (P):** the 2-of-3 Gnosis Safe (owner of BO/TM/DCHF/MONStaking/params) can add a
malicious BorrowerOps to the DCHF token (`addBorrowerOps` only checks `isContractBorrowerOps()`),
mint DCHF and drain the ActivePool — a fully privileged rug path, out of the E-U scope. LockedMON
$2,170 and CommunityIssuance $24 are also team-scoped.

---

## 5. PoC / fork verification

`poc/` (Foundry): `test/DeFiFrancPoC.t.sol`, interfaces in `src/Interfaces.sol`.
**CI: 11/11 PASS** — run [38230188670](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38230188670)
(prior iterations: 38205190492 compile, 38205461938 8/10, 38205856312 9/10, 38206382449 10/10,
38206943535 10/10, 38208918567 9/11, final 38230188670 11/11).

| test | proves | key numbers (fork block 26,175,501) |
|---|---|---|
| 01 state | 1 ETH / 2 WBTC troves; ICRs 174.35 / 856.3 / 919.0 % | — |
| 02 liquidation | `liquidate` + `batchLiquidateTroves` revert | — |
| 03 close lock | `closeTrove(ETH)` fails even when funded; WBTC owner close succeeds | recovered 0.80396145 WBTC |
| 04 redemption | 1,000 DCHF → 0.4597 ETH vs 0.4694 fair (−$24.85) | fee rate 2.0628 % |
| 05 SP gate | stranger reverts; depositor gets exactly 0.7865226 ETH | deposit 2,364.76 DCHF |
| 06 CSP gate | stranger reverts; owner gets exactly 0.91522192 WBTC | — |
| 07 V3 arb | full buy+redeem executed; gross $0.126; net −$1.51 @1 gwei | gas 643,492 |
| 08 mint+redeem | 2,100 DCHF minted → 0.9507 ETH back on 2 ETH collateral | fees 1 % round-trip |
| 09 MONStaking | fresh staker pending ETH/DCHF = 0 | — |
| 10 market | $100 USDC → 4.744 DCHF max | pool donation 976.5 DCHF uncollectable |
| 11 AirdropMON | freezer gets only 28.31 DCHF; `sweep(DCHF)` by owner reverts | ~$53.2k stuck |

CI also runs `ci/run.sh` → `ci-out/state.json` (live state dump, redacted RPC).

---

## 6. Verdict & residual/latent risk

**E-U = $0 (high confidence).** Every live value is either (a) gated to a specific
owner/depositor (H-O, ~$586k), (b) privileged (P, ~$2.2k + the Safe rug path), or (c) permanently
stuck (S, ~$91.6k). The single market-based path (DCHF/USDC V3 discount) has $0.126/cycle of gross
capacity and is gas-negative at ≥1 gwei.

Latent risks to watch:
- A sharp ETH/WBTC drawdown could push troves below 110 %, re-enabling liquidations (the
  liquidator then competes with an empty stability pool; with 26.3 ETH / 2.48 WBTC of collateral
  this is the only route to material E-U).
- The Gnosis Safe (2-of-3) plus `AdminContract` retain full control (add BO/TM, swap oracles,
  re-enable redemption whitelist) — a key compromise = total drain.
- The CHF/USD index oracle staleness is unchecked (`_chainlinkIsFrozen` not applied to the index) —
  a wrong-but-unfrozen index would misprice redemptions; no attacker input today.

Blockers: last-trove lock (ETH), scarce DCHF (top non-contract holder 2,351 DCHF), no DCHF
liquidity, zero SP deposits, no liquidatable troves.

---

## 7. Methodology, sources, files

Read-only RPC (`eth_call`/`eth_getLogs`), Etherscan V2 verified sources, event reconstruction
(SP/AirdropMON/CollSurplusPool/DCHF transfer graphs), DefiLlama + Chainlink pricing, and Foundry
fork PoCs on GitHub Actions (public RPCs only). Triage baseline: `l2-triage-a/summary.json`
(row *DeFi Franc*, $286,773 = ActivePool+DefaultPool+staked MON — the CollSurplusPool and both
stability pools were **not** counted; corrected here to ≈$679.8k).

Files: `analysis/` (state-latest.json, src/ verified sources, events/, per-user SP/Airdrop/DCHF
holder JSONs, scripts), `poc/` (Foundry project), `ci/run.sh`, `ci-out/state.json`, `ci-log.txt`,
`ci-artifacts/`, `summary.json`.

Caveats: USD values move with ETH/WBTC/CHF; the DCHF ETH-only; MON is illiquid (~$0.0002, priced
from the MON/WETH V3 pool) — MON-denominated figures are indicative. All amounts are on-chain
reads at the stated block; the fork tests assert invariants, exact numbers reproduce at that block.
