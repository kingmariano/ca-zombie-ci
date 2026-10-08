# LaChain network & CapyFi deployment — findings

*Read-only analysis. All on-chain claims verified via public RPC (`https://rpc1.mainnet.lachain.network`) at block 23,472,941 unless noted. No transactions were signed or sent.*

## 1. What "LaChain" is

| Field | Value |
|---|---|
| Name | LaChain (LaChain Network / LaChain Mainnet) |
| Chain ID | **274** (`0x112`) |
| Native currency | **LAC (LaCoin)**, 18 decimals, fixed supply 10,000,000,000 |
| RPC | `https://rpc1.mainnet.lachain.network`, `https://rpc2.mainnet.lachain.network` (both live) |
| Explorer | `https://explorer.lachain.network` ("Powered by Blockscout"; v2 API not reachable — see Blockers) |
| Stack | Polygon Edge v0.6.3 (Geth fork), PoA, ~14.3 s blocks |
| Operators | LACNet (RedCLARA/LACNIC non-profit) / Ripio ecosystem; whitepaper & docs at lachain.gitbook.io / lachain.network |
| Testnet | LaTestnet, chain ID 418, currency TLA |

Sources: chainlist.org/chain/274, rpc.info/lachain, LaChain whitepaper (PDF), explorer live reads.

**LAC on LaChain is the native gas coin.** There is no ERC-20 LAC needed for the protocol; the CapyFi repo (`DeployCLac.s.sol`) and the deployed market use the pseudo-native marker `0xEeee…EEeE` (CLac/CEther style). No live DEX market for LAC was found on LaChain (Ladex Exchange is marked `deprecated: true` on DefiLlama; its $16.6k TVL is stale).

## 2. CapyFi deployment on LaChain — FOUND, live

DefiLlama's `compound.js` registry lists a `lac` chain for capyfi; the LaChain/capyfi-sc repo's `HelperConfig.getLaChainConfig()` matches the on-chain deployment exactly. The current docs.capyfi.com "Networks" page no longer lists LaChain (only ETH / World Chain / Base are labelled Active), but the LaChain deployment is **live and accruing** (market accrual blocks ~20.6M vs tip 23.47M).

| Contract | Address | Notes |
|---|---|---|
| Unitroller (Comptroller proxy) | `0x123Abe3A273FDBCeC7fc0EBedc05AaeF4eE63060` | verified code on-chain |
| Comptroller impl (repo) | `0xB45435f4d5Fa43C8Fd59199beA39D5A023D0d20c` | from HelperConfig; not independently verified |
| Oracle | `0x4E07BDEec540D3a2318A91fAEe130E692506a360` | **SimplePriceOracle** — admin/authorized-set prices, no bounds (selectors `setUnderlyingPrice`, `getUnderlyingPrice`, `owner` present) |
| Admin / oracle owner | `0x8D3bdc2E35097B46Cd5Cc13808e47d79AF5FbB3C` | **contract on LaChain**; multisig-like, `getOwners()` returns 7 owners, `required()` = **4** |
| Multisig owners | `0x5CA3F8EE…F20F`, `0x23ceC92F…FBd5`, `0x9850b4F6…DcBe`, `0x00A74411…A645`, `0x5b72e13f…A313`, `0x34b6Ca11…9c7A`, `0x06782340…231E` | first 5 match the Ethereum CapyFi 2/5 multisig owners from the Coinspect audit |

Note: the Ethereum deployment addresses (`0x0b9af1fd…`, `0xfbA2712d…`, caTokens) are **not** deployed on LaChain (`eth_getCode` = `0x`). LaChain uses its own address set.

## 3. LaChain markets (on-chain, read-only)

Oracle prices come from the SimplePriceOracle; USD values are marked at those oracle prices. Full normalized data: `lachain_markets.json` (raw: `lachain_markets_raw.json`).

| Market | Address | Underlying | Cash | Supply (u) | Borrows (u) | Reserves | Util. | CF | Oracle px | Mint/Borrow paused |
|---|---|---|---|---|---|---|---|---|---|---|
| cUXD | `0x8A3e793E…DB5c` | UXD `0xDe09E74d…F4c7` | 51.92 UXD | 189.8k UXD | **194,747.7 UXD** | 3,372.2 | 99.97% | 0% | $1.00 | no/no |
| cLAC | `0x465ebFCe…D16cE` | **native LAC** (CLac) | 71,795,791.6 LAC | 71,837k LAC | 41,611.4 LAC | 30.6 | 0.06% | **75%** | $0.009995 | no/no |
| cWETH | `0xe0665116…b3C46` | WETH `0x42C8C9C0…0d7E` | 0.0000178 WETH | 59.6 WETH | 6.27 WETH | 0.1026 | ~100% | 82.5% | $2,454.27 | no/no |
| cWBTC (new) | `0x694C3940…9d251` | WBTC `0xf54B8cb8…4626` | 0.0285 WBTC | 0.581 WBTC | 0.5551 WBTC | 0.0057 | 95.1% | 70% | $77,971.04 | no/no |
| cWBTC (legacy) | `0x25F38518…B2D4a9` | WBTC (same) | 0 | 0 | 0 | 0 | — | 0% | $77,971.04 | **paused/paused** |
| cUSDT | `0x87153302…ee4bf6` | USDT `0x7dC8b9e3…FBee39` | 1,084.02 USDT | 1,090.0 USDT | 5.94 USDT | 996.3 | 0.5% | 0% | $1.00 | no/no |
| cUSDC | `0x08dfCC0e…F643063E` | USDC `0x51115241…cee5323` | 41,616.4 USDC | 238.8k USDC | 200,845.0 USDC | 3,420.3 | 82.8% | 0% | $1.00 | no/no |

Protocol-level: close factor 50%, liquidation incentive 8%, no global pauses. `whitelist()` reverts on every LaChain cToken — the whitelist gate exists only on the newer (Ethereum/WorldChain/Base) code; the LaChain cTokens are older.

**Key observations**

- **cLAC is the only borrowable collateral with a nonzero CF (75%)** and the largest cash position (~$718k marked at the admin-set oracle price of $0.009995). Mint and borrow are not paused and there is no whitelist on LaChain.
- **cUXD is insolvent on paper**: borrows 194.7k UXD exceed cash+borrows−reserves (189.8k UXD) against a hardcoded/oracle $1.00 price; supply is ~52 UXD of cash. The Coinspect audit's CAPY-01 (UXD always $1) was "fixed" by an updatable oracle — on LaChain it is a SimplePriceOracle still marking UXD at exactly $1.00.
- **cWETH/cWBTC/cUSDC are almost fully borrowed out** (utilization 83–100%), with cash of $0.04 / $2.2k / $41.6k respectively.
- The whole borrowable liquidity on LaChain is roughly **$43k (USDC) + $1.1k (USDT) + dust**; the cLAC collateral side holds ~$718k of native LAC valued by a single multisig-controlled oracle with **no price bounds**.

## 4. Verification / confidence

- **Verified on-chain**: chain ID/block, all 7 markets, oracle contract type (selectors), oracle prices, admin/owner, multisig owners/threshold, paused flags, no whitelist.
- **Cross-checked**: DefiLlama registry (`lac: 0x123Abe3A…`), LaChain/capyfi-sc `HelperConfig.s.sol`, Coinspect audit (ETH addresses & multisig owners).
- **Not verified**: Comptroller impl address (repo-only), the LaChain oracle's authorized-updater list (mapping getter only; owner can set prices directly), whether any Ladex/wLAC markets still exist (explorer API unavailable), Base-side LAC token (no evidence it exists — CapyFi Base markets do not include LAC).

## 5. Blockers

- `explorer.lachain.network` API (`/api/v2`, `/api`) returns 404/HTML; LaChain is not indexed by the Blockscout MCP server. All LaChain data was read via public RPC.
- Blockscout PRO credits were exhausted mid-session (Base token lookup failed); Base coverage for LAC relies on DexScreener/GeckoTerminal instead.
- Public Ethereum RPCs refuse wide-range `eth_getLogs` (403/525); pool keys were verified by local pool-id reconstruction instead of event scans.
