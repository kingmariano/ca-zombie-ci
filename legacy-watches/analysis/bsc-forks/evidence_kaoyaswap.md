# KaoyaSwap (BSC) — evidence: drained pairs + bricked accounting (2026-10-10)

## Contracts
- Factory `0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA` — UniswapV2Factory v0.6.10, 8 pairs, feeTo=0x0
  (verified source `UniswapV2Factory`, BscScan). https://bscscan.com/address/0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA
- Router (proxy) `0x879EAD67C92ec2bFa70fa9d157F500B7b31b64AB` — `RouterProxy` (AdminUpgradeabilityProxy)
  - admin() = `0x21079de6e13a5c7dbb0e3e2c9aad60135c30c01d` (also owner of MasterChef + KY token proxy)
  - implementation() = `0x498206af7d939c06eca9602ce518b985cb396c7b` (current; no longer exposes getTokenInPair)
  - Note: the KaoyaSwap interface `.env.production` pairs this router with **PancakeSwap's factory**
    `0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73`, i.e. UI swaps went to Pancake liquidity, not the 0xbFB0 pools.
- KY token `0xa8a33e365D5a03c94C3258A10Dd5d6dfE686941B` ("KaoyaProxy", symbol KY, 18 dec, totalSupply 1.3M,
  owner 0x21079de6e13a5c7dbb0e3e2c9aad60135c30c01d)
- MasterChef `0x86e7455180db4C9f627A8a62a382ebEFac243fbE` (verified `MasterChef`; owner 0x21079de6...; KY balance 188.50)
- Farm `0x21F17c2eC5741c1bEb76d50F08171138A6BA97bf` (owner 0x50d1859999f72486c22928b00865982c906278c8) — holds LP of drained pairs (see below)

## Modified pair: accounting trusts the router proxy
Verified source of pair `0x150587549bce4268a35aea3ac81d0ce94b722934` ("UniswapV2Pair" v0.6.10, non-standard):

```solidity
address public router;                              // extra storage vs canonical V2

function initialize(address _token0, address _token1, address _router) external {
    require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
    token0 = _token0; token1 = _token1; router = _router;   // router chosen by factory
}

function _getBalance(address _token) private view returns (uint balance) {
    return IUniswapV2Router02(router).getTokenInPair(address(this), _token);   // !! external trust
}
```
`swap/mint/burn/sync` all use `_getBalance(...)` instead of `token.balanceOf(pair)`. The pair has **no `skim()`**.

## Live state at BSC block 126,834,965 (all 8 pairs)
| pair | reserves (token0/token1) | real balances | notes |
|---|---|---|---|
| 0x150587549bce4268a35aea3ac81d0ce94b722934 | 40,986.28 KY / 891.09 WBNB | 0 / 0 | LP 6,022.26; farm holds 2,372 |
| 0x51a94dc11afe833d249cebb606acc9a1504782b2 | 128.71 WBNB / 1,919.49 BUSD | 0 / 0 | LP 494.19; farm holds 478.35 (96.8%) |
| 0x3533d784739c26812abf447d44966c1721fd9926 | 405,636.63 KY / 97,126.33 BUSD | 0 / 0 | LP 198,005.18; farm holds 103,223.11 |
| 0xc3ae9cdd... / 0xe97c8c5e... / 0x81fd072c... / 0x8374a42b... / 0x0a90d2a9... | small | 0 / 0 | LP 1,000–1,006 |

- Underwater (priced sides): **$861,278** at block 126,834,965 (WBNB/BUSD sides only; KY unpriced).
- DefiLlama TVL for KaoyaSwap shows **$1.63M** (tokensInUsd snapshot 2026-10-10) — phantom reserves, real value ≈ $0.

## Simulations (eth_call, read-only)
- `KaoyaPair.burn(random)` → revert (plain) — `_getBalance` → router proxy has no `getTokenInPair` anymore.
- `KaoyaPair.swap(1,0,random,0x)` → revert — same cause.
- `router.getTokenInPair(pair,token)` → revert (current impl `0x4982...` lacks the function).
=> pairs are **bricked**: LP tokens (still held by users and the farm) cannot be burned or traded; value $0.

## Attribution
All extraction functions on the router proxy side are admin-upgradeable (proxy admin 0x21079de6...). The drain itself
cannot be dated from state alone; DefiLlama lists a KaoyaSwap incident "2022-08-24 $118k (Protocol Logic/Swap Logic Flaw)"
— the 0xbFB0 factory/TVL data starts 2024, so the hack record may be misattributed. Current state is what matters:
pairs empty, accounting dead, value $0.
