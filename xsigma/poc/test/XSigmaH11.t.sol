// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// H-11 xSigma live-state / extraction PoC  (read-only; fork tests only)
//
// Target: xSigma stablecoin DEX on Ethereum.
//   SigThreePoolProxy  0x3333333ACdEdBbC9Ad7bda0876e60714195681c5
//     -> delegatecalls Curve 3pool implementation 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
//   SIG-LP token       0x88E11412BB21d137C217fd8b73982Dc0ED3665d7 (Vyper, minter = pool)
//   SigMasterChef #2   0x98C32b59a0AC00Cd33750427b1A317eBcf84D0F7 (SIG#1, live)
//   SigMasterChef #1   0xF837AB93DB8D12a3557021281e5850f789302F78 (SIG#2, abandoned)
//   SIG#1              0x7777777777697cFEECF846A76326dA79CC606517
//   SIG#2              0x77777777778E9F1259A32f4d605aDDe67d576c79
//   PeriodicDutchAuction 0xb843B122ac2Ff261F425bf0F639b5718e25C0691
//
// Key live facts proven below:
//  1. Pool is live & functional (exchange/add/remove liquidity work).
//  2. LP holders can redeem their pro-rata (H-O). ~$313k is LP-owned.
//  3. withdraw_admin_fees() is BRICKED: the Solidity loop transfers USDT through a
//     bool-returning IERC20 interface; USDT returns no data -> ABI decode reverts.
//     The ~$3.95k accrued admin surplus can never be swept out by anyone.
//  4. The Dutch auction pays stablecoins ONLY for SIG#2 (24 tokens total, held by
//     an EOA). The auction holds $0 and its inflow path (3) is bricked.
//  5. ETH cashback (1 ETH) needs >=30 SIG#2 while total supply is 24 -> unreachable,
//     and availableCashbackEther() is ~1.96e8 wei anyway.
//  6. MasterChef#1 cumulative SIG#2 mint is not capturable by a new attacker; only a
//     slow future accrual (~0.8 SIG/day at 100% pool share) is, and SIG#2 has no sink.
//  7. All privileged paths revert for arbitrary callers; self-swap reverts (assert i != j).
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IPool {
    function coins(uint256) external view returns (address);
    function balances(uint256) external view returns (uint256);
    function fee() external view returns (uint256);
    function admin_fee() external view returns (uint256);
    function owner() external view returns (address);
    function admin_balances(uint256) external view returns (uint256);
    function get_dy(int128, int128, uint256) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function exchange(int128, int128, uint256, uint256) external;
    function add_liquidity(uint256[3] calldata, uint256) external;
    function remove_liquidity(uint256, uint256[3] calldata) external;
    function remove_liquidity_one_coin(uint256, int128, uint256) external;
    function calc_withdraw_one_coin(uint256, int128) external view returns (uint256);
    function withdraw_admin_fees() external;
    function donate_admin_fees() external;
    function kill_me() external;
    function changeAuction(address) external;
    function setCashbackEther(uint256, uint256, int256, int256) external payable;
    function availableCashbackEther(uint256) external view returns (uint256);
    function entitledCashbackEther(uint256) external view returns (uint256);
    function calcCashbackEther(int128, uint256, uint256) external view returns (uint256);
    function exchange2(int128, int128, uint256, uint256) external;
}

interface IMasterChef {
    function sushi() external view returns (address);
    function poolLength() external view returns (uint256);
    function poolInfo(uint256) external view returns (address, uint256, uint256, uint256);
    function userInfo(uint256, address) external view returns (uint256, uint256);
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function updatePool(uint256) external;
    function pendingSushi(uint256, address) external view returns (uint256);
    function changeFactor(uint256) external;
}

interface IAuction {
    function sigToken() external view returns (address);
    function coins(uint256) external view returns (address);
    function getSig1e18Price(uint256, uint256) external view returns (uint256);
    function sellSigForStablecoin(uint256, uint256, uint256) external;
    function setAuctionSettings(uint256, uint256, uint256, uint256) external;
}

contract XSigmaH11 is Test {
    address constant POOL   = 0x3333333ACdEdBbC9Ad7bda0876e60714195681c5;
    address constant LP     = 0x88E11412BB21d137C217fd8b73982Dc0ED3665d7;
    address constant MC2    = 0x98C32b59a0AC00Cd33750427b1A317eBcf84D0F7; // live, SIG#1
    address constant MC1    = 0xF837AB93DB8D12a3557021281e5850f789302F78; // abandoned, SIG#2
    address constant SIG1   = 0x7777777777697cFEECF846A76326dA79CC606517;
    address constant SIG2   = 0x77777777778E9F1259A32f4d605aDDe67d576c79;
    address constant AUCTION= 0xb843B122ac2Ff261F425bf0F639b5718e25C0691;
    address constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant SIG2_HOLDER = 0xF74d2ECa7A47e5e0348541e47E9C4532c2bD5628;

    IPool pool = IPool(POOL);
    IERC20 lp = IERC20(LP);
    IMasterChef mc1 = IMasterChef(MC1);
    IMasterChef mc2 = IMasterChef(MC2);
    IAuction auction = IAuction(AUCTION);

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        console2.log("fork block:", block.number);
    }

    // ---------------------------------------------------------------- 01
    function test_01_live_state() public view {
        uint256 dBal = IERC20(DAI).balanceOf(POOL);
        uint256 uBal = IERC20(USDC).balanceOf(POOL);
        uint256 tBal = IERC20(USDT).balanceOf(POOL);
        uint256 dInt = pool.balances(0);
        uint256 uInt = pool.balances(1);
        uint256 tInt = pool.balances(2);

        console2.log("actual DAI/USDC/USDT:", dBal / 1e18, uBal / 1e6, tBal / 1e6);
        console2.log("intern DAI/USDC/USDT:", dInt / 1e18, uInt / 1e6, tInt / 1e6);
        console2.log("surplus DAI:", (dBal - dInt) / 1e18);
        console2.log("surplus USDC:", (uBal - uInt) / 1e6);
        console2.log("surplus USDT:", (tBal - tInt) / 1e6);
        console2.log("LP totalSupply:", lp.totalSupply() / 1e18);
        console2.log("virtual price:", pool.get_virtual_price());
        console2.log("auction DAI/USDC/USDT:", IERC20(DAI).balanceOf(AUCTION), IERC20(USDC).balanceOf(AUCTION), IERC20(USDT).balanceOf(AUCTION));
        console2.log("SIG2 totalSupply:", IERC20(SIG2).totalSupply() / 1e18);
        console2.log("SIG2 holder bal:", IERC20(SIG2).balanceOf(SIG2_HOLDER) / 1e18);
        console2.log("pool ETH:", POOL.balance);

        // actual >= internal for all coins (admin surplus positive)
        assertGe(dBal, dInt);
        assertGe(uBal, uInt);
        assertGe(tBal, tInt);
        // surplus == computed admin_balances
        assertEq(dBal - dInt, pool.admin_balances(0));
        assertEq(uBal - uInt, pool.admin_balances(1));
        assertEq(tBal - tInt, pool.admin_balances(2));
        // auction empty
        assertEq(IERC20(DAI).balanceOf(AUCTION), 0);
        assertEq(IERC20(USDC).balanceOf(AUCTION), 0);
        assertEq(IERC20(USDT).balanceOf(AUCTION), 0);
        // SIG2 supply 24, all held by the EOA
        assertEq(IERC20(SIG2).totalSupply(), 24e18);
        assertEq(IERC20(SIG2).balanceOf(SIG2_HOLDER), 24e18);
        // LP minter storage slot 6 == pool
        assertEq(uint256(vm.load(LP, bytes32(uint256(6)))), uint256(uint160(POOL)));
        // ~1 ETH cashback locked in pool
        assertApproxEqAbs(POOL.balance, 1e18, 1e15);
    }

    // ---------------------------------------------------------------- 02
    function test_02_exchange_is_live() public {
        uint256 amount = 10_000e18;
        deal(DAI, attacker, amount);
        uint256 quote = pool.get_dy(0, 1, amount);
        assertGt(quote, 9_900e6);

        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, amount);
        uint256 before = IERC20(USDC).balanceOf(attacker);
        pool.exchange(0, 1, amount, 0);
        uint256 got = IERC20(USDC).balanceOf(attacker) - before;
        vm.stopPrank();

        // deployed get_dy is 1 wei optimistic vs exchange rounding; output matches within 2 wei
        assertApproxEqAbs(got, quote, 2);
        console2.log("exchange 10000 DAI -> USDC:", got);
        console2.log("get_dy quote:", quote);
        assertEq(IERC20(DAI).balanceOf(POOL), pool.balances(0) + pool.admin_balances(0));
    }

    // ---------------------------------------------------------------- 03
    function test_03_lp_holders_can_redeem_HO() public {
        // attacker obtains LP through the real deposit path
        deal(DAI, attacker, 1_000e18);
        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, 1_000e18);
        pool.add_liquidity([uint256(1_000e18), 0, 0], 0);
        uint256 lpBal = lp.balanceOf(attacker);
        vm.stopPrank();
        assertGt(lpBal, 800e18);
        console2.log("LP minted for 1000 DAI:", lpBal / 1e18);

        uint256 supply = lp.totalSupply();
        uint256 expDai = pool.balances(0) * lpBal / supply;
        uint256 dBefore = IERC20(DAI).balanceOf(attacker);

        vm.prank(attacker);
        pool.remove_liquidity(lpBal, [uint256(0), 0, 0]);

        uint256 gotDai = IERC20(DAI).balanceOf(attacker) - dBefore;
        assertApproxEqRel(gotDai, expDai, 0.001e18); // pro-rata of internal balances
        assertEq(lp.balanceOf(attacker), 0);
        console2.log("redeemed DAI:", gotDai / 1e18);
    }

    // ---------------------------------------------------------------- 04
    function test_04_withdraw_admin_fees_is_bricked_by_usdt() public {
        // 4a. live call reverts for anyone, incl. owner
        vm.prank(attacker);
        vm.expectRevert();
        pool.withdraw_admin_fees();

        vm.prank(pool.owner());
        vm.expectRevert();
        pool.withdraw_admin_fees();

        // 4b. proof of cause: zero the USDT surplus (only reachable via cheat/store,
        //     NOT by any attacker call) -> same function succeeds and pays the auction.
        uint256 usdtActual = IERC20(USDT).balanceOf(POOL);
        uint256 k1 = uint256(keccak256(abi.encode(uint256(1))));
        vm.store(POOL, bytes32(k1 + 2), bytes32(usdtActual));

        uint256 dAuc = IERC20(DAI).balanceOf(AUCTION);
        uint256 uAuc = IERC20(USDC).balanceOf(AUCTION);
        uint256 expDai = IERC20(DAI).balanceOf(POOL) - pool.balances(0);
        uint256 expUsdc = IERC20(USDC).balanceOf(POOL) - pool.balances(1);

        vm.prank(attacker);
        pool.withdraw_admin_fees();

        assertEq(IERC20(DAI).balanceOf(AUCTION) - dAuc, expDai);
        assertEq(IERC20(USDC).balanceOf(AUCTION) - uAuc, expUsdc);
        assertEq(IERC20(USDT).balanceOf(AUCTION), 0);
        console2.log("auction would receive DAI:", expDai / 1e18, "USDC:", expUsdc / 1e6);
    }

    // ---------------------------------------------------------------- 05
    function test_05_auction_pays_only_sig2() public {
        // no SIG2 -> nothing
        vm.prank(attacker);
        vm.expectRevert();
        auction.sellSigForStablecoin(1e18, 0, 0);

        // fund auction via the (cheat) USDT-surplus-zero trick from test 04
        uint256 usdtActual = IERC20(USDT).balanceOf(POOL);
        uint256 k1 = uint256(keccak256(abi.encode(uint256(1))));
        vm.store(POOL, bytes32(k1 + 2), bytes32(usdtActual));
        vm.prank(attacker);
        pool.withdraw_admin_fees();

        // give attacker SIG2 (only possible via store here; real supply 24 all at an EOA)
        uint256 balSlot = uint256(keccak256(abi.encode(attacker, uint256(0))));
        vm.store(SIG2, bytes32(balSlot), bytes32(uint256(12e18)));

        uint256 price = auction.getSig1e18Price(block.number, 0);
        uint256 dAuc = IERC20(DAI).balanceOf(AUCTION);
        console2.log("auction DAI:", dAuc / 1e18, "price(SIG in DAI):", price / 1e18);

        // sell at most 12 SIG2, and never more than the auction can pay
        uint256 sellSig = 12e18;
        uint256 needForAll = dAuc * 1e18 / price;
        if (needForAll < sellSig) sellSig = needForAll;
        uint256 expOut = sellSig * price / 1e18;
        assertGt(expOut, 0);

        vm.startPrank(attacker);
        IERC20(SIG2).approve(AUCTION, type(uint256).max);
        uint256 before = IERC20(DAI).balanceOf(attacker);
        auction.sellSigForStablecoin(sellSig, 0, 0);
        uint256 got = IERC20(DAI).balanceOf(attacker) - before;
        vm.stopPrank();

        assertEq(got, expOut);
        assertEq(IERC20(SIG2).balanceOf(attacker), 12e18 - sellSig); // burned
        console2.log("sold SIG2 -> DAI:", got / 1e18);
        console2.log("SIG2 has no other buyer: DEX pools hold SIG#1, not SIG#2");
    }

    // ---------------------------------------------------------------- 06
    function test_06_cashback_unreachable() public view {
        // 30 SIG2 needed; total supply is 24 -> impossible for any address
        assertLt(IERC20(SIG2).totalSupply(), 30e18);
        assertEq(pool.entitledCashbackEther(1 gwei), 0);
        uint256 avail = pool.availableCashbackEther(block.number);
        console2.log("availableCashbackEther (wei):", avail);
        assertLt(avail, 2e9); // ~1.2e9 wei = 0.0000000012 ETH
        // even a hypothetical 30-SIG2 holder would get <= avail/10 per trade
        assertLt(pool.calcCashbackEther(0, 1000e18, 1 gwei), 2e8);
    }

    // ---------------------------------------------------------------- 07
    function test_07_masterchef1_slow_mint_only() public {
        // get 1 wei LP via real deposit
        deal(DAI, attacker, 1_000e18);
        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, 1_000e18);
        pool.add_liquidity([uint256(1_000e18), 0, 0], 0);
        uint256 lpBal = lp.balanceOf(attacker);
        lp.approve(MC1, 1);
        mc1.deposit(0, 1); // first stake resets lastRewardBlock (lpSupply was 0)
        vm.stopPrank();

        // accrue 300k blocks (~41 days at 12s)
        vm.roll(block.number + 300_000);
        uint256 pending = mc1.pendingSushi(0, attacker);
        console2.log("pending SIG2 after 300k blocks:", pending / 1e18);

        vm.prank(attacker);
        mc1.withdraw(0, 1);
        uint256 got = IERC20(SIG2).balanceOf(attacker);
        assertApproxEqRel(got, pending, 0.01e18);
        assertGt(got, 10e18);
        assertLt(got, 100e18);
        console2.log("SIG2/day at 100% pool share (wei):", got * 7200 / 300000);
        console2.log("auction is empty and cannot be funded by the pool (see test 04)");
    }

    // ---------------------------------------------------------------- 08
    function test_08_masterchef1_cumulative_mint_uncapturable() public {
        deal(DAI, attacker, 1_000e18);
        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, 1_000e18);
        pool.add_liquidity([uint256(1_000e18), 0, 0], 0);
        lp.transfer(MC1, 1); // donation: lpSupply=1 wei, lastRewardBlock stays old (2021)
        mc1.updatePool(0);   // huge cumulative mint: 60% to MC1, 10% dev, 30% vault
        vm.stopPrank();

        uint256 mcSig = IERC20(SIG2).balanceOf(MC1);
        uint256 pending = mc1.pendingSushi(0, attacker);
        console2.log("MC1 SIG2 after cumulative mint:", mcSig / 1e18);
        console2.log("attacker pending (no stake):", pending);
        assertGt(mcSig, 1_000_000e18); // >1M SIG2 minted
        assertEq(pending, 0);          // not capturable by a fresh address

        // even after depositing, past rewards are unreachable
        vm.startPrank(attacker);
        lp.approve(MC1, 1);
        mc1.deposit(0, 1);
        uint256 before = IERC20(SIG2).balanceOf(attacker);
        mc1.withdraw(0, 1);
        assertEq(IERC20(SIG2).balanceOf(attacker) - before, 0);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 09
    function test_09_privileged_paths_revert_for_attacker() public {
        vm.startPrank(attacker);
        vm.expectRevert(); pool.donate_admin_fees();
        vm.expectRevert(); pool.kill_me();
        vm.expectRevert(); pool.changeAuction(attacker);
        vm.expectRevert(); pool.setCashbackEther(1, 2, 1, 1);
        vm.expectRevert(); mc1.changeFactor(1);
        vm.expectRevert(); auction.setAuctionSettings(1, 1, 1, 1);
        vm.stopPrank();

        // LP token mint / set_minter are minter-gated (minter = pool)
        vm.startPrank(attacker);
        (bool ok,) = LP.call(abi.encodeWithSignature("mint(address,uint256)", attacker, 1));
        assertFalse(ok);
        (ok,) = LP.call(abi.encodeWithSignature("set_minter(address)", attacker));
        assertFalse(ok);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 10
    function test_10_self_swap_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        pool.exchange(0, 0, 1e18, 0);
    }

    // ---------------------------------------------------------------- 11
    function test_11_arb_negligible() public view {
        uint256 dx = 1_000e6; // 1000 USDC
        uint256 out = pool.get_dy(1, 2, dx); // USDC -> USDT
        uint256 back = pool.get_dy(2, 1, out); // round trip
        console2.log("1000 USDC -> USDT:", out);
        console2.log("round-trip back to USDC:", back);
        assertGt(out, dx);
        assertLt(out - dx, 0.1e6); // best gain < $0.10
        assertLt(back, dx);        // round trip loses (fees)
    }

    // ---------------------------------------------------------------- 12
    function test_12_masterchef2_principal_safe() public {
        // non-staker cannot withdraw anything
        vm.prank(attacker);
        vm.expectRevert();
        mc2.withdraw(0, 1);

        // real staker accounting: deposit then emergencyWithdraw returns exactly own LP
        deal(DAI, attacker, 1_000e18);
        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, 1_000e18);
        pool.add_liquidity([uint256(1_000e18), 0, 0], 0);
        uint256 lpBal = lp.balanceOf(attacker);
        lp.approve(MC2, lpBal);
        mc2.deposit(0, lpBal);
        (uint256 amt,) = mc2.userInfo(0, attacker);
        assertEq(amt, lpBal);
        mc2.emergencyWithdraw(0);
        assertEq(lp.balanceOf(attacker), lpBal);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 13
    function test_13_surplus_cannot_be_zeroed_by_trading() public {
        // (a) DAI -> USDT trade (USDT as output, exercises raw_call USDT transfer):
        //     the USDT admin surplus only grows, it can never be zeroed -> the
        //     withdraw_admin_fees() USDT leg stays blocked forever.
        uint256 tBefore = IERC20(USDT).balanceOf(POOL) - pool.balances(2);
        deal(DAI, attacker, 1_000e18);
        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, 1_000e18);
        pool.exchange(0, 2, 1_000e18, 0);
        vm.stopPrank();
        uint256 tAfter = IERC20(USDT).balanceOf(POOL) - pool.balances(2);
        console2.log("USDT surplus before/after DAI->USDT trade:", tBefore, tAfter);
        assertGe(tAfter, tBefore);

        // (b) USDC -> DAI trade: USDC surplus also non-decreasing
        uint256 uBefore = IERC20(USDC).balanceOf(POOL) - pool.balances(1);
        deal(USDC, attacker, 1_000e6);
        vm.startPrank(attacker);
        IERC20(USDC).approve(POOL, 1_000e6);
        pool.exchange(1, 0, 1_000e6, 0);
        vm.stopPrank();
        uint256 uAfter = IERC20(USDC).balanceOf(POOL) - pool.balances(1);
        assertGe(uAfter, uBefore);
    }
}
