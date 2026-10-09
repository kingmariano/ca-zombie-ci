// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library LibFeeHelper {
    function getTpSlExecutionFee(uint tp, uint sl, uint minExecutionFee) internal pure returns (uint) {
        uint tpSlExecutionFee = 0;
        if (tp > 0) {
            unchecked {
                tpSlExecutionFee += minExecutionFee;
            }
        }
        if (sl > 0) {
            unchecked {
                tpSlExecutionFee += minExecutionFee;
            }
        }
        return tpSlExecutionFee;
    }

    function splitTpSlExecutionFee(uint tp, uint sl, uint tpSlExecutionFee) internal pure returns (uint, uint) {
        if (tp != 0 && sl != 0) {
            return (tpSlExecutionFee / 2, tpSlExecutionFee / 2);
        } else if (tp != 0) {
            return (tpSlExecutionFee, 0);
        } else {
            return (0, tpSlExecutionFee);
        }
    }

    // when users change tp or sl, we need to adjust the execution fee
    // when users change tp or sl from 0 to non-zero, they should pay minExecutionFee for each of them
    // when users change tp or sl from non-zero to 0, they should get refund for each of them
    // If the final result is negative, it means the user should get refund
    // If the final result is positive, it means the user should pay more fee
    function quoteExecutionFeeAdjustment(uint oldTp, uint oldSl, uint tpSlExecutionFee, uint newTp, uint newSl, uint minExecutionFee) internal pure returns (int) {
        int executionFeeAdjustment = 0;
        (uint oldTpExecutionFee, uint oldSlExecutionFee) = splitTpSlExecutionFee(oldTp, oldSl, tpSlExecutionFee);
        if (oldTp == 0 && newTp > 0) {
            unchecked {
                executionFeeAdjustment += int(minExecutionFee);
            }
        } else if (oldTp > 0 && newTp == 0) {
            unchecked {
                executionFeeAdjustment -= int(oldTpExecutionFee);
            }
        }

        if (oldSl == 0 && newSl > 0) {
            unchecked {
                executionFeeAdjustment += int(minExecutionFee);
            }
        } else if (oldSl > 0 && newSl == 0) {
            unchecked {
                executionFeeAdjustment -= int(oldSlExecutionFee);
            }
        }

        return executionFeeAdjustment;
    }
}
