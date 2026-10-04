// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// Minimal Balancer V2 Math helpers used by StableMath.
library Math {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "ZERO_DIVISION");
        return a / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "ZERO_DIVISION");
        if (a == 0) {
            return 0;
        }
        return ((a - 1) / b) + 1;
    }
}
