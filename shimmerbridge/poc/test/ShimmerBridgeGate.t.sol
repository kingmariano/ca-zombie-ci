// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// ShimmerBridge (LayerZero EndpointV1 lock/mint bridge) — extraction-gate PoC.
//
// Origin-side custody: OriginalTokenBridge 0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898
// (Ethereum; same address on BSC/Polygon/Arbitrum/Base/Optimism/Avalanche/Fantom).
// Unlock path: _nonblockingLzReceive, reachable only via the LayerZero v1
// endpoint -> default receive library (ReceiveUln301, E1/ULN301 with DVNs) ->
// commitVerification (4 required DVNs) -> executor -> endpoint.receivePayload.
// Remote chain: ShimmerEVM, LZ chain id/EID 230 — SHUT DOWN (chain halted
// 2026-09-30; LayerZero DVN/Executor support ended 2026-08-28).
//
// These tests are read-only against mainnet state on a fork. The only
// "extraction" that happens runs on the local fork, by impersonating the
// LayerZero DVNs + executor to prove where the cryptographic gate is.
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address spender, uint256 amount) external returns (bool);
}

struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

interface IBridge {
    function owner() external view returns (address);
    function lzEndpoint() external view returns (address);
    function remoteChainId() external view returns (uint16);
    function useCustomAdapterParams() external view returns (bool);
    function trustedRemoteLookup(uint16 _srcChainId) external view returns (bytes memory);
    function supportedTokens(address token) external view returns (bool);
    function LDtoSDConversionRate(address token) external view returns (uint256);
    function totalValueLockedSD(address token) external view returns (uint256);
    function accruedFeeLD(address token) external view returns (uint256);
    function withdrawFee(address token, address to, uint256 amountLD) external;
    function registerToken(address token, uint8 sharedDecimals) external;
    function setRemoteChainId(uint16 _remoteChainId) external;
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external;
    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external payable;
}

interface IEndpointV1 {
    function getInboundNonce(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (uint64);
    function getOutboundNonce(uint16 _dstChainId, address _srcAddress) external view returns (uint64);
    function getReceiveLibraryAddress(address _userApplication) external view returns (address);
    function hasStoredPayload(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool);
    function receivePayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        address _dstAddress,
        uint64 _nonce,
        uint _gasLimit,
        bytes calldata _payload
    ) external;
}

interface IReceiveUln301 {
    function getUlnConfig(address _oapp, uint32 _remoteEid) external view returns (UlnConfig memory);
    function getExecutor(address _oapp, uint32 _remoteEid) external view returns (address);
    function verify(bytes calldata _packetHeader, bytes32 _payloadHash, uint64 _confirmations) external;
    function commitVerification(bytes calldata _packet, uint256 _gasLimit) external;
    function verifiable(UlnConfig memory _config, bytes32 _headerHash, bytes32 _payloadHash) external view returns (bool);
}

contract ShimmerBridgeGateTest is Test {
    error LZ_ULN_Verifying();
    error LZ_MessageLib_OnlyExecutor();

    address constant BRIDGE = 0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    uint16 constant REMOTE_CHAIN_ID = 230; // ShimmerEVM (LayerZero v1 chain id / EID)
    uint32 constant LOCAL_EID = 101; // Ethereum E1 EID (ReceiveUln301 localEid)
    uint8 constant PT_UNLOCK = 1; // TokenBridgeBase.PT_UNLOCK
    address constant ATTACKER = address(0xBADD00D5);

    IBridge bridge;
    IEndpointV1 endpoint;
    IReceiveUln301 lib;
    bytes trustedRemote;
    UlnConfig cfg;

    function setUp() public {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc);
        bridge = IBridge(BRIDGE);
        endpoint = IEndpointV1(bridge.lzEndpoint());
        lib = IReceiveUln301(endpoint.getReceiveLibraryAddress(BRIDGE));
        trustedRemote = bridge.trustedRemoteLookup(REMOTE_CHAIN_ID);
        cfg = lib.getUlnConfig(BRIDGE, REMOTE_CHAIN_ID);
    }

    // ---------------------------- helpers ---------------------------------

    function _msg(
        uint8 packetType,
        address token,
        address to,
        uint256 amountSD,
        uint256 totalSD,
        bool unwrapWeth
    ) internal pure returns (bytes memory) {
        return abi.encode(packetType, token, to, amountSD, totalSD, unwrapWeth);
    }

    /// PacketV1Codec header: version(1) nonce(8) srcEid(4) sender(32) dstEid(4) receiver(32) = 81 bytes
    function _header(
        uint64 nonce,
        uint32 srcEid,
        address sender,
        uint32 dstEid,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(1),
                nonce,
                srcEid,
                bytes32(uint256(uint160(sender))),
                dstEid,
                bytes32(uint256(uint160(receiver)))
            );
    }

    function _packet(bytes memory header, bytes32 guid, bytes memory message) internal pure returns (bytes memory) {
        return abi.encodePacked(header, guid, message);
    }

    function _attest(bytes memory header, bytes32 payloadHash, UlnConfig memory c) internal {
        for (uint256 i = 0; i < c.requiredDVNs.length; i++) {
            vm.prank(c.requiredDVNs[i]);
            lib.verify(header, payloadHash, c.confirmations);
        }
    }

    // ---------------------------- tests -----------------------------------

    /// Live state of the custody contract on Ethereum at the fork block.
    function test_01_live_state_eth() public {
        console2.log("=== ShimmerBridge live state (Ethereum) ===");
        console2.log("fork block", block.number);
        console2.log("bridge", BRIDGE);
        console2.log("endpoint", address(endpoint));
        console2.log("receiveLib", address(lib));
        console2.log("owner", bridge.owner());
        console2.log("remoteChainId", bridge.remoteChainId());
        console2.log("inboundNonce[230]", endpoint.getInboundNonce(REMOTE_CHAIN_ID, trustedRemote));
        console2.log("outboundNonce[230]", endpoint.getOutboundNonce(REMOTE_CHAIN_ID, BRIDGE));
        console2.log("requiredDVNs", cfg.requiredDVNCount);
        console2.log("confirmations", uint256(cfg.confirmations));
        console2.log("executor", lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID));
        console2.log("WETH locked (wei)", IERC20(WETH).balanceOf(BRIDGE));
        console2.log("USDC locked (1e6)", IERC20(USDC).balanceOf(BRIDGE));
        console2.log("USDT locked (1e6)", IERC20(USDT).balanceOf(BRIDGE));
        console2.log("WBTC locked (1e8)", IERC20(WBTC).balanceOf(BRIDGE));
        console2.log("accruedFee USDT (1e6)", bridge.accruedFeeLD(USDT));

        assertEq(bridge.remoteChainId(), REMOTE_CHAIN_ID, "remote chain id");
        // trustedRemote = remoteAddress(20) ++ localAddress(20), both the same address
        assertEq(trustedRemote, abi.encodePacked(BRIDGE, BRIDGE), "trusted remote");
        assertTrue(bridge.supportedTokens(WETH));
        assertTrue(bridge.supportedTokens(USDC));
        assertTrue(bridge.supportedTokens(USDT));
        assertTrue(bridge.supportedTokens(WBTC));
        assertGt(IERC20(WETH).balanceOf(BRIDGE), 0, "live custody");
        assertGt(IERC20(USDC).balanceOf(BRIDGE), 0, "live custody");
        assertGt(IERC20(WBTC).balanceOf(BRIDGE), 0, "live custody");
        // fee accounting: TVL (conv rate 1) equals the locked balance -> no owner-takeable principal
        assertEq(IERC20(WETH).balanceOf(BRIDGE), bridge.totalValueLockedSD(WETH));
        assertEq(IERC20(USDC).balanceOf(BRIDGE), bridge.totalValueLockedSD(USDC));
        assertEq(IERC20(WBTC).balanceOf(BRIDGE), bridge.totalValueLockedSD(WBTC));
        // the unlock gate: 4 required DVNs
        assertEq(cfg.requiredDVNCount, 4, "4 required DVNs");
        assertGe(cfg.confirmations, 15, "block confirmations");
        assertTrue(lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID) != address(0), "executor set");
        assertTrue(lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID) != ATTACKER, "executor not attacker");
    }

    /// An unprivileged attacker cannot call the app's lzReceive directly.
    function test_02_direct_lzReceive_reverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert("LzApp: invalid endpoint caller");
        bridge.lzReceive(
            REMOTE_CHAIN_ID,
            trustedRemote,
            530,
            _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false)
        );
    }

    /// An unprivileged attacker cannot inject a payload through the endpoint.
    function test_03_endpoint_receivePayload_reverts() public {
        uint64 nonce = endpoint.getInboundNonce(REMOTE_CHAIN_ID, trustedRemote) + 1;
        vm.prank(ATTACKER);
        vm.expectRevert("LayerZero: invalid default library");
        endpoint.receivePayload(
            REMOTE_CHAIN_ID,
            trustedRemote,
            BRIDGE,
            nonce,
            500000,
            _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false)
        );
    }

    /// Attacker can call the permissionless verify(), but it only records the
    /// attacker as a "DVN"; it never counts toward the 4 required DVNs.
    function test_04_permissionless_verify_is_not_counted() public {
        bytes memory header = _header(1, REMOTE_CHAIN_ID, BRIDGE, LOCAL_EID, BRIDGE);
        bytes32 guid = keccak256("attacker-guid");
        bytes memory message = _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));
        bytes memory pkt = _packet(header, guid, message);

        vm.prank(ATTACKER);
        lib.verify(header, payloadHash, cfg.confirmations);

        assertFalse(lib.verifiable(cfg, keccak256(header), payloadHash), "attacker is not a DVN");

        vm.prank(ATTACKER);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);
    }

    /// The gate in full: 4/4 DVN attestations + the configured executor are
    /// BOTH required. With both (fork-impersonated), the unlock succeeds —
    /// proving the gate is exactly the LayerZero DVN quorum + executor, and
    /// that no unprivileged shortcut exists. Replay of the same packet fails.
    function test_05_dvn_quorum_and_executor_gate() public {
        uint64 nonce = endpoint.getInboundNonce(REMOTE_CHAIN_ID, trustedRemote) + 1;
        bytes memory header = _header(nonce, REMOTE_CHAIN_ID, BRIDGE, LOCAL_EID, BRIDGE);
        bytes32 guid = keccak256("fork-guid");
        bytes memory message = _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false);
        bytes memory pkt = _packet(header, guid, message);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));

        // 1) without DVN attestations: not verifiable
        assertFalse(lib.verifiable(cfg, keccak256(header), payloadHash));
        vm.prank(ATTACKER);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);

        // 2) with 4/4 DVN attestations but a non-executor caller: rejected
        _attest(header, payloadHash, cfg);
        assertTrue(lib.verifiable(cfg, keccak256(header), payloadHash), "verifiable after quorum");
        vm.prank(ATTACKER);
        vm.expectRevert(LZ_MessageLib_OnlyExecutor.selector);
        lib.commitVerification(pkt, 500000);

        // 3) with 4/4 DVN attestations + executor: unlock executes
        address executor = lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID);
        uint256 balBefore = IERC20(WETH).balanceOf(ATTACKER);
        uint256 tvlBefore = bridge.totalValueLockedSD(WETH);
        vm.prank(executor);
        lib.commitVerification(pkt, 500000);
        assertEq(IERC20(WETH).balanceOf(ATTACKER) - balBefore, 1e18, "unlock executed");
        assertEq(tvlBefore - bridge.totalValueLockedSD(WETH), 1e18, "TVL decremented");

        // 4) replay of the same packet fails (attestations consumed + nonce used)
        vm.prank(executor);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);
    }

    /// Even with 4/4 DVN attestations and the executor, a packet whose sender
    /// is not the trusted remote cannot unlock: the app rejects it and the
    /// endpoint stores the payload (no funds move).
    function test_06_wrong_sender_cannot_unlock() public {
        bytes memory attackerPath = abi.encodePacked(ATTACKER, BRIDGE);
        uint64 nonce = endpoint.getInboundNonce(REMOTE_CHAIN_ID, attackerPath) + 1;
        bytes memory header = _header(nonce, REMOTE_CHAIN_ID, ATTACKER, LOCAL_EID, BRIDGE);
        bytes32 guid = keccak256("wrong-sender-guid");
        bytes memory message = _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false);
        bytes memory pkt = _packet(header, guid, message);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));

        _attest(header, payloadHash, cfg);
        uint256 balBefore = IERC20(WETH).balanceOf(ATTACKER);
        vm.prank(lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID));
        lib.commitVerification(pkt, 500000);

        assertEq(IERC20(WETH).balanceOf(ATTACKER), balBefore, "no unlock for wrong sender");
        assertTrue(endpoint.hasStoredPayload(REMOTE_CHAIN_ID, attackerPath), "payload stored");
    }

    /// Even with a full DVN quorum, a packet with srcEid != 230 cannot unlock:
    /// trustedRemoteLookup[101] is empty, so the app reverts.
    function test_07_wrong_srcEid_cannot_unlock() public {
        uint32 wrongEid = 101; // Ethereum itself; app only trusts EID 230
        assertEq(bridge.trustedRemoteLookup(uint16(wrongEid)).length, 0, "no trusted remote for 101");
        UlnConfig memory cfg101 = lib.getUlnConfig(BRIDGE, wrongEid);
        uint64 nonce = endpoint.getInboundNonce(uint16(wrongEid), trustedRemote) + 1;
        bytes memory header = _header(nonce, wrongEid, BRIDGE, LOCAL_EID, BRIDGE);
        bytes32 guid = keccak256("wrong-eid-guid");
        bytes memory message = _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false);
        bytes memory pkt = _packet(header, guid, message);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));

        _attest(header, payloadHash, cfg101);
        uint256 balBefore = IERC20(WETH).balanceOf(ATTACKER);
        vm.prank(lib.getExecutor(BRIDGE, wrongEid));
        lib.commitVerification(pkt, 500000);

        assertEq(IERC20(WETH).balanceOf(ATTACKER), balBefore, "no unlock for wrong srcEid");
        assertTrue(endpoint.hasStoredPayload(uint16(wrongEid), trustedRemote), "payload stored");
    }

    /// The owner cannot take principal — only accrued fees (and fees here are
    /// dust: 0.001 USDT). Admin entry points are owner-gated.
    function test_08_owner_cannot_take_principal() public {
        address owner = bridge.owner();
        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        bridge.withdrawFee(WETH, ATTACKER, 1);

        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        bridge.registerToken(ATTACKER, 6);

        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        bridge.setRemoteChainId(1);

        uint256 bal = IERC20(USDT).balanceOf(BRIDGE);
        uint256 tvl = bridge.totalValueLockedSD(USDT);
        uint256 fee = bridge.accruedFeeLD(USDT);
        assertEq(bal - tvl, fee, "fee = balance - TVL");
        assertGt(fee, 0, "some dust fee accrued");

        vm.prank(owner);
        vm.expectRevert("OriginalTokenBridge: not enough fees collected");
        bridge.withdrawFee(USDT, owner, fee + 1);

        vm.prank(owner);
        bridge.withdrawFee(USDT, owner, fee);
        assertEq(IERC20(USDT).balanceOf(BRIDGE), tvl, "principal untouched");
    }

    /// retryMessage can only replay an already-stored payload; there is none
    /// to inject for the trusted path.
    function test_09_retryMessage_cannot_inject() public {
        vm.prank(ATTACKER);
        vm.expectRevert("NonblockingLzApp: no stored message");
        bridge.retryMessage(
            REMOTE_CHAIN_ID,
            trustedRemote,
            530,
            _msg(PT_UNLOCK, WETH, ATTACKER, 1e18, 1e18, false)
        );
    }
}
