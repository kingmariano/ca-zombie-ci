// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ICampaignRegistry.sol";

interface IRewardsDistributor {
    struct ClaimParams {
        bytes32 campaignId;
        address account;
        address rewardToken;
        uint256 cumulativeAmount;
        bytes32[] merkleProof;
    }

    event MerkleRootUpdated(bytes32 indexed campaignId, bytes32 oldRoot, bytes32 newRoot);

    event Claimed(bytes32 indexed campaignId, address indexed account, address indexed rewardToken, uint256 amount);

    function updateMerkleRoot(bytes32 campaignId, bytes32 newRoot) external;

    function claim(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        returns (uint256 claimedAmount);

    function claimMultiple(ClaimParams[] calldata claims) external returns (uint256 totalClaimed);

    function getClaimable(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (uint256);

    function merkleRoots(bytes32 campaignId) external view returns (bytes32);

    function claimed(bytes32 campaignId, address account, address rewardToken) external view returns (uint256);

    function campaignRegistry() external view returns (ICampaignRegistry);
}
