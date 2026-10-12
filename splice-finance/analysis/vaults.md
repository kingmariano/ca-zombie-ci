# Splice Finance — Blast ERC4626 backing vaults: liveness & exploitability deep-dive

**Task:** subagent deep-dive for the Splice Finance L2 zombie-hunt (Blast, chainid 81457).
**Scope:** the five ERC4626 vaults backing the big Blast SY positions — are they (a) live and fully
redeemable by holders (H-O), (b) dead/paused/partially stuck (S), or (c) exploitable by an
unprivileged attacker (E-U)?
**Method:** read-only. Public keyless RPCs (`https://rpc.blast.io`, `https://blast.drpc.org`,
`https://blast-rpc.publicnode.com`), Etherscan V2 (Blast) for sources/logs, DefiLlama for prices,
web research for incidents. **No transactions were signed or sent; no private keys used.**
**Pinned block for all final numbers: Blast `41,477,200`** (2026-10-12 00:16:55 UTC).
Secondary reads used blocks 41,475,829–41,476,600 (same-day); noted where relevant.
**DefiLlama prices** (ts 1791762785, 2026-10-11 23:53 UTC): USDB = **$1.00146**, WETH = **$2,535.27**.

---

## TL;DR — verdicts

| # | Vault | Asset | Vault book value | SY claim (book) | Redeemable **now** | Verdict | Category |
|---|-------|-------|------------------|-----------------|--------------------|---------|----------|
| 1 | hUSDB `0x390b781BAf1e6Db546cF4e3354b81446947838d2` | USDB | 343,696.924 USDB ($344,198.72) | 341,148.653 USDB ($341,646.73) | **341,148.653 USDB** | **LIVE-REDEEMABLE** | H-O |
| 2 | hWETH `0x1856C7e0B559E9d7287473CB4b4786398Db4032A` | WETH | 40.6757 WETH ($103,123.80) | 40.21457 WETH ($101,954.72) | **40.21457 WETH** | **LIVE-REDEEMABLE** | H-O |
| 3 | wUSDB `0x4BeD2A922654cAcC2Be974689619768FaBF24855` | USDB | 163,243.246 USDB ($163,481.58) — **book only** | 14,338.183 USDB ($14,359.12) | **0** (reverts `InsufficientBalance`) | **DEAD-STUCK** | S |
| 4 | sWETH `0x8A444bF22B490fCcee46959678F070256F06729A` | WETH | 2.521838 WETH ($6,393.53) | 2.521838 WETH ($6,393.53) | **2.521838 WETH** | **LIVE-REDEEMABLE** | H-O |
| 5 | sUSDB `0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9` | USDB | 2,848.985 USDB ($2,853.14) | 2,848.985 USDB ($2,853.14) | **2,848.985 USDB** | **LIVE-REDEEMABLE** | H-O |

**E-U (extractable by an unprivileged attacker): $0.00 — no profitable path found for any of the five vaults**
(proof and math in §5). **H-O (holder self-service redemptions, verified by live `eth_call` execution): $452,848.13.**
**S (stuck): $14,359.12** in the SY-wUSDB claim (the whole wUSDB vault book of **$163,481.58** is unredeemable).
**P (privileged-only): the Wasabi recovery EOA may one day route recovered funds into the drained vault; nothing is fundable today.**

Key structural facts:
- The 4 live vaults are **standard ERC4626 with `totalAssets() = balanceOf(asset)`** (Hyper vaults verified;
  Splice vaults unverified but selector/behavior-identical, §3.4) and hold **cash == totalAssets to the wei**.
- The wUSDB vault is a **Wasabi vault drained on 2026-04-30** (same attacker as the cross-chain Wasabi
  admin-key compromise): **cash = 0**, `totalAssetValue` = 163,243.246 USDB of book debt now assigned to the
  Wasabi recovery strategy `0xac4eb51b…` which itself holds **0 USDB**. Redemption reverts.

---

## 1. How the claims are wired (SY ↔ vault)

All five SYs are Pendle-style `PendleERC4626SY` wrappers (verified source for HyperUSDBSY / HyperWETHSY /
SpliceWUSDBSY; selector-identical for the two unverified Splice SYs):

- SY `deposit(tokenIn = vault share)` mints **1 SY share per 1 vault share**; `deposit(tokenIn = asset)`
  deposits into the vault and mints vault shares 1:1.
- SY `exchangeRate() = vault.totalAssets() / vault.totalSupply()` — the SY is an oracle-less wrapper of the
  vault share price.
- SY `redeem(...)` burns SY shares and calls `vault.redeem(shares, receiver, SY)` → the vault must pay cash.

**On-chain confirmation that SY shares are exactly 1:1 with vault shares (block 41,477,200):**
`vault.balanceOf(SY) == SY.totalSupply()` for all five vaults (values in §3).

---

## 2. Liveness proof — live `eth_call` redemption simulations (pinned block 41,477,200)

Each simulation executes the **real** `redeem` path against live state (transfers execute; state discarded).
Both the vault-level call (from the SY) and the end-to-end holder-level call (from the actual YT holder,
`SY.redeem(receiver, shares, tokenOut, 0, false)`) were run:

| Vault | Vault-level redeem from SY | End-to-end SY.redeem from YT holder |
|---|---|---|
| hUSDB | ✅ returns `341148653289782259210660` | ✅ YT `0xc878aeb9…` redeems 99,235.683 SY → **110,915.353 USDB** |
| hWETH | ✅ returns `40214570880327105834` | ✅ YT `0x22c1c2f9…` redeems 28.767067 SY → **30.989272 WETH** |
| wUSDB | ❌ reverts **`InsufficientBalance`** | ❌ YT `0xaa1ed686…` redeem 9,515.587 SY → **reverts `InsufficientBalance`** |
| sWETH | ✅ returns `2521837675382966583` | ✅ YT `0x67f704a8…` redeems 1.080243 SY → **1.153813 WETH** |
| sUSDB | ✅ returns `2848985254928941850129` | ✅ YT `0x01b62ec2…` redeems 868.962 SY → **946.432 USDB** |

Corroborating **actual Redeem events** on Blast:
- SY-hUSDB: 7 redemptions in the last ~600k blocks; latest at block **41,472,368** (2026-10-11 21:35 UTC — ~2.5h before the pinned block). Frequent redemptions over the vault's life (100+ events in blocks 34.00M–34.86M alone).
- SY-hWETH: 7 redemptions in the last ~600k blocks; latest at block **41,447,389** (2026-10-11 07:43 UTC).
- SY-sWETH / SY-sUSDB: no redemptions in the last ~600k blocks (low activity), but the live simulations above succeed.
- SY-wUSDB: **0 redeems since the 2026-04-30 drain** (queried from block 34,000,000) — consistent with the vault having no cash.

---

## 3. Per-vault findings (all values at block 41,477,200 unless stated)

### 3.1 hUSDB — "Hyper USDB" — `0x390b781BAf1e6Db546cF4e3354b81446947838d2` — **LIVE-REDEEMABLE (H-O)**

| Field | Value |
|---|---|
| Source | **Verified** `HyperUSDB`, solc 0.8.20, OZ v4.9 `ERC4626` + `BlastPointsManager` (no proxy). Constructor: `ERC4626(IERC20(_USDB))`, `IERC20Rebasing(_USDB).configure(YieldMode.AUTOMATIC)` |
| asset | `0x4300000000000000000000000000000000000003` (USDB, 18 dec) |
| owner | `0x88653cb81db25dA4136448BDf561B41B77b052C4` — **EOA** (no code). Only powers: `initBlastPointsManager`, `configurePointsOperator`, `transferOwnership` (Blast points config only — **no pause, no sweep, no fund access**) |
| totalAssets | `343696924022952959816743` = **343,696.924022952959816743 USDB** |
| balanceOf(USDB) of vault | `343696924022952959816743` — **cash == totalAssets exactly** |
| totalSupply | `307504763172767082942607` = 307,504.763172767082942607 shares |
| price/share | `convertToAssets(1e18)` = `1117696260951417644` (**1.11769626**) — Blast USDB auto-rebase yield accrued |
| SY holder | `0x13293dacab830d8fa2e0e961fb997b3f37186f46` (HyperUSDBSY, verified, `paused=false`) |
| shares held by SY | `305224831833458911953218` = 305,224.831833458911953218 (**99.26%** of vault) |
| previewRedeem(SY shares) | `341148653289782259210660` = 341,148.653289782259210660 USDB |
| maxWithdraw(SY) | `341148653289782259210660` (same; OZ ERC4626 reports book value, not liquidity) |
| Redeem sim | ✅ returns exactly 341,148.653289782259210660 USDB |
| Other claimants | 2,279.931 shares held outside the SY (≈2,551.99 USDB book); no queues (standard ERC4626) |
| **Verdict** | **LIVE-REDEEMABLE — H-O $341,646.73; E-U $0** |

### 3.2 hWETH — "Hyper WETH" — `0x1856C7e0B559E9d7287473CB4b4786398Db4032A` — **LIVE-REDEEMABLE (H-O)**

| Field | Value |
|---|---|
| Source | **Verified** `HyperWETH`, solc 0.8.20, OZ v4.9 `ERC4626` + `BlastPointsManager` (no proxy); WETH configured `YieldMode.AUTOMATIC` |
| asset | `0x4300000000000000000000000000000000000004` (WETH, 18 dec) |
| owner | `0x88653cb81db25dA4136448BDf561B41B77b052C4` — same **EOA** as hUSDB |
| totalAssets | `40675698516182099595` = **40.675698516182099595 WETH** |
| balanceOf(WETH) of vault | `40675698516182099595` — **cash == totalAssets exactly** (grew slightly between block 41,475,829 and 41,477,200 due to WETH rebasing) |
| totalSupply | `37758891361206376882` = 37.758891361206376882 shares |
| price/share | `1077248213233048123` (**1.07724821**) |
| SY holder | `0xb80ad10dffdd415c2159962c1b35ef6edcf1b505` (HyperWETHSY, verified, `paused=false`) |
| shares held by SY | `37330830653189974341` = 37.330830653189974341 (**98.87%** of vault) |
| previewRedeem(SY shares) | `40214570880327105834` = 40.214570880327105834 WETH |
| maxWithdraw(SY) | `40214570880327105834` (same) |
| Redeem sim | ✅ returns exactly 40.214570880327105834 WETH |
| Other claimants | 0.428061 shares outside the SY (≈1,169.08 USD book); no queues |
| **Verdict** | **LIVE-REDEEMABLE — H-O $101,954.72; E-U $0** |

### 3.3 wUSDB — "Wasabi USDB Vault" — `0x4BeD2A922654cAcC2Be974689619768FaBF24855` — **DEAD-STUCK (S)**

| Field | Value |
|---|---|
| Source | **Verified proxy** `ERC1967Proxy` → impl `0xa8516ff9d132ed3a3c352fe04f05fe117bae97ce` = **`WasabiVaultRecoveryV1`** (verified; UUPS). Original logic = `WasabiVault` (OZ v5 upgradeable ERC4626 + PerpManager roles) |
| asset | USDB `0x4300…0003` |
| owner | `0xff2CDb9cdb79A60A31188FE37Bdc6774107cc268` — **Wasabi PerpManager proxy (contract)**; `hasRole(ADMIN_ROLE=0, 0x2eb7f20c38455ae3d5f21d01efea49988e043cc4)` = **true** (Wasabi recovery EOA) |
| totalAssets | `163243246270738143155167` = **163,243.246270738143155167 USDB** — this is `totalAssetValue` **internal bookkeeping**, not cash |
| balanceOf(USDB) of vault | **`0`** — the vault holds no USDB at all |
| totalSupply | `138773314269939199282332` = 138,773.314269939199282332 shares |
| price/share | `1176330241369032231` (**1.17633024**) — **fictional**: book debt, not redeemable cash |
| SY holder | `0xf904fa59d1eacec21d758ccd2fe43261a1dd5470` (SpliceWUSDBSY, verified, `paused=false`, owner EOA `0x04d440CE…`) |
| shares held by SY | `12188909584034137840117` = 12,188.909584034137840117 (**8.78%** of vault) |
| previewRedeem(SY shares) | `14338182953012187618435` = 14,338.182953012187618435 USDB (book) |
| maxWithdraw(SY) | `14338182953012187618435` (same — **misleading**; OZ ERC4626 does not check cash) |
| **Actual redeem** | ❌ **reverts `InsufficientBalance`** (vault-level and end-to-end SY-level) |
| getDepositCap | `1` → `maxDeposit = 0` → **deposits blocked** (post-incident recovery measure) |
| Other claimants | 126,584.405 shares held outside the SY (≈148,905 USDB book) — Wasabi users/treasury; **all equally stuck**. Treasury `0x04d440CE…` also holds 38.307 shares directly |
| **Verdict** | **DEAD-STUCK — S $14,359.12 (SY claim) / $163,481.58 (whole vault book); E-U $0** |

**Incident & recovery timeline (on-chain, Blast):**
- **Drain — block 34,362,930, 2026-04-30 07:54:35 UTC**, tx
  `0xaf0f58cb8e11e5c22189181f703d4ba269cdba9a42ec5659cc7c7544e52850c6`:
  attacker EOA **`0x02228b0afcdbedf8180d96fc181da3af5dd1d1ab`** (the same attacker as the cross-chain Wasabi
  exploit) called its harness `0xd01aD52a0B94BAA0aDa639f2F7035b9d944bE071` (selector `0xe2fba655`) with the
  vault list `[0x8e2b5041… (wWETH), 0x4bed2a92… (wUSDB)]`. The vault emitted
  `StrategyDeposit(strategy=0xe1e6f6d46466f9cff784438a4d726325262c0ca3, collateral=0x0,
  amountDeposited=163243.246280738143155167, collateralReceived=0)` — **the vault's entire USDB cash balance
  was sent to the attacker's strategy** (hence `balanceOf(USDB)=0`).
- Prior history: legit strategy `0xf9d4f4892f9c9a4ddf939166c592efb9be365e91` had deposits 100,000+200,000+200,000+526
  (blocks 19.6M–20.1M) and withdrawals 526+114,624+388,769 (blocks 20.1M–22.2M) — all repaid; not a factor.
- **Recovery upgrade — block 34,471,092, 2026-05-02 19:59:59 UTC**, tx
  `0xbaea1f5415c7994d7beea9b11e3fdd523f954f36037d879f7261566a286306fb`:
  proxy upgraded to `WasabiVaultRecoveryV1` and `StrategyDebtMigrated(from=0xe1e6f6d4…,
  to=0xac4eb51b77856fe3f3c8e128cdbaac8993ede03d, amount=163243.246280738143155167)` — pure bookkeeping.
- **Live state at block 41,477,200:** `strategyDebt(0xe1e6f6d4…)=0`, `strategyDebt(0xac4eb51b…)=163243246280738143155167`,
  and the recovery strategy's own balances: **USDB = 0, WETH = 0**. No funds have been routed back.
- The same attacker tx list also drained the sibling Blast vault **wWETH `0x8e2b50413a53f50e2a059142a9be060294961e40`**
  ("Wasabi WETH Vault", cash = 0, book 200.228 WETH) — same pattern.
- Public reporting: Wasabi Protocol admin-key compromise, ~$4.5–5.9M across Ethereum/Base/Berachain/Blast
  (CoinDesk 2026-04-30; Halborn 2026-05-04; Blockaid/CertiK/PeckShield; The Block). Blockaid:
  "All Wasabi/Spicy LP-share tokens … should be treated as COMPROMISED". Splice's `SpliceWUSDBSY` is a
  1:1 wrapper of this drained vault → its 14.3k USDB claim is stranded.

### 3.4 sWETH — "Splice WETH" — `0x8A444bF22B490fCcee46959678F070256F06729A` — **LIVE-REDEEMABLE (H-O)**

| Field | Value |
|---|---|
| Source | **Unverified** (Blastscan has no source). Runtime bytecode analyzed: 33-selector dispatcher; the set is exactly OZ ERC4626 + ERC20 + Ownable + BlastPointsManager (incl. `initBlastPointsManager(address)=0x9f5aff4c`, `configurePointsOperator(address)=0x36b91f2b`, `BLAST_POINTS()=0x4b8f9025`, `previewMint=0xb3d7f6b9`). **No pause/unpause, no sweep/rescue, no upgrade selectors.** Same code as sUSDB (selector sets identical; differs only in immutables/asset) |
| asset | WETH `0x4300…0004` |
| owner | `0x04d440CE29feC9a47Ed471fF0Dc7d002caAdbc66` — **EOA** (Splice treasury; only Blast-points config + `transferOwnership`) |
| totalAssets | `2521837675382966584` = **2.521837675382966584 WETH** |
| balanceOf(WETH) of vault | `2521837675382966584` — **cash == totalAssets exactly** |
| totalSupply | `2361040001101251585` = 2.361040001101251585 shares |
| price/share | `1068104588596570406` (**1.06810459**) |
| SY holder | `0xc28fb4cc69081f9f72c643c47e8fef7b4ab2e7aa` (SY Splice sWETH, `paused=false`) |
| shares held by SY | `2361040001101251585` — **100% of the vault** |
| previewRedeem(SY shares) | `2521837675382966583` = 2.521837675382966583 WETH |
| maxWithdraw(SY) | `2521837675382966583` (same) |
| Redeem sim | ✅ returns exactly 2.521837675382966583 WETH |
| Other claimants | none outside the SY (SY holds 100%) |
| **Verdict** | **LIVE-REDEEMABLE — H-O $6,393.53; E-U $0** |

### 3.5 sUSDB — "Splice USDB" — `0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9` — **LIVE-REDEEMABLE (H-O)**

| Field | Value |
|---|---|
| Source | **Unverified**; same bytecode/selector family as sWETH (see §3.4). No pause/sweep/upgrade |
| asset | USDB `0x4300…0003` |
| owner | `0x04d440CE29feC9a47Ed471fF0Dc7d002caAdbc66` — **EOA** |
| totalAssets | `2848985254928941850130` = **2,848.985254928941850130 USDB** |
| balanceOf(USDB) of vault | `2848985254928941850130` — **cash == totalAssets exactly** |
| totalSupply | `2615781099156029084831` = 2,615.781099156029084831 shares |
| price/share | `1089152779583947264` (**1.08915278**) |
| SY holder | `0x0e999eb7f4e553348703d4ed804079c89e8c92f5` (SY Splice sUSDB, `paused=false`) |
| shares held by SY | `2615781099156029084831` — **100% of the vault** |
| previewRedeem(SY shares) | `2848985254928941850129` = 2,848.985254928941850129 USDB |
| maxWithdraw(SY) | `2848985254928941850129` (same) |
| Redeem sim | ✅ returns exactly 2,848.985254928941850129 USDB |
| Other claimants | none outside the SY (SY holds 100%) |
| **Verdict** | **LIVE-REDEEMABLE — H-O $2,853.14; E-U $0** |

---

### 3.6 Protocol status research (web)

- **Hyper (hUSDB/hWETH):** no hack/rug/pause reports found. Data aggregator records the Hyper USDB vault as
  live with **"Deposit status: Open, Redemption status: Open"**, 41,472 deposit/redemption events, peak TVL
  ~$4.87M and current TVL ~$344.5k (matching our on-chain 343.7k USDB); share price 1.1148 on 2026-08-03
  (matching our 1.1177 today). The owner EOA `0x88653cb8…` last transacted on **2025-08-06** (block
  22,831,937: redeeming from both SYs and moving funds) — the team is inactive, but the vaults remain open
  and users redeem regularly (latest 2026-10-11 21:35 UTC). Small, obscure, abandoned-but-functional.
- **Wasabi (wUSDB):** **hacked 2026-04-30** (deployer admin-key compromise; malicious strategy drain via
  `strategyDeposit`), confirmed by CoinDesk/Halborn/Blockaid/CertiK/PeckShield/The Block; recovery upgrade
  applied 2026-05-02 with debt bookkeeping only; no funds returned so far.
- **Chain context — Blast L2 wind-down (material for exit timing):** Blast announced an **orderly L2
  wind-down on 2026-10-02** (The Block, Decrypt): users are directed to exit assets to Ethereum; normal
  interface withdrawals through **2026-10-26**, after which direct interaction with the Blast bridge
  contracts on Ethereum L1 remains possible; USDB is in "winding down" status with bridge-based DAI exit.
  This is a **chain-level, time-bounded exit risk on top of the vault-level verdicts**: the four live
  vaults can be redeemed for USDB/WETH on Blast right now, but converting USDB to Ethereum value depends on
  the Blast bridge wind-down process. It does not create any unprivileged extraction path (E-U remains $0).

---

## 4. Claimant map (who ultimately owns the SY claims) — block 41,477,200

| Vault | SY totalSupply | YT holds | Market 1 | Market 2 | Treasury EOA | Other users |
|---|---|---|---|---|---|---|
| hUSDB | 305,224.832 | 99,235.684 | 478.291 | 3,543.401 | 0 | ~201,967 |
| hWETH | 37.330831 | 28.767068 | 0.179821 | 3.863981 | 0 | ~4.520 |
| wUSDB | 12,188.910 | 9,515.587 | 2,232.251 | — | 49.228 | ~391.844 |
| sWETH | 2.361040 | 1.080243 | 1.276409 | — | 0.000405 | ~0.004 |
| sUSDB | 2,615.781 | 868.962 | 360.216 | — | 325.398 | ~1,061.206 |

Markets: hUSDB → `0x6b61cfce…` & `0x258133c3…` (PT Hyper hUSDB 27JUN2024, expired); hWETH → `0xb9612af2…` &
`0xaa09cff2…` (PT Hyper hWETH 27JUN2024); wUSDB → `0x0f2a202c…` (PT Splice wUSDB 18AUG2024);
sWETH → `0xeff6adf7…` (PT Splice sWETH 25SEP2024); sUSDB → `0x9e8ade40…` (PT Splice sUSDB 25SEP2024).
YT/market/treasury balances were read directly (`balanceOf`), see `analysis/claimants.json`.
None of the vaults use withdrawal queues; the four live vaults' cash covers **all** outstanding shares
(vault totalAssets == cash), so there is no first-come-first-served shortfall risk.

---

## 5. Exploitability analysis (E-U) — why an unprivileged attacker extracts nothing

### 5.1 What the vaults are
- **hUSDB / hWETH (verified):** OZ **v4.9** `ERC4626` + `BlastPointsManager`. `totalAssets()` =
  `asset.balanceOf(this)`. `_convertToShares` uses OZ v4.9 virtual-offset formula
  `assets·(totalSupply + 10^decimalsOffset) / (totalAssets + 1)` with `decimalsOffset = 0`.
  Only owner functions: `initBlastPointsManager`, `configurePointsOperator` (Blast points config) —
  **no pause, no fees, no caps, no sweep, no rescue**.
- **sWETH / sUSDB (unverified):** selector-identical family (OZ ERC4626 + Ownable + BlastPointsManager);
  `totalAssets() == balanceOf(asset)` to the wei for both (checked), consistent with standard OZ
  `totalAssets()`. Same conclusion: no pause/sweep/fund-moving owner function; deposits/withdrawals open.
- **wUSDB (verified):** Wasabi `ERC4626Upgradeable` where `totalAssets()` = **internal** `totalAssetValue`.
  Admin functions exist (`strategyDeposit/Withdraw/Claim`, `donate`, `cleanDust`, UUPS upgrade) but are
  `onlyAdmin`/role-gated and the vault holds **0 assets**; `donate` is role-gated. `maxDeposit = 0`.

### 5.2 Donation / share-price inflation
For the four live vaults, `totalAssets()` tracks the token balance, so a direct transfer ("donation") raises
the share price. **This cannot be turned into profit by an unprivileged attacker:**
- Donating `X` raises the price by factor `(T+X)/T` where `T = totalAssets` (T is 343.7k USDB / 40.7 WETH /
  2.52 WETH / 2.85k USDB). The attacker's own shares gain exactly the same factor, so their net change is
  `+X·a − X = −X·(1−a)` where `a` = attacker's share fraction (<1). **Strictly a loss.**
- The first-depositor inflation attack is structurally unavailable: all four vaults are **non-empty**
  (totalSupply 2.36–307.5k shares) and OZ v4.9 virtual shares/assets (offset 0) make the classic attack
  non-profitable even on empty vaults (per OZ's own analysis).
- Rounding: deposit rounds shares down, withdraw rounds assets up — both favor the vault; no round-trip gain.
- The SY layer does not change this: SY shares are 1:1 with vault shares (proven above), so any SY-side
  action still requires owning vault-share-backed value; the SY `exchangeRate()` is just the vault price.
- Reentrancy: USDB/WETH have no transfer hooks (no ERC777 callbacks); no external call between accounting
  and transfer that an attacker can re-enter for gain.
- Cross-layer note (parent scope): a donation would also raise the SY `exchangeRate()`. Any Pendle-market
  angle (expired 2024 markets) would still require the attacker to own the PT/YT/LP claims and would
  capture only their own share of the donated value — economically identical to the loss above. **No
  profitable path was found; the parent may verify market-level mechanics separately.**

### 5.3 wUSDB — no extractable value at all
- Vault holds **0 USDB**; every ERC4626 `withdraw`/`redeem` reverts (`InsufficientBalance`) — verified by
  live simulation at the pinned block.
- Deposits blocked (`getDepositCap = 1`). `donate`/`cleanDust`/`strategyWithdraw` are role-gated.
- No withdrawal queue, no pending claims, no allowances held by the vault (none granted).
- The only "value" is the recovery-strategy debt entry — an off-vault book claim controlled by the Wasabi
  team (P). Even if the team re-funds it, redemption is via the standard admin path (`strategyWithdraw`),
  not attacker-callable.

### 5.4 Privileged risks (P — not E-U)

**Exact privilege selectors (access control):**
- Hyper hUSDB/hWETH (owner EOA `0x88653cb8…`): `initBlastPointsManager(address)=0x9f5aff4c`, `configurePointsOperator(address)=0x36b91f2b` (onlyOwner); Ownable `transferOwnership=0xf2fde38b`, `renounceOwnership=0x715018a6`. **No pause/sweep/rescue/fund selector exists** (verified source).
- Splice sWETH/sUSDB (owner EOA `0x04d440ce…`): same three functions (selector scan: `0x9f5aff4c`, `0x36b91f2b`, Ownable). No pause/sweep/upgrade selectors.
- Wasabi wUSDB (owner = PerpManager `0xff2cdb9c…`; ADMIN_ROLE = recovery EOA `0x2eb7f20c…`): `upgradeToAndCall(address,bytes)=0x4f1ef286` (onlyAdmin), `strategyDeposit(address,uint256)=0x6f799ed8` (onlyAdmin), `strategyWithdraw(address,uint256)=0x5a294bc3` (onlyAdmin), `strategyClaim(address)=0xa9e97500` (onlyAdmin), `donate(uint256)=0xf14faf6f`, `cleanDust()=0x4d9b3509`, `setDepositCap(uint256)=0x86651203`, `setInterestFeeBips(uint256)=0x6d8638d4` (VAULT_ADMIN_ROLE), `initializeRecovery(address,address)=0x2fa5a606` (reinitializer(2)+onlyAdmin, already used). `hasRole(0, recovery EOA)=true` at block 41,477,200.
- SY layer: `SYBase.pause()=0x8456cb59` / `unpause()=0x3f4ba83a` (onlyOwner) block SY transfers **and burns** → can freeze SY-level redemption; `updateSupplyCap(uint256)=0xe5a97f07`. All five SYs currently `paused=false`.

- **SY owners are EOAs** (`0x88653cb8…` for Hyper SYs, `0x04d440ce…` for Splice SYs). `SYBase` has
  `pause()/unpause()` (`onlyOwner`) which blocks SY transfers **and burns** → can freeze SY-level redemption.
  The **vaults themselves have no pause** and remain redeemable by any vault-share holder. Latent P risk.
- **Wasabi wUSDB** owner = PerpManager; the recovery EOA (`0x2eb7f20c…`, `hasRole(0)=true`) can UUPS-upgrade
  the vault. Nothing to extract today (0 cash); matters only if funds are ever recovered into the vault.
- Hyper/Splice owner EOAs have **no vault fund access** (only Blast-points config + ownership transfer).

---

## 6. USD valuation summary

Prices: USDB $1.0014600023601181, WETH $2535.268030369663 (DefiLlama, 2026-10-11 23:53 UTC).

| Item | Amount | USD |
|---|---|---|
| SY-hUSDB claim, redeemable now | 341,148.653289782259210660 USDB | **$341,646.73** |
| SY-hWETH claim, redeemable now | 40.214570880327105834 WETH | **$101,954.72** |
| SY-sWETH claim, redeemable now | 2.521837675382966583 WETH | **$6,393.53** |
| SY-sUSDB claim, redeemable now | 2,848.985254928941850129 USDB | **$2,853.14** |
| **Total redeemable (H-O)** | | **$452,848.13** |
| SY-wUSDB claim, book value (unredeemable) | 14,338.182953012187618435 USDB | $14,359.12 |
| wUSDB whole-vault book (unredeemable) | 163,243.246270738143155167 USDB | $163,481.58 |
| **Stuck (S)** | | **$14,359.12 (SY claim) / $163,481.58 (whole vault)** |
| **E-U (unprivileged extractable)** | | **$0.00** |

---

## 7. Caveats & confidence

- **Confidence: high** on the four live vaults' redeemability (live `eth_call` execution + recent Redeem
  events + cash == totalAssets) and on wUSDB being unredeemable (0 cash + revert + zero Redeem events since
  the drain).
- sWETH/sUSDB vault sources are **unverified**; the conclusion rests on bytecode selector analysis
  (33-selector OZ ERC4626 surface, no pause/sweep/upgrade), exact `totalAssets == balanceOf` equality, and
  successful live redemption simulations. Confidence high, not absolute (a hidden internal-accounting
  variant could exist, but it would not change redeemability since cash == totalAssets and the redeem path
  executed).
- `eth_call` simulations are read-only and non-persistent; they prove the path succeeds at the pinned block
  against live state (including real token transfers). They do not guarantee future blocks if the owner
  pauses the SY or the Wasabi team upgrades the vault.
- USDB and WETH on Blast are rebasing tokens; balances drift continuously (observed between blocks), so
  USD figures move slightly over time.
- The wUSDB situation is **not** a live exploit path — it is an already-realised loss (2026-04-30) that may
  be partially recoverable only through Wasabi's privileged recovery process (no evidence of funding yet).
- No transactions were made; no secrets were written to any file (all scripts read keys from
  `/home/heisenberg/CA/.env` at runtime and only use keyless public RPCs in saved artifacts).

---

## 8. Evidence index (files)

| File | Contents |
|---|---|
| `analysis/vault_probe.py`, `vault_probe_raw.json`, `vault_probe.log` | first full read of all vaults+SYs (block 41,476,529) |
| `analysis/claimants.py`, `claimants.json` | SY/vault claimant balances |
| `analysis/etherscan-vaults/` | Etherscan V2 sources: HyperUSDB/HyperWETH (standard-json), wUSDB proxy + impl (`WasabiVaultRecoveryV1`, `WasabiVault`) |
| `analysis/src-sy/` | SY sources (HyperUSDBSY, HyperWETHSY, SpliceWUSDBSY) |
| `analysis/logs/wusdb_strategy_deposit.json` | all 5 `StrategyDeposit` events incl. the drain (block 34,362,930) |
| `analysis/logs/wusdb_upgraded.json` | full UUPS upgrade history of the wUSDB proxy |
| `analysis/logs/wusdb_debt_migrated.json` | `StrategyDebtMigrated` event (block 34,471,092) |
| `analysis/logs/attacker_txs_blast.json` | attacker EOA txs on Blast (drain + harness calls) |
| `analysis/logs/husdbsy_redeem_latest.json`, `*_redeem_last600k.json` | Redeem-event liveness per SY |
| `analysis/fetch_*.sh` | read-only fetch scripts (keys read from `.env` at runtime, never stored) |

### Exact pinned-block calls (reproducible)
```
cast call <vault> "totalAssets()(uint256)"                         --block 41477200 --rpc-url https://rpc.blast.io
cast call <asset> "balanceOf(address)(uint256)" <vault>            --block 41477200 --rpc-url https://rpc.blast.io
cast call <vault> "balanceOf(address)(uint256)" <SY>               --block 41477200 --rpc-url https://rpc.blast.io
cast call <vault> "previewRedeem(uint256)(uint256)" <SYshares>     --block 41477200 --rpc-url https://rpc.blast.io
cast call <vault> "redeem(uint256,address,address)(uint256)" <SYshares> <SY> <SY> \
     --from <SY> --block 41477200 --rpc-url https://rpc.blast.io
# wUSDB only: the redeem call above reverts with "InsufficientBalance"
```
