// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface ISpePool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external returns (int256 amount0, int256 amount1);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function liquidity() external view returns (uint128);
}

interface ISpeSwapCallback {
    function swapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

interface ISpeFlashCallback {
    function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}

interface IPancakeRouter02 {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external returns (uint256[] memory amounts);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}

/// @notice Minimal arbitrage executor for SheepDex (SpePool) fork tests.
/// Executes exact-input swaps along a route, paying inputs from its own balance.
/// Supports a self-contained flash-loan mode funded by a SpePool flash() (0.15% fee).
contract ArbBot is ISpeSwapCallback, ISpeFlashCallback {
    address public immutable owner;
    uint160 internal constant MIN_SQRT = 4295128740;                                        // TickMath.MIN_SQRT_RATIO + 1
    uint160 internal constant MAX_SQRT = 1461446703485210103287273052203988822378723970341; // MAX_SQRT_RATIO - 1

    constructor() { owner = msg.sender; }
    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    receive() external payable {}

    function approveAll(address token, address spender) external onlyOwner {
        IERC20(token).approve(spender, type(uint256).max);
    }

    /// @notice Swap the bot's entire balance of the route's current token through each pool in order.
    function runRoute(address[] calldata pools, bool[] calldata zeroForOne) external onlyOwner {
        _runRoute(pools, zeroForOne);
    }

    function _runRoute(address[] memory pools, bool[] memory zeroForOne) internal {
        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            bool zfo = zeroForOne[i];
            address tokenIn = zfo ? ISpePool(pool).token0() : ISpePool(pool).token1();
            uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
            require(amountIn > 0, "no input");
            ISpePool(pool).swap(address(this), zfo, int256(amountIn), zfo ? MIN_SQRT : MAX_SQRT, "");
        }
    }

    /// @notice Single exact-input swap; returns amount of output token received.
    function swapIn(address pool, bool zeroForOne, uint256 amountIn) external onlyOwner returns (uint256 out) {
        (int256 a0, int256 a1) = ISpePool(pool).swap(address(this), zeroForOne, int256(amountIn), zeroForOne ? MIN_SQRT : MAX_SQRT, "");
        out = zeroForOne ? uint256(-a1) : uint256(-a0);
    }

    /// @notice Route a swap through an external AMM (e.g. PancakeSwap V2) with the bot as msg.sender.
    function routerSwap(address router, address[] calldata path, uint256 amountIn) external onlyOwner returns (uint256 out) {
        IERC20(path[0]).approve(router, type(uint256).max);
        uint256[] memory amounts =
            IPancakeRouter02(router).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp + 60);
        out = amounts[amounts.length - 1];
    }

    function swapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        if (amount0Delta > 0) require(IERC20(ISpePool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta)), "pay0");
        if (amount1Delta > 0) require(IERC20(ISpePool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta)), "pay1");
    }

    /// @notice Flash-borrow from `flashPool` (principal amount0/amount1) and run an internal route with the proceeds.
    /// Repays principal + 0.15% fee; any surplus remains in the bot.
    function flashArb(address flashPool, uint256 amount0, uint256 amount1, address[] calldata pools, bool[] calldata zeroForOne)
        external onlyOwner
    {
        bytes memory data = abi.encode(pools, zeroForOne, amount0, amount1);
        ISpePool(flashPool).flash(address(this), amount0, amount1, data);
    }

    function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        (address[] memory pools, bool[] memory zeroForOne, uint256 amount0, uint256 amount1) =
            abi.decode(data, (address[], bool[], uint256, uint256));
        _runRoute(pools, zeroForOne);
        address t0 = ISpePool(msg.sender).token0();
        address t1 = ISpePool(msg.sender).token1();
        if (amount0 > 0) require(IERC20(t0).transfer(msg.sender, amount0 + fee0), "repay0");
        if (amount1 > 0) require(IERC20(t1).transfer(msg.sender, amount1 + fee1), "repay1");
    }
}
