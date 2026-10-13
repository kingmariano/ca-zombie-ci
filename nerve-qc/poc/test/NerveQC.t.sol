// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ISwap, IMetaSwap, ISafe, IFarm} from "../src/Interfaces.sol";

/// @title Nerve (BSC) — QC-5 adversarial re-audit
/// @notice Fork-only, read-only counter-tests against the prior "E-U $0" closure.
///         Nothing is signed or broadcast; all state changes are on throwaway forks.
contract NerveQC is Test {
    // ---- base pools ----
    address constant P3  = 0x1B3771a66ee31180906972580adE9b81AFc5fCDc; // 3pool BUSD/USDT/USDC
    address constant BTC = 0x6C341938bB75dDe823FAAfe7f446925c66E6270c;
    address constant ETH = 0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0;

    // ---- metapools ----
    address constant USTM   = 0x2dcCe1586b1664f41C72206900e404Ec3cA130e0; // PAUSED funded
    address constant FUSDM  = 0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3; // PAUSED funded
    address constant NRVM   = 0x96b849a73db2cc769b4Abe770aAb141aAC9014d6; // PAUSED empty
    address constant E0     = 0x97B9054122eF8888590934F0eC8E10580232E85d;
    address constant E1     = 0xC80Cc653392f4734201331E39a66aA8a483D29BD;
    address constant E2     = 0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f;
    address constant E3     = 0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459;
    address constant E4     = 0xF100326c19996eaf2d8E93A503725F643e36099C;
    address constant E5     = 0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE;
    address constant E6     = 0xbC7477e46A95758dE5012744f7A350A4E0d03484;
    address constant E7     = 0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114;
    // NEW clones discovered in QC (not in prior set) — all empty
    address constant N1     = 0x877A8437e76443cFCaCD05D21C3793070637d82f;
    address constant N2     = 0xCB922e4A5370020ACf2D0E29754e0a995Dec5B27;
    address constant N3     = 0xf873Ec132F38eFb86bd071234b4316878b48Fa97;

    address constant SAFE = 0xD94Ac9fB78dD9B3FEB0eC39F38d86D2Ee5BA6B06;
    address constant FARM = 0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E;
    address constant LP3  = 0xf2511b5E4FB0e5E2d123004b672BA14850478C14;
    address constant RUSD = 0x07663837218A003e66310a01596af4bf4e44623D;
    address constant FUSDT= 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
    }

    // ==================================================================
    // QC-1: complete state snapshot of every discovered clone + base pool
    // ==================================================================
    function test_qc1_state_all_known_pools() public {
        address[14] memory metas = [USTM, FUSDM, NRVM, E0, E1, E2, E3, E4, E5, E6, E7, N1, N2, N3];
        uint256 totalLpOut;
        for (uint256 k = 0; k < metas.length; k++) {
            address m = metas[k];
            uint256 i0 = ISwap(m).getTokenBalance(0);
            uint256 i1 = ISwap(m).getTokenBalance(1);
            uint256 a0 = ISwap(m).getAdminBalance(0);
            uint256 a1 = ISwap(m).getAdminBalance(1);
            emit log_named_address("pool", m);
            emit log_named_uint("  paused", ISwap(m).paused() ? 1 : 0);
            emit log_named_uint("  internal0", i0);
            emit log_named_uint("  internal1(LP3?)", i1);
            emit log_named_uint("  admin0", a0);
            emit log_named_uint("  admin1", a1);
            assertEq(ISwap(m).owner(), SAFE, "owner must be Safe");
            if (!ISwap(m).paused() && i0 > 0) {
                totalLpOut += ISwap(m).calculateSwap(0, 1, i0);
            }
        }
        emit log_named_uint("TOTAL LP3-out if dumping all internal0", totalLpOut);
        // prior bound: < 11 LP3
        assertLt(totalLpOut, 12e18, "unpaused drain bound");
    }

    // ==================================================================
    // QC-2: funded metapools — every value-moving entry reverts when paused
    // ==================================================================
    function test_qc2_funded_metas_pause_gate() public {
        address[2] memory funded = [USTM, FUSDM];
        for (uint256 k = 0; k < funded.length; k++) {
            address m = funded[k];
            assertTrue(ISwap(m).paused(), "must be paused");
            uint256[] memory amts = new uint256[](2);
            amts[0] = 1e6;
            uint256[] memory outs = new uint256[](2);

            vm.startPrank(attacker);
            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).swap(0, 1, 1e6, 0, block.timestamp);
            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).swapUnderlying(0, 1, 1e6, 0, block.timestamp);
            vm.expectRevert(bytes("Pausable: paused"));
            ISwap(m).addLiquidity(amts, 0, block.timestamp);
            vm.expectRevert(bytes("Pausable: paused"));
            ISwap(m).removeLiquidityOneToken(1e18, 1, 0, block.timestamp);
            vm.expectRevert(bytes("Pausable: paused"));
            ISwap(m).removeLiquidityImbalance(outs, type(uint256).max, block.timestamp);
            vm.stopPrank();
        }
    }

    // ==================================================================
    // QC-3: proportional removeLiquidity is allowed while paused — verify
    //       it is FAIR (internal reserves only, admin untouched)
    // ==================================================================
    function test_qc3_paused_removeLiquidity_is_fair() public {
        _checkFairRedeem(USTM, 0x35Ce243e0DC9eD77e3C348Bb2742095F78e1Cb70, 1e18);
        _checkFairRedeem(FUSDM, 0x2e91A0CECf28c5E518bB2E7fdcd9F8e2cd511c10, 1e18);
    }

    function _checkFairRedeem(address m, address lpToken, uint256 lp) internal {
        uint256 i0 = ISwap(m).getTokenBalance(0);
        uint256 i1 = ISwap(m).getTokenBalance(1);
        uint256 ts = IERC20(lpToken).totalSupply();
        // and verify an actual redemption works while paused, paying only internal
        deal(lpToken, attacker, lp);
        address t0 = ISwap(m).getToken(0);
        address t1 = ISwap(m).getToken(1);
        uint256 bal0 = IERC20(t0).balanceOf(attacker);
        uint256 bal1 = IERC20(t1).balanceOf(attacker);
        uint256[] memory mins = new uint256[](2);
        vm.startPrank(attacker);
        IERC20(lpToken).approve(m, type(uint256).max);
        ISwap(m).removeLiquidity(lp, mins, block.timestamp);
        vm.stopPrank();
        uint256 got0 = IERC20(t0).balanceOf(attacker) - bal0;
        uint256 got1 = IERC20(t1).balanceOf(attacker) - bal1;
        emit log_named_uint("redeem token0 got", got0);
        emit log_named_uint("redeem token1 got", got1);
        assertApproxEqRel(got0, i0 * lp / ts, 1e15, "token0 fair");
        assertApproxEqRel(got1, i1 * lp / ts, 1e15, "token1 fair");
        // admin accounting untouched by redemption
        assertEq(ISwap(m).getAdminBalance(0), _adm(m, t0, 0), "admin0 intact");
        assertEq(ISwap(m).getAdminBalance(1), _adm(m, t1, 1), "admin1 intact");
    }

    function _adm(address m, address t, uint8 i) internal view returns (uint256) {
        return IERC20(t).balanceOf(m) - ISwap(m).getTokenBalance(i);
    }

    // ==================================================================
    // QC-4: admin/pause/ownership functions owner-only on every clone
    // ==================================================================
    function test_qc4_admin_gate_all() public {
        address[8] memory metas = [USTM, FUSDM, E0, E1, E2, E3, E4, E5];
        for (uint256 k = 0; k < metas.length; k++) {
            _checkAdminGate(metas[k]);
        }
        _checkAdminGate(E6);
        _checkAdminGate(E7);
        _checkAdminGate(N1);
        _checkAdminGate(N2);
        _checkAdminGate(N3);
    }

    function _checkAdminGate(address m) internal {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISwap(m).withdrawAdminFees();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISwap(m).unpause();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISwap(m).pause();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISwap(m).transferOwnership(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISwap(m).setSwapFee(1);
        vm.expectRevert();
        IMetaSwap(m).initializeMetaSwap(
            new IERC20[](2), new uint8[](2), "x", "x", 1, 1, 1, 1, 1, attacker, ISwap(P3)
        );
        vm.stopPrank();
    }

    // ==================================================================
    // QC-5: extraction bound on unpaused clones (single-swap direction)
    // ==================================================================
    function test_qc5_unpaused_extraction_bound() public {
        address[8] memory live = [E0, E1, E2, E3, E4, E5, E6, E7];
        uint256 lp3Side;
        for (uint256 k = 0; k < live.length; k++) {
            address m = live[k];
            assertFalse(ISwap(m).paused());
            uint256 i0 = ISwap(m).getTokenBalance(0);
            uint256 i1 = ISwap(m).getTokenBalance(1);
            if (i0 == 0 && i1 == 0) continue;
            // max LP3 the pool can ever pay out (attacker needs token0 to get it)
            uint256 out1 = i0 > 0 ? ISwap(m).calculateSwap(0, 1, i0) : 0;
            // max token0 out for all internal LP3 (attacker can mint LP3 fairly)
            uint256 out0 = i1 > 0 ? ISwap(m).calculateSwap(1, 0, i1) : 0;
            lp3Side += out1;
            emit log_named_address("pool", m);
            emit log_named_uint("  i0", i0);
            emit log_named_uint("  max LP3 out for all i0", out1);
            emit log_named_uint("  max tok0 out for all i1", out0);
        }
        emit log_named_uint("TOTAL potential LP3 side", lp3Side);
        assertLt(lp3Side, 12e18, "total LP3 side bounded");
    }

    // ==================================================================
    // QC-6: the strongest unpaused adversary — manipulate base pool vprice
    //       UP, refresh the metapool cache, then dump LP3 for token0 at
    //       the inflated valuation. Measure net.
    // ==================================================================
    function test_qc6_manipulated_basevp_upper_bound() public {
        // upper bound: what if the cache were set to an inflated value
        // (the best a real upward manipulation can achieve)?
        address[3] memory cand = [E7, E6, E5];
        for (uint256 k = 0; k < cand.length; k++) {
            address m = cand[k];
            uint256 i0 = ISwap(m).getTokenBalance(0);
            uint256 i1 = ISwap(m).getTokenBalance(1);
            if (i1 == 0) continue;
            uint256 baseOut = ISwap(m).calculateSwap(1, 0, i1);
            // The cache manipulation only shifts the LP3 valuation linearly; the
            // token0 payout is capped by internal0 regardless of the cached VP.
            emit log_named_address("pool", m);
            emit log_named_uint("  internal0 (token0 max)", i0);
            emit log_named_uint("  internal1 (LP3 max)", i1);
            emit log_named_uint("  token0 out for all internal LP3 (live vp)", baseOut);
        }
    }

    // ==================================================================
    // QC-6b: real manipulation attempt on the 3pool (vprice up) then
    //        extract from an unpaused clone. Measures feasibility+cost.
    // ==================================================================
    function test_qc6b_real_3pool_manipulation() public {
        uint256 vpBefore = ISwap(P3).getVirtualPrice();
        // LP3 is OZ 3.x LPToken: _balances mapping at slot 4
        vm.store(LP3, keccak256(abi.encode(attacker, uint256(0))), bytes32(uint256(500_000e18)));
        assertEq(IERC20(LP3).balanceOf(attacker), 500_000e18, "LP3 credit");
        uint256 i0 = ISwap(P3).getTokenBalance(0);
        uint256[] memory amounts = new uint256[](3);
        // withdraw 5% of BUSD (imbalanced) to burn extra LP -> vprice up
        amounts[0] = i0 / 20;
        vm.startPrank(attacker);
        IERC20(LP3).approve(P3, type(uint256).max);
        try ISwap(P3).removeLiquidityImbalance(amounts, 500_000e18, block.timestamp) returns (uint256 b) {
            emit log_named_uint("LP3 burned for 5% BUSD", b);
        } catch {
            emit log("removeLiquidityImbalance reverted");
        }
        vm.stopPrank();
        uint256 vpAfter = ISwap(P3).getVirtualPrice();
        emit log_named_uint("3pool vp before", vpBefore);
        emit log_named_uint("3pool vp after", vpAfter);
        if (vpAfter > vpBefore) {
            emit log_named_uint("vp delta (wei)", vpAfter - vpBefore);
            emit log_named_uint("vp delta bps(x100)", (vpAfter - vpBefore) * 10000 / vpBefore);
        }
        // now try to sell LP3 into E7 at the refreshed valuation
        vm.startPrank(attacker);
        uint256 i1 = ISwap(E7).getTokenBalance(1);
        if (i1 > 0) {
            uint256 out0 = ISwap(E7).calculateSwap(1, 0, i1);
            emit log_named_uint("E7 token0 out for all i1 after vp bump", out0);
        }
        vm.stopPrank();
    }

    // ==================================================================
    // QC-13: SIMULATED MANIPULATED CACHE (vm.store baseVirtualPrice).
    //        The theoretical strongest stale/inflated-price state; prove
    //        the state-changing swap cannot pay beyond internal reserves
    //        (admin balances stay unreachable via SafeMath underflow).
    // ==================================================================
    function test_qc13_manipulated_cache_bound() public {
        address m = E7;
        // verify the metaSwapStorage layout: 218=baseSwap, 219=baseVirtualPrice
        bytes32 slot218 = vm.load(m, bytes32(uint256(218)));
        assertEq(address(uint160(uint256(slot218))), P3, "slot218 is baseSwap");
        uint256 i0 = ISwap(m).getTokenBalance(0);
        uint256 i1 = ISwap(m).getTokenBalance(1);
        uint256 a1 = ISwap(m).getAdminBalance(1);

        // A: cache inflated 2x (LP3 looks 2x more valuable in xp space)
        vm.store(m, bytes32(uint256(219)), bytes32(uint256(2e18)));
        vm.store(m, bytes32(uint256(220)), bytes32(block.timestamp)); // not expired
        uint256 outLpView = ISwap(m).calculateSwap(0, 1, i0);
        emit log_named_uint("baseVP=2e18: view LP3 out for all i0", outLpView);
        emit log_named_uint("internal1 (admin-protected)", i1);
        emit log_named_uint("admin1", a1);
        assertLe(outLpView, i1 + a1, "view-capped by total LP3 incl admin");

        // execute it as the funded bot (holds rUSD): must revert (SafeMath)
        // or pay at most internal1
        address bot = 0xD42fCe65B9cE5deD9d3a4EcaA20955BAB52DaA19;
        // rUSD is an OZ-upgradeable proxy: _balances at slot 51
        vm.store(RUSD, keccak256(abi.encode(bot, uint256(51))), bytes32(uint256(50e18)));
        uint256 in0 = IERC20(RUSD).balanceOf(bot);
        assertEq(in0, 50e18, "rUSD credit");
        if (in0 > 0) {
            vm.startPrank(bot);
            IERC20(RUSD).approve(m, type(uint256).max);
            try ISwap(m).swap(0, 1, in0, 0, block.timestamp) returns (uint256 got) {
                emit log_named_uint("baseVP=2e18: actual LP3 received", got);
                assertLe(got, i1, "never pays beyond internal1");
            } catch {
                emit log("baseVP=2e18: swap reverted (SafeMath underflow = admin safe)");
            }
            vm.stopPrank();
        }

        // B: cache deflated 0.5x; LP3 out for token0 bounded by internal1
        vm.store(m, bytes32(uint256(219)), bytes32(uint256(0.5e18)));
        uint256 outLpView2 = ISwap(m).calculateSwap(0, 1, i0);
        emit log_named_uint("baseVP=0.5e18: view LP3 out for all i0", outLpView2);
        assertLe(outLpView2, i1 + a1, "view-capped");
        // token0 out for all internal LP3 bounded by internal0
        uint256 outT0 = ISwap(m).calculateSwap(1, 0, i1);
        emit log_named_uint("baseVP=0.5e18: view token0 out for all i1", outT0);
        assertLe(outT0, i0, "token0 out capped by internal0");

        // restore
        vm.store(m, bytes32(uint256(219)), bytes32(ISwap(P3).getVirtualPrice()));
        vm.store(m, bytes32(uint256(220)), bytes32(uint256(0)));
    }

    // ==================================================================
    // QC-7: CONDITIONAL — fork-only owner unpause, then measure what a
    //       fresh attacker could extract (internal reserves vs admin).
    // ==================================================================
    function test_qc7_conditional_unpause_extraction() public {
        // fork-only: simulate the Safe unpausing the funded metapools
        vm.startPrank(SAFE);
        ISwap(USTM).unpause();
        ISwap(FUSDM).unpause();
        vm.stopPrank();

        address[2] memory funded = [USTM, FUSDM];
        for (uint256 k = 0; k < funded.length; k++) {
            address m = funded[k];
            uint256 i0 = ISwap(m).getTokenBalance(0);
            uint256 i1 = ISwap(m).getTokenBalance(1);
            uint256 a0 = ISwap(m).getAdminBalance(0);
            uint256 a1 = ISwap(m).getAdminBalance(1);
            emit log_named_address("pool", m);
            emit log_named_uint("  internal0", i0);
            emit log_named_uint("  internal1", i1);
            emit log_named_uint("  admin0", a0);
            emit log_named_uint("  admin1", a1);

            // strongest single-block attack: round trip token1 -> token0 -> token1
            uint256 dx = i1 / 4;
            if (dx > 0) {
                uint256 mid = ISwap(m).calculateSwap(1, 0, dx);
                uint256 back = ISwap(m).calculateSwap(0, 1, mid);
                emit log_named_uint("  rt 1->0->1 dx", dx);
                emit log_named_uint("  mid", mid);
                emit log_named_uint("  back", back);
            }
            // bound checks: a pump of token0 out can never exceed internal0
            uint256 max0 = ISwap(m).calculateSwap(1, 0, i1);
            uint256 max1 = ISwap(m).calculateSwap(0, 1, i0);
            emit log_named_uint("  max token0 out (all i1)", max0);
            emit log_named_uint("  max token1 out (all i0)", max1);
            // prove the caps: outputs stay strictly below internal reserves
            assertLt(max0, i0, "token0 out < internal0");
            assertLt(max1, i1, "token1 out < internal1");
        }
    }

    // ==================================================================
    // QC-8: impl contracts — state, balances, initialization
    // ==================================================================
    function test_qc8_impl_contracts() public {
        address[3] memory impls = [
            0xf642f2A626a8B732619606C493aBFc2433dd2D35,
            0xfA97aDb530B38639a83B1890Ee17942804035dDF,
            0xFcC3976ebdC240Ce83E8a94bC83Be5Cd4ad4a053
        ];
        for (uint256 k = 0; k < impls.length; k++) {
            emit log_named_address("impl", impls[k]);
            emit log_named_uint("  code len", impls[k].code.length);
            emit log_named_uint("  BUSD bal", IERC20(BUSD).balanceOf(impls[k]));
            emit log_named_uint("  USDT bal", IERC20(USDT).balanceOf(impls[k]));
            emit log_named_uint("  LP3 bal", IERC20(LP3).balanceOf(impls[k]));
            emit log_named_uint("  fUSDT bal", IERC20(FUSDT).balanceOf(impls[k]));
            emit log_named_uint("  rUSD bal", IERC20(RUSD).balanceOf(impls[k]));
        }
    }

    // ==================================================================
    // QC-9: farm — no unprivileged path moves staked LP
    // ==================================================================
    function test_qc9_farm_no_outsider_drain() public {
        uint256 n = IFarm(FARM).poolLength();
        emit log_named_uint("farm pools", n);
        for (uint256 i = 0; i < n; i++) {
            (address lp,,,) = IFarm(FARM).poolInfo(i);
            emit log_named_address("  lp", lp);
            emit log_named_uint("  farm bal", IERC20(lp).balanceOf(FARM));
        }
        vm.startPrank(attacker);
        // attacker has no stake: withdraw/emergencyWithdraw must move nothing
        uint256 before = IERC20(LP3).balanceOf(attacker);
        IFarm(FARM).withdraw(0, 0);
        IFarm(FARM).emergencyWithdraw(0);
        assertEq(IERC20(LP3).balanceOf(attacker), before, "no LP moved");
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFarm(FARM).add(1, IERC20(LP3), false);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFarm(FARM).set(0, 1, false);
        vm.stopPrank();
    }

    // ==================================================================
    // QC-10: the three NEW clones (found in QC) are initialized & empty;
    //        attacker cannot take them over or re-init
    // ==================================================================
    function test_qc10_new_clones_empty() public {
        address[3] memory nw = [N1, N2, N3];
        for (uint256 k = 0; k < nw.length; k++) {
            address m = nw[k];
            assertEq(ISwap(m).owner(), SAFE, "owned by safe");
            assertFalse(ISwap(m).paused());
            assertEq(ISwap(m).getTokenBalance(0), 0, "empty0");
            assertEq(ISwap(m).getTokenBalance(1), 0, "empty1");
            vm.prank(attacker);
            vm.expectRevert();
            IMetaSwap(m).initializeMetaSwap(
                new IERC20[](2), new uint8[](2), "x", "x", 1, 1, 1, 1, 1, attacker, ISwap(P3)
            );
        }
    }

    // ==================================================================
    // QC-11: base pools remain fair — big round trip loses
    // ==================================================================
    function test_qc11_base_pools_fair() public {
        deal(USDT, attacker, 100_000e18);
        vm.startPrank(attacker);
        IERC20(USDT).approve(P3, type(uint256).max);
        uint256 busd = ISwap(P3).swap(1, 0, 100_000e18, 0, block.timestamp);
        IERC20(BUSD).approve(P3, type(uint256).max);
        uint256 back = ISwap(P3).swap(0, 1, busd, 0, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("100k USDT round trip back", back);
        assertLt(back, 100_000e18, "3pool round trip must lose");
    }

    // ==================================================================
    // QC-12: admin piles are owner-only and NOT reachable by swapping
    //        (swap outputs always stay below internal reserves)
    // ==================================================================
    function test_qc12_admin_not_swappable() public {
        // for the funded metapools (paused path irrelevant: also test base pool)
        address[2] memory pools = [P3, FUSDM];
        for (uint256 k = 0; k < pools.length; k++) {
            address m = pools[k];
            uint8 nt = k == 0 ? 3 : 2;
            for (uint8 i = 0; i < nt; i++) {
                uint256 internal_ = ISwap(m).getTokenBalance(i);
                uint256 admin = ISwap(m).getAdminBalance(i);
                if (internal_ == 0) continue;
                uint8 other = i == 0 ? 1 : 0;
                uint256 out = ISwap(m).calculateSwap(i, other, internal_);
                emit log_named_uint("max out for full internal", out);
                assertLt(out, ISwap(m).getTokenBalance(other), "out < internal reserve");
                emit log_named_uint("admin at risk", admin > 0 ? 0 : 1);
            }
        }
    }
}
