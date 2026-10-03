# BFly Finance — Independent adversarial review (read-only)

Reviewer: independent verification subagent.
Date: 2026-10-03 (UTC). Chain: Starcoin mainnet (`chain_id=1`), RPC `https://main-seed.starcoin.org`.
Scope: attempt to falsify the claim **"no external unprivileged attacker can profitably extract value from the live deployment today"**.

## 1. Verdict

**FALSIFIED.** An external, unprivileged attacker with only STC (new capital, no pre-existing FAI, no keys, no capabilities) can today buy protocol FAI at a deep discount on the live **Starswap** pool (`0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapRouter`) and immediately liquidate the under-collateralized whale vault `0x0c357315f9351540114596324f41006e` through `MarketScript::liquidation`, converting cheap FAI into STC collateral at **111.111 STC per FAI**.

Live, freshly quoted round trip (numbers independent, from `contract.call_v2` on 2026-10-03):

| Step | Amount |
|---|---|
| Swap STC → FAI on Starswap (`swap_exact_token_for_token<STC,FAI>`) | spend **578,099 STC** → receive **12,502.518488819 FAI** |
| Liquidate whale (`cover = 12,502.518488819 FAI`) | seize **1,389,168.720979888 STC** |
| **Net** | **+811,069.72 STC (+140.3% on capital, risk-free in STC terms)** |

The previous analysis assumed *"no DEX market for FAI; all 305 FAI transfers are peer_to_peer_v2"*. That assumption is wrong: **21,413.90 FAI (61% of the non-treasury supply) sits in the live `TokenSwapPair<STC, FAI>` pool and is buyable by anyone**, and the pool's implied FAI price (19.19 STC/FAI spot) is ~5.8× below the 111.11 STC/FAI redemption value the liquidation path pays. The 305 p2p transfers simply do not capture DEX swaps.

## 2. The exploit (exact sequence and preconditions)

Preconditions (all live, all verified):
- Global switch absent/false → `check_global_switch()` passes (Config.txt 27-38, 97-121).
- Whale vault resource is `Vault::Vault<STCVaultPoolA::VaultPool, 0x1::STC::STC>`; `info = [10041, 33,472.927440229 FAI debt, 3,779.505965027 FAI fee, 4,000,000 STC collateral]`; `health_factor_by_address = 0.7158369e18 ≤ 1e18` (liquidatable).
- Starswap pair exists (`swap_pair_exists<STC,FAI> == true`), reserves `X = 410,813,790,911,242` STC atoms, `Y = 21,413,902,183,198` FAI atoms, poundage `(3,1000)` = 0.3%, `get_global_freeze_switch == false`. Last pair activity `last_block_timestamp = 1789592782` (2026-09-16), i.e. a live, recently-used pool.

Steps:

1. (one-time) Accept FAI: `0x1::Account::do_accept_token<0x4ffcc...::FAI::FAI>` (or `TokenSwapRouter::swap_pair_token_auto_accept<STC,FAI>`).
2. `0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapRouter::swap_exact_token_for_token<0x1::STC::STC, 0x4ffcc98f43ce74668264a0cf6eebe42b::FAI::FAI>(signer, 578099000000000, <min_out>)`
   → pays 578,099 STC, receives 12,502.518488819 FAI (exact quote `TokenSwapLibrary::get_amount_out(578099000000000, X, Y, 3, 1000) = 12502518488819`).
3. `0x4ffcc98f43ce74668264a0cf6eebe42b::MarketScript::liquidation(signer, 0x0c357315f9351540114596324f41006e, 12502518488819)`
   → `Liquidation::clip<STCVaultPoolA::VaultPool, STC>` → `STCVaultPoolA::crack` → `Vault::rearrange`:
   - cover `12,502.518 FAI ≤ (debt+fee)/2 = 18,626.215 FAI` (bound verified in bytecode, Liquidation.txt 67-98; live values)
   - seizure `floor(floor(cover·1e18/900000)/1e10) = 1,389,168,720,979,888 STC atoms ≤ 4,000,000 STC collateral`
   - arrangement: victim's STC withdrawn and `deposit_to_self` to attacker (Vault.txt 1047-1054), attacker's FAI withdrawn and used to repay victim debt (Vault.txt 1055-1062).
4. Net: attacker wallet +811,069.72 STC. The seized STC is the same native asset the attacker spent, so the P&L is **denominated in STC and free of external price risk**. STC can be sold on the same DEX (`STC/XUSDT` and `STC/STAR` pairs both exist).

Sensitivity of the optimum (fresh on-chain quotes; profit curve is flat and concave):

| STC spent | FAI received | STC seized | net STC |
|---|---|---|---|
| 400,000 | 10,548.07 | 1,172,008 | +772,008 |
| 520,000 | 11,947.03 | 1,327,448 | +807,448 |
| **578,099** | **12,502.52** | **1,389,169** | **+811,070** |
| 650,000 | 13,105.82 | 1,456,202 | +806,202 |
| 700,000 | 13,479.37 | 1,497,708 | +797,708 |

USD magnitude depends on STC's market value (CoinGecko 2026-10-03: STC ≈ $0.00011112 → capital ≈ $64, profit ≈ $90). The extraction is objectively positive and self-financing; the size is bounded by the pool's FAI reserve and the whale's half-debt.

## 3. Candidate paths examined

### 3.1 Liquidation path — **SUCCEEDS** (with external FAI from Starswap)
- `MarketScript::liquidation` (MarketScript.txt 61-68) → `Liquidation::clip` (Liquidation.txt 23-174).
- HF guard `HF ≤ 1e18` (Liquidation.txt 39-54). Live HF of whale = 0.7158.
- Cover guard: `cover == 0 → cover = (debt+fee)/2`; else `cover ≤ (debt+fee)/2` (Liquidation.txt 55-98).
- FAI balance guard (Liquidation.txt 99-115).
- Formula: `seized = cover·1e18/(value·(100-penalty)) / (1e18·100/scaling)` = `cover·scaling·100/(value·(100-penalty))` = `cover·1e6·100/(1e4·90)` = `cover·111.111...` (Liquidation.txt 128-157). Confirmed against the 9 historical `ClipEvent`s: e.g. event 2 (`collateral=152,740,929,983,732`, `debit=5,521,980,584,493`, `fee=74,019,415,507`) gives ratio `27.29 = 100/(90·price)` → historical oracle ≈ $0.0407/STC, consistent with the deployed formula and penalty=10.
- `STCVaultPoolA::crack` is `public(friend)` (STCVaultPoolA.txt 106), reachable only from Liquidation; `Vault::rearrange` is `public(friend)` (Vault.txt 1008). No arbitrary-argument call is possible.
- Capacity check: 12,502.5 FAI cover ≤ 18,626.2 FAI half-debt; 1,389,169 STC seized ≤ 4,000,000 STC collateral. A single `clip` call executes the whole trade; the attacker does not need a vault of their own.

### 3.2 Starswap FAI market — **THE MISSED PATH**
- Pair `0x8c10…::TokenSwap::TokenSwapPair<0x1::STC::STC, 0x4ffcc…::FAI::FAI>` reserves: 410,813.7909 STC / 21,413.9022 FAI (verified both via resource and `TokenSwapRouter::get_reserves`).
- `swap_exact_token_for_token(&signer, u128, u128)` is a public, signer-based, permissionless function (verified with `contract.resolve_function`); `get_global_freeze_switch == false`; 0.3% poundage.
- A different FAI (`0xfe125d…::FAI`) also has a Starswap pair, but it is empty — the live, funded pool is the protocol's FAI (`0x4ffcc…::FAI`).
- The context's FAI-transfer dataset (`fai_transfers.json`, 305 items, all `peer_to_peer_v2`, last Jan-2024) does not include DEX swaps, hence the erroneous "no market" conclusion. Pool FAI = 21,413.90 of 34,935.88 total supply (61% of non-treasury supply).

### 3.3 Minting / borrowing (`Vault::borrow_fai`, `STCVaultPoolA::borrow_fai`, `ETHVaultPoolA::borrow_fai`) — no extraction
- Health check: `amount + fee ≤ maxBorrow(collateral) − existing_debt + 2` (LiquidationHelper.txt 90-110 and 5-35; the `Sub` at bytecode offset 24 of `cal_max_borrow` subtracts existing debt). I verified live: `check_health_factor(amount=0, debt=1e18, fee=0, collateral=1e9)` aborts with arithmetic error inside `cal_max_borrow` (debt subtraction), and `cal_max_borrow(0, 1e9) = 3,333,333` (= collateral value / 3 at ccr 30000). No double-borrow bypass.
- Mint cost 300 STC per 1 FAI (STC pool) / 215 STC (ETH pool); spending that FAI on liquidation returns 111.111 STC. Mint-and-default loses 48–63% of the collateral; the seized amount is always below the locked collateral. No profit without external FAI.

### 3.4 Repay / accounting — no extraction
- `Vault::repay` (Vault.txt 1193-1286): fee-first waterfall, `debt_repaid + fee_repaid == amount` invariant abort 501, principal burned, fee deposited to the admin treasury. Verified empirically: treasury `Treasury::Vault<FAI>` holds 4,822.212531853 FAI ≈ cumulative fees (Σ of 234 unique `RepayEvent` fees = 4,730.16 FAI; Σ principal = 454,112.55 FAI). Correct behaviour, no attacker gain.
- `STCVaultPoolA::repay_fai`/`crack` counter arithmetic (`current_fai_supply -= debt_repaid`, `stc_amount -= seized`) is internally consistent; underflow aborts, reverting the tx.

### 3.5 Lock path (`Vault::lock_lock/lock_borrow/lock_unlock/lock_repay`, `STCVaultPoolB::*`) — dead
- `Vault::lock_lock` requires `Config::get_config_extension<Ty0>()` (Vault.txt 712); **no `VaultPoolConfigExtension` resource exists** at the protocol address (checked `0x1::Config::Config<…VaultPoolConfigExtension<…>>` = absent), so it aborts.
- `Vault::lock_unlock` requires `Vault::SharedTreasuryGetCapability<Ty1>` at admin (Vault.txt 954-962) — **absent**; `Vault::rearrange_lock` requires `SharedSTCTreasuryGetCapability` (Vault.txt 1117-1132) — **absent**; `STCTreasury::Vault` never initialized — absent.
- `STCVaultPoolB` is **not initialized**: no `VaultPool<OneMonth|ThreeMonth|SixMonth|OneYear>` resource exists; `STCVaultPoolB::initialize` is admin-gated (STCVaultPoolB.txt 120-163). Its `crack` is public (STCVaultPoolB.txt 79-110) but dereferences a non-existent `VaultPool<Ty0>` and `LockList`, so it always aborts. Same for `borrow/repay/unlock` (`is_exists` guard aborts).

### 3.6 Treasury / STCTreasury — gated
- `Treasury::deposit` is public (donation only); `Treasury::withdraw` mut-borrows `Vault<Ty0>` at **the caller's own address** (Treasury.txt 76-104) — only the admin has that resource; `Treasury::get_with_capability` needs a `WithdrawCapability` and `create_treasury/initialize` are admin-gated (Treasury.txt 10-22, 51-61). No `SharedTreasuryGetCapability<FAI>` exists, so the 4,822 FAI in the admin treasury is unreachable even by the admin. `STCTreasury::deposit/withdraw` check `is_stc_admin_address` (hard-coded admin) (STCTreasury.txt 11-28, 94-111).
- `FAI::mint_with_cap/burn_with_cap` need capabilities; `FAI::initialize` checks admin (FAI.txt 25-45).

### 3.7 Config / admin paths — gated
- `Config::update_config` aborts (deprecated) (Config.txt 240-245); `update_config_sign` checks `is_admin_address` (Config.txt 246-259); `set_global_switch` checks admin (Config.txt 176-201); `publish_new_config_with_capability` / `publish_new_extension_config_with_capability` check admin (Config.txt 142-175).
- `Admin::is_admin_address` is an unconditional abort for any address ≠ `0x4ffcc…` (Admin.txt 10-22). No role/multisig trick.
- Global switch resource is absent → `get_global_switch()` = false → all `check_global_switch()` gates pass (protocol is live, not frozen).

### 3.8 TestHelper / InitializeScript — dead or harmless
- `TestHelper::set_timestamp(u64)` is unauthenticated but borrows `TestHelper::GenesisSignerCapability` at `0x1` (TestHelper.txt 229-243); **that resource does not exist at `0x1` or at the protocol address** (`contract.get_resource` = null), so it aborts.
- `TestHelper::update_price` needs `UpdateCapability<STCUSD>` (held only by the oracle account); `mint_stc_to`/`deposit_stc_to` need an STC `MintCapability` signer (not obtainable); `init_oracle` only creates a data source at the caller's address, which the protocol never reads.
- `InitializeScript::{initialize, initialize_eth_pool_a, initialize_stc_pool_b}` all reach admin-gated callees (`FAI/Vault/pool initialize` check `is_admin_address`); `init_eth_pool_event` aborts unconditionally.

### 3.9 Oracles — fresh, not attacker-controllable
- STC `PriceNumber = (10000, 1000000)` → $0.01; `OracleFeed<STCUSD>` updated at ms 1791043734840 (minutes before review). ETH = (267,918,389,616 / 1e8) ≈ $2,679.18, also fresh. Only `0x82e3…` holds the `UpdateCapability`. No within-tx manipulation path (no callback hooks in the protocol).

### 3.10 Other paths checked, no extraction
- **ETH-pool liquidation is a silent no-op**: `clip` gates the collateral transfer on `is_same_token<Ty1, STC>` (Liquidation.txt 158-168), so `clip<ETHVaultPoolA::VaultPool, XETH>` only checks HF/balance. Not exploitable, but it means the ETH pool (7.008 FAI debt) cannot be liquidated at all.
- **Mixed-type vaults** (`Vault::create_vault/borrow_fai<ETHVaultPoolA::VaultPool, STC>` etc. called from a custom script) bypass pool counters, but the health check still enforces ≥215–300% collateral, so no free mint; at worst it can wedge `crack` accounting into an abort.
- **Self-liquidation** is value-neutral: pay c FAI, debt −c, collateral −1.111c, wallet +1.111c, FAI −c → Δ0.
- **Rounding/overflow**: two truncating divisions in `clip` round the seizure *down* (favours the protocol); all arithmetic is checked and aborts on underflow. No favourable rounding found.
- **Un-enumerated vaults**: live `current_fai_supply` (34,928,867,248,789) exactly equals the sum of the 158 enumerated STC-vault principal debts; therefore the 28–31 early `CreateVaultEvent` ids missing from `all_vaults2.json` cannot carry debt. (They do explain the ~9.8M STC gap between the pool's `stc_amount` and enumerated collateral, together with direct `Vault::withdraw` calls; not exploitable.)
- **`LiquidationHelper`/`Math`/`Rate`/`Exponential`/`U256`** are pure/view helpers; no signer, no resource moves.

## 4. Uncertainties / caveats

1. **Front-running**: steps 2–3 are separate transactions on Starcoin; a competitor could observe the swap and liquidate first. This does not rescue the claim — at least one unprivileged party can extract; and the pool has been untouched for 17 days, so the race is currently uncontested. `amount_out_min` protects the swapper.
2. **USD magnitude**: profit is +811,069.72 STC. At CoinGecko's STC price ($0.00011112) that is ≈ $90 on ≈ $64 capital; at the protocol's own oracle ($0.01/STC) it would be ≈ $8.1k. Either way the STC-denominated extraction is strictly positive and real.
3. **Pool liquidity is the binding constraint**: the optimum buys ~12.5k of the 21.4k FAI, after which the pool's marginal price reaches the 111.11 STC/FAI break-even. The whale has enough remaining debt (24,749 FAI) and collateral (2.61M STC) that the only cap is FAI supply. Total live extraction available via this route ≈ 0.8–0.9M STC.
4. **Data artifacts**: `analysis/explorer/fai_transfers.json` (p2p transfers only) and `all_vaults2.json` (158/189 STC vaults) are both incomplete for this question; conclusions built on them ("no market", "only existing holders can seize") are the root cause of the missed path.

## 5. Evidence commands / calls (read-only)

All calls are JSON-RPC POSTs to `https://main-seed.starcoin.org`; no transaction was sent.

```text
node.info                                                             -> main, chain_id 1
contract.call_v2 STCVaultPoolA::info [0x0c3573…]                      -> [10041, 33472927440229, 3779505965027, 4000000000000000, 1791046131]
contract.call_v2 Liquidation::health_factor_by_address type_args [STCVaultPoolA::VaultPool, 0x1::STC::STC] args [0x0c3573…]
                                                                      -> [715836905916171046]   (0.7158 < 1e18 ⇒ liquidatable)
contract.call_v2 STCOracle::usdt_price                                -> [{value:10000, scaling_factor:1000000}] = $0.01/STC
contract.call_v2 STCVaultPoolA::current_fai_supply                    -> [34928867248789]
contract.call_v2 STCVaultPoolA::current_stc_locked                    -> [14060938315319777]
contract.call_v2 STCVaultPoolA::vault_count                           -> [189]
contract.get_resource 0x4ffcc… Treasury::Vault<FAI>                   -> token value 4822212531853 (4,822.21 FAI locked, no WithdrawCapability exists)
contract.get_resource 0x4ffcc… 0x1::Token::TokenInfo<FAI>             -> total_value 34935875723197; scaling 1e9
contract.call_v2 STCVaultPoolA::repay_fai / LiquidationHelper views   -> health-check semantics verified live
(
Starswap:
contract.call_v2 0x8c10…::TokenSwapRouter::swap_pair_exists<STC,FAI>  -> [true]
contract.call_v2 0x8c10…::TokenSwapRouter::get_reserves<STC,FAI>      -> [410813790911242, 21413902183198]
contract.call_v2 0x8c10…::TokenSwapRouter::get_poundage_rate<STC,FAI> -> [3, 1000]  (0.3%)
contract.call_v2 0x8c10…::TokenSwapConfig::get_global_freeze_switch   -> [false]
contract.call_v2 0x8c10…::TokenSwapLibrary::get_amount_out(578099000000000, 410813790911242, 21413902183198, 3, 1000)
                                                                      -> [12502518488819]
contract.get_resource 0x8c10… TokenSwapPair<STC, 0x4ffcc…::FAI>       -> reserves above; last_block_timestamp 1789592782 (2026-09-16)
contract.resolve_function 0x8c10…::TokenSwapRouter::swap_exact_token_for_token
                                                                      -> args [&signer, U128, U128], ty_args [X, Y] (public, permissionless)
)
```

Bytecode references are to the disassembly in `analysis/disasm/` (module/line as cited in §3).
Exploit arithmetic: `seized = floor(floor(12,502,518,488,819·1e18/900,000)/1e10) = 1,389,168,720,979,888`; `net = 1,389,168.72 − 578,099 = +811,069.72 STC`.

## 6. Bottom line

The claim **does not hold**. The protocol's own liquidation path is sound and gated, but the implicit assumption that FAI cannot be acquired below its redemption value is false: the Starswap `STC/FAI` pool sells protocol FAI at ~19 STC spot (vs 111.11 STC redemption through liquidation) to any anonymous signer, with no freeze, and the whale vault has ample liquidatable capacity. An attacker with ~578k STC (≈ $64 at market) can realize ≈ +811k STC in one swap plus one liquidation, draining ~35% of the whale's collateral. This is a live, external, unprivileged, profitable extraction path.
