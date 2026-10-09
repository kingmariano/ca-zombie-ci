// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal interfaces for the live Fulcrom (Cronos) deployment, taken from the
// verified sources recovered from explorer.cronos.com (status: Matched).

interface IVault {
    function isLeverageEnabled() external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function gov() external view returns (address);
    function router() external view returns (address);
    function errors(uint256) external view returns (string memory);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external;
    function getPosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    )
        external
        view
        returns (
            uint256 size,
            uint256 collateral,
            uint256 averagePrice,
            uint256 entryFundingRate,
            uint256 reserveAmount,
            int256 realisedPnl,
            uint256 lastIncreasedTime
        );
}

interface IOrderBook {
    function minExecutionFee() external view returns (uint256);
    function weth() external view returns (address);
    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;
    function executeDecreaseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) external;
}

interface ITimelock {
    function enableLeverage(address _vault) external;
    function disableLeverage(address _vault) external;
    function setIsLeverageEnabled(address _vault, bool _isLeverageEnabled) external;
}

interface IPositionManager {
    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
}

interface IRouter {
    function approvePlugin(address _plugin) external;
}

interface IShortsTracker {
    function isGlobalShortDataReady() external view returns (bool);
    function updateGlobalShortData(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta,
        uint256 _markPrice,
        bool _isIncrease
    ) external;
}

interface IFlpManager {
    function shortsTrackerAveragePriceWeight() external view returns (uint256);
    function getAum(bool maximise) external view returns (uint256);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}
