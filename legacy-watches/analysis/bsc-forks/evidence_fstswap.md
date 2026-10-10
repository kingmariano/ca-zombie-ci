# FstSwap (BSC) — evidence (2026-10-10)

## Contracts (verified on-chain)
- Factory `0x9A272d734c5a0d7d84E0a892e891a553e8066dce` — "FstswapFactory"-style V2, **4,842 pairs**, `feeTo = 0x0`
  (no feeToSetter()/owner() functions; both revert). https://bscscan.com/address/0x9A272d734c5a0d7d84E0a892e891a553e8066dce
- Router `0x1b6c9c20693afde803b27f8782156c0f892abc2d` ("FstSwap Router 2") — factory() verified == 0x9A27...
- Old router `0xf817c41c7FF5E55FadC4afBb22B88b2108F0E4f3` ("Fstswap Finance: Router") — factory() reverts.
  **Holds 5.040146778 USDT + 4,335 wei FIST + 0.018052978 BNB** (dust; no rescue path found) → S ≈ $5.04.
- FIST `0xc9882def23bc42d53895b8361d0b1edc7570bc6a` — "FistStandard" v0.5.16, 6 decimals.
  - owner() = 0x0 (renounced). Source contains **no mint function** (function list: transfer/approve/transferFrom/allowance/renounce/transferOwnership only) → no free mint.
- FIST/USDT pair `0xb4ec801aed8c92f2e69589518aaa127afb37d8c9`; FIST/WBNB pair `0xe9d7363bd5b5c252f28ceb142ffdb01e0fb936a5` (dust).

## Live state
- Block 126,836,295 (sampled scan): FIST/USDT reserves = **3,140,594.29 USDT / 14,967,772.06 FIST**.
  Real balances == reserves (excess0 = excess1 = 0). LP totalSupply 1.316e18, 0% at 0x0/dEaD → LP-owned (H-O).
- USDT in FstSwap per DefiLlama tokensInUsd snapshot (2026-10-10): **$3.92M** (report's $3.54M consistent with an earlier snapshot).
- Excess scan (161/4,842 pairs sampled: first 80 + last 80 + must-include), hits verified at end block 126,836,342:
  - pair 0x3106cb6b0f71f5d88d9a36221e0f11edda03b998, token FEG 0xacfc9558..., excess 153.159714664 FEG
  - pair 0x8a94f437228d3f1c2f045e8cd172739641bc101d, token PG 0xdc748bbe..., excess 5.32e-7
  - Value ≈ $0: FEG price ≈ $8e-11 (Pancake FEG/WBNB pool: 3.7236 WBNB / 3.389e13 FEG); PG has a ~1.35 WBNB pool.
  - `skim(to)` simulation on these pairs succeeds (eth_call) → technically permissionless, economically nil.
  - **Full 4,842-pair scan deferred to CI** (`bsc-forks_enum.py`).

## FIST price sanity (live)
- Block 126,837,245: FstSwap `getAmountsOut(1 FIST)` = 0.2084716 USDT; PancakeSwap = 0.2092834 USDT (FIST/USDT pair 0x703f1c0b...).
  Spot difference 0.39% ≈ round-trip fee level (0.3%+0.3%) → **no stale arb**; report claim "$0.2259" is not current (live ≈ $0.2085–$0.2093).
  (WBNB = $747.31 via Pancake WBNB/USDT at same block.)

## Top-pair counterparty token checks (sampled top pairs)
- 0x0efb5fd2402a0967b92551d6af54de148504a115 named "WBNB" — a WETH-clone (deposit/withdraw only, no free mint).
- 0x2170ed08... = BETH (Binance); 0xf8069273... "Token" (no mint); FIST (no mint); no freely-mintable token vs USDT found.

## Farm/chef
- No staking contracts listed for FstSwap (DefiLlama registry: factory only). Factory/router/feeTo hold no user funds.

Verdict: no E-U found in sample; value is LP/user-held (H-O). Confidence high for sampled pairs; full-population excess scan pending CI.
