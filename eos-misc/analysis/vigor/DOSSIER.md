# Vigor (EOS) — H2-05 deep-dive dossier

- **Date:** 2026-10-10 (UTC)
- **Chain:** EOS mainnet (chain_id `aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906`)
- **Snapshot head block:** 524,653,327 (2026-10-10T13:08:44Z); earlier read pass at 524,642,876 (11:41:38Z)
- **Status:** read-only; no transactions sent; EOSIO cannot be dry-run on public nodes, so proof is (a) static WASM auth analysis + (b) live table state + (c) live action history. No mainnet writes performed.
- **API sources:** `https://eos.greymass.com` (chain), `https://eos.hyperion.eosrio.io` (history), Defibox `swap.defi` pairs (prices), CoinGecko (USD).

## 1. TL;DR

| Contract | Live tokens held (USD) | Primary verdict | Confidence |
|---|---|---|---|
| `vigorlending` | **$113,233.53** (PBTC $89,490 + PETH $11,971 + USDT $6,208 + VIGOR $4,980 + VIG $162 + IQ $417 + EOS $5) | **H-O $109,456** user-claimable (pToken/USDT-dominated); **E-U $0 direct**, conditional mispriced-borrow ≤ ~$138; **S ≈ $12,402** unbacked EOS claims | High (auth), Medium (H-O realization), Low-Med (E-U arb) |
| `vigorstaking` | **$10,191.17** (EOS $3,309 + USDT $6,359 + VIG $476 + VIGOR $48) | **H-O $10,179** fully backed user stakes, self-withdraw proven; **E-U $0**; **S/P $1,600** (contract's own unbacked EOS row) | High |

**Total live tokens at snapshot: $123,424.71.** Direct external-unprivileged extraction: **$0** (no auth-bypass path exists). The flagged `bailout`/`kick` actions are hard-gated by `require_auth(vigorlending)` (empirically and statically). One *latent/conditional* E-U vector exists (frozen Apr-2025 oracle + permissionless account creation + self-authorized borrows `assetout(...,memo="borrow")`), bounded today to ≲ **$138** net by the protocol's own pool availability tables — not demonstrated end-to-end (no dry-run possible); confidence **low-medium**.

## 2. Contracts, accounts, permissions (verified live)

| Account | Exists | Role | owner/active authority |
|---|---|---|---|
| `vigorlending` | ✅ created 2020-03-24 | CDP + lending ("baillout/kick") engine, VIGOR issuer | owner ← `dacauth11111@active`; active ← `dacauth11111@active` + `vigorlending@eosio.code`; extra perm `regyield` (key `EOS5p5q…`), `freeze`/`med` ← `dacauth11111@low|med` |
| `vigorstaking` | ✅ created 2022-09-16 | generic token staking vault (EOS/USDT/VIG/VIGOR) | owner/active ← `dacauth11111@active` + `vigorstaking@eosio.code` |
| `vigortoken11` | ✅ created 2020-04-07 | VIGOR token (eosio.token; issuer=`vigorlending`; supply 63,363.9554, max 100B) | owner/active ← `dacauth11111@active` |
| `vig111111111` | ✅ created 2019-03-27 | VIG token (eosio.token; issuer=self; supply 1,000,000,000 = max) | owner/active ← `dacauth11111@active` |
| `vigoraclehub` | ✅ | price feed hub (pairs: btcusd, eosusd, eosusdt, eosvigor, ethusd, iqeos, vigeos, efxeos) | — |
| `dactoken1111` | ✅ | DAC token VIG + **`members` registry** (memberreg/memberunreg) | — |
| `daccustodia1` | ✅ | DAC custodian contract (custodians/candidates/votes) | — |
| `dacauth11111` | ✅ | authority hub for all Vigor contracts | owner ← `daccustodia1@eosio.code`; active ← `dacauth11111@high`; high/med/low = threshold 4/3/2 of 7 accounts (`aus1genereos, cryptolions1, vigoradmin11..14, vigordacltd1`) |
| `vigorvaults`, `vigortoken`, `vigtoken`, `vigorstats`, `vigortoken111`, `vigorlock`, `vigor`, `vigordao` | ❌ DO NOT EXIST | — | — |

Notable: **no EOS keys on the contracts themselves** — control is entirely the DAC authority `dacauth11111` (4-of-7 custodian constellation; owner-level passes through `daccustodia1@eosio.code`). Everything in this report classifies under **P** if that authority is ever used; no such use is needed for the verdicts below.

## 3. Action authorization table (`vigorlending` WASM, sha256 63e8641f…, 485,001 bytes, block 524,642,876)

Decompiled with `wabt wasm-decompile`; dispatcher action-name constants decoded with the chain's 5-bit name packing (validated bijectively against all 25 ABI actions; anchors `eosio`/`transfer` matched). Wrappers build a context where `ctx[0] = receiver` (`f_cd`: `a[0]:long = b` where b=receiver), so `require_auth(a[0])` == `require_auth(vigorlending)`.

| Action | Impl | Gate (decompiled evidence) | Attacker reachable |
|---|---|---|---|
| `bailout` | f_qm L45715 | `env_require_auth(a[0])` = contract | **No (P)** |
| `bailoutup` | f_dn L47712 | `env_require_auth(a[0])` = contract | **No (P)** |
| `kick` | f_ai L23903 | `env_require_auth(a[0])` = contract (+ exectype==2 check) | **No (P)** |
| `liquidate` | f_mi L24893 | `env_has_auth(contract) \|\| env_has_auth(usern)`; self-liquidations blocked by config messages (9591/9637); requires exectype==2 | self-only; self-variant disabled by config |
| `liquidateup` | f_ni L25027 | same pattern (10000/9637) | self-only; disabled by config |
| `returncol` | f_mm L44704 | `env_require_auth(a[0])` = contract | **No (P)** |
| `returnins` | f_km L44451 | `env_require_auth(a[0])` = contract | **No (P)** |
| `cleanbailout` | f_lp L53311 | `env_require_auth(a[0])` = contract | **No (P)** |
| `log` | f_bq L54087 | `env_require_auth(e[0])` = contract | **No (P)** |
| `doupdate` | f_be L6130 | `env_require_auth(a[0])` = contract | only via contract inline |
| `predoupdate` | f_zk L33429 | `env_require_auth(a[0])` = contract | only via contract inline |
| `setacctsize` | f_in L48852 | `env_require_auth(a[0])` = contract | No (P) |
| `configure`/`freezelevel`/`whitelist`/`unwhitelist`/`clearconfig`/`setconfig` | f_tn/f_sn/f_ln/f_pn/f_mp/f_vn | `require_auth` = contract | No (P) |
| `tick` | f_dm | **NO auth** — permissionless; sends inline `vigorlending::doupdate` (perm "active") or drains the croneos queue | **Yes — but only triggers protocol logic, no caller-benefit** (E-U $0) |
| `assetout` (withdraw/borrow) | f_al L33503 | `env_require_auth(b[0])` = **`usern` (self)** | Yes — self-service only |
| `doassetout` | f_om L45426 | `env_require_auth(a[0])` = contract (queued/cron continuation) | No |
| `acctstake` (self) | f_oi L25156 | `env_require_auth(b[0])` = owner(self) | self-service |
| `deleteacnt`/`dodeleteacnt` | f_dj L26581 / f_ej L26645 | self / contract-queued | self-service |
| `openaccount` | f_si L25430-32 | `env_has_auth(owner) \|\| env_has_auth(contract)` + DAC gatekeeper==1: `dactoken1111::members` row + agreed terms == latest hash (`1f5e5fa6…`) | **Yes — permissionless account acquisition** (see §5) |

Inline value movement: exactly **one** `send_inline` site (f_ye, L11193); every transfer/issue goes through contract-authorized inline actions. The croneos queue executor (`f_em` → `f_ye(e+16)`) executes stored actions with stored authorization `[actor=vigorlending, perm=active]` (`f_pf` scheduling).

**Empirical gate proof (history, 2026-08-25 → 2026-09-11):** every `kick` and `bailout` executed with authorization `[{actor: "vigorlending", permission: "active"}]` (e.g. tx of 2026-09-11T09:25:23 kick `bluepix.hufi`; 2026-09-11T09:26:xx bailouts of `brucewayneio`; 2026-09-05 kick/bailouts of `bluepix.hufi`/`blazekos.vr`; 2026-08-25 bailout `azertydu.ftw`). Zero external callers since at least 2026-04.

## 4. Live value (block 524,653,327; exact balances from `get_currency_balance`)

Prices: EOS $0.105194 (CG), USDT $0.999254, IQ $0.00083829, PBTC = BTC $82,784 (pToken), PETH = ETH $2,495.83, VIG = DEX 2.3557e-5 EOS = **$2.478e-6**, VIGOR = DEX 0.94395 EOS = **$0.09930** (Defibox pair 11 & 76, live 2026-10-10).

**`vigorlending` physical: $113,233.53** — PBTC 1.08101067 ($89,490.39); PETH 4.79624528 ($11,970.61); USDT 6,213.1203 ($6,208.49); VIGOR 50,155.8346 ($4,980.38); VIG 65,472,027.4865 ($162.24); IQ 497,110.971 ($416.72); EOS 44.6956 ($4.70); GEN 19,488.696 (no market, ~$0).

**`vigorstaking` physical: $10,191.17** — EOS 31,454.4977 ($3,308.82); USDT 6,363.3605 ($6,358.61); VIG 192,167,198.3634 ($476.20); VIGOR 478.6766 ($47.53).

**Internal books (live tables):** total debt 63,360.39 VIGOR; l_totaldebt 36,775.54 VIGOR; savings 13,233.67 VIGOR; user collateral (main book) 8,767,783 VIG / 86,052 EOS / 3,956 USDT / 482,617 IQ / 1.0361 PBTC / 4.1734 PETH; insurance 5,943,115 VIG / 7,222 EOS / 2,803 USDT / 21,688 IQ / 0.06307 PBTC / 0.83836 PETH / 146.63 VIGOR. `globalstats`: solvency 0.32007 (last update 2026-09-11T09:24:33Z). User count 263; staking rows 351 across 158 scopes.

**Coverage by token (claims vs physical):** PBTC 98.4%, PETH 95.7%, USDT 91.9%, VIGOR (claims only 13,380) 100%, IQ 98.6%, VIG 100% — all user-claimable (**H-O $109,456** in `vigorlending`); **EOS 0.05%** → EOS claims are effectively unrecoverable (93,230 EOS unbacked ≈ $9,807 nominal → **S**). `vigorstaking` user stakes (excl. the contract's own 15,208 EOS row): EOS 31,339.39 (backed), USDT 6,363.36 (exact), VIG 192.17M (exact), VIGOR 478.68 (exact) → **H-O $10,179**, proven withdrawable (`withdraw` requires `require_auth(from)`; history shows many successful withdrawals incl. `prospectgold` 2,456 EOS 2024-07-28, `dltoneeosone` 4,624 EOS + 5.08M VIG + 474.85 VIGOR 2024-04-04). The contract-scope 15,208.05 EOS row is only withdrawable with `vigorstaking`'s own authority → **S/P $1,600**.

`S` nominal total ≈ **$14,002** (unbacked user claims; none of it attacker-reachable).

## 5. The one conditional E-U vector (frozen oracle arbitrage) — quantified, not inflated

**Fact:** the price oracle is frozen at **2025-04-03T14:10:11Z** — both `vigoraclehub` datapoints/tseries (eosusd 8204 → $0.8204; eosvigor 1.1457; iqeos 0.004669; vigeos 0.00006901; btcusd $82,071; ethusd $1,777.44) and `vigorlending::market` (same timestamp). Real market is 18 months later: EOS **7.8× lower**, VIG **22.7× lower**, IQ **4.6× lower**, VIGOR **7.2× lower**, PETH **0.71×**, PBTC **0.99×**. Frozen prices were demonstrably accepted live: `sagittariusa` successfully borrowed 1 + 49 VIGOR on 2026-09-11 via `assetout(me,"…VIGOR","borrow")` (issue→transfer), and ran `tick`→`doupdate` continuously that day.

**Account acquisition is permissionless (verified live):** `dactoken1111::memberreg` (handler `f_wc`, `env_require_auth(b)` where b=sender) + `vigorlending::openaccount(owner)` (`has_auth(owner)` || contract; gatekeeper==1 passes once a `members` row + latest-terms hash exists). Live proof: `1vgvgvgvgvg1` memberreg 2025-10-28T19:03:56 → openaccount 2025-10-28T19:05:09.

**Bounded extraction:** the protocol's own `whitelist` table (updated at last doupdate 2026-09-11) shows available lending = `lendable×(1−lentpct)`: USDT ≈ **164.3**, EOS ≈ 6,998 (unprofitable: EOS oracle 7.8× > VIGOR 7.2×), VIG ≈ 791,032 (unprofitable), VIGOR ≈ 146.6, PBTC/PETH/IQ **0** (lentpct = 1.0, pools exhausted). Borrowing the 164.3 USDT against VIGOR collateral (263.9 VIGOR, market cost ≈ $26.20) nets ≈ **+$138.10**; borrowing VIGOR against VIG collateral is profitable per unit (2.8×) but the VIGOR lending pool (~146.6 VIGOR ≈ $14.6) / mining drip caps it to ≈ +$9. **Practical conditional E-U ≈ ≤ $150 net, confidence low-medium** (cannot dry-run; pool availability may be stale). If the pool caps were ignored, the theoretical bound would rise to ~$2–10k (PBTC/PETH pools 0.063+0.838 @ ~$5.2k + $2.1k), but the live tables say those pools are fully lent and the engine drips capacity slowly (observed doupdate issue events of 0.006–0.2 VIGOR).

**Unresolved residual (flagged, not quantified):** the `recap`/`recapsaver` liquidation book (10k+ entries in `bailout` table, id 11013) and `l_debt` accounting — whether savers can buy recap positions at frozen-oracle terms to extract pTokens was not fully reverse-engineered. Recommend as the next target if this finding is escalated.

## 6. What an attacker can/cannot do (exact call paths)

- ❌ `kick(usern,delay_sec)` from an external account → aborts with "Needs auth" (require_auth(vigorlending)); ✅ only as inline executed by `vigorlending` (observed 11 bailouts + 2 kicks since Aug 2026, all `[vigorlending@active]`).
- ❌ `bailout/bailoutup/returncol/returnins/cleanbailout/doupdate/setconfig/…` from outside — contract-only.
- ❌ `liquidate/liquidateup` on *someone else* — needs either contract or the victim's auth.
- ✅ `tick` (no auth) — anyone can drive the protocol clock/queue; no value accrues to caller.
- ✅ `openaccount(me)` after `memberreg` — permissionless.
- ✅ `assetout(me, X, memo)` — self only: withdraw own insurance/collateral/savings/vigfees/stakerefund or borrow (memo `borrow`) subject to collateral ratio, frozen prices, per-user settle delay and daily outbound caps.
- Deposits = token `transfer` notifications to `vigorlending` (`apply` else-branch → `f_xp` → `f_ak`), which validate (token contract, symbol) against the whitelist ("assetin token contract mismatch or unknown") — forged-token deposits revert.
- Stealing balances of others / draining pools by auth bypass: **not found** (no `has_auth`-only value mover; no wrong-account `require_auth` in any value path).

## 7. Blockers / caveats

- No EOSIO dry-run available; borrows cannot be simulated — E-U conditional path rests on static code + one analogous successful live borrow (VIGOR) + pool tables.
- `lentpct` semantics ("available = lendable×(1−lentpct)") is an interpretation of the protocol's own table; if stale, conditional E-U could be up to ~$2–5k (PBTC/PETH pools).
- PBTC/PETH are pNetwork pTokens; redeemability into BTC/ETH not verified (pNetwork had 2021 issues); priced at BTC/ETH equivalent. Defibox PBTC pools are thin and skewed (do not support $82.8k liquidation at spot).
- H-O realization is first-come-first-served: on-chain coverage exists but withdrawals are throttled by the protocol's settle/daily caps and by each user's debt ratio; the frozen oracle *favours* users withdrawing pTokens (their EOS/VIG debt is wildly overvalued).
- The DAC authority (4-of-7 custodians + `daccustodia1` code path) can override everything (P) — no evidence of use.
- Prices are snapshot; VIGOR/VIG are illiquid and can move.

## 8. Verdicts

| Category | Amount | Basis |
|---|---|---|
| **E-U (headline)** | **$0 demonstrated** (conditional mispriced borrow ≤ ~$150, low-med confidence) | all value movers gated (`require_auth(vigorlending)` or self), verified statically + on history; frozen-oracle borrow path is capacity-throttled |
| **H-O** | **$119,635** | user balances covered by physical tokens ($109,456 `vigorlending` + $10,179 `vigorstaking`), self-service withdrawals (staking proven on-chain) |
| **P** | $122,425 (everything) | `dacauth11111` authority: 4-of-7 custodians via `daccustodia1`; action semantics restrict misuse |
| **S** | **$14,002** nominal | unbacked EOS claims ($12,402) + staking phantom row ($1,600); nobody external can move |

## 9. Evidence index (all under `/home/heisenberg/CA/eos-misc/analysis/vigor/raw/`)

- `abi_*.json`, `raw_*.json`, `*.wasm`, `*.dcmp` — ABIs, raw code, decompiles (vigorlending/vigorstaking/vigortoken11/vig111111111/dactoken1111).
- `dispatcher_map.json`, `strings_map.json`, `func_fingerprints.json` — action/name/string maps used for the auth table.
- `users_all.json` (263 user rows), `vigorstaking_allrows.json` (351 stake rows), `totals.json` — aggregation.
- `hist_vigorlending.json` — action history 2026-08/09 incl. contract-authorized kick/bailout proof.
- `staking_scopes_1.json` (+ `staking_rows/`) — staking scopes.
- Live reads (commands): `get_account`, `get_abi`, `get_raw_code_and_abi`, `get_currency_balance`, `get_table_rows` (`globalstats/config/whitelist/user/bailout/stake/market/croneosqueue`), `get_table_by_scope`, `abi_json_to_bin` (encoding validation), plus Hyperion `get_tokens`/`get_actions`.
