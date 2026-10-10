# NAVI Sui — version-gate analysis (all package versions)

Static analysis of Move bytecode disassembly fetched from the public Sui mainnet GraphQL endpoint. For every published version of the main lending lineage, the oracle lineage and lineage C, the same-package call graph was built and each function was checked for a transitive version-gate check (`*::version_verification` / `version::pre_check_version` / inline `version: u64` LdConst+Eq). See `gate_scan.py` and `gate-analysis.json` for raw detail.

Live objects today: Storage `0xbb4e...42fe` version=16, IncentiveV2 `0xf87a...559c` version=16, IncentiveV3 `0x6298...6c80` version=16.

## Main lending lineage

| v | package | gate | expected | modules | pub/entry | ungated pub/entry | of which stubs | ungated value-moving |
|---|---------|------|----------|---------|-----------|-------------------|----------------|----------------------|
| 1 | `0xd899cf7d...4c81ca` | inline | 2 | 11 | 105 | 86 | 0 | 9 |
| 2 | `0xcd265ef8...156d33` | inline | 2 | 11 | 106 | 87 | 0 | 9 |
| 3 | `0xd92bc457...82f6d5` | inline | 3 | 11 | 106 | 87 | 1 | 9 |
| 4 | `0xb2345915...2c1aa0` | inline | 3 | 11 | 107 | 88 | 1 | 9 |
| 5 | `0x0440aedc...53bb8b` | inline | 3 | 11 | 107 | 88 | 1 | 9 |
| 6 | `0x81be4913...04639c` | inline | 5 | 11 | 111 | 92 | 2 | 9 |
| 7 | `0xf5f8e3dc...112105` | inline | 5 | 11 | 111 | 92 | 2 | 9 |
| 8 | `0x461364d0...7820f6` | inline | 5 | 11 | 111 | 92 | 2 | 9 |
| 9 | `0xe66f07e2...f31b65` | inline | 6 | 12 | 146 | 119 | 6 | 15 |
| 10 | `0x66c91a85...479bb7` | inline | 6 | 13 | 153 | 122 | 6 | 15 |
| 11 | `0x3e8e806c...17616c` | inline | 6 | 13 | 153 | 122 | 6 | 15 |
| 12 | `0xdd01308c...f0e2b0` | inline | 6 | 13 | 157 | 124 | 6 | 16 |
| 13 | `0xd92d9db3...0205f3` | inline | 6 | 13 | 159 | 126 | 6 | 16 |
| 14 | `0x06007a2d...965edd` | constants | 7 | 18 | 205 | 165 | 8 | 16 |
| 15 | `0x9b3f4332...8c243e` | constants | 8 | 18 | 205 | 165 | 8 | 16 |
| 16 | `0x7c9b90b3...94442d` | constants | 8 | 18 | 207 | 165 | 8 | 16 |
| 17 | `0x2c256d2a...fa7063` | constants | 9 | 18 | 207 | 165 | 8 | 16 |
| 18 | `0xc6374c7d...c8c1ce` | constants | 10 | 18 | 207 | 165 | 8 | 16 |
| 19 | `0x7d53e260...19e771` | constants | 10 | 18 | 207 | 165 | 8 | 16 |
| 20 | `0x66aa3335...0027e1` | constants | 11 | 18 | 207 | 165 | 8 | 16 |
| 21 | `0x834a8697...9ddca3` | constants | 12 | 18 | 213 | 167 | 8 | 16 |
| 22 | `0x81c40844...95c18f` | constants | 13 | 19 | 264 | 204 | 23 | 22 |
| 23 | `0xee004123...6518e0` | constants | 14 | 20 | 300 | 223 | 23 | 30 |
| 24 | `0x1e4a13a0...7259cb` | constants | 15 | 21 | 354 | 259 | 26 | 29 |
| 25 | `0xc37b8136...fa2339` | constants | 15 | 21 | 355 | 259 | 26 | 29 |
| 26 | `0x512f2826...e6833a` | constants | 16 | 21 | 355 | 259 | 26 | 29 |

## Oracle lineage

| v | package | gate | expected | modules | pub/entry | ungated pub/entry | of which stubs | ungated value-moving |
|---|---------|------|----------|---------|-----------|-------------------|----------------|----------------------|
| 1 | `0xca441b44...fd210f` | inline | 1 | 1 | 6 | 1 | 0 | 1 |
| 2 | `0x1951eff0...6901ad` | inline | 1 | 1 | 7 | 2 | 0 | 2 |
| 3 | `0xc2d49bf5...2d5a83` | constants | 2 | 13 | 147 | 117 | 1 | 2 |
| 4 | `0x203728f4...3f6242` | constants | 3 | 14 | 158 | 124 | 3 | 2 |
| 5 | `0x4837ae94...148bea` | constants | 4 | 14 | 167 | 133 | 12 | 2 |

## Lineage C

| v | package | gate | expected | modules | pub/entry | ungated pub/entry | of which stubs | ungated value-moving |
|---|---------|------|----------|---------|-----------|-------------------|----------------|----------------------|
| 1 | `0xa49c5d1c...a8af26` | inline | 6 | 12 | 146 | 119 | 6 | 15 |
| 2 | `0x1125009b...7833db` | inline | 6 | 13 | 153 | 122 | 6 | 15 |
| 3 | `0x7a36940c...be2566` | inline | 6 | 13 | 159 | 126 | 6 | 16 |
| 4 | `0x70eecfcc...88a55d` | constants | 7 | 18 | 205 | 165 | 8 | 16 |
| 5 | `0x7b602f77...394db1` | constants | 8 | 18 | 207 | 165 | 8 | 16 |
| 6 | `0x842c0f00...e4fb30` | constants | 9 | 18 | 207 | 165 | 8 | 16 |
| 7 | `0x79d35901...997b1f` | constants | 10 | 18 | 207 | 165 | 8 | 16 |
| 8 | `0xb473a35e...784eb0` | constants | 10 | 18 | 207 | 165 | 8 | 16 |
| 9 | `0xc6359ef3...9d8889` | constants | 10 | 18 | 207 | 165 | 8 | 16 |
| 10 | `0x239b6bf3...e8f2d9` | constants | 11 | 18 | 211 | 165 | 8 | 16 |
| 11 | `0x0e1cc55f...887d9c` | constants | 11 | 18 | 213 | 167 | 8 | 16 |
| 12 | `0x91740d0b...21b92c` | constants | 12 | 18 | 213 | 167 | 8 | 16 |
| 13 | `0xacc64a32...b387b9` | constants | 13 | 19 | 264 | 204 | 23 | 22 |
| 14 | `0x2550b153...e8cda1` | constants | 12 | 19 | 264 | 204 | 23 | 22 |
| 15 | `0x8200ce83...f3395e` | constants | 13 | 19 | 264 | 204 | 23 | 22 |
| 16 | `0x2efd8c1b...48db41` | constants | 13 | 19 | 265 | 204 | 23 | 22 |
| 17 | `0x4fe00693...fb01c8` | constants | 13 | 20 | 300 | 222 | 23 | 30 |
| 18 | `0xef18e10d...843386` | constants | 14 | 20 | 300 | 222 | 23 | 30 |
| 19 | `0x6e9f8bce...162ab7` | constants | 14 | 20 | 301 | 223 | 23 | 30 |
| 20 | `0x20cb20ed...2a6341` | constants | 14 | 20 | 302 | 223 | 23 | 30 |
| 21 | `0xc371fc61...120c64` | constants | 15 | 21 | 356 | 261 | 26 | 29 |

## Ungated value-moving functions (complete list, all lineages)

Grouped by function signature; every scanned version that contains the function is listed. Entries of any visibility are shown (friend/private ones are not externally callable).

- `incentive::base_claim_reward` — visibility: private, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v3–v21; main v12–v26
- `incentive::claim_reward` — visibility: public, entry: yes; value calls: balance::split, coin::from_balance, transfer::public_transfer; capability args: none; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v2; main v1–v11
- `incentive::claim_reward` — visibility: public, entry: yes; value calls: coin::from_balance, transfer::public_transfer; capability args: none; transfer::public_transfer on Coin/Balance — present in: lineage_c v3–v21; main v12–v26
- `incentive_v2::add_funds` — visibility: public, entry: no; value calls: balance::join; capability args: OwnerCap — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::create_and_transfer_owner` — visibility: public, entry: no; value calls: transfer::public_transfer; capability args: OwnerCap — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::decrease_balance` — visibility: private, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::withdraw_funds` — visibility: public, entry: no; value calls: balance::split, coin::from_balance, transfer::public_transfer; capability args: OwnerCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v21; main v9–v26
- `incentive_v3::base_claim_reward_by_rule` — visibility: private, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::deposit_borrow_fee` — visibility: private, entry: no; value calls: balance::join, balance::split; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::deposit_reward_fund` — visibility: friend, entry: no; value calls: balance::join; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::withdraw_reward_fund` — visibility: friend, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v13–v21; main v22–v26
- `manage::deposit_incentive_v3_reward_fund` — visibility: public, entry: no; value calls: coin::split, transfer::public_transfer; capability args: OwnerCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v13–v21; main v22–v26
- `manage::mint_borrow_fee_cap` — visibility: public, entry: no; value calls: transfer::public_transfer; capability args: StorageAdminCap — present in: lineage_c v17–v21; main v23–v26
- `manage::withdraw_incentive_v3_reward_fund` — visibility: public, entry: no; value calls: coin::from_balance, transfer::public_transfer; capability args: StorageAdminCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v13–v21; main v22–v26
- `oracle::create_feeder` — visibility: public, entry: no; value calls: transfer::public_transfer; capability args: OracleAdminCap — present in: oracle v2–v5
- `oracle::init` — visibility: private, entry: no; value calls: transfer::public_transfer; capability args: none — present in: oracle v1–v5
- `pool::deposit` — visibility: friend, entry: no; value calls: balance::join; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `pool::deposit_balance` — visibility: friend, entry: no; value calls: balance::join; capability args: none — present in: lineage_c v1–v21; main v9–v26
- `pool::deposit_treasury` — visibility: friend, entry: no; value calls: balance::join, balance::split; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `pool::direct_withdraw_balance_v2` — visibility: friend, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `pool::init` — visibility: private, entry: no; value calls: transfer::public_transfer; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw` — visibility: friend, entry: no; value calls: balance::split, coin::from_balance, transfer::public_transfer; capability args: none; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw_balance` — visibility: friend, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v1–v21; main v9–v26
- `pool::withdraw_balance_v2` — visibility: friend, entry: no; value calls: balance::join, balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw_reserve_balance` — visibility: friend, entry: no; value calls: balance::split, coin::from_balance, transfer::public_transfer; capability args: PoolAdminCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v16; main v1–v22
- `pool::withdraw_reserve_balance_v2` — visibility: friend, entry: no; value calls: balance::join, balance::split, coin::from_balance, transfer::public_transfer; capability args: PoolAdminCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw_treasury` — visibility: public, entry: no; value calls: balance::split, coin::from_balance, transfer::public_transfer; capability args: PoolAdminCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw_vsui_from_treasury` — visibility: public, entry: no; value calls: coin::from_balance, transfer::public_transfer; capability args: PoolAdminCap; transfer::public_transfer on Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::prepare_before_withdraw` — visibility: friend, entry: no; value calls: balance::join, balance::split, coin::from_balance; capability args: none; returns Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::refresh_stake` — visibility: friend, entry: no; value calls: balance::join, balance::split, coin::from_balance; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::take_vsui_from_treasury` — visibility: friend, entry: no; value calls: balance::split; capability args: none; returns Coin/Balance — present in: lineage_c v17–v21; main v23–v26
- `storage::init` — visibility: private, entry: no; value calls: transfer::public_transfer; capability args: none — present in: lineage_c v1–v20; main v1–v23
- `storage::mint_owner_cap` — visibility: public, entry: no; value calls: transfer::public_transfer; capability args: StorageAdminCap — present in: lineage_c v17–v21; main v23–v26
- `utils::split_coin` — visibility: public, entry: no; value calls: coin::split, transfer::public_transfer; capability args: none; returns Coin/Balance; transfer::public_transfer on Coin/Balance — present in: lineage_c v1–v21; main v1–v26

## Ungated public/entry functions that mutate state (non-stub, `&mut` args)

Full ungated public/entry lists (including read-only getters and immediate-abort stubs) are in `gate-analysis.json` per version. Below: ungated, non-stub public/entry functions that take at least one `&mut` argument, grouped by function.

- `account::set_account_description` — present in: lineage_c v21; main v24–v26
- `account::set_account_name` — present in: lineage_c v21; main v24–v26
- `account::set_last_update_time` — present in: lineage_c v21; main v24–v26
- `account::set_market_balance` — present in: lineage_c v21; main v24–v26
- `calculator::caculate_utilization` — present in: lineage_c v1–v21; main v1–v26
- `calculator::calculate_borrow_rate` — present in: lineage_c v1–v21; main v1–v26
- `calculator::calculate_supply_rate` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::calculate_current_index` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_caculate_utilization` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_calculate_apy` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_calculate_borrow_rate` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_calculate_supply_rate` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_health_factor` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_liquidation_threshold` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_collateral_balance` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_collateral_value` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_health_collateral_value` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_health_loan_value` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_loan_balance` — present in: lineage_c v1–v21; main v1–v26
- `dynamic_calculator::dynamic_user_loan_value` — present in: lineage_c v1–v21; main v1–v26
- `flash_loan::init_config_for_main_market` — present in: lineage_c v21; main v24–v26
- `flash_loan::version_migrate` — present in: lineage_c v4–v21; main v14–v26
- `incentive::add_pool` — present in: lineage_c v1–v21; main v1–v26
- `incentive::claim_reward` — present in: lineage_c v1–v21; main v1–v26
- `incentive::claim_reward_non_entry` — present in: lineage_c v3–v21; main v12–v26
- `incentive::claim_reward_with_account_cap` — present in: lineage_c v3–v21; main v12–v26
- `incentive::earned` — present in: lineage_c v1–v21; main v1–v26
- `incentive::set_admin` — present in: lineage_c v1–v21; main v1–v26
- `incentive::set_owner` — present in: lineage_c v1–v21; main v1–v26
- `incentive_v2::add_funds` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::create_and_transfer_owner` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::create_incentive` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::create_incentive_pool` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::freeze_incentive_pool` — present in: lineage_c v3–v21; main v13–v26
- `incentive_v2::version_migrate` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::withdraw_funds` — present in: lineage_c v1–v21; main v9–v26
- `incentive_v3::get_effective_balance` — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::init_for_main_market` — present in: lineage_c v21; main v24–v26
- `incentive_v3::init_fund_for_market` — present in: lineage_c v21; main v24–v26
- `lending::create_account` — present in: lineage_c v2–v21; main v10–v26
- `logic::calculate_avg_ltv` — present in: lineage_c v1–v21; main v6–v26
- `logic::calculate_avg_threshold` — present in: lineage_c v1–v21; main v6–v26
- `logic::dynamic_liquidation_threshold` — present in: lineage_c v1–v21; main v1–v26
- `logic::is_collateral` — present in: lineage_c v1–v21; main v1–v26
- `logic::is_health` — present in: lineage_c v1–v21; main v1–v26
- `logic::is_loan` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_collateral_balance` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_collateral_value` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_health_collateral_value` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_health_factor` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_health_factor_batch` — present in: lineage_c v1–v21; main v4–v26
- `logic::user_health_loan_value` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_loan_balance` — present in: lineage_c v1–v21; main v1–v26
- `logic::user_loan_value` — present in: lineage_c v1–v21; main v1–v26
- `logic::weighted_user_health_loan_value` — present in: lineage_c v21; main v24–v26
- `manage::create_flash_loan_config` — present in: lineage_c v4–v20; main v14–v23
- `manage::create_flash_loan_config_with_storage` — present in: lineage_c v21; main v24–v26
- `manage::create_incentive_v3` — present in: lineage_c v13–v20; main v22–v23
- `manage::create_incentive_v3_reward_fund` — present in: lineage_c v13–v20; main v22–v23
- `manage::create_incentive_v3_reward_fund_with_storage` — present in: lineage_c v21
- `manage::create_incentive_v3_with_storage` — present in: lineage_c v21
- `manage::deposit_incentive_v3_reward_fund` — present in: lineage_c v13–v21; main v22–v26
- `manage::incentive_v3_version_migrate` — present in: lineage_c v13–v21; main v22–v26
- `manage::init_fields_batch` — present in: lineage_c v17–v20; main v23
- `manage::mint_borrow_fee_cap` — present in: lineage_c v17–v21; main v23–v26
- `manage::withdraw_incentive_v3_reward_fund` — present in: lineage_c v13–v21; main v22–v26
- `oracle::create_feeder` — present in: oracle v2–v5
- `oracle::decimal` — present in: oracle v3–v5
- `oracle::version_migrate` — present in: oracle v1–v2
- `oracle_manage::create_config` — present in: oracle v3–v5
- `oracle_manage::version_migrate` — present in: oracle v3–v5
- `pool::direct_deposit_sui` — present in: lineage_c v17–v21; main v23–v26
- `pool::disable_manage` — present in: lineage_c v17–v21; main v23–v26
- `pool::enable_manage` — present in: lineage_c v17–v21; main v23–v26
- `pool::init_pool_for_main_market` — present in: lineage_c v21; main v24–v26
- `pool::init_sui_pool_manager` — present in: lineage_c v17–v21; main v23–v26
- `pool::refresh_stake` — present in: lineage_c v17–v21; main v23–v26
- `pool::set_target_sui_amount` — present in: lineage_c v17–v21; main v23–v26
- `pool::set_validator_weights_vsui` — present in: lineage_c v17–v21; main v23–v26
- `pool::unstake_vsui` — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw_treasury` — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw_vsui_from_treasury` — present in: lineage_c v17–v21; main v23–v26
- `storage::destory_user` — present in: main v2
- `storage::get_borrow_cap_ceiling_ratio` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_borrow_rate_factors` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_current_rate` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_index` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_liquidation_factors` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_supply_cap_ceiling` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_total_supply` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_treasury_factor` — present in: lineage_c v1–v21; main v1–v26
- `storage::get_user_balance` — present in: lineage_c v1–v21; main v1–v26
- `storage::init_borrow_weight_for_main_market` — present in: lineage_c v21; main v24–v26
- `storage::init_emode_for_main_market` — present in: lineage_c v21; main v24–v26
- `storage::init_for_main_market` — present in: lineage_c v21; main v24–v26
- `storage::is_liquidatable` — present in: lineage_c v17–v21; main v23–v26
- `storage::mint_owner_cap` — present in: lineage_c v17–v21; main v23–v26
- `storage::version_migrate` — present in: lineage_c v1–v21; main v1–v26
- `storage::when_liquidatable` — present in: lineage_c v17–v21; main v23–v26
- `storage::withdraw_treasury` — present in: lineage_c v1–v21; main v1–v26
- `storage::withdraw_treasury_v2` — present in: lineage_c v17–v20; main v23
- `utils::split_coin` — present in: lineage_c v1–v21; main v1–v26
- `utils::split_coin_to_balance` — present in: lineage_c v1–v21; main v1–v26
- `validation::validate_borrow` — present in: lineage_c v1–v21; main v1–v26
- `validation::validate_deposit` — present in: lineage_c v1–v21; main v1–v26
- `validation::validate_liquidate` — present in: lineage_c v1–v21; main v1–v26
- `validation::validate_repay` — present in: lineage_c v1–v21; main v1–v26
- `validation::validate_withdraw` — present in: lineage_c v1–v21; main v1–v26

## Ungated Coin/Balance transfer-or-return flags

- `incentive::base_claim_reward` — visibility: private, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v3–v21; main v12–v26
- `incentive::claim_reward` — visibility: public, entry: yes; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `incentive::claim_reward_non_entry` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v3–v21; main v12–v26
- `incentive::claim_reward_with_account_cap` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: AccountCap — present in: lineage_c v3–v21; main v12–v26
- `incentive_v2::borrow` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::borrow_with_account_cap` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: AccountCap — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::decrease_balance` — visibility: private, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::liquidation` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::repay` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::repay_with_account_cap` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: AccountCap — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::withdraw` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v2::withdraw_funds` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: OwnerCap — present in: lineage_c v1–v21; main v9–v26
- `incentive_v2::withdraw_with_account_cap` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: AccountCap — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::base_claim_reward_by_rule` — visibility: private, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `incentive_v3::withdraw_reward_fund` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v13–v21; main v22–v26
- `manage::deposit_incentive_v3_reward_fund` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: OwnerCap — present in: lineage_c v13–v21; main v22–v26
- `manage::withdraw_incentive_v3_reward_fund` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: StorageAdminCap — present in: lineage_c v13–v21; main v22–v26
- `pool::direct_withdraw_balance_v2` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool::unstake_vsui` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw_balance` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v1–v21; main v9–v26
- `pool::withdraw_balance_v2` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw_reserve_balance` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: PoolAdminCap — present in: lineage_c v1–v16; main v1–v22
- `pool::withdraw_reserve_balance_v2` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: PoolAdminCap — present in: lineage_c v17–v21; main v23–v26
- `pool::withdraw_treasury` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: PoolAdminCap — present in: lineage_c v1–v21; main v1–v26
- `pool::withdraw_vsui_from_treasury` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: no; capability args: PoolAdminCap — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::prepare_before_withdraw` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::take_vsui_from_treasury` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `pool_manager::unstake_vsui` — visibility: friend, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v17–v21; main v23–v26
- `utils::split_coin` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: yes; returns Coin/Balance: yes; capability args: none — present in: lineage_c v1–v21; main v1–v26
- `utils::split_coin_to_balance` — visibility: public, entry: no; transfer::public_transfer on Coin/Balance: no; returns Coin/Balance: yes; capability args: none — present in: lineage_c v1–v21; main v1–v26

## Sanity checks

- PASS: v26 storage::version_verification transitively gated (calls version::pre_check_version)
- PASS: v9 storage::version_verification is inline gate with LdConst 6
- PASS: v9 incentive_v2::claim_reward calls version_verification and is gated

## Reachability context (verified live via public Sui GraphQL)

- Live Storage object `0xbb4e...42fe` type `d899...::storage::Storage`, version field = **16**.
- Live IncentiveV2 object `0xf87a...559c` type `e66f07e2...::incentive_v2::Incentive` (defining pkg = main v9), version field = **16**.
- Live IncentiveV3 object `0x6298...6c80` type `81c40844...::incentive_v3::Incentive` (defining pkg = main v22), version field = **16**.
- Legacy `d899...::incentive::Incentive` object `0xaaf735bf...` still exists and has **no version field** (fields: creator/owners/admins/pools/assets), so no version gate is possible on it; `incentive::claim_reward` operates on it ungated in every version, including current v26.
- Old package versions remain callable on Sui (each version keeps its own package ID); their gate aborts when the live object's version field != the version expected by that package.

## Assessment

Scanned 52 package versions: 852 ungated value-moving function entries (5 distinct names without any capability argument), 8051 ungated public/entry functions of which 543 are immediate-abort deprecation stubs (inert: they abort unconditionally).

Ungated, externally-callable value-moving paths with NO capability argument:
- `incentive::claim_reward` — present in: lineage_c v1–v21; main v1–v26
- `incentive::claim_reward_non_entry` — present in: lineage_c v3–v21; main v12–v26
- `pool::unstake_vsui` — present in: lineage_c v17–v21; main v23–v26
- `utils::split_coin` — present in: lineage_c v1–v21; main v1–v26
- `utils::split_coin_to_balance` — present in: lineage_c v1–v21; main v1–v26

(Private/friend no-capability helpers such as `pool::withdraw`, `pool::deposit_balance`, `incentive::base_claim_reward`, `incentive_v3::deposit_borrow_fee` are not externally callable; they are reachable only from within the package, i.e. through the gated entry paths. The full list is in the value-moving section above.)

**Bottom line:** No old package version exposes an ungated value-moving path that the current version does not also expose: every value-moving entry that touches the versioned live objects (Storage / IncentiveV2 / IncentiveV3, all at version=16) is transitively gated in every old version and aborts on the version check; the remaining ungated, externally-callable value movers are the legacy v1-incentive claim family (`incentive::claim_reward`, `claim_reward_non_entry`, `claim_reward_with_account_cap` — the latter requiring only the user's own AccountCap; all ungated in the current v26 too because the legacy `incentive::Incentive` object has no version field), the caller's-own-coin helpers `utils::split_coin` / `split_coin_to_balance`, and the vSUI redemption `pool::unstake_vsui` (unversioned `Pool<SUI>` / staking objects; user provides their own CERT coin); everything else is either an immediate-abort stub or capability-gated (protocol-held `OwnerCap` / `StorageAdminCap` / `PoolAdminCap`).
