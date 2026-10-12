# Augury Finance (Polygon) — Web Research Findings

Research date: **2026-10-12**. Method: web search + firecrawl scrapes + live fetches + web.archive.org
(CDX API). Read-only; no transactions. Companion raw files in this folder:
`raw_gitbook_docs.md`, `raw_medium_posts.md`, `raw_status_timeline_scanners.md`, `raw_github_team_aga.md`.
Confidence key: **H** = multiple primary sources agree; **M** = single/fuzzy source; **L** = weak/inferred.

---

## 1. What Augury Finance was — type, launch, team, docs, fate

- **Type (H):** Polygon DeFi yield platform: MasterChef fork ("MasterAugur") farm + weekly USDC dividends
  for staking/staked-LP holders + OMEN governance token + aggregator swap (via ParaSwap) + airdrop service
  ("Airmail") + launchpad ("Cauldron"). Docs self-description: "Augury Finance is a financial ecosystem on
  the Polygon (MATIC) blockchain which focuses on trust, community ownership, and sustainable returns."
  (https://augury.gitbook.io/augury-finance/master.md)
- **Launch (H):** Website live by 2021-04-30 (Wayback). First Medium post 2021-05-10 ("launching at the end
  of May, 2021"). Polycat "AugCat" IFO: sale opened **2021-06-09**; platform went live **2021-06-13**
  ("On Sunday, June 13, Augury Finance will go live." — Medium IFO post, 2021-06-05; matches repo commit
  "Augury Finance v1" 2021-06-13). OMEN ATH $0.714 on 2021-06-25 (CoinGecko).
- **Team (M-H):** Anonymous/pseudonymous. Handles publicly used: **"North"** (lead — "Our core team built
  Augury Finance last year. I am currently a member of the Polygon Ecosystem DAO/Polygon Builders
  (associated with Augury)" — Frax forum, 2022-01-13), **"Dirk"** (dirk_manjaw442), **"Major"** ("King of
  Tokenomics" per Medium 2021-06-30). GitHub org `augury-finance`; a second GH user `augury-raven` made the
  init commit (2021-06-08) but no longer resolves. No real names found. Claimed "over 100 years of combined
  development experience" (Medium 2021-05-10).
- **Docs (H):** GitBook **still live today**: https://augury.gitbook.io/augury-finance/ ("Last updated
  5 years ago" on pages). A legacy Notion knowledge base (augurydocs.notion.site) linked in Sep 2021 is
  JS-gated/unreadable today.
- **Shutdown/sunset (H):** **No formal sunset/shutdown announcement exists anywhere in the Medium archive
  (23 posts, last activity early 2022, all retrieved via Wayback).** The project simply faded after the
  Eternity pivot (see §6 timeline). By 2024-06-25 the dApp still rendered in Wayback; origin had 522 errors
  in Dec 2024/Mar 2025; by 2025-05-20 the site served no dApp content. **Today (2026-10-12) the domain
  augury.finance serves an unrelated Australian casino-affiliate page ("Crown Pokies… Copyright 2026 ©
  augury.finance")** — the DeFi front end is gone and the domain was repurposed. (H)
- **Social status today (H/M):** X/Twitter **@AuguryFinance is SUSPENDED** ("Account suspended. X suspends
  accounts which violate the X Rules" — Wayback capture 2026-08-15). Medium publication **deleted (404)**.
  **Telegram t.me/auguryfinance still exists** (preview: "539 members, 19 online"; fetched 2026-10-12).
  GitBook still live. GitHub last commit **2021-07-21** ("Delete AugurDividendsV1.sol"). (H)
- **Market today:** OMEN ≈ $0.00077; FDV ≈ $12.5k; only live volume ≈ $31/day total across Quickswap
  (OMEN/USDC) and Sushiswap Polygon (OMEN/WETH); CoinGecko ATH $0.714 (2021-06-25). DefiLlama still shows
  "Augury Finance" TVL $284,214 (Polygon) — derived from stuck MasterAugur LP balances via poolInfo; treat
  as indicative, not liquid value.

## 2. Exploits / incidents / hacks / post-mortems

- **No hack/exploit/drain of Augury or OMEN was found in any public source** (searches incl. rekt/slowmist
  queries, DeFiHackLabs GitHub code search for "augury" = 0 results, general web/portal searches). (M-H
  negative result — absence of evidence, not proof.)
- **Only incident found — Polycat IFO contract bug (June 2021), "IFO Post Mortem (Important Update)":**
  a math error in the first Polycat IFO contract prevented users from withdrawing OMEN; Polycat redeployed
  a new IFO contract, but **670,000 OMEN were permanently stuck in the broken contract** ("these OMEN
  tokens are 'dead'… They are completely unrecoverable"). Augury minted a replacement 670,000 OMEN, so
  **1,340,000 OMEN were minted for the IFO, of which only 670,000 were ever sellable**.
  Source: https://web.archive.org/web/2021if_/https://auguryfinance.medium.com/ifo-post-mortem-important-update-a9ed1971345b (H)
- Token docs claim "Migrator functionality has been removed. Augury Finance cannot migrate your funds."
  (README + GitBook "Migrator Code Removed") — i.e., the classic rug vector was removed by design. (H)
- Third-party auto-scanner "isthiscoinascam.com" rates OMEN **F / Safety Score 10%** (2026-10-12);
  low-quality source, cited only as sentiment. (L)

## 3. Audits

- **CertiK (H on status, M on interpretation):** Skynet project page exists
  (https://skynet.certik.com/projects/augury) but shows **"Code Audit History — 0 Audits available"** and a
  generic "audit is in progress / scheduled" flow; **no completed CertiK report is published anywhere**.
  GitBook (2021) says "Certik Report (**ongoing**)" linking certik.org/projects/augury. DefiLlama protocol
  page says plainly **"Audits: No"**. Conclusion: **no completed third-party audit was ever published.**
- **RugDoc (H):** docs link https://rugdoc.io/project/augury-finance/ — **now 404; no Wayback capture
  exists**. Whatever 2021 RugDoc review existed is not retrievable.
- Docs claim (quote, GitBook security page): "We are consistently and actively pursuing continual auditing…
  We aim to have quarterly audits by top auditors. We started with the infamous MasterChef for our base
  contract, because the MasterChef has been heavily audited and is currently used in production today."
  (i.e., core = Sushi MasterChef fork, relying on upstream audits) (H)
- The "sentinel auditing" angle is a monitoring product, not an audit: **"Augury Sentinel"** (GitBook) /
  **"Augury Sentry"** (Medium 2021-05-10 & IFO post): "it will alert our community of on-chain events with
  the platform"; "we will be leveraging OpenZeppelin Defender". No evidence Sentinel/Sentry was ever
  shipped. (H for the claims, M for never shipped)

## 4. Other Augury contracts / pools found in docs or explorers

From GitBook contracts page (https://augury.gitbook.io/augury-finance/tokenomics/contracts, still live): (H)
- MasterChef (MasterAugur): `0x6ad70613d14c34aa69E1604af91c39e0591a132e` (matches DefiLlama adapter + GoPlus)
- OMEN token: `0x76e63a3E7Ba1e2E61D3DA86a87479f983dE89a7E`
- Community wallet: `0x57831E532fc14846511D3B8A86AA692528e06A9a` (also used for weekly dividends; fee split per vaults page)
- Developer team wallet: `0xE2E26BAc2ff37A7aE219EcEF74C5A1Bf95d5f854` (also OMEN creator per GoPlus)
- OwnerAddress listed: `0x1eadf5cac8e5751d8420775875d30985d9390312` — an EOA, despite repo README saying
  MasterAugur "is to be owned by our Timelock" on mainnet (discrepancy worth re-checking on-chain; M)
- AugurStakeBasedDividendsV1 (stake-based dividend contracts, per LP):
  - OMEN single-stake: `0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3`
  - OMEN-USDC: `0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E`
  - OMEN-WETH: `0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238`
  - OMEN-WMATIC: `0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26`
- **Not found in public docs/explorers:** any "farming v2", bond, NFT, or bridge contract addresses.
  Product names that existed without public addresses: Portals (farm), Pylons (single-stake), Infusions/Vaults,
  Infinitum (USDC-redeemable "increasing price floor" token; whitepaper was augury.finance/INFINITUM_AUGURY.pdf,
  now dead), Cauldron (launchpad), Airmail, Predictions. Legacy DividendsV1 `0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61BC2B2`
  and DividendsV3 `0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4` are **not** on the GitBook page; V3 shows as
  PolygonScan-verified with $725.27 balance / 38,468 txs (as of 2026-09-05) — still actively used. (M for V3 figures)
- **Dividends V1→V3 migration:** no public post found. GitHub evidence: repo commit 2021-07-21 added V3 and
  **deleted AugurDividendsV1.sol**; docs still describe the V1 "AugurStakeBasedDividendsV1" addresses.
  Best inference: migration ≈ mid/late July 2021, undocumented publicly. (M/L — needs on-chain confirmation.)
- **GitHub (H):** https://github.com/augury-finance (3 repos; only `core` original; last commit 2021-07-21).
  Team's later project: **Eternity P2E RPG** (twitter.com/eternityrpg; FTM/AVAX/Polygon; $GLORY, Olympus-style
  bonding) announced Jan 2022 via Frax forum + Medium; no credible launch traces found later.

## 5. AGA tokens on the Augury farm (pids 12+)

- **Confirmed (H):** GitBook farm weights list **"AGA 5X" and "AGAr 5X"**; GitBook emergency-withdraw pool
  table lists **pool 12 = AGA, pool 13 = AGAr** (table jumps from 13 to 16, so 14/15 existed but are not
  documented publicly — consistent with later additions).
- AGA project (independent sources, H): AGA Token by @AGAToken — "mining-backed yield farming and DeFi
  pledge and governance tokens" (Bitget); on Polygon from Mar 2021 (Quickswap AGAR-USDC, Sushi AGAR-MATIC;
  AGA Rewards/AGAr ERC-20 0xb453f1f2EE776dAF2586501361c457dB70e1ca0F); AGA Medium: "AGA Carbon Neutral
  Project" (2021-05-27). **AGA Carbon Credit (AGAc)** = 0xF2032813Aa3c8feEf7973e44A92e68ab11eE8021
  (Ethereum; also on Polygon); **AGA Carbon Rewards (ACAR)** exists as a separate token.
- **Not confirmed (explicit gap):** public docs do not mention pids 14/15, nor do any AGA/Augury sources
  found explicitly tie AGA Carbon Credit / AGA Carbon Rewards to specific Augury pids. Mapping pids 14/15
  to the AGA carbon tokens is plausible (4 AGA-related tokens ≈ pids 12–15) but is **not verified by web
  sources** — needs on-chain pid name/token checks.

## 6. Timeline (all dates from primary sources)

| Date | Event | Source |
|---|---|---|
| 2021-04-30 | Website first archived | Wayback |
| 2021-05-10..22 | First Medium posts; launch details; "launching end of May" | Medium |
| 2021-06-09 | Polycat "AugCat" IFO opens (2.01M USDC, 670k OMEN @ $3) | Medium |
| 2021-06-13 | **Platform goes live** | Medium + GitHub |
| 2021-06 | IFO post-mortem: 670k OMEN stuck "dead" in broken IFO v1 | Medium |
| 2021-06-25 | OMEN ATH $0.714 | CoinGecko |
| 2021-06-30 | New tokenomics: emissions to end Aug (~60M supply; −93%) | Medium |
| 2021-07-21 | Last GitHub commit; DividendsV3 added, AugurDividendsV1.sol deleted | GitHub |
| 2021-08-17 | Emissions end (accelerated); Infusions launch | Medium |
| 2021-09-06..08 | Infinitum + Pylon announced/launched (90% Infinitum + 10% OMEN) | Medium |
| 2022-01-13/14 | Eternity pivot (Frax forum + "Go Forward"); "over $1.3MM in USDC" dividends to date | Frax/Medium |
| 2022 (H1) | Last Medium posts (Eternity) | Medium |
| 2024-06-25 | dApp still renders via Wayback | Wayback |
| 2024-12/2025-03 | Origin returns 522 | Wayback |
| ~2025-05 | dApp gone (parking/blank) | Wayback |
| 2026-10-12 | Domain = casino affiliate; X suspended; Medium 404; Telegram+GitBook live; OMEN ~$31/day vol | live checks |

## 7. Screenshot-worthy facts (with exact quotes in raw files)

1. `augury.finance` today = "Crown Pokies" casino page, "Copyright 2026 © augury.finance". (raw_status file)
2. "**Account suspended**" on X @AuguryFinance (Wayback 2026-08-15); Medium publication 404/deleted.
3. "**To date, we have issued over $1.3MM in USDC to $OMEN stakeholders.**" (Go Forward, 2022-01-14)
4. "**no more OMEN will ever be minted** … Total OMEN Minted: 51,047,375; Total OMEN Burned: 4,425,088;
   Maximum Supply: ~46,622,287" (Aug 2021) — note GoPlus shows totalSupply still 51,047,375 on-chain (burns
   likely to dead address, not burn()).
5. IFO post-mortem: "these OMEN tokens are **'dead'** … completely unrecoverable" (670k OMEN lost).
6. Dividends promise: "40% of all the fees from all swaps… 60% of all deposit fees… 20% of all additional
   investments…" (GitBook) + "We aim to have **quarterly audits by top auditors**" + "Certik Report (ongoing)".
7. Community wallet `0x57831E532fc14846511D3B8A86AA692528e06A9a`; dev wallet
   `0xE2E26BAc2ff37A7aE219EcEF74C5A1Bf95d5f854`; vault fee split "half to the dev wallet… half to the
   community wallet"; "The community wallet is the wallet used to pay weekly dividends."
8. CertiK Skynet: "**0 Audits available**"; "Top 10 Holders Ratio **75%**"; Token Scan Score 68.19.
9. GoPlus: OMEN **is_mintable = 1**; token **owner = MasterAugur contract itself**
   (0x6ad70613…132e, holding ~6.46M OMEN / 12.6%); creator = dev wallet 0xE2E26B…; 3,830 holders; no
   honeypot/tax/blacklist/pause.
10. Telegram group still live today: "Augury Finance — 539 members, 19 online" with links to the (dead) site.

## 8. Explicit "nothing found" list

- No shutdown/sunset announcement (project faded silently; no "we are closing" post).
- No hack, exploit, drain, or exploit post-mortem for Augury/OMEN in public sources.
- No completed third-party audit (CertiK never delivered a public report; RugDoc page unrecoverable).
- No public addresses for farming v2 / bonds / NFTs / bridges / Pylons / Infusions / Infinitum contracts.
- No DividendsV3 migration announcement (only GitHub commit evidence).
- No confirmation of pids 14/15 token names (AGA carbon tokens) in public docs.

## 9. Key source URLs

- GitBook (live): https://augury.gitbook.io/augury-finance/ (contracts, dividends, farm-weights, security pages)
- Medium archive (publication deleted): Go Forward — https://web.archive.org/web/20220706184604/https://auguryfinance.medium.com/augury-finance-go-forward-65bed3478af6 ; IFO post-mortem — https://web.archive.org/web/2021/https://auguryfinance.medium.com/ifo-post-mortem-important-update-a9ed1971345b
- GitHub: https://github.com/augury-finance/core (last commit 2021-07-21)
- CertiK: https://skynet.certik.com/projects/augury ; DefiLlama: https://defillama.com/protocol/augury-finance
- CoinGecko: https://www.coingecko.com/en/coins/augury-finance ; GoPlus API: https://api.gopluslabs.io/api/v1/token_security/137?contract_addresses=0x76e63a3e7ba1e2e61d3da86a87479f983de89a7e
- Frax forum (team): https://gov.frax.finance/t/eternity-rpg-x-frax/662
- Wayback CDX evidence: augury.finance timeline, twitter.com/AuguryFinance (2026-08-15 suspended), medium CDX.
