// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// QC-2 interfaces for the Convergence Fi adversarial re-audit (read-only fork research).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface ISdtStakingPositionService {
    struct WithdrawCallInfo { address addr; bytes signature; }

    function stakingAsset() external view returns (address);
    function vault() external view returns (address);
    function buffer() external view returns (address);
    function owner() external view returns (address);
    function depositPaused() external view returns (bool);
    function stakingCycle() external view returns (uint128);
    function symbol() external view returns (string memory);
    function tokenTotalStaked(uint256 tokenId) external view returns (uint256);
    function cycleInfo(uint256 cycleId) external view returns (uint256 cvgRewardsAmount, uint256 totalStaked, bool isSdtProcessed);
    function withdraw(uint256 tokenId, uint256 amount) external;
    function deposit(uint256 tokenId, uint256 amount, address operator) external;
    function processSdtRewards() external;
    function initialize(
        address _cvgControlTower,
        address _stakingAsset,
        string memory _symbol,
        bool _isGaugeAsset,
        WithdrawCallInfo calldata _withdrawCallInfo
    ) external;
}

interface ISdtBlackHole {
    function withdraw(address receiver, uint256 amount) external;
    function isBuffer(address) external view returns (bool);
    function isGaugeAsset(address) external view returns (bool);
    function owner() external view returns (address);
}

interface ISdtStakingPositionManager {
    function ownerOf(uint256) external view returns (address);
    function burn(uint256 _tokenId) external;
    function setLock(uint256 tokenId, uint256 timestamp) external;
    function unlockingTimestampPerToken(uint256 tokenId) external view returns (uint256);
    function checkTokenFullCompliance(uint256 tokenId, address receiver) external view;
    function nextId() external view returns (uint256);
    function stakingPerTokenId(uint256) external view returns (address);
    function maxLockingTime() external view returns (uint256);
}

interface ICvgControlTower {
    struct Staking { address stakingContract; string stakingName; }

    function owner() external view returns (address);
    function isSdtStaking(address) external view returns (bool);
    function isStakingContract(address) external view returns (bool);
    function toggleStakingContracts(address[] calldata) external;
    function insertNewSdtStaking(address _sdtStakingClone) external;
    function getSdtStakings(uint256 _cursorStart, uint256 _lengthDesired) external view returns (Staking[] memory);
    function cvgSdtStaking() external view returns (address);
    function cvgSdtBuffer() external view returns (address);
    function sdtBlackHole() external view returns (address);
    function sdtRewardDistributor() external view returns (address);
    function sdtStakingPositionManager() external view returns (address);
    function sdtUtilities() external view returns (address);
    function cloneFactory() external view returns (address);
    function sdt() external view returns (address);
    function cvgSDT() external view returns (address);
}

interface ICloneFactoryV2 {
    function createSdtStakingAndBuffer(address _sdAssetGauge, string memory _symbol, bool isLp) external;
}

interface ILiquidityGauge {
    function claim_rewards() external;
    function claim_rewards(address _addr) external;
    function claim_rewards(address _addr, address _receiver) external;
    function claim_rewards_for(address _addr, address _receiver) external;
    function claimer() external view returns (address);
    function admin() external view returns (address);
    function initialized() external view returns (bool);
    function staking_token() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function set_rewards_receiver(address _receiver) external;
    function set_claimer(address _claimer) external;
    function deposit(uint256 _value, address _addr) external;
    function withdraw(uint256 _value) external;
}

interface ISdtBufferV2 {
    function processorRewardsPercentage() external view returns (uint256);
    function pullRewards(address processor) external returns (bytes memory);
    function sdtStaking() external view returns (address);
    function owner() external view returns (address);
}

interface ISdtRewardDistributorV2 {
    struct ClaimSdtStakingContract { address stakingContract; uint256[] tokenIds; }

    function claimMultipleStaking(
        ClaimSdtStakingContract[] calldata claimContracts,
        uint256 minCvgSdtAmountOut,
        bool isConvert,
        uint256 sdtRewardCount
    ) external;

    function claimCvgSdtSimple(
        address receiver,
        uint256 totalCvgClaimable,
        ICommonStruct.TokenAmount[] memory totalSdtRewardsClaimable,
        uint256 minCvgSdtAmountOut,
        bool isConvert
    ) external;
}

interface ICommonStruct {
    struct TokenAmount { IERC20 token; uint256 amount; }
}

interface IClaimRewardsV1 {
    function initialize(address _governance) external;
    function governance() external view returns (address);
    function claimRewards(address[] calldata _gauges, bool _claimVeSDT) external;
}

interface ICvgRewards {
    function writeStakingRewards(uint256 _uselessParam) external;
    function lastUpdatedTimestamp() external view returns (uint256);
}
