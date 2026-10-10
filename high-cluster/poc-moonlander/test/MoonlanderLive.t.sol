// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20, S} from "../src/Interfaces.sol";
import * as C from "../src/Interfaces.sol";

// ---------------------------------------------------------------------------
// Moonlander (Cronos) live-state / extraction PoC — FORK ONLY, read-only on
// the real chain. Every call here runs against a local fork of Cronos.
// ---------------------------------------------------------------------------

contract MoonlanderLive is Test {
    IERC20 usdc = IERC20(C.USDC);
    IERC20 mlp = IERC20(C.MLP);

    address attacker;
    uint256 attackerPk = 0xA11CE;

    function forkRpc() internal view returns (string memory) {
        return vm.envOr("CRONOS_RPC_URL", string("https://evm.cronos.org"));
    }

    function setUp() public {
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(forkRpc());
        } else {
            vm.createSelectFork(forkRpc(), forkBlock);
        }
        attacker = vm.addr(attackerPk);
        vm.label(C.DIAMOND, "MoonlanderDiamond");
        vm.label(C.USDC, "USDC");
        vm.label(C.MLP, "MLP");
        vm.label(C.SMLP_TRACKER, "sMLP-Tracker");
        vm.label(C.REWARD_ROUTER, "RewardRouter");
        vm.label(C.MSIG, "MSIG");
    }

    // -- raw call helper that logs the revert reason -----------------------------
    function raw(address to, bytes memory data) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = to.call(data);
    }

    // -- helpers ----------------------------------------------------------------
    function _errString(bytes memory ret) internal pure returns (string memory s) {
        if (ret.length < 68) return "";
        bytes4 sel;
        assembly {
            sel := mload(add(ret, 32))
        }
        if (sel != 0x08c379a0) return "";
        assembly {
            s := add(ret, 68)
        }
    }

    function _logRevert(string memory tag, bytes memory ret) internal {
        bytes4 sel;
        if (ret.length >= 4) {
            assembly {
                sel := mload(add(ret, 32))
            }
        }
        string memory r = _errString(ret);
        if (bytes(r).length > 0) {
            console2.log("[gated] %s: %s", tag, r);
        } else if (ret.length == 0) {
            console2.log("[gated] %s: (empty revert)", tag);
        } else {
            console2.log("[gated] %s: custom error %s", tag, vm.toString(bytes32(sel)));
        }
    }

    // ==========================================================================
    // 00 — live state
    // ==========================================================================
    function test_00_live_state() public {
        uint256 diamondUsdc = usdc.balanceOf(C.DIAMOND);
        uint256 supply = mlp.totalSupply();
        uint256 trackerMlp = mlp.balanceOf(C.SMLP_TRACKER);
        console2.log("block", block.number);
        console2.log("diamond USDC (6d):", diamondUsdc);
        console2.log("MLP totalSupply (18d):", supply);
        console2.log("sMLP tracker MLP:", trackerMlp);
        assertGt(diamondUsdc, 15_000_000e6, "diamond must hold >15M USDC");
        assertGt(trackerMlp, 16_000_000e18, "tracker holds ~all MLP");

        // paused / signer / config
        (bool ok, bytes memory ret) = raw(C.DIAMOND, abi.encodeWithSignature("paused()"));
        assertTrue(ok && ret.length >= 32, "paused()");
        console2.log("paused:", uint256(32) <= ret.length ? abi.decode(ret, (bool)) : false);
    }

    // ==========================================================================
    // 01 — admin / initializer gates (classic diamond bugs)
    // ==========================================================================
    function test_01_admin_gates() public {
        address dead = address(0xdEaD);
        vm.startPrank(attacker);

        (bool ok, bytes memory ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.diamondCut, _emptyCut(), address(0), new bytes(0)));
        assertFalse(ok, "diamondCut must revert");
        _logRevert("diamondCut", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.initMlpManager, C.MLP, C.SIGNER));
        assertFalse(ok, "initMlpManagerFacet must revert");
        _logRevert("initMlpManagerFacet", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.initBrokerManager, uint24(1), C.USDC, "x", "y"));
        assertFalse(ok, "initBrokerManagerFacet must revert");
        _logRevert("initBrokerManagerFacet", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.initFeeManager, C.MSIG, C.MSIG));
        assertFalse(ok, "initFeeManagerFacet must revert");
        _logRevert("initFeeManagerFacet", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.initTradingConfig, uint256(1e15), uint256(1e18), uint24(1000), uint256(1)));
        assertFalse(ok, "initTradingConfigFacet must revert");
        _logRevert("initTradingConfigFacet", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.setPythOracle, dead));
        assertFalse(ok, "setPythOracle must revert");
        _logRevert("setPythOracle", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.addPythConfig, C.USDC, bytes32(uint256(1))));
        assertFalse(ok, "addPythConfig must revert");
        _logRevert("addPythConfig", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.removePythConfig, C.USDC));
        assertFalse(ok, "removePythConfig must revert");
        _logRevert("removePythConfig", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.setSigner, dead));
        assertFalse(ok, "setSigner must revert");
        _logRevert("setSigner", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.setRewardRouter, dead));
        assertFalse(ok, "setRewardRouter must revert");
        _logRevert("setRewardRouter", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.setCoolingDuration, uint256(1)));
        assertFalse(ok, "setCoolingDuration must revert");
        _logRevert("setCoolingDuration", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.batchReqPriceCbV1, _emptyCb1()));
        assertFalse(ok, "batchRequestPriceCallback V1 must revert");
        _logRevert("batchRequestPriceCallback(v1)", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.batchReqPriceCbV2, _emptyCb2(), new bytes[](0)));
        assertFalse(ok, "batchRequestPriceCallback V2 must revert");
        _logRevert("batchRequestPriceCallback(v2)", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.executeLimitOrder, _emptyExec(), new bytes[](0)));
        assertFalse(ok, "executeLimitOrder must revert");
        _logRevert("executeLimitOrder", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.executeLimitOrderV2, _emptyExecV2(), new bytes[](0)));
        assertFalse(ok, "executeLimitOrderV2 must revert");
        _logRevert("executeLimitOrderV2", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.withdrawCommission, uint24(1)));
        // Not a role-gated function: pays a broker's pending commission to the broker's
        // registered receiver (push). Assert the attacker gains nothing either way.
        {
            uint256 attBefore = usdc.balanceOf(attacker);
            // call again (the first call above already ran)
            (bool ok2, bytes memory ret2) = raw(C.DIAMOND, abi.encodeWithSelector(S.withdrawCommission, uint24(1)));
            if (ok2) {
                console2.log("[open-push] withdrawCommission(1) callable; attacker delta:", usdc.balanceOf(attacker) - attBefore);
            } else {
                _logRevert("withdrawCommission", ret2);
            }
            assertEq(usdc.balanceOf(attacker), attBefore, "attacker must gain nothing");
        }

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.queueTransaction, "x", new bytes(0)));
        assertFalse(ok, "queueTransaction must revert");
        _logRevert("queueTransaction", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.executeTransaction, uint256(0)));
        assertFalse(ok, "executeTransaction must revert");
        _logRevert("executeTransaction", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.cancelTransaction, uint256(0)));
        assertFalse(ok, "cancelTransaction must revert");
        _logRevert("cancelTransaction", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.settleLpFundingFee, uint256(1)));
        assertFalse(ok, "settleLpFundingFee must revert (onlySelf)");
        _logRevert("settleLpFundingFee", ret);

        vm.stopPrank();
    }

    // ==========================================================================
    // 01b — admin setters with VALID arity/values still revert (gate ≠ validation)
    // ==========================================================================
    function test_01b_admin_gates_valid_arity() public {
        address dead = address(0xdEaD);
        vm.startPrank(attacker);
        _expectRevert("setCoolingDuration(1)", abi.encodeWithSelector(S.setCoolingDuration, uint256(1)));
        _expectRevert(
            "updatePairFundingFeeConfig",
            abi.encodeWithSignature("updatePairFundingFeeConfig(address,uint256,uint256,uint256)", C.ETH_PAIR, uint256(1), uint256(1), uint256(1))
        );
        _expectRevert(
            "updatePairMaxOi",
            abi.encodeWithSignature("updatePairMaxOi(address,uint256,uint256)", C.ETH_PAIR, uint256(1), uint256(1))
        );
        _expectRevert("setExecutionFeeUsd(1)", abi.encodeWithSignature("setExecutionFeeUsd(uint256)", uint256(1)));
        _expectRevert("setMinBetUsd(1)", abi.encodeWithSignature("setMinBetUsd(uint256)", uint256(1)));
        _expectRevert("setMinNotionalUsd(1)", abi.encodeWithSignature("setMinNotionalUsd(uint256)", uint256(1)));
        _expectRevert("updatePairFee", abi.encodeWithSignature("updatePairFee(address,uint16)", C.ETH_PAIR, uint16(0)));
        _expectRevert("updatePairSlippage", abi.encodeWithSignature("updatePairSlippage(address,uint16)", C.ETH_PAIR, uint16(0)));
        _expectRevert(
            "updatePairHoldingFeeRate",
            abi.encodeWithSignature("updatePairHoldingFeeRate(address,uint40,uint40)", C.ETH_PAIR, uint40(0), uint40(0))
        );
        _expectRevert("removePair", abi.encodeWithSignature("removePair(address)", C.ETH_PAIR));
        _expectRevert("updatePairStatus", abi.encodeWithSignature("updatePairStatus(address,uint8)", C.ETH_PAIR, uint8(0)));
        _expectRevert("setExecutionFeeReceiver", abi.encodeWithSignature("setExecutionFeeReceiver(address)", dead));
        _expectRevert("setMaxTakeProfitP(1)", abi.encodeWithSignature("setMaxTakeProfitP(uint24)", uint24(1)));
        _expectRevert(
            "updateToken(USDC)",
            abi.encodeWithSignature("updateToken(address,uint16,uint16,bool)", C.USDC, uint16(25), uint16(5), true)
        );
        _expectRevert(
            "updateTokenFeature(USDC)",
            abi.encodeWithSignature("updateTokenFeature(address,bool,bool)", C.USDC, true, true)
        );
        // unnamed PairsManager selector — unconditional revert observed live and from msig prank
        _expectRevert("0x83b830b5(ETH_PAIR)", abi.encodeWithSelector(bytes4(0x83b830b5), C.ETH_PAIR));
        vm.stopPrank();
    }

    function _expectRevert(string memory tag, bytes memory data) internal {
        (bool ok, bytes memory ret) = raw(C.DIAMOND, data);
        assertFalse(ok, string.concat("must revert: ", tag));
        _logRevert(tag, ret);
    }

    // ==========================================================================
    // 02 — MLP mint / burn round trip (economics, cooling, fees)
    // ==========================================================================
    function test_02_mlp_roundtrip() public {
        deal(C.USDC, attacker, 100_000e6);
        uint256 priceBefore = _mlpPrice();
        console2.log("mlpPrice before:", priceBefore);

        vm.startPrank(attacker);
        usdc.approve(C.DIAMOND, type(uint256).max);
        (bool ok, bytes memory ret) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.mintMlp, C.USDC, uint256(10_000e6), uint256(0), false));
        if (!ok) {
            console2.log("[blocked] mintMlp reverted");
            _logRevert("mintMlp", ret);
            vm.stopPrank();
            return;
        }
        uint256 mlpGot = mlp.balanceOf(attacker);
        console2.log("minted MLP for 10,000 USDC:", mlpGot);
        assertGt(mlpGot, 0, "mint must produce shares");

        // direct burn inside cooling window must revert
        (bool ok2, bytes memory ret2) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.burnMlp, C.USDC, mlpGot, uint256(0), attacker));
        assertFalse(ok2, "burn within cooling window must revert");
        _logRevert("burnMlp (cooling window)", ret2);

        // warp past cooling (86400s) then burn everything
        vm.warp(block.timestamp + 86401);
        uint256 usdcBefore = usdc.balanceOf(attacker);
        (bool ok3, bytes memory ret3) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.burnMlp, C.USDC, mlpGot, uint256(0), attacker));
        if (!ok3) {
            console2.log("[blocked] burnMlp reverted after cooling");
            _logRevert("burnMlp", ret3);
            vm.stopPrank();
            return;
        }
        uint256 usdcOut = usdc.balanceOf(attacker) - usdcBefore;
        console2.log("USDC out for full burn:", usdcOut);
        vm.stopPrank();

        // round-trip must not be profitable (fees/tax) — value from live oracle
        assertLe(usdcOut, 10_000e6, "round trip must not print money");
        console2.log("round-trip loss (USDC 6d):", 10_000e6 - usdcOut);
    }

    // ==========================================================================
    // 03 — unstakeAndBurnMlp: no-stake attack + honest path
    // ==========================================================================
    function test_03_unstake_and_burn_mlp() public {
        // (a) attacker with zero stake tries to burn from the tracker
        vm.prank(attacker);
        (bool ok, bytes memory ret) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.unstakeAndBurnMlp, C.USDC, uint256(1_000e18), uint256(0), attacker));
        assertFalse(ok, "unstakeAndBurnMlp with 0 stake must revert");
        _logRevert("unstakeAndBurnMlp(0 stake)", ret);

        // (b) honest path: mint+stake, warp, unstake-and-burn
        deal(C.USDC, attacker, 50_000e6);
        vm.startPrank(attacker);
        usdc.approve(C.DIAMOND, type(uint256).max);
        (bool ok2, bytes memory ret2) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.mintMlp, C.USDC, uint256(5_000e6), uint256(0), true));
        if (!ok2) {
            _logRevert("mintMlp(stake=true)", ret2);
        } else {
            uint256 sMlp = IERC20(C.SMLP_TRACKER).balanceOf(attacker);
            console2.log("accounted sMLP after stake:", sMlp);
            vm.warp(block.timestamp + 86401);
            uint256 before = usdc.balanceOf(attacker);
            (bool ok3, bytes memory ret3) = raw(
                C.DIAMOND,
                abi.encodeWithSelector(S.unstakeAndBurnMlp, C.USDC, sMlp / 2, uint256(0), attacker)
            );
            if (ok3) {
                console2.log("unstakeAndBurnMlp USDC out:", usdc.balanceOf(attacker) - before);
            } else {
                _logRevert("unstakeAndBurnMlp(half)", ret3);
            }
        }
        vm.stopPrank();
    }

    // ==========================================================================
    // 04 — callbacks are onlySelf
    // ==========================================================================
    function test_04_callbacks_only_self() public {
        vm.prank(attacker);
        (bool ok, bytes memory ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.marketTradeCb, bytes32(0), uint256(1), uint256(1)));
        assertFalse(ok, "marketTradeCallback must be onlySelf");
        _logRevert("marketTradeCallback", ret);

        vm.prank(attacker);
        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.closeTradeCb, bytes32(0), uint256(1), uint256(1)));
        assertFalse(ok, "closeTradeCallback must be onlySelf");
        _logRevert("closeTradeCallback", ret);
    }

    // ==========================================================================
    // 05 — withdrawRevenue: recipient check (no attacker profit)
    // ==========================================================================
    function test_05_withdraw_revenue_recipient() public {
        uint256 attackerBefore = usdc.balanceOf(attacker);
        uint256 revenueBefore = usdc.balanceOf(C.REVENUE_ADDRESS);
        vm.prank(attacker);
        (bool ok, bytes memory ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.withdrawRevenue, _usdcArr()));
        if (ok) {
            uint256 aDelta = usdc.balanceOf(attacker) - attackerBefore;
            uint256 rDelta = usdc.balanceOf(C.REVENUE_ADDRESS) - revenueBefore;
            console2.log("withdrawRevenue: attacker delta:", aDelta);
            console2.log("withdrawRevenue: revenueAddress delta:", rDelta);
            assertEq(aDelta, 0, "attacker must gain nothing");
        } else {
            _logRevert("withdrawRevenue", ret);
        }
    }

    // ==========================================================================
    // 06 — setTradingDelegator semantics (self-scoped?)
    // ==========================================================================
    function test_06_trading_delegator_semantics() public {
        address delegatee = address(0xBEEF);
        vm.prank(attacker);
        (bool ok, bytes memory ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.setTradingDelegator, delegatee));
        if (!ok) {
            _logRevert("setTradingDelegator", ret);
            return;
        }
        // getTradingDelegator(address user) returns the user's delegate address (address, not bool)
        vm.prank(attacker);
        (bool ok1, bytes memory r1) = raw(C.DIAMOND, abi.encodeWithSelector(S.getTradingDelegator, delegatee));
        vm.prank(delegatee);
        (bool ok2, bytes memory r2) = raw(C.DIAMOND, abi.encodeWithSelector(S.getTradingDelegator, attacker));
        vm.prank(address(0xCAFE));
        (bool ok3, bytes memory r3) = raw(C.DIAMOND, abi.encodeWithSelector(S.getTradingDelegator, delegatee));
        console2.log("as attacker: delegate of delegatee:", ok1 && r1.length >= 32 ? abi.decode(r1, (address)) : address(0));
        console2.log("as delegatee: delegate of attacker:", ok2 && r2.length >= 32 ? abi.decode(r2, (address)) : address(0));
        console2.log("as third party: delegate of delegatee:", ok3 && r3.length >= 32 ? abi.decode(r3, (address)) : address(0));
        // self-scoped semantics: attacker's delegate is the delegatee; the delegatee has no delegate of its own
        assertTrue(ok2 && r2.length >= 32 && abi.decode(r2, (address)) == delegatee, "delegation must be registered");
        assertTrue(ok3 && r3.length >= 32 && abi.decode(r3, (address)) == address(0), "no cross-account delegation");
    }

    // ==========================================================================
    // 07 — tracker / router gates + MLP token gates
    // ==========================================================================
    function test_07_tracker_and_token_gates() public {
        address dead = address(0xdEaD);
        vm.startPrank(attacker);

        // StakedMlpTracker (UUPS, Ownable)
        (bool ok, bytes memory ret) = raw(C.SMLP_TRACKER, abi.encodeWithSignature("stakeForAccount(address,address,address,uint256)", dead, dead, C.MLP, uint256(1e18)));
        assertFalse(ok, "tracker.stakeForAccount must revert");
        _logRevert("tracker.stakeForAccount", ret);

        (ok, ret) = raw(C.SMLP_TRACKER, abi.encodeWithSignature("claimForAccount(address,address)", dead, dead));
        assertFalse(ok, "tracker.claimForAccount must revert");
        _logRevert("tracker.claimForAccount", ret);

        (ok, ret) = raw(C.SMLP_TRACKER, abi.encodeWithSignature("initialize(string,string,address[])", "x", "y", new address[](0)));
        assertFalse(ok, "tracker.initialize must revert (already initialized)");
        _logRevert("tracker.initialize", ret);

        (ok, ret) = raw(C.SMLP_TRACKER, abi.encodeWithSignature("upgradeTo(address)", dead));
        assertFalse(ok, "tracker.upgradeTo must revert");
        _logRevert("tracker.upgradeTo", ret);

        // MLP token gates
        (ok, ret) = raw(C.MLP, abi.encodeWithSignature("mint(address,uint256)", attacker, uint256(1e18)));
        assertFalse(ok, "MLP.mint must revert");
        _logRevert("MLP.mint", ret);

        (ok, ret) = raw(C.MLP, abi.encodeWithSignature("burnFrom(address,uint256)", dead, uint256(1e18)));
        assertFalse(ok, "MLP.burnFrom must revert");
        _logRevert("MLP.burnFrom", ret);

        (ok, ret) = raw(C.MLP, abi.encodeWithSignature("upgradeTo(address)", dead));
        assertFalse(ok, "MLP.upgradeTo must revert");
        _logRevert("MLP.upgradeTo", ret);

        // RewardRouter handler gate
        (ok, ret) = raw(C.REWARD_ROUTER, abi.encodeWithSelector(S.unstakeAndBurnMlp, C.USDC, uint256(1), uint256(0), attacker));
        // note: 0x062b5143-style handler calls; direct unstakeAndBurnMlp selector on router is not routed — expect revert
        _logRevert("router call", ret);

        vm.stopPrank();
    }

    // ==========================================================================
    // 08 — direct burn/unstake anomalies
    // ==========================================================================
    function test_08_no_stake_attacks() public {
        vm.startPrank(attacker);
        // burn MLP the attacker does not own
        (bool ok, bytes memory ret) =
            raw(C.DIAMOND, abi.encodeWithSelector(S.burnMlp, C.USDC, uint256(1e18), uint256(0), attacker));
        assertFalse(ok, "burnMlp with 0 balance must revert");
        _logRevert("burnMlp(0 balance)", ret);

        // forged mlp signature
        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.mintMlpWithSig, uint256(1e18), uint256(0), false, new bytes(0), new bytes(0)));
        assertFalse(ok, "mintMlpWithSignature(empty sig) must revert");
        _logRevert("mintMlpWithSignature(forged)", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.burnMlpWithSig, uint256(1e18), uint256(0), attacker, new bytes(0), new bytes(0)));
        assertFalse(ok, "burnMlpWithSignature(empty sig) must revert");
        _logRevert("burnMlpWithSignature(forged)", ret);

        // close a trade hash that does not exist
        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.closeTrade, bytes32(uint256(0xdead))));
        assertFalse(ok, "closeTrade(nonexistent) must revert");
        _logRevert("closeTrade(nonexistent)", ret);

        (ok, ret) = raw(C.DIAMOND, abi.encodeWithSelector(S.addMargin, bytes32(uint256(0xdead)), uint256(1)));
        assertFalse(ok, "addMargin(nonexistent) must revert");
        _logRevert("addMargin(nonexistent)", ret);

        vm.stopPrank();
    }

    // ==========================================================================
    // helpers for tuple encodings
    // ==========================================================================
    function _emptyCut() internal pure returns (IDiamondCutFacet.FacetCut[] memory cut) {
        cut = new IDiamondCutFacet.FacetCut[](0);
    }

    function _emptyCb1() internal pure returns (IPriceCallback.Param1[] memory a) {
        a = new IPriceCallback.Param1[](0);
    }

    function _emptyCb2() internal pure returns (IPriceCallback.Param2[] memory a) {
        a = new IPriceCallback.Param2[](0);
    }

    function _emptyExec() internal pure returns (ILimitOrders.KeeperExec[] memory a) {
        a = new ILimitOrders.KeeperExec[](0);
    }

    function _emptyExecV2() internal pure returns (ILimitOrders.KeeperExecV2[] memory a) {
        a = new ILimitOrders.KeeperExecV2[](0);
    }

    function _usdcArr() internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = C.USDC;
    }

    function _mlpPrice() internal view returns (uint256 p) {
        (bool ok, bytes memory ret) = C.DIAMOND.staticcall(abi.encodeWithSelector(S.mlpPrice));
        require(ok, "mlpPrice");
        p = abi.decode(ret, (uint256));
    }
}

interface IDiamondCutFacet {
    struct FacetCut {
        address facetAddress;
        uint8 action;
        bytes4[] functionSelectors;
    }
}

interface IPriceCallback {
    struct Param1 {
        bytes32 id;
        uint128 price;
    }
    struct Param2 {
        bytes32 id;
        bytes32 priceId;
        bool reciprocal;
        uint128 price;
    }
}

interface ILimitOrders {
    // executeLimitOrder((bytes32,bytes32,bool,uint128)[],bytes[])
    struct KeeperExec {
        bytes32 a;
        bytes32 b;
        bool c;
        uint128 d;
    }
    // executeLimitOrderV2((bytes32,uint128,uint32)[],bytes[])
    struct KeeperExecV2 {
        bytes32 a;
        uint128 b;
        uint32 c;
    }
}
