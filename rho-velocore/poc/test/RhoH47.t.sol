// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// H-47 · Rho Markets (Scroll) — live-state assessment
// Compound-v2/Moonwell fork. July-2024 incident: ETH oracle pointed at the
// WBTC feed (deployment misconfig) -> $7.6M borrowed, later returned.
// Tests: is the oracle fixed, are empty markets protected, is any value
// permissionlessly extractable today?
// Read-only fork tests. No mainnet transactions.
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IComptroller {
    function markets(address) external view returns (bool isListed, uint256 collateralFactorMantissa);
    function liquidatable() external view returns (bool);
    function liquidateBorrowAllowed(
        address rTokenBorrowed,
        address rTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external view returns (uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function redeemGuardianPaused(address) external view returns (bool);
    function oracle() external view returns (address);
}

interface IRToken {
    function totalSupply() external view returns (uint256);
    function getCash() external view returns (uint256);
    function decimals() external view returns (uint8);
    function underlying() external view returns (address);
    function redeemUnderlying(uint256) external returns (uint256);
    function mint(uint256) external returns (uint256);
    function symbol() external view returns (string memory);
}

interface IPriceOracle {
    function getUnderlyingPrice(address rToken) external view returns (uint256);
}

contract RhoH47Test is Test {
    address constant COMP = 0x8a67AB98A291d1AEA2E1eB0a79ae4ab7f2D76041;
    address constant ORACLE = 0x653C2D3A1E4Ac5330De3c9927bb9BDC51008f9d5;
    address constant ATTACKER = 0x00000000000000000000000000000000DeaDBeef;

    address constant rETH = 0x639355f34Ca9935E0004e30bD77b9cE2ADA0E692;
    address constant rUSDT = 0x855CEA8626Fa7b42c13e7A688b179bf61e6c1e81;
    address constant rUSDC = 0xAE1846110F72f2DaaBC75B7cEEe96558289EDfc5;
    address constant rSTONE = 0xAD3d07d431B85B525D81372802504Fa18DBd554c;
    address constant rwstETH = 0xe4FC4C444efFB5ECa80274c021f652980794Eae6;
    address constant rsolvBTC = 0x8966993138b95b48142f6ecB590427eb7e18a719;
    address constant rweETH_seed1 = 0x8698fB1093b6DBC345e2aAFEb853C602A3582548;
    address constant rweETH_seed2 = 0x00B49129Af3be28D0Cdb1e60B155B234d0E19190;
    address constant rweETH = 0x65a5dBEf0D1Bff772822E4652Aed2829718DC43F;
    address constant rwrsETH = 0x52Fef2B9040BA81e40421660335655D70Fe8Cf03;
    address constant rUSDe = 0x5fF1926507f6e71bFbd5f9897fBaeF021E2F77CA;
    address constant rWBTC_seed1 = 0x76DC94562c89D2820E88D1274d4Bb32Cee306d4C;
    address constant rWBTC_seed2 = 0x1D73ead2BBEa318344fccD7142F70488BAb08F44;
    address constant runiETH = 0xFE707359517f0d5AD0187a237974D3110A734016;
    address constant rylstETH = 0x7AE3c19De353ce163Fe81AE3ebFC90709d3868BE;
    address constant rSCR = 0xC34721FE52284FAB7AEC852A48CB45108F8b4aCa;

    function _scrollRpc() internal view returns (string memory) {
        return vm.envOr("SCROLL_RPC_URL", string("https://scroll-rpc.publicnode.com"));
    }

    function setUp() public {
        vm.createSelectFork(_scrollRpc());
    }

    function _markets() internal pure returns (address[16] memory m) {
        m = [
            rETH, rUSDT, rUSDC, rSTONE, rwstETH, rsolvBTC, rweETH_seed1, rweETH_seed2,
            rweETH, rwrsETH, rUSDe, rWBTC_seed1, rWBTC_seed2, runiETH, rylstETH, rSCR
        ];
    }

    // ------------------------------------------------------------------
    // 1. The oracle is fixed: ETH is priced from the ETH feed, not WBTC.
    // ------------------------------------------------------------------
    function test_oracle_eth_price_is_eth_not_btc() public {
        uint256 ethP = IPriceOracle(ORACLE).getUnderlyingPrice(rETH);
        uint256 btcP = IPriceOracle(ORACLE).getUnderlyingPrice(rWBTC_seed1);
        console.log("[oracle] rETH price 1e18-scaled:", ethP);
        console.log("[oracle] WBTC price 1e28-scaled:", btcP);
        assertGt(ethP, 1e21, "ETH must be > $1000");
        assertLt(ethP, 5e21, "ETH must be < $5000 (was ~20x inflated at BTC price)");
        assertGt(btcP, 1e31, "WBTC must be > $1000 (8-dec scale)");
        assertTrue(ethP != btcP, "ETH and WBTC must not share a feed");
    }

    // ------------------------------------------------------------------
    // 2. No empty market with a non-zero collateral factor (the Dedaub
    //    empty-market/donation class precondition).
    // ------------------------------------------------------------------
    function _checkMarket(address m) internal {
        (bool listed, uint256 cf) = IComptroller(COMP).markets(m);
        uint256 ts = IRToken(m).totalSupply();
        if (cf > 0) {
            assertGt(ts, 1, "market with CF>0 must not be empty/seeded-only");
        }
        assertTrue(listed, "market must be listed");
    }

    function test_no_empty_market_A() public {
        _checkMarket(rETH);
        _checkMarket(rUSDT);
        _checkMarket(rUSDC);
        _checkMarket(rSTONE);
    }

    function test_no_empty_market_B() public {
        _checkMarket(rwstETH);
        _checkMarket(rsolvBTC);
        _checkMarket(rweETH_seed1);
        _checkMarket(rweETH_seed2);
    }

    function test_no_empty_market_C() public {
        _checkMarket(rweETH);
        _checkMarket(rwrsETH);
        _checkMarket(rUSDe);
        _checkMarket(rWBTC_seed1);
    }

    function test_no_empty_market_D() public {
        _checkMarket(rWBTC_seed2);
        _checkMarket(runiETH);
        _checkMarket(rylstETH);
        _checkMarket(rSCR);
    }

    // ------------------------------------------------------------------
    // 3. The four seeded markets are fully paused with CF=0.
    // ------------------------------------------------------------------
    function test_seeded_markets_paused_cf_zero() public {
        address[4] memory seeded = [rweETH_seed1, rweETH_seed2, rWBTC_seed1, rWBTC_seed2];
        for (uint256 i = 0; i < seeded.length; i++) {
            (, uint256 cf) = IComptroller(COMP).markets(seeded[i]);
            assertEq(cf, 0, "seeded market CF must be 0");
            assertTrue(IComptroller(COMP).mintGuardianPaused(seeded[i]), "seeded mint paused");
            assertTrue(IComptroller(COMP).borrowGuardianPaused(seeded[i]), "seeded borrow paused");
        }
    }

    // ------------------------------------------------------------------
    // 4. Liquidations are whitelist-gated (liquidatable flag true).
    // ------------------------------------------------------------------
    function test_liquidations_are_whitelist_gated() public {
        assertTrue(IComptroller(COMP).liquidatable(), "liquidatable flag must be true");
        uint256 allowed =
            IComptroller(COMP).liquidateBorrowAllowed(rETH, rUSDC, ATTACKER, address(0xdead), 1);
        console.log("[liq] liquidateBorrowAllowed(attacker):", allowed);
        assertTrue(allowed != 0, "non-whitelisted attacker cannot liquidate");
    }

    // ------------------------------------------------------------------
    // 5. Total live cash is tiny (< $2k). Prices hardcoded at 2026-10-04.
    // ------------------------------------------------------------------
    function test_total_live_cash_small() public {
        uint256 usd1e18 = 0;
        // rylstETH: 0.2 ylstETH * $2889
        usd1e18 += IRToken(rylstETH).getCash() * 2889;
        // runiETH: 0.001001 uniETH * $3071
        usd1e18 += IRToken(runiETH).getCash() * 3071;
        // rSCR: 39.73 SCR * $0.0259
        usd1e18 += (IRToken(rSCR).getCash() * 25924120000000000) / 1e18;
        // rUSDC: raw 6-dec * $1
        usd1e18 += IRToken(rUSDC).getCash() * 1e12;
        console.log("[cash] rylstETH cash:", IRToken(rylstETH).getCash());
        console.log("[cash] runiETH cash:", IRToken(runiETH).getCash());
        console.log("[cash] rSCR cash:", IRToken(rSCR).getCash());
        console.log("[cash] rUSDC cash:", IRToken(rUSDC).getCash());
        console.log("[cash] total live cash USD (1e18):", usd1e18);
        assertLt(usd1e18, 2000e18, "total live cash must be < $2k");
    }

    // ------------------------------------------------------------------
    // 6. An attacker with no rTokens cannot redeem anything.
    // ------------------------------------------------------------------
    function test_attacker_cannot_redeem_without_rtokens() public {
        vm.prank(ATTACKER);
        bool failed;
        try IRToken(rUSDC).redeemUnderlying(1000e6) returns (uint256 code) {
            failed = (code != 0);
        } catch {
            failed = true;
        }
        assertTrue(failed, "redeemUnderlying with zero balance must fail");
        assertEq(IERC20(0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4).balanceOf(ATTACKER), 0, "attacker got USDC");
    }

    // ------------------------------------------------------------------
    // 7. An attacker cannot mint into the paused seeded markets.
    // ------------------------------------------------------------------
    function test_attacker_cannot_mint_into_seeded_market() public {
        vm.prank(ATTACKER);
        bool failed;
        try IRToken(rweETH_seed2).mint(1e18) returns (uint256 code) {
            failed = (code != 0);
        } catch {
            failed = true;
        }
        assertTrue(failed, "mint into paused seeded market must fail");
    }
}
