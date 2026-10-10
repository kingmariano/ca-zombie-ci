# Dossier — Arkadiko Swap v2 (Stacks) — legacy-custody watch

Campaign: **H2-09 zombie-hunt II — legacy-custody watches** · group **stacks-arkadiko**
Also cross-referenced by H2-06 (parent to mark cross-reference).

**VERDICT: E-U = $0. No external unprivileged extraction path found.**
The headline custody (~684.7k STX + 191.2k USDA + 13.55M DIKO + 0.336 xBTC + ~6.1M WELSH) is **LP-backed DEX pool reserves plus uncollected protocol fees and a small amount of unsweepable junk**. Every outflow path is either (a) a fair swap (pay input at AMM rate), (b) LP-proportional withdrawal (needs LP tokens), (c) a permissionless fee sweep whose recipient is hard-wired to the protocol payout address, or (d) multisig-privileged. All token supplies that feed the pools are guarded against free minting (DAO-gated or fixed-supply). Result matches the parent's "no path found" — now proven by source + state.

Confidence: **high** on E-U = $0 (full source read + line-by-line math check + on-chain state reconciliation + mint-authority review). Medium on valuation of DIKO/LDN (thin markets).

---

## 1. Snapshot metadata (all read-only, public keyless endpoints)

| Measurement | Stacks tip | Tip hash | Notes |
|---|---|---|---|
| Pool state, DAO state, LP supplies, guards | **9,166,412 → 9,166,426** | `d76bcb81c95041edf5604ab5c701239d2c55664a5f7a63856c40b4e1d7fa421e` | `data/ark-snapshot.json` |
| Coordinated pairs + contract balances + reconciliation | **9,166,481** (burn block 970,788) | `0x085f019ed7a12de592c548bac998f04c309bc07955f4c1a713e2055b21970416` | `data/ark-final.json` |
| Raw contract balances (first read) | ≈9,164,6xx (tip 9,164,636 observed) | — | `data/swap-balances-first-read.json` |
| Raw contract balances (final) | between 9,166,481 and 9,166,483 | — | `data/swap-balances-final.json` |
| Active-tx sample | 9,147,726 – 9,166,432 | — | `data/swap-recent-txs.json` |

Endpoints used (all public, keyless, read-only):
`https://api.hiro.so/v2/info`, `/v2/contracts/source/{p}/{n}`, `POST /v2/contracts/call-read/...`, `/extended/v1/address/{p}/balances`, `/extended/v1/address/{p}/transactions`, `/extended/v1/block/by_height/{h}`.
Prices: `https://coins.llama.fi/prices/current/...`, `https://api.coingecko.com/api/v3/simple/price`.

No keys, no writes, no transactions.

---

## 2. Contracts and addresses

| Role | Contract ID | Version / publish height | Notes |
|---|---|---|---|
| Deployer / payout | `SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR` (hash160 `982f3ec1…b896a5`, ver 22) | — | single-sig; DAO `get-payout-address` |
| **Swap core (v2)** | `SP2C2Y…89YZR.arkadiko-swap-v2-1` | publish h=37075, "@version 2" | **DAO-registered as "swap"** (verified on-chain) |
| Old swap | `SP2C2Y…89YZR.arkadiko-swap-v1-1` | — | holds only 691.94 STX + junk (checked) |
| DAO | `SP2C2Y…89YZR.arkadiko-dao` | h=34239 | owner/guardian = `SM1CZEHHNMHMWKK8VMH8S8N3B6YRS8DT78DYWYXKH` (multisig ver 20) |
| wSTX | `SP2C2Y…89YZR.wrapped-stx-token` | h=34286 | mint only via DAO |
| USDA | `SP2C2Y…89YZR.usda-token` | h=34239 | mint only via DAO |
| DIKO | `SP2C2Y…89YZR.arkadiko-token` | h=34230 | mint only via DAO |
| LP tokens (8) | `…arkadiko-swap-token-{wstx-usda, wstx-diko, diko-usda, wldn-usda, ldn-usda, wstx-welsh, wstx-xbtc, xbtc-usda}` | 34286 – 54138 | mint/burn only by DAO-registered "swap" |
| xBTC | `SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.Wrapped-Bitcoin` | canonical | not mintable |
| WELSH | `SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token` | fixed 10B supply | **no mint function** |
| LDN / wLDN | `SP3MBWGMCVC9KZ5DTAYFMG1D0AEJCR7NENTM3FTK5.{lydian-token, wrapped-lydian-token}` | h=51868 / 51872 | `mint` only by `active-minter` (Lydian treasury) |

Two independent on-chain confirmations that the LP mint guard target is v2-1:
`arkadiko-dao.get-qualified-name-by-name("swap")` = `…arkadiko-swap-v2-1`, and
`arkadiko-dao.get-contract-can-mint-by-qualified-name(swap)` = true (also can-burn = true).
`get-emergency-shutdown-activated` = **false**; `swap.shutdown-not-activated` = **true**; all 8 pairs `enabled` = true.

---

## 3. Live state at tip 9,166,481 — 8 pools (`get-pair-details`)

| Pair (x / y) | balance-x | balance-y | shares-total | fee-balance-x | fee-balance-y |
|---|---|---|---|---|---|
| wSTX / USDA | 645,240,139,132 uSTX | 163,659,384,939 uUSDA | 239,502,581,324 | 11,905,206,791 | 14,204,608,812 |
| wSTX / DIKO | 51,010,193,490 | 4,652,431,662,416 | 378,825,508,662 | 2,827,226,637 | 49,148,073,601 |
| DIKO / USDA | 8,945,131,881,965 | 25,093,657,231 | 414,278,941,156 | 30,601,385,907 | 2,544,432,196 |
| wLDN / USDA | 8,045 | 3 | 5 | 589,655 | 41,154,746 |
| LDN / USDA | 23,940,613 | 400,643,262 | 96,261,291 | 7,600,600 | 117,496,014 |
| wSTX / WELSH | 2,805,029,787 | 6,120,598,113,910 | 70,750,952,443 | 566,117,926 | 4,858,396,908,008 |
| wSTX / xBTC | 2,585,181,991 | 901,980 | 45,951,213 | 414,267,317 | 1,547,928 |
| xBTC / USDA | 35,337,963 | 25,640,781,943 | 852,748,895 | 999,501 | 484,414,669 |

LP total supplies at same epoch: 239.50M / 378.83M / 414.28M / 5 / 96.26M / 70.75M / 45.95M / 852.75M (raw, 6dp).
`pairs-map` (the enumerated `pair-id` index) returns **UnwrapFailure for ids 0–9** on read-only calls — i.e., the on-chain `pairs-map` index appears empty/unused at this epoch while `pair-count` = 8 and `pairs-data-map` is fully populated. Pools are looked up by token principals, so this does not affect operation; recorded as an anomaly (not security-relevant).

## 4. What the swap contract actually holds (tip 9,166,481)

| Token | Actual balance (raw) | Human | Reconciled vs tracked pool | vs pool+uncollected fees |
|---|---|---|---|---|
| STX (native) | 684,665,047,263 | 684,665.05 STX | −16,975.50 | −32,688.32 |
| wSTX | 684,665,047,263 | = STX (peg exact) | −16,975.50 | −32,688.32 |
| USDA | 191,168,486,354 | 191,168.49 | −23,625.98 | −41,018.09 |
| DIKO | 13,551,588,659,971 | 13,551,588.66 | −45,974.88 | −125,724.34 |
| xBTC | 33,558,053 | 0.33558053 BTC | −2.681890M sat | −5.229319M sat |
| WELSH | 6,120,598,113,910 | 6,120,598.11 | **0** | −4,858,396.91 (fees unbacked) |
| LDN | 2,062,964 | 2.062964 | −21,877,649 (raw) | −29,478,249 |
| wLDN | 8,045 | 0.008045 | 0 | −589,655 (fees unbacked) |
| Junk/spam (jenner, ELON, KNFE, rock, GME, …) | — | ~$0 | untracked | stuck |

Balance-sheet identity (per token): `actual = tracked_pool + uncollected_fees − historically_collected_fees` (assuming no direct donations; two spam tokens show donations exist in principle). The deficits vs tracked pool = historically collected fees that were withdrawn from actual reserves while `balance-x/y` was left untouched. **This is how ~16,975 STX / ~23,626 USDA / ~2.68M sat have already left the pool backing** — they were double-counted as both pool reserve and fee, then swept to the payout address. LP notional claims exceed actual backing by ~$33k (see §7).

Peg check: contract STX == contract wSTX, and wSTX supply outside it is backed by the v1 swap's STX (v1 holds 691.94 STX; 685,356,831,463 total wSTX supply ≈ 684,665,047,263 + 691,943,414). Reserves fully collateralise wSTX.

---

## 5. Source audit — `arkadiko-swap-v2-1` (`sources/arkadiko-swap-v2-1.clar`, 665 lines, full read)

### F1 — Swap math: division order, rounding, fee (lines 473–583)
```clarity
481:  (dx-with-fees (/ (* u997 dx) u1000))            ;; 0.3% fee for LPs
482:  (dy (/ (* balance-y dx-with-fees) (+ balance-x dx-with-fees)))
483:  (fee (/ (* u5 dx) u10000))                      ;; 0.05% fee
...
487:  balance-x: (+ balance-x dx), balance-y: (- balance-y dy),
489:  fee-balance-x: (if (is-some (get fee-to-address pair)) (+ fee (get fee-balance-x pair)) ...)
```
- Both output and fee computations **floor**; residue always favours the pool.
- Input `dx` is credited to `balance-x` in full while output uses `dx-with-fees < dx` ⇒ k = balance-x·balance-y strictly **increases** each swap. Numerically verified: k_new/k_old = (Bx+dx)/(Bx+dxf) > 1.
- `dy < balance-y` strictly (`dy = By·dxf/(Bx+dxf)`), so a single swap can never drain more than the tracked balance; for output token y, cumulative payouts across swaps are bounded by initial By.
- `swap-y-for-x` (534–583) is the exact mirror with the same properties.
- `dx ≤ 1 ⇒ dxf = 0 ⇒ dy = 0`; `dy=0` can never satisfy the slippage assert (see F2), so zero-amount k-manipulation is impossible/reverts.

### F2 — Slippage asserts are strict (lines 497, 554)
```clarity
497:  (asserts! (< min-dy dy) too-much-slippage-err)
554:  (asserts! (< min-dx dx) too-much-slippage-err)
```
Requires output **>** min; `min=0` still demands `output ≥ 1`. No bypass.

### F3 — add-to-position: shares minted from tracked reserves (lines 158–214)
```clarity
169:  (new-shares (if (is-eq (get shares-total pair) u0)
170:                 (sqrti (* x y))
172:                 (/ (* x (get shares-total pair)) balance-x)))
175:  (new-y (if (is-eq (get shares-total pair) u0) y (/ (* x balance-y) balance-x)))
```
- After initialisation, the caller's `y` argument is ignored; the contract pulls exactly the computed `new-y` and mints `floor(x·S/Bx)` shares. Rounding favours the pool; no minimum-shares check but zero shares only loses the depositor's own tokens.
- First-depositor `sqrt(x·y)` path is only reachable with `shares-total=0`. No pool is in that state (min shares = 5 on wLDN/USDA), and normal `reduce-position(100)` by the last LP leaves tracked balances exactly 0, so the classic "capture residue on empty pool" state is not reachable.
- It does **not** check `enabled` (a disabled pair still accepts deposits) — asymmetry vs `reduce-position` which does check `enabled` (line 439). Governance can therefore freeze withdrawals on a disabled pair. Observation only; no attacker path.

### F4 — reduce-position: strictly proportional (lines 411–465)
```clarity
424:  (withdrawal (/ (* shares percent) u100))
425:  (withdrawal-x (/ (* withdrawal balance-x) shares-total))
426:  (withdrawal-y (/ (* withdrawal balance-y) shares-total))
438:  (asserts! (<= percent u100) (err u5))
460:  (try! (contract-call? swap-token-trait burn tx-sender withdrawal))
```
`percent ≤ 100` ⇒ `withdrawal ≤ shares`; both legs floor; cannot withdraw more than pro-rata share of tracked balances. `shares` is read live from the LP token, so double-spend by re-entrancy is impossible (Clarity is atomic; also only whitelisted token contracts are called).

### F5 — collect-fees: unauthenticated, fixed recipient, can eat pool backing (lines 619–653)
```clarity
619: (define-public (collect-fees (token-x-trait <ft-trait>) (token-y-trait <ft-trait>))
624:   (address (unwrap! (get fee-to-address pair) (err ERR-NO-FEE-TO-ADDRESS)))
629:   (asserts! (> fee-x u0) no-fee-x-err)
632:   (asserts! (is-ok (as-contract (stx-transfer? fee-x (as-contract tx-sender) address))) ...)
635:   (try! (as-contract (contract-call? token-x-trait transfer fee-x (as-contract tx-sender) address none)))
```
- **No auth check** — anyone can trigger it; funds always go to the pair's `fee-to-address`, which is fixed to the DAO payout (`SP2C2Y…`) since creation (create-pair line 349; `set-fee-to-address` is dao-owner-only, line 590, and uses `tx-sender`).
- It transfers the *tracked* `fee-balance-*`, without checking that the actual contract balance exceeds the pool's tracked balance. Where fees are partially unbacked (today: WELSH 4.858B ≈ 79% of the contract's actual WELSH; wLDN 589,655; plus partially elsewhere) the sweep draws down backing that the pools' `balance-x/y` believe is there. Attacker profit = **$0** (fixed recipient), LP harm = up to the fee amounts.
- This is the mechanism that produced the deficits in §4.

### F6 — privileged functions / who can change what
| Function | Guard | Principal |
|---|---|---|
| `toggle-swap-shutdown` (31) | `contract-caller == dao.get-guardian-address` | multisig SM1CZ… |
| `toggle-pair-enabled` (391) | same | multisig SM1CZ… |
| `set-fee-to-address` (586) | `tx-sender == dao.get-dao-owner` | same multisig |
| `create-pair` (327), `migrate-create-pair` (235), `migrate-add-liquidity` (279) | `contract-caller == dao.get-dao-owner` | same multisig |
| `attack-and-burn` (657) | dao-owner **and `block-height < u40000`** | dead at 9.16M |

No unguarded `set-*`/`emergency-*`/oracle setters exist in the contract. **The swap contract references no oracle at all** (grep: 0 hits).

### F7 — LP token mint/burn guards (all 8 contracts verified)
Quoted from `sources/arkadiko-swap-token-wstx-usda.clar` (identical guard in all 8):
```clarity
(asserts! (is-eq contract-caller (unwrap-panic (contract-call? .arkadiko-dao get-qualified-name-by-name "swap"))) (err ERR-NOT-AUTHORIZED))
```
⇒ only `arkadiko-swap-v2-1` can mint/burn LP. LP cannot be forged.

### F8 — Input-token mint authorities (free-mint check)
| Token | Guard | Free mint? |
|---|---|---|
| wSTX | `mint-for-dao` requires `contract-caller == .arkadiko-dao`; DAO `mint-token` requires caller registered can-mint | **No** |
| USDA | identical DAO gate | **No** (only registered protocol contracts; no public free-mint) |
| DIKO | identical DAO gate; external `burn` only self; `set-contract-owner` owner-only | **No** |
| xBTC | canonical Wrapped-Bitcoin, burn/mint via its own protocol | **No** |
| WELSH | **no mint function at all**; 10B minted once at deploy | **No** |
| LDN / wLDN | `mint` requires `contract-caller == active-minter` (`…treasury-v1-1`); `set-active-minter` requires `tx-sender == .lydian-dao` | **No direct** |
| LP tokens (8) | DAO-"swap" gate | **No** |

---

## 6. Call-path analysis — every E-U route considered and why it fails

| # | Route | Result |
|---|---|---|
| E1 | Tiny/odd `dx` rounding in `swap-x-for-y`/`swap-y-for-x` | Floor on all legs; k increases; zero-output path hits strict slippage assert ⇒ revert. **$0** |
| E2 | Force k to decrease via fee accounting | `dx` credited in full, output uses 0.997·dx ⇒ k grows. **$0** |
| E3 | First-LP / empty-pool residue capture (`shares-total=0` with `balance>0`) | Unreachable: last proportional withdraw zeroes tracked balances; min live pool has shares=5. **$0** |
| E4 | Add liquidity then withdraw more than share | Both legs proportional-floor; round-trip strictly loses. **$0** |
| E5 | Mint a pool input token for free, then swap out real assets | All pool inputs are free-mint-proof (F8): wSTX/USDA/DIKO DAO-gated, xBTC canonical, WELSH fixed-supply, LDN/wLDN treasury-gated. Theoretical bounds if it were possible (not): wSTX/USDA pool = 645k STX / 163k USDA; wSTX/DIKO = 51k STX / 4.65M DIKO; wSTX/WELSH = 2.8k STX; wSTX/xBTC = 2.58k STX. **$0** |
| E6 | Redirect `collect-fees` to attacker | Recipient is the pair's `fee-to-address` = payout; `set-fee-to-address` dao-owner-only. Attacker can only *donate* to the payout. **$0** |
| E7 | Withdraw more than pro-rata via dust `percent` / repeated calls | `percent≤100`, live share balance, burns exact amount. **$0** |
| E8 | Trait substitution / fake token or fake LP contract | Pair key must equal registered `(token-x, token-y)`; `swap-token` must equal registered LP. Panics otherwise. **$0** |
| E9 | Re-entrancy via token trait | Clarity atomicity + whitelisted traits only; state written before/after consistently. **$0** |
| E10 | `attack-and-burn` LP burn | dao-owner-only **and** `block-height<40000` — dead since 2021. **$0** |
| E11 | Sweep "excess" tokens held by contract | No sweep/withdraw-any function; untracked (spam) tokens are stuck, not claimable. **$0** |
| E12 | Stale tracked reserves vs actual (the §4 deficits) — arbitrage edge | Real but bounded: pool pricing uses tracked balances; mismatch of +12% (USDA) vs actual favours *traders at the margin vs true balances*, but only via normal market-rate arbitrage, not a risk-free drain; extraction is capped by the actual holdings per pool and by external quotes. Info leak/haircut to LPs, **not free money**. **$0 risk-free** |

Frozen-pool observations (not extractable): LDN/USDA can pay out at most its tracked `balance-y` ≈ 400.64 USDA (needs ~24M LDN input, treasury-gated mint); wLDN/USDA tracked ≈ 3 uUSDA; both fail or revert well before exceeding actual holdings.

---

## 7. Classification & USD (prices at snapshot: STX $0.4053, BTC $82,962, WELSH $0.0001873, USDA $1 (face))

| Bucket | Class | Amount | USD (approx) |
|---|---|---|---|
| **Attacker-extractable** | **E-U** | 0 | **$0** |
| LP-recoverable pool backing (8 pools, actual held) | **H-O** (LP holders only, via `reduce-position`) | 684,665.05 STX-equivalent + 191,168.49 USDA + 13,551,588.66 DIKO + 0.33558 xBTC + 6,120,598.11 WELSH | ~$498k (STX $277.5k + USDA $191.2k + xBTC $27.8k + WELSH ~$1.1k + DIKO ≈$0 realizable; DIKO marginal-price value $38k–$60k, CG $0.02198 → $297.9k is illiquid — dumping all 13.55M DIKO into its own two pools returns only ≈$100) |
| LP haircut already realised (collected fees vs tracked pool) | S (LP loss) | −16,975.50 STX, −23,625.98 USDA, −45,974.88 DIKO, −2.68M sat | ≈ −$32.9k ($6.9k STX + $23.6k USDA + $2.2k xBTC + dust) |
| Uncollected fees (permissionless sweep to payout, partially unbacked) | P (payout-only) | 15,712.82 STX, 17,392.11 USDA, 79,749.46 DIKO, 0.02547928 BTC, 4,858,396.91 WELSH, … | ≈ $27.1k, goes to `SP2C2Y…`, **never to the caller** |
| Junk/spam tokens | S (stuck) | jenner, ELON, KNFE, rock, GME, TST… | ~$0 |

Residual risk flags (report, not exploit): (1) the payout address is a **single-sig principal** (`SP2C2Y…`) while DAO owner/guardian is a multisig — fee sweeps route value to a single key; (2) `collect-fees` has no auth and can take partially unbacked WELSH/LDN/wLDN amounts from pool backing; (3) `reduce-position` requires `enabled`, so guardian could freeze LP exits (currently all enabled).

---

## 8. Negatives recorded (with evidence)

- No oracle dependency in swap source (grep 0 hits; `sources/arkadiko-swap-v2-1.clar`).
- No proxy/upgrade function in the swap contract; no `set-token-uri`-style generic setters.
- No public `mint` on WELSH; WELSH supply is exactly 10,000,000,000 (verified `get-total-supply`).
- wSTX mint/burn guarded; LP mint/burn guarded (F7/F8); xBTC is the canonical bridged asset.
- Old v1 swap holds only 691.94 STX (not the headline pile); `arkadiko-swap-v2-2` / `-core` do not exist (404 at deployer).
- `attack-and-burn`: permanently disabled (`block-height < u40000` vs current 9.17M).
- `pairs-map` id-index read-only lookups fail (UnwrapFailure) although `pair-count`=8 — pools function via `pairs-data-map` keyed by token principals; no fund flow depends on the broken index.
- Hiro FT-holders index reports 0 holders for the legacy LP tokens (index limitation); LP balances verified directly via `get-balance`/`get-total-supply` instead.

## 9. Confidence & limitations

- **High** confidence on "no E-U": full swap source read; all public functions classified; mint authorities checked at source; live state reconciled; the only remaining paths are market-dependent (E12) and not risk-free.
- Medium confidence on exact USD for DIKO/LDN/WELSH (thin markets); USDA valued at $1 face (no deep market observed).
- Read-only calls execute at the node's tip at call time; the chain advanced ~40 blocks during the session (state in `ark-final.json` is coherent at tip 9,166,481; per-call tips recorded above). Pool balances drift with user activity (e.g. LPs withdrew ~576 STX between first and final reads).
- Not covered here (different contracts): Arkadiko vaults/Freddie (USDA minting), stacking, stake pools, governance; they are out of this group's scope.

## 10. Evidence index

| File | Content |
|---|---|
| `sources/arkadiko-swap-v2-1.clar` | Full swap source (quotes F1–F6) |
| `sources/arkadiko-dao.clar` | DAO: guardian/owner gates, mint-token/burn-token guards |
| `sources/wrapped-stx-token.clar`, `sources/usda-token.clar`, `sources/arkadiko-token.clar` | Mint-authority quotes (F8) |
| `sources/arkadiko-swap-token-wstx-usda.clar` | LP mint/burn guard (F7); all 8 LP contracts verified identical guard pattern |
| `sources/welshcorgicoin-token.clar` | Fixed supply, no mint function |
| `sources/lydian-token.clar`, `sources/wrapped-lydian-token.clar` | Treasury-gated mint |
| `sources/arkadiko-swap-trait-v1.clar` | Trait used for LP interactions |
| `data/ark-final.json` | Tip 9,166,481: all 8 pair tuples, actual balances, reconciliation, prices, raw balances |
| `data/ark-snapshot.json` | Tip 9,166,412–26: pairs, fees, LP supplies, DAO state, guards |
| `data/ark-analysis.json` | Derived tables: reconciliation, USD values, pool rows |
| `data/swap-balances-first-read.json`, `data/swap-balances-final.json` | Raw /extended balances responses |
| `data/swap-recent-txs.json` | Activity sample (live swaps at 9,147,726–9,166,432) |
