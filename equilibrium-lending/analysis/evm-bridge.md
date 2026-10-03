# H-09 — Ethereum-side EVM bridge contracts (live state, 2026-10-03)

All reads via public Ethereum RPC at **block 26,112,752** (unless noted); read-only `eth_call`.
Contracts were located from the team's own SDK (`equilibrium-eosdt/eq-networks`,
`packages/network/src/config/chains/ethereum.ts`) and verified on-chain; they are not documented
anywhere public (not verified on Etherscan).

## 1. Deployment map (all created by team EOA `0x81925a13D326420baEFD9f0b51bDd6309f778637`)

| Contract | Address | Created | Role | Live balances |
|---|---|---|---|---|
| ChainBridge v2 ("0.1.0") | `0x267c4d894db79a3023e266B84401e58f7434e1F1` | 2022-10-10, block 15,717,208 | current bridge (Genshiro domain 1 + Equilibrium domain 7) | **0 ETH** |
| ERC20 handler v2 | `0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F` | block 15,717,209 | locks/burns bridged ERC20s | **0 of all 9 mapped tokens** |
| ChainBridge v1 | `0x13D3D12478044E6Ea1b76F2A52d4bb6Dd3Ec867F` | 2021-08-15, block 13,100,122 | old bridge, **paused since 2022-09-05** | **0 ETH** |
| ERC20 handler v1 | `0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288` | block 13,100,124 | old handler (`_bridgeAddress` = v1) | **0 of all tokens** |
| ERC721 handler v1 | `0x42de8775d7D1998eD1bFb1EB3eDA84D3f0B31C1e` | block 13,100,125 | old NFT handler | none found |
| Admin proxy | `0x26404B78223336777d0290D60D82c16DfF83E2eD` | block 13,100,126 | AdminUpgradeabilityProxy | 0 |
| Old token impl (unused) | `0xaab8518B0740cd5C18895B0773e0B253f49be688` | block 13,100,134 | ERC20MinterBurnerPauser, totalSupply 0 | 0 |
| GENS token | `0x9D9152874294aC0489eCf191376F48db99014112` | block 13,100,143 | Genshiro ERC20, supply 4,969,962.49 | — |
| Old token impl (unused) | `0x4a2Fe8cd0E6CdEE927E59DDeaC2d71D00282daFC` | block 13,100,147 | ERC20MinterBurnerPauser, totalSupply 0 | 0 |
| EQD (old) | `0xf623CFC0b2067CF0976C263E83c04Cb06AaC32c7` | block 13,100,149 | "Equilibrium Dollar", totalSupply **0** | — |
| Forwarder/other | `0x84881B7F906551ac04F2bc3B4FB4dcF0903A0cd5` | block 13,100,151 | no ETH/ERC20 balances | 0 |
| Admin proxy #2 | `0x9e0480264e57c584ebA53dA3a1d3c28C326Ce3D8` | 2022-12-15, block 16,296,666 | AdminUpgradeabilityProxy | 0 |
| Token (uninitialized) | `0xaf5345A981bc7abc041B95647E1f0454FD93f349` | block 16,296,667 | ERC20MinterBurnerPauser, totalSupply 0, decimals 0 | 0 |
| **EQ token** | `0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82` | block 16,296,668 | "Equilibrium" (EQ), supply 1,846,403,069.99 | — |
| Token (uninitialized) | `0xd34412A2323aafbCF7734f9d10f6f74E8279cC41` | block 16,296,669 | ERC20MinterBurnerPauser, totalSupply 0, decimals 0 | 0 |
| EQD (new) | `0xfB41E1074DbE88EEb0Da01D52565774165DA03d3` | block 16,296,670 | "Equilibrium Dollar", totalSupply **0** | — |

## 2. v2 bridge configuration (live)

| Check | Value |
|---|---|
| `_relayerThreshold()` | **2** |
| `_totalRelayers()` / `getRoleMemberCount(RELAYER_ROLE)` | **5** |
| relayers | `0xA820508a9AaabD94b9c153c8a39902682B86B377`, `0xA713A67208D8F000a3fEE01B067B6E5cf8438b87`, `0x87f4E0428F76Ab076108b6e01F1c0Cac6DdF5986`, `0xE0750f97034206Cd75106E97a3663e31174f9EA3`, `0x9FD9E20C556C7EF9CeC7b2c0EA7038069a043dF2` |
| `paused()` | false |
| `_chainID()` / `_version()` | 0 / `"0.1.0"` |
| `getRoleMember(DEFAULT_ADMIN_ROLE,0)` | `0x81925a13D326420baEFD9f0b51bDd6309f778637` (team EOA) |
| Deposit enabled for destination chains | chain 7 (Equilibrium) **disabled**; chains 0/2/3 disabled; **chain 1 (Genshiro) still enabled** (0-amount `deposit` succeeds, fee 0.001 ETH) — inbound-only, no extraction |
| `_fee()` | 0.001 ETH per deposit |

## 3. Registered resources → tokens (handler `0xe2a1…2F2F`, all `_contractWhitelist == true`)

The v2 bridge exposes a resource-list getter (`0x5096c417`) returning **9 resource IDs** — all map to the
single handler `0xe2a1…2F2F`. (Deposit events only used 7 of them; GENS/CRV were also registered.)

| Resource ID | Token | burnList |
|---|---|---|
| `0x…e7af8cdba234ffeeddccbbaa3458798700` | WETH | false |
| `0x…62ced3722c69d04d18c5ce5fa6ef9a8a00` | USDT | false |
| `0x…b23802d01aeb6d2af5f66bc49383d20d00` | DAI | false |
| `0x…2167b82cfd0cb1a577e338e65331e87f00` | WBTC | false |
| `0x…f0ec6d6364bce9df4a3037c6d78bfe7900` | USDC | false |
| `0x…074f3176c2cfbbc7bba48d64535e071500` | EQD (new) | true (burn on deposit) |
| `0x…e54dd1f11e2fd2474af64f487e911b5900` | CRV | false |
| `0x…7a05c51f15d366ac77bc86672166836100` | GENS | true (burn on deposit) |
| `0x…681f812b3d181df0437de3f3e9ba249400` | **EQ** | **true** (burn on deposit / mint on proposal execution) |

Current handler balances: **0 for all 9 mapped tokens** (WETH, USDT, DAI, WBTC, USDC, CRV, EQD, EQ, GENS).
(CRV has **no v2 resource**: 500.6 CRV was migrated from the v1 handler to the v2 handler at blocks 15,717,511/15,717,818,
partially withdrawn by users, and the rest swept 2025-04-08. The single EQD resource deposit (nonce 1028, block 16,383,556)
burned 20 EQD.)
Bridge ETH: 0. v1 handler: 0 of all tokens; v1 bridge ETH 0.

## 4. History from logs (Etherscan v2 `getLogs`, complete)

### v2 bridge `0x267c…e1F1` (695 logs, blocks 15,717,227 → 22,223,090)
- **52 deposits**: 39 to domain 1 (Genshiro: WETH/USDT/DAI/WBTC/USDC/CRV, nonces 1001–1039,
  Oct 2022 – Oct 2023) + 13 to domain 7 (Equilibrium: EQ resource, nonces 1–13, Jan–Feb 2024,
  blocks 18,820,785 – 19,017,430).
- **Proposal events**: origin 1 nonces 179–290; origin 7 nonces 1–12 (112 + 12 executed paths).
- **9 `withdraw` events, all on 2025-04-08 (blocks 22,223,003–22,230,090), all sent by the admin EOA
  `0x81925a13…` to recipient EOA `0x774496dd14589ECb5ac406A4DD417293A0159a1E`:**
  WBTC 0.00000001 + 0.02891631, WETH 3.0 + 6.14502475, CRV 7.0 + 493.97839797,
  DAI 1,777.121636158, USDT 65,633.852016, USDC 1,208.393462.
  → the locked bridge float (~$96k at Apr-2025 prices) was **swept by the team**; the recipient EOA
  has since moved it on (dust remains: USDC 2, USDT 6, WBTC 632 sat, CRV 0.000007977).
- `paused` events: paused once (block 15,477,902 — v1), v2 was paused/unpaused twice (2022/2023).
- Role grants: 3 relayers added 2022-10-10; 2 relayers added 2024-01-03/04 (blocks 18,819,909 / 18,819,921).

### v1 bridge `0x13d3…867F` (1,104 logs, blocks 13,099,098 → 15,477,902 = Aug 2021 – Sep 2022)
- 221 deposits (all domain 1), 524 proposal events, 349 votes; **no admin withdraw events** —
  all locked tokens left via ordinary executed proposals (users withdrawing), and the bridge was
  paused on 2022-09-05 (block 15,477,902) around the Genshiro bridge migration.
- v1 handler received 217 token transfers historically (WETH 114, USDT 35, DAI 16, WBTC 29,
  USDC 20, CRV 3) — all released; balances are 0 today.

## 5. Unprivileged-path simulations (`eth_call`, from `0x…dEaD`)

| Attempt | Result |
|---|---|
| `adminWithdraw(handler,USDC,attacker,1)` | revert `sender doesn't have admin role` |
| `executeProposal(1,1,0x,RID_EQ)` | revert `sender doesn't have relayer role` |
| `voteProposal(1,1,RID_EQ,0x0)` | revert `sender doesn't have relayer role` |
| `transferFunds([attacker],[1])` | revert `sender doesn't have admin role` |
| handler `withdraw(USDC,attacker,1)` | revert `sender must be bridge contract` |
| EQ `mint(attacker,1e18)` | revert `ERC20PresetMinterBurnerPauser: must have minter role to mint` |
| `deposit{0.001 ETH}(7,RID_EQ,"")` | revert `deposits resource to chain with supplied chainID are disabled` |
| `deposit{0.001 ETH}(1,RID_WETH,0)` | **succeeds** (chain-1 deposits still enabled; caller pays the fee, gets nothing) |
| v1 `deposit{0.001 ETH}(1,RID_WETH,"")` | revert `Pausable: paused` |
| admin `adminWithdraw(handler,USDC,admin,0)` | success (0-value) |
| admin `adminWithdraw(handler,USDC,admin,1)` | revert `ERC20: call failed` (handler empty) |

## 6. EQ token authorities

- `MINTER_ROLE` members: **1** — the handler `0xe2a1…2F2F`. `DEFAULT_ADMIN_ROLE`: team EOA.
- EQ can only be minted when the bridge executes a proposal with **≥2 relayer votes**
  (`executeProposal` → handler `mint`). No unprivileged mint.
- EQ has **no market/price** (DefiLlama `coins.llama.fi` returns no price; GeckoTerminal search
  returns no pool), so even the relayer-gated mint path has ~$0 economic value today.
- EQD(new) totalSupply = 0 (fully burned); EQD(old) supply 0; GENS has no market.

## 7. Conclusion

Every value-bearing path on the live Ethereum contracts is either empty (0 balances) or gated by
the team's admin role / 2-of-5 relayer quorum. Deposits are administratively disabled. **External
unprivileged extractable value = $0.**
