// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Stakehouse (Blockswap) L2 Phase-2 deep dive — read-only fork PoC
// Target: can an external unprivileged attacker extract ETH from the live
// Stakehouse protocol?  AccountManager holds 64.3057 ETH at block 26,178,656.
// All tests are fork simulations; no mainnet transactions are ever sent.
// ---------------------------------------------------------------------------

struct ETH2DataReport {
    bytes blsPublicKey;
    bytes withdrawalCredentials;
    bool slashed;
    uint64 activeBalance;
    uint64 effectiveBalance;
    uint64 exitEpoch;
    uint64 activationEpoch;
    uint64 withdrawalEpoch;
    uint64 currentCheckpointEpoch;
}

struct Sweep {
    uint256 withdrawalIndex;
    uint256 validatorIndex;
    address recipient;
    uint256 amount;
}

struct SweepWithSlotInfo {
    Sweep sweep;
    uint256 slot;
    uint256 blockNumber;
}

struct VerifierSignature {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct ShanghaiReport {
    address stakeHouse;
    bytes blsPublicKey;
    uint256 totalETHSentToBLSKey;
    uint256 sumOfAllSweeps;
    Sweep[] sweeps;
}

interface IAccountManager {
    function withdrawETH(address, uint256) external;
    function rageQuitKnot(address, bytes calldata, address, uint256, ETH2DataReport calldata) external;
    function markKnotAsWithdrawn(address, bytes calldata) external;
    function setLifecycleExited(bytes calldata) external;
    function updateAccountState(bytes calldata, ETH2DataReport calldata) external;
    function updateExitEpochFromReport(bytes calldata, uint64) external;
    function updateKnotActiveBalanceFromReport(bytes calldata, uint64, uint64) external;
    function updateSlashedIsTrueFromReport(bytes calldata, uint64) external;
    function registerValidatorInitials(address, bytes calldata, bytes calldata) external;
    function blsPublicKeyToLifecycleStatus(bytes calldata) external view returns (uint8);
    function numberOfAccounts() external view returns (uint256);
}

interface IFullWithdrawals {
    function reportFinalSweepAndWithdraw(
        uint256,
        bytes calldata,
        Sweep[] calldata,
        SweepWithSlotInfo calldata,
        ETH2DataReport calldata,
        VerifierSignature calldata
    ) external;
    function isFullSweepReported(uint256) external view returns (bool);
    function isDesignatedVerifier(address) external view returns (bool);
    function sweepReportingContract() external view returns (address);
}

interface ISweepReporting {
    function reportSweeps(
        ShanghaiReport calldata,
        VerifierSignature calldata,
        ETH2DataReport calldata
    ) external returns (uint256);
    function reportAndWithdrawETH(
        bool,
        ShanghaiReport calldata,
        VerifierSignature calldata,
        ETH2DataReport calldata
    ) external;
    function totalReportedETHNotWithdrawn(bytes calldata) external view returns (uint256);
    function totalETHSentToBlsPublicKey(bytes calldata) external view returns (uint256);
    function isDesignatedVerifier(address) external view returns (bool);
}

interface ISlotRegistry {
    function userWithdrawn(address, bytes calldata) external view returns (bool);
    function isUserEnabledForKnotWithdrawal(address, bytes calldata) external view returns (bool);
}

interface IOwnableSmartWallet {
    function owner() external view returns (address);
}

contract StakehousePoC is Test {
    // --- live addresses (Ethereum mainnet) ---
    address constant AM = 0xDd6E67942a9566A70446f7400a21240C5f71377C; // AccountManager proxy
    address constant TR = 0x03F4310bfE3968934bC11DfA17B8DF809D7DEA80; // TransactionRouter proxy
    address constant SLOTREG = 0xC01DC3c7F83B12CFdF6C0AAa09c880EB45c48569; // SLOTRegistry proxy
    address constant SWEEPR = 0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0; // ShanghaiSweepReporting proxy
    address constant FW = 0x8F6839b0AcD8d7c7d2f01C1C7ECCa982Ca354333; // FullWithdrawals proxy
    address constant VERIFIER = 0x9785f8E50229Ebd2b3788452ABc31d1942394e0C; // designated verifier (EOA, nonce 0)
    address constant ATTACKER = 0x000000000000000000000000000000000000dEaD;

    // knot 78: validator 1,109,420 — full sweep 32.005324832 ETH to AM on 2024-08-08 (block 20482055), never claimed
    bytes constant KEY78 =
        hex"97d7b76dd71e01d3d0f6aeb9f7c329e956b75ebc51537f188dbe79fc0f4c9636aafc899e8001f331fa61ac00c9247ec7";
    address constant KNOT78_USER = 0xDdB50FfDbA4D89354E1088e4EA402de895562173; // enabled=1, withdrawn=0
    // knot 44: validator 747,994 — full sweep 31.086158519 ETH to AM on 2025-11-04 (block 23726929), never claimed
    bytes constant KEY44 =
        hex"8f691a275f2a741ea851897ad9833810237a25c9b200637c2970a232fcff0d3e06562bba4a154d0cb1742fccf859b9ad";
    address constant KNOT44_WALLET = 0x246269f844D538f02974E54c71c87A7E63C82A68;
    address constant KNOT44_OWNER = 0x831138EE43B1f230C0769A23E341E570eEAC9452;

    uint256 constant FORK_BLOCK = 26_178_656;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        // Prefer the pinned block for reproducibility; fall back to latest if the RPC is not archival.
        try vm.createSelectFork(rpc, FORK_BLOCK) {} catch {
            vm.createSelectFork(rpc);
        }
    }

    // ------------------------------------------------------------------
    // 1. AccountManager: every ETH-moving function is "Only core"
    // ------------------------------------------------------------------
    function test_01_accountManager_direct_calls_revert_only_core() public {
        ETH2DataReport memory rep;
        rep.blsPublicKey = KEY78;
        rep.withdrawalCredentials = hex"010000000000000000000000dd6e67942a9566a70446f7400a21240c5f71377c";
        rep.activeBalance = 32e9;

        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).withdrawETH(ATTACKER, 1 ether);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).rageQuitKnot(ATTACKER, KEY78, address(0), 0, rep);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).markKnotAsWithdrawn(ATTACKER, KEY78);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).setLifecycleExited(KEY78);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).updateAccountState(KEY78, rep);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).updateExitEpochFromReport(KEY78, 301_323);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).updateKnotActiveBalanceFromReport(KEY78, 32e9, 0);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).updateSlashedIsTrueFromReport(KEY78, 1);

        vm.expectRevert(bytes("Only core"));
        IAccountManager(AM).registerValidatorInitials(ATTACKER, KEY78, hex"1234");
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // 2. The AccountManager *does* pay when a core module instructs it.
    //    => the only gate on the vault is core-module status; no
    //       permissionless function anywhere pays the caller.
    // ------------------------------------------------------------------
    function test_02_accountManager_pays_when_called_by_core_module() public {
        uint256 before = ATTACKER.balance;
        vm.prank(FW); // impersonate a live core module (FullWithdrawals)
        IAccountManager(AM).withdrawETH(ATTACKER, 1 ether);
        assertEq(ATTACKER.balance, before + 1 ether, "core module can move ETH out");
    }

    // ------------------------------------------------------------------
    // 3. FullWithdrawals claim path: attacker call reverts at validation
    //    (report must match on-chain beacon state; verifier ECDSA sig
    //    required after that — see bytecode strings "Signature expired",
    //    "ECDSA: invalid signature", "Not rage quit").
    // ------------------------------------------------------------------
    function test_03_fullWithdrawals_attacker_call_reverts() public {
        Sweep[] memory unreported = new Sweep[](0);
        SweepWithSlotInfo memory fs = SweepWithSlotInfo({
            sweep: Sweep({withdrawalIndex: 54_109_538, validatorIndex: 1_109_420, recipient: AM, amount: 32_005_324_832}),
            slot: 0,
            blockNumber: 0
        });
        ETH2DataReport memory rep;
        rep.blsPublicKey = KEY78;
        rep.withdrawalCredentials = hex"010000000000000000000000dd6e67942a9566a70446f7400a21240c5f71377c";
        rep.activeBalance = 32e9;
        rep.effectiveBalance = 32e9;
        rep.exitEpoch = 301_323;
        rep.withdrawalEpoch = 301_579;
        VerifierSignature memory sig = VerifierSignature({deadline: 9_999_999_999, v: 27, r: bytes32(uint256(1)), s: bytes32(uint256(1))});

        vm.prank(ATTACKER);
        vm.expectRevert(); // live revert: "Active balance" (report validation precedes payment)
        IFullWithdrawals(FW).reportFinalSweepAndWithdraw(32e18, KEY78, unreported, fs, rep, sig);
    }

    // ------------------------------------------------------------------
    // 4. ShanghaiSweepReporting: attacker call reverts (report validation;
    //    verifier signature required for any report/withdrawal).
    // ------------------------------------------------------------------
    function test_04_sweepReporting_attacker_call_reverts() public {
        ShanghaiReport memory rpt;
        rpt.blsPublicKey = KEY78;
        rpt.totalETHSentToBLSKey = 32e18;
        rpt.sumOfAllSweeps = 1e9;
        Sweep[] memory sw = new Sweep[](1);
        sw[0] = Sweep({withdrawalIndex: 999_999_999, validatorIndex: 1_109_420, recipient: AM, amount: 1e9});
        rpt.sweeps = sw;

        ETH2DataReport memory rep;
        rep.blsPublicKey = KEY78;
        rep.withdrawalCredentials = hex"010000000000000000000000dd6e67942a9566a70446f7400a21240c5f71377c";
        rep.activeBalance = 32e9;
        rep.effectiveBalance = 32e9;
        rep.exitEpoch = 301_323;
        VerifierSignature memory sig = VerifierSignature({deadline: 9_999_999_999, v: 27, r: bytes32(uint256(1)), s: bytes32(uint256(1))});

        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("Invalid Report"));
        ISweepReporting(SWEEPR).reportSweeps(rpt, sig, rep);

        ShanghaiReport memory empty;
        empty.blsPublicKey = KEY78;
        vm.expectRevert(bytes("Zero sweeps"));
        ISweepReporting(SWEEPR).reportAndWithdrawETH(false, empty, sig, rep);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // 5. Live state of the two unclaimed full sweeps (the 64.3057 ETH)
    // ------------------------------------------------------------------
    function test_05_live_state_two_unclaimed_sweeps() public {
        // AccountManager holds exactly the two orphaned full sweeps + legacy dust
        uint256 amBal = AM.balance;
        console2.log("AccountManager ETH:", amBal);
        assertEq(amBal, 64.305717944108928421 ether, "AM balance at pinned block");

        // knot 78 (32.005 ETH): user IS enabled for withdrawal, has NOT withdrawn
        assertTrue(ISlotRegistry(SLOTREG).isUserEnabledForKnotWithdrawal(KNOT78_USER, KEY78), "knot78 enabled");
        assertFalse(ISlotRegistry(SLOTREG).userWithdrawn(KNOT78_USER, KEY78), "knot78 not yet withdrawn");
        assertEq(IAccountManager(AM).blsPublicKeyToLifecycleStatus(KEY78), 4, "knot78 EXITED");
        assertFalse(IFullWithdrawals(FW).isFullSweepReported(1_109_420), "knot78 final sweep unreported");

        // knot 44 (31.086 ETH): NOT enabled - a rage quit must happen first
        assertFalse(ISlotRegistry(SLOTREG).isUserEnabledForKnotWithdrawal(KNOT44_WALLET, KEY44), "knot44 not enabled");
        assertEq(IAccountManager(AM).blsPublicKeyToLifecycleStatus(KEY44), 3, "knot44 TOKENS_MINTED");
        assertFalse(IFullWithdrawals(FW).isFullSweepReported(747_994), "knot44 final sweep unreported");

        // knot44's smart wallet is owned by an operator EOA, not by anyone else
        assertEq(IOwnableSmartWallet(KNOT44_WALLET).owner(), KNOT44_OWNER, "knot44 wallet owner");
        assertTrue(KNOT44_OWNER != ATTACKER, "attacker is not the owner");

        // designated verifier: live in state, EOA (no code), never sent a tx (nonce 0)
        assertTrue(IFullWithdrawals(FW).isDesignatedVerifier(VERIFIER), "verifier enabled");
        assertTrue(ISweepReporting(SWEEPR).isDesignatedVerifier(VERIFIER), "verifier enabled on sweeps");
        assertEq(VERIFIER.code.length, 0, "verifier is EOA");
        assertEq(vm.getNonce(VERIFIER), 0, "verifier never sent a tx (off-chain signer only)");
        assertEq(IFullWithdrawals(FW).sweepReportingContract(), SWEEPR, "linked sweep reporter");
    }

    // ------------------------------------------------------------------
    // 6. The two sweep reports that WOULD unlock the money are the only
    //    missing pieces; verify reported-not-withdrawn is stale for
    //    already-claimed knots (knot 81 claimed 32.0657 = 32 + its
    //    reported 0.0657 at block 19,626,256, yet the counter persists).
    // ------------------------------------------------------------------
    function test_06_reported_counter_and_claim_history() public {
        bytes memory KEY81 =
            hex"aaf3621b11d18f645ae063051b31642232029b3ccbf3bb41b184785b701a5ee2ee0b06aa9da212926138a1fb98c214a9";
        assertEq(ISweepReporting(SWEEPR).totalReportedETHNotWithdrawn(KEY81), 65_709_911_000_000_000, "stale reported counter");
        // knot 81 already fully withdrew (FullWithdrawalExecuted 32.065710 at block 19,626,256)
        assertTrue(ISlotRegistry(SLOTREG).userWithdrawn(0x4553e3Bc6327006A63C5aA4cdAC887f66b6A433E, KEY81), "knot81 withdrawn");
        // => the 21.37 ETH "reportedNotWithdrawn" sum is NOT a separate live pot
    }
}
