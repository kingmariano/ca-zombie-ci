# Raw scrape: GitHub, team identity, AGA partner tokens, Eternity pivot (fetched 2026-10-12)

## 1. GitHub org `augury-finance` (github.com/augury-finance)
- Account id 83373888; 3 followers; created ~June 2021. 3 repos:
  1. **core** (Solidity, 10 stars, 4 forks) — "Welcome to Augury Finance! This repository contains the OMEN
     Token as well as our `MasterAugur` and Strategies that we will run on the platform."
  2. assets — fork of sushiswap/assets
  3. default-token-list — fork of sushiswap/default-token-list
- Repo https://github.com/augury-finance/core : 1 branch (`main`), 0 tags, **11 commits**.
  Last commit **2021-07-21: "Delete AugurDividendsV1.sol"** (and, minutes earlier, "dividends").
- Commits (all 2021): 06-08 init (author `augury-raven`); 06-13 "Augury Finance v1"; 06-15 "Final V1
  Dividends", "master augur", "tests passed"; 06-18 "Interfaces"; 07-21 "dividends" + "Delete AugurDividendsV1.sol".
- Contributors: only `augury-finance`. (This repo has no Strategies folder in the current tree.)
- Files in `contracts/`: DividendsV3.sol (39,954 b), MasterAugur.sol, OmenToken.sol, Operators.sol,
  Referral.sol, Timelock.sol, libs/{IDividends,IOperable,IReferral,IStrategy}.sol
- README (raw, full):
  > # Augury Finance
  > This repository contains the OMEN Token as well as our `MasterAugur` and Strategies...
  > Additionally, we have included our `Timelock` here, which is a fork from compound.finance
  > The `OMEN` token contains governance information so that eventually our community can govern itself.
  > ## Security
  > Migrator functionality has been removed. Augury Finance cannot migrate your funds.
  > The starting deposit fee on most of our pools (except OMEN/OMEN-USDC) is 4% and there are no withdrawal fees (0%).
  > The `emergencyWithdraw()` method on `MasterAugur` has been included so that you can call this directly through
  > the Mainnet. For details on this, please visit our Gitbook!
  > On the `mainnet` This contract is to be owned by our `Timelock`.
  > Enjoy reading these files. Have a wonderful day. God Bless!
- NOTE: second GH account `augury-raven` (author of "init" commit) no longer resolves via GitHub API
  (deleted/suspended or renamed). (Confidence: medium)

## 2. Team identity — pseudonymous, later pivoted to "Eternity" (P2E game)
Source: Frax governance forum thread "Eternity RPG x Frax" (https://gov.frax.finance/t/eternity-rpg-x-frax/662,
posts Jan 13-16, 2022), user `Eternity` (self-described "North"):

> Our core team built Augury Finance last year. I am currently a member of the Polygon Ecosystem DAO/Polygon
> Builders (associated with Augury). We have built several products on-chain and expanded our team to help
> create Eternity. We're planning on launching Eternity at the end of this quarter.

- Eternity: Play2Earn RPG for FTM, AVAX, Polygon; tokens/mechanics: $GLORY, Olympus-style bonding,
  NFT items/heroes; planned launch end of Q1 2022; beta late Feb 2022 planned.
- Team handles seen publicly: **"North"** (lead), **"Dirk"** (dirk_manjaw442), **"Major"** ("King of
  Tokenomics", named in Medium 2021-06-30). No real names/doxx found. (Confidence: medium-high on
  pseudonyms; high that team is not doxxed publicly)
- Eternity socials from the Jan-2022 Medium post: twitter.com/eternityrpg, discord.gg/WrRkdF8Wmu,
  twitch.tv/eternityrp. (eternityrpg X account has archive captures 2022→2025-01.)

## 3. AGA partner tokens farmed on the Augury farm (pids 12+, weights 5X)
Augury docs (GitBook) list farm weights: **AGA 5X, AGAr 5X** (all others are named assets).
Augury emergency-withdraw table lists **pool 12 = AGA, pool 13 = AGAr**. (Docs do not describe pids 14/15.)

AGA project facts (independent sources):
- AGA Token by @AGAToken (Ethereum→Polygon, March 2021): "mining-backed yield farming and DeFi pledge and
  governance tokens" (Bitget web3 description). AGA + AGAr lived on Polygon via Quickswap (AGAR-USDC) and
  Sushi (AGAR-MATIC) pairs; AGA Rewards (AGAr) also on Ethereum at 0xb453f1f2EE776dAF2586501361c457dB70e1ca0F.
- AGA Medium (Tomasz@AGAToken) post history: "AGA and AGAr on Polygon (MATIC)" (2021-03-21);
  "Concluding Successful AGA Offering" (2021-04-12, raised $950,000); "AGA Carbon Neutral Project"
  (2021-05-27) — "AGA intends to become Carbon Neutral and to offer Carbon Neutrality-Removal services to
  other miners through Carbon Credits".
- **AGA Carbon Credit (AGAc/AGAC)**: Ethereum contract 0xF2032813Aa3c8feEf7973e44A92E68ab11eE8021
  (ethplorer: "total supply is 8000000100000"); also exists on Polygon per Coinbase converter pages.
- **AGA Carbon Rewards (ACAR)**: listed on stakingrewards.com/cryptotracker as a separate rewards token.
=> The four token names in the task (AGA Token PoS, AGA Rewards, AGA Carbon Credit, AGA Carbon Rewards) all
   exist and belong to the AGA project. Web sources directly confirm AGA + AGAr on Augury (pids 12, 13);
   pids 14/15 mapping to the AGA carbon tokens is plausible but NOT confirmed by public docs.
   (Confidence: high for AGA/AGAr; low-medium for pids 14/15 naming.)

## 4. Eternity / pivot aftermath
- Last Augury Medium posts: Eternity P2E RPG + Go Forward (early 2022). No later Augury posts found.
- Eternity itself did not visibly launch on Polygon/Polygon gaming scene (no credible product traces found
  in quick search; the X account stopped ~2025). Not investigated deeply — out of scope. (Confidence: low)

## 5. Partnerships mentioned in docs/site assets (from 2021-2022)
- Polycat Finance (IFO partner, launch partner), Paraswap (swap aggregation), FarmScan, Gravity,
  PolyShield, VesQ (partner logos on site assets).
- No bridge, bond, or NFT contracts of Augury were found in public docs (only planned: NFT marketplace,
  cross-chain integrations, Eternity bonding inside the game). No "farming v2" contract addresses found in
  public docs; product names were Portals (farm), Pylons (single-stake), Infusions/Vaults, Infinitum (token),
  Cauldron (launchpad). Infinitum whitepaper was at https://augury.finance/INFINITUM_AUGURY.pdf (dead link
  today; may exist in Wayback under that path).
