// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICampaignRegistry {
    enum CampaignStatus {
        Active,
        Paused,
        Ended,
        Cancelled
    }

    struct Campaign {
        bytes32 id;
        address creator;
        address cToken;
        address rewardToken;
        uint256 totalBudget;
        uint256 totalPaid;
        uint256 startTime;
        uint256 endTime;
        uint256 maxApy; // Max APY in basis points (e.g., 10000 = 100%)
        CampaignStatus status;
    }

    event CampaignCreated(
        bytes32 indexed campaignId,
        address indexed creator,
        address indexed cToken,
        address rewardToken,
        uint256 totalBudget,
        uint256 startTime,
        uint256 endTime,
        uint256 maxApy
    );

    event CampaignToppedUp(bytes32 indexed campaignId, uint256 amount, uint256 newTotalBudget);

    event CampaignPaused(bytes32 indexed campaignId);

    event CampaignResumed(bytes32 indexed campaignId);

    event CampaignEnded(bytes32 indexed campaignId, uint256 refundedAmount);

    event CampaignCancelled(bytes32 indexed campaignId, uint256 refundedAmount);

    event RewardsPaid(bytes32 indexed campaignId, address indexed recipient, uint256 amount);

    function createCampaign(
        address cToken,
        address rewardToken,
        uint256 totalBudget,
        uint256 startTime,
        uint256 endTime,
        uint256 maxApy
    )
        external
        returns (bytes32 campaignId);

    function topUpCampaign(bytes32 campaignId, uint256 amount) external;

    function pauseCampaign(bytes32 campaignId) external;

    function resumeCampaign(bytes32 campaignId) external;

    function endCampaign(bytes32 campaignId) external;

    function cancelCampaign(bytes32 campaignId) external;

    function payoutRewards(bytes32 campaignId, uint256 amount, address recipient) external;

    function getCampaign(bytes32 campaignId) external view returns (Campaign memory);

    function getActiveCampaigns() external view returns (bytes32[] memory);

    function getCampaignsByOpportunity(address cToken) external view returns (bytes32[] memory);

    function getCampaignCount() external view returns (uint256);
}
