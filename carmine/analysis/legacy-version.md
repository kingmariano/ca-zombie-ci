# Legacy Carmine AMM (Starknet) — deployed implementation identification

Date: 2026-10-10 · Status: **read-only** (RPC archive reads + canonical calls only; no transactions) ·
Latest block used: 16,168,041 (snapshot) · Last upgrade: **block 267,110 = 2023-09-27 10:04:11 UTC**

## TL;DR

- Proxy `0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa` (OZ Cairo-0 generic proxy,
  class `0xeafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82`) currently points to impl class
  **`0x6eaee658250b9bee534ad7858f2c859460630e46ec5cdb2a1442ae64adc8b50`**
  (= decimal 3128964656966696289624950512934421795927781761489614896717803190622982277968).
- ABI = **v1.1 (identical file to v1)**. Code = **repo master core AMM as of 2023-09-27** — includes all
  post-v1.1 accounting work (stale-price checks, stablecoin divergence, Sep-26 "option settled" assert).
- `get_fees_percentage()` does **not** exist on this contract (ENTRYPOINT_NOT_FOUND); it exists only in the
  Cairo-1 AMM (`/tmp/opencode/carmine/protocol-cairo1/src/amm_core/peripheries/view.cairo`).
- Deployed 2023-04-07 with v1 class `0x2a67…` (class hash recorded in repo commit `0d2da7c`), upgraded twice
  in April 2023, then once on 2023-09-27 to the current master-era class.

## 1. Resume-style facts (verified)

| Item | Value |
|---|---|
| Proxy address | 0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa |
| Proxy class (getClassHashAt) | 0xeafb0413e759430def79539db681f8a4eb98cf4196fe457077d694c6aeeb82 (ABI: `__default__`, `constructor`) |
| getImplementationHash() | 0x6eaee658250b9bee534ad7858f2c859460630e46ec5cdb2a1442ae64adc8b50 |
| Impl storage key | 0x3f1abe37754ee6ca6d8dfa1036089f78a07ebe8f3b1e336cdbf3274d25becd0 (`Proxy_implementation_hash`) — matches getter |
| Impl class kind | Cairo 0 (`program` + `entry_points_by_type` + `abi`), 67 ABI entries, 53 functions |
| Admin (getAdmin) | 0x1405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f (Cairo-1 contract, class 0x4bc8bc7c…) |

## 2. ABI version match (deployed abi vs repo `abi/` folders)

| abi folder | match | notes |
|---|---|---|
| v1.1 | **EXACT** | `abi/v1.1/amm_abi.json` sha256 `a208b51483b71c63d14638033918d4486b8e388b76ba45ebab47652591eaa406` |
| v1 | **EXACT** | byte-identical file to v1.1 (same sha256) |
| v0.2.0 | no | v0.2.0-only fns: `migrate_lpool_balance`, `migrate_option_position`, `migrate_pool_locked_capital`, `remove_option`; different arities (v0.2.0 `trade_open/close` 7 inputs vs 9 deployed; `black_scholes` 5→6; `add_lptoken` 4→7; `get_value_of_position` 5→4). Deployed-only vs v0.2.0: `get_pool_volatility_separate`, `get_pool_volatility_auto/…_adjustment_speed`, `get_max_lpool_balance`, `get_max_option_size_percent_of_voladjspd`, `get_lptokens_for_underlying`, `set_max_*`, `set_pool_volatility_adjustment_speed_external` |

Functions of interest: `get_fees_percentage` **absent from all Cairo-0 versions**; `get_user_pool_infos` present since v0.2.0; `get_pool_volatility_separate`/`get_pool_volatility` present since v1.

## 3. Upgrade history (archive `starknet_getStorageAt` binary search + `Upgraded` events)

Storage key `0x3f1ab…` read at historical blocks (public node serves old state); changes at:

| Block | UTC | New impl class | Upgrade tx |
|---|---|---|---|
| 32,940 (deploy) | 2023-04-07 10:53:40 | 0x2a673a43e56c67dbd5dada9794a59c5dc9b14ba6c58f1c97de824f3d835e3e1 | 0x4d3984…df9 (constructor; AdminChanged → governance 0x1405ab78…) |
| 37,078 | 2023-04-12 07:06:57 | 0x16ce15797ac0473b945c6045e4cb2fb7bbbe0ffac1c6aba758a51262a62f14 | 0x3275c7…21a (sender 0x583a9d95…f722a1) |
| 38,088 | 2023-04-13 12:50:38 | 0x387c64af4d5dfa5c1823a971f79a5519bfe6b2f66ddb592d056bdff437ed4e3 | 0x3af095…5f8 (sender 0x583a9d95…f722a1) |
| 267,110 | 2023-09-27 10:04:11 | **0x6eaee658…c8b50 (current)** | 0x37c61e…8d3 (sender 0x583a9d95…f722a1) |

Each block has an `Upgraded` event (selector `0x2db340e6…1af3`, data = new impl hash); deploy block also emits `AdminChanged` (admin = governance `0x1405ab78…ba0f`). All three upgrades were routed through that governance admin by EOA `0x583a9d95…f722a1`.

## 4. Version fingerprinting of the four impl classes (program identifiers)

| Impl | Identifiers | `account_for_stablecoin_divergence` | `get_empiric_stablecoin_key` | `_get_value_of_pool_position.current_block_time` |
|---|---|---|---|---|
| 0x2a67 (Apr-07) | 6227 | no | no | no |
| 0x16ce (Apr-12) | 6224 | no | no | no |
| 0x387c (Apr-13…Sep-27) | 6224 | no | no | no |
| **0x6eaee (current)** | **6264** | **yes** (helpers+oracles) | **yes** (+`EMPIRIC_USDC_USD_KEY`, `EMPIRIC_DAI_USD_KEY`) | **yes** |

- `current_block_time` inside `_get_value_of_pool_position` was added by repo commit `3d90007`
  (2023-09-26, "Check that option is settled before pricing pool") → the current class post-dates it;
  it was upgraded 2023-09-27, one day after the commit. This is a decisive master-era marker.
- `0x16ce` and `0x387c` have identical identifier sets (program bytes differ; layout-only change);
  `0x2a67 → 0x16ce` removed exactly 3 identifiers (`withdraw_liquidity.ZERO/assert_res`,
  `_mint_option_token_long.assert_res`).
- Repo cross-check: commit `0d2da7c` (tag `1.0`, 2023-04-07 "Update mainnet class hashes") records
  `amm_class_hash=0x2a67…e3e1` and `generic_proxy_class_hash=0xeafb…eb82` → exact match to what is on-chain.

## 5. Live behavior checks on the proxy (block ~16,168,109)

- `get_fees_percentage()` → revert `ENTRYPOINT_NOT_FOUND`; selector `0x480605ab8e6b3b8a15c50144b27ded91328a9f70581b3706090fa0fdaf352`
  (== keccak("get_fees_percentage"), so encoding was correct). Proves the deployed class lacks it.
- `get_pool_volatility_separate(lptoken, maturity, strike)` → **works**, e.g. lptoken
  `0x7aba50fdb4e024c1ba63e2c60565d0fd32566ff4b18aa5818fc80c30e749024`, maturity 1704412799, strike 0x1130… → `135698015616455842292`;
  maturity 1682035199, strike 0xed80… → `225715298195400485788`.
- `get_user_pool_infos(addr)` works (0 entries); `get_trading_halt()` → 0 (not halted); `get_all_options(lptoken)` → 1068 felts = 178 options (lt1) / 840 felts = 140 options (lt2), maturities through 1704412799.
- `get_all_lptoken_addresses()` → [2, `0x7aba50fd…9024` (quote USDC `0x53c912…368a8`, base ETH `0x49d365…4dc7`, option_type=0), `0x18a6abca…827a` (same pair, option_type=1)]; observed strikes decode to ETH/USDC levels 1900/2000/2200.
- `get_pool_volatility(lptoken, maturity)` reverted `ASSERT_EQ 0 != 1` for tested maturities; the `_separate` variant works (probe again if relevant).

## 6. Repo history anchors (for accounting context)

- abi folder last-change dates: v0.1.1 2022-10-13 → v0.2.0 2023-01-17 → **v1 2023-04-05** (`9ef7f71`) →
  **v1.1 2023-05-08** (`c513ec2`, "Add airdrop (#142)"). No abi change after 2023-05-08; master last commit
  `7556bae` 2023-10-12. `contracts/core_amm/` last change: `3d90007` 2023-09-26.
- Accounting-relevant merges (first-parent): 2023-04-06 PR #134 (assert price not stale), 2023-04-11 fix,
  **2023-04-13 PR #138** (additional unlocked_balance check; second upgrade same day), 2023-04-20 PR #139
  (polish expire options), **2023-05-01 PR #141** (stale terminal price check), **2023-05-02 PR #133**
  (account for stablecoin price divergence), 2023-09-26 settle-check commit (upgrade 2023-09-27).
- `git diff c513ec2..master` for `contracts/core_amm/` = only `liquidity_pool.cairo` +5 lines (the Sep-26 assert).
  `types.cairo` unchanged since 2023-03-22; submodules unchanged across these revisions.

## 7. Accounting differences

- **Current (0x6eaee, since 2023-09-27) vs repo master: none detectable.** Identifier-level fingerprint
  matches master-era code (contains PR #133/#141/#138/POST-#134 work + Sep-26 assert). Cannot be byte-proven
  (repo contains no compiled artifacts for master; no Cairo-0 toolchain run here).
- **vs the code that actually ran 2023-04-13 → 2023-09-27 (0x387c): significant.** That version lacked the
  stablecoin-divergence accounting (Empiric stablecoin keys), the stale terminal price / stale price asserts,
  and the "option settled before pricing" guard. ABI was already v1.1-equivalent, so ABI checks alone cannot
  distinguish; the identifier markers do.
- Fee accounting is premia-based in all versions: internal `fees.get_fees` +
  `helpers._get_premia_before_fees/_with_fees` + `option_pricing_helpers.add_premia_fees` (all present since
  ≤Apr 2023); no fee-percentage getter in any Cairo-0 version.

## 8. Unknowns / caveats

- Explorer corroboration unavailable: `voyager.online` and `starkscan.co` contract pages are JS shells when
  fetched (webfetch returned no data; voyager API blocks external access). Upgrade history here comes from
  RPC archive storage + on-chain `Upgraded` events — direct and verifiable.
- Class *declaration* blocks for each impl hash are not directly exposed by RPC (only upgrade-execution blocks).
- A private, never-published build being deployed cannot be excluded in principle; no repo/ABI/identifier
  evidence of it. The current class is consistent with a post-2023-09-26 build of the public master.
- Storage archive reads via keyless `https://starknet-rpc.publicnode.com`; values re-verified at blocks 16,151,160 / 16,168,041.

## Files
`legacy_impl_class.json` (current impl 0x6eaee) · `legacy_v1_class.json` (0x2a67) · `legacy_mid_class.json`
(0x16ce) · `legacy_v11_class.json` (0x387c) · `proxy_class.json` · `upgrade-history.json` ·
`upgrade-events.json` · `live-calls.json` · `markers.json` · `sn.py`
