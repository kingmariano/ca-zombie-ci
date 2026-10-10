# BSCSwap (BSC) — evidence (2026-10-10)

Identity: bscswap.com ("BSCswap", South Korea; website offline since Aug 2024). BSWAP governance token; contracts
"modified Uniswap V2" per project README (github.com/DynamicSwap/bscswap-token-contract).

## Contracts (verified on-chain)
- Factory `0xCe8fd65646F2a2a897755A1188C04aCe94D2B8D0` — **728 pairs**, feeTo = `0xc26c62cb6298971daf9a51b1272ce3e4a782ead2`
- Router `0xd954551853F55deb4Ae31407c423e67B1621424A` — factory() verified == 0xCe8f...
- BSWAP v2 `0xf388ee045cab30321db3fb69eab7dfb0c20f10ec` (1:1 swap from v1 `0xacc234978a5eb941665fd051ca48765610d82584`;
  v1 BscScan page shows a stale $35.23 quote / $3.5M mcap — the live v2/WBNB pool prices it ≈ **$1.02**)
- Farm/staking `0x7B2dAC429DF0b39390cD3D4E6a8b8bcCeB331E2D` — code present (5.5 KB), holds 0 BSWAP2/0 WBNB.

## Live state (full 728-pair scan, block 126,836,644)
Top pairs by reserves:
| pair | reserves | real==reserves | note |
|---|---|---|---|
| 0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7 | 3,688.277 WBNB / 185,305.67 THUGS | yes (excess 0) | **99.41% of LP burned to 0x0** (LP total 21,778.26) |
| 0x1ebf0ee99971c6269062c3b480e8e23b7a74756b | 60.988 WBNB / 45,678.31 BUSD | yes | feeTo holds 67.27 LP = 5.46% |
| 0xc5c84863d32f41ad60eb2dead2d69c9553541616 | 12.809 WBNB / 9,430.64 BSWAP2 | yes | "BSCswap: BSWAP 2" pair |
| 0xf68fd424... USDT/BUSD | 4,705.94 / 4,701.73 | yes | stable-stable |
- THUGS = `0xe10e9822a5de22f8761919310dda35cd997d63c0` ("ThugsToken", TWAP/whitelist token; **no mint function** in its contract).
  The ~$2.76M WBNB in this pair is **permanently locked liquidity** (LP burned to 0x0) — value can only leave via swaps at AMM price.
- Excess scan: **31 hits across all 728 pairs, all verified, all dust/unpriced** (NCT 45.7M, MZI, GAIT, MZIT, PG, ...).
  Spot-checks: MZI/WBNB Pancake pair empty (0,0); NCT & MZIT pools price to ~1e-18 WBNB/token; no DefiLlama price for any.
- feeTo LP (protocol-owned, claimable by feeTo controller = P): 5.46% of WBNB/BUSD pair ≈ **$5.0k** + 0.0099% of THUGS/WBNB ≈ $272.

## Misc
- Router/factory token balances: empty (USDT/WBNB/BUSD/BSWAP2 = 0); BNB 0.
- No `emergencyWithdraw`-style public drain found in the verified router/factory sources.

Verdict: no E-U; largest value ($2.76M) is locked in a burn-LP pool; feeTo holds ≈$5.3k (P). Confidence high (full scan).
