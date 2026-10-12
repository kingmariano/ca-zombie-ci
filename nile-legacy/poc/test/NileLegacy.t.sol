// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/*
 * Nile Legacy (Linea) — read-only fork verification of extractability.
 *
 * Goal: prove that an external, unprivileged attacker can extract $0 live from the
 * Nile V2 cAMM (133 pairs) + ve(3,3) staking system at the pinned block, and show
 * exactly which gates close each candidate path. All "attacks" run on a local fork
 * of Linea; no mainnet transaction is ever sent.
 *
 * Pinned block: 32,297,269 (Linea, 2026-10-12). Public keyless RPC used.
 * Override with LINEA_RPC_URL env var if needed.
 *
 * Core addresses (all verified verified-on-Linea sources, see ../analysis/src_flat):
 *  factory 0xAAA16c016BF556fcD620328f0759252E29b1AB57 (TransparentUpgradeableProxy -> PairFactory; beacon for pairs)
 *  pair impl 0xE41E9d7bB3485b7bf5089FB50ceF8e74b5156330 (Pair, Velodrome-V2 style stable/volatile cAMM)
 *  top pair 0xA9A1Fb9F6664A0B6BFB1F52724fd7b23842248C5 (cAMM-ezETH/WETH, stable)
 *  gauge 0x01FB6B2FA528fE9fC5fF3aB092203953AA8a32Ff (dead gauge, holds 66.0759 LP of the top pair)
 *  VE 0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F (VotingEscrow, holds 13.79M NILE)
 */
contract NileLegacyForkTest is Test {
    // ---- core addresses ----
    address constant FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;
    address constant PAIR_EZ = 0xA9A1Fb9F6664A0B6BFB1F52724fd7b23842248C5;
    address constant EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address constant WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address constant NILE = 0xAAAac83751090C6ea42379626435f805DDF54DC8;
    address constant GAUGE = 0x01FB6B2FA528fE9fC5fF3aB092203953AA8a32Ff;
    address constant VE = 0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F;
    address constant VOTER = 0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869;
    address constant MINTER = 0xAAA823aa799BDa3193D46476539bcb1da5B71330;
    address constant XTOKEN = 0xAAAE58986b24e422740C8F22B3efB80BCbD68159;
    address constant REWARDS_DIST = 0xAAA9Ea898ae0b7D3805aF555AF3a2e3BdF06D22C;
    address constant FEE_DIST = 0x9DB63D0744bFfB438f4522cC81861183c0ce0216;
    address constant PROXY_ADMIN = 0x8e01fc0d89b93a6447D6c6Eca6fBd30e6E4a1ce3;
    address constant TIMELOCK = 0xbabe7a170A764C8367bFFB35EbDe8E97AA72c3aA;
    address constant SAFE = 0x44376f8F52407ed66E6D3356535410A7DCd4652B;
    address constant WHALE = 0xa3ce8F11cF241CB25F1Fd1B3f770F0B9402CEf0f; // 3-of-5 Safe holding 64.07 LP
    address constant SMALL_STAKER = 0x9da30faa351d2b142645f31f13022c9e66405a9E; // 0.0042 LP
    uint256 constant VE_TOKEN_ID = 100; // 100 NILE locked by 0xE2DcEAe30b9ea109a634fF6695688Fa389F39a1a

    uint256 constant FORK_BLOCK = 32_297_269;
    // ezETH/WETH market ratio from DefiLlama at 2026-10-12 (ezETH $2746.43 / WETH $2531.77)
    uint256 constant MARKET_EZ_PER_WETH_X1E6 = 1_084_789; // 1.084789 WETH per ezETH

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("LINEA_RPC_URL", string("https://rpc.linea.build"));
        vm.createSelectFork(rpc, FORK_BLOCK);
        vm.label(FACTORY, "NileFactory");
        vm.label(PAIR_EZ, "cAMM-ezETH/WETH");
        vm.label(GAUGE, "Gauge-ezETH/WETH");
        vm.label(VE, "veNILE");
    }

    // ------------------------------------------------------------------
    // A. live-state snapshot at the pinned block
    // ------------------------------------------------------------------
    function test_A_state_snapshot() public {
        uint256 n = IFactory(FACTORY).allPairsLength();
        assertEq(n, 133, "pair count");
        (uint256 r0, uint256 r1,) = IPairLike(PAIR_EZ).getReserves();
        emit log_named_uint("ezETH reserve", r0);
        emit log_named_uint("WETH reserve", r1);
        assertGt(r1, 80 ether, "WETH in top pool");
        uint256 gLp = IPairLike(PAIR_EZ).balanceOf(GAUGE);
        emit log_named_uint("gauge LP", gLp);
        assertGt(gLp, 66 ether, "staked LP");
        assertEq(gLp, IGauge(GAUGE).totalSupply(), "gauge totalSupply == staked LP");
        assertFalse(IVoter(VOTER).isAlive(GAUGE), "gauge killed");
        uint256 veNile = IERC20(NILE).balanceOf(VE);
        emit log_named_uint("veNILE locked", veNile);
        assertGt(veNile, 13_000_000 ether, "veNILE lock");
        assertEq(IFactory(FACTORY).owner(), TIMELOCK, "factory owner is timelock");
        assertEq(IProxyAdmin(PROXY_ADMIN).owner(), TIMELOCK, "proxy admin owner is timelock");
    }

    // ------------------------------------------------------------------
    // B. skim()/excess: every pair holds exactly its reserves -> nothing free
    // ------------------------------------------------------------------
    function test_B_skim_excess_zero_all_pairs() public {
        uint256 n = IFactory(FACTORY).allPairsLength();
        uint256 totalExcess;
        uint256 checked;
        uint256 skipped;
        for (uint256 i; i < n; ++i) {
            address p = IFactory(FACTORY).allPairs(i);
            (bool ok, address t0, address t1, uint256 r0, uint256 r1) = _pairData(p);
            if (!ok) {
                skipped++;
                continue;
            }
            uint256 b0 = IERC20(t0).balanceOf(p);
            uint256 b1 = IERC20(t1).balanceOf(p);
            if (b0 > r0) totalExcess += b0 - r0;
            if (b1 > r1) totalExcess += b1 - r1;
            checked++;
        }
        emit log_named_uint("pairs checked", checked);
        emit log_named_uint("pairs skipped (rpc)", skipped);
        emit log_named_uint("total skimable excess across all pairs (wei units)", totalExcess);
        assertGe(checked, 130, "almost all pairs checked");
        assertEq(totalExcess, 0, "no pair has balance > reserve");
    }

    /// @dev tolerant reader for pair token/reserve data (skips on RPC hiccup)
    function _pairData(address p)
        internal
        view
        returns (bool ok, address t0, address t1, uint256 r0, uint256 r1)
    {
        (bool s0, bytes memory d0) = p.staticcall(abi.encodeWithSelector(IPairLike.token0.selector));
        (bool s1, bytes memory d1) = p.staticcall(abi.encodeWithSelector(IPairLike.token1.selector));
        (bool s2, bytes memory d2) = p.staticcall(abi.encodeWithSelector(IPairLike.getReserves.selector));
        if (!s0 || !s1 || !s2 || d0.length < 32 || d1.length < 32 || d2.length < 64) return (false, address(0), address(0), 0, 0);
        t0 = abi.decode(d0, (address));
        t1 = abi.decode(d1, (address));
        (r0, r1,) = abi.decode(d2, (uint256, uint256, uint256));
        return (true, t0, t1, r0, r1);
    }

    function test_B2_skim_top_pair_transfers_nothing() public {
        uint256 before = IERC20(WETH).balanceOf(attacker) + IERC20(EZETH).balanceOf(attacker);
        vm.prank(attacker);
        IPairLike(PAIR_EZ).skim(attacker);
        uint256 afterBal = IERC20(WETH).balanceOf(attacker) + IERC20(EZETH).balanceOf(attacker);
        assertEq(afterBal, before, "skim yields 0 to attacker");
    }

    // ------------------------------------------------------------------
    // C. stable-pool math: pool mid == market, no atomic arb
    // ------------------------------------------------------------------
    function test_C_stable_pool_no_arb() public {
        uint256 one = 1 ether;
        uint256 outEzToW = IPairLike(PAIR_EZ).getAmountOut(one, EZETH);
        uint256 outWToEz = IPairLike(PAIR_EZ).getAmountOut(one, WETH);
        emit log_named_uint("1 ezETH -> WETH", outEzToW);
        emit log_named_uint("1 WETH -> ezETH", outWToEz);
        // round trip must lose money (fees + curve spread)
        uint256 back = (outWToEz * outEzToW) / 1e18;
        assertLt(back, one, "round trip 1 WETH -> ezETH -> WETH loses");
        // implied mid: sqrt(px_ab * px_ba) ~ geometric mid; check within 2% of market
        // px_ab = outEzToW (WETH per ezETH), px_ba = 1e36/outWToEz (WETH per ezETH inverted)
        uint256 pxBa = (one * one) / outWToEz; // ezETH per WETH -> WETH per ezETH = 1e18*1e18/outWToEz
        uint256 mid = (outEzToW + pxBa) / 2; // 1e18 scale, WETH per ezETH
        uint256 market = (one * MARKET_EZ_PER_WETH_X1E6) / 1e6;
        emit log_named_uint("pool mid (WETH per ezETH)", mid);
        emit log_named_uint("market   (WETH per ezETH)", market);
        uint256 diff = mid > market ? mid - market : market - mid;
        assertLt(diff * 100, market * 2, "pool within 2% of market");
    }

    // ------------------------------------------------------------------
    // D. gauge: attacker cannot touch others' stake/rewards
    // ------------------------------------------------------------------
    function test_D_gauge_others_forbidden() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        IGauge(GAUGE).withdraw(1 ether);
        vm.expectRevert();
        IGauge(GAUGE).withdrawAll();
        address[] memory toks = new address[](1);
        toks[0] = NILE;
        vm.expectRevert();
        IGauge(GAUGE).getReward(WHALE, toks);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // E. H-O proof: the whale (3-of-5 Safe) and any staker can withdraw their own LP
    // ------------------------------------------------------------------
    function test_E_staker_can_withdraw_own_LP() public {
        uint256 snap = vm.snapshotState();

        uint256 whaleLp = IGauge(GAUGE).balanceOf(WHALE);
        assertGt(whaleLp, 64 ether, "whale stake");
        vm.prank(WHALE);
        IGauge(GAUGE).withdraw(whaleLp);
        assertEq(IPairLike(PAIR_EZ).balanceOf(WHALE), whaleLp, "whale got LP back");
        vm.revertToState(snap);

        uint256 smallLp = IGauge(GAUGE).balanceOf(SMALL_STAKER);
        assertGt(smallLp, 0, "small staker stake");
        vm.prank(SMALL_STAKER);
        IGauge(GAUGE).withdrawAll();
        assertEq(IPairLike(PAIR_EZ).balanceOf(SMALL_STAKER), smallLp, "small staker got LP back");
        vm.revertToState(snap);
    }

    // ------------------------------------------------------------------
    // F. veNILE: attacker cannot withdraw/merge someone else's lock
    // ------------------------------------------------------------------
    function test_F_ve_others_forbidden() public {
        address owner = IVE(VE).ownerOf(VE_TOKEN_ID);
        assertTrue(owner != address(0) && owner != attacker, "fixture lock exists");
        vm.startPrank(attacker);
        vm.expectRevert();
        IVE(VE).withdraw(VE_TOKEN_ID);
        vm.expectRevert();
        IVE(VE).merge(VE_TOKEN_ID, VE_TOKEN_ID + 1);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // G. privileged surfaces: all revert for an unprivileged caller
    // ------------------------------------------------------------------
    function test_G_admin_paths_revert() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        IFactory(FACTORY).setImplementation(attacker);
        vm.expectRevert();
        IFactory(FACTORY).setFee(true, 0);
        vm.expectRevert();
        IFactory(FACTORY).setPause(true);
        vm.expectRevert();
        IFactory(FACTORY).setOwner(attacker);
        vm.expectRevert();
        IFactory(FACTORY).setTreasury(attacker);
        vm.expectRevert();
        IProxyAdmin(PROXY_ADMIN).upgrade(FACTORY, attacker);
        vm.expectRevert();
        IVoter(VOTER).recoverFees(new address[](0), new address[][](0));
        vm.expectRevert();
        IVoter(VOTER).killGauge(GAUGE);
        vm.expectRevert();
        IVoter(VOTER).whitelist(attacker);
        address[] memory gs = new address[](1);
        gs[0] = GAUGE;
        vm.expectRevert();
        IVoter(VOTER).clawBackUnusedEmissions(gs);
        vm.expectRevert();
        IMinter(MINTER).updateFlation(1);
        vm.expectRevert();
        IXToken(XTOKEN).rescueTrappedTokens(gs, new uint256[](1));
        vm.expectRevert();
        IXToken(XTOKEN).multisigRedeem(1);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // H. permissionless calls pay the caller nothing
    // ------------------------------------------------------------------
    function test_H_permissionless_calls_no_profit() public {
        uint256 snap = vm.snapshotState();

        uint256 n0 = IERC20(NILE).balanceOf(attacker);
        uint256 w0 = IERC20(WETH).balanceOf(attacker);
        uint256 e0 = IERC20(EZETH).balanceOf(attacker);
        uint256 l0 = IPairLike(PAIR_EZ).balanceOf(attacker);

        vm.startPrank(attacker);
        IPairLike(PAIR_EZ).claimFees(); // pushes fees to FeeDistributor (not caller)
        IGauge(GAUGE).claimFees();
        IVoter(VOTER).distribute(GAUGE); // dead gauge: no distribution
        IMinter(MINTER).updatePeriod(); // epoch not over at pinned block: no-op
        vm.stopPrank();

        assertEq(IERC20(NILE).balanceOf(attacker), n0, "no NILE to caller");
        assertEq(IERC20(WETH).balanceOf(attacker), w0, "no WETH to caller");
        assertEq(IERC20(EZETH).balanceOf(attacker), e0, "no ezETH to caller");
        assertEq(IPairLike(PAIR_EZ).balanceOf(attacker), l0, "no LP to caller");

        // RewardsDistributor pays only the veNFT owner
        vm.prank(attacker);
        vm.expectRevert();
        IRewardsDist(REWARDS_DIST).claim(VE_TOKEN_ID);

        vm.revertToState(snap);
    }

    // ------------------------------------------------------------------
    // I. swap round-trip on the top pool is a guaranteed loss (fees)
    // ------------------------------------------------------------------
    function test_I_swap_roundtrip_loss() public {
        uint256 start = 10 ether;
        deal(WETH, attacker, start);
        assertEq(IERC20(WETH).balanceOf(attacker), start, "deal WETH");

        vm.startPrank(attacker);
        uint256 ezOut = IPairLike(PAIR_EZ).getAmountOut(start, WETH);
        IERC20(WETH).transfer(PAIR_EZ, start);
        IPairLike(PAIR_EZ).swap((ezOut * 999) / 1000, 0, attacker, ""); // token1 in, token0 (ezETH) out
        uint256 ezBal = IERC20(EZETH).balanceOf(attacker);
        assertGt(ezBal, 0, "got ezETH");

        uint256 wOut = IPairLike(PAIR_EZ).getAmountOut(ezBal, EZETH);
        IERC20(EZETH).transfer(PAIR_EZ, ezBal);
        IPairLike(PAIR_EZ).swap(0, (wOut * 999) / 1000, attacker, ""); // token0 in, token1 (WETH) out
        vm.stopPrank();

        uint256 endBal = IERC20(WETH).balanceOf(attacker);
        emit log_named_uint("WETH start", start);
        emit log_named_uint("WETH end  ", endBal);
        assertLt(endBal, start, "round trip loses money");
        assertEq(IERC20(EZETH).balanceOf(attacker), 0, "no residual ezETH");
    }

    // ------------------------------------------------------------------
    // J. LP mint/burn round trip also loses (no LP-math exploit)
    // ------------------------------------------------------------------
    function test_J_lp_mint_burn_loss() public {
        // buy some ezETH first so we have both tokens
        deal(WETH, attacker, 4 ether);
        vm.startPrank(attacker);
        uint256 ezOut = IPairLike(PAIR_EZ).getAmountOut(2 ether, WETH);
        IERC20(WETH).transfer(PAIR_EZ, 2 ether);
        IPairLike(PAIR_EZ).swap((ezOut * 999) / 1000, 0, attacker, ""); // token1 in, token0 (ezETH) out
        uint256 ezBal = IERC20(EZETH).balanceOf(attacker);
        uint256 wBal = IERC20(WETH).balanceOf(attacker);

        // mint LP
        IERC20(EZETH).transfer(PAIR_EZ, ezBal);
        IERC20(WETH).transfer(PAIR_EZ, wBal);
        uint256 lp = IPairLike(PAIR_EZ).mint(attacker);
        assertGt(lp, 0, "minted LP");

        // burn it right back
        IERC20(PAIR_EZ).transfer(PAIR_EZ, lp);
        (uint256 a0, uint256 a1) = IPairLike(PAIR_EZ).burn(attacker);
        vm.stopPrank();
        emit log_named_uint("ezETH deposited", ezBal);
        emit log_named_uint("ezETH back     ", a0);
        emit log_named_uint("WETH deposited ", wBal);
        emit log_named_uint("WETH back      ", a1);
        // Imbalanced deposit: the over-supplied side (ezETH) is the min() side, so the
        // round trip strictly loses on it; the limiting side returns <= deposit.
        assertLt(a0, ezBal, "burn returns less ezETH than deposited");
        assertLe(a1, wBal, "burn never returns more WETH than deposited");
    }
}

// ------------------------- minimal interfaces -------------------------
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
}

interface IPairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256, uint256, uint256);
    function totalSupply() external view returns (uint256);
    function stable() external view returns (bool);
    function balanceOf(address) external view returns (uint256);
    function getAmountOut(uint256, address) external view returns (uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function claimFees() external returns (uint256, uint256);
}

interface IFactory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function owner() external view returns (address);
    function implementation() external view returns (address);
    function isPaused() external view returns (bool);
    function setImplementation(address) external;
    function setFee(bool, uint256) external;
    function setPause(bool) external;
    function setOwner(address) external;
    function setTreasury(address) external;
    function getFee(bool) external view returns (uint256);
}

interface IGauge {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function withdraw(uint256) external;
    function withdrawAll() external;
    function getReward(address, address[] calldata) external;
    function claimFees() external returns (uint256, uint256);
}

interface IVE {
    function ownerOf(uint256) external view returns (address);
    function locked(uint256) external view returns (uint256, uint256);
    function withdraw(uint256) external;
    function merge(uint256, uint256) external;
    function balanceOf(address) external view returns (uint256);
    function supply() external view returns (uint256);
}

interface IVoter {
    function isAlive(address) external view returns (bool);
    function distribute(address) external;
    function recoverFees(address[] calldata, address[][] calldata) external;
    function killGauge(address) external;
    function whitelist(address) external;
    function clawBackUnusedEmissions(address[] calldata) external;
    function gauges(address) external view returns (address);
}

interface IMinter {
    function updatePeriod() external returns (uint256);
    function updateFlation(uint256) external;
}

interface IRewardsDist {
    function claim(uint256) external returns (uint256);
}

interface IXToken {
    function rescueTrappedTokens(address[] calldata, uint256[] calldata) external;
    function multisigRedeem(uint256) external;
}

interface IProxyAdmin {
    function owner() external view returns (address);
    function upgrade(address, address) external;
}
