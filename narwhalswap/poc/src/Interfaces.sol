// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function mint(address, uint256) external;
    function deposit() external payable;
}

interface IPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function burn(address) external;
    function mint(address) external returns (uint256);
}

interface IFactory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address, address) external view returns (address);
    function setFeeTo(address) external;
}

interface IFarm {
    function withdraw(uint256) external;
    function emergencyWithdraw() external;
    function getReward() external;
    function stake(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function earned(address) external view returns (uint256);
    function updateBuffRate(address) external;
    function buffRateReporter(address) external;
    function getPower(address) external view returns (uint256);
    function _rewardPerTokenStored() external view returns (uint256);
    function lpToken() external view returns (address);
    function nar() external view returns (address);
    function rnlp() external view returns (address);
    function seize(address, uint256) external;
}

interface ICollecter {
    function convert(address, address) external;
    function threshold() external view returns (uint256);
}

interface INlpLock {
    function withdraw() external;
    function owner() external view returns (address);
    function unlockTime() external view returns (uint256);
    function lpToken() external view returns (address);
}

interface INarToken is IERC20 {
    function _maxSupply() external view returns (uint256);
    function _totalBurnToken() external view returns (uint256);
    function _openTransfer() external view returns (bool);
    function _governance() external view returns (address);
}

interface IThugs {
    function paused() external view returns (bool);
    function whitelistedSenders(address) external view returns (bool);
    function getLastTwap() external view returns (uint256);
    function priceAverageLast() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
