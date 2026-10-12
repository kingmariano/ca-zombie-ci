/*
Copyright 2024 Vessel Team.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import { TokenManager } from "./TokenManager.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";
import { WETH } from "lib/solmate/src/tokens/WETH.sol";

/// @notice Implements various transferIn and transferOut functionalities.
abstract contract TokenTransfers is TokenManager {
    using Address for address payable;
    using SafeERC20 for IERC20;

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Transfers funds from msg.sender to the exchange. Refund extra native tokens sent to vault.
    function transferIn(uint256 assetId, uint256 amount) internal {
        if (isERC20(assetId)) {
            if (amount == 0) return;
            address tokenAddress = assetIdToInfo[assetId].assetAddress;
            IERC20 token = IERC20(tokenAddress);
            uint256 exchangeBalanceBefore = token.balanceOf(address(this));
            token.safeTransferFrom(msg.sender, address(this), amount);
            uint256 exchangeBalanceAfter = token.balanceOf(address(this));
            require(exchangeBalanceAfter >= exchangeBalanceBefore, "OVERFLOW");
            require(exchangeBalanceAfter == exchangeBalanceBefore + amount, "INCORRECT_AMOUNT_TRANSFERRED");
        } else if (isNative(assetId)) {
            require(msg.value >= amount, "INCORRECT_DEPOSIT_AMOUNT");
            uint256 refundAmount = msg.value - amount;
            if (refundAmount > 0) {
                Address.sendValue(payable(msg.sender), refundAmount);
            }
        } else {
            revert("UNSUPPORTED_TOKEN_TYPE");
        }
    }

    /// @dev Transfers funds from the exchange to recipient.
    function transferOut(address payable recipient, uint256 assetId, uint256 amount) internal {
        // Make sure we don't accidentally burn funds.
        require(recipient != address(0x0), "INVALID_RECIPIENT");
        if (isERC20(assetId)) {
            if (amount == 0) return;
            address tokenAddress = assetIdToInfo[assetId].assetAddress;
            IERC20 token = IERC20(tokenAddress);
            uint256 exchangeBalanceBefore = token.balanceOf(address(this));
            token.safeTransfer(recipient, amount);
            uint256 exchangeBalanceAfter = token.balanceOf(address(this));
            require(exchangeBalanceAfter <= exchangeBalanceBefore, "UNDERFLOW");
            require(exchangeBalanceAfter == exchangeBalanceBefore - amount, "INCORRECT_AMOUNT_TRANSFERRED");
        } else if (isNative(assetId)) {
            if (amount == 0) return;
            Address.sendValue(recipient, amount);
        } else {
            revert("UNSUPPORTED_TOKEN_TYPE");
        }
    }

    /// @dev Transfers funds from the exit LP to recipient.
    function transferOutFromExitLp(address lp, address payable recipient, uint256 assetId, uint256 amount) internal {
        require(recipient != address(0x0), "TokenTransfer: invalid recipient");
        if (isERC20(assetId)) {
            if (amount == 0) return;
            address tokenAddress = assetIdToInfo[assetId].assetAddress;
            IERC20 token = IERC20(tokenAddress);
            token.safeTransferFrom(lp, recipient, amount);
        } else if (isNative(assetId)) {
            // transfer WETH from lp to vault -> unwrap WETH -> transfer ETH from vault to recipient
            if (amount == 0) return;
            uint256 exchangeBalanceBefore = address(this).balance;

            IERC20(wethAddress).safeTransferFrom(lp, address(this), amount);
            WETH(payable(wethAddress)).withdraw(amount);
            Address.sendValue(recipient, amount);

            uint256 exchangeBalanceAfter = address(this).balance;
            require(exchangeBalanceAfter == exchangeBalanceBefore, "TokenTransfer: vault balance changed");
        } else {
            revert("TokenTransfer: unsupported asset type");
        }
    }

    /// @dev Backfill funds from vault to exitLP.
    function backfillToExitLp(address payable lp, uint256 assetId, uint256 amount) internal {
        require(lp != address(0x0), "TokenTransfer: invalid recipient");
        if (isERC20(assetId)) {
            transferOut(lp, assetId, amount);
        } else if (isNative(assetId)) {
            if (amount == 0) return;
            uint256 exchangeBalanceBefore = address(this).balance;
            uint256 lpBalanceBefore = WETH(payable(wethAddress)).balanceOf(lp);

            WETH(payable(wethAddress)).deposit{value: amount}();
            IERC20(wethAddress).safeTransfer(lp, amount);

            uint256 exchangeBalanceAfter = address(this).balance;
            uint256 lpBalanceAfter = WETH(payable(wethAddress)).balanceOf(lp);
            require(exchangeBalanceAfter == exchangeBalanceBefore - amount, "TokenTransfer: exchange balance abnormal");
            require(lpBalanceAfter == lpBalanceBefore + amount, "TokenTransfer: lp balance abnormal change");
        } else {
            revert("TokenTransfer: unsupported asset type");
        }
    }
}
