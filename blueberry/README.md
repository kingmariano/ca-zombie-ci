# Blueberry (Monad live vaults + Ethereum / Hyperliquid remnants) — L2 Phase-2 deep dive

**Date:** 2026-10-11 · **Chains:** Monad (143), Ethereum (1), HyperEVM (999) / Hyperliquid L1
**Status:** read-only; PoC fork-verified only; **no mainnet transactions, no secrets.**
**Triage row:** `l2-triage-a` — Blueberry LIVE-FUNDED $1,243,000 (rank #2).

---

## 1. TL;DR

| Target | Live value (unprivileged view) | Who can move it | Why closed/open | Latent risk |
|---|---|---|---|---|
| Monad `Blueberry AUSD` vault `0xC2dd…E670` | **1,153,597.47 AUSD** (≈$1,152,354) | share holders only (redeem) | Yearn V3.1.0, immutable minimal proxy; all admin paths role-gated; anti-donation accounting; **E-U from the vault = $0** | Curvance market solvency; AUSD issuer |
| Monad `Blueberry USDC` vault `0x2153…6b2E` | **51,686.73 USDC** (≈$51,668) | share holders only (redeem) | same | Curvance market solvency |
| Monad strategies `CurvanceOptimizer` (opt1/opt2) | holds 100% of both vaults | vault only (shares 100% vault-held) | deposits **closed** (`open=false`, only vault whitelisted); `report/tend` keeper-only; `shutdown/emergencyWithdraw` emergency-only | Curvance protocol |
| ETH compound-fork bToken markets (13) | **≈$26,254** of depositors' money | bToken holders (redeem) | standard Compound fork; borrows ≈ 0 → cash covers | — |
| ETH `BlueberryBank` positions 38/39 | **$79.47** | the two position owners | not liquidatable → `liquidate` reverts; bank status 15 (flows open) | — |
| HyperEVM `HyperVaultRouter` `0x647a…1BB4b` | TVL **$10,300.42**, only **$498.24** redeemable today | share holders (≤$498) / `LIQUIDITY_ADMIN` role for the rest | escrow holds L1/HLP positions; L1→EVM pull is role-gated | admin-dependent liquidity |
| Curvance reward auction (opt2, cWMON) | **≈$0.84** (31.31 cWMON ≈ 32.69 WMON) | **anyone** (`take()` at decayed price) | the only live unprivileged value-transfer path found — dust | — |

**Total live value under custody ≈ $1,241,000** (market prices, 2026-10-11) — matches the triage.
**Live extractable by an external unprivileged attacker (E-U): ≈ $0.84 (dust auction discount; economically zero).**

> The triage's "Blueberry" zombie row (DefiLlama, ETH/Hyperliquid, last activity 403d) is **not** the same deployment as the Monad value. The Monad vaults were deployed **2026-08-15/10-01** (blocks 94.5M / 99.7M) and are **actively managed right now** (keeper reports every few hours; deposits/withdrawals landing continuously). It is a live, professionally operated Yearn-V3 + Curvance deployment, not a zombie.

---

## 2. Total live extractable now

| Category | USD | Confidence |
|---|---|---|
| **E-U** external unprivileged attacker | **≈$0.84** (dust cWMON auction discount; all other paths $0) | high |
| **H-O** holder/user self-service | **$1,230,873** (Monad $1,204,042 + ETH fork $26,254 + ETH bank $79 + HL redeemable $498) | high |
| **P** privileged-only | **$9,802** (HL router rest, requires `LIQUIDITY_ADMIN` to bridge from L1) | medium |
| **S** stuck/bricked | **$0** | high |

Value is moving in real time (deposits/withdrawals observed between blocks 112.48M→112.49M). Numbers above are at the stated blocks/prices; see `analysis/` and `ci-out/state.json`.

---

## 3. The mechanism in exact terms

### 3.1 Monad vaults are canonical Yearn V3.1.0 (Vyper 0.3.10)

Both vaults are **45-byte EIP-1167 minimal proxies** → implementation `0xdd3fa86409658d207a9be0141ee560c8db557824` (verified source: `analysis/vault1.vy`, identical for both). Minimal proxies are **not upgradeable** (no admin slot; EIP-1967 slots read zero).

```
V1 0xC2ddc1004CA0d6cC4bFd1dCD03Dcf855bED8E670  "Blueberry AUSD"  blbAUSD  6dp  asset 0x00000000eFE3…012a (AUSD)
V2 0x215394B5677Cb7a18B6fA8cc2cD155C024ee6b2E  "Blueberry USDC"  blbUSDC  6dp  asset 0x754704Bc05…b603 (USDC)
factory 0x310ac28acf5e514abdbff9ab25e21f1bfe22bcac (Yearn VaultFactory)
deployer 0x02426745D31185B9946E7E513D6B25d07a633f3f   (owner of mgmt Safe, active)
```

Accounting is **stored**, not `balanceOf`-derived (`_total_assets() = total_idle + total_debt`), so direct token donations cannot move PPS (proven, §6). Deposits are open (`deposit_limit = 2^256-1`, `auto_allocate=true`); withdrawals pull from the strategy queue with loss accounting (`_assess_share_of_unrealised_losses`, `max_loss` param).

### 3.2 All funds are in Curvance strategies

```
default_queue[0] V1 = 0x460BBe066AA0ff94d7AFCd95580c41190FC4C7E4  CurvanceOptimizer (AUSD)
default_queue[0] V2 = 0xe43b232FA6Ce535C6B4F8771427eBd4a77Bad593  CurvanceOptimizer (USDC)
(other queue entries: CurvanceLender 0x481d…, 0x814b…, 0x5b5d… — all zero debt)
```

The optimizers are **Yearn V3 TokenizedStrategy** strategies (canonical implementation `0xD377919FA87120584B21279a491F82D5265A139c`; source `analysis/TokenizedStrategy.sol`). Their shares are held **100% by the Blueberry vaults** (`balanceOf(vault) == totalSupply`). They allocate into **Curvance** markets on Monad:

- opt1 (AUSD): 4 markets — Curvance AUSD markets + **“High Yield AUSD Vault”** `0xaD663aC8…a00Bf` (the bulk, ~1.1526M AUSD at block 112.4857M)
- opt2 (USDC): 2 markets — Curvance USDC `0x207340D1…55e5` (~52.2k USDC)

### 3.3 Access control (verified on-chain)

| Role holder | Authority |
|---|---|
| Gnosis Safe **3-of-4** `0x72d19f7c71a2bD5E61871B1D3dF7a45ae5Ec9582` | **all 14 vault roles** (bitmask 16383) + strategy `management` + strategy factory admin; Safe owners `0x02426745…, 0x3031303b…, 0x4850d609…, 0x989b1a8e…`; nonce 39 |
| keeper EOA `0xf6b6dA3bbA0caA61eC3C65ad87a61b9d0130457b` | vault `REPORTING` (bit 32) + strategy `keeper`; EOA, actively reporting |
| `RoleManager` proxy `0x5b79684891c55A9E042Cd5D7719c211Bee17Ab39` → impl `0xa1ae1c65…9404` | vault `role_manager` (grants roles) |
| accountant `0xf7e5c38800498d773c875d447413b3b30f816190` | Yearn `Accountant` (fee math only; no vault roles) |
| fee recipient Safe 2-of-4 `0xe4d701c6…5119` | performance-fee shares only |

`report()` / `tend()` in the TokenizedStrategy are `onlyKeepers` (source line: `function report() external nonReentrant onlyKeepers`) — **not permissionless**. Strategy deposits are closed (`open=false`; `allowed(vault)=true`, `allowed(anyone-else)=false`).

---

## 4. Live-state assessment (all reads, latest/pinned block recorded)

**Monad — CI state dump block 112,493,204 (2026-10-11 ~14:26Z); pinned PoC block 112,485,700. Values move continuously (this table was 1,152,077.97 AUSD / 53,206.06 USDC seven minutes earlier at the pinned block):**

| Item | V1 (AUSD) | V2 (USDC) |
|---|---|---|
| totalAssets | 1,153,597.474993 | 51,686.727929 |
| totalIdle / totalDebt | 0 / 1,153,597.474993 | 0 / 51,686.727929 |
| totalSupply | 1,141,740.279466 | 51,340.02806 |
| pricePerShare | 1.010385 | 1.006753 |
| deposit_limit | 2^256−1 | 2^256−1 |
| paused / shutdown | false / false | false / false |
| deposit_hook / withdraw_hook | 0x0 / 0x0 | 0x0 / 0x0 |
| role_manager | `0x5b79…ab39` | `0x5b79…ab39` |
| strategy debt | 1,153,597.47 in opt1 | 51,686.73 in opt2 |
| strategy `open` / `allowed(vault)` | false / true | false / true |
| strategy `maxDeposit(vault)` | 2^256−1 | 2^256−1 |
| strategy shares held by vault | 100% | 100% |
| keeper lastReport | 1791717646 (≈2h before pin) | 1791717653 |

**Holders (Monad vaults)** — only 5–6 addresses, all with `maxRedeem ≥ balance − 1 wei` (full-liquidity simulation; the largest holder's `maxWithdraw` = full value):

| Holder | blbAUSD | blbUSDC |
|---|---|---|
| `0xa5190552e8A7902812C6F6Df07813BF6AEBfc6bd` (contract; storage slot0 = `"… Boring Vault"`) | 1,083,493.88 | 8,062.58 |
| `0xbA1333333333a1BA1108E8412f11850A5C319bA9` (contract, 24.5 kB) | 57,413.73 → 57,927.80 | 43,757.85 → 43,242.00 |
| accountant `0xf7e5…6190` | 201.34 | 19.55 |
| vault self (locked profit unlocking over 1 day) | ~134 | ~7 |
| initial depositor `0x3031303b…` | 10.10 | 10.00 |

**Ethereum (block 26,169,737):**
- `BlueberryBank` proxy `0xa34F59F634d48E2c3606048f2367326c46a4B5fA` (impl `0xb96f3016…`): owner = same mgmt Safe; status = 15 (borrow/repay/lend/withdrawLend all open); `nextPositionId=40`; **only positions 38 & 39 have value** ($41.66 + $37.80 = $79.47, both `isLiquidatable=false`, `getPositionRisk=0`); bank holds 0 USDT/USDC.
- Compound fork `Unitroller` `0xcb0D9Ff5BDD34521c6f8CDbeAf15e1A76Fa4dd5D` (13 bToken markets): total cash+borrows−reserves ≈ $26,254 at DefiLlama prices. Borrows only: bUSDC 36.32 + bWETH 0.015 (these are the bank positions). bUSDC cash 8,534.37 − reserves 532.48 → fully redeemable.

**HyperEVM (block 48,263,074):** `HyperVaultRouter` proxy `0x647a4D7F1F20Cf237C27b39fB6924f5a7691BB4b` (impl `0x893c6e4f…`): `tvl()=10,300.42e18`; `maxWithdrawable()=498.24 USDC` (escrow `0xba3b516c…` on HyperEVM holds only ~$498 of the withdraw asset); `maxRedeemable()=424,307.4e18` shares (≈4.8% of supply); owner `0x08be6a54…`; L1→EVM withdrawal (`vaultWithdraw`, `bridgeFromL1`) is `onlyRole(LIQUIDITY_ADMIN_ROLE)`.

---

## 5. What an attacker can / cannot do — exact call paths

**Can (all value-neutral, except the dust auction below):** `deposit`/`mint` into the vaults (open, fair PPS); `withdraw`/`redeem` own shares; transfer shares; call `claim()` on the optimizers (MERKL rewards accrue to the strategy); call `pokeFees()` on the HL router (mints fee shares to the fee recipient).

**One live unprivileged value-transfer path (dust):** the opt2 CurvanceOptimizer's reward auction (`0xd84472f841e1ab683f2ce03f15051cb233f0a730`) has an **active permissionless Dutch auction** for **31.30798 cWMON** (`0xe01d426b…22ed`, Curvance Wrapped MON, worth 32.69 WMON ≈ **$0.84** at MON $0.02575). `take(cWMON)` is callable by anyone; the price decays 0.5%/min from `$0.3195/cWMON` toward zero over the 24h auction window (`AUCTION_LENGTH = 1 days`), so a patient taker can buy the lot for well under its market value — a value transfer from vault holders to the taker of at most **$0.84**. Auction proceeds go to the strategy (vault holders). opt1's auction is inactive with zero balance. This is reward-token dust, not protocol value.

**Cannot (proven to revert in PoC, §6):**

| Attempted call (as attacker) | Result |
|---|---|
| `vault.process_report(opt1)` | revert (REPORTING role) |
| `vault.update_debt(opt1,0,0)` | revert (DEBT_MANAGER) |
| `vault.add_strategy/revoke_strategy/force_revoke_strategy/update_max_debt_for_strategy` | revert |
| `vault.set_role/set_accountant/set_default_queue/setPaused/shutdown_vault/buy_debt` | revert |
| `opt1.report()` / `opt1.tend()` | revert (`onlyKeepers`) |
| `opt1.shutdownStrategy()` / `opt1.emergencyWithdraw(1e6)` | revert (`onlyEmergencyAuthorized`) |
| `opt1.deposit(1000e6, attacker)` | revert — `maxDeposit(attacker)=0` (closed) |
| `opt1.kickAuction(AUSD)` | revert — protected token |
| `bank.liquidate(38, USDC, 1e6)` / `liquidate(39, WETH, 1e15)` | revert `NOT_LIQUIDATABLE` |

**Rejected attack hypotheses (with the reason):**

1. **ERC-4626 inflation / donation** — vault and strategy use stored `total_*` accounting; direct transfers of AUSD to vault or strategy leave `totalAssets`, `pricePerShare`, `convertToShares` unchanged (PoC). No first-depositor edge (supply is 1.14M).
2. **Rounding extraction** — `deposit→redeem` round-trip returns ≤ deposited (AUSD: 100,000.00 in → 99,999.999997 out = 3 units loss; USDC exact). Vault and strategy round against the user.
3. **Fake profit via permissionless `report()`** — `report()` is `onlyKeepers`; the keeper is an active EOA; even a donation that inflates the strategy is a *gift* to vault holders.
4. **Strategy dilution** — deposits closed; `allowed` only the vault.
5. **Auction discount (kickAuction)** — `kickAuction` on the protected asset reverts; the strategies' holdings are `asset` + market shares (protected). The **only** non-protected balance found is 31.31 cWMON (Curvance reward dust) in opt2's already-active auction, worth **$0.84** — the single live unprivileged value-transfer path (§5).
6. **Unrealised-loss theft** — vault `_redeem` charges losses to the redeemer and reverts when `max_loss` is exceeded; at the pinned block unrealised loss = 0.
7. **ETH bank liquidation** — positions 38/39 are over-collateralised (risk 0) → `liquidate` reverts; no other paths exist for non-owners (`execute` requires a whitelisted spell AND position ownership).
8. **Curvance-market donation** — donating AUSD into a Curvance market leaves its `totalAssets` unchanged (stored accounting) — no share-price inflation vector.

**What *is* true (context, not E-U):** holders can exit. Largest holder redeemed 1,083,493.88 blbAUSD in one call on the fork, receiving 1,094,739.737324 AUSD (preview 1,094,739.737326; realised rounding loss **2 wei ≈ $0.000002**) using the standard 3-argument `redeem(shares, to, owner)` (whose Vyper default is `max_loss=MAX_BPS`). Only an *explicit* `max_loss=0` call reverts `too much loss` on that 2-wei shortfall; `withdraw(assets, to, owner)` (default `max_loss=0`) can likewise revert on rounding. This is Yearn V3 loss accounting, not an extraction path. Second holder redeemed 44,751.15 blbUSDC for 45,053.10 USDC with **zero** loss.

---

## 6. PoC / fork-verification

| Project | Chain | Tests | Result | Notes |
|---|---|---|---|---|
| `poc-monad/` (`test/BlueberryMonad.t.sol`) | Monad fork @ block **112,485,700** via public `https://rpc.monad.xyz` (run with `--rpc-url` to select the Monad EVM) | 9 | **9/9 PASS** | state snapshot; holder1 full redeem; holder2 full redeem; 18 privileged-path reverts; donation-to-vault no-op; donation-to-strategy no-op; deposit/redeem round-trip; Curvance-market donation; value conservation |
| `poc/` (`test/BlueberryEth.t.sol`) | Ethereum fork (latest) via `FORK_RPC_URL` | 2 | **2/2 PASS** | bank positions not liquidatable + 2 `liquidate` reverts; compound-fork market liquidity |

CI runs (public repo `kingmariano/ca-zombie-ci`, branch `blueberry`, workflow `poc.yml`):
- Run 1 (initial suite): `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38147161283`
- Run 2 (final, corrected assertions): `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38147551546` — logs `ci-log.txt`, artifacts `ci-artifacts/result-blueberry/` (`ci-out/monad-tests.log` 9/9 PASS, `ci-out/state.json`).

Key PoC numbers (fork block 112,485,700):
- V1 totalAssets 1,152,077.966349; totalSupply 1,140,243.090775; pps 1.010379; opt1.totalAssets == vault debt; vault holds 100% of opt1 shares.
- Donation 1,000,000 AUSD → vault: `totalAssets`/`pps`/`convertToShares` **unchanged**.
- Donation 100,000 AUSD → opt1: `totalAssets`/`pps` **unchanged**.
- Round-trip 100,000 AUSD: out = 99,999.999997 (loss 3 units ≈ $0.000003); mint→withdraw nets −1,037.93 AUSD (no profit).
- Holder1: explicit `max_loss=0` redeem reverts `too much loss`; standard 3-arg redeem pays 1,094,739.737324 AUSD (2 wei rounding).
- Curvance market donation: `totalAssets` before/after 10,091,462,699 → unchanged.

---

## 7. Verdict, residual & latent risk

**Verdict:** an external unprivileged attacker can extract **≈$0.84** live from Blueberry today — and that is only the decay-discount on 31.31 cWMON of Curvance reward dust sitting in a permissionless auction (high confidence). Every dollar of real value (~$1.24M) sits behind either (a) holder-only redemption (vaults, bTokens, bank positions, HL router ≤$498), or (b) role-gated admin paths (mgmt Safe 3-of-4; HL `LIQUIDITY_ADMIN`). The Yearn V3.1.0 + TokenizedStrategy code is unmodified canonical code with its known protections (stored accounting, role gates, keeper-only reports).

**Residual / latent risk (not attacker-extractable today):**
- **External protocol risk:** vault value is 100% allocated to Curvance markets on Monad. A Curvance solvency/exploit event would impair the vaults (losses would be socialised to holders, not stealable by an outsider).
- **AUSD issuer/depeg:** AUSD last traded $0.99894 (DefiLlama) — a depeg would reduce the USD value.
- **Privileged trust:** the 3-of-4 Safe can reallocate strategies, set the queue, or (with `DEBT_MANAGER`) move funds; the keeper can report. That is the intended trust model; there is no timelock observed.
- **HL router liquidity:** holders are limited to the escrow's ~$498 USDC until the owner bridges from L1 — effectively admin-dependent for the remaining ~$9.8k.
- **Operational quirk:** an *explicit* zero-loss redeem/withdraw (`max_loss=0`) of a full AUSD balance reverts on a 2-wei rounding shortfall; the standard 3-arg `redeem` (default `MAX_BPS`) works.

**Blockers for an attacker:** role checks on every privileged path; `open=false` + whitelist on strategies; keeper-only `report/tend`; protected-token checks in `kickAuction`; over-collateralised bank positions; admin-gated HL L1 withdrawals.

---

## 8. Methodology & sources; caveats; files

**Method:** live `eth_call`/`eth_getStorageAt` reads on Monad/Ethereum/HyperEVM (public RPCs), Etherscan V2 (chain 143/1/999) for verified sources/ABIs/tokentx, DefiLlama for USD prices, and Foundry fork tests (pinned blocks) on CI. Sources saved: vault Vyper (`analysis/vault1.vy`), TokenizedStrategy (`analysis/TokenizedStrategy.sol`), CurvanceOptimizer (`analysis/CurvanceOptimizer.sol`), BlueberryBank (`analysis/BlueberryBank.sol`), HyperVaultRouter/Escrow, RoleManager, Accountant.

**Caveats:** (1) values are point-in-time and moving (active deposits/withdrawals/reports); (2) token prices from DefiLlama at 2026-10-11 ~14:20–15:00 UTC; (3) the holder contracts (`0xa519…`, `0xba13…`) are smart contracts — their internal beneficiaries were not resolved; (4) Curvance protocol internals were only screened at the integration boundary (positions, liquidity, accounting), not fully audited — out of scope; (5) the 2-wei rounding behaviour may vary by market/amount; (6) the cWMON auction discount is bounded by the lot's market value (≤$0.84) and decays over a 24h window.

**Files:** `README.md` (this), `summary.json`, `analysis/` (sources, ABIs, raw state dumps, holder list, prices), `poc/` + `poc-monad/` (Foundry projects), `ci/` (run.sh, state_dump.py), `ci-out/` (CI results), `ci-log.txt`, `ci-artifacts/`.
