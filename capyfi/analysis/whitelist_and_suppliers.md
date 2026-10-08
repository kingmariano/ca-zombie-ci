# C2-13 "Capyfi" (Ethereum) — Whitelist Gate & Cash/Collateral Suppliers

Read-only investigation (no transactions signed/sent; view calls only).
Sources: public RPC `https://ethereum-rpc.publicnode.com` + Etherscan V2 (free tier; `getLogs` full-range paginated).
Raw structured data: `c-13/analysis/ethereum_holders.json`.

**Blocks used** (all reads at "latest" of the moment):
| read | block |
|---|---|
| whitelist / feeds / token basics | 26149522 |
| market scan (comptroller, cToken params) | 26149474 |
| borrower live state (`getAccountLiquidity`, `borrowBalanceStored`) | 26149650 |
| topic decode / migration inspection | 26149752 |
| RPC/LAC token `balanceOf` holder checks | 26149793 |
| mint-pause recheck | 26149809 |

---

## TL;DR

* **Whitelist gate = HARD for unprivileged users.** `isWhitelisted(a) == hasRole(WHITELISTED_ROLE, a)`; the role can only be granted by `DEFAULT_ADMIN_ROLE`, held by a single **team Gnosis Safe 4-of-7** (`0x6C15…eD24`). Exactly 3 whitelisted EOAs, no revocations ever, no self-registration / batch-add / public address, UUPS upgrade also admin-gated. Mint is the **only** whitelist-gated user function and is **not paused** (block 26149809) — so the whitelist is the whole gate. **No unprivileged mint path exists today.**
* **Historical caveats:** caLAC had **no whitelist at all until block 23235190** (mint permissionless before that), and caRPC ran through temp whitelists, one of them **inactive** (check skipped) between blocks 23248204–23284148.
* **caLAC cash (117.33M LAC ≈ $1.18M at oracle):** 98.33% of cLAC supply supplied by **non-whitelisted EOA `0x677f69…`**, which minted its 117.32M LAC **pre-whitelist** (blocks 22224811 / 22520679 / 22618144). Its LAC was released via the **team-operated ChainBridge** and migrated 1:1. It has since **borrowed ~$695k of USDT+USDC** against it at ~98% of max LTV. That is the real value outflow.
* **caRPC cash (4.09B RPC ≈ $43.3M at oracle):** 100% supplied **post-whitelist** by whitelisted EOAs `0xb6e175…` (75.5%), `0x9fb13a…` (24.5%) and admin Safe (0.002%), **all funded directly by the team RPC treasury Safe `0xf0b223f5…`** immediately before minting. → **P (team)**.
* **RPC token ("Ripio Coin", 2018 vintage):** 53.4% of supply held by the team Safe `0xf0b223f5…`. Live market = Uniswap **v4** RPC/USDC pool (~$19.6k TVL, spot $0.010620, ~$1.4k 24h vol — see sibling `lac_rpc_liquidity.md`); all V2/V3 pools are dead (~$10, stale since 2026-09-08). The $0.0106 oracle is **team-set** (1-of-1 Safe updater, bounds [0.01, 0.02]) and sits ~0.2% **below** v4 spot — the problem is depth (pool absorbs ~$9.8k), not spot.
* **Liquidatable now (shortfall > 0):** `0x7cca92…` **$2,015.80** (dust collateral ⇒ bad-debt shaped), `0xced20c…` $48.60, `0x492d25…` $1.90, `0x1e1c8a2b…` $1.42, `0x54c32309…` $0.20.

---

## 1. Whitelist contract & gate strength

**Proxy** `0x302a893B1AC44fed29Cdf3e3a0a083d1Df3ce54E` (ERC1967Proxy, impl `0x6b787016c8aea6e929fba643178e453eaad0f750`, "Whitelist", UUPS). Live at block 26149522:

* `isActive() == true`; `WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE") = 0x8429d542…8c3b49`.
* `getRoleAdmin(WHITELISTED_ROLE) = DEFAULT_ADMIN_ROLE`; `getRoleAdmin(DEFAULT_ADMIN_ROLE) = itself`.
* **DEFAULT_ADMIN_ROLE members (1):** `0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24` = **Gnosis Safe v1.4.1, threshold 4-of-7**; owners: `0xa40D7d22…`, `0xf7104Ad3…`, `0x5CA3F8EEBa12D83408fc097c2dAd79212456F20F` (LAC token deployer), `0x23ceC92F…`, `0x5b72e13f…`, `0x9850b4F6…`, `0x00A74411…`. Same address is comptroller admin, all cToken admins, and owner of both price feeds.
* **WHITELISTED_ROLE members (3), all EOAs:** `0xBac110FFEC95464Ab5F25d2DAe75C0aeA92F4C29`, `0x9FB13A7dF5D66698bC47E719578F923d853F0ee3`, `0xB6E1757763BdF04C22e25F13676C3488E4d3178b`.
* Zero address, `0x…dEaD`, comptroller, both cTokens and the whitelist impl are **not** whitelisted/admin.
* Implementation logic (`c-13/analysis/sources/wl_impl.sol`, lines 2298–2431): OpenZeppelin `AccessControlEnumerableUpgradeable`. Adding = `grantRole` (admin-only); `renounceRole` self-only; **no `addToWhitelist`/`batchAdd`/self-registration** anywhere. `activate()/deactivate()` admin-only. UUPS `_authorizeUpgrade` requires DEFAULT_ADMIN_ROLE.
* **All-time grant history** (Etherscan logs, proxy): admin granted to `0x6c15e4…` at block 23233683 (by deployer `0x6a138b…`); WHITELISTED_ROLE granted to the 3 EOAs at blocks 23235190, 23284155, 23347083 (all by `0x6c15e4…`). **Zero `RoleRevoked` events.**
* cToken gate: `mintInternal` carries `_checkWhitelist(msg.sender)`; the check is **skipped when `whitelist == 0` or `!whitelist.isActive()`**. `redeem/borrow/repay/transfer/transferFrom/seize/liquidate` are **not** gated. `_mintGuardianPaused` global = false; per-market `mintGuardianPaused` = false for caLAC/caRPC (recheck block 26149809).

### Per-market whitelist timeline (`NewWhitelist` events)

* **caLAC** (deployed 22086756): `0x0 → 0x302a893B` at block **23235190** (tx `0x9efe1a97…`, same tx as first role grant). No other changes. All mints at blocks < 23235190 were permissionless; every mint ≥ 23235190 is by a then-whitelisted address (`0xbac110…`, `0xb6e175…`).
* **caRPC** (deployed 23247610): `0x0 → 0x302a893B` (23247933) → `0x77d6f2ed…` (23248134, still `isActive()==true` but **0 members**) → `0x9a3b3e4a…` (23248204, **`isActive()==false`**) → back to `0x302a893B` (23284148). During the inactive window the whitelist check was skipped. In the 23284148 tx the admin Safe **minted 100k RPC while the inactive whitelist was still attached, then switched back** (Mint log index 0x174 < NewWhitelist log index 0x177). Since 23284148 all caRPC mints are by whitelisted addresses (`0x9fb13a…`, `0xb6e175…`).

**Verdict:** an unprivileged attacker **cannot** mint caLAC/caRPC today by any path: no permissionless role path, admin is a 4-of-7 team Safe, all 3 whitelisted addresses are EOAs (no routing contract), and mint is unpaused so the whitelist is actively binding. Residual surface: cToken **transfers are not gated**, so cLAC acquired on the secondary market can still be used as collateral (cf 60%) — but no new supply can be created.

---

## 2. Who supplied the cash

### caLAC (`0x0568F6cb…`) — 117,332,608.315942560922722079 LAC ≈ **$1.175M** at oracle $0.010015 (block 26149522)

* 41 Mint events total. Top minters: `0xb6e175…` 9.454B (post-whitelist; later redeemed), `0xbac110…` 6.254B, `0x44076095…` 129.0M, **`0x677f69…` 117.322M**, `0x0e3b96…` 45.4M, etc.
* **Current supplier: `0x677f699053987fa3f6c52506b4c9317bbf63af47` holds 577,890,834,685,431,256 cTokens = 98.33% of total supply** (worth ~115.58M LAC ≈ $1.157M). Its mints: blocks 22224811 (50.0M), 22520679 (15.99358M), 22618144 (51.32845M) — **all before the whitelist existed on caLAC** (23235190). Not whitelisted, never was.
* **LAC provenance:** legacy LAC (`0x7d12bcab…`, old "LaCoin") was released to `0x677f69…` by the **ChainBridge proxy `0x450cbb88…`** via relayer votes from `0x037c7427…` and `0xac275029…` (both funded by `0x63789f76ba61e62a4b91c6e1349a733996d9810a`) at blocks 22224681 / 22497422 / 22617801; then `migrate()` on the team's **LaCoinMigration** contract `0x39b0899f…` (impl `0x809a292a…`, holds the full 10B LAC supply) at 22224711 / 22497584 / 22618138; then minted into caLAC ~30–100 blocks later.
* **Value outflow:** `0x677f69…` has borrowed **588,292.15 USDT + 107,249.70 USDC ≈ $695.5k** from caUSDT/caUSDC, plus ~9.0 ETH of cETH_B collateral; `getAccountLiquidity` = +$17.0k (≈98% of max LTV). The LAC is team-issued; the stables it extracted are real.
* Remaining ~1.7% of supply: other pre-whitelist minters (`0x0e3b96…`, `0xc6b3ea…`, `0xbac110…`, `0x260d0f…`, `0xfa79a9…`, `0x44bdea…`, `0xb019e5…`).
* **Interpretation:** EOA not on the whitelist, not a team Safe, active since 2023 (Aave user) — but its LAC arrived through team-run bridge relays (likely OTC/partner flow; cross-chain origin unverifiable from Ethereum). It behaved as the classic "supply LAC → borrow stables" position, executed **legally in the pre-whitelist era**. Classify the LAC cash as externally-held (E-U if treated as third-party; P-adjacent if the bridge flow is considered team-coordinated); the **$695k stablecoin outflow is the concrete value extraction**.

### caRPC (`0xF61159B4…`) — 4,090,155,904.787103532336474708 RPC ≈ **$43.35M** at oracle $0.010598 (block 26149522)

* 5 Mint events. Current cToken holders: `0xb6e175…` 15,450,779,015,045,170,817 (75.55%), `0x9fb13a…` 5,000,000,000,000,000,000 (24.45%), `0x6c15e4…` (admin Safe) 500,000,000,000 (0.0024%).
* **Funding chain (Etherscan token transfers):** team RPC treasury Safe `0xf0b223f5…` (Gnosis Safe 3-of-7, owners overlap the admin Safe) sent **1.090155892B RPC to `0xb6e175…` at block 24849239** and **2B at 24971801**; `0xb6e175…` minted into caRPC at 24872385 / 24972160. It sent **1B RPC to `0x9fb13a…` at 23289887**, which minted at 23299835 / 23325630. Admin Safe minted 100k at 23284148.
* **Interpretation: P (team).** The entire caRPC cash is team RPC, moved Safe→EOA→cToken. Outstanding caRPC borrows are negligible (116.93 RPC ≈ $1.24, borrower `0xbc37de7a…`, no shortfall).

---

## 3. RPC token status & oracle reality

* `0xEd025A9Fe4b30bcd68460BCA42583090c2266468` — **"Ripio Coin" (RPC)**, 18 dec, `totalSupply = 9,997,912,985.0 RPC`; deployed 2018 at block 13231201 by `0x5f4f43ba…` (old project token).
* **Holders (live `balanceOf`, block 26149793):** `0xf0b223f5…` **5,342,033,534.33 (53.43%)** — team Safe 3-of-7; `0x163f7da0…` 81.68M; `0x98329910…` 43.89M; `0x784e4d53…` 9.0M; UniV2 pair 512.71; `0xb6e175…` 18.04; most other historical holders are at 0. (Etherscan `tokenholderlist` is Pro-only; the Transfer log scan is capped at 10,000 records, so this is a partial list + live checks.)
* **DEX (my V2/V3 read + sibling v4 cross-check in `lac_rpc_liquidity.md`):**
  * Live: Uniswap **v4** RPC/USDC pool `0xd8442c1d…` — 923,771.35 RPC / 9,810.75 USDC (~**$19.6k TVL**), spot **$0.01062032**, ~$1.4k 24h vol, no hook.
  * Dead: V2 WETH pair `0x01f82214691b4ac9A0A88c2D84690B231F2F0623` — 0.0019698 WETH + 512.71 RPC (**~$9.7**), last update 2026-09-08; V3 pools `0x166B5fD1…` and `0xdfc9b111…` — **liquidity = 0**; v4 RPC/USDT and RPC/ETH pools — active liquidity 0.
* **Oracle price $0.01059766** (feed answer 1059766 @ 8 dec) sits **~0.2% below** the live v4 spot and inside bounds [0.01, 0.02]. It is a team-set number; the pools are far too thin to be a market anchor (a $100k RPC sale nets ≈ $8.9k).
* LAC: only live market is the Uniswap **v4** LAC/USDC pool `0xa8f7d314…` — 419,363.74 LAC / 4,259.97 USDC (~**$8.5k TVL**), spot **$0.01015818**; oracle $0.010015 is 1.4% **below** spot. No V2/V3 pairs exist; the pool can absorb only ~$4.3k.

---

## 4. Borrowers & liquidatable accounts (block 26149650)

Shortfall = 3rd return of comptroller `getAccountLiquidity` (USD 1e18 scale; `0` = none). All 5 flagged accounts have `assetsIn` including the borrowed markets, so the numbers are live.

| borrower | shortfall | current borrows | cToken collateral (live) | note |
|---|---|---|---|---|
| `0x7cca923387a3ce8d1f36354f8385aa9045798d51` | **$2,015.80** | caLAC 201,314.7048 LAC; caWARS 0.0385 | caUSDC 13,801,229 (≈$0.003); caETH_B 904,997 (≈0.000186 ETH ≈ $0.45) | **bad-debt shaped** — max seizable collateral ≈ $0.5 vs $2k debt; entered caETH_B/caRPC/caWARS/caUSDC/caLAC. Fresh 2025 wallet funded from `0x97d24df1ebcf883753a164423fb0b774c7944b07` |
| `0xced20c61a72d6ed57eca5afbcaff6f9a5d1e9e77` | $48.60 | caLAC 4,890.1674 LAC | caETH_B 942,389 (≈$0.47) | same bad-debt pattern |
| `0x492d255234c83f2ddc5aa904d8a9db6743e9f046` | $1.90 | caLAC 429.3045 LAC; caWARS 1.7446 | caUSDT 19,786,750,038 cTok (≈$4.17) | marginal |
| `0x1e1c8a2bda1ee312a373f9ced6d1037aa1e5918f` | $1.42 | caLAC 141.8420 LAC | caETH_A 83,339,156 cTok (cf=0) | marginal |
| `0x54c32309b67e72bd44899e46ec630d14eb96125f` | $0.20 | caUSDT 0.600152 | caUSDC 48,438,823,547 cTok (≈$10.28); caETH_B 996,119 | dust |

Other live borrower of note: `0xbc37de7a62a81d519db7ebf9ae59278ca021fcf6` — caRPC 116.928151081298845158 RPC, liquidity +$0.26, **no shortfall** (the only outstanding caRPC borrow). caLAC borrower `0x7cca92…` fully repaid its earlier caRPC borrow (459k RPC). Full per-borrower data for all markets (caLAC, caRPC, caUSDT, caUSDC, caWBTC, caETH_A, caETH_B) is in `ethereum_holders.json → borrowers_all_markets`.

Comptroller: closeFactor 0.5, liquidationIncentive 1.08, admin = team Safe, pendingAdmin/pauseGuardian = 0.

---

## 5. CapyfiAggregatorV3 feeds

| | LAC/USD `0xF3585f9D9a671e630055Ce0c436AA214954ce6D4` | RPC/USD `0x5da9a0bc9342b801640366e61592EE50E0285437` |
|---|---|---|
| owner / pendingOwner | `0x6C15e4Bc…eD24` / 0x0 | same |
| decimals / latest answer | 8 / **1001500 = $0.010015** | 8 / **1059766 = $0.01059766** |
| min/max bounds, checks | 850000 / 1150000, enabled | 1000000 / 2000000, enabled |
| authorized updater now | `0xbf41c0dc…` (only) | `0xbf41c0dc…` (only) |
| update history | 2029 `AnswerUpdated`, min $0.007793, max $0.012097 (343 distinct) | 2356 updates, min $0.01000055, max $0.01338038 (1695 distinct) |
| latest update | 2026-10-08 17:14:23 UTC (block 26149104, ~1.5h before reads) | same timestamp |
| updater identity | Gnosis Safe 1-of-1, owner EOA `0xaCDC3EBA833Ec6Edb048C109956440Fcf0985314` (funded by `0x63789f76ba61…`, a 7702-EOA that also funds the ChainBridge relayers) | same |

* `updateAnswer` is callable by owner or authorized addresses; `addAuthorizedAddress/removeAuthorizedAddress/setBounds/toggleBoundsChecking` are owner-only. Only one `AuthorizedAddressAdded` ever per feed (`0xbf41c0dc…`), zero removals.
* Bounds history: LAC [1.0,2.0] (block 23097751) → [0.5,2.0] (23383100) → **[0.85,1.15]** (24742538); RPC [1.0,2.0] set once (23919827). Ownership: LAC deployer `0x6a138b…` → team Safe (22989120→~23636627); RPC same pattern (23833750→~23843163).
* **Prices are pushed by a single team 1-of-1 Safe, are bound-checked, and are fresh (~3h cadence), but entirely discretionary** — the only "anchors" are near-empty v4 pools (LAC/USDC ~$8.5k; RPC/USDC ~$19.6k); oracle sits slightly below both spots.

---

## 6. Classification summary

| value | size (oracle) | supplier | class |
|---|---|---|---|
| caRPC cash | 4.09B RPC ≈ $43.35M | whitelisted team-funded EOAs + admin Safe | **P** (team) |
| caLAC cash | 117.33M LAC ≈ $1.18M | 98.3% non-whitelisted EOA `0x677f69…`, pre-whitelist mints, LAC via team bridge+migration | **E-U / P-adjacent** — team-issued LAC supplied by a third-party-looking EOA; **$695k stables already borrowed out** |
| caLAC bad debt | ≈ $2.0k (0x7cca92) + ≈ $51 (others) | borrowers with dust collateral | **S (stuck/lost)** — not meaningfully liquidatable |
| caRPC bad debt | ~$0 | none | — |
| RPC/LAC price integrity | $0.0106 / $0.010015 | team 1-of-1 Safe updater, bounds; ~0.2% / ~1.4% **below** thin v4 spot ($19.6k / $8.5k pools) | **P** (discretionary price, no real depth) |

## 7. Blockers / caveats

1. Etherscan free tier: `tokenholderlist` is Pro-only → holder sets were rebuilt from `getLogs` Transfer (capped at 10,000 records for the RPC token; caLAC/caRPC complete) + live `balanceOf` for candidates.
2. No archive node: all values are latest-state (blocks above); borrower/exchange-rate numbers drift slightly between reads.
3. Cross-chain origin of `0x677f69…`'s LAC (which domain it bridged from, and whether it bought it from the team) is not verifiable from Ethereum alone.
4. The `0x9a3b3e4a…` temp whitelist is `isActive()==false` now; its inactive state at block 23284148 is inferred from the in-tx log ordering (Mint before NewWhitelist) and the successful mint by a non-whitelisted admin.
5. `0x6a138b…` and `0x63789f76ba61…` are EOAs using **EIP-7702 delegation** (code `0xef0100…`), i.e. smart-account-augmented EOAs.
