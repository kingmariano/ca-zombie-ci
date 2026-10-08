// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IRewardsDistributor.sol";
import "./interfaces/ICampaignRegistry.sol";

/**
 * @title RewardsDistributor
 * @notice Handles Merkle-proof-based reward claims for Capyfi incentive campaigns
 * @dev Uses cumulative claims model - users claim the difference between their
 *      cumulative entitlement and what they've already claimed
 */
contract RewardsDistributor is IRewardsDistributor, AccessControl, ReentrancyGuard {
    bytes32 public constant ROOT_PUBLISHER_ROLE = keccak256("ROOT_PUBLISHER_ROLE");

    /// @notice The CampaignRegistry contract
    ICampaignRegistry public immutable campaignRegistry;

    /// @notice Merkle roots per campaign
    mapping(bytes32 => bytes32) public merkleRoots;

    /// @notice Total claimed per (campaignId, account, rewardToken)
    mapping(bytes32 => mapping(address => mapping(address => uint256))) public claimed;

    constructor(address _campaignRegistry, address admin) {
        require(_campaignRegistry != address(0), "Invalid registry");
        campaignRegistry = ICampaignRegistry(_campaignRegistry);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROOT_PUBLISHER_ROLE, admin);
    }

    /**
     * @notice Updates the Merkle root for a campaign
     * @dev Only callable by accounts with ROOT_PUBLISHER_ROLE
     * @param campaignId The campaign ID
     * @param newRoot The new Merkle root
     */
    function updateMerkleRoot(bytes32 campaignId, bytes32 newRoot) external onlyRole(ROOT_PUBLISHER_ROLE) {
        // Verify campaign exists
        ICampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(campaignId);
        require(campaign.id != bytes32(0), "Campaign does not exist");

        bytes32 oldRoot = merkleRoots[campaignId];
        merkleRoots[campaignId] = newRoot;

        emit MerkleRootUpdated(campaignId, oldRoot, newRoot);
    }

    /**
     * @notice Claims rewards for a single campaign
     * @dev Merkle leaf format: keccak256(bytes.concat(keccak256(abi.encode(campaignId, account, rewardToken, cumulativeAmount))))
     * @param campaignId The campaign ID
     * @param account The account claiming rewards (can claim on behalf of others)
     * @param rewardToken The reward token address
     * @param cumulativeAmount The total cumulative amount the account is entitled to
     * @param merkleProof The Merkle proof
     * @return claimedAmount The amount actually claimed (cumulative - already claimed)
     */
    function claim(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        nonReentrant
        returns (uint256 claimedAmount)
    {
        // Verify reward token matches campaign's reward token
        ICampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(campaignId);
        require(campaign.id != bytes32(0), "Campaign does not exist");
        require(rewardToken == campaign.rewardToken, "Reward token mismatch");

        // Verify the Merkle proof
        bytes32 leaf = _computeLeaf(campaignId, account, rewardToken, cumulativeAmount);
        require(MerkleProof.verify(merkleProof, merkleRoots[campaignId], leaf), "Invalid proof");

        // Calculate claimable amount
        uint256 alreadyClaimed = claimed[campaignId][account][rewardToken];
        require(cumulativeAmount > alreadyClaimed, "Nothing to claim");

        claimedAmount = cumulativeAmount - alreadyClaimed;

        // Update claimed amount
        claimed[campaignId][account][rewardToken] = cumulativeAmount;

        // Request payout from CampaignRegistry
        campaignRegistry.payoutRewards(campaignId, claimedAmount, account);

        emit Claimed(campaignId, account, rewardToken, claimedAmount);
    }

    /**
     * @notice Claims rewards from multiple campaigns in a single transaction
     * @param claims Array of claim parameters
     * @return totalClaimed The total amount claimed across all campaigns
     */
    function claimMultiple(ClaimParams[] calldata claims) external nonReentrant returns (uint256 totalClaimed) {
        for (uint256 i = 0; i < claims.length; i++) {
            ClaimParams calldata c = claims[i];

            // Verify reward token matches campaign's reward token
            ICampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(c.campaignId);
            require(campaign.id != bytes32(0), "Campaign does not exist");
            require(c.rewardToken == campaign.rewardToken, "Reward token mismatch");

            // Verify the Merkle proof
            bytes32 leaf = _computeLeaf(c.campaignId, c.account, c.rewardToken, c.cumulativeAmount);
            require(MerkleProof.verify(c.merkleProof, merkleRoots[c.campaignId], leaf), "Invalid proof");

            // Calculate claimable amount
            uint256 alreadyClaimed = claimed[c.campaignId][c.account][c.rewardToken];
            if (c.cumulativeAmount <= alreadyClaimed) {
                continue; // Skip if nothing to claim
            }

            uint256 claimedAmount = c.cumulativeAmount - alreadyClaimed;

            // Update claimed amount
            claimed[c.campaignId][c.account][c.rewardToken] = c.cumulativeAmount;

            // Request payout from CampaignRegistry
            campaignRegistry.payoutRewards(c.campaignId, claimedAmount, c.account);

            totalClaimed += claimedAmount;

            emit Claimed(c.campaignId, c.account, c.rewardToken, claimedAmount);
        }
    }

    /**
     * @notice Calculates the claimable amount for an account
     * @dev Returns 0 if the proof is invalid
     * @param campaignId The campaign ID
     * @param account The account to check
     * @param rewardToken The reward token address
     * @param cumulativeAmount The cumulative amount from the Merkle tree
     * @param merkleProof The Merkle proof
     * @return The amount that can be claimed
     */
    function getClaimable(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (uint256)
    {
        // Verify the Merkle proof
        bytes32 leaf = _computeLeaf(campaignId, account, rewardToken, cumulativeAmount);
        if (!MerkleProof.verify(merkleProof, merkleRoots[campaignId], leaf)) {
            return 0;
        }

        uint256 alreadyClaimed = claimed[campaignId][account][rewardToken];
        if (cumulativeAmount <= alreadyClaimed) {
            return 0;
        }

        return cumulativeAmount - alreadyClaimed;
    }

    /**
     * @notice Verifies a Merkle proof without claiming
     * @param campaignId The campaign ID
     * @param account The account
     * @param rewardToken The reward token
     * @param cumulativeAmount The cumulative amount
     * @param merkleProof The Merkle proof
     * @return True if the proof is valid
     */
    function verifyProof(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (bool)
    {
        bytes32 leaf = _computeLeaf(campaignId, account, rewardToken, cumulativeAmount);
        return MerkleProof.verify(merkleProof, merkleRoots[campaignId], leaf);
    }

    /**
     * @notice Gets the current Merkle root for a campaign
     * @param campaignId The campaign ID
     * @return The current Merkle root
     */
    function getMerkleRoot(bytes32 campaignId) external view returns (bytes32) {
        return merkleRoots[campaignId];
    }

    /**
     * @notice Gets total claimed for an account in a campaign
     * @param campaignId The campaign ID
     * @param account The account
     * @param rewardToken The reward token
     * @return The total amount claimed
     */
    function getClaimed(bytes32 campaignId, address account, address rewardToken) external view returns (uint256) {
        return claimed[campaignId][account][rewardToken];
    }

    // ============ Internal Functions ============

    /**
     * @notice Computes the Merkle leaf hash
     * @dev Uses double-hashing to prevent second preimage attacks.
     *      Must match the Python engine's leaf computation.
     * @param campaignId The campaign ID
     * @param account The account
     * @param rewardToken The reward token
     * @param cumulativeAmount The cumulative amount
     * @return The leaf hash
     */
    function _computeLeaf(
        bytes32 campaignId,
        address account,
        address rewardToken,
        uint256 cumulativeAmount
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(bytes.concat(keccak256(abi.encode(campaignId, account, rewardToken, cumulativeAmount))));
    }
}
