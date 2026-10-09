# C2-31 — Nolus (pirin-1): governance-capture economics — is the capture profitable?

**Campaign:** zombie-hunt II · **Chain:** Nolus `pirin-1` (Cosmos SDK / CosmWasm) · **Date:** 2026-10-09
**Status:** read-only research; **no transactions signed or sent**; all evidence from public LCD/RPC/API reads.
**Primary state:** block `27,319,088` (2026-10-09T06:38Z), reads to ~08:15Z; gov params via ABCI at `27,319,295`.
**CI re-verification:** block `27,324,402` (14:58Z), run [37948203035](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37948203035) (success).

**TL;DR — an external, unprivileged attacker can extract $0 live. Governance capture exists, but the
"$272k to capture $895k" claim is wrong in both directions: the quorum-corrected floor is ~$390k (spot,
unrealistic), validator opposition implies $0.62M–$1.19M+, and — decisively — NLS float depth makes any
capital capture deeply unprofitable (visible MEXC ask book = 2.2M NLS vs 106.6M+ needed; all-venue 24h
volume $62k). The CP's $895k nominal is 240.0M NLS tokens with an immediate market value of ~$1.9k and
$0.05 of stables. The residual risk is a low-capital *validator-deception* path (wasm params + malicious
code migration), mechanics proven on-chain, bounded by the same liquidity to ~$118k liquid.**

| # | Surface | Live extractable (E-U) | Why closed/open | Latent risk |
|---|---|---|---|---|
| 1 | **Capital capture** (buy stake → vote CP-spend) | **$0** | Quorum floor = 106.6M NLS = $389k (own-stake correction); empirical hostile-vote bloc = 162.3M NWV ⇒ needs 324.7M NLS = $1.19M to survive veto. All-venue depth is 2.2M NLS asks / $62k/day ⇒ acquisition cost multiples of spot; proceeds are 93%+ illiquid NLS | If NLS liquidity deepens (CEX listing), capture could flip positive |
| 2 | **CP spend** (MsgCommunityPoolSpend) | $0 (governance-only) | CP = 240,000,000.95 NLS + $0.05 dust. Immediate sale of 240M NLS ≈ $1.9k (MEXC bids); slow-sale $200–600k optimistic | Same as above |
| 3 | **Malicious-code migration** (gov sudo path) | $0 (governance-only) | Mechanics proven: wasm authority = gov (can open code upload); `migrate_contracts` honors explicit `code_id` incl. platform `treasury` (props 277/299/306/313/329/345); versioning checks are self-attested by target code. Requires validators to approve visibly non-team proposals | Real: treasury 152.0M NLS + LPP $118.3k; bounded by liquidity |
| 4 | Module accounts / bridges / ICA | $0 | Only distribution (CP) is gov-spendable; fee pool = delegator rewards; vestings/wasm empty; IBC escrow is user funds; Osmosis/Neutron markets sunset (~$0) | Software upgrade only (P, needs validator adoption) |
| 5 | Solana-side positions (~$228k, DefiLlama 10-04) | $0 (not reached) | Held on Solana behind remote-lease controller + relayer; no permissionless path; gov reach via `remote_lease` migration unverified | Medium-low: extend if relayer trust model is weak |

**Total live extractable by an external unprivileged attacker: $0.00** (confidence: high).
**Governance-movable nominal: ~$1.55M** (392.0M NLS = 42% of supply + $118k carried assets), **liquid: ~$118k**.
**Capture verdict: NOT profitable via capital (high confidence); residual deception risk real but
liquidity-bounded (medium confidence).**

---

## 1. The finding and what was claimed

`zombie_hunt/ZOMBIE-HUNT-II.md` C2-31 claims: *Nolus governance capture — capture cost $272k vs
community pool $895k — capital-heavy*. The claimed $272k = 33.4% (quorum) × 212.5M bonded × spot price
(≈70.98M NLS × $0.00365 = $259k; at the corpus' price ≈$272k). This ignores: (a) the attacker's own
stake in the quorum denominator, (b) validator/delegator opposition and the veto threshold, (c) NLS
float depth, (d) what the CP actually is (NLS tokens, not cash) and its liquidation depth.

## 2. Live-state assessment (exact reads)

### 2.1 Governance parameters (ABCI `/cosmos.gov.v1.Query/Params`, h 27,319,295)

| Param | Value |
|---|---|
| quorum / threshold / veto | **33.4% / 50% / 33.4%** |
| voting period / max deposit | **3 days** / 10 days |
| min_deposit | **200 NLS** (~$0.73) |
| expedited | 300 NLS, 1-day vote, 66.7% threshold |

### 2.2 Staking & validators (LCD, h 27,319,1xx)

- bonded **212,518,285.80 NLS**; not-bonded pool 57,403,690.09 NLS; unbonding **21 days**; 19 validators.
- top-1 28.60M (13.5%), top-3 78.59M (37.0%), top-5 119.4M (56.2%) of bonded.
- During the day, bonded grew to **217.16M** (CI, h 27,324,402) — +2.2% (defensive/ops bonding; raises the bar).

### 2.3 NLS market (CoinGecko + MEXC + Osmosis LCD, 2026-10-09)

- price **$0.00364916** (primary; $0.003670 at CI), mcap ~$3.25M, total supply 922.94M NLS.
- **all-venue 24h volume $62.4k**: MEXC $57.1k, Raydium CLMM $5.25k, Osmosis $23.
- MEXC NLS/USDT order book: **asks = 2.158M NLS total** (1.85M within 2× mid; tail orders at absurd
  prices up to $200M/NLS), **bids = $1,926 total**. Osmosis NLS pools total ~7,020 NLS (~$26).
- No NLS lending/derivative market ⇒ no leverage/flash path to acquire voting stake.

### 2.4 Community pool & treasury (LCD)

- CP (`/cosmos/distribution/v1beta1/community_pool`): **240,000,000.95 NLS** + micro-unit dust
  (6,529.91 µUSDC-noble + 22,947.40 µUSDC + 9,320.10 µATOM + 15,793.91 µOSMO + 8,057.09 µNTRN ≈ **$0.05**).
  Cross-check: distribution module account = 246.15M NLS (CP + ~6.15M fee pool/outstanding rewards).
- Protocol **treasury contract** `nolus14hj2tavq8fpesdwxxcu44rty3hh90vhujrvcmstlzr3txmfvw9s0k0puz`
  (code 911): **152,008,181.07 NLS** (+$2.6 dust), growing ~130 NLS/h — it receives 100% of base-denom
  tx fees (`x/tax` `fee_rate=100`, gov-updatable).

### 2.5 Protocol contracts (78 created by Admin contract `nolus1gurg…`, admin of all = Admin contract)

| Contract | Balance | USD (spot) |
|---|---|---|
| treasury (911) | 152,008,181.07 NLS | ~$554.7k |
| SOLANA-METIS-USDC-lpp | 97,093.07 USDC (solray carrier) | $97.1k |
| SOLANA-METIS-SOL-lpp | 93.744 SOL | $14.1k |
| SOLANA-METIS-CB_BTC-lpp | 0.10651540 cbBTC | $6.4k |
| SOLANA-METIS-WETH-lpp | 0.32499733 WETH | $0.8k |
| legacy Reserve/leaser/oracle/profits | 5 NLS / 1 NLS / dust | <$0.03 |
| other 70 contracts | 0/dust | ~$0 |

Decimals validated by cross-check with DefiLlama (Nolus-chain idle TVL $116,876 on 2026-10-04 ≈ measured
$118.3k). Module accounts: only `distribution` holds spendable value (the CP); `vestings`, `wasm`,
`fee_collector`, `interchainaccounts` are empty.

### 2.6 Governance history (100 proposals, ids ~275–374)

99 PASSED / 1 REJECTED; turnout 93.4M–183.1M NLS (median 150.1M ≈ 71% of bonded). Every pin/migrate/
upgrade proposal: **100% Yes**. The single hostile proposal (295, airdrop scam) was rejected with
**NoWithVeto = 162,331,398 NLS** — the empirical opposition bloc. No `MsgCommunityPoolSpend` has ever
executed (tx search: 0 results).

## 3. What an attacker can/cannot do — exact call paths

### 3.1 Capital capture (buy → bond → vote)

1. Buy A NLS on market; 2. `MsgDelegate` to own validator(s); 3. `MsgSubmitProposal` (deposit 200 NLS);
4. vote Yes; 5. if passed, `MsgCommunityPoolSpend` pays the CP to the attacker (executes on pass);
6. `MsgUndelegate` (21 days) and sell.

Costs with the standard corrections (primary numbers; CI in parentheses):

| Model | NLS needed | USD at spot |
|---|---|---|
| Claim basis (33.4% × bonded) | 70.98M | $259k ($266k) |
| **Quorum floor, own-stake corrected** A ≥ B0·q/(1−q) | **106.58M** | **$389k ($400k)** |
| Threshold vs 80% turnout No | 170.01M | $620k ($638k) |
| **Veto survival vs empirical 162.3M NWV** A ≥ 2×NWV | **324.66M** | **$1,185k ($1,192k)** |
| All validators NWV at 80% turnout | 347.46M | $1,241k ($1,275k) |

Float-depth correction: 106.6M NLS = 49× the entire visible MEXC ask book; at 20% of all-venue daily
volume it takes ~31 days of continuous buying (at 100%, ~6.2 days) while the attacker's own demand lifts
the price (MM replenishment above the visible ladder). Stress: 3× spot ⇒ $1.17M floor / $3.6M veto case;
10× ⇒ $3.9M / $11.8M.

### 3.2 The proceeds side (why even a "successful" capture pays little)

- CP = 240.0M NLS tokens. Immediate market sale recovers ~**$1.9k** (MEXC bids); distributing 42% of
  supply (392.0M NLS total in CP+treasury) into a $62.4k/day market over months, at $0.0015/$0.001/$0.0005
  average price, recovers $588k/$392k/$196k — all optimistic (price would keep collapsing).
- The attacker's own purchased stake (106.6–324.7M NLS) needs the same exit, plus 21-day unbonding.
- Net vs liquid proceeds only: floor **−$271k**, empirical-veto **−$1.07M**, floor-at-3×-slippage **−$1.05M**.
  Adding optimistic NLS slow-sale still leaves the floor case ≈ break-even before slippage and the
  realistic case deeply negative. **Capital capture is uneconomic.**

### 3.3 Residual: low-capital validator-deception path (mechanics proven, success unproven)

All primitives verified on-chain/in the chain source:

1. **wasm keeper authority = gov module account** (`app/keepers/keepers.go` passes
   `authtypes.NewModuleAddress(govtypes.ModuleName).String()` to `wasmkeeper.NewKeeper`) ⇒ a passing
   proposal can run `MsgUpdateParams(wasm)` and open `code_upload_access` (currently `AnyOfAddresses`:
   Admin contract + team EOA `nolus1klq25…`).
2. Attacker stores malicious code (implements `migrate` → `BankMsg::Send` its balance out; its
   `platform_package_release` query self-reports the expected release/storage strings, satisfying the
   Admin contract's versioning checks, which are self-attested by the target code).
3. A follow-up proposal (or the same bundle, since proposal messages execute sequentially): `MsgPinCodes([X])`
   + `MsgSudoContract(Admin, migrate_contracts{to_release, migration_spec with explicit code_id X})` for
   the **treasury** and LPP contracts — explicit platform `treasury` code_ids are proven in props
   277/299/306/313/329/345; protocol explicit code_ids in props 371/373. (The params-update → store-code
   → pin → migrate sequence is potentially bundleable into a single proposal; the conservative reading is
   two proposals because the Admin contract may require the target code to be registered/pinned first.)
4. Drains: 152.0M NLS + $118.3k carried + dust. Capital cost ≈ 200 NLS deposit per proposal (~$0.73;
   the whole sequence is potentially bundleable into a single proposal).

Constraint: validators must vote Yes on two proposals that are visibly not team-submitted. Empirically
they approve every routine proposal 100% Yes and crushed the one hostile proposal with 162.3M NWV —
so this path's success is a function of validator diligence, unprovable in a read-only study. Even if
successful, realizable proceeds are bounded by liquidity to ~$0.1–0.6M.

## 4. Verdict & classification

| Class | Amount | Confidence | Note |
|---|---|---|---|
| **E-U** (external unprivileged) | **$0.00** | high | no permissionless path; all value behind gov or remote systems |
| **capture** | capital path: unprofitable; deception path: mechanics proven | high (mechanics) / medium (deception success) | bounded by NLS liquidity |
| **P** (governance-movable nominal) | CP 240.0M NLS (~$880.8k) + treasury 152.0M NLS (~$557.9k) = **~$1.44M**; + LPP $118.3k via migration | high | at spot; not cash |
| **H-O** (holder/LP claims) | ~$118.3k LPP on-chain + ~$228k Solana-side (DefiLlama 10-04) | medium | self-service claims, not attacker-extractable |

**The C2-31 headline should be corrected to:** *capture cost ≥$389k (not $272k) in the best case and
$0.62–1.19M with realistic opposition; proceeds are 93%+ illiquid NLS with ~$1.9k immediate depth;
capital capture is net-negative. Residual risk is governance-integrity (validator deception), not
capital economics.*

## 5. Evidence, CI & reproducibility

- `analysis/params.md` — all params/facts with sources; `analysis/capture_model.md` — the model narrative.
- `analysis/model.py` — deterministic model; reads raw JSON, writes `capture_model.json` + `asset_inventory.json`.
- `analysis/raw/` — raw reads: gov params ABCI proof, staking pool, validators, CP, supply, 100 proposals,
  all 78 contracts (info + balances), MEXC book, CoinGecko. `analysis/wasm/` — deployed wasm (codes 913/911/…)
  used to recover the Admin/treasury interfaces (`migrate_contracts`, explicit `code_id`, versioning strings).
- **CI (success):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37948203035 —
  re-fetched everything keyless and reproduced the model (block 27,324,402; log `ci-log.txt`, artifacts
  `ci-artifacts/result-nolus/`, job output `ci-out/`).

## 6. Caveats & limitations

- Point-in-time reads (2026-10-09); NLS price/depth move. Bonded rose 2.2% intraday (defensive bonding).
- Admin/treasury contract source is not public; interfaces recovered from deployed wasm strings + executed
  governance proposals — the migration-deception mechanics are strongly evidenced but not fork-executed
  (a Cosmos chain has no EVM-style local fork; no transactions were sent, by campaign rule).
- Solana-side positions and the relayer trust model were not assessed (out of scope; flagged as extension).
- The deception path's success probability is not quantifiable from on-chain data.
