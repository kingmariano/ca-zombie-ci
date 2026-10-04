# H-22 · Serum (Solana) + OpenBook v1 — zombie order-book deep-dive

**Date:** 2026-10-04 · **Chain:** Solana · **Status:** read-only; no transactions sent; all state at finalized slots (latest `453,199,799`); CI-verified reproducibility (see §7).

**Targets:** Serum DEX v3 `9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin` (deprecated) · OpenBook v1 `srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX` (deprecated) · the community claim of "500K–1M SOL locked in dead market rent".

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| **Serum v3 markets** (168+ initialized; vaults hold real assets) | **$0** | Vault payouts require the OpenOrders **owner's signature** (`settle_funds`); no close-market; fee sweep is key-gated | FTX-era upgrade key `6XvcBm…` still set (P); accrued fees $2.5M+ sweepable by key `DeqYsmBd…` (P/S) |
| **OpenBook v1** (~727,161 initialized markets; 457 with any deposit ≈ **$139.7K** priced, mostly USDC) | **$0** | No `CloseMarket` instruction; `close_open_orders` is owner-only; `sweep_fees`/`disable_market`/`prune` are authority-gated; **0 zeroed OpenOrders shells exist** (the only claim-and-close path) | Unaudited v1 code (never audited, frozen 2022-12); dormant DAO upgrade path (needs 8/13 council tokens) |
| **Dead-market rent** (~672,800 SOL ≈ **$81.4M**) | **$0** | Market/bids/asks/event-queue/request-queue + vault token accounts are program-owned with **no close path** in either program | Program upgrade could add reclaim (governance, not permissionless) |
| **Serum Swap** (`SwaPpA9…`, DefiLlama $0.24M) | not assessed | separate program, out of scope | — |

## 2. Total live extractable now: **$0 (E-U)** — confidence **medium-high**

No external unprivileged attacker can withdraw, redirect or capture any material value today. All candidates were enumerated and every one is gated by a signer/authority check, or has zero instances on-chain. Confidence is medium-high rather than high only because OpenBook v1 is a **never-audited** frozen binary (residual unknown-bug risk, §8).

**Value split (USD, 2026-10-04, SOL = $120.98 via DefiLlama):**

| Category | Amount | Basis |
|---|---|---|
| **E-U** (unprivileged) | **$0** | all paths gated; 0 shells |
| **H-O** (owner-recoverable) | **$10.78M** (upper ≈ $16.5M) | Serum v3 deposits $8.37M (168-market registry, vault-spot-verified) + OpenBook priced deposits $139.7K + owner-closable OpenOrders rent ~18,736 SOL (~$2.27M; 802,133 accounts; DefiLlama state upper bound $1.16M) |
| **P** (key/governance-only) | **≥$2.54M** | accrued fees: Serum v3 registry $2.54M (SOL/USDC market alone 1,518,551 USDC); OpenBook pc-fees 658.7e9 raw (unpriced); program upgrades (Serum v3 EOA; OpenBook DAO council) |
| **S** (stuck) | **~$81.4M** | OpenBook locked rent ~672,800 SOL (range 218K–810K by book-size mix); 23,418 zeroed market shells (~84 SOL); Serum v3 market rent (~50 SOL); fees if fee-sweeper keys are lost |

## 3. The mechanism — why nothing is permissionlessly extractable

Both programs are variants of the same Serum v3.1 CLOB code. The value surfaces and their gates:

1. **Vault deposits** live in per-market token accounts owned by a per-market vault-signer PDA. The only outflow paths are `settle_funds` and `sweep_fees`.
   - `settle_funds` → `load_orders_mut(open_orders, Some(owner))`: requires **owner signature** and checks `open_orders.market == market` and destination token accounts' mint/authority (`state.rs:2795`, `state.rs:166–196`). An outsider cannot settle someone else's claim.
   - `sweep_fees` → `SigningFeeSweeper` requires `account.key == fee_sweeper::ID` **and** `is_signer` (`state.rs:1566–1570`). OpenBook's key `GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA` is an **off-curve PDA — the SPL Governance native treasury of the "Serum Community Fork" realm** (created via `CreateRealm`), so fees/`disable_market` require an **executed DAO proposal** (P). Serum v3's key `DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE` **does not exist on-chain** (key/controller unknown). Privileged/governance-only.
2. **Rent in market accounts.** Serum v3 / OpenBook v1 instruction enums contain **no `CloseMarket`** (only `CloseOpenOrders`, owner-only, and only for empty accounts). The market, bids, asks, event-queue, request-queue and vault token accounts are PDAs/program-owned with no lamport-out path. 727,164 markets × avg 0.925 SOL (n=40 sample) ≈ **672,800 SOL locked** — permanently stuck absent a program upgrade.
3. **Uninitialized (zeroed) OpenOrders shells** are the one theoretical claim-and-close path: `init_open_orders` accepts any zeroed program-owned 3,228-byte account (V1 markets have no `open_orders_authority`), then `close_open_orders` pays rent to the claimer. **On-chain count of such shells: 0** (`getProgramAccounts` filter dataSize=3228, flags=0). Zeroed *market* shells (23,418) can be initialized but never closed → no extraction.
4. **Cranks are value-conserving.** `consume_events` binds events to OpenOrders by owner key + slot/side + order-id checks (`state.rs:2975–3135`); `prune` requires `market.prune_authority()` which is `None` for V1 (all 727K markets are V1; 0 permissioned V2 markets exist). `close_open_orders` requires owner signer + empty account (`state.rs:2773`).
5. **Program upgrades are not permissionless.**
   - OpenBook v1 upgrade authority decodes as **ProgramGovernanceV2** under RealmV2 **"Serum Community Fork"** (`BtD6wKia…`): community mint supply **0**, community proposals disabled (`min_community_weight_to_create_proposal` ≈ u64::MAX); **council mint `J7jDKSPQ…` supply 13** (min 1 token to propose, YesVotePercentage(60) ≈ 8/13 votes, 3-day vote, 0 hold-up). Capturing it needs the cooperation of council-token holders — not unprivileged, no public market.
   - Serum v3 upgrade authority `6XvcBm…` is a plain system EOA (2.5M lamports, no data). FTX held the upgrade keys per CoinDesk/FTX court filings; no upgrade since 2022-08-19. P.
6. **Stale resting orders** (fill a forgotten book) is the only economic path that is not signer-gated — but it is ordinary trading, capped by the book, and the OpenBook deposit set is tiny (~$139.7K priced across all 457 deposit markets; DefiLlama's $1.16M state figure includes fees and unpriced junk). No evidence of material extractable stale liquidity was found.

## 4. Live-state assessment (all reads at finalized slot `453,199,799` unless noted)

| Item | Value |
|---|---|
| Serum v3 program | deploy slot `146,728,883` = 2022-08-19; programdata `DTxcpNApaMLNfYgwQ99PmpCm8rjS7o1q2YdfzYsrYohB` (494,866 B); upgrade authority `6XvcBmETaz5ZNRhwiz1ochXitHG771d6rmK4Ug3NVr1g` (system EOA, 2,500,000 lamports, 0 data) |
| OpenBook v1 program | deploy slot `168,006,653` = 2022-12-20; programdata `9K32VSPTg4PHY7Hb2QZq26e5CujwMgt8Bqq4kJrp5zp8` (468,941 B); upgrade authority `8xYs2tGXPayMtgsqs4NuMy7bnWr7DM9tnnkbY2SHVbys` = ProgramGovernanceV2 → realm `BtD6wKiazt4EEvfw6tqDh1BPSVchGeqyZ1e4HhV9VHJ6`, governed = the program |
| OpenBook markets | **727,161** fully enumerated (flags=3, dataSize 388); 0 disabled; 0 permissioned V2 markets; **802,133 initialized OpenOrders** (0 closed, **0 zeroed**); 23,418 zeroed 388-B shells |
| OpenBook deposits | 457 markets with any deposit (380 coin / 279 pc); priced deposits ≈ **$139,679** (USDC $134,073; Saber $3,470; SOL $1,815; USDT $286; rest dust); DefiLlama state-based TVL **$1,157,329.30** (includes fees/accounting, upper bound) |
| OpenBook OpenOrders rent | 802,133 × 0.02335776 SOL ≈ **18,736 SOL (~$2.27M)** — closable only by each account's owner (H-O), and only if the account is empty |
| OpenBook rent sample | n=40 random markets: avg **0.9252 SOL**, median 0.2977, min 0.293, max 2.784; templates: small (0.2974 SOL: event_q 11,308 B, bids/asks 14,524 B) and large (2.784 SOL: event_q 262,156 B, bids/asks 65,548 B) |
| Serum v3 markets | 168 in registry, all initialized, 0 disabled; registry deposits **$8,372,541.87**, accrued fees **$2,540,221.78**; DefiLlama full-set state TVL **$17,131,473.29** (adapter sums `deposits+fees`, not vault reads) |
| Serum v3 SOL/USDC market `9wFFyRf…` | vaults **really hold** 20,290.10016133 wSOL (`36c6YqAwy…`) + 2,546,686.997865 USDC (`8CFo8bL8…`) — matches market-state deposits (20,290 SOL, 956,741 USDC) + accrued fees (1,518,551 USDC) |
| Fee sweepers | OpenBook `GTgd6…`: **off-curve PDA** = SPL Governance native treasury of realm "Serum Community Fork" (not an EOA) — sweep requires an executed proposal. Serum v3 `DeqYsmBd9…`: **account absent** (controller unknown) |
| Disable authority (Serum v3) | `5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V`: system EOA, 194,422,050 lamports, no recent sigs |
| SOL price used | $120.98121171624892 (DefiLlama, 2026-10-04) |

## 5. What an attacker can / cannot do (exact paths)

| Attempt | Result | Gate |
|---|---|---|
| Settle a victim's Serum v3/OpenBook funds to attacker | reverts | owner signer required (`state.rs:166–196`, `2795`) |
| Close a victim's OpenOrders, take rent | reverts | owner signer + zero balances (`state.rs:2773–2793`) |
| Claim a zeroed OpenOrders shell and close it for rent | **nothing to claim — 0 shells exist** | init path itself is permissionless (V1 authority=None) but no instances |
| Call `sweep_fees` on a market with accrued fees | reverts | `fee_sweeper::ID` hardcoded EOA (`state.rs:1566`) |
| `disable_market`, then… | reverts | `disable_authority::ID` hardcoded (`state.rs:1572`) |
| `prune` an abandoned book | reverts on V1 | `prune_authority()` = None for V1 (`state.rs:137`) |
| Close a market and reclaim ~0.3–2.8 SOL rent | no such instruction | enum has no `CloseMarket` |
| Upgrade the program to add a drain | not unprivileged | Serum v3: FTX-era EOA; OpenBook: DAO council 8/13 tokens |
| Trade against stale resting orders | possible in principle | ordinary fills, capped by book; only 457 deposit markets, priced deposits ≈ $139.7K |

## 6. Negative results (dead ends, with evidence)

- **Jan-2023 OpenBook vulnerability: does not exist.** Last repo commit is 2023-01-05 CI-only (PR #27, dependency scanning); last deploy 2022-12-20 predates it. No OSV/RustSec/GitHub advisories for `serum_dex`/`openbook_dex`. OpenBook v1 was never audited ("turns out it was never audited", maintainer, 2022-11-19). The only OtterSec critical was **v2** (`place_order` missing vault-side check, Sept 2023, resolved). No post-FTX drains found.
- **Zeroed OpenOrders shells: 0** — the "free rent" claim path is empty.
- **Zeroed market shells: 23,418** — can be initialized by anyone, but have no close path → no value.
- **Prune on V1 markets: impossible** (authority None; no V2 markets exist).
- **Serum v3 fee sweeper account `DeqYsmBd9…` is absent on-chain** — if the key is lost, its accrued fees ($2.5M+ in the registry set) are stuck (S), not extractable.
- **DefiLlama's $17.13M is accounting-field-based, not a vault read** — spot checks confirm the largest market's vault really holds the assets, but the figure is not a direct custody proof for all 168+ markets.
- **The "500K–1M SOL" claim** traces to a single 2025 back-of-envelope estimate (serum-dex issue #268). Our measured estimate (~672,800 SOL) lands inside that range; it is **stuck**, not extractable.

## 7. Verification / CI

- Method: read-only Solana JSON-RPC (`getAccountInfo`, `getProgramAccounts` with `dataSize`/`memcmp` filters and `dataSlice`, `getMultipleAccounts`, `getTokenAccountBalance`), DefiLlama price/TVL APIs, full source audit of the frozen repos (local clones of `openbook-dex/program` @ `c85e56d` and `project-serum/serum-dex` @ 2022-08-19), and four parallel child subagents (web history, source audit, OpenBook enumeration, Serum v3 enumeration).
- Enumeration coverage: OpenBook **all 727,161 initialized markets** parsed (nonces 0–18; full JSONL evidence compressed to `analysis/openbook_markets_sample20k.jsonl.gz` + complete aggregates in `openbook_aggregates_full.json`). Serum v3: 168-market registry with per-market state + vault checks; gPA for the Serum program is disabled on `api.mainnet-beta.solana.com` (`KEY_EXCLUDED_FROM_SECONDARY_INDEX`).
- CI job: `ci/run.sh` re-verifies program authorities/deploy slots, zeroed-shell counts, Serum v3 SOL/USDC vault balances and DefiLlama TVLs into `ci-out/state_check.json`. **Successful run:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37190513690 (`exit=0`; artifact `result-serum`, CI log `ci-log.txt`, downloaded results `ci-artifacts/result-serum/ci-out/state_check.json`). The CI runner independently reproduced: deploy slots 146,728,883 / 168,006,653; Serum v3 vaults 20,290.10016133 wSOL + 2,546,686.997865 USDC; zeroed OpenOrders shells 0; zeroed market shells 23,418; Serum fee_sweeper account absent; DefiLlama Serum $17,159,933 / OpenBook $1,157,395.

## 8. Verdict & residual risk

**E-U = $0.** The zombie value in Serum/OpenBook is real but every extraction path is gated:
- **H-O** $10.78M (upper ~$16.5M): Serum v3 deposits + OpenBook priced deposits + owner-closable OpenOrders rent — only the original traders/owners can withdraw (many may be inactive, making it *de facto* stuck).
- **P** ≥$2.54M: accrued fees (sweepable only by the OpenBook DAO treasury PDA via an executed proposal, or by the unknown Serum v3 fee_sweeper controller) + upgrade authorities (FTX-era EOA for Serum v3; dormant DAO council for OpenBook).
- **S** ~$81.4M: dead-market rent — permanently locked; the largest "zombie" number in this finding, but not extractable by anyone.

**Residual/latent risk:** (a) OpenBook v1 is unaudited, frozen code — an undiscovered logic bug in `consume_events`/matching remains a theoretical E-U surface (no known one exists; this is the main reason confidence is medium-high rather than high); (b) if the FTX estate or any holder of `6XvcBm…` upgrades Serum v3, all vaults/fees become privileged-extractable; (c) council-token capture of the dormant OpenBook DAO would allow adding a reclaim instruction for the ~672,800 SOL of rent — needs 8/13 council tokens, not obtainable permissionlessly.

**Blockers/limitations:** no Solana transaction simulation was executed (negative-path gates proven by deployed source + live account state instead); the deployed ELF embeds `source_revision 546e5fe` = tag **v0.5.10**, confirming the audited source equals the deployed bytecode; vault balances were spot-verified for the largest Serum v3 market only; not all 802,133 OpenOrders were individually checked for emptiness/owner liveness.

## 9. Files index

- `README.md` (this file) · `summary.json`
- `analysis/` — `web-research.md/.json` (history), `source-audit` refs in README §3, `openbook_aggregates.json`, `openbook_market_tables.md`, `openbook_valued.json`, `openbook_markets.jsonl.gz` (chunks/), `serum_v3_markets.json`, `serum_v3_summary_raw.json`, `serum_v3_dep_fee_split.json`, `rent_sample.json`, `rent_sample40.json`, `final_spot_checks.json`, `onchain_spot_checks.json`, `rpc.py`, scripts.
- `ci/run.sh`, `ci-out/state_check.json`, `ci-log.txt`, `ci-artifacts/`.
