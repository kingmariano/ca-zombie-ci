// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPoint128} from "./FixedPoint128.sol";

/// @title Concentrated Liquidity Reward Math Library
/// @notice Standard algorithms for calculating rewards in concentrated liquidity pools
/// @dev These are well-established formulas used across Uniswap V3 forks (scenes a faire)
///      - Reward growth per liquidity using Q128 fixed-point arithmetic
///      - Position-specific reward accumulation based on tick range
///      - Uses OpenZeppelin's audited Math library for safe mulDiv operations
library CLRewardMath {

    /// @notice Snapshot of global reward state at a point in time
    struct GlobalRewardSnapshot {
        uint256 rewardGrowthGlobalX128;
        uint256 totalStakedLiquidity;
        uint256 availableReserve;
        uint256 secondsSinceLastUpdate;
    }

    /// @notice Position-specific reward tracking data
    struct PositionRewardInfo {
        uint256 rewardGrowthInsideLastX128;
        uint128 stakedLiquidity;
        int24 lowerTick;
        int24 upperTick;
    }

    /// @notice Computes additional reward growth since last update
    /// @dev Standard formula: deltaGrowth = (rewardRate * timeDelta * Q128) / totalLiquidity
    /// @param rewardRate Rewards distributed per second
    /// @param timeDelta Seconds elapsed since last update
    /// @param totalLiquidity Total liquidity staked in the pool
    /// @return additionalGrowthX128 Incremental growth in Q128 format
    function computeRewardGrowthDelta(
        uint256 rewardRate,
        uint256 timeDelta,
        uint256 totalLiquidity
    ) internal pure returns (uint256 additionalGrowthX128) {
        if (timeDelta == 0 || totalLiquidity == 0) {
            return 0;
        }

        uint256 rewardAmount = rewardRate * timeDelta;
        additionalGrowthX128 = Math.mulDiv(
            rewardAmount,
            FixedPoint128.Q128,
            totalLiquidity
        );
    }

    /// @notice Projects current global reward growth including pending updates
    /// @param snapshot Current state snapshot from the pool
    /// @param currentRate Active reward distribution rate
    /// @param currentTimestamp Block timestamp for projection
    /// @return projectedGrowthX128 Projected global growth including pending accrual
    function projectGlobalGrowth(
        GlobalRewardSnapshot memory snapshot,
        uint256 currentRate,
        uint256 currentTimestamp
    ) internal pure returns (uint256 projectedGrowthX128) {
        projectedGrowthX128 = snapshot.rewardGrowthGlobalX128;

        if (snapshot.secondsSinceLastUpdate == 0) {
            return projectedGrowthX128;
        }

        if (snapshot.availableReserve == 0 || snapshot.totalStakedLiquidity == 0) {
            return projectedGrowthX128;
        }

        uint256 accruedReward = currentRate * snapshot.secondsSinceLastUpdate;

        // Cap at available reserve
        if (accruedReward > snapshot.availableReserve) {
            accruedReward = snapshot.availableReserve;
        }

        uint256 deltaGrowth = Math.mulDiv(
            accruedReward,
            FixedPoint128.Q128,
            snapshot.totalStakedLiquidity
        );

        projectedGrowthX128 += deltaGrowth;
    }

    /// @notice Calculates rewards earned by a specific position
    /// @dev Formula: rewards = (growthInside - growthInsideLast) * liquidity / Q128
    /// @param growthInsideCurrentX128 Current reward growth inside position's tick range
    /// @param growthInsideLastX128 Last recorded growth when position was updated
    /// @param liquidity Amount of liquidity in the position
    /// @return earnedAmount Tokens earned by the position
    function calculatePositionEarnings(
        uint256 growthInsideCurrentX128,
        uint256 growthInsideLastX128,
        uint128 liquidity
    ) internal pure returns (uint256 earnedAmount) {
        if (growthInsideCurrentX128 <= growthInsideLastX128) {
            return 0;
        }

        uint256 growthDelta = growthInsideCurrentX128 - growthInsideLastX128;

        earnedAmount = Math.mulDiv(
            growthDelta,
            liquidity,
            FixedPoint128.Q128
        );
    }

    /// @notice Calculates reward distribution rate for an epoch
    /// @dev Handles both new epochs and ongoing epochs with additional rewards
    /// @param newRewardAmount Fresh rewards being added
    /// @param existingPendingRewards Unclaimed rewards from ongoing epoch
    /// @param epochDuration Time period over which to distribute
    /// @return ratePerSecond Reward tokens distributed per second
    function calculateDistributionRate(
        uint256 newRewardAmount,
        uint256 existingPendingRewards,
        uint256 epochDuration
    ) internal pure returns (uint256 ratePerSecond) {
        require(epochDuration > 0, "Invalid duration");

        uint256 totalRewards = newRewardAmount + existingPendingRewards;
        ratePerSecond = totalRewards / epochDuration;
    }

    /// @notice Computes pending rewards for an epoch in progress
    /// @param currentRate Active distribution rate
    /// @param timeRemaining Seconds until epoch ends
    /// @return pendingAmount Rewards not yet distributed
    function calculatePendingRewards(
        uint256 currentRate,
        uint256 timeRemaining
    ) internal pure returns (uint256 pendingAmount) {
        pendingAmount = currentRate * timeRemaining;
    }
}
