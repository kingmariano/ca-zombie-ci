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
import { StorageV2 } from "./StorageV2.sol";
import { MessageQueue } from "./MessageQueue.sol";

contract Users is StorageV2, EIP712, MessageQueue {
    /**********
     * Events *
     **********/

    event LogVesselKeyRegister(address userAddress, bytes vesselKey);

    /**********************
     * Function Modifiers *
     **********************/

    /// @dev Throws if vesselKey is not registered to given address.
    modifier validVesselKeyToAddress(bytes calldata vesselKey, address addr) {
        require(vesselKeyToUserAddress[vesselKey] == addr, "Users: vesselKey not registered to user address");
        _;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @notice Check whether <vesselKey, address> mapping is signed by operator.
    ///     If signature is valid, register user and add to L1->L2 message queue.
    function checkAndRegisterUser(
        bytes calldata vesselKey,
        address operatorAddr,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    )
        public
    {
        require(vesselKey.length == 64, "Users: invalid vessel key length");
        address oldAddress = vesselKeyToUserAddress[vesselKey];
        if (oldAddress == address(0)) {
            // verify signature
            require(operators[operatorAddr], "Users: invalid operator address");
            bytes32 digest = _digestUserBinding(vesselKey, msg.sender);
            require(_verifyECDSA(operatorAddr, digest, sigV, sigR, sigS), "Users: invalid operator signature");
            // register vessel key to address
            _registerVesselKey(vesselKey, msg.sender);
        } else {
            require(oldAddress == msg.sender, "Users: vessel key registration conflicts");
        }
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Register vesselKey to userAddress, adding add message to l1->l2 queue.
    function _registerVesselKey(bytes calldata vesselKey, address userAddress) internal {
        vesselKeyToUserAddress[vesselKey] = userAddress;
        pushL1ToL2RegisterMessage(userAddress, vesselKey);
        emit LogVesselKeyRegister(userAddress, vesselKey);
    }
}
