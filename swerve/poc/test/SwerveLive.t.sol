// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

// USDT mainnet: transfer/transferFrom/approve return nothing
interface IUSDT {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function approve(address, uint256) external;
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface ISwervePool {
    function coins(int128 i) external view returns (address);
    function underlying_coins(int128 i) external view returns (address);
    function balances(int128 i) external view returns (uint256);
    function A() external view returns (uint256);
    function fee() external view returns (uint256);
    function admin_fee() external view returns (uint256);
    function owner() external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function add_liquidity(uint256[4] calldata amounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[4] calldata min_amounts) external;
    function remove_liquidity_imbalance(uint256[4] calldata amounts, uint256 max_burn_amount) external;
    function withdraw_admin_fees() external;
    function commit_transfer_ownership(address _owner) external;
    function apply_transfer_ownership() external;
    function commit_new_parameters(uint256 amplification, uint256 new_fee, uint256 new_admin_fee) external;
    function apply_new_parameters() external;
    function revert_new_parameters() external;
    function kill_me() external;
    function unkill_me() external;
}

interface ISwerveLP is IERC20 {
    function totalSupply() external view returns (uint256);
    function mint(address, uint256) external;
    function burnFrom(address, uint256) external;
}

interface IGauge {
    function lp_token() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function user_checkpoint(address) external returns (bool);
    function claimable_tokens(address) external returns (uint256);
    function kick(address) external;
}

interface IDAOProxy {
    function ownership_admin() external view returns (address);
    function withdraw_admin_fees(address) external;
    function commit_transfer_ownership(address, address) external;
    function apply_transfer_ownership(address) external;
    function kill_me(address) external;
    function set_burner(address, address) external;
    function burn_coin(address) external;
    function burners(address) external view returns (address);
}

interface IMinter {
    function mint(address) external;
    function minted(address, address) external view returns (uint256);
}

contract EvilBurner {
    address immutable attacker;
    constructor(address _a) { attacker = _a; }
    // called by the DAO proxy; it has approved this contract for MAX
    function burn_coin(address coin) external returns (bool) {
        uint256 bal = IUSDT(coin).balanceOf(msg.sender);
        IUSDT(coin).transferFrom(msg.sender, attacker, bal);
        return true;
    }
    function burn() external returns (bool) { return true; }
}

contract SwerveLiveTest is Test {
    address constant POOL   = 0x329239599afB305DA0A2eC69c58F8a6697F9F88d;
    address constant LP     = 0x77C6E4a580c0dCE4E5c7a17d0bc077188a83A059;
    address constant GAUGE  = 0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa;
    address constant DAO    = 0x2638d2680ab4914126Ee05b9C5EE95bac311A95e;
    address constant SWRV   = 0xB8BAa0e4287890a5F79863aB62b7F175ceCbD433;
    address constant MINTER = 0x2c988c3974AD7E604E276AE0294a7228DEf67974;
    address constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant TUSD   = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address constant STAKER = 0x15FBa769DE1Fc3bdaF5AEc3Ab87D340ae20a519e; // live staker (57.26 swUSD staked)
    address constant DAO_ADMIN = 0x996E539a1242a541f5909c6B20BbEf4CC63F34b1;

    // DefiLlama prices 2026-10-12, 1e18 fixed point (stated price/time for USD valuation)
    uint256 constant P_DAI  = 1_000335855184050200;
    uint256 constant P_USDC = 999_754_128_071_200_000;
    uint256 constant P_USDT = 999_213_745_327_099_300;
    uint256 constant P_TUSD = 998_600_275_605_797_000;

    address attacker;
    ISwervePool pool;
    ISwerveLP lp;
    IGauge gauge;

    function setUp() public {
        // Latest-state fork (public CI RPCs do not serve pinned archive state).
        vm.createSelectFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
        pool = ISwervePool(POOL);
        lp = ISwerveLP(LP);
        gauge = IGauge(GAUGE);
        attacker = makeAddr("attacker");
        vm.label(POOL, "SwervePool");
        vm.label(LP, "swUSD");
        vm.label(GAUGE, "SwerveGauge");
        vm.label(DAO, "SwerveDAOProxy");
    }

    // ---------------- helpers ----------------
    function _tok(uint8 i) internal pure returns (address) {
        if (i == 0) return DAI;
        if (i == 1) return USDC;
        if (i == 2) return USDT;
        return TUSD;
    }
    function _dec(uint8 i) internal pure returns (uint256) {
        return (i == 0 || i == 3) ? 18 : 6;
    }
    function _val18(uint256[4] memory amts) internal pure returns (uint256 v) {
        for (uint8 i = 0; i < 4; i++) v += amts[i] * (10 ** (18 - _dec(i)));
    }
    function _price(uint8 i) internal pure returns (uint256) {
        if (i == 0) return P_DAI;
        if (i == 1) return P_USDC;
        if (i == 2) return P_USDT;
        return P_TUSD;
    }
    // value of a balance vector in USD at the stated DefiLlama snapshot, 18-dec
    function _valUSD(uint256[4] memory amts) internal pure returns (uint256 usd) {
        for (uint8 i = 0; i < 4; i++) {
            usd += (amts[i] * (10 ** (18 - _dec(i)))) * _price(i) / 1e18;
        }
    }
    function _bal4(address who) internal view returns (uint256[4] memory b) {
        for (uint8 i = 0; i < 4; i++) b[i] = IERC20(_tok(i)).balanceOf(who);
    }
    function _approveAll(address who, address spender) internal {
        vm.startPrank(who);
        IERC20(DAI).approve(spender, type(uint256).max);
        IERC20(USDC).approve(spender, type(uint256).max);
        IUSDT(USDT).approve(spender, type(uint256).max);
        IERC20(TUSD).approve(spender, type(uint256).max);
        vm.stopPrank();
    }

    // ---------------- 1. live state ----------------
    function test_baseline_state() public {
        assertEq(pool.owner(), address(0), "pool owner renounced");
        assertEq(pool.A(), 100, "A");
        assertEq(pool.fee(), 3_000_000, "fee 0.03%");
        assertEq(pool.admin_fee(), 0, "admin_fee 0");
        assertEq(uint256(vm.load(POOL, bytes32(uint256(15)))), 0, "is_killed false");
        uint256 kd = uint256(vm.load(POOL, bytes32(uint256(14))));
        assertLt(kd, block.timestamp, "kill_deadline expired");
        assertEq(pool.coins(0), DAI);
        assertEq(pool.coins(1), USDC);
        assertEq(pool.coins(2), USDT);
        assertEq(pool.coins(3), TUSD);
        assertEq(pool.underlying_coins(1), USDC, "coins==underlying");
        uint256 ts = lp.totalSupply();
        console.log("swUSD totalSupply:", ts);
        assertGt(ts, 280_000e18, "LP supply in expected range");
        assertLt(ts, 290_000e18, "LP supply in expected range");
        // LP minter (slot 6) == pool
        assertEq(address(uint160(uint256(vm.load(LP, bytes32(uint256(6)))))), POOL, "LP minter");
        assertEq(gauge.lp_token(), LP);
        uint256 gts = gauge.totalSupply();
        console.log("gauge staked swUSD:", gts);
        assertGt(gts, 270_000e18, "gauge staked in expected range");
        assertLt(gts, 280_000e18, "gauge staked in expected range");
        uint256[4] memory vb;
        for (uint8 i = 0; i < 4; i++) vb[i] = pool.balances(int128(uint128(i)));
        console.log("virtual balances (coin units):");
        console.log(" DAI ", vb[0]);
        console.log(" USDC", vb[1]);
        console.log(" USDT", vb[2]);
        console.log(" TUSD", vb[3]);
        console.log("total value (18dec, ~USD):", _val18(vb));
        console.log("virtual price:", pool.get_virtual_price());
        assertGt(_val18(vb), 300_000e18, "pool still funded");
    }

    // ---------------- 2. admin surface is dead for everyone ----------------
    function test_admin_paths_all_dead_for_anyone() public {
        vm.startPrank(attacker);
        vm.expectRevert(); pool.withdraw_admin_fees();
        vm.expectRevert(); pool.commit_transfer_ownership(attacker);
        vm.expectRevert(); pool.apply_transfer_ownership();
        vm.expectRevert(); pool.commit_new_parameters(200, 4_000_000, 5_000_000_000);
        vm.expectRevert(); pool.apply_new_parameters();
        vm.expectRevert(); pool.revert_new_parameters();
        vm.expectRevert(); pool.kill_me();
        vm.expectRevert(); pool.unkill_me();
        vm.stopPrank();
        // DAO proxy paths are also dead on the pool (owner=0)
        vm.startPrank(attacker);
        vm.expectRevert(); IDAOProxy(DAO).withdraw_admin_fees(POOL);
        vm.expectRevert(); IDAOProxy(DAO).apply_transfer_ownership(POOL);
        vm.expectRevert(); IDAOProxy(DAO).kill_me(POOL);
        vm.stopPrank();
        vm.startPrank(DAO_ADMIN);
        vm.expectRevert(); IDAOProxy(DAO).commit_transfer_ownership(POOL, attacker);
        vm.stopPrank();
    }

    // ---------------- 3. DAO proxy: 30.4k USDT is STUCK (S), not extractable ----------------
    function test_dao_proxy_usdt_is_stuck() public {
        uint256 held = IUSDT(USDT).balanceOf(DAO);
        console.log("DAO proxy USDT:", held);
        assertEq(held, 30_408_429_720, "proxy USDT at fork block");
        // attacker cannot set a burner
        vm.prank(attacker);
        vm.expectRevert(); IDAOProxy(DAO).set_burner(USDT, attacker);
        // burners[USDT] == 0 and burn_coin reverts for everyone
        assertEq(IDAOProxy(DAO).burners(USDT), address(0));
        vm.prank(attacker);
        vm.expectRevert(); IDAOProxy(DAO).burn_coin(USDT);
        // EVEN the admin cannot create a USDT burner (Tether approve returns no data;
        // the deployed set_burner path reverts). Fork-proven:
        EvilBurner eb = new EvilBurner(attacker);
        vm.prank(DAO_ADMIN);
        vm.expectRevert(); IDAOProxy(DAO).set_burner(USDT, address(eb));
        assertEq(IDAOProxy(DAO).burners(USDT), address(0), "still no burner");
        assertEq(IUSDT(USDT).allowance(DAO, address(eb)), 0, "no allowance");
        // Contrast: for DAI (burner already set -> set_burner path works) the admin can
        // install a malicious burner, but the proxy holds 0 DAI; USDT remains untouched.
        vm.prank(DAO_ADMIN);
        IDAOProxy(DAO).set_burner(DAI, address(eb));
        IDAOProxy(DAO).burn_coin(DAI); // permissionless trigger
        assertEq(IUSDT(USDT).balanceOf(DAO), held, "USDT untouched by DAI burner");
        assertEq(IUSDT(USDT).balanceOf(attacker), 0, "attacker got nothing");
        console.log("S proven: 30,408.43 USDT stuck in DAO proxy (no burner path)");
    }

    // ---------------- 4. swaps: fair, round trip loses fees ----------------
    function test_swap_roundtrip_loses_fees() public {
        deal(DAI, attacker, 2_000e18);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        uint256 quoted = pool.get_dy(0, 1, 2_000e18);
        pool.exchange(0, 1, 2_000e18, 0);
        uint256 usdcOut = IERC20(USDC).balanceOf(attacker);
        assertApproxEqAbs(usdcOut, quoted, 5, "out == quote (<=5 wei rounding)");
        uint256 back = pool.get_dy(1, 0, usdcOut);
        pool.exchange(1, 0, usdcOut, 0);
        vm.stopPrank();
        uint256 end = IERC20(DAI).balanceOf(attacker);
        assertApproxEqAbs(end, back, 5, "reverse out == quote");
        assertLt(end, 2_000e18, "round trip cannot profit");
        uint256 loss = 2_000e18 - end;
        console.log("roundtrip loss (18dec):", loss);
        assertLt(loss, 4e18, "loss <0.2% (2x fee + small slippage)");
    }

    function test_exchange_underlying_equivalent() public {
        deal(DAI, attacker, 1_000e18);
        _approveAll(attacker, POOL);
        uint256 q1 = pool.get_dy(0, 1, 1_000e18);
        uint256 q2 = pool.get_dy_underlying(0, 1, 1_000e18);
        assertApproxEqAbs(q1, q2, 5, "get_dy == get_dy_underlying");
        vm.startPrank(attacker);
        pool.exchange_underlying(0, 1, 1_000e18, 0);
        vm.stopPrank();
        assertApproxEqAbs(IERC20(USDC).balanceOf(attacker), q1, 5, "underlying output == quote");
    }

    // ---------------- 5. add/remove round trip: no profit ----------------
    function test_add_remove_roundtrip_no_profit() public {
        deal(DAI, attacker, 30_000e18);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        pool.exchange(0, 1, 5_000e18, 0);
        pool.exchange(0, 2, 5_000e18, 0);
        pool.exchange(0, 3, 5_000e18, 0);
        uint256[4] memory amts = _bal4(attacker);
        uint256 startVal = _val18(amts);
        pool.add_liquidity(amts, 0);
        uint256 minted = lp.balanceOf(attacker);
        uint256[4] memory z;
        pool.remove_liquidity(minted, z);
        vm.stopPrank();
        uint256[4] memory fin = _bal4(attacker);
        uint256 endVal = _val18(fin);
        console.log("added value (18dec):", startVal);
        console.log("value after add+remove:", endVal);
        assertLe(endVal, startVal, "no profit from liquidity round trip");
        // per-coin deltas may shift sign (LP takes the pool's composition back);
        // only total value must not increase - that is asserted above.
    }

    // ---------------- 5b. skewed single-coin withdrawal cannot beat fair value ----------------
    function test_remove_imbalance_no_profit() public {
        deal(DAI, attacker, 30_000e18);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        pool.exchange(0, 1, 5_000e18, 0);
        pool.exchange(0, 2, 5_000e18, 0);
        pool.exchange(0, 3, 5_000e18, 0);
        uint256[4] memory amts = _bal4(attacker);
        pool.add_liquidity(amts, 0);
        uint256 l = lp.balanceOf(attacker);
        uint256 ts = lp.totalSupply();
        // skewed withdrawal: half the pro-rata in DAI only, zero elsewhere
        uint256[4] memory want;
        want[0] = pool.balances(0) * l / ts / 2;
        uint256[4] memory before = _bal4(attacker);
        uint256[4] memory balBefore;
        for (uint8 i = 0; i < 4; i++) balBefore[i] = pool.balances(int128(uint128(i)));
        uint256 vpBefore = pool.get_virtual_price();
        pool.remove_liquidity_imbalance(want, l);
        uint256 burned = l - lp.balanceOf(attacker);
        uint256[4] memory got;
        for (uint8 i = 0; i < 4; i++) got[i] = IERC20(_tok(i)).balanceOf(attacker) - before[i];
        vm.stopPrank();
        uint256 outVal = _val18(got);
        uint256 fairVal = burned * vpBefore / 1e18;
        console.log("ts before remove:", ts);
        console.log("bal DAI :", balBefore[0]);
        console.log("bal USDC:", balBefore[1]);
        console.log("bal USDT:", balBefore[2]);
        console.log("bal TUSD:", balBefore[3]);
        console.log("vp before:", vpBefore);
        console.log("LP held before:", l);
        console.log("want DAI:", want[0]);
        console.log("LP burned:", burned);
        console.log("got DAI:", got[0]);
        console.log("imbalance out value (18dec):", outVal);
        console.log("fair value of burned LP (vp):", fairVal);
        // NOTE: vp-based benchmark is only approximate; the decisive check is the full cycle test.
        assertLe(outVal, fairVal + 10e18, "imbalance removal ~fair (<=$10 slack)");
    }

    // ---------------- 5c. full adversarial cycle: make a coin rich, deposit, skewed-exit, exit rest ----------------
    function test_remove_imbalance_full_cycle_no_profit() public {
        deal(DAI, attacker, 60_000e18);
        _approveAll(attacker, POOL);
        uint256 startVal = 60_000e18;
        vm.startPrank(attacker);
        // phase 1: make DAI the rich coin (swaps DAI in)
        pool.exchange(0, 1, 5_000e18, 0);
        pool.exchange(0, 2, 5_000e18, 0);
        pool.exchange(0, 3, 5_000e18, 0);
        // phase 2: deposit everything (DAI-heavy vs pool)
        uint256[4] memory amts = _bal4(attacker);
        pool.add_liquidity(amts, 0);
        uint256 l = lp.balanceOf(attacker);
        // phase 3: skewed withdrawal - take out DAI only, up to 80% of pro-rata DAI
        uint256 ts = lp.totalSupply();
        uint256[4] memory want;
        want[0] = pool.balances(0) * l / ts * 8 / 10;
        pool.remove_liquidity_imbalance(want, l);
        // phase 4: exit remaining LP proportionally
        uint256 rest = lp.balanceOf(attacker);
        uint256[4] memory z;
        pool.remove_liquidity(rest, z);
        vm.stopPrank();
        uint256 endVal = _val18(_bal4(attacker));
        console.log("cycle start value:", startVal);
        console.log("cycle end value:", endVal);
        assertLe(endVal, startVal, "full adversarial cycle cannot profit");
    }

    // ---------------- 5d. par-unit slack capture exists but is NOT market-profitable ----------------
    function test_slack_capture_par_vs_market() public {
        // proportional add (zero fee) -> USDT-only withdrawal (pool is USDT-rich) -> pro-rata exit.
        uint256[4] memory add;
        for (uint8 i = 0; i < 4; i++) add[i] = pool.balances(int128(uint128(i))) * 5 / 100;
        for (uint8 i = 0; i < 4; i++) deal(_tok(i), attacker, add[i]);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        uint256[4] memory startB = _bal4(attacker);
        uint256[4] memory amts = startB;
        pool.add_liquidity(amts, 0);
        uint256 l = lp.balanceOf(attacker);
        uint256[4] memory want;
        want[2] = 5_260e6; // 5,260 USDT
        pool.remove_liquidity_imbalance(want, l);
        uint256 rest = lp.balanceOf(attacker);
        uint256[4] memory z;
        pool.remove_liquidity(rest, z);
        vm.stopPrank();
        uint256[4] memory endB = _bal4(attacker);
        int256 parDiff = int256(_val18(endB)) - int256(_val18(startB));
        int256 usdDiff = int256(_valUSD(endB)) - int256(_valUSD(startB));
        console.log("par-unit delta (18dec):", parDiff);
        console.log("market-USD delta (18dec):", usdDiff);
        // The par-unit composition shift is real (+~$1.17 at $1/coin) ...
        assertGe(parDiff, int256(0.5e18), "par composition shift exists");
        // ... but at DefiLlama market prices it is NOT profitable (extracted USDT trades below the basket).
        assertLe(usdDiff, int256(0.05e18), "market net must be <= $0.05");
    }

    // ---------------- 5e. E-U: pool-vs-market mispricing, USDC->DAI (deep liquidity) ----------------
    function test_market_usdc_to_dai_swap() public {
        // The pool's USDC leg is underweight => pool pays a premium for USDC vs DAI;
        // USDC is also cheaper than DAI at market. Net capture at DefiLlama prices.
        uint256 dx = 1_480e6;
        deal(USDC, attacker, dx);
        _approveAll(attacker, POOL);
        uint256[4] memory startB = _bal4(attacker);
        uint256 quote = pool.get_dy(1, 0, dx);
        vm.prank(attacker);
        pool.exchange(1, 0, dx, 0);
        uint256[4] memory endB = _bal4(attacker);
        assertApproxEqAbs(endB[0], quote, 5, "out == quote");
        uint256 inUsd = _valUSD(startB);
        uint256 outUsd = _valUSD(endB);
        console.log("USDC->DAI in USD :", inUsd);
        console.log("USDC->DAI out USD:", outUsd);
        assertGt(outUsd, inUsd + 0.15e18, "market net > $0.15");
        assertLt(outUsd, inUsd + 0.45e18, "market net < $0.45");
    }

    // ---------------- 5f. conditional: TUSD->DAI (extraction from pool; acquisition is the caveat) ----------------
    function test_market_tusd_to_dai_swap_conditional() public {
        // TUSD trades at ~$0.9986 (DefiLlama) while the pool prices it ~at par.
        // NB: this proves the pool-side capture only. On-chain TUSD DEX depth is ~$0 today,
        // so sourcing 5,414 TUSD at ~$0.9986 requires off-chain (CEX/OTC) liquidity.
        uint256 dx = 5_414e18;
        deal(TUSD, attacker, dx);
        _approveAll(attacker, POOL);
        uint256[4] memory startB = _bal4(attacker);
        uint256 quote = pool.get_dy(3, 0, dx);
        vm.prank(attacker);
        pool.exchange(3, 0, dx, 0);
        uint256[4] memory endB = _bal4(attacker);
        assertApproxEqAbs(endB[0], quote, 5, "out == quote");
        uint256 inUsd = _valUSD(startB);
        uint256 outUsd = _valUSD(endB);
        console.log("TUSD->DAI in USD :", inUsd);
        console.log("TUSD->DAI out USD:", outUsd);
        assertGt(outUsd, inUsd + 3.5e18, "market net > $3.5 (if TUSD sourced at market)");
        assertLt(outUsd, inUsd + 4.5e18, "market net < $4.5");
    }

    // ---------------- 6. live staker exit (H-O) ----------------
    function test_live_staker_can_exit_exact() public {
        uint256 staked = gauge.balanceOf(STAKER);
        console.log("staker gauge balance:", staked);
        assertGt(staked, 1e18, "live staker present");
        uint256 amount = staked / 2;
        uint256 lpBefore = lp.balanceOf(STAKER);
        vm.prank(STAKER);
        gauge.withdraw(amount);
        assertEq(lp.balanceOf(STAKER) - lpBefore, amount, "gauge returns LP");

        uint256 ts = lp.totalSupply();
        uint256[4] memory expected;
        for (uint8 i = 0; i < 4; i++) {
            expected[i] = pool.balances(int128(uint128(i))) * amount / ts;
        }
        uint256[4] memory before = _bal4(STAKER);
        vm.prank(STAKER);
        pool.remove_liquidity(amount, [uint256(0), 0, 0, 0]);
        uint256[4] memory got;
        for (uint8 i = 0; i < 4; i++) {
            got[i] = IERC20(_tok(i)).balanceOf(STAKER) - before[i];
            assertEq(got[i], expected[i], "exact pro-rata payout");
        }
        uint256 value18 = _val18(got);
        uint256 vp = pool.get_virtual_price();
        console.log("staker exit value (18dec):", value18);
        console.log("expected via vp:", amount * vp / 1e18);
        assertApproxEqRel(value18, amount * vp / 1e18, 1e15, "value == LP * virtual price");
    }

    // ---------------- 7. attacker full cycle through gauge/rewards ----------------
    function test_attacker_full_cycle_no_extraction() public {
        deal(DAI, attacker, 20_000e18);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        IERC20(LP).approve(GAUGE, type(uint256).max);
        pool.exchange(0, 1, 5_000e18, 0);
        pool.exchange(0, 2, 5_000e18, 0);
        pool.exchange(0, 3, 5_000e18, 0);
        uint256[4] memory amts = _bal4(attacker);
        pool.add_liquidity(amts, 0);
        uint256 l = lp.balanceOf(attacker);
        gauge.deposit(l);
        gauge.user_checkpoint(attacker);
        uint256 claimable = gauge.claimable_tokens(attacker);
        console.log("claimable SWRV:", claimable);
        IMinter(MINTER).mint(GAUGE); // permissionless mint of msg.sender's SWRV
        uint256 swrv = IERC20(SWRV).balanceOf(attacker);
        console.log("SWRV received:", swrv);
        gauge.withdraw(l);
        uint256[4] memory z;
        pool.remove_liquidity(l, z);
        vm.stopPrank();
        uint256 endVal = _val18(_bal4(attacker));
        console.log("final value (18dec):", endVal);
        assertLe(endVal, 20_000e18, "no extraction through full stack");
        assertEq(IERC20(LP).balanceOf(attacker), 0, "all LP redeemed");
    }

    // ---------------- 8. donations are stuck (S) ----------------
    function test_donation_is_stuck() public {
        uint256[4] memory vb;
        for (uint8 i = 0; i < 4; i++) vb[i] = pool.balances(int128(uint128(i)));
        uint256 vp = pool.get_virtual_price();
        uint256 poolDai = IERC20(DAI).balanceOf(POOL);
        deal(DAI, POOL, poolDai + 1_000e18); // donation
        for (uint8 i = 0; i < 4; i++) {
            assertEq(pool.balances(int128(uint128(i))), vb[i], "virtual balances untouched");
        }
        assertEq(pool.get_virtual_price(), vp, "VP untouched by donation");
        vm.prank(attacker);
        vm.expectRevert(); pool.withdraw_admin_fees(); // nobody can claim surplus
        uint256 surplusDai = IERC20(DAI).balanceOf(POOL) - pool.balances(0);
        console.log("surplus DAI after donation:", surplusDai);
        assertGt(surplusDai, 1_000e18, "donation sits as unclaimable surplus");
    }

    // ---------------- 9. edge bounds ----------------
    function test_edge_bounds_revert() public {
        deal(DAI, attacker, 1e18);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        vm.expectRevert(); pool.exchange(0, 0, 1e18, 0);
        vm.expectRevert(); pool.exchange(0, 4, 1e18, 0);
        vm.expectRevert(); pool.exchange(4, 0, 1e18, 0);
        vm.expectRevert(); pool.exchange(-1, 0, 1e18, 0);
        uint256[4] memory z;
        vm.expectRevert(); pool.add_liquidity(z, 0);
        pool.remove_liquidity(0, z); // no-op allowed
        assertEq(pool.get_dy(0, 1, 0), 0, "zero in zero out");
        vm.stopPrank();
    }

    // ---------------- 10. LP mint/burn is pool-only ----------------
    function test_lp_minter_pool_only() public {
        vm.prank(attacker);
        vm.expectRevert(); lp.mint(attacker, 1e18);
        vm.prank(attacker);
        vm.expectRevert(); lp.burnFrom(attacker, 1);
        vm.prank(POOL);
        lp.mint(address(0xdead), 1); // pool is the minter (mintable only by pool code paths)
        vm.prank(POOL);
        lp.burnFrom(address(0xdead), 1);
    }

    // ---------------- 11. fuzz: no profitable DAI round trips ----------------
    function testFuzz_roundtrip_never_profits(uint96 dxRaw, uint8 jRaw) public {
        uint8 j = uint8(1 + (jRaw % 3));
        uint256 dx = bound(uint256(dxRaw), 1e18, 5_000e18);
        deal(DAI, attacker, dx);
        _approveAll(attacker, POOL);
        vm.startPrank(attacker);
        uint256 out = pool.get_dy(0, int128(uint128(j)), dx);
        if (out == 0) { vm.stopPrank(); return; }
        pool.exchange(0, int128(uint128(j)), dx, 0);
        uint256 jbal = IERC20(_tok(j)).balanceOf(attacker);
        pool.exchange(int128(uint128(j)), 0, jbal, 0);
        vm.stopPrank();
        uint256 end = IERC20(DAI).balanceOf(attacker);
        assertLe(end, dx, "fuzz round trip profit");
    }
}
