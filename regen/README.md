# C2-27 · Regen (regen-1) — governance-capture deep dive: Toucan NCT bridge claim resolved

**Date:** 2026-10-09 · **Chains:** regen-1 (Cosmos SDK v0.53.6 / regen-ledger v7.3.0), Polygon (bridge contract) ·
**Status:** read-only; no transactions signed or sent anywhere; no fork PoC applicable (Cosmos governance — verification
is live ABCI/LCD state + exact-version SDK source + CI evidence run). No secrets/keyed URLs in this folder.

**CI (re-verification, success):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37947388433 and
https://github.com/kingmariano/ca-zombie-ci/actions/runs/37949300856 —
artifact `ci-artifacts/result-regen/ci-out/regen-evidence.{json,md}`, log `ci-log.txt`.
Snapshots: regen-1 heights **29,202,472 → 29,202,669** (2026-10-09); Polygon block **95,235,089**.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why open / closed | Latent risk |
|---|---|---|---|
| **Regen community pool** (x/protocolpool) — 3,672,761.59 REGEN | **~$3.5k dump-realizable / $6.9k nominal** — *capture*: submit `MsgCommunityPoolSpend` to yourself; cost ≈ 200 REGEN initial deposit (~$0.38, refundable) + gas; passage = validators voting yes | Open path: proposals #63/#77/#78 all passed with **0 no votes**; #77 spent 100,000 REGEN to the proposer's own address (53.6M–0). 12-proposal window: only 5,000 REGEN of dust No (#72), **0 veto** | Whole pool; grows with CP revenue. Top-2 validators (34.0% of bonded) can veto if they object |
| **Capital capture of Regen gov** (buy quorum) | **$0 — negative EV** | Corrected cost **53,971,628 REGEN = $102.1k** (CG) / $131.4k (DL) vs $6.9k proceeds (**14.7×**); needed stake = **1,188% of the entire public DEX float** (4.54M REGEN ≈ $8.6k); 24h volume $3.4k; top-2 bloc can veto | If a large OTC buyer accumulates ~54M REGEN or a validator coalition forms |
| **Toucan "NCT bridge $547.1k"** | **$0** | **Misattribution**: $549.8k is Toucan's *global* TVL (Polygon $325.9k + Celo $159.8k + Base $34.7k + Regen $29.4k). Regen gov controls **none** of those contracts; Polygon bridge roles are operator EOAs | Operator-key compromise (not a gov path) |
| **Regen NCT basket** (`eco.uC.NCT`, 44,331.18 NCT, fully backed) | **$0** | Basket backing is holder-owned: `MsgTake` is signed by the NCT **owner**; gov's only basket message changes fees. Curator ≠ gov, and cannot move backing | Malicious chain upgrade only |
| **Malicious software-upgrade leg** (gov `MsgSoftwareUpgrade`) | **$0 today** | Needs ≥2/3 validator adoption of a hostile binary — the same bloc that can veto; realizable value bounded by ~$8.6k DEX float even if adopted | Nominal $476.4k (all chain assets) if validators ever adopt a hostile binary |
| **Regen staking rewards** (x/distribution module, 16.28M REGEN) | $0 | Unclaimed validator/delegator rewards, **not** community pool; no gov message moves them | Slashing/unbonding risk only |

**Total live extractable now: $0 mechanical E-U; $3,484.87 realizable capture (nominal ≈$6.9k: local model $6,945.23; CI run 2 $6,868.14), confidence medium.**
The finding's two headline numbers are both corrected: "$25.9k to quorum" (wrong formula + old price) and "$547.1k asset"
(not Regen-governance-controlled).

## 2. Finding corrections (exact)

1. **Capture-cost formula.** The finding used `quorum × bonded` = 0.40 × 80,957,442 = 32,382,977 REGEN ≈ $25.9k at the
   2026-10-04 price ($0.0008052). The correct cost includes the attacker's own stake in the quorum denominator
   (SDK v0.53.6 `tally.go`: `totalVotingPower / totalBondedTokens ≥ quorum`, with the attacker bonded):
   `X = q/(1−q)·B = 53,971,628 REGEN` → **$43.5k at the same old price, $102.1k at the current $0.00189, $131.4k at
   DefiLlama's $0.00243**. Moreover the market cannot supply it (below).
2. **Asset claim.** "$547.1k Toucan NCT bridge" = DefiLlama *Toucan Protocol* total TVL across Polygon/Celo/Base/Regen
   ($549,794.66 today; Regen share $29,363.14). Regen governance cannot touch the Polygon/Celo/Base bridge contracts,
   pools, or tokens. Regen-side Toucan value = the NCT basket: 44,331.18 NCT fully backed by 44,331.18 C03 credits
   = $10.2k at market ($29.4k at DefiLlama's stale ~$0.66/tonne). Neither is gov-movable.
3. **What remains live** is the zero-capital governance path to the community pool (below) — a real but small exposure,
   not the claimed $547.1k.

## 3. Mechanism (exact)

Regen's community pool sits in **x/protocolpool** (SDK v0.53.6). A passed proposal can execute
`/cosmos.protocolpool.v1.MsgCommunityPoolSpend` (authority = gov module `regen10d07y265gmmuvt4z0w9aw880jnsr700j9qceqh`)
to any address — decoded verbatim from proposal **#78** (`analysis/raw/abci_prop78.json`: 11 × 36,000,000 uregen to the
11 validators) and proposal **#77** (100,000 REGEN to the proposer's own address).

Tally rules (vendored SDK source `analysis/raw/sdk_tally.go`):
- quorum: `(yes+abstain+no+veto) / bonded_at_tally ≥ 0.40`
- veto: `veto / (yes+abstain+no+veto) > 0.334` → fail + **deposit burned** (`burn_vote_veto=true`)
- pass: `yes / (yes+abstain+no) > 0.50`
- `min_deposit = 2,000 REGEN`, `min_initial_deposit_ratio = 0.10` → 200 REGEN at submission; deposit refunded on plain
  rejection (burn only on veto); 7-day vote, 14-day deposit, 21-day unbonding.
- Expedited proposals are **inert** on Regen (`expedited_min_deposit = 50,000,000 stake` — "stake" is not a denom here).

**Attack path (capture):** acquire ≥200 REGEN (market: ~$0.38) → `MsgSubmitProposal{MsgCommunityPoolSpend(attacker, balance)}`
→ validators vote → payout in 1–7 days. No stake, no validator, no keys required. Historical validator behavior:
12-proposal window: no material No votes (only 5,000 REGEN of dust on #72), **0 veto**; CP spends #63 (43.68M yes), #77 (53.64M yes, self-address),
#78 (53.68M yes) all passed the vote. #80/#81 failed on quorum (28.5M yes < 32.4M needed), not opposition.

**Self-sufficient capture (capital route) is dead:** required 53,971,628 REGEN. Public float across every REGEN market
(Osmosis gamm 1,371,941 + Osmosis CL 52,535 + Base ≈2.22M + Celo ≈0.90M) ≈ **4,544,476 REGEN (~$8.6k)**, 24h volume
$3,359 (CoinGecko). The required stake is 11.9× the entire float; OTC accumulation from large holders would be needed
and would still cost ≥$102k to win $6.9k. The top-2 validators (ecoBridge.earth + Regenerator = 27,530,310 REGEN,
34.0% of bonded) could also veto (33.8% > 33.4%) and burn the attacker's deposit.

## 4. Live-state assessment (block 29,202,669, CI run 2, unless noted)

| Object | Read | Value |
|---|---|---|
| x/protocolpool account `regen1purnwdrhg477r0evks8t5ah7c8thvrssaxmfm8` | balance | **3,672,761.676841 REGEN** |
| x/distribution account `regen1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8ca0qlm` | balance | 16,277,617.93 REGEN (rewards; not CP) |
| gov module `regen10d07y265gmmuvt4z0w9aw880jnsr700j9qceqh` | balance | 0 |
| all other module accounts | balances | 0 |
| staking pool | bonded / unbonding | 80,959,415.153681 / 42,081,171.963265 REGEN |
| bonded validators | 11, tokens sum | 80,959,415.153681 REGEN (top-2 = 34.0%) |
| `eco.uC.NCT` | supply = basket backing | 44,331.178755 NCT = 44,331.178755 C03 credits (7 batches) |
| NCT holders | 74 (bank `denom_owners`) | top holder 38,415.74 NCT (86.7%) |
| Toucan bridge (Polygon `0xdC1Dfa22…11DCC`, blk 95,235,089) | `paused()` = false; `totalTransferred` = 127,379.19 TCO2; roles live | admin `0xCDe1E9f9…`, pauser `0xd4b3e6b9…`, issuer `0x87A13b0A…` (operator EOAs, **not** gov) |
| IBC assets on Regen | supply scan | ~12,472.36 USDC (ch-48) + ~$250 dust — not gov-movable (upgrade-only) |
| REGEN price | CoinGecko / DefiLlama | $0.00188211 / $0.0018787 (was $0.0008052 on 2026-10-04) |

## 5. What an attacker can / cannot do

**Can (unprivileged, live):**
1. `MsgSubmitProposal` + `MsgDeposit` — 200 REGEN to start, 2,000 to enter voting (refunded unless vetoed).
2. Vote their own delegation — no minimum.
3. If validators approve: receive up to the full CP balance; sell on Osmosis/Base/Celo. **Dump-realizable ≈ $3.5k**
   (proportional-split across the $7.8k of counterpart liquidity); nominal $6.9k.
4. Nothing else — no call can move the bridge (Polygon roles), the NCT backing (owner-signed `MsgTake`), staking
   rewards (distribution), or other module accounts.

**Cannot:**
- Buy quorum: required stake 53.97M REGEN ≫ 4.54M REGEN total public float; even a full sweep of every pool yields
  ~2% of the needed amount, and the top-2 bloc can veto.
- Move Polygon/Celo/Base Toucan assets by any Regen proposal (operator EOAs hold all roles).
- Fast-track via expedited proposals (inert denom).
- Move basket backing or change its curator (owner/curator-signed only).

**Latent (P, validator-gated):** a malicious `MsgSoftwareUpgrade` could rewrite any state (nominal chain assets
$476.4k: REGEN supply $451k + NCT $10.2k + IBC ~$12.7k). Requires ≥2/3 validator adoption; validators are exactly the
bloc that can veto; realizable value bounded by the ~$8.6k DEX float. No evidence of any such intent.

## 6. Verification / PoC

No fork PoC is possible for Cosmos governance. Verification = live reads at explicit heights + exact-version SDK source
+ ABCI-decoded proposals, all reproduced in CI:

- `analysis/params-evidence.md` — params/staking/CP/tallies, with raw JSON (`analysis/raw/*`).
- `analysis/bridge-resolution.md` — bridge/NCT resolution and gov-reachability analysis.
- `analysis/model.py` → `analysis/out/model.{json,md}` — full cost/proceeds model.
- `ci/run.sh` → `ci-out/regen-evidence.{json,md}` — reproducible snapshot (public endpoints only).
- CI runs: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37947388433** and
  **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37949300856** (both conclusion: success).

Key decoded evidence: gov params ABCI (`abci_gov_params_v1.json`), prop #78 11×36k REGEN spends (`abci_prop78.json`),
prop #77 self-address spend + its text (`abci_prop77.json`), SDK tally source (`sdk_tally.go`), SDK v0.53.6
distribution "external community pool" string (`sdk_dist_grpc.go`), bridge deployment/args/source (`toucan_*`),
Osmosis pools (`osmosis_pools.json`, `osmosis_cl_pools.json`), GeckoTerminal pools (`gt_*.json`).

## 7. Verdict

- **E-U (mechanical): $0.00.** No permissionless contract/module bug; all funds are where they belong.
- **Capture: $3,484.87 realizable / ~$6.9k nominal (medium confidence)** — a ~$0.38-deposit CP-spend proposal to the
  attacker, gated by validators who have passed every CP spend with 0 no votes (including a self-addressed one).
  This is the only live unprivileged extraction path and it is *not* the $547.1k the finding claimed.
- **Capital capture: negative EV** (−$95.1k at current price; cost 14.7× proceeds; unfillable float; veto risk).
- **P:** community pool (same $6.9k, gov-only) and the latent upgrade leg (nominal $476.4k, validator-adoption-gated).
- **H-O:** NCT basket 44,331.18 NCT = $10,200.80 (holder-redeemable); staking rewards 16.28M REGEN (staker-claimable).
- **S:** none material.
- **Residual / latent:** CP grows with revenue; if validators ever start voting no (or a whale accumulates 54M REGEN
  OTC), the picture changes. Monitor `MsgCommunityPoolSpend` proposals and validator turnout (recent quorum misses at
  28.5M yes show turnout is close to the 32.4M quorum line).

## 8. Methodology & sources

Public keyless endpoints: `regen-api.polkachu.com` (LCD), `regen-rpc.polkachu.com` (ABCI), `lcd.osmosis.zone`,
`api.geckoterminal.com`, `coins.llama.fi`, `api.coingecko.com`, `api.llama.fi`, `polygon-bor-rpc.publicnode.com`.
Primary sources: cosmos-sdk **v0.53.6** `x/gov/keeper/tally.go`, `x/distribution/keeper/grpc_query.go`; regen-ledger
**v7.3.0** proto files (`proto/regen/ecocredit/{basket/v1,v1}/tx.proto`); `github.com/regen-network/toucan-bridge`
(master). All reads recorded with heights in §4 and `ci-out/`.

**Caveats:** USD values move with REGEN/NCT prices (REGEN swung $0.0008→$0.0024→$0.0019 during the campaign);
the capture headline is conditional on validator behavior (a judgment, not a measurement — precedent is strong but
not proof); the $3.5k realization is a proportional-split estimate over pool counterpart liquidity; `targets_checked`
counts distinct on-chain objects read and is approximate. Nothing here is investment or legal advice; re-verify
on-chain before acting.

## 9. Files index

```
regen/
├── README.md                      # this file
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── params-evidence.md         # gov params / staking / CP / tallies (citations)
│   ├── bridge-resolution.md       # Toucan bridge + NCT basket resolution
│   ├── model.py, decode_proto.py  # cost model + protobuf decoder
│   ├── out/model.{json,md}        # computed model
│   └── raw/                       # all raw LCD/ABCI/GitHub dumps (public data only)
├── ci/run.sh                      # keyless re-verification job (ran in CI)
├── ci-out/regen-evidence.{json,md}# CI-produced evidence
├── ci-log.txt, ci-artifacts/      # CI log + downloaded artifact
```
