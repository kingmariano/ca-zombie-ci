// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPulseXPairLike {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function factory() external view returns (address);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPulseXFactoryLike {
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function allPairsLength() external view returns (uint256);
    function getPair(address, address) external view returns (address);
}

interface IPulseXRouterLike {
    function factory() external view returns (address);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IStableSwap3 {
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
    function owner() external view returns (address);
    function fee() external view returns (uint256);
    function admin_fee() external view returns (uint256);
    function A() external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
    function token() external view returns (address);
}

interface IBuyAndBurn {
    function owner() external view returns (address);
    function anyAuth() external view returns (bool);
    function devCut() external view returns (uint256);
    function devAddr() external view returns (address);
    function convertLps(address[] calldata, address[] calldata) external;
}

interface IPhuxPool {
    function getScalingFactors() external view returns (uint256[] memory);
    function getRateProviders() external view returns (address[] memory);
}

interface I9inchMCV2 {
    function owner() external view returns (address);
    function withdraw(uint256 pid, uint256 amount) external;
    function emergencyWithdraw(uint256 pid) external;
    function userInfo(uint256 pid, address user) external view returns (uint256 amount, uint256 rewardDebt);
}

interface IV3Pool {
    function liquidity() external view returns (uint128);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function factory() external view returns (address);
}
