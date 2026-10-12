// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    IERC20, IPair, IFactory, IFarm, ICollecter, INlpLock, INarToken, IThugs
} from "../src/Interfaces.sol";

/// @title Narwhalswap (BSC) zombie deep-dive — fork verification of the E-U surface.
/// Read-only on mainnet: everything runs on a local fork; no transactions are ever sent.
contract NarwhalTest is Test {
    address constant FACTORY   = 0xB9fA84912FF2383a617d8b433E926Adf0Dd3FEa1;
    address constant COLLECTER = 0x7f8a46EC48442d9EBF28fBC1144A83f8BC53F7e9;
    address constant FEE_SETTER= 0xb104AE8b7DA105ca79cbA208b9A41C1D63fff2C5;
    address constant NAR       = 0xA1303E6199b319a891b79685F0537D289af1FC83;
    address constant WBNB      = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant THUGS     = 0xE10e9822A5de22F8761919310DDA35CD997d63c0;
    address constant NARWBNB   = 0xb6B0ba4e208AB93602be7a81f1400a7c7Daad1f2;
    address constant THUGSWBNB = 0x40Ff83ac2890DD5469f5eCa2c17dcAf10ee09957;
    address constant WBNBBUSD  = 0x5EC32C21C9A6215D239F2BD0Df22d7632b4717c3;
    address constant LOCKER    = 0x07f1B50D5ae24eC41aA7269d65a5e23e8401542A;
    address constant FARM_V2_NW= 0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f;
    address constant FARM_V2_WB= 0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B;
    address constant FARM_V1_NW= 0x186bE2A9f0E9c92B880bBd3eC1F35f422F0d8835;
    address constant FARM_V3_NW= 0xBE85812237741D75f81aEBF1D9Af52D544542168;
    address constant DIV_V3_2  = 0xf7a36c87c3A8909949638120f23CD721bF572032;
    address constant RNLP5     = 0x6451571Cb5bEe9Fd575ad98506E96f3d09C66F91;
    address constant BSCSWAP_P = 0x71c1B6302c7F9C49EE3E675224B22CdE34Ab5AC7;
    address constant BURN_SINK = 0x7777777777777777777777777777777777777777;

    // live stakers used for gate tests (public data)
    address constant STAKER_NO_ALLOW = 0x2aefcE802c8Db8c25216140CB672eF8F5B806186; // 233.89 LP staked, allowance 0
    address constant STAKER_ALLOW    = 0x840e20dFb9f8F3dC076865223D6cE7e84ddc8C67; // 63.44 LP staked, max allowance
    address constant STAKER_MAXBUFF   = 0x0567B7665d5633903C558cEEc8Fe7023743333a4; // buffrate 15000 == rule-1 max
    address constant STAKER_OLDTIME   = 0x2aefcE802c8Db8c25216140CB672eF8F5B806186; // timeStamp 2020 -> updateBuffRate OOG

    address constant ATTACKER = address(0xA77ACCE7);

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.label(ATTACKER, "attacker");
    }

    function _getAmountOut(uint256 amountIn, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        uint256 a = amountIn * 997;
        return (a * rOut) / (rIn * 1000 + a);
    }

    function _fundWbnb(uint256 amount) internal {
        vm.deal(ATTACKER, amount);
        vm.prank(ATTACKER);
        IERC20(WBNB).deposit{value: amount}();
    }

    // ------------------------------------------------------------------ factory
    function test_factory_state_and_setFeeTo_gate() public {
        uint256 n = IFactory(FACTORY).allPairsLength();
        emit log_named_uint("allPairsLength", n);
        assertGe(n, 96);
        assertEq(IFactory(FACTORY).feeTo(), COLLECTER, "feeTo == NarwhalCollecter");
        assertEq(IFactory(FACTORY).feeToSetter(), FEE_SETTER, "feeToSetter == team EOA");
        vm.prank(ATTACKER);
        vm.expectRevert("Narwhalswap: FORBIDDEN");
        IFactory(FACTORY).setFeeTo(ATTACKER);
    }

    // ------------------------------------------------------- skim: dust only
    function test_skim_excess_is_dust_only() public {
        uint256 n = IFactory(FACTORY).allPairsLength();
        uint256 excessPositions;
        uint256 totalWbnbExcess;
        for (uint256 i = 0; i < n; i++) {
            address p = IFactory(FACTORY).allPairs(i);
            IPair pair = IPair(p);
            address t0 = pair.token0();
            address t1 = pair.token1();
            if (t0.code.length == 0 || t1.code.length == 0) continue; // dead pair 0x9b7b76fb
            (uint112 r0, uint112 r1,) = pair.getReserves();
            uint256 b0 = IERC20(t0).balanceOf(p);
            uint256 b1 = IERC20(t1).balanceOf(p);
            // V2 pairs are always >= reserve; any positive delta is un-owned dust
            assertGe(b0, r0, "balance0 >= reserve0");
            assertGe(b1, r1, "balance1 >= reserve1");
            if (b0 > r0 || b1 > r1) {
                excessPositions++;
                emit log_named_address("pair with raw excess", p);
                if (t0 == WBNB) totalWbnbExcess += (b0 - r0);
                if (t1 == WBNB) totalWbnbExcess += (b1 - r1);
            }
        }
        emit log_named_uint("excess positions (all 96 pairs)", excessPositions);
        assertLe(excessPositions, 8, "only known dust accrual (fee/rebasing meme tokens)");
        assertEq(totalWbnbExcess, 0, "no WBNB excess anywhere");

        // skim() hands the caller exactly the pre-existing excess and nothing more
        address[3] memory top = [NARWBNB, THUGSWBNB, WBNBBUSD];
        for (uint256 j = 0; j < 3; j++) {
            uint256 before = IERC20(WBNB).balanceOf(ATTACKER);
            vm.prank(ATTACKER);
            IPair(top[j]).skim(ATTACKER);
            assertEq(IERC20(WBNB).balanceOf(ATTACKER), before, "skim pays 0 on funded pairs");
        }
        // PBANK/WBNB holds the largest raw excess (10.5M PBANK); its WBNB side is $1.22 total,
        // so the excess is worth ~1e-8 WBNB: verify skim pays the dust and no WBNB.
        // (PBANK reflects fees to holders, so the pair's balance keeps inching up — we only
        //  assert the caller gains no WBNB and the excess moved.)
        address PBANKWBNB = 0xc2B0FEC18dc38308E8a31F255dF746f15B0f8f24;
        address PBANK = IPair(PBANKWBNB).token0();
        uint256 pbankBefore = IERC20(PBANK).balanceOf(ATTACKER);
        uint256 wbnbBefore = IERC20(WBNB).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IPair(PBANKWBNB).skim(ATTACKER);
        uint256 pbankGot = IERC20(PBANK).balanceOf(ATTACKER) - pbankBefore;
        emit log_named_uint("PBANK dust received from skim", pbankGot);
        assertGt(pbankGot, 1_000_000e9, "skim paid the standing dust excess");
        assertEq(IERC20(WBNB).balanceOf(ATTACKER), wbnbBefore, "no WBNB from PBANK skim");
    }

    // ---------------------------------------- NAR/WBNB pair: no extraction path
    function test_nar_pair_roundtrip_is_a_loss() public {
        _fundWbnb(1 ether);
        uint256 start = IERC20(WBNB).balanceOf(ATTACKER);
        assertEq(start, 1 ether);

        (uint112 r0, uint112 r1,) = IPair(NARWBNB).getReserves(); // token0 = NAR, token1 = WBNB
        uint256 outNar = _getAmountOut(1 ether, r1, r0);

        vm.prank(ATTACKER);
        IERC20(WBNB).transfer(NARWBNB, 1 ether);
        vm.prank(ATTACKER);
        IPair(NARWBNB).swap(outNar, 0, ATTACKER, "");

        uint256 gotNar = IERC20(NAR).balanceOf(ATTACKER);
        emit log_named_uint("NAR quoted out", outNar);
        emit log_named_uint("NAR actually received (5% transfer tax)", gotNar);
        // 2.5% burn + 2.5% reward fee are skimmed by the NAR token itself
        assertLe(gotNar, (outNar * 96) / 100, "NAR fee applied");
        assertGe(gotNar, (outNar * 94) / 100, "NAR fee applied");

        // sell the NAR back (another 5% tax on the way in)
        vm.prank(ATTACKER);
        IERC20(NAR).transfer(NARWBNB, gotNar);
        (uint112 nr0, uint112 nr1,) = IPair(NARWBNB).getReserves();
        uint256 amountIn = IERC20(NAR).balanceOf(NARWBNB) - nr0; // 95% of gotNar
        uint256 outWbnb = _getAmountOut(amountIn, nr0, nr1);
        vm.prank(ATTACKER);
        IPair(NARWBNB).swap(0, outWbnb, ATTACKER, "");

        uint256 end = IERC20(WBNB).balanceOf(ATTACKER);
        emit log_named_uint("WBNB returned after round trip", end);
        emit log_named_uint("round-trip loss (wei)", start - end);
        // must lose >5% to the pair fees + two 5% NAR transfer taxes
        assertLt(end, (start * 95) / 100, "round trip loses >5%: no arbitrage to extract the WBNB side");
    }

    // --------------------------------------------------------- locker: P, not E-U
    function test_nlp_locker_withdraw_is_only_owner() public {
        INlpLock lock = INlpLock(LOCKER);
        assertEq(lock.owner(), FEE_SETTER);
        assertLt(lock.unlockTime(), block.timestamp);
        uint256 lp = IERC20(NARWBNB).balanceOf(LOCKER);
        emit log_named_uint("locked NAR/WBNB LP (80.4% of pool)", lp);
        assertGt(lp, 20_000e18);
        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        lock.withdraw();
    }

    // ----------------------------------------------------------- farm gates (V2)
    function test_farm_v2_withdraw_requires_stake_and_rnlp() public {
        IFarm farm = IFarm(FARM_V2_NW);
        vm.prank(ATTACKER);
        vm.expectRevert();
        farm.withdraw(1e18);

        vm.prank(ATTACKER);
        vm.expectRevert("Cannot withdraw 0");
        farm.emergencyWithdraw();

        // getReward by a non-staker pays nothing
        uint256 balBefore = IERC20(NAR).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        farm.getReward();
        assertEq(IERC20(NAR).balanceOf(ATTACKER), balBefore, "no reward for non-staker");
        assertEq(farm.earned(ATTACKER), 0);

        // seize() is team-only
        vm.prank(ATTACKER);
        vm.expectRevert("not governance");
        farm.seize(NAR, 1e18);
    }

    function test_farm_buffRate_loops_are_broken_gates_only() public {
        IFarm farm = IFarm(FARM_V2_NW);
        // victim condition (maxBuffRate < buffrate) is false for every live staker ->
        // the self-boost branch of buffRateReporter is unreachable; call is a no-op.
        vm.prank(ATTACKER);
        farm.buffRateReporter(STAKER_MAXBUFF);
        assertEq(farm.getPower(ATTACKER), 0);

        // updateBuffRate loops `for (uint8 i = 0; i < daysCalculate; i++)`:
        // for an account with timeStamp == 0 daysCalculate ~= 20,700 and the counter
        // overflows at i=255 -> solc panic revert. Pure griefing (no value moved).
        (bool okFresh,) = address(farm).call{gas: 900_000}(
            abi.encodeWithSelector(IFarm.updateBuffRate.selector, ATTACKER)
        );
        assertFalse(okFresh, "updateBuffRate reverts for fresh/zero accounts");
        // V1 flavour has no early break, so even an old staker's call reverts
        (bool okV1,) = FARM_V1_NW.call{gas: 900_000}(
            abi.encodeWithSelector(IFarm.updateBuffRate.selector, ATTACKER)
        );
        assertFalse(okV1, "V1 updateBuffRate reverts (unbounded uint8 loop)");
    }

    function test_farm_v2_staker_withdraw_needs_rnlp_approval() public {
        IFarm farm = IFarm(FARM_V2_NW);
        // staker with 233.89 LP but allowance 0 -> withdraw reverts in rNLP transferFrom
        vm.prank(STAKER_NO_ALLOW);
        vm.expectRevert();
        farm.withdraw(1e18);

        // staker with allowance: withdrawal is a normal self-service path (H-O)
        uint256 farmLpBefore = IERC20(NARWBNB).balanceOf(FARM_V2_NW);
        uint256 stakerLpBefore = IERC20(NARWBNB).balanceOf(STAKER_ALLOW);
        vm.prank(STAKER_ALLOW);
        farm.withdraw(1e18);
        assertEq(IERC20(NARWBNB).balanceOf(FARM_V2_NW), farmLpBefore - 1e18);
        assertEq(IERC20(NARWBNB).balanceOf(STAKER_ALLOW), stakerLpBefore + 1e18);
    }

    // -------------------------------------------------- collecter: pays nobody
    function test_collecter_convert_permissionless_but_pays_nobody() public {
        ICollecter col = ICollecter(COLLECTER);
        uint256 wBefore = IERC20(WBNB).balanceOf(ATTACKER);
        uint256 nBefore = IERC20(NAR).balanceOf(ATTACKER);
        uint256 colBefore = IERC20(WBNB).balanceOf(COLLECTER);

        // GOLD/WBNB LP is the collecter's largest fee-LP position
        address GOLD = 0x8f4087Cb09E0F378f4278a314C94A636665dE24b;
        col.convert(GOLD, WBNB);

        assertEq(IERC20(WBNB).balanceOf(ATTACKER), wBefore, "caller gets no WBNB");
        assertEq(IERC20(NAR).balanceOf(ATTACKER), nBefore, "caller gets no NAR");
        emit log_named_uint("collecter WBNB after convert", IERC20(WBNB).balanceOf(COLLECTER));
        emit log_named_uint("collecter WBNB before convert", colBefore);
        emit log_named_uint("collecter threshold", col.threshold());

        // the NAR pair itself is explicitly excluded
        vm.expectRevert("NarwhalswapCollector: This is NAR pair");
        col.convert(NAR, WBNB);
    }

    // ------------------------------------------- THUGS burn tax kills extraction
    function test_thugs_burn_tax_on_narwhal_pair() public {
        IThugs th = IThugs(THUGS);
        assertFalse(th.paused(), "THUGS not paused");
        assertFalse(th.whitelistedSenders(THUGSWBNB), "Narwhal pair NOT whitelisted (burns apply)");
        emit log_named_uint("whitelisted(bscswap pair)", th.whitelistedSenders(BSCSWAP_P) ? 1 : 0);
        emit log_named_uint("last TWAP (tokens/BNB, 1e18)", th.getLastTwap());

        // buy THUGS from the Narwhal WBNB/THUGS pair: pair sends X, buyer receives X*(1-burn)
        _fundWbnb(0.5 ether);
        uint256 startWbnb = IERC20(WBNB).balanceOf(ATTACKER);
        (uint112 r0, uint112 r1,) = IPair(THUGSWBNB).getReserves(); // token0=WBNB, token1=THUGS
        uint256 quoted = _getAmountOut(0.5 ether, r0, r1);
        vm.prank(ATTACKER);
        IERC20(WBNB).transfer(THUGSWBNB, 0.5 ether);
        vm.prank(ATTACKER);
        IPair(THUGSWBNB).swap(0, quoted, ATTACKER, "");
        uint256 received = IERC20(THUGS).balanceOf(ATTACKER);
        emit log_named_uint("THUGS quoted out", quoted);
        emit log_named_uint("THUGS received after dynamic burn", received);
        emit log_named_uint("burn pct applied (bps of 10000)", (quoted - received) * 10000 / quoted);
        // dynamic burn is 5-50%: the buy itself loses at least the 0.5% floor
        assertLe(received, quoted, "burn applied");
        assertLe(received, (quoted * 995) / 1000, "burn >= 0.5% floor");

        // sell the received THUGS back: second burn + pair fee -> always a loss
        vm.prank(ATTACKER);
        IERC20(THUGS).transfer(THUGSWBNB, received);
        (uint112 s0, uint112 s1,) = IPair(THUGSWBNB).getReserves();
        uint256 amountIn = IERC20(THUGS).balanceOf(THUGSWBNB) - s1;
        uint256 outWbnb = _getAmountOut(amountIn, s1, s0);
        vm.prank(ATTACKER);
        IPair(THUGSWBNB).swap(outWbnb, 0, ATTACKER, "");
        uint256 wbnbAfterSell = IERC20(WBNB).balanceOf(ATTACKER);
        emit log_named_uint("WBNB back after sell", wbnbAfterSell);
        emit log_named_uint("WBNB start (pre-buy)", startWbnb);
        emit log_named_uint("WBNB lost on full round trip", startWbnb - wbnbAfterSell);
        assertLt(wbnbAfterSell, startWbnb / 2, "round trip loses >50%: WBNB side not extractable");
    }

    // ------------------------------------------------- dividend + token gates
    function test_div_v3_2_withdraw_gate() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        IFarm(DIV_V3_2).withdraw(1e18);
        vm.prank(ATTACKER);
        vm.expectRevert();
        IFarm(DIV_V3_2).emergencyWithdraw();
    }

    function test_nar_mint_gate_and_cap() public {
        INarToken nar = INarToken(NAR);
        assertTrue(nar._openTransfer());
        assertEq(nar._governance(), FEE_SETTER);
        uint256 remaining = nar._maxSupply() - nar.totalSupply() - nar._totalBurnToken();
        emit log_named_uint("NAR mintable remaining under cap", remaining);
        assertLt(remaining, 300_000e18);
        vm.prank(ATTACKER);
        vm.expectRevert("!minter");
        nar.mint(ATTACKER, 1e18);
    }

    function test_rnlp_mint_gate() public {
        vm.prank(ATTACKER);
        vm.expectRevert("!minter");
        IERC20(RNLP5).mint(ATTACKER, 1e18);
    }

    // ------------------------------------------------------------- live numbers
    function test_live_numbers_snapshot() public {
        (uint112 r0, uint112 r1,) = IPair(NARWBNB).getReserves();
        emit log_named_uint("NAR/WBNB: NAR reserve", r0);
        emit log_named_uint("NAR/WBNB: WBNB reserve", r1);
        emit log_named_uint("NAR/WBNB: LP supply", IERC20(NARWBNB).totalSupply());
        (uint112 t0, uint112 t1,) = IPair(THUGSWBNB).getReserves();
        emit log_named_uint("WBNB/THUGS: WBNB reserve", t0);
        emit log_named_uint("WBNB/THUGS: THUGS reserve", t1);
        (uint112 b0, uint112 b1,) = IPair(WBNBBUSD).getReserves();
        emit log_named_uint("WBNB/BUSD: WBNB reserve", b0);
        emit log_named_uint("WBNB/BUSD: BUSD reserve", b1);
        emit log_named_uint("farm V2 NAR/WBNB LP held", IERC20(NARWBNB).balanceOf(FARM_V2_NW));
        emit log_named_uint("farm V2 NAR/WBNB NAR pot", IERC20(NAR).balanceOf(FARM_V2_NW));
        emit log_named_uint("farm V3 NAR/WBNB LP held", IERC20(NARWBNB).balanceOf(FARM_V3_NW));
        emit log_named_uint("farm V1 NAR/WBNB LP held", IERC20(NARWBNB).balanceOf(FARM_V1_NW));
        emit log_named_uint("collecter WBNB", IERC20(WBNB).balanceOf(COLLECTER));
        emit log_named_uint("block.number", block.number);
    }
}
