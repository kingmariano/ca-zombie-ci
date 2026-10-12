// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IPoolView {
    function getPoolValue(bool _max) external view returns (uint256);
    function virtualPoolValue() external view returns (uint256);
    function lpToken() external view returns (address);
    function feeReserves(address) external view returns (uint256);
    function poolTokens(address) external view returns (uint256, uint256, uint256, uint256);
    function trancheAssets(address, address) external view returns (uint256, uint256, uint256, uint256);
    function isLiquidityProvider(address) external view returns (bool);
    function isListed(address) external view returns (bool);
    function owner() external view returns (address);
    function maxLiquidationGasPrice() external view returns (uint256);
    function positions(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function getPositionKey(address, address, address, uint8) external pure returns (bytes32);
}

interface IOMView {
    function nextOrderId() external view returns (uint256);
    function orders(uint256) external view returns (address, address, address, address, address, uint256, uint256, uint256, uint256, bool);
    function requests(uint256) external view returns (uint8, uint256, uint256, uint8);
    function executor() external view returns (address);
    function minPerpetualExecutionFee() external view returns (uint256);
    function isReporter(address) external view returns (bool);
}

interface IOracleView {
    function getPrice(address, bool) external view returns (uint256);
    function lastAnswerTimestamp(address) external view returns (uint256);
    function isReporter(address) external view returns (bool);
}

/// @title Swych Perpetual (BSC) — fork verification of unprivileged extraction surface.
/// @notice Read-only against mainnet state via fork; no mainnet transactions are ever sent.
contract SwychForkTest is Test {
    address constant POOL   = 0xF86f70fb4959a9FCF1e7dD67A05dC0AC95c3802d;
    address constant OM     = 0x092D00a4965A6336c9C52BDf522b012C2DD42DCe;
    address constant PR     = 0x1CB9992c13Ac8de4d14661e7d05b3DB178b70dC5;
    address constant PR2    = 0x161BddB95C079AE14F6EE85A246E106D1a00143d;
    address constant FD     = 0x7c57c2F579175570E23CCc8C3C26723beD50D6b1;
    address constant ORACLE = 0xe4460109425EbC1CE34cAd59Ab7ce60535956BF5;
    address constant LPTOK  = 0x03F9B914f605d732dd7d5B57e6B494be8d44b28A; // "Tranche One" TR1
    address constant LPH    = 0x9A6A5Aed7e4F4454AA89517AFdbBaE9EAD0FA59a; // 100% TR1 holder (EOA, whitelisted LP)
    address constant FDEST  = 0x9baE46B159f0ce7eF40b6F3a932DFF3d5B01d3F5; // FeeDistributor recipient
    address constant KEEPER = 0x75cE0c34DB3B81c661ce9E4b77533E09245A0497; // PriceReporter reporter EOA
    address constant ORDER429_OWNER = 0xa6D6783E521513c829EE60eeD3Df33236f4A573f;
    address constant ATT    = 0x000000000000000000000000000000000000dEaD; // external unprivileged attacker

    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant SOL  = 0x570A5D26f7765Ecb712C0924E4De545B89fD43dF;
    address constant ETHPSEUDO = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", vm.envOr("FORK_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        forkBlock = block.number;
        vm.deal(ATT, 100 ether);
        vm.deal(KEEPER, 100 ether);
        console2.log("=== Swych fork ===");
        console2.log("fork block:", forkBlock);
    }

    // ---------- helpers ----------
    function _callAs(address who, address to, bytes memory data) internal returns (bool ok, bytes memory ret) {
        vm.prank(who);
        (ok, ret) = to.call(data);
    }

    function _reason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return ret.length == 0 ? "(empty)" : "(non-string revert)";
        bytes4 sel;
        assembly { sel := mload(add(ret, 0x20)) }
        if (sel == 0x08c379a0) {
            assembly {
                ret := add(ret, 0x04)
            }
            return abi.decode(ret, (string));
        }
        return "(custom/other)";
    }

    function _logResult(string memory name, bool ok, bytes memory ret) internal view {
        if (ok) {
            console2.log(string.concat("[OK]      ", name));
        } else {
            console2.log(string.concat("[REVERT]  ", name, " :: ", _reason(ret)));
        }
    }

    function _feeReserves(address token) internal view returns (uint256) {
        return IPoolView(POOL).feeReserves(token);
    }

    // =========================================================
    // T1 — direct Pool / Oracle / OrderManager gates
    // =========================================================
    function test_T1_direct_gates() public {
        bool ok; bytes memory ret;
        // ------- Pool -------
        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("addLiquidity(address,uint256,uint256,address)", USDT, 1e18, 0, ATT));
        _logResult("pool.addLiquidity (ATT)", ok, ret);
        require(!ok, "addLiquidity must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("removeLiquidity(address,uint256,uint256,address)", USDT, 1, 0, ATT));
        _logResult("pool.removeLiquidity (ATT)", ok, ret);
        require(!ok, "removeLiquidity must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("swap(address,address,uint256,address,bytes)", USDT, WBNB, 0, ATT, ""));
        _logResult("pool.swap (ATT)", ok, ret);
        require(!ok, "swap must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("withdrawFee(address,address)", USDT, ATT));
        _logResult("pool.withdrawFee (ATT)", ok, ret);
        require(!ok, "withdrawFee must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("distributeSurplus()"));
        _logResult("pool.distributeSurplus (ATT)", ok, ret);
        require(!ok, "distributeSurplus must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("increasePosition(address,address,address,uint256,uint8)", ATT, WBNB, WBNB, 1e18, 0));
        _logResult("pool.increasePosition (ATT)", ok, ret);
        require(!ok, "increasePosition must be gated");

        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("decreasePosition(address,address,address,uint256,uint256,uint8,address)", ATT, WBNB, WBNB, 0, 0, 0, ATT));
        _logResult("pool.decreasePosition (ATT)", ok, ret);
        require(!ok, "decreasePosition must be gated");

        vm.txGasPrice(1 gwei);
        (ok, ret) = _callAs(ATT, POOL, abi.encodeWithSignature("liquidatePosition(address,address,address,uint8,address)", ATT, WBNB, WBNB, 0, ATT));
        _logResult("pool.liquidatePosition (ATT, 1 gwei)", ok, ret);
        require(!ok, "liquidatePosition must be gated");
        vm.txGasPrice(0);

        // ------- Oracle -------
        (ok, ret) = _callAs(ATT, ORACLE, abi.encodeWithSignature("postPrices(address[],uint256[])", new address[](0), new uint256[](0)));
        _logResult("oracle.postPrices (ATT)", ok, ret);
        require(!ok, "oracle.postPrices must be gated");

        (ok, ret) = _callAs(ATT, ORACLE, abi.encodeWithSignature("addReporter(address)", ATT));
        _logResult("oracle.addReporter (ATT)", ok, ret);
        require(!ok, "oracle.addReporter must be gated");

        // ------- OrderManager -------
        (ok, ret) = _callAs(ATT, OM, abi.encodeWithSignature("executeOrder(uint256,address)", uint256(429), ATT));
        _logResult("om.executeOrder(429) (ATT)", ok, ret);
        require(!ok, "om.executeOrder must be gated (onlyExecutor)");

        (ok, ret) = _callAs(ATT, OM, abi.encodeWithSignature("cancelOrder(uint256)", uint256(429)));
        _logResult("om.cancelOrder(429) (ATT)", ok, ret);
        require(!ok, "cancelOrder of someone else's order must be gated");

        (ok, ret) = _callAs(ATT, OM, abi.encodeWithSignature("setOracle(address)", ATT));
        _logResult("om.setOracle (ATT)", ok, ret);
        require(!ok, "om.setOracle must be gated");
    }

    // =========================================================
    // T2 — PriceReporter (executor wrapper) semantics
    // =========================================================
    function test_T2_priceReporter() public {
        bool ok; bytes memory ret;
        console2.log("PR code size:", PR.code.length, " PR2 code size:", PR2.code.length);
        console2.log("om.executor:", IOMView(OM).executor());

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("postPrices(address[],uint256[])", new address[](0), new uint256[](0)));
        _logResult("PR.postPrices (ATT)", ok, ret);

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("postPriceAndExecuteOrders(address[],uint256[],uint256[])", new address[](0), new uint256[](0), new uint256[](0)));
        _logResult("PR.postPriceAndExecuteOrders (ATT)", ok, ret);

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("executeOrder(uint256,address)", uint256(429), ATT));
        _logResult("PR.executeOrder(429) (ATT)", ok, ret);

        // same call as a whitelisted reporter (to separate 'reporter gate' from other failure)
        (ok, ret) = _callAs(KEEPER, PR, abi.encodeWithSignature("executeOrder(uint256,address)", uint256(429), KEEPER));
        _logResult("PR.executeOrder(429) (KEEPER)", ok, ret);

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("executeSwapOrder(uint256,address)", uint256(1), ATT));
        _logResult("PR.executeSwapOrder(1) (ATT)", ok, ret);

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("executeSwapOrders(uint256[])", new uint256[](0)));
        _logResult("PR.executeSwapOrders([]) (ATT)", ok, ret);

        (ok, ret) = _callAs(ATT, PR, abi.encodeWithSignature("addReporter(address)", ATT));
        _logResult("PR.addReporter (ATT)", ok, ret);
        require(!ok, "addReporter must be gated");

        // pending order 429 is positionless: log owner-position size for the record
        bytes32 key = IPoolView(POOL).getPositionKey(ORDER429_OWNER, WBNB, WBNB, 0);
        (uint256 sz,, , , , ) = IPoolView(POOL).positions(key);
        console2.log("order429 owner position size (1e30):", sz);
    }

    // =========================================================
    // T3 — if PR.executeOrder were permissionless: round-trip via orders
    // =========================================================
    function test_T3_roundtrip_if_executor_open() public {
        // Give ATT 2 WBNB and try a full market long round trip through OM+PR.
        deal(WBNB, ATT, 2 ether);
        vm.prank(ATT);
        IERC20(WBNB).approve(OM, type(uint256).max);

        uint256 wbnbBefore = IERC20(WBNB).balanceOf(ATT);
        uint256 ethBefore = ATT.balance;
        uint256 nextId = IOMView(OM).nextOrderId();

        // place market INCREASE LONG WBNB collateral WBNB, ~1.5x notional of 1 WBNB
        bytes memory data = abi.encode(uint256(0), WBNB, uint256(1 ether), uint256(900e30), uint256(1 ether), bytes(""));
        vm.prank(ATT);
        (bool okP, ) = OM.call{value: 0.01 ether}(abi.encodeWithSignature("placeOrder(uint8,uint8,address,address,uint8,bytes)", uint8(0), uint8(0), WBNB, WBNB, uint8(0), data));
        console2.log("placeOrder(INCREASE) ok:", okP, "orderId:", nextId);

        (bool okE, bytes memory retE) = _callAs(ATT, PR, abi.encodeWithSignature("executeOrder(uint256,address)", nextId, ATT));
        _logResult("execute increase via PR (ATT)", okE, retE);

        if (okE) {
            // close it with a market decrease
            uint256 nextId2 = IOMView(OM).nextOrderId();
            bytes memory ddata = abi.encode(uint256(0), WBNB, type(uint256).max, type(uint256).max, bytes(""));
            vm.prank(ATT);
            (bool okP2, ) = OM.call{value: 0.01 ether}(abi.encodeWithSignature("placeOrder(uint8,uint8,address,address,uint8,bytes)", uint8(1), uint8(0), WBNB, WBNB, uint8(0), ddata));
            console2.log("placeOrder(DECREASE) ok:", okP2, "orderId:", nextId2);
            (bool okE2, bytes memory retE2) = _callAs(ATT, PR, abi.encodeWithSignature("executeOrder(uint256,address)", nextId2, ATT));
            _logResult("execute decrease via PR (ATT)", okE2, retE2);
            console2.log("ATT WBNB before/after:", wbnbBefore, IERC20(WBNB).balanceOf(ATT));
            console2.log("ATT ETH before/after:", ethBefore, ATT.balance);
        } else {
            console2.log("executor path CLOSED for ATT - no round trip possible");
        }
    }

    // =========================================================
    // T4 — FeeDistributor: can an unprivileged caller move value to themselves?
    // =========================================================
    function test_T4_feeDistributor() public {
        console2.log("== FeeDistributor ==");
        console2.log("pool feeReserves WETH:", _feeReserves(WETH));
        console2.log("pool feeReserves WBNB:", _feeReserves(WBNB));
        console2.log("pool feeReserves BTCB:", _feeReserves(BTCB));
        console2.log("FD WETH:", IERC20(WETH).balanceOf(FD), " FDEST WETH:", IERC20(WETH).balanceOf(FDEST));
        console2.log("FD WBNB:", IERC20(WBNB).balanceOf(FD), " FDEST WBNB:", IERC20(WBNB).balanceOf(FDEST));

        uint256 attWeth = IERC20(WETH).balanceOf(ATT);
        uint256 attWbnb = IERC20(WBNB).balanceOf(ATT);
        uint256 fdWeth = IERC20(WETH).balanceOf(FD);
        uint256 destWeth = IERC20(WETH).balanceOf(FDEST);
        uint256 prWeth = _feeReserves(WETH);

        (bool ok, bytes memory ret) = _callAs(ATT, FD, abi.encodeWithSignature("withdrawFee()"));
        _logResult("FD.withdrawFee() (ATT)", ok, ret);
        if (ok) {
            console2.log("after withdrawFee(): pool feeReserves WETH:", _feeReserves(WETH));
            console2.log("FD WETH delta:", int256(IERC20(WETH).balanceOf(FD)) - int256(fdWeth));
            console2.log("FDEST WETH delta:", int256(IERC20(WETH).balanceOf(FDEST)) - int256(destWeth));
            console2.log("ATT WETH delta:", int256(IERC20(WETH).balanceOf(ATT)) - int256(attWeth));
            console2.log("ATT WBNB delta:", int256(IERC20(WBNB).balanceOf(ATT)) - int256(attWbnb));
            require(IERC20(WETH).balanceOf(ATT) == attWeth, "attacker must gain nothing");
            require(IERC20(WBNB).balanceOf(ATT) == attWbnb, "attacker must gain nothing");
        }

        // distribute() selector 0xb069bec2 — also permissionless-looking
        uint256 a2 = ATT.balance;
        (ok, ret) = _callAs(ATT, FD, abi.encodeWithSelector(0xb069bec2));
        _logResult("FD.distribute() (ATT) [0xb069bec2]", ok, ret);
        console2.log("ATT ETH delta from distribute:", int256(ATT.balance) - int256(a2));

        // owner-only probes
        (ok, ret) = _callAs(ATT, FD, abi.encodeWithSignature("pause()"));
        _logResult("FD.pause() (ATT)", ok, ret);
        require(!ok, "pause must be gated");
        (ok, ret) = _callAs(ATT, FD, abi.encodeWithSignature("setFeeTokens(address[])", new address[](1)));
        _logResult("FD.setFeeTokens (ATT)", ok, ret);
        require(!ok, "setFeeTokens must be gated");
    }

    // =========================================================
    // T5 — accounting / value snapshot at fork block
    // =========================================================
    function test_T5_value_snapshot() public {
        uint256 lpSupply = IERC20(LPTOK).totalSupply();
        uint256 vMax = IPoolView(POOL).getPoolValue(true);
        uint256 vMin = IPoolView(POOL).getPoolValue(false);
        uint256 vMid = (vMax + vMin) / 2;
        console2.log("TR1 totalSupply:", lpSupply);
        console2.log("poolValue max/min/mid (1e30):", vMax, vMin, vMid);
        console2.log("LP price (mid/supply, 1e18):", vMid / (lpSupply / 1e18));
        console2.log("LPH TR1 balance:", IERC20(LPTOK).balanceOf(LPH));
        console2.log("LPH isLiquidityProvider:", IPoolView(POOL).isLiquidityProvider(LPH));
        console2.log("ATT isLiquidityProvider:", IPoolView(POOL).isLiquidityProvider(ATT));
        for (uint256 i = 0; i < 5; i++) {
            address[5] memory toks = [BTCB, WBNB, USDT, WETH, SOL];
            address t = toks[i];
            uint256 bal = IERC20(t).balanceOf(POOL);
            (uint256 maxP, uint256 minP) = (IOracleView(ORACLE).getPrice(t, true), IOracleView(ORACLE).getPrice(t, false));
            (uint256 pa, uint256 ra, uint256 gv, uint256 ss) = IPoolView(POOL).trancheAssets(LPTOK, t);
            console2.log("token", t);
            console2.log("  pool balance:", bal);
            console2.log("  oracle max:", maxP);
            console2.log("  oracle min:", minP);
            console2.log("  tranche poolAmount:", pa);
            console2.log("  tranche reserved:", ra);
            console2.log("  tranche guaranteed:", gv);
            console2.log("  tranche shortSize:", ss);
        }
    }

    // =========================================================
    // TZ — LP holder self-service exit (H-O) and attacker attempt
    // =========================================================
    function test_TZ_lp_holder_exit() public {
        uint256 lpBal = IERC20(LPTOK).balanceOf(LPH);
        uint256 supply = IERC20(LPTOK).totalSupply();
        uint256 vMid = (IPoolView(POOL).getPoolValue(true) + IPoolView(POOL).getPoolValue(false)) / 2;

        // attacker cannot remove liquidity
        (bool okA, bytes memory retA) = _callAs(ATT, POOL, abi.encodeWithSignature("removeLiquidity(address,uint256,uint256,address)", USDT, lpBal, 0, ATT));
        _logResult("attacker removeLiquidity", okA, retA);
        require(!okA, "attacker must not be able to remove LP");

        // LP holder: approve pool then remove part of liquidity as USDT (fork simulation only)
        vm.prank(LPH);
        IERC20(LPTOK).approve(POOL, type(uint256).max);
        uint256 usdtBefore = IERC20(USDT).balanceOf(LPH);
        uint256 burnAmount = lpBal / 10; // 10% for the record (keep fork state usable)
        vm.prank(LPH);
        (bool ok, bytes memory ret) = POOL.call(abi.encodeWithSignature("removeLiquidity(address,uint256,uint256,address)", USDT, burnAmount, 0, LPH));
        _logResult("LPH removeLiquidity 10% as USDT", ok, ret);
        if (ok) {
            uint256 got = IERC20(USDT).balanceOf(LPH) - usdtBefore;
            console2.log("LPH received USDT:", got);
            console2.log("implied full-LP redeemable (mid):", vMid);
        }
        // expected outputs per token for the full balance
        for (uint256 i = 0; i < 5; i++) {
            address[5] memory toks = [BTCB, WBNB, USDT, WETH, SOL];
            address t = toks[i];
            uint256 p = (IOracleView(ORACLE).getPrice(t, true) + IOracleView(ORACLE).getPrice(t, false)) / 2;
            // out = lpAmount * poolValue / totalSupply / tokenPrice
            uint256 outAmt = (lpBal * vMid) / supply / p;
            console2.log("full-exit in", t, "amount:", outAmt);
        }
    }
}
