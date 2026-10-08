// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function markets(address cToken) external view returns (bool, uint256);
    function mintGuardianPaused(address cToken) external view returns (bool);
    function borrowGuardianPaused(address cToken) external view returns (bool);
    function borrowCaps(address cToken) external view returns (uint256);
    function oracle() external view returns (address);
    function admin() external view returns (address);
    function pauseGuardian() external view returns (address);
    function liquidatorsWhitelistVerifier() external view returns (address);
    function liquidateBorrowAllowed(address, address, address, address, uint256) external returns (uint256);
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);
    function borrowGuardianPaused() external view returns (bool);
    function transferGuardianPaused() external view returns (bool);
}

interface ICToken {
    function symbol() external view returns (string memory);
    function underlying() external view returns (address);
    function getCash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function reserveFactorMantissa() external view returns (uint256);
    function getAccountSnapshot(address) external view returns (uint256, uint256, uint256, uint256);
    function protocolSeizeShareMantissa() external view returns (uint256);
    function initialExchangeRateMantissa() external view returns (uint256);
    function admin() external view returns (address);
}

interface IOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
    function assetPrices(address asset) external view returns (uint256);
    function tokenConfigs(address asset) external view returns (address, bytes21, uint64, address);
    function getExchangeRateOf(address asset) external view returns (uint256);
}

interface IFtsoV2 {
    function getFeedById(bytes21 feedId) external view returns (uint256, int8, uint64);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IStakedFlr {
    function submit() external payable returns (uint256);
    function getPooledFlrByShares(uint256 shareAmount) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IExchangeable {
    function getExchangeRate() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IAllowList {
    function allowed(address) external view returns (bool);
}
