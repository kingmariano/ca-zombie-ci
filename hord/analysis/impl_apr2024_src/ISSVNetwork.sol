//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

interface ISSVNetwork {
    struct Cluster {
        uint32 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    function registerValidator(
        bytes calldata publicKey,
        uint64[] memory operatorIds,
        bytes calldata sharesEncrypted,
        uint256 amount,
        Cluster memory cluster
    ) external;

    function removeValidator(bytes calldata publicKey, uint64[] memory operatorIds, Cluster memory cluster) external;
}
