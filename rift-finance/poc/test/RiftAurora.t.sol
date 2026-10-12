// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IRiftVault, IRiftCore, IERC20 } from "../src/RiftInterfaces.sol";

/// @notice Aurora-side PoC (v1 vaults, April 2022). Two facts are proven on a live fork:
///   1. deposits are OPEN (no whitelist / no depositsEnabled gate in v1) — anyone can push funds in;
///   2. there is NO unprivileged way to get value out: nextEpoch is strategist-only, claims need an
///      existing position, and fresh depositors cannot withdraw in the same epoch (locked).
/// Read-only fork test: no live-chain transactions.
contract RiftAuroraGatesTest is Test {
    address constant CORE = 0x40A01A4064b690cA33FA52d315ec02015eF5287E;
    address constant WNEAR = 0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d;
    address constant PAD = 0x885f8CF6E45bdd3fdcDc644efdcd0AC93880c781;
    address constant FEE_TO = 0x4f41Aac8B882362248f9271D95641592297c01E1;
    address constant ATTACKER = address(0xA11CE);

    address constant V_E914 = 0xe914B3E4adf87DBF5ff35895f8aEf5B169f82c9a; // WNEAR/PAD  (open, funded)
    address constant V_B311 = 0xB31142aFf04cf4cE4f5fdc5458B03A93db274Ad4; // WNEAR/PLY  (open, funded)
    address constant V_D51C = 0xd51ccf4208D36D13fEDC5F6a729DB69138dcf04F; // WNEAR/BSTN (open, funded)
    address constant V_5A99 = 0x5a999FEd5BD99f8a6a30CB1D411f689390514A61; // WNEAR/FLX  (fees accrued)
    address constant V_8EF6 = 0x8EF6069046Af6fd9043f22b2633FcFF38991E5B4; // WNEAR/WANNA
    address constant V_2C72 = 0x2C72bE54f04cBbbF816a87530ae2ed878BB04455; // WNEAR/AURORA
    address constant V_C8DD = 0xC8DdC0ad618e8F293d773917738c065a0ED44384; // empty vault
    address constant V_51C6 = 0x51C6f3433e8fF88726c09950ADD24726c28264d3; // dust vault (1 WNEAR trapped)
    address constant V_40D2 = 0x40D23398d9D553C1406d44Ce020E15b702B308e4; // PAUSED vault

    function setUp() public {
        string[3] memory urls = [
            vm.envOr("AURORA_RPC_URL", string("https://mainnet.aurora.dev")),
            string("https://aurora.drpc.org"),
            string("https://1rpc.io/aurora")
        ];
        for (uint256 i = 0; i < urls.length; i++) {
            try vm.createSelectFork(urls[i]) {
                return;
            } catch {}
        }
        revert("AURORA_FORK_UNAVAILABLE");
    }

    function test_aurora_live_state() public view {
        assertGt(block.number, 200_000_000, "expected Aurora fork");
        assertEq(IRiftCore(CORE).paused(), false, "core unpaused");
        assertEq(IRiftCore(CORE).feeTo(), FEE_TO, "feeTo");
        // v1 vaults have no depositsEnabled getter: deposits are ungated
        (bool ok, ) = V_E914.staticcall(abi.encodeWithSignature("depositsEnabled()"));
        assertEq(ok, false, "v1 vault must NOT expose depositsEnabled");
        assertEq(IRiftVault(V_E914).paused(), false, "vault unpaused");
        assertEq(IRiftVault(V_40D2).paused(), true, "vault 40d2 must be PAUSED");
    }

    /// The attacker CAN deposit (open, ungated) — and the money is captured by the vault.
    function test_aurora_attacker_can_deposit_but_funds_are_trapped() public {
        IRiftVault v = IRiftVault(V_E914);
        uint256 amount = 10e24; // 10 WNEAR (24 decimals)

        deal(WNEAR, ATTACKER, amount);
        vm.startPrank(ATTACKER);
        IERC20(WNEAR).approve(V_E914, type(uint256).max);

        uint256 vaultBefore = IERC20(WNEAR).balanceOf(V_E914);
        v.depositToken0(amount); // succeeds: deposits are OPEN
        vm.stopPrank();

        assertEq(IERC20(WNEAR).balanceOf(V_E914) - vaultBefore, amount, "vault pulled the deposit");

        (uint256 dep, uint256 pend, uint256 claim) = v.token0Balance(ATTACKER);
        assertEq(dep, 0, "not deposited yet (queued request)");
        assertEq(pend, amount, "pending request in current epoch");
        assertEq(claim, 0, "nothing claimable");

        // no exit: same-epoch withdraw is impossible, claim impossible, nextEpoch strategist-only
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
        v.withdrawToken0(amount);
        vm.expectRevert(bytes("NO_CLAIM"));
        v.claimToken0();
        vm.expectRevert(bytes("NOT_STRATEGIST"));
        v.nextEpoch(0, 0);
        vm.stopPrank();
    }

    /// All value-moving entry points refuse a fresh attacker.
    function test_aurora_attacker_gates_revert() public {
        address[7] memory vs = [V_E914, V_B311, V_D51C, V_5A99, V_8EF6, V_2C72, V_C8DD];
        vm.startPrank(ATTACKER);
        for (uint256 i = 0; i < vs.length; i++) {
            IRiftVault v = IRiftVault(vs[i]);

            vm.expectRevert(bytes("NOT_STRATEGIST"));
            v.nextEpoch(0, 0);

            vm.expectRevert(bytes("NO_CLAIM"));
            v.claimToken0();

            vm.expectRevert(bytes("NO_CLAIM"));
            v.claimToken1();

            vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
            v.withdrawToken0(1);

            vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
            v.withdrawToken1(1);

            vm.expectRevert(bytes("NOT_PAUSER"));
            v.pause();

            vm.expectRevert(bytes("NOT_STRATEGIST"));
            v.setToken0Floor(1);

            address[] memory toks = new address[](1);
            toks[0] = WNEAR;
            uint256[] memory amts = new uint256[](1);
            amts[0] = 0;
            vm.expectRevert(bytes("NOT_GUARDIAN"));
            v.rescueTokens(toks, amts);
        }
        vm.stopPrank();
    }

    /// Paused vault refuses everything, including deposits.
    function test_aurora_paused_vault_is_frozen() public {
        IRiftVault v = IRiftVault(V_40D2);
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("PAUSED"));
        v.depositToken0(1);
        vm.expectRevert(bytes("PAUSED"));
        v.claimToken0();
        vm.expectRevert(bytes("NOT_STRATEGIST"));
        v.nextEpoch(0, 0);
        vm.stopPrank();
    }

    /// collectFees() is permissionless but pays the treasury (core.feeTo()), never the caller.
    function test_aurora_collectFees_pays_feeTo_only() public {
        IRiftVault v = IRiftVault(V_5A99);
        (uint256 f0, ) = v.feesAccrued();
        assertGt(f0, 0, "expected accrued fees on 5a99");
        address token0 = v.token0();

        uint256 feeToBefore = IERC20(token0).balanceOf(FEE_TO);
        uint256 attackerBefore = IERC20(token0).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        v.collectFees();

        assertEq(IERC20(token0).balanceOf(FEE_TO) - feeToBefore, f0, "fee reached the treasury");
        assertEq(IERC20(token0).balanceOf(ATTACKER), attackerBefore, "attacker got nothing");
    }

    /// Core admin surface unreachable.
    function test_aurora_core_admin_gates_revert() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IRiftCore(CORE).pause();
        vm.expectRevert();
        IRiftCore(CORE).setFeeTo(ATTACKER);
        address[] memory vs = new address[](1);
        vs[0] = ATTACKER;
        vm.expectRevert();
        IRiftCore(CORE).registerVaults(vs);
        vm.stopPrank();
    }
}
