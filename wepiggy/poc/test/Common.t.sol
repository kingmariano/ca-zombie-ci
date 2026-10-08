// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPToken {
    function symbol() external view returns (string memory);
    function underlying() external view returns (address);
    function comptroller() external view returns (address);
    function getCash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function borrowBalanceStored(address) external view returns (uint256);
}

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function markets(address) external view returns (bool, uint256, bool);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
    function oracle() external view returns (address);
    function getUnderlyingPrice(address) external view returns (uint256);
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function closeFactorMantissa() external view returns (uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function pTokenMintGuardianPaused(address) external view returns (bool);
    function pTokenBorrowGuardianPaused(address) external view returns (bool);
    function borrowAllowed(address, address, uint256) external returns (uint256);
}

/// Shared helpers for WePiggy (Compound-v2 fork) zombie-hunt verification.
/// Compound oracle price mantissa = USD * 1e(36-decimals); hence
/// USD(amount_raw) = amount_raw * price / 1e36  (decimals cancel).
contract WepiggyCommon is Test {
    function usd(uint256 amount, uint256 price, uint256) internal pure returns (uint256) {
        return amount * price / 1e36;
    }

    function _dec(address token) internal view returns (uint256) {
        (bool ok, bytes memory r) = token.staticcall(abi.encodeWithSelector(IERC20.decimals.selector));
        if (!ok || r.length < 32) return 18;
        return uint256(bytes32(r));
    }

    function slice32(bytes memory b, uint256 off) internal pure returns (bytes32 out) {
        assembly {
            out := mload(add(add(b, 32), off))
        }
    }

    /// Select a fork, trying several RPCs in order (public fork RPCs are flaky).
    /// blockNumber == 0 forks "latest"; a pinned block avoids latest-hash races
    /// on load-balanced RPCs but requires an archive-capable endpoint.
    function selectForkWithFallback(string[] memory urls, uint256 blockNumber) internal {
        for (uint256 i = 0; i < urls.length; i++) {
            if (bytes(urls[i]).length == 0) continue;
            if (blockNumber == 0) {
                try vm.createSelectFork(urls[i]) {
                    return;
                } catch {}
            } else {
                try vm.createSelectFork(urls[i], blockNumber) {
                    return;
                } catch {}
            }
        }
        revert("no working fork RPC");
    }

    struct UB {
        address victim;
        uint256 priceV;
        uint256 cf;
        uint256 D;
        uint256 X;
        uint256 B_usd;
    }

    /// Upper bound (USD, signed) on an attacker's net for the Hundred-class recipe
    /// against `victim`, given mint D, donation X (both in victim underlying) and
    /// B_usd = value borrowable from all other markets.
    /// The redeem liquidity check forces the attacker to keep k shares whose value
    /// covers the debt; the most they can withdraw is (t-k+1) shares' worth.
    function hundredUpperBound(
        address comptroller,
        address victim,
        uint256 D,
        uint256 X,
        uint256 B_usd,
        uint256
    ) internal view returns (int256) {
        UB memory u;
        u.victim = victim;
        u.D = D;
        u.X = X;
        u.B_usd = B_usd;
        address oracle = IComptroller(comptroller).oracle();
        u.priceV = IComptroller(oracle).getUnderlyingPrice(victim);
        u.cf = _cf(comptroller, victim);
        if (u.priceV == 0 || u.cf == 0) return type(int256).min;
        (uint256 t, uint256 rate2) = _postRate(victim, D, X);
        uint256 k = _keptShares(u.cf, rate2, u.priceV, u.B_usd);
        if (k < 1) k = 1;
        if (k > t) return type(int256).min; // infeasible
        return _netFrom(u, t, rate2, k);
    }

    function _cf(address comptroller, address victim) internal view returns (uint256 cf) {
        (bool ok, bytes memory mret) = comptroller.staticcall(abi.encodeWithSignature("markets(address)", victim));
        if (ok && mret.length >= 64 && uint256(bytes32(mret)) != 0) cf = uint256(slice32(mret, 32));
    }

    function _postRate(address victim, uint256 D, uint256 X) internal view returns (uint256 t, uint256 rate2) {
        uint256 T = IPToken(victim).totalSupply();
        uint256 xr = IPToken(victim).exchangeRateStored();
        uint256 cash = IPToken(victim).getCash();
        uint256 borrows = IPToken(victim).totalBorrows();
        uint256 reserves = IPToken(victim).totalReserves();
        if (xr == 0 || T == 0) return (0, 0);
        t = D * 1e18 / xr;
        rate2 = (cash + borrows - reserves + D + X) * 1e18 / (T + t);
    }

    function _keptShares(uint256 cf, uint256 rate2, uint256 priceV, uint256 B_usd) internal pure returns (uint256) {
        // collateral USD per raw share = (cf/1e18) * (rate2/1e18) * (priceV/1e36)
        // => den2 = cf*rate2/1e18 * priceV/1e18  (USD * 1e18 per share)
        uint256 den1 = cf * rate2 / 1e18;
        uint256 den2 = den1 * priceV / 1e18;
        if (den2 == 0) return 0;
        uint256 num = B_usd * 1e36;
        return (num + den2 - 1) / den2;
    }

    function _netFrom(UB memory u, uint256 t, uint256 rate2, uint256 k) internal view returns (int256) {
        uint256 R = (t - k + 1) * rate2 / 1e18;
        uint256 cashAvail = IPToken(u.victim).getCash() + u.D + u.X;
        if (R > cashAvail) R = cashAvail;
        return int256(usd(R, u.priceV, 0)) + int256(u.B_usd) - int256(usd(u.D, u.priceV, 0))
            - int256(usd(u.X, u.priceV, 0));
    }

    /// Sum of other markets' cash in USD (borrowable), skipping the victim and paused markets.
    function otherCashUsd(address comptroller, address victim) internal returns (uint256 total) {
        address[] memory mkts = IComptroller(comptroller).getAllMarkets();
        address oracle = IComptroller(comptroller).oracle();
        for (uint256 i = 0; i < mkts.length; i++) {
            address m = mkts[i];
            if (m == victim) continue;
            bool paused = false;
            try IComptroller(comptroller).pTokenBorrowGuardianPaused(m) returns (bool p) {
                paused = p;
            } catch {
                paused = true;
            }
            if (paused) continue;
            uint256 price = IComptroller(oracle).getUnderlyingPrice(m);
            if (price == 0) continue;
            total += usd(IPToken(m).getCash(), price, 0);
        }
    }

    /// Mint D into victim, donate X, enter the market, then borrow all cash from every other market.
    function mintDonateBorrowAll(
        address comptroller,
        address victim,
        address underlying,
        address attacker,
        uint256 D,
        uint256 X
    ) internal returns (uint256 borrowedUsd) {
        vm.startPrank(attacker);
        IERC20(underlying).approve(victim, type(uint256).max);
        require(IPToken(victim).mint(D) == 0, "mint failed");
        require(IERC20(underlying).transfer(victim, X), "donation failed");
        // NOTE: WePiggy's mintAllowed() does NOT auto-enter the market (unlike Compound),
        // so the attacker must explicitly enable the collateral market.
        address[] memory enter = new address[](1);
        enter[0] = victim;
        IComptroller(comptroller).enterMarkets(enter);
        borrowedUsd = _borrowAllMarkets(comptroller, victim);
        vm.stopPrank();
    }

    function _borrowAllMarkets(address comptroller, address victim) internal returns (uint256 borrowedUsd) {
        address[] memory mkts = IComptroller(comptroller).getAllMarkets();
        address oracle = IComptroller(comptroller).oracle();
        for (uint256 i = 0; i < mkts.length; i++) {
            address m = mkts[i];
            if (m == victim) continue;
            bool paused;
            try IComptroller(comptroller).pTokenBorrowGuardianPaused(m) returns (bool p) {
                paused = p;
            } catch {
                paused = true;
            }
            if (paused) continue;
            uint256 cash = IPToken(m).getCash();
            if (cash == 0) continue;
            uint256 err = IPToken(m).borrow(cash);
            if (err != 0 && cash > 1) err = IPToken(m).borrow(cash - 1);
            if (err == 0) borrowedUsd += usd(cash, IComptroller(oracle).getUnderlyingPrice(m), 0);
        }
    }

    /// After the attack setup: prove the cash drain is blocked and the net bound is negative.
    function assertDrainBlocked(
        address comptroller,
        address victim,
        address attacker,
        uint256 D,
        uint256 X,
        uint256 borrowedUsd
    ) internal {
        vm.startPrank(attacker);
        uint256 cashV = IPToken(victim).getCash();
        uint256 rate = IPToken(victim).exchangeRateStored();
        uint256 t = IPToken(victim).balanceOf(attacker);
        emit log_named_uint("victim cash", cashV);
        emit log_named_uint("attacker shares", t);
        emit log_named_uint("shares needed to drain", (cashV - 1) * 1e18 / rate);
        assertGt((cashV - 1) * 1e18 / rate, t, "Hundred gate: attacker CAN burn enough shares");
        assertTrue(IPToken(victim).redeemUnderlying(cashV - 1) != 0, "full-cash drain succeeded");
        assertTrue(IPToken(victim).redeem(t) != 0, "full-share redeem succeeded");
        (,, uint256 shortfall) = IComptroller(comptroller).getAccountLiquidity(attacker);
        assertEq(shortfall, 0, "position unexpectedly unhealthy");
        int256 net = hundredUpperBound(comptroller, victim, D, X, borrowedUsd, 0);
        emit log_named_int("net_ub USD", net);
        assertLt(net, 0, "net upper bound is not negative");
        vm.stopPrank();
    }
}
