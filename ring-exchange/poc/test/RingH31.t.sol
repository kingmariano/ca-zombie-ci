// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/*
 * H-31 Ring Exchange (HyperEVM, chainid 999) — fork-verified boundary tests.
 *
 * Read-only research PoC. Runs on a LOCAL FORK only; no mainnet transactions.
 * Pinned fork block 47,619,259 (2026-10-04). DefiLlama prices at that block:
 *   WHYPE = $89.83544193833231   UETH = $2695.440828462575   (UETH/WHYPE = 30.00420)
 *
 * Claims under test:
 *  1. Every Few wrapped token (fw*) is massively under-collateralised; the
 *     $148.7M-$153M pool valuation is nominal, real wrapper collateral is ~$4.8M.
 *  2. Buying fw tokens on Ring Swap and unwrapping to the real underlying is a
 *     guaranteed loss (pool spot is within ~0.2% of market, swap fee is 0.3%,
 *     plus price impact) -> no unprivileged arbitrage.
 *  3. Redemption of fw tokens is first-come-first-served and hard-capped by the
 *     wrapper's real collateral balance; the next wei reverts.
 *  4. No excess token balances sit in the pairs (skim() extracts nothing).
 *  5. Core init() is already consumed; attacker has no roles; the unused
 *     launchpad/minter contract 0xc38f2fd5 reverts on public calls.
 *  6. LATENT/PRIVILEGED (P) scenario: if a MINTER_ROLE key (EOA 0x9336… or the
 *     launchpad contract) were compromised, unbacked fwWHYPE could be minted and
 *     dumped into pool[1] to drain up to ~$2.99M of UETH collateral. Quantified
 *     here only to bound the privileged risk; it is NOT externally extractable.
 */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IFewWrappedToken is IERC20 {
    function token() external view returns (address);
    function wrap(uint256) external returns (uint256);
    function unwrap(uint256) external returns (uint256);
    function unwrapTo(uint256, address) external returns (uint256);
    function mint(address, uint256) external;
}

interface ISwapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
}

interface ISwapV2Router {
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
}

interface ICore {
    function isGovernor(address) external view returns (bool);
    function isMinter(address) external view returns (bool);
    function init() external;
}

contract RingH31Test is Test {
    uint256 constant FORK_BLOCK = 47_619_259;

    address constant WHYPE   = 0x5555555555555555555555555555555555555555;
    address constant UETH    = 0xBe6727B535545C67d5cAa73dEa54865B92CF7907;
    address constant USDC    = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address constant USDT0   = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address constant USDH    = 0x111111a1a0667d36bD57c0A9f569b98057111111;

    address constant FW_WHYPE = 0x9e1148bC3665a9f7C35F313d89c0432c34928AEf;
    address constant FW_UETH  = 0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397;
    address constant FW_USDC  = 0xd2646b9B02859416D8cBc759F85f0676f6E19974;
    address constant FW_USDT0 = 0x7576dd9a2775bFd789616d9eA7A2af21d06782D0;
    address constant FW_USDH  = 0x09D21E89EF332347eb3E1E496f1265a600e364C1;

    address constant PAIR1 = 0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a; // fwUETH/fwWHYPE

    address constant CORE        = 0x1cda28aD2915356EB618518b1bDD3f462aeF3803;
    address constant ROUTER      = 0x701D1d675415efA2d2429fB122ccC6dD4FCcA959;
    address constant MINTER_EOA  = 0x9336D0C82299Da0ab178271792954ADFD6f10fD7;
    address constant LAUNCHPAD   = 0xC38F2Fd561d748cE74A5f9ce09b89d2Cf421Fb56;

    // prices at the pinned block (USD, 1e18 fixed point)
    uint256 constant P_WHYPE = 89.83544193833231e18;
    uint256 constant P_UETH  = 2695.440828462575e18;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("HYPEREVM_RPC_URL", string("https://rpc.hyperliquid.xyz/evm"));
        vm.createSelectFork(rpc, FORK_BLOCK);
        vm.deal(attacker, 100 ether);
    }

    // ---------------------------------------------------------------- 1
    function test_live_state_undercollateralised() public {
        _check(FW_WHYPE, WHYPE);
        _check(FW_UETH, UETH);
        _check(FW_USDC, USDC);
        _check(FW_USDT0, USDT0);
        _check(FW_USDH, USDH);

        // pool[1] nominal TVL vs real backing
        (uint112 r0, uint112 r1,) = ISwapV2Pair(PAIR1).getReserves();
        uint256 nominalUsd = uint256(r0) * P_UETH / 1e18 + uint256(r1) * P_WHYPE / 1e18;
        uint256 realUsd = IERC20(UETH).balanceOf(FW_UETH) * P_UETH / 1e18
                        + IERC20(WHYPE).balanceOf(FW_WHYPE) * P_WHYPE / 1e18;
        emit log_named_uint("pool1 nominal TVL USD", nominalUsd / 1e18);
        emit log_named_uint("wrapper real collateral USD (UETH+WHYPE)", realUsd / 1e18);
        assertLt(realUsd * 100, nominalUsd * 5, "real backing should be <5% of nominal");
    }

    function _check(address wrapper, address underlying) internal {
        uint256 sup = IERC20(wrapper).totalSupply();
        uint256 col = IERC20(underlying).balanceOf(wrapper);
        emit log_named_address("wrapper", wrapper);
        emit log_named_uint("  supply", sup);
        emit log_named_uint("  underlying held", col);
        assertLt(col, sup, "wrapper must be under-collateralised");
    }

    // ---------------------------------------------------------------- 2
    function test_no_unprivileged_arbitrage_roundtrip() public {
        (uint112 r0, uint112 r1,) = ISwapV2Pair(PAIR1).getReserves(); // r0 fwUETH, r1 fwWHYPE
        uint256 spot = uint256(r1) * 1e18 / uint256(r0);              // fwWHYPE per fwUETH
        uint256 market = P_UETH * 1e18 / P_WHYPE;                     // WHYPE per UETH
        emit log_named_uint("spot fwWHYPE per fwUETH (1e18)", spot);
        emit log_named_uint("market WHYPE per UETH (1e18)", market);
        // spot is within 1% of market -> no large standing mispricing
        assertApproxEqRel(spot, market, 0.01e18, "spot must be close to market");

        // $1M-equivalent buy of fwUETH with fwWHYPE through the router
        uint256 amountIn = 1_000_000e18 * 1e18 / P_WHYPE; // fwWHYPE in
        address[] memory path = new address[](2);
        path[0] = FW_WHYPE; path[1] = FW_UETH;
        uint256[] memory amounts = ISwapV2Router(ROUTER).getAmountsOut(amountIn, path);
        uint256 outUeth = amounts[1];
        uint256 inUsd  = amountIn * P_WHYPE / 1e18;
        uint256 outUsd = outUeth * P_UETH / 1e18;
        emit log_named_uint("in USD", inUsd / 1e18);
        emit log_named_uint("out USD after swap (before unwrap)", outUsd / 1e18);
        assertLt(outUsd, inUsd, "buying fwUETH with fwWHYPE must lose money");

        // reverse direction
        path[0] = FW_UETH; path[1] = FW_WHYPE;
        amountIn = 1_000_000e18 * 1e18 / P_UETH;
        amounts = ISwapV2Router(ROUTER).getAmountsOut(amountIn, path);
        uint256 outWhype = amounts[1];
        inUsd  = amountIn * P_UETH / 1e18;
        outUsd = outWhype * P_WHYPE / 1e18;
        emit log_named_uint("reverse in USD", inUsd / 1e18);
        emit log_named_uint("reverse out USD", outUsd / 1e18);
        assertLt(outUsd, inUsd, "buying fwWHYPE with fwUETH must lose money");
    }

    // ---------------------------------------------------------------- 3
    function test_redemption_cap_first_come_first_served() public {
        uint256 col = IERC20(UETH).balanceOf(FW_UETH);
        emit log_named_uint("UETH collateral before", col);

        // Attacker holds fwUETH (as if bought/wrapped) and tries to redeem more than exists.
        deal(FW_UETH, attacker, col + 1e18);
        vm.startPrank(attacker);
        vm.expectRevert(bytes("TransferHelper::safeTransfer: transfer failed"));
        IFewWrappedToken(FW_UETH).unwrap(col + 1e18); // more than the wrapper holds -> revert
        IFewWrappedToken(FW_UETH).unwrap(col);        // exactly the collateral -> succeeds
        vm.stopPrank();

        assertEq(IERC20(UETH).balanceOf(FW_UETH), 0, "collateral drained to zero");
        assertEq(IERC20(UETH).balanceOf(attacker), col, "first-come redeemer receives exactly the collateral");

        // one more wei cannot be redeemed
        vm.prank(attacker);
        vm.expectRevert(bytes("TransferHelper::safeTransfer: transfer failed"));
        IFewWrappedToken(FW_UETH).unwrap(1);
    }

    // ---------------------------------------------------------------- 4
    function test_pairs_have_no_skim_excess() public view {
        (uint112 r0, uint112 r1,) = ISwapV2Pair(PAIR1).getReserves();
        assertEq(IERC20(FW_UETH).balanceOf(PAIR1), uint256(r0), "no excess fwUETH");
        assertEq(IERC20(FW_WHYPE).balanceOf(PAIR1), uint256(r1), "no excess fwWHYPE");
    }

    // ---------------------------------------------------------------- 5
    function test_core_roles_and_init_closed() public {
        assertFalse(ICore(CORE).isGovernor(attacker));
        assertFalse(ICore(CORE).isMinter(attacker));
        vm.prank(attacker);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        ICore(CORE).init();
    }

    function test_launchpad_minter_public_calls_revert() public {
        vm.startPrank(attacker);
        (bool ok,) = LAUNCHPAD.call(abi.encodeWithSelector(bytes4(0x40c10f19), attacker, 1e18)); // mint(address,uint256)
        assertFalse(ok, "mint must revert for public caller");
        (ok,) = LAUNCHPAD.call(abi.encodeWithSelector(bytes4(0xc21ab7f9), attacker)); // createToken(address)
        assertFalse(ok, "createToken must revert for public caller");
        (ok,) = LAUNCHPAD.call(abi.encodeWithSelector(bytes4(0x5dbd6059), 1e18, attacker)); // unwrapTo(uint256,address)
        assertFalse(ok, "unwrapTo must revert for public caller");
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 6 (P scenario)
    function test_privileged_mint_would_drain_collateral() public {
        uint256 colU = IERC20(UETH).balanceOf(FW_UETH);
        emit log_named_uint("UETH collateral available to drain", colU);

        // Simulate a compromised MINTER_ROLE holder minting unbacked fwWHYPE.
        // Need ~34,638 fwWHYPE of pool input to buy out the full 1,108 UETH collateral.
        vm.prank(MINTER_EOA);
        IFewWrappedToken(FW_WHYPE).mint(attacker, 40_000e18);

        // dump into pool[1] directly (pair.swap) for fwUETH
        (uint112 r0, uint112 r1,) = ISwapV2Pair(PAIR1).getReserves();
        uint256 amountIn = 40_000e18;
        uint256 amountOut = _getAmountOut(amountIn, r1, r0); // fwWHYPE -> fwUETH
        vm.startPrank(attacker);
        IERC20(FW_WHYPE).transfer(PAIR1, amountIn);
        ISwapV2Pair(PAIR1).swap(amountOut, 0, attacker, "");
        // redeem as much UETH as the wrapper holds
        uint256 redeemable = amountOut < colU ? amountOut : colU;
        IFewWrappedToken(FW_UETH).unwrap(redeemable);
        vm.stopPrank();

        uint256 drained = IERC20(UETH).balanceOf(attacker);
        emit log_named_uint("UETH drained by privileged minter (wei)", drained);
        emit log_named_uint("USD value drained (1e18)", drained * P_UETH / 1e18 / 1e18);
        assertGt(drained, 0, "privileged mint path can drain collateral");
        assertLe(drained, colU, "cannot exceed wrapper collateral");
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal pure returns (uint256)
    {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }
}
