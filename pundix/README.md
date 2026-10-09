# C2-33 — PundiX governance capture: dead-end confirmation

**Campaign:** zombie-hunt II (deep-dive C2-33) · **Chain:** PundiX (`PUNDIX`, Cosmos SDK) · **Date of work:** 2026-10-09
**Status:** read-only research. No transactions signed or sent anywhere. Public keyless LCD/RPC + public price APIs only. CI re-verification on GitHub Actions (public repo).
**Corpus claim under test:** "PundiX governance capture — capture $33.6k vs CP $1.7k — dead end" (`zombie_hunt/ZOMBIE-HUNT-II.md` C2-33; chain advisory context from the C2-26 sweep).

**TL;DR — the dead end is confirmed with corrected numbers.** The community pool is **$1,844.54** and is the *only* asset any governance message can move immediately. The corrected capture cost is **≥ $30,704.73** (campaign-standard `quorum × bonded`) and **≥ $51,174.55** with the exact cosmos-sdk v0.45.11 tally semantics (the attacker's own stake enters the quorum denominator). EV is **−$28.9k / −$49.3k** before gas and market impact — and the required tokens are not even purchasable on-chain (free float 217,406 PUNDIX = 47.6% of the precise requirement; the only route is an IBC bridge-in from fxcore, whose public endpoints return 503). **External-unprivileged extractable: $0.00.**

| # | Target | Live extractable (unprivileged) | Why closed / negative | Latent risk |
|---|---|---|---|---|
| 1 | PundiX gov capture (PUNDIX) | **$0 E-U** · capture prize (P) **$1,844.54 CP**, cost ≥ **$30.7k** naive / **$51.2k** precise | CP is 6.0% of the naive cost and 3.6% of the precise cost; on-chain token float insufficient to reach quorum; bridge-in route (fxcore) currently unreachable | none for E-U; capture becomes rational only if bonded falls ~2.7× *and* the CP grows ~16× — not the case |

**Total live extractable now: $0.00 (high confidence).**

---

## 1. The mechanism in exact terms

PundiX is a Cosmos SDK chain (binary `pundix HEAD-9be0620c…`, cosmos-sdk **v0.45.11**, ibc-go **v3.4.0**, **no wasm**). Governance is gov v1beta1. A captured majority can pass a `CommunityPoolSpendProposal` and pay the community pool to any address — the standard Cosmos capture path.

**Live governance parameters (read at height 28,956,738, 2026-10-09 07:09:47Z, via `/cosmos/params/v1beta1/params?subspace=gov&key=…`):**

| param | live value | note |
|---|---|---|
| quorum | **0.400000000000000000** | SDK v0.45 default; **not** 0.334 (that is the veto threshold) |
| threshold | 0.500 | >1/2 of non-abstaining votes |
| veto_threshold | 0.334 | |
| voting_period | 604,800 s (7 days) | |
| max_deposit_period | 1,209,600 s (14 days) | |
| min_deposit | **3,000 PUNDIX** (≈ $335.67, refunded on pass) | |
| unbonding_time | 1,814,400 s (21 days) | |

**Tally semantics (the decisive correction), verified from the tagged source `cosmos-sdk v0.45.11 x/gov/keeper/tally.go` (sha256 `2877b62f4ab8ae84e7ab4a05dc7b7ec04381d6ac13b93aacfe1538eca3db5375`):**

```go
percentVoting := totalVotingPower.Quo(keeper.sk.TotalBondedTokens(ctx).ToDec())
if percentVoting.LT(tallyParams.Quorum) { return false, true, tallyResults }
```

The quorum denominator is **total bonded tokens at tally time**, and any account may vote (validators with their bonded weight, delegators with their shares). An attacker who buys and stakes X tokens therefore raises the denominator by X while supplying X of the numerator. With zero other voters the pass condition is `X / (B + X) ≥ 0.40`, i.e. **X ≥ (2/3)·B** — not the naive `0.40·B`.

**Capture economics (B = 685,703.5398 PUNDIX bonded, price $0.1119461 DL live):**

| scenario | PUNDIX needed | USD | vs CP |
|---|---|---|---|
| naive `Q×B` (campaign-standard) | 274,281.42 | **$30,704.73** | 16.6× |
| **precise `Q/(1−Q)×B` (v0.45 self-inclusive)** | **457,135.69** | **$51,174.55** | 27.7× |
| majority of cast votes, full bonded turnout voting No | 685,703.54 | $76,724.27 | 41.6× |
| veto-proof against full turnout | 1,367,301.07 | $152,989.12 | 82.9× |

**Proceeds (the whole prize):** community pool = **792,064,621.67 PURSE + 1,840.32 PUNDIX = $1,844.54**. Nothing else is reachable by a gov message (see §2).

**Corpus reconciliation.** The corpus figure $33.6k = `0.40 × 685,703.54 × $0.1225` — the correct live quorum at the Oct-4-2026 price ($0.1222–0.1227). It did not include the self-inclusive denominator correction (true minimum today $51.2k at the lower live price $0.1119; naive today $30.7k). The C2-26 sweep's "~$25,579 to quorum" used quorum 0.334 (the veto default, wrong for this chain). All variants are ≥16× the CP, so the conclusion is invariant.

---

## 2. Live-state assessment (height 28,956,738; all reads public)

| Item | Value | Source |
|---|---|---|
| binary | `pundix HEAD-9be0620c49bb…` · SDK v0.45.11 · ibc-go v3.4.0 · wasmvm: none | node_info / build_deps |
| bond_denom | `ibc/55367B7B…DD78` = PUNDIX ERC-20 `0x0FD10b98…` bridged via fxcore (denom trace `transfer/channel-0/eth0x0FD10b9899882a6f2fcb5c371E17e70FdEe00C38`) | staking params / denom trace |
| bonded | **685,703.5398 PUNDIX** ($76,724.27) — 20 validators | staking pool |
| not-bonded (unbonding queue) | 5,208.8470 PUNDIX ($583) | staking pool |
| total supply (PUNDIX voucher) | **910,159.0594 PUNDIX** ($101,838.89) | bank supply |
| free float (supply − bonded − unbonding − CP) | **217,406.3529 PUNDIX** ($24,337.79) | computed |
| community pool | 792,064,621.67 PURSE + 1,840.32 PUNDIX = **$1,844.54** | distribution community_pool |
| distribution module account | 938,026,316.90 PURSE + 2,119.03 PUNDIX; excess over CP = 145,961,695.23 PURSE + 278.71 PUNDIX = **$333.15 unclaimed staking rewards** (not gov-spendable) | bank balances |
| module accounts (7) | transfer, bonded_tokens_pool, not_bonded_tokens_pool, gov, distribution, mint, fee_collector | auth accounts scan (1,111 accounts total) |
| gov module / fee_collector / mint / transfer balances | **empty** | bank balances |
| IBC escrow ch0 (→ fxcore) | **64,454,393,244.57 PURSE** ($133,334.81) — correct ibc-go v3.4.0 address `px1a53udazy8ayufvy0s434pfwjcedzqv34hargq6` | bank balances |
| IBC escrow ch1 (→ osmosis-1) | 5,075,094.6472 PURSE ($10.50) — `px1kq2rzz6fq2q7fsu75a9g7cpzjeanmk68f5yjsq` | bank balances |
| other user vouchers | Tron USDT $105.70 · fxcore USDT $36.11 · Polygon USDT $9.31 · FX 6,111.96 ($438.85 @ $0.0718) · WETH 0.00925728 ($23.11) · uosmo dust = **$613.07** | supply + denom traces + prices |
| PURSE supply / mint | 67,168,258,486.65 PURSE nominal ($138,948.90 @ $2.0687e-6); mint_denom = PURSE, inflation **27.215%**/yr (max 40%) | bank supply / mint params |
| governance history | 8 proposals, **all passed**; last #8 "Sunset and Full Migration to Ethereum" 2025-12-12→19 (turnout 7.37M PUNDIX; yes 4.63M / abstain 1.13M / no 1.61M); **no active proposal**; current_plan = null | gov v1beta1 |
| validator concentration | Galaxy **301,982.52 (44.04%)**, Jupiter 183,399.48 (26.75%) — top-2 = 70.79%; all 20 @ 3% commission | staking validators |
| chain liveness | block 28.96M, ~5.4 s/block, still producing; ~91–96% of the Dec-2025 stake has exited | blocks / pool |

**Critical address-construction note (correction applied).** ibc-go v3.4.0 derives transfer escrows as `sha256("ics20-1" ‖ 0x00 ‖ "<port>/<channel>")[:20]` (`GetEscrowAddress`, `modules/apps/transfer/types/keys.go`), **not** the plain-path hash. The plain-path addresses read empty; the correct escrows hold **64.45B + 5.08M PURSE**. This does not change the capture verdict (escrows are not gov-spendable) but it corrects the chain's asset inventory materially.

### Gov-movable assets beyond the community pool: none

- **Bonded / not-bonded pools** ($77.3k) are delegator property; no gov spend message touches them.
- **IBC escrows** ($133.3k PURSE) are locked by the transfer module for counterparty voucher holders; only packet processing releases them.
- **Distribution-module excess over CP** ($333) is unclaimed staking rewards owed to delegators — `DistributeFromCommunityPool` is bounded by the CP accounting, not the physical module balance.
- **User balances** (PUNDIX float $24.3k + PURSE float $3.7k + other vouchers $0.6k) are not gov-spendable.
- **Software upgrade** (`MsgSoftwareUpgrade`) could in principle rewrite state, but validators must adopt and run the binary — a privileged, non-autonomous leg (P), not an unprivileged extraction. No upgrade plan is live.

---

## 3. What an attacker can / cannot do

**Can (permissionless):** submit a text/param/CP-spend proposal (min deposit 3,000 PUNDIX ≈ $335.67, refunded on pass); acquire and stake the voucher; vote. If quorum and threshold are met, a `CommunityPoolSpendProposal` executes the transfer of the CP immediately on pass.

**Preconditions that fail today:**
1. **Math.** With no other voters the attacker must stake **457,135.69 PUNDIX** ($51.2k). The naive 274,281.42 ($30.7k) fails the quorum test on this SDK version.
2. **Acquisition.** On-chain free float is 217,406.35 PUNDIX = **47.6%** of the precise requirement (79.3% of naive). The chain has no DEX/AMM (no wasm; 1,111 accounts). The only way to get more is an IBC bridge-in: channel-0 from **fxcore** (voucher origin) or channel-1 from **osmosis-1**. fxcore's public LCD/RPC endpoints (`fx-rest.functionx.io`, `functionx.*.nodeshub.online`) return **503 / NXDOMAIN** as of 2026-10-09 — bridge-in is unverified and plausibly degraded on this sunset asset.
3. **Prize.** $1,844.54 in bridge-voucher tokens, themselves needing an outbound bridge to realize USD. The attacker's principal is recoverable after the 21-day unbonding, but even under zero market impact the prize is 16.6×–27.7× smaller than the capital deployed; a 3.6% adverse move on $51k wipes out the entire proceeds.

**Cannot:** move the bonded pool, the IBC escrows, the user balances, or the unclaimed rewards through any governance message. No `MsgCommunityPoolSpend` can exceed the CP accounting. No wasm module exists (so no contract-admin capture).

**Validator-risk note (P, for completeness):** Galaxy alone holds 44.04% of bonded — above the 40% quorum. A validator-key compromise or bribe of Galaxy (+ enough Yes share) is a *privileged* path that bypasses the token-purchase requirement; it is not an unprivileged capture and no evidence of key compromise exists.

---

## 4. Verification (CI re-run, no fork surface)

Cosmos chains have no EVM fork surface; verification is live-state re-derivation. The same script runs locally and on GitHub Actions:

- `ci/verify.py` — read-only re-derivation of every headline number from `https://px-rest.pundix.com` (gov params, bonded, CP, supply, module accounts, v3.4.0 escrows, prices) + fetch and hash-check of `cosmos-sdk v0.45.11 x/gov/keeper/tally.go` (asserts the `TotalBondedTokens` quorum denominator) — **0 errors, success=true** (heights 28,956,738 → 28,956,750).
- CI run: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37893557238** (workflow `poc.yml`, branch `pundix`) — artifacts in `ci-artifacts/result-pundix/ci-out/` and local `ci-out/`.
- Local analysis pipeline: `analysis/compute.py` → `analysis/params.json`, `analysis/assets.json`, `analysis/capture_economics.json`.

Key CI numbers (identical logic, live prices): quorum 0.40 · bonded 685,703.5398 · CP $1,844.54 · naive cost $30,704.73 · precise cost $51,174.55 · EV −$49,330.02 · escrows $133,345.31 · gov-movable beyond CP **$0.00**.

---

## 5. Verdict, classification, residual risk

| Category | USD | Confidence | Notes |
|---|---|---|---|
| **E-U** (external-unprivileged) | **$0.00** | high | No unprivileged extraction path; capture is negative-EV and capital-constrained |
| **capture (P)** | **$1,844.54** prize; cost ≥ $30,704.73 (naive) / $51,174.55 (precise); EV ≤ −$28,860 / −$49,330 | high | Dead end confirmed; corpus "dead end" label is correct |
| **H-O** (holder-recoverable) | ≈ $101,838.89 PUNDIX-side (bonded+unbonding+float+CP) + $133,345.31 escrowed PURSE backing (fxcore/Osmosis voucher holders) + $613.07 other vouchers | medium (bridge-dependent) | Users can unbond (21 d) and IBC back; fxcore endpoints 503 today |
| **S** (stuck) | $0.00 | high | Nothing bricked |

**Latent risk / monitoring:** (a) a governance-param proposal lowering quorum, or a further ~2.7× collapse in bonded (to < ~256k) would lower the absolute capture cost, but the CP is orders of magnitude smaller and the acquisition problem remains; (b) restoration of the fxcore bridge would restore bridge-in feasibility but not the EV; (c) the C2-26 ibc-go v3.4.0 halt advisory (DoS, $0 gain) remains the only live permissionless chain-level issue on this zombie — tracked there, not here.

**Blockers to a capture today:** quorum math (self-inclusive), token acquisition (float insufficient; bridge-in unreachable), and the negligible prize. Nothing here changes with a state flip short of the CP growing ~16× or bonded falling ~2.7× with tokens purchasable.

---

## 6. Methodology, sources, caveats, files

**Sources:** public PundiX LCD `https://px-rest.pundix.com` (node_info, blocks, staking, distribution, bank, auth, ibc transfer traces, gov v1beta1) and `https://px-json.pundix.com`; x/params REST for gov params (the ABCI/gRPC gov-params route fails on this build — the x/params route works); cosmos-sdk v0.45.11 `tally.go` and ibc-go v3.4.0 `keys.go` from GitHub (hashed); PundiAI/pundix commit `9be0620c…` app/modules source; DefiLlama and CoinGecko prices (PUNDIX $0.1119461 DL live / $0.112057 CG; PURSE $2.0687e-6; FX $0.071802; WETH $2,495.17); DefiLlama historical PUNDIX $0.12223 (Oct 4) for corpus reconciliation.

**Caveats:** point-in-time reads at stated heights; fxcore public endpoints 503 → bridge-in feasibility unverified; PURSE/USD uses the BSC market price and redeemability of the PundiX-chain denom is bridge-dependent; FX voucher priced at the `fx-coin` mark (a PUNDIAI-parity mark would be ~6× higher — still immaterial to the verdict); no fork PoC is possible for a Cosmos chain — verification is live re-derivation + tagged-source checks.

**Files index:**
```
pundix/
├── README.md                      (this file)
├── summary.json                   (machine-readable)
├── analysis/
│   ├── compute.py                 (re-derivation from raw snapshot)
│   ├── params.json                (live gov/staking/mint params)
│   ├── assets.json                (asset inventory incl. modules + escrows)
│   ├── capture_economics.json     (all scenarios, EV, acquisition)
│   ├── snapshot_live.json         (raw consolidated live reads @28,956,602)
│   ├── module_balances.json / module_accounts_full.json / module_and_escrow_addresses.json
│   ├── escrow_balances_v340.json  (correct v3.4.0 escrow addresses)
│   ├── accounts_page1.json / accounts_page2.json  (full 1,111-account scan)
│   ├── params_gov_{voting,tally,deposit}.json, staking_pool.json, community_pool.json, supply.json
│   ├── denom_trace_pundix.json, fxcore_side.json (endpoints 503), dl_prices.json, cg_prices.json
├── ci/
│   ├── run.sh                     (CI entrypoint)
│   └── verify.py                  (independent re-derivation, 0 errors)
├── ci-out/
│   ├── verification.json          (full CI evidence)
│   ├── summary_ci.json
│   └── raw/…                      (raw JSON + tally.go, all public data)
└── ci-log.txt / ci-artifacts/     (written by ci-run.sh)
```
