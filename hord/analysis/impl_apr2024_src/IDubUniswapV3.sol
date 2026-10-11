//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * HETH contract.
 * @author Srdjan Simonovic
 * Date created: 27.09.23.
 * Github: s2imonovic
 */
interface IDubUniswapV3 {
    function WETH() external view returns(address);
    function estimateAmountOut(
        address pool,
        address tokenIn,
        uint128 amountIn
    ) external view returns (uint amountOut);
    function swapExactOutputSingle(
        address addrOfSwapRouter,
        address pool,
        address tokenIn,
        uint256 amountInMaximum,
        uint256 amountOut
    ) external returns (uint256 amountIn);
}
