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

import { Governance } from "./Governance.sol";
import { StorageV2 } from "./StorageV2.sol";
import { MessageQueueEncoder } from "../affiliate/MessageQueueEncoder.sol";

contract MessageQueue is StorageV2, Governance {
    /**********
     * Events *
     **********/

    event LogL1ToL2MessageQueueRegister(address userAddress, bytes vesselKey, bytes32 newHash);
    event LogL1ToL2MessageQueueDeposit(address userAddress, uint256 assetId, uint256 amount, bytes32 newHash);
    // solhint-disable-next-line max-line-length
    event LogL1ToL2MessageQueueFastWithdraw(address lpAddr, address recipientAddr, uint256 assetId, uint256 assetAmount, uint256 nonce, bytes32 newHash);
    event LogL1ToL2MessageQueueUpdate(uint256 newIndex);
    event LogL2ToL1MessageQueueUpdate(bytes32 newHash);
    event LogMessageQueueEncoderAddressSet(address encoderAddr);

    /***************
     * Constructor *
     ***************/

    function initMessageQueue() public initializer {
        l1ToL2MessageQueueTailIndex = 0;
        l1ToL2MessageQueueCommitIndex = 0;
        l2ToL1MessageQueueCommitHash = 0;
    }

    function setMessageQueueEncoder(address encoderAddr) external onlyAdmin {
        mqEncoder = MessageQueueEncoder(encoderAddr);
        emit LogMessageQueueEncoderAddressSet(encoderAddr);
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice returns last committed message hash and index of l1->l2 message queue.
    function getL1ToL2MessageQueueCommitIndex() public view returns (uint256) {
        return l1ToL2MessageQueueCommitIndex;
    }

    /// @notice returns tail message hash and index of l1->l2 message queue.
    function getL1ToL2MessageQueueTailIndex() public view returns (uint256) {
        return l1ToL2MessageQueueTailIndex;
    }

    /// @notice returns raw message by given index of l1->l2 message queue.
    function getL1ToL2MessageQueueHashAt(uint256 index) public view returns (bytes32) {
        return l1ToL2MessageQueueHash[index];
    }

    /// @notice returns last committed message hash of l2->l1 message queue.
    function getL2ToL1MessageQueueCommitHash() public view returns (bytes32) {
        return l2ToL1MessageQueueCommitHash;
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Update l1->l2 message queue with new index.
    /// Caller is responsible to perform relative checkes and make sure this update is legal.
    function updateL1ToL2MessageQueue(uint256 newIndex) internal {
        l1ToL2MessageQueueCommitIndex = newIndex;
        emit LogL1ToL2MessageQueueUpdate(newIndex);
    }

    /// @dev Add new register message to l1->l2 message queue.
    function pushL1ToL2RegisterMessage(address userAddress, bytes calldata vesselKey) internal {
        bytes32 prevHash = l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex];
        bytes memory newMessage = mqEncoder.encodeRegisterMessage(prevHash, userAddress, vesselKey);
        bytes32 newHash = keccak256(newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = newHash;
        emit LogL1ToL2MessageQueueRegister(userAddress, vesselKey, newHash);
    }

    /// @dev Add new deposit message to l1->l2 message queue.
    function pushL1ToL2DepositMessage(address userAddress, uint32 assetId, uint128 amount) internal {
        bytes32 prevHash = l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex];
        bytes memory newMessage = mqEncoder.encodeDepositMessage(prevHash, userAddress, assetId, amount);
        bytes32 newHash = keccak256(newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = newHash;
        emit LogL1ToL2MessageQueueDeposit(userAddress, assetId, amount, newHash);
    }

    /// @dev Add new fast-withdraw l1 message to l1->l2 message queue
    function pushL1ToL2FastWithdrawMessage(
        address lpAddr,
        address recipientAddr,
        uint32 assetId,
        uint128 assetAmount,
        uint256 nonce
    ) internal {
        bytes32 prevHash = l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex];
        bytes memory newMessage = mqEncoder.encodeFastWithdrawL1Message(
            prevHash,
            lpAddr,
            recipientAddr,
            assetId,
            assetAmount,
            nonce
        );
        bytes32 newHash = keccak256(newMessage);
        l1ToL2MessageQueueTailIndex++;
        l1ToL2MessageQueueHash[l1ToL2MessageQueueTailIndex] = newHash;
        emit LogL1ToL2MessageQueueFastWithdraw(lpAddr, recipientAddr, assetId, assetAmount, nonce, newHash);
    }

    /// @dev Update l2->l1 message queue with new hash. Messages are not stored in contract.
    /// Caller is responsible to perform relative checkes and make sure this update is legal.
    function updateL2ToL1MessageQueue(bytes32 newHash) internal {
        l2ToL1MessageQueueCommitHash = newHash;
        emit LogL2ToL1MessageQueueUpdate(newHash);
    }
}
