# NAVI (Sui) — Adjacent Packages & Old-Version Path Review

Date: 2026-10-10. Read-only, public data only (Sui mainnet GraphQL `https://graphql.mainnet.sui.io/graphql`, public GitHub, GitBook, web search). Raw artifacts in `analysis/raw/` (`oracle_modules/`, `lineage_c/`, `iv2_details.json`, etc.).

## 1. Oracle lineage `0xca441b44...`

Package original id `0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f`, 5 versions, current `0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea`.

| pkg v | address | modules in version | gate constant | notes |
|---|---|---|---|---|
| 1 | `0xca441b44…` | oracle | **1** (inline) | init creates OracleAdminCap + OracleFeederCap to deployer; shares PriceOracle |
| 2 | `0x1951eff0…` | oracle | **1** (inline) | adds `create_feeder` |
| 3 | `0xc2d49bf5…` | + config, oracle_version, oracle_manage, oracle_pro, adaptor_pyth/supra, strategy… | **2** | OracleConfig + oracle_pro + version module added; `update_single_price` (permissionless) added |
| 4 | `0x203728f4…` | + adaptor_switchboard | **3** | `update_single_price_v2`; announced 2026-02-11 |
| 5 | `0x4837ae94…` | full set | **4** | current; `update_single_price_v3`; MoveBit PythPro audit 2026 |

**Live objects**
- `PriceOracle` `0x1568865ed9a0b5ec414220e8f79b3d04c77acc82358f6e5ae4635687392ffbef` (type `0xca441b44…::oracle::PriceOracle`, shared) — contents keys `id, version, update_interval, price_oracles`; **internal version field = 4**, update_interval 15000, 38 price entries. (Sui object version 1042250017; shared since version 8202835.)
- `OracleConfig` `0x1afe1cb83634f581606cc73c4487ddd8cc39a944b951283af23f7d69d5589478` (type `0xc2d49bf5…::config::OracleConfig` — config module first defined in v3) — version field 4, paused=false, 38 feeds.

**Gate — YES.** `oracle::version_verification` → `oracle_version::pre_check_version(PriceOracle.version)` asserts equality with that package version's `oracle_constants::version()` (v1/v2 are inline `== 1`). v3 expects 2, v4 expects 3, v5 expects 4. Live objects are at 4 → **only v5 functions pass**; v1–v4 all abort (error 50000 / `oracle_error::incorrect_version`). OracleConfig is gated the same way (live 4).

**Who can update prices (current v5)**
- `entry public update_token_price` / `update_token_price_batch` — need **`&OracleFeederCap`**.
- `entry public register_token_price` / `set_update_interval` — need **`&OracleAdminCap`**.
- `public(friend) update_price` — only friend modules inside the package (oracle_pro / adaptors).
- `oracle_pro::update_single_price_v2` / `_v3` — `public`, **permissionless (keeper path)**: reads signed Pyth/Supra/Switchboard data and enforces config/strategy checks (paused, version, max timestamp diff, price-diff thresholds, min/max effective price, span %, historical TTL) before writing. Confirmed PTB-callable and used in production by third-party senders (e.g. `0x19befd56…`, `0x3be8db6c…`).

**Caps (enumerated)**
- `OracleAdminCap`: 1, `0x7204e37882baf10f31b66cd1ac78ac65b3b8ad29c265d1e474fb4b24ccd6d5b7`, owner `0x39c70d4ce3ce769a46f46ad80184a88bc25be9b49545751f5425796ef0c3d9ba`.
- `OracleFeederCap`: 6, all owned by the same `0x39c70d4c…`.
- Oracle upgrade cap `0x436d774dedebb6300c35ef99307a315e4c313fe79cdec326678a5c5ef574f0e0`, owner `0x39c70d4c…` (latest upgrade tx `7nCLBXSR…`).

**Unprivileged old-version update? NO.** Every v1–v4 price-mutating function either requires a cap (held only by `0x39c70d4c…`) and/or aborts on the version gate (live=4 ≠ 1/2/3). The caps are the same v1-defined types, so the *only* barrier for old versions is the gate — which holds. Residual: the admin-cap holder could call v1/v2 `version_migrate` (sets version=1 if ≥1) to downgrade, then use old functions — admin-only footgun, not unprivileged. v5's `version_migrate` aborts unconditionally.

## 2. Lineage C `0xacc64a32…` = NAVI **staging** lending deployment

Original id `0xa49c5d1c8f0a9eaa4e1c0c461c2b5dfb6e88213876739e56db1afb3649a8af26`, **21 versions**, current `0xc371fc618faca4671253811faef480903b86c58966e8f899184ebaa640120c64` (v21). Same module set as the main lending lineage (account, calculator, constants, …, incentive/incentive_v2/incentive_v3, lending, storage, version).

**Identity**: NAVI's staging/development deployment (not the main protocol). Evidence: `naviprotocol/navi-sdk` `src/addressStg.ts` sets `ProtocolPackage=0x8200ce83…` (lineage C v15), `StorageId=0x111b9d70…`, `IncentiveV3=0x5db40639…`, `PriceOracle=0x25c718f4…`; an older `Published.toml` snapshot lists `[published.development] original-id=0xa49c5d1c… version=10` on mainnet chain-id; `address.ts`/`addressStg.ts` reference lineage C RewardFund `0xfb0de07c…`.

**Gate — YES**: `version::pre_check_version` (assert `== constants::version()`); constants progressed 6→15 across versions (v1–v3 inline 6; v4=7 … v13=13; v14=12 anomaly; v18=14; v21=15). Live Storage/Incentive objects all have version field **15** → only v21 gated functions pass; v1–v20 abort. Upgrade cap `0x77c3e3ffe6889ed4d2d7280aece738119eccc5db4c50e784779f677cfd4d75cc`, owner `0xdf6bff0ffa1e6a7ae93df6585c84438df84224e53bdc40965299d34c5ae3d6cc`; v1 publish sender `0x8635a944…`.

**Objects**: 12 Storage markets (all v15; main one `0x111b9d70…`, 39 reserves); 14 IncentiveV3 objects (v15); **13 RewardFunds** — incl. the queried `RewardFund<WETH>` `0xfb0de07cd39509ecb312464daa9442fac0eb4487d7a9b984cdfc39c1fb7d2791` (shared, balance **997715993 raw**, coin `0x0eedc385…::weth::WETH`); 2 IncentiveV2 objects; 7 V2 IncentiveFundsPool objects **with non-zero balances** (2× ~98.4 WETH, 7.47 SUI, 50.1B raw CERT, 203.6M raw NAVX, HASUI, …).

**Old versions callable?** No for gated state-changing functions (constants mismatch). v1–v12 use inline constants (no `version` module); sampled v1 lending entry points are gated. Not every old function was exhaustively enumerated.

## 3. Other objects / lineages

- **uiGetter `0xf5637047…`** — an **immutable package** (v1 only, no upgrade lineage) with read-only getter modules (`getter::get_oracle_info/get_user_state/get_reserve_data`, calculator/getter variants). Earlier "null type" was because it is a MovePackage, not a MoveObject. Publish sender `0xf89bf436…`.
- **flashloanConfig `0x3672b2bf…`** — shared `flash_loan::Config` object, type `0x06007a2d0ddd3ef4844c6d19c83f71475d6d3ac2d139188d6b62c052e6965edd::flash_loan::Config` (module first defined at **main lineage v14**), version field 16 (matches only v26 constants=16). No separate lineage; `flash_loan` has version gates (9 call sites).
- **ReserveParentId `0xe6d4c661…`** — the main storage's `reserves` Table (`Table<u8, ReserveData>`, child/dynamic object; `object()` returns null). Not independently callable.
- **Main-lineage package versions** (per `packageVersions`): v22 `0x81c40844…` (incentive_v3 type origin), v23 `0xee004123…` (2025-11-17 announcement), v24 `0x1e4a13a0…` (2026-02-11 announcement), v25 `0xc37b8136…`, v26 `0x512f2826…` (current). **Upgrade authority**: UpgradeCap `0xdba1b40f3537441b51d2848fc0a149610e48e67c1cc48c6ad641767622000623`, owner `0x25549f15b144032b4a61921552f6ecbfea13556615f7b45576b12f10d67955e7`, policy 0; latest upgrade tx `9x1yr6Fx…`. Source/Published.toml verified in `naviprotocol/navi-smart-contracts`.
- Type-origin packages inside the main lineage: `incentive_v2` → v9 `0xe66f07e2…`, `incentive_v3` → v22 `0x81c40844…`, `flash_loan` → v14 `0x06007a2d…`. No additional independent package origins found among SDK-listed objects.

## 4. Incentive objects (dynamic-field inspection)

**Main IncentiveV2 `0xf87a8acb…`** (type `0xe66f07e2…::incentive_v2::Incentive`, version 16): `pool_objs` **empty**, `inactive_objs` = 746 addresses = the **keys of frozen `IncentivePool` structs stored inside the `pools` Table** (`0xcc4aac9c…`), not standalone objects (multiGetObjects → null) and holding no coin balance (rewards live in `IncentiveFundsPool`). Verified via `multiGetDynamicFields` (e.g. pool `0xd11e492b…`: phase 11, funds `0xf975bc2d…`, asset 2, option 3, total_supply 153.15B, distributed 131.6B, index 8.7e22, ended 2023-12). The `funds` Table (9) maps to 9 `IncentiveFundsPool` objects — **all balances 0**; main V1 `incentive` has **no funds pools**. Main IncentiveV3 `0x62982dad…` (v16) has 15 RewardFunds with real balances (CERT, NAVX, WA, IK, BLUE, DEEP, HA, …).

**Lineage C IncentiveV2 `0x952b6726…`** (v15): 8 active pools, 186 inactive, 7 funds; active pools reference only the NAVX (`0x015a4aa9…`) and CERT (`0x1ca8aff8…`) funds.

## 5. Reward-checkpoint bug (public, unmerged fix) — reachable on staging, not on main

- GitHub **PR #13** (claude[bot], 2026-09-13, **closed unmerged**): "stop discarding sub-second interest and initialise absent legacy reward checkpoints". The deprecated v1/v2 claim paths read a missing per-user checkpoint as index 0 → an account never settled against a pool appears to have earned **the pool's entire historical index × current balance** and can claim for a window in which it held no balance.
- Source still contains the bug (`incentive.move` 271-277, `incentive_v2.move` 448-453). **Deployed bytecode confirmed**: main v26 and lineage C v21 `incentive_v2::calculate_one` are byte-identical (both 51407 bytes) with `LdU256(0)` default for `index_rewards_paid`.
- Claim path (`claim_reward` → `base_claim_reward` → `update_reward`) calls `version_verification`, and the live objects match the current constants (main 16, staging 15) → **the current-version claim path is callable by anyone**; old versions remain gated off.
- **Main deployment: no value at stake** — V2 `pool_objs` empty, all V2 funds 0, V1 has no funds.
- **Lineage C staging: reachable** — 8 active pools reference non-empty NAVX (203.6M raw) and CERT (50.1B raw) funds; a fresh user with a supply/borrow balance can claim `index_reward × balance / RAY` (capped by remaining pool supply and fund balance). The WETH funds (~98.4 WETH ×2) are referenced only by **inactive** pools and are not reachable via this path (`get_pool_from_funds_pool` scans `pool_objs` only).
- Related: issue #2 "owner is not the real owner" (AccountCap.owner is logical, not enforced by Sui ownership).

## 6. Web context (sources)

- **2025-11-17 announcement** — package `0xee004123…` (v23); v2 interfaces; audited by OtterSec + Movebit. https://naviprotocol.gitbook.io/navi-protocol-developer-docs/smart-contract-overview/release-history/navi-lending-protocol-upgrade-announcement-2025-11-17.md
- **2026-02-11 announcement** — lending `0x1e4a13a0…` (v24), oracle `0x203728f4…` (v4); E-Mode, isolated markets, Incentive V3 redesign; "old package id deprecated and no longer functional"; oracle `update_single_price` → `update_single_price_v2`; audited by Veridise and Movebit. https://naviprotocol.gitbook.io/navi-protocol-developer-docs/smart-contract-overview/release-history/navi-lending-protocol-upgrade-announcement-2026-02-11.md
- **Public contracts repo**: https://github.com/naviprotocol/navi-smart-contracts — `lending_core` v26 + `oracle` v5 sources, `Published.toml` (original-id/published-at), version-gate code (`lending_core/sources/version.move`), `audits/` with 12 PDFs (OtterSec 2023/2024/2025, Movebit 2023/2025/2026, Veridise 2024/2026, Salus 2023, Asymptotic formal verification 2026). SDK repos: `navi-sdk` (address.ts/addressStg.ts), `naviprotocol-monorepo`, `protocol-interface`.
- **Incident**: 2026-04-21/22 Volo Protocol vaults ~$3.5M drained via **compromised operator private key** (social engineering), not a contract/version bug; Volo is a NAVI-group product routing into NAVI lending; NAVI stated no impact to NAVI funds (DefiLlama lists it as NAVI's one recorded incident).
- Bug bounty: https://hackenproof.com/companies/navi-protocol

## Closure-relevant answers

1. **Oracle gate**: yes — live version 4; v1–v4 abort; all direct updates need caps owned solely by `0x39c70d4c…`; v5 adds a permissionless signed-data keeper path. **No unprivileged old-version oracle path.**
2. **Lineage `0xacc64a32…`**: NAVI **staging** lending deployment (original `0xa49c5d1c…`, 21 versions, controlled by `0xdf6bff0f…`), version-gated (constants 6→15, live objects 15).
3. **Additional lineage/gate gaps**: main lending v26 upgrade cap owner `0x25549f15…`; oracle caps/upgrade `0x39c70d4c…`; the unmerged reward-checkpoint bug is reachable only where active V2 pools + non-empty V2 funds exist (staging; NAVX/CERT at risk), not on the main deployment.
