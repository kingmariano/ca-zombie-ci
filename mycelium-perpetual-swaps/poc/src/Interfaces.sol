// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Minimal interfaces for Mycelium Perpetual Swaps (Arbitrum) — read-only fork tests.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

interface IVault {
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;
    function directPoolDeposit(address _token) external;
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong)
        external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
    function getMinPrice(address) external view returns (uint256);
    function getMaxPrice(address) external view returns (uint256);
    function isSwapEnabled() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);
    function isLiquidator(address) external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);
    function poolAmounts(address) external view returns (uint256);
    function reservedAmounts(address) external view returns (uint256);
    function bufferAmounts(address) external view returns (uint256);
    function feeReserves(address) external view returns (uint256);
    function errors(uint256) external view returns (string memory);
    function gov() external view returns (address);
}

interface IOrderBook {
    function executeSwapOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeIncreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function getSwapOrder(address _account, uint256 _orderIndex)
        external view returns (address, address, address, uint256, uint256, uint256, bool, bool, uint256);
}

interface IMlpManager {
    function removeLiquidity(address _tokenOut, uint256 _mlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function removeLiquidityForAccount(address _account, address _tokenOut, uint256 _mlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function getAum(bool maximise) external view returns (uint256);
    function getAumInUsdg(bool maximise) external view returns (uint256);
    function inPrivateMode() external view returns (bool);
    function isHandler(address) external view returns (bool);
    function cooldownDuration() external view returns (uint256);
    function lastAddedAt(address) external view returns (uint256);
}

interface IRewardTracker {
    function claim(address _receiver) external returns (uint256);
    function claimable(address _account) external view returns (uint256);
    function stake(address _depositToken, uint256 _amount) external;
    function unstake(address _depositToken, uint256 _amount) external;
    function stakedAmounts(address) external view returns (uint256);
    function depositBalances(address, address) external view returns (uint256);
    function isDepositToken(address) external view returns (bool);
    function isHandler(address) external view returns (bool);
    function inPrivateStakingMode() external view returns (bool);
    function inPrivateClaimingMode() external view returns (bool);
    function totalSupply() external view returns (uint256);
    function rewardToken() external view returns (address);
}

interface IRewardRouter {
    function unstakeAndRedeemMlp(address _tokenOut, uint256 _mlpAmount, uint256 _minOut, address _receiver) external returns (uint256);
    function claimFees() external;
}

interface IRewardDistributor {
    function pendingRewards() external view returns (uint256);
    function tokensPerInterval() external view returns (uint256);
    function lastDistributionTime() external view returns (uint256);
    function rewardTracker() external view returns (address);
    function rewardToken() external view returns (address);
    function distribute() external returns (uint256);
}
