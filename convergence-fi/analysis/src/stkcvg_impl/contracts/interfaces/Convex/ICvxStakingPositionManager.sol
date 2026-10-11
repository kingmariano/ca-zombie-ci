// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../ISdtStakingLogo.sol";
import "./ICvxStakingPositionService.sol";

interface ICvxStakingPositionManager {
    struct ClaimCvxStakingContract {
        ICvxStakingPositionService stakingContract;
        uint256[] tokenIds;
    }

    function mint(address account) external returns (uint256);

    function burn(uint256 tokenId) external;

    function nextId() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function checkMultipleClaimCompliance(ClaimCvxStakingContract[] calldata, address account) external view;

    function checkTokenFullCompliance(uint256 tokenId, address account) external view;

    function checkIncreaseDepositCompliance(uint256 tokenId, address account) external view;

    function stakingPerTokenId(uint256 tokenId) external view returns (address);

    function unlockingTimestampPerToken(uint256 tokenId) external view returns (uint256);

    function logoInfo(uint256 tokenId) external view returns (ISdtStakingLogo.LogoInfos memory);

    function getTokenIdsForWallet(address _wallet) external view returns (uint256[] memory);
}
