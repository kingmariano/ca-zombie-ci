// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function mint(address, uint256) external;
}

interface IAU {
    function mint(uint256) external;
    function redeem(uint256) external;
    function redeemUnderlying(uint256) external;
    function borrow(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function getCash() external view returns (uint256);
    function sweepToken(address token) external;
    function accrualBlockTimestamp() external view returns (uint256);
}

interface IUnitroller {
    function getAllMarkets() external view returns (address[] memory);
    function borrowCaps(address) external view returns (uint256);
    function enterMarkets(address[] calldata) external;
    function claimReward(uint8, address) external;
    function rewardAccrued(uint8, address) external view returns (uint256);
    function rewardSpeeds(uint8, address, bool) external view returns (uint256);
    function rewardSupplyState(uint8, address) external view returns (uint224, uint32);
    function getAccountLiquidity(address) external view returns (uint256, uint256);
}

contract MockERC20 {
    string public name = "MOCK";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract ForkAuditTest is Test {
    address constant UNIT    = 0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb;
    address constant AUUSDC  = 0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b;
    address constant AUETH   = 0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9;
    address constant USDC    = 0xB12BFcA5A55806AaF64E99521918A4bf0fC40802;
    address constant ADMIN   = 0x2D05FfFE70CE64c5954710D4C308dB31C8dBd8dE;
    address constant AUWNEAR = 0xaE4fac24dCdAE0132C6d04f564dCf059616E9423;
    address constant WNEAR   = 0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d;
    address constant AUTRI   = 0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca;
    address constant AUPLY   = 0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c;
    address constant PLY     = 0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f;

    function setUp() public {
        vm.createSelectFork(vm.envOr("AURORA_RPC_URL", string("https://mainnet.aurora.dev")));
    }

    /// A) sweepToken has NO admin check in the deployed AuErc20: any EOA can
    ///    force the cToken to move a non-underlying token balance to the admin Safe.
    function test_sweepToken_missing_admin_check() public {
        MockERC20 mock = new MockERC20();
        mock.mint(AUUSDC, 1_000e18);
        assertEq(mock.balanceOf(ADMIN), 0);

        vm.prank(address(0xBEEF));
        IAU(AUUSDC).sweepToken(address(mock)); // no revert expected

        assertEq(mock.balanceOf(ADMIN), 1_000e18, "funds not moved to admin");
        assertEq(mock.balanceOf(AUUSDC), 0);
        emit log_string("CONFIRMED: sweepToken callable by anyone (upstream Compound requires msg.sender==admin)");
    }

    /// A2) The same hole lets anyone sweep a DIFFERENT market's underlying if the
    ///     cToken ever holds it (e.g. accidental transfer). Recipient is admin, not attacker.
    function test_sweepToken_cross_market_underlying_goes_to_admin() public {
        MockERC20 mock = new MockERC20(); // stand-in for a foreign underlying
        mock.mint(AUWNEAR, 5e17);
        vm.prank(address(0xBEEF));
        IAU(AUWNEAR).sweepToken(address(mock));
        assertEq(mock.balanceOf(ADMIN), 5e17);
        emit log_string("CONFIRMED: cross-token sweep also open; recipient fixed to admin => griefing only");
    }

    /// B) redeem(type(uint).max) and redeemUnderlying(type(uint).max) cannot extract more than fair value.
    function test_redeem_max_paths_no_gain() public {
        address attacker = makeAddr("attacker");
        deal(USDC, attacker, 1_000e6);
        vm.startPrank(attacker);
        IERC20(USDC).approve(AUUSDC, type(uint256).max);
        IAU(AUUSDC).mint(1_000e6);
        uint256 shares = IAU(AUUSDC).balanceOf(attacker);
        assertGt(shares, 0);
        IAU(AUUSDC).redeem(type(uint256).max);
        uint256 got = IERC20(USDC).balanceOf(attacker);
        assertEq(IAU(AUUSDC).balanceOf(attacker), 0, "not fully redeemed");
        assertLe(got, 1_000e6, "redeem(max) produced profit");
        emit log_named_uint("redeem(max) returned (1e6)", got);

        // now the redeemUnderlying(max) path on a fresh mint (use remaining balance)
        uint256 rem = IERC20(USDC).balanceOf(attacker);
        IAU(AUUSDC).mint(rem);
        IAU(AUUSDC).redeemUnderlying(type(uint256).max);
        got = IERC20(USDC).balanceOf(attacker);
        assertLe(got, 1_000e6, "redeemUnderlying(max) produced profit");
        vm.stopPrank();
        emit log_named_uint("cumulative after redeemUnderlying(max) (1e6)", got);
        emit log_string("PASS: both custom max-redeem paths are value-conserving");
    }

    /// B2) 24-decimal markets (auWNEAR, auSTNEAR): mint/redeem round-trip is value-conserving.
    function test_roundtrip_24dec_markets() public {
        address attacker = makeAddr("attacker24");
        deal(WNEAR, attacker, 100e24);
        deal(STNEAR, attacker, 100e24);
        vm.startPrank(attacker);
        IERC20(WNEAR).approve(AUWNEAR, type(uint256).max);
        IERC20(STNEAR).approve(AUSTNEAR, type(uint256).max);
        IAU(AUWNEAR).mint(100e24);
        uint256 t1 = IAU(AUWNEAR).balanceOf(attacker);
        assertGt(t1, 0);
        IAU(AUWNEAR).redeem(t1);
        assertEq(IAU(AUWNEAR).balanceOf(attacker), 0);
        uint256 wback = IERC20(WNEAR).balanceOf(attacker);
        assertLe(wback, 100e24, "auWNEAR round-trip gained");
        IAU(AUSTNEAR).mint(100e24);
        uint256 t2 = IAU(AUSTNEAR).balanceOf(attacker);
        IAU(AUSTNEAR).redeem(t2);
        uint256 sback = IERC20(STNEAR).balanceOf(attacker);
        assertLe(sback, 100e24, "auSTNEAR round-trip gained");
        vm.stopPrank();
        emit log_named_uint("auWNEAR in/out (1e24 units) 100 /", wback / 1e24);
        emit log_named_uint("auSTNEAR in/out (1e24 units) 100 /", sback / 1e24);
        emit log_string("PASS: 24-dec markets round-trip without gain");
    }

    /// B3) native auETH mint/redeem round-trip via payable path.
    function test_eth_roundtrip() public {
        address attacker = makeAddr("attackerETH");
        vm.deal(attacker, 5 ether);
        vm.prank(attacker);
        IAU(AUETH).mint{value: 5 ether}();
        uint256 shares = IAU(AUETH).balanceOf(attacker);
        assertGt(shares, 0);
        vm.prank(attacker);
        IAU(AUETH).redeem(shares);
        uint256 bal = attacker.balance;
        assertLe(bal, 5 ether, "auETH round-trip gained");
        emit log_named_uint("auETH in/out (wei) 5e18 /", bal);
        emit log_string("PASS: auETH native roundtrip value-conserving");
    }

    /// C) A brand-new supplier cannot capture pre-entry PLY index growth: index is
    ///    snapshotted in mintAllowed BEFORE shares are credited.
    function test_reward_no_retro_capture_with_timewarp() public {
        address attacker = makeAddr("attackerR");
        deal(USDC, attacker, 200_000e6);
        uint256 budget = 20_000e6;

        // accrue 30 days of index growth before the attacker enters
        vm.warp(block.timestamp + 30 days);
        (uint224 idxPre,) = IUnitroller(UNIT).rewardSupplyState(0, AUUSDC);

        vm.startPrank(attacker);
        IERC20(USDC).approve(AUUSDC, type(uint256).max);
        IAU(AUUSDC).mint(budget);
        // claim immediately (accrued for pre-mint balance = 0 => 0)
        IUnitroller(UNIT).claimReward(0, attacker);
        uint256 early = IERC20(PLY).balanceOf(attacker);
        vm.stopPrank();

        assertLt(early, 1e6, "fresh minter captured retroactive PLY");
        emit log_named_uint("PLY gained immediately after mint (wei)", early);

        // hold 30 days then claim: only post-entry growth
        vm.warp(block.timestamp + 30 days);
        (uint224 idx2,) = IUnitroller(UNIT).rewardSupplyState(0, AUUSDC);
        vm.prank(attacker);
        IUnitroller(UNIT).claimReward(0, attacker);
        uint256 later = IERC20(PLY).balanceOf(attacker) - early;
        emit log_named_uint("PLY gained after 30d hold (wei)", later);
        // 1 wei/s speed * 30d = 2,592,000 wei * attacker share (<1% of supply)
        assertLt(later, 100_000, "reward math leak?");
        emit log_named_uint("index pre-entry", uint256(idxPre));
        emit log_named_uint("index after entry+30d", uint256(idx2));
        emit log_string("PASS: no retroactive reward capture; growth after entry only");
    }

    /// D) Dead markets (CF=0/oracle-unset) cannot be entered by a fresh account.
    function test_dead_markets_unenterable() public {
        address a = makeAddr("newbie");
        address[] memory m = new address[](1);
        m[0] = AUTRI;
        vm.prank(a);
        vm.expectRevert(); // MarketCollateralFactorZero
        IUnitroller(UNIT).enterMarkets(m);
        m[0] = AUPLY;
        vm.prank(a);
        vm.expectRevert();
        IUnitroller(UNIT).enterMarkets(m);
        emit log_string("PASS: CF=0 markets cannot be joined; oracle-revert markets unreachable");
    }

    /// E) borrow(0) edge: cap check is strict `<`, so 0 passes on a zero-debt market;
    ///    verify it cannot be leveraged to move cash or gain liquidity.
    function test_borrow_zero_is_inert() public {
        address a = makeAddr("borrower0");
        (uint256 liq0, uint256 short0) = IUnitroller(UNIT).getAccountLiquidity(a);
        vm.prank(a);
        IAU(AUWNEAR).borrow(0);
        (uint256 liq1, uint256 short1) = IUnitroller(UNIT).getAccountLiquidity(a);
        assertEq(liq0, liq1);
        assertEq(short0, short1);
        assertEq(IERC20(WNEAR).balanceOf(a), 0);
        emit log_string("PASS: borrow(0) is inert (no cash, no liquidity change)");
    }
}
