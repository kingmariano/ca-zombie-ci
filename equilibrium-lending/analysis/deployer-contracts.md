# H-09 — Complete contract set created by the Equilibrium team EOA on Ethereum

Creator: `0x81925a13D326420baefd9f0b51bdd6309f778637` (EOA, no code; `DEFAULT_ADMIN_ROLE` on the bridge
and EQ token; sent the 2025-04-08 bridge sweep).
Source: Etherscan v2 `module=account&action=txlist` (pages 1–2, 161 txs) + `getcontractcreation`.
All balances checked at block 26,112,752 (2026-10-03).

## Aug 2021 deployment (blocks 13,100,122–13,100,151) — ChainBridge v1 + Genshiro tokens

| # | Block | Address | Type | Current value |
|---|---|---|---|---|
| 1 | 13,100,122 | `0x13D3D12478044E6Ea1b76F2A52d4bb6Dd3Ec867F` | ChainBridge v1 (`_relayerThreshold=2`, `_fee=0.001 ETH`, **paused**) | 0 ETH |
| 2 | 13,100,124 | `0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288` | ERC20 handler v1 (`_bridgeAddress` = v1) | 0 of WETH/USDT/DAI/WBTC/USDC/CRV/GENS |
| 3 | 13,100,125 | `0x42de8775d7D1998eD1bFb1EB3eDA84D3f0B31C1e` | ERC721 handler v1 | no deposits found |
| 4 | 13,100,126 | `0x26404B78223336777d0290D60D82c16DfF83E2eD` | AdminUpgradeabilityProxy (getProxyImplementation/getProxyAdmin/upgrade/…) | 0 |
| 5 | 13,100,134 | `0xaab8518B0740cd5C18895B0773e0B253f49be688` | ERC20MinterBurnerPauser (unused impl; totalSupply 0, decimals 0) | 0 |
| 6 | 13,100,143 | `0x9D9152874294aC0489eCf191376F48db99014112` | GENS ("Genshiro"), supply 4,969,962.49, MINTER count 2 | no market |
| 7 | 13,100,147 | `0x4a2Fe8cd0E6CdEE927E59DDeaC2d71D00282daFC` | ERC20MinterBurnerPauser (unused impl; totalSupply 0) | 0 |
| 8 | 13,100,149 | `0xf623CFC0b2067CF0976C263E83c04Cb06AaC32c7` | "Equilibrium Dollar" (EQD old), totalSupply **0**, MINTER count 2 | 0 |
| 9 | 13,100,151 | `0x84881B7F906551ac04F2bc3B4FB4dcF0903A0cd5` | other (no ETH/ERC20 balances; no dispatch selectors matched) | 0 |

## Oct 2022 deployment (blocks 15,717,208–15,717,209) — ChainBridge v2

| # | Block | Address | Type | Current value |
|---|---|---|---|---|
| 10 | 15,717,208 | `0x267c4d894db79a3023e266B84401e58f7434e1F1` | ChainBridge v2 custom "0.1.0"; threshold 2; 5 relayers; not paused; deposits disabled; `adminWithdraw`/`transferFunds` admin-gated | 0 ETH |
| 11 | 15,717,209 | `0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F` | ERC20 handler v2 (9 resources: 6 lock-release + EQD/EQ/GENS burn-mint) | 0 of all mapped tokens |

## Dec 2022 deployment (blocks 16,296,666–16,296,670) — EQ/Q-era tokens + proxies

| # | Block | Address | Type | Current value |
|---|---|---|---|---|
| 12 | 16,296,666 | `0x9e0480264e57c584ebA53dA3a1d3c28C326Ce3D8` | AdminUpgradeabilityProxy | 0 |
| 13 | 16,296,667 | `0xaf5345A981bc7abc041B95647E1f0454FD93f349` | ERC20MinterBurnerPauser, totalSupply 0, decimals 0 (uninitialized) | 0 |
| 14 | 16,296,668 | `0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82` | **EQ token** ("Equilibrium"), supply 1,846,403,069.99; MINTER_ROLE = handler `0xe2a1…` only; no market price | — |
| 15 | 16,296,669 | `0xd34412A2323aafbCF7734f9d10f6f74E8279cC41` | ERC20MinterBurnerPauser, totalSupply 0, decimals 0 (uninitialized) | 0 |
| 16 | 16,296,670 | `0xfB41E1074DbE88EEb0Da01D52565774165DA03d3` | "Equilibrium Dollar" (EQD new), totalSupply **0** | 0 |

## Cross-checks

- `getcontractcreation` for `0x267c…` and `0xe2a1…`: both created 2022-10-10 08:09 UTC
  (timestamps 1665398951) in blocks 15,717,208/15,717,209.
- The bridge constructor (decoded from creation bytecode) sets domain 0, threshold 2,
  fee 0.001 ETH, expiry 72,000 blocks, no initial relayers; relayers were added by the admin
  immediately after (RoleGranted blocks 15,717,227/228/229 and 18,819,909/921).
- The EQ token was registered on the v2 handler under resource ID
  `0x…681f812b3d181df0437de3f3e9ba249400` with `_burnList = true` (burn on Ethereum deposit,
  mint on proposal execution) — matching the team SDK's `resourceId` for EQ.
- No contract created by the team EOA holds any ETH or any of the tracked ERC20s at block 26,112,752.
