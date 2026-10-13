// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function deposit() external payable;
    function totalSupply() external view returns (uint256);
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function totalSupply() external view returns (uint256);
}

interface ILendingPool {
    function paused() external view returns (bool);
    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function liquidationCall(address collateral, address principal, address user, uint256 debtToCover, bool receiveAToken) external;
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getReserveData(address asset)
        external
        view
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 currentLiquidityRate,
            uint128 variableBorrowIndex,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint8 id
        );
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}
