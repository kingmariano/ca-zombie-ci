# H-5 shutdown census — scope & assignment map (parent working file)

Finding: H-5 · 2026 shutdown census — stranded-contract watch (from non_llama_and_directories.md §2C).
Excluded from scope: MilkyWay (H-27), Polynomial (H-06 done), Ionic (C-41 done), Balancer V2 (H-43).

26 in-scope protocols. DefiLlama TVL pulled 2026-10-04 (not ground truth; verify on-chain).

| # | Protocol | Chain(s) | Sector | DefiLlama TVL (USD) | Auditor |
|---|----------|----------|--------|--------------------|---------|
| 1 | ZeroLend Lending | zkSync/Blast/Manta/Linea/Abstract/XLayer/Hemi + | Lending | 1,442,516 (zkSync 855k, Blast 478k, Manta 55k, Abstract 32k, Linea 10k, XLayer 9k, Hemi 3k) | child B |
| 2 | ZeroLend Vaults (Euler curator) | Ethereum/Linea/Berachain/Sonic | Risk curator | 1,852,964 (ETH 1.845M) | child B |
| 3 | Goldfinch | Ethereum | Credit | 1,958,762 | child C |
| 4 | Stream Finance | Ethereum | Yield/credit | 0 (dead) | child E |
| 5 | Summer.fi Pro | Ethereum/Arbitrum/Base/Optimism | Lending automation | 18,377,258 (ETH 18.11M) | child A |
| 6 | Seamless V2 (Leverage Tokens) | Ethereum/Base | Leverage | 7,259,712 (ETH 7.20M coll / 13.16M debt) | child A |
| 7 | Seamless V1 | Base | Lending | 586,290 (supplied) / 69,973 borrowed | child A |
| 8 | Levvy for Tokens/NFTs | Cardano | Lending | 21,914 + 3,606 | child C |
| 9 | Avon MegaVault | MegaETH | Yield | 11,391 | child C |
| 10 | Buck | ? | Lending/stable | n/a (name collision w/ Bucket Protocol Sui) | child E |
| 11 | Cura | ? | Lending | n/a | child E |
| 12 | Strobe Finance | ? | Yield | n/a | child E |
| 13 | DeltaDeFi | Cardano | DEX | 0 | child E |
| 14 | Rage Trade v1 | Arbitrum | Perps | 6 (dead) | child D |
| 15 | Vela Exchange | Arbitrum/Base | Perps | ~0 (dead) | child D |
| 16 | LogX V1/V2 | Linea/Manta/Telos/Mode/zkLink/Mantle + | Perps | 1,242 / 41 | child D |
| 17 | Satori Perp | Linea + 12 chains | Perps | 11,107 (Linea 10,374) | child D |
| 18 | Fusion Trade | ? | Perps | n/a | child D |
| 19 | Valhalla | ? | Perps | n/a | child D |
| 20 | Ranger Finance | Solana | Perps/options | null (dead) | child D |
| 21 | BasePerp | Base | Perps | n/a | child D |
| 22 | Angle Protocol | Ethereum/Arbitrum/Polygon/Optimism/Avax/Gnosis/Celo/BSC | Stablecoin | 1,831,982 (ETH 1.582M, Arb 243k) | child B |
| 23 | ODOS | multi | Aggregator | null | child E |
| 24 | VaporDEX V1/V2 | Avalanche/Telos/ApeChain | DEX | 415,428 / 29,211 | child C |
| 25 | Ebisu / Ebisus Bay | Cronos / Ethereum / Mode / Plasma | Stable/DEX | 425,642 + 25,151 + 7,605 | child C |
| 26 | Quiet Finance | ? | Stable/aggregator | n/a | child E |
| 27 | Remora Markets | Solana | RWA/prediction | 296,074 (dead) | child E |
| 28 | Step Finance | Solana | Portfolio | 0 (dead, hacked) | child E |

Note: count above is 28 rows because ZeroLend and Seamless and VaporDEX/Ebisu split into sub-deployments.
Child assignments:
- child A: Summer.fi, Seamless V1+V2 → analysis/summerfi.md, analysis/seamless.md
- child B: ZeroLend (lending+vaults), Angle → analysis/zerolend.md, analysis/angle.md
- child C: Goldfinch, VaporDEX, Ebisu/Ebisus Bay, Levvy, Avon → analysis/{goldfinch,vapordex,ebisu,levvy,avon}.md
- child D: Rage, Vela, LogX, Satori, Fusion, Valhalla, BasePerp, Ranger → analysis/{ragetrade,vela,logx,satori,fusiontrade,valhalla,baseperp,ranger}.md
- child E: ODOS, Stream, Quiet, Buck, Cura, Strobe, DeltaDeFi, Remora, Step → analysis/{odos,streamfinance,quietfinance,buck,cura,strobe,deltadefi,remora,stepfinance}.md

Parent (me): verification of top claims, fork PoC + CI, README.md, summary.json.
