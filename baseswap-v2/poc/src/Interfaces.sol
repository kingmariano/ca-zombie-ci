// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function factory() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function kLast() external view returns (uint256);
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function mint(address to) external returns (uint256);
    function burn(address to) external returns (uint256, uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address to) external;
    function sync() external;
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IPancakeFactory {
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function getPair(address, address) external view returns (address);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IMasterChef {
    function owner() external view returns (address);
    function bswap() external view returns (address);
    function bswapPerSec() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function poolLength() external view returns (uint256);
    function poolInfo(uint256)
        external
        view
        returns (address lpToken, uint256 allocPoint, uint256 lastRewardTime, uint256 accPerShare, uint256 totalDeposit);
    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}

interface IFactoryManager {
    function owner() external view returns (address);
    function operator() external view returns (address);
    function treasury() external view returns (address);
    function collectProtocolFeeV2(IPancakePair pool) external;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}
