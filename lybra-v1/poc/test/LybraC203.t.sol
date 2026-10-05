// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/Interfaces.sol";

/// @title C2-03 Lybra V1 deep-dive PoC (fork-only, read-only on mainnet)
/// @notice Pinned fork block 26,127,193 (2026-10-05). All state reads/asserts reproduce
///         the analysis in lybra-v1/README.md. No mainnet transactions are ever sent.
contract LybraC203Test is Test {
    address constant LYBRA = 0x97de57eC338AB5d51557DA3434828C5DbFaDA371; // Lybra V1 vault = eUSD token
    address constant PRICE_FEED = 0x4c517D4e2C851CA76d7eC94B805269Df0f2201De; // Liquity PriceFeed
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // Lido stETH
    address constant CURVE_EUSD_USDC = 0x880F2fB3704f1875361DE6ee59629c6c6497a5E3; // Curve eUSD/USDC
    uint256 constant PINNED_BLOCK = 26_127_193;
    uint256 constant P0 = 2_700_500_000_000_000_000_000; // fetchPrice() at pinned block ($2,700.50)
    uint256 constant WAD = 1e18;

    ILybra lybra = ILybra(LYBRA);
    ILido lido = ILido(STETH);
    IPriceFeed feed = IPriceFeed(PRICE_FEED);
    ICurveStableSwap curve = ICurveStableSwap(CURVE_EUSD_USDC);

    // 17 underwater borrowers at the pinned block (CR < 150%), sorted by collateral desc.
    address[17] VICTIMS = [
        address(0x2cC05782c77930c65D2450D3298F1D784A89BB00),
        address(0x1309c007567a71b393094c21E70bd2647356A352),
        address(0x9874f9B05B073771c7b98e192543FA2684e61246),
        address(0x3528942Bf01874cB51A79ac32E3FC839Ae2a1367),
        address(0xEC7d08f5a982B213A8BAf73B9e89df30656F5880),
        address(0xAe9DB1fF69cfCa2720fF2e5d81807d7383138A39),
        address(0x84eCA34e4a1732113883407e3666B014dCca0a16),
        address(0x5789A38a3FAcfaa86ED950e88D79a9A2F6140052),
        address(0x16FA6B8FCC2D5F459600713cF961E349067a278c),
        address(0xF71D161FdC3895F21612D79f15Aa819b7A3d296a),
        address(0x508D090e2A9e84cBE873c3BcC39c8f92e3CaCE80),
        address(0x8c42a956f99A621277Cb36Ea6fAcb4b9586EF842),
        address(0x34C49E4b376407E142eD183B80A42aed85A31519),
        address(0x6F471EcB704A38E653C839DdD7E3957E989a9d29),
        address(0x4ACF1f34041E9B3027dD1d7F7588761B1bd7BDE3),
        address(0x9c57027B1eca93093a6F446422C59C85A5A3Fa52),
        address(0x971740Ed368934875f1890898D5FFC10EA99FA43)
    ];
    uint256[17] V_DEP = [
        21113253084214258873, 3925435305378691908, 46461870033649122, 33600000000000000,
        33000000000000000, 28523500000000000, 28125953874057613, 25827044144745680,
        24300000000000000, 23924604523201219, 15354562500000000, 13800000000000100,
        9500000000000000, 5100000000000000, 500000000000000, 500000000000000, 390000000000000
    ];
    uint256[17] V_BOR = [
        55244960568680626523340, 9191168087461654484880, 148907845207439406001, 92220000000000000000,
        100000000000000000000, 58946022946000000000, 201986080575546516295, 138380804576931163895,
        50455250885620000000, 80981784024068349989, 181030735704937743750, 30640000000000000000,
        18522468280666450000, 10000000000000000000, 1000000000000000000, 1000000000000000000, 785000000000000000
    ];

    function setUp() public {
        // Pinned historical state needs an archive node (drpc.org public is archive).
        string memory url = vm.envOr("ARCHIVE_FORK_RPC_URL", string("https://eth.drpc.org"));
        vm.createSelectFork(url, PINNED_BLOCK);
    }

    function _cr(uint256 dep, uint256 bor) internal pure returns (uint256) {
        return (dep * P0 * 100) / bor; // 1e18-scaled ratio
    }

    // ---------------------------------------------------------------- T1
    /// @notice Reproduce the pinned live state exactly: price, totals, the 17 underwater
    ///         positions, and that superLiquidation is blocked by the 187% global CR.
    function test_T1_pinned_state_and_victims() public {
        assertEq(feed.fetchPrice(), P0, "price at pinned block");
        assertEq(lybra.totalDepositedEther(), 61_570_470_569_434_976_880, "totalDepositedEther");
        assertEq(lybra.totalEUSDCirculation(), 88_794_473_385_114_144_857_812, "totalEUSDCirculation");
        assertEq(lybra.getTotalShares(), 85_239_140_226_168_927_372_476, "totalShares");
        assertEq(lybra.safeCollateralRate(), 160e18, "safeCollateralRate");
        assertEq(lybra.keeperRate(), 1, "keeperRate");

        uint256 n;
        for (uint256 i; i < 17; i++) {
            uint256 dep = lybra.depositedEther(VICTIMS[i]);
            uint256 bor = lybra.getBorrowedOf(VICTIMS[i]);
            assertEq(dep, V_DEP[i], "victim deposit mismatch");
            assertEq(bor, V_BOR[i], "victim debt mismatch");
            assertLt(_cr(dep, bor), 150e18, "victim not underwater");
            n++;
        }
        assertEq(n, 17, "17 underwater");

        // Global CR = 61.57*2700.5/88794 = 187% -> superLiquidation gated shut.
        uint256 globalCr = (lybra.totalDepositedEther() * P0 * 100) / lybra.totalEUSDCirculation();
        assertGt(globalCr, 150e18, "global CR");
        vm.expectRevert(bytes("overallCollateralRate should below 150%"));
        lybra.superLiquidation(address(this), VICTIMS[0], 1);

        emit log_named_decimal_uint("global CR", globalCr, 18);
    }

    // ---------------------------------------------------------------- T2
    /// @notice Single-shot max liquidation on the largest victim: the liquidator pays
    ///         eUSD and receives exactly 1.1x of the ETH-denominated repayment in stETH.
    ///         Net-worth delta is +10% of the repaid value (~1.0557 stETH).
    function test_T2_single_shot_bonus_biggest_victim() public {
        address victim = VICTIMS[0];
        uint256 dep = V_DEP[0];
        uint256 bor = V_BOR[0];
        uint256 e = bor * WAD / P0; // full debt in ETH
        if (dep / 2 < e) e = dep / 2; // 50%-of-collateral cap binds
        assertEq(e, 10_556_626_542_107_129_436, "max single-shot etherAmount"); // ~10.5566 ETH

        uint256 funding = e * 16 / 10 + 1e15; // 1.6x capital (mint at ~160% CR)
        vm.deal(address(this), funding);
        lido.submit{value: funding}(address(0));
        uint256 stBal = lido.balanceOf(address(this));
        assertGe(stBal, funding - 2, "stETH minted");

        lido.approve(LYBRA, type(uint256).max);
        lybra.depositStETHToMint(address(this), stBal, 0);

        uint256 eusdNeeded = e * P0 / WAD + 1;
        lybra.mint(address(this), eusdNeeded);
        lybra.approve(LYBRA, eusdNeeded);

        uint256 before = lido.balanceOf(address(this));
        lybra.liquidation(address(this), victim, e);
        uint256 received = lido.balanceOf(address(this)) - before;

        // 1.1x of e, to within stETH share rounding.
        assertApproxEqAbs(received, e * 11 / 10, 3, "seized != 1.1x");

        // Net worth = wallet + collateral - debt (marked at oracle) + leftover eUSD.
        uint256 depNow = lybra.depositedEther(address(this));
        uint256 borNow = lybra.getBorrowedOf(address(this));
        uint256 eusdBal = lybra.balanceOf(address(this));
        int256 netDelta = int256(lido.balanceOf(address(this)) + depNow + eusdBal * WAD / P0)
            - int256(borNow * WAD / P0) - int256(stBal);
        assertApproxEqRel(netDelta, int256(e / 10), 0.002e18, "net worth delta != 10% of repaid");

        emit log_named_decimal_uint("etherAmount liquidated", e, 18);
        emit log_named_decimal_uint("stETH seized (1.1x)", received, 18);
        emit log_named_decimal_uint("eUSD deployed", eusdNeeded, 18);
        emit log_named_decimal_int("net worth delta (stETH)", netDelta, 18);
        emit log_named_decimal_uint("capital posted (stETH)", stBal, 18);
        emit log_named_decimal_uint("cash after (stETH)", lido.balanceOf(address(this)), 18);
    }

    // ---------------------------------------------------------------- T3
    /// @notice The bonus is NOT flash-loanable: a liquidator at max mint has zero
    ///         withdrawable collateral, so a flash loan of the 1.6x principal can
    ///         never be repaid from the position (withdraw(1 wei) reverts).
    function test_T3_flashloan_cannot_close() public {
        address victim = VICTIMS[0];
        uint256 dep = V_DEP[0];
        uint256 bor = V_BOR[0];
        uint256 e = bor * WAD / P0;
        if (dep / 2 < e) e = dep / 2;

        uint256 funding = e * 16 / 10 + 2; // 1.6x principal + rounding slack
        vm.deal(address(this), funding);
        lido.submit{value: funding}(address(0));
        uint256 stBal = lido.balanceOf(address(this));
        lido.approve(LYBRA, type(uint256).max);
        lybra.depositStETHToMint(address(this), stBal, 0);

        // Max borrow allowed at 160% CR -> zero withdrawable collateral remains.
        uint256 maxBorrow = stBal * P0 * 100 / (160e18);
        lybra.mint(address(this), maxBorrow);
        lybra.approve(LYBRA, maxBorrow);
        lybra.liquidation(address(this), victim, e);

        // Flash loan of stBal cannot be repaid: not a single wei is withdrawable.
        vm.expectRevert(bytes("collateralRate is Below safeCollateralRate"));
        lybra.withdraw(address(this), 1);

        emit log_string("flash-loan loop cannot close: withdraw(1 wei) reverts at ~160% CR");
    }

    // ---------------------------------------------------------------- T4
    /// @notice Full multi-round extraction across all 17 victims (greedy max each round,
    ///         exact contract integer math). Deploys ~61.2k eUSD of minted capital and
    ///         seizes ~22.67 stETH; the +10% bonus (~2.27 stETH) accrues as position
    ///         equity, while cash in hand after the run is less than the capital posted.
    function test_T4_full_multiround_extraction() public {
        uint256 capital = 37 ether;
        vm.deal(address(this), capital);
        lido.submit{value: capital}(address(0));
        uint256 stBal = lido.balanceOf(address(this));
        lido.approve(LYBRA, type(uint256).max);
        lybra.depositStETHToMint(address(this), stBal, 0);
        uint256 dep0 = lybra.depositedEther(address(this));
        uint256 maxMint = (dep0 * P0 / WAD) * 10 / 16 - 1e15; // capacity at 160% CR
        lybra.mint(address(this), maxMint);
        lybra.approve(LYBRA, type(uint256).max);

        uint256 totalE;
        uint256 totalX;
        uint256 rounds;
        uint256 gasStart = gasleft();
        for (uint256 i; i < 17; i++) {
            for (uint256 j; j < 100; j++) {
                uint256 c = lybra.depositedEther(VICTIMS[i]);
                uint256 d = lybra.getBorrowedOf(VICTIMS[i]);
                if (d == 0 || c == 0) break;
                if (_cr(c, d) >= 150e18) break;
                uint256 e = d * WAD / P0;
                if (c / 2 < e) e = c / 2;
                if (e == 0) break;
                uint256 x = e * P0 / WAD;
                if (x == 0 || x > d) break;
                require(lybra.balanceOf(address(this)) >= x, "out of eUSD");
                lybra.liquidation(address(this), VICTIMS[i], e);
                totalE += e;
                totalX += x;
                rounds++;
            }
        }
        uint256 gasUsed = gasStart - gasleft();

        uint256 seized = lido.balanceOf(address(this));
        uint256 depNow = lybra.depositedEther(address(this));
        uint256 borNow = lybra.getBorrowedOf(address(this));
        uint256 eusdBal = lybra.balanceOf(address(this));
        int256 netDelta = int256(seized + depNow + eusdBal * WAD / P0) - int256(borNow * WAD / P0) - int256(dep0);

        assertApproxEqRel(totalE, 22.669e18, 0.02e18, "total ETH repaid");
        assertApproxEqRel(totalX, 61_218e18, 0.02e18, "total eUSD deployed");
        assertApproxEqRel(seized, 24.936e18, 0.02e18, "total stETH seized");
        assertApproxEqRel(netDelta, int256(2.267e18), 0.02e18, "net worth delta");
        assertGt(rounds, 200, "rounds");

        emit log_named_uint("liquidation rounds", rounds);
        emit log_named_decimal_uint("total eUSD deployed", totalX, 18);
        emit log_named_decimal_uint("stETH seized", seized, 18);
        emit log_named_decimal_uint("capital posted (stETH)", dep0, 18);
        emit log_named_decimal_uint("cash after (stETH)", seized, 18);
        emit log_named_decimal_int("net worth delta (stETH, locked equity)", netDelta, 18);
        emit log_named_decimal_uint("gas used (test ctx)", gasUsed, 0);
    }

    // ---------------------------------------------------------------- T5
    /// @notice Market-buy path is unprofitable: buying eUSD from the only live market
    ///         (Curve, 1.54k eUSD / 2.81k USDC) already costs > $1.10/eUSD at the
    ///         smallest size, while liquidation yields exactly $1.10 per eUSD.
    function test_T5_market_buy_path_unprofitable() public view {
        uint256[6] memory usdcIn = [uint256(50e6), 100e6, 250e6, 500e6, 1000e6, 2809e6];
        for (uint256 i; i < 6; i++) {
            uint256 eusdOut = curve.get_dy(1, 0, usdcIn[i]); // USDC -> eUSD
            uint256 price6 = usdcIn[i] * WAD / eusdOut; // USDC (6 dec) per eUSD
            assertGt(price6, 1.10e6, "buy price below liquidation yield");
        }
        // Selling eUSD into the pool yields only ~$1.05-1.08 (bid side).
        uint256 usdcOut = curve.get_dy(0, 1, 100e18); // eUSD -> USDC
        assertLt(usdcOut, 1.09e8, "eUSD bid too high");
    }

    // ---------------------------------------------------------------- T6
    /// @notice Context: 80.1 stETH of excess LSD income sits in the vault as the par
    ///         (1:1) redemption sink for eUSD, which floors eUSD near $1 and caps the
    ///         liquidation-bonus arbitrage at ~$1.10.
    function test_T6_excess_income_par_sink() public {
        uint256 excess = lido.balanceOf(LYBRA) - lybra.totalDepositedEther();
        assertGt(excess, 79e18, "excess income");
        assertLt(excess, 81e18, "excess income");
        emit log_named_decimal_uint("excess stETH income (par sink)", excess, 18);
    }

    // ---------------------------------------------------------------- T7
    /// @notice Live-state check (fork at env FORK_RPC_URL, latest block): the path is
    ///         still open today, and the market still prices eUSD at/above the bonus.
    function test_T7_live_state_still_open() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        uint256 price = feed.fetchPrice();
        uint256 underwater;
        uint256 totalDebt;
        for (uint256 i; i < 17; i++) {
            uint256 c = lybra.depositedEther(VICTIMS[i]);
            uint256 d = lybra.getBorrowedOf(VICTIMS[i]);
            if (d == 0) continue;
            if (c * price * 100 / d < 150e18) {
                underwater++;
                totalDebt += d;
            }
        }
        uint256 globalCr = (lybra.totalDepositedEther() * price * 100) / lybra.totalEUSDCirculation();
        assertGt(underwater, 10, "underwater victims still live");
        assertGt(globalCr, 150e18, "global CR still blocks superLiquidation");
        // eUSD buy price from Curve still at/above the 10% bonus threshold region.
        uint256 eusdOut = curve.get_dy(1, 0, 50e6);
        uint256 price6 = 50e6 * WAD / eusdOut;
        assertGt(price6, 1.05e6, "eUSD buy price collapsed");
        emit log_named_decimal_uint("live price", price, 18);
        emit log_named_uint("underwater victims still <150%", underwater);
        emit log_named_decimal_uint("total debt of underwater set", totalDebt, 18);
        emit log_named_decimal_uint("global CR", globalCr, 18);
        emit log_named_decimal_uint("Curve eUSD buy price (6dp)", price6, 6);
    }
}
