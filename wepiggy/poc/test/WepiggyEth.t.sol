// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Common.t.sol";

/// Ethereum mainnet WePiggy — Hundred-class attack verification (largest cash chain).
/// All interactions are fork-only; no mainnet transactions.
contract WepiggyEthTest is WepiggyCommon {
    address constant COMPTROLLER = 0x0C8c1ab017c3C0c8A48dD9F1DB2F59022D190f0b;
    address constant PWBTC = 0xc12B9D620bFCB48be3e0CCbf0ea80C717333b46F;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // Uniswap V3 WBTC/USDC 0.3% pool: a WBTC whale used to fund the attacker on the fork
    // (avoids `deal`'s storage-slot discovery, which is flaky on public fork RPCs).
    address constant WBTC_WHALE = 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35;
    address attacker = address(0xBEEF01);

    function setUp() public {
        string[] memory urls = new string[](6);
        urls[0] = vm.envOr("BLOCKPI_RPC_URL", string(""));
        urls[1] = vm.envOr("NODEREAL_ETH_RPC_URL", string(""));
        urls[2] = vm.envOr("RPC_URL", string(""));
        urls[3] = vm.envOr("FORK_RPC_URL", string(""));
        urls[4] = "https://ethereum-rpc.publicnode.com";
        urls[5] = "https://eth.drpc.org";
        selectForkWithFallback(urls, 0);
    }

    /// The Hundred/Agave/Midas empty-market attack requires the victim market to be
    /// (near-)empty: to drain its cash the attacker must burn totalSupply-1 shares,
    /// which is only possible if other holders own <=1 raw wei of cTokens.
    function test_eth_no_empty_market() public {
        address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
        assertEq(mkts.length, 10, "expected 10 markets");
        for (uint256 i = 0; i < mkts.length; i++) {
            uint256 T = IPToken(mkts[i]).totalSupply();
            emit log_named_string("market", IPToken(mkts[i]).symbol());
            emit log_named_uint("  totalSupply_raw", T);
            assertGt(T, 1e6, "market near-empty: Hundred gate open");
        }
    }

    /// Upper-bound search over (D, X) for the Hundred recipe on the largest-cash
    /// market pWBTC ($361k cash). Net upper bound must be negative for every config.
    function test_eth_hundred_upper_bound_negative() public {
        uint256 B = otherCashUsd(COMPTROLLER, PWBTC);
        emit log_named_uint("borrowable other cash (USD)", B);
        assertGt(B, 100_000, "sanity: plenty of borrowable cash exists");
        uint256[5] memory Ds = [uint256(1e8), 10e8, 100e8, 1000e8, 10000e8];
        uint256[6] memory Xs = [uint256(0), 10e8, 100e8, 1000e8, 10000e8, 100000e8];
        int256 best = type(int256).min;
        for (uint256 i = 0; i < Ds.length; i++) {
            for (uint256 j = 0; j < Xs.length; j++) {
                int256 net = hundredUpperBound(COMPTROLLER, PWBTC, Ds[i], Xs[j], B, 0);
                if (net == type(int256).min) continue;
                emit log_named_uint("D", Ds[i]);
                emit log_named_uint("X", Xs[j]);
                emit log_named_int("net_ub USD", net);
                if (net > best) best = net;
            }
        }
        assertTrue(best != type(int256).min, "no feasible config at all");
        assertLt(best, 0, "a profitable Hundred-class config exists!");
    }

    /// Concrete best-case attempt: mint 100 WBTC, donate 1500 WBTC, borrow ALL cash
    /// from every other market, then try to redeem the victim's cash.
    function test_eth_concrete_attack_fails() public {
        uint256 D = 5e8;
        uint256 X = 10e8;
        vm.prank(WBTC_WHALE);
        IERC20(WBTC).transfer(attacker, D + X);
        uint256 borrowedUsd = mintDonateBorrowAll(COMPTROLLER, PWBTC, WBTC, attacker, D, X);
        emit log_named_uint("borrowed (USD)", borrowedUsd);
        assertGt(borrowedUsd, 10_000, "borrow leg should work on this live market");
        assertDrainBlocked(COMPTROLLER, PWBTC, attacker, D, X, borrowedUsd);
    }

    /// Donation DOES inflate the exchange rate (mechanism live) but the redeemer's
    /// extraction is bounded by fair value: no free lunch without an empty market.
    function test_eth_donation_inflates_but_is_fair() public {
        uint256 rate0 = IPToken(PWBTC).exchangeRateStored();
        address donor = address(0xD00D);
        vm.prank(WBTC_WHALE);
        IERC20(WBTC).transfer(donor, 11e8);
        vm.startPrank(donor);
        IERC20(WBTC).transfer(PWBTC, 10e8);
        vm.stopPrank();
        uint256 rate1 = IPToken(PWBTC).exchangeRateStored();
        emit log_named_uint("rate before", rate0);
        emit log_named_uint("rate after 10 WBTC donation", rate1);
        assertGt(rate1, rate0, "donation should inflate exchange rate");
        address fresh = address(0xF11E5);
        vm.prank(WBTC_WHALE);
        IERC20(WBTC).transfer(fresh, 1e8);
        vm.startPrank(fresh);
        IERC20(WBTC).approve(PWBTC, type(uint256).max);
        assertEq(IPToken(PWBTC).mint(1e8), 0);
        uint256 before = IERC20(WBTC).balanceOf(fresh);
        uint256 err = IPToken(PWBTC).redeem(IPToken(PWBTC).balanceOf(fresh));
        uint256 out = IERC20(WBTC).balanceOf(fresh) - before;
        emit log_named_uint("redeem err", err);
        emit log_named_uint("WBTC out", out);
        assertEq(err, 0, "fair redeem should work");
        assertLe(out, 1e8, "redeemer got more than deposited: profit!");
        vm.stopPrank();
    }
}
