# Jet V1 (Solana) — obligation census + activity census + live-path assessment

> ⚠️ **CORRECTION (superseded by post-hoc verification).** Section 2 below ("borrow against
> frozen-oracle solBTC collateral (~$155k)") was written from source+state inference WITHOUT
> executing the deployed binary. A LiteSVM execution PoC against the sha256-verified live ELF
> (`analysis/jet_program.so`, sha256 `2ccc9a0e…c352`) subsequently proved that **`borrow` is
> hard-disabled in the deployed program** (`panic!` at `src/instructions/borrow.rs:110:5`;
> commit `66991f4c8f14` "disable borrows", deployed 2022-11-10, ProgramData slot 160,301,534).
> All 15 borrow variants panic; the vaults cannot be borrowed. See `README.md` §"PoC" and
> `ci-out/poc_results.json`. The borrow path described in §2 is therefore **NOT extractable**;
> it is retained only as latent risk (if the program were upgraded to re-enable borrows).
> Sections 1, 3 and 4 (census, activity, caveats) remain valid.

Status: **read-only research** (no transactions signed/sent). Data: public RPC + Tatum public
archival gateway + cloned accounts (see files index). Market: `9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo`
(program `JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU`). All four reserves live: USDC(0),
SOL(1), solBTC(2, Sollet BTC `9n4nbM75...`), solETH(3, Sollet ETH `2FPyTwc...`).

## 1. Task A — obligation census (ALL 7,289 accounts fetched)

- 7,289 = total obligations (disc `a8ce8d6a584caca7`). 7,287 have at least one position entry, but
  many entries are zeroed dust: **2,853 have any nonzero position** (2,379 collateral-only,
  470 with both, 4 with nonzero debt and no nonzero collateral — all dust); **474 obligations
  carry a nonzero debt value**.
- Totals (recomputed with the on-chain market-cache exchange rates; program math
  `value = notes x note_exchange_rate x price`):

| metric | oracle prices | real prices (Jupiter v3) |
|---|---|---|
| total loan value | $54,393.61 | $51,406.61 |
| total collateral value | $485,041.69 | $206,452.00 |
| unhealthy obligations (loan*1.25 > collateral) | **26** | **60** |
| USDC / SOL / solBTC / solETH debt | 42,566.56 / 9,717.87 / 2,002.94 / 106.25 | 42,554.69 / 8,836.16 / 2.09 / 13.67 |
| USDC / SOL / solBTC / solETH collateral | 58,817.27 / 161,626.79 / 261,364.71 / 3,232.93 | 58,800.87 / 146,962.30 / 272.80 / 416.03 |

- Oracle prices (frozen, market cache last written slot 451021492 = 2026-09-27, from **frozen Pyth
  legacy feeds**): USDC $1.0, SOL $119.23378, solBTC $52,326.9113705, solETH $2304.08750074.
- Real prices used: USDC $0.9997, SOL $108.42, solBTC $54.6161, solETH $296.5034 (Jupiter v3;
  CoinGecko cross-check SOL $108.53).
- Dust (debt bands, oracle set): <$0.10: 133; <$1: 104; <$10: 162; <$100: 44; >=$100: 31.

### Liquidation-path extraction (answer: ~$0)
- The 26 oracle-unhealthy obligations hold $7,269.66 oracle debt vs $4,233.31 oracle collateral.
- Simple bonus metric (min(C - D/1.25, 0.03D)) summed: **$36.44**; exact per-source-formula
  (obligation.rs `liquidate()`, min_cr 1.25, bonus 300bps): **$22.61** oracle USD.
- **Real-terms PnL of executing those exact on-chain liquidations: +$0.083 total** (cents).
  The two non-dust candidates both pay in "hard" assets and seize solBTC: e.g. B8FENB5 repays
  $1,207 USDC to receive ~$1.25 of real solBTC; 2xFbaXMJ repays ~40 SOL (~$4,340 real) to seize
  ~$2.78 of real solBTC. The only positive real pair is a $0.08 solBTC-debt/USDC-collateral dust
  obligation (few cents). The Kamino-linked bot already swept the profitable dust (obligation
  `CoYopT73...` drained Sep 27).
- A real liquidator cannot profit because seized collateral is priced by the same frozen oracle:
  solBTC collateral is credited at 958x its real value, so the ~3% oracle bonus is dwarfed by the
  real discount.

### Hidden bad debt (real terms)
- 60 obligations are underwater in real terms ($47,550 real debt vs $654 real collateral):
  almost all are 2022-vintage USDC debt collateralized by solBTC (oracle still marks it
  $260k+). USDC loan book: $42,566 debt vs $9,914 real collateral (~23% real coverage).
- This is not attacker-extractable today (on-chain they look healthy); it is a depositor
  solvency hole. The remaining **$16,246 USDC available in the vault is** — via the path below.

## 2. The live unprivileged extraction path: borrow against frozen-oracle solBTC collateral (~$155k)

Nobody has used it (see activity census); the components are all verified live:

1. **Oracle feeds are frozen but accepted.** All four legacy Pyth price accounts
   (Gnt27... USDC, H6ARH... SOL, GVXRSBj... solBTC, JBu1AL4... solETH) exist, last published
   **2024-08-29 / 2024-11-02**, `agg.status = 0` (not Trading). `refresh_reserve`
   (disc `02da8aeb`, permissionless) checks only `price >= 0` and confidence vs twap — **no
   publish-time/status check** — so refreshes keep succeeding and keep copying the stale prices.
   Proven live: the keeper/bot refreshed all 4 reserves successfully on 2026-09-27 (slot 451021492).
2. Market flags = 0 (deposits/borrows/repays enabled). Reserves permissionlessly refreshable.
3. Vault balances (slot 456079739): USDC **16,246.54**, SOL **1,274.172**, solETH **1.357014**,
   solBTC 4.956563 — all borrowable liquidity.
4. `borrow` (and deposit/depositCollateral) use the market cache at the current slot
   (panic "Reserve needs to be refreshed" otherwise) -> the whole sequence must be one tx
   (or same-slot bundle): `initObligation`, `initDepositAccount(solBTC)`, N x
   `refreshReserve`(until Full; <=1 week of accrual per iteration), `deposit(solBTC)`,
   `depositCollateral`, `borrow(USDC)`, `borrow(SOL)`, `borrow(solETH)`. All instructions are
   permissionless (owner only needs its own accounts; only PDAs are protocol accounts).
5. **Numbers.** Depositing ~**4.092 solBTC** (buy on DEX for ~**$223.5**; pool depth for
   4 solBTC is thin but the trade is ~$220) is sufficient collateral (at the frozen
   $52,326.9114/token) to borrow the whole USDC vault + whole SOL vault + whole solETH vault
   (health limit requires debt <= collateral/1.25):
   - USDC 16,246.54 -> receive $16,246.54
   - SOL 1,274.172 -> debt valued $151,928.86 oracle, receive ~$138,155 real
   - solETH 1.357014 -> debt valued $3,126.87 oracle, receive ~$402 real
   - total real received **~$154,785**, cost ~$223.5 + ~0.01 SOL fees/rent
   - **net extraction ~= $154,500**, then default (no repayment enforcement).
   (The solBTC vault itself is not worth draining: same oracle price on both sides.)

Confidence: **medium-high on mechanics** (code path + live state + successful Sep 27 refresh
txs verified), **not tx-simulated** (read-only constraint; no signed/sent tx, no local fork).
Residual risks: unknown runtime difference between deployed v0.2.0 binary and the v0.2.0
source used for the math (the binary contains "Reserve needs to be refreshed"/`c_ratio_ltv`
strings consistent with the source); refresh iterations must complete within compute budget
(<= ~12 refresh ix needed for a 15-day accrual gap); DEX liquidity for acquiring 4 solBTC.

## 3. Task B — program activity census

- 1,000 signatures of the Jet program listed (34 days of largest coverage; list spans
  **2026-07-07 .. 2026-09-27**). **No Jet activity after 2026-09-27 14:17 UTC** (checked fresh).
- Per-day histogram: Jul 7: 93, Jul 20: 214, Jul 21: 414, Jul 22: 17, Jul 28: 12, Aug 1: 12,
  Aug 2: 27, Aug 8: 3, Aug 25: 4, Sep 2: 4, Sep 3: 21, Sep 19: 18, Sep 27: 161.
- Classified txs (archival fetch, partial due to 5 req/min archival-gateway limit — see
  activity_census.json for per-tx rows and exact coverage): **refreshReserve** dominates;
  the newest burst (2026-09-27, 14:14–14:17, 161 sigs) is the keeper bot program
  `C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8` (fee payer `4VnBfBpw...`, integrates
  Kamino `KLend2g3cP`): it force-refreshes all 4 reserves, then repeatedly liquidates the
  same dust obligation `CoYopT73...` (USDC/USDC; 9 liquidate + withdraw + withdrawTokens
  txs) — i.e. cleanup of a dust position, not a user.
- A second signer `AZgsUBQpMa9DHuX5jpQKDNxNJ7BHgJHpkTaeAqr59cDB` performed plain
  `refreshReserve` iterations for the SOL reserve (Jul 21; no bot program). The big
  Jul 20–21 burst (628 sigs) is consistent with interest-accrual iteration loops by keepers
  (each refresh = 1 week of accrual).
- **Non-bot borrow/deposit transactions: none found in the classified set** (0 of them;
  all classified activity is refresh/liquidate/withdraw by the two keepers above). Nobody
  is currently exploiting the borrow path; the 2022-vintage borrowers are gone.
- Corroborating: only **12 obligations** have a cache timestamp >400M slots (the recent era) —
  all dust/touched by the bot except `8aAhuyRVPu...` (a 2022 position). No newly-created
  obligations with debt exist; 1,211 obligation accounts were never used (cache slot 0).
- Both the solBTC reserve `GqPX7JNR...` and solETH reserve `2X39AAQz...` are touched only by
  the bot's refreshReserve (and liquidate account lists) in the classified window; the lists
  are in activity_census.json/md.

## 4. Blockers / caveats
- Public Solana RPC prunes `getTransaction` history (~2 weeks); keyless archival sources are
  rate-limited (Tatum: 5 req/min) — activity classification coverage is partial (documented),
  but every listed signature's slot/time/err is captured, and the 30-day window is the
  priority of the ongoing fetch.
- Alchemy local key monthly cap exceeded; Dune API datapoint cap exceeded (both unusable).
- "Real prices" for solBTC/solETH are thin-market DEX prices (Jupiter v3, solBTC liquidity
  $509; solETH $46.3k) — indicative, low exit capacity.
- No end-to-end transaction simulation was performed (read-only), so the borrow-and-default
  path is inferred from source + live state + the keeper's successful same-primitive txs.

## 5. Files
- `analysis/obligations_full.json` — all 7,289 parsed obligations (+ derived values, oracle & real)
- `analysis/obligations_summary.json` / `.md` — aggregates, unhealthy lists, bonus metrics, dust
- `analysis/obligations_keys.json`, `analysis/raw_batches/` — raw fetch evidence
- `analysis/activity_signatures.json` — 1,000 signatures with slots/times
- `analysis/activity_census.json` / `.md` — per-tx classification + aggregates (partial coverage noted)
- `analysis/live_prices.json` — real prices with sources
- `analysis/*.py` — fetch/parse/compute scripts (public endpoints only; no secrets)
