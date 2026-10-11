# DeFIL (FILST / DFL / eFIL) — web + corpus research notes

- Date: 2026-10-11 (all live reads/fetches this day unless noted). Produced by the research subagent for the DeFIL Phase-2 deep-dive; saved verbatim (with minor formatting) by the parent.
- Read-only research: web, public docs, public GitHub, keyless public APIs and public RPC (`eth_call`). No transactions signed/sent; no keys used.
- Ethereum reads at block `0x18f5255` (= 26,169,941); BSC reads at latest via `bsc-rpc.publicnode.com`.
- Uncertainty is marked [U]; negative results are stated explicitly in §9.

## 0. One-screen summary
- DeFIL ("decentralized Filecoin lending and finance service platform") launched on Ethereum 2020-11-20 (v1), relaunched as "DeFIL 2.0" on ETH+BSC in Aug 2021 (migration 2021-08-12/13/16), Arbitrum added 2022-03-25. Project went silent June 2022 (last X post 2022-06-22; last Medium weekly 2022-06-20).
- Today (2026-10-11): `defil.org` is a GoDaddy "domain for sale" parking page; the GitBook support docs are still online (frozen, "last updated 4 years ago"); GitHub org `DeFIL-org` has 2 repos, last real commit 2020-11.
- Trackers: CoinGecko removed "defil" (API 404); CMC marks DFL (id 11740) and FILST (id 12595) as `untracked`; Coinbase still has static pages ("not tradable"). No CEX listing verified live (docs list Gate.io/ZB/ZBG/AEX historically).
- Value today is concentrated in the ETH FILST/USDT Uniswap-V2 pair `0xa2f6a219a51b4682e34a13a94c160d6c79cdca35`: 1,396,416 FILST + 714,487.847125 USDT (implied 0.51166 USDT/FILST), with 99.99% of the LP held by the ETH "Staking" farming contract `0x9e08bd9a1e3880902688b32d563046cab74d2f2f` (verified).
- A second, smaller pool exists on BSC (PancakeSwap): 1,038,200 FILST + ~139,005 USDT, implied $0.1335/FILST. Both pools: 0 trades in 24h. FILST/eFIL LPs on both chains are EMPTY. DFL-USDT LP ≈ $1,885.
- FILST is not open-mint: minting needs an mNFT (ERC-1155) + a DFL fee through `FILSTManage` (mint path is NFT-ownership-gated, see §6).
- One EOA (`0x557edaaf…`, no code) owns FILST on both chains and eFIL on ETH.
- No hack/exploit post-mortem exists anywhere we could find; the only known bridge incident is the Sept-2021 upgrade with a 1:1 airdrop compensation (§2).

## 1. Identity, registry, primary sources
- DefiLlama protocol `defil`: category Lending; chains Ethereum + Binance(BSC); twitter `defilofficial`; `deadUrl: true`; audits "2" (1 link); listedAt 2022-03-22; TVL at query: $1,757,132 total = ETH $1,618,264 + BSC $138,868 + pool2 $22,094 (staking $0). Sources: https://api.llama.fi/protocol/defil ; https://defillama.com/protocol/defil
- Official docs (still live): https://defilofficial.gitbook.io/support-center/ + llms.txt index. Contains: White Paper (file), Audit Report (17 audit-page images + 1 file), Contract Address page, FAQ, migration announcements, Bridge (FIL↔eFIL) guides, Arbitrum bridge tutorial, mint/redeem FILST guides.
- Official contract registry (docs, "Contract Address" page):
  - ETH: DFL-v2 `0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB`; DFL-USDT LP `0xd372a3221021df72eda38f77117d3a95f057e163`; eFIL `0x2a2cB9bA73289D4D068BD57D3c26165DaD5Cb628`; FILST `0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2`; FILST-USDT LP `0xa2f6a219a51b4682e34a13a94c160d6c79cdca35`; FILST-eFIL LP `0x7393aa9de6585ae2ec5e18abffe1ed07123d0e87`.
  - BSC: FILST `0x899e2a220CBC6eb1Ab154211353EDED74BC1e266`; DFL-v2 `0x6ded0F2c886568Fb4Bb6F04f179093D3D167c9D7`; eFIL `0x22B475f3e93390b7E523873ad7073337f4E56C2c`; USDT `0x55d398326f99059fF775485246999027B3197955`; DFL-USDT LP `0x3558c47c0f2309197857689d84cb620405e2c54d`; FILST-USDT LP `0xecf6aa34b19e31311eb92768888bddd25aa72933`; FILST-eFIL LP `0x3ce2669c9aaf8e717c739b1e9100fa792ad23835`.
  - Arbitrum: eFIL `0x66ba30d5D7c66aFd4ed41c3498eC9e20a03a1368`; DFL `0x31635A2a3892dAeC7C399102676E344F55d20Da7` (no FILST).
- Official token list repo (2021-08-10) lists ONLY ETH DFL: `0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB`, name "DeFIL-V2", symbol DFL: https://github.com/DeFIL-org/token-list/blob/main/defil.tokenlist.json
- GitHub: `DeFIL-org/defil-contract` (2020; contracts: DFL.sol, DeFIL.sol, EFIL.sol, MFIL.sol, StakingDFL.sol, StakingLP.sol, Timelock.sol, WhitePaperInterestRateModel.sol; last commit 2020-11-17). This 2020 repo is NOT the deployed 2.0 code; DeFIL 2.0 source has not been published as a repo [U].
- Socials: X https://x.com/defilofficial (1,769 followers, not verified, last post 2022-06-22 "Build and build."); Medium https://medium.com/@defilofficial (last post 2022-06-20 weekly report); Telegram t.me/defilorg / defilorgEN; Discord (dead link per X bio).
- Wayback: `app.defil.org` captures 2022-04-27… last 2025-04-04 (302); last 200 capture 2023-01-05. `defil.org` 91 captures, last 2026-05-19 (now parking page).

## 2. Incident / exploit / audit history
- DefiLlama hacks DB (1,299 incidents, 2026-10-11): ZERO entries for DeFIL / FILST / Filecoin Standard. Negative result.
- rekt.news / DeFiHackLabs / SlowMist hacked-DB: no hits surfaced ("DeFIL hack/exploit/rug", Chinese variants "跑路/崩盘/黑客/被盗"). [U: search coverage limits; not a proof of nonexistence.]
- Bridge incident (official, first-party): "Announcement on Airdrop for FILST Holders" (2021-09-22): "The upgrade of DeFIL's deployment of cross-chain bridge was completed on September 19, 2021. All functions have returned to normal … As to problems such as data display errors and unreceivable benefits during the previous cross-chain bridge upgrade, we decide to give airdrop as reward." Snapshot of FILST holders 2021-09-22 22:00 UTC+8; 1:1 FILST airdrop, both ETH and BSC; "the total number of issued FILST tokens remains unchanged at 3,144,704"; "Each FILST is anchored with 1G of FIL computing power… total computing power is still 3P". Also: "new nodes will adopt a two-way multi-node multi-signature scheme".
- No wind-down announcement, no post-mortem, no governance thread found. Death was silent (socials stop June 2022).
- Audits: DefiLlama metadata says audits "2" with one link: SlowMist certificate id `e84a975074cb9aef9299f9dec92311fd1458d0bbb4163adfadac8e16e0da3c61`; as of 2026-10-11 that URL renders "NOT FOUND". The docs' "Audit Report" page reproduces 17 audit-report page images + one attached file (likely the SlowMist report) [U exact date/scope]. Corpus said "1 audit"; DefiLlama says 2 — unresolved.
- Context (not incident): promoter post in filecoin-project/community discussion #195 (Aug 2021) claims "The amount of FIL deposited on DeFIL had reached 2 million…", DFL "available on Gate io, ZB, AEX and many other exchanges", backers "IPFS Ecological Foundation, FBG Capital, Fenbushi Capital, Monolith Capital, ZB Capital, ZBG Capital". FAQ names alliance members FILPool/AEX/KPool/LDPool. All project claims — unverified.

## 3. Bridge / cross-chain: is ETH FILST one asset bridged to BSC FILST?
Evidence:
1. Same system design across chains: docs/FAQ: DeFIL 2.0 multi-chain (Ethereum/BSC/Arbitrum); one system-wide FILST supply figure (3,144,704 in 2021; CMC + Coinbase both quote 3,144,704 as FILST "total supply" today); 1 FILST = 1 GiB of FIL hashpower.
2. Same owner EOA for FILST(ETH) and FILST(BSC): `0x557edaafd875569f0bd6abae1185c17fd5a30ba0` (eth_call `owner()`, both chains; no code on either chain; nonce 45). eFIL(ETH) owner is the same EOA.
3. Chain-specific minters: different `poster` (only-minter) contracts per chain — ETH `FILSTManage 0xcd429f23…`, BSC `0x81da5064…` — supply minted natively per chain by team contracts, not by a public lock-mint bridge.
4. DeFIL's own "bridge" (跨链桥): FIL→eFIL 1:1 "mapping token" conversions (trust-based, "credit-endorsed by the mining pool alliance"), plus a DFL old→new migration and an Arbitrum bridge tutorial. No bridge contract address is published in any doc.
5. The Sept-2021 "cross-chain bridge" upgrade & FILST 1:1 airdrop on both chains shows bridges/airdrops were team-operated.
6. Markets: ETH FILST implied $0.5117 vs BSC $0.1335 (both pools frozen, 0 trades/24h for years; supplies 1,959,936 vs 1,901,568). No arbitrage flow exists, and no third-party canonical bridge (LayerZero/Wormhole/Multichain/etc.) link was found for FILST.

**Determination (medium-high confidence):** FILST is conceptually ONE asset (single global supply & single admin) deployed as separate native contracts on ETH and BSC, with cross-chain movement only via DeFIL's own team-operated (multi-sig) bridge — not a public/trustless bridge, and not two independent deployments. Functionally, no working public FILST bridge path exists today [U: the bridge contracts were never published; whether the multi-sig still functions is unverifiable from public sources].

## 4. Token market history
- ETH FILST `0x7346ad4c…` (verified, "Filecoin Standard Token"): totalSupply 1,959,936 (live read; GeckoTerminal same); 212 holders (Etherscan snapshot "as at Aug-26-2026"); no DefiLlama/CoinGecko price (pools only).
- ETH FILST/USDT pair `0xa2f6a219…` ("JamUniswapV2Pair", verified; Uniswap-V2 fork, 0.3%): created 2021-10-11 03:58 UTC. Live reserves (block 26,169,941): 1,396,416 FILST + 714,487.847125 USDT; LP totalSupply 0.979559 LP; staking contract holds 0.979544 LP (99.9985%). TradingView lists the pair as FILSTUSDT.
- Volume: GeckoTerminal daily OHLCV — only 60 non-zero days; top day 2026-03-08 ≈ $3,188; 2025 total ≈ $4,603; 2026 total ≈ $3,678 (latest day ≈ $17). No meaningful market; liquidity was never removed — the USDT side parked at ~714.5k.
- BSC FILST `0x899e2a22…`: totalSupply 1,901,568; PancakeSwap FILST/USDT pair `0xecf6aa34…` created 2021-08-30 11:15 UTC; live reserves 1,038,200 FILST + ~139,005 USDT (TVL $278,010); implied $0.1335/FILST; last trades 2026-09-04 (1 FILST) and 2026-07-07 (594.54 FILST / $79.45); top day ever 2025-07-15 $52,295; 2026 total $192.
- FILST/eFIL LPs: BOTH CHAINS EMPTY (gecko reserve_in_usd 0; on-chain the ETH pair holds ~0.99 FILST + 982 eFIL — dust).
- DFL (`0x09ce2B74…`, "DeFIL-V2"): on-chain totalSupply 125,814,138.56; owner `0x6b4f20b2…` (Unitroller). Prices: Coinbase $0.0001127 (2026-10-11, "not tradable"); DFL-USDT LP `0xd372a322…` reserve ≈ $1,885; LP staked in pool2 farm `0x6b0c7d01…`.
- eFIL (`0x2a2cb9ba…`, "Ethereum FIL"): supply 87,105.55. 1:1 redemption promise is off-chain (FIL custody).
- CEX listings: docs FAQ listed AEX/Gate.io/ZB/ZBG for DFL and UniSwap/AEX for FILST — all historical; CMC/CoinGecko delisting + Coinbase "not tradable" are the current observable state.
- Airdrop/mint history: FILST "perpetual standard hashrate" launched 2021; 1:1 airdrop Sep 2021; total issued 3,144,704 as of Sep 2021; current chain supplies sum to 3,861,504, implying later mints beyond the 2021 figure [U].

## 5. Corpus grep results
- `/home/heisenberg/CA/zombie_hunt/FINDINGS.md` L-2 row: `| DeFIL | Binance,Ethereum | $1.760M | 220d | 1 | deadUrl | defil |` (only substantive corpus mention).
- `x_social_leads.md`: no DeFIL rows (matches are the word "DefiLlama"). `verification_live_funds.md`: no DeFIL section. `incidents_zombie_contracts.md`: only a link label to DefiLlama's hacks DB. `non_llama_and_directories.md`: no DeFIL. `github_stuck_funds.md`: NO matches for DeFIL/FILST/minerfil/mFIL/eFIL/DFL.
- `/home/heisenberg/CA/zombie-deep/*.md` (incl. LIVE-PROFIT-PATHS.md): NO matches. DeFIL was not covered by the first sweep.

## 6. Mint mechanics, architecture, known-vulnerability notes
**FILST mint mechanics (public verified source, ETH):**
- `FILST.sol` (solc 0.8.7, verified): `mint(address,uint256)` and `burn(address,uint256)` are `onlyPoster`; `setPoster(address)` is `onlyOwner`; `owner()`/`transferOwnership` = Ownable. → nobody except the poster can mint; poster is set by the owner.
- Live: ETH `poster()` = `0xcd429f23088b3fa4aabff61dd5f9e534793f9944` = verified `FILSTManage`; BSC `poster()` = `0x81da5064…` (contract, likely BSC FILSTManage). Owner of FILST (both chains) = EOA `0x557edaaf…` (no code, nonce 45).
- `FILSTManage.mint(address _recipient, uint256 _tokenId, uint256 _nftAmount)` is `external` and permissionless apart from two gates: (1) `require(miningNFT.balanceOf(msg.sender, tokenId) >= nftAmount)` — caller must hold the mNFT (ERC-1155); (2) a DFL fee (`getMintFee` = filstAmount × `mintFeeRatio`/`MINT_FEE_DENOMINATOR`, converted to DFL by `PriceConverter`). It then escrows the mNFT into FILSTManage and calls `filst.mint(_recipient, amount)` where `amount = nftAmount × MNFT_TO_FILST_RATIO(1024) × 10^18`. `burn(minerId, tokenId, amount)` lets a FILST holder burn against a miner's minted amount.
- `PriceConverter` `0x7f5f88f7…` (verified) is LIVE and reads the actual pairs: `convertFromFilstToDFLAmount(1e18)` ≈ 4,612.24 DFL per 1 FILST. So the DFL-denominated mint fee for minting 1 FILST ≈ 4,612.24 × feeRatio DFL. Live `mintFeeRatio` = 50 / 1000 (5%) — read on-chain by the parent.
- `FILSTManage.getTotalMintedAmount()` = 1,959,936 FILST → the entire current ETH supply was minted via this contract (no net burns).
- Relevant FILSTManage views: `miningNFT()`, `miningNFTManage()`, `filstPool()`, `usdtToken()`, `dfl()`, `priceConverter()`, `cumulatedFee()`, `getMintedMinerList()`, `minerStakedMiningNftAmount(string)`, `totalStakedMiningNftAmount()`, `getFilstMintedAmountByNftTokenId(uint256)`.

**Staking / distributor architecture (Compound-style, solc 0.5.17, all verified "Staking"):**
- ETH LP Staking `0x9e08bd9a…`: `property` = FILST/USDT LP `0xa2f6a219…`; `superior()` = `0xe67ae15c…` = verified PrivilegedRedistributor; live `totalDeposits()` = 0.979544 LP (= its LP balance; 99.9985% of LP supply).
- ETH FILST Staking `0x01aabbad…`: `property` = FILST; `superior()` = `0x5e6468b3…` = verified RewardPoolDelegator; `totalDeposits()` = 374,551 FILST.
- ETH DFL Staking `0xb685bfda…`: `property` = DFL; `superior()` = `0x3ccd0160…` = verified PrivilegedRedistributor; `totalDeposits()` ≈ 52.01M DFL.
- ABI surface (16 fns): `deposit`, `withdraw`, `claim(address,uint256)`, `claimAll`, `accrue`, `accountState(address)`, `accruedStored(address)`, `globalAccruedIndex`, `superior()`, `superiorAccruedAmount()`, `property()`, `totalDeposits()`, `transfer(address,uint256)`, `asset()`; events Accrued/Claimed/Deposit/Distributed/Transferred/Withdraw.
- No public vulnerability, write-up, or exploit for these contracts found. Audit-focus list for the on-chain squad: (a) `claim()`/`claimAll()` accrual math; (b) whether any path lets a non-depositor pull LP principal; (c) `FILSTManage.mint` mNFT gate — is any mNFT circulating/tradeable; (d) FILST `poster`/`owner` liveness (privileged); (e) `PrivilegedRedistributor`/`RewardPoolDelegator` funding state; (f) `0x312c6ffe…` (FILST-eFIL LP holder) — same runtime code hash as the verified Staking (confirmed by the parent).

**Parent's live-call results (answers to §10 checklist, added 2026-10-11):**
1. FILSTManage: `mintFeeRatio`=50, `MINT_FEE_DENOMINATOR`=1000, `totalStakedMiningNftAmount`=1914, `getTotalMintedAmount`=1,959,936, `cumulatedFee`=606,725.28 DFL, poster=FILSTManage, owner=EOA 0x557E.
2. MiningNFT (0xad1ED31e): all 1,914 units of token IDs 100001–100011 are held by FILSTManage (verified by `balanceOf` for every id and by TransferSingle log netting). No mNFT circulating. FILSTManage has NO function to withdraw NFTs (only `transfer` of DFL, onlyOwner).
3. MiningNFTManage.mint: `require(minerManage.whiteList(msg.sender))` → reverts "sender not in whitelist" for outsiders; whitelist is owner-only. Minting new mNFTs closed to outsiders.
4. PriceConverter effective fee for 1024 FILST: ~233,900 DFL (~$26) — irrelevant while mNFTs are locked.
5. Staking contracts: `withdraw`/`claim` from a non-depositor reverts ("withdraw: insufficient value" / "claim: insufficient value"); all six staking instances share runtime code hash 0xd3b82811… (verified Staking). Top LP staker f2ba8f66 (EOA) holds 0.978272/0.979544 = 99.88% of staked LP and can withdraw (H-O proof, simulated OK).
6. FILST token: poster=FILSTManage, owner=EOA 0x557E (both chains). No outsider mint path.
7. BSC mirror: see parent report / bsc notes (child subagent).
8. No mNFT obtainable → mint→dump PoC is closed at the gate; documented instead.

## 7. DefiLlama page & adapter history
- Page: https://defillama.com/protocol/defil — TVL $1.76m (ETH 92.1%), category Lending, "Audits: Yes"; API row: `deadUrl: true`, `audits: "2"`, 1 audit link, `url: ""`.
- Adapter `projects/defil/index.js`: counts tokens held by "holder" contracts via each holder's `property()`: ETH holders {DFL 0xb685…, FILST-USDT 0x9e08…, FILST-EFIL 0x312c…, FILST 0x01aabbad…}, pool2 0x6b0c7d01…; BSC holders {DFL 0x272257bb…, FILST-USDT 0xde6239b3…, FILST-EFIL 0x6b9ee349…, FILST 0x6c753ca9…}, pool2 0x6b6811a7….
- Commit history: created 2022-03-17; fixes 2022; refactor 2023-01; 2025-05-29 "mispriced tokens of different chain, changed to native (#14837)"; last 2026-07-08 repo-wide "clean-up".
- DefiLlama's $1.757M does NOT price the BSC FILST leg — consistent with the triage note.

## 8. Corrections & uncertainties
- Corpus correction (triage): `0x01aabbad…` (ETH) and `0x6c753ca9…` (BSC) are "Staking" contracts (holders), NOT the FILST tokens. Real FILST tokens: ETH `0x7346ad4c…`, BSC `0x899e2a22…`. Likewise `0x9e08bd9a…`/`0xde6239b3…` (LP holders) are Staking contracts, and `0xb685bfda…`/`0x272257bb…` are DFL Staking contracts.
- "FILST price $0.5108" was pool-implied, not an oracle: no DefiLlama/CoinGecko FILST price; CMC untracked; Coinbase page contradictory prints.
- Audit count: corpus 1 vs DefiLlama "2" (1 link); SlowMist certificate page renders NOT FOUND.
- Supply discrepancies: official 3,144,704 (2021) vs ETH 1,959,936 + BSC 1,901,568 = 3,861,504 now; DFL supply: 81.3M (Coinbase FAQ) / 87.7M (CMC) / 125.8M (on-chain). Root causes unknown [U].
- The bridge failure of Sept 2021 is described only as "data display errors and unreceivable benefits" — no technical detail published [U].
- X/Medium silence may not reflect private channels (Telegram/Discord) [U].
- Search coverage is incomplete for niche/Chinese content; empty searches are weak negative evidence.

## 9. Explicit negative results
- No hack/exploit/rug record in DefiLlama hacks DB (1,299), and no post-mortem found elsewhere.
- No CEX listing found live; CoinGecko delisted (404); DexScreener does not index either FILST pair.
- No public bridge contract address for DeFIL, and no third-party bridge integration found.
- No mentions of DeFIL/FILST in `zombie-deep/*` or `zombie_hunt/github_stuck_funds.md`; only the FINDINGS.md L-2 row and triage artifacts.
- No whitepaper text extractable (PDF-only GitBook attachment).
- No mNFT/MiningNFT public documentation beyond the FAQ description; no public list of miner whitelist or mNFT holders.
