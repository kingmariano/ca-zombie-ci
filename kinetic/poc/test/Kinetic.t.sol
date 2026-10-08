// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IComptroller, ICToken, IOracle, IFtsoV2, IERC20, IStakedFlr, IExchangeable, IAllowList} from "../src/Interfaces.sol";
import {SonneAttacker} from "../src/SonneAttacker.sol";

/// @title Kinetic (Flare) — live extractability determination (C2-12)
/// @notice Read-only on-chain; all tests run on a local Flare fork. No mainnet transactions.
contract KineticTest is Test {
    address constant C1 = 0x15F69897E6aEBE0463401345543C26d1Fd994abB; // ISO FXRP pool
    address constant C2 = 0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8; // main pool
    address constant C3 = 0xDcce91d46Ecb209645A26B5885500127819BeAdd; // ISO JOULE pool
    address constant C4 = 0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f; // legacy/"t" pool

    address constant O1 = 0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b;
    address constant O2 = 0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c;
    address constant O3 = 0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D;

    address constant kSFLR = 0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656;
    address constant kUSDCE = 0xDEeBaBe05BDA7e8C1740873abF715f16164C29B8;
    address constant kFLR = 0xb84F771305d10607Dd086B2f89712c0CeD379407;
    address constant sFLR = 0x12e605bc104e93B45e1aD99F9e555f659051c2BB;
    address constant sNative = 0x7E0182d284c39A0B4dB0E870c59dCf5CDb6F65Cc; // sFLR rate wrapper
    address constant sETH = 0x1347192F6CE9EE6C6Ff4AC899EF5CA7379892D94; // flrETH rate wrapper
    address constant flrETH = 0x26A1faB310bd080542DC864647d05985360B16A5;
    address constant LIQ_VERIFIER = 0x5fa1B6Cdc8E46BfFEed066E1ECd92F90C663e8CC;
    address constant FTSO_V2 = 0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20;
    address constant FTSO_C2 = 0xB18d3A5e5A85C65cE47f977D7F486B79F99D3d32;

    bytes21 constant FLR_USD = bytes21(hex"01464c522f55534400000000000000000000000000");
    bytes21 constant XRP_USD = bytes21(hex"015852502f55534400000000000000000000000000");

    string public usedRpc;

    function setUp() public {
        string[6] memory urls;
        urls[0] = "https://flare.public-rpc.com";
        urls[1] = "https://flare-api.flare.network/ext/C/rpc";
        urls[2] = "https://rpc.ankr.com/flare";
        urls[3] = "https://14.rpc.thirdweb.com";
        urls[4] = "https://flare.drpc.org";
        urls[5] = "";
        // allow CI (ci/run.sh) to pin a probed RPC
        try vm.readFile(".rpc") returns (string memory s) {
            string memory t = _trim(s);
            if (bytes(t).length > 0) urls[5] = t;
        } catch {}

        bool ok = false;
        for (uint256 i = 0; i < urls.length; i++) {
            if (bytes(urls[i]).length == 0) continue;
            try vm.createSelectFork(urls[i]) {
                usedRpc = urls[i];
                ok = true;
                break;
            } catch {}
        }
        if (!ok) vm.skip(true);
        console2.log("fork rpc:", usedRpc);
        console2.log("block:", block.number);
        console2.log("ts:", block.timestamp);
    }

    function _trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 e = b.length;
        while (e > 0 && (b[e - 1] == 0x0a || b[e - 1] == 0x0d || b[e - 1] == 0x20)) e--;
        uint256 st = 0;
        while (st < e && (b[st] == 0x20)) st++;
        bytes memory o = new bytes(e - st);
        for (uint256 i = st; i < e; i++) o[i - st] = b[i];
        return string(o);
    }

    /// USD value (1e18) of `baseUnits` of an underlying with oracle price `price`
    /// (Compound price scaling: USD_token = price / 10**(36-decimals); baseUnits = 10**decimals * tokens)
    function _usd1e18(uint256 baseUnits, uint256 price) internal pure returns (uint256) {
        return (baseUnits * price) / 1e18;
    }

    // ---------------------------------------------------------------- 1

    /// Enumerate both live pools + tripwires for the empty-market / precision-loss class.
    function test_1_live_state_tripwires() public {
        address[2] memory cms = [C1, C2];
        address[2] memory orcs = [O1, O2];
        uint256 totalCashUsd;
        uint256 minSupply = type(uint256).max;
        address minSupplyMkt;

        for (uint256 ci = 0; ci < 2; ci++) {
            IOracle orc = IOracle(orcs[ci]);
            address[] memory mk = IComptroller(cms[ci]).getAllMarkets();
            console2.log("=== comptroller", cms[ci], "markets:", mk.length);
            for (uint256 i = 0; i < mk.length; i++) {
                ICToken t = ICToken(mk[i]);
                uint256 cash = t.getCash();
                uint256 supply = t.totalSupply();
                uint256 borrows = t.totalBorrows();
                uint256 rate = t.exchangeRateStored();
                uint256 price = orc.getUnderlyingPrice(mk[i]);
                (bool listed, uint256 cf) = IComptroller(cms[ci]).markets(mk[i]);
                bool mp = IComptroller(cms[ci]).mintGuardianPaused(mk[i]);
                bool bp = IComptroller(cms[ci]).borrowGuardianPaused(mk[i]);
                uint256 cap = IComptroller(cms[ci]).borrowCaps(mk[i]);

                console2.log(t.symbol());
                console2.log("  cash", cash);
                console2.log("  supply(raw)", supply);
                console2.log("  borrows", borrows);
                console2.log("  exRate", rate);
                console2.log("  cf", cf);
                console2.log("  mintPaused", mp);
                console2.log("  borrowPaused", bp);
                console2.log("  borrowCap", cap);

                assertTrue(listed, "market not listed");
                // Hard tripwire: any market holding cash with microscopic supply would reopen
                // the Sonne donation/truncation class. Fail loudly if that ever becomes true.
                if (cash > 0) {
                    assertGe(supply, 1e9, "TRIPWIRE: market with cash has microscopic supply");
                }
                if (supply == 0) {
                    assertEq(cash, 0, "TRIPWIRE: empty market holds cash");
                    assertEq(borrows, 0, "TRIPWIRE: empty market has borrows");
                }
                if (supply < minSupply) {
                    minSupply = supply;
                    minSupplyMkt = mk[i];
                }
                totalCashUsd += _usd1e18(cash, price);
            }
        }
        console2.log("total cash USD(1e18):", totalCashUsd);
        console2.log("min totalSupply(raw):", minSupply);
        console2.log("min supply market:", minSupplyMkt);
        assertGt(minSupply, 1e9, "TRIPWIRE: some market supply is microscopic");
    }

    // ---------------------------------------------------------------- 2

    /// End-to-end Sonne-style donation attack against the largest unpaused market (kSFLR).
    /// Result must be net-negative: a donation on a market with existing suppliers accrues
    /// to all holders pro-rata; the attacker cannot recover more than fair value.
    function test_2_sonne_donation_attack_is_net_negative() public {
        SonneAttacker atk = new SonneAttacker(IComptroller(C2), ICToken(kSFLR), ICToken(kUSDCE), IStakedFlr(sFLR));
        uint256 flrIn = 20_000 ether;
        vm.deal(address(atk), 30_000 ether);
        SonneAttacker.Result memory r = atk.attack(flrIn);

        console2.log("--- Sonne sequence on kSFLR ---");
        console2.log("flrIn (wei)", r.flrIn);
        console2.log("sflrAcquired", r.sflrAcquired);
        console2.log("minMintWei", r.minMintWei);
        console2.log("sharesHeld(raw)", r.sharesHeld);
        console2.log("sflrDonated", r.sflrDonated);
        console2.log("rateBefore", r.rateBefore);
        console2.log("rateAfter", r.rateAfter);
        console2.log("usdcBorrowed", r.usdcBorrowed);
        console2.log("redeemUnderlying ret", r.redeemRet);
        console2.log("sflrBack", r.sflrBack);

        uint256 flrPx = IOracle(O2).getUnderlyingPrice(kFLR);
        uint256 usdcPx = IOracle(O2).getUnderlyingPrice(kUSDCE);
        uint256 sflrPx = IOracle(O2).getUnderlyingPrice(kSFLR);

        uint256 costUsd = _usd1e18(flrIn, flrPx);
        uint256 borrowedUsd = _usd1e18(r.usdcBorrowed, usdcPx);
        uint256 backUsd = _usd1e18(r.sflrBack, sflrPx);
        int256 netUsd = int256(borrowedUsd + backUsd) - int256(costUsd); // walking away from debt + left collateral

        console2.log("cost USD(1e18)", costUsd);
        console2.log("borrowed USD(1e18)", borrowedUsd);
        console2.log("sflrBack USD(1e18)", backUsd);
        console2.log("NET USD(1e18)", netUsd);
        assertLt(netUsd, 0, "donation attack must be net-negative");
        // and the redeem of the donation must have failed (attacker holds 1 raw share, needs ~1e13)
        assertTrue(r.redeemRet != 0, "redeemUnderlying should fail on non-microscopic supply");
    }

    // ---------------------------------------------------------------- 3

    /// Per-call precision-loss bound: redeemUnderlying can over-pay at most one raw share unit.
    /// Value of one raw cToken unit must be economically irrelevant (< $0.01).
    function test_3_precision_loss_dust_bound() public {
        address[2] memory cms = [C1, C2];
        address[2] memory orcs = [O1, O2];
        for (uint256 ci = 0; ci < 2; ci++) {
            address[] memory mk = IComptroller(cms[ci]).getAllMarkets();
            for (uint256 i = 0; i < mk.length; i++) {
                uint256 rate = ICToken(mk[i]).exchangeRateStored();
                uint256 price = IOracle(orcs[ci]).getUnderlyingPrice(mk[i]);
                // underlying base units represented by ONE raw cToken unit
                uint256 perShare = rate / 1e18;
                uint256 usd1e18 = _usd1e18(perShare, price);
                console2.log(ICToken(mk[i]).symbol(), "dust-per-call USD(1e18):", usd1e18);
                assertLt(usd1e18, 1e16, "precision-loss per call must be < $0.01");
            }
        }
    }

    // ---------------------------------------------------------------- 4

    function test_4_ftso_freshness_and_fail_closed() public {
        (uint256 p, int8 d, uint64 ts) = IFtsoV2(FTSO_V2).getFeedById(FLR_USD);
        console2.log("FLR/USD", p);
        console2.log("dec", int256(d));
        console2.log("feedTs", uint256(ts));
        console2.log("blockTs", block.timestamp);
        assertGt(p, 0);
        assertGt(d, 0);
        // Flare FastUpdater reports block.timestamp while submissions exist; allow either side
        if (uint256(ts) <= block.timestamp) {
            assertLe(block.timestamp - uint256(ts), 420, "feed older than maxStalePeriod");
        } else {
            assertLe(uint256(ts) - block.timestamp, 60, "feed timestamp implausibly ahead");
        }
        uint256 px = IOracle(O2).getUnderlyingPrice(kSFLR);
        assertGt(px, 0);
    }

    function test_4b_ftso_stale_reverts() public {
        // Flare's FastUpdater returns block.timestamp while the feed receives submissions, so vm.warp
        // cannot simulate an outage. Mock the FtsoV2 pointer used by the C2 oracle to return a stale ts.
        (uint256 p, int8 d, ) = IFtsoV2(FTSO_C2).getFeedById(FLR_USD);
        vm.mockCall(
            FTSO_C2,
            abi.encodeWithSelector(IFtsoV2.getFeedById.selector, FLR_USD),
            abi.encode(p, d, block.timestamp - 421)
        );
        vm.expectRevert(bytes("stale price"));
        IOracle(O2).getUnderlyingPrice(kSFLR);
        vm.clearMockedCalls();
        // positive control: fresh mock -> price returned
        vm.mockCall(
            FTSO_C2,
            abi.encodeWithSelector(IFtsoV2.getFeedById.selector, FLR_USD),
            abi.encode(p, d, block.timestamp)
        );
        assertGt(IOracle(O2).getUnderlyingPrice(kSFLR), 0);
        vm.clearMockedCalls();
    }

    // ---------------------------------------------------------------- 5

    function test_5_liquidator_allowlist_blocks_outsiders() public {
        address[3] memory cms = [C1, C2, C3];
        for (uint256 i = 0; i < cms.length; i++) {
            uint256 code = IComptroller(cms[i]).liquidateBorrowAllowed(
                kSFLR, kUSDCE, address(0xDeaD), address(0xBeeF), 0
            );
            console2.log("liquidateBorrowAllowed; random liquidator returns (1 == UNAUTHORIZED):", code);
            assertEq(code, 1, "expected UNAUTHORIZED");
            assertFalse(IAllowList(LIQ_VERIFIER).allowed(address(0xDeaD)), "random addr must not be allowed");
        }
    }

    // ---------------------------------------------------------------- 6

    function test_6_ctoken_approve_allowlist() public {
        vm.expectRevert(bytes("SNA"));
        ICToken(kSFLR).approve(address(0xDeaD), 1);
    }

    // ---------------------------------------------------------------- 7

    /// c3 (ISO JOULE) fully paused; c4 legacy pool: only tflrETH open and same-asset only.
    function test_7_closed_pools_c3_c4() public {
        address[] memory m3 = IComptroller(C3).getAllMarkets();
        for (uint256 i = 0; i < m3.length; i++) {
            assertTrue(IComptroller(C3).mintGuardianPaused(m3[i]), "c3 mint must be paused");
            assertTrue(IComptroller(C3).borrowGuardianPaused(m3[i]), "c3 borrow must be paused");
        }
        console2.log("c3 markets mint+borrow paused:", m3.length);

        address[] memory m4 = IComptroller(C4).getAllMarkets();
        for (uint256 i = 0; i < m4.length; i++) {
            bool mp = IComptroller(C4).mintGuardianPaused(m4[i]);
            bool bp = IComptroller(C4).borrowGuardianPaused(m4[i]);
            uint256 cash = ICToken(m4[i]).getCash();
            (bool listed, uint256 cf) = IComptroller(C4).markets(m4[i]);
            console2.log(ICToken(m4[i]).symbol());
            console2.log("  mintPaused", mp);
            console2.log("  borrowPaused", bp);
            console2.log("  cash", cash);
            console2.log("  cf", cf);
            if (!mp) {
                // the only mintable market: same-asset collateral can at most borrow cf*collateral
                assertLt(cf, 1e18, "cf must be < 100%");
                assertTrue(address(ICToken(m4[i]).underlying()) != address(0), "expected ERC20 market");
            }
        }
        // tFLR market: borrow open but cash == 0 -> nothing to take
        assertEq(ICToken(0x02350987093a804556d65be52063E85eaF80C806).getCash(), 0, "tFLR cash must be 0");
    }

    // ---------------------------------------------------------------- 8

    /// Oracle has no owner-pushed overrides; sFLR/flrETH prices equal FTSO x on-chain rate leg.
    function test_8_oracle_no_overrides_and_rate_legs() public {
        _checkPoolLeg(O2, kSFLR, sFLR, sNative, "sFLR");
        _checkPoolLeg(O2, 0x40eE5dfe1D4a957cA8AC4DD4ADaf8A8fA76b1C16, flrETH, sETH, "flrETH");
    }

    function _checkPoolLeg(
        address orc_,
        address mkt,
        address underlying,
        address rateWrapper,
        string memory label
    ) internal {
        IOracle orc = IOracle(orc_);
        assertEq(orc.assetPrices(underlying), 0, "owner price override present");
        (address asset, bytes21 fid, uint64 stale, address exAsset) = orc.tokenConfigs(underlying);
        assertEq(asset, underlying);
        assertEq(stale, 420);
        assertEq(exAsset, rateWrapper);
        assertFalse(fid == bytes21(0), "no feed configured");
        uint256 rate = IExchangeable(rateWrapper).getExchangeRate();
        uint256 price = orc.getUnderlyingPrice(mkt);
        console2.log(label, "rate", rate);
        console2.log(label, "oraclePrice", price);
        // recompute from the live FTSO feed configured on the oracle
        (uint256 fp, int8 fd, ) = IFtsoV2(FTSO_V2).getFeedById(fid);
        uint256 norm = fp * (10 ** uint256(int256(18) - int256(fd)));
        uint256 expected = (norm * rate) / 1e18;
        console2.log(label, "expected", expected);
        assertApproxEqRel(expected, price, 1e15); // 0.1%
    }

    // ---------------------------------------------------------------- 9

    /// Direct FLR donation to StakedFlr does NOT move the rate (rate is storage-based).
    function test_9_sflr_rate_not_donation_manipulable() public {
        uint256 before = IExchangeable(sNative).getExchangeRate();
        vm.deal(address(this), 10_000 ether);
        (bool ok, ) = sFLR.call{value: 10_000 ether}("");
        assertTrue(ok, "plain transfer must succeed");
        uint256 after_ = IExchangeable(sNative).getExchangeRate();
        console2.log("sFLR rate before:", before);
        console2.log("sFLR rate after :", after_);
        assertApproxEqAbs(before, after_, 5, "rate must not move on plain transfer");
    }
}
