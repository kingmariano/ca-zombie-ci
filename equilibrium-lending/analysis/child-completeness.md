# H-09 — Child Completeness Check (independent verification)

Date: 2026-10-03 · Scope: read-only enumeration + balance verification · No transactions sent.

## Tools / methods used

- Blockscout Ethereum API v2 (`https://eth.blockscout.com/api/v2/...`): full normal-tx list of team EOA, internal txs, contract metadata, token balances, token holders, search.
- Etherscan v2 API (`module=account&action=txlist`): **rejected the configured key** (`Invalid API Key (#err2)`, len 34 / key not echoed). All enumeration was therefore done via Blockscout and cross-checked with internal txs + GoldRush. This is a tooling note, not a data gap.
- GoldRush (Covalent) v2 `balances_v2` for all 17 addresses (16 contracts + EOA) — independent token-balance cross-check.
- Public RPC `https://eth-mainnet.public.blastapi.io` with `cast 1.7.1`: `eth_getBalance` and `eth_call balanceOf` sweep of 13 tokens × 17 addresses (221 calls), plus read-only `eth_call` simulations from `0x…dEaD` (no state change).
- Web search for other Equilibrium/Genshiro Ethereum deployments.

## 1. Contract-creation enumeration for 0x81925a13D326420baEFD9f0b51bDd6309f778637

All 161 normal txs + internal txs reviewed. **Exactly 16 contracts created** (9 in the 2021-08-26 batch, 7 in the 2022-10/12 batches). This matches the parent's known list 16/16 — **no missed deployments**. No factory-created extras (internals contain only these same 7 creations of the 2022 batch; 2021 creations are top-level CREATEs).

| # | Address | Block | Created (UTC) | Type (verified) | ETH | ERC20 now |
|---|---------|-------|---------------|-----------------|-----|-----------|
| 1 | 0x13D3D12478044E6Ea1b76F2A52d4bb6Dd3Ec867F | 13100122 | 2021-08-26 09:21:08 | ChainBridge v1 Bridge (paused) | 0 | none |
| 2 | 0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288 | 13100124 | 2021-08-26 09:21:23 | ERC20Handler v1 | 0 | **19,568.585937472110905023 BTT** |
| 3 | 0x42dE8775d7D1998eD1BfB1Eb3edA84D3F0B31c1E | 13100125 | 2021-08-26 09:21:29 | GenericHandler | 0 | none |
| 4 | 0x26404B78223336777D0290d60d82c16dfF83E2ED | 13100126 | 2021-08-26 09:21:37 | ProxyAdmin (owner = team EOA) | 0 | none |
| 5 | 0xaaB8518b0740CD5C18895b0773e0b253f49bE688 | 13100134 | 2021-08-26 09:23:22 | ERC20PresetMinterPauserUpgradeSafe (uninitialized impl: name/symbol empty, totalSupply 0) | 0 | none |
| 6 | 0x9D9152874294aC0489eCf191376F48db99014112 | 13100143 | 2021-08-26 09:24:36 | AdminUpgradeabilityProxy (GENS, EIP-1967) | 0 | none |
| 7 | 0x4A2fe8cD0e6CDEE927E59DDEAC2D71D00282dafc | 13100147 | 2021-08-26 09:26:04 | ERC20PresetMinterPauserUpgradeSafe (uninitialized impl) | 0 | none |
| 8 | 0xF623Cfc0b2067CF0976C263e83C04cb06aAc32C7 | 13100149 | 2021-08-26 09:26:12 | AdminUpgradeabilityProxy (EQD old) | 0 | none |
| 9 | 0x84881B7f906551ac04F2BC3B4fb4dCf0903a0cD5 | 13100151 | 2021-08-26 09:27:52 | Vyper 0.2.7 **voting escrow for GENS** (`token()` = 0x9D91…, `admin()` = team EOA, `is_killed()` = false); GENS locked = **0** | 0 | none |
| 10 | 0x267c4d894db79a3023e266B84401e58f7434e1F1 | 15717208 | 2022-10-10 10:48:59 | ChainBridge v2 Bridge (unverified source) | 0 | none |
| 11 | 0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F | 15717209 | 2022-10-10 10:49:11 | ERC20Handler v2 | 0 | 2,500 raw spam token ($ Evmosia.com) |
| 12 | 0x9e0480264e57c584EBa53da3a1d3c28C326Ce3D8 | 16296666 | 2022-12-30 09:23:11 | ProxyAdmin (owner = team EOA) | 0 | none |
| 13 | 0xaF5345a981bc7ABc041b95647E1f0454Fd93F349 | 16296667 | 2022-12-30 09:23:23 | ERC20PresetMinterBurnerPauserUpgradeSafe (uninitialized impl) | 0 | none |
| 14 | 0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82 | 16296668 | 2022-12-30 09:23:35 | AdminUpgradeabilityProxy (EQ; name "Equilibrium", totalSupply 1.846403069988e27) | 0 | **200.0 of 0xB508…EQ** |
| 15 | 0xd34412A2323aafbCF7734F9d10f6f74E8279cc41 | 16296669 | 2022-12-30 09:23:47 | ERC20PresetMinterBurnerPauserUpgradeSafe (uninitialized impl) | 0 | none |
| 16 | 0xfB41E1074DbE88EEb0Da01D52565774165DA03d3 | 16296670 | 2022-12-30 09:23:59 | AdminUpgradeabilityProxy (EQD new) | 0 | none |
| — | Team EOA 0x81925a13…8637 | — | — | EOA | **0.001464735414855325** | 0.0001 WETH; 1.0 EQ (0xA5eD…); fake "ETH" spam token |

Balance sweep tokens: EQ(0xa5ede), EQ(0xB508), EQD-new, EQD-old, GENS, USDC, USDT, DAI, WETH, WBTC, CRV, BTT-old, spam(0x0A52). GoldRush independently confirms every row above (it additionally flags only the same spam tokens plus the fake Cyrillic "ЕTH" 0x2339… on the EOA).

### Nonzero holdings — extractability analysis

1. **BTT 19,568.585… in v1 ERC20Handler 0x47840A… (≈ $0.007).**
   - `_contractWhitelist(0xC669…BTT)` = **false** (call `0x9a40693a…` arg BTT).
   - read-only simulation `eth_call withdraw(BTT, 0x…dEaD, 1)` from `0x…dEaD` reverts: `sender must be bridge contract` (0x08c379a0…"sender must be bridge contract"). Same for the v2 handler 0xe2a1….
   - **Not unprivileged-extractable.**
2. **2,500 raw "Earn $WBTC / $ Evmosia.com"-style tokens in v2 handler 0xe2a1….**
   - `balanceOf(0x…dEaD)` and `balanceOf(0x1111…1111)` = 40,000 for `0x525fC44C…` and 475 for `0x0A527683…` — **constant fake balances for any address**, no market. Every one of the 17 addresses "holds" 475 of `0x0A527683…` for the same reason. **Worthless spam.**
3. **200.0 of 0xB508C100… EQ inside the EQ token proxy 0xA5eDE2…** (see §2). Unofficial token, no market, no sweep/claim function on a standard ERC20 proxy. **Airdrop dust, not extractable.**
4. **Team EOA own funds: 0.0014647 ETH + 0.0001 WETH + 1.0 EQ.** Team-controlled, not protocol TVL, and not extractable by third parties.

No value-moving function on any of the 16 contracts (with or without balance) is callable by an arbitrary address: handlers are `onlyBridge`, proxies are transparent (admin calls from non-admin revert), ProxyAdmin owners = team EOA, escrow admin = team EOA.

## 2. Other Equilibrium/Genshiro-related mainnet contracts (not deployed by the EOA)

Search: Blockscout search (`Equilibrium`, `Genshiro`, `eq.finance`, `GENS`, `xDOT`, `Q token`), web search, and GoldRush token lists. Candidates examined:

| Address | What | Creator | State |
|---|---|---|---|
| 0xB508C100D107a98bd9F1e3D1dCBA577cfDf01065 | 2nd "Equilibrium EQ" token, 24M supply, 15 holders | 0x7Fbe14c5a948EDfa14aF8A5988A65f7Ea788C48c, tx 0x2d64a4…6027, **2020-10-15** (10 months before team contracts) | ETH 0; no exchange rate / no market; 200.0 airdropped to team's EQ proxy. Not team-deployed, not team-held, no extraction vector |
| 0x824Df198321380071FB91a73ce89AEB73C208C30 | "equilibrium.io EQ", 120M supply, 180 holders | 0xc251fd6af4ec4e38bac354976f0a223edd8c6049 | ETH 0; not team-controlled; clone |
| 0xC539fA1cE23189BADE6A3a1cC91a35369A254267 | "Genshiro DRX", 1e29 supply, 7 holders | 0x2d71ca5913d5fbc3602bc40fea740a7e4a9698ee | ETH 0; not team-controlled; clone |
| 0x53860befa2378B32bd91Dec357Cb2D4fC6B92775 | "GENSHIRO.io cats" (NFCATS) | 0xc98fe8c7c065bbe7f51cf0e5f0d259bb29481caa | ETH 0; not team-controlled; clone |
| 0xfE80D611c6403f70e5B1b9B722D2B3510B740B2B | "Equilibria Finance" (Pendle ecosystem, name collision) | unrelated | out of scope, not Equilibrium/eq-lab |

- Official EQ on Ethereum is confirmed as 0xa5ede2fee620ac3d68065ec01f26f9dd99850b82 (livecoinwatch, coincarp); GENS as 0x9d9152874294ac0489ecf191376f48db99014112. No genuine second deployment found.
- xDOT / Fluid xDOT / Q token were parachain-internal Equilibrium assets with **no Ethereum contract** (equilibrium.io docs, Medium); nothing on Ethereum to hold value.
- No other contract interacted with by the team EOA beyond the 16 known ones is a protocol contract (top counterparties: the two bridges; remaining are EOAs with no code).

## Conclusion

**No live unprivileged-extractable value found (yes/no): NO.**
- Zero real value is exposed to arbitrary callers. Aggregate non-team "value" at risk is ≤ ~$0.01: 19,568.6 old BTT in the v1 handler (simulated `withdraw` reverts `sender must be bridge contract`; BTT not even whitelisted) plus fake-balance spam tokens (constant `balanceOf` for any address) and 200 units of a no-market clone EQ token inside the real EQ contract.
- The **target set is complete**: all 16 contracts created by 0x81925a13…8637 are identified with creation blocks/types, and every one was balance-checked on-chain (native + 13 tokens, cross-checked by GoldRush). Nothing was missed by the parent's list.
- Residual value in scope is only the team EOA's own 0.0014647 ETH + 0.0001 WETH + 1 EQ, and 19,568.6 BTT dust locked behind bridge permissions; neither is recoverable by an unprivileged address.
