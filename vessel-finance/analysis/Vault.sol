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
import { Users } from "./Users.sol";
import { TokenTransfers } from "./TokenTransfer.sol";
import { VerifierManager } from "./VerifierManager.sol";
import { FastWithdrawManager } from "./FastWithdrawManager.sol";

// solhint-disable-next-line max-line-length
contract Vault is
    StorageV2,
    Users,
    TokenTransfers,
    FastWithdrawManager,
    VerifierManager
{
    /**********
     * Events *
     **********/

    event LogDeposit(address userAddress, uint256 assetId, uint256 amount);
    event LogWithdraw(address userAddress, uint256 assetId, uint256 amount);
    event LogFastWithdrawBackfill(address lpAddress, uint256 assetId, uint256 amount);
    event LogNewPendingDepositAmount(address account, uint256 assetId, uint256 amount);
    event LogNewPendingWithdrawAmount(address account, uint256 assetId, uint256 amount);
    event LogProofCommitted(uint256 batchId, uint256 lastEventId);
    event LogAmmPoolCreated(
        uint32 poolId,
        uint32 baseAssetId,
        uint32 quoteAssetId,
        uint128 minPrice,
        uint128 priceDelta,
        uint64 totalTicks,
        uint64 curTickIndex
    );

    /*************
     * Constants *
     *************/
    string public constant NAME = "vessel";
    string public constant CONTRACT_VERSION = "1.0";

    /***************
     * Constructor *
     ***************/

    /// @dev Vault contract must be deployed with upgradeable proxy. Initialization from constructor is disabled.
    constructor() {
        _disableInitializers();
    }

    function initialize(address vaultAdmin) public initializer {
        initGovernance(vaultAdmin);
        initMessageQueue();
        initTokenManager();
        initVerifierManager();
        domainSeparator = _hashDomain(
            EIP712Domain({
                name: NAME,
                version: CONTRACT_VERSION,
                chainId: block.chainid,
                verifyingContract: address(this)
            })
        );
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Encode (uint256[], bytes) into calldata.
    function encodeVerifyData(
        uint256[] memory instances,
        bytes calldata proof
    )
        public
        pure
        returns (bytes memory encodedData)
    {
        bytes memory instancesData = abi.encodePacked(instances);
        encodedData = abi.encodePacked(instancesData, proof);
    }

    /// @notice Encode data and call verifier.
    function verifySnarkProof(
        uint256[] calldata instances,
        bytes calldata proof,
        address snarkVerifier
    )
        public
        view
        returns (bool)
    {
        bytes memory data = encodeVerifyData(instances, proof);
        bool success = false;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            success := staticcall(gas(), snarkVerifier, add(data, 0x20), mload(data), 0, 0)
        }
        return success;
    }

    /// @notice Get pending withdraw.
    function getPendingWithdraw(address account, uint256 assetId) public view returns (uint256 amount) {
        amount = pendingWithdraw[account][assetId];
    }

    /// @notice Get deposit verifier address.
    function getLastCommitBatchId() public view returns (uint256) {
        return lastCommitBatchId;
    }

    /// @notice Get deposit verifier address.
    function getLastCommitEventId() public view returns (uint256) {
        return lastCommitEventId;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @notice Check and register a user.
    ///     User registration is authorized by operator signature to avoid potential exploit like transaction front-run.
    function registerUser(bytes calldata vesselKey, address operator, uint8 sigV, bytes32 sigR, bytes32 sigS) public {
        checkAndRegisterUser(vesselKey, operator, sigV, sigR, sigS);
    }

    /// @notice Deposit ERC20.
    function depositERC20(uint256 assetId, uint256 amount, bytes calldata vesselKey) public nonReentrant {
        require(isERC20(assetId), "Vault: asset must be ERC20");
        _depositAsset(assetId, amount, vesselKey);
    }

    /// @notice Register and deposit ERC20.
    function registerAndDepositERC20(
        bytes calldata vesselKey,
        address operator,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint256 assetId,
        uint256 amount
    )
        external
    {
        registerUser(vesselKey, operator, sigV, sigR, sigS);
        depositERC20(assetId, amount, vesselKey);
    }

    /// @notice Deposit native asset.
    function depositNative(bytes calldata vesselKey) public payable nonReentrant {
        uint256 amount = msg.value;
        uint256 assetId = 0;
        _depositAsset(assetId, amount, vesselKey);
    }

    /// @notice Register and deposit native asset.
    function registerAndDepositNative(
        bytes calldata vesselKey,
        address operator,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    )
        external
        payable
    {
        registerUser(vesselKey, operator, sigV, sigR, sigS);
        depositNative(vesselKey);
    }

    /// @notice Withdraw balance.
    function withdraw(uint256 assetId, uint256 amount) public nonReentrant {
        uint256 balance = pendingWithdraw[msg.sender][assetId];
        require(balance >= amount, "Vault: not enough funds");
        _decreasePendingWithdraw(msg.sender, assetId, amount);
        transferOut(payable(msg.sender), assetId, amount);
        emit LogWithdraw(msg.sender, assetId, amount);
    }

    /// @notice Withdraw all.
    function withdrawAll(uint256 assetId) external nonReentrant {
        uint256 balance = pendingWithdraw[msg.sender][assetId];
        withdraw(assetId, balance);
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Only operator can commit SNARK proof to update on-chain state.
    /// @param instances: list of public instances to verify along with SNARK proof.
    ///     Encoding of instances must be consistent with circuit:
    ///     - 12 * aggregation circuit lhs & rhs values used by verifier
    ///     - state before:
    ///         - l1 to l2 message queue hash before
    ///         - l2 to l1 message queue hash before
    ///         - eternal mpt root before
    ///         - ephemeral mpt root before
    ///     - state after:
    ///         - l1 to l2 message queue hash after
    ///         - l2 to l1 message queue hash after
    ///         - eternal mpt root after
    ///         - ephemeral mpt root after
    /// @param proof: SNARK proof to commit
    /// @param l1ToL2MessageCnt: number of l1 to m2 message to be consumed in SNARK proof. This is used as an auxiliary
    ///     variable to help proof verification and on-chain state update, while not impacting proof soundness.
    /// @param l2ToL1Messages: preimages of l2 to l1 message. This is used as an auxiliary variable to help proof
    ///     verification and on-chain state update, while not impacting proof soundness.
    /// @param batchId: used to track the progress of SNARK proofs.
    /// @param lastEventId: used to track the progress of SNARK proofs.
    function commitSnarkProof(
        uint256[] calldata instances,
        bytes calldata proof,
        uint256 l1ToL2MessageCnt,
        bytes[] calldata l2ToL1Messages,
        uint256 batchId,
        uint256 lastEventId
    )
        external
        onlyOperator
    {
        _verifySnarkProofAndUpdateMerkleRoots(instances, proof);
        _verifyAndUpdateL1ToL2MessageQueue(instances[12], instances[16], l1ToL2MessageCnt);
        _verifyAndUpdateL2ToL1MessageQueue(instances[13], instances[17], l2ToL1Messages);
        _updateProofCommitmentMetadata(batchId, lastEventId);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Internal function for updating pending withdraw.
    function _increasePendingWithdraw(address account, uint256 assetId, uint256 amount) internal {
        uint256 beforePendingAmount = pendingWithdraw[account][assetId];
        unchecked {
            pendingWithdraw[account][assetId] += amount;
        }
        require(pendingWithdraw[account][assetId] >= beforePendingAmount, "Vault: OVERFLOW");
        emit LogNewPendingWithdrawAmount(account, assetId, pendingWithdraw[account][assetId]);
    }

    /// @dev Internal function for updating pending withdraw.
    function _decreasePendingWithdraw(address account, uint256 assetId, uint256 amount) internal {
        uint256 beforePendingAmount = pendingWithdraw[account][assetId];
        unchecked {
            pendingWithdraw[account][assetId] -= amount;
        }
        require(pendingWithdraw[account][assetId] <= beforePendingAmount, "Vault: UNDERFLOW");
        emit LogNewPendingWithdrawAmount(account, assetId, pendingWithdraw[account][assetId]);
    }

    /// @dev Internal deposit function.
    function _depositAsset(
        uint256 assetId,
        uint256 amount,
        bytes calldata vesselKey
    )
        internal
        assetActive(assetId)
        validVesselKeyToAddress(vesselKey, msg.sender)
        vaultAssetAmountUnderLimit(assetId)
    {
        uint256 actualAmount = constrainAmountWithPrecision(assetId, amount);
        transferIn(assetId, actualAmount);
        pushL1ToL2DepositMessage(msg.sender, uint32(assetId), uint128(actualAmount));
        emit LogDeposit(msg.sender, assetId, actualAmount);
    }

    /// @dev Verify SNARK proof can be accepted by verifier and instances matches the current on-chain root. Update
    ///     on-chain root after verification passes.
    function _verifySnarkProofAndUpdateMerkleRoots(uint256[] calldata instances, bytes calldata proof) private {
        require(instances.length == 20, "Vault: instance size not match SNARK proof");
        require(instances[14] == eternalTreeRoot, "Vault: current eternal tree root not match proof instance");
        require(instances[15] == ephemeralTreeRoot, "Vault: current ephemeral tree root not match proof instance");
        require(verifySnarkProof(instances, proof, snarkVerifier), "Vault: SNARK verifier rejected proof");
        updateEternalTreeRoot(instances[18]);
        updateEphemeralTreeRoot(instances[19]);
    }

    /// @dev Update on-chain state of L1 to L2 message queue and verify it is consistent with the provided SNARK
    ///     proof instance value.
    function _verifyAndUpdateL1ToL2MessageQueue(
        uint256 hashBeforeModQ,
        uint256 hashAfterModQ,
        uint256 l1ToL2MessageCnt
    )
        private
    {
        require(
            uint256(l1ToL2MessageQueueHash[l1ToL2MessageQueueCommitIndex]) % Q == hashBeforeModQ,
            "Vault: l1 to l2 message queue hash not match instance before update"
        );
        require(
            l1ToL2MessageQueueCommitIndex + l1ToL2MessageCnt <= l1ToL2MessageQueueTailIndex,
            "Vault: l1 to l2 message queue out of range"
        );

        uint256 newIndex = l1ToL2MessageQueueCommitIndex + l1ToL2MessageCnt;
        require(
            uint256(l1ToL2MessageQueueHash[newIndex]) % Q == hashAfterModQ,
            "Vault: l1 to l2 message hash not match instance after update"
        );
        updateL1ToL2MessageQueue(newIndex);
    }

    /// @dev Update on-chain state of L2 to L1 message queue and verify it is consistent with the provided SNARK
    ///     proof instance value.
    function _verifyAndUpdateL2ToL1MessageQueue(
        uint256 hashBeforeModQ,
        uint256 hashAfterModQ,
        bytes[] calldata l2ToL1Messages
    )
        private
    {
        require(
            uint256(l2ToL1MessageQueueCommitHash) % Q == hashBeforeModQ,
            "Vault: l2 to l1 message queue hash not match instance before update"
        );
        bytes32 newHash = l2ToL1MessageQueueCommitHash;

        for (uint256 i = 0; i < l2ToL1Messages.length; i++) {
            if (l2ToL1Messages[i][32] == 0) {
                (bytes32 prevMessageQueueHash, address userAddress, uint256 assetId, uint256 withdrawAmount) =
                    mqEncoder.decodeWithdrawMessage(l2ToL1Messages[i]);
                _increasePendingWithdraw(userAddress, assetId, withdrawAmount);
                require(prevMessageQueueHash == newHash, "Vault: l2 to l1 message queue hash not match");
            } else if (l2ToL1Messages[i][32] == bytes1(uint8(1))) {
                (
                    bytes32 prevMessageQueueHash,
                    uint32 poolId,
                    uint32 baseAssetId,
                    uint32 quoteAssetId,
                    uint128 minPrice,
                    uint128 priceDelta,
                    uint64 totalTicks,
                    uint64 curTickIndex
                ) = mqEncoder.decodeAmmPoolCreateMessage(l2ToL1Messages[i]);
                emit LogAmmPoolCreated(
                    poolId, baseAssetId, quoteAssetId, minPrice, priceDelta, totalTicks, curTickIndex
                );
                require(prevMessageQueueHash == newHash, "Vault: l2 to l1 message queue hash not match");
            } else if (l2ToL1Messages[i][32] == bytes1(uint8(2))) {
                (
                    bytes32 prevMessageQueueHash,
                    address lpAddr,
                    uint32 assetId,
                    uint128 backfillAmount
                ) = mqEncoder.decodeFastWithdrawL2Message(l2ToL1Messages[i]);
                backfillToExitLp(payable(lpAddr), assetId, backfillAmount);
                emit LogFastWithdrawBackfill(lpAddr, assetId, backfillAmount);
                require(prevMessageQueueHash == newHash, "Vault: l2 to l1 message queue hash not match");
            } else {
                revert("Vault: unsupported l2 to l1 message type appears");
            }
            newHash = keccak256(l2ToL1Messages[i]);
        }
        require(
            uint256(newHash) % Q == hashAfterModQ, "Vault: l2 to l1 message queue hash not match instance after update"
        );
        updateL2ToL1MessageQueue(newHash);
    }

    /// @dev Update SNARK proof metadata.
    function _updateProofCommitmentMetadata(uint256 batchId, uint256 lastEventId) private {
        lastCommitBatchId = batchId;
        lastCommitEventId = lastEventId;
        emit LogProofCommitted(lastCommitBatchId, lastCommitEventId);
    }
}
