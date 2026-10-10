# C2-47 — Carmine Options (Starknet): live extractability deep-dive

**Date:** 2026-10-10 · **Chain:** Starknet mainnet · **Status:** read-only; no mainnet transactions; all proofs are `starknet_call` / view calls at recorded blocks + CI-hosted read-only enumeration. No fork PoC applicable (closed accounting paths proven by view-level call traces and exact math reproduction).

**Targets (both Carmine options-AMM deployments):**

| Target | Address | Class | Note |
|---|---|---|---|
| Legacy AMM (Cairo-0, OZ proxy) | `0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa` | proxy `0xeafb0413…`; impl `0x06eaee658250b9bee534ad7858f2c859460630e46ec5cdb2a1442ae64adc8b50` | `github.com/CarmineOptions/carmine-protocol` |
| New AMM (Cairo-1, v2.3.x) | `0x047472e6755afc57ada9550b6a3ac93129cc4b5f98f51c73e0644d129fd208d9` | `0x7fb1aa680d9c02e1017d5ed048612630c30d11991d43b3e4e7a22531621cd5c` | `github.com/CarmineOptions/protocol-cairo1` |
| Sister instance (test/dust) | `0x1007d87af0a2b9b6199f5f09ab9c230f415470eeceb5a8b01590c51229da562` | `0x45fb686c…` | holds ~$19 total — not in original finding |
| Governance (owner of both AMMs) | `0x001405ab78ab6ec90fba09e6116f373cda53b0ba557789a4578d8c1ec374ba0f` | `0x4bc8bc…` | on-chain voting |

## TL;DR

| Target | Live extractable (unprivileged attacker) | Why closed | Latent risk |
|---|---|---|---|
| Legacy AMM pools | **$0** | All 318 listed options expired (Apr–Sep 2023); no trading possible; LP deposit/withdraw is fair-value (floor-consistent); settle is holder-gated; every admin entry point reverts for non-admin | Governance can `add_option`/`upgrade`; then pricing/volatility design applies again |
| New AMM pools | **$0** | All ~5,600 listed options expired (Jan 2024 – mid 2025); `trade_open` → `VTI - opt already expired`; `trade_close` → `GTTM - secs_left < 0`; `trade_settle` → `EOT - User has no tokens`; deposit/withdraw fair-value; owner-gated admin | Permissionless `set_pragma_checkpoint`/`set_pragma_required_checkpoints` relays to Pragma (keeper-only); governance upgrade |
| Sister instance | **$0** | ~$19 dust, same class family, all pools empty of options | — |

**Total live extractable by an external unprivileged attacker: $0.00** (confidence: **high**).  
What remains live is **holder-recoverable (H-O)**: LP withdrawals (fair pro-rata) and expired-option settlements by token holders — quantified in §5. Residual dust is **S**.

## 1. What the finding claimed vs what is live

The corpus lead (C2-47) said: “$104.7k (20.95 ETH + 20,637 USDC legacy + $27.1k new); options AMM accounting unverified”. Verified on 2026-10-10 (all reads block-stamped; final CI enumeration at block 16155120 — see `ci-out/`):

- Legacy AMM balances: **20.951135380291823434 ETH + 20,637.220256 USDC** (matches the lead).
- New AMM balances: **5.697351956771662870 ETH + 8,250.178739 USDC + 0.00108604 WBTC + 53,800.852894369432713458 STRK + 3.216785878790275605 EKUBO**.
- Both AMMs hold only *expired* options. There is no non-expired option in any of the 12 pools (`get_all_non_expired_options_with_premia` returns empty for every pool — see §5).
- The AMM accounting (pricing, LP share math, settlement splits, expiry adjustments) was reviewed against the deployed source (legacy repo + `protocol-cairo1` v2.3.1). No unprivileged extraction path exists in the current state.

## 2. The mechanism in exact terms

Carmine is a European-options AMM. Pools are keyed by `(quote, base, option_type)` with an LP token per pool. Options are keyed by `(pool, side, maturity, strike)` with an ERC-20 option token per side. The AMM holds pool collateral; option writers' collateral sits in the AMM; payouts on expiry use `split_option_locked_capital(option_type, size, strike, terminal_price)`:

- CALL: `long = size·max(0,(T−K)/T)` (base units), `short = size·(1−long_rel)` (base units).
- PUT: `long = size·max(0,K−T)` (quote units), `short = size·min(K,T)` (quote units).

LP shares are priced as `value_of_pool = free_capital + value_of_pool_position`; `free_capital = lpool_balance − locked_capital`. All rounding floors toward the pool.

**The state that closes the door:** every listed option is past maturity, and `add_option`/`add_option_both_sides` is owner-gated, so no new option can be created by an attacker. Therefore:
- `trade_open` cannot succeed (expired options rejected).
- `trade_close` cannot succeed (negative time-to-maturity assert).
- `trade_settle`/`expire_option_token` pays only to holders of the option tokens (balance check).
- `expire_option_token_for_pool` is permissionless but value-preserving and no-ops for zero positions.
- LP deposit/withdraw are fair-value (verified by reproducing the on-chain math; see §6).

## 3. Live-state assessment (all citations at recorded blocks)

See `ci-out/state-proof.json` (block-stamped) for the full machine-readable dump. Key facts:

**Legacy AMM** (`0x076dbabc…`):
- `getAdmin()` = governance `0x001405ab…`; `get_trading_halt()` = 0; `getImplementationHash()` = `0x06eaee…`.
- Implementation identified (`analysis/legacy-version.md`): the **repo-master core AMM as of 2023-09-27** (ABI v1.1; includes the post-v1.1 stale-price checks, stablecoin-divergence accounting and the 2023-09-26 “option settled before pricing” guard). Upgrade history: deployed 2023-04-07 (`0x2a67…`), upgraded 2023-04-12 (`0x16ce…`), 2023-04-13 (`0x387c…`), and 2023-09-27 10:04 UTC to `0x6eaee…` (block 267,110, tx `0x37c61e…`), all via the governance admin.
- Pools: `0x07aba50f…` (ETH/USDC CALL; lpool 12.541574290747724 ETH; locked 100 wei; LP supply 11.130441688642078372; LP claim 12.541574290747723 ETH) and `0x18a6abca…` (ETH/USDC PUT; lpool ≈ 17,139.968192 USDC; locked 64; LP supply 14.371124208).
- Listed options: 178 (call pool) + 140 (put pool), all with maturity ≤ 2023-09-15. All pool positions zero/dust.
- Balances: 20.951135380291823434 ETH + 20,637.220256 USDC.

**New AMM** (`0x047472e6…`):
- `owner()` = governance `0x001405ab…`; `get_trading_halt()` = 0; `get_fees_percentage()` = 3; class `0x7fb1aa…` (declared 2025-05-02; upgraded via governance proposal tx `0x74ff7a5a…` on 2025-05-14).
- 10 pools (ETH/USDC, BTC/USDC, ETH/STRK, STRK/USDC, EKUBO/USDC × call/put), each with ~500–820 listed options, all expired.
- Balances: 5.697351956771662870 ETH + 8,250.178739 USDC + 0.00108604 WBTC + 53,800.852894369432713458 STRK + 3.216785878790275605 EKUBO.

**Sister** (`0x1007d87a…`): balances 69 wei ETH + 19.000000 USDC + 42 sats WBTC; 4 LP pools; dust.

## 4. What an attacker can / cannot do

**Cannot (all probed with caller = zero address, read-only):**
- `trade_open` (legacy & new) — expired; new AMM: `VTI - opt already expired`.
- `trade_close` — new AMM: `GTTM - secs_left < 0`.
- `trade_settle` — new AMM: `EOT - User has no tokens`; legacy reverts at the same ownership assert.
- `mint`/`burn` on LP or option tokens — revert (AMM-only minters).
- `upgrade`, `setAdmin`, `initializer`, `add_option`/`add_option_both_sides`, `set_max_lpool_balance`, `set_trading_halt`, `set_trading_halt_permission`, `set_pool_volatility_adjustment_speed`, `set_max_option_size_percent_of_voladjspd` — all revert for non-admin (`Caller is the zero address` / `Proxy: caller is not admin` / `already initialized`).
- `withdraw_liquidity` with caller 0 — `Caller address is zero`.

**Can (permissionless, but no value for an attacker):**
- `deposit_liquidity` / `withdraw_liquidity` — fair-value, floor-consistent, LP tokens burned/minted 1:1 with the formula; an attacker cannot profit from a round trip (both directions floor toward the pool).
- `expire_option_token_for_pool` — anyone may expire a pool’s own position on an expired option; value-preserving for LPs (proof in §6) and required for holder settlements.
- `set_pragma_required_checkpoints()` / `set_pragma_checkpoint(key)` (new AMM only) — permissionless relays that make the AMM call Pragma’s `set_checkpoint`; they snapshot the *genuine* Pragma median at the current time (no attacker-chosen price). No value transfer to the caller.
- Settle expired options **if you hold the option tokens** — holder-only (H-O).

## 5. Live value split: E-U / H-O / P / S

Exact numbers from `analysis/enumerate_claims.py` over **every listed option** on both AMMs (token supplies × the contracts' own `get_terminal_price` views), run in CI at block 16158081 (see `ci-out/claims.json`). USD at run-time DefiLlama prices (ETH $2,490.65, USDC $0.9997, BTC $82,582.14, STRK $0.0710, EKUBO $1.3794):

| Pool | # options | LP claim (H-O) | Option-holder claims (H-O) |
|---|---|---|---|
| legacy ETH/USDC CALL | 178 | 12.541574290747723 ETH ($31,236.62) | 8.41003488 ETH ($20,946.42) |
| legacy ETH/USDC PUT | 140 | 17,139.968128 USDC ($17,134.96) | 3,497.45259115 USDC ($3,496.43) |
| new ETH/USDC CALL | 820 | 4.70619274108251 ETH ($11,721.46) | 0.48075799 ETH ($1,197.40) |
| new ETH/USDC PUT | 814 | 3,628.938453 USDC ($3,627.88) | 34.40070201 USDC ($34.39) |
| new BTC/USDC CALL | 694 | 0.00108599 WBTC ($89.68) | 0 (all OTM at expiry) |
| new BTC/USDC PUT | 686 | 46.658395 USDC ($46.64) | 0.6081151 USDC ($0.61) |
| new ETH/STRK CALL | 822 | 0.5081141290466102 ETH ($1,265.53) | 0.0022871 ETH ($5.70) |
| new ETH/STRK PUT | 852 | 23,213.809368086215 STRK ($1,647.93) | 0.14438706 STRK ($0.01) |
| new STRK/USDC CALL | 826 | 30,124.47409654737 STRK ($2,138.51) | 462.42504267 STRK ($32.83) |
| new STRK/USDC PUT | 808 | 4,264.801445 USDC ($4,263.56) | 271.24726772 USDC ($271.17) |
| new EKUBO/USDC CALL | 506 | 2.9077759739592253 EKUBO ($4.01) | 0.3090099 EKUBO ($0.43) |
| new EKUBO/USDC PUT | 488 | 4.950698 USDC ($4.95) | 0.37535168 USDC ($0.38) |
| sister (4 pools, dust) | ~0 | ~$19.03 | 0 |

**Buckets:**
- **E-U (external unprivileged): $0.00** — no extraction path found (high confidence).
- **H-O (holders): $99,186.51** = LP withdrawals $73,181.74 + expired-option settlements $25,985.75 + sister ~$19.03.
- **P (privileged): $0.00** today (governance can revive/upgrade — latent).
- **S (stuck): $2.62** — locked-capital dust in pools whose pool positions are zero and whose `expire_option_token_for_pool` no-ops, plus rounding.

All pools: **0 non-expired options** and **0 blocked maturities** (every maturity's terminal price resolves on-chain). Contract balances reconcile with (LP claims + option claims) to within float/Fixed dust (<$2), i.e., there is no hidden unaccounted bucket.

Note: two new-AMM pools still carry unexpired *pool* positions on expired options — STRK/USDC PUT (marked value ≈2.106 USDC) and EKUBO/USDC PUT (≈1.625 USDC) — already included in the LP claims above. Anyone may release them with `expire_option_token_for_pool`; the operation is value-preserving (verified analytically: `lpool_balance ± long_value`, `locked_capital − (long+short)` leaves `free_capital + value_of_position` unchanged).

## 6. Verification: CI proofs and math reproduction

CI job (read-only; keyless RPC): `ci/run.sh` runs
1. `analysis/state_proofs.py` — block-stamped live state + permissionless/gated probes (`ci-out/state-proof.json`);
2. `analysis/enumerate_claims.py` — full option enumeration for all 12 pools, token supplies, on-chain terminal prices, payout math (`ci-out/claims.json`);
3. `ci-out/math-check.txt` — LP math reproduction: `get_underlying_for_lptokens(all supply)` vs Python `free_capital` (exact match within 2 wei).

CI run URLs:
- **Final run (success, matches `ci-out/` here):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38024489199
- Earlier full runs (success): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38022169096 · https://github.com/kingmariano/ca-zombie-ci/actions/runs/38019539924
- First attempt (claims enumeration hit a publicnode 403; fixed with keyed-env failover): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38019168983

Results: `ci-out/state-proof.json`, `ci-out/claims.json`, `ci-out/math-check.txt` (all block-stamped; `MATH CHECK PASS`), downloaded to `ci-artifacts/result-carmine/ci-out/`.

## 7. Verdict, residual and latent risk

**Verdict:** E-U $0.00 (high confidence). Both deployments are fully-expired, accounting-consistent zombie systems whose remaining funds are holder claims. An attacker with only public liquidity and no option/LP tokens cannot extract anything: every state-changing path either requires token ownership, requires an owner key, or is economically neutral.

**Latent risk (why this finding should stay on a watchlist):**
- Both AMMs are **upgradeable by the governance contract** `0x001405ab…`; governance can add options and revive trading at any time. If it does, the pricing design (midpoint-volatility trade pricing, `VOLATILITY_UPPER_BOUND = 2^64` — effectively unbounded) deserves the full manipulation analysis that this closed state made moot.
- New AMM exposes **permissionless Pragma checkpoint relays**; if Pragma ever charges the caller, the AMM (as caller) could be griefed into paying fees.
- The new AMM has a hard-coded hotfix list of five EKUBO/USDC maturities (Apr–May 2025) whose terminal prices come from constants, not Pragma.
- Documented history (see `analysis/web-research.md`): **Hack-a-Chain** audited the legacy Cairo-0 AMM (final 2023-05; stale-oracle and USD/USDC-quote findings, fixed) and **Nethermind NM-0153** audited the Cairo-1 v2 (final 2024-01-08; 28 findings incl. 2 Critical locked-capital bugs and LP-valuation bugs — all fixed pre-deployment; a sandwich risk fixed via an LP-token `SandwichGuard`). The only known loss event is a self-documented **Aug-2023 oracle historical-price bug** (~0.046 ETH across 11 addresses, repo `supreme-dollop`); no public exploit/hack of Carmine exists. A 2026 Pragma conversion-rate poisoning issue (Asymmetric Research) was fixed and named Carmine among affected integrations.
- Governance-capture cost is out of scope here (covered by the campaign’s governance-capture class).

**Blockers/unknowns:** the sibling instance’s purpose (dust); Pragma fee mechanics for `set_checkpoint` (none observed); Nethermind Critical #1 exact mechanism (title only in the public record). Legacy implementation version is resolved (`analysis/legacy-version.md`).

## 8. Methodology, sources, caveats

- Read-only Starknet JSON-RPC (`starknet_call`, `starknet_getClass`, `starknet_getClassHashAt`) against `https://starknet-rpc.publicnode.com` (keyless) and a keyed endpoint used locally only (never stored).
- Source review: `github.com/CarmineOptions/carmine-protocol` (Cairo 0) and `github.com/CarmineOptions/protocol-cairo1` (v2.3.1, Cairo 1).
- Audits: Hack-a-Chain (legacy Cairo-0, final 2023-05-01) and Nethermind NM-0153 (Cairo-1 v2, final 2024-01-08) — details and URLs in `analysis/web-research.md`.
- Caveats: option-claim totals are computed with the contracts’ own terminal-price views and the documented split formulas; conversion to USD uses DefiLlama prices at run time; rounding of ±dust (<$2) possible; all maturities resolved on-chain (`blocked` lists empty in `ci-out/claims.json`).

## 9. Files index

- `analysis/sn.py`, `analysis/keccak_pure.py` — Starknet RPC helper + pure-Python keccak.
- `analysis/state_proofs.py` — live-state proofs & probes.
- `analysis/enumerate_claims.py` — full claims enumeration.
- `analysis/new-amm-abi.md` — new-AMM provenance/ABI/gating analysis (child subagent).
- `analysis/legacy-version.md` — legacy implementation identification (impl `0x06eaee…`, upgrade history, markers).
- `analysis/web-research.md` — audits/incidents/migration research with URLs.
- `analysis/make_summary.py` — builds `summary.json` from CI outputs.
- `analysis/upgrade-history.json`, `upgrade-events.json`, `live-calls.json`, `markers.json`, `proxy_class.json`, `legacy_*_class.json` — legacy version evidence chain.
- `analysis/legacy-options-details.json` — per-option evidence for the legacy pools (318 rows).
- `analysis/state-dump-3.json`, `analysis/claims-test-*.json` — raw local dumps.
- `ci/run.sh`, `ci-out/*` — CI job and results; `ci-log.txt`, `ci-artifacts/` — CI logs/artifacts.
- `summary.json` — machine-readable summary.
