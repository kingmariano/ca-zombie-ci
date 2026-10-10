# REF Finance (now Rhea) — legacy v1 farms, dead v1 exchange, live v2 farms & Boost Farm (NEAR)

- Date: 2026-10-10 (UTC). Chain: NEAR mainnet. Status: **read-only**; no transactions signed/sent; keyless endpoints only
  (`https://rpc.mainnet.near.org`, `https://api.nearblocks.io`, `https://coins.llama.fi`).
- Scope: legacy Ref "Boost" farms + v1 farms (per C2-55 non-EVM cluster brief). Adjacent live contracts (v2 farm,
  Boost Farm v0.5.0) measured and audited because the brief explicitly names them ("boostfarm…", "booster contracts").
- All reads below cite account id + method + raw value + block height. NEAR price used: **$5.193434850153741** (DefiLlama
  `near:wrap.near`, ts 1791610xxx) unless stated; KSM $5.106736053852194 (ts 1791609783); REF $0.09698142306835059
  (ts 1791609783).

---

## 0. TL;DR

| Target | What it is | Live real value (measured) | Class | Note |
|---|---|---|---|---|
| `ref-farming.near` | v1 farm (July 2021); **code emptied** | 45.7621 NEAR + 3.57257 KSM ≈ **$255.9** + junk RFTT | **S** (P-escape via 7 FA keys) | state holds unbacked bookkeeping: 326.25 wNEAR + 11,902.55 dead LP units |
| `ref-finance.near` | v1 exchange; **code emptied, state wiped** | 134.3236 NEAR ≈ **$697.6** | **S** (P-escape via 1 FA key) | public still calls it and calls fail (2026) |
| `v2.ref-farming.near` | farm v1.1.0, live code; **174/176 farms Ended** | staked LP **$2,809,854** + reward balances **$92,235** | **H-O** (E-U $0) | 25,960 farmer records; 0 access keys; owner = DAO |
| `boostfarm.ref-labs.near` | "Boost Farm" v0.5.0, live code | staked LP **$1,839,449** + reward balances **$141,373** | **H-O** (E-U $0, medium conf.) | 101 seeds (88 v2 pools + 11 DCL + xRHEA); owner = DAO; 2 operators |

**Headline: external-unprivileged extractable (E-U) = $0.00.** The two genuinely dead contracts hold ≈ **$953.5** total that
nobody can move without privileged keys (**S**). The two live farm contracts hold ≈ **$4.88M of user custody** that farmers
can still withdraw (**H-O**) — no permissionless path to it was found (New source-verified, Boost Farm black-box-verified).

Dead names (do not re-investigate): `v1.ref-farming.near`, `boostfarm.ref-finance.near`, `farming.ref-finance.near`,
`ref-boost.near`, `booster.ref-finance.near`, `ref-farming-v1.near`, `farm.ref-finance.near` — all UNKNOWN_ACCOUNT
(blocks 219,321,6xx–219,321,7xx).

---

## 1. `ref-farming.near` — v1 farm: executable code is **gone**; funds stuck (S)

### 1.1 Proof the code is empty (not merely old)
- `view_account(ref-farming.near)` block **219,335,481**:
  `amount = 45762080117524650300000159` yocto = **45.7621 NEAR**, `storage_usage = 219,522`, `code_hash = GKot5hBsd81kMupNCXHaqbhv3huEbxAFMLnpcX2hniwn`.
- **`GKot5hBsd81kMupNCXHaqbhv3huEbxAFMLnpcX2hniwn` = base58(sha256(b""))** — the code hash of *empty* code
  (verified locally: sha256 of the empty byte string encodes to exactly this hash). The v1 farm's code was deleted /
  replaced with empty bytes at some point.
- `view_code(ref-farming.near)` → `code_base64: ""` (nearblocks contract endpoint agrees, block 219,323,775).
- Any call fails at compile: `call_function(get_farms)` → `wasm execution failed with error: CompilationError(PrepareError(Deserialization))`, block **219,321,488**.
  Every probed method (get_farms/get_account/get_owner/…) returns the same.

### 1.2 History (last activity 2021-09-27)
- nearblocks tx list (newest-first): last tx `HcdpLoWG8L77a8yRd9BNh6uMYY2iQPhTE1bcrqz9p94b`, block **48,748,393**, 2021-09-27,
  signer = contract itself, action = **ADD_KEY** (this added the FunctionCall key `ed25519:8rrXCC8E…` scoped to `v2.ref-farming.near`).
- 2021-09-02: migration txs `EdQLdLqPorAH17BXtCpj9sm4rF7NN6ZHTSFBtSXcxN2Y` (self-calls, incl. → `v2.ref-farming.near` at block 46,746,777) — the v1→v2 farm migration.
- No later signed txs on this account were found in nearblocks (indexer caveat; RPC prunes 2021 txs: `EXPERIMENTAL_tx_status` → UNKNOWN_TRANSACTION).

### 1.3 Access keys (who could resurrect it)
`view_access_key_list` block **219,321,579** — **7 FullAccess** keys + 1 FunctionCall key (receiver `v2.ref-farming.near`, allowance 0.25 NEAR):
`ed25519:4gofRk5U4EqL…` (nonce 43,821,417,000,002), `6W8kV4inrmFo…` (46,585,010,000,003), `B6QopWTMFVvc…` (43,821,226,000,003),
`B7mRnV8KNi2u…` (44,745,531,000,001), `BT9U4w3m9aku…` (46,584,963,000,004), `DBfs9yTeRh7P…` (43,821,218,000,002),
`HCB2WmEa8rMb…` (45,201,900,000,001); FC key `8rrXCC8EtsxVWuaEZoTLkkJ5pMZ3sUqx45sPLRFC2Fr8` (nonce 48,748,392,000,000).
Key holders are **not identifiable on-chain**. They could `DeployContract` and sweep (**P**), but no signature has been seen since 2021.

### 1.4 Live balances (what is actually there)
| token | read (block) | raw | amount | USD |
|---|---|---|---|---|
| NEAR native | view_account block 219,335,481 | 45,762,080,117,524,650,300,000,159 | 45.7621 NEAR | $237.66 |
| `kusama-airdrop.near` (KSM, 5 dec) | ft_balance_of block 219,335,491 | `357257` | 3.57257 KSM | $18.24 |
| `rftt.tkn.near` (RFTT, 8 dec) | block ~219,322,7xx | 40,000,000,000,000 | 400,000 RFTT | $0 (no market) |
| `wrap.near` | ft_balance_of block 219,335,500 | `0` | 0 | $0 |

### 1.5 Internal state decoded (330 keys, block 219,323,242; `dumps/ref-farming.near.farmers_decoded.json`)
`view_state` succeeds (state is readable even though code is dead). 1 STATE key + 329 farmer records
(`f` + u32 len + account_id; Borsh `VersionedFarmer(V101(Farmer))`). Totals decoded cleanly (0 errors):
- storage deposits `amount`: **32.9 NEAR** (committed user storage);
- `rewards`: **326,248,441,525,168,282,290,837,473 yocto wNEAR = 326.2483 wNEAR** — *claimed but not withdrawn*; **unbacked**
  (contract's wNEAR balance = 0), so they are payable to nobody;
- `seeds`: **`ref-finance.near@1429` = 11,902,547,666,915,886,727,517,264,089 raw (≈11,902.55 LP units @24 dec)** — LP tokens of
  the **old** exchange pool 1429. The old exchange (`ref-finance.near`) has its state **wiped** (storage 227 bytes) and its code
  emptied → those LP tokens no longer exist on-chain. Cross-check: `mft_balance_of(token_id=":1429", account=ref-farming.near)`
  on the live v2 exchange = `0` (block ~219,33x,xxx).

### 1.6 Candidate unprivileged paths tried
| path | result |
|---|---|
| call `withdraw_seed` / `claim_reward_by_seed` / `withdraw_reward` | **impossible** — `PrepareError(Deserialization)` at compile, before any method dispatch (block 219,321,488) |
| spoofed `ft_on_transfer` / `mft_on_transfer` (fake deposit) | impossible — code does not execute |
| function-call key tricks | FC key is scoped to `v2.ref-farming.near` only, allowance 0.25 NEAR — cannot touch this account |
| re-deploy code by anyone | impossible without one of the 7 FullAccess keys (P-only) |

### 1.7 Classification
- **E-U: $0.00** — an external unprivileged caller cannot execute anything on this account. Confidence: **high**.
- **H-O: $0.00** — users cannot withdraw (no executable method; no self-service path). The 326.25 wNEAR / 11,902.55 LP
  bookkeeping is void (unbacked).
- **P: possible** — any of the 7 FullAccess key holders could redeploy code and then take the 45.7621 NEAR + 3.57257 KSM.
- **S: ≈ $255.9** stuck (the real tokens), plus void accounting.
- Would change the verdict: appearance of a transaction signed by one of the listed keys (would prove key control and turn S into P-with-live-actor), or a nearcore change restoring empty-code execution (none plausible).

---

## 2. `ref-finance.near` — old exchange: code emptied, state wiped

- `view_account` block **219,335,510**: `amount = 134323556652221816308138186` = **134.3236 NEAR** ($697.57), `storage_usage = 227`,
  `code_hash = GKot5hBsd…` (same empty-code hash as above).
- The old exchange's state is gone (227 bytes vs its historical size) — the MFT ledger that held user LP (and the farm's
  pool-1429 LP) no longer exists.
- Public probing continues and fails: e.g. `storage_deposit` call tx `HqrkQTfpgPkyb3E9…` (block 201,743,996, status **false**),
  `mint` call tx `5go5hbCWbnMJyaRT…` (block 202,936,815, **false**), `intents.near` call (block 206,413,576, **false**);
  only a plain 0.001 NEAR `TRANSFER` succeeded (tx `7y5rt3bEGtK7yWBj…`, block 211,425,038).
- Access keys: **1 FullAccess** (`ed25519:HJsDpaCdKvsq…`, nonce 45,549,719,015,303).
- **Classification: S ≈ $697.6** (P-escape via its FullAccess key). E-U $0, H-O $0 (state destroyed).

---

## 3. `v2.ref-farming.near` — live farm contract, product wound down (174/176 farms Ended)

### 3.1 Metadata & authority
- `get_metadata` block **219,335,529**: `version 1.1.0`, `owner_id = ref-finance.sputnik-dao.near`,
  `farmer_count 25960`, `farm_count 176`, `seed_count 45`, `reward_count 23`, `state Running`.
- `list_farms(0,300)` block **219,328,573**: 176 farms = **174 Ended, 2 Created** → no running farms; the product is winding down.
- `view_account` block 219,335,519: 2,986.7546 NEAR; storage 16.2 MB; code `dp5BqcBKtpqEUTx5jF3fQKjUZ1gghEHo54oRLJ8uXZ4`.
  `view_access_key_list` → **0 keys** (contract is permanently locked; only owner-DAO method calls can administer).

### 3.2 Live balances (headline reads)
| item | method (block) | raw | amount | USD |
|---|---|---|---|---|
| wNEAR | `ft_balance_of(wrap.near)` 219,335,548 | `4553253526706129374256153` | 4.5533 | $23.45 |
| REF | `ft_balance_of(token.v2.ref-finance.near)` 219,335,539 | `649757651759647202121080` | 649,757.65 | $63,014 (@$0.09698) |
| $META | `ft_balance_of(meta-token.near)` 219,33x | 2,072,730,681,129,760,479,074,224,712,965 raw (24 dec) | 2,072,730.68 | $26,187 |
| stNEAR | `ft_balance_of(meta-pool.near)` 219,33x | 5,503,506,093,088,377,963,138,691 | 5.5035 | $42.66 |
| USN | `ft_balance_of(usn)` 219,33x | 10,774,290,287,545,446,251,289 | 10,774.29 | $952 (@$0.0884) |
| others (22 tokens) | see `dumps/ref_final_values.json` | — | — | total **$92,234.92** |

### 3.3 Staked LP (the bulk of the value)
- 45 seeds, total **36,922.01 LP units**; USD value computed from `get_pool` reserves × DefiLlama token prices:
  **$2,809,853.80** (96 pools read, blocks ~219,333,0xx–219,335,0xx; all 45 seeds covered; `dumps/lp_value_full.json`,
  `dumps/pool_lp_prices.json`). Largest: `v2.ref-finance.near@1910` $2.16M; `@535` $159.8k; `@2` $122.4k; `@4` $70.6k.
- **MFT ownership cross-check** — the farm really holds the LP: `mft_balance_of(v2.ref-finance.near, ":79", v2.ref-farming.near)`
  = `2090450465903387087332949538` (block **219,334,953**) = the seed total for `v2.ref-finance.near@79` exactly;
  `":1910"` = `2133074233862558527472257` (block 219,334,977) = seed total; `":2"` = `274010030371452176163416626` (block 219,335,011).

### 3.4 Audit (extraction check) — E-U closed
Source: `jumbo-exchange/contracts` fork of Ref's `ref-farming` (v1.0.2, near-sdk 3.1; the deleted upstream repo is
`ref-finance/ref-farming`). The deployed 1.1.0 export set has *exactly* these entry points plus the standard storage trait
(diff = `ft_on_transfer, mft_on_transfer, pause/resume, storage_*` only). Key code paths (file refs):
- `actions_of_seed.rs:19` `withdraw_seed` → `internal_seed_withdraw(&seed_id, &sender_id …)` with
  `sender_id = env::predecessor_account_id()`; `farmer.sub_seed` reverts if over-balance. Cross-user withdrawal impossible.
- `actions_of_reward.rs:35-78` `claim_reward_by_farm` / `claim_reward_by_seed` / `withdraw_reward` — all sender-scoped;
  callbacks `#[private]` and revert-safe.
- `token_receiver.rs:16-84` `ft_on_transfer`: seed deposits require `self.get_seed(&env::predecessor_account_id())`
  (predecessor must *be* the registered seed token); reward deposits require
  `assert_eq!(farm.get_reward_token(), env::predecessor_account_id())` — a malicious token contract **cannot** spoof
  deposits of another seed/reward token (attacker-controlled contracts are not registered seeds).
- `token_receiver.rs:127-175` `mft_on_transfer`: seed id is built as `"{predecessor}@{pool_id}"`; unregistered predecessor ⇒
  `ERR31_SEED_NOT_EXIST` panic. Spoofed MFT deposits impossible.
- `owner.rs:13` `force_clean_farm` = owner-only (`assert_owner`); `owner.rs:29` `migrate` = predecessor==current account;
  `view.rs` expositions are read-only.
- Write methods cannot be simulated by view calls (they read `env::predecessor_account_id()` →
  `HostError(ProhibitedInView)`, observed on-block), so the above is static verification, corroborated by matching deployed
  strings (e.g. "withdraw seed with amount", "user_rps@… increased", callback-private traps in the wasm).

### 3.5 Classification
- **E-U $0.00** — no permissionless drain found; deposit and withdrawal paths are token-identity-validated and sender-scoped.
  Confidence: **high** (source parity caveat: deployed binary is v1.1.0 vs fork v1.0.2; method set identical).
- **H-O: $2,809,854 (staked LP) + $92,235 (reward balances the farm owes users)** — farmers can still `withdraw_seed` /
  `claim_reward_by_*` / `withdraw_reward` (contract live, state Running).
- **P:** owner DAO `ref-finance.sputnik-dao.near` can create/cancel farms, pause/resume, clean farms — cannot move user stakes
  to itself (no such method exists).
- Blockers: none for user recovery; no keys to upgrade.

---

## 4. `boostfarm.ref-labs.near` — "Boost Farm" v0.5.0 (closed source), $1.98M user custody

### 4.1 Metadata & authority
- `get_metadata` block **219,335,567**: `version 0.5.0`, `owner_id = ref-finance.sputnik-dao.near`,
  operators `doublerose.near`, `x_space.near`; `farmer_count 12098`, `farm_count 177`, `outdated_farm_count 3`,
  `seed_count 101`, `state Running`, `ref_exchange_id = v2.ref-finance.near`.
- `get_config` (block ~219,327,8xx): `seed_slash_rate 200` (2%), `booster_seeds{xtoken.rhealab.near → 7 affected seeds}`,
  `boost_suppress_factor 100`, `max_num_farms_per_seed 32`, `max_num_farms_per_booster 64`,
  `maximum_locking_duration_sec 1`, `max_locking_multiplier 10001`.
- `view_account` block 219,335,557: 1,336.7449 NEAR; storage 7.5 MB; code `Dpwz7Ju2n8cTfKsFTyNsoptUaHzzGRZrffab8WGh7ybh`;
  `view_access_key_list` → **0 keys** (permanently locked).

### 4.2 Live balances
| item | method (block) | raw | amount | USD |
|---|---|---|---|---|
| wNEAR | `ft_balance_of(wrap.near)` 219,335,577 | `12067222323824207750893202777` | 12,067.2223 | $62,146 |
| REF | `ft_balance_of(token.v2.ref-finance.near)` 219,335,587 | `601650845852052458562971` | 601,650.85 | $58,349 (@$0.09698) |
| rNEAR (`lst.rhealab.near`) | 219,33x | 2,436.9579 raw/24dec | 2,436.96 | $13,319 (@$5.4654) |
| $META | 219,33x | 310,376.7417 | 310,376.74 | $3,921 |
| USN | 219,33x | 27,398.7617 | 27,398.76 | $2,421 (@$0.0884) |
| xRHEA (`xtoken.rhealab.near`) | 219,33x | `2345416766316827744841539` (18 dec) | 2,345,416.77 | unpriced (no llama feed) |
| others (49 contracts) | — | — | — | total FT **$141,373.47** |

### 4.3 Staked LP
- `list_seeds_info(0,200)` block **219,328,563**: 101 seeds — **88 v2-pool seeds (88 nonzero) + 11 DCL range seeds on
  `dclv2.ref-labs.near` + 1 FT seed `xtoken.rhealab.near`**. Total simple seeds **6,688,339.76 LP units**.
- USD: **$1,839,448.92** for the simple v2 pools (76 pools priced; `dumps/lp_value_full.json`; 14 seeds unvalued = 11 DCL +
  2 zero pools + xRHEA seed — DCL ranges not priced here).
- **MFT cross-check:** `mft_balance_of(":6458", boostfarm.ref-labs.near)` = `5090647864812014596152194296991`
  (blocks 219,334,989 / 219,335,597) = seed total exactly; `":5438"` = `1258584742158042561138402047947` (block 219,335,000);
  `":79"` = `4360354215874838508974538080` (block 219,334,966).

### 4.4 Audit (closed source, black-box + wasm analysis) — E-U not found
- Source is **not public** (wasm embeds paths `contracts/boost-farming/src/*`; no GitHub repo found). Audit = export list +
  embedded strings + the public ref-ui integration (`src/services/farm.ts` calls: stake/unstake, `stake_boost_shadow`,
  `unStake_boost_shadow`, `withdrawAllReward_boost`, `claimRewardBySeed_boost`).
- 69 exports; all user-withdraw/claim flows mirror the v2 farm design; all `callback_*` are `#[private]`
  (strings: "Method callback_withdraw_seed is private", etc. — wasm trap table).
- Deposit identity checks exist (strings): `E404: reward token does NOT match`, `E600: MFT token_id is invalid`,
  `E308: invalid seed id` — the same anti-spoofing checks as the audited farm contract.
- Admin gates exist: `E002: not allowed for the caller`, `E003/E007/E009 operator` errors; owner rotation methods
  (`grant/confirm/accept_next_owner`) present; `migrate` is **private**.
- Locking/slashing mechanics (`free/locked/shadow amounts`, `seed_slash_rate 200`, `seed_withdraw_slashed`,
  `seed_withdraw_lostfound`, `return_seed_lostfound`, `force_unlock`, `on_cast_shadow/on_remove_shadow`) are custom and
  **not source-verified**. No public method that withdraws *another account's* stake was found in the export set, and
  view-call simulation of write methods is impossible (`HostError(ProhibitedInView)` on-block).
- Residual risk: economically-buggy boost/slash logic could in principle be exploitable; cannot be fully excluded without
  source or a fork test. No indicator found.

### 4.5 Classification
- **E-U $0.00** — no permissionless drain found. Confidence: **medium** (closed source; unverified slashing/boost logic).
- **H-O $1,839,449 (staked LP) + $141,373 (reward balances) + unvalued DCL seeds/xRHEA** — users can stake/unstake/claim via the
  live contract (state Running; ref-ui flows).
- **P:** owner DAO + 2 operators (extend/remove operators, cancel farms, slash config) — no method to take user stakes.
- Blockers: source unavailable; write-method view simulation blocked.

---

## 5. Negative results / dead ends (with evidence)
- Account-name probes (UNKNOWN_ACCOUNT at blocks 219,321,6xx–219,321,7xx): `v1.ref-farming.near`, `boostfarm.ref-finance.near`,
  `farming.ref-finance.near`, `ref-boost.near`, `booster.ref-finance.near`, `ref-farming-v1.near`, `farm.ref-finance.near`;
  `boostfarm.near` exists but has code_hash `1111…` (no code) and 0 balance.
- nearblocks search for "boostfarm"/"ref-farming" returns no accounts (index limitation — not evidence of nonexistence;
  direct RPC was used instead).
- Old-exchange LP token `ref-finance.near@1429`: no live representation on the v2 exchange (mft balance 0); the old
  exchange state is wiped — these positions are unrecoverable by anyone.
- The v1 farm's last tx (ADD_KEY, 2021) added only a 0.25 NEAR-limited FC key to the successor farm — no recovery capability.

## 6. Files
- Scripts (`scripts/`): `near.py` (RPC helper), `dump_state.py` (prefix-paginated state dump), `decode_v1_farm_state.py`,
  `rpc_call.py`, `wasm_exports.py`, `pool_lp_price.py`, `val_all_seeds.py`, `finish_ref.py`.
- Dumps (`dumps/`): `ref-farming.near.state.json`, `ref-farming.near.farmers_decoded.json`, `headline_refs.json`,
  `v2.ref-farming.seeds.json`, `v2.ref-farming.farms.json`, `v2.ref-farming.rewards.json`, `v2.ref-farming.near.ft_balances.json`,
  `boostfarm.seeds.json`, `boostfarm.ref-labs.near.ft_balances.json`, `pool_lp_prices.json`, `lp_value_full.json`,
  `ref_final_values.json`, `*.wasm.exports.txt` (boostfarm, v2 farm), `*ft_balances.txt`.
- Prices: DefiLlama `coins.llama.fi` (near:* + coingecko:kusama) at timestamps stated inline (2026-10-10).

## 7. Caveats
- Block heights drift by 1–2 between parallel reads (blocks cited per read).
- REF price in this dataset is volatile: **$0.09698** (DefiLlama ts 1791609783, conf 0.99) vs **$0.05745**
  (ts 1791610737, conf 0.7). REF portions of the USD totals ($63,014 in v2 farm, $58,349 in boost farm) scale with it;
  token amounts are exact on-chain reads regardless.
- LP USD values are reserve-based at the read block and move with prices; treat $2.81M/$1.84M as ±few % snapshots.
- The v1 farmer-record decode assumes the v1.0.x Borsh layout (validated: all 329 records decode with 0 errors, tail shapes consistent).
- Written for a public repo: no secrets, no keyed endpoints, no transactions.
