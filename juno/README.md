# C2-07 · Juno governance capture — economically dead on live state (juno-1)

**Date:** 2026-10-05 · **Chains:** juno-1 (Cosmos SDK v0.53.7, junod v30.0.0) + Osmosis (JUNO market) · **Status:** read-only research; no transactions signed or sent; no secrets; on-chain state verification + CI heavy pulls (no EVM fork applicable).

**Bottom line:** The finding's "$73–110k to capture Juno governance" is **not achievable and not profitable** on live state. The stake needed to pass a hostile proposal is **14.85M JUNO (solo quorum, dynamic denominator) to 23.5–29.6M JUNO (outvoting validators)**. **All JUNO on every known market is 4.77M JUNO (~$42.6k)** — 3.1× short of even solo quorum — so the stake cannot be bought on-market at any price. Even if captured, the community pool is 96% illiquid JUNO: realizable proceeds are **~$12.0k of hard assets + at most ~$29k–$38k from dumping 20.49M JUNO into the entire DEX liquidity**. Net extraction for a rational unprivileged attacker: **≈ $0** (confidence: high). The only cheap "capture" is social engineering (a plausible CP-spend proposal, deposit $45) — a social risk, not a technical exploit.

## TL;DR table

| Target | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| Community pool (gov `MsgCommunityPoolSpend`) | **$0** — needs a passed proposal; capture stake doesn't exist on-market | CP = 20,491,874 JUNO + $11,515.79 USDC + $460.9 DAI + dust; JUNO dump capped by $44.3k total counterpart liquidity | Social engineering: $45 deposit; validators routinely vote (mostly >90% Yes on 2026 proposals) — a disguised spend could pass (fraud, not capture) |
| CP spend economics (stake-buy capture) | **$0 / negative** | Cost 14.85M JUNO = $132.7k at spot (if buyable) or 23.5M = $209.6k; proceeds ≤ $12.0k hard + ≤$38k JUNO sale | If a whale ever dumps 15M+ JUNO OTC at <$0.0028, capture turns marginally positive (unmeasurable) |
| Malicious software upgrade (chain-wide theft) | **$0** — requires >50% votes **and** validators to adopt a malicious binary | 25 bonded validators coordinate publicly (Discord, cosmovisor, sha256 in plan); v31 upgrade scheduled Oct 7 | Latent P: on-chain liquid pot ≈ $12k CP stables + ~$118k bridged majors + $44k DEX reserves + 142.5M illiquid JUNO |
| Wasm migrate power (contracts with gov admin) | **$0** (CI scan — see `ci-out/contracts_gov_admin.json`) | Only contracts whose admin == gov module can be migrated; Juno TVL $50.8k total | Any future gov-admin contract holding value |

**Total live extractable now (E-U): $0.00** — confidence **high** on "no on-market capture", **medium** on the exact residual OTC/social tail.

## 1. The mechanism, in exact terms

Juno governance is standard Cosmos SDK v0.53.7 x/gov (wrapped by `x/wrappers/gov`, which only replaces the query server — no tally changes; source checked). A passed proposal executes arbitrary module messages as the gov module account, including `MsgCommunityPoolSpend` (drains the community pool) and `MsgSoftwareUpgrade`/`MsgMigrateContract`.

Verified on-chain gov params (gRPC `cosmos.gov.v1.Query/Params` @ `juno-grpc.publicnode.com:443`, 2026-10-05; verbatim in `analysis/raw/gov_params_grpc.json`):

| Param | Value | Consequence |
|---|---|---|
| `quorum` | **0.334** | turnout must be ≥33.4% of **total bonded at tally time** |
| `threshold` | **0.5** (strict `>`) | need >50% of Yes+No; `abstain` excluded |
| `veto_threshold` | **0.334** (`>`, burns deposits) | defenders can veto with >33.4% NoWithVeto |
| `voting_period` | **432,000s = 5 days** | 5-day public vote |
| `max_deposit_period` | 864,000s = 10 days | — |
| `min_deposit` | **5,000 JUNO** (5e9 ujuno) | proposal cost ~$45 |
| `min_initial_deposit_ratio` | 0.2 | 1,000 JUNO starts voting |
| `expedited_*` | 86,400s / 0.667 / 10,000 JUNO | worse for an attacker |
| `burn_vote_veto` | true | veto burns deposit |

**The dynamic-quorum trap.** SDK v0.53.7 `x/gov/keeper/tally.go` computes `percentVoting = totalVotingPower / staking.TotalBondedTokens()` at tally time (line 176, verified from source). The attacker's own newly-bonded stake **raises the denominator**. To reach quorum *alone*: `B/(T0+B) ≥ 0.334` → `B ≥ T0 × 0.5015`. With `T0 = 29,611,617 JUNO`: **B ≥ 14,850,270 JUNO**, not the naive `0.334 × T0 = 9.89M` used by the finding.

**The defender bar.** Validators routinely vote with most of their stake. Live proposals at snapshot (h 42,396,945, 2026-10-05 15:49:51 UTC):

- #378 "Recover frozen IBC client with Cronos": yes = **23,077,946 JUNO**, no = 0, veto = 0
- #379 "Juno v31 Software Upgrade": yes = **23,457,598 JUNO** (87 voters, all Yes), no = 0

2026 historical turnout: 16.49M–24.50M JUNO (props 374→375), capacity = all 29.61M bonded. So a blatant CP-drain needs **B > 16.5M (best case) and realistically B > 23.5M**, with veto exposure.

**Staking params:** `unbonding_time = 2,419,200s (28 days)`, `max_validators = 25`, min commission 5% (`analysis/raw/cosmos_staking_v1beta1_params.json`). Time-to-cash for the attacker's own stake: **≥33 days** (5-day vote + 28-day unbond), plus acquisition.

## 2. Live-state assessment (all reads at stated blocks)

| Item | Value | Evidence |
|---|---|---|
| bonded_tokens | 29,611,617 JUNO (first read 15:26 UTC) → 29,611,748 (16:24 UTC) — inflation drift | `analysis/raw/staking_pool_grpc.json`, `ci-out/state.json` |
| not_bonded | 24,986,243 JUNO | same |
| ujuno total supply | 142,468,456 JUNO | `analysis/raw/supply_ujuno_grpc.json` |
| community pool (gov-spendable) | **20,491,874 JUNO** + 11,515.79 USDC (ibc/4A48… ch-224) + 460.9 DAI (ch-71) + 3.28 ATOM + 163 LUNA + 69 HUAHUA + 2.85M THIOL + 2.1M TERP + dust | `analysis/raw/community_pool_grpc.json`; IBC traces via `ibc…Query/Denom` |
| CP paper value | **$195,056.60** ($183,065.90 JUNO + $11,990.71 hard) | `analysis/cost_model.json` |
| distribution module account | 29,035,486 JUNO = CP + **8,543,658 JUNO of unclaimed staking rewards** — **not** gov-spendable | `DistributeFromFeePool` only subtracts tracked CP (SDK v0.53.7 `x/distribution/keeper/fee_pool.go`, checked) |
| wasm params | `code_upload_access = Everybody`, `instantiate_default = Everybody` | `analysis/raw/cosmwasm_wasm_v1_codes_params.json` |
| wasm codes | **5,169** uploaded (finding said "400+") | `ci-out/codes.json` |
| wasmvm | v3.0.4 (v31 upgrade to v3.0.8 pending, prop 379) | juno v30 go.mod + prop 379 summary |
| gov module account | `juno10d07y265gmmuvt4z0w9aw880jnsr700jvss730` (auth ModuleAccounts) | `analysis/raw/` |
| JUNO price | **$0.0089336** (DefiLlama 2026-10-05); market cap $712k; 24h volume ~$663–668 | `analysis/raw/prices_llama_full.json`, `analysis/raw/cg_tickers.json` |
| JUNO venues | Osmosis only per CoinGecko (3 tickers); Kraken delisting (liq. Dec 14–18, 2026, ~$23/day); Crypto.com delisted | `analysis/child-verify/tickers.json` |
| **All JUNO in DEX pools** | **4,773,329 JUNO** (Osmosis GAMM 1,768,867 + CL 546,467 + WYND 2,430,156 + Loop 17,516 + White Whale 10,309 + test DEX 13) ≈ **$42.6k** | parent + independent child (`analysis/child-verify/REPORT.md`) |
| Counterpart liquidity (what a JUNO dump can extract) | **$44,350** across all priced pools | `analysis/cost_model.json` |
| Juno chain TVL (DefiLlama) | **$50,802** total | `analysis/raw/llama_protocols.json` |
| Bridged majors on juno-1 | ~$67.1k USDC variants + ~$35.5k ATOM + ~$14.0k WETH + ~$0.5k DAI + ~$0.7k LINK + dust | `analysis/raw/all_supply.json` + IBC traces |

## 3. What an attacker can/cannot do

**Path A — buy stake, pass `MsgCommunityPoolSpend` (the finding's model).** Preconditions: acquire B ≥ 14.85M JUNO (solo quorum) or ≥23.5M (beat live turnout), delegate it, submit with 5,000 JUNO, vote Yes, wait 5 days, receive CP, then unbond 28 days and sell.

- **Acquisition is impossible on-market.** Buy curves (equalized marginal, 0.3% fee, `analysis/cost_model.py`):

| Buy | Cost | Avg $/JUNO |
|---|---|---|
| 500k JUNO | $4,891 | $0.0098 |
| 1M JUNO | $11,213 | $0.0112 |
| 2M JUNO | $30,975 | $0.0155 |
| 3M JUNO | $74,468 | $0.0248 |
| 4M JUNO | $240,710 | $0.0602 |
| 4.7M (all pools) | ~$13.1M | $2.79 |
| **15M** | **impossible** (3.1× all JUNO in existence on markets) | — |

  Independent child verification: buying 90% of priced pools (~3.41M JUNO) costs **$311,832** (10× spot); 15M unreachable at any price.
- **Proceeds are capped by liquidity, not by paper value.** Selling the captured 20,490,612 JUNO into every pool returns **$29,069** (child, proportional split) to **$38,374** (parent, equalized marginal) — vs $183,066 paper. Counterpart liquidity across all pools is **$34.5k (strict majors: ATOM/OSMO/USDC) to $44.4k (incl. NETA/WYND at CoinGecko)**. Per-pool examples (child): WYND JUNO/ATOM $11,788; GAMM 498 $10,217; WYND USDC $5,651; GAMM 497 $5,005. Hard CP assets add $11,990.71.
- **Net.** OTC-only scenarios (unmeasurable price; conservative total proceeds = $11,990.71 hard + $29,069 JUNO sale = **$41,060**):

| Capture stake | Break-even OTC price | Net @ OTC $0.001 | Net @ spot |
|---|---|---|---|
| 14,850,270 (solo quorum) | ≤ $0.00276 | +$26.2k | −$91.6k |
| 23,457,598 (beat live turnout) | ≤ $0.00175 | +$17.6k | −$168.5k |
| 29,611,617 (beat all bonded) | ≤ $0.00139 | +$11.4k | −$223.5k |

  With the optimistic equalized-marginal sale ($38,374; total $50,365), break-even rises to $0.0034 / $0.0021 / $0.0017. A positive result still requires an OTC seller dumping 15–30M JUNO at **11–38% of the already-collapsed spot**, defenders under-performing their observed turnout, and the attacker capturing the entire DEX liquidity — all simultaneously. Expected value ≈ $0; the rational unprivileged attacker does not attack.

**Path B — social engineering (the only cheap path).** Submit a plausible-looking CP-spend to an attacker address; cost = 5,000 JUNO deposit (~$45) + proposal text. Juno validators pass proposals at 56–98% Yes (2026: 371 96.3%, 372 56.4%, 373 91.7%, 374 80.4%, 375 97.8%) with turnout 16.5–24.5M. If the recipient isn't scrutinized, proceeds = CP ($195k paper / ~$41–50k realizable). This is fraud, not cryptographic capture; success probability is a social judgment (low–medium), and the funds are public for 5 days.

**Path C — malicious upgrade/migration.** Needs >50% votes **and** 25 validators to run a malicious binary (public plan, sha256, Discord coordination, cosmovisor). Theoretical pot = all on-chain value: 142.47M JUNO (paper $1.27M, illiquid), ~$118k bridged majors, ~$44k DEX reserves, CP. Not E-U; latent P. The CI scan enumerates contracts whose admin is the gov module (`ci-out/contracts_gov_admin.json`); Juno DeFi TVL is only $50.8k.

**Path D — wasm code upload (Everybody).** Anyone can upload code (5,169 codes already), but upload alone gives no access to funds; instantiation requires victims. Not an extraction path; relevant only to chain-DoS advisories (v31 ships wasmvm v3.0.8 on Oct 7).

## 4. Verdict and classification

| Category | Amount | Confidence |
|---|---|---|
| **E-U (external unprivileged)** | **$0.00** | high — no on-market path can assemble quorum-sized stake; CP is not directly reachable |
| **capture** | net ≈ **$0** (cost > proceeds for every on-market and spot-priced path; OTC break-even ≤$0.0028/JUNO) | high on cost side, medium on OTC tail |
| **P (governance/privileged)** | CP **$195,056.60** paper / **$11,990.71** hard + ≤$38k JUNO dump; upgrade leg latent over ~$160k on-chain hard assets | high on CP, medium on upgrade pot |
| **H-O** | — (stakers/holders self-custody; CP is not holder-recoverable) | — |
| **S (stuck)** | — | — |

**Residual/latent risk:** (1) a future large pool or CEX listing changes liquidity math — monitor; (2) a whale OTC dump below ~$0.0028/JUNO would make capture marginally positive; (3) social-engineering CP spends; (4) validators adopting a malicious upgrade; (5) any contract that later sets gov as admin; (6) **adjacent, not this finding:** juno-1 still runs wasmvm v3.0.4 with `code_upload_access=Everybody`; v31 (prop 379, activates ~Oct 7 at height 42,452,000) ships wasmvm v3.0.8 / wasmvm-v3 maintenance fix (Wasmer v7.4.2, cosmwasm 3.0.10) described by the proposers as a CosmWasm security release — the same permissionless chain-DoS class as C2-09/C2-10 until the upgrade executes.

**Corrections to the finding:** cost is not $73–110k (dynamic quorum ⇒ ≥14.85M JUNO = $132.7k at spot, before slippage, and un-buyable); "400+ wasm codes" is 5,169; CP USDC 11,515.79 + DAI 460.9 are the only hard assets; JUNO's only market is Osmosis + juno-1 DEXes.

## 5. Verification & evidence

- **Independent child verification** (`analysis/child-verify/REPORT.md`, session `ses_ef335af83ffe5ItnbjGVcKkg4W`): reproduced every state number, found the missed venues (Loop Finance 17,515.73 JUNO; White Whale 10,309.13; test DEX 13.17), reproduced the cost/sell curves, confirmed no CEX.
- **CI run** (`ci/scan.py`): full wasm code count, contract enumeration + admin/balance scan (gov-admin contracts, top contracts by JUNO), bridged-asset totals, live re-verification. Artifacts in `ci-out/`; run URL in `ci-log.txt` / below.
- Local model: `analysis/cost_model.py` → `analysis/cost_model.json` (buy/sell curves, scenarios, CP valuation).
- Gov params: `analysis/raw/gov_params_grpc.json` (verbatim gRPC); tally source checked against SDK v0.53.7 `x/gov/keeper/tally.go`.

## 6. Methodology, caveats, files

**Method:** public LCD/gRPC only (juno-api.polkachu.com, juno-rest.publicnode.com, lcd-juno.keplr.app, juno-grpc.publicnode.com:443, lcd.osmosis.zone); DefiLlama/CoinGecko prices; SDK/Juno source from GitHub. No transactions, no keys.

**Caveats:** pool reserves move block-to-block; CL 1097 is approximated by its reserves; OTC prices are unobservable; social-engineering success probability is subjective; USD values at 2026-10-05 prices; CP grows ~2.6 JUNO/min (community tax 10%).

**Files:** `README.md`, `summary.json`, `analysis/cost_model.py|json`, `analysis/raw/*` (state, params, CP, supplies, pools, prices), `analysis/child-verify/` (independent report + raw pulls), `ci/scan.py`, `ci-out/` (CI artifacts), `ci-log.txt` (CI run URL).
