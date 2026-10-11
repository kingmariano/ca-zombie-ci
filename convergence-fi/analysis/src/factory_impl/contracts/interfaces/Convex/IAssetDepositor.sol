// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetDepositor {
    function deposit(uint256 amount, bool isLock) external;
}
