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

import { EIP712 } from "./EIP712.sol";
import { TokenTransfers } from "./TokenTransfer.sol";
import { MessageQueue } from "./MessageQueue.sol";
import { StorageV2 } from "./StorageV2.sol";

contract FastWithdrawManager is
    StorageV2,    
    EIP712,
    MessageQueue,
    TokenTransfers
{
    /************************
     * Restricted Functions *
     ************************/
    /// @notice Withdraw asset in an expeditious manner.
    ///     Only whitelisted exitLP can call this function.
    ///     Assets will be transfered from exitLP and not affect assets under the Vault.
    ///     Message queue will be updated to notify off-chain processor to refill the exitLP.
    function fastWithdraw(
        address lpAddr,
        address recipientAddr,
        address assetAddr,
        uint256 assetAmount,
        uint256 feeAmount,
        uint256 nonce,
        uint256 expireTimestampSec,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    )
        external
        nonReentrant
        onlyExitManager
    {
        // check asset id and active
        uint256 assetId = _checkAndExtractAssetId(assetAddr);

        // check expire timestamp
        require(block.timestamp <= expireTimestampSec, "Fast Withdraw: expired request");

        // check signature validity
        bytes32 digest = _digestFastWithdraw(
            recipientAddr,
            assetAddr,
            assetAmount,
            feeAmount,
            nonce,
            expireTimestampSec
        );
        require(_verifyECDSA(recipientAddr, digest, sigV, sigR, sigS), "Fast Withdraw: invalid user signature");

        // check and mark nonce usage
        require(!fastExitUserNonce[recipientAddr][nonce], "Fast Withdraw: user nonce already used");
        fastExitUserNonce[recipientAddr][nonce] = true;

        // check fee amount not eceeds total asset amount
        require(feeAmount <= assetAmount, "Fast Withdraw: fee amount must not exceeds total asset amount");

        // transfer assets from liquidity provider to recipient
        transferOutFromExitLp(lpAddr, payable(recipientAddr), assetId, assetAmount-feeAmount);

        // push to l1->l2 message queue
        pushL1ToL2FastWithdrawMessage(lpAddr, recipientAddr, uint32(assetId), uint128(assetAmount), nonce);
    }

    // Fallback function to receive ETH when unwrapping WETH
    receive() external payable {}
}
