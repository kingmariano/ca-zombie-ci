# WePiggy Ethereum — market state (read-only, block 26,150,020)

Comptroller `0x0C8c1ab017c3C0c8A48dD9F1DB2F59022D190f0b` (EIP-1967 impl `0x81ed5efd9477106f898733e47e9ec7738fa3e00c`), oracle `0xa1e683f0d956351106e6f45bdd3da5bce1db7f5a` (WePiggyPriceProviderV1), closeFactor 0.5, liquidationIncentive 1.08, seizeGuardianPaused=false, pauseGuardian `0x33f9694ec9751397c15cfb36d5aa61b63c2f725f`, owner `0x8114b3854d1e7b7f5f14896537c321e9062284ce` (Gnosis Safe 4-of-7).

| market | cToken | underlying | cash | supply claim | reserves | borrows | CF | mintPaused* | borrowPaused* | mintCap | borrowCap | oracle $ | real $ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pETH | `0x27a94869341838d5783368a8503fda5fbcd7987c` | `native` | $50,843 | $30,840 | $22,583 | $2,580 | 0.80 | False | False | 0 (∞) | 0 (∞) | 2470.57 | 2419.82 |
| pDAI | `0x85166b72c87697a6acff24101b43fd54fe28a179` | `0x6b175474e89094c44da98b954eedeac495271d0f` | $16,343 | $2,698 | $13,771 | $126 | 0.75 | False | False | 0 (∞) | 0 (∞) | 0.999927 | 0.999914 |
| pUSDT | `0x5cfad792c4df1323188180778aec58e00eace32a` | `0xdac17f958d2ee523a2206206994597c13d831ec7` | $35,924 | $29,449 | $7,045 | $570 | 0.80 | False | False | 0 (∞) | 0 (∞) | 0.999287 | 0.999263 |
| pUSDC | `0xf8e5b9738bf63adfff36a849f9b9c9617c8d8c1f` | `0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48` | $12,224 | $2,190 | $11,791 | $1,758 | 0.80 | False | False | 0 (∞) | 0 (∞) | 0.99986 | 0.999598 |
| pWBTC | `0xc12b9d620bfcb48be3e0ccbf0ea80c717333b46f` | `0x2260fac5e5542a773aa44fbcfedf7c193bc2c599` | $362,047 | $59,752 | $302,891 | $596 | 0.70 | False | False | 0 (∞) | 0 (∞) | 81585.7 | 81714.7 |
| pUNI | `0x82413f75f0da101e0fe7f6ff6cba3461f7e04f29` | `0x1f9840a85d5af5bf1d1762f925bdaddc4201f984` | $29,537 | $29,384 | $286 | $133 | 0.60 | False | False | 3,898,930 | 0 (∞) | 7.29348 | 7.29434 |
| pYFII | `0x82de3959c09f665a82c794fafc1eb34cfcb555ee` | `0xa1d0e215a23d7030842fc67ce582a6afa3ccab83` | $180 | $167 | $15 | $2 | 0.00 | True | True | 0 (∞) | 0 (∞) | 417.99 | 27.4024 |
| pLRC | `0x690aa2591e57180cba5a6123e9d462907a5e1c95` | `0xbbbbca6a901c926f240b89eacb641d8aec7aeafd` | $42 | $0 | $42 | $0 | 0.00 | True | True | 0 (∞) | 0 (∞) | 0.03123 | 0.00968343 |
| pxLON | `0xef86384cf696929c3227428f539e740ee12fcdc7` | `0xf88506b0f1d30056b9e5580668d5875b9cd30f23` | $877 | $887 | $18 | $29 | 0.00 | True | True | 0 (∞) | 0 (∞) | 0.5 | 0.5 |
| pRAI | `0x959f30f765a44273eccaa0fac094160aa7c238e2` | `0x03ab458634910aad20ef5f1c8ee96f1d6ac54919` | $22 | $0 | $68 | $46 | 0.00 | False | True | 0 (∞) | 0 (∞) | 3.33 | 3.00928 |
| **total** | | | **$508,039** | **$155,367** | **$358,512** | **$5,839** | | | | | | | |

\* `mintPaused`/`borrowPaused` are the fork's custom `pTokenMintGuardianPaused`/`pTokenBorrowGuardianPaused` mappings (Compound-named getters revert on this fork). Values read live at the same block range.

Notes:
- `getCashPrior()` = `IERC20(underlying).balanceOf(this)` → exchange rate is donation-sensitive (Hundred-class precondition), but every market has a large non-empty `totalSupply` (see SUMMARY.md).
- Oracle sources: CF>0 markets use live Chainlink feeds (checked `latestRoundData` freshness); CF=0 markets (pYFII/pLRC/pxLON/pRAI) use the owner-set `WePiggyPriceOracleV1` at `0xe4a1e73157eb4b58b1347e2be2df7ac83467b288` (stale: YFII $417.99 vs real $26.31, LRC $0.0312 vs $0.0096, RAI $3.33 vs $3.00) — inert because CF=0 and borrow paused.
- cToken implementation `0x465461657b4175c1676ecea1fb0e8d0174d8d7f6` (`PERC20`), source verified (compiler 0.6.12).
