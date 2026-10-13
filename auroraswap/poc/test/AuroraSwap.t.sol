// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, IUniV2Factory, IUniV2Pair, IBRLMasterChef} from "../src/Interfaces.sol";

/// @title AuroraSwap (Aurora) — read-only fork verification of unprivileged-extraction paths
/// @notice Fork of Aurora mainnet at a pinned block. No mainnet transactions; all state changes are local.
contract AuroraSwapTest is Test {
    // ---- protocol addresses (Aurora, chain id 1313161554) ----
    address constant FACTORY = 0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3;
    address constant FEE_TO = 0x9F678909C735001Ac6482fCCFc928e11B703bcAE;
    address constant MC = 0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE;
    address constant BRL = 0x12c87331f086c3C926248f964f8702C0842Fd77F;
    address constant AZFD = 0x19185181EA1F59e1CAB83efd6BeeF6A9730603ee;
    address constant MC_OWNER = 0xFdf4aF84764E67333985af2Db9b1fE57dFEc8251;

    address constant USDT = 0x4988a896b1227218e4A686fdE5EabdcAbd91571f; // 6 dec
    address constant NEAR = 0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d; // 24 dec
    address constant USDC = 0xB12BFcA5A55806AaF64E99521918A4bf0fC40802; // 6 dec
    address constant WETH = 0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB; // 18 dec

    address constant PAIR_USDT_NEAR = 0xF3DE9dc38f62608179c45fE8943a0cA34Ba9CEfc;
    address constant PAIR_NEAR_WETH = 0xc57eCc341aE4df32442Cf80F34f41Dc1782fE067;
    address constant PAIR_USDC_NEAR = 0x480A68bA97d70495e80e11e05D59f6C659749F27;
    address constant PAIR_USDT_USDC = 0xEc538fAfaFcBB625C394c35b11252cef732368cd;
    address constant PAIR_BRL_WETH = 0xEfCF518CA36DC3362F539965807b42A77DC26Be0;
    address constant PAIR_XNEAR_NEAR = 0x05692A796eEaE39b48F0CA935B5ef3a22d905623;
    address constant LP_USDT_NEAR = 0xF3DE9dc38f62608179c45fE8943a0cA34Ba9CEfc;

    uint256 constant FORK_BLOCK = 219723846;
    address attacker = address(0xA11CE);
    address attacker2 = address(0xB0B);

    function setUp() public {
        string[3] memory urls = [
            vm.envOr("AURORA_RPC_URL", string("https://mainnet.aurora.dev")),
            "https://aurora.drpc.org",
            "https://mainnet.aurora.dev"
        ];
        for (uint256 i = 0; i < urls.length; i++) {
            try this.selectFork(urls[i]) {
                return;
            } catch {}
        }
        revert("no working Aurora RPC");
    }

    function selectFork(string memory url) external {
        vm.createSelectFork(url, FORK_BLOCK);
    }

    // ---------------------------------------------------------------- helpers

    function fund(address token, address to, uint256 amt) external {
        deal(token, to, amt);
    }

    function tryFund(address token, address to, uint256 amt) internal returns (bool) {
        try this.fund(token, to, amt) {
            return true;
        } catch {
            return false;
        }
    }

    function _bal(address tok, address who) internal view returns (bool ok, uint256 v) {
        (bool s, bytes memory d) = tok.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, who));
        if (s && d.length >= 32) return (true, abi.decode(d, (uint256)));
        return (false, 0);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256)
    {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // ---------------------------------------------------------------- tests

    /// All 125 pairs are deployed from one identical template.
    function test_all_pairs_same_template() public {
        uint256 n = IUniV2Factory(FACTORY).allPairsLength();
        assertEq(n, 125, "pair count changed");
        bytes32 h0 = keccak256(IUniV2Factory(FACTORY).allPairs(0).code);
        for (uint256 i = 1; i < n; i++) {
            assertEq(keccak256(IUniV2Factory(FACTORY).allPairs(i).code), h0, "template mismatch");
        }
        emit log_named_uint("pairs", n);
        emit log_named_bytes32("pair codehash", h0);
    }

    /// No pair holds more tokens than its own reserves -> nothing to skim (excess == 0).
    function test_no_excess_all_pairs() public {
        uint256 n = IUniV2Factory(FACTORY).allPairsLength();
        uint256 checked;
        uint256 skipped;
        for (uint256 i = 0; i < n; i++) {
            address pair = IUniV2Factory(FACTORY).allPairs(i);
            (address t0, address t1) = (IUniV2Pair(pair).token0(), IUniV2Pair(pair).token1());
            (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
            (bool ok0, uint256 b0) = _bal(t0, pair);
            (bool ok1, uint256 b1) = _bal(t1, pair);
            if (!ok0 || !ok1) {
                skipped++;
                emit log_named_address("balanceOf failed, skipped pair", pair);
                continue;
            }
            checked++;
            assertEq(b0, uint256(r0), "excess token0");
            assertEq(b1, uint256(r1), "excess token1");
        }
        emit log_named_uint("pairs fully checked", checked);
        emit log_named_uint("skipped", skipped);
        assertGe(checked, n * 9 / 10, "too many pairs unreadable");
    }

    /// Unfair swaps on funded pairs must revert (k-invariant enforced), reserves untouched.
    function test_unfair_swap_reverts() public {
        address[6] memory pairs = [
            PAIR_USDT_NEAR,
            PAIR_NEAR_WETH,
            PAIR_USDC_NEAR,
            PAIR_USDT_USDC,
            PAIR_BRL_WETH,
            PAIR_XNEAR_NEAR
        ];
        for (uint256 i = 0; i < pairs.length; i++) {
            address pair = pairs[i];
            address t0 = IUniV2Pair(pair).token0();
            (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
            uint8 d0 = IERC20(t0).decimals();
            uint256 tinyIn = 10 ** uint256(d0); // 1 unit of token0
            if (!tryFund(t0, attacker, tinyIn)) {
                emit log_named_address("deal failed (skip pair)", pair);
                continue;
            }
            vm.prank(attacker);
            IERC20(t0).transfer(pair, tinyIn);
            vm.prank(attacker);
            (bool ok, bytes memory ret) =
                pair.call(abi.encodeWithSelector(IUniV2Pair.swap.selector, 0, uint256(r1) * 90 / 100, attacker, ""));
            assertFalse(ok, "unfair swap DID NOT revert");
            emit log_named_address("pair", pair);
            emit log_named_bytes("revert data", ret);
            (uint112 s0, uint112 s1,) = IUniV2Pair(pair).getReserves();
            assertEq(s0, r0, "reserves changed after failed swap (t0)");
            assertEq(s1, r1, "reserves changed after failed swap (t1)");
        }
    }

    /// The k-check revert reason is exactly "Aurora: K" on the main pair.
    function test_k_revert_reason_exact() public {
        (uint112 r0, uint112 r1,) = IUniV2Pair(PAIR_USDT_NEAR).getReserves();
        assertTrue(tryFund(USDT, attacker, 1e6), "deal USDT");
        vm.prank(attacker);
        IERC20(USDT).transfer(PAIR_USDT_NEAR, 1e6);
        vm.prank(attacker);
        (bool ok, bytes memory ret) = PAIR_USDT_NEAR.call(
            abi.encodeWithSelector(IUniV2Pair.swap.selector, 0, uint256(r1) * 90 / 100, attacker, "")
        );
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("Error(string)", "Aurora: K"), "unexpected revert reason");
        // reserves untouched
        (uint112 s0, uint112 s1,) = IUniV2Pair(PAIR_USDT_NEAR).getReserves();
        assertEq(s0, r0);
        assertEq(s1, r1);
    }

    /// A fair swap matches the 0.3%-fee constant-product formula exactly.
    function test_fair_swap_matches_formula() public {
        address pair = PAIR_USDT_NEAR;
        (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
        uint256 amtIn = 100e6; // 100 USDT
        uint256 expected = getAmountOut(amtIn, r0, r1);
        assertTrue(tryFund(USDT, attacker, amtIn), "deal USDT");
        vm.startPrank(attacker);
        IERC20(USDT).transfer(pair, amtIn);
        IUniV2Pair(pair).swap(0, expected, attacker, "");
        vm.stopPrank();
        (bool ok, uint256 got) = _bal(NEAR, attacker);
        assertTrue(ok);
        assertEq(got, expected, "output != formula");
        emit log_named_uint("USDT in", amtIn);
        emit log_named_uint("NEAR out (24dp)", got);
    }

    /// Add/remove liquidity round trip yields no profit (no LP math bug); fee mint dilutes.
    function test_lp_roundtrip_no_profit() public {
        address pair = PAIR_USDT_NEAR;
        (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
        uint256 amt0 = 100e6; // 100 USDT
        uint256 amt1 = (amt0 * uint256(r1)) / uint256(r0);
        assertTrue(tryFund(USDT, attacker, amt0), "deal USDT");
        assertTrue(tryFund(NEAR, attacker, amt1), "deal NEAR");
        vm.startPrank(attacker);
        IERC20(USDT).transfer(pair, amt0);
        IERC20(NEAR).transfer(pair, amt1);
        uint256 lp = IUniV2Pair(pair).mint(attacker);
        assertGt(lp, 0);
        IUniV2Pair(pair).transfer(pair, lp);
        (uint256 o0, uint256 o1) = IUniV2Pair(pair).burn(attacker);
        vm.stopPrank();
        assertLe(o0, amt0, "got more USDT back than deposited");
        assertLe(o1, amt1, "got more NEAR back than deposited");
        assertGe(o0, amt0 * 98 / 100, "unexpectedly large loss t0");
        assertGe(o1, amt1 * 98 / 100, "unexpectedly large loss t1");
        emit log_named_uint("USDT deposited", amt0);
        emit log_named_uint("USDT returned", o0);
        emit log_named_uint("NEAR deposited", amt1);
        emit log_named_uint("NEAR returned", o1);
    }

    /// Protocol fees accrue to feeTo only (permissionless mint, no attacker share).
    function test_feeto_fee_mint_only_to_feeto() public {
        address pair = PAIR_USDT_NEAR;
        (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
        uint256 feeBefore = IUniV2Pair(pair).balanceOf(FEE_TO);
        uint256 amt0 = 10e6;
        uint256 amt1 = (amt0 * uint256(r1)) / uint256(r0);
        assertTrue(tryFund(USDT, attacker, amt0), "deal USDT");
        assertTrue(tryFund(NEAR, attacker, amt1), "deal NEAR");
        vm.startPrank(attacker);
        IERC20(USDT).transfer(pair, amt0);
        IERC20(NEAR).transfer(pair, amt1);
        IUniV2Pair(pair).mint(attacker);
        vm.stopPrank();
        uint256 feeAfter = IUniV2Pair(pair).balanceOf(FEE_TO);
        assertGt(feeAfter, feeBefore, "no protocol fee minted");
        emit log_named_uint("kLast", IUniV2Pair(pair).kLast());
        emit log_named_uint("feeTo LP before", feeBefore);
        emit log_named_uint("feeTo LP after", feeAfter);
        emit log_named_uint("pair totalSupply", IUniV2Pair(pair).totalSupply());
    }

    /// skim() on a funded pair returns nothing (excess == 0).
    function test_skim_returns_zero() public {
        address[3] memory pairs = [PAIR_USDT_NEAR, PAIR_NEAR_WETH, PAIR_BRL_WETH];
        for (uint256 i = 0; i < pairs.length; i++) {
            address pair = pairs[i];
            address t0 = IUniV2Pair(pair).token0();
            address t1 = IUniV2Pair(pair).token1();
            (bool ok0, uint256 a0) = _bal(t0, attacker);
            (bool ok1, uint256 a1) = _bal(t1, attacker);
            vm.prank(attacker);
            IUniV2Pair(pair).skim(attacker);
            (bool ok0b, uint256 b0) = _bal(t0, attacker);
            (bool ok1b, uint256 b1) = _bal(t1, attacker);
            if (ok0 && ok0b) assertEq(b0, a0, "skim gave token0");
            if (ok1 && ok1b) assertEq(b1, a1, "skim gave token1");
        }
    }

    /// Synthetic: a donation to a pair makes the k-check bypassable (drain of the other side)
    /// until it is absorbed. Demonstrates the latent (not live) risk window.
    function test_donation_k_bypass_synthetic() public {
        address pair = PAIR_USDT_NEAR;
        (uint112 r0, uint112 r1,) = IUniV2Pair(pair).getReserves();
        // donation: 1e12 USDT (synthetic, via deal) to the pair
        uint256 donation = 1e12;
        assertTrue(tryFund(USDT, pair, uint256(r0) + donation), "deal donation");
        assertTrue(tryFund(USDT, attacker, 1e6), "deal attacker USDT");
        vm.prank(attacker);
        IERC20(USDT).transfer(pair, 1e6);
        vm.prank(attacker);
        // with the donation, an unfair swap (50% of the NEAR side) is accepted
        IUniV2Pair(pair).swap(0, uint256(r1) * 50 / 100, attacker, "");
        (bool ok, uint256 got) = _bal(NEAR, attacker);
        assertTrue(ok && got > 0, "drain did not work in synthetic case");
        emit log_named_uint("NEAR drained with 1e6 USDT in (synthetic)", got);
    }

    /// Synthetic: skim() is the permissionless mitigation for a donation — whoever calls it
    /// first recovers the excess (before any swap absorbs it into the reserves).
    function test_donation_skim_recovers() public {
        address pair = PAIR_USDT_NEAR;
        (uint112 r0,,) = IUniV2Pair(pair).getReserves();
        uint256 donation = 1e12;
        assertTrue(tryFund(USDT, pair, uint256(r0) + donation), "deal donation");
        uint256 before = IERC20(USDT).balanceOf(attacker);
        vm.prank(attacker);
        IUniV2Pair(pair).skim(attacker);
        uint256 recovered = IERC20(USDT).balanceOf(attacker) - before;
        emit log_named_uint("skim recovered USDT (synthetic)", recovered);
        assertGt(recovered, donation * 9 / 10, "skim did not recover the donation");
    }

    /// Pool-35 gap: permissionless updatePool mints ~3.4M BRL; pending goes to the existing
    /// staker (MC owner); a fresh address gets nothing.
    function test_farm_pool35_gap_goes_to_owner() public {
        IBRLMasterChef mc = IBRLMasterChef(MC);
        (address lp, uint256 alloc, uint256 lastReward, uint256 acc, uint16 feeBp) = mc.poolInfo(35);
        assertEq(lp, AZFD, "pool 35 lp token");
        assertEq(feeBp, 0);
        uint256 lpSupply = IERC20(AZFD).balanceOf(MC);
        assertEq(lpSupply, 1e18, "AZFD staked supply");
        (uint256 ownerAmt, uint256 ownerDebt) = mc.userInfo(35, MC_OWNER);
        assertEq(ownerAmt, 1e18, "owner stake");
        uint256 gap = block.number - lastReward;
        uint256 R = (gap * mc.BRLPerBlock() * alloc) / mc.totalAllocPoint();
        uint256 ownerPendingBefore = mc.pendingBRL(35, MC_OWNER);
        uint256 tsBefore = IERC20(BRL).totalSupply();
        uint256 mcBalBefore = IERC20(BRL).balanceOf(MC);

        vm.prank(attacker);
        mc.updatePool(35);

        uint256 minted = IERC20(BRL).totalSupply() - tsBefore;
        uint256 ownerPendingAfter = mc.pendingBRL(35, MC_OWNER);
        assertApproxEqRel(ownerPendingBefore, R, 0.01e18, "owner projected pending != gap reward");
        assertApproxEqRel(ownerPendingAfter, R, 0.01e18, "owner realized pending != gap reward");
        assertApproxEqRel(minted, R + R / 10, 0.01e18, "minted != R + dev 10%");
        assertEq(mc.pendingBRL(35, attacker), 0, "attacker got pending");
        assertEq(IERC20(BRL).balanceOf(attacker), 0, "attacker got BRL");
        emit log_named_uint("pool35 allocPoint", alloc);
        emit log_named_uint("gap blocks", gap);
        emit log_named_uint("BRL gap reward (1e18)", R);
        emit log_named_uint("BRL minted (MC+dev)", minted);
        emit log_named_uint("owner pending after", ownerPendingAfter);
        emit log_named_uint("MC BRL before", mcBalBefore);
        emit log_named_uint("owner rewardDebt", ownerDebt);
        emit log_named_uint("accBRLPerShare before", acc);
    }

    /// A fresh staker cannot capture a pre-existing gap: deposit() updates the pool first.
    function test_farm_fresh_stake_cannot_capture_gap() public {
        IBRLMasterChef mc = IBRLMasterChef(MC);
        address lp = LP_USDT_NEAR; // pool 4
        (, uint256 alloc, uint256 lastReward,,) = mc.poolInfo(4);
        uint256 lpSupplyBefore = IERC20(lp).balanceOf(MC);
        uint256 gap = block.number - lastReward;
        uint256 R = (gap * mc.BRLPerBlock() * alloc) / mc.totalAllocPoint();
        uint256 mcBalBefore = IERC20(BRL).balanceOf(MC);

        uint256 lpAmt = 1e18;
        assertTrue(tryFund(lp, attacker2, lpAmt), "deal LP");
        vm.startPrank(attacker2);
        IERC20(lp).approve(MC, lpAmt);
        mc.deposit(4, lpAmt); // triggers updatePool(4) -> mints the gap for EXISTING stakers
        uint256 pendingJustAfter = mc.pendingBRL(4, attacker2);
        mc.withdraw(4, lpAmt);
        vm.stopPrank();
        uint256 gained = IERC20(BRL).balanceOf(attacker2);
        uint256 mcBalAfter = IERC20(BRL).balanceOf(MC);

        emit log_named_uint("gap blocks (pool4)", gap);
        emit log_named_uint("gap reward R (pool4)", R);
        emit log_named_uint("MC BRL before", mcBalBefore);
        emit log_named_uint("MC BRL after", mcBalAfter);
        emit log_named_uint("fresh staker BRL gained", gained);
        assertGt(R, 1000e18, "pool4 gap should be material");
        assertGe(mcBalAfter, mcBalBefore + R * 9 / 10, "gap was not minted");
        assertLt(gained, 1e12, "fresh staker captured rewards");
        assertLt(pendingJustAfter, 1e12, "pending not ~0 right after fresh deposit");
        assertEq(lpSupplyBefore, IERC20(lp).balanceOf(MC), "MC lp supply not restored");
    }

    /// Privileged entry points revert for an unprivileged attacker.
    function test_privileged_gates_revert() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        IUniV2Factory(FACTORY).setFeeTo(attacker);
        vm.expectRevert();
        IUniV2Factory(FACTORY).setFeeToSetter(attacker);
        vm.expectRevert();
        IUniV2Factory(FACTORY).setLocked(true);
        vm.expectRevert();
        IBRLMasterChef(MC).updateEmissionRate(1e18);
        vm.expectRevert();
        IBRLMasterChef(MC).set(35, 0, 0, false);
        vm.expectRevert();
        IBRLMasterChef(MC).add(1, IERC20(BRL), 0, false);
        vm.expectRevert();
        IBRLMasterChef(MC).dev(attacker);
        vm.expectRevert();
        IBRLMasterChef(MC).setFeeAddress(attacker);
        vm.expectRevert();
        IERC20(BRL).mint(attacker, 1e24); // BRL owned by MasterChef
        vm.stopPrank();
        assertEq(IBRLMasterChef(MC).owner(), MC_OWNER);
        assertEq(IBRLMasterChef(MC).BRL(), BRL);
        assertEq(IUniV2Factory(FACTORY).feeTo(), FEE_TO);
        assertEq(IUniV2Factory(FACTORY).feeToSetter(), FEE_TO);
        assertFalse(IUniV2Factory(FACTORY).locked());
    }

    /// Arb upper bound on the main pair at the pinned block.
    /// p6 = USDT (6dp) per whole NEAR (DefiLlama global, 2026-10-12). NOTE: the Aurora-local
    /// wNEAR price (Trisolaris/WannaSwap) is ~2.8% lower, at which there is no arb at all.
    function test_arb_upper_bound_main_pair() public {
        (uint112 r0, uint112 r1,) = IUniV2Pair(PAIR_USDT_NEAR).getReserves();
        uint256 x = uint256(r0); // USDT 6dp
        uint256 y = uint256(r1); // NEAR 24dp
        uint256 p6 = 5505000; // USDT 6dp per 1e24 NEAR (DefiLlama global)
        uint256 f = 997;
        uint256 k = x * y;
        uint256 kScaled = k / 1e24;
        uint256 rhs = (kScaled * p6 * f) / 1000; // USDT_raw^2
        uint256 root = sqrt(rhs);
        emit log_named_uint("pool price USDT(6dp) per NEAR(1e18)", (x * 1e18) / y);
        emit log_named_uint("reserve USDT", x);
        emit log_named_uint("reserve NEAR", y);
        if (root > x) {
            uint256 d = ((root - x) * 1000) / f;
            uint256 out = y - (k * 1000) / (x * 1000 + f * d);
            uint256 value6 = (out * p6) / 1e24;
            uint256 profit6 = value6 > d ? value6 - d : 0;
            emit log_named_uint("optimal USDT in (6dp)", d);
            emit log_named_uint("NEAR out (24dp)", out);
            emit log_named_uint("profit (USDT 6dp)", profit6);
            assertLt(profit6, 100e6, "arb profit unexpectedly large");
        } else {
            emit log("no arb direction at this block");
        }
    }
}
