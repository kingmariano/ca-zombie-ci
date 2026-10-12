// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IWFLR {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external returns (bool);
}

/// @dev Bank v0.1.3 (verified source: flare-explorer 0xA76578a68a05CedE65E6587d60efd2ea4555C6d6)
interface IBank {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function buyPrice() external view returns (uint256);
    function sellPrice() external view returns (uint256);
    function buy(address referredBy) external payable returns (uint256);
    function buy(uint256 amount, address referredBy) external returns (uint256);
    function sell(uint256 amount) external returns (uint256);
    function withdraw() external;
    function exit() external;
    function reinvest() external;
    function dividendsOf(address user, bool referral) external view returns (uint256);
    function calculateTokensReceived(uint256) external view returns (uint256);
    function calculateEthereumReceived(uint256) external view returns (uint256);
    function unclaimedDividendTotal() external view returns (uint256);
    function unclaimedTeamFees() external view returns (uint256);
    function unclaimedFeeReceiverFees() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function initialize(
        address _owner,
        address _teamAddress,
        address _feeReceiverAddress,
        address _delegator,
        address[] calldata _delegates,
        uint256[] calldata _bips
    ) external;
    function upgradeTo(address) external;
}

/// @dev TsoRewardsClaimer / IBDP vault (unverified impl 0x564953d87668514415fb2339ef0834313713e332,
///      decompiled with panoramix; selectors verified on-chain)
interface IVault {
    function bank() external view returns (address);
    function getBalance(address user) external view returns (uint256);
    function getDepositTimestamp(address user) external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function claimWNatRewards(uint24 latestClaimRewardEpoch) external;
    function claimFlareDrops(uint256 latestClaimMonth) external;
    function tryClaimAllTsoRewards() external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function initialize(
        address _bank,
        address _wnat,
        address[] calldata _delegates,
        uint256[] calldata _bips
    ) external;
    function upgradeTo(address) external;
}
