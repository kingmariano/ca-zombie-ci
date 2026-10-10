# New Carmine AMM — provenance & IAMM interface (read-only recon)
- Date 2026-10-10 · Starknet mainnet · head block 16152527 · read-only (no txs; keyless RPC).
- Target AMM: 0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9 — Sierra (v0.1.0), NON-proxy but replace_class-upgradeable (upgrade()).
- Class @head: 0x7fb1aa680d9c02e1017d5ed048612630c30d11991d43b3e4e7a22531621cd5c (27866-felt sierra program; 56 external entry points; verified same at block 16150435).

## Provenance (all on-chain, verified)
- 2024-01-09 blk 500525: sister instance 0x1007d87a…2562 deployed with class 0x45fb686c… (see UNKNOWNS).
- 2024-01-12 blk 504056 (ts 1705078858): target deployed with class 0x45fb686c… — tx 0x633b9cf97fa848f2d2918f10aa0070ec89c7564ff23efc3a474f4e405aa49d2, sender 0x74fd7da2…f3067 (Carmine deployer account, class 0x48dd59fa…). Constructor emitted OwnershipTransferred 0x0→0x292a4de0… then 0x292a4de0…→0x74fd7da2… (same tx).
- 2024-10-21 blk 819749 (ts 1729537381): owner 0x74fd7da2… → governance 0x1405ab78… — tx 0x7b7ea7c8d3e77d2a5a7cc614a1985e95b90cfa3962a7200e8595fdd436fc3f8 (sent by 0x74fd7da2…).
- 2025-05-02: class 0x7fb1aa… declared by 0x74fd7da2… — tx 0x78a9d373974b1a19a8e86768c3af21664739e0315e925563092e6ab8736622e, ts 1746175906. Same day as protocol-cairo1 master tip (commit 195dccdd02e8c69e86d94a154bd2231e107b7206, repo last push 2025-05-02).
- 2025-05-14 blk 1399968 (ts 1747206647): contract upgraded to class 0x7fb1aa… — tx 0x74ff7a5acc7595e897b95a7701c20d591ced23f29ac5eed5ea7e1bab9cd6407 invokes governance.apply_passed_proposal (selector 0x3507e241…; sender account 0x6717eaf5…0af) ⇒ upgrade went through governance.
- Source: github.com/CarmineOptions/protocol-cairo1 ("Carmine Options AMM written in C1, version 2.3.1"); deployed ABI == master src/amm_interface.cairo 1:1 (51 IAMM fns; exact commit NOT pinnable — class unverified on Voyager).
- Integrations pointing at target as current AMM: CarmineOptions/fe-app (config-mainnet.json: AMM_ADDRESS=target, GOVERNANCE_ADDRESS=0x1405ab…), CarmineOptions/carmine-api (MAINNET_CONTRACT_ADDRESS), DefiLlama-Adapters/projects/carmine-options (amm=target; legacyAmm=0x076dbabc…), CarmineOptions/amm-governance proposals/tests.

## Owner analysis
- owner() @head = 0x1405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f = CONTRACT (class 0x4bc8bc7c476c4fca95624809dab1f1aa718edb566184a9d6dfe54f65b32b507) = Carmine AMM governance; ifaces konoha::contract::IGovernance, amm_governance::{ICarmineGovernance, IProposals, IUpgrades, IStaking}, konoha::airdrop::IAirdrop; fns submit_proposal/vote/apply_passed_proposal/stake/unstake/… .
- governance get_amm_address() returns 0x1007d87a…2562 (sister), NOT target — inconsistent with fe-app/proposal code; semantics unknown.
- gov token 0x3c0286e9e428a130ae7fbbe911b794e8a829c367dd788e7cfe3efb0367548fa; get_live_proposals()=0.

## Full ABI & per-function gate (56 external fns)
Legend: addr=ContractAddress, fx=Fixed(cubit f128), V=view, EXT=external, ANY=permissionless, OWNER=assert_only_owner, OWNER|h=owner or halt-permitted(address) (can halt, not unhalt).
| function | mut | inputs → outputs | gate |
|---|---|---|---|
| trade_open | EXT | u8,fx,u64,u8,u128,addr,addr,fx,u64 → fx | ANY (halt-gated, reentrancy-guarded) |
| trade_close | EXT | same as trade_open → fx | ANY |
| trade_settle | EXT | u8,fx,u64,u8,u128,addr,addr | ANY |
| is_option_available | V | addr,u8,fx,u64 → bool | ANY |
| set_trading_halt | EXT | bool | OWNER|h |
| get_trading_halt | V | → bool | ANY |
| set_trading_halt_permission | EXT | addr,bool | OWNER |
| get_trading_halt_permission | V | addr → bool | ANY |
| add_lptoken | EXT | addr,addr,u8,addr,fx,u256 | OWNER |
| add_option_both_sides | EXT | u64,fx,addr,addr,u8,addr,addr,addr,fx | OWNER |
| get_option_token_address | V | addr,u8,u64,fx → addr | ANY |
| get_lptokens_for_underlying | V | addr,u256 → u256 | ANY |
| get_underlying_for_lptokens | V | addr,u256 → u256 | ANY |
| get_available_lptoken_addresses | V | felt → addr | ANY |
| get_all_options | V | addr → Array<Option_> | ANY |
| get_all_non_expired_options_with_premia | V | addr → Array<OptionWithPremia> | ANY |
| get_option_with_position_of_user | V | addr → Array<OptionWithUsersPosition> | ANY |
| get_all_lptoken_addresses | V | → Array<addr> | ANY |
| get_value_of_pool_position | V | addr → fx | ANY |
| get_fees_percentage | V | → u128 | ANY |
| get_value_of_pool_expired_position | V | addr → fx | ANY |
| get_value_of_pool_non_expired_position | V | addr → fx | ANY |
| get_value_of_position | V | Option_,u128,u8,fx → fx | ANY |
| get_all_poolinfo | V | → Array<PoolInfo> | ANY |
| get_user_pool_infos | V | addr → Array<UserPoolInfo> | ANY |
| deposit_liquidity | EXT | addr,addr,addr,u8,u256 | ANY |
| withdraw_liquidity | EXT | addr,addr,addr,u8,u256 | ANY |
| get_unlocked_capital | V | addr → u256 | ANY |
| expire_option_token_for_pool | EXT | addr,u8,fx,u64 | ANY |
| set_max_option_size_percent_of_voladjspd | EXT | u128 | OWNER |
| get_max_option_size_percent_of_voladjspd | V | → u128 | ANY |
| get_lpool_balance | V | addr → u256 | ANY |
| get_max_lpool_balance | V | addr → u256 | ANY |
| set_max_lpool_balance | EXT | addr,u256 | OWNER |
| get_pool_locked_capital | V | addr → u256 | ANY |
| get_available_options | V | addr,u32 → Option_ | ANY |
| get_lptoken_address_for_given_option | V | addr,addr,u8 → addr | ANY |
| get_pool_definition_from_lptoken_address | V | addr → Pool | ANY |
| get_option_volatility | V | addr,u64,fx → fx | ANY |
| get_underlying_token_address | V | addr → addr | ANY |
| get_available_lptoken_addresses_usable_index | V | felt → felt | ANY |
| get_pool_volatility_adjustment_speed | V | addr → fx | ANY |
| set_pool_volatility_adjustment_speed | EXT | addr,fx | OWNER |
| get_option_position | V | addr,u8,u64,fx → u128 | ANY |
| get_total_premia | V | Option_,u256,bool → (fx,fx) | ANY |
| black_scholes | V | fx,fx,fx,fx,fx,bool → (fx,fx,bool) | ANY |
| get_current_price | V | addr,addr → fx | ANY |
| get_terminal_price | V | addr,addr,u64 → fx | ANY |
| set_pragma_checkpoint | EXT | felt(key) | **ANY (runtime-proven)** |
| set_pragma_required_checkpoints | EXT | — | **ANY (runtime-proven)** |
| upgrade | EXT | ClassHash | OWNER (replace_class) |
| Ownable: owner()@V; transfer_ownership(addr), renounce_ownership(), transferOwnership(addr), renounceOwnership() | EXT | as named | OWNER (owner() view ANY) |

## Gating evidence (starknet_call, caller = zero address, head state)
- upgrade / set_max_lpool_balance / set_trading_halt_permission / transfer_ownership → revert "Caller is the zero address" (OZ assert_only_owner executes).
- set_trading_halt(true) → revert "Cant set trading halt status" (owner-or-permitted check; whitelisted halters can only set true).
- set_pragma_required_checkpoints() → SUCCESS; set_pragma_checkpoint('ETH/USD'=0x4554482f555344) → SUCCESS; set_pragma_checkpoint(0x1) → Pragma revert "No checkpoint available". ⇒ pragma relays are callable by ANYONE (AMM acts as caller toward Pragma; fee/rate-limit mechanics unknown → possible griefing surface; source branch hotfix-checkpoit suggests later patch, but DEPLOYED class still allows it).
- Live state @head: trading_halt=false; fees_percentage=3; max_option_size_percent_of_voladjspd=50; trading_halt_permission(owner)=false; 10 LP tokens (first 0x70cad6be…=ETH/USDC-CALL per fe-app); 0 events in last 1000 blocks.

## Legacy (Cairo-0, abi/v1.1/amm_abi.json) → new mapping
| legacy v1.1 | new | note |
|---|---|---|
| trade_open/close/settle | same names | typed args; reentrancy guard |
| add_option | add_option_both_sides | registers long+short tokens + initial_volatility; pooled_token_addr dropped |
| empiric_median_price | (none) | Empiric replaced by Pragma; new get_current_price |
| get_pool_volatility / _separate / _auto | get_option_volatility | consolidated |
| set_pool_volatility_adjustment_speed_external | set_pool_volatility_adjustment_speed | renamed |
| get_option_type / get_option_info_from_addresses / get_available_options_usable_index | (none) | removed views |
| (none) | get_value_of_pool_expired_position / _non_expired | new |
| (none) | get_fees_percentage | new (v1.3.0) |
| (none) | set/get_trading_halt_permission | new |
| (none) | set_pragma_checkpoint / set_pragma_required_checkpoints | new; ANY |
| (none) | get_current_price | new |
| OZ-proxy admin: initializer, getAdmin, setAdmin, getImplementationHash (+Upgraded/AdminChanged) | owner, transfer_ownership, renounce_ownership (+camel), upgrade(ClassHash) | proxy admin → OZ Ownable + replace_class |
| add_lptoken(…,pooled_token_addr,…); get_total_premia(…,lptoken,…) | same names, args changed | pooled_token/lptoken params dropped |
| unchanged names | is_option_available, black_scholes, get_terminal_price, get_value_of_* , deposit/withdraw_liquidity, expire_option_token_for_pool, get_lpool_balance, get_pool_locked_capital, get_max_lpool_balance, set_max_lpool_balance, set/get_max_option_size_percent_of_voladjspd, get_unlocked_capital, get_option_token_address, get_option_position, get_all_*, get_user_pool_infos, get_lptoken_address_for_given_option, get_pool_definition_from_lptoken_address, get_underlying_token_address, get_lp/underlying conversions | — |

## Audits & docs
- Nethermind NM0153-FINAL_CARMINE.pdf (2024-01-08): https://docs.carmine.finance/carmine-options-amm/audit · https://github.com/NethermindEth/PublicAuditReports/blob/main/NM0153-FINAL_CARMINE.pdf · summary https://numist.io/audit/nethermind-security-carmine-options-security-review (their page says 20 findings: 3H/4M/3L/8I; prose also mentions "28 findings with 2 critical" — inconsistent).
- protocol-cairo1 CHANGELOG v1.0.1: "Issues found in the audit by Nethermind"; releases v1.0.0–v1.3.1 (2024-01-09…2024-06-05).
- Docs: "Our old Cairo 0.10 AMM codebase has been audited by Hackachain." (same docs page).
- Governance: github.com/CarmineOptions/amm-governance; Medium "Carmine Governance" (medium.com/@carminefinanceinfo/carmine-governance-30e35228026d).

## UNKNOWNS / could not determine
- Exact source commit of deployed class 0x7fb1aa… (class source UNVERIFIED on Voyager; ABI matches master 1:1).
- Pragma set_checkpoint fee payer/rate-limits; worst-case cost/bricking of the permissionless pragma relays (fee is likely borne by the AMM as external caller).
- Semantics of governance.get_amm_address() returning the sister instance 0x1007d87… (stale config vs used elsewhere).
- Whether both AMM instances are intended to be live (both quiet last 1000 blocks; sister: class 0x45fb686c…, 4 LP tokens, same governance owner; unreferenced in public configs).
- Full TVL/pool composition (out of scope here).
