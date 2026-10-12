# ErgoDEX v1 (Ergo) — Phase-2 deep dive: how much can an external unprivileged attacker extract?

**Date:** 2026-10-12 · **Chain:** Ergo (mainnet) · **Status:** read-only; **no transactions sent**; proof by
chain-native script evaluation (public node `executeWithContext`) + sigma-rust decompilation of the deployed
ergoTree. No keys, no secrets, no fork needed (eUTxO scripts are pure functions of the transaction context).

**Triage row:** `l2-triage-c` → ErgoDEX, `LIVE-FUNDED`, $405,929, P2S `5vSUZRZb…SCqM`, 285 unspent boxes, ~632K ERG.

---

## 1. TL;DR

| # | Target (ErgoDEX v1) | Live custody now | E-U (external, unprivileged) | Why closed | Latent / residual |
|---|---|---|---|---|---|
| 1 | **n2t AMM pools** — P2S `5vSUZRZb…SCqM` (632,482.6 ERG + tokens, **267 pools**, 285 boxes) | **$410,997** | **$0** | Pool contract invariants are sound: successor must keep the pool NFT/script/fee and satisfy the constant-product swap bound, the proportional-mint deposit bound, or the proportional-burn redemption bound. Verified by decompilation **and** 10 chain-native evaluations (drain/over-redeem/over-mint all evaluate **false**). | Long-overflow path needs ≥ ~9.25M ERG input for fee=997 (unprofitable, see §8); pools with fee=1 are frozen; market-order MEV on parked orders |
| 2 | **t2t AMM pools** — P2S `3gb1RZuc…` (2.79 ERG + tokens, 262 pools, 293 boxes) | **$9,898** | **$0** | Same contract family; decompiled tree shows identical swap/deposit/redeem bounds (X/Y are tokens; `successor.value ≥ SELF.value`). Unlike n2t it has no successor token-count check, but no live t2t box carries extra tokens (all 262 pools have exactly 4) | same as above |
| 3 | Token locks `XqM6yyAm…` (227 lock boxes, 102 token entries) | **$0.20** | **$0** | `sigmaProp(Pk && validAction)`: Pk in R5 + deadline in R4 — owner-only relock/withdraw | none material |
| 4 | LQ-mining pools `59vY1yth…` / `2JowFgqd…` (39 boxes) | **$6.36** | **$0** | farm accounting (LP per staking bundle; reward tokens) | none material |
| 5 | 18 anomalous boxes at the n2t P2S (326.4 ERG) | $106 | **$0** | script evaluation **errors** (`SELF.tokens(2)` out of bounds / missing R4) ⇒ unspendable | none — stuck (S) |

### **Total live extractable by an external unprivileged attacker right now: $0 (confidence: high).**
Total value sitting in ErgoDEX v1 contracts: **≈ $420,902** — live, actively traded AMM liquidity
(LP-holder redeemable = H-O), not zombie money. Re-verified live at Ergo height **1,892,615**
(explorer snapshot 2026-10-12 00:40 UTC; ERG = $0.3266, DefiLlama).

**Live value vs triage:** triage $405,929 → now **$410,997** at the same P2S address (ERG price moved
$0.3225→$0.3266; balance 632,553→632,483 ERG; same 285 boxes). No new value appeared; nothing was drained.

---

## 2. What ErgoDEX v1 on Ergo is (and what the triage got wrong)

ErgoDEX v1 (Spectrum Finance) is an eUTxO AMM. Every pool is **one box** guarded by the *Pool* script
(`propositionBytes` = the 412-byte ergoTree). A pool box holds:

| position | content |
|---|---|
| `value` (nanoErg) | X reserve = ERG |
| `tokens(0)` | pool NFT, amount 1 (identity) |
| `tokens(1)` | LP token, amount = *unsold* supply (`InitiallyLockedLP = 2^63−1` minus circulating/burned) |
| `tokens(2)` | Y reserve = paired token |
| `R4` | `feeNum` (Int; fee = 1 − feeNum/1000) |

The **user order contracts** (SwapSell/SwapBuy/Deposit/Redeem) only guard *user* boxes; they are optional.
The Pool script is self-sufficient: **anyone** may spend a pool box directly as long as OUTPUTS(0) is a valid
successor and the reserve deltas satisfy one of the three bounds. That is the entire attack surface.

**Triage correction (important):** the triage listed ErgoDEX as dead ("deadUrl"). The *domain/frontend* is
dead, but the **contracts are alive and actively arbitraged**: 47 of the 285 n2t pool boxes were recreated in
the last 24 h (e.g., the 115,535 ERG SigUSD pool box ~2 h before this snapshot; the 251,397 ERG RSN pool
~1.4 d), 45 more within 7 days; t2t: 25 boxes in 7 days. The $410K is functioning AMM liquidity —
which is exactly why the pools' marginal prices match external market prices (see §7, arbitrage check).

---

## 3. Target set — every ErgoDEX v1 contract family found (with live value)

| contract | P2S address | live boxes | live value |
|---|---|---|---|
| n2t Pool (`AMMContracts.N2TCFMMContracts.pool` = SDK `PoolSample`) | `5vSUZRZb…SCqM` | 285 (267 pools + 18 anomalies) | **$410,997.12** |
| t2t Pool (`AMMContracts.T2TCFMMContracts.pool` = SDK `t2tTemplates.PoolSample`) | `3gb1RZuc…` | 293 (262 pools + 11 anomalies) | **$9,898.36** |
| TokenLock (`lockingTemplates.TokenLockSample`) | `XqM6yyAm…` | 227 | $0.20 |
| LQ-mining unmanaged pool (SDK `lqmining.pool()`) | `59vY1yth…` | 2 | ~$0.00 |
| LQ-mining managed pool (SDK `lqmining.managedPool()`) | `2JowFgqd…` | 37 | $6.36 |
| n2dexyGOLD/USD pool template (SDK history, "TODO: update according mainnet data") | `3W5ZTNTW…` | **0** | $0 (template never deployed/emptied) |

Not enumerable without the (dead) project indexer, listed as residual in §8: parked order boxes
(user funds, per-order parameterized addresses), legacy `PoolBoot` bootstrap boxes and the parameterized
`arbPool` template (no evidence of live value; all discovered variants either have 0 boxes or hold dust).

---

## 4. The contract, exactly — deployed tree == audited source (byte-level)

1. **Address → ergoTree.** Base58-decode of `5vSUZRZb…SCqM` gives prefix `0x03` (mainnet P2S), valid
   blake2b-256 checksum, **412-byte ergoTree** (`1999030f…730e`; 15 segregated constants:
   `0,1,1,2,2, 2^63−1,2^63−1, 0L, 1000, 0,0, 3, 0L,0L, 10000000`).
2. **Byte-exact provenance.** The tree equals, byte for byte:
   * `spectrum-finance/ergo-dex-backend` → `AMMContracts.scala` `N2TCFMMContracts.pool` (the canonical
     production tree), **and** `spectrum-finance/ergo-dex-sdk-js` → `n2tTemplates.PoolSample`
     (the tree the SDK uses to *find* live pools). Both comparisons verified in this repo
     (`analysis/ergo_tree.hex`, `analysis/pool_n2t_address.txt`).
3. **Decompilation.** The tree was parsed with `ergo-lib` 0.28 (sigma-rust, locally built; see
   `analysis/deployed_pool_debug.txt`, `analysis/deployed_pool_pretty_resolved.txt`) and diffed against the
   node-compiled master source `contracts/amm/cfmm/v1/n2t/Pool.sc` (== backend `sources/n2tContracts.scala`
   `pool`). The only differences are compiler-version artefacts (one extra ValDef holding the constant 1000,
   constant de-duplication, ValId renumbering) — the logic is identical, and the top-level `AND` chain
   (incl. `successor.value > MinStorageRent` as the last conjunct) was verified in the parsed tree.
4. **The audited script (deployed semantics):**

```
successor = OUTPUTS(0);  feeNum0 = SELF.R4[Int].get;  feeNum1 = successor.R4[Int].get
poolNFT/reservedLP/tokenY at tokens(0/1/2) of SELF and successor
supplyLP0 = 2^63-1 - reservedLP0.amount ;  deltaSupplyLP = supplyLP1 - supplyLP0
dX = successor.value - SELF.value ;  dY = successor.tokens(2).amount - SELF.tokens(2).amount

validSuccessorScript = successor.propBytes == SELF.propBytes
preservedFeeConfig   = feeNum1 == feeNum0
preservedPoolNFT     = successor.tokens(0) == SELF.tokens(0)          // full tuple (id, amount=1)
validLP / validY     = successor LP-id / Y-id unchanged ; successor.tokens.size == 3
validStorageRent     = successor.value > 10_000_000

validSwap   = if dX > 0 then Y0*dX*feeNum0 >= -dY*(X0*1000 + dX*feeNum0)
                        else    X0*dY*feeNum0 >= -dX*(Y0*1000 + dY*feeNum0)
validDeposit= deltaSupplyLP <= min(dX*supplyLP0/X0, dY*supplyLP0/Y0)
validRedeem = dX*supplyLP0 >= deltaSupplyLP*X0 && dY*supplyLP0 >= deltaSupplyLP*Y0
validAction = if deltaSupplyLP == 0 then validSwap
              else if dX > 0 && dY > 0 then validDeposit else validRedeem

sigmaProp( validSuccessorScript && preservedFeeConfig && preservedPoolNFT && validLP && validY
        && noMoreTokens && validAction && validStorageRent )
```

**Why this is closed to an unprivileged attacker** (case analysis, all multiplications in `BigInt` except
the noted Long term):
* `deltaSupplyLP == 0` ⇒ swap only. `dX>0` branch bounds the Y taken by the standard constant-product-with-fee
  bound (`-dY ≤ Y0·dX·fee/(X0·1000 + dX·fee)`); `dX≤0` branch is the symmetric bound. Removing **both**
  reserves is impossible: for `dX<0,dY<0` the condition reduces to `|dY|·fee·(|dX|−X0) ≥ |dX|·Y0·1000`,
  and `|dX| ≤ X0` makes the LHS ≤ 0 < RHS. Removing one side with zero input is likewise impossible.
* `deltaSupplyLP > 0` (LP flows **out** of the pool): both branches require reserves to be *added*
  (`dX ≥ dS·X0/S0 > 0` and `dY ≥ dS·Y0/S0 > 0` for the redemption branch — but then the action would have
  been classified as deposit; the deposit branch caps `dS` by the proportional mint bound). Free LP: impossible.
* `deltaSupplyLP < 0` (LP burned): reserves may only be **removed** up to the burned LP's proportional share
  (`|dR|·S0 ≤ |dS|·R0`). Adding reserves while burning LP is allowed (conservative donation).
* Structural: successor must keep the same script, the same NFT (full tuple), the same fee, exactly 3 tokens,
  LP/Y ids, and value > 0.01 ERG. SELF's own token ids cannot be forged (Ergo tokens are conserved; a token id
  is the first input box id of its minting tx). An attacker cannot mint more LP: the LP id is fixed at pool
  creation.
* Consequence: an attacker may interact **directly** with the pool (no order box, no DexFee) but only at the
  pool's own invariant price — that is a fee saving for the attacker, not extraction of pool value.

---

## 5. Live-state assessment (Ergo height 1,892,615; explorer snapshot 2026-10-12 00:40 UTC)

* **n2t P2S** `5vSUZRZb…SCqM`: `balance/total` = **632,482,610,969,189 nanoErg** + **755 token entries**;
  **285 unspent boxes** (box-value sum matches the balance exactly). Classification:
  * **267 pools** = 3 tokens, `tokens(0).amount == 1`, R4 present → **632,156.19 ERG** + token reserves;
  * 18 anomalies → 326.42 ERG (see §5.3);
  * `feeNum` (R4) distribution: 997×107, 990×78, 970×21, 995×14, 996×8, 958×6, 999×5, 950×4, 931×3, 980×3,
    900/981/985/993/998×2, 850, 862, 929, 947, 954, 965, 590, 500×2, 310, 99, **1×3**; **no R4 ×14** (stuck).
* **t2t P2S** `3gb1RZuc…`: 2,794,488,673 nanoErg (2.79 ERG — storage only) + 695 token entries, 293 boxes
  (262 pools; 11 anomalies → 0.019 ERG stuck).
* **Token locks** `XqM6yyAm…`: 227 boxes, 0.6201 ERG + 102 token entries (all ~$0 priced).
* **LQ-mining** `59vY1yth…` 2 boxes; `2JowFgqd…` 37 boxes, 1.0186 ERG + Bober tokens $6.03.
* **Activity:** 47 n2t pool boxes recreated <24 h, 45 <7 d, 41 <30 d, 82 >1 y — the pools are live.

### 5.1 Valuation (DefiLlama prices at 2026-10-12 00:40 UTC; ERG $0.3266)

| side | amount | USD |
|---|---|---|
| ERG (n2t) | 632,482.61 | $206,556 |
| tokens (n2t, priced subset) | 37 priced of 755 entries | $204,441 |
| **n2t total** | | **$410,997** |
| t2t (2.79 ERG + tokens) | | $9,898 |
| locks + LQ farms | | $6.56 |
| **ErgoDEX v1 total** | | **$420,902** |

Largest priced token reserves held by the pools: RSN $83.2K, SigUSD $37.5K, rsBTC $13.9K, rsFIRO $9.4K,
MEOW $7.4K, SigRSV $5.8K, Paideia $5.1K, QUACKS $5.0K, WALRUS $4.3K, CYPX $4.1K, EXLE $3.9K, PEPERG $2.5K,
heisenbERG $2.4K, SPF $2.4K, rsADA $2.3K, BURN $2.1K (+30 more). LP tokens in the pool boxes are the pools'
own unsold supply and are not counted as value.

### 5.2 Everything an attacker can do (and their costs)

| action | needs | bound enforced | net gain |
|---|---|---|---|
| swap (direct, no order box) | input amount | `validSwap` (constant product − fee) | $0 (fair price; saves the 0.1–0.2% DexFee only) |
| deposit | proportional reserves | `validDeposit` (min mint) | $0 |
| redeem | LP tokens | `validRedeem` (proportional burn) | $0 |
| execute a parked order | 1 tx | order script pays Pk ≥ fair price; miner fee ≤ MaxMinerFee | ≤ order's miner-fee constant (dust) |
| spend a stuck box | — | script evaluation **errors** | impossible |

Gas on Ergo is ~0.001–0.01 ERG per tx; a *failing* drain costs a tx fee only.

### 5.3 The 18 anomalous boxes — stuck (S), $106

* 7 boxes with **0 tokens**, no R4 (1.118 ERG), 7 with **1 token**, no R4 (0.0043 ERG):
  script needs `SELF.R4[Int].get` → `None.get` → **evaluation error ⇒ unspendable** (verified).
* 4 "Mew Fund" boxes with **2 tokens** (NFT + LP, R4=970, **325.30 ERG**): `SELF.tokens(2)` is out of bounds
  → evaluation error/NPE ⇒ unspendable. (Even if a future interpreter returned a zeroed default instead of
  throwing, `validY` would require the successor's Y-token id to equal the empty id — impossible.)
* Live-verified with `executeWithContext` on each box (`ci-out/eval_results.json`,
  `analysis/…`); amounts: 326.42 ERG ≈ **$106**.

---

## 6. Proof / verification

* **Chain-native evaluation** (`/script/executeWithContext` on the public Ergo node `node.ergo.watch`,
  the deployed source as `script`, contexts built from the **real live pool box** fetched from the node's
  `/utxo/byId`): 14/14 scenarios match expectations (CI job `ergodex/ci/run.sh`, artifacts `ci-out/`).

| scenario | expected | result |
|---|---|---|
| fair swap (dX = 1,000,000; dY = −floor(fair)) | true | **true** |
| unfair swap (one nanoErg of Y above the bound) | false | **false** |
| drain via swap (dX = 1, take Y−1) | false | **false** |
| remove both reserves, LP unchanged | false | **false** |
| fair redeem (1,000,000 LP → rx, ry) | true | **true** |
| over-redeem X (rx+1) / over-redeem Y (ry+1) | false | **false** |
| fair deposit (max LP out) | true | **true** |
| over-mint LP (max+1) / take LP with 0 reserves | false | **false** |
| 4 anomalous boxes (spend attempts) | unspendable (error) | **ERROR** |

* **Arbitrage check (fee-aware).** For all **54 pools whose Y token has a DefiLlama price**, the maximum
  profitable trade against the pool (either direction, fee-aware numeric maximisation) sums to **$0.01** —
  i.e. the pools are at market (they are actively arbitraged). For the 157 pools with unpriced long-tail
  tokens no market reference exists; their Y side has no observable market and their X side is small — this
  is a residual unknown, not a demonstrated path (§8).
* **Decompiler**: `analysis/deployed_pool_debug.txt` (full sigma-rust parse of the deployed 412-byte tree),
  `analysis/master_pool_debug.txt` + normalized diff (structure identical).
* CI: see §7 run links; the whole job is reproducible from `ci/run.sh` (public endpoints only).

---

## 7. CI

* Job: `ergodex/ci/run.sh` → `ci/evaluate.py` (chain-native eval + live state + valuation + fee-aware arb),
  artifacts uploaded to `ci-out/` (eval_results.json, state.json, arb.json, summary.json, boxes_*.json,
  anomalies.json, scan.log).
* CI run URL(s): **see `ci-log.txt` / `summary.json` → `poc.ci_run_urls`** (GitHub Actions,
  `kingmariano/ca-zombie-ci`, branch `ergodex`).
* Local validation run: 14/14 PASS (same script; see `ci-out/scan.log`).

---

## 8. Verdict, residual risk, blockers

**Verdict:** external unprivileged extraction from ErgoDEX v1 on Ergo **= $0 (high confidence)**.
The value in custody (≈$420,902) is live AMM liquidity that only its entitled holders can realise
(LP redemption; lock withdrawal after deadline) or that can be acquired at the pool's own invariant price.
No contract path lets an outsider take reserves, LP, or rewards without paying proportional value.

**Residual / latent (not counted in E-U):**
1. **Long-overflow in the swap bound.** `deltaReservesX * feeNum0` (inner term) is Long arithmetic.
   For `feeNum0=997` a wrap needs `dX ≥ 2^64/997 ≈ 9.25M ERG` — the attacker must *add* that ERG to the
   pool and can never recover it proportionally; even if a congruent `dX` existed it is strictly
   unprofitable (the pool's Y side is worth far less). For the largest observed feeNum (999) the threshold
   is ~18.5M ERG. No live pool has an exploitable feeNum (none > 999; no R4-less pools are spendable).
2. **Parked orders are market orders.** The order scripts bound the executor only by the pool's *current*
   price (`fairPrice` is computed from live reserves), so an executor can sandwich/manipulate the pool before
   executing someone's parked order. This is MEV against the order owner, not protocol-value extraction;
   the pool invariant still holds. The order contracts themselves cannot be spent to steal (reward must pay
   `Pk`; owner can always cancel).
3. **The 2023-03-04 order-contract change** `INPUTS.size == 2 → >= 2` (commit `ce716e132f`) is a
   functionality fix; it does **not** touch the Pool contract (semantic diff verified) and does not create a
   theft path (relaxation, not tightening).
4. **Legacy / parameterised variants** (`PoolBoot` bootstrap boxes; SDK `arbPool` template with a
   compile-time `emissionLP`): their deployed instances cannot be enumerated without the dead indexer.
   All variants we could address-check are empty (n2dexyGOLD: 0 boxes) or dust; no evidence of live value.
5. **Burn-locked fraction (S).** At pool creation `InitiallyLockedLP=2^63−1` LP are minted; part is burned
   (never circulating) so a fraction of each pool's reserves is mathematically irredeemable. The exact
   fraction needs per-pool creation history and is not readable from the current boxes — a slice of the
   H-O figure is therefore permanently locked (S). Stuck dust quantified: **$106**.
6. **Unpriced long tail:** 157/211 distinct Y tokens have no price feed; they are counted as $0. Their pools'
   ERG side is small (the 54 priced pools hold the bulk of the ERG). No demonstrable extraction, but the
   USD total for the long tail is a lower bound.
7. **Blockers:** project API/indexer dead (orders/farms/legacy pools not exhaustively enumerable);
   Ergo has no public mempool API for order-flow analysis; the public node's `executeWithContext` returns
   `ERROR` (node-side exception) rather than a clean `false` for the stuck boxes — classified as unspendable
   because any script error invalidates the input.

---

## 9. Methodology, sources, files

**Sources of truth** (all public): Ergo explorer `api.ergoplatform.com/api/v1` (balances, boxes, tokens,
transactions); public Ergo node `node.ergo.watch` (`/script/p2sAddress`, `/utxo/byId`,
`/script/executeWithContext`); `spectrum-finance/ergo-dex` (contracts + history),
`spectrum-finance/ergo-dex-backend` (`AMMContracts.scala`, `sources/n2tContracts.scala`,
`N2TCFMMTemplates.scala`), `spectrum-finance/ergo-dex-sdk-js` (compiled templates, incl. git history),
`arkadianet/citadel` (independent Rust implementation of the same pools, used as a cross-reference),
DefiLlama `coins.llama.fi` (prices); sigma-rust `ergo-lib 0.28` (decompiler, locally built).

**Files:**
```
ergodex/
├── README.md                     (this file)
├── summary.json                  (machine-readable summary)
├── analysis/
│   ├── ergo_tree.hex             deployed 412-byte ergoTree
│   ├── deployed_pool_debug.txt   full sigma-rust parse (deployed tree)
│   ├── deployed_pool_pretty_resolved.txt  resolved pretty-print
│   ├── master_pool_debug.txt / master_pool_norm.txt  node-compiled source + normalized diff inputs
│   ├── contracts/                audited ErgoScript sources (backend == repo, + PoolSample)
│   ├── contracts_hist/           git-history versions of Pool.sc (address comparison)
│   ├── backend_*.scala|*_*.sc    backend contract trees/sources/templates (public)
│   ├── sdk/ sdk2/                JS-SDK compiled templates (PoolSample, lqmining, locks)
│   ├── n2t_boxes_unique.json     285 live boxes (full explorer data)
│   ├── t2t_boxes_unique.json     293 live boxes
│   ├── n2t_y_reserves.json       aggregated Y reserves
│   ├── balance_*.json            live balances (n2t, t2t, TokenLock, LQ pools)
│   ├── prices_now.json / token_meta.json  price snapshot
│   └── arb_table.json            fee-aware arb computation
├── ci/
│   ├── run.sh                    CI entry (expectation validator)
│   └── evaluate.py               chain-native eval + live state + valuation + arb
├── ci-out/                       CI artifacts (eval_results.json, state.json, arb.json, summary.json …)
├── ci-log.txt                    CI log (after run)
└── ci-artifacts/                 downloaded CI artifacts
```

**Caveats.** Point-in-time reads (height 1,892,615); the address is actively traded so exact box sets drift
by the minute (box-value sums reconcile to `balance/total` at fetch time). USD values use DefiLlama prices
at the stated time; illiquid tokens are $0/lower bound. No transactions were signed or sent; the public
node only *compiled and evaluated* scripts locally. No keyed endpoints or secrets are stored in this folder.
