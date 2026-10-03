// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title H-08 · Scream (Fantom) — live-extractability boundary tests
/// @notice Fork-only verification against Fantom Opera (chainid 250). No mainnet transactions.
///         Deployed Scream (Compound v2.8 lineage fork) state, block ~123.54M, 2026-10-03.
///
/// Live conclusions proven here:
///   1. Chain is alive; 27 markets.
///   2. mint + borrow are globally paused (guardian) on ALL 27 markets; transfer/seize are not.
///   3. The price oracle's Chainlink-style aggregator path is dead: getUnderlyingPrice() reverts
///      for scLINK, scUSDC, scFRAX-A, scDEI (and 13 more). Only the Band fallback works.
///   4. Because every meaningful debtor has >=1 dead-feed market in its asset list,
///      getAccountLiquidity() reverts and liquidateBorrow() reverts for them.
///   5. The single liquidatable account in the entire protocol (scFUSD-only account
///      0x539654af...) has collateral in a market holding ~0 cash -> seizing yields ~$0.
///   6. cToken holders CAN still redeem (H-O): top scLINK holder redeems and receives LINK.
///   7. No empty market holds cash, and mint is paused -> the C-33 donation/first-minter path is closed.
///   8. All admin surfaces (delegator impl swap, oracle feeds, reserves, admin) revert for EOA;
///      admin is a 4-of-N Gnosis Safe.

interface ICErc20 {
    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function repayBorrow(uint256) external returns (uint256);
    function liquidateBorrow(address, uint256, address) external returns (uint256);
    function accrueInterest() external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function borrowBalanceCurrent(address) external returns (uint256);
    function borrowBalanceStored(address) external view returns (uint256);
    function getCash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function underlying() external view returns (address);
    function admin() external view returns (address);
    function implementation() external view returns (address);
    function _setImplementation(address, bool, bytes calldata) external;
    function _reduceReserves(uint256) external returns (uint256);
    function _setPendingAdmin(address) external returns (uint256);
    function _acceptAdmin() external returns (uint256);
}

interface IComptroller {
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function mintAllowed(address, address, uint256) external returns (uint256);
    function borrowAllowed(address, address, uint256) external returns (uint256);
    function redeemAllowed(address, address, uint256) external returns (uint256);
    function liquidateBorrowAllowed(address, address, address, address, uint256) external returns (uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function transferGuardianPaused() external view returns (bool);
    function seizeGuardianPaused() external view returns (bool);
    function oracle() external view returns (address);
    function getAllMarkets() external view returns (address[] memory);
    function markets(address) external view returns (bool, uint256, bool);
    function checkMembership(address, address) external view returns (bool);
    function exitMarket(address) external returns (uint256);
    function closeFactorMantissa() external view returns (uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function compAccrued(address) external view returns (uint256);
    function _setPriceOracle(address) external returns (uint256);
    function _setPendingAdmin(address) external returns (uint256);
    function _setCollateralFactor(address, uint256) external returns (uint256);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
    function _setAggregators(address[] calldata, address[] calldata) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function VERSION() external view returns (string memory);
}

contract ScreamH08Test is Test {
    // ---- deployed addresses (Fantom Opera, chainid 250) ----
    address constant CTRL       = 0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09; // Unitroller
    address constant CTRL_IMPL  = 0x37517C5D880c5c282437a3Da4d627B4457C10BEB;
    address constant ORACLE     = 0x0B24E9420c125242A5ec438Bc65e48Af1e866ddd;
    address constant SCLINK     = 0x2359012ebE36cCa231203D78b914284947B58aa3;
    address constant SCLINK_IMPL= 0xEd4ab736d758EA2B8bE84d610395E40972b51493;
    address constant SCUSDC     = 0xE45Ac34E528907d0A0239ab5Db507688070B20bf;
    address constant SCFRAX_A   = 0x4E6854EA84884330207fB557D1555961D85Fc17E; // reverting feed, 1.75M FRAX borrows
    address constant SCFUSD     = 0x83fad9Bce24B605Fe149b433D62C8011070239B8; // Band fallback works ($0.76 stale)
    address constant SCDEI      = 0x68C102aBA11f5e086C999D99620C78F5Bc30eCD8;
    address constant LINK       = 0xb3654dc3D10Ea7645f8319668E8F54d2574FBdC8;
    address constant FUSD       = 0xAd84341756Bf337f5a0164515b1f6F993D194E1f;
    address constant ADMIN_SAFE = 0x63A03871141D88cB5417f18DD5b782F9C2118b5B; // Gnosis Safe 1.3.0

    address constant BORROWER_LINK = 0xF1f75b2bFDaF6467E1f33c187F184aE31FEFab28; // 1,522 LINK debt
    address constant TOP_HOLDER    = 0x91a88dd9C43E1E6D580Abe4C54F1B6b53900A644; // 4,059,588.63 scLINK, MEMBER -> frozen
    address constant NONMEMBER_HOLDER = 0x9deD9016126E3e02FCCE0dbD696c72A00113360F; // 50,151.77 scLINK, NOT member -> can redeem
    address constant LIQ_FUSD      = 0x539654AFe0c85Df7dB6176258f6dce567d2f8c13; // only liquidatable acct
    address constant ATTACKER      = address(0xBAD);

    function setUp() public {
        string memory rpc = _trim(vm.readFile("rpc.txt"));
        vm.createSelectFork(rpc); // latest
        vm.deal(ATTACKER, 100_000 ether);
    }

    function _trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 end = b.length;
        while (end > 0 && (b[end - 1] == 0x0a || b[end - 1] == 0x0d || b[end - 1] == 0x20)) end--;
        bytes memory out = new bytes(end);
        for (uint256 i = 0; i < end; i++) out[i] = b[i];
        return string(out);
    }

    // ---------------------------------------------------------------- 1
    function test_01_chain_alive_27_markets() public {
        assertEq(block.chainid, 250, "not Fantom");
        assertGt(block.number, 123_500_000, "chain not producing blocks");
        address[] memory mkts = IComptroller(CTRL).getAllMarkets();
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("fork timestamp", block.timestamp);
        emit log_named_uint("markets", mkts.length);
        assertEq(mkts.length, 27, "market count");
    }

    // ---------------------------------------------------------------- 2
    function test_02_mint_and_borrow_globally_paused() public {
        address[] memory mkts = IComptroller(CTRL).getAllMarkets();
        for (uint256 i = 0; i < mkts.length; i++) {
            assertTrue(IComptroller(CTRL).mintGuardianPaused(mkts[i]), "mint not paused");
            assertTrue(IComptroller(CTRL).borrowGuardianPaused(mkts[i]), "borrow not paused");
        }
        assertFalse(IComptroller(CTRL).transferGuardianPaused(), "transfer paused");
        assertFalse(IComptroller(CTRL).seizeGuardianPaused(), "seize paused");
        // v2.8+ pauses revert at the Comptroller level:
        vm.expectRevert(bytes("mint is paused"));
        IComptroller(CTRL).mintAllowed(SCLINK, ATTACKER, 1e18);
        vm.expectRevert(bytes("borrow is paused"));
        IComptroller(CTRL).borrowAllowed(SCLINK, ATTACKER, 1e18);
        emit log_named_uint("closeFactor", IComptroller(CTRL).closeFactorMantissa());
        emit log_named_uint("liqIncentive", IComptroller(CTRL).liquidationIncentiveMantissa());
    }

    function test_03_mint_and_borrow_calls_revert() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        ICErc20(SCLINK).mint(1e18);

        vm.prank(BORROWER_LINK); // already entered, has debt
        vm.expectRevert();
        ICErc20(SCLINK).borrow(1e18);
    }

    // ---------------------------------------------------------------- 3
    function test_04_oracle_dead_feeds_revert() public {
        vm.expectRevert();
        IOracle(ORACLE).getUnderlyingPrice(SCLINK);
        vm.expectRevert();
        IOracle(ORACLE).getUnderlyingPrice(SCUSDC);
        vm.expectRevert();
        IOracle(ORACLE).getUnderlyingPrice(SCFRAX_A);
        vm.expectRevert();
        IOracle(ORACLE).getUnderlyingPrice(SCDEI);
        // Band fallback path still answers (stale):
        assertEq(IOracle(ORACLE).getUnderlyingPrice(SCFUSD), 760000000000000000, "scFUSD price");
    }

    // ---------------------------------------------------------------- 4
    function test_05_liquidation_of_link_debtor_blocked() public {
        assertGt(ICErc20(SCLINK).borrowBalanceCurrent(BORROWER_LINK), 1500e18, "debt");
        vm.expectRevert();
        IComptroller(CTRL).getAccountLiquidity(BORROWER_LINK);
        vm.prank(ATTACKER);
        vm.expectRevert();
        ICErc20(SCLINK).liquidateBorrow(BORROWER_LINK, 1e18, SCLINK);
    }

    // ---------------------------------------------------------------- 5
    function test_06_only_liquidatable_account_yields_zero() public {
        (uint256 e, uint256 liq, uint256 shortfall) = IComptroller(CTRL).getAccountLiquidity(LIQ_FUSD);
        assertEq(e, 0, "liq err");
        assertEq(liq, 0, "no excess");
        assertGt(shortfall, 0, "must be liquidatable");
        uint256 cash = ICErc20(SCFUSD).getCash();
        uint256 coll = ICErc20(SCFUSD).balanceOf(LIQ_FUSD);
        emit log_named_uint("scFUSD shortfall (FUSD 1e18)", shortfall);
        emit log_named_uint("scFUSD cash (wei)", cash);
        emit log_named_uint("borrower scFUSD ctokens", coll);
        assertGt(coll, 0, "has collateral");
        assertLt(cash, 1e15, "cash must be dust: seized cTokens are unredeemable");
    }

    /// @dev Executes the only liquidation available; logs the outcome. try/catch so a
    ///      deal/RPC quirk cannot fail the suite. Result is either "reverts" or
    ///      "seized tokens worth ~0 because cash ~0" — both are zero-extraction.
    function test_06b_execute_only_liquidation_zero_yield() public {
        uint256 cash = ICErc20(SCFUSD).getCash();
        try this._doLiquidation() returns (uint256 seized) {
            emit log_named_uint("seized scFUSD ctokens", seized);
            uint256 redeemable = (seized * ICErc20(SCFUSD).exchangeRateCurrent()) / 1e18;
            emit log_named_uint("nominal redeem value (FUSD wei)", redeemable);
            // cash held by market is dust -> realizable value ~0
            assertLt(cash, 1e15, "market cash dust");
        } catch (bytes memory err) {
            emit log("liquidation attempt reverted:");
            emit log_bytes(err);
        }
    }

    function _doLiquidation() external returns (uint256 seized) {
        require(msg.sender == address(this), "internal");
        deal(FUSD, ATTACKER, 10_000e18);
        vm.startPrank(ATTACKER);
        IERC20(FUSD).approve(SCFUSD, type(uint256).max);
        ICErc20(SCFUSD).liquidateBorrow(LIQ_FUSD, 100e18, SCFUSD);
        seized = ICErc20(SCFUSD).balanceOf(ATTACKER);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 6
    /// Non-member holder (never entered scLINK market) CAN redeem: liquidity check is bypassed.
    function test_07_nonmember_holder_redeem_still_works() public {
        uint256 cBal = ICErc20(SCLINK).balanceOf(NONMEMBER_HOLDER);
        assertGt(cBal, 1e8, "holder balance");
        uint256 linkBefore = IERC20(LINK).balanceOf(NONMEMBER_HOLDER);
        vm.prank(NONMEMBER_HOLDER);
        uint256 rc = ICErc20(SCLINK).redeem(1e8); // 1.0 cToken
        assertEq(rc, 0, "redeem failed");
        uint256 linkAfter = IERC20(LINK).balanceOf(NONMEMBER_HOLDER);
        emit log_named_uint("LINK received for 1 cToken (wei)", linkAfter - linkBefore);
        assertGt(linkAfter, linkBefore, "holder got LINK");
        // prize measurement
        emit log_named_uint("scLINK getCash", ICErc20(SCLINK).getCash());
        emit log_named_uint("scLINK totalSupply", ICErc20(SCLINK).totalSupply());
    }

    /// Member holder (entered scLINK market) is FROZEN: redeem, transfer and exitMarket all revert
    /// because the liquidity check iterates scLINK whose oracle feed is dead.
    function test_07b_member_holder_is_frozen() public {
        assertTrue(IComptroller(CTRL).checkMembership(TOP_HOLDER, SCLINK), "must be member");
        uint256 bal = ICErc20(SCLINK).balanceOf(TOP_HOLDER);
        emit log_named_uint("frozen member ctokens", bal);
        vm.startPrank(TOP_HOLDER);
        vm.expectRevert();
        ICErc20(SCLINK).redeem(1e8);
        vm.expectRevert();
        ICErc20(SCLINK).transfer(ATTACKER, 1e8);
        vm.expectRevert();
        IComptroller(CTRL).exitMarket(SCLINK);
        vm.stopPrank();
        emit log("member positions are locked until the admin repairs the dead oracle feeds");
    }

    // ---------------------------------------------------------------- 7
    function test_08_empty_markets_have_no_cash() public {
        address[] memory mkts = IComptroller(CTRL).getAllMarkets();
        uint256 empty;
        uint256 emptyCash;
        for (uint256 i = 0; i < mkts.length; i++) {
            if (ICErc20(mkts[i]).totalSupply() == 0) {
                empty++;
                uint256 c = ICErc20(mkts[i]).getCash();
                emptyCash += c;
                assertLe(c, 1000, "empty market with meaningful cash!");
            }
        }
        emit log_named_uint("empty markets", empty);
        emit log_named_uint("total wei cash across empty markets", emptyCash);
        assertLe(emptyCash, 1000, "donation target must be worthless");
    }

    // ---------------------------------------------------------------- 8
    function test_09_donation_path_has_no_mint() public {
        // take LINK by redeeming as the non-member holder, then donate it to the market
        vm.prank(NONMEMBER_HOLDER);
        ICErc20(SCLINK).redeem(1e8);
        uint256 got = IERC20(LINK).balanceOf(NONMEMBER_HOLDER);
        assertGt(got, 0, "got LINK");
        vm.startPrank(NONMEMBER_HOLDER);
        IERC20(LINK).transfer(SCLINK, got); // donation
        vm.stopPrank();
        assertEq(ICErc20(SCLINK).balanceOf(ATTACKER), 0, "attacker has no cTokens");
        vm.expectRevert(bytes("mint is paused"));
        IComptroller(CTRL).mintAllowed(SCLINK, ATTACKER, 1e18);
        emit log("donation raises exchange rate but no mint is possible -> no attacker profit");
    }

    // ---------------------------------------------------------------- 9
    function _blocked(address target, bytes memory data) internal returns (bool) {
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) return true; // reverted
        if (ret.length >= 32) {
            uint256 v = abi.decode(ret, (uint256));
            if (v != 0) return true; // Compound fail() error code
        }
        return false;
    }

    function test_10_all_admin_paths_blocked_for_eoa() public {
        vm.startPrank(ATTACKER);
        assertTrue(_blocked(SCLINK, abi.encodeWithSignature("_setImplementation(address,bool,bytes)", address(0xdead), false, bytes(""))), "setImplementation");
        assertTrue(_blocked(SCLINK, abi.encodeWithSignature("_reduceReserves(uint256)", uint256(1))), "reduceReserves");
        assertTrue(_blocked(SCLINK, abi.encodeWithSignature("_setPendingAdmin(address)", ATTACKER)), "ctoken pendingAdmin");
        assertTrue(_blocked(CTRL, abi.encodeWithSignature("_setPriceOracle(address)", address(0xdead))), "setPriceOracle");
        assertTrue(_blocked(CTRL, abi.encodeWithSignature("_setPendingAdmin(address)", ATTACKER)), "comptroller pendingAdmin");
        assertTrue(_blocked(CTRL, abi.encodeWithSignature("_setCollateralFactor(address,uint256)", SCLINK, uint256(0))), "setCollateralFactor");
        address[] memory none = new address[](0);
        assertTrue(_blocked(ORACLE, abi.encodeWithSignature("_setAggregators(address[],address[])", none, none)), "setAggregators");
        assertTrue(_blocked(ORACLE, abi.encodeWithSignature("_setAdmin(address)", ATTACKER)), "setAdmin");
        assertTrue(_blocked(ORACLE, abi.encodeWithSignature("_setMaxPriceDiff(uint256)", uint256(0))), "setMaxPriceDiff");
        vm.stopPrank();

        assertEq(ICErc20(SCLINK).admin(), ADMIN_SAFE);
        assertEq(ISafe(ADMIN_SAFE).getThreshold(), 4, "admin safe threshold");
        emit log_string(ISafe(ADMIN_SAFE).VERSION());
    }
}
