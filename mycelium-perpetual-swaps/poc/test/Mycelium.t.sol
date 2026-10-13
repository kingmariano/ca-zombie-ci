// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, IVault, IOrderBook, IMlpManager, IRewardTracker, IRewardRouter, IRewardDistributor} from "../src/Interfaces.sol";

/// Mycelium Perpetual Swaps (Arbitrum) — live-state gate proofs (fork-only, read-only logic).
/// All tests run on an Arbitrum fork; no mainnet transactions are ever sent.
contract MyceliumLiveTest is Test {
    // ---- live addresses (verified on Arbiscan) ----
    address constant VAULT = 0xDfbA8AD57d2c62F61F0a60B2C508bCdeb182f855;
    address constant ORDERBOOK = 0x2EeEf7852a306a580acF94F7c18C3FF124A59d4f;
    address constant MLPMANAGER = 0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f;
    address constant MLP = 0x752b746426b6D0c3188bb530660374f92FD9cf7c;
    address constant REWARDROUTER = 0xd98d8e458F7aD22DD3C1d7A8B35C74005eb52b0b;
    address constant TRACKER2023 = 0xF9B003Ee160dA9677115Ad3c5bd6BB6dADcB2F93; // sMYC (2023) 6.66 WETH + 23.4M MYC
    address constant FEE_MLP_TRACKER = 0xF0BFB95087E611897096982c33B6934C8aBfA083; // 19.42 WETH + staked MLP
    address constant UNSTAKED_MLP_DIST = 0x0F5976e0380e9B743A90271AcBD031b4Cc4D9dE8;
    address constant TRACKER2023_DIST = 0xD5c7bbA9073a8D3e21cf69F5A1fa01B870ac72C0;

    // ---- tokens ----
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address constant UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
    address constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address constant CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address constant MYC = 0xC74fE4c715510Ec2F8C61d70D397B32043F55Abe;

    // ---- actors ----
    address constant ATTACKER = address(0xA11CE);
    address constant SMYC_STAKER = 0x6faE34CFC6F2762Bac55828177a7a221EA9CD979; // 4,960 sMYC, ~0.0084 WETH claimable
    address constant MLP_STAKER = 0x12A492EadC62071208C7D1dA4FEaF206fD30b5b7; // 1.126 MLP staked, WETH claimable
    address constant POSITION_OWNER = 0x9bAaA9b5AE178C238714201A3022804C1bd6f279; // live USDC/UNI short
    address constant OB_SWAP_ORDER_ACCOUNT = 0x3d38f21012052C201bb94EB97eEd6F774EeC4b69; // pending swap order idx 1
    address constant OB_INC_ORDER_ACCOUNT = 0xd1dE80930227C56eE8bB2049e4D36bFf4161163E; // pending increase order idx 10
    address constant OB_DEC_ORDER_ACCOUNT = 0xacFF176Fd0F2fFEFf6027b91764084AC93D3FDce; // pending decrease order idx 0

    // ---- market reference prices (DefiLlama snapshot ts 1791915784 = 2026-10-13) ----
    uint256 constant FRAX_MKT = 0.99089e18;
    uint256 constant UNI_MKT = 7.5771e18;
    uint256 constant FRAX_MKT_CONSERVATIVE = 0.995e18; // conservative floor for the assertion

    IVault vault = IVault(VAULT);
    IOrderBook orderBook = IOrderBook(ORDERBOOK);
    IMlpManager mlpManager = IMlpManager(MLPMANAGER);

    function setUp() public {
        vm.createSelectFork(vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc")));
    }

    // ------------------------------------------------------------------
    // A. Vault.swap() — permissionless, but oracle is live + buffers block extraction
    // ------------------------------------------------------------------

    function test_01_swap_wbtc_out_reverts_buffer() public {
        assertEq(vault.isSwapEnabled(), true, "swaps enabled");
        assertGt(vault.bufferAmounts(WBTC), vault.poolAmounts(WBTC), "buffer > pool for WBTC");

        deal(USDC, ATTACKER, 1_000e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).transfer(VAULT, 1_000e6);
        vm.expectRevert(bytes("Vault: poolAmount < buffer"));
        vault.swap(USDC, WBTC, ATTACKER);
        vm.stopPrank();
    }

    function test_02_only_dust_pools_are_unblocked() public {
        // Every material asset is buffer-locked as a swap output (buffer >= pool)
        assertGt(vault.bufferAmounts(WBTC), vault.poolAmounts(WBTC), "WBTC locked");
        assertGt(vault.bufferAmounts(WETH), vault.poolAmounts(WETH), "WETH locked");
        assertGt(vault.bufferAmounts(USDC), vault.poolAmounts(USDC), "USDC locked");
        assertGt(vault.bufferAmounts(LINK), vault.poolAmounts(LINK), "LINK locked");
        assertGt(vault.bufferAmounts(USDT), vault.poolAmounts(USDT), "USDT locked");
        assertGt(vault.bufferAmounts(DAI), vault.poolAmounts(DAI), "DAI locked");
        // Unblocked outputs are dust only
        assertEq(vault.bufferAmounts(UNI), 0, "UNI not locked");
        assertLt(vault.poolAmounts(UNI), 1e15, "UNI pool is dust (<0.001 UNI)");
        assertLt(vault.poolAmounts(FRAX), 1e15, "FRAX pool is dust");
        assertLt(vault.poolAmounts(CRV), 1e15, "CRV pool is dust");
        console.log("UNI pool (unblocked but dust)", vault.poolAmounts(UNI));
        console.log("WBTC pool vs buffer", vault.poolAmounts(WBTC), vault.bufferAmounts(WBTC));

        // taking WETH out reverts (buffer) even though pool-reserved > 0
        uint256 priceIn = vault.getMinPrice(WBTC);
        uint256 priceOut = vault.getMaxPrice(WETH);
        uint256 amountIn = (0.001e18 * priceOut * 10 ** 8) / (priceIn * 10 ** 18);
        deal(WBTC, ATTACKER, amountIn + 1);
        vm.startPrank(ATTACKER);
        IERC20(WBTC).transfer(VAULT, amountIn);
        vm.expectRevert(bytes("Vault: poolAmount < buffer"));
        vault.swap(WBTC, WETH, ATTACKER);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // B. OrderBook — permissionless execute*(), but every pending order reverts
    // ------------------------------------------------------------------

    function test_03_orderbook_executeSwapOrder_reverts_reserve() public {
        (,,,,,, bool triggerAbove,, uint256 fee) = orderBook.getSwapOrder(OB_SWAP_ORDER_ACCOUNT, 1);
        assertEq(triggerAbove, false, "no price trigger");
        assertEq(fee, 0.0003e18, "execution fee");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Vault: reserve exceeds pool"));
        orderBook.executeSwapOrder(OB_SWAP_ORDER_ACCOUNT, 1, payable(ATTACKER));
    }

    function test_04_orderbook_executeIncreaseOrder_reverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Vault: reserve exceeds pool"));
        orderBook.executeIncreaseOrder(OB_INC_ORDER_ACCOUNT, 10, payable(ATTACKER));
    }

    function test_05_orderbook_executeDecreaseOrder_reverts_plugin() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Router: invalid plugin"));
        orderBook.executeDecreaseOrder(OB_DEC_ORDER_ACCOUNT, 0, payable(ATTACKER));
    }

    // ------------------------------------------------------------------
    // C. Vault liquidation / position paths — privileged or owner-only
    // ------------------------------------------------------------------

    function test_06_liquidatePosition_notLiquidator_reverts() public {
        assertEq(vault.inPrivateLiquidationMode(), true, "private liquidation mode");
        assertEq(vault.isLiquidator(ATTACKER), false, "attacker not liquidator");
        assertEq(vault.isLiquidator(0x3892b8cF646b17709C91E653319bA5504a5FEafe), true, "PositionManager is liquidator");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Vault: invalid liquidator"));
        vault.liquidatePosition(POSITION_OWNER, USDC, UNI, false, ATTACKER);
    }

    function test_07_decreasePosition_notOwner_reverts() public {
        (uint256 size,,,,,,,) = vault.getPosition(POSITION_OWNER, USDC, UNI, false);
        assertGt(size, 0, "live position exists");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Vault: invalid msg.sender"));
        vault.decreasePosition(POSITION_OWNER, USDC, UNI, 0, size, false, ATTACKER);
    }

    function test_08_increasePosition_leverageDisabled_reverts() public {
        assertEq(vault.isLeverageEnabled(), false, "leverage disabled on vault");
        deal(WETH, ATTACKER, 1e18);
        vm.startPrank(ATTACKER);
        IERC20(WETH).transfer(VAULT, 1e18);
        vm.expectRevert(bytes("Vault: leverage not enabled"));
        vault.increasePosition(ATTACKER, WETH, WETH, 1e18, true);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // D. MLP (LP) redemption — handler-gated AND bricked (S)
    // ------------------------------------------------------------------

    function test_09_mlp_removeLiquidity_direct_reverts() public {
        assertEq(mlpManager.inPrivateMode(), true, "private mode");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("MlpManager: action not enabled"));
        mlpManager.removeLiquidity(USDC, 1e18, 0, ATTACKER);
    }

    function test_10_mlp_removeLiquidityForAccount_nonHandler_reverts() public {
        assertEq(mlpManager.isHandler(REWARDROUTER), true, "RewardRouter is the handler");
        assertEq(mlpManager.isHandler(ATTACKER), false, "attacker not handler");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("MlpManager: forbidden"));
        mlpManager.removeLiquidityForAccount(MLP_STAKER, USDC, 1e18, 0, ATTACKER);
    }

    function test_11_mlp_redemption_bricked_getAum_reverts() public {
        (bool ok, bytes memory data) = MLPMANAGER.staticcall(abi.encodeWithSignature("getAum(bool)", false));
        assertEq(ok, false, "getAum reverts");
        assertEq(data.length, 0, "empty revert = dead price feed, not a require string");

        assertEq(mlpManager.lastAddedAt(MLP_STAKER) + 900 < block.timestamp, true, "cooldown passed");
        vm.prank(REWARDROUTER);
        (bool ok2, bytes memory data2) =
            MLPMANAGER.call(abi.encodeWithSignature("removeLiquidityForAccount(address,address,uint256,uint256,address)", MLP_STAKER, USDC, 1e18, 0, MLP_STAKER));
        assertEq(ok2, false, "handler redeem reverts");
        assertEq(data2.length, 0, "empty revert = getAum/price feed");
    }

    // ------------------------------------------------------------------
    // E. RewardTracker (sMYC 2023) — no fresh-attacker capture of the 6.66 WETH
    // ------------------------------------------------------------------

    function test_12_rewardTracker_freshAccount_claim_zero() public {
        uint256 bal = IERC20(WETH).balanceOf(TRACKER2023);
        console.log("tracker2023 WETH balance", bal);
        vm.prank(ATTACKER);
        uint256 got = IRewardTracker(TRACKER2023).claim(ATTACKER);
        assertEq(got, 0, "fresh account claims nothing");
        assertEq(IRewardTracker(TRACKER2023).claimable(ATTACKER), 0, "claimable is zero");
    }

    function test_13_rewardTracker_stakeThenClaim_noPastCapture() public {
        assertEq(IRewardTracker(TRACKER2023).isDepositToken(MYC), true, "MYC is a deposit token");
        deal(MYC, ATTACKER, 100_000e18);
        vm.startPrank(ATTACKER);
        IERC20(MYC).approve(TRACKER2023, 100_000e18);
        IRewardTracker(TRACKER2023).stake(MYC, 100_000e18);
        uint256 got = IRewardTracker(TRACKER2023).claim(ATTACKER);
        vm.stopPrank();
        assertEq(got, 0, "stake-then-claim captures zero past rewards (paid=cumulative at stake)");
    }

    function test_14_rewardTracker_staker_canClaim_HO() public {
        uint256 claimable = IRewardTracker(TRACKER2023).claimable(SMYC_STAKER);
        assertGt(claimable, 0, "existing staker has claimable WETH");
        uint256 before = IERC20(WETH).balanceOf(SMYC_STAKER);
        vm.prank(SMYC_STAKER);
        uint256 got = IRewardTracker(TRACKER2023).claim(SMYC_STAKER);
        assertGt(got, 0, "claims accrued amount");
        assertApproxEqAbs(got, claimable, 1e13, "matches view (minus un-funded pending)");
        assertEq(IERC20(WETH).balanceOf(SMYC_STAKER) - before, got, "WETH received");
        console.log("sMYC staker claimed WETH", got);
    }

    function test_15_feeMlpTracker_staker_canClaim_HO() public {
        uint256 claimable = IRewardTracker(FEE_MLP_TRACKER).claimable(MLP_STAKER);
        assertGt(claimable, 0, "MLP staker has claimable WETH");
        vm.prank(MLP_STAKER);
        uint256 got = IRewardTracker(FEE_MLP_TRACKER).claim(MLP_STAKER);
        assertGt(got, 0, "claims accrued amount");
        assertApproxEqAbs(got, claimable, 1e13, "matches view (minus un-funded pending)");
        console.log("MLP staker claimed WETH", got);
    }

    // ------------------------------------------------------------------
    // F. Conditional path: FRAX is valued $1.00 by the vault (strict stable) but
    //    trades ~$0.99 -> drains the UNI pool (only unblocked output)
    // ------------------------------------------------------------------

    function test_16_frax_mispricing_not_extractable() public {
        // The vault values FRAX at exactly $1.00 (strict stable cap) while the market is ~$0.99
        uint256 fraxVaultMin = vault.getMinPrice(FRAX);
        uint256 fraxVaultMax = vault.getMaxPrice(FRAX);
        assertEq(fraxVaultMin, 1e30, "FRAX min = $1.00");
        assertEq(fraxVaultMax, 1e30, "FRAX max = $1.00");
        assertLt(FRAX_MKT_CONSERVATIVE, 1e30, "FRAX market below peg");

        // ...but every meaningful output is buffer-blocked, and the only unblocked
        // pools (UNI/FRAX/CRV) are dust, so the mispricing cannot be monetised.
        uint256 uniPool = vault.poolAmounts(UNI);
        uint256 uniMax = vault.getMaxPrice(UNI);
        console.log("UNI pool (max unblocked output)", uniPool);
        console.log("vault UNI max price (1e30)", uniMax);

        uint256 fraxIn = (uniPool * uniMax) / 1e30;
        deal(FRAX, ATTACKER, fraxIn);
        vm.startPrank(ATTACKER);
        IERC20(FRAX).transfer(VAULT, fraxIn);
        uint256 uniOut = vault.swap(FRAX, UNI, ATTACKER);
        vm.stopPrank();

        console.log("FRAX in (wei)", fraxIn);
        console.log("UNI out (after 20bps fee, wei)", uniOut);
        assertEq(IERC20(UNI).balanceOf(ATTACKER), uniOut, "UNI received");

        uint256 costUsd = (fraxIn * FRAX_MKT) / 1e18;
        uint256 valueUsd = (uniOut * UNI_MKT) / 1e18;
        console.log("cost USD (wei)", costUsd);
        console.log("value USD (wei)", valueUsd);
        console.log("gross edge USD (wei)", valueUsd > costUsd ? valueUsd - costUsd : 0);
        // whole extractable value is far below $0.001
        assertLt(valueUsd, 1e15, "max value extractable < $0.001");
    }

    // ------------------------------------------------------------------
    // G. Reward distributors — no further streaming (pots are static)
    // ------------------------------------------------------------------

    function test_17_distributors_empty_no_streaming() public {
        console.log("tracker2023 distributor WETH", IERC20(WETH).balanceOf(TRACKER2023_DIST));
        console.log("feeMlp distributor WETH", IERC20(WETH).balanceOf(UNSTAKED_MLP_DIST));
        assertEq(IERC20(WETH).balanceOf(TRACKER2023_DIST), 0, "no WETH left to stream");
        assertEq(IERC20(WETH).balanceOf(UNSTAKED_MLP_DIST), 0, "no WETH left to stream");
    }
}
