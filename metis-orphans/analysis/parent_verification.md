# Parent-level independent verification (lead checks)

All reads on Metis Andromeda (1088) via `https://andromeda.metis.io/?owner=1088`, block 23,238,6xx–23,238,7xx, 2026-10-04.
These are the checks the lead ran directly (in addition to the child dossiers) to validate the headline.

## H-35 Safe `0xdd7c49D1bA862b1285710A30E20C2438b13AE532`

- Singleton slot0 = `0xfb1bffc9d739b8d520daf37df666da4c687191ea`; VERSION() = `1.3.0`; threshold = **4**; 6 EOA owners; nonce 17.
- Fallback handler slot = `0x017062a1de2fe6b99be3d9d37841fed19f573804` (canonical CompatibilityFallbackHandler).
- **Module linked-list walk (storage slot 1, SENTINEL = 0x1): terminates immediately → NO MODULES.** Guard slot 8 = 0.
- `execTransaction` with empty signatures reverts `GS020` (fork-verified + eth_call).
- `enableModule` / `addOwnerWithThreshold` / `setGuard` revert for unprivileged caller (fork-verified).
- Sibling Safe `0xeA0f824CbA2A003d599186DA41A8842E2C4Bd964`: 4-of-7, 6/7 owners overlap H-35 owners, 16,025.5 METIS.

## H-36 Vault `0x17A30350771d02409046A683b18Fe1C13cCFC4A8`

- Impl slot = `0xd62dEdee92074458B1C31133E6601CB6b87e844B`; admin/beacon slots = 0.
- `owner()` = `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` (EOA).
- Revert reasons captured by eth_call simulation:
  - `initialize()` → `Initializable: contract is already initialized`
  - `transferEther(...)` → `AccessControl: account … is missing role 0x8ec07e268e32cae7f300b49ad34f20106d088445cb9d9b2d62cbd864638308b2` (`PAYER_ROLE`)
  - `upgradeTo(...)` → `Ownable: caller is not the owner`
- Role membership (proxy reads):
  - `DEFAULT_ADMIN_ROLE`: 2 — `0xd534b9530425E9F32b7281f4FfCcA97203A182aD` (EOA), `0x52c904aB…` (EOA)
  - `PAYER_ROLE` (0x8ec07e26…): 2 — **`0x96ED493C74e23e4FAAd2409e59eD2d4eC8f64E52` (CONTRACT)**, `0x52c904aB…` (EOA)
  - `PAYEE_ROLE` (0x95ed160e…): 3 EOAs — `0xD6216fC1…9a2c`, `0xC519c75c…B1d5`, `0xE7f7F1e5…9332`
- **`0x96ED493C…` is a GnosisSafeProxy (Safe v1.3.0, singleton `0xf66f5d84c6e094b57efaa3d264f9c38e32fc9cd4`), 3-of-6, owners `0x1caEB632…, 0xad60Ab02…, 0xddFC422f…, 0x52c904aB…, 0xd534b953…, 0xf636bDE8…`; module walk → NO MODULES; guard 0; fallback handler 0.** So the only contract in the money path is itself a multisig — no permissionless trigger.
- Sibling vault `0xb8e6D31e…` same impl, owner `0xc5588FA2…` (EOA), 35,193.875 METIS.

## H-37 Mining `0x7077f35063f17EE1B84678334d261Ccf47980271`

- Full 1,098-line source reviewed by lead. **Correction after child dossier + lead spot-check:** both pools stake **METIS itself** (`poolInfo(0).token = poolInfo(1).token = 0xDeadDeAd…0000`), so `IERC20(pool.token).safeTransfer` IS a METIS transfer. The contract's balance is **staker principal**, not an unreachable reward reserve.
- Lead spot-check at block ~23,238,7xx: Σ `userInfo(1,user).amount` (all 4,850 participants, from `h37/userinfo_all.json`) = **13,217,961,828,430,000,000,000 wei = contract balance exactly (delta 0)**; top staker `0xab917dab…8e43` (2,000 METIS) `emergencyWithdraw(1)` eth_call **succeeds**; `withdraw` reverts `paused`; `deposit` reverts `not DAC`.
- Classification: **H-O (stakers' principal, individually retrievable while paused)**, not S. E-U $0.
- Adjacent latent risk (child): `emergencyWithdraw` zeroes rewardDebt without clearing DACRecorder state → if unpaused, pending rewards (from the DACRecorder vault, 105,376.88 METIS) could be re-claimed. Separate contract; flagged.

## H-38 Netswap pairs

- All four pairs: token balances == reserves on both sides; pair self-LP = 0; `burn` without LP reverts `Netswap: INSUFFICIENT_LIQUIDITY_BURNED`; `skim` transfers 0.
- Pair code reviewed in full (standard Uniswap-v2 fork with factory `feeRate`, `lock`); factory `feeToSetter` = `0x9C003fdcb0815C1Cf4b3bd45220Ee891bBbEdE97` (EOA); `setFeeRate`/`setFeeTo` revert for attacker.
- BANG token (pair D token0) is a standard OZ ERC20 (no rebase/fee functions in ABI).

## H-41 Aave aMetMETIS

- Pool `withdraw` from attacker reverts `NotEnoughAvailableUserBalance()` (`0x47bc4b2c`); whale `withdraw(max)` succeeds (4,577.173943729028969480 METIS) → H-O.
- Reserve config: LTV 0, liqThreshold 40%, bonus 10%, frozen, RF 99%, caps 1, flash loans off.
- Largest METIS borrower `0x24a30823bd87E785B0c4B3803a2bffD91eb6876F`: collateral $42,855.24, debt $18,196.68, HF **1.9547** → healthy.

## CI

- Run #1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37180378111 — 14/14 pass (fork block 23,238,745).
- Run #2 (expanded suite): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37182150552 — **19/19 pass**.
