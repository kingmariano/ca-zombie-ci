# C2-10 · Desmos (desmos-mainnet) — unpatched wasmvm + ibc-go halt surface, and governance-capture economics

**Date:** 2026-10-05 · **Chain:** desmos-mainnet (Cosmos SDK v0.47.10 / CometBFT v0.37.4) · **Status:** read-only; no mainnet transactions; no keys; PoC = deterministic replay + live-state assertions in CI (non-EVM chain, no fork available).

## TL;DR

| target | live extractable (unprivileged) | why closed/open | latent risk |
|---|---|---|---|
| Community pool **16,666,867.9 DSM** (≈$157.0k nominal) | **$0** | governance-only (P); capture cost ≥ $260.8k (best case) vs ≤ $7.28k realizable exit liquidity; top-4 validators hold 83% and vetoed the last CP-spend attempt (prop 46) | if the DSM market ever deepens ≥100× or a strategic buyer appears, re-check |
| wasmvm **1.5.2/1.5.3** + open uploads (CWA-2025-001/002) | **$0** (pure DoS) | permissionless: upload a malicious contract → reliable chain crash; patched only in ≥1.5.8 | chain halt; no theft primitive |
| ibc-go/v7 **7.4.0** (ISA-2025-001 / ASA-2025-004) | **$0** (pure DoS) | permissionless: open an IBC channel + crafted ack → non-deterministic state → halt; patched only in ≥7.9.2/≥7.10.0 | chain halt; no theft primitive |
| IBC escrow 41,366,045 DSM backing Osmosis DSM | $0 (S/P) | no standard gov message can spend escrow; only a malicious software upgrade (validators) | governance-captured upgrade, not unprivileged |

## Total live extractable now: **$0** (confidence: high)

The finding's nominal $155.1k community pool is real, but it is **not extractable by an external unprivileged attacker today**: the only path is governance capture, whose cost (≥$260.8k at spot for the cheapest passing scenario, before market impact) exceeds the immediately realizable value of the pool (≈$7.18k when dumped into all observable DSM liquidity). The two permissionless halt vectors are real, cheap and unpatched, but **a halt moves no funds** (`analysis/halt-extraction-analysis.md`). Categorized: **E-U $0 · P $157.0k (unreachable) · DoS live/$0 extractable · H-O n/a · S n/a**.

## 1. Mechanism, in exact terms

### 1a. wasmvm CWA-2025-001 / CWA-2025-002 (chain crash / slowdown)
- Deployed nodes compile in **wasmvm v1.5.2** (Desmos v7.1.0, `00b333c1`) or **v1.5.3** (v7.1.1, `0e53a67d`) — see `analysis/version-evidence.md`, raw `analysis/nodeinfo-v710.json` / `nodeinfo-v711.json`.
- CWA-2025-001 (GHSA-23qp-3c2m-xx6w): "malicious smart contract can **crash the chain**", affected wasmvm <1.5.8, patched 1.5.8/2.0.6/2.1.5/2.2.2, "can only be triggered *reliably* with a malicious contract".
- CWA-2025-002 (GHSA-mx2j-7cmv-353c): "slow down block production", patched 1.5.8/1.5.10.
- Live preconditions verified: `code_upload_access = ACCESS_TYPE_EVERYBODY`, `instantiate_default_permission = ACCESS_TYPE_EVERYBODY` (gRPC `cosmwasm.wasm.v1.Query/Params`, h 30,863,3xx). **34 wasm codes** already stored (26 with instantiated contracts, ≈60 contracts) — the module is enabled and in use; there is no whitelist, so uploading code 35 (malicious) is one ordinary tx.

### 1b. ibc-go ISA-2025-001 / ASA-2025-004 (chain halt via acknowledgement)
- Deployed **ibc-go/v7 v7.4.0** in both node binaries. Affected <7.9.2 (ASA-2025-004) and <7.10.0 (ISA-2025-001, extends protection to all apps); patched in 7.9.2 / 7.10.0.
- Fix in v7.10.0 `modules/core/04-channel/keeper/packet.go` (`AcknowledgePacket`): reject acknowledgements that do not round-trip through canonical JSON marshalling (`ack.Acknowledgement()` bytes != raw ack bytes). Before the fix, a crafted non-canonical ack drives state/execution divergence → app-hash mismatch → **halt**; release note: "If the vulnerability is exploited before 2/3 is patched, the chain will halt."
- Precondition: *"Any user that can open an IBC channel can introduce this state to the chain."* Desmos v7.1.1 `app/app.go` registers the standard router (`transfer`, `ibc-profiles`, `wasm.NewIBCHandler`, `icahost`, `icacontroller`) with **no channel-opening allowlist**; the deployed binary predates the 2025 workaround, and the attacker can use the permissionless wasm upload to deploy an IBC-enabled contract as the counterparty app.

## 2. Live-state assessment (all read-only, exact heights)

Snapshot: h **30,863,237** (2026-10-05T15:27:47Z) unless noted; CI re-pins (`ci-out/cost-model.json`).

| item | value | source |
|---|---|---|
| app versions | v7.1.1 (wasmvm 1.5.3) / v7.1.0 (wasmvm 1.5.2); ibc-go v7.4.0 both | node_info build_deps |
| bonded | **82,888,768.073014 DSM** | `/cosmos/staking/v1beta1/pool` |
| not-bonded pool | 34,243,060.534512 DSM | same |
| total supply | 193,296,212.545896 DSM | `/cosmos/bank/v1beta1/supply` |
| community pool | **16,666,867.902454 DSM** | `/cosmos/distribution/v1beta1/community_pool` |
| distribution module acct | 20,982,447.738103 DSM (CP + 4.32M unclaimed rewards) | `desmos1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8n8fv78` |
| bonded pool acct | 82,888,768.073014 DSM | `desmos1fl48vsnmsdzcv85q5d2q4z5ajdha8yu3prylw0` |
| not-bonded pool acct | 34,243,060.534512 DSM | `desmos1tygms3xhhs3yv487phx3dw4a95jn7t7l4rcwcm` |
| other module accounts | **0** (profiles/relationships/posts/reports/subspaces/fees/wasm/gov/mint/ibc/transfer/tokenfactory…) | balance scan |
| gov params | quorum **0.334**, threshold **0.5**, veto **0.334**, min deposit **2,000 DSM**, voting **7 d**, deposit period 3 d | `/cosmos/params/v1beta1/params?subspace=gov&key={tally,voting,deposit}params` |
| unbonding | 14 days | `/cosmos/staking/v1beta1/params` |
| inflation | 0 (prop 52, executed 2026-09-26) | mint params + prop 52 |
| wasm | upload Everybody; instantiate Everybody; 34 codes | gRPC wasm queries |
| IBC channel-2 escrow | **41,366,045.204562 DSM** at `desmos12k2pyuylm9t7ugdvz67h9pg4gmmvhn5vt7gzxv` | bank query (escrow address recomputed from ibc-go v7 `GetEscrowAddress`) |
| Osmosis DSM (ibc/EA4C…A46DAD1C) | supply 41,313,379.466221 DSM | Osmosis supply |
| Osmosis DSM pools | 618: 468,058.6 DSM / 2,481.55 ATOM; 619: 310,407.9 DSM / 80,493.8 OSMO; 1559 negligible | gamm pools scan |
| DSM price | $0.00942007 (CoinGecko simple); pool-implied $0.009514 (ATOM) / $0.009337 (OSMO); mcap $900k; 24h vol $17.12 | prices |
| IBC client 07-tendermint-6 (Osmosis) | latest h 71,836,940, consensus ts 2026-10-03T17:01:16Z, trusting period 9 d → alive but relayers sparse | `/ibc/core/client/v1/client_states/...` |

Validators: 16 bonded; top-4 (Apollo, Athena, Artemis, Poseidon) = **68,804,250.596394 DSM = 83.0%** of bonded; they vote on everything (props 50/51/52: 63.6M/76.7M/76.2M Yes). **Prop 46 (Apr 2024)**, a 50M-DSM community-pool spend to its proposer, was **NoWithVeto 42.5M / Yes 0 → vetoed**; props 38/49 also vetoed.

## 3. What an attacker can and cannot do

**Can (permissionless, cheap):**
1. `MsgStoreCode` + instantiate/call a malicious contract → crash the chain (CWA-2025-001). Cost: one tx fee (udsm); no listing/whitelist.
2. Open an IBC channel (standard handshake; or via an uploaded wasm IBC contract) and relay a crafted acknowledgement → halt (ISA-2025-001). Cost: fees + counterparty app.
3. Submit any governance proposal (2,000 DSM deposit).

**Cannot (paths checked and closed):**
- **Extract the community pool without governance.** Only `MsgCommunityPoolSpend` (authority = gov) can spend it; passing it requires quorum 33.4% of bonded = 27,684,848.5 DSM *plus* Yes>50% of non-abstain, with a veto at 33.4% of all votes cast.
- **Buy the quorum on-market.** All observable DSM liquidity = 778,466.6 DSM (≈$7.35k counter-value) across Osmosis pools 618/619 (+negligible 1559). Quorum is 35.6× the total pool reserves → the constant-product cost diverges; **infeasible**.
- **Buy the quorum OTC and profit.** At spot, 27.68M DSM costs **$260.8k**; dumping the attacker's whole bag (quorum + CP = 44.35M DSM) into all pools returns **≈$7.28k**. Net **−$253.5k**. Break-even acquisition price = **$0.000263/DSM = 2.79% of market price**.
- **Survive the validators.** If the top-4 vote plain No, the attacker needs >68.8M DSM Yes ($648.1k at spot); if they vote NoWithVeto, the veto rule forces the attacker above **137.2M DSM** ($1.29M) — more than any observable liquid venue holds (Osmosis holds 41.3M; ~55M DSM is liquid outside pools/CP/stake). See `analysis/tally-simulation.md` (S1–S7) for the exact SDK v0.47.10 tally rules.
- **Extract via a halt.** No theft primitive; IBC timeouts refund senders; no lending/liquidation market to front-run; escrow/backing unaffected. `analysis/halt-extraction-analysis.md`.
- **Seize the IBC escrow or module funds.** No standard gov message spends escrow or other module accounts (all zero except distribution/staking pools).

**Costs:** capture capital is locked 7 days (vote) + 14 days (unbond); veto burns the 2,000 DSM deposit; DoS tx cost is negligible (single-digit USD at most).

## 4. Verification (CI)

- Heavy evidence pull + assertions run on GitHub Actions (`kingmariano/ca-zombie-ci`, workflow `poc.yml`) via `bash /home/heisenberg/CA/ci/ci-run.sh desmos`.
- Files: `ci/run.sh` (pulls versions/params/wasm/IBC/pools), `ci/assertions.py` (16 live assertions incl. "no node patched", "upload Everybody", "quorum > pool reserves", "tally S1 PASS / S2 FAIL / S4 VETOED"), `analysis/cost_model.py`, `analysis/tally_simulation.py`.
- Results: `ci-out/ASSERTIONS.md` (x/y PASS), `ci-out/COST-MODEL.md`, `ci-out/cost-model.json`, raw dumps in `ci-out/raw/`; downloaded to `ci-artifacts/`.
- CI run URLs: _filled after run_ (run 1: evidence pull; run 2: evidence + assertions).
- Non-EVM caveat: no Foundry fork is possible for desmos-mainnet; the "PoC" here is (a) live compiled-in version evidence, (b) exact advisory/patch diff matching, (c) deterministic tally/AMM simulations on live state, (d) live assertion suite. No transaction was sent on mainnet; no exploit was executed against the live chain.

## 5. Verdict, residual/latent risk, blockers

**Verdict:** E-U **$0** (high confidence). The CRIT in the corpus is correct as an *availability* finding (two independent, cheap, permissionless halt vectors on an end-of-line 2024 binary) and as a *governance-capture surface in principle*, but it is **not monetizable today**: the capture cost is ~36× the break-even price and the exit market is ~$7.3k deep, with an 83% validator bloc that vetoes CP spends.

**Residual/latent risk:**
- If DSM liquidity deepens ≥100× (or an OTC buyer of 16–44M DSM appears at near-market prices), capture economics flip — re-check pool depth and CP size.
- A malicious *software upgrade* by captured governance (or validator key compromise) could move escrow/module funds; not unprivileged, not counted.
- The halt vectors will remain live until a new Desmos release (≥wasmvm 1.5.8, ≥ibc-go 7.10.0) is built and adopted — no such release exists upstream (latest v7.1.1, 2024-08-08).
- Off-chain bribery of validators is unquantifiable; prop 46 precedent argues it is resisted.

**Blockers:** no PoC of the memory-safety crash itself (advisory trigger details withheld; read-only rules forbid executing against mainnet); off-chain vectors unmeasurable; CoinGecko delisted the coin mid-research (price cross-checked with pool-implied prices).

## 6. Methodology, sources, files

- All state via public REST/gRPC (`api.mainnet.desmos.network`, `desmos-rest.staketab.org`, `rest.cosmos.directory/desmos`, `lcd.osmosis.zone`, `grpc.mainnet.desmos.network:443`), pinned heights recorded per query. Advisories: GHSA-23qp-3c2m-xx6w, GHSA-mx2j-7cmv-353c, GHSA-jg6f-48ff-5xrw, GHSA-4wf3-5qj9-368v; ibc-go v7.10.0 release notes + compare diff; SDK v0.47.10 `x/gov/keeper/tally.go`; desmos-labs/desmos v7.1.1 `app/app.go`.
- Independent verification: `analysis/verify_market.md` (market/depth), `analysis/verify_dos.md` (DoS preconditions).
- Files: `README.md`, `summary.json`, `analysis/` (version-evidence, advisory-analysis, halt-extraction-analysis, capture-economics, tally-simulation, cost_model.py, tally_simulation.py, nodeinfo dumps, verify_*), `ci/`, `ci-out/`, `ci-artifacts/`, `ci-log.txt`.

**Caveats:** DSM price is thin/illiquid — USD figures are indicative, not realizable at scale; "nominal" always means last-price × amount. Governance capture has unquantifiable off-chain components; the on-chain conclusion is about on-chain acquisition/exit.
