// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces for the Enosys Bridge (Flare Finance) "Wrap" family.
/// Source verified on XDC blocksscan (WrapDepositRedeem, compiler 0.8.17);
/// identical deployed bytecode on Ethereum / XDC (10537 bytes, keccak
/// 0xfc583019372fe7139c5efb62e3678b7d3cb36899ceadb2d1c8ba15635c28cb23).
/// WrapMintBurn (Songbird/Flare) shares the same Multisig/Wrap base.

struct TokenInfo {
    uint256 maxAmount;
    uint256 minAmount;
    uint256 dailyLimit;
}

struct MultisigConfig {
    uint8 firstCommitteeAcceptanceQuorum;
    uint8 secondCommitteeAcceptanceQuorum;
}

struct RequestInfo {
    uint256 id;
    address token;
    uint256 amount;
    address to;
}

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IWrapLike {
    // errors
    error SignerNotActive(address signer);
    error InvalidBlockHash();
    error ContractPaused();
    error ContractNotPaused();
    error ContractMigrated();
    error InvalidTokenAmount();
    error InvalidToAddress();
    error InvalidId();
    error InvalidNextExecutionIndex();
    error DailyLimitExhausted();
    error InvalidFeeRecipient();
    error FeeExceedsMaxFee();
    error InvalidTokenConfig();

    // views
    function paused() external view returns (bool);
    function depositIndex() external view returns (uint256);
    function nextExecutionIndex() external view returns (uint256);
    function validatorFeeBPS() external view returns (uint16);
    function migratedContract() external view returns (address);
    function tokens(uint256) external view returns (address);
    function tokenInfos(
        address
    )
        external
        view
        returns (
            uint256 maxAmount,
            uint256 minAmount,
            uint256 dailyLimit,
            uint256 consumedLimit,
            uint256 lastUpdated
        );
    function mirrorTokens(address) external view returns (address);
    function validatorInfo(
        address validator
    ) external view returns (uint8 status, uint8 index);
    function attesters(
        bytes32 hash
    ) external view returns (uint16[] memory attesters, uint16 count);
    function feeBalance(address token, uint256 index) external view returns (uint256);
    function validatorFeeRecipients(address validator) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);

    // state changers
    function deposit(address token, uint256 amount, address to) external returns (uint256);
    function approveExecute(
        uint256 id,
        address mirrorToken,
        uint256 amount,
        address to,
        bytes32 recentBlockHash,
        uint256 recentBlockNumber
    ) external;
    function batchApproveExecute(
        RequestInfo[] calldata requests,
        bytes32 recentBlockHash,
        uint256 recentBlockNumber
    ) external;
    function claimValidatorFees(address validator) external;
    function pause() external;
    function unpause() external;
    function configureToken(address token, TokenInfo calldata tokenInfo) external;
    function addToken(address token, address mirrorToken, TokenInfo calldata tokenInfo) external;
    function configureMultisig(MultisigConfig calldata config) external;
    function addValidator(address validator, bool isFirstCommittee, address feeRecipient) external;
    function removeValidator(address validator) external;
    function forceSetNextExecutionIndex(uint256 index) external;
    function migrate(address _newContract) external;
}

interface IAccessControlErrors {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
}
