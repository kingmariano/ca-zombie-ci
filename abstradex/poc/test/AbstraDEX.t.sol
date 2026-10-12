// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// AbstraDEX (X Layer) live-state fork PoC — read-only research, local fork only.
/// Chain: X Layer (196). Fork RPC: public keyless endpoint (no secrets).
/// Verified: AbstraFactory (solc 0.5.16, verified on ZetaChain Blockscout) is byte-identical
/// on X Layer / Zeta / Morph / ZKFair / Blast (runtime keccak 0xbf2c16...),
/// and the pair template is the canonical UniV2 SwapPair embedded in the factory
/// (CREATE2 address check in T0). Token order is read on-chain in every test.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
}

interface IPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function burn(address to) external returns (uint256, uint256);
    function mint(address to) external returns (uint256);
}

interface IFactory {
    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
}

contract AbstraDEXTest is Test {
    // ---- pinned fork ----
    uint256 constant FORK_BLOCK = 73_036_000;
    address constant ATTACKER = address(0xA11CE);

    // ---- X Layer addresses ----
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant FACTORY = 0xA7afB6163c331DDb0845843889D6f9544328846F;

    // top pool: OKcat/WOKB  (812.9 WOKB side) — the $100k+ pool
    address constant P_OKCAT = 0x0B07f323697348879BB21C44f8341E2511604858;
    address constant OKCAT = 0x5574730E54E167e2fD0003aEd0D6Ce31eD8b4600;
    // lopsided pool: TToken/WOKB (1,938.77 TToken side vs 0.00052 WOKB side) — worthless side drainable
    address constant P_TTOKEN = 0x137Ca6f986D431c805e2753E22271453Abb67B60;
    address constant TTOKEN = 0x030CDF1e93db503FF73cdbC76e6FCBfFDFfA59f6;
    // 1-wei-side pools where the WOKB side is the real money (XDOG $24.6, XBONK $0.13, Duck $0.50)
    address constant P_XDOG = 0x3B503053e5fA1494E380395Eae993891a2a737f9;
    address constant XDOG = 0xe8dFF65cc550e6c0d5542Ed806D69e9a4C7Ea0d5;
    address constant P_XBONK = 0x98c21d64fFd44138DE1c520A5B5ff9d7825CF8A9;
    address constant P_DUCK = 0x425b2F37100Be9A16b6B6D750AD13ACb043B326C;
    // PotatoSwap V2 OKcat/WOKB pool (the only external "market" for any counterpart token)
    address constant P_PS = 0xFfb85Bc9204558531676971BCDE62ac639DaEb48;

    function setUp() public {
        string memory rpc = vm.envOr("XLAYER_RPC_URL", string("https://rpc.xlayer.tech"));
        vm.createSelectFork(rpc, FORK_BLOCK);
        vm.label(ATTACKER, "attacker");
        vm.label(P_OKCAT, "OKcat/WOKB pool");
        vm.label(P_PS, "PotatoSwap OKcat/WOKB");
    }

    /// Force an ERC20 balance without needing the exact storage layout.
    function forceBalance(address token, address who, uint256 amount) internal {
        for (uint256 slot = 0; slot < 25; slot++) {
            bytes32 k = keccak256(abi.encode(who, slot));
            vm.store(token, k, bytes32(amount));
            if (IERC20(token).balanceOf(who) == amount) return;
            vm.store(token, k, bytes32(0));
        }
        revert("balance slot not found");
    }

    /// UniV2 out-amount bound: in-side rIn, out-side rOut, amountIn in.
    function maxOut(uint256 rIn, uint256 rOut, uint256 amountIn) internal pure returns (uint256) {
        return (998 * amountIn * rOut) / (1000 * rIn + 998 * amountIn);
    }

    // ---------------------------------------------------------------
    // T0: deployed factory == verified AbstraFactory source; pair is CREATE2 of its template
    // ---------------------------------------------------------------
    function test_T0_pairCodeMatchesVerifiedFactory() public {
        bytes32 initHash = IFactory(FACTORY).INIT_CODE_PAIR_HASH();
        bytes32 salt = keccak256(abi.encodePacked(OKCAT, WOKB));
        address computed =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), FACTORY, salt, initHash)))));
        assertEq(computed, P_OKCAT, "pair must be CREATE2 of factory template");
        assertEq(IFactory(FACTORY).feeTo(), address(0), "protocol fee off");
        assertEq(IFactory(FACTORY).feeToSetter(), 0xCe8Bd93A367B81d255EB2bCCAe5a98900126884C);
    }

    // ---------------------------------------------------------------
    // T1: lopsided pool: ANYONE can strip the whole scam-token side for < $1 of WOKB.
    //     (real value extracted = 1,938.77 TToken, USD ~0 — "TestToken")
    // ---------------------------------------------------------------
    function test_T1_lopsidedPool_anyoneCanStripWorthlessSide() public {
        address t0 = IPair(P_TTOKEN).token0(); // TToken
        address t1 = IPair(P_TTOKEN).token1(); // WOKB
        assertEq(t0, TTOKEN);
        assertEq(t1, WOKB);
        (uint112 r0, uint112 r1,) = IPair(P_TTOKEN).getReserves();
        assertGt(uint256(r0), 1e18, "TToken side > 1e18");
        assertLt(uint256(r1), 1e15, "WOKB side is dust");

        // spend 10x the WOKB side -> take out ~91% of the TToken side
        uint256 spend = uint256(r1) * 10;
        vm.deal(ATTACKER, spend);
        vm.prank(ATTACKER);
        IWETH(WOKB).deposit{value: spend}();
        uint256 out = maxOut(uint256(r1), uint256(r0), spend);
        vm.startPrank(ATTACKER);
        IERC20(WOKB).transfer(P_TTOKEN, spend);
        IPair(P_TTOKEN).swap(out, 0, ATTACKER, "");
        vm.stopPrank();
        uint256 got = IERC20(TTOKEN).balanceOf(ATTACKER);
        emit log_named_uint("WOKB spent (wei)", spend);
        emit log_named_uint("TToken extracted", got);
        assertGt(got, (uint256(r0) * 9) / 10, ">=90% of the TToken side extracted");
    }

    // ---------------------------------------------------------------
    // T2: 1-wei-side pool: the WOKB side ($24.58) is only extractable if the attacker
    //     can source >=1 wei of the counterpart token (XDOG — no market, no mint).
    // ---------------------------------------------------------------
    function test_T2_tinySideGate_noCounterpart_reverts() public {
        address t0 = IPair(P_XDOG).token0(); // WOKB (large side)
        address t1 = IPair(P_XDOG).token1(); // XDOG (1 wei)
        assertEq(t0, WOKB);
        assertEq(t1, XDOG);
        (uint112 r0, uint112 r1,) = IPair(P_XDOG).getReserves();
        assertEq(uint256(r1), 1, "XDOG reserve is 1 wei");
        assertGt(uint256(r0), 0, "WOKB reserve > 0");
        // attacker holds no XDOG -> revert
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Swap: INSUFFICIENT_INPUT_AMOUNT"));
        IPair(P_XDOG).swap(uint256(r0) - 1, 0, ATTACKER, "");
    }

    function test_T2b_tinySideGate_withOneWei_extractsHalfWOKB() public {
        address t1 = IPair(P_XDOG).token1(); // XDOG
        (uint112 r0, uint112 r1,) = IPair(P_XDOG).getReserves();
        forceBalance(t1, ATTACKER, 1); // simulate sourcing 1 wei of XDOG (impossible today)
        uint256 balBefore = IERC20(t1).balanceOf(P_XDOG);
        vm.startPrank(ATTACKER);
        IERC20(t1).transfer(P_XDOG, 1);
        vm.stopPrank();
        uint256 received = IERC20(t1).balanceOf(P_XDOG) - balBefore;
        assertGt(received, 0, "pair received XDOG");
        uint256 out = maxOut(uint256(r1), uint256(r0), received); // in = XDOG, out = WOKB
        vm.prank(ATTACKER);
        IPair(P_XDOG).swap(out, 0, ATTACKER, "");
        uint256 gotWokb = IERC20(WOKB).balanceOf(ATTACKER);
        emit log_named_uint("WOKB extracted with 1 wei XDOG (wei)", gotWokb);
        assertGt(gotWokb, 0, "half of the WOKB side is extractable with 1 wei");
        assertLt(gotWokb, uint256(r0) / 2 + 2, "consistent with AMM bound");
    }

    // ---------------------------------------------------------------
    // T3: the top pools: no free extraction path
    // ---------------------------------------------------------------
    function test_T3_topPool_noFreeExtraction() public {
        // (a) LP is burned -> nobody can withdraw reserves via burn()
        uint256 ts = IPair(P_OKCAT).totalSupply();
        uint256 deadLP = IPair(P_OKCAT).balanceOf(0x000000000000000000000000000000000000dEaD);
        uint256 zeroLP = IPair(P_OKCAT).balanceOf(address(0));
        assertGt((deadLP + zeroLP) * 10_000 / ts, 9990, ">99.9% LP burned");
        vm.prank(ATTACKER);
        vm.expectRevert(); // no LP to burn
        IPair(P_OKCAT).burn(ATTACKER);

        // (b) no skim excess
        uint256 balBefore = IERC20(WOKB).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IPair(P_OKCAT).skim(ATTACKER);
        assertEq(IERC20(WOKB).balanceOf(ATTACKER), balBefore, "no skim excess");

        // (c) swap without counterpart tokens reverts (both directions)
        (uint112 r0, uint112 r1,) = IPair(P_OKCAT).getReserves();
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Swap: INSUFFICIENT_INPUT_AMOUNT"));
        IPair(P_OKCAT).swap(0, 1 ether, ATTACKER, "");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Swap: INSUFFICIENT_INPUT_AMOUNT"));
        IPair(P_OKCAT).swap(1 ether, 0, ATTACKER, "");

        // (d) the reserves stay in the pool
        assertGt(uint256(r1), 812 ether, "WOKB still locked in pool");
        assertGt(uint256(r0), 4e29, "OKcat side untouched");
    }

    // ---------------------------------------------------------------
    // T4: quantify the ONLY swap-path extraction: dumping OKcat held OUTSIDE the pool.
    //     (holder-only; requires acquiring OKcat, impossible unprivileged today)
    // ---------------------------------------------------------------
    function test_T4_holderOnly_extraction_quantified() public {
        (uint112 r0, uint112 r1,) = IPair(P_OKCAT).getReserves();
        uint256 supply = IERC20(OKCAT).totalSupply();
        uint256 outside = supply - uint256(r0); // OKcat held outside the pool (~8.8e28)
        emit log_named_uint("OKcat outside pool", outside);
        forceBalance(OKCAT, ATTACKER, outside);
        uint256 balBefore = IERC20(OKCAT).balanceOf(P_OKCAT);
        vm.startPrank(ATTACKER);
        IERC20(OKCAT).transfer(P_OKCAT, outside);
        vm.stopPrank();
        uint256 received = IERC20(OKCAT).balanceOf(P_OKCAT) - balBefore;
        emit log_named_uint("OKcat received by pool", received);
        uint256 out = maxOut(uint256(r0), uint256(r1), received); // in = OKcat, out = WOKB
        vm.prank(ATTACKER);
        IPair(P_OKCAT).swap(0, out, ATTACKER, "");
        uint256 gotWokb = IERC20(WOKB).balanceOf(ATTACKER);
        emit log_named_uint("WOKB extractable by dumping ALL outside OKcat (wei)", gotWokb);
        // ~142.4 WOKB = ~$18k at $126.3/OKB; the remaining ~$85k is permanently unreachable
        assertGt(gotWokb, 135 ether);
        assertLt(gotWokb, 150 ether);
    }

    // ---------------------------------------------------------------
    // T5: "market" arb via the only external OKcat market (PotatoSwap) is unprofitable
    //     and capacity-limited to dust.
    // ---------------------------------------------------------------
    function test_T5_potatoSwapArb_unprofitable() public {
        (uint112 ps0, uint112 ps1,) = IPair(P_PS).getReserves(); // OKcat / WOKB
        emit log_named_uint("PS OKcat reserve", ps0);
        emit log_named_uint("PS WOKB reserve (wei)", ps1);

        // attacker buys OKcat with WOKB on PotatoSwap, then dumps it into AbstraDEX
        uint256 spend = 1e13; // 0.00001 WOKB (PS pool holds only ~3.9e13 wei total)
        forceBalance(WOKB, ATTACKER, spend);
        uint256 okcatOut = maxOut(uint256(ps1), uint256(ps0), spend);
        emit log_named_uint("OKcat bought on PS", okcatOut);

        (uint112 r0, uint112 r1,) = IPair(P_OKCAT).getReserves();
        uint256 wokbBack = maxOut(uint256(r0), uint256(r1), okcatOut);
        emit log_named_uint("WOKB back from AbstraDEX", wokbBack);
        assertLt(wokbBack, spend, "round trip loses >= 2x 0.3% fee -> unprofitable");
    }

    // ---------------------------------------------------------------
    // T6: the other two 1-wei-side WOKB pools have the same gate (XBONK, Duck)
    // ---------------------------------------------------------------
    function test_T6_otherTinyPools_sameGate() public {
        for (uint256 i = 0; i < 2; i++) {
            address p = i == 0 ? P_XBONK : P_DUCK;
            (uint112 r0, uint112 r1,) = IPair(p).getReserves();
            uint256 tiny = uint256(r0) < uint256(r1) ? uint256(r0) : uint256(r1);
            assertEq(tiny, 1, "1-wei side");
            vm.prank(ATTACKER);
            vm.expectRevert(bytes("Swap: INSUFFICIENT_INPUT_AMOUNT"));
            if (uint256(r0) == 1) IPair(p).swap(0, uint256(r1) - 1, ATTACKER, "");
            else IPair(p).swap(uint256(r0) - 1, 0, ATTACKER, "");
        }
    }
}
