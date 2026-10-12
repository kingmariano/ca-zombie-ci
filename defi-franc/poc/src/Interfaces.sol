// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface ITroveManager {
    function liquidate(address _asset, address _borrower) external;
    function batchLiquidateTroves(address _asset, address[] memory _troveArray) external;
    function redeemCollateral(
        address _asset,
        uint256 _DCHFamount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external;
    function isRedemptionWhitelisted() external view returns (bool);
}

interface ITroveManagerHelpers {
    function getTroveOwnersCount(address) external view returns (uint256);
    function getTroveFromTroveOwnersArray(address, uint256) external view returns (address);
    function getTroveDebt(address, address) external view returns (uint256);
    function getTroveColl(address, address) external view returns (uint256);
    function getTroveStatus(address, address) external view returns (uint256);
    function getCurrentICR(address, address, uint256) external view returns (uint256);
    function getPendingAssetReward(address, address) external view returns (uint256);
    function getPendingDCHFDebtReward(address, address) external view returns (uint256);
    function getRedemptionRateWithDecay(address) external view returns (uint256);
    function getBorrowingRateWithDecay(address) external view returns (uint256);
    function getTCR(address, uint256) external view returns (uint256);
}

interface IActivePoolLike {
    function getAssetBalance(address) external view returns (uint256);
    function getDCHFDebt(address) external view returns (uint256);
}

interface IDefaultPoolLike {
    function getAssetBalance(address) external view returns (uint256);
    function getDCHFDebt(address) external view returns (uint256);
}

interface IStabilityPoolLike {
    function getTotalDCHFDeposits() external view returns (uint256);
    function getAssetBalance() external view returns (uint256);
    function deposits(address) external view returns (uint256);
    function getDepositorAssetGain(address) external view returns (uint256);
    function getCompoundedDCHFDeposit(address) external view returns (uint256);
    function withdrawFromSP(uint256) external;
    function currentEpoch() external view returns (uint128);
}

interface ICollSurplusPoolLike {
    function getCollateral(address, address) external view returns (uint256);
    function getAssetBalance(address) external view returns (uint256);
}

interface IBorrowerOpsLike {
    function claimCollateral(address) external;
    function closeTrove(address) external;
    function openTrove(
        address _asset,
        uint256 _tokenAmount,
        uint256 _maxFeePercentage,
        uint256 _DCHFamount,
        address _upperHint,
        address _lowerHint
    ) external payable;
}

interface IHintHelpersLike {
    function getRedemptionHints(address, uint256, uint256, uint256)
        external
        view
        returns (address, uint256, uint256);
}

interface IPriceFeedLike {
    function fetchPrice(address) external returns (uint256);
}

interface IMONStakingLike {
    function stake(uint256) external;
    function unstake(uint256) external;
    function getPendingAssetGain(address, address) external view returns (uint256);
    function getPendingDCHFGain(address) external view returns (uint256);
    function totalMONStaked() external view returns (uint256);
    function paused() external view returns (bool);
}

interface IUniswapV3PoolLike {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256, int256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function liquidity() external view returns (uint128);
    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
    function fee() external view returns (uint24);
}

interface IQuoterV2Like {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);
}

interface IAggregatorLike {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}
