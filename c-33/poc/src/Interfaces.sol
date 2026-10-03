// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface ICToken {
    function underlying() external view returns (address);
    function getCash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function comptroller() external view returns (address);
    function decimals() external view returns (uint8);

    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function repayBorrow(uint256) external returns (uint256);
    function liquidateBorrow(address, uint256, address) external returns (uint256);
    function accrueInterest() external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
}

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function markets(address) external view returns (bool isListed, uint256 collateralFactorMantissa, bool isComped);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
    function oracle() external view returns (address);
    function closeFactorMantissa() external view returns (uint256);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
}
