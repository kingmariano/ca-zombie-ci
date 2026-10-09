# Aurigami market table — Aurora block 219,162,280 (2026-10-09)

Prices: DefiLlama/CoinGecko at 2026-10-09 (ETH $2,483.43, BTC $82,039.09, NEAR $4.6957, stNEAR $6.7301, AURORA $0.058863, USDC $0.99961, USDT $0.99929, DAI $0.99977, TRI $0.00012557, PLY $0.0000369, USN $0.08758; NEARX priced at oracle $5.24332).

| market | address | underlying | cash | borrows | reserves | CF | oracle px | cash USD | borrows USD | reserves USD | supplier claim USD |
|---|---|---|---|---|---|---|---|---|---|---|---|
| auUSDC | `0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b` | `0xb12bfca5a55806aaf64e99521918a4bf0fc40802` | 80,846.4793 | 29,011.5570 | 37,830.9272 | 0.80 | $0.999610 | $80,815 | $29,000 | $37,816 | $71,999 |
| auETH | `0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9` | `(ETH)` | 109.3176 | 72.0308 | 4.6364 | 0.70 | $2,483.430000 | $271,482 | $178,883 | $11,514 | $438,852 |
| auWBTC | `0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb` | `0xf4eb217ba2454613b15dbdea6e5f22276410e89e` | 1.1880 | 0.0187 | 0.0775 | 0.60 | $82,039.090000 | $97,464 | $1,533 | $6,362 | $92,635 |
| auUSDT | `0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54` | `0x4988a896b1227218e4a686fde5eabdcabd91571f` | 116,328.1908 | 10,507.8728 | 10,692.9133 | 0.75 | $0.999290 | $116,246 | $10,500 | $10,685 | $116,061 |
| auDAI | `0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c` | `0xe3520349f477a5f6eb06107066048508498a291b` | 34.0131 | 0.1013 | 0.0136 | 0.00 | $0.999770 | $34 | $0 | $0 | $34 |
| auWNEAR | `0xaE4fac24dCdAE0132C6d04f564dCf059616E9423` | `0xc42c30ac6cc15fac9bd938618bcaa1a1fae8501d` | 13,235.5604 | 7,847.2915 | 3,133.6542 | 0.60 | $4.695690 | $62,150 | $36,848 | $14,715 | $84,284 |
| auSTNEAR | `0x3195949f267702723bc614cAE037cdc8D1E94786` | `0x07f9f7f963c5cd2bbffd30ccfb964be114332e30` | 48,820.5806 | 2.0748 | 5,339.2642 | 0.40 | $6.730060 | $328,565 | $14 | $35,934 | $292,646 |
| auAURORA | `0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf` | `0x8bec47865ade3b172a928df8f990bc7f2a3b9f79` | 44,408.4633 | 0.0000 | 1,500.3334 | 0.40 | $0.058863 | $2,614 | $0 | $88 | $2,526 |
| auTRI | `0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca` | `0xfa94348467f64d5a457f75f8bc40495d33c65abb` | 436,476.1086 | 0.0000 | 0.0000 | 0.00 | $0.000126 | $55 | $0 | $0 | $55 |
| auPLY | `0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c` | `0x09c9d464b58d96837f8d8b6f4d9fe4ad408d3a4f` | 310,749,151.0571 | 0.0000 | 0.0000 | 0.00 | $0.000037 | $11,467 | $0 | $0 | $11,467 |
| auUSN | `0x5cCAD065400341db391FD3a4B7F50087B678D7CC` | `0x5183e1b1091804bc2602586919e6880ac1cf2896` | 335.3375 | 0.0000 | 0.0000 | 0.00 | $0.087580 | $29 | $0 | $0 | $29 |
| auNEARX | `0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a` | `0xb39eeb9e168ef6c639f5e282fef1f6bc4dcae375` | 293.8958 | 78.5851 | 131.7769 | 0.40 | $5.243320 | $1,541 | $412 | $691 | $1,262 |
| auUSDCNative | `0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c` | `0x368ebb46aca6b8d0787c96b2b20bd3cc3f2c45f7` | 4,171.6402 | 62.5488 | 18.5132 | 0.70 | $0.999610 | $4,170 | $63 | $19 | $4,214 |
| auUSDTNative | `0xdDfd0407220026c6566979B5be6A4983d1247a3E` | `0x80da25da4d783e57d2fcda0436873a193a4beccf` | 4,213.7462 | 156.8530 | 28.8489 | 0.70 | $0.999290 | $4,211 | $157 | $29 | $4,339 |

TOTAL cash $980843 | borrows $257411 | reserves $117853 | claims $1120401

supplier claims = cash + borrows - reserves (recoverable by cToken holders)
supplier-claim vs cash gap (net loans receivable USD): $139558

Notes: cash = underlying balance of the cToken (auETH = contract ETH balance). Supplier claim = cash + borrows - reserves (the redemption value of all cTokens). USN marked at market ($0.0876), not its $1 peg.
