# H-22 web research — Serum v3 / OpenBook v1 zombie markets
Date: 2026-10-04 · read-only research (no transactions, no secrets). Artifact transport: pushed to GitHub kingmariano/ca-zombie-ci branch h-22-web-research because this sandbox has no local file-write tool. Copy to /home/heisenberg/CA/serum/analysis/.

## TL;DR (decision-relevant facts)
1. No evidence found of a "critical vulnerability in OpenBook reported/fixed around January 2023". Only Jan-2023 artifact: openbook-dex/program PR #27 "CI updates and bump deps" merged 2023-01-05T19:33:36Z ("adds dependency vulnerability scanning to the CI pipeline and bumps all dependencies"). No protocol fix; last on-chain deploy (parent: slot 168,006,653 = 2022-12-20) predates it. [Q1, med-high negative]
2. Only OpenBook critical ever: OtterSec v2 audit (Sept 7-20, 2023, commit 840e661): OS-OBK-ADV-00 "Missing Side Check On Market Vault Account" in place_order - Resolved; all 1C/1H/1M/1L Resolved. v2 only. [Q1, high]
3. OpenBook v1 never audited: mschneider, issue #6, 2022-11-19: "turns out it was never audited". [Q1, high]
4. No OSV/RustSec/GitHub advisories for openbook/serum_dex/openbook_dex; no OpenBook entry in Helius "Solana Hacks" or Pine Analytics incident history. [Q1/Q6, medium]
5. Serum tweet 2022-11-29: "The Serum software on mainnet became defunct... Since upgrade authority is held by FTX, security is in jeopardy, leading to protocols like Jupiter and Radium moving away." [Q2, high]
6. CoinDesk Nov 12, 2022 (also FTX court doc 8923-2): "The true power over Serum rested with FTX Group, which continues to hold the program update authority keys." Serum v3 (9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin) not upgraded since 2022-08-19; authority 6XvcBmETaz5ZNRhwiz1ochXitHG771d6rmK4Ug3NVr1g is a plain EOA (2,500,000 lamports, no data; re-verified). Todays keyholder not publicly attributed. [Q2, high facts / low attribution]
7. No post-FTX drains of Serum v3 markets found in web sources. [Q2, medium negative]
8. "500K-1M SOL locked" originates from one rough estimate: jnuno98, project-serum/serum-dex issue #268, 2025-02-10: "would say they are easily on the tens of thousands. Each market costed 4 SOL... around 500k-1M SOL lost" ("I'm not sure of any way to get a grasp of how many markets exist"). Reposted in openbook-dex/program #58 and SE 24425. No measurement; likely overstates recoverable rent (minimal markets 0.3-0.4 SOL; full ~2.8 SOL; parent sample ~0.297 SOL per market). [Q3, high provenance / low accuracy]
9. OpenBook FAQ: "Can I close a market and retrieve rent? In V2, you can close markets and retrieve rent. In V1, you cannot." [Q5, high]
10. CAN close on v1: own OpenOrders (~0.02-0.024 SOL each) and own token accounts. CANNOT: market, bids, asks, request queue, event queue (program PDAs), vault token accounts (vault-signer PDA). No CloseMarket instruction exists. [Q3/Q5, high]
11. Real cases: SE 24428 (~120 SOL across 40+ markets); SE 24500 (Oct 2026) on reclaiming excess rent after the 2026 rent reduction - technically possible (token-2022 withdraw_excess_lamports model) but DAO path unclear. [Q3/Q5]
12. Upgrade authority decodes (read-only RPC) as ProgramGovernanceV2 account 8xYs2tGXPayMtgsqs4NuMy7bnWr7DM9tnnkbY2SHVbys under RealmV2 "Serum Community Fork" BtD6wKiazt4EEvfw6tqDh1BPSVchGeqyZ1e4HhV9VHJ6 (owner GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw); seed = srmqPvym... (v1 program). Community mint DFnfxL8zyhZgjY6cEdnRqhtTTVWX1AfgKv99q3Z8o7Ne has supply 0 (never launched). [Q5, high]
13. OpenBook DAO (Realms, ~20 proposals, 9 members, treasury $0.41) dormant since ~2022/23; last visible activity = "Upgrade srmqPvym..." Completed (~4y ago) + failed vote-threshold proposals; no close/reclaim proposal ever. [Q5, high]
14. Fix requires a program upgrade. mschneider 2026-09-29 (issue #59): "Good idea, seems doable. Would be good for the solana network to shed a bit of account space. Feel free to reach out on twitter or tg." SE: approval needs "specific multisig signers... does not involve SRM holders", contact council members (Raydium/Mango). [Q5]
15. DefiLlama "Serum" $17,131,473 (2026-10-04) is NOT a vault-balance read: adapter projects/serum.js sums market-account accounting fields (baseDepositsTotal+baseFeesAccrued; quoteDepositsTotal+quoteFeesAccrued) for all 388-byte Serum v3 markets. Token USD: USDC $9.70M (56.6%), SOL $3.78M (22.0%), WETH $2.22M (12.9%), USDT $0.64M (3.8%). OpenBook adapter $1.16M; Serum Swap $0.24M. [Q4, high]
16. OpenBook v1 repo last commit 2023-01-05 (CI); only release v0.5.10 (2022-12-14); frozen since 2022-12. [Q1/Q5, high]

## Q1 details
- Repo: last commit c85e56deea 2023-01-05 "CI updates and bump deps (#27)"; releases: v0.5.10 2022-12-14. PR #27 quote above; merged 2023-01-05T19:33:36Z (created 2022-12-14).
- Parent on-chain: v1 last deploy slot 168,006,653 = 2022-12-20 → Jan-2023 changes never deployed.
- OtterSec report https://osec.io/reports/527e1c3e-b913-4a2a-9d82-88757467e4a0 (PDF: openbook-v2/audit/openbook_audit.pdf): scope Sept 7-20 2023, commit 840e661; finding table all Resolved (00 crit place_order vault-side; 01 high variance; 02 med close_authority; 03 low target_var).
- "turns out it was never audited" - mschneider, issue #6, 2022-11-19 (thread "Road to immutability"; robre: "Full immutability is dangerous. If/When a new bug would be discovered this would be fatal").
- Advisories: OSV crates serum_dex/openbook_dex/openbook = 0; GitHub advisories affects=openbook = []; RustSec 0.
- Searches for Jan 2023 OpenBook vuln found nothing; likely referents: PR #27 (Jan 5, 2023 dep scanning), OtterSec v2 critical (Sept 2023), Nov 2022 authority panic. CollinsDeFiPen history: "Solana developers preemptively forked Serum into OpenBook, effectively neutering the risk."
Other v1 advisories/exploits 2023-2026: none found.

## Q2 details
- FTX held upgrade authority (CoinDesk via Yahoo, Nov 12-13 2022); Serum tweet Nov 29 2022 (URL above), quoted by The Block, crypto.news, Daily Hodl, ForkLog, TokenInsight, Invezz.
- FTX court doc Case 22-11068-JTD Doc 8923-2: "The Serum Exchange became defunct in November 2022 following the collapse of FTX and Alameda"; "On November 15, 2022, a 'fork' of the Serum exchange called OpenBook was deployed. OpenBook uses the exact codes from the Serum exchange but without any ties to FTX."
- No serum upgrade post-FTX: last deploy 2022-08-19 (parent); authority EOA 6Xvc... unchanged/never burned.
- Migration: resources README ("FTX had access to it and funds could be stolen by the hacker, forked program with multisig control on Realms"; "deployed by a multi-sig"; "Still using SRM token for simplicity"). OpenBook live Nov 15 2022 (court doc); CoinMarketCap says Nov 14.
- Drains: none found. Status today: dormant; <100 users/day cited (serum-dex#268, 2025-02-10); DefiLlama still shows $17.1M stale accounting; OpenBook FAQ: "the orderbook still exists on-chain".

## Q3 details
- Original 500k-1M SOL estimate: project-serum/serum-dex#268 (2025-02-10) jnuno98 comment 2025-02-10T17:20:11Z (quote above); jmanprz: "99.9% of Solana markets are built with the purpose of being rugged"; "those lost SOL are lost forever and contribute to SOL burn".
- Reposts: openbook-dex/program#58 (2026-06-23, "each market costed 3 SOL"); SE 24425 (2026-06-23).
- Cost data: FAQ ~2.8 SOL; DexLab ~2.78+0.22; Smithii 0.4/1.5/2.8; GitHub #41 mentions 0.3 SOL market; parent sample ~0.297 SOL total.
- Medium deep dive (early 2023, Flipside): "over 16000 SOL and SOL derivative tokens being held in OpenBook market vaults... over 1.5M USDC and USDT".
- Tooling: Solana Compass (OpenOrders ~0.02+ SOL); OpenBook FAQ (old open orders closable); DropCopy close market = V2 only; Smithii no v1; Sol Incinerator/Alphecca token accounts only; nedim1511 (serum-dex#268, 2026-04-29) claims working close tx - UNVERIFIED, Discord/Tg contact, disputed in thread; SE 24428 answer (rent can only leave via program instruction; no market exit; governance only theoretical; SweepFees note).
- 2026 rent reduction (SIMD-0437, lamports_per_byte 696; solana.com/news/rent-reduction-deep-dive): issue #59 asks for excess-rent reclaim; requires upgrade.

## Q4 details
- api.llama.fi/protocol/serum 2026-10-04: currentChainTvls.Solana 17,131,473.29; mcap 2,385,951 (SRM). /protocols: Serum 17,131,473.29; OpenBook 1,156,646.66; Serum Swap 240,204.81.
- Adapter projects/serum.js: getProgramAccounts(9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin), filter dataSize 388, dataSlice offset 53 length span; decode MARKET_STATE_LAYOUT_V3_MINIMAL; add baseMint/baseDepositsTotal+baseFeesAccrued and quoteMint/quoteDepositsTotal+quoteFeesAccrued; timetravel:false; isHeavyProtocol:true; hallmarks ["2022-11-07 FTX/Alameda collapse","2023-04-01 Move to onchain data"].
- Layout file openbook-layout.js: baseMint, quoteMint, baseVault, baseDepositsTotal u64, baseFeesAccrued u64, quoteVault, quoteDepositsTotal u64, quoteFeesAccrued u64.
- Interpretation: market accounting fields, not vault reads; dead markets can be stale; includes fees. Token USD mix quoted above (tokensInUsd 2026-10-04).

## Q5 details
- Docs FAQ (openbook-docs/src/faq.md): v1 is fork of Serum V3; v2 complete rewrite; "Presently, all of the live integrations (with the exception of the MetaDAO) are using OpenBook V1. This will be changing shortly."; "In V1, you cannot" close markets/retrieve rent; "Does OpenBook have a token? We do not."
- V2 announcement https://x.com/openbookdex/status/1720402140919648263 (2023-11-08). No explicit dated v1 sunset announcement found.
- DAO: https://app.realms.today/dao/OPENBOOK ; https://v2.realms.today/dao/BtD6wKiazt4EEvfw6tqDh1BPSVchGeqyZ1e4HhV9VHJ6 - 9 members, ~20 proposals, treasury $0.41; proposals: Test proposal Succeeded; Adjust DAO rules Defeated; 4x Change vote threshold 51% Defeated (H1BiN...3KKSx, DsrFm...yTpLy, EB7XS...k6pDP, 8xYs2...HVbys); Upgrade srmqPvym... Completed; Add council member 8oy7j...CUvdD zeta tristan. All ~4y old.
- My RPC decode: 8xYs2... = 236B, type 19 = ProgramGovernanceV2, realm BtD6..., seed srmqPvym...; realm name "Serum Community Fork"; community mint DFnfx... supply 0.
- SE 24428 comments (Aseneca): upgrade needs "specific multisig signers", "does not involve SRM holders"; "council multisig members to approve"; suggests Raydium/Mango; "no exact examples" of successful v1 proposals. Issue #59 mschneider quote 2026-09-29. No proposal as of 2026-10-04.

## Q6 details
- Negative checks: OSV 0; RustSec 0; GitHub advisories 0; Helius Solana Hacks 0 mentions; Pine Analytics 0 mentions; news 0.
- Theoretical: stale resting orders remain takerable at stale prices (program still callable; crankers exist: openbook-explorer.xyz; SpaceMonkeyForever/openbook-cranker). Unquantified, no reports.
- Scam-market context: jmanprz quote (2025).

## Caveats
- Artifact pushed to GitHub branch h-22-web-research (paths h-22-web-research/web-research.md and .json); copy to /home/heisenberg/CA/serum/analysis/.
- Some quotes secondary (tweet via news). Reddit blocks scrapers (snippets only). Q1 is a negative finding. DefiLlama as of 2026-10-04 (ts 1791084083). RPC reads latest, not slot-pinned.

## Key URLs
https://github.com/openbook-dex/program ; https://github.com/openbook-dex/program/pull/27 ; https://github.com/openbook-dex/program/issues/6 ; https://github.com/openbook-dex/program/issues/58 ; https://github.com/openbook-dex/program/issues/59 ; https://github.com/project-serum/serum-dex/issues/268 ; https://solana.stackexchange.com/questions/24428 ; https://solana.stackexchange.com/questions/24425 ; https://solana.stackexchange.com/questions/24500 ; https://osec.io/reports/527e1c3e-b913-4a2a-9d82-88757467e4a0 ; https://raw.githubusercontent.com/openbook-dex/openbook-docs/main/src/faq.md ; https://raw.githubusercontent.com/openbook-dex/resources/main/README.md ; https://app.realms.today/dao/OPENBOOK ; https://v2.realms.today/dao/BtD6wKiazt4EEvfw6tqDh1BPSVchGeqyZ1e4HhV9VHJ6 ; https://api.llama.fi/protocol/serum ; https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/serum.js ; https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/openbook/index.js ; https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/helper/utils/solana/layouts/openbook-layout.js ; https://www.theblock.co/news/defi/2022-11-29-ftx-backed-dex-serum-calls-itself-defunct-promotes-community-fork-190566 ; https://crypto.news/ftx-supported-dex-declares-itself-dead-advocates-for-community-fork/ ; https://finance.yahoo.com/news/ftx-hack-sparks-revolution-serum-235117897.html ; https://restructuring.ra.kroll.com/FTX/ExternalCall-DownloadPDF?id1=MzA4NDI5Mw%3D%3D&id2=0 ; https://solana.com/news/rent-reduction-deep-dive ; https://solanacompass.com/tools/solana-token-account-rent-reclaim ; https://www.helius.dev/blog/solana-hacks
