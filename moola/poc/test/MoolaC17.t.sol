// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ILendingPool, ILendingPoolAddressesProvider, ILendingPoolConfigurator,
        IMoolaOracle, ICeloProxyPriceProvider, ISortedOraclesPriceFeed, IFixedPriceOracle,
        ISortedOracles, IRegistry, IAToken, DataTypes} from "../src/IMoola.sol";
import {TestFlashLoanReceiver} from "../src/TestFlashLoanReceiver.sol";

/// C2-17 · Moola Market (Celo) — live extractability boundary tests.
/// Read-only mainnet state; all execution happens on a local fork at a pinned
/// block. No mainnet transactions are ever sent.
contract MoolaC17Test is Test {
    // ---- live Celo mainnet addresses ----
    address constant POOL        = 0x970b12522CA9b4054807a2c5B736149a5BE6f670;
    address constant PROVIDER    = 0xD1088091A174d33412a968Fa34Cb67131188B332;
    address constant ORACLE      = 0xBa2224905Ad3CDbA6c1b764CD62FDa52bd524d29;
    address constant CONFIGURATOR= 0x928F63a83217e427A84504950206834CBDa4Aa65;
    address constant CELO        = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    address constant CUSD        = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant CEUR        = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address constant CREAL       = 0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787;
    address constant MOO         = 0x17700282592D6917F6A73D0bF8AcCf4D578c131e;
    address constant aCELO       = 0x7D00cd74FF385c955EA3d79e47BF06bD7386387D;
    address constant aCUSD       = 0x918146359264C492BD6934071c6Bd31C854EDBc3;
    address constant aMOO        = 0x3A5024E3AAB31A1d3184127B52b0e4B4E9ADcC34;
    address constant vCELO       = 0xAF451D23d6f0FA680113CE2D27a891Aa3587f0C3;
    address constant CELO_PROXY  = 0x9F9037cE8deB6e8EF3045aD5C1a31D93895446C4;
    address constant FEED_CUSD   = 0x67Cf66ece8e5aD2D30c1B88c770CdE2e3eE811D6;
    address constant FEED_CEUR   = 0x559Ea867FC19798cA167797A02aC4cf3fAbf465c;
    address constant FEED_CREAL  = 0x0a4FF58100A2a0117cC291E375189cCbcb924551;
    address constant FIXED_MOO   = 0x321429d18C75C166d7ad5E684877C31Eb489bD50;
    address constant FALLBACK    = 0xb13F9Fb45B2E4446EF0047CBB2b9Dee269162309;
    address constant REGISTRY    = 0x000000000000000000000000000000000000ce10;
    address constant SORTED_ORACLES = 0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33;
    address constant POOL_ADMIN  = 0x313bc86D3D6e86ba164B2B451cB0D9CfA7943e5c;
    address constant EMERGENCY_ADMIN = 0x643C574128c7C56A1835e021Ad0EcC2592E72624;

    // under-collateralised target found by the off-chain census
    address constant LIQ_TARGET  = 0x7c980b8C8311dCf2Ca3515A7099e3687f56D46d4;
    // large, healthy borrowers (not liquidatable)
    address constant WHALE_1     = 0xF67973E1ed409b4f31d42244Bc7Ad973F701Fd7E;
    address constant WHALE_2     = 0x2BfFd70b9b7246967357228688Ba28c75F482bc5;

    uint256 constant FORK_BLOCK = 79_583_113;

    ILendingPool pool;
    IMoolaOracle oracle;
    ILendingPoolAddressesProvider provider;

    function setUp() public {
        string memory rpc = vm.envOr("CELO_RPC_URL", string("https://forno.celo.org"));
        vm.createSelectFork(rpc, FORK_BLOCK);
        pool = ILendingPool(POOL);
        oracle = IMoolaOracle(ORACLE);
        provider = ILendingPoolAddressesProvider(PROVIDER);
    }

    // ---------------------------------------------------------------- state

    function test_pool_live_state_pinned() public {
        assertEq(pool.paused(), false, "pool must be unpaused");
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 1, "flashloan premium = 1bp");
        address[] memory list = pool.getReservesList();
        assertEq(list.length, 5, "5 reserves");
        assertEq(list[0], CELO);
        assertEq(list[1], CUSD);
        assertEq(list[2], CEUR);
        assertEq(list[3], CREAL);
        assertEq(list[4], MOO);

        // roles
        assertEq(provider.getPoolAdmin(), POOL_ADMIN);
        assertEq(provider.getEmergencyAdmin(), EMERGENCY_ADMIN);
        assertEq(provider.owner(), POOL_ADMIN);
        assertEq(provider.getPriceOracle(), ORACLE);
        assertEq(provider.getLendingPoolCollateralManager(), 0xa2Db2e70A795B566F129ae7Dff242a4AD1393B32);

        // CELO reserve — anomalous liquidity index < 1 (historical write-down),
        // borrow index > 1, cash + debt == aToken claims
        DataTypes.ReserveData memory r = pool.getReserveData(CELO);
        assertEq(uint256(r.liquidityIndex), 919744944634535603956668469);
        assertEq(uint256(r.variableBorrowIndex), 1036164995650221152435708043);
        assertLt(uint256(r.liquidityIndex), 1e27, "CELO liq index below 1");
        assertEq(_cfg(r), uint256(0x3e8051229041b581964)); // LTV 65 / thr 70 / bonus 105 / rf 10
        assertEq(IERC20(CELO).balanceOf(aCELO), 4841063591887344534425723);
        assertEq(IERC20(aCELO).totalSupply(), 4970192513047744285913061);
        assertEq(IERC20(vCELO).totalSupply(), 129126846742215065569374);

        // cUSD reserve
        r = pool.getReserveData(CUSD);
        assertEq(_cfg(r), uint256(0x3e8051229041f401d4c)); // LTV 75 / thr 80 / bonus 105 / rf 10
        assertEq(uint256(r.liquidityIndex), 1140311864201178296801478259);
        assertEq(IERC20(CUSD).balanceOf(aCUSD), 400820049990577513956874);

        // cEUR reserve
        r = pool.getReserveData(CEUR);
        assertEq(_cfg(r), uint256(0x3e805122af813881194)); // LTV 45 / thr 50 / bonus 110 / rf 10

        // cREAL reserve (LTV 1bp)
        r = pool.getReserveData(CREAL);
        assertEq(_cfg(r), uint256(0x3e805122af800010001)); // LTV 1 / thr 1 / bonus 110 / rf 10

        // MOO reserve — frozen + LTV 1bp
        r = pool.getReserveData(MOO);
        assertEq(_cfg(r), uint256(0x3e807122af800010001)); // frozen bit set
        (bool activeMoo, bool frozenMoo, bool borrowingMoo, bool stableMoo) = _flags(r);
        activeMoo; borrowingMoo; stableMoo;
        assertTrue(frozenMoo, "MOO frozen");

        // accounting invariant per reserve: aToken claims <= cash + debts
        _assertBacking(CELO, aCELO, vCELO, 0x02661dd90c6243Fe5cdF88De3E8cb74BcC3bD25E);
        _assertBacking(CUSD, aCUSD, 0xf602D9617564C07f1e128687798D8C699cED3961, address(0));
    }

    function test_oracle_live_primary_and_dead_fallback() public {
        // prices at pinned block
        assertEq(oracle.getAssetPrice(CELO), 1e18);
        assertEq(oracle.getAssetPrice(CUSD), 11114487445408416290);
        assertEq(oracle.getAssetPrice(CEUR), 11811634360715485296);
        assertEq(oracle.getAssetPrice(CREAL), 2100449195176596085);
        assertEq(oracle.getAssetPrice(MOO), 5e15);

        // stables priced by Mento SortedOracles wrapper (primary), not by Ubeswap
        assertEq(oracle.getSourceOfAsset(CUSD), CELO_PROXY);
        assertEq(oracle.getSourceOfAsset(CEUR), CELO_PROXY);
        assertEq(oracle.getSourceOfAsset(CREAL), CELO_PROXY);
        assertEq(ICeloProxyPriceProvider(CELO_PROXY).getPriceFeed(CUSD), FEED_CUSD);
        assertEq(ISortedOraclesPriceFeed(FEED_CUSD).consult(), 11114487445408416290);
        assertEq(ISortedOraclesPriceFeed(FEED_CEUR).consult(), 11811634360715485296);
        assertEq(ISortedOraclesPriceFeed(FEED_CREAL).consult(), 2100449195176596085);

        // Mento reports are live (not expired)
        address so = IRegistry(REGISTRY).getAddressForOrDie(keccak256(abi.encodePacked("SortedOracles")));
        assertEq(so, SORTED_ORACLES);
        (bool expiredCUSD,) = ISortedOracles(so).isOldestReportExpired(CUSD);
        (bool expiredCEUR,) = ISortedOracles(so).isOldestReportExpired(CEUR);
        (bool expiredCREAL,) = ISortedOracles(so).isOldestReportExpired(CREAL);
        assertFalse(expiredCUSD && expiredCEUR && expiredCREAL, "at least one report live");
        assertFalse(expiredCUSD, "cUSD reports live");

        // fallback (Ubeswap sliding-window TWAP) is DEAD: consult() reverts
        assertEq(oracle.getFallbackOracle(), FALLBACK);
        vm.expectRevert(bytes("SlidingWindowOracle: MISSING_HISTORICAL_OBSERVATION"));
        IMoolaOracle(FALLBACK).getAssetPrice(CUSD);
        vm.expectRevert(bytes("SlidingWindowOracle: MISSING_HISTORICAL_OBSERVATION"));
        IMoolaOracle(FALLBACK).getAssetPrice(CEUR);

        // MOO source is an immutable FixedPriceOracle
        assertEq(oracle.getSourceOfAsset(MOO), FIXED_MOO);
        assertEq(IFixedPriceOracle(FIXED_MOO).PRICE(), 5e15);
        assertEq(IFixedPriceOracle(FIXED_MOO).ASSET(), MOO);
    }

    function test_moo_frozen_deposit_reverts() public {
        vm.deal(address(this), 100 ether);
        IERC20(MOO).approve(POOL, 100e18);
        // no MOO balance needed — frozen check happens first
        vm.expectRevert(bytes("3")); // VL_RESERVE_FROZEN
        pool.deposit(MOO, 1e18, address(this), 0);
    }

    function test_moo_frozen_but_withdrawable_by_holder() public {
        // frozen reserves still allow withdraw (validateWithdraw checks isActive only)
        address holder = 0xD7199780db7386190bF9d24866c43B8E64d4092e;
        uint256 aBal = IERC20(aMOO).balanceOf(holder);
        assertGt(aBal, 0, "holder has aMOO");
        uint256 before = IERC20(MOO).balanceOf(holder);
        vm.prank(holder);
        pool.withdraw(MOO, aBal, holder);
        assertEq(IERC20(MOO).balanceOf(holder), before + aBal);
    }

    function test_borrow_without_collateral_reverts() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(bytes("9")); // VL_COLLATERAL_BALANCE_IS_0
        pool.borrow(CELO, 1e18, 2, 0, address(this));
    }

    function test_withdraw_without_balance_reverts() public {
        vm.expectRevert(bytes("5")); // VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE
        pool.withdraw(CELO, 1e18, address(this));
    }

    // ------------------------------------------------- donation / rounding

    function test_deposit_withdraw_roundtrip_and_donation_is_inert() public {
        vm.deal(address(this), 1_100 ether);
        IERC20(CELO).approve(POOL, type(uint256).max);
        uint256 idxBefore = pool.getReserveNormalizedIncome(CELO);
        pool.deposit(CELO, 100e18, address(this), 0);
        uint256 aBal = IERC20(aCELO).balanceOf(address(this));
        uint256 supplyBefore = IERC20(aCELO).totalSupply();

        // donation: send 1000 CELO straight to the aToken contract
        IERC20(CELO).transfer(aCELO, 1000e18);

        // index / supply / attacker balance unchanged -> Compound-class donation inert
        assertEq(pool.getReserveNormalizedIncome(CELO), idxBefore);
        assertEq(IERC20(aCELO).totalSupply(), supplyBefore);
        assertEq(IERC20(aCELO).balanceOf(address(this)), aBal);

        // round trip returns exactly the deposit (no interest accrued same block)
        uint256 balBefore = IERC20(CELO).balanceOf(address(this));
        pool.withdraw(CELO, 100e18, address(this));
        assertEq(IERC20(CELO).balanceOf(address(this)), balBefore + 100e18);
    }

    // ------------------------------------------------------------ flashloan

    function test_flashloan_permissionless_and_repaid() public {
        TestFlashLoanReceiver receiver = new TestFlashLoanReceiver(POOL);
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes = new uint256[](1);
        assets[0] = CELO; amounts[0] = 100e18; modes[0] = 0;

        uint256 treasuryBefore = IERC20(CELO).balanceOf(POOL_ADMIN);
        // the borrower pays the 1bp premium out of its own funds
        vm.deal(address(receiver), 1e16);
        pool.flashLoan(address(receiver), assets, amounts, modes, address(this), "", 0);
        // receiver returned everything + 1bp premium
        assertEq(IERC20(CELO).balanceOf(address(receiver)), 0);
        assertEq(IERC20(CELO).balanceOf(POOL_ADMIN), treasuryBefore + 1e16);
    }

    // ---------------------------------------------------------- liquidation

    function test_liquidation_undercollateralised_dust_profit() public {
        // pre-state
        (, , , , , uint256 hfBefore) = pool.getUserAccountData(LIQ_TARGET);
        assertLt(hfBefore, 1e18, "target HF < 1");

        uint256 collBefore = IERC20(aCUSD).balanceOf(LIQ_TARGET);
        uint256 debtBefore = IERC20(vCELO).balanceOf(LIQ_TARGET);
        assertEq(collBefore, 1000218363964449770);
        assertEq(debtBefore, 10502744824436612895);

        // liquidator funded with CELO (native == ERC20 CELO on Celo)
        vm.deal(address(this), 20 ether);
        IERC20(CELO).approve(POOL, type(uint256).max);

        uint256 celoBefore = IERC20(CELO).balanceOf(address(this));
        uint256 cusdBefore = IERC20(CUSD).balanceOf(address(this));

        emit log_named_uint("step: celoBefore", celoBefore);
        pool.liquidationCall(CUSD, CELO, LIQ_TARGET, 5251372412218306448, false);
        emit log_string("step: after liquidation");
        uint256 celoAfter = IERC20(CELO).balanceOf(address(this));
        emit log_named_uint("step: celoAfter", celoAfter);
        uint256 cusdAfter = IERC20(CUSD).balanceOf(address(this));
        emit log_named_uint("step: cusdAfter", cusdAfter);
        uint256 repaid = celoBefore - celoAfter;
        uint256 receivedCUSD = cusdAfter - cusdBefore;

        // exact contract math (bonus 5% + 2% treasury cut on collateral)
        assertEq(repaid, 5251372412218306448);
        assertApproxEqAbs(receivedCUSD, 496103941806792409, 2);
        // proceeds in CELO minus repaid > 0, but tiny
        uint256 proceeds = receivedCUSD * 11114487445408416290 / 1e18;
        assertGt(proceeds, repaid);
        uint256 profit = proceeds - repaid;
        emit log_named_uint("liquidation profit wei CELO", profit);
        assertApproxEqAbs(profit, 262568620610915328, 2e6);
        // user collateral seized, debt reduced
        assertLt(IERC20(aCUSD).balanceOf(LIQ_TARGET), collBefore);
        assertLt(IERC20(vCELO).balanceOf(LIQ_TARGET), debtBefore);
    }

    function test_healthy_whales_not_liquidatable() public {
        (, , , , , uint256 hf1) = pool.getUserAccountData(WHALE_1);
        (, , , , , uint256 hf2) = pool.getUserAccountData(WHALE_2);
        assertGt(hf1, 1e18);
        assertGt(hf2, 1e18);
        vm.expectRevert(bytes("42")); // LPCM_HEALTH_FACTOR_NOT_BELOW_THRESHOLD
        pool.liquidationCall(CELO, CUSD, WHALE_1, 1e18, false);
    }

    // ------------------------------------------------- privileged surface

    function test_privileged_calls_revert_for_arbitrary_caller() public {
        vm.startPrank(address(0xBEEF));
        vm.expectRevert(bytes("33")); // CALLER_NOT_POOL_ADMIN
        ILendingPoolConfigurator(CONFIGURATOR).setReserveFactor(CELO, 5000);
        vm.expectRevert(bytes("33"));
        ILendingPoolConfigurator(CONFIGURATOR).freezeReserve(CELO);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        provider.setPriceOracle(address(0xBEEF));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        oracle.setAssetSources(_arr(CUSD), _arr(address(0xBEEF)));
        vm.expectRevert(bytes("27")); // LP_CALLER_NOT_LENDING_POOL_CONFIGURATOR
        pool.setPause(true);
        vm.stopPrank();
    }

    // ------------------------------------------------------------- helpers

    function _arr(address a) internal pure returns (address[] memory r) {
        r = new address[](1); r[0] = a;
    }

    function _cfg(DataTypes.ReserveData memory r) internal pure returns (uint256) {
        return r.configuration.data;
    }

    function _flags(DataTypes.ReserveData memory r)
        internal pure returns (bool active, bool frozen, bool borrowing, bool stable)
    {
        uint256 d = r.configuration.data;
        active = ((d >> 56) & 1) == 1;
        frozen = ((d >> 57) & 1) == 1;
        borrowing = ((d >> 58) & 1) == 1;
        stable = ((d >> 59) & 1) == 1;
    }

    function _assertBacking(address asset, address aToken, address vDebt, address sDebt) internal view {
        uint256 cash = IERC20(asset).balanceOf(aToken);
        uint256 v = IERC20(vDebt).totalSupply();
        uint256 s = sDebt == address(0) ? 0 : IERC20(sDebt).totalSupply();
        uint256 claims = IERC20(aToken).totalSupply();
        // claims <= cash + debt (pool never over-issues claims)
        assertLe(claims, cash + v + s + 1, "backing invariant");
    }
}

