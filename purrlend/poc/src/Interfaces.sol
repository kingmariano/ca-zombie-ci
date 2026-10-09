// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IACLManager {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function POOL_ADMIN_ROLE() external view returns (bytes32);
    function EMERGENCY_ADMIN_ROLE() external view returns (bytes32);
    function RISK_ADMIN_ROLE() external view returns (bytes32);
    function FLASH_BORROWER_ROLE() external view returns (bytes32);
    function BRIDGE_ROLE() external view returns (bytes32);
    function ASSET_LISTING_ADMIN_ROLE() external view returns (bytes32);
}

interface IPool {
    function ADDRESSES_PROVIDER() external view returns (address);
    function getReservesList() external view returns (address[] memory);
    function getConfiguration(address asset) external view returns (uint256);
    function getReserveData(address asset) external view returns (
        uint256 configuration,
        uint128 liquidityIndex,
        uint128 currentLiquidityRate,
        uint128 variableBorrowIndex,
        uint128 currentVariableBorrowRate,
        uint128 currentStableBorrowRate,
        uint40 lastUpdateTimestamp,
        uint16 id,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress,
        uint128 accruedToTreasury,
        uint128 unbacked,
        uint128 isolationModeTotalDebt
    );
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function backUnbacked(address asset, uint256 amount, uint256 fee) external returns (uint256);
    function paused() external view returns (bool);
}

interface IPoolConfigurator {
    function setReservePause(address asset, bool paused) external;
    function setReserveFreeze(address asset, bool freeze) external;
    function configureReserveAsCollateral(address asset, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus) external;
    function updateAToken(address asset, address implementation, bytes calldata params) external;
}

interface IPoolAddressesProvider {
    function owner() external view returns (address);
    function getPool() external view returns (address);
    function getPoolConfigurator() external view returns (address);
    function getACLManager() external view returns (address);
    function getACLAdmin() external view returns (address);
    function setACLManager(address newAclManager) external;
    function setPoolImpl(address newPoolImpl) external;
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}
