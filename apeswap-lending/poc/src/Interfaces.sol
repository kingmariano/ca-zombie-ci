// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IComptroller {
    function admin() external view returns (address);
    function getAllMarkets() external view returns (address[] memory);
    function getAccountLiquidityByLiquidationFactor(address account) external view returns (uint, uint, uint);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getUnderlyingPriceInLen(address underlying) external view returns (uint);
    function markets(address cToken) external view returns (bool, uint, uint, uint, uint, uint);
    function mintGuardianPaused(address cToken) external view returns (bool);
    function borrowGuardianPaused(address cToken) external view returns (bool);
    function _setMintPaused(address cToken, bool state) external returns (bool);
    function _setBorrowPaused(address cToken, bool state) external returns (bool);
    function _setActiveCollateralCaps(address[] calldata cTokens, uint[] calldata caps) external;
    function checkMembership(address account, address cToken) external view returns (bool);
}

interface ICToken {
    function symbol() external view returns (string memory);
    function underlying() external view returns (address);
    function decimals() external view returns (uint8);
    function comptroller() external view returns (address);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function totalSupply() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function accrueInterest() external returns (uint);
    function mint(uint256 mintAmount) external returns (uint);
    function mint() external payable returns (uint);
    function redeem(uint256 redeemTokens) external returns (uint);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint);
    function borrow(uint256 borrowAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint);
    function transfer(address dst, uint256 amount) external returns (bool);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function decimals() external view returns (uint8);
}
