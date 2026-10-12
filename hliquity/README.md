# HLiquity (Hedera) — L2 Phase-2 deep dive: what can an external unprivileged attacker extract today?

**Date:** 2026-10-12 · **Chain:** Hedera mainnet (chain id 295) · **Status:** read-only; all checks are
`eth_call` simulations on live state (no transactions signed or sent); CI-run evidence below.

**Finding:** triage row `hliquity` — LIVE-FUNDED, $209,097 (2.28M HBAR in the ActivePool, Liquity-style CDP).
**Headline result:** **E-U (external unprivileged extractable) = $0.00 — confidence: high.**

---

## 1. TL;DR

| Target | Live value | E-U today | Why closed | Latent risk |
|---|---|---|---|---|
| ActivePool collateral (11 troves) | 2,279,844.90 HBAR = **$209,376.87** | **$0** | No trove is liquidatable (min ICR **313.1%** vs MCR 110%); borrowing/redemption at the live oracle price is value-negative (−154 bps); oracle-manipulation path patched | If the Supra feed (the only live oracle) is manipulated again — as it was on 2026-07-11 — this entire balance plus the StabilityPool is at risk |
| StabilityPool (unclaimed liquidation gains) | 227,976.35 HBAR = **$20,936.94** | **$0** | Gains are snapshot-allocated to existing depositors only (standard audited Liquity SP); no permissionless drain path | Same oracle risk: a manipulated crash would let a depositor capture the system's collateral surplus |
| HLQTStaking (unclaimed redemption fees) | 18,417.35 HBAR = **$1,691.42** | **$0** | `increaseF_ETH` accrues only to staked HLQT snapshots; new stakers earn nothing retroactively | none material |
| CollSurplusPool (surplus from closed troves) | 63,613.16 HBAR = **$5,842.12** | **$0** | Claimable only by the respective trove owners (`claimCollateral`) | none material |
| SaucerSwapPool (staked LP + HLQT rewards) | 17,663.99 LP = $13,335.63 + 19,549 HLQT = $28.66 | **$0** | `withdraw`/`getReward` only for the stakers themselves | none material |
| HCHF mint/burn, admin/init paths | — | **$0** | All guards live (proofs below); every contract owner renounced to `0x0` | none material |

**Total live extractable by an external unprivileged attacker now: $0.00 (high confidence).**
Holder-recoverable (H-O) gross value sitting in protocol custody: **$251,211.64** at block 101,036,347
(trove collateral $209,376.87 before repaying $57,674.42 of HCHF debt → $151,702.45 net borrower equity;
SP gains $20,936.94; CSP $5,842.12; staking rewards $1,691.42; LP stakers' LP $13,335.63; unclaimed HLQT
rewards $28.66). At the CI re-run block 101,036,523 (HBAR $0.09208, HCHF $1.20973) the same H-O total is
**$251,846.98**. P = $0, S = $0.

---

## 2. The one finding that matters: the oracle stack and its July-2026 near-miss

HLiquity is an immutable, governance-free Liquity V1 fork (deployed 2024-06-03; contract version
`30f7253f635f6015267b0fcdb5554d259b76e5db`, docs: docs.hliquity.org/fundamentals/token-ids-pools-contracts).
Its PriceFeed uses **Pyth as primary and Supra as fallback**, each adapter computing HBAR/CHF as
`HBAR/USD × USD/CHF` (deployed source: `PriceFeed.sol`, `PythCaller.sol`, `SupraCaller.sol` at the commit above).

Live reality at block **101,036,347**:

* Pyth feeds on Hedera are **frozen** — HBAR/USD last published 2025-10-22, USD/CHF 2025-03-18
  (adapter returns HBAR/CHF = 0.15032809, age **49,502,931 s ≈ 1.57 years**).
* Supra feeds are **fresh** (pair 75 HBAR/USD × pair 5012 USD/CHF, updated hourly; last update 2,282 s old).
* PriceFeed `status()` = **3 = `usingSupraPythFrozen`**; `fetchPrice()` returns the live Supra value
  (**0.07655201 HCHF/HBAR**), not Pyth's stale value.

Consequence: in state `usingSupraPythFrozen` the feed returns Supra's price with **no deviation sanity check**
(`_pythPriceChangeAboveMax` is only applied in the `pythWorking` state). Supra is therefore the protocol's
**single point of price truth**, and it is exactly the oracle whose on-chain verifier was exploited six hours
before it was patched:

* **2026-07-11 00:51 UTC** — attacker submitted a Supra price update with a **zeroed BLS signature `[0,0]`**
  (committee id 2). Supra's verifier built a pairing check from the zero signature and zero public key; the
  Hedera pairing precompile (0.0.8) correctly returned true for the identity, and the verifier accepted it.
  A SAUCE price inflated by 12 orders of magnitude was written into the **S-Value storage contract
  `0xd02cc7a670047b6b012556a88e275c685d25e0c9` (0.0.4322850)**; Bonzo Lend lost **$9.05M** reading that feed
  (Bonzo incident report; tx `0xd50c55e24eb8483ec55bf74e84fc9853d0f0fe36f64abdb812a2d9afa2a10a60`).
* **2026-07-11 07:08 UTC** — Supra upgraded the verifier proxy `0.0.4323006` to a fixed implementation
  (`upgradeTo(0x02ebd8829b944c48e6bff15fdec04f7d51b70526)` = 0.0.10633768, created that minute).

**HLiquity reads the very same S-Value storage contract** (`SupraCaller` → `getSvalue(75/5012)` on
0.0.4322850 = `0xd02cc7a6…`). During the 6-hour window the protocol's price was attacker-writable — a live
$209K+ exploit that nobody took. Today the vector is closed, proven by an A/B replay of the exact exploit
calldata (see §4).

---

## 3. Live-state assessment (block 101,036,347, 2026-10-12 ~14:55 UTC)

**Contract map (all verified by `eth_getCode` + getters; Hedera IDs in parentheses):**

| Role | EVM address | Hedera ID | Owner | Notes |
|---|---|---|---|---|
| TroveManager | 0x…5c9f66 | 0.0.6070118 | `0x0` (renounced) | 11 active troves |
| BorrowerOperations | 0x…5c9F4e | 0.0.6070094 | `0x0` | `openTrove/closeTrove/adjustTrove` |
| StabilityPool | 0x…5c9F5c | 0.0.6070108 | `0x0` | 24,455.90 HCHF deposits |
| ActivePool | 0x…5c9f0b | 0.0.6070027 | `0x0` | holds trove collateral |
| DefaultPool / CollSurplusPool / GasPool | 0x…5c9F19 / 0x…5c9f0e / 0x…5c9f1f | 0.0.6070041 / 0.0.6070030 / 0.0.6070047 | `0x0` | DP empty; CSP 63,613.16 HBAR; GasPool 0 HCHF |
| SortedTroves / PriceFeed | 0x…5c9F49 / 0x…5c9F42 | 0.0.6070089 / 0.0.6070082 | `0x0` | PriceFeed status = 3 |
| CommunityIssuance | 0x…5c9f14 | 0.0.6070036 | `0x0` | 8,240,909.36 HLQT emission reserve; `issueHLQT` = SP-only |
| HLQTStaking | 0x…5c9f30 | 0.0.6070064 | `0x0` | 18,878,232.83 HLQT staked |
| LockupContractFactory / SaucerSwapPool | 0x…5c9f29 / 0x…5c9f75 | 0.0.6070057 / 0.0.6070133 | `0x0` | LP staking (17,663.99 LP) |
| HCHF controller + HTS token | 0x…5c9f6a / 0x…5c9f70? (HTS 0.0.6070123) | 0.0.6070122 | — | supply 47,788.035 HCHF; mint/burn guarded |
| HLQT controller + HTS token | 0x…5c9f6f / HTS 0x…5c9f70 | 0.0.6070127 / 0.0.6070128 | `0x0` | supply 100M; mint/burn guarded |
| PythCaller / SupraCaller | 0x…5c9f80 / 0x…5c9f83 | 0.0.6070144 / 0.0.6070147 | — | immutable adapters |
| Pyth / Supra S-Value storage / Supra verifier / Supra pull | 0.0.4622850 / 0xd02cc7a6… / 0x2fa6dbfe… / 0x41ab2059… | 0.0.4622850 / 0.0.4322850 / 0.0.4323006 / 0.0.4323024 | Supra admin | verifier fixed 2026-07-11 |

**Troves (all `status=1`, all above MCR 110%; system TCR 365.21%, recovery mode off):**

| # | owner | debt (HCHF) | coll (HBAR) | ICR |
|---|---|---|---|---|
| 6 | 0xe09D3c…6611 | 1,800.00 | 73,624.25 | **313.1%** |
| 1 | 0x…216440 | 11,569.40 | 479,945.87 | 317.6% |
| 10 | 0x…1347b9 | 6,816.79 | 283,799.89 | 318.7% |
| 3 | 0x…798850 | 6,225.03 | 268,800.00 | 330.6% |
| 4 | 0x…3f7039 | 3,866.08 | 170,000.00 | 336.6% |
| 8 | 0x…0d403c | 4,520.00 | 202,528.57 | 343.0% |
| 0 | 0x56bda9…22d0 | 2,651.94 | 119,591.38 | 345.2% |
| 2 | 0x…5e8392 | 4,895.44 | 250,219.57 | 391.3% |
| 7 | 0x…41d9C7 | 1,800.00 | 100,352.40 | 426.8% |
| 5 | 0x…520E51 | 1,843.36 | 112,000.00 | 465.1% |
| 9 | 0x…0063cb | 1,800.00 | 218,982.97 | 931.3% |

Totals: collateral 2,279,844.90 HBAR; debt 47,788.04 HCHF; MCR 110%, CCR 150%; redemption fee
0.948% (`baseRate` 0.448% + 0.5% floor).

**Market context:** HCHF $1.20688 (SaucerSwap) / $1.20996 (DefiLlama); HBAR $0.09183821; HCHF liquidity
≈ $26.2K (V1 HBAR-HCHF $13.3K + V2 USDC-HCHF $12.9K); HLQT $0.001466 (V2 HBAR-HLQT pool $19.1K).

---

## 4. What an attacker can / cannot do — exact paths

**Closed paths (each proven by a live `eth_call` simulation; see §5 and CI artifacts):**

1. **Oracle manipulation via the Bonzo zero-signature vector** — replay of the exact exploit calldata
   (`0x03a02dfd…`, tx `0xd50c55e2…`) against the Supra pull contract:
   * at latest state → **revert `DataNotVerified()` (0x40ef6502)**;
   * at pre-fix block `0x5cfcda5` → **success** (control).
   Cost/limit: none needed; impact if open would be total ($209K+).
2. **Direct write to the S-Value storage** — `restrictedSetSupraStorage(uint256,bytes32)` (0xbed9d186)
   from an external account → **revert `UnauthorisedAccess()` (0x1a1a6da9)**.
3. **Minting HCHF** — `mint` → revert `HCHFToken: Caller is not BorrowerOperations`;
   `burn` → revert `HCHF: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool`.
4. **Minting HLQT** — HLQT controller `mint`/`burn` revert for external callers; `communityIssuanceAddress()` = CommunityIssuance.
5. **Admin/init takeovers** — `setAddresses` on PriceFeed/TroveManager/BorrowerOperations/StabilityPool all
   revert; every protocol owner is `0x0` (renounced at deployment). No proxy on the core contracts (immutable).
6. **Liquidation profit** — `liquidate(0xe09D3c…6611)` (lowest ICR) → revert `TroveManager: nothing to liquidate`.
   The lowest ICR is 313.1%; HBAR/CHF would have to fall ~65% to reach 110%.
7. **Redemption arbitrage** — redeeming is live (simulation closes trove 6: 1,780 HCHF → 23,031.69 HBAR net
   after the 0.948% fee = 12.9392 HBAR/HCHF). At HBAR $0.09184 that is **$1.1883 per HCHF vs a market cost of
   $1.2069 → −153.9 bps**. Negative; no arbitrage. (Fee revenue goes to stakers, not the attacker.)
8. **Borrow-and-dump** — borrowing 1 HCHF requires ≥1.1/0.07655 = 14.37 HBAR of collateral; selling the HCHF
   yields 1.20688/0.09184 = 13.14 HBAR. Negative.

**Open-but-not-attacker-profitable paths:** SP withdrawals with accrued HBAR gains, CSP `claimCollateral`,
staking `unstake`/reward claims, SaucerSwapPool `withdraw` — all H-O for the respective users (snapshot logic,
audited Liquity code, deployed from the same commit).

**Residual/latent risk (not E-U today):** the protocol now runs on **one live oracle with no deviation bound**.
If Supra's feed is manipulated again (new verifier flaw) or its publisher stalls, the feed either takes an
arbitrary price (full $209K+ extraction, as Bonzo showed) or freezes at `lastGoodPrice` (operational halt,
no extraction). Pyth cannot currently serve as a working fallback (its Hedera feeds are >1.5 years stale);
it can only ever come back as primary if both feeds become live and within 5% again.

---

## 5. Verification (CI-run, read-only)

* **`poc/verify.py`** — 18 hard checks against live mainnet state via raw `eth_call` simulations
  (state-changing calls simulated, never sent). **18/18 PASS** locally and on CI.
* **`poc/exploit_tx_input.hex`** — exact historical exploit calldata (public, from the Bonzo incident tx).
* **Tooling note:** anvil 1.8.5 and `forge test` `vm.createSelectFork` **cannot fork Hedera mainnet** through
  public relays (`mainnet.hashio.io`, `295.rpc.thirdweb.com`) — their fork genesis sends EIP-1898 block
  objects that Hedera's relay rejects (`Invalid parameter 1 … [object Object]`). Raw `eth_call` with an
  explicit block parameter works and is equivalent for every check above (each is a single transaction
  simulation; the only fork-only capability — persistence across steps — is moot because both price-write
  paths are proven closed). Details in `poc/README.md`.
* **CI:** `ci/run.sh` (executed by the `poc.yml` workflow) runs the battery and uploads `ci-out/`.
  Run URL(s): **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38259984555** (conclusion: success;
  18/18 checks at block 101,036,523) — workflow: kingmariano/ca-zombie-ci, branch `hliquity`.
* Key CI artifacts: `ci-out/state.json` (full census), `ci-out/verification.json` (checks + market + redemption accounting).

---

## 6. Methodology & sources

* Deployed source: `github.com/SwisscoastAG/HLiquity` @ `30f7253f635f6015267b0fcdb5554d259b76e5db`
  (the exact "Contract Version" pinned in the official docs); Omniscia audit referenced from docs.
* Live reads: Hedera JSON-RPC relay (`mainnet.hashio.io`, `295.rpc.thirdweb.com`) + mirror node
  (`mainnet-public.mirrornode.hedera.com`) — contract bytecode, call results, internal contract actions,
  token balances. Block pinned per read.
* Incident facts: Bonzo Lend incident report (bonzo.finance, 2026-07-11) with on-chain references;
  Defiant/CoinDesk coverage. The exploit tx was replayed read-only.
* Market data: SaucerSwap public API + DefiLlama coins API.

## 7. Caveats & limitations

* Point-in-time: all numbers at block 101,036,347 (2026-10-12 ~14:55 UTC); the oracle price moves hourly.
* USD values use SaucerSwap spot (HBAR $0.09183821, HCHF $1.20688) unless stated; DefiLlama HCHF $1.20996.
* The A/B replay proves the *specific* zero-signature vector is rejected; it is not a full audit of Supra's
  fixed verifier implementation (we did not decompile it exhaustively). Other unknown Supra bugs cannot be
  excluded — that is the main latent risk.
* SP/CSP/staking H-O amounts assume the standard Liquity snapshot/claim semantics of the deployed commit
  (source-verified, not fuzzed).
* No transactions were signed or sent; no secrets are used or stored.

## 8. Files index

```
hliquity/
├── README.md                  (this file)
├── summary.json               machine-readable summary
├── analysis/                  raw state dumps, scripts (scan1.py, rpc.py, selectors, holder lists)
├── poc/verify.py              CI verification battery (18 checks)
├── poc/exploit_tx_input.hex   exact historical Supra exploit calldata (public)
├── poc/README.md              method + fork-tooling limitation
├── ci/run.sh                  CI entry point
├── ci-out/                    CI results (state.json, verification.json)
├── ci-log.txt / ci-artifacts/ downloaded after each CI run
```
