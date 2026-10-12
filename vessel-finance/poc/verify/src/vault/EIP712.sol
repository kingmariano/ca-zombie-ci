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

import { StorageV2 } from "./StorageV2.sol";

/// @title EIP712
/// @notice Contains all of the order hashing functions for EIP712 compliant signatures
contract EIP712 is StorageV2 {
    /***********
     * Structs *
     ***********/

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    /*************
     * Constants *
     *************/

    /// @dev typehash for EIP 712 compatibility.
    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant USER_BINDING_TYPEHASH = keccak256("UserBinding(bytes pubKey,address addr)");

    // solhint-disable-next-line max-line-length
    bytes32 public constant FAST_WITHDRAW_TYPEHASH = keccak256("FastWithdraw(string action,address recipientAddress,address assetAddress,uint256 assetAmount,uint256 feeAmount,uint256 nonce,uint256 expireTimestampSec)");

    string public constant FAST_WITHDRAW_ACTION = "FAST_WITHDRAW";

    /**********************
     * Internal Functions *
     **********************/

    /// @dev hash implementation
    function _hashDomain(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function _digestUserBinding(bytes calldata pubKey, address addr) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", domainSeparator, keccak256(abi.encode(USER_BINDING_TYPEHASH, keccak256(pubKey), addr))
            )
        );
    }

    function _digestFastWithdraw(
        address lpAddr,
        address assetAddr,
        uint256 assetAmount,
        uint256 feeAmount,
        uint256 nonce,
        uint256 expireTimestampSec
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(
                    FAST_WITHDRAW_TYPEHASH,
                    keccak256(bytes(FAST_WITHDRAW_ACTION)),
                    lpAddr,
                    assetAddr,
                    assetAmount,
                    feeAmount,
                    nonce,
                    expireTimestampSec
                ))
            )
        );
    }

    /// @dev Verify ECDSA signature.
    function _verifyECDSA(address signer, bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (bool) {
        require(v == 27 || v == 28, "Users: Invalid v parameter");
        address recoveredSigner = ecrecover(digest, v, r, s);
        if (recoveredSigner == address(0)) {
            return false;
        } else {
            return signer == recoveredSigner;
        }
    }
}
