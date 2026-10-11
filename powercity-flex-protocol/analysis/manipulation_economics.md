# Oracle-manipulation economics — cost vs prize (the decisive gate)

Mechanic (fork-verified, see `poc/test/FlexPoC.t.sol`): because `fetchPrice()` is permissionless
and the TWAP window is `(cumulative_now − cumulative_old)/(t_now − t_old)` with rolls gated at
420 s, an attacker who (1) rolls the window, (2) crashes the 4 pairs and (3) holds the crash for
≥ 421 s gets a crashed oracle price and can liquidate / redeem at it.

**All components must be crashed**: the blend is `(0.65·HEX/WPLS_V1 + 0.35·HEX/WPLS_V2)·WPLS_USD`.
The cheapest leg is the two HEX/WPLS pools (combined ~250.7 M HEX ≈ $622k of reserves).

## Cost to crash the two HEX/WPLS pools (live reserves; sell HEX, receive WPLS)

| crash factor f | HEX dumped | $ dumped @0.0024815 | WPLS recovered | $ recovered |
|---|---|---|---|---|
| 0.50 (−50 %) | 104 M | $0.26 M | 18.5 B | $181 k |
| 0.30 (−70 %) | 207 M | $0.51 M | 28.6 B | $280 k |
| 0.20 (−80 %) | 310 M | $0.77 M | 35.0 B | $342 k |
| 0.12 (−88 %) | 473 M | $1.17 M | 41.3 B | $404 k |
| 0.10 (−90 %) | 542 M | $1.35 M | 43.3 B | $423 k |
| 0.082 (−91.8 %) | 625 M | $1.55 M | 45.2 B | $441 k |

The dumped HEX is recoverable only by buying it back — but while the crash is held, arbitrageurs
buy the ~12× discounted HEX. Every dollar of arbitrage inflow raises the price and is value the
attacker cannot recover. Holding a 12× dislocation for 7 minutes on a public chain is the
fundamental blocker: the attacker must out-sell arbitrageurs for 421 s with finite capital.

## Prize at each crash depth

| crash f | liquidatable / redeemable set | gross capture | notes |
|---|---|---|---|
| 0.50 | nothing liquidatable (no trove below TCR≈640 %) | $0 | — |
| 0.30 | nothing (all ICR > TCR≈385 %) | $0 | — |
| 0.12 | redemption only: 20,000 HEXDC → ~$137 k (after ~20.5 % fee) | +$137 k | needs 20k HEXDC |
| 0.10 | redemption only: ~$164 k | +$164 k | needs 20k HEXDC |
| **0.082** | **trove #9 liquidation (SP offset): SP receives 90.39 M HEX = $224 k** | **+$224 k** (attacker share ≈ $162 k + $1.2 k gas comp) | **narrow band f∈(0.0780, 0.0858)** — outside it: ICR≤100 % → pure redistribution (SP gets $0), or ICR≥110 % → trove #9 is above TCR → "nothing to liquidate" (fork-verified) |
| 0.05 | redemption only, small eligible set | ≤ $50 k | — |

Notes:
- In recovery mode (any crash beyond −11.7 %), the liquidatable set is only troves with
  `ICR < TCR` (below system average) or `100 % < ICR < 110 %`. All large troves except #9 are
  above the system average and can never be liquidated; #9 is *marginally above* TCR, so only
  the (100 %, 110 %) band works — a ~0.8 pp-wide crash window.
- Redeeming needs HEXDC. On-chain liquidity is 15,550.86 HEXDC in a thin pool: buying 10,000
  costs ~11.7 M HEX ($29 k, avg $2.90/HEXDC), buying 14,000 costs ~58.6 M HEX ($145 k,
  avg $10.4). Realistic on-market acquisition ≈ 10,000 HEXDC → net redemption profit ≈ $30–45 k.
- Fork-verified captures: trove #9 → SP gain 90.39 M HEX for 17,055.92 HEXDC burned;
  redemption 20,000 HEXDC → 50.78 M HEX (6.11× the live-price payout).

## Verdict on the manipulation path

- Mechanically real (fork-proven), but the attacker must dump **$1.2–1.6 M of HEX and hold it
  for 421 s** while arbitrageurs buy the discount. Break-even needs arbitrage take < ~20–25 %
  of the dumped discount; a 12× dislocation on PulseChain will not survive 7 minutes with only
  ~$1.06 M of value at stake. **Net expected profit: negative / unproven.** Not counted as live E-U.
- Additional practical blockers: only ~15.5 k HEXDC on-market; the trove-#9 band is ~0.8 pp wide;
  the attacker's own capital must be ~$1.5 M+ for the dump and the 7-minute defence.
