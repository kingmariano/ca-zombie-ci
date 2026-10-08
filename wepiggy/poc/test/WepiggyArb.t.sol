// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Common.t.sol";

/// Arbitrum WePiggy — no empty market, all markets unpaused, Hundred-class bound negative.
contract WepiggyArbTest is WepiggyCommon {
    address constant COMPTROLLER = 0xaa87715E858b482931eB2f6f92E504571588390b;
    address constant PWBTC = 0x3393cD223f59F32CC0cC845DE938472595cA48a1;
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address attacker = address(0xBEEF02);

    function setUp() public {
        string[] memory urls = new string[](2);
        urls[0] = vm.envOr("ARB_RPC_URL", string(""));
        urls[1] = "https://arb1.arbitrum.io/rpc";
        selectForkWithFallback(urls, 0);
    }

    function test_arb_no_empty_market() public {
        address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
        assertGt(mkts.length, 0);
        for (uint256 i = 0; i < mkts.length; i++) {
            uint256 T = IPToken(mkts[i]).totalSupply();
            emit log_named_string("market", IPToken(mkts[i]).symbol());
            emit log_named_uint("  totalSupply_raw", T);
            assertGt(T, 1e6, "market near-empty: Hundred gate open");
        }
    }

    function test_arb_hundred_upper_bound_negative() public {
        uint256 B = otherCashUsd(COMPTROLLER, PWBTC);
        emit log_named_uint("borrowable other cash (USD)", B);
        assertGt(B, 10_000, "sanity");
        uint256[5] memory Ds = [uint256(1e8), 10e8, 100e8, 1000e8, 10000e8];
        uint256[6] memory Xs = [uint256(0), 1e8, 10e8, 100e8, 1000e8, 10000e8];
        int256 best = type(int256).min;
        for (uint256 i = 0; i < Ds.length; i++) {
            for (uint256 j = 0; j < Xs.length; j++) {
                int256 net = hundredUpperBound(COMPTROLLER, PWBTC, Ds[i], Xs[j], B, 0);
                if (net == type(int256).min) continue;
                if (net > best) best = net;
            }
        }
        assertTrue(best != type(int256).min, "no feasible config");
        assertLt(best, 0, "profitable Hundred config exists");
    }

    function test_arb_concrete_attack_fails() public {
        uint256 D = 10e8;
        uint256 X = 100e8;
        deal(WBTC, attacker, D + X);
        uint256 borrowedUsd = mintDonateBorrowAll(COMPTROLLER, PWBTC, WBTC, attacker, D, X);
        emit log_named_uint("borrowed (USD)", borrowedUsd);
        assertDrainBlocked(COMPTROLLER, PWBTC, attacker, D, X, borrowedUsd);
    }
}
