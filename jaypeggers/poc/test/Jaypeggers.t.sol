// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Jaypeggers (Ethereum) — live-extractability boundary tests (read-only, fork)
//
// Scope (all confirmed live at ETH block 26,178,136):
//   v1  JAY     0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E  (ETH-reserve bonding curve)
//   v1  staking 0x112E9FdAd728aDFBb1CE407a9CFa9339E1C6E130  (JAY/USDC-LP staking, ETH rewards)
//   v1  feeSpl  0x4826B4DE107623e0A42e85C2649CaeF736cBCaE9
//   v1  pair    0xEb7b5294c79b0369315Ed7fE76b52d3108B0A62D  (UNI-V2 JAY/USDC)
//   v2  jUSDC   0xca9f9671765F8D1A7e19ae2639E01FFF730f0D9B  (USDC-reserve bonding curve)
//   v2  staking 0xF70C2657C4135C2cE81977C32F7bC1E012A7226d  (jUSDC/WETH-LP staking, USDC rewards)
//   v2  feeSpl  0x0b4E01AB9938E554f4d02B579C3474B3B673A08F
//   v2  pair    0x893Be9aca9bE32a9bCE005D034E4C1facd4709Ac  (UNI-V2 jUSDC/WETH)
//
// Tests prove:
//   * both reserves are live and redeemable ONLY by token holders (H-O), at 90%
//     (v1) / 90% (v2) of pro-rata, with a small fee to the fee-address;
//   * no profitable arbitrage exists between each curve and its only market
//     (Uniswap V2) in either direction — fuzzed over sizes;
//   * neither staking pool's pre-existing rewards can be captured by a fresh
//     stake (deposit/withdraw cycle nets exactly 0), only pro-rata shares of
//     NEW inflows that arrive while staked;
//   * every privileged function reverts for an unprivileged caller;
//   * the 2022 reentrancy class is dead (OZ ReentrancyGuard).
//
// No mainnet transaction is ever sent; everything runs on a local fork.
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ICurveV1 is IERC20 {
    function sell(uint256 jay) external;
    function buy(address receiver) external payable;
    function JAYtoETH(uint256 value) external view returns (uint256);
    function ETHtoJAY(uint256 value) external view returns (uint256);
    function owner() external view returns (address);
    function start() external view returns (bool);
    function SELL_FEE() external view returns (uint16);
    function setStart() external;
    function setMax(uint256) external;
    function setSellFee(uint16) external;
    function setBuyFee(uint16) external;
    function setFeeAddress(address) external;
}

interface ICurveV2 is IERC20 {
    function sell(uint256 jay) external;
    function buy(address receiver, uint256 amount) external;
    function JAYtoETH(uint256 value) external view returns (uint256);
    function owner() external view returns (address);
    function start() external view returns (bool);
    function JAYNFT() external view returns (address);
    function setStart() external;
    function setMax(uint256) external;
    function setSellFee(uint16) external;
    function setBuyFee(uint16) external;
    function setFeeAddress(address) external;
    function setJAYNFT(address) external;
}

interface IStaking {
    function getStaked(address) external view returns (uint256);
    function getReward(address) external view returns (uint256);
    function getTotalStaked() external view returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function start() external view returns (bool);
    function owner() external view returns (address);
    function setStart() external;
    function setFeeAddress(address) external;
    function initalize(uint256, address[] calldata, uint256[] calldata) external;
}

interface ISplitterV1 {
    function splitFees() external;
    function owner() external view returns (address);
    function setTEAMWallet(address) external;
    function setLPWallet(address) external;
}

interface IRouter02 {
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256)
        external
        returns (uint256[] memory);
    function swapExactETHForTokens(uint256, address[] calldata, address, uint256)
        external
        payable
        returns (uint256[] memory);
    function swapExactTokensForETH(uint256, uint256, address[] calldata, address, uint256)
        external
        returns (uint256[] memory);
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
}

contract JaypeggersPoC is Test {
    // ---- mainnet constants (verified at block 26,178,136) ----
    address constant JAY_V1 = 0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E;
    address constant STK_V1 = 0x112E9FdAd728aDFBb1CE407a9CFa9339E1C6E130;
    address constant SPL_V1 = 0x4826B4DE107623e0A42e85C2649CaeF736cBCaE9;
    address constant PAIR_V1 = 0xEb7b5294c79b0369315Ed7fE76b52d3108B0A62D;
    address constant JAYD = 0xca9f9671765F8D1A7e19ae2639E01FFF730f0D9B;
    address constant STK_V2 = 0xF70C2657C4135C2cE81977C32F7bC1E012A7226d;
    address constant SPL_V2 = 0x0b4E01AB9938E554f4d02B579C3474B3B673A08F;
    address constant PAIR_V2 = 0x893Be9aca9bE32a9bCE005D034E4C1facd4709Ac;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // existing stakers used as witnesses (have pending rewards; see analysis/census)
    address constant STAKER_V1 = 0xe6181bDb6e75ccCa82D2e7C105F26DC67090099a;
    address constant STAKER_V2 = 0xfAB22550fcD520A7eCED27414CD74Bc70a6ac1a9;

    address attacker = makeAddr("attacker");
    address holder = makeAddr("holder");

    bool forked;

    function setUp() public {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("FORK_RPC", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
        uint256 pin = vm.envOr("PIN_BLOCK", uint256(26_178_136));
        // Prefer the exact triage block; fall back to latest if the RPC cannot
        // serve it (public RPCs may refuse archive requests).
        try vm.createSelectFork(rpc, pin) {
            forked = true;
        } catch {
            try vm.createSelectFork(rpc) {
                forked = true;
            } catch {
                forked = false;
            }
        }
        if (!forked) {
            emit log_string("WARNING: no fork available; fork tests will be skipped");
        }
    }

    modifier onFork() {
        vm.skip(!forked, "no fork");
        _;
    }

    // ------------------------------------------------------------------
    // 1. v1: reserve is live, only JAY holders can redeem it (H-O) and the
    //    payout split is exactly 90% seller / 3% fee address / 7% retained.
    // ------------------------------------------------------------------
    function test_v1_reserve_onlyRedeemableByHolders() public onFork {
        assertTrue(ICurveV1(JAY_V1).start(), "v1 curve started");
        assertEq(ICurveV1(JAY_V1).SELL_FEE(), 900, "v1 sell fee 90%");

        // unprivileged attacker without JAY cannot take anything
        vm.prank(attacker);
        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        ICurveV1(JAY_V1).sell(1001);

        uint256 reserveBefore = JAY_V1.balance;
        uint256 supplyBefore = ICurveV1(JAY_V1).totalSupply();
        assertGt(reserveBefore, 60 ether, "v1 reserve live (>60 ETH)");

        // a JAY holder sells: gets exactly 90% of pro-rata, fee addr gets eth/33
        uint256 jay = 100e18;
        deal(JAY_V1, holder, jay);
        uint256 expectedEth = (jay * reserveBefore) / supplyBefore;
        uint256 splitBefore = SPL_V1.balance;

        vm.prank(holder);
        ICurveV1(JAY_V1).sell(jay);

        uint256 paid = holder.balance;
        uint256 fee = SPL_V1.balance - splitBefore;
        assertEq(paid, (expectedEth * 900) / 1000, "seller got exactly 90%");
        assertEq(fee, expectedEth / 33, "fee addr got exactly eth/33");
        assertEq(
            JAY_V1.balance,
            reserveBefore - paid - fee,
            "reserve decreased exactly by payouts"
        );
        emit log_named_decimal_uint("v1 holder ETH redeemed", paid, 18);
    }

    // ------------------------------------------------------------------
    // 2. v1 arbitrage: pool -> curve is NEVER profitable (fuzzed)
    // ------------------------------------------------------------------
    function testFuzz_v1_poolToCurve_noProfit(uint96 usdcIn) public onFork {
        uint256 poolUsdc = IERC20(USDC).balanceOf(PAIR_V1);
        usdcIn = uint96(bound(usdcIn, 10e6, poolUsdc * 95 / 100));
        deal(USDC, attacker, usdcIn);

        vm.startPrank(attacker);
        IERC20(USDC).approve(ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = JAY_V1;
        uint256[] memory amounts =
            IRouter02(ROUTER).swapExactTokensForTokens(usdcIn, 0, path, attacker, block.timestamp + 1200);
        uint256 jayOut = amounts[1];

        ICurveV1(JAY_V1).sell(jayOut); // ETH to attacker
        uint256 ethOut = attacker.balance;

        // value the ETH in USDC by honestly selling it back through the market
        address[] memory path2 = new address[](2);
        path2[0] = WETH;
        path2[1] = USDC;
        IRouter02(ROUTER).swapExactETHForTokens{value: ethOut}(0, path2, attacker, block.timestamp + 1200);
        uint256 finalUsdc = IERC20(USDC).balanceOf(attacker); // swap output already landed
        vm.stopPrank();

        assertLt(finalUsdc, usdcIn, "pool->curve must lose money");
        emit log_named_uint("usdc in", usdcIn);
        emit log_named_uint("value out (usdc)", finalUsdc);
    }

    // ------------------------------------------------------------------
    // 3. v1 arbitrage: curve -> pool is NEVER profitable (fuzzed)
    // ------------------------------------------------------------------
    function testFuzz_v1_curveToPool_noProfit(uint96 ethIn) public onFork {
        ethIn = uint96(bound(ethIn, 0.001 ether, 20 ether));
        vm.deal(attacker, ethIn);

        vm.startPrank(attacker);
        ICurveV1(JAY_V1).buy{value: ethIn}(attacker);
        uint256 jayOut = IERC20(JAY_V1).balanceOf(attacker);

        IERC20(JAY_V1).approve(ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = JAY_V1;
        path[1] = USDC;
        uint256[] memory amounts =
            IRouter02(ROUTER).swapExactTokensForTokens(jayOut, 0, path, attacker, block.timestamp + 1200);

        address[] memory path2 = new address[](2);
        path2[0] = USDC;
        path2[1] = WETH;
        IERC20(USDC).approve(ROUTER, type(uint256).max);
        uint256[] memory amounts2 =
            IRouter02(ROUTER).swapExactTokensForTokens(amounts[1], 0, path2, attacker, block.timestamp + 1200);
        uint256 wethOut = amounts2[1];
        vm.stopPrank();

        // WETH == ETH in value; attacker ends with WETH instead of ETH
        assertLt(wethOut, ethIn, "curve->pool must lose money");
        emit log_named_uint("eth in", ethIn);
        emit log_named_uint("weth out", wethOut);
    }

    // ------------------------------------------------------------------
    // 4. v2 (jUSDC): reserve live, holders redeem 90%; no arb pool -> curve
    // ------------------------------------------------------------------
    function test_v2_reserve_onlyRedeemableByHolders() public onFork {
        assertTrue(ICurveV2(JAYD).start(), "v2 curve started");
        assertEq(ICurveV2(JAYD).JAYNFT(), address(0), "v2 NFT discount unset");

        uint256 reserveBefore = IERC20(USDC).balanceOf(JAYD);
        uint256 supplyBefore = ICurveV2(JAYD).totalSupply();
        assertGt(reserveBefore, 20_000e6, "v2 reserve live (>$20k)");

        // attacker without jUSDC cannot drain
        vm.prank(attacker);
        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        ICurveV2(JAYD).sell(1000);

        uint256 jayd = 100e18;
        deal(JAYD, holder, jayd);
        uint256 expectedUsdc = (jayd * reserveBefore) / supplyBefore;
        uint256 splitBefore = IERC20(USDC).balanceOf(SPL_V2);

        vm.prank(holder);
        ICurveV2(JAYD).sell(jayd);

        uint256 paid = IERC20(USDC).balanceOf(holder);
        uint256 fee = IERC20(USDC).balanceOf(SPL_V2) - splitBefore;
        assertEq(paid, (expectedUsdc * 9000) / 10000, "seller got exactly 90%");
        assertEq(fee, expectedUsdc / 25, "fee addr got exactly 4%");
        assertEq(
            IERC20(USDC).balanceOf(JAYD),
            reserveBefore - paid - fee,
            "reserve decreased exactly by payouts"
        );
        emit log_named_decimal_uint("v2 holder USDC redeemed (6dp)", paid, 6);
    }

    function testFuzz_v2_poolToCurve_noProfit(uint96 ethIn) public onFork {
        // pool holds only ~0.2 WETH; keep sizes sane
        ethIn = uint96(bound(ethIn, 0.001 ether, 2 ether));
        vm.deal(attacker, ethIn);

        vm.startPrank(attacker);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = JAYD;
        uint256[] memory amounts =
            IRouter02(ROUTER).swapExactETHForTokens{value: ethIn}(0, path, attacker, block.timestamp + 1200);
        uint256 jaydOut = amounts[1];

        ICurveV2(JAYD).sell(jaydOut); // pays USDC to attacker
        uint256 usdcOut = IERC20(USDC).balanceOf(attacker);

        address[] memory path2 = new address[](2);
        path2[0] = USDC;
        path2[1] = WETH;
        IERC20(USDC).approve(ROUTER, type(uint256).max);
        uint256[] memory amounts2 =
            IRouter02(ROUTER).swapExactTokensForTokens(usdcOut, 0, path2, attacker, block.timestamp + 1200);
        vm.stopPrank();

        assertLt(amounts2[1], ethIn, "v2 pool->curve must lose money");
        emit log_named_uint("eth in", ethIn);
        emit log_named_uint("weth back", amounts2[1]);
    }

    function testFuzz_v2_curveToPool_noProfit(uint96 usdcIn) public onFork {
        usdcIn = uint96(bound(usdcIn, 10e6, 20_000e6));
        deal(USDC, attacker, usdcIn);

        vm.startPrank(attacker);
        IERC20(USDC).approve(JAYD, type(uint256).max);
        ICurveV2(JAYD).buy(attacker, usdcIn); // mints 0.90 * usdcIn * S/B
        uint256 jaydOut = IERC20(JAYD).balanceOf(attacker);

        IERC20(JAYD).approve(ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = JAYD;
        path[1] = WETH;
        uint256[] memory amounts =
            IRouter02(ROUTER).swapExactTokensForTokens(jaydOut, 0, path, attacker, block.timestamp + 1200);

        IERC20(WETH).approve(ROUTER, type(uint256).max);
        address[] memory path2 = new address[](2);
        path2[0] = WETH;
        path2[1] = USDC;
        uint256[] memory amounts2 =
            IRouter02(ROUTER).swapExactTokensForTokens(amounts[1], 0, path2, attacker, block.timestamp + 1200);
        vm.stopPrank();

        assertLt(amounts2[1], usdcIn, "v2 curve->pool must lose money");
        emit log_named_uint("usdc in", usdcIn);
        emit log_named_uint("usdc back", amounts2[1]);
    }

    // ------------------------------------------------------------------
    // 5. v1 staking: a fresh stake cannot capture pre-existing rewards.
    //    The deposit itself triggers splitFees(); the inflow is credited to
    //    the CURRENT stakers at the pre-deposit denominator, and the
    //    depositor's entry is set after the distribution -> nets exactly 0.
    // ------------------------------------------------------------------
    function test_v1_staking_freshStakeCapturesNothing() public onFork {
        uint256 L = 8.75e14; // same magnitude as the largest existing staker

        uint256 witnessShares = IStaking(STK_V1).getStaked(STAKER_V1);
        uint256 T0 = IStaking(STK_V1).getTotalStaked();
        uint256 rewardWitnessBefore = IStaking(STK_V1).getReward(STAKER_V1);
        uint256 contractBalBefore = STK_V1.balance;
        uint256 splitterBalBefore = SPL_V1.balance;

        deal(PAIR_V1, attacker, L);
        vm.startPrank(attacker);
        IERC20(PAIR_V1).approve(STK_V1, type(uint256).max);

        uint256 ethBefore = attacker.balance;
        IStaking(STK_V1).deposit(L);
        uint256 afterDeposit = attacker.balance;
        IStaking(STK_V1).withdraw(L);
        uint256 afterWithdraw = attacker.balance;
        vm.stopPrank();

        assertEq(afterDeposit, ethBefore, "deposit pays attacker nothing");
        assertEq(afterWithdraw, ethBefore, "withdraw pays attacker nothing");
        assertEq(IERC20(PAIR_V1).balanceOf(attacker), L, "LP returned");

        // claim() drained the splitter: 2/3 went into the pool for the EXISTING
        // stakers, 1/3 went to the team wallet. The witness's pending therefore
        // moves exactly by -(team third) * shares / total (the view had counted
        // the whole splitter balance as if fully destined to stakers).
        uint256 rewardWitnessAfter = IStaking(STK_V1).getReward(STAKER_V1);
        if (witnessShares > 0) {
            uint256 teamCut = splitterBalBefore / 3;
            uint256 expectedDrop = (teamCut * witnessShares) / T0;
            assertApproxEqRel(
                rewardWitnessBefore - rewardWitnessAfter, expectedDrop, 0.005e18, "witness drop = team third"
            );
            assertGt(rewardWitnessAfter, 0, "existing staker still holds claim");
        }
        assertLt(SPL_V1.balance, splitterBalBefore, "splitter was drained by claim()");
        assertGe(STK_V1.balance, contractBalBefore, "pool kept (and grew) its balance");
        emit log_named_decimal_uint("witness staker pending after (eth)", rewardWitnessAfter, 18);
    }

    // ------------------------------------------------------------------
    // 6. v1 staking: only NEW inflows that arrive while staked are
    //    capturable, strictly pro-rata (no over-capture, no free lunch).
    // ------------------------------------------------------------------
    function test_v1_staking_newInflowOnlyProRata() public onFork {
        uint256 L = 3.55e15; // ≈ existing total staked -> ~50% share
        uint256 T0 = IStaking(STK_V1).getTotalStaked(); // BEFORE the new stake
        deal(PAIR_V1, attacker, L);

        vm.startPrank(attacker);
        IERC20(PAIR_V1).approve(STK_V1, type(uint256).max);
        IStaking(STK_V1).deposit(L); // entry set post-claim
        vm.stopPrank();

        // simulate future protocol fees landing in the splitter (1 ETH)
        vm.deal(SPL_V1, SPL_V1.balance + 1 ether);

        // anyone can trigger the split
        vm.prank(attacker);
        ISplitterV1(SPL_V1).splitFees();

        vm.prank(attacker);
        IStaking(STK_V1).withdraw(L);

        uint256 captured = attacker.balance;
        // splitter sends 1/3 to team + 2/3 into the staking pool (LP+NFT wallets
        // are both the staking contract). Attacker's share = L/(L+T0) of 2/3.
        uint256 oneEth = 1 ether;
        uint256 inflowToPool = (oneEth * 2) / 3;
        uint256 expected = (inflowToPool * L) / (L + T0);
        assertApproxEqRel(captured, expected, 0.02e18, "capture is exactly pro-rata");
        emit log_named_decimal_uint("attacker captured of new 1 ETH inflow", captured, 18);
        emit log_named_decimal_uint("existing stakers kept", inflowToPool - captured, 18);
    }

    // ------------------------------------------------------------------
    // 7. v2 staking: same pre-existing-reward non-capturability (USDC)
    // ------------------------------------------------------------------
    function test_v2_staking_freshStakeCapturesNothing() public onFork {
        uint256 L = 6.66e18; // ≈ largest existing staker
        uint256 rewardWitnessBefore = IStaking(STK_V2).getReward(STAKER_V2);

        deal(PAIR_V2, attacker, L);
        vm.startPrank(attacker);
        IERC20(PAIR_V2).approve(STK_V2, type(uint256).max);

        uint256 usdcBefore = IERC20(USDC).balanceOf(attacker);
        IStaking(STK_V2).deposit(L);
        uint256 afterDeposit = IERC20(USDC).balanceOf(attacker);
        IStaking(STK_V2).withdraw(L);
        uint256 afterWithdraw = IERC20(USDC).balanceOf(attacker);
        vm.stopPrank();

        assertEq(afterDeposit, usdcBefore, "v2 deposit pays nothing");
        assertEq(afterWithdraw, usdcBefore, "v2 withdraw pays nothing");
        assertEq(IERC20(PAIR_V2).balanceOf(attacker), L, "v2 LP returned");

        uint256 rewardWitnessAfter = IStaking(STK_V2).getReward(STAKER_V2);
        if (IStaking(STK_V2).getStaked(STAKER_V2) > 0) {
            assertGe(rewardWitnessAfter, rewardWitnessBefore, "existing staker kept/increased");
        }
        emit log_named_decimal_uint("v2 witness staker pending (usdc)", rewardWitnessAfter, 6);
    }

    // ------------------------------------------------------------------
    // 8. privileged surface reverts for an unprivileged caller
    // ------------------------------------------------------------------
    function test_adminFunctionsRevertForAttacker() public onFork {
        vm.startPrank(attacker);
        string memory own = "Ownable: caller is not the owner";

        vm.expectRevert(bytes(own));
        ICurveV1(JAY_V1).setStart();
        vm.expectRevert(bytes(own));
        ICurveV1(JAY_V1).setMax(0);
        vm.expectRevert(bytes(own));
        ICurveV1(JAY_V1).setSellFee(901);
        vm.expectRevert(bytes(own));
        ICurveV1(JAY_V1).setBuyFee(901);
        vm.expectRevert(bytes(own));
        ICurveV1(JAY_V1).setFeeAddress(attacker);

        vm.expectRevert(bytes(own));
        IStaking(STK_V1).setStart();
        vm.expectRevert(bytes(own));
        IStaking(STK_V1).setFeeAddress(attacker);
        address[] memory a = new address[](1);
        uint256[] memory b = new uint256[](1);
        a[0] = attacker;
        b[0] = 1;
        vm.expectRevert(bytes(own));
        IStaking(STK_V1).initalize(1, a, b);

        vm.expectRevert(bytes(own));
        ISplitterV1(SPL_V1).setTEAMWallet(attacker);
        vm.expectRevert(bytes(own));
        ISplitterV1(SPL_V1).setLPWallet(attacker);

        vm.expectRevert(bytes(own));
        ICurveV2(JAYD).setStart();
        vm.expectRevert(bytes(own));
        ICurveV2(JAYD).setMax(1e28);
        vm.expectRevert(bytes(own));
        ICurveV2(JAYD).setSellFee(9001);
        vm.expectRevert(bytes(own));
        ICurveV2(JAYD).setFeeAddress(attacker);
        vm.expectRevert(bytes(own));
        ICurveV2(JAYD).setJAYNFT(attacker);

        vm.expectRevert(bytes(own));
        IStaking(STK_V2).setStart();
        vm.expectRevert(bytes(own));
        IStaking(STK_V2).setFeeAddress(attacker);

        // v2 fee splitter wallets (same Ownable pattern)
        vm.expectRevert(bytes(own));
        ISplitterV1(SPL_V2).setTEAMWallet(attacker);
        vm.expectRevert(bytes(own));
        ISplitterV1(SPL_V2).setLPWallet(attacker);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // 9. the 2022 reentrancy class (malicious receiver in sell) is dead
    // ------------------------------------------------------------------
    function test_reentrancyBlocked() public onFork {
        ReentrantSell r = new ReentrantSell();
        deal(JAY_V1, address(r), 10e18);
        vm.expectRevert(bytes("ETH Transfer failed."));
        r.attack();
    }
}

contract ReentrantSell {
    ICurveV1 constant JAY_V1 = ICurveV1(0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E);
    bool tried;

    receive() external payable {
        if (!tried) {
            tried = true;
            JAY_V1.sell(1000); // must revert via nonReentrant; bubbles as failed send
        }
    }

    function attack() external {
        JAY_V1.sell(10e18);
    }
}
