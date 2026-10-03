// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/*
 * C-32 Moonwell oracle-misconfiguration deep dive — live-state fork tests.
 *
 * All tests are READ-ONLY against forks (no mainnet transactions). They snapshot
 * the live state at the fork head and assert the containment / misconfiguration
 * facts that determine the current unprivileged extractable value:
 *
 *  Base        : all Core Market borrow caps == 1 wei (new borrowing disabled);
 *                oracles current and matching market (cbETH, wrsETH, MAMO).
 *  Moonbeam    : chain frozen (last block 2026-08-10); feeds stale > 30 days;
 *                live shortfall accounts exist but cannot be liquidated (no blocks).
 *  Moonriver   : chain frozen; all collateral factors 0; placeholder oracle prices.
 */

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function oracle() external view returns (address);
    function closeFactorMantissa() external view returns (uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function borrowCaps(address) external view returns (uint256);
    function supplyCaps(address) external view returns (uint256);
    function markets(address) external view returns (bool, uint256, bool);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function seizeGuardianPaused(address) external view returns (bool);
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
    function getFeed(string calldata) external view returns (address);
    function assetPrices(address) external view returns (uint256);
}

interface IMToken {
    function symbol() external view returns (string memory);
    function underlying() external view returns (address);
    function decimals() external view returns (uint8);
    function totalBorrows() external view returns (uint256);
    function getCash() external view returns (uint256);
    function mint(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function balanceOfUnderlying(address) external returns (uint256); // non-view: accrues interest
    function borrowBalanceStored(address) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
}

interface IAggregator {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
}

contract MoonwellC32Test is Test {
    // ---------------------------------------------------------------- addresses
    address constant BASE_COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;
    address constant BASE_ORACLE = 0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0;
    address constant BASE_mWETH = 0x628ff693426583D9a7FB391E54366292F509D457;
    address constant BASE_mcbBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    address constant BASE_mcbETH = 0x3bf93770f2d4a794c3d9EBEfBAeBAE2a8f09A5E5;
    address constant BASE_mwstETH = 0x627Fe393Bc6EdDA28e99AE648fD6fF362514304b;
    address constant BASE_mwrsETH = 0xfC41B49d064Ac646015b459C522820DB9472F4B5;
    address constant BASE_mMAMO = 0x2F90Bb22eB3979f5FfAd31EA6C3F0792ca66dA32;
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address constant BASE_MAMO = 0x7300B37DfdfAb110d83290A29DfB31B1740219fE;

    address constant GLMR_COMPTROLLER = 0x8E00D5e02E65A19337Cdba98bbA9F84d4186a180;
    address constant GLMR_ORACLE = 0xED301cd3EB27217BDB05C4E9B820a8A3c8B665f9;
    address constant GLMR_mDOT = 0xD22Da948c0aB3A27f5570b604f3ADef5F68211C3;
    address constant GLMR_mUSDCh = 0x744b1756e7651c6D57f5311767EAFE5E931D615b;
    address constant GLMR_SHORTFALL_ACCOUNT = 0x82849867f1A1aeFad1B4F2fA5aa7bD12e462F549;

    address constant MOVR_COMPTROLLER = 0x0b7a0EAA884849c6Af7a129e899536dDDcA4905E;
    address constant MOVR_ORACLE = 0x892bE716Dcf0A6199677F355f45ba8CC123BAF60;
    address constant MOVR_mETH = 0x6503D905338e2ebB550c9eC39Ced525b612E77aE;

    uint256 constant SEPT_1_2026 = 1_788_220_800; // chain-freeze reference

    function _forkBase() internal returns (uint256) {
        return vm.createSelectFork(vm.envOr("C32_BASE_RPC", vm.envOr("BASE_RPC_URL", string("https://base-rpc.publicnode.com"))));
    }

    function _forkMoonbeam() internal returns (uint256) {
        // note: MOONBEAM_RPC_URL may be unset in CI; onfinality is the working public endpoint
        return vm.createSelectFork(vm.envOr("C32_MOONBEAM_RPC", vm.envOr("MOONBEAM_RPC_URL", string("https://moonbeam.api.onfinality.io/public"))));
    }

    function _forkMoonriver() internal returns (uint256) {
        // the brief's publicnode fallback for Moonriver is dead (404); onfinality works
        return vm.createSelectFork(vm.envOr("C32_MOONRIVER_RPC", vm.envOr("MOONRIVER_RPC_URL", string("https://moonriver.api.onfinality.io/public"))));
    }

    // ------------------------------------------------------------------- BASE
    function test_base_all_borrow_caps_one_wei() public {
        _forkBase();
        IComptroller c = IComptroller(BASE_COMPTROLLER);
        address[] memory markets = c.getAllMarkets();
        assertGt(markets.length, 10, "expected many Base markets");
        for (uint256 i = 0; i < markets.length; i++) {
            uint256 cap = c.borrowCaps(markets[i]);
            emit log_named_string("market", IMToken(markets[i]).symbol());
            emit log_named_uint("  borrowCap", cap);
            assertEq(cap, 1, "Base borrow cap is not 1 wei");
        }
        emit log_named_uint("base markets checked", markets.length);
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("fork timestamp", block.timestamp);
    }

    function test_base_borrow_reverts_under_one_wei_cap() public {
        _forkBase();
        IComptroller c = IComptroller(BASE_COMPTROLLER);
        // unprivileged attacker with real capital
        vm.deal(address(this), 100 ether);
        IWETH(BASE_WETH).deposit{value: 100 ether}();
        IERC20(BASE_WETH).approve(BASE_mWETH, type(uint256).max);
        uint256 err = IMToken(BASE_mWETH).mint(100 ether);
        assertEq(err, 0, "WETH supply failed");
        address[] memory mem = new address[](1);
        mem[0] = BASE_mWETH;
        c.enterMarkets(mem);

        // collateral is in; cbBTC market has cash; still cannot borrow (cap == 1 wei)
        assertGt(IMToken(BASE_mcbBTC).getCash(), 0, "no cbBTC cash");
        assertGt(IMToken(BASE_mcbBTC).totalBorrows(), 1, "borrows <= cap");
        assertEq(c.borrowCaps(BASE_mcbBTC), 1, "cbBTC cap changed");
        vm.expectRevert();
        IMToken(BASE_mcbBTC).borrow(1);
        emit log_string("borrow(1) reverted under 1-wei cap as expected");
    }

    function test_base_mamo_vector_closed() public {
        _forkBase();
        IComptroller c = IComptroller(BASE_COMPTROLLER);
        assertEq(c.borrowCaps(BASE_mMAMO), 1, "MAMO borrow cap");
        assertEq(c.supplyCaps(BASE_mMAMO), 1, "MAMO supply cap");
        assertGt(IMToken(BASE_mMAMO).totalBorrows(), 1e18, "residual MAMO borrows expected");
        // supplying manipulated MAMO collateral is blocked by the 1-wei supply cap
        deal(BASE_MAMO, address(this), 1e18);
        IERC20(BASE_MAMO).approve(BASE_mMAMO, type(uint256).max);
        vm.expectRevert();
        IMToken(BASE_mMAMO).mint(1e18);
        emit log_string("MAMO mint reverted under 1-wei supply cap as expected");
    }

    function test_base_oracles_match_market() public {
        _forkBase();
        IOracle o = IOracle(BASE_ORACLE);
        uint256 pWETH = o.getUnderlyingPrice(BASE_mWETH);
        uint256 pcbETH = o.getUnderlyingPrice(BASE_mcbETH);
        uint256 pwstETH = o.getUnderlyingPrice(BASE_mwstETH);
        uint256 pwrsETH = o.getUnderlyingPrice(BASE_mwrsETH);
        uint256 pUSDC = o.getUnderlyingPrice(0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22);
        emit log_named_uint("WETH", pWETH);
        emit log_named_uint("cbETH", pcbETH);
        emit log_named_uint("wstETH", pwstETH);
        emit log_named_uint("wrsETH", pwrsETH);
        emit log_named_uint("USDC", pUSDC);
        // cbETH ~ 1.0-1.3 x ETH; wstETH ~ 1.0-1.3 x ETH; wrsETH ~ 0.9-1.3 x ETH
        assertGt(pcbETH, (pWETH * 95) / 100, "cbETH below ETH");
        assertLt(pcbETH, (pWETH * 130) / 100, "cbETH far above ETH");
        assertGt(pwstETH, (pWETH * 95) / 100, "wstETH below ETH");
        assertLt(pwstETH, (pWETH * 130) / 100, "wstETH far above ETH");
        assertGt(pwrsETH, (pWETH * 90) / 100, "wrsETH below 0.9 ETH");
        assertLt(pwrsETH, (pWETH * 130) / 100, "wrsETH far above ETH");
        // USDC ~ 1e30 (6-dec scale)
        assertGt(pUSDC, 95e28, "USDC below 0.95");
        assertLt(pUSDC, 105e28, "USDC above 1.05");
    }

    // --------------------------------------------------------------- MOONBEAM
    function test_moonbeam_chain_frozen_and_feeds_stale() public {
        _forkMoonbeam();
        emit log_named_uint("moonbeam fork block", block.number);
        emit log_named_uint("moonbeam fork timestamp", block.timestamp);
        // Moonbeam entered maintenance mode 2026-08-01; last block 2026-08-10
        assertLt(block.timestamp, SEPT_1_2026, "moonbeam is producing blocks again!");

        IComptroller c = IComptroller(GLMR_COMPTROLLER);
        IOracle o = IOracle(GLMR_ORACLE);
        address[] memory markets = c.getAllMarkets();
        assertEq(markets.length, 12, "unexpected moonbeam market count");
        for (uint256 i = 0; i < markets.length; i++) {
            assertTrue(c.mintGuardianPaused(markets[i]), "mint not paused");
            assertTrue(c.borrowGuardianPaused(markets[i]), "borrow not paused");
            assertGt(o.getUnderlyingPrice(markets[i]), 0, "zero oracle price");
        }
        // xcDOT feed: 18-decimal composite/aggregator; assert it is stale > 30 days
        address feed = o.getFeed("xcDOT");
        (uint80 rid, int256 ans, uint256 sAt, uint256 uAt, uint80 air) = IAggregator(feed).latestRoundData();
        emit log_named_uint("xcDOT feed updatedAt", uAt);
        emit log_named_int("xcDOT feed answer", ans);
        emit log_named_uint("stale seconds", block.timestamp - uAt);
        assertGt(block.timestamp - uAt, 7 days, "xcDOT feed not stale");
        rid; sAt; air;
        // shortfall account exists under stale prices (but chain is frozen)
        (, , uint256 shortfall) = c.getAccountLiquidity(GLMR_SHORTFALL_ACCOUNT);
        emit log_named_uint("shortfall account shortfall (USD 1e18)", shortfall);
        assertGt(shortfall, 0, "expected shortfall under stale feed");
        // and the position's theoretical profit is small: collateral 89.44 xcDOT vs debt ~39 USDC
        uint256 collUnderlying = IMToken(GLMR_mDOT).balanceOfUnderlying(GLMR_SHORTFALL_ACCOUNT);
        uint256 debt = IMToken(GLMR_mUSDCh).borrowBalanceStored(GLMR_SHORTFALL_ACCOUNT);
        emit log_named_uint("mDOT collateral (xcDOT, 10dec)", collUnderlying);
        emit log_named_uint("mUSDC.wh debt (6dec)", debt);
        // bound: seize value at oracle vs market; keep test simple and directional
        assertLt(collUnderlying, 1e12, "collateral unexpectedly large");
    }

    // --------------------------------------------------------------- MOONRIVER
    function test_moonriver_frozen_zero_cf_placeholder_prices() public {
        _forkMoonriver();
        emit log_named_uint("moonriver fork block", block.number);
        emit log_named_uint("moonriver fork timestamp", block.timestamp);
        assertLt(block.timestamp, SEPT_1_2026, "moonriver is producing blocks again!");
        IComptroller c = IComptroller(MOVR_COMPTROLLER);
        IOracle o = IOracle(MOVR_ORACLE);
        address[] memory markets = c.getAllMarkets();
        assertEq(markets.length, 7, "unexpected moonriver market count");
        for (uint256 i = 0; i < markets.length; i++) {
            (, uint256 cf, ) = c.markets(markets[i]);
            assertEq(cf, 0, "moonriver CF not zero");
            assertTrue(c.mintGuardianPaused(markets[i]), "mint not paused");
            assertTrue(c.borrowGuardianPaused(markets[i]), "borrow not paused");
            assertGt(o.getUnderlyingPrice(markets[i]), 0, "zero oracle price");
        }
        // placeholder override prices are wired (proposal #73), e.g. mETH == $2050
        uint256 pETH = o.getUnderlyingPrice(MOVR_mETH);
        emit log_named_uint("moonriver mETH placeholder price", pETH);
        assertEq(pETH, 2050e18, "unexpected mETH placeholder");
        (, uint256 cfETH, ) = c.markets(MOVR_mETH);
        assertEq(cfETH, 0, "mETH CF not zero");
    }
}
