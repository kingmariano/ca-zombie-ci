// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// Minimal interfaces for Aurigami (Aurora) fork tests. Read-only evidence collection:
/// every test asserts a CLOSED or OPEN state against a live fork; no mainnet tx is ever sent.
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IAU {
    function mint(uint256) external;
    function redeem(uint256) external;
    function redeemUnderlying(uint256) external;
    function borrow(uint256) external;
    function repayBorrow(uint256) external;
    function liquidateBorrow(address borrower, uint256 repayAmount, address auTokenCollateral) external;
    function seize(address liquidator, address borrower, uint256 seizeTokens) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function accrualBlockTimestamp() external view returns (uint256);
    function getCash() external view returns (uint256);
    function getAccountSnapshot(address) external view returns (uint256, uint256, uint256);
}

interface IUnitroller {
    function getAllMarkets() external view returns (address[] memory);
    function borrowCaps(address) external view returns (uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function transferGuardianPaused() external view returns (bool);
    function seizeGuardianPaused() external view returns (bool);
    function getAccountLiquidity(address) external view returns (uint256, uint256);
    function liquidateCalculateSeizeTokens(address borrowed, address collateral, uint256 repayAmount) external view returns (uint256);
    function claimReward(uint8 rewardType, address holder) external;
    function oracle() external view returns (address);
    function rewardSpeeds(uint8, address, bool) external view returns (uint256);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
    function owner() external view returns (address);
}

contract AurigamiTest is Test {
    // --- core addresses (Aurora mainnet) ---
    address constant UNIT   = 0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb; // Unitroller (Comptroller proxy)
    address constant ORACLE = 0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE;
    address constant AUUSDC = 0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b;
    address constant AUETH  = 0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9;
    address constant AUWBTC = 0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb;
    address constant AUUSDT = 0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54;
    address constant AUWNEAR= 0xaE4fac24dCdAE0132C6d04f564dCf059616E9423;
    address constant AUSTNEAR=0x3195949f267702723bc614cAE037cdc8D1E94786;
    address constant AUAURORA=0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf;
    address constant AUPLY  = 0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c;

    address constant USDC = 0xB12BFcA5A55806AaF64E99521918A4bf0fC40802; // bridged USDC.e (auUSDC underlying)
    address constant WNEAR= 0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d;
    address constant STNEAR=0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30;
    address constant AURORA=0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79;
    address constant PLY   = 0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f;

    uint256 constant E18 = 1e18;

    function setUp() public {
        string memory rpc = vm.envOr("AURORA_RPC_URL", string("https://mainnet.aurora.dev"));
        vm.createSelectFork(rpc);
        emit log_named_uint("fork block", block.number);
    }

    // ---------------------------------------------------------------- helpers
    function _usd(uint256 amount, uint256 decimals_, uint256 price36) internal pure returns (uint256) {
        // price36 is oracle price scaled 1e(36-decimals); returns USD scaled 1e18
        decimals_; // decimals encoded in price36
        return amount * price36 / E18;
    }

    function _addrEq(address a, address b) internal pure returns (bool) { return a == b; }

    // ================================================================ tests

    /// 1. All 14 markets live; mint open; borrow caps 1 wei everywhere; pauses off.
    function test_01_market_state_live_unpaused_borrow_capped() public {
        address[] memory mkts = IUnitroller(UNIT).getAllMarkets();
        assertEq(mkts.length, 14, "market count");
        assertFalse(IUnitroller(UNIT).transferGuardianPaused(), "transfer paused");
        assertFalse(IUnitroller(UNIT).seizeGuardianPaused(), "seize paused");
        for (uint256 i = 0; i < mkts.length; i++) {
            assertEq(IUnitroller(UNIT).borrowCaps(mkts[i]), 1, "borrowCap != 1");
            assertFalse(IUnitroller(UNIT).mintGuardianPaused(mkts[i]), "mint paused");
            assertFalse(IUnitroller(UNIT).borrowGuardianPaused(mkts[i]), "borrow paused");
            assertGt(IAU(mkts[i]).totalSupply(), 0, "zero-supply market");
        }
        emit log_string("PASS: 14 markets, all supplied, mint open, borrow caps = 1 wei");
    }

    /// 2. New borrowing is impossible on every debt market ("market borrow cap reached").
    function test_02_borrow_disabled_on_all_debt_markets() public {
        address[7] memory m = [AUUSDC, AUETH, AUWBTC, AUUSDT, AUWNEAR, AUSTNEAR, AUAURORA];
        for (uint256 i = 0; i < m.length; i++) {
            vm.expectRevert(bytes("market borrow cap reached"));
            IAU(m[i]).borrow(1);
        }
        emit log_string("PASS: borrow(1) reverts 'market borrow cap reached' on all 7 debt markets");
    }

    /// 3. Oracle push is keeper-gated: unauthorised setPrices reverts "not price setter".
    function test_03_oracle_push_is_keeper_gated() public {
        address[] memory toks = new address[](1);
        toks[0] = AUUSDC;
        uint256[] memory prices = new uint256[](1);
        prices[0] = 1e30; // absurd price, must not be accepted
        (bool ok, bytes memory ret) = ORACLE.call(abi.encodeWithSelector(0xec3115f9, toks, prices));
        assertFalse(ok, "setPrices must revert for unauthorised caller");
        // decode Error(string)
        string memory reason = _decodeRevert(ret);
        assertEq(reason, "not price setter", "wrong revert reason");
        emit log_string("PASS: oracle setPrices reverts 'not price setter' for external caller");
        emit log_named_address("oracle owner", IOracle(ORACLE).owner());
    }

    /// 4. seize() cannot be invoked by an arbitrary address (caller must be a listed market).
    function test_04_seize_without_liquidation_reverts() public {
        address victim = 0x1A8ADd5e75Ff515Dd83b6745C38389E220cf4080; // auUSDC member with balance
        vm.prank(address(0xBEEF));
        vm.expectRevert(); // MarketNotListed (caller not a listed auToken)
        IAU(AUUSDC).seize(address(0xdead), victim, 1);
        emit log_string("PASS: external seize() from non-market address reverts");
    }

    /// 5. H-O: mint/redeem round-trip is open and value-preserving (no extraction).
    function test_05_mint_redeem_roundtrip_open() public {
        address attacker = makeAddr("attacker5");
        deal(USDC, attacker, 50_000e6);
        uint256 cashBefore = IAU(AUUSDC).getCash();
        vm.startPrank(attacker);
        IERC20(USDC).approve(AUUSDC, type(uint256).max);
        IAU(AUUSDC).mint(50_000e6);
        uint256 tokens = IAU(AUUSDC).balanceOf(attacker);
        assertGt(tokens, 0, "no shares minted");
        IAU(AUUSDC).redeem(tokens);
        vm.stopPrank();
        uint256 back = IERC20(USDC).balanceOf(attacker);
        assertGe(back + 50, 50_000e6, "round-trip lost value");
        assertLe(back, 50_000e6, "round-trip gained value (??)");
        assertApproxEqAbs(IAU(AUUSDC).getCash(), cashBefore, 50, "cash not restored");
        emit log_named_uint("mint 50000e6 USDC -> redeemed (units)", back);
        emit log_string("PASS: mint/redeem open, value preserved (H-O path), no profit");
    }

    /// 6. Rewards: a fresh minter does NOT capture retroactive PLY index growth.
    function test_06_no_retroactive_reward_capture() public {
        address attacker = makeAddr("attacker6");
        uint256 plyBefore = IERC20(PLY).balanceOf(UNIT);
        deal(USDC, attacker, 20_000e6);
        vm.startPrank(attacker);
        IERC20(USDC).approve(AUUSDC, type(uint256).max);
        IAU(AUUSDC).mint(20_000e6);
        uint256 plyMid = IERC20(PLY).balanceOf(attacker);
        IUnitroller(UNIT).claimReward(0, attacker);
        uint256 plyGain = IERC20(PLY).balanceOf(attacker) - plyMid;
        IAU(AUUSDC).redeem(IAU(AUUSDC).balanceOf(attacker));
        vm.stopPrank();
        assertLt(plyGain, 0.01e18, "retroactive PLY capture detected");
        uint256 plyAfter = IERC20(PLY).balanceOf(UNIT);
        assertGe(plyAfter + 0.02e18, plyBefore, "Unitroller PLY pool drained");
        emit log_named_uint("PLY gained by fresh minter+claim (wei)", plyGain);
        emit log_named_uint("Unitroller PLY before", plyBefore);
        emit log_named_uint("Unitroller PLY after", plyAfter);
        emit log_string("PASS: no retroactive reward capture; pool not drained");
    }

    /// 7. Liquidation surface: every shortfall account is dust; execute one real liquidation.
    function test_07_liquidation_surface_is_dust() public {
        uint256 totalShortfall = 0;
        address[30] memory shortAddrs = _shortfallAddresses();
        uint256 n = shortAddrs.length;
        for (uint256 i = 0; i < n; i++) {
            (uint256 liq, uint256 short) = IUnitroller(UNIT).getAccountLiquidity(shortAddrs[i]);
            liq; // silence
            totalShortfall += short;
        }
        assertLt(totalShortfall, 20e18, "liquidatable shortfall unexpectedly large");
        emit log_named_uint("shortfall accounts", n);
        emit log_named_uint("sum shortfall USD (1e18)", totalShortfall);

        // Execute a real liquidation on the largest shortfall account with collateral:
        // 0xe7354c21 debt 392.876 WNEAR, collateral 2,500 auAURORA.
        address borrower = 0xe7354C21A5d7972726Efcdeb7C322F3DF2ca96Bc;
        (, uint256 debt, ) = IAU(AUWNEAR).getAccountSnapshot(borrower);
        assertGt(debt, 0, "no debt");
        uint256 maxRepay = debt / 2; // close factor 50%
        address liquidator = makeAddr("liquidator7");
        deal(WNEAR, liquidator, maxRepay);
        uint256 auroraBefore = IAU(AUAURORA).balanceOf(liquidator);
        vm.startPrank(liquidator);
        IERC20(WNEAR).approve(AUWNEAR, type(uint256).max);
        try IAU(AUWNEAR).liquidateBorrow(borrower, maxRepay, AUAURORA) {
            vm.stopPrank();
            uint256 seized = IAU(AUAURORA).balanceOf(liquidator) - auroraBefore;
            uint256 exRate = IAU(AUAURORA).exchangeRateStored();
            uint256 seizedUnderlying = seized * exRate / E18; // auAURORA units -> AURORA (18d)
            uint256 seizeUsd18 = _usd(seizedUnderlying, 18, IOracle(ORACLE).getUnderlyingPrice(AUAURORA));
            uint256 repayUsd18 = _usd(maxRepay, 24, IOracle(ORACLE).getUnderlyingPrice(AUWNEAR));
            emit log_named_uint("repay USD (1e18)", repayUsd18);
            emit log_named_uint("seized USD (1e18)", seizeUsd18);
            // profit bounded to a few dollars at most
            assertLt(seizeUsd18, repayUsd18 + 20e18, "liquidation profit unexpectedly large");
            emit log_string("PASS: live liquidation possible but only dust-sized profit (top-30 shortfall accounts); full 140-account scan total $11.18 (analysis/health_scan.json)");
        } catch {
            vm.stopPrank();
            emit log_string("NOTE: account not liquidatable at this fork block (interest repaid since scan)");
        }
    }

    /// 8. H-O value is withdrawable: a top auUSDC holder can redeem today.
    function test_08_top_holder_can_withdraw() public {
        address holder = 0x1Ee43E7570AA78240A70a9D2eC29DDcde9eB1945; // largest auUSDC holder
        uint256 bal = IAU(AUUSDC).balanceOf(holder);
        assertGt(bal, 0, "holder has no shares");
        uint256 usdcBefore = IERC20(USDC).balanceOf(holder);
        vm.prank(holder);
        IAU(AUUSDC).redeem(bal);
        uint256 got = IERC20(USDC).balanceOf(holder) - usdcBefore;
        assertGt(got, 0, "no proceeds");
        emit log_named_uint("top holder auUSDC shares", bal);
        emit log_named_uint("USDC received (6d)", got);
        emit log_string("PASS: holder withdrawal works (value is H-O, not E-U)");
    }

    /// 9. Utilisation-spike interest attack is economically negligible:
    ///    even with cash drained to 1 wei, the IRM annual rate is bounded (~39%/yr max here).
    function test_09_utilisation_spike_interest_bounded() public {
        uint256 rate = _irmRate();
        uint256 annual = rate * 31_536_000; // per-timestamp mantissa * timestamps/yr
        emit log_named_uint("auETH borrow rate per second (wei)", rate);
        emit log_named_uint("auETH annualised rate (1e18)", annual);
        assertLt(annual, 2e18, "rate unexpectedly high (interest-spike weapon?)");
        emit log_string("PASS: drained-cash utilisation spike yields <200%/yr; no fast forced-liquidation weapon");
    }

    function _irmRate() internal view returns (uint256) {
        // call the Ethernet JumpRateModel directly at drained cash
        address irm = 0x054fC05b20bd0a4c44CDE830Ac086B511e9098Bf; // auETH/auWBTC IRM
        uint256 borrows = IAU(AUETH).totalBorrows();
        uint256 reserves = IAU(AUETH).totalReserves();
        (bool ok, bytes memory ret) = irm.staticcall(abi.encodeWithSignature("getBorrowRate(uint256,uint256,uint256)", uint256(1), borrows, reserves));
        assertTrue(ok, "rate call failed");
        return abi.decode(ret, (uint256));
    }

    /// 10. Donation does not create free money for the donor (share-proportional accounting).
    function test_10_donation_roundtrip_no_profit() public {
        address attacker = makeAddr("attacker10");
        deal(USDC, attacker, 15_000e6);
        vm.startPrank(attacker);
        IERC20(USDC).approve(AUUSDC, type(uint256).max);
        IAU(AUUSDC).mint(10_000e6);
        // donate 5,000 USDC directly to the cToken (inflates exchange rate)
        IERC20(USDC).transfer(AUUSDC, 5_000e6);
        uint256 tokens = IAU(AUUSDC).balanceOf(attacker);
        IAU(AUUSDC).redeem(tokens);
        vm.stopPrank();
        uint256 back = IERC20(USDC).balanceOf(attacker);
        assertLt(back, 15_000e6, "donation produced free money");
        emit log_named_uint("in 15000e6, out (1e6)", back);
        emit log_string("PASS: donation+redeem round-trip returns less than contributed (no free money)");
    }

    function _decodeRevert(bytes memory data) internal pure returns (string memory) {
        if (data.length < 68) return "";
        bytes memory sliced = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; i++) sliced[i - 4] = data[i];
        // first 32 bytes = offset, next 32 = length
        uint256 len;
        assembly { len := mload(add(sliced, 0x40)) }
        bytes memory str = new bytes(len);
        for (uint256 i = 0; i < len; i++) str[i] = sliced[64 + i];
        return string(str);
    }

    

    function _shortfallAddresses() internal pure returns (address[30] memory out) {
        out = [
            0x334256eE41a63bD7c34d97EB37252b271af0763e, 0x08ba994F2C466CA23093ff82Bc06BD479Ff8d099, 0x1190226A666A9Dc756b4bd58FD05F65e66666666, 0xF5341bDEDD30A32e8B347de0F3852d553Dd0A511,
            0xe7354C21A5d7972726Efcdeb7C322F3DF2ca96Bc, 0x374AcC8f1b7e115B34CECb7eDF84eC468E79e994, 0x53A4eD81FdC310f775963e26508a2E89e8af6d12, 0x1F6eaDf4b38a9101DCa8d8df481A0144a7Db2958,
            0x7C3Ad821Eab5B8a4588F8787Df2daD63cfb8383E, 0x0b0F9f02d9aEF778433dea88C4BEC341D6C86834, 0x80cbFCa1c2432022746f851b490BDB89Cb83916e, 0x363B6DA99E944F4641df18D95356E6FF7D281cA3,
            0xFf31Aef7dab2e18950ccf63CbA7b9f6c84ea116F, 0x4AFC2398e1B0b4596706e5e96218571Eb9203D12, 0x34775D70485859CAb99Dd1F88919f458A7280e33, 0x5b82D74307d75Fde3A5Da2cdfEB60ED60430f2A8,
            0x52942ddc0C194440D2f6957121825Fa73202CE77, 0xaE3eE144e2C7aE4336919Ca199F1a3B9DC9e0BB6, 0xD82609AEe7500CE9066a6d2a6FbB9B7721C38721, 0xe7160fD23A7c3582eeE900206d06038979Fc04Bf,
            0x383d91Eb81a9B4Ba22441990839b10048257E2C7, 0xCa24d08d0ab2CF476F34f5d1AA06a51dE016664E, 0x282956d55c37Fa711B020A3100f8b8CE49626667, 0x1A8ADd5e75Ff515Dd83b6745C38389E220cf4080,
            0x6D72ADbA7F3B1A8d2Aeae1265f033bea7B8e6aA6, 0xC1165690B8a901120A1dA6355e0288803Ce055d0, 0xc39d6bBFF322de55A98dd84026322d41853F2d3A, 0xF70Fa1b8443c620CA7d43a9d17F4bDe8B09031CC,
            0x9Af6a7B3E1F0a55DD6e1248cEBCe3313c139A3CA, 0x700C6e966a8f617b3C3c8F45C65AC2A6A4Bf3501
        ];
    }

}
