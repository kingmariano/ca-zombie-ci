// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IVault, IERC20, IProxyAdmin, IExecutor} from "../src/Interfaces.sol";

/// @title Vessel Finance (Scroll) — external-unprivileged extraction PoC
/// @notice Read-only fork tests. NO real-chain transactions. Everything runs against a local
///         fork of Scroll (createSelectFork). Purpose: prove that every value-moving entry
///         point of the live VaultProxy is closed to an unprivileged attacker, quantify the
///         live state, and demonstrate the holder-only (self-service) withdrawal path.
contract VesselPoC is Test {
    // --- live Scroll mainnet addresses (verified on-chain 2026-10-12) ---
    address constant VAULT = 0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2;
    address constant IMPL = 0x8804201FD6C0aBBcB62C158e51978893aA47785c;
    address constant GOVERNANCE_ADMIN = 0x3c417EC088f19EA02Ac9853cd6c35Fb193c98Abe; // executor contract
    address constant PROXY_ADMIN = 0x6251b4291ae357e63D9665dC2ABcD958e7CEe742;
    address constant EXECUTOR = 0x3c417EC088f19EA02Ac9853cd6c35Fb193c98Abe;
    address constant SAFE = 0x9549F1d6428066BE58C315374676E9d244716d4F;
    address constant SNARK_VERIFIER = 0xF33De4cA77959061a17B0866d35c850249aCed7E;
    address constant OPERATOR2 = 0xB7bBcD40C51fdf99c7EBdb4b454640a055001Fc3; // last proof committer
    address constant EXIT_MANAGER = 0x5bef2A1fCf34911e0Eb7b02376d1aB1c85cecfAc;
    address constant ETH_PSEUDO = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant USDT = 0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df;
    address constant WBTC = 0x3C1BCa5a656e69edCD0D4E36BEbb3FcDAcA60Cf1;
    address constant SCR = 0xd29687c813D741E2F938F4aC377128810E217b1b;

    // accounts with live pendingWithdraw at fork time (last writes were 2026-08-03, vault dormant since)
    address constant HO_USER_SCR = 0x6Da57994F93693FAdDB7f4abB96B27A8924A3722; // 87.378 SCR
    address constant HO_USER2_SCR = 0x6935a5941Bd1A41bDEc7328c89731B49C551A79F; // 91.7419 SCR

    IVault vault = IVault(VAULT);
    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("SCROLL_RPC_URL", string("https://scroll-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        require(block.chainid == 534352, "not on Scroll fork");
        vm.deal(attacker, 100 ether);
    }

    // ------------------------------------------------------------------
    // 1) live state
    // ------------------------------------------------------------------
    function test_live_state_roles_and_impl() public view {
        assertEq(vault.adminAddress(), GOVERNANCE_ADMIN, "governance admin");
        bytes32 slot = vm.load(VAULT, bytes32(uint256(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)));
        assertEq(address(uint160(uint256(slot))), IMPL, "EIP-1967 impl");
        assertEq(vault.getSnarkVerifierAddress(), SNARK_VERIFIER, "snark verifier");
        assertEq(vault.getCircuitVersion(), "vessel-0.1.20", "circuit version");
        assertTrue(vault.isOperator(OPERATOR2), "operator2 live");
        assertTrue(vault.isOperator(0x570b2C710445091C95a2859cE282D16D4Cf1A257), "operator1 live");
        assertTrue(vault.isExitManager(EXIT_MANAGER), "exit manager live");
        assertGt(vault.lastCommitBatchId(), 4000, "proof batches committed historically");
        assertGt(SNARK_VERIFIER.code.length, 0, "verifier has code");
        assertEq(IProxyAdmin(PROXY_ADMIN).owner(), GOVERNANCE_ADMIN, "ProxyAdmin owner = executor");
    }

    function test_live_state_balances() public view {
        assertGt(VAULT.balance, 40 ether, "vault ETH");
        assertGt(IERC20(USDC).balanceOf(VAULT), 37_000e6, "vault USDC");
        assertGt(IERC20(USDT).balanceOf(VAULT), 39_000e6, "vault USDT");
        assertGt(IERC20(WBTC).balanceOf(VAULT), 0.08e8, "vault WBTC");
        assertGt(IERC20(SCR).balanceOf(VAULT), 15_000e18, "vault SCR");
        // 4 active assets + native
        assertEq(vault.extractAssetId(USDC), 1);
        assertEq(vault.extractAssetId(USDT), 2);
        assertEq(vault.extractAssetId(WBTC), 3);
        assertEq(vault.extractAssetId(SCR), 4);
    }

    // ------------------------------------------------------------------
    // 2) attacker paths — every value-moving entry point must revert
    // ------------------------------------------------------------------
    function test_attacker_withdraw_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Vault: not enough funds"));
        vault.withdraw(0, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(bytes("Vault: not enough funds"));
        vault.withdraw(1, 1e6);
    }

    function test_attacker_commitSnarkProof_reverts() public {
        uint256[] memory inst = new uint256[](0);
        bytes[] memory msgs = new bytes[](0);
        vm.prank(attacker);
        vm.expectRevert(bytes("Gov: caller is not an operator"));
        vault.commitSnarkProof(inst, "", 0, msgs, 0, 0);
    }

    function test_attacker_fastWithdraw_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Gov: caller is not an exit manager."));
        vault.fastWithdraw(attacker, attacker, ETH_PSEUDO, 1 ether, 0, 1, block.timestamp + 1, 27, bytes32(0), bytes32(0));
    }

    function test_attacker_admin_functions_revert() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Gov: caller is not the admin"));
        vault.transferAdmin(attacker);
        vm.expectRevert(bytes("Gov: caller is not the admin"));
        vault.updateAll(attacker, "pwn");
        vm.expectRevert(bytes("Gov: caller is not the admin"));
        vault.updateSnarkVerifierAddress(attacker);
        vm.expectRevert(bytes("Gov: caller is not the admin"));
        vault.setWethAddress(attacker);
        vm.expectRevert(bytes("Gov: caller is not an operator"));
        vault.registerNewAsset(attacker, 9, 10, 8, 18);
        vm.expectRevert(bytes("Gov: caller is not an operator"));
        vault.setAssetActive(5);
        vm.expectRevert(bytes("Gov: caller is not an operator"));
        vault.setAssetInactive(4);
        vm.stopPrank();
    }

    function test_initialize_locked() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        vault.initialize(attacker);
    }

    function test_registerUser_fake_operator_reverts() public {
        bytes memory key = new bytes(64);
        vm.prank(attacker);
        vm.expectRevert(bytes("Users: invalid operator address"));
        vault.checkAndRegisterUser(key, attacker, 27, bytes32(uint256(1)), bytes32(uint256(1)));
    }

    function test_deposit_unregistered_key_reverts() public {
        bytes memory key = new bytes(64);
        vm.prank(attacker);
        vm.expectRevert(bytes("Users: vesselKey not registered to user address"));
        vault.depositNative{value: 1 ether}(key);
    }

    function test_proxyAdmin_upgrade_reverts_for_attacker() public {
        vm.prank(attacker);
        vm.expectRevert();
        IProxyAdmin(PROXY_ADMIN).upgradeTo(attacker);

        vm.prank(attacker);
        vm.expectRevert();
        IProxyAdmin(PROXY_ADMIN).upgradeAndCall(attacker, "");
    }

    function test_executor_execute_reverts_for_attacker() public {
        bytes memory inner = abi.encodeWithSignature("transferAdmin(address)", attacker);
        vm.prank(attacker);
        vm.expectRevert(); // AccessControl: missing role 0x00..0 (DEFAULT_ADMIN_ROLE)
        IExecutor(EXECUTOR).execute(VAULT, 0, inner, bytes32(0));
    }

    // ------------------------------------------------------------------
    // 3) full attack matrix — balances must be unchanged afterwards
    // ------------------------------------------------------------------
    function test_balances_unchanged_after_attack_matrix() public {
        uint256 eth0 = VAULT.balance;
        uint256 usdc0 = IERC20(USDC).balanceOf(VAULT);
        uint256 usdt0 = IERC20(USDT).balanceOf(VAULT);
        uint256 wbtc0 = IERC20(WBTC).balanceOf(VAULT);
        uint256 scr0 = IERC20(SCR).balanceOf(VAULT);

        vm.startPrank(attacker);
        _mustFail(VAULT, abi.encodeWithSignature("withdraw(uint256,uint256)", 0, 1 ether));
        _mustFail(VAULT, abi.encodeWithSignature("withdraw(uint256,uint256)", 4, 1e18));
        _mustFail(VAULT, abi.encodeWithSignature("withdrawAll(uint256)", 4));
        _mustFail(VAULT, abi.encodeWithSignature("commitSnarkProof(uint256[],bytes,uint256,bytes[],uint256,uint256)", new uint256[](0), "", 0, new bytes[](0), 0, 0));
        _mustFail(VAULT, abi.encodeWithSignature("fastWithdraw(address,address,address,uint256,uint256,uint256,uint256,uint8,bytes32,bytes32)",
            attacker, attacker, ETH_PSEUDO, 1 ether, 0, 1, block.timestamp + 1, 27, bytes32(0), bytes32(0)));
        _mustFail(VAULT, abi.encodeWithSignature("transferAdmin(address)", attacker));
        _mustFail(VAULT, abi.encodeWithSignature("registerNewAsset(address,uint256,uint8,uint8,uint8)", attacker, 9, 10, 8, 18));
        _mustFail(VAULT, abi.encodeWithSignature("updateAll(address,string)", attacker, "pwn"));
        _mustFail(VAULT, abi.encodeWithSignature("initialize(address)", attacker));
        _mustFail(PROXY_ADMIN, abi.encodeWithSignature("upgradeTo(address)", attacker));
        _mustFail(EXECUTOR, abi.encodeWithSignature("execute(address,uint256,bytes,bytes32)", VAULT, 0, abi.encodeWithSignature("transferAdmin(address)", attacker), bytes32(0)));
        vm.stopPrank();

        assertEq(VAULT.balance, eth0, "ETH unchanged");
        assertEq(IERC20(USDC).balanceOf(VAULT), usdc0, "USDC unchanged");
        assertEq(IERC20(USDT).balanceOf(VAULT), usdt0, "USDT unchanged");
        assertEq(IERC20(WBTC).balanceOf(VAULT), wbtc0, "WBTC unchanged");
        assertEq(IERC20(SCR).balanceOf(VAULT), scr0, "SCR unchanged");
        assertEq(attacker.balance, 100 ether, "attacker ETH unchanged");
    }

    function _mustFail(address target, bytes memory data) internal {
        (bool ok,) = target.call(data);
        assertFalse(ok, "attack path unexpectedly succeeded");
    }

    // ------------------------------------------------------------------
    // 4) holder-only (H-O) self-service path + known withdrawAll quirk
    // ------------------------------------------------------------------
    function test_HO_selfservice_withdraw_works() public {
        uint256 amt = vault.getPendingWithdraw(HO_USER_SCR, 4);
        assertGt(amt, 0, "expected live pendingWithdraw for HO user");
        uint256 bal0 = IERC20(SCR).balanceOf(HO_USER_SCR);
        vm.prank(HO_USER_SCR);
        vault.withdraw(4, amt);
        assertEq(IERC20(SCR).balanceOf(HO_USER_SCR), bal0 + amt, "withdraw paid out");
        assertEq(vault.getPendingWithdraw(HO_USER_SCR, 4), 0, "claim consumed");
    }

    function test_withdrawAll_nested_reentrancy_quirk() public {
        uint256 amt = vault.getPendingWithdraw(HO_USER2_SCR, 4);
        assertGt(amt, 0, "expected live pendingWithdraw for HO user2");
        vm.prank(HO_USER2_SCR);
        vm.expectRevert(bytes("ReentrancyGuard: reentrant call"));
        vault.withdrawAll(4); // withdrawAll -> withdraw() hits its own nonReentrant guard
    }
}
