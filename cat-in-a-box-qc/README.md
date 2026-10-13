# Cat in a Box (Ethereum) — QC-3 adversarial re-audit

**Date:** 2026-10-13 · **Chain:** Ethereum mainnet · **Status:** read-only; fork PoCs;
no mainnet transactions; no secrets.
**Prior closure:** E-U $0 (high) — *triage lead L2-Triage-A #22, triage row `l2-triage-a/README.md` row 22
($214,034; 0x7f0a0c71… + 0x24146d…)* — deep dive at `cat-in-a-box` CI branch, block 26,176,576.
**This QC re-audit assumed the closure was wrong and attacked it.** Verdict below.

---

## 1. Verdict

| | |
|---|---|
| **Verdict** | **closure stands** (E-U today ≤ $0.08 gross, negative net of gas) |
| **Confidence** | **high** on “no material keyless extraction now”; **high** on the conditional preconditions |
| **Fresh-attacker E-U (live)** | **~$0** (best measurable: +0.0000312 stETH ≈ $0.08 gross; path gas ≈2.17M per the prior suite on the same route) |
| **Overhang (latent)** | **302.0313 stETH redeemable debt; gross ceiling 301.55 stETH ≈ $766.7k** — needs ~315.7 boxETH acquired at ≤0.9568 stETH (30,000× the profitably-priced depth that exists today) |
| **New vs prior** | a **third venue the prior missed** (Trader Joe LB pair `0x184d768d…`) briefly (until ~block 26.13M) sold boxETH *below* redemption break-even — a keyless bot extracted **+0.00459 WETH gross (~$11.7)** on 2026-10-11. That venue is now drained/swept (0.123 boxETH residual). |

**One-line:** every fresh keyless route was tried — full sweep of all live venues with the
globally optimal redemption order, a new self-liquidate cycle, vault/share and third-party-vault
routes, unguarded-function and bytecode enumeration — and today the entire market offers ≤$0.08 of
gross extraction; the $750k+ unlock needs boxETH at ≤0.9568 stETH/unit, which no live venue
provides (9.76 boxETH of pool depth, all priced ≥0.9947 at the margin and worse on impact).

---

## 2. Prior evidence recovered (mandate item 1)

- CI branch `cat-in-a-box` of `kingmariano/ca-zombie-ci` (README + summary.json + analysis/ + poc/ + ci-out/).
  Prior result: E-U $0; gross cap 302.03 stETH; custody 515.78 stETH ($1.31M) incl. the v1.1 CDP
  (`0x6ffd098e…`, 427.78 stETH) + feeSplitStaking; 11/11 fork tests passed (run 38254742771).
- Triage row: `l2-triage-a/README.md` row 22 — “Cat in a Box | Ethereum | LIVE-FUNDED | $214,034 |
  ETH 0x7f0a0c71…, 0x24146d1b…”. The prior deep dive already corrected the triage (missing v1.1 CDP).
- Re-verified live at block **26,182,236** (2026-10-13): state unchanged; **zero transactions** on all
  six core contracts since the prior block 26,176,576. Roles unchanged (fresh `hasRole` calls):
  PSM CONVERTER = Safe `0x98e6475C…` + deployer EOA `0x56C40ade…`; feeSplit CONVERTER = Safe +
  deployer + 2 owner EOAs; boxETH ADMIN = only the two CDPs; attacker holds no role.

---

## 3. Fresh attacker-path hunt (mandate item 2)

### 3.1 Full contract enumeration — no unguarded function found
Enumerated **all 12 contract creations** of deployer `0x56C40ade…` (Etherscan txlist, nonce 0–170):

| Contract | Note |
|---|---|
| boxsteth, feeSplitToken, psmstart, feeSplitStaking, catinaboxcdp (v1), catinaboxcdp1point1 | known core (sources reviewed) |
| `0x1e63d4e8…` catinaboxcdp **CDP0** | abandoned; 223 wei stETH; debt 0 — no value |
| `0xe12bceb3…, 0x797ed331…, 0x39980c30…, 0x646f46cd…, 0x932705a4…` | **MortgageFi** token contracts (unrelated project); $26.31 USDC + 0.001699 WBTC (~$105) ≈ $132 total |

**Deployed-bytecode vs source diff (adversarial):** extracted the real dispatcher selectors from the
runtime bytecode (`DUP1 PUSH4 <sel> EQ PUSH2 JUMPI` pattern) for all six core contracts and diffed
against the verified sources — **every selector maps to a source function**; the only extras are the
auto-generated `ADMIN_ROLE()/CONVERTER_ROLE()/DEFAULT_ADMIN_ROLE()` getters. No hidden function,
no unguarded mint/init, no sweep. Multi-venue and third-party contracts (`perpetualTokenOffering`,
`GarageExperiment1`, `BunniHub`, flash-bot contracts `0x073197fa…`/`0xf411fca5…`) hold ≤0.2 boxETH each.

### 3.2 boxETH acquisition census — all sources enumerated
Full `Transfer` history of boxETH (7,350 events): **204 net-positive holders**, supply 304.135.
Split: vault 248.31 · UniV3 pools 9.758 · feeSplitStaking 1.469 · PSM 0.662 · **EOAs ~34.4** ·
misc contracts ~0.46 (incl. **Trader Joe LB pair 0.123**). No other DEX venues exist:
UniV3 factory (all fee tiers × WETH/stETH/wstETH/USDC/USDT/DAI) → only the 3 known pools (+1 dead);
Sushi V2/V3 → none; Curve → none; **Balancer Vault holds 0 boxETH**. Aggregator history
(1inch/Paraswap/CoW) shows historical routing but the last on-chain CoW boxETH trade was ≈block 24.5M.

**New venue found (prior gap): `0x184d768d…` = Trader Joe Liquidity Book pair boxETH/WETH**
(selectors `getBin/addLiquidity/swapCallback/tokenA/B`, tickSpacing 50, factory `0xEb6625D6…`).
It routed boxETH via 1inch/Paraswap/CoW for years and was still live until ~block 26.13M:
at **block 26,066,190** a keyless bot (via `0x8f10b468…`/`0x22a57ff173…`) bought **2.039 boxETH for
2.027 WETH (0.9941 WETH/boxETH — below the redemption break-even)**, redeemed it through
`stabilisePeg` (2.03186 stETH, 0.00731 fee) and sold the stETH for 2.03169 WETH → **+0.00459 WETH
gross (~$11.7)**. The pair was then wound down by the team (2.97 + 0.098 boxETH swept to the Safe at
blocks 26,126,975–26,129,675, then 3.14 boxETH onward to the deployer EOA); residual = **0.1228 boxETH
+ 0.2957 WETH (dust)**. This validates the *conditional* path as real (punctuated, tiny, arbitrated
within blocks) but does not create a live extraction today.

### 3.3 Fork PoC counter-tests — 10/10 pass (fresh suite, not the prior tests)
`poc/test/QcCatInABox.t.sol` — run on CI (`cat-in-a-box-qc` branch, workflow `poc.yml`), read-only:

| Test | Result |
|---|---|
| QC1 roles/state | CONVERTER stays Safe+3 EOAs; `PSM.trade`, `synthToFeeToken`, `feeSplit.trade` revert for outsiders; boxETH mint = CDPs only |
| **QC2 full pool sweep, globally-optimal redemption** (`debt/4`-cap loop, cheapest marginal fee first) | **0.01 WETH buy → +0.0000312 stETH (+$0.08) — the sweep max**; 0.1 → −0.000647; 0.5 → −0.0378; 1 → −0.1501; 3 → −1.0699; 5 → −2.4125. Net of gas: negative at every size (path gas ≈2.17M measured by the prior suite on the same route) |
| QC2b wstETH 1% pool sweep | 0.5 stETH → 0.4444; 2 stETH → 1.3612 — loss |
| QC2c both pools combined | 2.0 spent → 1.6553 — loss |
| **QC3 NEW ×prior-untested: mint v1 (no fee) → SELF-LIQUIDATE (collateral→PSM, boxETH kept) → redeem against others** | PSM gained 2.940 stETH; **walk-away −0.0150 stETH** — converts own collateral into boxETH at 1:1, worse than the market; no value creation |
| QC4 boxFEE vault | deposit 1 boxETH → 1 share → redeem 0.10666; mint 1 share costs 1 boxETH → redeem 0.10704; `previewWithdraw(1 boxETH)` = 9.3425 shares — every entry loses ~89% |
| QC5 secondary pools | boxFEE/WETH pools hold 662 wei / 234e9 wei / 0.0044 boxFEE (dust; liquidity 0 / 0 / 6e14); dead boxETH/WETH 1% pool = 4 wei |
| QC6 3rd-party PTO (holds 9.11 boxETH) | `depositCheapeth(0.1 ETH)` → 0.08955 boxETH (10% haircut); shares minted at NAV — boxETH cannot be sourced cheap here |
| QC7 gross overhang | with `vm.deal`ed boxETH: **301.5529 stETH** extracted; residual debt 0.00296 + 0.00007 — ceiling re-proven |
| QC8 quantification | total redeemable debt **302.0313 stETH**; debt at marginal fee <0.5% = **6.6795 stETH**; live pool depth **9.7582 boxETH**; pool005 marginal **0.99472 WETH/boxETH** |

---

## 4. Conditional paths quantified (mandate item 3)

Redemption math (`stabilisePeg`): for victim (D, P), cost to redeem x = x + 0.1·c·ln(P/(P−x)),
c = P−D. Cherry-picking victims by current marginal fee f1 = 0.1·(1−D/P):

| Victim | debt stETH | marg fee | full-drain avg fee |
|---|---|---|---|
| 0xaD46… | 0.168 | 0.19% | 0.77% |
| 0xbbA3… | 0.167 | 0.25% | 0.95% |
| 0x5Ac0… | 6.096 | 0.47% | 1.52% |
| 0xB1da… | 77.84 | 0.97% | 2.51% |
| PTO 0xCdD7… | 65.40 | 1.10% | 2.72% |
| 0x83C8… | 106.53 | 4.42% | 6.47% |
| **Σ (45 victims)** | **302.0313** | — | **13.6463 total fee** |

- **Full-drain blended break-even = 0.956771 stETH per boxETH** (315.6776 boxETH in → 302.0313 stETH out).
- **Upper-bound profit if boxETH could be bought at a flat price p (unlimited depth):**

| p (stETH/boxETH) | stETH out | boxETH cost | attacker profit | ≈USD |
|---|---|---|---|---|
| 0.9947 (current pool marginal) | 1.154 | 1.159 | **+0.0014** | **$3.5** |
| 0.99 | 7.053 | 7.109 | +0.0154 | $39 |
| 0.98 | 84.58 | 85.75 | +0.546 | $1,389 |
| 0.97 | 113.21 | 115.09 | +1.569 | $3,987 |
| 0.9568 (full-drain break-even) | 142.44 | 145.47 | +3.255 | $8,274 |
| 0.95 | 180.59 | 185.48 | +4.385 | $11,146 |
| 0.90 | 302.03 | 315.68 | +17.92 | $45,556 |
| 0.80 | 302.03 | 315.68 | +49.49 | $125,802 |
| 0.50 | 302.03 | 315.68 | +144.19 | $366,537 |
| →0 (free) | 302.03 | 315.68 | +302.03 | gross ceiling $767,950 |

- **The realisable number is far below the flat-price bound** because the only live pools are tiny:
  measured global optimum from the actual UniV3 curves is **+0.0000312 stETH (~$0.08)** for a
  0.01 WETH buy; by 0.05 WETH the round trip is already negative. The pools hold **9.758 boxETH**
  total and price it at 0.9947 (marginal) / 1.078–1.923 (average, 0.5–5 WETH).
- **Exact precondition to flip (what a watcher needs to see):**
  1. a venue/market selling boxETH **with depth** at ≤ ~0.996 (any ≥$1k extraction needs several
     stETH of depth below break-even — e.g. ~$1.4k at 0.98, ~$8.3k at 0.9568, ~$45k at 0.90);
  2. or a **large holder dump** into the thin pools (someone else takes the loss; the arb extracts
     only the residual spread, bounded by what stays in the pool);
  3. or **boxFEE shares** ever trading below 0.1016 boxETH-equivalent (0.9568 × NAV 0.10627) —
     currently no market at all (all 3 pools dust; biggest holders are EOAs + the staker contract);
  4. or a **new/revived venue** (the trader-Joe LB pair is the template: it alone provided the
     sub-par window the bot used; it is now emptied).
  The current gap: **~315.7 boxETH needed at ≤0.9568 vs ~0.01 boxETH profitably priced today**
  (≈30,000× depth gap); all remaining supply is locked behind EOAs/vault shares that have no market.
- **Mint-it-yourself does not help:** minting boxETH is collateralised 1:1 (v1, no fee) or 0.5% dearer
  (v1.1) — a mint→redeem cycle returns at most your own collateral minus fee (QC3 −0.015; prior T4
  −0.044/−0.074); self-`liquidate` donates your collateral to the PSM without burning boxETH (QC3).

---

## 5. Residual risk register (unchanged category, updated venues)

1. **Redemption overhang is live and permissionless** — 302 stETH vs 9.76 boxETH of real depth.
   Any venue/transfer that puts boxETH below ~0.99 with depth converts into extraction within blocks
   (observed: +$11.7 gross at block 26,066,190). Include the LB pair `0x184d768d…` and any new
   boxETH pair in monitoring; the prior DefiLlama-adapter gap (v1.1 CDP + feeSplitStaking) still stands.
2. **Privileged keys** (Safe 3/5, deployer EOA, 2 owner EOAs) can redeem PSM+feeSplit stETH at par
   (~$10.9k, P-category) and hold boxETH (deployer received 3.14 boxETH on 2026-10-12). Any key
   compromise is E-O, not keyless; not counted here. The Safe/deployer keys were not found in the
   local weak-key datasets.
3. **CoW production order book could not be verified from this environment** (api.cow.fi returns 403
   for the runner IP; the barn endpoint is a separate environment and held no boxETH orders). On-chain
   history shows no CoW boxETH trade since ≈block 24.5M, so the odds of a resting sub-par order are
   low but nonzero — **documented as the single residual check gate** (needs a browser/API key).
4. boxFEE vault mispricing and boxETH `burnFrom` bug: holder harms/griefing only (re-verified; the
   `burnFrom` allowance is never decremented but every burn is from `msg.sender`'s own balance).

---

## 6. Repro

```
bash /home/heisenberg/CA/ci/ci-run.sh cat-in-a-box-qc     # CI fork run (poc.yml, branch cat-in-a-box-qc)
# or locally:
cd cat-in-a-box-qc/poc && FORK_RPC_URL=<eth-rpc> forge test -vv     # 10/10
```

CI run (this re-audit): see `ci-log.txt` / `ci-artifacts/` in this folder (URL appended below once the
run completes: **RUN_URL**).

Artifacts: `poc/test/QcCatInABox.t.sol` (this suite), `ci/run.sh` (state dump), `ci-out/live-state.txt`,
`local-test-log.txt` (local 10/10), `analysis/` (holder census, venue list, conditional analysis notes).

## 7. Methodology / caveats

- Read-only: pinned-block `eth_call`/`eth_getLogs`, Etherscan V2, full boxETH/boxFEE transfer census,
  dispatcher-selector extraction from deployed bytecode, fork tests on an archival node.
- USD figures at stETH $2,542.62 (2026-10-12 DefiLlama, as prior); ETH/price moves scale them.
- The conditional table is an **upper bound** (flat-price, unlimited-depth assumption); the measured
  fork numbers (QC2/2b/2c) are the realisable ones.
- No mainnet transaction was signed or sent; no secrets printed or stored.
