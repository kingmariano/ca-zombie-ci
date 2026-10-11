// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import './FullMath.sol';
import './FixedPoint128.sol';
import './FixedPoint32.sol';
import './LiquidityMath.sol';
import './SqrtPriceMath.sol';
import './States.sol';
import './Tick.sol';
import './TickMath.sol';
import './TickBitmap.sol';
import './Oracle.sol';

/// @title Position
/// @notice Positions represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Positions store additional state for tracking fees owed to the position
library Position {
    /// @notice Returns the hash used to store positions in a mapping
    /// @param owner The address of the position owner
    /// @param index The index of the position
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @return _hash The hash used to store positions in a mapping
    function positionHash(
        address owner,
        uint256 index,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, index, tickLower, tickUpper));
    }

    /// @notice Returns the Info struct of a position, given an owner and position boundaries
    /// @param self The mapping containing all user positions
    /// @param owner The address of the position owner
    /// @param index The index of the position
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @return position The position info struct of the given owners' position
    function get(
        mapping(bytes32 => PositionInfo) storage self,
        address owner,
        uint256 index,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (PositionInfo storage position) {
        position = self[positionHash(owner, index, tickLower, tickUpper)];
    }

    /// @notice Credits accumulated fees to a user's position
    /// @param self The individual position to update
    /// @param liquidityDelta The change in pool liquidity as a result of the position update
    /// @param feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @param feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    function _updatePositionLiquidity(
        PositionInfo storage self,
        States.PoolStates storage states,
        uint256 period,
        bytes32 _positionHash,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128,
        uint160 secondsPerLiquidityPeriodX128
    ) internal {
        uint128 liquidity = self.liquidity;
        uint128 liquidityNext;

        if (liquidityDelta == 0) {
            require(liquidity > 0, 'NP'); // disallow pokes for 0 liquidity positions
            liquidityNext = liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(liquidity, liquidityDelta);
        }

        // calculate accumulated fees
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(feeGrowthInside0X128 - self.feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128)
        );
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(feeGrowthInside1X128 - self.feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128)
        );

        // update the position
        if (liquidityDelta != 0) {
            self.liquidity = liquidityNext;
        }

        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
        {
            // write checkpoint, push a checkpoint if the last period is different, overwrite if not
            uint256 checkpointLength = states.positionCheckpoints[_positionHash].length;
            if (
                checkpointLength == 0 ||
                states.positionCheckpoints[_positionHash][checkpointLength - 1].period != period
            ) {
                states.positionCheckpoints[_positionHash].push(
                    PositionCheckpoint({period: period, liquidity: liquidityNext})
                );
            } else {
                states.positionCheckpoints[_positionHash][checkpointLength - 1].liquidity = liquidityNext;
            }
        }
        {
            int160 secondsPerLiquidityPeriodIntX128 = int160(secondsPerLiquidityPeriodX128);

            int160 secondsPerLiquidityPeriodStartX128 = self
                .periodRewardInfo[period]
                .secondsPerLiquidityPeriodStartX128;

            // take the difference to make the delta positive or zero
            secondsPerLiquidityPeriodIntX128 -= secondsPerLiquidityPeriodStartX128;

            // these int should never be negative
            if (secondsPerLiquidityPeriodIntX128 < 0) {
                secondsPerLiquidityPeriodIntX128 = 0;
            }

            int256 secondsDebtDeltaX96 = SafeCast.toInt256(
                FullMath.mulDivRoundingUp(
                    liquidityDelta > 0 ? uint256(liquidityDelta) : uint256(-liquidityDelta),
                    uint256(secondsPerLiquidityPeriodIntX128),
                    FixedPoint32.Q32
                )
            );

            self.periodRewardInfo[period].secondsDebtX96 = liquidityDelta > 0
                ? self.periodRewardInfo[period].secondsDebtX96 + secondsDebtDeltaX96
                : self.periodRewardInfo[period].secondsDebtX96 - secondsDebtDeltaX96; // can't overflow since each period is way less than uint31
        }
    }

    /// @notice Initializes secondsPerLiquidityPeriodStartX128 for a position
    /// @param position The individual position
    /// @param secondsInRangeParams Parameters used to find the seconds in range
    /// @param secondsPerLiquidityPeriodX128 The seconds in range gained per unit of liquidity, inside the position's tick boundaries for this period
    function initializeSecondsStart(
        PositionInfo storage position,
        PositionPeriodSecondsInRangeParams memory secondsInRangeParams,
        uint160 secondsPerLiquidityPeriodX128
    ) internal {
        // record initialized
        position.periodRewardInfo[secondsInRangeParams.period].initialized = true;

        // record owed tokens if liquidity > 0 (means position existed before period change)
        if (position.liquidity > 0) {
            uint256 periodSecondsInsideX96 = positionPeriodSecondsInRange(secondsInRangeParams);

            position.periodRewardInfo[secondsInRangeParams.period].secondsDebtX96 = -int256(periodSecondsInsideX96);
        }

        // convert uint to int
        // negative expected sometimes, which is allowed
        int160 secondsPerLiquidityPeriodIntX128 = int160(secondsPerLiquidityPeriodX128);

        position
            .periodRewardInfo[secondsInRangeParams.period]
            .secondsPerLiquidityPeriodStartX128 = secondsPerLiquidityPeriodIntX128;
    }

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        uint256 index;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    /// @dev Effect some changes to a position
    /// @param params the position details and the change to the position's liquidity to effect
    /// @return position a storage pointer referencing the position with the given owner and tick range
    /// @return amount0 the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount1 the amount of token1 owed to the pool, negative if the pool should pay the recipient
    function _modifyPosition(
        ModifyPositionParams memory params
    ) external returns (PositionInfo storage position, int256 amount0, int256 amount1) {
        States.PoolStates storage states = States.getStorage();

        // check ticks
        require(params.tickLower < params.tickUpper, 'TLU');
        require(params.tickLower >= TickMath.MIN_TICK, 'TLM');
        require(params.tickUpper <= TickMath.MAX_TICK, 'TUM');

        Slot0 memory _slot0 = states.slot0; // SLOAD for gas optimization

        position = _updatePosition(
            UpdatePositionParams({
                owner: params.owner,
                index: params.index,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: params.liquidityDelta,
                tick: _slot0.tick
            })
        );

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                uint128 liquidityBefore = states.liquidity; // SLOAD for gas optimization

                // write an oracle entry
                (states.slot0.observationIndex, states.slot0.observationCardinality) = Oracle.write(
                    states.observations,
                    _slot0.observationIndex,
                    States._blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                states.liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    struct UpdatePositionParams {
        // the owner of the position
        address owner;
        // the index of the position
        uint256 index;
        // the lower tick of the position's tick range
        int24 tickLower;
        // the upper tick of the position's tick range
        int24 tickUpper;
        // the amount liquidity changes by
        int128 liquidityDelta;
        // the current tick, passed to avoid sloads
        int24 tick;
    }

    struct UpdatePositionCache {
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool flippedUpper;
        bool flippedLower;
        uint256 feeGrowthInside0X128;
        uint256 feeGrowthInside1X128;
    }

    struct ObservationCache {
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
    }

    /// @dev Gets and updates a position with the given liquidity delta
    /// @param params the position details and the change to the position's liquidity to effect
    function _updatePosition(UpdatePositionParams memory params) private returns (PositionInfo storage position) {
        States.PoolStates storage states = States.getStorage();

        uint256 period = States._blockTimestamp() / 1 weeks;

        bytes32 _positionHash = positionHash(params.owner, params.index, params.tickLower, params.tickUpper);
        position = states.positions[_positionHash];

        UpdatePositionCache memory cache;

        cache.feeGrowthGlobal0X128 = states.feeGrowthGlobal0X128; // SLOAD for gas optimization
        cache.feeGrowthGlobal1X128 = states.feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        if (params.liquidityDelta != 0) {
            uint32 time = States._blockTimestamp();
            ObservationCache memory observationCache;
            (observationCache.tickCumulative, observationCache.secondsPerLiquidityCumulativeX128) = Oracle
                .observeSingle(
                    states.observations,
                    time,
                    0,
                    states.slot0.tick,
                    states.slot0.observationIndex,
                    states.liquidity,
                    states.slot0.observationCardinality
                );

            cache.flippedLower = Tick.update(
                states._ticks,
                Tick.UpdateTickParams(
                    params.tickLower,
                    params.tick,
                    params.liquidityDelta,
                    cache.feeGrowthGlobal0X128,
                    cache.feeGrowthGlobal1X128,
                    observationCache.secondsPerLiquidityCumulativeX128,
                    observationCache.tickCumulative,
                    time,
                    false,
                    states.maxLiquidityPerTick
                )
            );
            cache.flippedUpper = Tick.update(
                states._ticks,
                Tick.UpdateTickParams(
                    params.tickUpper,
                    params.tick,
                    params.liquidityDelta,
                    cache.feeGrowthGlobal0X128,
                    cache.feeGrowthGlobal1X128,
                    observationCache.secondsPerLiquidityCumulativeX128,
                    observationCache.tickCumulative,
                    time,
                    true,
                    states.maxLiquidityPerTick
                )
            );

            if (cache.flippedLower) {
                TickBitmap.flipTick(states.tickBitmap, params.tickLower, states.tickSpacing);
            }
            if (cache.flippedUpper) {
                TickBitmap.flipTick(states.tickBitmap, params.tickUpper, states.tickSpacing);
            }
        }

        (cache.feeGrowthInside0X128, cache.feeGrowthInside1X128) = Tick.getFeeGrowthInside(
            states._ticks,
            params.tickLower,
            params.tickUpper,
            params.tick,
            cache.feeGrowthGlobal0X128,
            cache.feeGrowthGlobal1X128
        );

        {
            uint160 secondsPerLiquidityPeriodX128 = Oracle.periodCumulativesInside(
                uint32(period),
                params.tickLower,
                params.tickUpper
            );

            if (!position.periodRewardInfo[period].initialized) {
                initializeSecondsStart(
                    position,
                    PositionPeriodSecondsInRangeParams({
                        period: period,
                        owner: params.owner,
                        index: params.index,
                        tickLower: params.tickLower,
                        tickUpper: params.tickUpper
                    }),
                    secondsPerLiquidityPeriodX128
                );
            }

            _updatePositionLiquidity(
                position,
                states,
                period,
                _positionHash,
                params.liquidityDelta,
                cache.feeGrowthInside0X128,
                cache.feeGrowthInside1X128,
                secondsPerLiquidityPeriodX128
            );
            /*
            _updateBoostedPosition(
                boostedPosition,
                params.liquidityDelta,
                boostedLiquidityDelta,
                secondsPerLiquidityPeriodX128,
                secondsPerBoostedLiquidityPeriodX128
            );
            */
        }

        // clear any tick data that is no longer needed
        if (params.liquidityDelta < 0) {
            if (cache.flippedLower) {
                Tick.clear(states._ticks, params.tickLower);
            }
            if (cache.flippedUpper) {
                Tick.clear(states._ticks, params.tickUpper);
            }
        }
    }

    /// @notice gets the checkpoint directly before the period
    /// @dev returns the 0th index if there's no checkpoints
    /// @param checkpoints the position's checkpoints in storage
    /// @param period the period of interest
    function getCheckpoint(
        PositionCheckpoint[] storage checkpoints,
        uint256 period
    ) internal view returns (uint256 checkpointIndex, uint256 checkpointPeriod) {
        {
            uint256 checkpointLength = checkpoints.length;

            // return 0 if length is 0
            if (checkpointLength == 0) {
                return (0, 0);
            }

            checkpointPeriod = checkpoints[0].period;

            // return 0 if first checkpoint happened after period
            if (checkpointPeriod > period) {
                return (0, 0);
            }

            checkpointIndex = checkpointLength - 1;
        }

        checkpointPeriod = checkpoints[checkpointIndex].period;

        // Find relevant checkpoint if latest checkpoint isn't before period of interest
        if (checkpointPeriod > period) {
            uint256 lower = 0;
            uint256 upper = checkpointIndex;

            while (upper > lower) {
                uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
                checkpointPeriod = checkpoints[center].period;
                if (checkpointPeriod == period) {
                    checkpointIndex = center;
                    return (checkpointIndex, checkpointPeriod);
                } else if (checkpointPeriod < period) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }
            checkpointIndex = lower;
            checkpointPeriod = checkpoints[checkpointIndex].period;
        }

        return (checkpointIndex, checkpointPeriod);
    }

    struct PositionPeriodSecondsInRangeParams {
        uint256 period;
        address owner;
        uint256 index;
        int24 tickLower;
        int24 tickUpper;
    }

    // Get the period seconds in range of a specific position
    /// @return periodSecondsInsideX96 seconds the position was not in range for the period
    function positionPeriodSecondsInRange(
        PositionPeriodSecondsInRangeParams memory params
    ) public view returns (uint256 periodSecondsInsideX96) {
        States.PoolStates storage states = States.getStorage();

        {
            uint256 currentPeriod = states.lastPeriod;
            require(params.period <= currentPeriod, 'FTR'); // Future period, or current period hasn't been updated
        }

        bytes32 _positionHash = positionHash(params.owner, params.index, params.tickLower, params.tickUpper);

        uint256 liquidity;
        int160 secondsPerLiquidityPeriodStartX128;

        {
            PositionCheckpoint[] storage checkpoints = states.positionCheckpoints[_positionHash];

            // get checkpoint at period, or last checkpoint before the period
            (uint256 checkpointIndex, uint256 checkpointPeriod) = getCheckpoint(checkpoints, params.period);

            // Return 0s if checkpointPeriod is 0
            if (checkpointPeriod == 0) {
                return 0;
            }

            liquidity = checkpoints[checkpointIndex].liquidity;

            secondsPerLiquidityPeriodStartX128 = states
                .positions[_positionHash]
                .periodRewardInfo[params.period]
                .secondsPerLiquidityPeriodStartX128;
        }

        uint160 secondsPerLiquidityInsideX128 = Oracle.periodCumulativesInside(
            uint32(params.period),
            params.tickLower,
            params.tickUpper
        );

        // underflow will be protected by sanity check
        secondsPerLiquidityInsideX128 = uint160(
            int160(secondsPerLiquidityInsideX128) - secondsPerLiquidityPeriodStartX128
        );

        RewardInfo storage rewardInfo = states.positions[_positionHash].periodRewardInfo[params.period];
        int256 secondsDebtX96 = rewardInfo.secondsDebtX96;

        // addDelta checks for under and overflows
        periodSecondsInsideX96 = FullMath.mulDiv(liquidity, secondsPerLiquidityInsideX128, FixedPoint32.Q32);

        // Need to check if secondsDebtX96>periodSecondsInsideX96, since rounding can cause underflows
        if (secondsDebtX96 < 0 || periodSecondsInsideX96 > uint256(secondsDebtX96)) {
            periodSecondsInsideX96 = LiquidityMath.addDelta256(periodSecondsInsideX96, -secondsDebtX96);
        } else {
            periodSecondsInsideX96 = 0;
        }

        // sanity
        if (periodSecondsInsideX96 > 1 weeks * FixedPoint96.Q96) {
            periodSecondsInsideX96 = 0;
        }
    }
}
