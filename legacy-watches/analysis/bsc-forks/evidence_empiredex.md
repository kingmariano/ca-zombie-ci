# EmpireDEX (multi-chain) — evidence: sweep() pairs, phantom reserves, owner extraction (2026-10-10)

## Contracts (docs: https://empire-dex.readthedocs.io/en/latest/multichain.html)
| chain | factory | router | DEX token | block (scan) |
|---|---|---|---|---|
| BSC | 0x06530550A48F990360DFD642d2132354A144F31d | 0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348 | EMPIRE 0xc83859c413a6ba5ca1620cd876c7e33a232c1c34 | 126,835,070 |
| Ethereum | 0xd674b01E778CF43D3E6544985F893355F46A74A5 | 0xe7A504316BebbE540496E29798187c9ECAD6ef4F | ROOTDEX 0x2302f393690487a4Fc5927bBeF63ff113E0c479d | 26,162,307 |
| Cronos | 0x06530550A48F990360DFD642d2132354A144F31d | 0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348 | CRODEX 0xc83859c4..., EMPIRE 0x0001df70e9cdc0c1c6b24e2172b89b105c879ddc | 99,073,880 |
| Polygon / xDai / Avalanche / Fantom / Kava | 0x06530550A48F990360DFD642d2132354A144F31d | 0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348 | per-chain tokens (docs) | see JSONs |

Routers verified on-chain: BSC router.factory() == BSC factory. ETH pair factory() == ETH factory.

## Custom pair ("EmpirePair"): virtual balances via sweep
Verified source of pair `0x3af4cf7953cab46a1b4af5f483c2ac81b994777e` (BSC WBNB/ROOT):

```solidity
function _balanceOfSelf(address token) internal view returns (uint256 balance) {
    if (token == sweepableToken) { balance = sweptAmount; }        // !! virtual component
    return balance.add(IERC20(token).balanceOf(address(this)));
}

function sweep(uint256 amount, bytes calldata data) external override lock {
    // msg.sender MUST be token0 or token1 (the DEX token contract)
    ... maxSweepable = _reserveSwept - amountOut; ...
    _safeTransfer(sweepableToken, msg.sender, amount);   // paired asset leaves the pair
    sweptAmount = sweptAmount.add(amount);               // reserves stay "whole" (virtual)
    IEmpireCallee(msg.sender).empireSweepCall(amount, data);
}
function unsweep(uint256 amount) external override lock { /* token contract sends asset back */ }
```
swap/mint/burn/sync/skim all use `_balanceOfSelf` (virtual = sweptAmount + real balance).
The DEX token contracts (BSC `wROOTSat` 0xf2f9889e..., `EmpireDex` 0xc83859c4...) expose
`sweep()/unsweep()` **onlyOwner**, plus `extractLegacyEmpire()` / `extractFutureRewards()` **onlyOwner**.

## Live state — reserves vs real balances (the "underwater" gap)
| chain | pairs | underwater (priced sides, USD) | example |
|---|---|---|---|
| BSC | 40 | **$1,171,658** | pair 0x3af4cf79 WBNB/ROOT: reserve 834.000000066 WBNB, real 0.000000066 WBNB; pair 0xf3114cb3 EMPIRE/WBNB: reserve 698.692164984 WBNB, real 0.00000073 WBNB |
| Cronos | 44 | $146,180 | 0xe5f14636: reserve 916,531 WCRO, real 175,420 (741k missing); 0xc8c0ad6b: 661,535 → 635; 0xb0a7d882: 285,067 → 79,017 |
| Ethereum | 5 | $36,406 | ROOTDEX/WETH pair: reserve 14.608 WETH, real 1.418 WETH |
| xDai | 9 | $22,328 | — |
| Avalanche | 14 | $12,187 | — |
| Fantom | 17 | $5,872 | — |
| Polygon | 11 | $3,084 | — |
| Kava | 3 | $0 | tiny |

**Total phantom reserves ≈ $1.40M** across chains (only priced sides; unpriced sides would add more).

Swept assets are NOT in the token contracts (checked 2026-10-10, BSC block ~126,835,000):
- WBNB.balanceOf(wROOTSat 0xf2f9889e...) = 0
- WBNB.balanceOf(EmpireDex 0xc83859c4...) = 0
- WBNB.balanceOf(factory/router/escrow 0x38F73653...) = 0
- WCRO.balanceOf(CRODEX / EMPIRE) = 0 ; WETH.balanceOf(ROOTDEX) = 0
=> swept value was moved onward by the token owners (extractLegacyEmpire/extractFutureRewards are onlyOwner).

## Simulations (eth_call, read-only)
- `EmpirePair.sweep(1,0x)` from random EOA → `Empire: INCORRECT_CALLER`
- `wROOTSat.sweep(1,0x)` from random EOA → `Ownable: caller is not the owner`
- `EmpirePair.skim(random)` is callable but only pays the (near-zero) positive excess.

## Excess scan (all pairs, all chains)
- BSC 6 hits / Cronos 1 / Ethereum 1 / Polygon 1 — all dust: e.g. ADMC 68.66 tokens; sell simulation
  (getAmountsOut 68.66 ADMC → USDT) returns **0.000000316 USDT**. Others unpriced (no DefiLlama price, dead pairs).
=> no material skim opportunity.

Verdict: privileged (owner-only) sweep + extraction; reserves are virtual; real value in pairs ≈ dust.
DefiLlama TVL ($2.86M) is overstated by ≈$1.4M vs real tokens present in pairs.
