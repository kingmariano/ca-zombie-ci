// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Common.t.sol";

/// Optimism WePiggy — no empty market, all markets unpaused, Hundred-class bound negative.
contract WepiggyOpTest is WepiggyCommon {
    address constant COMPTROLLER = 0x896aecb9E73Bf21C50855B7874729596d0e511CB;
    address constant PWBTC = 0x48a5322c3021d5eD5CE4293112141045d12c7EFC;
    address constant WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address attacker = address(0xBEEF03);

    function setUp() public {
        string[] memory urls = new string[](2);
        urls[0] = vm.envOr("OP_RPC_URL", string(""));
        urls[1] = "https://mainnet.optimism.io";
        selectForkWithFallback(urls, 0);
    }

    function test_op_no_empty_market() public {
        address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
        assertGt(mkts.length, 0);
        for (uint256 i = 0; i < mkts.length; i++) {
            uint256 T = IPToken(mkts[i]).totalSupply();
            emit log_named_string("market", IPToken(mkts[i]).symbol());
            emit log_named_uint("  totalSupply_raw", T);
            assertGt(T, 1e6, "market near-empty: Hundred gate open");
        }
    }

    function test_op_hundred_upper_bound_negative() public {
        uint256 B = otherCashUsd(COMPTROLLER, PWBTC);
        emit log_named_uint("borrowable other cash (USD)", B);
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

    function test_op_concrete_attack_fails() public {
        uint256 D = 10e8;
        uint256 X = 100e8;
        deal(WBTC, attacker, D + X);
        uint256 borrowedUsd = mintDonateBorrowAll(COMPTROLLER, PWBTC, WBTC, attacker, D, X);
        emit log_named_uint("borrowed (USD)", borrowedUsd);
        assertDrainBlocked(COMPTROLLER, PWBTC, attacker, D, X, borrowedUsd);
    }
}
