// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
}

interface IAToken is IERC20 {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function RESERVE_TREASURY_ADDRESS() external view returns (address);
    function redeem(uint256 amount) external;
    function scaledTotalSupply() external view returns (uint256);
}

interface IVariableDebtToken is IERC20 {
    function scaledTotalSupply() external view returns (uint256);
}

interface ILendingPool {
    function getReservesList() external view returns (address[] memory);
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    function getReserveData(address asset) external view returns (ReserveData memory);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;
    function paused() external view returns (bool);
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
}

struct ReserveConfigurationMap {
    uint256 data;
}

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

interface IPriceOracleGetter {
    function getAssetPrice(address asset) external view returns (uint256);
}

interface IPriceFeed {
    function fetchPrice() external view returns (uint256);
    function lastGoodPrice() external view returns (uint256);
    function updatePrice() external returns (uint256);
    function status() external view returns (uint8);
    function chainlinkOracle() external view returns (address);
    function bandOracle() external view returns (address);
    function TIMEOUT() external view returns (uint256);
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function getSourceOfAsset(address asset) external view returns (address);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IMultiFeeDistribution {
    struct RewardData {
        address token;
        uint256 amount;
    }
    function stake(uint256 amount, bool lock) external;
    function withdraw(uint256 amount) external;
    function getReward(address[] memory rewardTokens) external;
    function claimableRewards(address account) external view returns (RewardData[] memory);
    function totalSupply() external view returns (uint256);
    function lockedSupply() external view returns (uint256);
    function rewardTokens(uint256 idx) external view returns (address);
}
