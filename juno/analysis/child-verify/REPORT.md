# Child verification — C2-07 Juno governance capture: independent liquidity & state reproduction

Date: 2026-10-05 (snapshot ~16:00–17:25 UTC) · Chain: juno-1 + Osmosis · Status: **read-only; no transactions; no secrets**.
Scope: independently reproduce the parent's (i) juno-1 state, (ii) gov params via gRPC, (iii) ALL JUNO market
liquidity, (iv) CEX status. Own pulls only; parent numbers quoted for comparison.

## 1. juno-1 state (LCD: juno-api.polkachu.com = A, rest.cosmos.directory/juno = B)

| item | child pull (A) | parent | delta |
|---|---|---|---|
| block | 42,397,188 @ 16:00:14Z (B: 42,397,190) | — | — |
| bonded | 29,611,625.997463 JUNO | 29,611,617 | +9 |
| not bonded | 24,986,242.585849 JUNO | — | — |
| supply ujuno | 142,468,769.781520 JUNO | 142,468,455.54 | +314 (2 LCDs agree ±1) |
| community pool ujuno | 20,491,905.061243 JUNO | 20,491,827.30 | +77.8 |
| wasm codes params | code_upload_access=**Everybody**, instantiate_default=Everybody | same | ✅ |
| staking params | unbonding 2,419,200s = 28d; max_validators **25**; min commission 5% | 28d | ✅ |

CP deltas are pure inflation drift (CP accrues ≈2.6 JUNO/min); supply delta ≈ 2h. Both LCDs agree.
Community pool also holds ~11,515.79 (6-dec token) + 460.9 (18-dec token) + dust — DecCoin amounts are
base-unit-scaled (ujuno/1e6). Not material here.

## 2. Gov params (gRPC exec, saved verbatim)

`/tmp/opencode/grpcurl -max-time 25 -insecure -d '{}' juno-grpc.publicnode.com:443 cosmos.gov.v1.Query/Params` (exit 0):
quorum **0.334**, threshold **0.5**, veto **0.334**, voting_period **432000s** (5d), max_deposit 864000s,
min_deposit **5,000,000,000 ujuno = 5,000 JUNO**, min_initial_deposit_ratio **0.2**, expedited voting 86,400s /
threshold 0.667 / min deposit 1e10 ujuno, burn_vote_veto=true, min_deposit_ratio=0.01.
All parent gov-param claims reproduced exactly.

Live proposals (both VOTING_PERIOD): #378 "Recover frozen IBC client with Cronos" ends 2026-10-06 05:28:06Z,
yes=23,319,176.49 JUNO; #379 "Juno v31 Software Upgrade" ends 2026-10-06 10:02:50Z, yes=23,698,828.50 JUNO.
Quorum threshold = 0.334 × 29,611,626 = **9,890,283 JUNO**.

## 3. Liquidity enumeration (all endpoints listed in files)

| venue | method | JUNO pools | total JUNO | parent | delta |
|---|---|---|---|---|---|
| Osmosis GAMM | `/osmosis/gamm/v1beta1/pools` pag. (2,036 pools, 3 pages) | 47 | 1,768,867.2467 | 1,768,706 | +161 |
| Osmosis CL | `/osmosis/concentratedliquidity/v1beta1/pools` + bank balances/pool | 6 | 546,467.4176 | 546,400 | +67 |
| WYND (juno-1) | factory `juno16adshp…3u3s` `{"pairs":{"limit":100}}` + `{"pool":{}}` | 20/32 pairs | 2,430,155.8959 | ≈2,430,156 | ✅ exact |
| Loop Finance | factory `juno1p4dmvj…aspeak` | 10/24 pairs | 17,515.7298 | — | **missed** |
| White Whale | factory `juno14m9rd2…xrnx` | 8/14 pairs | 10,309.1326 | — | **missed** |
| "Juno DEX" (new Astroport v1 fork, code 5129, created block 39,381,297) | factory `juno1n5ettlq…elca` | 4 test | 13.17 | — | **missed (test-only)** |
| Junoswap | DefiLlama: deprecated, Juno TVL $0 | — | 0 | — | — |
| **TOTAL** | | | **4,773,328.60 JUNO ≈ $42,643** | ≈4.75M | +27,838 |

Largest pools (JUNO : counterpart): WYND JUNO/ATOM 1,372,607.73 : 7,061.30 ATOM; WYND JUNO/USDC
641,398.48 : 5,845.98 USDC; OSMO GAMM 498 JUNO/ATOM 1,191,615.24 : 6,069.61 ATOM; GAMM 497 JUNO/OSMO
572,480.72 : 143,121.57 OSMO; CL 1097 546,400.39 JUNO + 104,564.99 OSMO (others ~0/67). All parent pool
numbers reproduce to <0.03% (differences = swaps during the hour).
Denoms confirmed via chain-registry: ibc/C4CFF…=ATOM (ch-1), ibc/EAC38…=USDC (ch-224); Osmosis
ibc/46B448…=JUNO, ibc/27394F…=ATOM.

## 4. Cost curves (static, fee 0.3%, prices: JUNO $0.0089336, ATOM $1.78656, OSMO $0.036059, USDC $1.00)

Aggregate across priced CP pools ($34,544 counterpart-side value); buy split proportional to pool JUNO reserves:

| buy | JUNO | USD cost | avg $/JUNO | note |
|---|---|---|---|---|
| | 500k | $5,271 | $0.0105 | feasible |
| | 1M | $12,434 | $0.0124 | feasible |
| | 2M | $38,788 | $0.0194 | feasible |
| | 3.41M | $311,832 | $0.0915 | 90% of priced-pool JUNO |
| | 3.75M | $3,430,147 | $0.9150 | 99%; **100% cost → unbounded** |

Per major pool (buy 500k / 1M / 2M): WYND ATOM $7,250 / $33,959 / impossible (N≥reserve); GAMM 498
$7,863 / $56,762 / impossible; WYND USDC $20,733 / impossible; GAMM 497 $35,708 / impossible.

Sell proceeds (aggregate, proportional split): 1M → $7,195 ($0.0072); 5M → $19,598 ($0.0039);
**20,490,612 → $29,069 ($0.00142)**; 50M → $32,016 (asymptote = total priced counter-side ≈ $34.5k).
Paper value of 20.49M JUNO at spot = $183k; realistic DEX exit ≈ **$29k** and only under a static-pool
assumption. Single-pool examples for the 20.49M dump: WYND ATOM $11,788; GAMM 498 $10,217; WYND USDC $5,651;
GAMM 497 $5,005.

**Max JUNO purchasable on-market:** ceiling is total JUNO in every pool = **4,773,329 JUNO** (of which
4,226,859 in constant-product pools, 546,467 in CL); approaching 100% is unbounded in cost. Buying 15M
JUNO is **impossible** — total WYND+Osmosis alone (parent's venues) = 4,745,491 JUNO < 15M, and even the
complete universe is 3.1× short. It is also impossible to buy the 9,890,283 JUNO needed for quorum
(every JUNO on-market ≈48% of that).

## 5. CEX check

- CoinGecko `/coins/juno-network/tickers`: **3 tickers, all Osmosis**, 24h vol **$663.21** (parent ~$668 ✅); simple
  price $0.00896663, mcap $711,732. No CEX tickers tracked.
- CoinLore: only Osmosis (96.9% of volume) + Kraken (JUNO/USD $14/day, JUNO/EUR $9/day, data 2026-09-17..19).
- Kraken: notice Aug 2026 — deposits disabled 2026-09-11, withdrawals disabled 2026-12-10, liquidation
  2026-12-14..18. Crypto.com: delisted, withdrawals only until 2026-10-14 03:00 UTC. bunq: last trade 2026-09-11.
- api.kraken.com was unreachable from this sandbox (DNS); CEX conclusion relies on Kraken's published notice +
  CoinLore. No untracked CEX found. Treat any Kraken residual as non-executable depth (~$23/day).

## VERDICT

**(a) Reproduction:** Parent's liquidity numbers reproduce. WYND exact (2,430,155.90 vs ≈2,430,156); Osmosis GAMM
+161, CL +67 (live swaps); juno-1 state within inflation drift (bonded +9, supply +314, CP +77.8 JUNO);
gov params + wasm params exact. ✅

**(b) On-market acquisition of 15M JUNO: impossible.** Total JUNO liquidity across every known venue is
~4.77M JUNO (~$42.6k at spot); buying 90% of the priced pools (~3.41M JUNO) already costs ~$312k at
$0.0915/JUNO (10× spot), and 15M cannot be acquired at any price. The market also cannot supply the
9.89M-JUNO quorum threshold (total market = 48% of it). Even a captured 20.49M-JUNO community pool could
be sold on-market for only ~$29k under static-pool assumptions (paper $183k).

**(c) Venues the parent missed:** Loop Finance (17,515.73 JUNO), White Whale (10,309.13 JUNO), the new
community Astroport-v1 "Juno DEX" (13.17 JUNO, test tokens only), plus Junoswap confirmed dead ($0, migrated
to WYND). Missed total ≈27,838 JUNO ≈ $249 — 0.58% of market and not verdict-changing.

**Confidence:** high on all reproduced numbers and the 15M conclusion; medium on exhaustiveness (old Junoswap
pools not enumerated, CL tick math approximated, proportional-split approximation, fees assumed 0.3%,
snapshot at one block — pools move). What would change the verdict: a large new pool/CEX appearing after
2026-10-05, or protocol-owned liquidity outside these factories.

## Files

`state.json` (chain state, proposals, params), `gov_params.json` (verbatim gRPC), `osmosis_juno_pools.json`,
`wynd_juno_pools.json` (+`wynd_raw_pools.json`), `loop_juno_pools.json`, `whitewhale_juno_pools.json`,
`cost_curve.json`, `tickers.json`; scripts `osmosis_enum.py`, `wynd_enum.py`, `other_dex_enum.py`,
`cost_curve.py`; raw pulls in `raw/` (per-endpoint JSON, both LCDs).
