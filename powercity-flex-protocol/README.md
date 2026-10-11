# Powercity Flex Protocol (PulseChain) — L2 Phase-2 deep dive

**Date:** 2026-10-11 · **Chain:** PulseChain (369) · **Status:** read-only; PoC fork-verified only;
no mainnet transactions. All state re-verified on-chain at blocks 27,769,393 / 27,771,631 / 27,771,670.

**Target:** FLEX Protocol — a Liquity v1 fork (HEX collateral, HEXDC stable, FLEX token) from the
Powercity ecosystem. Triage (L2 watchlist B, rank 2) reported $730,044 live custody value.

---

## 1. TL;DR

| # | surface | live extractable (unprivileged) | why closed/open | latent risk |
|---|---|---|---|---|
| 1 | TroveManager / ActivePool (265.92 M HEX ≈ $660 k at market) | **$0** | No trove below 110 % (min ICR 138.2 %); no permissionless path to the collateral | **Oracle manipulation**: permissionless `fetchPrice` + 420 s TWAP window; fork-proven capture if a −87…−92 % crash is sustained for 421 s (economics implausible — §6) |
| 2 | Redemptions (HEXDC → HEX) | **$0** | Oracle lags market by ~2.9 % but HEXDC trades at $1.038 > the $1.0308 oracle payout → negative per cycle | Same crash gate; fork-proven 6.11× payout at a −87 % oracle |
| 3 | StabilityPool (7,719.33 HEXDC ≈ $8.0 k) | **$0** | Depositor-only withdrawals; standard Liquity accounting | — (H-O) |
| 4 | LQTYStaking (80.18 M FLEX ≈ $62.0 k + $3.4 k fees) | **$0** | stake/unstake are self-only; fee functions caller-gated | — (H-O) |
| 5 | Farms (LP ≈ $23.6 k), CollSurplusPool (≈ $2.1 k) | **$0** | Standard Synthetix staking; surplus claimable by borrowers | — (H-O) |
| 6 | Admin / init paths | **$0** | `setAddresses` is onlyOwner + `_renounceOwnership()`; owner()=0; LUSDToken minters immutable | P: PriceFeed admin EOA + timelock `updatePriceFeed` |

**Total live extractable now (E-U): $0.00 — confidence: high.**
The system is solvent (1282 % TCR), all privileged paths are closed or renounced, and the only
open-looking surface (the unverified oracle) is fork-proven to require an economically
implausible 7-minute market takeover.

---

## 2. What the protocol is / live state

FLEX is a Liquity v1 fork on PulseChain: HEX (8 dec) collateral, HEXDC (8 dec) stable, FLEX token.
Docs: docs.powercity.io/flex-protocol. Triage value re-verified: **265,923,978.026 HEX** in the
ActivePool (≈ **$660 k** at the 2026-10-11 market price $0.0024815; triage's $645.7 k used
$0.002428), 21 troves, **49,959.03 HEXDC** total debt, **7,719.33 HEXDC** in the StabilityPool,
**80.18 M FLEX** staked (≈ $62 k), farms ≈ $23.6 k, CollSurplusPool ≈ $2.1 k. Full tables:
`analysis/live_state.md`, `analysis/trove_table.csv`.

Core addresses: TroveManager `0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE`, BorrowerOperations
`0x5b8575BD870a06a88FD6a2E4C68A66b2F74628Cb`, StabilityPool `0x271F576fD6DE465231320a0F9997ACb0C8b97e07`,
ActivePool `0xE4FD443B26fA809A48EB658eA7edeB31E95c2144`, PriceFeed
`0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C` (unverified), HEXDC
`0x1FE0319440A672526916C232EAEe4808254Bdb00`, HEX `0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39`.

## 3. The unverified oracle — mechanics (from bytecode + traces)

The PriceFeed is **not verified**; mechanics were established by selector extraction, full
disassembly, `debug_traceCall` and storage reads (`analysis/oracle_mechanics.md`):

- `fetchPrice()` is **state-changing and permissionless** (random EOAs poke it on-chain; 21 such
  txs Apr–Aug 2026).
- It computes 4 PulseX-V2 TWAPs — HEX/WPLS V1+V2, WPLS/DAI, WPLS/USDC — as
  `(cumulative_now − cumulative_old)/(t_now − t_old)` with observations rolling only when
  `now − lastUpdate ≥ 420 s`. **The TWAP window is therefore attacker-controllable but ≥ 420 s.**
- Final blend: `HEX_USD = (0.65·HEX/WPLS_V1 + 0.35·HEX/WPLS_V2) · (0.60·WPLS/DAI + 0.40·WPLS/USDC)`.
- Price is stored to slot 4 (lastGoodPrice) and returned; no staleness fallback, no admin needed
  for a refresh. Anchor ratios (2.5 / ~0) and anchorPeriod 3600 are vestigial in this path.

## 4. Live extraction paths — all closed at the current state

1. **Liquidations:** none possible — min trove ICR 138.2 % vs MCR 110 %. No trove even below
   150 % recovery threshold territory (system TCR 1282 %).
2. **Redemption arbitrage:** 1 HEXDC redeems for 415.4 HEX = **$1.0308** at market while HEXDC
   costs **$1.0381** → −0.7 % per cycle. Closed.
3. **Admin/init:** `TroveManager`/`BorrowerOperations` `setAddresses` is `onlyOwner` and ends with
   `_renounceOwnership()` (owner = 0x0) — no re-init. HEXDC minters are constructor-immutable
   (TM/SP/BO). PriceFeed admin = EOA `0x7510…`; `updatePriceFeed` = onlyTimelock (OZ
   TimelockController, no proposer/executor found among observed addresses). Privileged, not E-U.
4. **Fork-specific code:** TroveManager/BorrowerOperations/StabilityPool/LQTYStaking are standard
   Liquity v1 with only collateral-transfer adaptations (`transferFrom` instead of `msg.value`).
   No weakened ICR/TCR guards found in the modified `_adjustTrove`, `offset`, or staking paths.

## 5. Latent path: 420 s oracle takeover — fork-verified mechanics

Because `fetchPrice()` can be rolled by anyone and the TWAP window is as short as ~421 s, an
attacker who rolls the window, crashes the 4 pairs, and holds the crash for 421 s controls the
oracle. The fork PoC reproduces this end-to-end **on real deployed contracts** (no mocks):

- `poc/test/FlexPoC.t.sol :: test_sustained_crash_liquidation_capture`
  crash to 8.25 % of live → oracle returns **19,890** (baseline 240,963) → trove #9 ICR = 105.9 % →
  `liquidate()` → **StabilityPool receives 90,391,079 HEX ($224 k) for burning 17,055.92 HEXDC**;
  attacker (72 % of the SP) claimable gain **65,218,813 HEX ($162 k)** + gas comp.
- `poc/test/FlexPoC.t.sol :: test_sustained_crash_redemption_drain`
  crash to 13.0 % → TCR 166 % (normal mode) → `redeemCollateral(20,000 HEXDC)` → **50,777,608 HEX
  ($126 k)**, **6.11×** the live-price payout of the same HEXDC.

**Why this is not counted as live E-U:** see `analysis/manipulation_economics.md`. The crash
requires dumping **$1.2–1.6 M of HEX** into two pools (~$622 k combined reserves) and holding it
for 421 s while arbitrageurs buy a ~12× discount; the recoverable WPLS is only ~$0.44 M, so the
round-trip is deeply negative unless arbitrage takes < ~20–25 % of the dislocation. Additional
blockers: only ~15.5 k of 49.96 k HEXDC is on-market (thin pool; buying 10 k costs ~$29 k), and the
trove-#9 capture only works in the narrow band `f ∈ (0.0780, 0.0858)` (outside it: ICR ≤ 100 % →
pure redistribution → SP gets $0; or ICR ≥ 110 % → trove #9 sits marginally above system TCR →
"nothing to liquidate" — both fork-verified). Net expected profit: negative/unproven.

## 6. Categories

- **E-U live: $0.00** (high confidence).
- **H-O:** StabilityPool deposits $8.0 k; staked FLEX $62.0 k; staking fee balances $3.4 k; farm LP
  deposits $23.6 k; CollSurplusPool $2.1 k; borrowers' equity in the 265.9 M HEX collateral
  (~$608 k above the $51.9 k of HEXDC debt).
- **P:** PriceFeed admin EOA (`updateAdmin`, admin-only fn) + TimelockController
  (`updatePriceFeed`, `TroveManager`/`BorrowerOperations`); parameters otherwise immutable.
- **S:** none identified. (GasPool 1,050 HEXDC = liquidation reserves, protocol-internal.)

## 7. PoC / fork verification

- Project: `poc/` (Foundry, solc 0.8.24, vendored forge-std). Fork RPC: keyless public
  PulseChain endpoints only (`PULSE_RPC` env override; default publicnode). No secrets, no keys.
- Tests: `test_baseline_live_state` (PASS), `test_sustained_crash_liquidation_capture` (PASS),
  `test_sustained_crash_redemption_drain` (PASS) — **3/3 PASS** (see CI).
- CI: GitHub Actions `kingmariano/ca-zombie-ci` run URL(s) recorded in `summary.json` / below;
  artifacts in `ci-artifacts/`, live-state dump in `ci-out/`.

## 8. Caveats & limitations

- The fork PoC *proves mechanics*, not real-world economics: it warps 421 s to simulate a
  sustained crash. The arbitrage-response gate (§5) is a market judgement, not fork-verifiable.
- PriceFeed is unverified; the disassembly is high-confidence but not source-audited. A hidden
  admin path in it cannot be fully excluded (admin/owner are EOAs; privileged either way).
- USD figures use 2026-10-11 DefiLlama prices (HEX $0.0024815, HEXDC $1.0381, FLEX $0.0007735,
  WPLS $9.5436e-6). Triage's $730 k used slightly different prices; live custody re-verified.
- Farm contracts (LP staking) are unverified; classified H-O from standard Synthetix selectors.

## 9. Files

- `summary.json` — machine-readable verdict
- `analysis/live_state.md` — addresses, balances, roles, block numbers
- `analysis/oracle_mechanics.md` — unverified-oracle disassembly/trace evidence
- `analysis/manipulation_economics.md` — crash-cost vs prize table, the arb gate
- `analysis/trove_table.csv` — all 21 troves: debt, collateral, ICR, crash-to-110 %
- `poc/` — Foundry fork tests (3/3 PASS)
- `ci/run.sh` — live-state dump (keyless RPC) → `ci-out/live-state.json`
- `ci-log.txt`, `ci-artifacts/` — CI evidence
