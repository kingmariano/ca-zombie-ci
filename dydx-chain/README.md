# C2-34 · dYdX chain — ibc-go v8.5.1 halt advisory (ISA-2025-001 / ASA-2025-004)

**Campaign:** zombie-hunt II · **Chain:** dYdX chain (`dydx-mainnet-1`, Cosmos appchain) · **Date of work:** 2026-10-09
**Status:** read-only; no transactions signed or sent on any network; no secrets in this folder. Cosmos chains have no EVM-fork surface — evidence is public RPC/LCD reads at pinned heights + public GitHub source verification, re-derived by the CI job in `ci/` (`ci-out/` artifacts).

**Headline:** the live dYdX chain **is not affected** by the ibc-go halt advisories. Its build info self-reports `github.com/cosmos/ibc-go/v8 v8.5.1` (inside both vulnerable ranges), but the binary is built from dYdX's vendored fork `github.com/dydxprotocol/ibc-go/v8` at commit **8733b3edf43a** (2025-03-12), and **both fix checks (ASA-2025-004 and ISA-2025-001) are present in that exact commit**. External unprivileged extraction = **$0**, and the DoS vector is **closed**; residual risk is monitor-only (a future release dropping the replace / regressing the fork).

---

## 1. TL;DR

| Surface | Live status | Why closed / open | Latent risk |
|---|---|---|---|
| **ibc-go halt advisory (ISA-2025-001 + ASA-2025-004)** on dYdX | **CLOSED — patched** | Effective code = `dydxprotocol/ibc-go` fork @ `8733b3edf43a`, which contains both upstream fix hunks (`AcknowledgePacket` core check + transfer `OnAcknowledgementPacket` check). Live v9.7.0/9.7.1 binaries pin that commit; module sum is empty in build info (replaced dep) | If a future protocol release stops replacing ibc-go (or regresses the fork) while staying on a v8 base `< 8.6.1`/`< 8.7.0`, the permissionless crafted-ack halt vector reopens. Monitor `protocol/go.mod` replace line + the two fix markers per release |
| **DoS monetization** | **$0** | Halt is liveness-only; neither advisory describes a theft/fund-loss primitive; ack validation rejects the tx instead of halting. No value converts to an attacker | A halt (if it ever occurred) would freeze ~**$70.77M USDC** (Noble, channel-0) + stDYX supply + all perp positions — damage, not profit |
| **Gov capture (completeness)** | **negative EV** | Quorum = **50%** of bonded (recently raised by prop 392) = **142,967,079 DYDX ≈ $19.42M** at spot, against 24h volume ~$6M; gov-spendable pots ≈ **$23.3M nominal** (community treasury + rewards treasury + insurance fund, spendability per child analysis) | Same as any live gov chain; capture cost ≈ or > assets, plus 21-day unbonding lockup and veto risk |

**Total live extractable by an external unprivileged attacker: $0.00** (confidence: **high** for the patched-status claim — two independent nodes + pinned source + byte-level fix markers; see §5).

## 2. The bug/mechanism in exact terms

Both advisories are the same class: **non-deterministic JSON unmarshalling of an IBC acknowledgement in `AcknowledgePacket` → consensus divergence → chain halt**. Any user who can open an IBC channel can introduce the state; the workaround is permissioning channel opening.

- **ASA-2025-004** (GHSA-jg6f-48ff-5xrw, 2025-02-27, critical): affected ibc-go `< 7.9.2` (v2–v7 lines) and **v8 `< 8.6.1`**; fix **v8.6.1** in `modules/apps/transfer/ibc_module.go` — after unmarshalling, the transfer module re-marshals the ack and requires `bytes.Equal(re-marshalled, supplied)`.
- **ISA-2025-001** (GHSA-4wf3-5qj9-368v, 2025-03-12, high): affected `< 7.10.0` (v2–v7) and **v8 `>= 8.0.0-alpha.1 < 8.7.0`**; fix **v8.7.0** in `modules/core/04-channel/keeper/packet.go` — the same round-trip byte-equality check at the core level, covering all applications beyond transfer. OSV GO-2025-3517 maps the affected symbol to `modules/core/04-channel/keeper.Keeper.AcknowledgePacket`.

The fix semantics are the key: an acknowledgement whose canonical re-marshalling differs from the supplied bytes is rejected (`ErrInvalidAcknowledgement`, "acknowledgement marshalling error") **before** proof verification/app callback. Pre-fix, such non-canonical acks could be processed into non-deterministic state → app-hash divergence → halt. The advisories describe **no fund-loss primitive** — the impact is chain liveness only.

## 3. Live-state assessment (all reads 2026-10-09, ~07:00–07:15Z; height ~108,685,800)

| Check | Result | Source |
|---|---|---|
| Chain / height | `dydx-mainnet-1`, latest height 108,685,828 @ 2026-10-09T07:02:32Z | public RPC `status` |
| Node app version (2 independent nodes) | **9.7.1** (git 5935cb7c5dd684b17836e75093fc5c3ca5019ea3, publicnode) and **9.7.0** (git 67a3c71670c460ef92ffb15930dda7047a901f64, polkachu) | `/cosmos/base/tendermint/v1beta1/node_info` |
| ibc-go build dep | `github.com/cosmos/ibc-go/v8 v8.5.1`, **sum empty** (replaced module; cosmos-sdk, cometbft, iavl also empty-sum = replaced) | node_info `build_deps` |
| go.mod replace (tags v9.7.0, v9.7.1, main) | `github.com/cosmos/ibc-go/v8 => github.com/dydxprotocol/ibc-go/v8 v8.0.0-rc.0.0.20250312180215-8733b3edf43a` | raw.githubusercontent.com dydxprotocol/v4-chain |
| Fork fix — ASA (transfer) | `modules/apps/transfer/ibc_module.go` lines 245–247: `bz := types.ModuleCdc.MustMarshalJSON(&ack); if !bytes.Equal(bz, acknowledgement) { … "acknowledgement did not marshal to expected bytes" }` inside `OnAcknowledgementPacket` | fork @ 8733b3edf43a |
| Fork fix — ISA (core) | `modules/core/04-channel/keeper/packet.go` lines 431–435: `if err == nil { ackBz := ack.Acknowledgement(); if !bytes.Equal(ackBz, acknowledgement) { … "acknowledgement marshalling error" } }` inside `AcknowledgePacket` (line 358) | fork @ 8733b3edf43a |
| Ack-deserializing middleware | none — build deps have no ibc-hooks / packet-forward-middleware / wasm | node_info build_deps (247 deps) |
| Current upgrade plan | `current_plan = null`; **prop 398 "Software Upgrade v9.8" in voting** (submitted 2026-10-08, ends 2026-10-11T02:23Z; plan height 109,170,000; yes 161.4M / abstain 15.5M / no 0 — quorum met). v9.8.0 source not yet public at read time | `/cosmos/gov/v1/proposals/398`, `/cosmos/upgrade/v1beta1/current_plan` |
| IBC state | **123 channels** (76 OPEN, 42 CLOSED, 5 TRYOPEN; ports: icahost 83, transfer 40) and **47 connections** (40 OPEN); channel opening is **permissionless** (only IBC params-updates are gov-only internal msgs); largest IBC asset: Noble USDC via `transfer/channel-0`, total supply **70,772,323.76 USDC** | LCD `/ibc/...` + bank supply; `analysis/ibc_state.json` |

## 4. What an attacker can / cannot do

- **Cannot** halt dYdX via a crafted acknowledgement: the pinned fork rejects non-canonical acks at both the core (`AcknowledgePacket`) and transfer (`OnAcknowledgementPacket`) layers; the offending `MsgAcknowledgement` fails as a normal tx error while block production continues.
- **Cannot** extract any value via this advisory class: no theft primitive exists (liveness-only impact; the fix is a validation error path).
- **Could** (historically, if unpatched) have opened an IBC channel (channel opening is permissionless by default — see reachability analysis) and introduced a non-canonical ack, halting the chain for $0 gain. This is the latent-risk scenario if the replace is ever dropped.
- **Gov capture** (completeness, negative EV): acquiring 50% of bonded DYDX = 142.97M DYDX ≈ **$19.42M at spot** ($0.13582) vs **$23.33M nominal gov-spendable** (community treasury $10.83M + rewards treasury $4.41M + insurance fund $8.08M + community pool ~$0.0002M), with DYDX 24h volume ≈ $5.9M (**3.29× ADV** to acquire), a 21-day unbonding lockup, and a 33.4% veto threshold. Spendability is code-verified: `dydxprotocol.sending.MsgSendFromModuleToAccount` is a gov-only internal msg whose only blocked senders are the two staking pools and `subaccounts` — **community_treasury is proven spendable** (prop 390 sent 357,142.71 DYDX from it on 2026-07-07); rewards_treasury and insurance_fund pass the same guard (no precedent). The `bridge` module account (41.66M DYDX ≈ $5.66M user-backed escrow) is also *not* protected — flagged as a broader governance-authority observation (not counted in the headline). Realizable value is below nominal because 87% of the non-USDC pot is DYDX. See `analysis/gov-economics.md`.

## 5. Verification / CI

No EVM fork applies (Cosmos chain). Verification = source-level fix-marker checks at the exact pinned commit + live node build-info reads, re-derived reproducibly by the CI job:

- CI job: `ci/run.sh` → `ci/verify.py` (public endpoints only; stdlib; no secrets) → `ci-out/verification.json`, `ci-out/summary_ci.json`.
- CI run URL: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37897247041** (conclusion: success; artifact `result-dydx-chain.zip`; CI-verified at height 108,686,391 @ 2026-10-09T07:08:21Z: app 9.7.0/9.7.1, ibc-go v8.5.1 empty sum, **fork transfer fix present = true, fork core fix present = true**, quorum cost $19,417,902.93, gov-spendable nominal $23,326,382.85).
- Module-artifact check (`analysis/module-artifact-check.md`): the content-addressed Go module zip for `dydxprotocol/ibc-go/v8@v8.0.0-rc.0.0.20250312180215-8733b3edf43a` contains both fix markers, and its dirhash `h1:aF1rORtUApr+N6dWsNiT/G9H2ysfjyj5DiVRU8CRDaU=` **matches the go.sum entry in v4-chain `protocol/v9.7.1`** — i.e., the exact artifact the live binary was built against is patched.
- Child verifications (independent): `analysis/fork-patch-verification.md` (fork commit + release matrix), `analysis/gov-economics.md`, `analysis/ibc-reachability.md`.

## 6. Verdict, residual risk, blockers

- **E-U: $0.00** — advisory does not apply in effect (patched via vendored fork); confidence **high**.
- **DoS: $0.00 realized** — closed; latent only under a future regression. If it ever occurred (hypothetically unpatched), it would freeze 70,772,323.76 USDC + ~$38.95M perp open interest for $0 attacker gain.
- **Capture: negative EV** — quorum cost $19.42M at spot (3.29× ADV) vs $23.33M nominal gov-spendable, with 21-day unbonding and veto risk; not counted as extractable.
- **P: $0** — no external privileged path; the treasury/insurance/bridge module accounts are gov-gated (spendability detail in `analysis/gov-economics.md`; bridge escrow flagged as a broader observation).
- **Residual/latent risk:** (1) monitor each dYdX protocol release's `protocol/go.mod` replace line and the two fix markers at the pinned commit; (2) prop 398 (v9.8) upgrade should be re-checked once its source/binary pin is public; (3) if dYdX ever un-forks to upstream ibc-go, the required floors are **≥ 8.6.1 (ASA) and ≥ 8.7.0 (ISA)**; (4) the fork base is upstream v8.0.0 + cherry-picks — future upstream v8 security fixes must be assumed *not* present unless cherry-picked.
- **Blockers:** none — the path is closed by code, not by capital or permissions.

## 7. Methodology & sources

- Live reads: public LCD/RPC only (`dydx-dao-api.polkachu.com`, `dydx-rest.publicnode.com`, `dydx-rpc.publicnode.com`); heights/times recorded. No keyed endpoints written to files.
- Source: `raw.githubusercontent.com` files at pinned refs (`dydxprotocol/ibc-go@8733b3edf43a`, `cosmos/ibc-go@v8.5.1/v8.6.1/v8.7.0`, `dydxprotocol/v4-chain@protocol/v9.7.x`, `@main`); GitHub Advisory Database (`GHSA-jg6f-48ff-5xrw`, `GHSA-4wf3-5qj9-368v`); OSV GO-2025-3517.
- Gov: `/cosmos/gov/v1/*`, `/cosmos/staking/v1beta1/*`, `/cosmos/bank/v1beta1/*`, `/cosmos/distribution/v1beta1/community_pool`, module accounts via `/cosmos/auth/v1beta1/module_accounts`.
- Prices: `coins.llama.fi` + CoinGecko (`dydx`) at 2026-10-09 ~07:05Z.

### Caveats

- Build deps are self-reported by nodes; corroborated on **4 independent public endpoints** (publicnode, polkachu ×2, kingnodes) + pinned go.mod + the **go.sum dirhash match** against the proxy.golang.org module zip (content-addressed). No reproducible binary build was performed, but the replace directive + empty build-info sum + hash-pinned artifact + four agreeing nodes is strong evidence.
- The exact internal reason Go's JSON handling diverges is not spelled out in the public advisories; the fix (round-trip byte equality) is the authoritative statement of the vulnerable condition.
- USD figures are point-in-time at ~$0.1358/DYDX.

## 8. Files

```
dydx-chain/
├── README.md                       (this file)
├── summary.json
├── analysis/  advisory-mapping.md (advisory ranges + live mapping + fix code),
│              fork-patch-verification.md + fork-version-matrix.json (all v8.x/v9.x tags → fork commit → fix presence),
│              module-artifact-check.md + fork-module-zip.sha256 (proxy zip ↔ go.sum hash),
│              gov-economics.md + gov_economics.json (params, balances, spendability, capture cost),
│              ibc-reachability.md + ibc_state.json (channel opening permissioning, 123 ch/47 conn),
│              node_info_dydx_*.json (4 endpoints), raw/ (raw LCD + GitHub fetches, manifest.tsv)
├── ci/        run.sh, verify.py
├── ci-out/    verification.json, summary_ci.json, runner.log (CI artifacts)
├── ci-log.txt (CI log, written by the helper)
└── ci-artifacts/
```
