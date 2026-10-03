# IntentX / SYMMIO — Factual History, Incident Record, Audit Record, Shutdown Timeline

Compiled 2026-10-03 (child research subagent deliverable, saved by parent).
Sources: live web (Firecrawl), Web Archive, GitHub REST/MCP, DefiLlama/CoinGecko APIs. Read-only research; no on-chain or code analysis. Every claim carries a date + URL + short quote. Disputed/conflicting sources are flagged. Nothing inferred is stated as fact.

## 1. IntentX basics: team, funding, token, chains, versions, SYMMIO relationship

**Identity**
- Non-custodial, intent-based OTC perpetual futures DEX built on SYMMIO. Launch: November 2023. Quote (Symmio, 2024-05-14): *"Launched in November of 2023, IntentX has grown from strength to strength and has cemented itself as one of the premier frontends built on SYMMIO... establishing itself as SYMMIO's flagship serviced frontend provider... (including an upcoming TGE)."* — https://medium.com/symmio-publication/intentx-leading-the-charge-of-the-on-chain-derivatives-trading-revolution-247a75289a33
- SYMMIO relationship: SYMMIO is the settlement/clearing layer (PartyA traders / PartyB solvers), IntentX matches OTC order flow to solver quotes. Quote (same article): *"SYMMIO provides the settlement layer while IntentX facilitates OTC trades by matching order flows with Solver quotes."* Carbon (the successor) docs say it now runs on SYMMIO-Core v0.8.5 (https://docs.carbon.inc/additional-information/security-and-audits.md). IntentX docs (Jan 2026 snapshot) said it used *"SYMMIO-Core v0.8 contracts for trade settlement"*.

**Team**
- Founders: pseudonymous **levy** (@levysaur) and **Roux** (0xRoux). Quote (0xWizard, 2024-03-28): *"IntentX is founded by levy and Roux, and has raised $4.3M from Selini Capital, the Mantle Foundation, Magnus Fund, and others."* — https://0xwizard.substack.com/p/intentx-investment-thesis
- Team size ~12; open beta November 2023 — https://startupintros.com/orgs/intentx

**Funding (total ~$4.3M across 2 rounds)**
- Seed $2.5M announced 2023-11-22 — https://startupintros.com/news/2023-11-22-intentx-seed
- Strategic $1.8M announced 2024-02-12, led by Selini Capital; participants Mantle EcoFund, Manifold Trading, The G House — https://www.cypherhunter.com/en/e/intentx-raised-funding-2024-02-12/

**INTX token / xINTX**
- Token: INTX on Base, `0x7d27187eb33a7b1d99258ff222633670f84fa342` — https://basescan.org/token/0x7d27187eb33a7b1d99258ff222633670f84fa342
- Supply: 100M total; circulating 38,613,934 (Yahoo Finance profile)
- TGE / claim: on or about **2024-05-31** — https://web.archive.org/web/20240531082731/https://app.intentx.io/claim
- xINTX: staked form of INTX represented by an NFT collection (Quantstamp executive summary); *"xINTX stakers earn 85% of revenues"* (https://intentx.io/information, live 2026-10-03).

**Chains**
- DefiLlama `chains`: Blast, Arbitrum, Mantle, Base (https://api.llama.fi/protocol/intentx, fetched 2026-10-03).

**Versions (SYMMIO line)**
- v0.82 upgrade end-2023; v0.83 audit 2024-06-17; v0.84 audit 2024-10-03; v0.85 audit page 2026-02-13.
- ⚠️ The specific claim "0.8.3 migration September 2024" could **not** be verified in any public source found; mark as unconfirmed.

## 2. Shutdown / death timeline (Dec 2025 – 2026)

**Primary evidence — in-app shutdown modal (still live 2026-10-03)**
- `https://app.intentx.io/home` renders: *"Important Announcement: IntentX is shutting down. Effective Date: Jan 8, 2026. Trading on IntentX will be permanently disabled on January 8. Please withdraw all funds from your account before this date. After the shutdown, access to trading features will no longer be available."* Plus button *"Withdraw Funds now!"* (captured raw HTML, 2026-10-03).
- DefiLlama: `deadFrom: "2026-01-08"` — https://api.llama.fi/protocol/intentx

**Successor brand: Carbon (not Aegas)**
- `https://intentx.io/` (live 2026-10-03): *"IntentX is now — Try out Carbon NOW!"*
- Rebrand first announced in Q1 2025 per Symmio's stakeholder letter (2025-04-16) — https://medium.com/symmio-publication/symmio-stakeholders-frens-letter-q1-2025-year-of-the-symmgularity-0739fded2b6a
- Carbon relaunch: "Introducing Carbon — The Everything Perp DEX" (2025-10-03) — https://medium.com/@CarbonTerminal/introducing-carbon-the-everything-perp-dex-e822bbd5d1ba
- "Carbon 2026 Roadmap" (2026-01-06) — https://medium.com/@CarbonTerminal/carbon-2026-roadmap-tradfi-scaling-9d6f0eb7b336
- Carbon is live: app.carbon.inc; docs.carbon.inc describes 950+ markets; $CARBON token not yet live.
- **No shutdown announcement post** was found on X/Medium/Discord. The only public notice located is the app banner.

**Aegas — identified (not a rebrand/successor)**
- Aegas (https://aegas.io/) is a fintech/blockchain software-development agency. Portfolio includes SYMMIO-based DEX builds (Privex case study lists IntentX as "Project Partner").
- `github.com/Intent-X/solver-deposit-vault` (created 2025-10-22) description: *"For Aegas to add the smart contract code"* — i.e., a task handoff to the agency to implement the "Symmio Solver Vaults" contract. Aegas = external engineering vendor, **not** an IntentX rebrand.

**Withdrawal window / funds**
- Banner instructs withdrawing before 2026-01-08; app remains online with "Withdraw Funds now!" as of 2026-10-03. No separate claim site or withdrawal contract was found. Whether withdrawals still function after 2026-01-08 is **unknown** from public sources.

## 3. Incident record (hack / exploit / loss)

- **No hack, exploit, or loss event for IntentX or SYMMIO core was found.** Checks performed 2026-10-03:
  - DeFiHackLabs (`SunWeb3Sec/DeFiHackLabs`) code search for "symmio"/"intentx": 0 results.
  - rekt.news search: no entry. SlowMist hacked DB / OAK searches: no matching entry.
  - Web searches ("SYMMIO exploit/hack", "IntentX hack/exploit/drained", "partyA exploit", "Muon signature exploit"): no incident reporting found.
- Only SYMMIO-adjacent negative event: **Aqua rugpull** (Solana, ~21,770 SOL ≈ $4.65M, reported 2025-09-08 by ZachXBT), where SYMMIO was listed among teams that had *"promoted"* Aqua — not an attack on SYMMIO itself.
- Absence of evidence ≠ evidence of absence: private/undisclosed incidents cannot be ruled out from public sources.

## 4. Audit record

**DefiLlama**: `audits: "0"` (contradicted by IntentX's own docs; DefiLlama likely counts only protocol-level submissions).

**IntentX-stated audits (docs.intentx.io snapshot 2026-01-14)**
- https://web.archive.org/web/20260114125319/https://docs.intentx.io/additional-information/security-and-audits
- *"IntentX currently utilizes SYMMIO-Core v0.8 contracts for trade settlement which have undergone a full Sherlock Audit:"* → https://audits.sherlock.xyz/contests/85
- *"The INTX token and xINTX staking contract are fully audited by Quantstamp:"* → https://certificate.quantstamp.com/full/intent-x/a195e62f-30b6-4219-b9e5-42af8a9e2fd5/index.html

**Quantstamp audit of IntentX token/staking** — Timeline 2023-11-27 → 2023-12-04; source `Intent-X/intentx-SmartContracts` @ `6d04434`. Findings: 17 total — 3 High (2 fixed, 1 acknowledged), 3 Medium (1 fixed, 1 acknowledged, 1 mitigated), 7 Low, 4 Informational.

**SYMMIO core audit registry** (https://docs.symm.io/security-and-architecture/audit-reports)
- v0.8–0.81: Sherlock 2023-06-15 + Smart State 2023-07-02
- v0.82: Sherlock 2023-08-30, contest 108 — `sherlock-audit/2023-08-symmetrical-judging`
- v0.83: Sherlock 2024-06-17, contest 427 — `sherlock-audit/2024-06-symmetrical-update-2-judging`
- v0.84: Sherlock 2024-10-03, contest 577 — `sherlock-audit/2024-09-symmio-v0-8-4-update-contest-judging`
- v0.85: page dated 2026-02-13 (post-dates IntentX's app shutdown)
- Vaults: Sherlock 2024-01-02; Staking & Vesting: Sherlock 2025-03-07

**IntentX GitHub repos (org `Intent-X`, 3 public repos)**
- `intentx-SmartContracts` — created 2023-10-29; pushed 2026-09-22. Latest commit **"Fix Party B"** (`0def5ea`, 2026-09-22) — patches an InstantLayer authorization check in `contracts/solver/SymmioPartyB.sol`.
- `intentx-subgraphs` — created 2023-10-10; pushed 2025-11-27.
- `solver-deposit-vault` — created 2025-10-22; pushed 2026-06-08; 3 unmerged fix PRs:
  - **#2** "The withdrawalPeriod change is applied retrospectively" (open)
  - **#3** "Lack of ability to update the minimumPaybackRatio" (open)
  - **#4** "depositPerUserLimit can be bypassed" (open)
  - Merged then reverted/consolidated: #5 excess collateral retrieval, #6 forceApprove, #7 CEI/reentrancy, #8 validation.

## 5. Known-bug classes in the SYMMIO 0.8.x line (public findings + fix commits)

- **v0.8 contest** (`2023-06-symmetrical-judging`): `liquidatePositionsPartyB` selective liquidation to steal funds (#160, High); `LibMuon` verification **hash collisions** (#180, #214, High); partial-fill accounting loss (#68, High); PartyB stake never released (#144, High); PartyB pending-locked-balance accounting (#211/#226); #189 "actions ... on partyB when corresponding partyA is liquidated allowing to steal all protocol funds".
- **v0.82-era** (`2023-08-symmetrical-judging`): #5 "liquidatePartyA requires signature which doesn't have nonce..." (fixed by PR #34); #6 inflated partyB balance; #35 ineffective liquidation signature expiration; decimal scaling in `depositAndAllocateForAccount` (#15/#28/#43, fixed by PR #35).
- **v0.83** (`2024-06-symmetrical-update-2-judging`): M-1 "PartyA's allocated balance could increase after `deferredLiquidatePartyA`"; M-2 "Deferred Liquidation can get stuck at step one if the nonce increment"; #11 collateral allocated while paused via internal transfer.
- **v0.84** (`2024-09-symmio-v0-8-4-update-contest-judging`): #40 "Unauthorized PartyB could settle PNL of other PartyBs" (fixed PR #57); #42 force-close DoS via settleUpnl (fixed PR #58). Unlabelled/unconfirmed: #65 hash collision in `verifyPartyBUpnl`, #34 "withdraw allows draining of funds", #22 reentrancy in liquidation, #25 ecrecover replay.
- Other fix PRs: #50 chargeFundingRate for liquidated partyA; #51 internal transfers to suspended user; #56 remove nonce increase in LockQuote; #59 Version 0.8.5.

## 6. On-chain aftermath signals (2026)

- **app.intentx.io:** still served 2026-10-03 with the shutdown modal and "Withdraw Funds now!".
- **intentx.io:** live, promotes Carbon; **docs.intentx.io:** DNS-dead; **Medium @IntentX:** redirects to @CarbonTerminal.
- **Carbon:** app.carbon.inc live; docs describe 950+ markets; `$CARBON` token not yet live.
- **INTX token:** no market data returned by CoinGecko API (2026-10-03); Coinbase shows "last known price ... 0.05069609 USD". No INTX→$CARBON migration or redemption program found.
- **No user complaints of stuck IntentX withdrawals** found on Reddit/X/Telegram/Discord searches.
- **Developer activity continues on the successor stack** (Intent-X GitHub org): solver-deposit-vault V2 work through 2026-05/06; intentx-SmartContracts commits Apr 2026 and 2026-09-22 ("Fix Party B").

## 7. Unknowns (explicit)

1. **Shutdown announcement source/date**: only the in-app banner; decision date unknown.
2. **Withdrawals post-2026-01-08**: whether withdrawals still process / funds stuck — unknown.
3. **Solver-deposit-vault audit**: auditor identity and report not public; 3 fix PRs remain unmerged; whether the deployed version contains the fixes is unknown.
4. **INTX/xINTX end-state**: no conversion to $CARBON or redemption mechanics found.
5. **Funding discrepancies**: seed lead "Magnus" vs "JJ" across sources; round dates differ.
6. **Version history**: "0.8.2 → 0.8.3 migration Sep-2024" unverified.
7. **Incidents**: no public hack found; undisclosed losses cannot be excluded.
8. **X/Twitter content** could not be read directly (x.com blocks scrapers).

## Appendix — key source URLs

- App banner: https://app.intentx.io/home
- IntentX docs (audits): https://web.archive.org/web/20260114125319/https://docs.intentx.io/additional-information/security-and-audits
- Quantstamp: https://certificate.quantstamp.com/full/intent-x/a195e62f-30b6-4219-b9e5-42af8a9e2fd5/index.html
- Sherlock v0.8: https://audits.sherlock.xyz/contests/85 · https://github.com/sherlock-audit/2023-06-symmetrical-judging
- Sherlock 2023-08: https://github.com/sherlock-audit/2023-08-symmetrical-judging · 2024-06: https://github.com/sherlock-audit/2024-06-symmetrical-update-2-judging · 2024-09: https://github.com/sherlock-audit/2024-09-symmio-v0-8-4-update-contest-judging
- SYMMIO audit registry: https://docs.symm.io/security-and-architecture/audit-reports
- GitHub: https://github.com/Intent-X/solver-deposit-vault · https://github.com/Intent-X/intentx-SmartContracts · https://github.com/SYMM-IO/protocol-core
- Carbon: https://medium.com/@CarbonTerminal · https://docs.carbon.inc/token/usdcarbon.md
- Data: https://api.llama.fi/protocol/intentx · https://startupintros.com/orgs/intentx
