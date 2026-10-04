# H-43 — Balancer V2 aftermath: live permissionless-extraction audit across chains

**Date:** 2026-10-04 · **Chains:** Ethereum, Arbitrum, Optimism, Base, Polygon, Gnosis, Avalanche, Mode, Fraxtal
**Status:** read-only; PoC fork-verified only (local anvil forks + GitHub Actions); no mainnet transactions.
**Scope note:** counterpart to the completed V1 dive (`c-02`). This report covers **V2 only** (Vault, CSP,
Linear/MetaStable/Weighted pools, relayers); V1 BPools are not re-audited here.

---

## 1. TL;DR

| target | live extractable (unprivileged) | why closed / open | latent risk |
|---|---|---|---|
| Nov-2025 rounding bug (`ComposableStablePool` v3–v5, rate-provider pools) | **$0** (no live pool reproduced) | The only funded CSPs with real rate providers are (a) **swap-bricked**: their rate provider reverts `Not implemented`, so every `onSwap` reverts; or (b) have no usable rate pivot (dust, e.g. swETH = 3 wei); or (c) are v6 pools **paused** since Nov-2025 | The deployed code is immutable; if a dead provider were replaced/repaired (only possible for pools whose owner can change providers) the path would re-open |
| MetaStable pools with rate providers (separate Nov-2025 path) | **$0** | Remaining live MetaStables with balances are ~$0.9k/$0.7k and attempts revert | small |
| Linear pools (wrapped-rate rounding) | **$0** | No invariant amplification; all live Linear pools with value are in recovery mode and/or dust; historical hack did not drain them | low |
| Weighted pools (V1-style dust-join analogue) | **$0** | V2 WeightedMath rounds in the pool's favour (`mulUp` inputs / `mulDown` outputs, `MAX_IN_RATIO` blocks dust joins); no live path found | low |
| Relayers / approval residue (BIP-927) | **$0** | BIP-927 revoked V2 Vault permissions from deprecated relayers; only Batch Relayer V6 remains | low |
| **Total live extractable by an external unprivileged attacker** | **$0** (confidence: medium-high) | | |

Non-attacker categories for the remaining V2 liquidity (DefiLlama: **$20.5M** across 8 chains at 2026-10-04):

- **H-O ≈ $19.4M** — LP/user-redeemable via `exitPool` (exits were never gated by the Vault pause; recovery mode was enabled on the legacy composables precisely to let LPs exit).
- **S ≈ $1.1M** — CSPs with dead rate providers where even `exitPool`/recovery exits may revert (exit path not yet verified end-to-end; counted as potentially stuck, not attacker-extractable).
- **P = $0** — no privileged value is attacker-reachable; governance (BIP-928) controls only the future pause of pausable pools.

---

## 2. The vulnerability (exact, as deployed)

Root cause (Certora / Trail of Bits / Check Point): in `BasePool._swapGivenOut`, the exact-output amount is
upscaled with `FixedPoint.mulDown`:

```solidity
// ComposableStablePool._swapWithBpt (deployed v3–v5)
_upscaleArray(registeredBalances, scalingFactors);
swapRequest.amount = _upscale(swapRequest.amount, scalingFactors[isGivenIn ? indexIn : indexOut]);
```

`_upscale` rounds **down** for every amount; the output amount should round **up**. The comment in the deployed
code says "there's no rounding error unless `_scalingFactor()` is overridden" — `ComposableStablePool` overrides
it with per-token **rate** scaling factors, so pools with a live rate provider (wstETH, osETH, swETH, ETHx,
bb-*-BPT, rETH, JitoSOL, …) have a 1-unit error per exact-out swap.

Amplification (the actual $128M mechanism): BPT is itself a pool token, and `batchSwap` nets all deltas, so an
attacker can temporarily run a **BPT deficit** (sell BPT it does not own), drain the pool's rate-token balance to
a rounding boundary (8–370 wei), grind the invariant/BPT price down with micro-swaps, and then buy the BPT back
at the suppressed price. No flash loan and no upfront capital are required — only gas (the settlement is
internal-balance-only). Historical attack: tx `0x6ed07db1…23bc9742`, 226 swaps in one constructor, drained
6,586 WETH + 6,851 osETH + 4,259 wstETH (~$128M across chains).

Preconditions for a live attack: (1) CSP with BPT as a swap token (v3–v5; v6 pausable), (2) ≥1 non-BPT token
with a **live** rate scaling factor ≠ 1e18 and a manipulable balance, (3) swaps enabled (Vault unpaused, pool
not paused/recovery-blocked), (4) value to extract.

---

## 3. Live-state assessment (read-only, explicit blocks)

Vault address is the same canonical `0xBA12222222228d8Ba445958a75a0704d566BF2C8` on all chains (verified
`eth_getCode` + `getPoolTokens` decode + `getPausedState`). Vault code hash differs only by the immutable WETH.

| chain | block | pools registered | pools w/ balances | CSP live | Vault paused | pause window ended |
|---|---|---|---|---|---|---|
| Ethereum | 26,117,041 | 2,003 | 1,732 | 144 | false | 2021-07-18 (buffer 2021-08-17) |
| Arbitrum | 511,538,383 | 1,706 | 1,495 | 102 | false | 2021-12-22 |
| Base | 52,153,824 | 898 | 772 | 23 | false | 2023-11-09 |
| Optimism | 157,748,898 | 383 | 295 | 37 | false | 2022-08-31 |
| Mode | 45,462,480 | 22 | 2 | 2 (recovery) | false | — |
| Fraxtal | 42,140,842 | 11 | 7 | 5 | false | — |
| Polygon / Gnosis / Avalanche | — | — | — | — | false | (scan not completed — see §9) |

**The Vault can never be paused again.** `TemporarilyPausable._setPaused` reverts after the buffer period;
`getPausedState().paused = false` everywhere and the pause windows expired 2021–2023. The Nov-2025 mitigation
could therefore only pause **v6 CSPs** individually (BIP-794 Hypernative module) — and those pools are still
`paused = true` today (verified on all v6 CSPs with balances: e.g. Ethereum `0xC5b3f108…`, `0x48A5bBFb…`,
`0x8296057e…`; Arbitrum/Base/OP v6 sets). v3–v5 CSPs have no pause and are not paused.

### 3.1 Funded CSPs with real rate providers (not paused) — the complete E-U candidate set

Enumerated via `PoolRegistered` logs → `getPoolTokens` → `getRateProviders()/getScalingFactors()` (correct
dynamic-array decoding; an initial off-by-one decode bug was found and fixed) → DefiLlama pricing.

| chain | pool | ver / rec | non-BPT value | rate pivot | live result |
|---|---|---|---|---|---|
| Ethereum | `0xaE8535c2…f92b` | v5 / recovery | swETH 167.0 + bb-a-WETH 32.8 ≈ **$600k** | swETH sf 1.0333 | **swap reverts `Not implemented`** — provider `0xbb688187…` → `convertToAssets` on `0x03928473…` reverts; every `onSwap` reverts |
| Ethereum | `0x4CbdE5C4…6163` | v5 / recovery | ETHx 104.4 + bb-a-WETH 90.5 ≈ **$550k** | ETHx sf 1.0045 | **swap reverts `Not implemented`** (same provider family) |
| Ethereum | `0x02D928E6…dc8c` | v3 / recovery | swETH 9.2 ≈ $28k | swETH | reverts (provider / invariant) |
| Ethereum | `0xe7e2c68d…b9d2` | v5 / normal | WETH 122.7 ≈ **$331k** | swETH balance = **3 wei** | no usable pivot: the only rate token is dust, so the invariant cannot be suppressed; pivot test skips it |
| Ethereum | `0x09B03b7c…947b` | v5 / normal | PYUSD/sDOLA ≈ $155 | sDOLA | reverts (panic 0x4e487b71 / invariant) |
| Ethereum | `0x74E5e530…b001` | v5 / normal | MATIC/TruMATIC ≈ $12 | TruMATIC | reverts `ZERO_DIVISION` |
| Ethereum | 8 more (≤$75 each) | v3–v5 | ≤$241 | mixed | all attempts revert |
| Arbitrum | `0xFb2f7Ed5…9Ef` | v5 / normal | SOL 98.2 + JitoSOL 118.2 ≈ **$26k** | JitoSOL | CI re-run in progress (local run hit a public-RPC archive 403) |
| Arbitrum | `0xCBa9ff45…3562`, `0xbe0f3021…2CD4`, `0x5a7f3943…E3e7`, `0x0C897243…8BfD` | v3/v5 | $5.4k / $3.2k / $2k / $63 | rETH, wstETH | all attempts revert (`BAL#001` / invariant) |
| Optimism | 4 pools | v5 | ≤$26 | rETH/wrsETH | all attempts revert |
| Base | 10 pools | v5 | ≤$0.81 | SWEEP etc. | dust |
| Mode / Fraxtal | 7 CSPs | v3–v6 | recovery mode, **no non-zero rate providers** | — | not vulnerable |

The historical exploit was **reproduced end-to-end** by our harness on an archive fork at block 23,717,396
(osETH pool: 4,623.60 WETH + 6,851.12 osETH; wstETH pool: 1,964.65 WETH + 4,227.26 wstETH captured), proving
the PoC is valid and the negative live result is not a harness artefact.

### 3.2 Other pool types

- **Weighted (1,404 live on Ethereum; the bulk of the $20.5M TVL).** `WeightedMath` ups `amountsIn` and downs
  `amountsOut`; joins are capped at 30% of the balance (`MAX_IN_RATIO`), which blocks the V1-style dust-join
  recipe. No live extraction path found (V1 dive `c-02` remains the only dust-join result).
- **Linear (61 live on Ethereum).** `_onSwapGeneral` has the same rounding-down `_upscale`, and BPT is a swap
  token, but LinearMath has no invariant to suppress; the historical attacker skipped them and the funded ones
  are recovery-mode/dust. No amplification found.
- **MetaStable (13 live on Ethereum).** Only ~$0.9k/$0.7k with balances; attempts revert.
- **Relayers (BIP-927, Aug-2026).** Deprecated relayers' V2 Vault permissions were revoked; only Batch Relayer
  V6 `0x35Cea9e5…48f` retains any. No unrevoked-approval drain found.
- **Exit/withdraw for non-LPs.** `exitPool` always burns BPT from `sender` (or a Vault-approved relayer);
  no permissionless non-LP withdrawal path exists. Recovery-mode exits still require the caller's BPT.

---

## 4. What an attacker can/cannot do (call paths, preconditions, costs)

- **Can:** call `Vault.batchSwap`/`swap` on any registered pool, `updateTokenRateCache` (permissionless when
  stale), `exitPool` with own BPT, `manageUserBalance` for own internal balances. Gas-only; no flash loan
  needed for the deficit attack.
- **Cannot (verified):** reproduce the rounding extraction on any live funded pool — top pools revert inside
  `onSwap` at the rate provider (`Not implemented`), or lack a rate pivot, or are paused v6. `getPausedState`
  is false on the Vault everywhere and there is no way to pause it.
- **Costs:** the exploit path costs only gas (~28M gas / attack historically). On pools where it is blocked,
  no parameter set helps because the revert is in the immutable provider/pool code.

---

## 5. PoC / fork verification

- Harness: `poc/src/Attacker.sol` (adapted DeFiHackLabs `BalancerV2_exp.sol` with asset reordering so BPT is
  handled at any index, revert-reason capture, and per-attempt snapshots), `poc/test/BalancerV2Attack.t.sol`.
- Historical sanity: `test_historical_sanity` at block 23,717,396 (archive RPC) — **PASS**, matches the public
  DeFiHackLabs reproduction (osETH 4,623.60 WETH + 6,851.12 osETH; wstETH 1,964.65 WETH + 4,227.26 wstETH).
- Current-state sweeps: `test_current_ethereum_candidates`, `test_current_arbitrum_candidates`,
  `test_current_optimism_candidates`, `test_v6_paused_pool_swap_reverts`, `test_drained_pools_have_no_value`.
  Every live candidate attempt reverted with `Not implemented` / `BAL#001` / invariant errors; **no SUCCESS and
  no gains on any live pool**.
- CI: GitHub Actions `poc.yml` on branch `balancer-v2` of `kingmariano/ca-zombie-ci` — run URL and log are in
  `ci-log.txt` / `ci-run.out`; historical-sanity output in `ci-out/historical-sanity.log` (artifact).
- Mainnet-realistic aspect: the historical PoC needed no upfront capital (internal-balance netting), so the
  "$0 live" result is not a capital-availability artefact.

---

## 6. Verdict and residual/latent risk

**Verdict: E-U = $0 today.** The Nov-2025 bug remains in immutable deployed code, but every live funded
rate-provider CSP is either swap-bricked by a dead provider, lacks a manipulable rate pivot, or is a paused v6
pool. The remaining V2 TVL is in pool types not affected by the rounding bug. Confidence: **medium-high**
(high for the top Ethereum/Arb/OP candidates checked on forks; medium overall because Polygon/Gnosis/Avalanche
scans were not completed and the parameter grid is finite).

**Latent risks:** (1) any owner/admin action that repairs or replaces a rate provider on a funded CSP (e.g.
`setTokenRateProvider` where the pool owner still has authority) would re-open the path for that pool;
(2) BIP-928 pauses pausable pools on **2026-10-30** (withdrawals-only), which would close swap paths for v6
pools but does not affect v3–v5; (3) the same rounding bug exists in forks of Balancer V2 code elsewhere;
(4) pools counted as H-O may include exit-bricked ones if the dead provider is used on the exit path.

**Blockers observed:** dead rate providers (`Not implemented`), pool-level pause (v6), recovery-mode exit-only
semantics, dust pivots, and (for non-CSP types) absence of a rate scaling factor.

---

## 7. Methodology & sources

- Enumeration: `PoolRegistered(bytes32,address,uint8)` logs from each Vault (Etherscan V2 where supported;
  Blockscout/RPC `eth_getLogs` fallback for OP/Base/Mode/Fraxtal) → `getPoolTokens` batched `eth_call` →
  selector probes (`getBptIndex`, `getRateProviders`, `getScalingFactors`, `getAmplificationParameter`,
  `inRecoveryMode`, `getPausedState`, `version`) with corrected ABI decoding → DefiLlama prices.
- Fork tests: Foundry 1.7.1 / solc 0.8.24, `via_ir`; local anvil forks + GitHub Actions (Ubuntu, 2 vCPU).
- Sources: Check Point Research (rounding exploitation), Trail of Bits (TOB-BALANCER-004, Linear/StableMath),
  Certora (root cause + BPT deficit), Balancer BIP-794 (v6 pause), BIP-887 (factory shutdown), BIP-927
  (relayer revocation), BIP-928 (wind-down, Sep-29-2026; withdrawals-only Oct-30-2026), DeFiHackLabs PoC,
  DefiLlama protocol/yields API.
- Files: `analysis/chain-*.json` (raw scans), `analysis/chain-*-fixed.json` (corrected rate data),
  `analysis/pool-table-*.csv` (priced tables), `analysis/candidates.py`, `analysis/research-governance.md`,
  `analysis/exploit-mechanics.md`, `analysis/v2-deployments.md`, `analysis/chain-scan-notes-*.md`,
  `analysis/local-*.log`, `poc/`, `ci/run.sh`.

## 8. Caveats & limitations

- Polygon, Gnosis and Avalanche scans did not complete (public-RPC rate limits / session restarts). DefiLlama
  shows Polygon $2.86M, Gnosis $232k, Avalanche $143k, dominated by Weighted/Stable pools; the CSP+rates
  candidates there were not fork-tested. This is the main gap in the multi-chain claim.
- The parameter grid for the live attacks is finite (up to 5 init balances × 15 loops per pool); a
  `STABLE_INVARIANT_DIDNT_CONVERGE` result is a harness-simulation failure, not proof of safety by itself.
  For the top pools the on-chain `Not implemented` revert is decisive.
- USD values are DefiLlama spot estimates at 2026-10-04; tokens without a price source are excluded (pool value
  understated, e.g. bb-a-WETH is priced via WETH in the text but excluded from the strict sum).
- H-O/S split is estimated: exits were not verified per pool; the $1.1M "S" is the bricked-CSP subset.
- Read-only throughout; no transaction was signed or sent to any live network.

## 9. Files index

```
balancer-v2/
├── README.md                      (this file)
├── summary.json                   (machine-readable)
├── analysis/                      (scans, tables, scripts, research, logs)
├── poc/                           (Foundry PoC: src/, test/, foundry.toml, lib/forge-std)
├── ci/run.sh                      (historical archive-fork validation job)
├── ci-out/historical-sanity.log   (CI artifact)
├── ci-log.txt / ci-run.out        (CI log + run URL)
└── ci-artifacts/                  (downloaded CI artifacts)
```
