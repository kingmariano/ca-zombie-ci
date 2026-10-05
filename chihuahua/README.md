# C2-06 — Chihuahua (chihuahua-1) governance capture: cost vs proceeds, live

**Date:** 2026-10-05 · **Chain:** chihuahua-1 (Cosmos SDK v0.54.4, CometBFT v0.39.4, ibc-go v11.2.0, wasmd v0.70.4)
**Status:** read-only research; **no transactions signed or sent**; no fork PoC possible for Cosmos gov (no chain binary) — the path is verified by live ABCI/LCD state + source-level analysis of the exact SDK version in use + a reproducible CI evidence run.

---

## TL;DR

| Target | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| Chihuahua community pool (x/distribution, held by `chihuahua1jv65s3…`) | **≈ $8.1k realistic / $10.6k ceiling** (nominal $33.3k) | **Capture (open):** `MsgCommunityPoolSpend` pays any address; a 5,000,000 HUAHUA deposit ($22.55, refundable) + a 1–5 day vote is all that stands between an attacker and the pool. Pass gate = 20 validators, who vote within ~1 minute and ~97–100% Yes | Validators auto-vote; any future CP inflow re-arms the same attack |
| Solo-quorum capture (buy 33.4% of bonded) | **$0 — infeasible** | Needs 7,724,435,925 HUAHUA ($34.8k at spot); only **2.52B HUAHUA** exists in all on-chain pools (2.35B Osmosis + 0.17B native DEX) and no CEX lists HUAHUA. Proceeds ($8–10.6k) < spot cost | — |
| ampGASH (868M spendable) | **$0** | No Osmosis pool, no native DEX pool; Migaloo (issuer chain) is sunsetting with all public endpoints dead | — |
| ADGM (50M spendable) | **$0** | Origin is the `dogmond_174394-1` Dymension rollapp (client height 7,557); no market found | — |
| ashHUAHUA 10.3M, beer/sbdc/shib/shiva 4×250k | **$0** | Tokenfactory memecoins/receipts; no Osmosis or native pools | — |
| uatom (29.291024 ATOM spendable) | **$52.56** | IBC to Osmosis, liquid | — |

## Total live extractable now

**≈ $8,085 (realistic single-shot dump of everything spendable) — hard ceiling $10,618; nominal mark $33,330.**
Confidence: **medium-high** on mechanics, amounts, caps and liquidity (all read live; SDK source checked); **medium-low** on the pass probability (social gate — no precedent of a hostile CP-spend passing, but strong precedent of automated Yes voting).

Categories: **capture ≈ $8.1k** (E-U-class path: no keys required, ~$23 refundable cost, gated only by validator votes). **E-U solo-quorum = $0 (infeasible). P = $0** beyond the pool (module holds 2.62B extra uhuahua and 4.56B extra ampGASH that `MsgCommunityPoolSpend` cannot touch — see §4). **H-O/S = $0.**

---

## 1. The mechanism in exact terms

**Governance can move the community pool to any address; capture = the cost of a passing proposal.**

1. **Gov params** (live ABCI `/cosmos.gov.v1.Query/Params`, chihuahua h 25,614,418; value re-decoded from the protobuf):

   | Param | Value |
   |---|---|
   | `min_deposit` | **5,000,000 HUAHUA** (5e12 uhuahua) |
   | `min_initial_deposit_ratio` | 0.25 (1.25M HUAHUA upfront) |
   | `max_deposit_period` / `voting_period` | 5 days / **5 days** |
   | `quorum` | **0.334** |
   | `threshold` / `veto_threshold` | 0.50 / 0.334 |
   | `expedited_voting_period` / `expedited_threshold` / `expedited_min_deposit` | 1 day / 0.667 / **10,000,000 HUAHUA** |
   | `burn_vote_veto` | **true** (deposit burned only if vetoed; refunded on pass/reject) |

2. **The payout handler** — Cosmos SDK **v0.54.4** (the exact version in chihuahuad v10.0.0's `go.mod`; the chain imports upstream `cosmos-sdk/x/distribution`):
   - `x/distribution/keeper/msg_server.go` → `CommunityPoolSpend` validates authority (gov module), rejects blocked addresses, then calls `DistributeFromFeePool`.
   - `x/distribution/keeper/fee_pool.go` → `DistributeFromFeePool` does `feePool.CommunityPool.SafeSub(amount)` **first** (reverts if the spend exceeds the fee-pool DecCoins accounting) and then `SendCoinsFromModuleToAccount(distribution → recipient)`.
   - `recipient` is attacker-controlled; there is **no allowlist, timelock, or spend limit** beyond the pool accounting. A single gov v1 proposal may carry **multiple** `MsgCommunityPoolSpend` messages (one per denom) and executes automatically when the voting period ends (SDK ≥ v0.46 EndBlocker; passed-but-failed proposals get `PROPOSAL_STATUS_FAILED`).

3. **What is spendable (live, h 25,614,418; `min(feePool DecCoins, distribution module balance)`):**

   | Denom | Fee-pool accounting | Module balance | **Spend cap** | Price | Nominal |
   |---|---|---|---|---|---|
   | uhuahua | 7,399,836,472.11 | 10,019,561,374 | **7,399,836,472 HUAHUA** | $4.5e-6 | $33.3k |
   | ibc/7D01429F… (ampGASH) | 867,995,216.39 | 5,432,824,467 | **867,995,216 ampGASH** | $0 (no market) | $0 |
   | ibc/C1F002C3… (ADGM) | 50,000,000 | 50,000,000 | **50,000,000 ADGM** | $0 (no market) | $0 |
   | ibc/B1C671DA… (uatom) | 29.291024 | 29.291024 | **29.291024 ATOM** | $1.79 | $52.56 |
   | uhuahua.ash (ashHUAHUA) | 10,306,079.548 | 10,306,079,548,000 raw | 10,306,079.548 | $0 | $0 |
   | beer/sbdc/shib/shiva | ~250,000 each | ~250k each | ~250k each | $0 | $0 |

   The distribution module holds **2.62B uhuahua and 4.56B ampGASH more than the fee-pool accounting**; `DistributeFromFeePool` reverts on those (the `SafeSub` check). They are **not** extractable via `MsgCommunityPoolSpend` (only via a malicious software upgrade, which requires validators to adopt a binary — P, not E-U).

4. **Historical precedent for CP spends:** proposals 64 (600M), 69 (2.5B), 71 (275M), 72 (13.5M), 79 (180M), 82 (210M) HUAHUA **all passed** and paid out. The only rejected CP spend (78) had an *empty* amount array. Recent turnout 66–77% of bonded, Yes share 95–100%.

---

## 2. Live-state assessment (all read live; no roles/allowances involved — this is a chain-level path)

| Item | Value | Where |
|---|---|---|
| Latest block (chihuahua) | **25,614,448** (2026-10-05T16:33Z) | `blocks/latest` |
| Gov module (authority) | `chihuahua10d07y265gmmuvt4z0w9aw880jnsr700jeh7th3` | `module_accounts` |
| Distribution module (holds CP) | `chihuahua1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8y2fjga` | `module_accounts` |
| Bonded tokens | **15,402,617,743.21 HUAHUA** | `staking/pool` |
| Not-bonded | 18,823,561,935 HUAHUA | `staking/pool` |
| Supply | **121,785,420,571.78 HUAHUA** | `bank/supply` |
| Bonded validators | **20** (max_validators 80; prop 103 live proposes 30) | `staking/validators` |
| Community tax | 0.05 | `distribution/params` |
| Wasm code upload | Everybody / Everybody (not relevant here) | `wasm codes/params` |

**Market (the extraction bottleneck):**
- Real price: **$4.5–4.6e-6/HUAHUA** — CoinGecko `chihuahua-token` $4.55e-6 (mcap $522k, 24h vol $4.4k), DefiLlama `chihuahua:uhuahua` $4.54e-6, Osmosis pool 605 $4.56e-6, pool 606 $4.62e-6. *(Caution: CoinGecko id `chihuahua` at $1.48e-9 is a different token — do not use.)*
- **Only venue: Osmosis.** All 3,610 pools scanned → **33 HUAHUA pools** (23 gamm + 10 concentrated-liquidity). Native chihuahua `x/liquidity` DEX has 6 pools (all paired with local memecoins). MEXC/CoinEx/Gate/BitMart do **not** list HUAHUA (verified: "invalid symbol").
- **HUAHUA on-chain float: 2,349,814,818 in Osmosis pools + 170,416,010 in the native DEX = 2.52B** — vs 7.72B needed for solo quorum.
- **Realizable counterpart across all HUAHUA pools: $10,565.89 liquid** (OSMO/ATOM/USDC), $11,258.93 marked (incl. illiquid AWIF/allLTC/allBTC). Optimal split of a 7.4B dump across pools → **$8,032.90**; native DEX counterpart ≈ $0.

| Pool (Osmosis) | Type | HUAHUA | Counterpart | USD |
|---|---|---|---|---|
| 606 | gamm | 1,022,564,532 | 2,576.03 ATOM | $4,622.70 |
| 605 | gamm | 528,729,639 | 66,267.60 OSMO | $2,386.18 |
| 1111 | CL | 372,446,496 | 46,494.98 OSMO | $1,674.20 |
| 2452 | CL | 304,308,004 | 778.88 ATOM | $1,397.70 |
| 2315 | gamm | 522,957 | 8.72 allLTC (illiquid) | $611.86* |
| 2487 | CL | 95,771,330 | 12,240.70 OSMO | $440.77 |
| all other 27 | — | ~24.7M | memecoins/USTC/TORI/AWIF | < $100 |

\* allLTC decimal ambiguity ($6–612); excluded from the liquid ceiling.

---

## 3. What an attacker can and cannot do

**Path A — deposit + validator vote (the live path).**
1. Buy **5,000,000 HUAHUA** on Osmosis (~$22.55; pool 606 quote $22.49) — or reuse existing holdings.
2. Submit `MsgSubmitProposal` (gov v1) containing one or more `MsgCommunityPoolSpend` messages: `authority = gov`, `recipient = attacker`, amounts = the full caps above. Pay 5M HUAHUA initial deposit (100% of `min_deposit`) → straight to voting. For 1-day expedited: 10M HUAHUA ($45.10) and a 66.7% threshold.
3. Validators vote. Turnout 66–77% of bonded has historically been reached without the proposer's help; **the attacker does not need any stake**.
4. If Yes > 50% of non-abstain and veto < 33.4% → passes; the gov EndBlocker executes the spends automatically. Payout lands in the attacker's address in **1 day (expedited) or 5 days**.
5. Dump the 7.4B HUAHUA into the 33 Osmosis pools → **≈ $8.1k** (optimal split; ceiling $10.6k); IBC the 29.29 ATOM out → $52.56. All other denoms are worthless.

Cost: **$22.55 (refundable on pass or reject; burned only on veto)** + ~$0.02 gas. Downside if validators say No: gas + temporarily locked deposit. Expected value is positive for any pass probability above ~0.3%.

**Path B — solo quorum (buy 33.4% of bonded).**
- Requirement: X ≥ q/(1−q)·B₀ = **7,724,435,925 HUAHUA** (the attacker's own stake raises the bonded denominator, so 33.4% of the pre-stake bonded is not enough).
- Cost at spot $34.8k; **available on-chain: 2.52B HUAHUA (33% of the requirement)**. No CEX, no OTC market; the entire token's 24h volume is ~$4.4k. Not executable. Even if it were, proceeds ($8.1–10.6k) < spot cost, and staking locks the capital for 21 days' unbonding.
- **Verdict: infeasible and uneconomic.**

**Validator gate — the only real blocker (and it is weak):**
- 20 bonded validators; top 3 hold 63% of voting power.
- Live prop 103 (routine staking-param change): **3 Yes votes 66 seconds after submission** (18:32:32Z → 18:33:38Z), 37 Yes / 2 No by Oct 5, 9.14B Yes / 0.27B No (61% turnout, 97% Yes) — consistent with automated default-Yes voting (REStake-style bots).
- But validators **can** reject: prop 78 (malformed CP spend) and prop 88 (contested upgrade, 26.2B No) failed. A CP spend to a fresh anonymous address with an obviously hostile summary would likely be noticed; a plausible-looking proposal may not be.
- **No on-chain defense exists** (no recipient allowlist, no timelock, no spend cap).

---

## 4. Verification (CI + live reads; no fork)

Cosmos governance cannot be fork-tested with Foundry; the verification is instead:
- **Exact-version source check:** chihuahuad v10.0.0 `go.mod` pins `github.com/cosmos/cosmos-sdk v0.54.4`; `app/app.go` imports upstream `x/distribution`; `DistributeFromFeePool` in v0.54.4 caps at `feePool.CommunityPool` — fetched and quoted in `analysis/raw/sdk_fee_pool.go` and `sdk_dist_msg_server.go`.
- **Live ABCI decode** of `/cosmos.gov.v1.Query/Params` (the LCD's REST route is not implemented; the raw protobuf was decoded by `analysis/model.py`).
- **Reproducible CI job:** `ci/run.sh` pulls all raw state into `ci-out/raw/` and re-computes the model (`ci-out/model.json`, `ci-out/model.md`) on the public runner. Run URLs are recorded in `summary.json` / below.

CI runs:
- `<filled after CI completes>` — see `summary.json.poc.ci_run_urls`.

Key script outputs (latest local run, chihuahua h 25,614,447, Osmosis h 71,960,2xx):
```
bonded HUAHUA:            15,402,617,743.21
solo-quorum stake:         7,724,435,925 HUAHUA = $34,837 (spot)
min deposit:               5,000,000 HUAHUA = $22.55  | expedited 10,000,000 = $45.10
HUAHUA in Osmosis pools:   2,349,814,818 | native DEX 170,416,010
liquid dump ceiling:       $10,565.89 | optimal split $8,032.90 | + ATOM $52.56
CP nominal:                $33,277–33,870 | CP realizable: $8,085 (realistic) / $10,618 (ceiling)
path B feasible:           False
```

---

## 5. Verdict, residual and latent risk

- **Classification: capture (not a contract E-U exploit).** An unprivileged attacker can extract **≈ $8.1k realistic / $10.6k ceiling** for a **~$23 refundable** deposit and 1–5 days, *if* 20 validators let a hostile spend through. The "cost to capture" is therefore not the corpus's "~$26 to quorum" — the solo-quorum route is infeasible; the true cost is a refundable deposit and the social gate.
- **Corpus corrections:** bonded was mis-scaled 1000× (15.38M → **15.40B** HUAHUA); "quorum ~$26" is actually the **min deposit $22.55** (solo quorum = 7.72B HUAHUA ≈ $35k and infeasible); CP "7,399,835 HUAHUA ≈ $37.4k" → **7.40B HUAHUA ≈ $33.3k nominal, ~$8–10.6k realizable**; ampGASH/ADGM amounts are right but **worth $0** (Migaloo sunsetting; dogmond has no market). The "$37.4k CP vs ~$26" framing overstated the prize and understated the gate.
- **Residual/latent:** the CP keeps accruing (community tax 5% of fees/inflation; spend cap grew ~100 HUAHUA between our reads). Any future CP spend proposal is the same attack. If a hostile proposal ever gets human review before auto-votes pass it, it dies; if not, ~$8–10.6k is lost per successful attempt. Recommend: social monitoring of all CP-spend proposals + a recipient allowlist/timelock upgrade.
- **Blockers (why it is not more):** on-chain float (2.52B) < solo-quorum requirement (7.72B); CP realizable value bounded by ~$10.6k of pool counterparty; ampGASH/ADGM/dust have no market; extra module balance is unspendable without an upgrade.

## 6. Methodology, sources, caveats

- **State:** public LCDs (`api.chihuahua.wtf`, `lcd.osmosis.zone`) + RPC (`rpc.chihuahua.wtf`) + DefiLlama/CoinGecko, all read 2026-10-05 (heights recorded per run in `ci-out/`).
- **Full market scan:** all 3,610 Osmosis pools (poolmanager) filtered for the HUAHUA IBC denom; native `x/liquidity` reserves read per pool; CEX listing probes; denom traces resolved for every counterpart token.
- **Caveats:** (1) USD values move with the $4.5–4.6e-6 HUAHUA price and pool reserves (they changed ~1–2% during the session); (2) CL-pool extractable amounts are approximated by active-tick liquidity (`L·√P`), so the ceiling may be slightly optimistic; (3) the optimal-split dump assumes a single-block sale — a patient seller with no buyers gets no better; (4) pass probability is a judgment: automated Yes votes are proven, hostile-proposal review is not; (5) Eris hub "1.043B HUAHUA" (corpus context) was not independently re-verified — it is bonded stake, not separately extractable.
- **Files:** `analysis/model.py` (model), `analysis/out/model.{json,md}`, `analysis/raw/` (raw LCD/price pulls, SDK sources), `ci/run.sh` + `ci/evidence.py` (CI job), `ci-out/` (CI artifacts), `summary.json`.
