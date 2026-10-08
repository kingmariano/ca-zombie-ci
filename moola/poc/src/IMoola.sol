// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces for the Moola Market (Celo) live-state PoC.
/// Read-only + local-fork only; no mainnet transactions.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

library DataTypes {
    struct ReserveConfigurationMap { uint256 data; }
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint8 id;
    }
}

interface ILendingPool {
    function paused() external view returns (bool);
    function getReservesList() external view returns (address[] memory);
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
    function getUserAccountData(address user)
        external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function getUserConfiguration(address user) external view returns (uint256);
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken)
        external;
    function flashLoan(address receiverAddress, address[] calldata assets, uint256[] calldata amounts,
        uint256[] calldata modes, address onBehalfOf, bytes calldata params, uint16 referralCode) external;
    function getAddressesProvider() external view returns (address);
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint256);
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);
    function setPause(bool val) external;
}

interface ILendingPoolAddressesProvider {
    function owner() external view returns (address);
    function getPriceOracle() external view returns (address);
    function getPoolAdmin() external view returns (address);
    function getEmergencyAdmin() external view returns (address);
    function getLendingPool() external view returns (address);
    function getLendingPoolConfigurator() external view returns (address);
    function getLendingPoolCollateralManager() external view returns (address);
    function setPriceOracle(address) external;
    function setPoolAdmin(address) external;
}

interface ILendingPoolConfigurator {
    function setReserveFactor(address asset, uint256 reserveFactor) external;
    function freezeReserve(address asset) external;
    function unfreezeReserve(address asset) external;
    function activateReserve(address asset) external;
    function deactivateReserve(address asset) external;
    function configureReserveAsCollateral(address asset, uint256 ltv, uint256 liqThreshold, uint256 liqBonus) external;
}

interface IMoolaOracle {
    function owner() external view returns (address);
    function getAssetPrice(address asset) external view returns (uint256);
    function getSourceOfAsset(address asset) external view returns (address);
    function getFallbackOracle() external view returns (address);
    function setAssetSources(address[] calldata assets, address[] calldata sources) external;
}

interface ICeloProxyPriceProvider is IMoolaOracle {
    function getPriceFeed(address asset) external view returns (address);
    function updateAssets(address[] calldata assets, address[] calldata priceFeeds) external;
}

interface ISortedOraclesPriceFeed {
    function consult() external view returns (uint256);
}

interface IFixedPriceOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function PRICE() external view returns (uint256);
    function ASSET() external view returns (address);
}

interface ISortedOracles {
    function medianRate(address token) external view returns (uint256, uint256);
    function isOldestReportExpired(address token) external view returns (bool, address);
    function medianTimestamp(address token) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(address[] calldata assets, uint256[] calldata amounts, uint256[] calldata premiums,
        address initiator, bytes calldata params) external returns (bool);
}

interface IAToken is IERC20 {
    function scaledBalanceOf(address user) external view returns (uint256);
    function scaledTotalSupply() external view returns (uint256);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function RESERVE_TREASURY_ADDRESS() external view returns (address);
    function POOL() external view returns (address);
}

interface IPriceFeedWrapper {
    function consult() external view returns (uint256);
}

interface IRegistry {
    function getAddressForOrDie(bytes32 id) external view returns (address);
}
