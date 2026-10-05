# C2-05 · Stride governance capture (stride-1) — deep-dive re-verification

**Date:** 2026-10-05 · **Chain:** stride-1 (Cosmos SDK v0.54.3, app v34.1.0) · **Status:** read-only; no transactions signed or sent; no secrets.
**Finding under review:** C2-05 “Stride governance capture — $48.4k bonded stake controls ~$5M of stATOM”, claimed path: buy >25% of bonded → `MsgCommunityPoolSpend` (CP ~$14.5k) or `MsgSoftwareUpgrade` (malicious binary → ICA-held assets).
**Canonical snapshot:** stride-1 height **41,148,157** (2026-10-05T16:25:27Z), CI run [`37340699999`](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37340699999) (success). An earlier local snapshot at height 41,147,534 gave the same figures within price drift.

**Headline result:** the capture is **not economically executable by an external unprivileged attacker today** — not because the governance parameters are hard (they are not: quorum 25%, threshold 50%, 5-day vote, 20,000 STRD deposit), but because **the STRD market cannot supply the required stake at any price**. The entire Osmosis STRD market (the only public venue) holds ≈0.68M STRD and SQS quotes saturate at ≈0.74–0.87M STRD even for $180k+ of input, while the no-opposition quorum requirement is **2,210,219 STRD** (shortfall **66.0%** at the CI snapshot). The CP prize is only **$12,455.09**, and the ~$5.05M of ICA-held staking assets is only reachable through a **malicious software upgrade (validator adoption required)** — a social/operational attack, not an unprivileged one.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| Community pool (`MsgCommunityPoolSpend`) | **$0 today** (conditional capture prize $12,455.09) | Passing any proposal needs either (a) >2.21M STRD of yes-vote stake — market cannot supply it — or (b) the incumbent validators’ consent; scam proposals on Stride are routinely rejected | Vote-buying / social engineering of validators; CP is small |
| ICA-held staking assets (~$5.05M: ATOM/TIA/INJ/OSMO/ISLM/BAND/…) | **$0** | ICA controller = Stride chain code; live v34.1.0 has **no message** that moves ICA funds to an arbitrary address. Host allowlists are fully open (Hub: `["*"]`; Celestia: MsgSend/MsgTransfer allowed) so the only gate is code integrity | Malicious `MsgSoftwareUpgrade` (undelegate → 21d unbond → transfer out) — requires validators to run an attacker binary |
| Module-account balances (distribution outstanding staker rewards, auction, poa, reward_collector) | **$0** | Not spendable by gov messages; outstanding rewards are holder-claimable (H-O) | Malicious upgrade |
| F5 admin key (`stride1k8c2m5…`, 2-of-3 multisig) | **$0** | Hard-coded admin for several stakeibc/staketia messages (rebates, bounds, channel close, rebalance, record overwrites); key-compromise surface | 2-of-3 key compromise |

**Total live E-U extractable now: $0.00 (high confidence).**
**Conditional capture prize (requires a passed proposal): $12,455.09 (community pool).**
**Latent P exposure behind a malicious upgrade: ≈$5.05M of ICA custody.**

---

## 2. Re-verification of the claim

All values at stride-1 height **41,148,157** (2026-10-05T16:25:27Z) unless stated; raw evidence in `ci-out/raw/`, recomputed in `ci-out/report.json`.

| Claim (C2-05) | Re-verified value | Verdict |
|---|---|---|
| `bonded_tokens = 6,629,059 STRD ≈ $48.4k` | **6,630,658.205459 STRD = $47,505.76** @ $0.00716456 | ✅ (0.02% drift) |
| quorum 25%, threshold 50%, 5-day vote | quorum **0.25**, threshold **0.50**, veto **0.334**, voting period **432,000s (5d)**, max deposit period 172,800s (2d) — via gRPC `cosmos.gov.v1.Query/Params` on 2 independent nodes | ✅ |
| min deposit 20,000 STRD | **20,000,000,000 ustrd** = 20,000 STRD; `minInitialDepositRatio=0.50`; `burnVoteVeto=true` | ✅ |
| stATOM supply 1,075,833.76 | **1,076,771.446421 stATOM** | ✅ (stale by ~0.09%) |
| stTIA supply 633,055.33 | **633,055.327098 stTIA** | ✅ exact |
| TVL ~$4.99M | DefiLlama protocol TVL sum ≈ $4.99M; **on-chain ICA custody $5,047,044.18** | ✅ |
| CP ~$14.5k | **$12,455.09** (stATOM $11,701.86 + STRD $498.65 + stBAND $75.13 + TIA $47.91 + stDYDX $40.99 + stOSMO $27.87 + stTIA $26.76 + stLUNA $14.73 + dust) | ⚠️ 14% lower than claim |
| “acquire >25% of bonded (≈$24.7k)” | **Not executable**: 25%-of-bonded-equivalent capture requires ≥2,210,219 STRD ($15,835 spot), but the whole market can deliver ≈0.75–0.87M STRD. $24.7k of market buying yields ≈0.55–0.66M STRD (market price impact 3–5×) | ❌ infeasible |

---

## 3. Live-state assessment (all values read on-chain; addresses below)

### 3.1 Governance parameters (authoritative, gRPC)
`grpcurl stride.lavenderfive.com:443 cosmos.gov.v1.Query/Params` (also verified via `grpc.stride.citizenweb3.com:443`):
```
minDeposit:            20,000 STRD          maxDepositPeriod: 172,800s (2d)
votingPeriod:          432,000s (5d)        quorum:           0.250
threshold:             0.500                vetoThreshold:    0.334
minInitialDepositRatio:0.50                 proposalCancelRatio: 0.50
expeditedVotingPeriod: 86,400s (1d)         expeditedThreshold: 0.667
expeditedMinDeposit:   50,000,000 "stake"  ← denom does not exist on Stride → expedited proposals unusable
burnVoteVeto:          true                 minDepositRatio: 0.01
```
`bond_denom=ustrd`, `unbonding_time=1,209,600s (14 days)`, 100 bonded validators.

### 3.2 Stake and supply
- **Bonded:** 6,630,658.205459 STRD (bonded pool `stride1fl48vsnmsdzcv85q5d2q4z5ajdha8yu3ksfndm`).
- **Not bonded (unbonding queue):** 3,819,122.238760 STRD.
- **Total supply:** 37,732,746.37 STRD (was 37,738,058 earlier the same day — the buyback-and-burn is active).
- **Market cap:** ≈$270k. Top validator = 1.22M STRD (18.4% of bonded); top 10 ≈66%; top 20 ≈86% (100 validators).
- **Historical tallies (quorum enforcement evidence):** prop 282 rejected with 1,654,900.73 STRD voted (≈24.96% of bonded) and 99.9998% Yes — a pure quorum failure, exactly consistent with quorum=25%. Upgrade proposals historically turn out 45–70% of bonded (prop 284: 3,633,655; prop 283: 4,545,197; prop 280: 4,463,522), and the current live proposal 285 has 149/152 votes Yes.

### 3.3 Community pool (gov-spendable)
Distribution module account `stride1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8y5yqan`; CP coins via `/cosmos/distribution/v1beta1/community_pool` = **$12,455.09**, dominated by **3,278.061418 stATOM ($11,701.86)** + **69,599.51 STRD ($498.65)** + **320.467755 stBAND ($75.13)** + 102.672736 TIA ($47.91) + dust. (The distribution module’s *bank* balance is larger — ≈$65k of unclaimed stToken staking rewards for STRD stakers — but those are **not** in the CP and not spendable via `MsgCommunityPoolSpend`.)

### 3.4 ICA custody (the “≈$5M”)
Host-zone state via `stride.stakeibc.Query/HostZoneAll`; host chains independently queried.

| Host zone | Staked amount (chain state) | USD | Delegation ICA | On-chain check |
|---|---|---|---|---|
| cosmoshub-4 | 2,165,802.35 ATOM (rr 2.011456) | $3,878,055 | `cosmos10uxaa5gkxpeungu2c9qswx035v6t3r24w6v2r6dxd858rq2mzknqj8ru28` | ✅ 109 delegations, 2,165,802.087170 ATOM (exact match) + 8,564.07 ATOM liquid |
| celestia | 744,230.33 TIA (rr 1.176364) | $347,261 | `celestia1rdfn69mf3xey2jlqyp70vljtx6df4lkydndplz9drdueuhqh8geqk9gjkj` | ⚠️ on-chain shows 587,357.974464 TIA (92 delegations) + 475.83 TIA liquid; 156,872 TIA gap unresolved (no unbonding/redelegation found) |
| haqq | 107,130,613.50 ISLM | $345,685 | `haqq1ap9ax6qe73hy5r9ntmrla6yy28fvdxu2gt0j9gfta256e0fdncsstexhwv` | chain state |
| injective-1 | 20,768.72 INJ | $156,251 | `inj16ujqtje2en9ns59hrcjfu2885epsrvus9czdw8ljtd45whxucs5srrejpa` | chain state |
| laozi-mainnet | 513,447.26 BAND | $120,378 | `band1r9sw8tc4z8sgzy8nvkzes4t7qset9seqwr7854phphlp9wkxs3vqlnj5g3` | chain state |
| osmosis-1 | 3,358,166.15 OSMO | $120,376 | `osmo1npfl4vmmmf4yqhcemz95mvqujgdnlhrlxfzhlhz2gru8g2t749xqr9zm5e` | chain state |
| dydx-mainnet-1 | 404,352.53 DYDX | $58,427 | `dydx1xkpgnprs33sr9a3e78evgk0hkfzlkxdpsqajl97tqkvam9krw42s29ckac` | chain state |
| phoenix-1 | 133,855.14 LUNA | $6,806 | `terra1ap70xcsx25u5ke77jmajdkza0lr7jr5mun98zsalzlr7z20hxa8slsnpaa` | chain state |
| evmos_9001-2 | 12,432,591.60 EVMOS | $4,701 | `evmos1d67tx0zekagfhw6chhgza6qmhyad5qprru0nwazpx5s85ld0wh2sdhhznd` | chain state |
| juno-1 | 477,839.16 JUNO | $4,269 | `juno1zjpfewdsdykrgce8d20lfanhh6evufxeyya4fyepjs9lh57tv3jqrutwt0` | chain state |
| ssc-1 | 105,111.67 SAGA | $2,600 | `saga1nzftmskrztvcct6jjdgsskqf4ac40jamr3ulz27hfqptu6w96n0sp3ec6t` | chain state |
| stargaze-1 | 27,925,242.73 STARS | $1,639 | `stars1rfxv568skvtncxfl28s25scg87es2w8q32z727mvtxgjmexuqc246ra` | chain state |
| sommelier-3 | 1,441,234.22 SOMM | $596 | `somm1p7tx0yrgawf6tud3m4jmsl4m2y72syp73phfps43h8qx3y0t8t0qy3x676` | chain state |
| comdex-1 | 2,312,175.14 CMDX | $0.2 | `comdex1qj6rdc6qwqnat5scej42299meeke455gpxy4cyan7ktfasd3wt5q06dyv6` | chain state |
| umee-1 | 33,185,925.32 UMEE | $0.2 | `umee14vgwwpem5p0d84gsqw9e0urwpnuwug8mre7hyahlmuey7t4kgpdqj6xr9c` | chain state |
| **Total** | | **$5,047,044** | | |

Community-pool ICAs on the host chains are dust (2–8 atoms). The Hub withdrawal ICA additionally holds 277.21 liquid ATOM + IBC dust.

### 3.5 Who can move the ICA funds?
- The ICAs are controlled by the **Stride chain’s ICAController module** (stakeibc). Host-side allowlists do **not** constrain it:
  - Cosmos Hub `ibc/apps/interchain_accounts/host/v1/params`: `{"host_enabled":true,"allow_messages":["*"]}` — **all messages allowed** (MsgSend, MsgTransfer, staking, etc.).
  - Celestia: allowlist includes `MsgTransfer`, `MsgSend`, staking and distribution messages.
- Stride v34.1.0 (live) stakeibc messages that can move/steer funds: none to an arbitrary address. `MsgClearBalance` is **admin-gated (gov/F5)** and sends fee-ICA balances to the fixed Stride fee account (not attacker-profitable). `MsgRestoreInterchainAccount` is permissionless but only re-registers an already-existing ICA (maintenance, not extractive). `MsgUpdateHostZoneParams` (gov) only changes `MaxMessagesPerIcaTx`; `DeprecateHostZone` (gov) only halts a zone.
- **Unreleased main branch** adds `MsgUndelegateFromValidators` (proto comment: “Admin drain of a host zone’s delegations”), `MsgTransferFromIca` (“Admin ICA transfer … receiver and channel are hard-coded constants” — destination = an Osmosis vault), and `MsgSweepTokensOffStride` (“batched sweep of holders’ balances off Stride”). **Not live in v34.1.0** — a monitor item for v35.
- Admin gating is a hard-coded map (`utils/admins.go`): `{gov module stride10d07y265gmmuvt4z0w9aw880jnsr700jefnezl, F5 stride1k8c2m5cn322akk5wy8lpt87dd2f4yh9azg7jlh}`. The F5 address is a **2-of-3 LegacyAmino multisig** (seq 760). Several stakeibc messages (`SetCommunityPoolRebate`, `UpdateInnerRedemptionRateBounds`, `CloseDelegationChannel`, `ResumeHostZone`, `RebalanceValidators`, `AddValidators`, `DeleteValidator`, `ChangeValidatorWeights`) accept the gov module as admin — so a passed proposal can call them; none of them transfers ICA funds to an arbitrary address. The live `x/staketia` module likewise exposes gov/F5-gated record overwrites (`MsgOverwriteDelegationRecord`, `MsgOverwriteUnbondingRecord`, `MsgOverwriteRedemptionRecord`, `MsgAdjustDelegatedBalance`) that can distort stTIA redemption records but not move ICA principal directly.

### 3.6 STRD market (Osmosis — the only venue)
CoinGecko lists only two Osmosis markets for STRD (24h volume **$457 + $42**). On-chain pools holding STRD: gamm **806** (576,784.72 STRD + 113,728.20 OSMO), CL **1098** (88,661.22 STRD + OSMO), CL **1243** (8,342.98 STRD + USDC), alloyed 3493 (6,787.62 STRD), plus dust pools — **≈683k STRD total on-chain**.

SQS router quotes, CI snapshot (`https://sqs.osmosis.zone/router/quote`):

| Buy with OSMO | → STRD | Buy with USDC | → STRD |
|---|---|---|---|
| 1,000 OSMO | 4,932.19 | 1,000 USDC | 129,216.11 |
| 10,000 OSMO | 45,895.59 | 5,000 USDC | 458,874.46 |
| 100,000 OSMO | 273,674.82 | 15,800 USDC | 655,064.62 |
| 434,000 OSMO | 540,967.96 | 30,000 USDC | **752,101.99 (max observed)** |
| 5,000,000 OSMO | **739,591.23 (saturates)** | | |

| Sell STRD | → OSMO | USD |
|---|---|---|
| 100,000 | 17,004.05 | $609 |
| 1,000,000 | 75,142.83 | $2,693 |
| **2,210,000** | **95,059.41** | **$3,407** |
| 3,320,000 | 102,586.40 | $3,677 |

The market cannot deliver the 2,210,219 STRD needed for even the “no other votes” quorum case; the shortfall is **1,458,117 STRD (66.0%)**, and at any larger budget the quotes flatten (the pools run out of STRD; the price runs 3–5× spot). Across two independent snapshots the maximum deliverable was 0.75–0.87M STRD — the conclusion is insensitive to the range.

---

## 4. Attack model — end to end

### Path A — trustless capture by market acquisition (the finding’s claimed path): **INFEASIBLE**
1. Required stake: quorum counts *current* bonded (SDK v0.54.3 `tally.go` uses the sum of active validator power at tally time), and the attacker’s own stake inflates the denominator: X/(B+X) ≥ 0.25 → **X ≥ B/3 = 2,210,219.4 STRD** (=$15,835 at spot) for the best case where nobody else votes; threshold 50% then passes with 100% Yes.
2. Realistic case: upgrades historically draw 3.6–4.6M STRD voting; to outvote a No-coalition the attacker needs >50% of all bonded (≈3.3M STRD) up to doubling the bonded (worst case).
3. Acquisition: the entire Osmosis market can supply ≈0.75–0.87M STRD; the max buy costs ≈$30k for STRD worth ≈$5.4k at spot. **Shortfall 66.0% (CI snapshot).**
4. Exit: selling 2.21M STRD back into the same pools returns ≈95,059 OSMO ($3,407) — a ~78% haircut vs spot. Even if the attacker obtained 2.21M STRD OTC at spot ($15.8k) and passed with zero opposition, net ≈ CP $12.46k + exit $3.41k − $15.8k ≈ **−$0.0k (break-even at best)**, before 14-day unbonding price risk.
5. Verdict: **not executable at any realistic budget; probability ≈0%, high confidence.**

### Path B — capture conditional on a passed proposal (social / vote-buying): **POSSIBLE but low-probability, prize $12,455.09**
- Anyone can submit a `MsgCommunityPoolSpend` proposal for 20,000 STRD deposit (minInitialDepositRatio 0.5 → 10,000 STRD to start the 2-day deposit window; voting starts immediately when the min deposit is met).
- If validators vote Yes (or abstain while the attacker somehow supplies quorum — impossible per Path A), the CP is transferred to any address at the end of the 5-day vote.
- Cost if passed: deposit returned → net cost ≈ transaction fees; prize $12,455.09. If vetoed (33.4%), the deposit is burned (20,000 STRD = $143).
- Feasibility: Stride’s validator community rejects scam proposals (props 267, 274, 275, 281, 282 rejected; prop 282 failed purely on quorum). A disguised spend-to-attacker proposal is public and decodable; a blatant one is rejected. **Low probability; not an E-U path.**

### Path C — malicious `MsgSoftwareUpgrade` (the ~$5M leg): **P (social/validator adoption), not unprivileged**
- A passed upgrade proposal halts the chain at a height and validators restart with the binary they source from the Stride team (prop 284’s plan has an **empty `info` field**; binaries are distributed off-chain/GitHub releases, and validators verify them). A malicious binary could instruct the stakeibc ICA controller to (a) undelegate all host-zone delegations, (b) wait out the host unbonding periods (21 days on the Hub, 21 on Celestia, 14–30 on others), and (c) transfer the funds out — the host allowlists permit it (Hub `["*"]`).
- The attack needs the validator set to run attacker code for weeks while visible on-chain; probability very low. **Exposure ≈$5.05M ICA custody + module balances; not counted as E-U.**

### Path D — validator-weight redirect (latent, P)
- Gov/admin messages (`ChangeValidatorWeights`, `RebalanceValidators`, `AddValidators`) can steer ICA delegations. An attacker running a host-chain validator (Hub active-set floor is only **109.5 ATOM ≈ $196**) could receive the ICA’s stake and take up to 100% commission — a yield-extraction of roughly 5–10% APR on ~2.17M ATOM ≈ **$194k–$389k/yr**, plus the other zones. Requires passing proposals and sustaining capture; detected easily (stToken redemption rate stops growing). Not E-U.

### Time & capital summary
| Path | Capital at risk | Prize | Time | Feasibility |
|---|---|---|---|---|
| A (buy quorum) | ≥$15.8k at spot (unobtainable; market max ~$5.4k of STRD for ~$30k) | CP $12.46k | 5d vote + 14d unbond | **0% — blocked by liquidity** |
| B (social capture) | $143 deposit (refundable) | CP $12.46k | 5d vote | Low |
| C (malicious upgrade) | validator adoption | ≈$5.05M | 21d+ unbond per host | Very low |
| D (weight redirect) | validator entry ~$200+ | ≈$0.2–0.4M/yr yield | weeks–months | Very low |

---

## 5. Verification / “PoC” section

There is no EVM contract to fork, so verification is (1) live-state reads at recorded heights and (2) a reproducible CI job that re-pulls every input and recomputes the model:
- **CI job:** `ci/run.sh` (pull) + `ci/analyze.py` (valuation/cost model) → `ci-out/raw/*.json`, `ci-out/report.json`, `ci-out/report.txt`.
- **CI run:** [`37340699999`](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37340699999) — **success**; log in `ci-log.txt`, artifacts in `ci-artifacts/result-stride/ci-out/` (mirrored into `ci-out/`).
- **No forge tests:** `poc/` intentionally absent — this is a Cosmos chain, not an EVM target; the deliverable is state evidence + arithmetic, fully reproducible from the CI artifacts.
- Key checks reproduced by the job: gRPC gov params (2 nodes), staking pool/supply, CP, HostZoneAll, Hub/Celestia ICA delegations, ICA host allowlists, SQS buy/sell curves, DefiLlama prices, proposal tallies.

---

## 6. Verdict, residual and latent risk; blockers

**Verdict:** E-U = **$0.00** (high confidence). The C2-05 “$48.4k → $5M” capture is not reachable: the market cannot supply the stake for a trustless capture, and the $5M sits behind validator-adopted code changes. The honest maximum an unprivileged attacker can win is the **$12,455.09 CP**, and only by persuading validators to pass a malicious-looking proposal (low probability).

**Blockers (why it is closed today):**
1. **Liquidity:** 2,210,219 STRD required vs ≈0.75–0.87M obtainable (66.0% shortfall at the CI snapshot); buying is 3–5× spot and saturates.
2. **Validator gate:** all other paths (CP spend, upgrade, weights) require the validator set’s votes; historical turnout is 45–70% and scam proposals are rejected.
3. **Live code has no arbitrary ICA-transfer message**; the “admin drain” messages (`UndelegateFromValidators`, `TransferFromIca`, `SweepTokensOffStride`) are only on unreleased `main`.
4. Expedited proposals are unusable (expedited min deposit in non-existent denom `stake`).

**Residual/latent risks to monitor:**
- **v35 upgrade shipping the admin-drain messages** (`MsgUndelegateFromValidators`/`MsgTransferFromIca`) — if gated to the same admins (gov + F5), a future capture would no longer need a software upgrade. If `MsgSweepTokensOffStride` (“sweep of holders’ balances”) ships, user balances become admin-movable — the single most important monitor item.
- **Staketia admin messages (live)**: `x/staketia` exposes gov/F5-gated record/balance overwrites that can manipulate stTIA redemption-rate records (see §3.5). Latent P, same validator/keys gate.
- **F5 2-of-3 multisig compromise** (hard-coded admin for several stakeibc/staketia messages).
- Any new STRD listing/liquidity (CEX, OTC) ≥2.5M STRD would flip Path A economics; re-check if 24h STRD volume rises above ~$100k.
- Celestia custody gap (156,872 TIA chain-state vs on-chain) — reconcile before relying on the $5.05M figure.

**What would change the verdict:** deep STRD liquidity (≥2.5M STRD obtainable near spot), a lowered quorum, a validator cartel, or the v35 admin-drain messages going live.

---

## 7. Methodology, sources, caveats, files

**Method:** all state re-read from public endpoints (cosmos.directory/polkachu LCDs, lavenderfive/citizenweb3 gRPC, Osmosis LCD/SQS, DefiLlama, CoinGecko); Stride v34.1.0 source read from the `Stride-Labs/stride` repo tag v34.1.0 (admin map, msg_server, proto) and unreleased `main` for the forward-looking messages; SDK v0.54.3 `x/gov/keeper/tally.go` for the quorum denominator. Read-only; no transactions; no secrets.

**Caveats:**
- Point-in-time reads (heights 41,148,157 CI / 41,147,534 local pre-run; both in `ci-out/`). Prices from DefiLlama at query time; illiquid stToken valuations approximate.
- The “market max” is venue-dependent; SQS quotes fluctuate between calls (0.75–0.87M STRD across two snapshots). The conclusion is insensitive to this range.
- The gRPC `totalDelegations` for Celestia exceeds on-chain delegations by 156,872 TIA (unresolved); other zones are chain-state values, not individually verified on-chain.
- Path probabilities B–D are judgment calls (stated as such), not measurable facts.
- CP valuation differs from the finding’s $14.5k by ~14% (prices/denoms); exact itemization in `ci-out/report.json`.

**Files:** `README.md` (this), `summary.json`; `analysis/` (raw pulls + scripts incl. denom-hash identification + `source-findings.md`); `ci/run.sh`, `ci/analyze.py`; `ci-out/raw/*.json`, `ci-out/report.json`, `ci-out/report.txt`; `ci-log.txt` (CI log), `ci-artifacts/` (CI artifacts).
