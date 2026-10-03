# mySwap V1 — Source, Contracts, Sunset & CL Hack Research

**Research date:** 2026-10-03 · **Chain:** Starknet mainnet · **Method:** read-only historical `starknet_call`/`getClass`/`getEvents` via public RPC (`https://starknet-rpc.publicnode.com`), GitHub code/repo search, web/archival sources, Voyager/GoPlus/mySwap primary posts. No transactions signed or sent. Selector values computed with a local keccak256 implementation, validated against the known `transfer` selector `0x83afd3f4…` and against the on-chain class entry points.

> Saved verbatim from the research child subagent (researcher, session `ses_efd6e6517ffetvBLk8FdlGFunZ`) by the parent H-10 subagent. Parent re-verified the key on-chain claims independently (see `analysis/measure.py`, `ci-out/`).

## TL;DR

- **V1 source is not public.** No mySwap contracts repo exists; the AMM implementation class `0x55ef1b2c…` is marked **UNVERIFIED** on Voyager ("Class is not verified — No source code is available for this class"). No repo URL / commit hash can be given because none exists publicly. Architecture below is reconstructed from the on-chain class ABI/selectors and the official V1 frontend build.
- **V1 core:** proxy `0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28`, admin `0x1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8`, one implementation class from ≤2022 until sunset.
- **Sunset = class replacement** at block **1,397,399 = 2025-05-13T10:44:48Z** to Cairo1 `MySwapLegacy` (`0x40b83509…`). Same day the admin **distributed all pooled tokens back to users** via `distribute_tokens` in 100-entry ledger batches (ETH 116.71, USDC 178,181, USDT 51,030, DAI 28,141, wstETH 19.12, LORDS 13,044, WBTC 0.0116). Only dust remains.
- **8 V1 pools** existed at sunset (not 4 as the stale frontend config shows); full list with tokens/reserves/LP contracts below.
- **CL hack** (2026-06-19 07:15 UTC): attack tx `0x1c15c406…`, block 10,951,100; attacker deployed fake `EVIL` token `0x028c9acd…` and, in one tx, created 12 EVIL/real-token pools and ran Mint/Burn/Collect cycles against the shared singleton `0x1114c710…`. ~$305K: 137.96 ETH, 230,167.88 STRK, 45,123.91 USDC.e, 19,945.24 USDT. No public source-level post-mortem names the exact missing check.
- **Audits:** none found for V1 (or CL). The "0 audits" claim is consistent with all public evidence.

---

## 1. Contract inventory

### 1.1 mySwap V1 (mainnet)

| Role | Address / hash | Evidence |
|---|---|---|
| **Core AMM (upgradeable proxy)** | `0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28` | DefiLlama adapter `projects/myswap/api.js`; live on-chain reads |
| Proxy class (Cairo 0) | `0x7e35b811e3d4e2678d037b632a0c8a09a46d82185187762c0d429363e3ef9cf` | `starknet_getClassHashAt` at blocks 100,000–1,250,000 |
| Proxy ABI | `constructor`, `Upgraded`, `AdminChanged`, `getImplementationHash`, `getAdmin`, `__default__`, `__l1_default__` | class ABI at block 1,000,000 |
| **AMM implementation class** | `0x55ef1b2cb1313b8202f68ef32aaefca4133b21cbce68c4bfee453e595ce646f` | `getImplementationHash` = same at blocks 200,000…1,250,000; Voyager: declared 2022-10-24 23:18:25 by `0x…0001`, tx `0x3915a7654178213cd1e79fc9c5bfcb171f43617f1899563916f227753ba51dc`, **UNVERIFIED** (`voyager.online/class/0x55ef1b2c…`) |
| **Current class (since sunset)** | `0x40b83509bc9cebd1af068b7d32e8b04cda394db1aedacb512f321d8a825e683` — Cairo1 `myswap_legacy_cairo2::MySwapLegacy`: `upgrade(new_class_hash)`, `distribute_tokens(token_address, ledger: Span<Ledger>)`, `assert_admin()` (view) | class ABI (recursive parse); upgrade tx below |
| Admin / owner | `0x1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8` (contract account, class `0x3957f9f5a1cbfe918cedc2015c85200ca51a5f7506ecb6de98a5207b759bf8a`) | proxy `getAdmin` unchanged at blocks 200,000–1,250,000 and pre-upgrade |
| **LP token class** | `0x2797c4997ea0ca14401188bf6cbd4d89f0e632bd088088ab6cabf63c2056fc8` (Cairo 0; ABI: name/symbol/decimals/totalSupply/balanceOf/allowance/owner/transfer/transferFrom/approve/increaseAllowance/decreaseAllowance/mint/burnFrom/transferOwnership/renounceOwnership; events Transfer/Approval/OwnershipTransferred) | class ABI; all 8 LP tokens share it |
| 8 LP token instances | see §3 ("MYLP", 12 decimals, `owner()` = core AMM) | on-chain |
| Router / factory / distributor | **none found for V1.** Pool creation and liquidity logic live on the core (`create_new_pool`); LP tokens are owned by the core. No separate router appears in the frontend config/ABI | frontend ABI/config; on-chain |
| Third-party helper used by UI | `0x163dd8182a69972b9fc7e95eb0be92b731680212beddfede2eff4ffcfa28bfb` — Braavos bulk `multi_call_contract` (not mySwap-owned) | V1 frontend bundle |
| Testnet (historical) | alpha-goerli `0x71faa7d6c3ddb081395574c5a6904f4458ff648b66e2123b877555d9ae0260e` (Jun 2022, `myswapxyz/static_data/db.json`) and alpha4 `0x18a439bcbb1b3535a6145c1dc9bc6366267d923f60a84bd0c7618f33c81d334` (frontend config) | repos |

Sources: `github.com/DefiLlama/DefiLlama-Adapters/projects/myswap/{api.js,abi.js}` (adapter also has `hallmarks: [['2025-05-13','Sunset of MySwap']]`, `deadFrom: '2025-05-13'`); `github.com/myswapxyz/v1` (gh-pages build, ABI + mainnet config); `voyager.online/class/0x55ef1b2c…`; on-chain reads.

### 1.2 mySwap CL (comparison)

| Role | Address / hash | Evidence |
|---|---|---|
| **Singleton pool / AMM / shared vault** | `0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111` | DefiLlama `projects/myswap-cl/index.js`; GoPlus ("exploited contract 0x01114c") |
| Class | `0x40974d74561db5f6c5e66cb50989cfdfc0ec0d1a96b577f85f29695c769a7bd` — Sierra `myswapv3::contract::pool::PoolContract` | class ABI; key fns: `positions`, `ticks`, `current_tick`, `current_sqrt_price`, `liquidity`, `balance0/1`, `token0/1`, `mint`, `collect`, `burn`, `swap`, `limited_swap`, `create_pool`, `create_and_initialize_pool`, `initialize_pool_price`, `owner`, `pool_key`, `get_pool`, `migrator`, `set_migrator`, `upgrade`, `migrate_storage`, `get_storage_version` (=2), owner() = `0x1dec…` |
| Position manager (ERC-721, `NftPositionManagerContract`) | `0xfff107e2403123c7df78d91728a7ee5cfd557aec0fa2d2bdc5891c286bbfff` (class `0x48f0385817a361b9559cb6372de3a80d8e3cd93e71f442476ae1e0c54ed597e`) | class ABI (events IncreaseLiquidity/DecreaseLiquidity/Collect/Rebalance) |
| Lens | `0x32a08e81590831a01c8c1d27ee8a162adce2dac31c9c4cda87d5e8661ec28f1` (class `0xbe40709b11fd8e8c021bfd1a48c443fd20b6200c462461889c0b71ea0934aa`; `get_account_positions`) | class ABI |
| Fail helper | `0x05d547138513745f14619ae5f696b4c76c3154a50c31865ee35a1f085217c7dd` (`myswapv3::contract::fail::Fail`) | class ABI |
| Token list (10 tokens: WBTC, RETH, wstETH, USDC, ETH, LORDS, DAI, USDT, LUSD, STRK) | `https://myswap-cl-charts.s3.us-east-1.amazonaws.com/tokenList.json` | DefiLlama adapter; fetched |

No separate CL factory or vault contract was found — `create_pool` is on the singleton, which custodies all pools' tokens (the "shared vault" of the hack reports). Class unchanged across the hack (same hash at block 15,000,000 and 15,840,660); `migrator() = 0x0`.

Also seen in the current `myswapxyz/app` bundle: a Merkle `Distributor` contract `0x005763f02381e89c6894ffea078d1cf9e58da0ead33d5b52aa608acc04063053` (`claim`, `add_root`) — not confirmed to be V1/CL-related.

## 2. V1 architecture + source (source: NOT FOUND — explicit)

**No public V1 Cairo source exists.** Evidence:
- GitHub repository search `myswap cairo` / `myswap contracts` / `starknet myswap`: no contracts repo. Users `myswapxyz` and `MySwap` contain only frontend/Solidity-2021 artifacts; `github.com/myswap-org` is 404.
- GitHub code search: `"create_new_pool" language:Cairo` → 0; `"cfmm_type" language:Cairo` → 0; `"get_total_number_of_pools"` → only DeFiLlama adapters and bot/ABI files; `"myswap extension:cairo"` → only third-party adapters (Fibrous, AVNU).
- Voyager for the implementation class: **"UNVERIFIED — No source code is available for this class."**
- The repo `myswapxyz/v1` (URL: `https://github.com/myswapxyz/v1`, branch `gh-pages`) is the built frontend; last commit `3c87bb5c12d84768065f9c5e442597330cf28712` (2025-05-13T10:26:45Z, "update", yaron.segalov@braavos.app). It contains the complete ABI + token/pool config — a useful primary artifact, but no contract source.

**Verified architecture (on-chain + official frontend ABI):**
- **Upgradeable proxy** (Cairo 0) with admin-gated `upgrade`; `Upgraded`/`AdminChanged` events; `__default__` delegates to the implementation (`library_call`). Single implementation class `0x55ef…` from at least block 200,000 through 1,250,000 (no impl upgrades observed in that span).
- **ABI (implementation):** `constructor(owner)`, `get_owner`, `get_version` (returns `0x1000000`), `get_total_number_of_pools`, `get_pool(pool_id) -> Pool`, `get_lp_balance(pool_id, lp_address) -> u256`, `get_total_shares(pool_id) -> u256`, `transfer_ownership(new_owner)`, `add_liquidity(pool_id, a_address, a_amount u256, a_min_amount u256, b_address, b_amount u256, b_min_amount u256) -> (actual1, actual2)`, `withdraw_liquidity(pool_id, shares_amount u256, amount_min_a u256, amount_min_b u256) -> (actual1, actual2, res1, res2)`, `swap(pool_id, token_from_addr, amount_from u256, amount_to_min u256) -> amount_to`, `create_new_pool(pool_name, a_address, a_initial_liquidity u256, b_address, b_initial_liquidity u256, a_times_b_sqrt_value u256) -> pool_id`, `upgrade`; events `Upgraded`, `AdminChanged`.
- **`Pool` struct (10 felts):** `name, token_a_address, token_a_reserves u256, token_b_address, token_b_reserves u256, fee_percentage, cfmm_type, liq_token`.
- **LP tokens:** per-pool ERC-20 `MYLP` (name = pool name, 12 decimals), owned by the core; `totalSupply == get_total_shares(pool_id)` (verified). All pools use `fee_percentage = 300` (0.3%), `cfmm_type = 0`.
- **Access control / upgradeability:** proxy admin = `0x1dec3416…` (one contract account; no timelock/multisig visible). Admin can `upgrade` the class and later call `distribute_tokens`; `assert_admin` reverts with ASCII `"Caller is not admin"` for others.
- **Token whitelist:** none found. `create_new_pool` is a public external function (args above); the 8 pools appear curated/launched over time, but with source unavailable the exact permissioning can't be verified — flagged as **unknown**.
- **Fee/math details cannot be source-verified** (no source). Observed: constant-product style pools (creation takes `a_times_b_sqrt_value`), 0.3% fee, pro-rata LP shares (LP supply mirrors `get_total_shares`).

Verified selectors (usable for reproduction):
```
get_total_number_of_pools 0x105b90925282800807177a6067e409237de3431ff129a80067088d890f2d9d3
get_pool                  0x279193ae67f7ef3a6be330f5bd004266a0ec3fd5a6f7d2fe71a2096b3101578
get_lp_balance            0xc1e569fccc9c1d55913b6a5e96786d4b93333f285e82dd96233e40ccdc715
get_total_shares          0x1e33f51158c22791e6fc5b1b117211865ee914f241e349d743eb9c3a7e4702b
swap                      0x15543c3708653cda9d418b4ccd3be11368e40636c10c44b18cfe756b6d88b29
add_liquidity             0x2cfb12ff9e08412ec5009c65ea06e727119ad948d25c8a8cc2c86fec4adee70
withdraw_liquidity        0xb69b4361a8bcfea4e074bd844f59471180e9e07bd42a66ff4906186a9f2628
create_new_pool           0x2e4c967a99d5730f3a5b9c21d6d2f78525d3c81a1534474b1f575f38eb5c243
upgrade                   0xf2f7c15cbe06c8d94597cd91fd7f3369eae842359235712def5584f8d270cd
get_version               0x2a4bb4205277617b698a9a2950b938d0a236dd4619f82f05bec02bdbd245fab
proxy getImplementationHash 0x1f01da52d973fb13ba47dbc8e4ca94015dc4e581e2cc20b2050e87b0a743fae
proxy getAdmin              0x16840a3a6d7aa5535efd58bdf6fef6cb8b15ad6bbd1f00ae070b3d44f600085
distribute_tokens         0x5dac7a4bf79fe9e5627ad9ff4cb2b1547e6f348c887f0c85052120baba1baa
assert_admin              0xd246002fced6f89c3edc2d579780a37441b8f0ab0630cf522a880d27430090
Upgraded                  0x2db340e6c609371026731f47050d3976552c89b4fbb012941663841c59d1af3
```

## 3. Pool list at sunset (block 1,397,398, 2025-05-13 ~10:44 UTC)

Recovered on-chain via historical `get_pool(i)` / `get_total_shares(i)` (no published list exists; the frontend config only had a stale 4-pool/7-token snapshot from 2022). Core held **8 pools**:

| # | Name | Token A (reserves) | Token B (reserves) | Fee | LP token (MYLP) | totalShares |
|---|---|---|---|---|---|---|
| 1 | MYSWAP ETH/USDC | ETH `0x049d36…4dc7` (65.019545514226496596) | USDC `0x053c91…368a8` (160,626.073078) | 300 (0.3%) | `0x22b05f9396d2c48183f6deaf138a57522bcc8b35b67dee919f76403d1783136` | 1,874,308,956,727,175 |
| 2 | MYSWAP DAI/ETH | DAI `0x00da11…6eb3` (23,643.307802445568921321) | ETH (12.194319461904151801) | 300 | `0x7c662b10f409d7a0a69c8da79b397fd91187ca5f6230ed30effef2dceddc5b3` | 356,533,681,651,235,342,469 |
| 3 | MYSWAP WBTC/USDC | WBTC `0x03fe2b…e7ac` (0.01160003) | USDC (1,183.453699) | 300 | `0x25b392609604c75d62dde3d6ae98e124a31b49123b8366d7ce0066ccb94f696` | 28,060,290 |
| 4 | MYSWAP ETH/USDT | ETH (16.374402895184240235) | USDT `0x068f5c…0fb8` (40,368.653496) | 300 | `0x41f9a1e9a4d924273f5a5c0c138d52d66d2e6a8bee17412c6b0f48fe059ae04` | 492,936,651,532,804 |
| 5 | MYSWAP USDC/USDT | USDC (10,689.686225) | USDT (10,661.551835) | 300 | `0x1ea237607b7d9d2e9997aa373795929807552503683e35d8739f4dc46652de1` | 8,949,295,962 |
| 6 | MYSWAP DAI/USDC | DAI (4,497.580004728294514976) | USDC (5,682.182179) | 300 | `0x611e8f4f3badf1737b9e8f0ca77dd2f6b46a1d33ce4eed951c6b18ac497d505` | 4,329,948,926,990,547 |
| 7 | MYSWAP tETH/ETH | `0x42b8f048…96d2` (19.122960000245353755) | ETH (22.916368668703245295) | 300 | `0x14e644c20bd5f9888033d2093c8ba3334caa0c7d15ed142962a9bebf36cc7e0` | 19,464,358,665,738,978,862 |
| 8 | MYSWAP LORDS/ETH | LORDS `0x0124ae…33b49` (13,044.468139711354924654) | ETH (0.201390743649120438) | 300 | `0x2699b69786cb08b4c83c1c02e943eca3eba00234d80a564ebe00c40226ea70b` | 41,314,300,080,818,026,939 |

Note: token `0x042b8f0484…` is labelled **wstETH** in the official frontend token list, but pool 7's on-chain name decodes to `MYSWAP tETH/ETH` — the label is inconsistent; flag for review. The 2022 frontend config lists only pools 1–4 with 7 tokens (`USDC, ETH, DAI, WBTC, USDT, wstETH, LORDS`); pools 5–8 were created later.

Core balances at sunset (block 1,397,398): **ETH 116.706354272091809887**, USDC 178,181.406181, USDT 51,030.218471, DAI 28,140.887807173863436297, WBTC 1,160,003 sats, LORDS 13,044.468139711354924654, wstETH 19.122960000245353755.

## 4. The upgrade / wind-down (2025-05-13)

**Upgrade transaction:** `0x5fb287a8f9099c2c258819ccb6e2baf97414308ff6ddbc8dafe98091603a418`
- Block **1,397,399**, timestamp **2025-05-13T10:44:48Z** (block 1,397,400 = 10:45:18Z).
- Sender = admin `0x1dec3416…`; v3 invoke; nonce `0x212`; multicall calldata: `upgrade(0x40b83509…)` ×2 then `assert_admin()` (selector `0xd246002f…`).
- Events (emitted by core): `Upgraded` (`0x2db340e6…`) with data = new class `0x40b83509…`, plus a second event `0x13028670…` (alias/admin-related) with the same class hash.
- Proxy class history measured: `0x7e35b811…` at blocks 100,000–1,250,000 → `0x40b83509…` at 1,397,399 onward.

**What happened to V1 LP funds (on-chain):** Immediately the same day, the admin began calling the new `distribute_tokens(token_address, ledger)` to push pooled tokens back out to holders, in batches of **100** `(owner, amount.low, amount.high)` ledger triples per tx (`calldata` length `0x12e`; sample tx `0x33f2f3c41a6c33caf3fa3d8409fef8ad47894313a3a0ffdbf420283a3f895f8`, 100 ETH `Transfer` events to distinct recipients, e.g. `0x2e5ae827…` 662,398,716,586 wei, `0x4d73adc7…` 10,276,393,839,687 wei).
- ETH balance curve (core): unchanged 116.706359… through block 1,398,050 → 22.363005541015275972 at 1,398,150 → 2.872281779905427531 at 1,398,159 → 0.082693710943884552 at 1,398,160 (16:29:03Z) → 0.000326988424641313 at 1,398,200. The bulk of the outflow happened roughly **16:04–16:29 UTC**.
- Net distributed (sunset balance − dust, ≈): ETH **116.7060**, USDC **178,181.33**, USDT **51,030.19**, DAI **28,140.89**, wstETH **19.12296**, LORDS **13,044.47**, WBTC **0.01159581**. Remaining dust today (matches the dust reported in the audit context): 0.011576988424641313 ETH (0.01125 ETH was sent back in later), 0.074318 USDC, 0.031378 USDT, ~0.000000000000013162 DAI, 422 sats WBTC, 0.000000000000004052 wstETH, ~970 wei LORDS.
- LP token supplies today are **unchanged** from sunset (e.g., pool 1 supply = 1,874,308,956,727,175), i.e. LP tokens were never burned; holders received underlying assets instead. LP tokens are now stale.

**Announcements:** none found. Medium `@mySwap_StarkNet_AMM` has no post after Sep 26, 2022; `docs.myswap.xyz` now documents only CL (no V1/sunset page in `llms.txt`); no sunset/migration post was found on X. The strongest documentary evidence is the last V1 frontend commit at **10:26:45Z** (18 minutes before the upgrade) plus the on-chain sequence, and DefiLlama's `hallmarks: [['2025-05-13','Sunset of MySwap']]` / `deadFrom: '2025-05-13'`. Treat "no public announcement" as a finding, not a gap in search effort.

## 5. CL hack — technical record (2026-06-19)

- **Time/block:** attack block **10,951,083 = 2026-06-19T07:15:01Z**; exploit tx at block 10,951,100.
- **Exploit tx:** `0x1c15c4064cb3d72df27a35dfcd2da17c108abfb8e671428cb9d457f698f588` (sender = attacker `0x029f9de5cafb30f55e4a6f4f032e8774958520c1649b3a0441f1354c0b330518`; 128 events).
- **Fake token:** `EVIL` `0x028c9acd8eb7dc1cd7e3da98da3997cb57beca3c39d425e90780195df3a9a49e` (GoPlus abbreviated it `0x028c9a`).
- **Exploited contract:** CL singleton `0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111`.
- **On-chain event trace of the tx:** 12 × `PoolCreated`, 12 × `Initialize`, 12 × `Mint`, 12 × `Burn`, 12 × `Collect` (decoded selectors: PoolCreated `0x27dd458d…`, Initialize `0x3610d518…`, Mint `0x34e55c1c…`, Burn `0x243e1de0…`, Collect `0x33b678d8…`), plus 38 ERC-20 `Transfer` and 25 `Approval` events. The 12 pools are the EVIL token paired with **ETH, STRK, USDC, USDT** at fee tiers/spacings **500/10, 3000/60, 10000/200** — i.e. one atomic tx that created pools, added liquidity, burned and collected against all real-token pools of the shared singleton.
- **Losses (GoPlus; consistent with F12):** 137.96 ETH, 230,167.88 STRK, 45,123.91 USDC.e, 19,945.24 USDT ≈ **$305K**. mySwap says ~$300K and that the attacker bridged funds and used Railgun.
- **mySwap statement (X, 2026-06-19T12:05:41Z, status 2067941891010711560):** *"Security update: at 7:15am UTC today, the mySwap CL protocol was exploited, resulting in ~$300K being drained from liquidity pools. The mySwap interface has been closed to new liquidity for the past 6+ months, and the remaining balances were mostly residual LP positions spread across over 100K positions. The attacker has bridged the stolen funds and used Railgun to obfuscate the flow of assets. The exploit has drained nearly all remaining liquidity from the protocol."* (myswap.xyz now shows the same text, with "over 55K positions".)
- **F12 (X):** *"Attacker deployed a fake 'EVIL' token to manipulate the pool accounting and drain the shared vault: 137.96 ETH, 45K USDC, 19.9K USDT, 230K STRK. Real permissionless exploit, not a rug."*
- **Public technical write-ups:** AUTOSEC.DEV incident review is the most detailed; it explicitly notes *"the reviewed sources did not disclose the vulnerable function or transaction trace"* and classifies it as *"fake-token validation and concentrated-liquidity accounting failure"* (recommends binding pool assets/positions/vault balances to trusted token contracts). SlowMist and cryptotimes are incident summaries; no F12/Blockaid/0xposed source-level post-mortem was found, and mySwap published no post-mortem.
- **Mechanism characterization (evidence-based, not source-verified):** this was **not** a V1-style join/exit or "vault shares" ledger bug. The attack path is the CL **position-lifecycle accounting on the shared singleton** — `Mint`/`Burn`/`Collect` cycles using a self-issued fake token as one side of newly created pools — which let fake-token state unlock real pooled balances held by the singleton. The precise missing check is **not publicly established** (the class is Sierra at `0x40974d…`; no source-level root cause has been published). Any report should keep that caveat.

## 6. Audits

- **V1:** no audit report, audit page, or audit reference found. Searches (web + GitHub), the V1 frontend/docs, and DeFiLlama metadata show nothing; Voyager shows the implementation class unverified. **The "0 audits" claim is consistent with public evidence — no denial found.**
- **CL:** DefiLlama-adjacent enrichment (`guil-lambert/defipunkd` `data/enrichment/myswap-cl/audits.json`, extracted 2026-04-29) lists **no audits**; no audit report found in web searches either. Note the CL docs (`docs.myswap.xyz`) never mention audits.

## Key sources / raw evidence

- DefiLlama V1 adapter: `github.com/DefiLlama/DefiLlama-Adapters/blob/main/projects/myswap/api.js` (+`abi.js`) — core address, `get_total_number_of_pools`/`get_pool`, `hallmarks: [['2025-05-13','Sunset of MySwap']]`, `deadFrom: '2025-05-13'`.
- DefiLlama CL adapter: `projects/myswap-cl/index.js` — singleton `0x1114c710…`, token list S3 URL.
- V1 frontend (official build): `github.com/myswapxyz/v1` (`gh-pages`), commit `3c87bb5c12d84768065f9c5e442597330cf28712`, 2025-05-13T10:26:45Z — full AMM ABI, `ammContractAddress 0x10884171…`, pool/token config, `version 16777216`.
- Static config: `github.com/myswapxyz/static_data` (`db.json` goerli deployment 2022-06-03).
- Voyager: `voyager.online/class/0x55ef1b2cb1313b8202f68ef32aaefca4133b21cbce68c4bfee453e595ce646f` — "Class is not verified…", declared 2022-10-24, tx `0x3915a765…`.
- mySwap X statement: `x.com/mySwapxyz/status/2067941891010711560`; current notice at `myswap.xyz`.
- GoPlus: `x.com/GoPlusSecurity/status/2068336316061028626` (attacker / EVIL / contract links).
- AUTOSEC: `blog.autosec.dev/security-events/myswap-cl-fake-evil-token-305k-exploit`.
- Attack tx: `voyager.online/tx/0x1c15c4064cb3d72df27a35dfcd2da17c108abfb8e671428cb9d457f698f588`.
- On-chain reproduction: public RPC `starknet-rpc.publicnode.com`, blocks 1,397,398 (pool state), 1,397,399 (upgrade), 1,397,400–1,398,300 (distribution), 10,951,083–10,951,100 (CL exploit), 15,840,660 (current).

## Gaps / unverified items

1. **No V1 contract source or commit** (never published/verified) — architecture above is ABI/selector- and behavior-based.
2. No public announcement of the V1 wind-down was located (Medium/docs/X).
3. Exact permissioning of `create_new_pool` (whitelist vs permissionless) cannot be proven without source.
4. CL hack root-cause function/check is not in the public record; only the on-chain function classes used are established (create/initialize/mint/burn/collect).
5. No CL/V1 audit reports found.
