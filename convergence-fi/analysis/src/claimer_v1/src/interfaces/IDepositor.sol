// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IDepositor {
    function deposit(uint256 amount, bool lock, bool stake, address user) external;
    function minter() external returns (address);
}
