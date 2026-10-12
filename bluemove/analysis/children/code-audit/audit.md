# BlueMove AMM (Sui) — Phase-2 Code Audit (child: code-audit)

Scope: disassembly of three deployed upgrade versions of the BlueMove AMM + stable module,
verification of the parent's four formula hypotheses, full entry-point/en-gating inventory,
desync/exploitability preconditions, and live verification (read-only GraphQL reads + simulations).
No transactions were built, signed, or executed; no secrets used.

Working dir: `/home/heisenberg/CA/bluemove/analysis/children/code-audit/`
Inputs: `/home/heisenberg/CA/bluemove/analysis/{pkg,vmid,vlatest}_*.disasm` (parent's disassembly),
plus on-chain `moduleBcs` re-disassembly via `/tmp/opencode/sui-cli/sui move disassemble`
(children/code-audit/modules/*), plus public GraphQL reads/simulations.

---

## 0. VERDICT IN ONE PARAGRAPH (with corrections to the parent's understanding)

The AMM has **three disjoint token stores** for the same logical pool while `reserve_x/reserve_y`
(+`k_last`) are **single shared fields**: V1 uses `pool.token_x/token_y` (store "T"),
V-mid (0x08cd) uses dynamic field `EscownCoins` (store "EM") and V-latest (0x35f3) uses
`EscrowCoinsV2` (store "E2"). Each version writes `reserves := its own store` after every op, so
mixing versions desyncs the reserves from a store. The parent's core hypothesis is REAL but its
trigger and its "which version is active" facts are wrong in several places:

1. **V1 has no version gate — confirmed.** V1 `router::{add_liquidity, remove_liquidity, swap_*}`
   are callable by anyone today (live proof: 2026-10-12 swap tx `9rjCSkLRWR...` calls
   `0xb24b6789...::router::swap_exact_input_`).
2. **The expected version constants are 8 (0x08cd) and 11 (0x35f3) — not 7 and 12** (the "7"/"12"
   are *package object versions*; see §1). **V-mid expects 8** and **V-latest (v12) expects 11**.
3. **Both gated versions are OFF today**: live `VersionManage.version = 12`; simulations of
   `0x08cd::swap::assert_version_contract` and `0x35f3::swap::assert_version_contract` both abort
   **25** (independent + parent's own sims agree). No package in the lineage v7..v12 expects 12
   (constants: v7=8, v8=8, v9=8, v10=10, v11=10, v12=11). **The entire gated lineage is currently
   disabled; only V1 (and ungated v2–v6 clones, §6) can execute.** This directly contradicts
   "V-latest active".
4. **V1 burn does NOT use reserves**: `out = token_balance * lp / supply` (the V1 store balance is
   the multiplier). V-mid and v12 burns use `out = reserves * lp / supply` and split from their
   escrow. V1 mint does use `dx = token_x - reserve_x` as assumed.
5. The unprivileged desync lever is **v12/v11/v10 `swap::sync_pool`** (public, no dev gate):
   it *overwrites* `reserve_x/reserve_y := EscrowCoinsV2` and `k_last := product`, for any pool that
   has an `EscrowCoinsV2` dynamic field. It cannot move coins itself, but it is the missing piece
   that turns divergent stores into extraction (details §5). `skim_pool` is a dead stub (abort 26);
   `withdraw_fee_direct`/`withdraw_fee_` are dead stubs in v7/v12 (abort 1) — do not chase them.
6. **v2–v6 are ungated V1 clones with extra privileged backdoors** the parent did not analyze:
   v2 `withdraw_fee_` is `entry public` and v3/v4/v5 `withdraw_fee_direct` are public — all gated
   only by five hardcoded operator addresses (`0x9c8c…`, `0x97a7…`, `0x5e99…`, `0x95d6…`, `0xa675…`);
   they withdraw `token * amount / supply` from any pool **without burning LP**. Privileged, but
   permanent (no version gate in v2–v6).
7. **V-mid's `add_liquidity` aborts on any pool that already has an `EscownCoins` field** (it
   unconditionally calls `dynamic_object_field::add`, lines 1121–1159; v12 fixed this with an
   exists-check, lines 1389–1488). Consequence: the "inflate LP via vmid mint" leg is unusable on
   funded vmid pools, and liquidity could only ever be added once per pool in the vmid era.
8. **Primed live pools**: 12 of the parent's 600-pool escrow sample hold BOTH a funded V1 store (T)
   and a funded EscrowCoinsV2 (E2) with **ratio divergence 1.2e5×–9.0e7×**. The moment a
   `sync_pool`-bearing version becomes callable (VersionManage set to 10/11, or a new package),
   ungated V1 swaps/redemptions can extract at the E2-derived (manipulated) price. Addresses and
   numbers in §7.

---

## 1. Versions, packages, gates (verified)

Lineage (GraphQL `packageVersionsAfter`, all modules keep self-address `0xb24b6789…` — the
original package; struct/type origins follow the version that introduced them):

| set | package id | obj ver | `utils::get_contract_version()` | `assert_version_contract`? | status with live VersionManage=12 |
|---|---|---|---|---|---|
| V1 `pkg_*` | `0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9` | 1 | n/a (no function!) | NO gate anywhere | **CALLABLE** (used live today) |
| v2 | `0xdc8437d021efc026249b796ce5375ce60433a5dd9c05cf6aee8668dc2191a8ad` | 2 | n/a | NO | CALLABLE |
| v3–v6 | `0xdf87af8c…`, `0xb574a776…`, `0x941f5ee6…`, `0xa00faab5…` | 3–6 | n/a | NO | CALLABLE |
| v7 `vmid_*` | `0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f` | 7 | **8** | yes (abort 25) | **gated OFF** (sim: abort 25) |
| v8, v9 | `0x0cdcbc6a…`, `0x7be61b62…` | 8–9 | 8 | yes | OFF |
| v10, v11 | `0xc396a92a…`, `0xf72bd3b3…` | 10–11 | **10** | yes | OFF |
| v12 `vlatest_*` | `0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7` | 12 | **11** | yes (abort 25) | **gated OFF** (sim: abort 25) |

- Constants read from raw bytecode (`moduleBcs` → `sui move disassemble`), see
  `modules/*_utils.mv` / `version_constants.py`; also consistent with the parent's
  `vlatest_utils.disasm:29-33` (LdU64 11) and `vmid_utils.disasm:29-33` (LdU64 8).
- Live `VersionManage` (dynamic object field of Dex_Info `0x3f2d9f72…`, key = Dex_Info's own ID):
  type `0x08cd…::swap::VersionManage`, address `0x41d5f1c1…`, **version = 12**; last written by
   `0x35f3…::swap::migrate_contract_version` in tx `EanzxUeS…` (success) on **2026-07-12T01:24:51Z**.
- Therefore `assert_version_contract` aborts 25 for v7..v12 until VersionManage is changed to a
  value that matches an active package, or a new package expecting 12 is published.
- Live proof V1 is the working code path: swap txs `9rjCSkLRWRjxKXLsLiCtWDpPzRzh2zkXSmCBNMYk5k3y`
  and `FhwBTFkyANCyzVEG4F2xyJZeiWHee5STqkciSwvNQH4` (2026-10-12, both effects status SUCCESS) call
  `0xb24b6789…::router::swap_exact_input_` (plus aggregator packages).

## 2. Task A — formula verification (exact lines, abort codes)

Files cited by parent names; `vlatest_*` ↔ 0x35f3 (v12), `vmid_*` ↔ 0x08cd (v7), `pkg_*` ↔ 0xb24b (v1).
Abort codes are the module's own `LdConst[..](u64: N)` before `Abort` unless marked "Move".

### 2.1 V-latest (v12) — `vlatest_swap.disasm`
- **mint** (`2758-2902`), signature `mint<T0,T1>(&mut Pool, u64 balance_x, u64 balance_y, &mut TxContext)`:
  - `dx = balance_x - reserve_x` u128 (`2771-2778`); `dy = balance_y - reserve_y` (`2779-2786`).
    Underflow = Move arithmetic abort (no custom code).
  - `mint_fee(pool)` first (`2787-2789`) — may mint protocol LP to `fee_amount`.
  - `supply == 0` → `LP = sqrt(dx*dy) - 1000`; requires `sqrt > 1000` else **abort 4** (`2805-2817`);
    1000 LP go to `minimum_liq` (`2819-2835`).
  - else `LP = min(dx*S/reserve_x, dy*S/reserve_y)` (u128, cast u64); requires `LP > 0` else **abort 4**
    (`2837-2868`).
  - `increase_supply(LP)`, `coin<LSP>` to caller (`2870-2882`); **`update(balance_x, balance_y)`**
    (`2883-2886`) → `reserve_x = balance_x`, `reserve_y = balance_y`; `k_last = reserve_x*reserve_y`
    (`2887-2898`).  ➜ Parent claim 1 VERIFIED. (Note: the balances are the **total EscrowCoinsV2
    balances after join**, passed by `add_liquidity_direct` at `1429`/`1473`.)
- **burn** (`2608-2756`): `out_x = reserve_x*lp/S`, `out_y = reserve_y*lp/S`, both from the **shared
  reserve fields** (`2622-2677`); `lp>0` else **abort 7** (`2640-2646`); `out_x>0 && out_y>0` else
  **abort 10** (`2696-2702`); `mint_fee` first (`2651-2653`); `decrease_supply`; splits from
  `EscrowCoinsV2` (`2709-2731`); `update(escrow_x_remaining, escrow_y_remaining)`; `k_last=product`
  (`2732-2751`).  ➜ Parent claim 2 VERIFIED. `remove_liquidity` also checks `is_freeze` → **abort 24**
  (`1505-1519`).
- **add_liquidity_direct** (`1213-1496`): reserves==0 both → use full deposit (`1253-1278`); else
  quote ratio check (`1280-1321`, **abort 8** if neither direction fits); used ≤ input (**abort 6**,
  `1344-1363`); split refunds; join into E2 (create at `1420-1424` or join at `1446-1473`); `mint`
  (`1429`/`1473`). `add_liquidity`/`add_liquidity_returns` reject `is_freeze` with **abort 24**
  (`1039-1044`, `1148-1154`) and reject zero LP with **abort 7** (`1077-1080`, `1187-1190`).
- **swap core** (`1978-2597`): both out-amounts 0 → **abort 13** (`2043-2048`); requires
  `out_x < reserve_x` AND `out_y < reserve_y` (i.e., both reserves > 0 for a real swap) else
  **abort 7** (`2050-2078`); joins input into E2 (or into `Pool.token_x/token_y` when E2 is absent —
  fallback branch `2348-2592`!), splits outputs; k-invariant check with 0.2%-skew:
  `(store_x_post*10000 - delta_x*20)*(store_y_post*10000 - delta_y*20) >= (reserve_x*10000)*(reserve_y*10000)`
  (`2227-2339`; overflow-guarded with `2^128-1` = constant `[36]`; **abort 15** at `2333-2336`);
  **`update(store_post_x, store_post_y)`** (`2338-2341` / `2584-2588`). **No `k_last` comparison in
  swaps.**
- **swap entry variants** reject `is_freeze` with **abort 24** (e.g. `1580-1593`, `1693-1706`).
- **update** (`3000-3011`): `reserve_x=Arg0; reserve_y=Arg1` (no k_last).
- **mint_fee** (`2904-2998`): skipped if `k_last==0`; else
  `fee = S*(√(r_x*r_y) - √k_last)*40 / (60*√k_last + 40*√(r_x*r_y))` minted to `fee_amount`
  (weights 40/60; V1 uses 10/20 — see `1922-2015`).
- Constants (`3309-3347`): `fee_to` init `0x85bf745a…`, `dev` `0x049c…`, `2^128-1` idx 36.

### 2.2 V1 — `pkg_swap.disasm`
- **mint** (`1766-1920`): `dx = token_x_value - reserve_x` (`1780-1796`); `dy = token_y_value - reserve_y`
  (`1797-1804`); supply==0 sqrt branch (`1813-1835`, **abort 4** if ≤1000); else
  `LP = min(dx*S/reserve_x, dy*S/reserve_y)`, **abort 4** if 0 (`1855-1886`); `update(token_x, token_y)`
  (`1901-1904`); `k_last = reserves product` (`1905-1916`).  ➜ Claim 3 (mint) VERIFIED.
- **burn** (`1627-1764`): **`out_x = token_x_value*lp/S`, `out_y = token_y_value*lp/S`** (store
  balances as multiplier — **NOT reserves**) (`1640-1694`); `lp>0` else **abort 7** (`1651-1663`);
  `out_x>0 && out_y>0` else **abort 10** (`1695-1719`); `mint_fee` first; splits from
  `token_x/token_y` (`1726-1739`); `update(token balances)`; `k_last` (`1740-1759`).
  ➜ **CORRECTION**: claim 3's "same formula shape" is wrong for burn.
- **swap core** (`1293-1616`): same shape as v12's fallback branch, but always uses
  `token_balances` = `pool.token_x/token_y` (`1417-1421`); **abort 13/7/15** at `1342-1343`,
  `1372-1373`, `1606-1607`; `update(token balances)` (`1609-1612`); no `k_last` read.
- **add_liquidity_direct** (`633-812`): quote checks **abort 8** (`725-726`), **abort 6**
  (`753-754`, `767-768`); joins into `token_x/token_y`; `mint` (`800-802`). `add_liquidity`/`remove_liquidity`
  reject `is_freeze` = **abort 24** (`545`, `834`).
- **admin**: `freeze_pool` dev-only **abort 17** (`263-266`); `set_fee_to` dev-only (`326-329`);
  `withdraw_fee` fee_to-or-dev **abort 17** (`377-383`), transfers 100% of `fee_amount`, `fee_x`,
  `fee_y` (`384-520`).
- **update** (`2018-2029`): same as v12.

### 2.3 V-mid (v7) — `vmid_swap.disasm`
- **assert_version_contract** (`117-146`): `utils::get_contract_version() == VersionManage.version`
  else **abort 25** (`142-143`); constant = **8**.
- **migrate_pool** (`203-326`): dev-only (**abort 17**, `221-227`) + gate; moves **all** of
  `token_x/token_y` into a new `EscownCoins` field if absent (`248-271`, `293-317`); no-op if the
  field exists. This is the V1→escrow migration primitive (dev-only).
- **mint** (`2436-2574`) / **burn** (`2286-2434`): byte-for-byte the same formulas as v12's
  mint/burn but on `EscownCoins`; same abort codes (**4** at `2490-2495`/`2541-2546`; **7** at
  `2318-2323`; **10** at `2374-2379`). `burn` uses **reserves** as the payout multiplier (`2336-2355`).
- **add_liquidity_direct** (`966-1174`): same quote logic (**abort 8** `1062-1063`; **abort 6**
  `1090-1091`, `1104-1105`) BUT **unconditional `dynamic_object_field::add` of a new `EscownCoins`
  at `1159`** — no exists-check. Any vmid `add_liquidity` on a pool that already has an escrow
  aborts inside `dynamic_object_field::add` (EFieldAlreadyExists). v12 fixed this
  (`exists` check at `1389-1394`, join branch `1446-1488`).
- **swap core** (`1656-2275`): identical shape to v12 (out<reserve **abort 7**, both-zero **abort 13**,
  k-check **abort 15** at `2260-2261`), E2→EM; falls back to `token_x/token_y` if `EscownCoins`
  absent (`1764-1772`).
- **update** (`2678-2689`): same. `token_balances` (`2728-2771`) reads EM or T.
- Admin: `migrate_contract_version` dev-only (**abort 0**); `create_new_pool_admin`, `freeze_pool`,
  `set_fee_to` dev-only (**abort 17**); `withdraw_fee` allowed senders = fee_to, dev, `0x9c8c…`,
  `0x97a7…` (**abort 17** otherwise, `642-773`); `withdraw_fee_` (`559-563`) and
  `withdraw_fee_direct` (`2879-2883`) are dead stubs (**abort 1**).

### 2.4 k_last — where used
- Written only in `mint`/`burn` (`k_last = reserve_x*reserve_y`, u128) and in v12 `sync_pool`.
- Read only by `mint_fee` (skip if 0; fee formula above).
- **Swaps never compare `k_last`** in any version; they enforce the local product invariant with the
  20/10000 fee skew (**abort 15**) and `out < reserve` (**abort 7**).

## 3. Task B — entry points a PTB can call (gating → abuse)

Legend: G=version gate (assert_version_contract, abort 25 when mismatched), D=dev/multi-sig gate,
F=frozen check, P=privileged (fee_to/dev/ops), U=unprivileged. "PTB" = callable from a programmable
transaction (public and entry functions are both callable from PTBs; confirmed live for
`0x21fc…::d::lsb` → `0xb24b…::router::swap_exact_input_`).

### 3.1 V1 (`pkg_swap` + `pkg_router`) — **no gate at all**
| function | vis | gating | writes/reads | abuse |
|---|---|---|---|---|
| `router::add_liquidity` | entry | none (auto-creates pool if missing, `swap::create_new_pool`) | T, reserves, supply | U (normal) |
| `router::remove_liquidity` | entry | none | T, reserves | U (normal) |
| `router::swap_exact_input`, `_output`, double/triple/quadruplehop (+ `_` variants) | entry/public | none | T, reserves | U (normal); see §5 |
| `swap::{mint,burn,swap,add_liquidity,remove_liquidity,add_liquidity_direct,...}` | friend/private | not PTB-callable (router only) | T | — |
| `swap::create_new_pool_admin` | entry | dev (abort 17) | pool creation | P |
| `swap::freeze_pool` | entry | dev (abort 17, `263-266`) | `is_freeze` | P |
| `swap::set_fee_to` | entry | dev (abort 17) | `fee_to` | P |
| `swap::withdraw_fee` | entry | fee_to or dev (abort 17, `377-383`) | drains 100% fee_amount/fee_x/fee_y | P |
| `swap::get_pool` (public, `&mut Dex_Info`→`&mut Pool`) / `get_amounts` / `token_reserves` / `token_balances` / `check_pool_exist` / event emitters | public | none | read/ref-return; emits events | U but harmless (event forging possible: `add_swap_event_internal`/`add_swap_event_with_address` are public and take arbitrary amounts) |

### 3.2 V-mid (0x08cd) — every entry point starts with `assert_version_contract` (**abort 25** today)
`router::add_liquidity`, `router::add_liquidity_returns` (public non-entry), `router::remove_liquidity`,
all `router::swap_*` → G → swap core. `swap::create_new_pool` (friend), `create_new_pool_admin` (G+D),
`freeze_pool` (G+D), `set_fee_to` (G+D), `migrate_contract_version` (+D, abort 0), `migrate_pool`
(+D, abort 17), `withdraw_fee` (G+P: fee_to/dev/0x9c8c/0x97a7), `withdraw_fee_`/`withdraw_fee_direct`
→ dead stubs (abort 1) — `assert_version_contract` itself is public (G). No unprivileged extraction
when active beyond normal swap/liquidity behavior; the interesting primitive is the broken
`add_liquidity` (no exists-check) and the fact that a v7-era op resets reserves to EM.

### 3.3 V-latest (0x35f3, v12) — same skeleton, plus:
| function | vis | gating | semantics | abuse |
|---|---|---|---|---|
| `swap::sync_pool<T0,T1>(&mut Dex_Info, ctx)` | **public** | G only (U) | `reserve_x/y := EscrowCoinsV2 balances`, `k_last := product` (`3207-3301`; update `3245-3248`; k_last `3249-3260`) | **the desync lever** — §5 |
| `swap::skim_pool` | public | — | dead stub, **abort 26** (`3201-3205`) | none (verified by sim) |
| `swap::withdraw_fee_direct` | public | — | dead stub, **abort 1** (`3303-3307`) | none |
| `swap::withdraw_fee_` | public | — | dead stub, **abort 1** (`744-748`) | none |
| `router::unfreeze_and_add_liquidity` | public | G | sets `is_freeze=false` then deposits; LP is sent to hardcoded `0x1937f2c5ce1cbab08893b63945c20cde349e4a7850eea317b965ff8da383c80e` (router const 6, `157`, `191`) | U: anyone can unfreeze a frozen pool by donating liquidity; no direct profit, breaks the admin freeze invariant |
| `swap::create_and_freeze_pool` | public | D (dev/0x049c, abort 17) | creates frozen pool | P |
| `swap::set_new_dev` | entry | D (current dev or 0x049c) | rotates `dev` | P |
| `swap::migrate_escrow_coins<T0,T1>` | entry | G+D (abort 17) | moves `EscownCoins`→`EscrowCoinsV2` without touching reserves | P (dev migration) |
| `swap::migrate_contract_version` | entry | D (abort 0) | writes version | P |
| `swap::migrate_pool` | entry | — | dead stub, abort 1 | none |
| `swap::withdraw_fee` | entry | G+P (fee_to / dev / 0x85bf const; abort 17 `871-872`) | 100% of fee buckets | P |
| `router::add_liquidity`, `add_liquidity_returns`, `remove_liquidity`, `swap_*` | entry/public | G | normal ops + slippage aborts 2/3 (add/remove) or 0 (swap) | U when gate passes |

### 3.4 Stable module (all versions of `stable_swap`/`stable_router`)
- **No version gate anywhere** (0 references in all six stable files; pkg/vmid stable_router are
  byte-identical, vlatest differs only by compiler version marker; vmid/vlatest stable_swap are
  byte-identical, pkg differs only in `update_oracle`).
- `stable_router::create_stable_pool` — **dev-only** (abort 1 if not `0x049c…`) in all versions.
- `add_stable_liquidity`, `remove_liquidity`, `swap_exact_input/output(+_)` — U; normal stable-swap
  with `is_freeze` checks (**abort 111**) and slippage (**203/202**, remove **106**); leftover input
  refunded via `pay::keep`.
- `stable_swap::{set_fee_to, set_dev_account, set_fee_config, freeze_stable_pool}` — dev-only
  (abort 17/112); `set_fee`, `set_dao_fee` — fee_to-only (abort 112); `withdraw_fee_stable_pool` —
  fee_to or dev (abort 17); `get_*` views public.
- `swap_coin_for_coin_unchecked[_]` — friend-only; **no router calls it** (dead code).
- Live: 1 stable pool `0xf47f15e0…` (COIN/COIN), `is_freeze=false`, fee=4 (1e-4?), dao_fee=30,
  inactive since ~2026-07-31 (oracle timestamp `1785473243129`); funds ~57.1M/68.0M raw units.
  **No reserve/store split → no desync class in stable pools.**

## 4. Task C — exact LP-inflation preconditions

For the *inflation* (supply>0) mint of any AMM version, the minting version uses store
`B` (T/EM/E2) and the shared reserves `r`:

1. Pool exists; `lsp_supply = S > 0`; **`r_x > 0` and `r_y > 0`** (else the u128 division by zero
   aborts; r=(0,0) therefore blocks all mints — sync_pool setting r to a zero escrow is a
   denial-of-service, not a drain).
2. `is_freeze == false` (else **abort 24**).
3. Store must cover the reserves: `B_x + d_x - r_x ≥ 0` and `B_y + d_y - r_y ≥ 0` (u128 underflow
   abort). This is why V1 ops abort on escrow-funded pools while their T store is 0 (sim s3:
   `balance::split` abort 2; sim s4: `utils::quote` abort 2).
4. Deposit ratio check against `r` passes (quote-based; **abort 8**), used ≤ input (**abort 6**).
5. `LP = min((B_x+d_x-r_x)*S/r_x, (B_y+d_y-r_y)*S/r_y) > 0` (**abort 4**).
6. **Inflation** requires `B_x > r_x` **and** `B_y > r_y` (store bigger than reserves on both sides):
   then LP ≈ `(B-r)*S/r` ≫ deposit, the minter owns ≈ `1 - r/B` of supply, `update` sets
   `r := B + d`, and burning that LP via any version whose payout store covers
   `out ≈ B + d` (in practice the same version) returns ≈ `B` for a deposit ≈ `d`; attacker profit
   ≈ `B - r` (the honest LPs' claim on the excess).
7. `minimum_liq` (1000 LSP) only exists in the S==0 branch; it does not gate later mints.
   The S==0 branch itself requires `sqrt(dx*dy) > 1000` (**abort 4**), so it cannot be inflated
   beyond sqrt-proportionality.
8. `k_last`: never compared in swaps; only `mint_fee` uses it; `sync_pool` overwrites it.

Cross-version burn/payout nuances (same preconditions apply to swap-based extraction):
- V1 burn/swap pay from **T**; V1 burn multiplies by **T values** (`T*lp/S`), V1 swap quotes by `r`.
- vmid/v12 burn pay from **EM/E2** and multiply by **r** (`r*lp/S`).
- v12 swap pays from E2 (or T if E2 absent) but quotes the k-check by `r`; vmid swap pays from EM
  (or T if EM absent).

## 5. The desync lever(s), precisely

Reserve writers and their stores:

| operation | writes r := | notes |
|---|---|---|
| V1 `add_liquidity`/`remove_liquidity`/`swap` | `T` (token_x/y post-op) | ungated; can only succeed if T covers the op |
| vmid (v7) `add/burn/swap` | `EM` | gated (abort 25 today); `add` aborts if EM exists |
| vmid `migrate_pool` (dev) | — | moves T→EM, r unchanged |
| v12 `add/burn/swap` | `E2` (or T in the no-E2 fallback) | gated (abort 25 today) |
| v12 `sync_pool` (public, ungated by dev) | **`E2` + `k_last := E2x*E2y`** | **forced overwrite**; requires E2 field to exist |
| v12 `migrate_escrow_coins` (dev) | — | moves EM→E2, r unchanged |

Attack shape (once a sync_pool-bearing version is gate-open):
1. Find/arrange a pool where a store `B` (T or EM) exceeds E2, with E2>0 on both sides.
2. `sync_pool` → `r := E2` (small).
3. Extract via the ungated/same-gate version's **swap** (cleanest: V1 swaps always callable):
   quotes use `r`, payouts split from `B`; the k-check also uses `r`, so it passes trivially.
   Each `sync_pool` resets `r := E2` again, so the trade can be repeated (same PTB or across PTBs).
   For a swap that trades the mispriced direction, the attacker can take up to ≈`r`-worth per
   iteration at a price up to ~1e8× off; with `sync_pool` re-arm, effectively drains `B` down to the
   E2-implied ratio. Mint-inflation (`add_liquidity`) is the alternative leg but is ratio-checked and
   (for vmid) broken by the exists-check bug — see §0.7.
4. Burns are the third leg: v12/vmid `burn` pays `r*lp/S` from the escrow `E2/EM`; V1 `burn` pays
   `T*lp/S` from T. Any LP holder can pick the version that pays best for the current `r`/store
   mismatch; the same-version mint+burn round trip nets ≈ (store − reserves).

## 6. Task D — LP type identity across versions (the "same LP coin" question)

- `struct LSP<phantom Ty0, phantom Ty1> has drop { dummy_field: bool }` is declared in module
  **`0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9::swap`** in all three
  disassemblies (`pkg_swap.disasm:67`, `vmid_swap.disasm:67`, `vlatest_swap.disasm:67`).
- Because every upgrade keeps the original package id as module self-address and `LSP` was first
  defined in v1, the type tag is `0xb24b6789…::swap::LSP<T0,T1>` in **all** versions.
- `pkg_router.disasm:111` takes `Coin<LSP<Ty0, Ty1>>` for `remove_liquidity`; vmid/v12 routers take
  and return the same nominal type (live normalized signature evidence in the parent's
  `sim-poc/evidence/function_signatures.json`: `router::add_liquidity_returns` returns
  `"Coin<0xb24b6789…::swap::LSP<$0,$1>>"` for the 0x35f3 package).
- **Answer: YES.** LSP minted by any version is accepted/burnable by every other version's router
  (`Coin<LSP<T0,T1>>` is one type). This is exactly what makes cross-version flows (and the mixed
  store/reserve mismatches) exploitable; it is also why LP can migrate across code eras.
- Distinct types: stable LP is `b24b6789…::stable_swap::LSP` (`vlatest_stable_swap.disasm:17`) — NOT
  interchangeable with `swap::LSP`; `EscownCoins` (0x08cd origin) and `EscrowCoinsV2` (0x35f3 origin)
  are different structs (live escrow type repr confirms: `0x08cd3348…::swap::EscownCoins<…>` on the
  sampled pools).

## 7. Task E — stable_swap (same bug class?)

- `Stable_Pool` (`vlatest_stable_swap.disasm:21-37`) holds `token_x/token_y` and **no reserve
  mirror**; every function reads/writes the single store, so the AMM's desync cannot occur.
- `stable_mint` (`1156-1300`): S==0 → `LP = sqrt_u64(x*y)`, require `>1000` else **abort 102**;
  else `LP = min(dx*S/x, dy*S/y)` via `mul_div_u128`, require `>0` else **abort 103**; joins coins,
  `increase_supply`, `update_oracle`. No minimum-liq lock (1000 LP simply never minted).
- `stable_burn` (`1302-1401`): `out_x = lp*x/S`, `out_y = lp*y/S`, both>0 else **abort 106**;
  splits from the same store; `decrease_supply`; `update_oracle`.
- All lp add/remove/swap entry points check `is_freeze` (**abort 111**) and are **ungated by
  version**; `create_stable_pool` is dev-only. So the stable pools are live under every code version
  simultaneously — but they hold no cross-version state split, and standard stable-curve rounding
  appears used consistently (no separate LP-inflation precondition of the AMM's kind).
- Residual risk: rounding/oracle math in `get_y`/`quote` (out of scope of this pass), and the
  permanent ungated exposure of `add_stable_liquidity`/`remove_liquidity`/swaps. Live: 1 pool, frozen
  by inactivity, no evidence of misuse.

## 8. Task F — other unprivileged / value-relevant paths

1. **`sync_pool` (v12 public, and the v11 package)**: force-writes reserves+k_last from E2; no auth
   beyond the version gate. Currently inert (gate abort 25); becomes the armed trigger when the
   gate opens or a version-12-constant package ships. Combined with **ungated V1 swaps** on the 12
   primed pools (§7 of Context / list below) it is a full-store extraction primitive.
2. **`unfreeze_and_add_liquidity` (v12 router, public)**: anyone can clear `is_freeze` on any frozen
   pool by donating liquidity (LP goes to hardcoded `0x1937…`). Breaks the freeze control; no direct
   profit; also usable to re-enable add/remove/swap on a pool admins froze for cause.
3. **Legacy privileged backdoors in ungated v2–v6** (always callable, independent of VersionManage):
   - v2 `swap::withdraw_fee_` — **`entry public`**, senders limited to the five operator addresses
     (`0x9c8c8293…`, `0x97a74533…`, `0x5e99f037…`, `0x95d65996…`, `0xa67511f0…`; **abort 999**
     otherwise); withdraws `token_x*amount/supply` and `token_y*amount/supply` from the pool to the
     sender **without burning LP** (`v2_swap.disasm:2185-2360`). This is a standing drain capability
     for those five keys over every pool.
   - v3/v4/v5 `swap::withdraw_fee_direct` — same five-address gate (abort 999), delegates to the same
     pro-rata-withdrawal helper (`v5_swap.disasm:2217-2313`, `2315-…`). v6 stubs both to no-ops
     (`v6_swap.disasm:2299-2309`); v7/v12 stub `withdraw_fee_direct` to **abort 1**.
   - v2–v6 core functions (`mint`, `burn`, `swap`, `add_liquidity_direct`, `update`, `mint_fee`) are
     semantically identical to V1 (diff only in constant-table indexes) → no additional unprivileged
     desync primitive from them; they make the "permanently callable" code surface 6 packages wide.
4. **`mint_fee` dilution (all versions)**: every mint/burn can mint protocol LP to `fee_amount`
   up to ~S per call (weights 40/60 in v7/v12, 10/20 in V1/v2–v6) when `√(r product) > √k_last`.
   `sync_pool` also rewrites `k_last`. Only fee_to/dev can withdraw, so not attacker-profit, but it
   lets any user trigger large supply dilutions (grief) and is the likely cause of the observed
   `fee_amount ≈ supply − 1000` on sampled pools.
5. **Event forging**: `swap::add_swap_event_internal`/`add_swap_event_with_address` are public in all
   versions and take arbitrary amounts (`vlatest_swap.disasm:3119-3183`); anyone can emit fake
   `Swap_Event`/`Add_Liquidity_Pool` events for indexers. No on-chain value impact.
6. **Dead stubs to ignore**: `skim_pool` (abort 26), `withdraw_fee_direct` (abort 1), `withdraw_fee_`
   (abort 1), `migrate_pool` in v12 (abort 1); v6's `withdraw_fee_direct`/`withdraw_fee_` silently
   no-op (empty `Ret`) — a silent-success trap for integrators.
7. **Admin centralization**: `dev` = `0x049c391a…`, `fee_to` = `0x85bf745a…` (both set via init and
   mutable by dev; `withdraw_fee` also accepts the initial fee_to constant in v12). `freeze_pool`,
   `set_fee_to`, `set_new_dev`, pool creation, and (in v2–v5) the five operator addresses can move
   value. Not exploitation by an outsider, but the trust surface is large and partly versionless.

## 9. Live evidence (read-only)

- Gate sims (GraphQL `simulateTransaction`, checks disabled): `0x08cd::swap::assert_version_contract`
  → FAILURE abort **25**; `0x35f3::swap::assert_version_contract` → FAILURE abort **25**; V1
  `create_new_pool_admin` → abort **17** (dev gate works, V1 executable); vmid
  `withdraw_fee_direct(0)` → abort **1** (dead stub); v12 `skim_pool(0)` → abort **26** (dead stub).
  Parent's own sims (`/tmp/opencode/bluemove_simtest2/sim/sim_results.json`) independently show the
  same v7/v12 gate aborts and V1 aborts (split/quote) on escrow-funded pools.
- Live Dex_Info `0x3f2d9f72…` (shared, initialSharedVersion 1587827): `fee_to=0x85bf…`,
  `dev=0x049c…`, `total_pool_created=16739`; `VersionManage.version=12` (last written 2026-07-12 by
  0x35f3 `migrate_contract_version`).
- Escrow distribution (parent's 600-pool sample, `escrow_sample.json`):
  last writer vmid 587 / V1 12 / v12 1; 586 pools have empty V1 stores; **12 pools have two populated
  stores with divergent ratios** — the primed set:
  `0x2cb35fc6…` (T/EM, ratio 3.86e7), `0xcdc590d3…` (T/E2, 8.51e7), `0x40dce7f1…` (T/E2, 8.08e7),
  `0x54e40e4b…` (T/E2, 8.19e7), `0x1edd2fb4…` (T/E2, 1.76e5), `0x3d1bf3a7…` (T/E2, 1.27e5),
  `0x9ccd5180…` (T/E2, 8.97e7), `0x592494b3…` (T/EM, 2.73), `0x4ac0309f…` (T/E2, 8.91e7),
  `0x52a56168…` (T/E2, 8.43e7), `0x6d26fca4…` (T/E2, 2.84e7), `0xf2ae3b09…` (T/E2, 1.79e5).
  (ratio = (store_y/store_x) / (E2_y/E2_x); larger = bigger mispricing.)
- Stable registry `0x5a7eca40…`: 1 pool `0xf47f15e0…` (COIN/COIN), inactive.

## 10. Open items / recommendations for the parent

1. **Do not rely on "V-latest active".** Today's callable AMM code is V1 (plus v2–v6 clones). If the
   team intends v12 to be live, the VersionManage value (12) or the v12 `get_contract_version`
   constant (11) is wrong — either way, **every v7+ entry point currently aborts 25**.
2. **Disassemble v10/v11 packages** (`0xc396a92a…`, `0xf72bd3b3…`): v11 has `sync_pool` and the
   same escrow model; v10 has `skim_pool`/`create_and_freeze_pool` but no `sync_pool`. They matter
   for “what becomes live if the version is set to 10”.
3. **Analyze v2–v6** (`0xdc8437d0…` … `0xa00faab5…`): ungated, V1-identical core, with privileged
   `withdraw_fee_`/`withdraw_fee_direct` backdoors (five operator addresses). Verify those five
   addresses' key custody before concluding the drain paths are privileged-only.
4. **Monitor `sync_pool`/gate state** on the Dex_Info and watch for VersionManage changes; the 12
   primed pools are ready-to-drain if a `sync_pool`-bearing version becomes active.
5. Re-run the parent's exploit PoC against a **fork/simulation with the gate value temporarily set
   to 10/11 on a throwaway fork** (not mainnet) to measure extraction; the arithmetic conclusion
   (store−reserves per pool) is solid but the exact PTB sequence should be validated.
6. Note the V-mid `add_liquidity` exists-check bug for the historical record (liquidity frozen on
   587/600 sampled vmid-era pools is consistent with it).
