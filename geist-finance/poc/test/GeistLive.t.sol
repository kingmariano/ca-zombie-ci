// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GeistInterfaces.sol";

/// @title Geist Finance (Fantom) live-state + extractability PoC
/// @notice Read-only against a fork. No mainnet transactions are ever sent.
contract GeistLiveTest is Test {
    address constant POOL = 0x9FAD24f572045c7869117160A571B2e50b10d068;
    address constant PROVIDER = 0x6c793c628Fe2b480c5e6FB7957dDa4b9291F9c9b;
    address constant ORACLE = 0xC466e3FeE82C6bdc2E17f2eaF2c6F1E91AD10FD3;
    address constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address constant SPOOKY_ROUTER = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address constant GEIST = 0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d;
    address constant STAKING = 0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8;

    // reserve assets (index order from getReservesList)
    address[9] ASSETS = [
        0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E, // DAI
        0x74b23882a30290451A17c44f4F05243b6b58C76d, // ETH
        0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83, // WFTM
        0x321162Cd933E2Be498Cd2267a90534A804051b11, // BTC
        0x049d68029688eAbF473097a2fC38ef61633A3C7A, // fUSDT
        0x04068DA6C83AFCFA0e13ba15A6696662335D5B75, // USDC
        0x1E4F97b9f9F913c46F1632781732927B9019C68b, // CRV
        0x82f0B8B456c1A451378467398982d4834b6829c1, // MIM
        0xb3654dc3D10Ea7645f8319668E8F54d2574FBdC8  // LINK
    ];
    function sym(uint256 i) internal pure returns (string memory) {
        string[9] memory s = ["DAI", "ETH", "WFTM", "BTC", "fUSDT", "USDC", "CRV", "MIM", "LINK"];
        return s[i];
    }

    function _selectFork() internal returns (uint256) {
        string[4] memory urls = [
            vm.envOr("FANTOM_RPC_URL", string("")),
            "https://rpcapi.fantom.network",
            "https://fantom.drpc.org",
            "https://1rpc.io/ftm"
        ];
        for (uint256 i = 0; i < urls.length; i++) {
            if (bytes(urls[i]).length == 0) continue;
            try vm.createSelectFork(urls[i]) returns (uint256 blk) {
                return blk;
            } catch {}
        }
        revert("no working fantom fork rpc");
    }

    function setUp() public {
        _selectFork();
        emit log_named_uint("fork block", block.number);
    }

    // ---------------------------------------------------------------- state

    function test_live_state() public {
        ILendingPool pool = ILendingPool(POOL);
        assertEq(pool.paused(), false, "pool paused?");

        address[] memory list = pool.getReservesList();
        assertEq(list.length, 9, "9 reserves");
        for (uint256 i = 0; i < list.length; i++) {
            ReserveData memory rd = pool.getReserveData(list[i]);
            IAToken a = IAToken(rd.aTokenAddress);
            uint256 cash = IERC20(list[i]).balanceOf(rd.aTokenAddress);
            emit log_named_string("reserve", sym(i));
            emit log_named_uint("  liquidityIndex(ray)", rd.liquidityIndex);
            emit log_named_uint("  aTokenSupply", a.totalSupply());
            emit log_named_uint("  aTokenCash", cash);
            emit log_named_uint("  vDebtSupply", IVariableDebtToken(rd.variableDebtTokenAddress).totalSupply());
            emit log_named_uint("  oraclePrice(1e18)", IPriceOracleGetter(ORACLE).getAssetPrice(list[i]));
            emit log_named_uint("  config", rd.configuration.data);
        }
        // all reserves frozen (bit 57) => repay/withdraw/liquidate-only mode
        for (uint256 i = 0; i < list.length; i++) {
            uint256 cfg = pool.getReserveData(list[i]).configuration.data;
            assertEq((cfg >> 57) & 1, 1, "reserve frozen");
            assertEq((cfg >> 56) & 1, 1, "reserve active");
        }
    }

    function test_oracle_is_frozen() public {
        // every price feed must return its stored lastGoodPrice (Chainlink dead, Band frozen)
        for (uint256 i = 0; i < ASSETS.length; i++) {
            address feed = IAaveOracle(ORACLE).getSourceOfAsset(ASSETS[i]);
            uint256 fetch = IPriceFeed(feed).fetchPrice();
            uint256 lgp = IPriceFeed(feed).lastGoodPrice();
            emit log_named_string("feed for", sym(i));
            emit log_named_uint("  fetchPrice", fetch);
            emit log_named_uint("  lastGoodPrice", lgp);
            emit log_named_uint("  status", IPriceFeed(feed).status());
            assertEq(fetch, lgp, "fetchPrice != lastGoodPrice (oracle live?)");
        }
    }

    function test_oracle_cannot_be_refreshed_by_attacker() public {
        // updatePrice() is permissionless; show it cannot move the price
        for (uint256 i = 0; i < ASSETS.length; i++) {
            address feed = IAaveOracle(ORACLE).getSourceOfAsset(ASSETS[i]);
            uint256 before = IPriceFeed(feed).fetchPrice();
            uint256 afterUpd = IPriceFeed(feed).updatePrice();
            emit log_named_string("updatePrice no-op for", sym(i));
            emit log_named_uint("  before", before);
            emit log_named_uint("  after", afterUpd);
            assertEq(afterUpd, before, "oracle price moved by updatePrice!");
        }
    }

    // ------------------------------------------------- negative: no free withdrawal

    function test_fresh_attacker_cannot_withdraw() public {
        address attacker = makeAddr("attacker");
        // no aTokens, no deposits: withdraw must revert
        vm.startPrank(attacker);
        vm.expectRevert();
        ILendingPool(POOL).withdraw(ASSETS[8], 1e18, attacker);
        vm.stopPrank();
    }

    function test_fresh_attacker_cannot_redeem_aTokens() public {
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        vm.expectRevert();
        IAToken(0xBeCF29265B0cc8D33fA24446599955C7bcF7F73B).redeem(1e18); // aLINK
        vm.stopPrank();
    }

    /// H-O check: an actual aToken holder (the Geist staking contract, which holds
    /// treasury aLINK) can withdraw its claim up to the available cash.
    function test_holder_can_withdraw_its_aTokens() public {
        IAToken aLink = IAToken(0xBeCF29265B0cc8D33fA24446599955C7bcF7F73B);
        uint256 bal = aLink.balanceOf(STAKING);
        emit log_named_uint("staking aLINK balance", bal);
        assertGt(bal, 0, "staking has aLINK");
        uint256 linkBefore = IERC20(ASSETS[8]).balanceOf(STAKING);
        vm.prank(STAKING);
        uint256 got = ILendingPool(POOL).withdraw(ASSETS[8], bal, STAKING);
        uint256 linkAfter = IERC20(ASSETS[8]).balanceOf(STAKING);
        emit log_named_uint("withdrew LINK", got);
        assertEq(linkAfter - linkBefore, got, "underlying received");
        assertEq(got, bal, "1:1 redemption (cash sufficient)");
    }

    /// S check: the WFTM market has zero cash, so even the treasury cannot redeem aWFTM.
    function test_wftm_market_is_unbacked() public {
        IAToken aWftm = IAToken(0x39B3bd37208CBaDE74D0fcBDBb12D606295b430a);
        assertEq(IERC20(WFTM).balanceOf(address(aWftm)), 0, "aWFTM cash is zero");
        uint256 bal = aWftm.balanceOf(0x0F595677AfC5F4A99Cfa1dDB4a00B8f54Cfda506);
        assertGt(bal, 0, "wftm treasury holds aWFTM");
        vm.prank(0x0F595677AfC5F4A99Cfa1dDB4a00B8f54Cfda506);
        vm.expectRevert();
        ILendingPool(POOL).withdraw(WFTM, bal, 0x0F595677AfC5F4A99Cfa1dDB4a00B8f54Cfda506);
    }

    // ------------------------------------------------- realizable value via real DEX

    function test_realizable_cash_via_spooky() public {
        // For each reserve, measure how much WFTM the whole aToken cash actually buys
        // on the live SpookySwap pool (path asset -> WFTM). This is the honest
        // "what can an attacker actually sell the cash for" number.
        ILendingPool pool = ILendingPool(POOL);
        address[] memory list = pool.getReservesList();
        uint256 totalWftm;
        for (uint256 i = 0; i < list.length; i++) {
            ReserveData memory rd = pool.getReserveData(list[i]);
            uint256 cash = IERC20(list[i]).balanceOf(rd.aTokenAddress);
            if (cash == 0) continue;
            address[] memory path = new address[](2);
            path[0] = list[i];
            path[1] = WFTM;
            uint256 out;
            try IUniswapV2Router(SPOOKY_ROUTER).getAmountsOut(cash, path) returns (uint256[] memory amts) {
                out = amts[amts.length - 1];
            } catch {
                out = 0;
            }
            emit log_named_string("cash sellable", sym(i));
            emit log_named_uint("  cash (token units)", cash);
            emit log_named_uint("  -> WFTM out (whole cash)", out);
            totalWftm += out;
        }
        emit log_named_uint("TOTAL WFTM out for all cash", totalWftm);
        emit log_named_uint("WFTM usd approx (1e18=1usd*1e18/0.0684)", totalWftm);
    }

    // ------------------------------------------------- staking rewards are not free

    function test_fresh_staker_rewards_are_dust() public {
        address attacker = makeAddr("attacker");
        // buy a meaningful GEIST amount on the live pool: 20000 WFTM -> GEIST
        deal(WFTM, attacker, 20_000e18);
        vm.startPrank(attacker);
        IERC20(WFTM).approve(SPOOKY_ROUTER, 20_000e18);
        address[] memory path = new address[](2);
        path[0] = WFTM;
        path[1] = GEIST;
        uint256[] memory amounts =
            IUniswapV2Router(SPOOKY_ROUTER).swapExactTokensForTokens(20_000e18, 0, path, attacker, block.timestamp);
        uint256 geistBought = amounts[1];
        emit log_named_uint("GEIST bought for 20000 WFTM", geistBought);

        IERC20(GEIST).approve(STAKING, geistBought);
        IMultiFeeDistribution(STAKING).stake(geistBought, false);
        // advance one week so any active stream fully accrues
        vm.warp(block.timestamp + 7 days);
        IMultiFeeDistribution.RewardData[] memory rw =
            IMultiFeeDistribution(STAKING).claimableRewards(attacker);
        uint256 n = rw.length;
        emit log_named_uint("reward tokens", n);
        for (uint256 i = 0; i < n; i++) {
            emit log_named_address("  reward token", rw[i].token);
            emit log_named_uint("  claimable", rw[i].amount);
        }
        vm.stopPrank();
    }
}
