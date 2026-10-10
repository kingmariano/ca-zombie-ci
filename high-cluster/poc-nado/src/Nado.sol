// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal interfaces for the Nado (Ink) on-chain contract set.
// Signatures verified against Blockscout-verified sources of the live
// implementation contracts (see analysis/nado/REPORT.md).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

library Types {
    struct Balance {
        int128 amount;
    }

    struct SpotBalance {
        uint32 productId;
        Balance balance;
    }

    struct WithdrawCollateral {
        bytes32 sender;
        uint32 productId;
        uint128 amount;
        uint64 nonce;
    }

    struct WithdrawCollateralV2 {
        bytes32 sender;
        uint32 productId;
        uint128 amount;
        uint64 nonce;
        address sendTo;
        uint128 appendix;
    }

    struct SlowModeTx {
        uint64 executableAt;
        address sender;
        bytes tx;
    }

    struct CompactSignature {
        bytes32 r;
        bytes32 vs;
    }
}

interface IEndpoint {
    function depositCollateral(
        bytes12 subaccountName,
        uint32 productId,
        uint128 amount
    ) external;

    function submitSlowModeTransaction(bytes calldata transaction) external;
    function executeSlowModeTransaction() external;
    function processSlowModeTransaction(address sender, bytes calldata transaction) external;

    function getSlowModeTx(uint64 idx)
        external
        view
        returns (
            Types.SlowModeTx memory,
            uint64,
            uint64
        );

    function nSubmissions() external view returns (uint64);
    function getSequencer() external view returns (address);
    function getEndpointTx() external view returns (address);
    function getSubaccountId(bytes32 subaccount) external view returns (uint64);
    function getNonce(address sender) external view returns (uint64);
    function getPriceX18(uint32 productId) external view returns (int128);
    function clearinghouse() external view returns (address);
    function owner() external view returns (address);

    function submitTransactionsChecked(
        uint64 idx,
        bytes[] calldata transactions,
        bytes32 e,
        bytes32 s,
        uint8 signerBitmask
    ) external;

    function submitTransactionsCheckedWithGasLimit(
        uint64 idx,
        bytes[] calldata transactions,
        uint256 gasLimit
    ) external;
}

interface IClearinghouse {
    function withdrawCollateral(
        bytes32 sender,
        uint32 productId,
        uint128 amount,
        address sendTo,
        uint64 idx
    ) external;

    function getEndpoint() external view returns (address);
    function getQuote() external view returns (address);
    function getWithdrawPool() external view returns (address);
    function getInsurance() external view returns (int128);
    function getSlowModeFee() external view returns (uint256);
    function owner() external view returns (address);
}

interface IWithdrawPool {
    function submitFastWithdrawal(
        uint64 idx,
        bytes calldata transaction,
        bytes[] calldata signatures
    ) external;

    function submitWithdrawal(
        IERC20 token,
        address sendTo,
        uint128 amount,
        uint64 idx
    ) external;

    function minIdx() external view returns (uint64);
    function markedIdxs(uint64 idx) external view returns (bool);
    function fees(uint32 productId) external view returns (int128);
    function owner() external view returns (address);

    function checkProductBalances(uint32[] calldata productIds)
        external
        view
        returns (uint256[] memory);
}

interface IVerifier {
    function getPubkey(uint8 index)
        external
        view
        returns (uint256 x, uint256 y);

    function getEcdsaSigner(uint8 index) external view returns (address);
    function getPubkeyAddress(uint8 index) external view returns (address);

    function requireValidTxSignatures(
        bytes calldata txn,
        uint64 idx,
        bytes[] calldata signatures
    ) external view;

    function requireValidSignature(
        bytes32 message,
        bytes32 e,
        bytes32 s,
        uint8 signerBitmask
    ) external;

    function validateSignature(
        bytes32 sender,
        address linkedSigner,
        bytes32 digest,
        bytes memory signature
    ) external pure;

    function validateCompactSignature(
        bytes32 sender,
        address linkedSigner,
        bytes32 digest,
        Types.CompactSignature memory signature
    ) external pure;

    function computeDigest(uint8 txType, bytes calldata transactionBody)
        external
        view
        returns (bytes32);

    function txSignatureDigest(bytes calldata txn, uint64 idx)
        external
        view
        returns (bytes32);

    function owner() external view returns (address);
}

interface ISpotEngine {
    function getProductIds() external view returns (uint32[] memory);
    function getToken(uint32 productId) external view returns (address);
    function updateBalance(
        uint32 productId,
        bytes32 subaccount,
        int128 amountDelta
    ) external;

    function updatePrice(uint32 productId, int128 priceX18) external;
    function owner() external view returns (address);
    function getEndpoint() external view returns (address);
}

interface IPerpEngine {
    function owner() external view returns (address);
    function getEndpoint() external view returns (address);
}

interface IOffchainExchange {
    function owner() external view returns (address);
    function getEndpoint() external view returns (address);
}

interface IQuerier {
    function getSpotBalance(bytes32 subaccount, uint32 productId)
        external
        view
        returns (Types.SpotBalance memory);
}
