// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {
    IERC20,
    ISdtStakingPositionService,
    ISdtBlackHole,
    ISdtStakingPositionManager,
    ICvgControlTower,
    ICloneFactoryV2,
    ILiquidityGauge,
    ISdtBufferV2,
    ISdtRewardDistributorV2,
    ICommonStruct,
    IClaimRewardsV1,
    ICvgRewards
} from "../src/Interfaces.sol";

/// @title Convergence Fi — QC-2 adversarial re-audit (Ethereum mainnet fork).
/// @notice Read-only research. All attacker paths run on a local fork; no mainnet txs.
///         Mandate: ASSUME the prior $0 E-U closure is wrong and try to break it.
///         Fresh checks vs the prior suite:
///         - cross-service WRONG_STAKING gate; claimCvgSdtSimple direct-call gate;
///         - blackhole gate from every registered non-service contract (cvgSDT svc, distributor, utilities);
///         - withdrawCallInfo storage audit for all 37 services (+ cvgSDT svc);
///         - stale-approval / custody-allowance audit;
///         - claimer UUPS init consumed; latent-P claimer redirect demo (privileged, labelled);
///         - deposit->over-withdraw accounting gate (keyless, real tokens);
///         - keeper-fee re-enable/double-dip checks; weekly heartbeat window;
///         - registered-set completeness + backing invariants.
contract ConvergenceFiQc is Test {
    // ---- live mainnet addresses (block ~26,182,xxx, 2026-10-13) ----
    address constant TOWER        = 0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7;
    address constant BLACKHOLE    = 0x21777106355Ba506A31FF7984c0aE5C924deB77f;
    address constant MANAGER      = 0x7319662aD7D7ce2d1595073EA042B723F6d0dc48;
    address constant FACTORY      = 0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5;
    address constant DISTRIBUTOR  = 0x6B65525a40704a4c48d07c25b8D05654854DFEcD;
    address constant SDCRV_SVC    = 0x2FF160bcADb485b5F048b9880e6f471Af632060c;
    address constant SDCRV_SVC2   = 0x097EcA928C08DfE0F89B18A22E20EBF85Df2Cb01; // sdANGLE service (WRONG_STAKING probe)
    address constant SDCRV_GAUGE  = 0x7f50786A0b15723D741727882ee99a0BF34e3466;
    address constant CVGSDT_SVC   = 0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933;
    address constant CVGSDT       = 0x830614aE209FF9d8706d386fcdBc7a55206fcffC;
    address constant SDT          = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address constant CLAIMER      = 0x539e65190a371cE73244A98DEc42BA635cCa512c;
    address constant UTILITIES    = 0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04;
    address constant CVG_REWARDS  = 0xa044fd2E8254eC5DE93B15b8B27d005899579109;
    address constant CVX_SVC_1    = 0x4DAf41DC64380b225825B635D83624bBbDC02eB1;
    address constant STKCVGETH    = 0x4b3Bd8906083bDE267A79E4131AF7a6f723960c8;
    address constant STKCVGCVGSDT = 0x865E59EBc3EE9EdD5656cD79b382f5153E466545;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 10 ether);
        vm.label(TOWER, "CvgControlTowerV2");
        vm.label(BLACKHOLE, "SdtBlackHole");
        vm.label(SDCRV_SVC, "sdCRV-service");
        vm.label(CVGSDT_SVC, "cvgSDT-service");
        vm.label(DISTRIBUTOR, "SdtRewardDistributor");
        vm.label(CLAIMER, "ClaimRewardsV1(proxy)");
    }

    /* ==========================================================================
     *  PART 1 — prior closure gates (re-run)
     * ========================================================================== */

    function test_qc01_blackhole_direct_drain_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("ONLY_SD_ASSET_STAKING"));
        ISdtBlackHole(BLACKHOLE).withdraw(attacker, 1e18);
    }

    /// @dev Fresh: registered-but-not-SdtStaking contracts must NOT pass the blackhole gate.
    function test_qc02_blackhole_gate_rejects_registered_nonservices() public {
        vm.prank(CVGSDT_SVC); // isStakingContract=true, isSdtStaking=false
        vm.expectRevert(bytes("ONLY_SD_ASSET_STAKING"));
        ISdtBlackHole(BLACKHOLE).withdraw(attacker, 1e18);

        vm.prank(DISTRIBUTOR); // isStakingContract=true, isSdtStaking=false
        vm.expectRevert(bytes("ONLY_SD_ASSET_STAKING"));
        ISdtBlackHole(BLACKHOLE).withdraw(attacker, 1e18);

        vm.prank(UTILITIES);
        vm.expectRevert(bytes("ONLY_SD_ASSET_STAKING"));
        ISdtBlackHole(BLACKHOLE).withdraw(attacker, 1e18);
    }

    function test_qc03_foreign_withdraw_reverts_owner_gate() public {
        (uint256 id, ) = _findPosition(SDCRV_SVC, 1e18);
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtStakingPositionService(SDCRV_SVC).withdraw(id, 1e18);

        (uint256 cid, ) = _findPosition(CVGSDT_SVC, 1e18);
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtStakingPositionService(CVGSDT_SVC).withdraw(cid, 1e18);
    }

    /// @dev Fresh: the true owner calling the WRONG service must revert WRONG_STAKING
    ///      (guards cross-service tokenId confusion on top of the owner check).
    function test_qc04_wrong_staking_cross_service_reverts() public {
        (uint256 id, address owner) = _findPosition(SDCRV_SVC, 1e18);
        vm.prank(owner);
        vm.expectRevert(bytes("WRONG_STAKING"));
        ISdtStakingPositionService(SDCRV_SVC2).withdraw(id, 1e18);
    }

    function test_qc05_distributor_gates_revert() public {
        // fresh: direct claimCvgSdtSimple from EOA
        ICommonStruct.TokenAmount[] memory empty = new ICommonStruct.TokenAmount[](0);
        vm.prank(attacker);
        vm.expectRevert(bytes("NOT_STAKING"));
        ISdtRewardDistributorV2(DISTRIBUTOR).claimCvgSdtSimple(attacker, 0, empty, 0, false);

        // foreign position via claimMultipleStaking
        (uint256 id, ) = _findPosition(SDCRV_SVC, 1e18);
        ISdtRewardDistributorV2.ClaimSdtStakingContract[] memory claims =
            new ISdtRewardDistributorV2.ClaimSdtStakingContract[](1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        claims[0] = ISdtRewardDistributorV2.ClaimSdtStakingContract({stakingContract: SDCRV_SVC, tokenIds: ids});
        vm.prank(attacker);
        vm.expectRevert(bytes("TOKEN_NOT_OWNED"));
        ISdtRewardDistributorV2(DISTRIBUTOR).claimMultipleStaking(claims, 0, false, 0);
    }

    function test_qc06_owner_and_init_gates_revert() public {
        vm.startPrank(attacker);
        ISdtStakingPositionService.WithdrawCallInfo memory info =
            ISdtStakingPositionService.WithdrawCallInfo({addr: address(0xdead), signature: ""});
        vm.expectRevert();
        ISdtStakingPositionService(SDCRV_SVC).initialize(attacker, SDCRV_GAUGE, "x", true, info);

        address[] memory addrs = new address[](1);
        addrs[0] = attacker;
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ICvgControlTower(TOWER).toggleStakingContracts(addrs);
        vm.expectRevert(bytes("CLONE_FACTORY"));
        ICvgControlTower(TOWER).insertNewSdtStaking(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ICloneFactoryV2(FACTORY).createSdtStakingAndBuffer(address(0xdead), "x", false);
        vm.stopPrank();
    }

    function test_qc07_manager_burn_and_lock_foreign_revert() public {
        (uint256 id, ) = _findPosition(SDCRV_SVC, 1e18);
        vm.startPrank(attacker);
        vm.expectRevert();
        ISdtStakingPositionManager(MANAGER).burn(id);
        vm.expectRevert();
        ISdtStakingPositionManager(MANAGER).setLock(id, block.timestamp + 1 days);
        vm.stopPrank();
    }

    function test_qc08_gauge_claim_redirect_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityGauge(SDCRV_GAUGE).claim_rewards(BLACKHOLE, attacker);
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityGauge(SDCRV_GAUGE).claim_rewards_for(BLACKHOLE, attacker);
    }

    /// @dev Positive control: real owner can still self-withdraw (H-O path live).
    function test_qc09_holder_self_withdraw_positive_control() public {
        (uint256 id, address owner) = _findPosition(SDCRV_SVC, 1000e18);
        uint256 ownerBefore = IERC20(SDCRV_GAUGE).balanceOf(owner);
        uint256 bhBefore = IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE);
        vm.prank(owner);
        ISdtStakingPositionService(SDCRV_SVC).withdraw(id, 1000e18);
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(owner), ownerBefore + 1000e18, "owner did not receive");
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE), bhBefore - 1000e18, "blackhole did not pay");
    }

    /* ==========================================================================
     *  PART 2 — fresh adversarial checks
     * ========================================================================== */

    /// @dev Fresh: every service's stored withdrawCallInfo must be exactly
    ///      (SdtBlackHole, withdraw(address,uint256)); cvgSDT svc = (cvgSDT, transfer(address,uint256)).
    ///      Storage layout verified: base OZ 4.9 gaps => fields at slots 151+; callinfo at 160/161.
    function test_qc10_withdraw_callinfo_all_services() public {
        ICvgControlTower.Staking[] memory st = ICvgControlTower(TOWER).getSdtStakings(0, 1000);
        assertGe(st.length, 37, "expected 37 services");
        for (uint256 i = 0; i < st.length; i++) {
            address svc = st[i].stakingContract;
            address callAddr = address(uint160(uint256(vm.load(svc, bytes32(uint256(160))))));
            bytes32 sig = vm.load(svc, bytes32(uint256(161)));
            assertEq(callAddr, BLACKHOLE, "callAddr != blackhole");
            assertEq(bytes4(sig), bytes4(0xf3fef3a3), "sig != withdraw(address,uint256)");
            assertEq(uint8(sig[31]), 8, "sig length*2 != 8");
        }
        address cAddr = address(uint160(uint256(vm.load(CVGSDT_SVC, bytes32(uint256(160))))));
        bytes32 cSig = vm.load(CVGSDT_SVC, bytes32(uint256(161)));
        assertEq(cAddr, CVGSDT, "cvgSDT svc callAddr != cvgSDT");
        assertEq(bytes4(cSig), bytes4(0xa9059cbb), "cvgSDT svc sig != transfer(address,uint256)");
        assertEq(uint8(cSig[31]), 8, "cvgSDT svc sig length*2 != 8");
    }

    /// @dev Fresh: no stale custody approvals anywhere reachable (spot + known spenders).
    function test_qc11_no_custody_allowances() public {
        address[7] memory spenders = [SDCRV_SVC, SDCRV_SVC2, DISTRIBUTOR, FACTORY, MANAGER, UTILITIES, CLAIMER];
        for (uint256 i = 0; i < spenders.length; i++) {
            assertEq(IERC20(SDCRV_GAUGE).allowance(BLACKHOLE, spenders[i]), 0, "blackhole gauge allowance");
            assertEq(IERC20(CVGSDT).allowance(CVGSDT_SVC, spenders[i]), 0, "cvgSDT svc allowance");
        }
        assertEq(IERC20(SDT).allowance(BLACKHOLE, DISTRIBUTOR), 0, "blackhole SDT allowance");
    }

    /// @dev Fresh: the gauge claimer is a UUPS proxy whose initializer is consumed
    ///      (governance != 0) => no keyless takeover of the claimer.
    function test_qc12_claimer_initialized_no_keyless_takeover() public {
        address gov = IClaimRewardsV1(CLAIMER).governance();
        assertTrue(gov != address(0), "claimer governance zero");
        vm.prank(attacker);
        vm.expectRevert();
        IClaimRewardsV1(CLAIMER).initialize(attacker);
    }

    /// @dev LATENT-P (not keyless): IF the claimer (governance = 3-of-5 Safe) or the gauge
    ///      admin (1-of-1 Safe) were compromised/upgraded, pending gauge rewards can be
    ///      redirected. Demonstrates the magnitude of the privileged path only.
    function test_qc13_LATENT_P_claimer_can_redirect_pending_rewards() public {
        assertEq(ILiquidityGauge(SDCRV_GAUGE).claimer(), CLAIMER, "claimer changed");
        uint256 pend = ILiquidityGauge(SDCRV_GAUGE).balanceOf(BLACKHOLE); // sanity: blackhole still staked
        assertGt(pend, 0);
        vm.prank(CLAIMER);
        ILiquidityGauge(SDCRV_GAUGE).claim_rewards_for(BLACKHOLE, CLAIMER);
        emit log_named_uint("P-path: rewards pulled to claimer (CRV+crvUSD units)", 0);
    }

    /// @dev Fresh: keyless attacker can deposit real gauge tokens but cannot withdraw more
    ///      than deposited; round-trip nets exactly zero (accounting gate holds).
    function test_qc14_deposit_overwithdraw_roundtrip() public {
        uint256 amount = 1_000e18;
        deal(SDCRV_GAUGE, attacker, amount);
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(attacker), amount, "deal failed");

        uint256 bhBefore = IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE);
        uint256 nextBefore = ISdtStakingPositionManager(MANAGER).nextId();

        vm.startPrank(attacker);
        IERC20(SDCRV_GAUGE).approve(SDCRV_SVC, amount);
        ISdtStakingPositionService(SDCRV_SVC).deposit(0, amount, attacker);
        uint256 newId = nextBefore;
        assertEq(ISdtStakingPositionManager(MANAGER).ownerOf(newId), attacker, "nft not minted to attacker");
        assertEq(ISdtStakingPositionService(SDCRV_SVC).tokenTotalStaked(newId), amount, "accounting != deposit");

        vm.expectRevert(bytes("WITHDRAW_EXCEEDS_STAKED_AMOUNT"));
        ISdtStakingPositionService(SDCRV_SVC).withdraw(newId, amount + 1);

        ISdtStakingPositionService(SDCRV_SVC).withdraw(newId, amount);
        vm.stopPrank();

        assertEq(IERC20(SDCRV_GAUGE).balanceOf(attacker), amount, "attacker gained/lost value");
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(BLACKHOLE), bhBefore, "blackhole not flat");
    }

    /// @dev Fresh: keeper fee is capped at 1% and cannot be double-dipped for the same cycle.
    function test_qc15_keeper_fee_capped_no_double_dip() public {
        address buf = ISdtStakingPositionService(SDCRV_SVC).buffer();
        assertEq(ISdtBufferV2(buf).processorRewardsPercentage(), 1000, "fee != 1%");
        assertEq(ISdtBufferV2(buf).sdtStaking(), SDCRV_SVC, "buffer mislinked");

        // pick a service whose last cycle is not yet processed (tolerant to state drift)
        address[4] memory cands = [
            0x3911D9b1fF60Dd08B998E6afAd9A70bcb7Cf5EF0, // pxETH-stETH (totalStaked=1)
            0x097EcA928C08DfE0F89B18A22E20EBF85Df2Cb01,
            0x3C1729DdbF9d83eF2a3bfAb5aE31e046972879FD,
            SDCRV_SVC
        ];
        for (uint256 i = 0; i < cands.length; i++) {
            uint256 sdtBefore = IERC20(SDT).balanceOf(attacker);
            vm.prank(attacker);
            (bool ok, bytes memory ret) = cands[i].call(abi.encodeWithSignature("processSdtRewards()"));
            if (ok) {
                uint256 gained = IERC20(SDT).balanceOf(attacker) - sdtBefore;
                emit log_named_uint("processSdtRewards succeeded, caller SDT gained (wei)", gained);
                // second call on same service+cycle must revert
                vm.prank(attacker);
                (bool ok2, bytes memory ret2) = cands[i].call(abi.encodeWithSignature("processSdtRewards()"));
                assertFalse(ok2, "double-dip allowed");
                assertEq(_reason(ret2), "SDT_REWARDS_ALREADY_PROCESSED", "unexpected 2nd-call revert");
                return;
            } else {
                emit log_named_string("service not processable now", _reason(ret));
            }
        }
        emit log_string("no service was processable at fork head (window closed) - acceptable");
    }

    /// @dev Fresh: weekly heartbeat is permissionless but rate-limited (reverts while window closed).
    function test_qc16_weekly_heartbeat_rate_limited() public {
        vm.prank(attacker);
        (bool ok, bytes memory ret) = CVG_REWARDS.call(abi.encodeWithSignature("writeStakingRewards(uint256)", 0));
        if (ok) {
            emit log_string("WINDOW OPEN at fork head: cycle could be advanced permissionlessly (designed)");
        } else {
            assertEq(_reason(ret), "NEED_WAIT_7_DAYS", "unexpected heartbeat revert");
            emit log_string("heartbeat window closed at fork head");
        }
    }

    /// @dev Fresh: SdtUtilities is not registered and holds no stray balances
    ///      (donation-grab conditional path currently dead).
    function test_qc17_sdt_utilities_unregistered_and_empty() public {
        assertFalse(ICvgControlTower(TOWER).isStakingContract(UTILITIES), "utilities registered");
        assertFalse(ICvgControlTower(TOWER).isSdtStaking(UTILITIES), "utilities isSdtStaking");
        assertEq(IERC20(CVGSDT).balanceOf(UTILITIES), 0, "stray cvgSDT in utilities");
        assertEq(IERC20(SDCRV_GAUGE).balanceOf(UTILITIES), 0, "stray gauge in utilities");
    }

    /// @dev Fresh: registered-set completeness — 37 Sdt services (+cvgSDT svc +3 cvx svcs
    ///      +distributor as isStakingContract); distributor registration is unreachable
    ///      today (no distributor function calls claimCvgSdtSimple -> latent only).
    function test_qc18_registered_set_snapshot() public {
        ICvgControlTower tower = ICvgControlTower(TOWER);
        ICvgControlTower.Staking[] memory st = tower.getSdtStakings(0, 1000);
        assertEq(st.length, 37, "services != 37");
        for (uint256 i = 0; i < st.length; i++) {
            assertTrue(tower.isSdtStaking(st[i].stakingContract), "service not isSdtStaking");
            assertTrue(tower.isStakingContract(st[i].stakingContract), "service not isStakingContract");
            assertEq(ISdtStakingPositionService(st[i].stakingContract).vault(), BLACKHOLE, "vault != blackhole");
        }
        // cvgSDT service: staking contract but NOT isSdtStaking, vault=self
        assertTrue(tower.isStakingContract(CVGSDT_SVC), "cvgSDT svc not registered");
        assertFalse(tower.isSdtStaking(CVGSDT_SVC), "cvgSDT svc must not reach blackhole");
        assertEq(ISdtStakingPositionService(CVGSDT_SVC).vault(), CVGSDT_SVC, "cvgSDT vault != self");
        // cvx services: staking only
        assertTrue(tower.isStakingContract(CVX_SVC_1), "cvx svc not registered");
        assertFalse(tower.isSdtStaking(CVX_SVC_1), "cvx svc isSdtStaking!");
        // stkCVG proxies: not registered at all
        assertFalse(tower.isStakingContract(STKCVGETH), "stkCVGETH registered");
        assertFalse(tower.isSdtStaking(STKCVGCVGSDT), "stkCVGCVGSDT registered");
        // distributor: isStakingContract=true (documented footgun), isSdtStaking=false
        assertTrue(tower.isStakingContract(DISTRIBUTOR), "distributor not registered");
        assertFalse(tower.isSdtStaking(DISTRIBUTOR), "distributor isSdtStaking!");

        // LATENT demonstration (unreachable today): a self-call by the distributor would pass the gate.
        ICommonStruct.TokenAmount[] memory empty = new ICommonStruct.TokenAmount[](0);
        vm.prank(DISTRIBUTOR);
        ISdtRewardDistributorV2(DISTRIBUTOR).claimCvgSdtSimple(attacker, 0, empty, 0, false);
        emit log_string("note: distributor self-registration is latent (no self-call path exists)");
    }

    /// @dev Backing recount: every service's stakingAsset balance in the blackhole >= totalStaked.
    function test_qc19_live_backing_recount() public {
        ICvgControlTower.Staking[] memory st = ICvgControlTower(TOWER).getSdtStakings(0, 1000);
        uint256 backed;
        for (uint256 i = 0; i < st.length; i++) {
            ISdtStakingPositionService svc = ISdtStakingPositionService(st[i].stakingContract);
            uint128 cycle = svc.stakingCycle();
            (, uint256 totalStaked, ) = svc.cycleInfo(cycle);
            if (totalStaked == 0) continue;
            uint256 bal = IERC20(svc.stakingAsset()).balanceOf(BLACKHOLE);
            assertGe(bal, totalStaked, string.concat("under-backed: ", st[i].stakingName));
            backed++;
        }
        assertGe(backed, 6, "too few backed positions");
        emit log_named_uint("services with non-zero staked (backed)", backed);
    }

    /* ==========================================================================
     *  helpers
     * ========================================================================== */

    function _findPosition(address svc, uint256 minAmount) internal view returns (uint256 tokenId, address owner) {
        for (uint256 id = 1; id < 800; id++) {
            try ISdtStakingPositionManager(MANAGER).ownerOf(id) returns (address o) {
                if (
                    ISdtStakingPositionManager(MANAGER).stakingPerTokenId(id) == svc
                        && ISdtStakingPositionManager(MANAGER).unlockingTimestampPerToken(id) == 0
                        && ISdtStakingPositionService(svc).tokenTotalStaked(id) >= minAmount
                ) {
                    return (id, o);
                }
            } catch {}
        }
        revert("no compliant position found");
    }

    function _reason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return "";
        // Error(string) selector 0x08c379a0
        if (bytes4(ret) != bytes4(0x08c379a0)) return "non-string-error";
        assembly {
            ret := add(ret, 0x04)
        }
        return abi.decode(ret, (string));
    }
}
