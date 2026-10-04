// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// Minimal Balancer V2 FixedPoint (18-decimal fixed point) for PoC math only.
library FixedPoint {
    uint256 internal constant ONE = 1e18;

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / ONE;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        if (product == 0) {
            return 0;
        }
        return ((product - 1) / ONE) + 1;
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * ONE) / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        return ((a * ONE) - 1) / b + 1;
    }

    function complement(uint256 x) internal pure returns (uint256) {
        return ONE - x;
    }
}
