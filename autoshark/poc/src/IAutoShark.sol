// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function skim(address) external;
    function sync() external;
}

interface IFactory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
}

interface IMasterChef {
    function poolLength() external view returns (uint256);
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function pendingFins(uint256, address) external view returns (uint256);
    function owner() external view returns (address);
    function feeAddress() external view returns (address);
    function fins() external view returns (address);
    function controller() external view returns (address);
}

interface IFeeDistributor {
    function distribute(address[] calldata) external;
    function distributeSingle(address[] calldata) external;
    function owner() external view returns (address);
    function keeper() external view returns (address);
}

interface ITokenMintable is IERC20 {
    function mint(uint256) external returns (bool);
    function mint(address, uint256) external returns (bool);
    function owner() external view returns (address);
}

interface IMasterSquidFarm {
    function deposit(uint256, uint256, address) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function poolLength() external view returns (uint256);
    function controller() external view returns (address);
    function owner() external view returns (address);
    function getBoost(address, uint256) external view returns (uint256);
}

interface IJawsPool {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function stakingToken() external view returns (address);
    function rewardsToken() external view returns (address);
    function paused() external view returns (bool);
    function withdraw(uint256) external;
    function getReward() external;
    function withdrawAll() external;
}

interface ILaunchpad {
    function harvest() external;
    function allowClaim() external view returns (bool);
    function finalWithdraw(uint256, uint256) external;
    function lpToken() external view returns (address);
}
