// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IPool {
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function getUserAccountData(address user) external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function burn(address to) external returns (uint256, uint256);
}

interface IRouter {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory);
    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint256 amountA, uint256 amountB);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
}

interface IFavorToken {
    function logBuy(address user, uint256 amount) external;
    function pendingBonus(address) external view returns (uint256);
    function isBuyWrapper(address) external view returns (bool);
    function bonusRate() external view returns (uint256);
}

interface IMintRedeemer {
    function redeemFavor(uint256, address) external;
    function paused() external view returns (bool);
    function favorTokens(address) external view returns (bool);
}

interface IWrapper {
    function swapExactTokensForFavorAndTrackBonus(uint256, uint256, address[] calldata, address, uint256) external;
    function isFavorToken(address) external view returns (bool);
    function uniswapRouter() external view returns (address);
}

/// @title BetterBank (PulseChain) live-state + liquidation PoC
/// @notice Read-only mainnet research; runs only on a local fork. No mainnet txs.
contract BetterBankPoC is Test {
    // PulseChain mainnet addresses (verified on-chain, block ~27,709,8xx)
    address constant POOL      = 0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee;
    address constant DAI       = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WPLS      = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address constant PDAIF     = 0xBc91E5aE4Ce07D0455834d52a9A4Df992e12FE12;
    address constant COLL_LP   = 0x6A7E018d334b8cc9116010D8779CB5b4b0143adC; // oldPDAIF/DAI PulseX pair
    address constant COLL_ATKN = 0x29601fB5C87bE0fCE1A4438DF1d8992EC47c24d2; // bPlsPLP aToken for COLL_LP
    address constant ROUTER    = 0x165C3410fC91EF562C50559f7d2289fEbed552d9; // PulseXRouter02
    address constant WRAPPER   = 0x9361841A51bD90999FAc8382aBECf976273141F7;
    address constant REDEEMER  = 0x6bBC91c980780C393E9DAc11EC58684191De611d;
    address constant USER      = 0xB123a367E2C783A814719AbBCDdFD8016daA2bed; // HF ~0.00005, 62.03M LP collateral
    address constant WHALE_DAI = 0xaE8429918FdBF9a5867e3243697637Dc56aa76A1; // deep DAI/WPLS pair (holds 193M DAI)

    address attacker = address(0xA11CE);

    function forkUrl() internal view returns (string memory) {
        return vm.envOr("PULSE_RPC_URL", vm.envOr("FORK_RPC_URL_PULSE", string("https://rpc.pulsechain.com")));
    }

    function setUp() public {
        vm.createSelectFork(forkUrl());
        vm.deal(attacker, 100 ether);
    }

    function _fundDai(uint256 amount) internal {
        deal(DAI, attacker, amount);
        if (IERC20(DAI).balanceOf(attacker) < amount) {
            vm.prank(WHALE_DAI);
            IERC20(DAI).transfer(attacker, amount - IERC20(DAI).balanceOf(attacker));
        }
    }

    function test_liquidation_profitable() public {
        IPool pool = IPool(POOL);
        (uint256 coll0, uint256 debt0, , , , uint256 hf0) = pool.getUserAccountData(USER);
        emit log_named_uint("user collateral base (1e8)", coll0);
        emit log_named_uint("user debt base (1e8)", debt0);
        emit log_named_uint("user health factor (1e18)", hf0);
        assertLt(hf0, 1e18, "user must be liquidatable");

        uint256 lpBefore = IAToken(COLL_ATKN).balanceOf(USER);
        emit log_named_uint("user LP aToken collateral", lpBefore);
        assertGt(lpBefore, 0, "user has LP collateral");

        _fundDai(1_000e18);
        uint256 daiBefore = IERC20(DAI).balanceOf(attacker);
        emit log_named_uint("attacker DAI funded", daiBefore);
        assertGe(daiBefore, 1_000e18, "funding failed");

        vm.startPrank(attacker);
        IERC20(DAI).approve(POOL, type(uint256).max);

        // Permissionless liquidation: repay dust of oracle-priced DAI, seize LP collateral
        pool.liquidationCall(COLL_LP, DAI, USER, type(uint256).max, false);

        uint256 daiSpent = daiBefore - IERC20(DAI).balanceOf(attacker);
        uint256 lpAtk = IAToken(COLL_ATKN).balanceOf(attacker);
        uint256 lpBal = IERC20(COLL_LP).balanceOf(attacker);
        emit log_named_uint("DAI repaid", daiSpent);
        emit log_named_uint("LP aTokens seized", lpAtk);
        emit log_named_uint("LP tokens received (receiveAToken=false)", lpBal);
        assertGt(lpBal, 0, "seized collateral");

        // If collateral was delivered as aTokens, withdraw; otherwise already underlying
        if (lpAtk > 0) {
            pool.withdraw(COLL_LP, lpAtk, attacker);
            lpBal = IERC20(COLL_LP).balanceOf(attacker);
        }
        emit log_named_uint("LP tokens to redeem", lpBal);

        // Redeem LP for the pair's assets and sell the non-DAI side back into the pair
        IPair pair = IPair(COLL_LP);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        address t0 = pair.token0();
        address t1 = pair.token1();
        emit log_named_uint("pair reserve0", r0);
        emit log_named_uint("pair reserve1", r1);
        emit log_named_address("pair token0", t0);
        emit log_named_address("pair token1", t1);

        address t0b = pair.token0();
        address t1b = pair.token1();
        IERC20(COLL_LP).approve(ROUTER, lpBal);
        (uint256 a0, uint256 a1) = IRouter(ROUTER).removeLiquidity(t0b, t1b, lpBal, 0, 0, attacker, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("redeemed token0", a0);
        emit log_named_uint("redeemed token1", a1);

        address other = (t0 == DAI) ? t1 : t0;
        uint256 otherBal = IERC20(other).balanceOf(attacker);
        emit log_named_uint("non-DAI side received (oldPDAIF)", otherBal);
        // oldPDAIF blocks transfers to any contract ("Transfer not allowed") -> cannot be sold
        // through a router/pair; only the DAI side is realizable.
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Transfer not allowed"));
        IERC20(other).transfer(ROUTER, otherBal);
        vm.stopPrank();

        uint256 daiOut = IERC20(DAI).balanceOf(attacker) - (daiBefore - daiSpent);
        emit log_named_int("net DAI profit", int256(daiOut) - int256(daiSpent));
        assertGt(daiOut, daiSpent, "liquidation must be net-profitable in DAI terms");
    }

    function test_reward_paths_closed() public {
        // Current live state (block ~27,710,000): wrapper still registers the favor tokens and
        // the favor tokens still authorize the wrapper, ESTEEM minters are active -- BUT:
        //   (a) wrapper.uniswapRouter is an EOA (0xc070...deployer), so every swap reverts;
        //   (b) bonusRate == 0 -> logBuy computes zero bonus;
        //   (c) MintRedeemer is paused.
        // => no ESTEEM can be minted for value and none can be redeemed.
        assertTrue(IWrapper(WRAPPER).isFavorToken(PDAIF), "PDAIF registered in wrapper");
        assertTrue(IFavorToken(PDAIF).isBuyWrapper(WRAPPER), "wrapper still authorized (leftover)");
        assertEq(IFavorToken(PDAIF).bonusRate(), 0, "bonusRate must be 0");
        assertTrue(IMintRedeemer(REDEEMER).paused(), "redeemer paused");
        assertTrue(IMintRedeemer(REDEEMER).favorTokens(PDAIF), "PDAIF activated but paused");

        address router = IWrapper(WRAPPER).uniswapRouter();
        emit log_named_address("wrapper.uniswapRouter (EOA!)", router);
        assertEq(router, 0xc0702Ae0374F83fc3bA71CE2B30A323b09EC19da, "router is the deployer EOA");
        assertEq(router.code.length, 0, "router has no code -> swaps always revert");

        _fundDai(10e18);
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = PDAIF;
        vm.startPrank(attacker);
        IERC20(DAI).approve(WRAPPER, 10e18);
        vm.expectRevert();
        IWrapper(WRAPPER).swapExactTokensForFavorAndTrackBonus(1e18, 0, path, attacker, block.timestamp);
        vm.stopPrank();

        // Direct logBuy from an unprivileged address is rejected
        vm.prank(attacker);
        vm.expectRevert(bytes("Only approved buy wrapper can log buys"));
        IFavorToken(PDAIF).logBuy(attacker, 1e18);
    }

    function test_drained_reserves_are_stuck() public {
        // WPLS/DAI/PLSX reserves: aTokens exist but the pool holds 0 underlying -> S (stuck)
        IPool pool = IPool(POOL);
        (uint256 coll, uint256 debt, , , , ) = pool.getUserAccountData(0x281C0f611ddaA6F5dB41aD7A1026c2F452B90822);
        emit log_named_uint("sample WPLS/DAI/PLSX borrower collateral", coll);
        emit log_named_uint("sample borrower debt", debt);
        assertGt(debt, 0, "bad debt exists");
    }
}
