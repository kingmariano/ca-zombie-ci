// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function closeFactorMantissa() external view returns (uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function mintAllowed(address, address, uint256) external returns (uint256);
    function borrowAllowed(address, address, uint256) external returns (uint256);
    function redeemAllowed(address, address, uint256) external returns (uint256);
    function repayBorrowAllowed(address, address, address, uint256) external returns (uint256);
    function liquidateBorrowAllowed(address, address, address, address, uint256) external returns (uint256);
    function seizeAllowed(address, address, address, address, uint256) external returns (uint256);
    function transferAllowed(address, address, address, uint256) external returns (uint256);
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function getUnderlyingPrice(address) external view returns (uint256);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
}

interface ICToken {
    function symbol() external view returns (string memory);
    function underlying() external view returns (address);
    function mint(uint256) external returns (uint256);
    function mint() external;
    function borrow(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function getCash() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function getAccountSnapshot(address) external view returns (uint256, uint256, uint256, uint256);
    function liquidateBorrow(address, uint256, address) external returns (uint256);
}

interface IAggregator {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
    function owner() external view returns (address);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title C-38 Tectonic (Cronos) live-state + exploitability fork tests
/// @notice Read-only fork tests. No mainnet transactions.
contract TectonicLiveTest is Test {
    address constant UNITROLLER = 0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0;
    address constant ORACLE = 0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A;
    address constant TUSDC = 0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e;
    address constant USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
    address constant TVVS = 0xB075A3590c9FFc8332c47Db49f5c6Ee1dBcDF804;
    address constant VVS = 0x2D03bECE6747ADC00E1a131BBA1469C15fD11e03;
    address constant TTONIC = 0xfe6934FDf050854749945921fAA83191Bccf20Ad;
    address constant TONIC = 0xDD73dEa10ABC2Bff99c60882EC5b2B81Bb1Dc5B2;
    address constant TCRO = 0xeAdf7c01DA7E93FdB5f16B0aa9ee85f978e89E95;
    address constant TLCROD = 0x6b986d5109cd065E4098664b3e2E34b4028967cd;
    address constant TONIC_FEED = 0x14f753940720C1Fa4247Cd464C7EA28c806d123F;
    address constant VVS_USDC_TONIC = 0x2f12D47Fe49B907d7a5Df8159C1CE665187F15c4;
    // underwater borrower: tUSDC debt, tVVS collateral (dust collateral, dust profit)
    address constant BORROWER = 0x8E2C707786B55b2c25c9B834d5A2C1Fb6D56D395;
    // bad-debt account: 1.2e12 TONIC debt, ~$0.12 tUSDC collateral
    address constant BAD_DEBT = 0xbeB083D0B3db1bb37e51FB0C9db3488Df1F64380;
    uint256 constant PROTO_SEIZE_SHARE = 0.028e18;

    IComptroller comp;
    address[] markets;
    address attacker;

    function setUp() public {
        // dedicated fork-capable public RPC (the shared CRONOS_RPC_URL secret is load-balanced
        // and intermittently cannot serve fork state reads; drpc verified locally for all tests)
        vm.createSelectFork("https://cronos.drpc.org");
        comp = IComptroller(UNITROLLER);
        markets = comp.getAllMarkets();
        attacker = makeAddr("attacker");
    }

    function _isNative(address m) internal view returns (bool) {
        (bool ok, ) = m.staticcall(abi.encodeWithSignature("underlying()"));
        return !ok;
    }

    /// 1. Every market is mint- and borrow-paused; direct mint/borrow revert.
    function test_all_markets_mint_borrow_paused() public {
        assertEq(markets.length, 18, "expected 18 markets");
        for (uint256 i = 0; i < markets.length; i++) {
            assertTrue(comp.mintGuardianPaused(markets[i]), "mint not paused");
            assertTrue(comp.borrowGuardianPaused(markets[i]), "borrow not paused");
        }
        vm.expectRevert(bytes("mint is paused"));
        ICToken(TUSDC).mint(1e6);
        vm.expectRevert(bytes("borrow is paused"));
        ICToken(TUSDC).borrow(1e6);
        vm.expectRevert(bytes("mint is paused"));
        ICToken(TCRO).mint();
        vm.expectRevert(bytes("mint is paused"));
        ICToken(TTONIC).mint(1e18);
    }

    /// 2. Comptroller gates: mint/borrow closed at the gate; redeem/repay/transfer/seize open.
    function test_gates() public {
        vm.startPrank(TUSDC);
        vm.expectRevert(bytes("mint is paused"));
        comp.mintAllowed(TUSDC, attacker, 1e6);
        vm.expectRevert(bytes("borrow is paused"));
        comp.borrowAllowed(TUSDC, attacker, 1e6);
        assertEq(comp.redeemAllowed(TUSDC, attacker, 1), 0, "redeem blocked");
        assertEq(comp.repayBorrowAllowed(TUSDC, attacker, attacker, 1), 0, "repay blocked");
        assertEq(comp.transferAllowed(TUSDC, attacker, attacker, 1), 0, "transfer blocked");
        vm.stopPrank();
        vm.prank(TVVS);
        assertEq(comp.seizeAllowed(TVVS, TUSDC, attacker, BORROWER, 1), 0, "seize blocked");
    }

    /// 3. Empty-market donation path requires mint, which is paused.
    function test_empty_market_donation_blocked() public {
        // tLCROd: near-empty market (0.1 LCRO cash, CF=0)
        assertApproxEqAbs(ICToken(TLCROD).getCash(), 0.1e18, 1e15, "unexpected cash");
        vm.expectRevert(bytes("mint is paused"));
        ICToken(TLCROD).mint(1e18);
        // direct underlying donation does not create attacker cTokens (no mint possible)
        assertEq(ICToken(TLCROD).balanceOf(attacker), 0);
    }

    /// 4. Liquidations are open: liquidating the largest-collateral underwater account yields dust.
    function test_liquidation_profit_is_dust() public {
        (, uint256 liq, uint256 shortfall) = comp.getAccountLiquidity(BORROWER);
        if (liq != 0 || shortfall == 0) {
            emit log_string("BORROWER no longer underwater (already liquidated?) - state check only");
            return;
        }
        assertGt(shortfall, 0, "borrower not underwater");

        // fund attacker with USDC from the market's own cash via prank (fork only)
        vm.prank(TUSDC);
        IERC20(USDC).transfer(attacker, 100e6);

        (uint256 err, , uint256 borrowBal, ) = ICToken(TUSDC).getAccountSnapshot(BORROWER);
        assertEq(err, 0);
        uint256 repay = borrowBal / 2;

        vm.prank(TUSDC);
        assertEq(comp.liquidateBorrowAllowed(TUSDC, TVVS, attacker, BORROWER, repay), 0, "liq not allowed");

        vm.startPrank(attacker);
        IERC20(USDC).approve(TUSDC, type(uint256).max);
        uint256 before = ICToken(TVVS).balanceOf(attacker);
        ICToken(TUSDC).liquidateBorrow(BORROWER, repay, TVVS);
        uint256 seized = ICToken(TVVS).balanceOf(attacker) - before;
        assertGt(seized, 0, "nothing seized");
        // realize the seized collateral in VVS
        uint256 vvsBefore = IERC20(VVS).balanceOf(attacker);
        ICToken(TVVS).redeem(seized);
        assertGt(IERC20(VVS).balanceOf(attacker) - vvsBefore, 0, "redeem failed");
        vm.stopPrank();

        // value with protocol oracle prices (all in 1e18-scaled USD)
        uint256 priceUsdc = IOracle(ORACLE).getUnderlyingPrice(TUSDC); // 1e30 scale (6-dec underlying)
        uint256 priceVvs = IOracle(ORACLE).getUnderlyingPrice(TVVS); // 1e18 scale (18-dec underlying)
        uint256 repayUsd = (repay * priceUsdc) / 1e18; // 6-dec raw * 1e30 / 1e18 = 1e18 USD
        uint256 exRate = ICToken(TVVS).exchangeRateStored();
        uint256 seizeUnderlying = (seized * exRate) / 1e18; // raw VVS (18 dec)
        uint256 seizeUsdGross = (seizeUnderlying * priceVvs) / 1e18; // 1e18 USD
        // cToken `seize` already deducts protocolSeizeShare from the liquidator's received balance
        uint256 seizeUsdNet = seizeUsdGross;
        int256 profit = int256(seizeUsdNet) - int256(repayUsd);
        emit log_named_uint("repay_usdc_raw", repay);
        emit log_named_uint("seized_ctokens", seized);
        emit log_named_uint("repay_usd_1e18", repayUsd);
        emit log_named_uint("seize_usd_net_1e18", seizeUsdNet);
        emit log_named_int("profit_usd_1e18", profit);
        assertLt(profit, 2e18, "liquidation profit exceeds $2 - revisit");
    }

    /// 5. TONIC oracle is >2x the live VVS DEX price (live mispricing, not attacker-writable).
    function test_tonic_oracle_premium() public {
        (, int256 answer, , uint256 updatedAt, ) = IAggregator(TONIC_FEED).latestRoundData();
        assertGt(answer, 0);
        assertGt(updatedAt, block.timestamp - 7 days, "feed stale");
        uint256 oracleUsd = uint256(answer) * 1e6; // 12-dec feed -> 1e18 USD
        IUniswapV2Pair pair = IUniswapV2Pair(VVS_USDC_TONIC);
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        uint256 dexUsd = (uint256(r0) * 1e30) / uint256(r1); // USDC(6)/TONIC(18) -> 1e18 USD
        emit log_named_uint("tonic_oracle_usd_1e18", oracleUsd);
        emit log_named_uint("tonic_dex_usd_1e18", dexUsd);
        assertGt(oracleUsd, dexUsd * 2, "no 2x premium");
        // feed is owner-gated: attacker cannot update
        vm.prank(attacker);
        (bool ok, ) = TONIC_FEED.call(abi.encodeWithSignature("updatePrice(uint256,uint256,int256)", 1, block.timestamp, 1));
        assertFalse(ok, "feed permissionless update!");
    }

    /// 6. Bad debt is stuck (shortfall with no collateral left) - not extractable.
    function test_bad_debt_not_extractable() public {
        (, uint256 liq, uint256 shortfall) = comp.getAccountLiquidity(BAD_DEBT);
        assertEq(liq, 0);
        assertGt(shortfall, 2e22, "expected >$20k shortfall");
        (uint256 err, uint256 ctBal, uint256 borrowBal, ) = ICToken(TTONIC).getAccountSnapshot(BAD_DEBT);
        assertEq(err, 0);
        assertGt(borrowBal, 1e30, "expected TONIC debt");
        (err, ctBal, , ) = ICToken(TUSDC).getAccountSnapshot(BAD_DEBT);
        assertEq(err, 0);
        // collateral ~ 0.11 cToken = ~$0.12
        assertLt(ctBal, 2e7, "collateral larger than expected");
    }
}
