// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IDemaxFactory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function getPair(address, address) external view returns (address);
    function isPair(address) external view returns (bool);
    function contractCodeHash() external view returns (bytes32);
}

interface IDemaxPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function remainReward() external view returns (uint256);
    function getDGASReserve() external view returns (uint256);
    function totalShare() external view returns (uint256);
    function mintedShare() external view returns (uint256);
    function lastMintBlock(address) external view returns (uint256);
    function users(address) external view returns (uint256 amount, uint256 rewardDebt, uint256 rewardEarn);
    function queryReward() external view returns (uint256, uint256);
    function mintReward() external returns (uint256);
    function sync() external;
    function swap(uint256, uint256, address, bytes calldata) external;
    function mint(address) external returns (uint256);
    function burn(address, address, uint256) external returns (uint256, uint256);
}

interface IDemaxPlatform {
    function isPause() external view returns (bool);
    function owner() external view returns (address);
    function POOL() external view returns (address);
    function GOVERNANCE() external view returns (address);
    function FACTORY() external view returns (address);
    function DGAS() external view returns (address);
    function WETH() external view returns (address);
    function CONFIG() external view returns (address);
    function swapPrecondition(address) external view returns (bool);
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256)
        external returns (uint256[] memory);
    function addLiquidity(address, address, uint256, uint256, uint256, uint256, uint256)
        external returns (uint256, uint256, uint256);
    function removeLiquidity(address, address, uint256, uint256, uint256, address, uint256)
        external returns (uint256, uint256);
}

interface IDemaxPool {
    function claimReward(address, address) external;
    function queryReward(address, address) external view returns (uint256);
    function totalReward() external view returns (uint256);
    function pairReward(address) external view returns (uint256);
    function pairAmountPerShare(address) external view returns (uint256);
    function users(address, address) external view returns (uint256, uint256);
}

interface IDemaxGovernance {
    function baseToken() external view returns (address);
    function lockTime() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function stakingSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function rewardOf(address) external view returns (uint256);
    function collectReward(address) external returns (uint256);
    function upgradeApproveReward() external returns (uint256);
    function receiveReward(address, uint256) external returns (bool);
}

interface IDemaxConfig {
    function getConfigValue(bytes32) external view returns (uint256);
    function platform() external view returns (address);
    function governor() external view returns (address);
    function dev() external view returns (address);
    function tokenStatus(address) external view returns (uint256);
}

interface IPancakeRouter {
    function getAmountsIn(uint256, address[] calldata) external view returns (uint256[] memory);
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256)
        external returns (uint256[] memory);
    function swapTokensForExactTokens(uint256, uint256, address[] calldata, address, uint256)
        external returns (uint256[] memory);
}
