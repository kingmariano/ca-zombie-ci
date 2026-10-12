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

// solhint-disable-next-line max-states-count
contract StorageV1 {
    /*************
     * Variables *
     *************/

    /// @dev verifier config
    address internal snarkVerifier;
    string internal circuitVersion;

    /// @dev mpt state
    uint256 internal eternalTreeRoot;
    uint256 internal ephemeralTreeRoot;

    /// @dev message quue state
    mapping(uint256 index => bytes32 msgHash) internal l1ToL2MessageQueueHash;
    uint256 internal l1ToL2MessageQueueTailIndex;
    uint256 internal l1ToL2MessageQueueCommitIndex;
    bytes32 internal l2ToL1MessageQueueCommitHash;

    /// @dev governance storage
    address internal admin;
    mapping(address account => bool isOperator) internal operators;

    /// @dev asset registry
    struct AssetInfo {
        address assetAddress;
        uint8 limitDigit;
        uint8 precisionDigit;
        uint8 decimals;
        bool isActive;
    }

    mapping(address assetAddress => uint256 assetId) internal assetAddressToId;
    mapping(uint256 assetId => AssetInfo assetInfo) internal assetIdToInfo;

    /// @dev pending withdraw: a map for userAddress => assetId => amount
    mapping(address userAddress => mapping(uint256 assetId => uint256 amount)) internal pendingWithdraw;

    /// @dev users: a map for vesselKey => address to prevent key conflicts
    mapping(bytes vesselKey => address userAddress) internal vesselKeyToUserAddress;

    /// @dev used by EIP712 signature
    bytes32 public domainSeparator;

    /// @dev used by contract operator to check on-chain progress
    uint256 public lastCommitBatchId;
    uint256 public lastCommitEventId;
}
