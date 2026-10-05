# C2-10 Desmos — governance-capture economics (live)

All state read 2026-10-05 (h≈30,863,2xx–30,863,3xx); CI re-pins the snapshot (`ci-out/cost-model.json`). Sources: `api.mainnet.desmos.network` (REST/gRPC), `desmos-rest.staketab.org`, `lcd.osmosis.zone`.

## 1. Live governance parameters (legacy subspace `gov`)

Query: `GET /cosmos/params/v1beta1/params?subspace=gov&key={depositparams,votingparams,tallyparams}`

| param | live value |
|---|---|
| min_deposit | 2,000 DSM |
| max_deposit_period | 259,200 s (3 days) |
| voting_period | 604,800 s (7 days) |
| quorum | **0.334** (33.4% of bonded) |
| threshold | **0.5** |
| veto_threshold | **0.334** |

Unbonding time: 14 days (1,209,600 s). Community tax: 2%; inflation now 0 (prop 52, 2026-09-26). Bonded: **82,888,768.07 DSM** (16 validators). Community pool: **16,666,867.90 DSM**.

## 2. The target

Community pool = **16,666,867.90 DSM** ≈ **$157.0k** nominal at DSM $0.00942.
Only standard gov-spendable pot: all other module accounts hold zero (checked distribution, fee_collector, bonded/not-bonded pools, gov, mint, ibc, transfer, wasm, and Desmos modules profiles/relationships/posts/reports/subspaces/fees/tokenfactory). The IBC escrow (41,366,045 DSM) and staking pools are **not** spendable by any standard gov message.

## 3. Validator behavior (the practical blocker)

- Top-4 validators hold **68,804,250.6 DSM = 83.0%** of bonded (Apollo 20.04M, Athena 17.81M, Artemis 16.03M, Poseidon 14.93M).
- Validators vote en masse on every proposal: prop 50 63.6M Yes, prop 51 76.7M Yes, prop 52 76.2M Yes.
- **Precedent (prop 46, Apr 2024):** a `MsgCommunityPoolSpend` of 50M DSM to the proposer's own address received **Yes 0, No 2.9M, Abstain 15.5M, NoWithVeto 42.5M → rejected (vetoed)**. Props 38 and 49 were likewise vetoed. A hostile CP spend is recognised and vetoed.

## 4. Market depth / price (the economic blocker)

DSM on Osmosis (denom `ibc/EA4C0A9F…A46DAD1C`, path transfer/channel-135/udsm); Desmos channel-2 escrow holds 41,366,045.2 DSM matching Osmosis supply 41,313,379.5 DSM.

| pool | pair | DSM | counter | counter USD | implied DSM |
|---|---|---|---|---|---|
| 618 | DSM/ATOM | 468,058.6 | 2,481.55 ATOM | $4,453 | $0.009514 |
| 619 | DSM/OSMO | 310,407.9 | 80,493.8 OSMO | $2,898 | $0.009337 |
| 1559 | DSM/… | 0.32 | 27.8 | ~$0 | — |

Total observable liquidity: **~$7.35k counter-value / 0.78M DSM**. CoinGecko: $0.00942007, market cap $900k, 24 h volume **$17.12** (no CEX depth; no other DEX pools found on Osmosis).

## 5. Attack model and costs

Let `Q` = quorum stake = 0.334 × 82,888,768.07 = **27,684,848.5 DSM**.

**Route 1 — on-market accumulation.** The pools hold 0.78M DSM total. Buying 27.68M DSM on-market is **physically infeasible** (cannot buy more than reserves; the constant-product cost diverges as X→D). Draining all pools costs ~$7.35k and yields only 0.78M DSM.

**Route 2 — OTC accumulation at spot.** Cost = Q × $0.00942 = **$260.8k** for quorum (validators abstain scenario); **$648.1k** to outvote the top-4 if they vote No (need Yes > 68.8M).

**Exit value.** Dumping the whole bag (Q + CP = 44.35M DSM) into the observable pools returns **≈$7.28k** (constant-product, 0.2% fee; pools saturate at their counter reserves). Even dumping only the 16.67M CP returns **≈$7.18k**.

**Net (OTC-at-spot scenario):** 7.28k − 260.8k = **−$253.5k**. Break-even OTC price = $7.28k / 27.68M = **$0.000263/DSM = 2.8% of market price** — i.e. capture only pays if 27.7M DSM can be acquired at ~36× below spot. No such market exists.

**Additional frictions:** 7-day voting + 14-day unbonding lockup on Q; NoWithVeto ≥33.4% of cast votes kills the proposal and burns the 2,000 DSM deposit; validators demonstrably veto CP spends.

## 6. Variants checked (all closed)

- **Hyperinflation route:** captured gov could raise mint `inflation_max` and distribution `community_tax` to 100% and then CP-spend new issuance — but this requires capture first, mints worthless DSM, and still exits only through the same ~$7.3k pools.
- **IBC escrow seizure:** no standard gov message can spend escrow; only a malicious software upgrade could, which requires validators to run it (not unprivileged; not credible with an active, concentrated validator set).
- **Vote rental / borrowing:** no DSM LST or vote-rental market exists; Cosmos gov has no flash-loanable voting power (14-day unbonding).

## 7. Verdict

**Capture E-U = $0.** The nominal $157k community pool is a *governance-only (P)* pot that is economically unreachable: capture cost ≥ $260.8k (best case, at spot, if tokens were buyable at all) versus ≤ $7.3k immediately realizable, before the 83% validator bloc and its veto record. Confidence: **high** on-chain; **medium** against off-chain bribery of validators (not measurable, and the last hostile CP-spend attempt was vetoed).
