# Carmine Options (Starknet) — public documentary record (web research)
Subagent deliverable for C2-47. Date: 2026-10-10. Read-only; no transactions; web sources only.
Addresses (parent's dump, for context): LEGACY AMM 0x076dbabc…0aa (20.95 ETH + 20,637 USDC held);
NEW AMM 0x047472e6…8d9; GOV 0x001405ab…ba0f. DefiLlama adapter tracks both AMMs.

## (a) Audits
1. **Hack-a-Chain** — Cairo 0.10 AMM (`carmine-protocol`): scope = AMM, proxy, option token, LP token.
   First delivery 2023-04-05, final 2023-05-01 (report published May 2023; announced by Starknet ZH 2023-05-10).
   Commits 6274ab7b (initial) → 4920a689 (post-fix). Findings (all Fixed except 2 doc items):
   - AMM-1 (Low): stale oracle prices → arbitrage windows; alleviation: trading lock if oracle stale >1h.
   - AMM-2 (Medium): USD-quoted oracle vs USDC-quoted pools divergence/depeg risk (fix text not fully captured).
   - AMM-3 (Info, Fixed) reentrancy-guard consistency; AMM-4/AMM-5 (Info, Acknowledged) docs/test documentation.
   PDF: https://github.com/hack-a-chain/security-audits/blob/main/Carmine%20Finance%20-%20Security%20Audit%20Report%20and%20Certificate.pdf
2. **Nethermind Security NM-0153** — Cairo 1 AMM v2 (`protocol-cairo1`), 5,878 LoC.
   Initial report 2023-12-21, final **2024-01-08**; commit b4662ddd… → fixed at 436e9d55….
   28 findings: 2 Critical, 3 High, 4 Medium, 3 Low, 8 Info, 8 Best-Practice; 27 Fixed, 1 Acknowledged. Test-suite grade: Medium.
   Pricing/LP/settlement-relevant:
   - [Critical, Fixed] locked-capital miscalculation from wrong variable.
   - [Critical, Fixed] burning short options decreased locked capital instead of increasing it (typo introduced in Cairo-1 rewrite; Cairo-0 unaffected; fix 79446d69). Allows LP withdrawal when funds should stay locked → unsettleable options.
   - [High, Fixed] expired-position valuation loop skips option at index 0 → wrong LP mint/burn value (fix 5889f8b1).
   - [High, Fixed] LP value wrongly assumed options sorted by maturity.
   - [High, Fixed] shadowed `usable_index` permanently locks funds in old options.
   - [Medium, Fixed] max-LP-balance check; owner can overwrite option LP tokens; pool-position miscalc;
     sandwich attack (instant LP deposit/withdraw around a trade to skim fees risk-free) → SandwichGuard on LP token:
     no mint/burn/transfer if any mint/burn occurred in the same block (fixes 5afb766e, c3147e9e).
   - [Low, Fixed] wrong option side expired; `pow` edge case; deposit/withdraw blocked near expiry.
   - [Info, Fixed] “Only governance can halt trading, defeating its purpose” → emergency halt by permitted addresses
     (fb6a886a); follow-up 9972e000: permitted addresses can only halt (not resume), governance sets permissions;
     storage annotation semantics fixed so `trading_halt=true` means halted.
   PDF: https://github.com/NethermindEth/PublicAuditReports/blob/main/NM0153-FINAL_CARMINE.pdf
   Summary page: https://numist.io/audit/nethermind-security-carmine-options-security-review
   Docs audit page (Nethermind PDF + Hackachain mention): https://docs.carmine.finance/carmine-options-amm/audit
   (old carmine.finance/carmine-audit-by-nethermind.pdf link now 404s).

## (b) Incidents / bugs
- **No public exploit/hack of Carmine found.** Searches of Rekt, SlowMist Hacked DB, PeckShield/Chainalysis-type
  news, DefiLlama hacks, and “Carmine exploit/hack/vulnerability” returned nothing Carmine-specific (as of 2026-10-10).
  Unrelated Starknet incidents for contrast: zkLend ~$10M (Feb 2025); Vesu recovered (https://rekt.news/dodging-a-bullet);
  Starknet outage 2026-01-05.
- **Aug 2023 — self-documented oracle settlement bug:** repo `supreme-dollop` (2023-08-02) = “notebook for calculating
  Amm losses caused by bug in historical prices provided by oracle”; `amm_losses.ipynb` + `user_losses_ETH.csv`
  (11 addresses, losses ≈0.000026–0.041 ETH, Σ≈0.046 ETH). No public post-mortem/announcement found.
  https://github.com/CarmineOptions/supreme-dollop
- **Oracle-dependency risk (2026):** Asymmetric Research disclosed that any anonymous caller could permanently poison
  Pragma’s conversion-rate pair list (~$0.10, append-only, no removal), disabling price feeds chain-wide — would force
  stale-price trading halts in integrations named incl. Carmine. Responsibly disclosed; fixed with `assert_only_admin`.
  https://blog.asymmetric.re/all-roads-lead-to-panic-a-starknet-oracle-story/
- Audited critical bugs in (a) are the only known “bugs”; all fixed pre-deployment (deployed class hashes per
  amm-governance/src/constants.cairo reference protocol-cairo1 branch `audit-fixes`, commit 7b7db574).

## (c) Volatility-adjustment mechanics (as documented)
- Black-Scholes pricing; spot from Pragma (ex-Empiric); σ (implied vol) updates only via trades; σ kept separately per
  pool / maturity (v1 also per strike, `SEPARATE_VOLATILITIES_FOR_DIFFERENT_STRIKES=1`).
- Formulas: **σ = (σ_{t-1} + σ_t)/2 ;  σ_t = σ_{t-1} + Q_t / C** ; C = volatility-adjustment speed; Q_t = trade size
  (positive long, negative short). Midpoint averaging chosen so splitting trades converges and arbitrage can drive σ
  toward the “true” value.
  https://docs.carmine.finance/carmine-options-amm/mechanics-deeper-look/option-pricing-mechanics
- C is per-pool, set/updated by governance (“roughly according to pool size”, legacy code comment) in `add_lptoken`;
  readable via `get_pool_volatility_adjustment_speed`; max option size capped as % of C
  (`get_max_option_size_percent_of_voladjspd`). No numeric C values published in docs (on-chain per pool).
- Bounds/params (code): VOLATILITY_LOWER_BOUND=1; UPPER=2**64 * 2**61 (identical v1/v2); fee 3% of premia;
  risk-free rate 0; no trade within last 7,200 s before expiry.
  https://github.com/CarmineOptions/protocol-cairo1/blob/master/src/amm_core/constants.cairo
  https://github.com/CarmineOptions/carmine-protocol/blob/master/contracts/core_amm/constants.cairo
- Initial σ per option set by governance vote.
  https://docs.carmine.finance/carmine-options-amm/mechanics-basic-overview/initialization-of-new-pairs-and-new-options

## (d) Legacy → new (v2) timeline; legacy status
- 2023-04-07: v1 (Cairo 0.10) mainnet launch (docs tokenomics; CARM locked ≤12 months.
  https://docs.carmine.finance/carmine-options-amm/tokenomics/tokenomics).
- 2023-04/05 Hack-a-Chain audit; 2023-08 oracle bug (b); 2023-12-21→2024-01-08 Nethermind audit of v2;
  protocol-cairo1 CHANGELOG v1.0.0 = 2024-01-09 (audit fixes = v1.0.1).
- v1→v2 switch ≈ 2024-01-09/10: konoha commit “Deploy new amm (#37)” 2024-01-10; frontend constant
  `AMM_SWITCH_TIMESTAMP = 1704841200` (2024-01-09 23:00 UTC)
  (https://github.com/CarmineOptions/fe-app/blob/development/src/constants/amm.ts). Medium (Feb 2024):
  “The new version of Carmine Options AMM is on mainnet…”
  https://medium.com/@carminefinanceinfo/empowering-community-token-distribution-refreshment-b113f2104284
- **No in-contract migration:** Nethermind fix notes say all migrating functionality was removed from v2
  (commit 636af75a); v2 launched with fresh pools. v1 endpoints relabeled “Deprecated Smart Contract v1 Endpoints”
  (https://docs.carmine.finance/carmine-options-amm/tech-docs/deprecated-smart-contract-v1-endpoints).
- **Legacy not zeroed / not formally sunset:** funds remain (above); fe-app still ships legacy ABI + legacy LP
  addresses and a Transfer component calling legacy `get_user_pool_infos` (in-app legacy LP exit path).
  https://github.com/CarmineOptions/fe-app/blob/development/src/components/Transfer/transfer.ts
  carmine.finance (2026) lists the AMM in past tense: “In the past we have built frontend and backend for Carmine
  Options AMM” (https://carmine.finance/). No wind-down announcement found.

## (e) Current status signals (2026-10-10)
- app.carmine.finance live (T&C gate). fe-app updated 2026-08-31; Carmine_landing 2026-10-06; carmine-api 2025-11-07;
  protocol-cairo1 last release v1.3.1 (2024-06-05), last commits 2025-05-02 (Ekubo terminal prices); 1 open issue
  (#25 Blast API shutdown, unresolved). https://github.com/CarmineOptions/protocol-cairo1/issues/25
- DefiLlama: TVL $99,326 (Starknet, legacy+new); “Audits: Yes”; no hacks entry.
  https://defillama.com/protocol/carmine-options
- X @CarmineOptions (7,854 followers, verified): low-frequency; 2026-08-03 “Our friends from supervega launhed.
  Good luck.” → SuperVega = separate team (public beta 2026-08-03; supervega.app ToS 2026-06-17), promoted by Carmine.
  https://x.com/CarmineOptions/status/2084242038292127768 ; https://supervega.app/terms ;
  https://cryptobriefing.com/supervega-options-trading-starknet-beta/
- Medium last post 2024-08-28; no incident/sunset posts since. https://medium.com/@carminefinanceinfo
- **Halting:** legacy — three hardcoded addresses can halt AND resume via `set_trading_halt` (added 2023-04-04
  “Add trading halt by any of team members”): Ondra 0x0583a9d9…c722a1, Andrej 0x06717eaf…270a0af,
  Marek 0x0011d341…b86233 (https://github.com/CarmineOptions/carmine-protocol/blob/master/contracts/core_amm/state.cairo;
  team page names: https://docs.carmine.finance/carmine-options-amm/organization/team). v2: `trading_halt_permission`
  storage map; permitted addresses halt-only (audit 6.16). No public record of a historic halt announcement; README:
  trading auto-halts when Pragma is stale (https://github.com/CarmineOptions/carmine-protocol README).

## (f) Open questions
1. On-chain halt state of legacy and v2 today (get_trading_halt) — web record only proves the mechanism.
   [Resolved by parent: both halt=0; see ci-out/state-proof.json.]
2. Nethermind Critical #1 exact mechanism (only title/summary captured).
3. Hack-a-Chain AMM-2 exact alleviation (USD vs USDC) not fully captured.
4. Was any compensation for the Aug-2023 oracle bug announced? CSV totals (~0.046 ETH) look small/possibly partial.
5. Does deployed v2 class hash 0x0217863f… map to audited commit 436e9d5 or audit-fixes 7b7db57?
6. Who still operates/monitors the AMM UI; whether legacy LP exit works today.
7. SuperVega affiliation (called “friends”; CryptoBriefing calls it a competitor) — appears independent.
