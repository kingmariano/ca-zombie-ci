// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAdapter.sol";

/// @title BaseAdapter
/// @notice Abstract base for all protocol adapters with shared sweep helpers
abstract contract BaseAdapter is IAdapter {
    using SafeERC20 for IERC20;

    address public immutable router;

    error OnlyRouter();
    error ETHTransferFailed();

    modifier onlyRouter() {
        if (msg.sender != router) revert OnlyRouter();
        _;
    }

    constructor(address _router) {
        router = _router;
    }

    /// @notice Sweep ERC20 token balances to msg.sender (the Router)
    function _sweep(address[] calldata tokens) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
            if (bal > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, bal);
            }
        }
    }

    /// @notice Sweep any native ETH balance to msg.sender (the Router)
    function _sweepETH() internal {
        if (address(this).balance > 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            if (!success) revert ETHTransferFailed();
        }
    }
}
