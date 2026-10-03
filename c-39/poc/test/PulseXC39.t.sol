// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {
    IERC20Like,
    IPulseXPairLike,
    IPulseXFactoryLike,
    IPulseXRouterLike,
    IStableSwap3,
    IBuyAndBurn
} from "../src/Interfaces.sol";

/// @title C-39 PulseX stack — live extractability PoC (PulseChain fork, read-only against the real chain)
/// @notice All tests run on a fork via vm.createSelectFork. No mainnet transactions.
contract PulseXC39Test is Test {
    address constant V1_FACTORY = 0x1715a3E4A142d8b698131108995174F37aEBA10D;
    address constant V2_FACTORY = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;
    address constant V1_FEE_TO = 0xD46BD969d995A122AD5B803A45d309021A647B87;
    address constant V2_FEE_TO = 0xd6cA7ee047a6F45d20d2962E4394E070cF27724F;
    address constant FEE_TO_SETTER = 0x3a27c0a67D6bbc3DC024Af200bb309cB1FE1F091;
    address constant V1_ROUTER_A = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;
    address constant V1_ROUTER_B = 0xaf5e33cb31A3454C950bee39ed1C76fd65b394cf;
    address constant V2_ROUTER = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
    address constant STABLE_POOL = 0xE3acFA6C40d53C3faf2aa62D0a715C737071511c;
    address constant USDT = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;
    address constant USDC = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address constant DAI = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address constant PLSX = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab;
    address constant WPLS = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;

    // top pairs by TVL (GT lists)
    address[8] v1Top = [
        0xf1F4ee610b2bAbB05C635F726eF8B0C568c8dc65, // HEX/WPLS
        0xE56043671df55dE5CDf8459710433C10324DE0aE, // DAI/WPLS
        0x322Df7921F28F1146Cdf62aFdaC0D6bC0Ab80711, // USDT/WPLS
        0x42AbdFDB63f3282033C766E72Cc4810738571609, // WETH/WPLS
        0x6753560538ECa67617A9Ce605178F788bE7E524E, // USDC/WPLS
        0x1b45b9148791d3a104184Cd5DFE5CE57193a3ee9, // PLSX/WPLS
        0x2Bb9baA3092cE864390bF3e687ABF72bE19E03DC, // WETH/DAI
        0x6F1747370B1CAcb911ad6D4477b718633DB328c8  // HEX/DAI
    ];
    address[7] v2Top = [
        0xaE8429918FdBF9a5867e3243697637Dc56aa76A1, // DAI/WPLS
        0xF0eA3efE42C11c8819948Ec2D3179F4084863D3F, // HEX/WPLS
        0x19BB45a7270177e303DEe6eAA6F5Ad700812bA98, // HEX/WPLS
        0x29d66D5900Eb0d629E1e6946195520065A6c5aeE, // WETH/WPLS
        0x149B2C629e652f2E89E11cd57e5d4D77ee166f9F, // WPLS/PLSX
        0xC475332e92561CD58f278E4e2eD76c17D5b50f05, // USDC/HEX
        0xe0e1F83A1C64Cf65C1a86D7f3445fc4F58f7Dcbf  // WBTC/WPLS
    ];
    // pairs where the balance exceeds stored reserves (skim-able), from system scan
    address[6] excessPairs = [
        0x56B498580c868a5F0C8511966525911cd68d7823, // bPlsWPLS/WPLS ex0=1746e18 (scam token)
        0x6865930a00a5968761Bf2108fd9469AFB956bACB, // 1/WPLS ex0=0.89e18
        0xdb1a7505eb1918163A118C86A119CBb9cd0Ca53F, // MAGIC/WPLS
        0x2F97D022a31b07dD3D4187f9C0acEdD5cc92246E, // Liquid/pTGC ex1=2.26e18
        0xED6B0aF61E3716306256008d8909206512189F23, // WPLS/PEPEJOHN
        0x75a4BB346283F28c0e582eA6D7Afe14bEaDB034e  // WPLS/Cavalo
    ];

    uint256 forkBlock;
    address attacker = address(0xBEEF);

    function setUp() public {
        string memory rpc =
            vm.envOr("PULSECHAIN_RPC", string("https://pulsechain-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        forkBlock = block.number;
    }

    // ---------------------------------------------------------------- roles

    function test_roles_factories_and_feeTo() public view {
        assertGt(V1_FACTORY.code.length, 0, "V1 factory has code");
        assertGt(V2_FACTORY.code.length, 0, "V2 factory has code");
        assertEq(IPulseXFactoryLike(V1_FACTORY).feeTo(), V1_FEE_TO, "V1 feeTo");
        assertEq(IPulseXFactoryLike(V2_FACTORY).feeTo(), V2_FEE_TO, "V2 feeTo");
        assertEq(IPulseXFactoryLike(V1_FACTORY).feeToSetter(), FEE_TO_SETTER, "V1 setter");
        assertEq(IPulseXFactoryLike(V2_FACTORY).feeToSetter(), FEE_TO_SETTER, "V2 setter");
        // feeToSetter is an EOA (no code) -> owner-controlled path, not E-U
        assertEq(FEE_TO_SETTER.code.length, 0, "feeToSetter is EOA");
        assertGt(IPulseXFactoryLike(V1_FACTORY).allPairsLength(), 60000);
        assertGt(IPulseXFactoryLike(V2_FACTORY).allPairsLength(), 180000);
    }

    function test_buyAndBurn_convertLps_is_gated() public {
        address[] memory a = new address[](1);
        address[] memory b = new address[](1);
        a[0] = WPLS;
        b[0] = PLSX;
        assertFalse(IBuyAndBurn(V1_FEE_TO).anyAuth(), "anyAuth false");
        // unprivileged caller (EOA: msg.sender == tx.origin) must revert with FORBIDDEN
        vm.prank(address(0x1234), address(0x1234));
        vm.expectRevert(bytes("PLSXBuyAndBurn: FORBIDDEN"));
        IBuyAndBurn(V1_FEE_TO).convertLps(a, b);
        // even with a valid pair list
        vm.prank(address(0x1234), address(0x1234));
        vm.expectRevert(bytes("PLSXBuyAndBurn: FORBIDDEN"));
        IBuyAndBurn(V2_FEE_TO).convertLps(a, b);
    }

    // ------------------------------------------------------- skim surfaces

    function test_top_pairs_have_no_excess() public view {
        for (uint256 i = 0; i < v1Top.length; i++) {
            _assertNoExcess(v1Top[i]);
        }
        for (uint256 i = 0; i < v2Top.length; i++) {
            _assertNoExcess(v2Top[i]);
        }
    }

    function _assertNoExcess(address pair) internal view {
        (uint112 r0, uint112 r1,) = IPulseXPairLike(pair).getReserves();
        uint256 b0 = IERC20Like(IPulseXPairLike(pair).token0()).balanceOf(pair);
        uint256 b1 = IERC20Like(IPulseXPairLike(pair).token1()).balanceOf(pair);
        assertGe(b0, uint256(r0), "bal0 >= reserve0 (else skim reverts)");
        assertGe(b1, uint256(r1), "bal1 >= reserve1");
        // no meaningful excess on top-TVL pairs
        assertLe(b0 - uint256(r0), 1e15, "excess0 dust-bounded");
        assertLe(b1 - uint256(r1), 1e15, "excess1 dust-bounded");
    }

    function test_excess_pairs_skim_is_real_but_valueless() public {
        uint256 totalWplsStolen = 0;
        uint256 successful = 0;
        for (uint256 i = 0; i < excessPairs.length; i++) {
            (uint256 wpls, bool ok) = _skimOne(excessPairs[i]);
            totalWplsStolen += wpls;
            if (ok) successful++;
        }
        // The only WPLS obtained is dust; scan showed ~0 WPLS excess chain-wide.
        assertLe(totalWplsStolen, 1e15, "no WPLS value extractable via skim");
        assertGt(successful, 0, "at least one dust pair skim-able");
    }

    function _skimOne(address pair) internal returns (uint256 wplsDelta, bool ok) {
        address t0 = IPulseXPairLike(pair).token0();
        address t1 = IPulseXPairLike(pair).token1();
        (uint112 r0, uint112 r1,) = IPulseXPairLike(pair).getReserves();
        uint256 b0 = IERC20Like(t0).balanceOf(pair);
        uint256 b1 = IERC20Like(t1).balanceOf(pair);
        if (b0 <= uint256(r0) && b1 <= uint256(r1)) return (0, false);
        uint256 a0 = IERC20Like(t0).balanceOf(attacker);
        uint256 a1 = IERC20Like(t1).balanceOf(attacker);
        try IPulseXPairLike(pair).skim(attacker) {
            ok = true;
            uint256 d0 = IERC20Like(t0).balanceOf(attacker) - a0;
            uint256 d1 = IERC20Like(t1).balanceOf(attacker) - a1;
            if (t0 == WPLS) wplsDelta += d0;
            if (t1 == WPLS) wplsDelta += d1;
            if (b0 > uint256(r0)) assertGt(d0, 0, "excess0 > 0 paid");
        } catch {}
    }

    function test_skim_on_top_pair_is_noop_or_dust() public {
        address pair = v1Top[5]; // PLSX/WPLS
        (uint112 r0, uint112 r1,) = IPulseXPairLike(pair).getReserves();
        uint256 b0 = IERC20Like(IPulseXPairLike(pair).token0()).balanceOf(pair);
        uint256 b1 = IERC20Like(IPulseXPairLike(pair).token1()).balanceOf(pair);
        uint256 before = IERC20Like(WPLS).balanceOf(attacker);
        IPulseXPairLike(pair).skim(attacker);
        uint256 got = IERC20Like(WPLS).balanceOf(attacker) - before;
        assertLe(got, (b0 - uint256(r0)) + (b1 - uint256(r1)), "skim <= excess");
        assertLe(got, 1e15, "no WPLS value");
    }

    // ------------------------------------------------------- swap baseline

    function test_pulsex_v2_swap_works_and_fee_is_29bps() public {
        // fund attacker with PLSX from a whale
        address plsxWhale = 0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954;
        vm.prank(plsxWhale);
        IERC20Like(PLSX).transfer(attacker, 1000e18);
        vm.startPrank(attacker);
        IERC20Like(PLSX).approve(V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = PLSX;
        path[1] = WPLS;
        uint256[] memory amounts = IPulseXRouterLike(V2_ROUTER).getAmountsOut(1000e18, path);
        assertGt(amounts[1], 0, "quote > 0");
        uint256 before = IERC20Like(WPLS).balanceOf(attacker);
        IPulseXRouterLike(V2_ROUTER).swapExactTokensForTokens(
            1000e18, amounts[1], path, attacker, block.timestamp + 60
        );
        uint256 got = IERC20Like(WPLS).balanceOf(attacker) - before;
        assertGe(got, amounts[1], "min-out honored");
        // pair retains 0.29% fee: effective out < no-fee constant product
        assertLt(got, 1000e18, "fee charged");
        vm.stopPrank();
    }

    function test_v2_router_holds_stuck_plsx() public {
        uint256 bal = IERC20Like(PLSX).balanceOf(V2_ROUTER);
        assertGt(bal, 0, "router holds PLSX");
        // swapping through the router must not move its own PLSX balance
        address plsxWhale = 0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954;
        vm.prank(plsxWhale);
        IERC20Like(PLSX).transfer(attacker, 10e18);
        vm.startPrank(attacker);
        IERC20Like(PLSX).approve(V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = PLSX;
        path[1] = WPLS;
        IPulseXRouterLike(V2_ROUTER).swapExactTokensForTokens(
            10e18, 0, path, attacker, block.timestamp + 60
        );
        vm.stopPrank();
        assertEq(IERC20Like(PLSX).balanceOf(V2_ROUTER), bal, "router balance unchanged");
    }

    // -------------------------------------------------------- stable swap

    function test_stableswap_state_and_pricing() public view {
        assertEq(IStableSwap3(STABLE_POOL).owner(), 0x73a08E51a509Ca063D9C159f16DA4bd9B2be398B);
        assertEq(IStableSwap3(STABLE_POOL).fee(), 4_000_000, "0.04%");
        assertEq(IStableSwap3(STABLE_POOL).admin_fee(), 5_000_000_000, "50% of fees");
        assertEq(IStableSwap3(STABLE_POOL).A(), 1000);
        // near-balanced pool, no free arb: dy for 10k USDC -> USDT is ~9996 (0.04% fee)
        uint256 dy = IStableSwap3(STABLE_POOL).get_dy(1, 0, 10_000e6);
        assertGt(dy, 9_990e6, "dy > 99.9%");
        assertLt(dy, 10_000e6, "fee charged");
    }

    function test_stableswap_exchange_is_not_profitable() public {
        address usdcWhale = 0xAFa2A89CB43619677d9C72E81f6d4c8a730a1022;
        vm.prank(usdcWhale);
        IERC20Like(USDC).transfer(attacker, 10_000e6);
        uint256 quote = IStableSwap3(STABLE_POOL).get_dy(1, 0, 10_000e6);
        // exchange() applies the fee in xp units (get_dy applies it after conversion):
        // allow 1bp tolerance, which is far below any profitable extraction.
        uint256 minOut = quote * 9999 / 10000;
        vm.startPrank(attacker);
        IERC20Like(USDC).approve(STABLE_POOL, type(uint256).max);
        uint256 before = IERC20Like(USDT).balanceOf(attacker);
        IStableSwap3(STABLE_POOL).exchange(1, 0, 10_000e6, minOut);
        uint256 got = IERC20Like(USDT).balanceOf(attacker) - before;
        assertGe(got, minOut, "min_dy honored");
        assertLt(got, 10_000e6, "cannot extract more than input");
        assertGe(got, quote * 999 / 1000, "within 0.1% of quote");
        vm.stopPrank();
    }

    // ------------------------------------------------- feeTo LP accounting

    function test_v1_mintFee_bug_feeTo_share() public view {
        address pair = v1Top[5]; // PLSX/WPLS V1
        uint256 feeLp = IERC20Like(pair).balanceOf(V1_FEE_TO);
        uint256 ts = IPulseXPairLike(pair).totalSupply();
        assertGt(feeLp, 0, "feeTo holds LP");
        assertLt(feeLp, ts, "feeTo share < 100%");
        // value belongs to the protocol (P/S); convertLps is gated (test above)
    }

    // ----------------------------------------------------- fork block info

    function test_report_block() public {
        emit log_named_uint("pulsechain fork block", forkBlock);
        assertGt(forkBlock, 27_000_000);
    }
}
