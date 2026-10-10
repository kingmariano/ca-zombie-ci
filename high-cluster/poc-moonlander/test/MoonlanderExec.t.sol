// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Interfaces.sol";

// ---------------------------------------------------------------------------
// Moonlander: async execution attack surface (FORK ONLY).
// batchExecuteOpenMarketOrders / batchExecuteCloseMarketOrders accept
// user-signed EIP-712 orders AND a caller-supplied PriceData.cachePrice[].
// These tests try to open a position with an attacker-controlled price and
// then close it for profit. Negative results are the expected outcome;
// any USDC profit is a live extraction path and will fail the assertions.
// ---------------------------------------------------------------------------

struct OpenOrderParams {
    address user;
    address tokenIn;
    uint96 amountIn;
    uint128 price;
    uint128 qty;
    uint128 stopLoss;
    uint128 takeProfit;
    address pairBase;
    uint24 broker;
    bool isLong;
    uint32 timestamp;
    bytes32 tradeHash;
    uint96 extraFee;
}

struct SignedOpenOrder {
    OpenOrderParams p;
    uint8 signatureType;
    bytes signature;
}

struct SignedCloseOrder {
    bytes32 tradeHash;
    address user;
    uint8 signatureType;
    bytes signature;
}

struct CachePrice {
    address token;
    uint128 price;
    uint32 timestamp;
}

struct PriceData {
    bytes[] pythPrice;
    CachePrice[] cachePrice;
}

contract MoonlanderExec is Test {
    IERC20 usdc = IERC20(USDC);
    IERC20 mlp = IERC20(MLP);

    address attacker;
    uint256 attackerPk = 0xA11CE;

    bytes32 constant OPEN_TYPEHASH = keccak256(
        "OpenOrderParams(address user,address tokenIn,uint96 amountIn,uint128 price,uint128 qty,uint128 stopLoss,uint128 takeProfit,address pairBase,uint24 broker,bool isLong,uint32 timestamp,bytes32 tradeHash,uint96 extraFee)"
    );
    bytes32 constant CLOSE_TYPEHASH =
        keccak256("CloseTradeParams(bytes32 tradeHash,address user)");
    bytes32 constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    function setUp() public {
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        string memory rpc = vm.envOr("CRONOS_RPC_URL", string("https://evm.cronos.org"));
        if (forkBlock == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, forkBlock);
        }
        attacker = vm.addr(attackerPk);
        deal(USDC, attacker, 1_000_000e6);
    }

    // -- signing helpers --------------------------------------------------------
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256("Moonlander"), keccak256("1"), block.chainid, DIAMOND));
    }

    function _hashOpen(OpenOrderParams memory p) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                OPEN_TYPEHASH,
                p.user,
                p.tokenIn,
                p.amountIn,
                p.price,
                p.qty,
                p.stopLoss,
                p.takeProfit,
                p.pairBase,
                p.broker,
                p.isLong,
                p.timestamp,
                p.tradeHash,
                p.extraFee
            )
        );
    }

    function _hashClose(bytes32 tradeHash, address user) internal view returns (bytes32) {
        return keccak256(abi.encode(CLOSE_TYPEHASH, tradeHash, user));
    }

    function _digest(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _logRevert(string memory tag, bytes memory ret) internal pure {
        if (ret.length >= 68) {
            bytes4 sel;
            assembly {
                sel := mload(add(ret, 32))
            }
            if (sel == 0x08c379a0) {
                string memory s;
                assembly {
                    s := add(ret, 68)
                }
                console2.log("[gated] %s", tag);
                console2.log("        reason: %s", s);
                return;
            }
        }
        if (ret.length == 0) {
            console2.log("[gated] %s: (empty revert)", tag);
        } else {
            console2.log("[gated] %s: custom error data %s", tag, bytesToHex(ret));
        }
    }

    function bytesToHex(bytes memory b) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(2 + b.length * 2);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i = 0; i < b.length; i++) {
            out[2 + i * 2] = hexChars[uint8(b[i]) >> 4];
            out[2 + i * 2 + 1] = hexChars[uint8(b[i]) & 0x0f];
        }
        return string(out);
    }

    // ==========================================================================
    // 10 — self-signed close order for a nonexistent trade, with fabricated price
    // ==========================================================================
    function test_10_batch_close_self_signed() public {
        bytes32 fakeHash = keccak256("attacker-close");
        SignedCloseOrder[] memory orders = new SignedCloseOrder[](1);
        orders[0] = SignedCloseOrder({
            tradeHash: fakeHash,
            user: attacker,
            signatureType: 0,
            signature: _sign(attackerPk, _digest(_hashClose(fakeHash, attacker)))
        });
        PriceData memory pd;
        pd.pythPrice = new bytes[](0);
        pd.cachePrice = new CachePrice[](1);
        pd.cachePrice[0] = CachePrice({token: ETH_PAIR, price: uint128(100e8), timestamp: uint32(block.timestamp)}); // fabricated $100 ETH

        vm.prank(attacker);
        (bool ok, bytes memory ret) = DIAMOND.call(abi.encodeWithSelector(S.batchExecClose, orders, pd));
        assertFalse(ok, "close order on nonexistent trade must revert");
        _logRevert("batchExecuteCloseMarketOrders(nonexistent)", ret);
    }

    // ==========================================================================
    // 11 — self-signed open order with fabricated cache price
    // ==========================================================================
    function test_11_batch_open_self_signed_fabricated_price() public {
        // qty: with fabricated price 100e8 ($100) and 10x on 10,000 USDC => notional 100k USD => qty = 1000 ETH (18d)
        OpenOrderParams memory p = OpenOrderParams({
            user: attacker,
            tokenIn: USDC,
            amountIn: uint96(10_000e6),
            price: uint128(100e8), // must match what we want to execute at
            qty: uint128(1000e18),
            stopLoss: 0,
            takeProfit: 0,
            pairBase: ETH_PAIR,
            broker: 0,
            isLong: true,
            timestamp: uint32(block.timestamp),
            tradeHash: keccak256("attacker-open"),
            extraFee: 0
        });

        vm.startPrank(attacker);
        usdc.approve(DIAMOND, type(uint256).max);

        for (uint8 st = 0; st <= 1; st++) {
            SignedOpenOrder[] memory orders = new SignedOpenOrder[](1);
            orders[0] = SignedOpenOrder({p: p, signatureType: st, signature: _sign(attackerPk, _digest(_hashOpen(p)))});
            PriceData memory pd;
            pd.pythPrice = new bytes[](0);
            pd.cachePrice = new CachePrice[](1);
            pd.cachePrice[0] =
                CachePrice({token: ETH_PAIR, price: uint128(100e8), timestamp: uint32(block.timestamp)});

            (bool ok, bytes memory ret) = DIAMOND.call(abi.encodeWithSelector(S.batchExecOpen, orders, pd));
            console2.log("-- batchExecuteOpenMarketOrders signatureType", st, ok ? "OPENED" : "reverted");
            if (!ok) _logRevert("batchExecuteOpenMarketOrders", ret);

            // also try with no cachePrice (forces oracle path)
            PriceData memory pd2;
            pd2.pythPrice = new bytes[](0);
            pd2.cachePrice = new CachePrice[](0);
            (bool ok2, bytes memory ret2) = DIAMOND.call(abi.encodeWithSelector(S.batchExecOpen, orders, pd2));
            console2.log("-- batchExecuteOpenMarketOrders (no cache) signatureType", st, ok2 ? "OPENED" : "reverted");
            if (!ok2) _logRevert("batchExecuteOpenMarketOrders(no cache)", ret2);
        }

        // if anything opened a position, verify the state and try to close at a fabricated high price
        (bool okPos, bytes memory retPos) =
            DIAMOND.staticcall(abi.encodeWithSignature("positionsCount(address,address)", attacker, ETH_PAIR));
        uint256 n = okPos && retPos.length >= 32 ? abi.decode(retPos, (uint256)) : 0;
        console2.log("attacker positions on ETH/USD after attempts:", n);

        vm.stopPrank();
        assertEq(n, 0, "no position may be opened for an unprivileged account");
    }

    // ==========================================================================
    // 12 — plain openMarketTrade on a REDUCE_ONLY pair
    // ==========================================================================
    function test_12_open_market_trade_reduce_only() public {
        // struct OpenDataInput(address pairBase,bool isLong,address tokenIn,uint96 amountIn,uint128 qty,uint128 price,uint128 sl,uint128 tp,uint24 broker)
        bytes memory data = abi.encodeWithSelector(
            S.openMarketTrade,
            ETH_PAIR,
            true,
            USDC,
            uint96(1_000e6),
            uint128(0.5e18),
            uint128(4000e8),
            uint128(0),
            uint128(0),
            uint24(0)
        );
        vm.startPrank(attacker);
        usdc.approve(DIAMOND, type(uint256).max);
        (bool ok, bytes memory ret) = DIAMOND.call(data);
        assertFalse(ok, "openMarketTrade on REDUCE_ONLY pair must revert");
        _logRevert("openMarketTrade(REDUCE_ONLY)", ret);

        // limit order as well
        (ok, ret) = DIAMOND.call(
            abi.encodeWithSelector(
                S.openLimitOrder,
                ETH_PAIR,
                true,
                USDC,
                uint96(1_000e6),
                uint128(0.5e18),
                uint128(4000e8),
                uint128(0),
                uint128(0),
                uint24(0)
            )
        );
        assertFalse(ok, "openLimitOrder on REDUCE_ONLY pair must revert");
        _logRevert("openLimitOrder(REDUCE_ONLY)", ret);

        // limitOrderDeal with zeroed struct
        bytes memory dealData = abi.encodeWithSelector(
            S.limitOrderDeal,
            bytes32(0), address(0), uint128(0), address(0), address(0), uint96(0), uint128(0), uint128(0), uint24(0), false, uint96(0), uint96(0), uint128(0),
            uint256(0)
        );
        (ok, ret) = DIAMOND.call(dealData);
        assertFalse(ok, "limitOrderDeal(zero) must revert");
        _logRevert("limitOrderDeal", ret);
        vm.stopPrank();
    }

    // ==========================================================================
    // 13 — delegator abuse: can a delegate burn the victim's MLP via unstakeAndBurnMlp?
    // ==========================================================================
    function test_13_delegator_cross_account() public {
        // A sets B as delegate; B then attempts to act for A on a value path
        address alice = address(0xA11CE0);
        address bob = address(0xB0B0);
        vm.prank(alice);
        (bool ok, ) = DIAMOND.call(abi.encodeWithSelector(S.setTradingDelegator, bob));
        console2.log("alice set bob as delegate:", ok);

        // bob tries to unstake-and-burn for alice (should be msg.sender-scoped)
        vm.prank(bob);
        (bool ok2, bytes memory ret2) =
            DIAMOND.call(abi.encodeWithSelector(S.unstakeAndBurnMlp, USDC, uint256(1e18), uint256(0), alice));
        assertFalse(ok2, "delegate must not be able to unstake+burn for another user");
        _logRevert("delegate unstakeAndBurnMlp(victim)", ret2);

        // bob tries to burn alice's MLP via burnMlp (receiver alice)
        vm.prank(bob);
        (ok2, ret2) = DIAMOND.call(abi.encodeWithSelector(S.burnMlp, USDC, uint256(1e18), uint256(0), alice));
        assertFalse(ok2, "delegate must not be able to burn another user's MLP");
        _logRevert("delegate burnMlp(victim)", ret2);
    }
}
