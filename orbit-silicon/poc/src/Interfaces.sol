// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces for the Orbit/Silicon live-state PoC (read/call only).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

/// OrbitVoting proxy on Silicon (0x33fa9a4f...)
interface IVoting {
    function totalStaking() external view returns (uint256);
    function totalPending() external view returns (uint256);
    function lockupPeriod() external view returns (uint256);
    function stakingToken() external view returns (address);
    function rewardToken() external view returns (address);
    function inflationContract() external view returns (address);
    function extensionContract() external view returns (address);
    function voterList(uint256) external view returns (address);
    function isVoter(address) external view returns (bool);
    function getStakingAmount(address) external view returns (uint256);
    function getPendingAmount(address) external view returns (uint256);
    function votingAmount(address delegatedVoter, address voter) external view returns (uint256);
    function voting(address account, uint256 amount) external;
    function unvoting(address account, uint256 amount) external;
    function claimUnvoting() external;
    function claimUnvoting(uint256 uid) external;
    function claimUnvotingAll() external;
    function claimReward(address account) external;
    function distribute() external;
}

/// OrbitGovernor proxy on Silicon (0x3d0FD4bB...)
interface IGovernor {
    function admin_() external view returns (address);
    function owner_() external view returns (address);
    function orc() external view returns (address);
    function proposalCount() external view returns (uint256);
    function emergencyTransfer(address targetToken, address targetAddr, uint256 amount) external;
    function emergencyTransferNative(address targetAddr, uint256 amount) external;
    function execute(uint256 proposalId) external;
    function cancel(uint256 proposalId) external;
    function setProposalFee(uint256 amount) external;
}

/// Canonical Agglayer bridge (same address on L1 and on Silicon L2)
interface IAgglayerBridge {
    function networkID() external view returns (uint32);
    function globalExitRootManager() external view returns (address);
    function depositCount() external view returns (uint256);
    function getRoot() external view returns (bytes32);
    function isEmergencyState() external view returns (bool);
    function isClaimed(uint32 leafIndex, uint32 sourceBridgeNetwork) external view returns (bool);
    function claimAsset(
        bytes32[32] calldata smtProofLocalExitRoot,
        bytes32[32] calldata smtProofRollupExitRoot,
        uint256 globalIndex,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external;

    function getTokenWrappedAddress(uint32 originNetwork, address originTokenAddress) external view returns (address);
}

/// Wrapped-token proxy deployed by the bridge (mint/burn onlyBridge).
interface ITokenWrapped {
    function mint(address, uint256) external;
    function burn(address, uint256) external;
    function totalSupply() external view returns (uint256);
    function bridgeAddress() external view returns (address);
}
