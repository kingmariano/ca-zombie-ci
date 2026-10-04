// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    IERC20, IVoting, IGovernor, IAgglayerBridge, ITokenWrapped
} from "../src/Interfaces.sol";

/// @title  Orbit Chain / Silicon Network — live unprivileged-extraction PoC (fork-only)
/// @notice Read-only campaign: these tests run on local forks of Silicon L2 and Ethereum.
///         No mainnet transaction is ever signed or sent.
contract OrbitSiliconTest is Test {
    // ---- Silicon L2 (chain id 2355) ----
    address constant VOTING   = 0x33fa9a4f2C06de9bD80A34663C72C797E257D3d9;
    address constant GOVERNOR = 0x3d0FD4bB3eA78657727eD7d20d9195288EaBC7dF;
    address constant ORC      = 0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260; // bridge-wrapped ORC (canonical)
    address constant L2_BRIDGE= 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

    // ---- Ethereum mainnet ----
    address constant L1_BRIDGE= 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe; // AgglayerBridge proxy
    address constant USDC     = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT     = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC     = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // ---- Actors ----
    address constant ATTACKER = address(0xA11CE);
    address constant STAKER   = 0xa287467261637115051391712d292e790bCaABca; // registered voter
    address constant DV       = 0xe355566d2b5C654b0A08cf4d40d35DE20C38DCc2; // delegated voter (validator)

    uint256 siliconFork;
    uint256 ethFork;

    function setUp() public {
        siliconFork = vm.createFork(vm.envOr("SILICON_RPC_URL", string("https://rpc.silicon.network")));
        ethFork = vm.createFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
    }

    // ------------------------------------------------------------------
    // A. Silicon L2 — live state
    // ------------------------------------------------------------------

    function test_A1_l2_live_state() public {
        vm.selectFork(siliconFork);
        assertGt(block.number, 21_000_000, "Silicon is producing blocks");
        assertGt(block.timestamp, 1_790_000_000, "block time is current (Oct 2026)");

        IAgglayerBridge bridge = IAgglayerBridge(L2_BRIDGE);
        assertEq(bridge.networkID(), 10, "Silicon bridge networkID");
        assertFalse(bridge.isEmergencyState(), "L2 bridge not in emergency state");
        assertEq(bridge.getTokenWrappedAddress(0, 0x662b67d00A13FAf93254714DD601F5Ed49Ef2F51), ORC,
                 "wrapped ORC is a canonical bridged token");

        IVoting v = IVoting(VOTING);
        assertEq(v.stakingToken(), ORC);
        assertEq(v.rewardToken(), ORC);
        assertGt(v.totalStaking(), 30_000_000e18, "ORC staked");
        assertGt(v.lockupPeriod(), 0);
        assertTrue(v.isVoter(STAKER));
        assertGt(v.votingAmount(DV, STAKER), 100e18, "staker has stake delegated to DV");
    }

    // ------------------------------------------------------------------
    // B. Governance — attacker cannot take ORC
    // ------------------------------------------------------------------

    /// @dev `unvoting(address account,uint256 amount)` checks the CALLER's own
    ///      delegated stake; an attacker with zero stake reverts.
    function test_B1_attacker_cannot_unvote_victim() public {
        vm.selectFork(siliconFork);
        vm.prank(ATTACKER);
        vm.expectRevert("amount is too big");
        IVoting(VOTING).unvoting(DV, 1e18);
    }

    /// @dev `claimUnvoting()` processes only msg.sender's own pending queue.
    function test_B2_attacker_cannot_claim_unvoting() public {
        vm.selectFork(siliconFork);
        vm.prank(ATTACKER);
        vm.expectRevert("all claimed");
        IVoting(VOTING).claimUnvoting();
    }

    /// @dev Governor admin paths (incl. emergencyTransfer) are owner-gated
    ///      (owner = 2-of-4 multisig via the proxy admin).
    function test_B3_attacker_cannot_emergency_transfer() public {
        vm.selectFork(siliconFork);
        vm.prank(ATTACKER);
        vm.expectRevert("not owner");
        IGovernor(GOVERNOR).emergencyTransfer(ORC, ATTACKER, 1);
    }

    function test_B4_attacker_cannot_execute_governor() public {
        vm.selectFork(siliconFork);
        vm.prank(ATTACKER);
        vm.expectRevert("not owner");
        IGovernor(GOVERNOR).execute(0);
    }

    /// @dev Bridge-wrapped ORC can only be minted/burned by the canonical L2 bridge.
    function test_B5_attacker_cannot_mint_orc() public {
        vm.selectFork(siliconFork);
        vm.prank(ATTACKER);
        vm.expectRevert();
        ITokenWrapped(ORC).mint(ATTACKER, 1e18);
    }

    // ------------------------------------------------------------------
    // C. Holder exit path works (H-O) — self-service unvote + claim
    // ------------------------------------------------------------------

    /// @dev The sedaily claim "no UNVOTE path" is a front-end gap: the contract
    ///      exposes unvoting() and claimUnvoting(). This test proves the full
    ///      lifecycle for a real staker on a fork.
    function test_C1_holder_unvote_claim_lifecycle() public {
        vm.selectFork(siliconFork);
        IVoting v = IVoting(VOTING);
        uint256 amount = 100e18;

        uint256 balBefore = IERC20(ORC).balanceOf(STAKER);
        uint256 pendingBefore = v.getPendingAmount(STAKER);

        vm.prank(STAKER);
        v.unvoting(DV, amount);
        assertEq(v.getPendingAmount(STAKER), pendingBefore + amount, "unvote recorded as pending");

        // lockup elapses
        vm.warp(block.timestamp + v.lockupPeriod() + 1);

        vm.prank(STAKER);
        v.claimUnvoting();

        assertGe(IERC20(ORC).balanceOf(STAKER), balBefore + amount, "ORC returned to holder");
    }

    /// @dev distribute() is permissionless but pays the caller nothing.
    function test_C2_distribute_permissionless_no_profit() public {
        vm.selectFork(siliconFork);
        uint256 before = IERC20(ORC).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (bool ok,) = VOTING.call(abi.encodeWithSelector(IVoting.distribute.selector));
        ok; // may revert when nothing to distribute; either way no profit
        assertEq(IERC20(ORC).balanceOf(ATTACKER), before, "attacker gained nothing");
    }

    // ------------------------------------------------------------------
    // D. Canonical bridge — forged claims are impossible without a valid GER
    // ------------------------------------------------------------------

    function test_D1_l1_bridge_live_and_not_emergency() public {
        vm.selectFork(ethFork);
        IAgglayerBridge bridge = IAgglayerBridge(L1_BRIDGE);
        assertFalse(bridge.isEmergencyState(), "L1 bridge not in emergency state");
        assertGt(IERC20(USDC).balanceOf(L1_BRIDGE), 1_000_000e6, "shared L1 bridge holds USDC");
        assertGt(IERC20(USDT).balanceOf(L1_BRIDGE), 1_000_000e6, "shared L1 bridge holds USDT");
        assertGt(IERC20(WBTC).balanceOf(L1_BRIDGE), 10e8, "shared L1 bridge holds WBTC");
        assertGt(L1_BRIDGE.balance, 1_000 ether, "shared L1 bridge holds ETH");
    }

    /// @dev Forged claim against the L1 AgglayerBridge: zero proofs and an
    ///      unknown global exit root must revert (GlobalExitRootInvalid).
    function test_D2_l1_forged_claim_reverts() public {
        vm.selectFork(ethFork);
        bytes32[32] memory p1;
        bytes32[32] memory p2;
        vm.prank(ATTACKER);
        vm.expectRevert();
        IAgglayerBridge(L1_BRIDGE).claimAsset(
            p1, p2,
            0,            // globalIndex
            bytes32(0),   // mainnetExitRoot
            bytes32(0),   // rollupExitRoot
            0,            // originNetwork (mainnet)
            address(0),   // originTokenAddress = ETH
            0,            // destinationNetwork = mainnet
            ATTACKER,
            1e18,
            ""
        );
    }

    /// @dev Same forged claim on the L2 bridge (destinationNetwork = 10).
    function test_D3_l2_forged_claim_reverts() public {
        vm.selectFork(siliconFork);
        bytes32[32] memory p1;
        bytes32[32] memory p2;
        vm.prank(ATTACKER);
        vm.expectRevert();
        IAgglayerBridge(L2_BRIDGE).claimAsset(
            p1, p2,
            0,
            bytes32(0),
            bytes32(0),
            0,
            address(0),
            10,           // Silicon
            ATTACKER,
            1e18,
            ""
        );
    }
}
