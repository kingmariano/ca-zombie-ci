// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @dev Minimal Nerve/Curve-style Swap interface (as deployed by Mobius on Celo).
interface ISwap {
    function getToken(uint8 index) external view returns (address);
    function getTokenBalance(uint8 index) external view returns (uint256);
    function getLpToken() external view returns (address);
    function getA() external view returns (uint256);
    function getAPrecise() external view returns (uint256);
    function getSwapFee() external view returns (uint256);
    function getVirtualPrice() external view returns (uint256);
    function getAdminBalance(uint256 index) external view returns (uint256);
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function calculateSwap(uint8 from, uint8 to, uint256 dx) external view returns (uint256);
    function calculateRemoveLiquidity(address account, uint256 amount) external view returns (uint256[] memory);
    function calculateRemoveLiquidityOneToken(address account, uint256 amount, uint8 idx) external view returns (uint256);
    function swap(uint8 from, uint8 to, uint256 dx, uint256 minDy, uint256 deadline) external returns (uint256);
    function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external returns (uint256);
    function removeLiquidity(uint256 amount, uint256[] calldata minAmounts, uint256 deadline) external returns (uint256[] memory);
    function removeLiquidityOneToken(uint256 amount, uint8 idx, uint256 minAmount, uint256 deadline) external returns (uint256);
    function withdrawAdminFees() external;
    function setSwapFee(uint256) external;
    function setAdminFee(uint256) external;
    function pause() external;
}

/// @dev Mobius StableSwap Proxy (Vyper) that owns all pools.
interface IPoolProxy {
    function ownership_admin() external view returns (address);
    function emergency_admin() external view returns (address);
    function burner_kill() external view returns (bool);
    function burners(address) external view returns (address);
    function burn(address) external;
    function burn_many(address[20] calldata) external;
    function withdraw_admin_fees(address pool) external;
    function set_burner_kill(bool) external;
}

interface IMobiusBurner {
    function burn(IERC20 coin) external returns (bool);
    function receiver() external view returns (address);
    function baseToken() external view returns (address);
    function is_killed() external view returns (bool);
}

interface IUbeswapFactory {
    function getPair(address, address) external view returns (address);
    function allPairs(uint256) external view returns (address);
    function allPairsLength() external view returns (uint256);
}

interface IUbeswapPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
}

interface IUbeswapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory);
}

interface IGauge {
    function lp_token() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claim_rewards() external;
    function claimable_reward(address, address) external view returns (uint256);
    function reward_tokens(uint256) external view returns (address);
}
