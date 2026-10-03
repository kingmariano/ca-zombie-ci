# BFly Finance — contract map (deployed at `0x4ffcc98f43ce74668264a0cf6eebe42b`)

30 modules fetched from Starcoin mainnet via `state.list_code` (head 32,904,523) and disassembled in `analysis/disasm/`.

## Core protocol

| Module | Key functions (visibility) | Notes |
|---|---|---|
| `MarketScript` | `create_vault`, `deposit`, `withdraw`, `borrow_fai`, `repay_fai`, `liquidation(addr,cover)`, `lock_*`, ETH variants, `set_global_switch`, `update_config` — all `public entry` | The public entry surface. `liquidation` → `Liquidation::clip`; admin fns assert admin |
| `STCVaultPoolA` | `create_vault`, `deposit`, `withdraw`, `borrow_fai`, `repay_fai`, `crack` (**public(friend)**), views (`info`, `max_borrow`, `current_stc_locked`, …) | STC CDP pool: 14,060,938.315 STC / 34,928.867 FAI / 189 vaults. Events: CreateVault/Deposit/Borrow/Repay/Withdraw/Clip |
| `STCVaultPoolB` | `initialize`, `borrow`, `repay`, `lock_lock`, `unlock`, `crack` | **Never initialized** (no resources) — all paths abort |
| `ETHVaultPoolA` | same shape, collateral `XETH` | 0.011012 ETH / 7.008 FAI / 3 vaults; `crack` **public(friend)** |
| `Vault` | `create_vault`, `deposit`, `withdraw`, `borrow_fai`, `repay_fai`, `info`, `rearrange`/`rearrange_lock` (**public(friend)**), `lock_*` (public), `create_treasury`/`create_stc_treasury` (admin), `initialize` | Per-user `Vault<VaultPoolType, TokenType>` resource holds collateral + debt + fee; `rearrange` is the liquidation settlement path |
| `Liquidation` | `clip`, `clip_b` (public), `health_factor_by_address`, `lock_health_factor_by_address` (views); `cal_max_*`/`check_health_factor` are **deprecated (abort)** | `clip` computes `collateral = cover*1e8/(price*(100-penalty))`, gates HF ≤ 1e18 and cover ≤ half debt+fee, then calls `crack` only when collateral token == STC |
| `LiquidationHelper` | `cal_max_borrow`, `cal_max_withdraw(_v2)`, `check_health_factor`, `min_collateral(_v2)`, `max_borrow`, `to_token_amount`, `token_value_of_usd` | The live health math; `cal_max_borrow = collateral×price×1e4/ccr − fee` |
| `Config` | `get`, `new_config`, `update_config` (**deprecated/aborts**), `update_config_sign` (admin), `set_global_switch` (admin), `get_global_switch`, extension getters | Global freeze switch resource **absent → default false** |
| `Treasury` | `initialize`/`create_treasury` (admin), `deposit` (public), `withdraw` (signer's own vault), `get_with_capability(&cap)` | Admin `Vault<FAI>` holds 4,822.212531853 FAI; **no WithdrawCapability resource exists** |
| `STCTreasury` | `initialize` (admin), `deposit`/`withdraw` (STC-admin), `lock`/`repay`/`get_with_capability` (public(friend)) | **Not initialized** (no resources) |
| `FAI` | `initialize` (admin), `mint_with_cap`/`burn_with_cap` (capability), `deposit_to_treasury`, `treasury_balance` | FAI token; mint cap lives in `Vault::SharedMintCapability` at the admin address |
| `VaultCounter` | `initialize_counter` (admin), `fresh_guid` | guid 10,202 (vault ids 10001–10202) |
| `Rate` | `stability_fee`, `stability_fee_calc`, `rate_per_second` | 3 %/yr simple on debt+fee |
| `Exponential`, `Math`, `U256` | fixed-point helpers | e18 fixed point |
| `Admin` | `admin_address` = 0x4ffcc…, `is_admin_address` (abort guard), `stc_admin_address` = same | |
| `Initialize`, `InitializeScript` | init scripts | Admin-gated / already executed |
| `PriceOracle`, `STCOracle`, `ETHOracle`, `FAIOracle`, `Price` | views | STC from `0x1::STCUSDOracle` feed; FAI hardcoded $1 |
| `Test*` (6 modules) | test-only | Deployed but inert (no GenesisSignerCapability at 0x1) |

## External contracts relevant to extraction

| Contract | Address | Role |
|---|---|---|
| Starswap `TokenSwapPair<STC, FAI>` | `0x8c109349c6bd91411d6bc962e080c4a3` | **The arb venue**: 410,813.79 STC / 21,413.90 FAI; 0.3 % fee; freeze off |
| Starswap `TokenSwapPair<STC, XUSDT>` | same | USD exit: 3,889,384.28 STC / 4,520.87 XUSDT |
| Starswap `TokenSwapPair<STC, STAR>` | same | 2,160,692.98 STC / 12,626,630.51 STAR (no USD pair) |
| Starswap `TokenSwapRouter` / `TokenSwapLibrary` | same | Public swaps + view quotes (`get_amount_out`, `get_reserves`) |
| Oracle account | `0x82e35b34096f32c42061717c06e44a59` | Holds `Oracle::UpdateCapability<STCUSD>`; only updater |

## Value-bearing resources at the admin account (live)

- `STCVaultPoolA::VaultPool`: id 10, current_fai_supply 34,928.867248789 FAI, vault_count 189, stc_amount 14,060,938.315319777 STC (STC itself sits in users' `Vault` resources)
- `ETHVaultPoolA::VaultPool`: 7.008 FAI debt, 0.01101153 ETH
- `Treasury::Vault<FAI>`: 4,822.212531853 FAI (no withdraw path)
- `Token::TokenInfo<FAI>`: total supply 34,935.875723197 FAI
- `Vault::Vault<STCVaultPoolA::VaultPool, STC>` (admin's own vault): dust (0.00052 STC, 0.0000184 FAI debt)
- `Vault::SharedMintCapability`, `Vault::SharedBurnCapability` (module-owned capability holders)
- `VaultCounter::Counter`: guid 10,202
- Absent: `Treasury::Vault<STC>`, `VaultPoolConfigExtension<…>`, `STCTreasury::*`, `SharedTreasuryGetCapability` — these absences close the lock/treasury paths
