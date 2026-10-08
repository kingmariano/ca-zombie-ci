// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Common.t.sol";

/// BSC WePiggy — shutdown state: every market CF=0 and borrowing paused.
/// The Hundred-class attack needs a borrow against inflated collateral: impossible.
contract WepiggyBscTest is WepiggyCommon {
    address constant COMPTROLLER = 0x8c925623708A94c7DE98a8e83e8200259fF716E0;
    address constant PUNI = 0x17933112E9780aBd0F27f2B7d9ddA9E840D43159;
    address constant UNI = 0xBf5140A22578168FD562DCcF235E5D43A02ce9B1;
    address attacker = address(0xBEEF04);

    function setUp() public {
        string[] memory urls = new string[](2);
        urls[0] = vm.envOr("BSC_RPC_URL", string(""));
        urls[1] = "https://bsc-dataseed.binance.org";
        selectForkWithFallback(urls, 0);
    }

    function test_bsc_no_empty_market_and_cf_zero() public {
        address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
        assertGt(mkts.length, 0);
        for (uint256 i = 0; i < mkts.length; i++) {
            uint256 T = IPToken(mkts[i]).totalSupply();
            (bool listed, uint256 cf, ) = IComptroller(COMPTROLLER).markets(mkts[i]);
            emit log_named_string("market", IPToken(mkts[i]).symbol());
            emit log_named_uint("  totalSupply_raw", T);
            emit log_named_uint("  collateralFactor", cf);
            assertTrue(listed, "not listed");
            assertGt(T, 1e6, "near-empty market");
            assertEq(cf, 0, "CF>0: borrow surface open");
        }
    }

    function test_bsc_borrow_is_paused() public {
        address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
        for (uint256 i = 0; i < mkts.length; i++) {
            bool paused;
            try IComptroller(COMPTROLLER).pTokenBorrowGuardianPaused(mkts[i]) returns (bool p) { paused = p; } catch { paused = true; }
            assertTrue(paused, "borrow not paused on a market");
            // direct call must revert with the pause guard
            bool reverted;
            try IComptroller(COMPTROLLER).borrowAllowed(mkts[i], attacker, 1e18) { reverted = false; }
            catch { reverted = true; }
            assertTrue(reverted, "borrowAllowed did not revert");
        }
    }

    function test_bsc_hundred_attack_blocked() public {
        // pUNI mint is the only open mint; try the full recipe anyway
        uint256 D = 1e18;
        deal(UNI, attacker, D * 2);
        vm.startPrank(attacker);
        IERC20(UNI).approve(PUNI, type(uint256).max);
        uint256 err = IPToken(PUNI).mint(D);
        emit log_named_uint("mint err", err);
        if (err == 0) {
            assertTrue(IERC20(UNI).transfer(PUNI, D), "donation failed");
            // find a market with cash and try to borrow against the inflated pUNI collateral
            address[] memory mkts = IComptroller(COMPTROLLER).getAllMarkets();
            bool anyBorrowSucceeded;
            for (uint256 i = 0; i < mkts.length; i++) {
                if (mkts[i] == PUNI) continue;
                uint256 cash = IPToken(mkts[i]).getCash();
                if (cash == 0) continue;
                try IPToken(mkts[i]).borrow(cash) { anyBorrowSucceeded = true; } catch {}
            }
            assertFalse(anyBorrowSucceeded, "borrow succeeded despite pause");
        }
        vm.stopPrank();
    }
}
