// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IUniV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniV2Factory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
}

interface IDfynStakingRewards {
    function getReward() external;
    function withdraw(uint256) external;
    function earned(address account, address rewardToken) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function rewardTokens(uint256) external view returns (address);
    function stakingToken() external view returns (address);
}

interface IDfynVault {
    function claim() external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function vaultToken() external view returns (address);
}
