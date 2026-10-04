# H-35…H-41 — Metis orphan contracts: live extractable-value determination

**Campaign:** zombie-hunt (deep-dive phase) · **Chain:** Metis Andromeda (chain id 1088) · **Date of work:** 2026-10-04
**Status:** read-only research; every PoC/negative-path test executed on a **local fork inside GitHub Actions** — no mainnet transactions sent.
**Fork block:** 23,238,745 (CI suite) / 23,238,690 (recon) · **METIS price:** $3.37615 (DefiLlama, 2026-10-04)

**Scope (all addresses on Metis Andromeda):**

| # | Target | Address | METIS held (verified) |
|---|---|---|---|
| H-35 | GnosisSafeProxy (SafeL2 v1.3.0) | `0xdd7c49D1bA862b1285710A30E20C2438b13AE532` | 1,847,552.364 |
| H-36 | ERC1967 proxy → `Vault` (UUPS) | `0x17A30350771d02409046A683b18Fe1C13cCFC4A8` | 68,713.855 |
| H-37 | `Mining` (MasterChef-style, paused) | `0x7077f35063f17EE1B84678334d261Ccf47980271` | 13,217.96182843 |
| H-38 | Netswap pairs A–D | `0x3D60…c5A1`, `0x5905…610d`, `0x5Ae3…5091`, `0x9dAb…3a00` | 93,247.613 (METIS side) |
| H-41 | Aave V3 aToken `aMetMETIS` | `0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8` | 26,448.834 (backing) |

---

## TL;DR

**An external, unprivileged attacker can extract ≈ $0 live from every one of these contracts.** Each target is closed by an explicit, on-chain-verifiable gate: a 4-of-6 EOA multisig (H-35), role-gated transfers + owner-gated UUPS upgrade (H-36), a DAC-only caller gate + pause + a contract with **no METIS outflow function at all** (H-37), standard Uniswap-v2 pair math with zero excess balances (H-38), and a frozen, LTV-0, cap-1, 99%-reserve-factor Aave reserve whose only exit is holder self-withdrawal (H-41). The value is classified as P (privileged), H-O (holder self-service) and S (stuck) — not E-U.

| # | Target | Live E-U (unprivileged) | Why closed | Category of the funds | Latent risk |
|---|---|---|---|---|---|
| H-35 | GnosisSafeProxy | **$0** | 4-of-6 EOA signatures required (`GS020` on unsigned exec); no modules ever (storage walk); canonical SafeL2 v1.3.0 singleton + CompatibilityFallbackHandler | **P** — $6.24M under a 4-of-6 multisig cluster (**Metis Foundation EDF** per dossier) | owner-key compromise; none structural |
| H-36 | Vault proxy | **$0** | `transferEther`/`transferErc20` need `PAYER_ROLE` + `PAYEE_ROLE`; `initialize()` reverts `already initialized`; `upgradeTo` reverts `Ownable: caller is not the owner` | **P** — $232.0k under owner `0x52c9…` (**KuCoin-linked active hot-wallet vault**, not an orphan) | UUPS upgrade by owner; same impl holds a sibling $118.8k vault |
| H-37 | Mining | **$0** | `deposit`/`withdraw` are `onlyDAC` ("not DAC"); contract is `paused`; the METIS is **wei-for-wei the stakers' principal** (Σ user.amount == balance, delta 0) — only each staker can `emergencyWithdraw` their own amount | **H-O** — $44.6k stakers' principal, fully backed; no admin sweep | adjacent DACRecorder reward vault (105,376.88 METIS) if unpaused |
| H-38 | Netswap pairs A–D | **$0** | balances == reserves exactly (skim pays 0); pair self-LP = 0; `burn` without LP reverts; factory setters are EOA-gated; standard locked Uniswap-v2 code | **H-O** — LP holders' $596.5k (METIS side $314.8k); LP supplies anomalous on pairs A/C | MasterChef/staking contracts (per-dossier); pair A/C LP concentration |
| H-41 | Aave aMetMETIS | **$0** | All 5 reserves frozen, LTV 0, caps 1, RF 99%; no liquidatable positions (min HF 1.45); attacker `withdraw` reverts `NotEnoughAvailableUserBalance`; no donation path | **H-O** — $89.3k withdrawable by aToken holders (whale exit fork-proven) | 0.217 METIS formal bad debt; market deprecated via AIP #521 (2026-09-20) |

**Total live extractable now: ≈ $0 E-U (confidence: high).**
Custody map: P ≈ **$6.47M** (H-35 + H-36 in-scope; ≈$6.64M incl. sibling Safes/Vaults) · H-O ≈ **$89.3k** (Aave aToken) **+ $44.6k** (Mining stakers' principal) **+ Netswap LP claims** · S ≈ **$0**.

---

## 1. H-35 · GnosisSafeProxy `0xdd7c49D1bA862b1285710A30E20C2438b13AE532`

### 1.1 Verified live state (block 23,238,745 / 23,238,690)

| Check | Value |
|---|---|
| `VERSION()` | `1.3.0` (SafeL2 — explorer `implementation_name = GnosisSafeL2`) |
| singleton (storage slot 0) | `0xfb1bffc9d739b8d520daf37df666da4c687191ea` |
| fallback handler (slot `keccak256("fallback_manager.handler.address")`) | `0x017062a1de2fe6b99be3d9d37841fed19f573804` (canonical CompatibilityFallbackHandler) |
| `getThreshold()` | **4** |
| `getOwners()` | 6 EOAs (no code): `0xFA30D7D3…6071`, `0x0be0515B…0C96`, `0xb41b842A…5a66`, `0x02836327…0BaB`, `0xAdabeccd…7882`, `0x923170a0…1a30` |
| modules | **none** — `getModules()` is absent from this singleton build, so the module linked list was walked in storage (slot 1, SENTINEL): terminates immediately. Guard slot 8 = 0 |
| `nonce()` | 17 |
| balance | **1,847,552.364 METIS** = 1,847,552,364,000,000,000,000,000 wei |
| sibling Safe (same signer cluster) | `0xeA0f824CbA2A003d599186DA41A8842E2C4Bd964` — 4-of-**7**, 6 owners overlap, 16,025.5 METIS |

### 1.2 Attack-surface analysis

- `execTransaction` with empty signatures reverts **`GS020`** (not enough signatures) — fork-verified. A valid execution needs 4 of 6 EOA signatures; there is no signature-replay, no unprotected `approveHash`, and `execTransactionFromModule` cannot be used because the module list is empty.
- `enableModule` / `addOwnerWithThreshold` / `setGuard` all revert for an unprivileged caller — fork-verified.
- `getGuard()` reverts through the proxy because the deployed singleton exposes no `getGuard()` selector (direct call to the singleton returns empty); the fallback handler does not implement it. No guard is set — a guard only *adds* checks, so this is not an extraction path.
- The only value-bearing paths are the six EOA keys; no on-chain path exists without 4 of them.

### 1.3 Verdict

**E-U $0 (high confidence).** Funds = **P**: 1,847,552.364 METIS ≈ **$6,237,615** (at the live METIS price $3.37615; a $10/METIS placeholder would give ≈$18.5M — the live price is used throughout this report) controlled by a 4-of-6 EOA multisig cluster (owners overlap the 4-of-7 sibling Safe). Latent risk is off-chain (key compromise), not structural.

**Identity (from `analysis/h35/dossier.md`):** the funder `0x26eC4FF7…` moved exactly 4,590,000 METIS on 2023-12-20 in the same split as the announced **Metis Foundation / MetisDAO Ecosystem Development Fund (EDF) sequencer-mining allocation** (3,000,000 METIS → this Safe; 1,390,000 → the sibling Safe `0xeA0f824C…`; 200,000 → an EOA). All 17 historical executions carried valid threshold signatures; accounting reconciles exactly: 3,000,000 in − 1,152,447.636 out = 1,847,552.364. No modules were ever enabled; owners are code-less EOAs (no EIP-7702).

---

## 2. H-36 · ERC1967 proxy `0x17A30350771d02409046A683b18Fe1C13cCFC4A8` → `Vault`

### 2.1 Verified live state (block 23,238,745)

| Check | Value |
|---|---|
| EIP-1967 implementation slot | `0xd62dEdee92074458B1C31133E6601CB6b87e844B` (contract name `Vault`) |
| admin / beacon slots | `0x0` / `0x0` (no transparent admin, no beacon) |
| `owner()` | `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` (EOA, no code) |
| `initialize()` (replay attempt) | reverts **`Initializable: contract is already initialized`** |
| balance | **68,713.855 METIS** = 68,713,855,000,000,000,000,000 wei |
| sibling deployment of the same impl | `0xb8e6D31e7B212b2b7250EE9c26C56cEBBFBe6B23` — owner `0xc5588FA2…dEd2`, 35,193.875 METIS |

### 2.2 The code (deployed verified source, 150 lines)

`Vault` = OZ UUPS + Ownable + AccessControlEnumerable + ERC721Holder. Money paths:

- `transferEther(payee, amount)` / `batchTransferEther` — `onlyRole(PAYER_ROLE)`, and the payee must hold `PAYEE_ROLE`.
- `transferErc20` / `batchTransferErc20` / `transferErc721` / `batchTransferErc721` — same two-role gate.
- `_authorizeUpgrade` — `onlyOwner`; `upgradeTo`/`upgradeToAndCall` therefore revert for anyone but the owner.
- `receive()` accepts ETH; `initialize()` sets the deployer as DEFAULT_ADMIN once.

### 2.3 Attack-surface analysis (all fork-verified reverts)

| Attempt | Result |
|---|---|
| `transferEther(attacker, 1 ETH)` | reverts `AccessControl: account … is missing role 0x8ec07e26…` (= `PAYER_ROLE`) |
| `transferErc20(METIS, attacker, 1e18)` | reverts |
| `initialize()` | reverts `already initialized` |
| `upgradeTo(attacker)` | reverts `Ownable: caller is not the owner` |

There is no unprivileged path. Role membership (verified on-chain): `DEFAULT_ADMIN_ROLE` = 2 EOAs (`0xd534b953…`, `0x52c904aB…`); `PAYER_ROLE` = `0x52c904aB…` (EOA) + **`0x96ED493C74e23e4FAAd2409e59eD2d4eC8f64E52`, which is itself a GnosisSafeProxy (Safe v1.3.0, 3-of-6, singleton `0xf66f5d84…`, no modules, no guard, no fallback handler)**; `PAYEE_ROLE` = 3 EOAs. The only contract in the money path is a multisig — it cannot be triggered permissionlessly. See `analysis/parent_verification.md`.

### 2.4 Verdict

**E-U $0 (high confidence; dossier confidence 0.97).** Funds = **P**: 68,713.855 METIS ≈ **$231,988** (live price) under owner `0x52c9…`. **The "orphan" premise is disproven:** the dossier identifies this as a **KuCoin-linked hot-wallet/payment vault** (impl deployer `0x720d5253…` is tagged "KuCoin: Hot Wallet Vault 15"; the address is in hildobby's CEX list as KuCoin and appears in KuCoin's Avalanche Proof-of-Reserves; same deployer family on Avalanche). Lifetime flows reconcile exactly: 75,173.29 METIS deposited (2024-03-22 → 2026-02-10) − 6,459.435 paid out = 68,713.855; last payout 2026-08-11. All value-moving calls require PAYER_ROLE (one EOA + a 3-of-6 Safe with no modules) and the payee must hold PAYEE_ROLE. Latent risk: the owner EOA can upgrade the UUPS implementation; the same implementation secures a second vault (`0xb8e6D31e…`, 35,193.875 METIS ≈ $118,820) with a different owner.

---

## 3. H-37 · `Mining` `0x7077f35063f17EE1B84678334d261Ccf47980271`

### 3.1 Verified live state (block 23,238,745)

| Check | Value |
|---|---|
| `owner()` | `0x855E37b6068a44BdAb574c86C1817a374623225E` (EOA, also the deployer) |
| `paused()` | **1 (paused)** |
| `poolLength()` | 2 |
| balance | **13,217.96182843 METIS** = 13,217,961,828,430,000,000,000 wei |
| `deposit(...)` from attacker | reverts **`not DAC`** |
| `emergencyWithdraw(0)` from attacker | succeeds (no-op) and pays **0** |
| `withdraw` / `setPaused` / `setMetisPerSecond` from attacker | revert |

### 3.2 The code (deployed source, 1,098 lines, solc 0.6.12)

A MasterChef-style farm with DAC (Decentralized Autonomous Community) integration. **Both pools stake METIS itself** (`poolInfo(0).token = poolInfo(1).token = 0xDeadDeAd…0000`), not LP tokens — this is the key to the correct classification:

- `deposit`/`withdraw`/`dismissDAC` are `onlyDAC` — **the caller must be the DAC contract itself** (`require(msg.sender == address(DAC), "not DAC")`). The DAC contract mediates all user interaction and pulls an equal amount of METIS from the depositor (`safeTransferFrom`), so recorded `user.amount` is always 1:1 collateralized.
- `emergencyWithdraw(pid)` is callable by anyone **only while paused**, and returns the caller's **own** `user.amount` of METIS (then zeroes amount and rewardDebt). It can never exceed the caller's entitlement.
- Rewards do **not** come from this contract's METIS balance: `updatePool` mints via the external `distributor` to `DACRecorder`; user reward claims are paid from the DACRecorder vault. `MetisPerSecond = 0`, `teamAddr = 0`.
- There is **no admin sweep** — the owner can pause/unpause and change addresses, but no function pays the owner or an arbitrary address.

### 3.3 Live invariant — the decisive check

A batched read of `userInfo(pid,user)` for all 4,850 historical participants at block 23,238,720 gives:

```
Σ userInfo[1][user].amount = 13,217,961,828,430,000,000,000 wei
contract METIS balance     = 13,217,961,828,430,000,000,000 wei   (delta = 0 wei)
```

The contract holds **exactly** the stakers' principal — no excess, no shortfall. `emergencyWithdraw(1)` from the largest staker (2,000 METIS) simulates successfully; `withdraw` reverts `paused`; deposits are frozen by `paused=true` since block 751,102 (2022-02-04).

### 3.4 Attack-surface analysis

| Path | Result |
|---|---|
| Attacker with no stake: `emergencyWithdraw` | returns 0 (own amount) |
| Attacker `deposit` → farm | blocked: `onlyDAC` + `paused`; DAC entry pulls 1:1 METIS |
| Attacker `withdraw` / `dismissDAC` | reverts (`paused` / `onlyDAC` / `DAO_OPEN=false`) |
| Owner unpause / parameter change | cannot free principal (no sweep); only redirects future minted rewards |
| Zero-amount deposit harvest | re-bases rewardDebt only; no METIS out |

### 3.5 Verdict

**E-U $0 (high confidence).** The 13,217.96182843 METIS ≈ **$44,626** is **H-O — stakers' principal**, wei-for-wei backed and individually retrievable via `emergencyWithdraw` while paused. Not stuck, not owner-withdrawable. **Latent adjacent risk:** `emergencyWithdraw` zeroes `rewardDebt` without clearing DACRecorder state, so if the owner ever unpauses, users could re-claim pending rewards from the **DACRecorder vault** (105,376.88 METIS) — a latent drain on that separate contract, not on this balance.

---

## 4. H-38 · Netswap pairs A–D

### 4.1 Verified live state (block 23,238,745; factory `0x70f51d68…ff9f`)

| Pair | Pair | reserve0 | reserve1 | LP totalSupply |
|---|---|---|---|---|
| A `0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1` | m.USDT / METIS | 118,441,267,425 (6dp) | 35,117.222266 METIS | 31,909,024,818,890,984 wei |
| B `0x59051B5F5172b69E66869048Dc69D35dB0B3610d` | WETH / METIS | 31.651671 WETH | 25,290.279438 METIS | 589.448711 |
| C `0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091` | METIS / m.USDC | 22,627.157495 METIS | 77,953.1532 m.USDC | 19,059,985,164,448,982 wei |
| D `0x9dAbD9257E55230Fa17415BF9a6946085f533a00` | BANG / METIS | 181,541,968.405 BANG | 10,212.954057 METIS | 1,146,517.186 |

Total pair value ≈ **$596,477** (METIS side ≈ $314,818); m.USDT/m.USDC ≈ $1, WETH ≈ $2,694.16, BANG unpriced (standard OZ ERC20, no rebase/fee functions).

### 4.2 Pair-level attack surface (all fork-verified)

| Path | Result |
|---|---|
| `skim(to)` | token balances are **exactly equal** to reserves on both sides for all four pairs → transfers **0** |
| Pair self-LP (`balanceOf(pair)`) | **0** for all four → no burnable stuck LP |
| `burn(to)` with zero LP | reverts `Netswap: INSUFFICIENT_LIQUIDITY_BURNED` |
| `mint`/`burn` rounding | proportional floor math; no free liquidity |
| Factory `setFeeRate` / `setFeeTo` | revert for non-`feeToSetter` (`0x9C003fdc…dE97`, EOA) |
| Reentrancy | standard `lock` modifier present; standard Uniswap-v2 fork logic |

The deployed pair code is the standard Uniswap-v2 `NetswapPair` (m.USDT/METIS pair source reviewed in full): constant-product with factory `feeRate`, `lock`, `_mintFee`, standard `mint`/`burn`/`swap`/`skim`/`sync`. **No pair-level permissionless extraction exists.**

### 4.3 The LP-supply anomaly (pairs A and C)

Pairs A and C have LP totalSupply that is tiny relative to their reserves (0.0319 LP and 0.0191 LP), while pairs B and D have normal supplies. The LP holder sets are consistent with `totalSupply` (sum of holder balances ≈ supply), the pair contracts hold no excess tokens, and there is no `sync`/donation exploit that yields free value: any LP acquired via `mint` is proportional. The likely history (donations + `sync`, or a past drain followed by re-funding) is reconstructed from Mint/Burn/Sync events in `analysis/h38/dossier.md`. Regardless of the cause, the current state is not attacker-extractable: the reserves belong to the LP holders, and LP cannot be acquired below NAV.

### 4.4 Verdict

**E-U $0 (high confidence) at the pair level.** Value = **H-O**: LP holders' claims on ≈ $596.5k. MasterChef/staking contracts holding these LP tokens are analysed in `analysis/h38/dossier.md`; no permissionless drain found there either *(final verdict pending the child dossier — update on completion)*.

---

## 5. H-41 · Aave V3 Metis aToken `0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8`

### 5.1 Verified live state (block 23,238,745)

| Check | Value |
|---|---|
| name / symbol | `Aave Metis METIS` / `aMetMETIS` |
| underlying / pool | `0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000` (METIS) / `0x90df02551bB792286e8D4f13E0e357b4Bf1D6a57` |
| aToken impl | `0x9ec6457cd8953ac68b5bd612fc64bf8d50df3140` (ATokenInstance) |
| `totalSupply()` | 26,528.057592567194524852 |
| aToken METIS balance (backing) | **26,448.834076746246245959 METIS** |
| variable debt token `0x0110174183…` totalSupply | 79.034953567807543199 METIS |
| reserve configuration | LTV **0**, liqThreshold 40%, bonus 10%, **isFrozen = 1**, borrowingEnabled 1, **flash loans ENABLED** (bit 63 in this v3.5-line revision; premium 5 bps), reserveFactor **99%**, borrowCap 1, supplyCap 1, liquidationProtocolFee 10% |
| `lastUpdateTimestamp` | 1,791,035,563 (recent accrual) |
| bad-debt check (new) | **reserve deficit 0.216680562557106426 METIS** — permanently unbacked (formal bad debt); all 5 reserves carry small deficits |

### 5.2 Attack surface (all fork-verified)

| Path | Result |
|---|---|
| Attacker `Pool.withdraw(METIS, 1e18, attacker)` | reverts custom error `NotEnoughAvailableUserBalance()` (`0x47bc4b2c`) |
| Attacker `Pool.borrow(METIS, …)` | reverts (no collateral) |
| Attacker `aToken.rescueTokens(...)` | reverts (pool-admin gated) |
| New supply / borrow | blocked: all 5 reserves frozen (`ReserveFrozen()`); LTV 0; caps 1 |
| Flash loan | enabled (5 bps premium) but no profitable target: feeds are fresh Chainlink/capped, no donation path |
| Largest METIS borrower `0x24a30823…` | collateral $42,855.24, debt $18,196.68, **healthFactor 1.9547 → not liquidatable** (min HF across all 83 debt holders = **1.45**; zero positions < 1) |
| aToken holders | 4,050 top holders (99.69% of supply): all EOAs except the Aave Collector (548.71 aMetMETIS, governance treasury); largest EOA 4,577.17 (17.25%) |
| Whale self-exit `0xA4C39Bc8…` withdraws max | **succeeds**, receives 4,577.173943729028969480 METIS |

### 5.3 Verdict

**E-U $0 (confidence 0.9).** The 26,448.834 METIS ≈ **$89,295** is **H-O** — withdrawable by the aToken holders themselves (frozen ≠ paused: withdrawals still work; last withdrawal 2026-10-03; the fork test proves a 4,577-METIS holder exit). The 79.035 METIS of variable debt (83 addresses, all EOAs) offsets supply; there are **no liquidatable positions** (min HF 1.45) and no way to create one (all reserves frozen, LTV 0, caps 1, 99% RF, no donation/flash-loan path). **New finding:** the reserve carries a **0.216680562557106426 METIS formal bad debt** (permanently unbacked; ≈$0.73 at the live price) — the only unbacked amount, far too small to be an extraction target. Governance context: Aave ARFC "Low Adoption Asset Deprecation on Aave V3" (2026-07-29), **AIP #521 executed 2026-09-20**, METIS frozen since 2026-03-03; no Metis-specific incident.

---

## 6. Total live extractable now

| Category | Amount | Notes |
|---|---|---|
| **E-U (external unprivileged)** | **≈ $0** | high confidence; every candidate path fork-reverts or pays 0 |
| **H-O (holder self-service)** | **≈ $133,921** | Aave aTokens $89,295 (whale exit fork-proven) + Mining stakers' principal $44,626 (Σ == balance, top-holder exit simulated) + Netswap LP claims (LP-owned market liquidity ≈$596.5k pair value, not counted) |
| **P (privileged)** | **≈ $6,469,603** | H-35 Safe $6,237,615 + H-36 Vault $231,988 (in-scope); +$172,924 sibling Safe/Vault (context, out of scope) |
| **S (stuck)** | **≈ $0** | none found |
---

## 7. PoC / fork verification

- **Project:** `poc/` (Foundry 0.8.24, vendored forge-std) · **Suite:** `poc/test/MetisOrphans.t.sol` — **19 tests**.
- **CI run #1:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37180378111 — 14/14 PASS, fork block 23,238,745, RPC `https://andromeda.metis.io/?owner=1088`.
- **CI run #2 (full suite, includes privileged-path negatives):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37182150552 — **19 passed / 0 failed**.
- Key proofs: H-35 `GS020` revert + no modules (storage walk); H-36 three gated reverts with exact reasons + PAYER_ROLE held only by an EOA and a 3-of-6 Safe; H-37 `not DAC` + `paused` + zero-gain `emergencyWithdraw` + no METIS outflow function; H-38 balances==reserves and `burn` revert + factory setters EOA-gated; H-41 whale self-withdraw success + attacker withdraw revert + borrower HF 1.95.
- All reads are at explicit block numbers; no mainnet transaction was ever constructed or sent.

---

## 8. Verdict & residual risk

The Metis orphan set is **closed to external unprivileged extraction today**. The residual/latent risks are:

1. **Key/role compromise only** for the two Vaults and the Safe cluster (P-value ≈ $6.53M).
2. **H-37's METIS is staker principal** (H-O): wei-for-wei backed, exit via `emergencyWithdraw`; the adjacent DACRecorder reward vault (105,376.88 METIS) carries a latent double-claim if the farm is ever unpaused.
3. **H-41 remains a frozen legacy market** (AIP #521 deprecation, 2026-09-20): any future governance unfreeze (LTV/caps/oracle change) would need re-assessment; currently the only exit is holder withdrawal, and 0.2167 METIS of bad debt is permanently unbacked.
4. **H-38's LP-supply anomaly** (pairs A/C) is a historical artifact; LP holders retain claims; no excess to skim. Watch for MasterChef/staking contract changes.
5. **Related orphans observed (out of scope):** Granary METIS aToken `0x7f5eC43a46dF54471DAe95d3C05BEBe7301b75Ff` holds 9,165.84 METIS (≈$30.9k) in a dead Compound-fork market; the sibling vaults/Safes above. Recommended for a follow-up finding.

## 9. Methodology, caveats, files

- **Method:** on-chain reads via public Metis RPC at pinned blocks; verified sources/ABIs from the Andromeda Blockscout explorer; full manual source review; negative-path simulation (`cast call` with revert-reason capture); fork tests in CI; DefiLlama pricing.
- **Caveats:** (a) partially-verified H-37 source was reviewed line-by-line and its ABI selector set checked — no METIS-moving selector exists; (b) "E-U $0" is a claim about *code paths*, not about key compromise or future upgrades; (c) LP anomaly reconstruction is historical and does not affect extractability; (d) prices are point-in-time.
- **Files:** `analysis/recon_state.json`, `analysis/ci_evidence.md`, `analysis/usd_table.json`, per-target dossiers in `analysis/h35…h41/`, `poc/`, `ci-log.txt`, `summary.json`.

*Read-only; no mainnet transactions. PoC verified on forks only.*
