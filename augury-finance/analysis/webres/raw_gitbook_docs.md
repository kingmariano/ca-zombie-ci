# Raw scrape: Augury Finance GitBook (still live, fetched 2026-10-12)

Source base: https://augury.gitbook.io/augury-finance/
All pages served as `.md` append (GitBook legacy export). Pages say "Last updated 5 years ago".

---

## tokenomics/contracts.md — CONTRACTS PAGE (key source of addresses)

> For the complete documentation index, see [llms.txt](https://augury.gitbook.io/augury-finance/llms.txt)...
>
> ### ✅ **Masterchef:** 0x6ad70613d14c34aa69E1604af91c39e0591a132e   ✅ **Community wallet:** 0x57831E532fc14846511D3B8A86AA692528e06A9a` `  ✅ **Developer team wallet :** 0xE2E26BAc2ff37A7aE219EcEF74C5A1Bf95d5f854  ✅ **Omen Token contract address:** 0x76e63a3E7Ba1e2E61D3DA86a87479f983dE89a7E
>
> ### ✅OwnerAddress:
> ### 0x1eadf5cac8e5751d8420775875d30985d9390312
>
> ### ✅AugurStakeBasedDividendsV1 - OMEN Single Stake
> ### 0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3
>
> ### ✅AugurStakeBasedDividendsV1 - OMEN-USDC
> ### 0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E
>
> ### ✅AugurStakeBasedDividendsV1 - OMEN-WETH
> ### **0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238**
>
> ### ✅AugurStakeBasedDividendsV1 - OMEN-WMATIC
> ### 0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26
>
> Always make sure you check the token address! Malicious actors can create fake tokens.

NOTE: This page does NOT list the legacy AugurDividendsV1 (0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61BC2B2) nor
DividendsV3 (0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4). "OwnerAddress" is an EOA (0x1ead...) even though repo
README says MasterAugur "is to be owned by our Timelock" on mainnet.

## tokenomics/the-triple-yield-advantage-dividends.md (key claims)

> **How dividends work?** Staking OMEN token in the OMEN portal (USDC,WMATIC or WETH for now) or single stakes results in the following weekly dividend payment:
> I. 40% of **all** the fees from all **swaps** that occur on the platform (given to you in USDC).
> II. 60%\* of **all deposit** fees within the platform (40% given to you in USDC, 20% reinvested as described directly below).
> III. 20% of **all** additional investments that are made outside the platform (e.g. we will be using a portion of the deposit fees (in 2) to re-invest into low-risk stable coin investments through protocols like curve and other Stable-LP pairs). The return from this gets added back into your weekly dividend payout.
>
> Here is the direct link to the community wallet: https://polygonscan.com/address/0x57831e532fc14846511d3b8a86aa692528e06a9a
> Incase you don't like links here is the adress : **0x57831E532fc14846511D3B8A86AA692528e06A9a**
>
> "**Am I able to get dividends if I am in portals?** Yes, but please don't forget that dividends are calculated based on your staked OMEN... it's not related to the Lp Value or total liquidity in those pools."
> Dividend math example quotes: "your eligible dividends percent for the period in that pool would be: `5% [(100 + 100) / (1000 + 3000)]`" ...
> "Don't forget to buy more omen !"

## products/portals/farm-weights.md (full)

> # Farm Weights
> * OMEN-USDC 100X
> * OMEN 60X
> * WMATIC 10X
> * WBCT 10X
> * WETH 10X
> * QUICK 5X
> * USDC 10X
> * USDT 10X
> * DAI 10X
> * PDOGE 3X
> * LINK 10X
> * SUSHI 5X
> * **AGA 5X**
> * **AGAr 5X**

## security/emergency-withdraw.md (full, incl. pool ID table)

> If something happens to Augury Finance front-end such as a DDoS attack or a temporary outage, farmers can still withdraw their tokens by interacting directly with the MasterAugur contract.
> Masterchef: 0x6ad70613d14c34aa69E1604af91c39e0591a132e
> Use the farm or pool ID listed below to withdraw your staked tokens:
>
> | Farm / Pool ID | Token Name |
> | 0 | OMEN |
> | 1 | OMEN-USDC LP |
> | 2 | WMATIC |
> | 3 | WBTC |
> | 4 | WETH |
> | 5 | QUICK |
> | 6 | FISH |
> | 7 | USDC |
> | 8 | USDT |
> | 9 | DAI |
> | 10 | POLYDOGE |
> | 11 | LINK |
> | **12 | AGA** |
> | **13 | AGAr** |
> | 16 | SUSHI |
> | 17 | OMEN-WETH |
> | 18 | OMEN-WMATIC |

(No rows 14/15 in the docs table — those pid numbers are not described in public docs.)

## master.md — Introduction (full product list; "Sentinel" claim)

> Augury Finance is a financial ecosystem on the Polygon (MATIC) blockchain which focuses on trust, community ownership, and sustainable returns...
> * **Triple Yield Advantage:** Weekly Dividends for Staking OMEN tokens
> * **Swapping Capabilities**
> * **Pooling**
> * **Portals:** We offer vaults for long-term storage of your coins
> * **Gamification:** ...predict the future of how a coin will perform
> * **Governance:** ...eventually allow you to vote on... fees... community pot of OMEN tokens, potential token burns...
> * **Augury Cauldron:** This is our launchpad for new products...
> * **Augury Sentinel:** Security is a core tenant within Augury Finance, and we're working on a product called Sentinel which helps to alert our community of on-chain events with the platform. For non-developers, this can give you instant insight into our contracts and any changes that get made with the contracts.
> * **So Much More:** Cross-Chain integrations, user/community growth, additional gamification, NFTs and more.

## security/introduction-to-security.md (audit claims)

> We are consistently and actively pursuing continual auditing to make sure Augury Finance remains a **safe and reliable** platform for all investors. We aim to have quarterly audits by top auditors.
> We started with the infamous MasterChef for our base contract, because the `MasterChef` has been heavily audited and is currently used in production today.
> [**RugDoc Report**](https://rugdoc.io/project/augury-finance/) [**Certik Report (ongoing)**](https://www.certik.org/projects/augury)
> **Rug-Pull prevention.** No migrator code. Emergency withdraw.

## security/migrator-code-removed.md (full)

> We have completely removed the migration capability within our contracts so that users are protected against an exploit that could cause a loss of funds. Once you stake your funds with us, no one at Augury Finance can move (or remove) them.

## products/vaults.md (excerpt)

> Augury's vaults have a 4.5% performance fee, along with a .1% withdrawal fee. These fees help feed the Augury ecosystem and are split half to the dev wallet (0xe2e26bac2ff37a7ae219ecef74c5a1bf95d5f854), half to the community wallet (0x57831e532fc14846511d3b8a86aa692528e06a9a). The performance fee is taken out of the tokens earned through staking in the vault. The withdrawal fee is taken out of the total amount of Omen withdrawn. The community wallet is the wallet used to pay weekly dividends... The devs have thought about this and will sell other tokens from the community wallet when available to fund the weekly dividends, ensuring you receive the dividends you are entitled to while also avoiding any additional sell pressure on Omen.

## tokenomics/tokenomics-1.md (excerpt)

> **The OMEN token** Pre-minted: 0 OMEN; Tokens Pre-sold: 0
> ~~IFO: 670k (maximum of 1M)~~ ~~Maximum Number of OMEN: 77.7M~~
> IFO: 6.7M OMEN (listed through our partners)
> Augury Cauldron: 3.2M OMEN *(Only 400k Omen has been sold in this Cauldron. Leftover **2.8m** Omen is **forever locked**)*
> ~~Total OMEN: 777.777.777~~ Total OMEN: 60.000.000
> Emission Rate: 17.77 OMEN/Block; ... **Approximate emission end date is August 31st, 2021.**
> ## Augury Finance Team: 6M OMEN (10%)
> * Rolling-cliff, Maximum 5% of monthly OMEN distributed to team...

## products/portals/pools-faq.md (excerpt)

> **OMEN** native pools have a 0% fee. Other pools have a 4% fee, which is paid back to people who are staking **OMEN.**
> **How many hours should I have to wait to harvest?** None! You can harvest immediately.

## products/governance.md (excerpt)

> As the **Augury Finance ($OMEN) token** is a governance token, holding the **$OMEN** gives you the ability to vote... **$OMEN** can only be acquired through interactions on the Augury Finance platform.

## roadmap.md (excerpt)

> **Now:** **Launch:** with Polycat and through our very own Augury Cauldron!
> Q3 (July-Sept): Augury Airmail ... Dividend System upgrades ... Cross-Chain Integrations ... Augury Predictions
> Q4: Augury Marketplace (NFTs, Collectibles) ... Expanded Partnerships: Currently with Paraswap and Polycat.

## Other pages (summary)
- products/airmail.md: airdrops for OMEN stakers; partners list tokens.
- products/cauldron.md: overflow-method launchpad (PancakeSwap-style).
- products/augury-swap.md: aggregated DEX, Paraswap; "50% of any fees... to treasury... distributed to token holders" (per docs wording: "a portion of any fees").
- products/liquidity.md: LP tokens, "13+ pairs".
- products/untitled-1.md: Predictions game (Q3 2021).
- our-beginners-guide/contact-us/social-accounts-and-communities.md: broken legacy content-refs (socials not exported).
