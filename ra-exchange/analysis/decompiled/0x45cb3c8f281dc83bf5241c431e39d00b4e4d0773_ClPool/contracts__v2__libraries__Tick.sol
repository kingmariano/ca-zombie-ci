// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './TickMath.sol';
import './LiquidityMath.sol';
import './States.sol';

/// @title Tick
/// @notice Contains functions for managing tick processes and relevant calculations
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    /// @notice Derives max liquidity per tick from given tick spacing
    /// @dev Executed within the pool constructor
    /// @param tickSpacing The amount of required tick separation, realized in multiples of `tickSpacing`
    ///     e.g., a tickSpacing of 3 requires ticks to be initialized every 3rd tick i.e., ..., -6, -3, 0, 3, 6, ...
    /// @return The max liquidity per tick
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) external pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    /// @notice Retrieves fee growth data
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @param tickCurrent The current tick
    /// @param feeGrowthGlobal0X128 The all-time global fee growth, per unit of liquidity, in token0
    /// @param feeGrowthGlobal1X128 The all-time global fee growth, per unit of liquidity, in token1
    /// @return feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @return feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    function getFeeGrowthInside(
        mapping(int24 => TickInfo) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        TickInfo storage lower = self[tickLower];
        TickInfo storage upper = self[tickUpper];

        // calculate fee growth below
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // calculate fee growth above
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    struct UpdateTickParams {
        // the tick that will be updated
        int24 tick;
        // the current tick
        int24 tickCurrent;
        // a new amount of liquidity to be added (subtracted) when tick is crossed from left to right (right to left)
        int128 liquidityDelta;
        // the all-time global fee growth, per unit of liquidity, in token0
        uint256 feeGrowthGlobal0X128;
        // the all-time global fee growth, per unit of liquidity, in token1
        uint256 feeGrowthGlobal1X128;
        // The all-time seconds per max(1, liquidity) of the pool
        uint160 secondsPerLiquidityCumulativeX128;
        // the tick * time elapsed since the pool was first initialized
        int56 tickCumulative;
        // the current block timestamp cast to a uint32
        uint32 time;
        // true for updating a position's upper tick, or false for updating a position's lower tick
        bool upper;
        // the maximum liquidity allocation for a single tick
        uint128 maxLiquidity;
    }

    /// @notice Updates a tick and returns true if the tick was flipped from initialized to uninitialized, or vice versa
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param params the tick details and changes
    /// @return flipped Whether the tick was flipped from initialized to uninitialized, or vice versa
    function update(
        mapping(int24 => TickInfo) storage self,
        UpdateTickParams memory params
    ) internal returns (bool flipped) {
        TickInfo storage info = self[params.tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, params.liquidityDelta);

        require(liquidityGrossAfter <= params.maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (params.tick <= params.tickCurrent) {
                info.feeGrowthOutside0X128 = params.feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = params.feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = params.secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = params.tickCumulative;
                info.secondsOutside = params.time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        info.liquidityNet = params.upper
            ? int256(info.liquidityNet).sub(params.liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(params.liquidityDelta).toInt128();
    }

    /// @notice Clears tick data
    /// @param self The mapping containing all initialized tick information for initialized ticks
    /// @param tick The tick that will be cleared
    function clear(mapping(int24 => TickInfo) storage self, int24 tick) internal {
        delete self[tick];
    }

    struct CrossParams {
        // The destination tick of the transition
        int24 tick;
        // The all-time global fee growth, per unit of liquidity, in token0
        uint256 feeGrowthGlobal0X128;
        // The all-time global fee growth, per unit of liquidity, in token1
        uint256 feeGrowthGlobal1X128;
        // The current seconds per liquidity
        uint160 secondsPerLiquidityCumulativeX128;
        // The previous period end's seconds per liquidity
        uint256 endSecondsPerLiquidityPeriodX128;
        // The starting tick of the period
        int24 periodStartTick;
        // The tick * time elapsed since the pool was first initialized
        int56 tickCumulative;
        // The current block.timestamp
        uint32 time;
    }

    /// @notice Transitions to next tick as needed by price movement
    /// @param self The mapping containing all tick information for initialized ticks
    /// @param params Structured cross params
    /// @return liquidityNet The amount of liquidity added (subtracted) when tick is crossed from left to right (right to left)
    function cross(
        mapping(int24 => TickInfo) storage self,
        CrossParams calldata params
    ) external returns (int128 liquidityNet) {
        TickInfo storage info = self[params.tick];
        uint256 period = params.time / 1 weeks;

        info.feeGrowthOutside0X128 = params.feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = params.feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 =
            params.secondsPerLiquidityCumulativeX128 -
            info.secondsPerLiquidityOutsideX128;

        {
            uint256 periodSecondsPerLiquidityOutsideX128;
            uint256 periodSecondsPerLiquidityOutsideBeforeX128 = info.periodSecondsPerLiquidityOutsideX128[period];
            if (params.tick <= params.periodStartTick && periodSecondsPerLiquidityOutsideBeforeX128 == 0) {
                periodSecondsPerLiquidityOutsideX128 =
                    params.secondsPerLiquidityCumulativeX128 -
                    periodSecondsPerLiquidityOutsideBeforeX128 -
                    params.endSecondsPerLiquidityPeriodX128;
            } else {
                periodSecondsPerLiquidityOutsideX128 =
                    params.secondsPerLiquidityCumulativeX128 -
                    periodSecondsPerLiquidityOutsideBeforeX128;
            }
            info.periodSecondsPerLiquidityOutsideX128[period] = periodSecondsPerLiquidityOutsideX128;
        }

        info.tickCumulativeOutside = params.tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = params.time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }

    /// @dev Common checks for valid tick inputs.
    function checkTicks(int24 tickLower, int24 tickUpper) external pure {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= TickMath.MIN_TICK, 'TLM');
        require(tickUpper <= TickMath.MAX_TICK, 'TUM');
    }
}
