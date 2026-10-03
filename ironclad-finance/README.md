# H-14 · Ironclad Finance (Mode) — deep dive

**Date:** 2026-10-03 · **Chain:** Mode (chain id 34443) · **Status:** read-only on-chain analysis; PoC fork-verified only; no mainnet transactions signed or sent.

**Headline:** an external, unprivileged attacker can extract **$0** right now. **Confidence: high.** The whole Aave-v2-fork deployment is frozen by `LendingPool.paused == true` (set 2025-03-17, block 21,029,938); every value-moving entry point reverts, aToken transfers are blocked by the paused `finalizeTransfer` hook, and every admin/upgrade path is gated by a 3/6 Safe + Timelock. ~$122.4k of liquidity is stranded (S) and would only become holder-withdrawable (H-O) if governance unpauses.

> **Corpus correction (important):** the address previously reported as the "bricked provider" (`0x5C93B799D31d3d6a7C977f75FDB88d069565A55b`) is actually the **LendingPoolAddressesProviderRegistry**. Its storage slot 0 is its owner (the Timelock), not a pool. The real provider is `0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC` and it answers all reads. The deployment is **not bricked — it is paused**.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed | Latent risk |
|---|---:|---|---|
| LendingPool `0xB702…eEd3` (11 reserves) | **$0** | `paused == true` since 2025-03-17; deposit/withdraw/borrow/repay/swap/rebalance/setCollateral/liquidation/flashLoan/finalizeTransfer all `whenNotPaused` → revert `"64"` | if unpaused: stale oracles + HF<1 positions |
| aTokens (11) | **$0** | user transfers call `pool.finalizeTransfer` (paused); mint/burn/`transferUnderlyingTo` are `onlyLendingPool` (`"29"`) | if unpaused: holders can withdraw ~$122.4k available liquidity |
| Debt tokens (11) | **$0** | `transfer`/`transferFrom` revert `TRANSFER_NOT_SUPPORTED`; mint/burn `onlyLendingPool` | none (debt only) |
| Pool admin/upgrade paths | **$0** | `setPause`/`setConfiguration` → `"27"`; `Configurator.setPoolPause` → `"76"`; proxy `upgradeTo` needs immutable ADMIN = Provider; Provider owner = Timelock; Timelock admin = 3/6 Safe | Safe/Timelock key compromise |
| Treasury `0xd93E…e6EF` | **$0** | `withdrawAllReserves()` is public but routes into the paused `Pool.withdraw` → `"64"`; `transferToMultisig` is `onlyOwner`; its aTokens (~$4.8k) cannot even be transferred while paused | Safe-only (~$4.8k) |
| M-BTC market | **$0** | aToken's backing was **burned by the M-BTC issuer** on 2025-02-07 (30.354 M-BTC); market is insolvent (~$2.14M nominal claims, $139 backing) | dead |
| MODE market | **$0** | unfrozen but pool paused; MODE oracle feed reverts `dAPI name not set` | if unpaused, MODE users are DoS'd (HF queries revert) |

**Total live extractable by an external unprivileged attacker: $0** (high confidence).

Category split (current state, market prices 2026-10-03):

| Category | USD | Notes |
|---|---:|---|
| **E-U** (external unprivileged) | **0** | every value path reverts |
| **H-O** (holder self-service) | **0** | withdrawals blocked by pause; latent ~$122.4k if unpaused |
| **P** (privileged) | **4,842** | Treasury aToken claims (Safe-only, only ~$14 currently backed by available liquidity; rest is a claim on borrowers) |
| **S** (stuck/bricked) | **117,575** | non-treasury share of the frozen available liquidity (total available = $122,417; +$2.14M M-BTC nominal claims whose backing was burned) |

---

## 2. What the protocol actually is

A modified Aave v2 (solc 0.6.12) deployment, "Ironclad Genesis Market", parent Oath Foundation. All core contracts are verified on ModeScan; the Pool implementation bytecode hash `0x203a65f79290043bcbd82d3a1f684a64a2f638c0bc6d445b72f485199604480f` matches the explorer-verified `LendingPool.sol` exactly.

| Role | Address | Notes |
|---|---|---|
| Registry | `0x5C93B799D31d3d6a7C977f75FDB88d069565A55b` | returns exactly one provider |
| Provider | `0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC` | owner = Timelock |
| LendingPool (proxy) | `0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3` | impl `0xDb45611E…fF3D1`; revision 3 |
| PoolConfigurator (proxy) | `0xc534f577c0e6c46B27fdcA6D27D132c543b0D61c` | impl `0x37133a8d…3ee0` |
| Price Oracle | `0xE4F4F36FcBb2D53c0bAB95F5D117489579553CaA` | Api3 aggregator adaptors; owner = Timelock |
| LendingRateOracle | `0x8e82618E67783D6595Cd02CDE94C11a7Ce894d45` | |
| CollateralManager | `0x025D9d36C616946530Ff8eA32d912aBf73170947` | delegatecall-only from Pool |
| PoolAdmin + EmergencyAdmin | `0xD4D995787D39D70F35E694dC8306D7dB863234aC` | **Gnosis Safe v1.3.0, threshold 3/6**, no modules |
| Timelock | `0x96bCFB86F1bFf315c13E00D850e2FAeA93CcD3e7` | Compound-style, delay 86400s, grace 1209600s, admin = Safe, `executeTransaction` admin-only |
| Treasury | `0xd93E25A8B1D645b15f8c736E1419b4819Ff9e6EF` | owner = Safe; holds reserve-factor aTokens |
| UI signer | `0xe027880CEB8114F2e367211dF977899d00e66138` | cosmetic `setSignature` only |

Fork-specific modifications vs upstream: `LENDINGPOOL_REVISION = 3`, a `setSignature`/`getSignature` string (UI signer gated), `setFlashLoanFee` (pool-admin), and `UiSigner` support. No change to the pause logic or access control.

**Pause timeline** (Pool events + tx `0x061701c3dbde88b98d42eb99cd546a65200fbb3594981062d2f09a49a494d11f`):

| Block | Time (UTC) | Event |
|---:|---|---|
| 3,929,832 | early | `Paused()` |
| 3,931,818 | early | `Unpaused()` |
| **21,029,938** | **2025-03-17 16:04:19** | **`Paused()` — Safe `execTransaction` → `Configurator.setPoolPause(true)`; no further pool activity** |

---

## 3. Live state (block 45,438,468)

Pool: `paused = true`; 11 reserves; 10 frozen, only MODE unfrozen; `FLASHLOAN_PREMIUM_TOTAL = 0`; `MAX_NUMBER_RESERVES = 128`.

| Asset | Oracle $ (feed age) | Market $ | aToken supply | Variable debt | Available liquidity | Available $ | Frozen |
|---|---:|---:|---:|---:|---:|---:|---|
| USDC | 0.9997 (96d) | 0.9999 | 378,225.74 | 378,223.14 | 0.498 | $0 | yes |
| USDT | 0.9986 (96d) | 0.9999 | 314,550.32 | 314,553.03 | 0 | $0 | yes |
| WETH | 1,589.14 (95d) | 2,681.72 | 461.4760 | 461.4805 | 0 | $0 | yes |
| ezETH | 1,726.85 (5.3d) | 2,908.45 | 38.7952 | 0.0074 | 38.7878 | $112,812 | yes |
| weETH | 1,745.07 (95d) | 2,961.91 | 0.0514 | 0 | 0.05135 | $152 | yes |
| wrsETH | 1,708.09 (95d) | 2,811.80 | 10.4947 | 10.4953 | 0 | $0 | yes |
| M-BTC | 59,452.29 (95d) | 70,232.99 | 30.4198 | 0.0042 | 0.00198 | $139 | yes |
| weETH.mode | 1,745.07 (95d) | 2,961.91 | 22.2478 | 22.2562 | 0 | $0 | yes |
| MODE | **reverts** | 0.0000874 | 23,784,833.68 | 13,061,085.63 | 10,725,098.60 | $937 | **no** |
| sUSDe | 1.2361 (95d) | 1.2507 | 10,055.36 | 10,055.50 | 0 | $0 | yes |
| uniBTC | 59,452.29 (95d) | 84,407.43 | 0.0992 | 0.0000434 | 0.09923 | $8,375 | yes |
| **Totals** | | | **$4,298,149** | **$2,039,741** | | **$122,417** | |

- Available liquidity = underlying held by the aToken contracts (Aave v2 keeps liquidity in aTokens; the Pool itself holds 0).
- The two big numbers diverge because almost all supply is borrowed out; the only meaningful free liquidity is ezETH (38.79) and uniBTC (0.0992).
- The pool's own oracle (Api3 adaptors) is **stale**: WETH feed last updated ~95 days ago at $1,589.14 vs $2,681.72 market; USDC ~96 days; uniBTC/M-BTC ~95 days; ezETH ~5.3 days; **MODE feed reverts `dAPI name not set`** (decommissioned).
- Treasury (reserve factor) aTokens at market: USDC $1,168.15 + USDT $916.84 + WETH $2,688.84 + sUSDe $32.59 + MODE $1.32 + wrsETH $9.21 + weETH.mode $12.84 + uniBTC $12.47 ≈ **$4,842**.

### 3.1 The M-BTC hole (found during this audit)

- On **2025-02-07 13:41:21 UTC** (block 19,384,049) the M-BTC token minter `0x000039DdCF1F63Cf3555e62a8D32a11bD1E7E1E1` called `MintableERC20.burn(0xC17312076F48764d6b4D263eFdd5A30833E311DC, 30353941375558573157)` — **burning 30.354 M-BTC directly out of the M-BTC aToken contract** (tx `0x12dc2a8ab6e78009b3bb8d25df2b1698b3dc50d46734378e28cd19411f65d5a0`, method `burn`, status ok). `burn` is `onlyMinter` on the token.
- The M-BTC token (`Merlin's Seal BTC`, `0x59889b…46c`) now has a total supply of only **0.549 M-BTC**; the aToken holds **0.00198 M-BTC** but still credits **30.42 M-BTC** to depositors (top holder `0x9E34d89C…0430` holds 30.3994 = ~$2.14M nominal).
- Consequence: the M-BTC market is **insolvent**; its collateral is worthless to the protocol, and the whale that used it as collateral still owes ~$0.9M of other assets (WETH $686k, USDC $77k, USDT $76k, wrsETH $16k, weETH.mode $36k, MODE 12.8M). This is the likely reason the market is dead; the global pause followed ~5 weeks later.

### 3.2 Positions / health factors (sampled)

- 108 unique borrowers sampled (top-15 holders per debt token); 74 returned `getUserAccountData`, 34 reverted because the user has a MODE position and the MODE feed is dead.
- **11 positions have HF < 1** at the (stale) oracle prices: ~$98.5k debt / ~$94.5k collateral. Deepest: `0x0BcaB08a…FB83` HF 0.53 (sUSDe debt $7,347), `0x76d757c1…8CB9` HF 0.67, `0x9227dFf3…237B` HF 0.71 ($23.4k debt).
- `liquidationBonus = 10001` (0.01%) on every reserve, so direct liquidation profit is negligible; the real latent exposure is the stale-vs-market price gap (e.g. ETH oracle $1,589 vs $2,682) if the pool is ever unpaused.

---

## 4. What an attacker can and cannot do (exact call paths)

All of the following were executed as `eth_call` from an unprivileged address against the live chain, and independently fork-tested (Section 6):

| Attempt | Result |
|---|---|
| `Pool.deposit/withdraw/borrow/repay/swapBorrowRateMode/rebalanceStableBorrowRate/setUserUseReserveAsCollateral/liquidationCall/flashLoan/finalizeTransfer` | revert `"64"` = `LP_IS_PAUSED` |
| `aUSDC.transfer` from a real holder; `transferFrom` with allowance | revert `"64"` (aToken `_transfer` → `pool.finalizeTransfer`, paused) |
| `aUSDC.mint/burn/mintToTreasury/transferUnderlyingTo/handleRepayment/transferOnLiquidation` | revert `"29"` = `CT_CALLER_MUST_BE_LENDING_POOL` |
| `vUSDC.transfer/transferFrom` | revert `TRANSFER_NOT_SUPPORTED` |
| `Pool.setPause/setConfiguration/setReserveInterestRateStrategyAddress` | revert `"27"` = not configurator |
| `Configurator.setPoolPause` | revert `"76"` = not emergency admin |
| `Pool.initialize(provider)` | revert `Contract instance has already been initialized` |
| Pool/aToken proxy `upgradeTo` | revert (caller ≠ immutable ADMIN = Provider / Configurator) |
| `Provider.setLendingPoolImpl` etc. / `Registry.registerAddressesProvider` / `Oracle.setAssetSources` | revert `Ownable: caller is not the owner` (owner = Timelock) |
| `Timelock.queueTransaction/executeTransaction` | revert `Timelock::…Call must come from admin.` (admin = Safe) |
| `Treasury.withdrawAllReserves()` (public!) | revert `"64"` — routes into paused `Pool.withdraw` |
| `Treasury.transferToMultisig` | revert `Ownable: caller is not the owner` |
| `CollateralManager.liquidationCall` direct | revert (its own storage has no provider/reserves; it is delegatecall-only) |
| `Oracle.getAssetPrice(MODE)` | revert `dAPI name not set` |

Exhaustive surface probe (`ci/probe_surface.py`): **197 functions across 13 Ironclad contracts, 106 state-changing; only 4 do not revert** — `aUSDC.approve`, `aUSDC.increaseAllowance`, `vUSDC.approveDelegation`, `M-BTC.approve`. All four are allowance-only bookkeeping and move no value; `approveDelegation` would only enable borrowing, which is paused.

**Costs:** irrelevant — no path executes. Gas on Mode would be cents, flash-loan premium is 0, but there is nothing to call.

---

## 5. Candidate Aave-fork exploit classes checked

| Class | Verdict |
|---|---|
| Oracle manipulation | **blocked** (all market ops paused); latent: feeds are already stale (WETH 95d) |
| Empty-market / donation | **not applicable** — aTokens are index-based (not balance-based) and deposits are paused |
| Liquidation against stale prices | **blocked** by pause; latent only |
| Interest accrual corruption | **blocked** — no non-paused function triggers `ReserveLogic.updateState`; stored indices frozen since 2025-03 |
| Uncollateralized borrow | **blocked** — `borrow` paused; validation libraries unchanged in reachable paths |
| Admin/emergency reachability | **gated** — 3/6 Safe + Timelock; no permissionless timelock execution (unlike legacy Compound) |
| aToken/burn/mint abuse | **blocked** — `onlyLendingPool`; MockAToken is upstream AToken + revision only |
| Debt-token transfer / credit delegation | **not exploitable** — transfers disabled, borrowing paused |
| Direct collateral-manager call | **reverts** (delegatecall-only design) |
| Treasury drain | **blocked** — public function depends on paused Pool; owner-only otherwise |
| Proxy re-init / upgrade | **blocked** — initialized; immutable ADMIN |
| Other markets/chains | registry has exactly one provider; DefiLlama lists Mode only |

---

## 6. PoC / fork verification

`poc/` is a Foundry project (vendored forge-std). All tests fork Mode at latest via `MODE_RPC_URL` (public fallback `https://mainnet.mode.network`) and are read-only.

`poc/test/Ironclad.t.sol` — 10 tests:

1. `test_01_state_snapshot` — paused=true, 11 reserves, single provider.
2. `test_02_pool_value_paths_paused` — 10 entry points revert `"64"`.
3. `test_03_atoken_transfers_blocked` — holder transfer/transferFrom revert `"64"`; approve works (harmless).
4. `test_04_atoken_only_pool_paths_blocked` — 6 functions revert `"29"`.
5. `test_05_admin_paths_blocked` — setPause/setConfiguration `"27"`; configurator `"76"`; initialize; proxy upgrade.
6. `test_06_timelock_treasury_blocked` — Timelock admin-only; Treasury public withdraw `"64"`; transferToMultisig owner-only.
7. `test_07_misc_paths_blocked` — collateral manager; vDebt `TRANSFER_NOT_SUPPORTED`; MODE feed dead.
8. `test_08_oracle_staleness_latent` — WETH feed >30 days stale.
9. `test_09_available_liquidity_snapshot` — 38.79 ezETH / 0.0992 uniBTC available.
10. `test_10_mbtc_market_insolvent` — aToken backing <0.1% of claims; token supply << claims.

**CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):**

- Run 1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137721899 — **9/10 PASS** (one wrong 10× assertion in test_09; no protocol failure), plus a CI-side missing `eth-hash` backend that was fixed.
- Run 2: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137982962 — **10/10 PASS** (gas: test_02 324,182; test_03 354,694; test_05 246,946; test_10 51,484). Surface probe artifact: **197 functions, 106 state-changing, only 4 no-revert** (aUSDC.approve/increaseAllowance, vUSDC.approveDelegation, M-BTC.approve — allowance-only).
- Run 3 (final, snapshot path fixed): see `ci-log.txt` / below.

<!-- CI3 -->

Local validation: `test_01`, `test_02`, `test_09` all PASS.

---

## 7. Verdict, residual and latent risk

**Verdict:** **E-U = $0, high confidence.** The only thing standing between an attacker and the remaining value is a single paused flag controlled by a 3/6 Safe. There is no unprivileged path through the Pool, aTokens, debt tokens, Treasury, Timelock, proxies, or the collateral manager.

**Residual/latent risks (not currently extractable):**

1. **Unpause** (Safe) → ~$122.4k of available liquidity becomes holder-withdrawable; liquidations of the 11+ HF<1 positions become possible (bonus only 0.01%, but stale oracles make ETH-collateral liquidations up to ~69% profitable to a liquidator at users' expense).
2. **Stale oracles** — WETH/USDC/M-BTC/uniBTC feeds ~95–96 days old, MODE feed dead. Any future unpause without refreshing feeds creates mispriced liquidations and a MODE-user DoS (`getUserAccountData` reverts for any user with MODE positions, so those positions cannot be liquidated).
3. **M-BTC bad debt** — ~$2.14M nominal claims backed by $139; the issuer burn is irreversible.
4. **Key risk** — the whole system is controlled by a 3/6 Safe whose signers are EOAs; a key compromise would allow unpause + upgrade. That is privileged, not unprivileged, risk.

**Blockers to extraction:** `paused == true` (LP_IS_PAUSED `"64"`); `finalizeTransfer` pause on every aToken transfer; `onlyLendingPool` on all aToken value functions; `TRANSFER_NOT_SUPPORTED` on debt tokens; Safe/Timelock on admin functions; delegatecall-only collateral manager; dead MODE oracle.

---

## 8. Methodology, sources, caveats, files

**Method:** raw `eth_getStorageAt`/`eth_call` on Mode RPC; ModeScan (Blockscout) v2 API for verified sources, ABIs, holders, token transfers, logs; DefiLlama for market prices; bytecode-hash comparison for the Pool impl; fork tests in Foundry (CI).

**Caveats / limitations:**
- All USD are market prices on 2026-10-03 (DefiLlama); the pool's own oracle is stale, so pool-internal values differ.
- Borrower health-factor analysis is a sample (108 unique addresses from top-15 holders per debt token; 34 could not be evaluated due to the dead MODE feed). It is sufficient to bound latent risk, not a complete census.
- Holder lists were paginated to ≤400 addresses per token; small holders may be missing.
- The M-BTC burn was executed by the token's `minter` role; we did not attempt to attribute the minter beyond the on-chain address.
- Mode's public RPC rejects checksummed addresses in `eth_call` (returns "execution reverted"); all scripts lowercase addresses.
- No archive state was needed; every read is at the stated latest block.

**Key on-chain citations:** pool `paused()` → true @45,438,468; registry `getAddressesProvidersList()` → `[0xEDc8…]`; pause tx `0x061701c3…` @21,029,938; M-BTC burn tx `0x12dc2a8a…` @19,384,049; WETH feed `latestTimestamp 1782798933` / `latestAnswer 158914490000`; Treasury aToken balances (see `analysis/borrowers_hf.json`); probe results (`ci-out/probe_results.json`).

**Files index:**
- `analysis/` — `dump_state.py` + `state_dump.json` (block 45,438,468), `final_numbers.py` + `final_numbers.json` + `real_prices.json` (market table), `holders.json` + `fetch_holders.py`, `borrowers_hf.py` + `borrowers_hf.json` (HF sample), verified sources (`LendingPool.sol`, `PoolConfigurator.sol`, `CollateralManager.sol`, `Oracle.sol`, `Timelock.sol`, `Treasury.sol`, `MBTCToken.sol`, `PoolProxy.sol`), contract metadata/ABIs (`*_contract.json`, `*_impl.json`), `mbtc_burn_tx.json`, `prepause_logs.json`.
- `poc/` — Foundry project (`foundry.toml`, `test/Ironclad.t.sol`, vendored `lib/forge-std`).
- `ci/run.sh`, `ci/probe_surface.py` — CI custom job (RPC pick + state snapshot + 197-function surface probe).
- `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI results.
- `summary.json` — machine-readable summary.
