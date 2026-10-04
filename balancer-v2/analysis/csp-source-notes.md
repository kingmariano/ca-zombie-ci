# ComposableStablePool source notes — rounding bug, BPT handling, vulnerable pool types

Provenance: unless stated otherwise, quotes below are from the **deployed** ComposableStablePool
source of pool `0xDACf5Fa19b1f720111609043ac67A9818262850c` (Ethereum), fetched via Etherscan
`getsourcecode` and extracted to `deployed-csp-src/`. Contract name `ComposableStablePool`,
compiler `0.7.1`, `version()` = `{"name":"ComposableStablePool","version":5,"deployment":"20230711-composable-stable-pool-v5"}`.
The second exploited pool `0x93D199263632a4EF4Bb438F1feB99e57b4b5f0BD` is the same v5 code.
`MetaStablePool.sol` was fetched from `balancer-v2-monorepo` commit `059284e75dce88071f90950379cc13170f172c98`
(the commit that introduced the rate-based scaling-factor override), `LinearPool.sol` /
`BaseGeneralPool.sol` / `ScalingHelpers.sol` / `BasePool.sol` from the repo master
(`other-pools/`).

## 1. Entry point and BPT handling

`onSwap` is inherited from `BaseGeneralPool` (deployed `@balancer-labs/v2-pool-utils/contracts/BaseGeneralPool.sol`):

```solidity
function onSwap(
    SwapRequest memory swapRequest,
    uint256[] memory balances,
    uint256 indexIn,
    uint256 indexOut
) external override onlyVault(swapRequest.poolId) returns (uint256) {
    _beforeSwapJoinExit();
    _validateIndexes(indexIn, indexOut, _getTotalTokens());
    uint256[] memory scalingFactors = _scalingFactors();

    return
        swapRequest.kind == IVault.SwapKind.GIVEN_IN
            ? _swapGivenIn(swapRequest, balances, indexIn, indexOut, scalingFactors)
            : _swapGivenOut(swapRequest, balances, indexIn, indexOut, scalingFactors);
}
```

**BPT is a fully swappable registered token.** There is no rejection of the BPT address anywhere
in `onSwap`; indices and balances are the *registered* arrays that include BPT
(`_getTotalTokens()` counts it, `getBptIndex()` gives its position). `ComposableStablePool`
overrides the two hooks and reroutes any swap touching BPT to `_swapWithBpt`
(`contracts/ComposableStablePool.sol`, lines 183-231):

```solidity
function _swapGivenOut(
    SwapRequest memory swapRequest,
    uint256[] memory registeredBalances,
    uint256 registeredIndexIn,
    uint256 registeredIndexOut,
    uint256[] memory scalingFactors
) internal virtual override returns (uint256) {
    return
        (swapRequest.tokenIn == IERC20(this) || swapRequest.tokenOut == IERC20(this))
            ? _swapWithBpt(swapRequest, registeredBalances, registeredIndexIn, registeredIndexOut, scalingFactors)
            : super._swapGivenOut(
                swapRequest, registeredBalances, registeredIndexIn, registeredIndexOut, scalingFactors
            );
}
```

(`_swapGivenIn` is the mirror image with `super._swapGivenIn`.)

`_swapWithBpt` (lines 310-365) is the **BPT join/exit swap path** and contains the same
rounding-down upscale:

```solidity
function _swapWithBpt(
    SwapRequest memory swapRequest,
    uint256[] memory registeredBalances,
    uint256 registeredIndexIn,
    uint256 registeredIndexOut,
    uint256[] memory scalingFactors
) private returns (uint256) {
    bool isGivenIn = swapRequest.kind == IVault.SwapKind.GIVEN_IN;

    _upscaleArray(registeredBalances, scalingFactors);
    swapRequest.amount = _upscale(                       // <-- mulDown, both directions
        swapRequest.amount,
        scalingFactors[isGivenIn ? registeredIndexIn : registeredIndexOut]
    );

    (uint256 preJoinExitSupply, uint256[] memory balances, uint256 currentAmp, uint256 preJoinExitInvariant) =
        _beforeJoinExit(registeredBalances);

    (uint256 amountCalculated, uint256 postJoinExitSupply) = registeredIndexOut == getBptIndex()
        ? _doJoinSwap(isGivenIn, swapRequest.amount, balances, _skipBptIndex(registeredIndexIn), ...)
        : _doExitSwap(isGivenIn, swapRequest.amount, balances, _skipBptIndex(registeredIndexOut), ...);

    _updateInvariantAfterJoinExit(currentAmp, balances, preJoinExitInvariant, preJoinExitSupply, postJoinExitSupply);

    return
        isGivenIn
            ? _downscaleDown(amountCalculated, scalingFactors[registeredIndexOut]) // Amount out, round down
            : _downscaleUp(amountCalculated, scalingFactors[registeredIndexIn]);  // Amount in, round up
}
```

- `registeredIndexOut == getBptIndex()` → **join swap** (`_doJoinSwap`): BPT is the output
  (token in → BPT out). If `!isGivenIn` it calls `_joinSwapExactBptOutForTokenIn` →
  `StableMath._calcTokenInGivenExactBptOut`, increases `postJoinExitSupply`, and the Vault later
  charges the token in. This is the repayment path used in phase 3 of the exploit.
- otherwise → **exit swap** (`_doExitSwap`): BPT is the input (BPT in → token out). If
  `!isGivenIn` it calls `_exitSwapExactTokenOutForBptIn` →
  `StableMath._calcBptInGivenExactTokensOut`, decreases `postJoinExitSupply`. This is the
  deficit-creating path used in phase 1.
- Both branches mutate a *memory* copy of `balances` and call `_updateInvariantAfterJoinExit`,
  which stores the new invariant for protocol-fee accounting. The BPT swap itself is priced by
  `StableMath` with the invariant — i.e. exactly like a single-token join/exit.

BPT accounting facts (`contracts/ComposableStablePoolStorage.sol`):

```solidity
function _getVirtualSupply(uint256 bptBalance) internal view returns (uint256) {
    // The initial amount of BPT pre-minted is _PREMINTED_TOKEN_BALANCE, and it goes entirely to the pool balance in
    // the vault. So the virtualSupply (the amount of BPT supply in circulation) is defined as:
    // virtualSupply = totalSupply() - _balances[_bptIndex]
    return totalSupply().sub(bptBalance);
}
```

The pool pre-mints a huge BPT amount at initialization and holds it in the Vault
(`_PREMINTED_TOKEN_BALANCE`), so the registered balance of BPT is enormous (observed:
`2.596e33` in the on-swap `balances`). `getActualSupply()` = virtual supply + protocol fee debt.
This is why a batchSwap can "borrow" BPT from the pool: the Vault moves BPT balances around and
only requires the *sender's net delta* to be covered at settlement.

## 2. The rounding error(s)

### 2a. Regular (non-BPT) exact-out swaps — `BaseGeneralPool._swapGivenOut`

```solidity
function _swapGivenOut(...) internal virtual returns (uint256) {
    _upscaleArray(balances, scalingFactors);
    swapRequest.amount = _upscale(swapRequest.amount, scalingFactors[indexOut]); // BUG: mulDown
    uint256 amountIn = _onSwapGivenOut(swapRequest, balances, indexIn, indexOut);
    amountIn = _downscaleUp(amountIn, scalingFactors[indexIn]);                 // round up (input)
    return _addSwapFeeAmount(amountIn);
}
```

`ComposableStablePool` does **not** override this for regular swaps; it is the code path used
for the WETH↔osETH / WETH↔wstETH amplification triplets.

### 2b. The helpers — `BasePool`/`ScalingHelpers`

```solidity
function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
    // ... (comment) ...
    return FixedPoint.mulDown(amount, scalingFactor);   // floor(amount*sf/1e18)
}
function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal pure {
    for (uint256 i = 0; i < length; ++i) {
        amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
    }
}
function _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
    return FixedPoint.divDown(amount, scalingFactor);
}
function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
    return FixedPoint.divUp(amount, scalingFactor);
}
```

So downscaling is directional (down for outputs, up for inputs) but **upscaling is always
`mulDown`**. For EXACT_IN, upscaling the input down is conservative for the pool. For
EXACT_OUT, upscaling the output down is *anti*-conservative: the pool believes less leaves
than actually leaves, under-charges the input, and the invariant slips down. The fix used in
simulations is an upscale-up variant:

```solidity
swapRequest.amount = _upscaleUp(swapRequest.amount, scalingFactors[indexOut]); // FixedPoint.mulUp
```

### 2c. Scaling factors include exchange rates (the enabling override)

`contracts/ComposableStablePoolRates.sol`:

```solidity
function _scalingFactors() internal view virtual override returns (uint256[] memory) {
    uint256 totalTokens = _getTotalTokens();
    uint256[] memory scalingFactors = new uint256[](totalTokens);
    for (uint256 i = 0; i < totalTokens; ++i) {
        scalingFactors[i] = _getScalingFactor(i).mulDown(_getTokenRate(i));   // decimals * rate
    }
    return scalingFactors;
}
```

`_getTokenRate` returns `FixedPoint.ONE` for BPT and otherwise the cached rate-provider value
(osETH ≈ 1.057, wstETH ≈ 1.218). The `_upscale` comment explicitly warns there is
"no rounding error unless `_scalingFactor()` is overridden" — this override is the enabling
change. In the exploit's critical swap, osETH's scaling factor ≈1.057 made
`mulDown(17, 1.057e18) = 17` (true scaled value 17.97…), a ~5.8% error on a single 17-wei output;
repeated over 25-30 triplets at 1-18 wei balances this moves `D` by a large relative amount.

## 3. Why the attack works end-to-end

1. `batchSwap` step with `assetIn = BPT` and `kind = GIVEN_OUT` enters `_swapWithBpt` →
   `_exitSwapExactTokenOutForBptIn`: the pool sends out real tokens and computes BPT in. The
   attacker does not need to own that BPT at that moment — the Vault only requires the batch's
   *final net* delta per token to be settled.
2. The exit ladder drives the real-token balances to tens of wei; the exact-out dust triplets
   then make `D` decrease by systematically under-charging for the 4-17 wei outputs, because
   `_upscale` truncates the output's scaled value. (`_calcInGivenOut` itself is not the bug:
   per Unvariant, Balancer's version even rounds *up* in the solver; the bug is the input to it.)
3. The final join swaps (`assetOut = BPT`, `GIVEN_OUT`) mint/return BPT at the deflated price
   and close the temporary deficit. Net BPT ends positive; WETH/wstETH/osETH end up credited
   to the attacker's Vault internal balance.

## 4. Which pool types share the vulnerable code?

| pool type | overrides `_scalingFactors` with rates? | exact-out path | rounding-down `_upscale`? | BPT flash-deficit (BPT as swappable token)? | observed exploited? |
|---|---|---|---|---|---|
| `StablePool` | no — only decimals (`_computeScalingFactor` → 1e12/1e18, unitary) | `BaseGeneralPool._swapGivenOut` | yes (but no scale beyond decimals → harmless) | no (no BPT token) | no |
| `WeightedPool` | no | own path, 18-dec normalization | n/a | no | no |
| `MetaStablePool` | **yes** — `_scalingFactors()` multiplies `super._scalingFactors()` by `_priceRates()` (quote below) | `BaseGeneralPool._swapGivenOut` | **yes** | no (no BPT) | flagged in the post-incident re-audit; whitehat-drained preventively (weaker: needs pre-existing low liquidity / large capital) |
| `LinearPool` | **yes** — `_scalingFactor(wrapped) = decimalsScaling * _getWrappedTokenRate()`, and `getScalingFactors()` includes BPT at `FixedPoint.ONE` | own `_onSwapGeneral` with the same `request.amount = _upscale(request.amount, scalingFactors[indexOut])` (line 310) | **yes** | **yes** — LinearPool's BPT is a registered token and `_swapGivenBptIn/_onSwapGivenOut` implement BPT join/exit swaps | not the pool class used in this tx; OpenZeppelin lists LinearPool as containing the attack vector; Balancer's post-mortem says only CSPs actually satisfied all exploit preconditions |
| `ComposableStablePool` | **yes** — `decimals * rate` | `BaseGeneralPool._swapGivenOut` (regular) **and** `_swapWithBpt` (BPT swaps) | **yes, two sites** | **yes** — BPT is a swappable pool token, preminted to the Vault | **yes** — this is the $128M exploit |

`MetaStablePool._scalingFactors` (commit `059284e`, `pkg/pool-stable/contracts/meta/MetaStablePool.sol`):

```solidity
function _scalingFactors() internal view virtual override returns (uint256[] memory scalingFactors) {
    scalingFactors = super._scalingFactors();
    uint256[] memory priceRates = _priceRates();
    for (uint256 i = 0; i < scalingFactors.length; i++) {
        scalingFactors[i] = scalingFactors[i].mulDown(priceRates[i]);
    }
}
```

`LinearPool._onSwapGeneral` (master, `pkg/pool-linear/contracts/LinearPool.sol`, lines 301-315):

```solidity
if (request.kind == IVault.SwapKind.GIVEN_IN) {
    request.amount = _upscale(request.amount, scalingFactors[indexIn]);
    uint256 amountOut = _onSwapGivenIn(request, balances, params);
    return _downscaleDown(amountOut, scalingFactors[indexOut]);
} else {
    request.amount = _upscale(request.amount, scalingFactors[indexOut]);   // same rounding-down bug
    uint256 amountIn = _onSwapGivenOut(request, balances, params);
    return _downscaleUp(amountIn, scalingFactors[indexIn]);
}
```

**Is the BPT-deficit amplification unique to composable pools?** The *code-level* combination
"BPT is a registered token + swaps may touch BPT + rate-based scaling factors" is present in
`ComposableStablePool` **and** `LinearPool` (both include their BPT in the token list and
support BPT-in/BPT-out swap paths). `MetaStablePool` has the rounding bug but no BPT and
therefore no flash-deficit amplification. `StablePool`/`WeightedPool` have neither the
rate-based factors nor BPT. In practice, the November 2025 on-chain exploit used only
ComposableStablePools; the Balancer post-mortem attributes this to CSPs uniquely satisfying
all three requirements, and both Certora and Trail of Bits name MetaStable as the other
pool type requiring emergency action.

## 5. Patch status note (for the fork test)

The `balancer-v2-monorepo` master, fetched 2026-10, still contains `_upscale` =
`FixedPoint.mulDown` in `pkg/solidity-utils/contracts/helpers/ScalingHelpers.sol` and the
rounding-down `_swapGivenOut` in `BaseGeneralPool.sol` (Balancer v2 was frozen; the response to
the incident was operational — pausing pools and recovery-mode exits — not an in-place pool
upgrade). The fork test must therefore use a mainnet fork at block `23,717,396` (or the
public PoC's `23717397 - 1`), not a locally patched build. Newer ComposableStablePool
deployments (v6/v7, if any) and Balancer v3 are not affected: v3 rounds consistently and
removed composable BPT swaps in favour of ERC4626 buffers (Certora, Balancer post-mortem).
