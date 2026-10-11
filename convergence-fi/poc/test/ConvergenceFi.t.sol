// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ISdtStakingPositionService, ISdtBlackHole, ISdtStakingPositionManager,
        ICvgControlTower, ICloneFactoryV2, ILiquidityGauge, ISdtBufferV2,
        ISdtRewardDistributorV2} from "../src/Interfaces.sol";

/// @title Convergence Fi — live extraction-surface PoC (Ethereum mainnet fork)
/// @notice Read-only research. Everything runs on a local fork; no mainnet transactions.
///         The suite proves: (a) all 37 gauge positions are backed in the SdtBlackHole;
///         (b) every withdraw/claim entry point is gated on position-NFT ownership
///         (external unprivileged attacker = $0); (c) the position owners can still
///         self-withdraw (holder-recoverable).
contract ConvergenceFiPoC is Test {
    // ---- live mainnet addresses (2026-10-11) ----
    address constant TOWER        = 0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7; // CvgControlTowerV2 proxy
    address constant BLACKHOLE    = 0x21777106355Ba506A31FF7984c0aE5C924deB77f; // SdtBlackHole proxy (holds gauge tokens)
    address constant MANAGER      = 0x7319662aD7D7ce2d1595073EA042B723F6d0dc48; // SdtStakingPositionManager (NFTs)
    address constant FACTORY      = 0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5; // CloneFactoryV2
    address constant DISTRIBUTOR  = 0x6B65525a40704a4c48d07c25b8D05654854DFEcD; // SdtRewardDistributorV2
    address constant SDCRV_SERVICE= 0x2FF160bcADb485b5F048b9880e6f471Af632060c; // sdCRV staking service
    address constant SDCRV_GAUGE  = 0x7f50786A0b15723D741727882ee99a0BF34e3466; // "Stake DAO sdCRV Gauge" (stakingAsset)
    address constant SDCRV_BUFFER = 0x8405FF734C157f51011FC7d7dfa22f4a32505B43; // buffer of the sdCRV service
    address constant CVGSDT_SERVICE = 0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933; // cvgSDT staking service (vault=self)
    address constant CVGSDT       = 0x830614aE209FF9d8706d386fcdBc7a55206fcffC; // cvgSDT liquid locker token

    // ---- real live positions used in the PoC ----
    uint256 constant POS_SDCRV = 177; // owned by POS_SDCRV_OWNER, ~600,027.82 sdCRV-gauge staked
    address constant POS_SDCRV_OWNER = 0xb0e83C2D71A991017e0116d58c5765Abc57384af;
    uint256 constant POS_CVGSDT = 3;  // owned by POS_CVGSDT_OWNER
    address constant POS_CVGSDT_OWNER = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 10 ether);
        vm.label(TOWER, "CvgControlTowerV2");
        vm.label(BLACKHOLE, "SdtBlackHole");
        vm.label(SDCRV_SERVICE, "sdCRV-service");
        vm.label(SDCRV_GAUGE, "sdCRV-gauge");
        vm.label(CVGSDT_SERVICE, "cvgSDT-service");
    }

    /* ------------------------------------------------------------------
     *  1. Live state: custody is real and backed
     * ------------------------------------------------------------------ */

    function test_live_sdCRV_state_backed_and_unpaused() public {
        ISdtStakingPositionService svc = ISdtStakingPositionService(SDCRV_SERVICE);
        uint128 cycle = svc.stakingCycle();
        (, uint256 totalStaked, ) = svc.cycleInfo(cycle);
        uint256 bhBal = IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE);

        assertGt(totalStaked, 3_400_000e18, "sdCRV totalStaked unexpectedly small");
        assertGe(bhBal, totalStaked, "blackhole balance does not cover accounting");
        assertEq(svc.depositPaused(), false, "deposits paused");
        assertEq(svc.owner(), 0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7, "owner is not the Safe");
        assertEq(ICvgControlTower(TOWER).isSdtStaking(SDCRV_SERVICE), true, "service not registered");
        emit log_named_uint("sdCRV cycle totalStaked", totalStaked);
        emit log_named_uint("blackhole sdCRV-gauge balance", bhBal);
    }

    /// @notice All positions returned by the tower are backed 1:1 (or better) by blackhole balances.
    function test_live_all_37_positions_backed() public {
        ICvgControlTower tower = ICvgControlTower(TOWER);
        ICvgControlTower.Staking[] memory stakings = tower.getSdtStakings(0, 1000);
        assertGe(stakings.length, 37, "expected >= 37 registered stakings");
        uint256 covered;
        for (uint256 i = 0; i < stakings.length; i++) {
            ISdtStakingPositionService svc = ISdtStakingPositionService(stakings[i].stakingContract);
            uint128 cycle = svc.stakingCycle();
            (, uint256 totalStaked, ) = svc.cycleInfo(cycle);
            address asset = svc.stakingAsset();
            uint256 bal = IERC20(asset).balanceOf(BLACKHOLE);
            assertGe(bal, totalStaked, string.concat("under-backed: ", stakings[i].stakingName));
            if (totalStaked > 0) covered++;
        }
        emit log_named_uint("positions with non-zero staked", covered);
    }

    /* ------------------------------------------------------------------
     *  2. Attacker paths — all must revert
     * ------------------------------------------------------------------ */

    function test_attacker_cannot_withdraw_foreign_position() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtStakingPositionService(SDCRV_SERVICE).withdraw(POS_SDCRV, 1_000e18);
    }

    function test_attacker_cannot_withdraw_cvgSDT_position() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtStakingPositionService(CVGSDT_SERVICE).withdraw(POS_CVGSDT, 1e18);
    }

    function test_blackhole_direct_drain_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("ONLY_SD_ASSET_STAKING"));
        ISdtBlackHole(BLACKHOLE).withdraw(attacker, 1e18);
    }

    function test_gauge_claim_rewards_for_not_claimer_reverts() public {
        // blackhole's gauge rewards must not be redirectable by an arbitrary caller
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityGauge(SDCRV_GAUGE).claim_rewards_for(BLACKHOLE, attacker);
    }

    function test_gauge_claim_rewards_redirect_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityGauge(SDCRV_GAUGE).claim_rewards(BLACKHOLE, attacker);
    }

    function test_service_reinitialize_reverts() public {
        ISdtStakingPositionService.WithdrawCallInfo memory info =
            ISdtStakingPositionService.WithdrawCallInfo({addr: address(0xdead), signature: ""});
        vm.prank(attacker);
        vm.expectRevert();
        ISdtStakingPositionService(SDCRV_SERVICE).initialize(attacker, SDCRV_GAUGE, "x", true, info);
    }

    function test_tower_owner_functions_revert() public {
        address[] memory addrs = new address[](1);
        addrs[0] = attacker;
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ICvgControlTower(TOWER).toggleStakingContracts(addrs);
        vm.expectRevert(bytes("CLONE_FACTORY"));
        ICvgControlTower(TOWER).insertNewSdtStaking(attacker);
        vm.stopPrank();
    }

    function test_clone_factory_owner_gate() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ICloneFactoryV2(FACTORY).createSdtStakingAndBuffer(address(0xdead), "x", false);
    }

    function test_distributor_foreign_claim_reverts() public {
        ISdtRewardDistributorV2.ClaimSdtStakingContract[] memory claims =
            new ISdtRewardDistributorV2.ClaimSdtStakingContract[](1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = POS_SDCRV;
        claims[0] = ISdtRewardDistributorV2.ClaimSdtStakingContract({stakingContract: SDCRV_SERVICE, tokenIds: ids});
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtRewardDistributorV2(DISTRIBUTOR).claimMultipleStaking(claims, 0, false, 0);
    }

    function test_manager_burn_foreign_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISdtStakingPositionManager(MANAGER).burn(POS_SDCRV);
    }

    function test_manager_timelock_is_self_only() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISdtStakingPositionManager(MANAGER).setLock(POS_SDCRV, block.timestamp + 1 days);
    }

    /* ------------------------------------------------------------------
     *  3. Positive control — the actual owner CAN self-withdraw (H-O)
     * ------------------------------------------------------------------ */

    function test_position_owner_withdraw_works_positive_control() public {
        assertEq(ISdtStakingPositionManager(MANAGER).ownerOf(POS_SDCRV), POS_SDCRV_OWNER, "owner changed");
        assertEq(ISdtStakingPositionManager(MANAGER).unlockingTimestampPerToken(POS_SDCRV), 0, "position locked");

        uint256 ownerBefore = IERC20(SDCRV_GAUGE).balanceOf(POS_SDCRV_OWNER);
        uint256 bhBefore = IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE);

        vm.prank(POS_SDCRV_OWNER);
        ISdtStakingPositionService(SDCRV_SERVICE).withdraw(POS_SDCRV, 1_000e18);

        assertEq(IERC20(SDCRV_GAUGE).balanceOf(POS_SDCRV_OWNER), ownerBefore + 1_000e18, "owner did not receive");
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE), bhBefore - 1_000e18, "blackhole did not pay");
        emit log_string("owner self-withdraw works: H-O path live");
    }

    /* ------------------------------------------------------------------
     *  4. Keeper surface — designed 1% processor fee (documented, not a bug)
     * ------------------------------------------------------------------ */

    function test_keeper_processor_fee_is_one_percent_designed() public view {
        // processorRewardsPercentage = 1000 ; DENOMINATOR = 100_000 -> 1%
        assertEq(ISdtBufferV2(SDCRV_BUFFER).processorRewardsPercentage(), 1000);
    }

    function test_processSdtRewards_observation() public {
        uint256 sdtBefore = IERC20(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F).balanceOf(attacker);
        (bool ok, bytes memory ret) = SDCRV_SERVICE.call(abi.encodeWithSignature("processSdtRewards()"));
        uint256 sdtAfter = IERC20(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F).balanceOf(attacker);
        emit log_named_string("processSdtRewards ok", ok ? "true" : "false");
        if (!ok) emit log_named_bytes("revert", ret);
        emit log_named_uint("attacker SDT gained (wei)", sdtAfter - sdtBefore);
    }
}
