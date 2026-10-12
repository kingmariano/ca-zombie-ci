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

contract MessageQueueEncoder {
    /*************************
     * Public View Functions *
     *************************/

    /// @notice Encode l1->l2 deposit message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 0 for deposit (1 byte)
    ///     - user address to deposit (20 bytes)
    ///     - asset id (4 bytes)
    ///     - deposit asset amount (16 bytes)
    function encodeDepositMessage(
        bytes32 prevMessageQueueHash,
        address userAddress,
        uint32 assetId,
        uint128 depositAmount
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = abi.encodePacked(prevMessageQueueHash, bytes1(0), userAddress, assetId, depositAmount);
        return message;
    }

    function decodeDepositMessage(bytes calldata message)
        public
        pure
        returns (bytes32 prevMessageQueueHash, address userAddress, uint32 assetId, uint128 depositAmount)
    {
        require(message.length == 73, "MessageQueue: deposit message length must be 73");
        require(message[32] == 0, "MessageQueue: deposit message invalid type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            userAddress := shr(96, calldataload(add(message.offset, 33))) // mask last 12 bytes
            assetId := shr(224, calldataload(add(message.offset, 53))) // mask last 28 bytes
            depositAmount := shr(128, calldataload(add(message.offset, 57))) // mask last 16 bytes
        }
    }
    
    /// @notice Encode l1->l2 register message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 1 for register (1 byte)
    ///     - user address (20 bytes)
    ///     - user vessel public key (64 bytes)
    function encodeRegisterMessage(
        bytes32 prevMessageQueueHash,
        address userAddress,
        bytes calldata vesselPubKey
    )
        public
        pure
        returns (bytes memory)
    {
        require(vesselPubKey.length == 64, "MessageQueue: vessel key length must be 64");
        bytes memory message = abi.encodePacked(prevMessageQueueHash, bytes1(uint8(1)), userAddress, vesselPubKey);
        return message;
    }

    function decodeRegisterMessage(bytes calldata message)
        public
        pure
        returns (bytes32 prevMessageQueueHash, address userAddress, bytes memory vesselPubKey)
    {
        require(message.length == 117, "MessageQueue: register message length must be 117");
        require(message[32] == bytes1(uint8(1)), "MessageQueue: register message incorrect type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            userAddress := shr(96, calldataload(add(message.offset, 33))) // mask last 12 bytes
            let vesselPubKeyPart1 := calldataload(add(message.offset, 53))
            let vesselPubKeyPart2 := calldataload(add(message.offset, 85))
            vesselPubKey := mload(0x40) // allocate free memory
            mstore(vesselPubKey, 64)
            mstore(add(vesselPubKey, 32), vesselPubKeyPart1)
            mstore(add(vesselPubKey, 64), vesselPubKeyPart2)
            mstore(0x40, add(vesselPubKey, 96)) // move free memory pointer
        }
    }

    /// @notice Encode l1->l2 fast-withdraw message by concatenating following:
    ///     - previous l1->l2 message queue hash (32 bytes)
    ///     - message type: 2 for fast-withdraw (1 byte)
    ///     - liqudity provider address (20 bytes)
    ///     - recipient address (20 bytes)
    ///     - asset id (4 bytes)
    ///     - withdraw amount (16 bytes)
    ///     - nonce (32 bytes)    
    function encodeFastWithdrawL1Message(
        bytes32 prevMessageQueueHash,
        address lpAddr,
        address recipientAddr,
        uint32 assetId,
        uint128 assetAmount,
        uint256 nonce
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = abi.encodePacked(
            prevMessageQueueHash,
            bytes1(uint8(2)),
            lpAddr,
            recipientAddr,
            assetId,
            assetAmount,
            nonce
        );
        return message;
    }

    function decodeFastWithdrawL1Message(bytes calldata message)
        public
        pure
        returns (
            bytes32 prevMessageQueueHash,
            address lpAddr,
            address recipientAddr,
            uint32 assetId,
            uint128 assetAmount,
            uint256 nonce
        )
    {
        require(message.length == 125, "MessageQueue: fastWithdrawL1 message length must be 125");
        require(message[32] == bytes1(uint8(2)), "MessageQueue: fastWithdrawL1 message invalid type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            lpAddr := shr(96, calldataload(add(message.offset, 33))) // mask last 12 bytes
            recipientAddr := shr(96, calldataload(add(message.offset, 53))) // mask last 12 bytes
            assetId := shr(224, calldataload(add(message.offset, 73))) // mask last 28 bytes
            assetAmount := shr(128, calldataload(add(message.offset, 77))) // mask last 16 bytes
            nonce := calldataload(add(message.offset, 93)) // mask last 16 bytes
        }
    }

    /// @notice Encode l2->l1 withdraw message by concatenating following:
    ///     - previous l2->l1 message queue hash (32 bytes)
    ///     - message type: 0 for withdraw (1 byte)
    ///     - user address to withdraw (20 bytes)
    ///     - withdraw asset id (4 bytes)
    ///     - withdraw asset amount (16 bytes)
    function encodeWithdrawMessage(
        bytes32 prevMessageQueueHash,
        address userAddress,
        uint32 assetId,
        uint128 assetAmount
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = abi.encodePacked(prevMessageQueueHash, bytes1(0), userAddress, assetId, assetAmount);
        return message;
    }

    function decodeWithdrawMessage(bytes calldata message)
        public
        pure
        returns (bytes32 prevMessageQueueHash, address userAddress, uint32 assetId, uint128 assetAmount)
    {
        require(message.length == 73, "MessageQueue: withdraw message length must be 73");
        require(message[32] == 0, "MessageQueue: withdraw message invalid type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            userAddress := shr(96, calldataload(add(message.offset, 33))) // mask last 12 bytes
            assetId := shr(224, calldataload(add(message.offset, 53))) // mask last 28 bytes
            assetAmount := shr(128, calldataload(add(message.offset, 57))) // mask last 16 bytes
        }
    }

    function encodeAmmPoolCreateMessage(
        bytes32 prevMessageQueueHash,
        uint32 poolId,
        uint32 baseAssetId,
        uint32 quoteAssetId,
        uint128 minPrice,
        uint128 priceDelta,
        uint64 totalTicks,
        uint64 curTickIndex
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = abi.encodePacked(
            prevMessageQueueHash,
            bytes1(uint8(1)),
            poolId,
            baseAssetId,
            quoteAssetId,
            minPrice,
            priceDelta,
            totalTicks,
            curTickIndex
        );
        return message;
    }

    function decodeAmmPoolCreateMessage(bytes calldata message)
        public
        pure
        returns (
            bytes32 prevMessageQueueHash,
            uint32 poolId,
            uint32 baseAssetId,
            uint32 quoteAssetId,
            uint128 minPrice,
            uint128 priceDelta,
            uint64 totalTicks,
            uint64 curTickIndex
        )
    {
        require(message.length == 93, "MessageQueue: AMM pool create message length must be 93");
        require(message[32] == bytes1(uint8(1)), "MessageQueue: AMM pool create message invalid type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            poolId := shr(224, calldataload(add(message.offset, 33))) // mask last 28 bytes
            baseAssetId := shr(224, calldataload(add(message.offset, 37))) // mask last 28 bytes
            quoteAssetId := shr(224, calldataload(add(message.offset, 41))) // mask last 28 bytes
            minPrice := shr(128, calldataload(add(message.offset, 45))) // mask last 16 bytes
            priceDelta := shr(128, calldataload(add(message.offset, 61))) // mask last 16 bytes
            totalTicks := shr(192, calldataload(add(message.offset, 77))) // mask last 24 bytes
            curTickIndex := shr(192, calldataload(add(message.offset, 85))) // mask last 24 bytes
        }
    }

    /// @notice Encode l2->l1 fast-withdraw message by concatenating following:
    ///     - previous l2->l1 message queue hash (32 bytes)
    ///     - message type: 2 for fast-withdraw (1 byte)
    ///     - liquidity provider address to backfill (20 bytes)
    ///     - backfill asset id (4 bytes)
    ///     - backfill asset amount (16 bytes)
    function encodeFastWithdrawL2Message(
        bytes32 prevMessageQueueHash,
        address lpAddr,
        uint32 assetId,
        uint128 backfillAmount
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = abi.encodePacked(
            prevMessageQueueHash,
            bytes1(uint8(2)),
            lpAddr,
            assetId,
            backfillAmount
        );
        return message;
    }

    function decodeFastWithdrawL2Message(bytes calldata message)
        public
        pure
        returns (bytes32 prevMessageQueueHash, address lpAddr, uint32 assetId, uint128 backfillAmount)
    {
        require(message.length == 73, "MessageQueue: fastWithdrawL2 message length must be 73");
        require(message[32] == bytes1(uint8(2)), "MessageQueue: fastWithdrawL2 message invalid type");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            prevMessageQueueHash := calldataload(message.offset)
            lpAddr := shr(96, calldataload(add(message.offset, 33))) // mask last 12 bytes
            assetId := shr(224, calldataload(add(message.offset, 53))) // mask last 28 bytes
            backfillAmount := shr(128, calldataload(add(message.offset, 57))) // mask last 16 bytes
        }
    }
}