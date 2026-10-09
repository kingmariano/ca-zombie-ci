// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct ReferralPositionFee {
    uint feeForPoolAmount;
    uint feeForPoolUsd;
    uint rebateAmount;
    uint rebateUsd;
}

struct ReferralInfo {
    bytes32 code;
    address affiliate;
    bool isActive;
    Tier tier;
}

struct Tier {
    uint256 id;
    uint256 rebate;
    uint256 discount;
}

interface IReferralManager {
    function codeOwners(bytes32 _code) external view returns (address);

    function getReferralInfoByTrader(address _trader) external view returns (ReferralInfo memory);

    function getReferralInfoByCode(bytes32 _code) external view returns (ReferralInfo memory);

    function getReferralInfoByAffiliate(address _affiliate) external view returns (ReferralInfo memory);

    function setTraderReferralCode(address _trader, bytes32 _code) external;

    function setTraderReferralCodeByUser(bytes32 _code) external;

    function setTier(uint256 _tierId, uint256 _rebate, uint256 _discount) external;

    function setAffiliateTier(address _referrer, uint256 _tierId) external;

    function getAffiliateReward(address _affiliate) external view returns (address[] memory, uint256[] memory);

    function claimAffiliateReward() external;

    function discountPositionFee(
        address _trader,
        address _token,
        uint256 _tokenPrice,
        uint256 _positionFeeUsd,
        uint256 _sizeDelta
    ) external returns (ReferralPositionFee memory fee);
}
