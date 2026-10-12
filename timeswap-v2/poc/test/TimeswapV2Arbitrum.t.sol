// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "./TimeswapV2Interfaces.sol";

/// Timeswap V2 zombie assessment — Arbitrum fork PoC (read-only simulation; no mainnet txs).
/// Deployed code was verified exact-match (Sourcify) against Timeswap-Labs/Timeswap-V2-Contracts @ main.
/// All pools on Arbitrum are matured (checked at block of run). These tests attempt every plausible
/// unprivileged extraction path against live state and show the gates.
contract TimeswapV2ArbitrumTest is Test {
    // ---- v2.5 core (same addresses on ETH/OP/Polygon/Arb/Base/zkEVM/Mantle/inEVM/XLayer) ----
    address constant OPTION_FACTORY = 0x17385e95cb74A20150E4fA092Aa72D57330896C4;
    address constant POOL_FACTORY = 0x97509c65Ff29C268F0D283A41201Be6b4090354c;
    address constant TOKENS = 0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c;
    address constant LIQUIDITY_TOKENS = 0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09;
    // v2.2 instances
    address constant LIQ_TOKENS_V22 = 0x5753b99901C271Ace51ce2342F51ba701ed1cf90;

    // ---- top-value pair: wstETH/WETH ($27.9k, matured 2024-02-26) ----
    address constant WSTETH_WETH_OPTION = 0x8A4dc1ed808be5a6dB02CEbe4EC5Edf0c0235128;
    address constant WSTETH_WETH_POOL = 0xe9c925A2155414b5863D794a5B646651b96b7fD8;
    uint256 constant WW_STRIKE = 377713427282241694444345814249262714716;
    uint256 constant WW_MATURITY = 1708948800;
    address constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address constant WETH_ARB = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // ---- FIN/USDC ($14.6k, matured 2024-05-14); v2.2 LiquidityToken holds the LP aggregate shorts ----
    address constant FIN_USDC_OPTION = 0x9fCCa41DC15F2609ba3A2104D110Eb2049627Fd0;
    address constant FIN_USDC_POOL = 0x5d5a7819C558684438419D54c0eAE120dEC6a351;
    uint256 constant FU_STRIKE = 340282366920938463463374607;
    uint256 constant FU_MATURITY = 1715688000;

    // ---- protocol-fee pool (PENDLE/mPendle; short protocol fees > 0) ----
    address constant PENDLE_POOL = 0xF002710b681676c068e3cCf15cddCCA88674A85B;
    uint256 constant PENDLE_STRIKE = 680564733841876926926749214863536422912;
    uint256 constant PENDLE_MATURITY = 1756641600;

    // ---- v2.5 NoDex peripheries (Arbitrum) ----
    address[6] PERIPHERIES = [
        0xf253Ecea8aAFeAd83E2e76B8db75F0dcb9BA90F0, // LendGivenPrincipal
        0xecEbd8FB1d3E0a4aCaA6DeCf5db90B99f0587451, // Withdraw
        0x1Ae701557E9a8cF003deFd07C717d2aB2099c8E0, // Collect
        0x0288F05848318c3B3Cbfb524ce129EE67179F130, // CloseLendGivenPosition
        0x01BEad00AF784CfE774e9d01522966ed24f6E299, // BorrowGivenPrincipal
        0x35e1a13425a20f12BFA160e6e1Fe953505731994  // AddLiquidityGivenPrincipal
    ];

    address attacker = address(0xA77ACC);

    function setUp() public {
        vm.createSelectFork(vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc")));
    }

    /* ------------------------------------------------------------------ */
    /* 1. every sampled pool is matured                                    */
    /* ------------------------------------------------------------------ */
    function test_arb_pools_are_matured() public {
        // sample pools from each factory generation on Arbitrum
        address[6] memory pools = [
            0xe9c925A2155414b5863D794a5B646651b96b7fD8, // v2.4 wstETH/WETH
            0x5d5a7819C558684438419D54c0eAE120dEC6a351, // v2.5 FIN/USDC
            0xF002710b681676c068e3cCf15cddCCA88674A85B, // v2.5 PENDLE/mPendle
            0x1C95B2A2D09310e33016CC03565404f19fEa0A0F, // v2.0 ARB/USDC
            0xDEB6D249F85fF722017e5044DF5BECeD49DC54Ec, // v2.1 ARB/USDC
            0x4cb082F052898e1238c97DE74b32806728564695  // v2.2.1 ARB/USDC
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            ITimeswapV2Pool pool = ITimeswapV2Pool(pools[i]);
            uint256 n = pool.numberOfPools();
            assertGt(n, 0, "pool must have entries");
            for (uint256 j = 0; j < n; j++) {
                (, uint256 maturity) = pool.getByIndex(j);
                assertLt(maturity, block.timestamp, "every pool entry must be matured");
            }
        }
    }

    /* ------------------------------------------------------------------ */
    /* 2. outsider cannot claim other holders' shorts                      */
    /* ------------------------------------------------------------------ */
    function test_outsider_cannot_collect_shorts() public {
        ITimeswapV2Option option = ITimeswapV2Option(WSTETH_WETH_OPTION);
        assertGt(option.totalPosition(WW_STRIKE, WW_MATURITY, OptionPosition.Short), 0);
        uint256 bal0Before = IERC20(WSTETH).balanceOf(WSTETH_WETH_OPTION);

        vm.prank(attacker);
        vm.expectRevert(); // arithmetic underflow: attacker holds no short
        option.collect(
            OptionCollectParam({
                strike: WW_STRIKE,
                maturity: WW_MATURITY,
                token0To: attacker,
                token1To: attacker,
                transaction: OptionCollect.GivenShort,
                amount: 1e15,
                data: ""
            })
        );
        assertEq(IERC20(WSTETH).balanceOf(WSTETH_WETH_OPTION), bal0Before, "no tokens left the option");
    }

    /* ------------------------------------------------------------------ */
    /* 3. position owners can still claim (value is live, not stuck)       */
    /* ------------------------------------------------------------------ */
    function test_position_owner_can_collect() public {
        // The v2.2 LiquidityToken holds the aggregate shorts of FIN/USDC LPs (49.4e9 units).
        ITimeswapV2Option option = ITimeswapV2Option(FIN_USDC_OPTION);
        uint256 shortBal = option.positionOf(FU_STRIKE, FU_MATURITY, LIQUIDITY_TOKENS, OptionPosition.Short);
        assertGt(shortBal, 1e9, "LP aggregate short claim must exist");

        uint256 amount = 1e9;
        uint256 optBal0Before = IERC20(option.token0()).balanceOf(FIN_USDC_OPTION);
        uint256 optBal1Before = IERC20(option.token1()).balanceOf(FIN_USDC_OPTION);

        vm.prank(LIQUIDITY_TOKENS);
        (uint256 t0, uint256 t1,,) = option.collect(
            OptionCollectParam({
                strike: FU_STRIKE,
                maturity: FU_MATURITY,
                token0To: LIQUIDITY_TOKENS,
                token1To: LIQUIDITY_TOKENS,
                transaction: OptionCollect.GivenShort,
                amount: amount,
                data: ""
            })
        );
        assertGt(t0 + t1, 0, "collect must pay out");
        assertEq(IERC20(option.token0()).balanceOf(FIN_USDC_OPTION), optBal0Before - t0);
        assertEq(IERC20(option.token1()).balanceOf(FIN_USDC_OPTION), optBal1Before - t1);
    }

    /* ------------------------------------------------------------------ */
    /* 4. all pre-maturity entry points are closed                         */
    /* ------------------------------------------------------------------ */
    function test_all_pre_maturity_paths_revert() public {
        ITimeswapV2Option option = ITimeswapV2Option(WSTETH_WETH_OPTION);
        ITimeswapV2Pool pool = ITimeswapV2Pool(WSTETH_WETH_POOL);

        vm.startPrank(attacker);

        vm.expectRevert(); // alreadyMatured
        option.mint(OptionMintParam(WW_STRIKE, WW_MATURITY, attacker, attacker, attacker, OptionMint.GivenShorts, 1, 1, ""));
        vm.expectRevert(); // alreadyMatured
        option.burn(OptionBurnParam(WW_STRIKE, WW_MATURITY, attacker, attacker, OptionBurn.GivenShorts, 1, 1, ""));
        vm.expectRevert(); // alreadyMatured
        option.swap(OptionSwapParam(WW_STRIKE, WW_MATURITY, attacker, attacker, true, OptionSwap.GivenToken0AndLong0, 1, ""));

        vm.expectRevert(); // alreadyMatured
        pool.mint(PoolMintParam(WW_STRIKE, WW_MATURITY, attacker, 0, 1, ""));
        vm.expectRevert(); // alreadyMatured
        pool.burn(PoolBurnParam(WW_STRIKE, WW_MATURITY, attacker, attacker, attacker, 0, 1, ""));
        vm.expectRevert(); // alreadyMatured
        pool.deleverage(PoolDeleverageParam(WW_STRIKE, WW_MATURITY, attacker, 0, 1, ""));
        vm.expectRevert(); // alreadyMatured
        pool.leverage(PoolLeverageParam(WW_STRIKE, WW_MATURITY, attacker, attacker, 0, 1, ""));
        vm.expectRevert(); // alreadyMatured
        pool.rebalance(PoolRebalanceParam(WW_STRIKE, WW_MATURITY, attacker, true, 0, 1, ""));

        vm.stopPrank();
    }

    /* ------------------------------------------------------------------ */
    /* 5. pools cannot be re-initialized (no reset of a drained pool)      */
    /* ------------------------------------------------------------------ */
    function test_pool_initialize_blocked() public {
        ITimeswapV2Pool pool = ITimeswapV2Pool(WSTETH_WETH_POOL);
        vm.prank(attacker);
        vm.expectRevert(); // alreadyMatured
        pool.initialize(WW_STRIKE, WW_MATURITY, 1e18);
    }

    /* ------------------------------------------------------------------ */
    /* 6. protocol fees: owner-gated (P category)                          */
    /* ------------------------------------------------------------------ */
    function test_outsider_cannot_collect_protocol_fees() public {
        ITimeswapV2Pool pool = ITimeswapV2Pool(PENDLE_POOL);
        (uint256 l0f, uint256 l1f, uint256 sf) = pool.protocolFeesEarned(PENDLE_STRIKE, PENDLE_MATURITY);
        assertGt(l0f + l1f + sf, 0, "pool must have protocol fees");
        assertGt(sf, 0, "short protocol fees (real value) must exist");

        vm.prank(attacker);
        vm.expectRevert(); // NotTheOwner
        pool.collectProtocolFees(
            PoolCollectProtocolFeesParam(PENDLE_STRIKE, PENDLE_MATURITY, attacker, attacker, attacker, type(uint256).max, type(uint256).max, type(uint256).max)
        );
    }

    function test_owner_can_collect_protocol_fees() public {
        ITimeswapV2Pool pool = ITimeswapV2Pool(PENDLE_POOL);
        address owner = ITimeswapV2PoolFactory(POOL_FACTORY).owner();
        vm.prank(owner);
        (uint256 l0, uint256 l1, uint256 s) = pool.collectProtocolFees(
            PoolCollectProtocolFeesParam(PENDLE_STRIKE, PENDLE_MATURITY, owner, owner, owner, type(uint256).max, type(uint256).max, type(uint256).max)
        );
        assertGt(l0 + l1 + s, 0, "owner collects");
        (uint256 l0f, uint256 l1f, uint256 sf) = pool.protocolFeesEarned(PENDLE_STRIKE, PENDLE_MATURITY);
        assertEq(l0f + l1f + sf, 0, "protocol fees zeroed after collection");
    }

    /* ------------------------------------------------------------------ */
    /* 7. LP fee/shortReturned claims are caller-keyed                     */
    /* ------------------------------------------------------------------ */
    function test_lp_claim_is_caller_keyed() public {
        ITimeswapV2Pool pool = ITimeswapV2Pool(FIN_USDC_POOL);
        // attacker has no liquidity position -> zero claim, positions only move to chosen recipients
        vm.prank(attacker);
        (uint256 f0, uint256 f1, uint256 sf, uint256 sr) = pool.collectTransactionFeesAndShortReturned(
            PoolCollectTxnFeesParam(FU_STRIKE, FU_MATURITY, attacker, attacker, attacker, attacker, type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max)
        );
        assertEq(f0 + f1 + sf + sr, 0, "outsider has no LP claim");
    }

    function test_liquidityToken_collect_requires_approval() public {
        vm.prank(attacker);
        vm.expectRevert(); // NotApprovedToTransferFees
        ITimeswapV2LiquidityToken(LIQUIDITY_TOKENS).collect(
            LiquidityTokenCollectParam(address(0), address(0), 0, 0, address(0xdead), attacker, attacker, attacker, attacker, type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max, "")
        );
    }

    /* ------------------------------------------------------------------ */
    /* 8. wrapped positions cannot be burned by non-holders                */
    /* ------------------------------------------------------------------ */
    function test_token_burn_without_balance_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ITimeswapV2Token(TOKENS).burn(
            TokenBurnParam(WSTETH, WETH_ARB, WW_STRIKE, WW_MATURITY, attacker, attacker, attacker, 0, 0, 1e15, "")
        );
    }

    function test_transferPosition_cannot_move_others() public {
        ITimeswapV2Option option = ITimeswapV2Option(WSTETH_WETH_OPTION);
        vm.prank(attacker);
        vm.expectRevert(); // underflow: attacker owns nothing
        option.transferPosition(WW_STRIKE, WW_MATURITY, attacker, OptionPosition.Short, 1);
    }

    /* ------------------------------------------------------------------ */
    /* 9. peripheries hold no user funds (refundNatives/unwrap sweepable)  */
    /* ------------------------------------------------------------------ */
    function test_peripheries_hold_no_funds() public {
        for (uint256 i = 0; i < PERIPHERIES.length; i++) {
            assertEq(PERIPHERIES[i].balance, 0, "periphery native balance");
            assertEq(IERC20(WETH_ARB).balanceOf(PERIPHERIES[i]), 0, "periphery WETH balance");
        }
    }

    /* ------------------------------------------------------------------ */
    /* 10. record live value context                                       */
    /* ------------------------------------------------------------------ */
    function test_live_value_context() public {
        uint256 opt0 = IERC20(WSTETH).balanceOf(WSTETH_WETH_OPTION);
        uint256 opt1 = IERC20(WETH_ARB).balanceOf(WSTETH_WETH_OPTION);
        emit log_named_decimal_uint("wstETH held by option", opt0, 18);
        emit log_named_decimal_uint("WETH held by option", opt1, 18);
        uint256 f0 = IERC20(ITimeswapV2Option(FIN_USDC_OPTION).token0()).balanceOf(FIN_USDC_OPTION);
        uint256 f1 = IERC20(ITimeswapV2Option(FIN_USDC_OPTION).token1()).balanceOf(FIN_USDC_OPTION);
        emit log_named_decimal_uint("FIN held by option", f0, 18);
        emit log_named_decimal_uint("USDC held by option", f1, 6);
    }
}
