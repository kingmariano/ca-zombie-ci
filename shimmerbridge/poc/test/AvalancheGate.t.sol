// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// ShimmerBridge — Avalanche leg (largest single-chain custody, ~$57k).
// Same mechanism as the Ethereum suite: unlock only via LayerZero EndpointV1
// -> ReceiveUln301 (E1) with 4 required DVNs -> executor -> app lzReceive.
// Run against a fork of Avalanche C-Chain (read-only; unlock executed on the
// local fork only, by impersonating the DVNs + executor).
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
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
    function trustedRemoteLookup(uint16 _srcChainId) external view returns (bytes memory);
    function supportedTokens(address token) external view returns (bool);
    function totalValueLockedSD(address token) external view returns (uint256);
    function accruedFeeLD(address token) external view returns (uint256);
    function withdrawFee(address token, address to, uint256 amountLD) external;
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external;
    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external payable;
}

interface IEndpointV1 {
    function getInboundNonce(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (uint64);
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

contract ShimmerBridgeAvalancheGateTest is Test {
    error LZ_ULN_Verifying();
    error LZ_MessageLib_OnlyExecutor();

    address constant BRIDGE = 0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898;
    address constant USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7; // USDt (6 dec)
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; // USDC (6 dec)
    address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    uint16 constant REMOTE_CHAIN_ID = 230; // ShimmerEVM
    uint8 constant PT_UNLOCK = 1;
    address constant ATTACKER = address(0xBADD00D5);

    IBridge bridge;
    IEndpointV1 endpoint;
    IReceiveUln301 lib;
    bytes trustedRemote;
    UlnConfig cfg;
    uint32 localEid;

    function setUp() public {
        string memory rpc = vm.envOr(
            "AVALANCHE_RPC_URL",
            vm.envOr("AVAX_RPC_URL", string("https://avalanche-c-chain-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc);
        bridge = IBridge(BRIDGE);
        endpoint = IEndpointV1(bridge.lzEndpoint());
        lib = IReceiveUln301(endpoint.getReceiveLibraryAddress(BRIDGE));
        trustedRemote = bridge.trustedRemoteLookup(REMOTE_CHAIN_ID);
        cfg = lib.getUlnConfig(BRIDGE, REMOTE_CHAIN_ID);
        localEid = _discoverLocalEid();
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

    /// The ReceiveUln301 library has no localEid() getter (internal immutable).
    /// commitVerification asserts dstEid == localEid BEFORE checking DVN
    /// attestations, so a wrong dstEid reverts LZ_ULN_InvalidEid while the
    /// right one reverts LZ_ULN_Verifying (not attested). Probe candidates.
    function _discoverLocalEid() internal returns (uint32) {
        uint32[4] memory candidates = [uint32(106), 101, 230, 1];
        for (uint256 i = 0; i < candidates.length; i++) {
            bytes memory h = _header(1, REMOTE_CHAIN_ID, BRIDGE, candidates[i], BRIDGE);
            bytes memory pkt = _packet(h, bytes32(0), "");
            try lib.commitVerification(pkt, 100000) {
                revert("unexpected success");
            } catch (bytes memory reason) {
                if (bytes4(reason) == LZ_ULN_Verifying.selector) {
                    return candidates[i];
                }
            }
        }
        revert("localEid not discovered");
    }

    // ---------------------------- tests -----------------------------------

    function test_01_live_state_avax() public {
        console2.log("=== ShimmerBridge live state (Avalanche) ===");
        console2.log("fork block", block.number);
        console2.log("bridge", BRIDGE);
        console2.log("endpoint", address(endpoint));
        console2.log("receiveLib", address(lib));
        console2.log("owner", bridge.owner());
        console2.log("localEid", uint256(localEid));
        console2.log("inboundNonce[230]", endpoint.getInboundNonce(REMOTE_CHAIN_ID, trustedRemote));
        console2.log("requiredDVNs", cfg.requiredDVNCount);
        console2.log("confirmations", uint256(cfg.confirmations));
        console2.log("executor", lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID));
        console2.log("USDt locked (1e6)", IERC20(USDT).balanceOf(BRIDGE));
        console2.log("USDC locked (1e6)", IERC20(USDC).balanceOf(BRIDGE));
        console2.log("WAVAX locked (wei)", IERC20(WAVAX).balanceOf(BRIDGE));
        console2.log("accruedFee USDt (1e6)", bridge.accruedFeeLD(USDT));

        assertEq(bridge.remoteChainId(), REMOTE_CHAIN_ID, "remote chain id");
        assertEq(trustedRemote, abi.encodePacked(BRIDGE, BRIDGE), "trusted remote");
        assertEq(localEid, 106, "Avalanche E1 localEid");
        assertTrue(bridge.supportedTokens(USDT));
        assertTrue(bridge.supportedTokens(USDC));
        assertTrue(bridge.supportedTokens(WAVAX));
        assertGt(IERC20(USDT).balanceOf(BRIDGE), 0, "live custody");
        assertEq(IERC20(USDT).balanceOf(BRIDGE), bridge.totalValueLockedSD(USDT), "TVL == balance");
        assertEq(IERC20(USDC).balanceOf(BRIDGE), bridge.totalValueLockedSD(USDC), "TVL == balance");
        assertEq(cfg.requiredDVNCount, 4, "4 required DVNs");
        assertGe(cfg.confirmations, 15, "block confirmations");
    }

    function test_02_direct_lzReceive_reverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert("LzApp: invalid endpoint caller");
        bridge.lzReceive(REMOTE_CHAIN_ID, trustedRemote, 2090, _msg(PT_UNLOCK, USDT, ATTACKER, 1e6, 1e6, false));
    }

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
            _msg(PT_UNLOCK, USDT, ATTACKER, 1e6, 1e6, false)
        );
    }

    function test_04_permissionless_verify_is_not_counted() public {
        bytes memory header = _header(1, REMOTE_CHAIN_ID, BRIDGE, localEid, BRIDGE);
        bytes32 guid = keccak256("attacker-guid-avax");
        bytes memory message = _msg(PT_UNLOCK, USDT, ATTACKER, 1e6, 1e6, false);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));
        bytes memory pkt = _packet(header, guid, message);

        vm.prank(ATTACKER);
        lib.verify(header, payloadHash, cfg.confirmations);
        assertFalse(lib.verifiable(cfg, keccak256(header), payloadHash), "attacker is not a DVN");

        vm.prank(ATTACKER);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);
    }

    function test_05_dvn_quorum_and_executor_gate() public {
        uint64 nonce = endpoint.getInboundNonce(REMOTE_CHAIN_ID, trustedRemote) + 1;
        bytes memory header = _header(nonce, REMOTE_CHAIN_ID, BRIDGE, localEid, BRIDGE);
        bytes32 guid = keccak256("fork-guid-avax");
        bytes memory message = _msg(PT_UNLOCK, USDT, ATTACKER, 1e6, 1e6, false);
        bytes memory pkt = _packet(header, guid, message);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));

        assertFalse(lib.verifiable(cfg, keccak256(header), payloadHash));
        vm.prank(ATTACKER);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);

        _attest(header, payloadHash, cfg);
        assertTrue(lib.verifiable(cfg, keccak256(header), payloadHash), "verifiable after quorum");
        vm.prank(ATTACKER);
        vm.expectRevert(LZ_MessageLib_OnlyExecutor.selector);
        lib.commitVerification(pkt, 500000);

        address executor = lib.getExecutor(BRIDGE, REMOTE_CHAIN_ID);
        uint256 balBefore = IERC20(USDT).balanceOf(ATTACKER);
        uint256 tvlBefore = bridge.totalValueLockedSD(USDT);
        vm.prank(executor);
        lib.commitVerification(pkt, 500000);
        assertEq(IERC20(USDT).balanceOf(ATTACKER) - balBefore, 1e6, "unlock executed on fork");
        assertEq(tvlBefore - bridge.totalValueLockedSD(USDT), 1e6, "TVL decremented");

        // replay blocked
        vm.prank(executor);
        vm.expectRevert(LZ_ULN_Verifying.selector);
        lib.commitVerification(pkt, 500000);
    }

    function test_06_owner_cannot_take_principal() public {
        address owner = bridge.owner();
        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        bridge.withdrawFee(USDT, ATTACKER, 1);

        uint256 bal = IERC20(USDT).balanceOf(BRIDGE);
        uint256 tvl = bridge.totalValueLockedSD(USDT);
        uint256 fee = bridge.accruedFeeLD(USDT);
        assertEq(bal - tvl, fee, "fee = balance - TVL");
        vm.prank(owner);
        vm.expectRevert("OriginalTokenBridge: not enough fees collected");
        bridge.withdrawFee(USDT, owner, fee + 1);
    }
}
