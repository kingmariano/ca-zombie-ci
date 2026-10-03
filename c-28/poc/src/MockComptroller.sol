// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal malicious Comptroller used only on a fork to prove the drain path.
///         The real Moonwell Comptroller gates borrows in borrowAllowed(); replacing it
///         removes both the liquidity check and the guardian-pause checks.
contract MockComptroller {
    function isComptroller() external pure returns (bool) {
        return true;
    }

    function borrowAllowed(address, address, uint256) external pure returns (uint256) {
        return 0; // Error.NO_ERROR
    }

    function mintAllowed(address, address, uint256) external pure returns (uint256) {
        return 0;
    }

    function redeemAllowed(address, address, uint256) external pure returns (uint256) {
        return 0;
    }

    function repayBorrowAllowed(address, address, address, uint256) external pure returns (uint256) {
        return 0;
    }

    function liquidateBorrowAllowed(address, address, address, address, uint256) external pure returns (uint256) {
        return 0;
    }

    function seizeAllowed(address, address, address, address, uint256) external pure returns (uint256) {
        return 0;
    }

    function transferAllowed(address, address, address, uint256) external pure returns (uint256) {
        return 0;
    }
}
