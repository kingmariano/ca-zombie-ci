// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function mint(address, uint256) external;
}

interface IUniV2Factory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function getPair(address, address) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function locked() external view returns (bool);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setLocked(bool) external;
}

interface IUniV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function kLast() external view returns (uint256);
    function factory() external view returns (address);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function sync() external;
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IBRLMasterChef {
    function poolLength() external view returns (uint256);
    function poolInfo(uint256) external view returns (address, uint256, uint256, uint256, uint16);
    function userInfo(uint256, address) external view returns (uint256, uint256);
    function pendingBRL(uint256, address) external view returns (uint256);
    function updatePool(uint256) external;
    function massUpdatePools() external;
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function BRL() external view returns (address);
    function owner() external view returns (address);
    function BRLPerBlock() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function updateEmissionRate(uint256) external;
    function set(uint256, uint256, uint16, bool) external;
    function add(uint256, IERC20, uint16, bool) external;
    function dev(address) external;
    function setFeeAddress(address) external;
}
