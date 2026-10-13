// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
import './FullMath.sol';
import './SafeCast.sol';
import '@openzeppelin-3.4.2/contracts/math/Math.sol';

/// @title Math library for liquidity
library LiquidityMath {
    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }

    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addDelta256(uint256 x, int256 y) internal pure returns (uint256 z) {
        if (y < 0) {
            require((z = x - uint256(-y)) < x, 'LS');
        } else {
            require((z = x + uint256(y)) >= x, 'LA');
        }
    }

    function calculateBoostedLiquidity(
        uint128 liquidity,
        int128 veNftAmount,
        int128 totalVeNftAmount
    ) internal pure returns (uint256 veNftRatio, uint128 boostedLiquidity) {
        veNftRatio = FullMath.mulDiv(
            uint256(veNftAmount),
            1.5e18,
            totalVeNftAmount != 0 ? uint256(totalVeNftAmount) : 1
        );

        // users acheive full boost if their veRA is >=10% of the total veRA attached to the pool
        // full boost is 1x original + 1.5x boost
        //uint256 boostRatio = Math.min(veNftRatio * 10, 1.5e18); // veNftAmount and totalVeNftAmount can't go below 0
        uint256 boostRatio = 1.5e18;

        boostedLiquidity = SafeCast.toUint128(FullMath.mulDiv(liquidity, boostRatio, 1e18));
    }
}
