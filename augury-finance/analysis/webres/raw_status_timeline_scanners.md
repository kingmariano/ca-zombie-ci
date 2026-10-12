# Raw scrape: project status, timeline & third-party scanners (fetched 2026-10-12)

## 1. Live site status — DEAD DAPP, DOMAIN REPURPOSED

`https://augury.finance/` (fetched 2026-10-12 via webfetch) now serves an **Australian online-casino
affiliate page ("Crown Pokies")** — completely unrelated to DeFi. Exact evidence:
- Page title/heading: "# Crown Casino Online Pokies at Crown Pokies: The 2026 Review"
- Footer: "Copyright 2026 © augury.finance"
- "This site is an independent guide and is not operated by, affiliated with or endorsed by Crown Resorts..."
- Internal asset paths like `/yardbc3417dc/Crown-Pokies-Casino...webp` (typical of a spam/seo farm).

Wayback Machine content notes:
- 2021-04-30: first capture of www.augury.finance (site existed).
- 2023-05-31 / 2024-06-25 captures (cleaned text) still render the Augury dApp shell:
  "Home | Augury Finance ... My Stats ... Total Staked $ 0.00 ... Dividends $ 0.00 Claim ... Infinitum ... Portals ... Infusions ... Infinitum ... Partnerships Latest News"
  => the dApp was still deployed and reachable on 2024-06-25.
- 2024-12-14 and 2025-03-03 captures: HTTP **522** (origin down / Cloudflare error).
- 2025-05-20 capture: page content **empty** (no dApp text) — site effectively dead.
- 2025-05-24/2025-06-05 captures of `/_next/...` asset URLs return HTML (parking/catch-all) —
  domains parking page period.
- 2026-07-10 capture: 200 (already the new casino content era).
=> Verdict: dApp alive through at least 2024-06-25; origin down/flaky from late 2024; by May 2025 no dApp;
   by Jul 2026 the domain serves unrelated casino affiliate content. (Confidence: high)

## 2. Medium blog — DELETED (404)
- Live https://auguryfinance.medium.com/ today: Medium "PAGE NOT FOUND 404".
- Wayback: many captures remain of individual posts (2021-06 → 2022-07 + later re-crawls; profile captured
  2025-11-14). Content still readable via web.archive.org.

## 3. X / Twitter — ACCOUNT SUSPENDED
- https://x.com/AuguryFinance (twitter.com/AuguryFinance): Wayback capture **2026-08-15** shows:
  "X Log in Sign up **Account suspended** X suspends accounts which violate the X Rules".
- Earlier captures: 2021-06-10 (200), 2022-08-21 (200), 2026-01-10 (301). Suspension date not pinned down;
  confirmed suspended as of the 2026-08-15 capture. (Confidence: high for that date)
- Team's later project account twitter.com/eternityrpg archived 2022→2025-01 (302 on 2025-01-14).

## 4. Telegram — STILL LIVE (as of 2026-10-12)
- https://t.me/auguryfinance preview (fetched today): "Download **Augury Finance** — **539 members, 19 online**
  Project site: https://augury.finance/ Medium: https://auguryfinance.medium.com Docs:
  https://augury.gitbook.io/augury-finance/ Announcement Channel: https://t.me/joinchat/4qkrMGD3o89lZWRh
  Price Chat: https://t.me/joinchat/CPsRJLohrhc0Y2Y0"
  (Numbers are as rendered in the preview card; group still exists.) (Confidence: medium-high)

## 5. GitBook — STILL LIVE (fetched 2026-10-12)
- https://augury.gitbook.io/augury-finance/ fully readable (also `llms.txt` + per-page `.md` export).
  Pages marked "Last updated 5 years ago". (Confidence: high)

## 6. CoinGecko (API + site, 2026-10-12)
- id `augury-finance`, symbol OMEN, contract 0x76e63a3e7ba1e2e61d3da86a87479f983de89a7e (polygon-pos).
- Description: "Augury Finance is a DeFi platform that offers a Triple Yield Advantage (Weekly Dividends,
  Airmail and Staking). Additionally, new projects can get started through the Augury Finance Cauldron."
- Links: homepage https://augury.finance/ ; twitter `auguryfinance` ; telegram `auguryfinance` ;
  discord.gg/576EUqQKej ; announcements https://auguryfinance.medium.com ; github augury-finance/core.
- Market (today): price ≈ $0.000768; FDV ≈ $12,549; total supply 16,336,205 (CoinGecko's circulating figure);
  ATH $0.714 on **2021-06-25**; mcap $0; 828 watchlist users; genesis_date: null.
- Tickers today: Quickswap OMEN/USDC ≈ $17/day vol; Sushiswap(Polygon) OMEN/WETH ≈ $14/day vol. (~$31/day total)

## 7. DefiLlama (protocol page, 2026-10-12)
- https://defillama.com/protocol/augury-finance : Category Yield; TVL **$284,214** (Polygon); OMEN price
  $0.00077; ATH $0.71; ATL $0.000088; FDV $12,509; Treasury $863.80 (stablecoins $479.52, own tokens $373.71).
- "**Audits: No**". Method: "MasterAugur(MasterChef) contract is used to pull LP token amounts. LP tokens are
  unwrapped and each token token balance is considered in the TVL sum." (adapter:
  github.com/DefiLlama/DefiLlama-Adapters/blob/main/projects/auguryfinance/index.js — uses poolLength/poolInfo)
- X/Twitter link: https://x.com/AuguryFinance ; GitHub: https://github.com/augury-finance
- CAUTION: DefiLlama TVL for dead projects may misvalue stuck LP/OMEN; treat as indicative only.

## 8. CertiK Skynet (audit status)
- https://skynet.certik.com/projects/augury (fetched 2026-10-12). Key rendered text:
  - "Code Audit History — **0 Audits available** | Final Report Delivered"
  - "Augury Finance audit is in progress · Final Report Delivered 100%" / "Project Scheduled"
  - "The final report has been delivered to the project team after extensive review of the findings and
    appropriate changes." (generic Skynet boilerplate for each stage)
  - Token Scan: address 0x76e63a3e7ba1e2e61d3da86a87479f983de89a7e; Token Scan Score **68.19**;
    "Deployer Address 0xE...854"; "Owner Address 0x6...32e"; "Top 10 Holders Ratio **75%**".
- A search-engine snippet of the same page: "This project is scheduled for a security assessment. Our
  security experts are currently onboarding the client and preparing to initiate the audit process."
- No CertiK audit PDF/report is discoverable. GitBook says "Certik Report (**ongoing**)" with link
  https://www.certik.org/projects/augury. DefiLlama says "Audits: No".
=> Best reading: **no completed CertiK audit report was ever published**; the listing stayed in
   scheduled/in-progress state. (Confidence: medium-high)

## 9. GoPlus token security (API, 2026-10-12)
POST/GET https://api.gopluslabs.io/api/v1/token_security/137?contract_addresses=0x76e63a3e7ba1e2e61d3da86a87479f983de89a7e
Result for OMEN:
- is_open_source 1; is_proxy 0; **is_mintable 1**; owner_address **0x6ad70613d14c34aa69e1604af91c39e0591a132e**
  (= the MasterAugur contract itself is the token owner); owner_balance ≈ 6,455,556 OMEN (12.6%);
  creator_address **0xe2e26bac2ff37a7ae219ecef74c5a1bf95d5f854** (dev wallet);
- can_take_back_ownership 0; owner_change_balance 0; hidden_owner 0; selfdestruct 0; is_honeypot 0;
  is_blacklisted 0; is_whitelisted 0; transfer_pausable 0; trading_cooldown 0; buy_tax 0; sell_tax 0.
- holder_count **3830**; lp_holder_count 287; total_supply 51,047,375.326... (matches "Total OMEN Minted:
  51,047,375" from the Aug-2021 Medium post — note the 4,425,088 "burned" figure is NOT reflected in
  totalSupply, i.e. burns were likely transfers to a dead address, not burn() calls).

## 10. isthiscoinascam.com (third-party, auto-generated — LOW quality source)
- https://isthiscoinascam.com/check/augury-finance : "Safety Score: 10% ... Rated F"
  Buckets: Liquidity & Market 0 F (67% · medium); Team Credibility 0 F (25% · low); Social Behavioral 20 D;
  Contract Mechanics 5 F (20% · medium); Holder Distribution (0% · low).

## 11. RugDoc (former report link)
- GitBook links https://rugdoc.io/project/augury-finance/ — **now 404 ("Page not found - RugDoc IO")**.
- No Wayback captures of that RugDoc project page (CDX empty). The RugDoc "report" referenced in 2021 docs
  is not retrievable today. (Confidence: high that it is not currently retrievable)

## 12. PolygonScan spot data (search snippets, 2026)
- DividendsV3 0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4: "Contract: Verified | Balance: $725.27 across 1
  Chain | Transactions: 38468 | As at Sep-05-2026" => still heavily interacted with (claim transactions).
- Legacy DividendsV1 0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61BC2B2 (parent-provided context: holds ~50,759 USDC).
