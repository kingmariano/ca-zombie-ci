# C2-27 · Regen governance parameters & live state — evidence

All reads 2026-10-09 (UTC), public endpoints only. Local snapshot ~07:35–08:15 UTC; CI re-verification at
regen-1 height **29,202,472** (2026-10-09T14:48:52Z), artifact `ci-artifacts/result-regen/ci-out/regen-evidence.json`.

## Chain
| item | value | source |
|---|---|---|
| chain-id | `regen-1` | `/cosmos/base/tendermint/v1beta1/node_info` |
| app version | regen-ledger **v7.3.0** | same |
| Cosmos SDK | **v0.53.6** (go1.24.7) | same |
| latest block (CI snapshot) | **29,202,472** @ 2026-10-09T14:48:52Z | `/blocks/latest` |

## Gov params (`/cosmos.gov.v1.Query/Params` via ABCI on regen-rpc.polkachu.com — LCD route returns code 12)
Decoded from protobuf (script `analysis/decode_proto.py`); the params message sits in the response wrapper's
field 4 on this build. Raw: `analysis/raw/abci_gov_params_v1.json`.

| param | value |
|---|---|
| min_deposit | **2,000,000,000 uregen = 2,000 REGEN** |
| min_initial_deposit_ratio | 0.10 (200 REGEN at submission) |
| max_deposit_period | 1,209,600 s = **14 d** |
| voting_period | 604,800 s = **7 d** |
| quorum | **0.40** |
| threshold | **0.50** |
| veto_threshold | **0.334** |
| proposal_cancel_ratio | 0.50 (burned, dest empty) |
| expedited_voting_period | 86,400 s (1 d) |
| expedited_threshold | 0.667 |
| expedited_min_deposit | 50,000,000 **stake** — inert denom on Regen, expedited path unusable |
| burn_vote_veto | **true** (deposit burned on veto) |
| burn_vote_quorum / burn_proposal_deposit_prevote | false / false |
| min_deposit_ratio | 0.01 |

## Staking / supply / community pool (block 29,202,472)
| item | value |
|---|---|
| bonded_tokens | **80,959,415.153681 REGEN** |
| not_bonded (unbonding) | 42,081,171.963265 REGEN |
| uregen total supply | **239,826,669.588209 REGEN** |
| bonded validators | **11** (sum of tokens = bonded exactly) |
| top-2 validator bloc | ecoBridge.earth 16.86M + Regenerator 10.66M = **27,530,309.72 REGEN = 34.0 % of bonded** |
| community pool (x/protocolpool) | **3,672,761.673099 REGEN** (`/cosmos/protocolpool/v1/community_pool`) |
| x/distribution module account | 16,277,617.93 REGEN — **unclaimed staking rewards**, not CP (validators' own outstanding rewards alone = 9,034,300.85 REGEN + commissions 1,104,838.70 REGEN; delegator share makes up the rest) |
| all other module accounts (gov, fee_collector, mint, wasm, transfer, ecocredit, ecocredit-basket, marketplace-feepool, protocolpool_escrow, ICA) | **0** |

The `/cosmos/distribution/v1beta1/community_pool` LCD route returns
`"external community pool is enabled - use the CommunityPool query exposed by the external community pool"`
— that string is stock cosmos-sdk **v0.53.6** `x/distribution/keeper/grpc_query.go:367` (CP lives in x/protocolpool
in SDK ≥0.50; not a Regen fork). Source vendored: `analysis/raw/sdk_dist_grpc.go`.

## Tally semantics (cosmos-sdk v0.53.6 `x/gov/keeper/tally.go`, vendored `analysis/raw/sdk_tally.go`)
- `totalVotingPower = yes + abstain + no + veto`; quorum: `totalVotingPower / bonded_at_tally >= 0.40`.
- veto: `veto / totalVotingPower > 0.334` → fail, **deposit burned**.
- pass: `yes / (totalVotingPower − abstain) > 0.50`.
- The attacker's own stake is bonded → it **inflates the quorum denominator** (cost = q/(1−q)·B, not q·B).

## Proposal history (last 12; fields yes/abstain/no/veto)
| id | status | yes | abstain | no | veto |
|---|---|---|---|---|---|
| 81 | rejected | 28,510,098,955,887 | 0 | 0 | 0 |
| 80 | rejected | 28,516,969,272,713 | 0 | 0 | 0 |
| 79 | passed | 62,101,833,772,762 | 0 | 0 | 0 |
| 78 | passed | 53,681,403,509,219 | 0 | 0 | 0 |
| 77 | passed | 53,644,269,772,707 | 0 | 0 | 0 |
| 76 | passed | 53,625,866,646,368 | 0 | 0 | 0 |
| 75 | passed | 35,040,733,456,333 | 0 | 0 | 0 |
| 74 | passed | 35,041,983,456,333 | 0 | 0 | 0 |
| 73 | passed | 47,680,653,622,629 | 0 | 0 | 0 |
| 72 | passed | 47,675,634,146,266 | 29,000,000 | 5,000,000,000 | 0 |
| 71 | rejected | 31,383,854,961,639 | 53,832,999,351 | 0 | 0 |
| 70 | rejected | 25,763,499,778,558 | 117,190,000,000 | 0 | 0 |

Note: no material No votes in this window (only 5,000 REGEN of dust on #72) and **0 veto votes**; #80/#81 failed on quorum only.

### CP-spend precedents (ABCI-decoded, `analysis/raw/abci_prop77.json`, `abci_prop78.json`)
- **#78** (passed 53.68M–0–0–0): 11 × `MsgCommunityPoolSpend` 36,000,000 uregen each = **396,000 REGEN** to the 11 validators.
  Authority = gov module `regen10d07y265gmmuvt4z0w9aw880jnsr700j9qceqh`.
- **#77** (passed 53.64M–0–0–0): 100,000 REGEN CP spend to the **proposer's own address**
  `regen1jfheyvsah5wqfyawmedme43te056z8gzdnpf3j` ("payout account ... is the proposer's own address" — proposal text).
- **#63**: a CP spend that passed (43,683,675,101,665 yes / 0 no) but **failed at execution** because it used
  x/distribution's deprecated message instead of `cosmos.protocolpool.v1.MsgCommunityPoolSpend` (per #77's text).
- CP balance trajectory: 5,035,750 REGEN at #77 build time (2026-09-07) → **3,672,761.67 REGEN** now.
