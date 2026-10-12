// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IVault {
    function adminAddress() external view returns (address);
    function isOperator(address account) external view returns (bool);
    function isExitManager(address account) external view returns (bool);
    function getSnarkVerifierAddress() external view returns (address);
    function getCircuitVersion() external view returns (string memory);
    function lastCommitBatchId() external view returns (uint256);
    function lastCommitEventId() external view returns (uint256);
    function getPendingWithdraw(address account, uint256 assetId) external view returns (uint256);
    function extractAssetId(address assetAddress) external view returns (uint256);
    function withdraw(uint256 assetId, uint256 amount) external;
    function withdrawAll(uint256 assetId) external;
    function transferAdmin(address newAdmin) external;
    function registerNewAsset(address assetAddress, uint256 assetId, uint8 limitDigit, uint8 precisionDigit, uint8 decimals) external;
    function setAssetActive(uint256 assetId) external;
    function setAssetInactive(uint256 assetId) external;
    function updateAll(address snarkVerifier, string calldata circuitVersion) external;
    function updateSnarkVerifierAddress(address newVerifier) external;
    function setWethAddress(address addr) external;
    function commitSnarkProof(
        uint256[] calldata instances,
        bytes calldata proof,
        uint256 l1ToL2MessageCnt,
        bytes[] calldata l2ToL1Messages,
        uint256 batchId,
        uint256 lastEventId
    ) external;
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
    ) external;
    function initialize(address vaultAdmin) external;
    function checkAndRegisterUser(bytes calldata vesselKey, address operatorAddr, uint8 sigV, bytes32 sigR, bytes32 sigS) external;
    function depositNative(bytes calldata vesselKey) external payable;
    function registerAndDepositNative(bytes calldata vesselKey, address operator, uint8 sigV, bytes32 sigR, bytes32 sigS) external payable;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IProxyAdmin {
    function owner() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function upgradeAndCall(address newImplementation, bytes calldata data) external;
}

interface IExecutor {
    function execute(address target, uint256 value, bytes calldata data, bytes32 salt) external;
}
