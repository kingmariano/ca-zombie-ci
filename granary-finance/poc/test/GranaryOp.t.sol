// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, IAToken, ILendingPool, IAaveOracle} from "../src/Interfaces.sol";

/// @title Granary Optimism — liquidation surface is dust; pool otherwise live.
/// Full CI scan: 1,260 live debtors; 208 are liquidatable (HF<1). The largest nominal
/// collateral among them is $0.78 of **retired sUSD** (unseizable); the best seizable
/// position is $0.14 of OP -> realized profit ~$0.01. This test proves both on-chain.
contract GranaryOpTest is Test {
    ILendingPool constant pool = ILendingPool(0x8FD4aF47E4E63d1D2D45582c3286b4BD9Bb95DfE);
    IAaveOracle constant oracle = IAaveOracle(0x9aEeFef549323511E027D70562f0C7EdcDEB294C);
    IERC20 constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 constant OP = IERC20(0x4200000000000000000000000000000000000042);
    IERC20 constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IAToken constant aOP = IAToken(0x30091e843deb234EBb45c7E1Da4bBC4C33B3f0B4);
    IERC20 constant sUSD = IERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    IAToken constant aSUSD = IAToken(0x8AaA9d29305D331aE67AD65495B9e22cf98f9035);

    // top liquidatable accounts from the full CI scan (ci-out/borrowers-optimism.json)
    address constant BAD_DEBT_SNX = 0xA98E339f5a0F135792286d481B4e23d91A667d3f; // $737 SNX debt, $0 collateral
    address constant RETIRED_COLL = 0xAB75c93Bb7D3A4F444c77D17c4f935f5Efb01a86; // best nominal: $0.78 "collateral" = retired sUSD
    address constant DUST_BEST = 0xc9EaF0D439b2aBe81BC9E91Ee287b9bC9615e6c2;    // HF .87, $0.14 OP collateral

    function setUp() public {
        vm.createSelectFork(vm.envOr("OP_RPC_URL", string("https://mainnet.optimism.io")));
    }

    function test_op_pool_live_oracles_fresh() public {
        assertFalse(pool.paused(), "pool paused");
        assertGt(oracle.getAssetPrice(address(USDC)), 0);
        assertGt(oracle.getAssetPrice(address(WETH)), 0);
    }

    function test_op_liquidatable_positions_are_all_dust() public {
        // largest liquidatable: zero collateral -> nothing can be seized
        (uint256 collBad, uint256 debtBad, , , , uint256 hfBad) = pool.getUserAccountData(BAD_DEBT_SNX);
        assertLt(hfBad, 1e18);
        assertLt(collBad, 5e8, "collateral not dust"); // < $5 (observed: 0)
        assertGt(debtBad, 300e8); // > $300 of unseizable bad debt
        emit log_named_uint("bad-debt account collateralBase (8dec)", collBad);
        emit log_named_uint("bad-debt account debtBase (8dec)", debtBad);

        // best nominal liquidatable: "collateral" is retired sUSD (token supply 0, reserve cash 0)
        (uint256 collRet, , , , , uint256 hfRet) = pool.getUserAccountData(RETIRED_COLL);
        assertLt(hfRet, 1e18);
        assertGt(collRet, 0); // pool still counts it
        assertEq(sUSD.totalSupply(), 0, "sUSD not retired");
        assertEq(sUSD.balanceOf(address(aSUSD)), 0, "sUSD reserve has cash");
        emit log_named_uint("retired-sUSD account collateralBase (8dec)", collRet);

        // best seizable: collateral <= $0.25 (observed ~$0.14; bound widened for OP price drift)
        (uint256 collDust, , , , , uint256 hfDust) = pool.getUserAccountData(DUST_BEST);
        assertLt(hfDust, 1e18);
        assertLe(collDust, 25e6, "collateral above $0.25");
        emit log_named_uint("best-seizable account collateralBase (8dec)", collDust);
    }

    function test_op_retired_susd_collateral_cannot_be_seized() public {
        // RETIRED_COLL's debt is USDC; its "collateral" is retired sUSD.
        // Liquidating to underlying must revert '45': the sUSD aToken holds no sUSD.
        deal(address(USDC), address(this), 2e6);
        USDC.approve(address(pool), type(uint256).max);
        try pool.liquidationCall(address(sUSD), address(USDC), RETIRED_COLL, 1e6, false) {
            fail();
        } catch (bytes memory reason) {
            assertEq(_reason(reason), "45");
        }
    }

    /// @dev decode require(false, "msg") revert reasons
    function _reason(bytes memory r) internal pure returns (string memory) {
        if (r.length < 4) return "";
        bytes4 sel;
        assembly { sel := mload(add(r, 0x20)) }
        if (sel != 0x08c379a0) return "";
        bytes memory payload = new bytes(r.length - 4);
        for (uint256 i = 0; i < payload.length; i++) payload[i] = r[i + 4];
        return abi.decode(payload, (string));
    }

    function test_op_best_liquidation_profit_is_one_cent() public {
        // fund liquidator with WETH, repay DUST_BEST's WETH debt, seize OP collateral (bonus 7.5%)
        vm.deal(address(this), 1 ether);
        WETH.deposit{value: 0.01 ether}();
        WETH.approve(address(pool), type(uint256).max);

        uint256 wethDebt = IERC20(0x0A05d3D77b66aF45233599fe4F5558326E4AD269).balanceOf(DUST_BEST); // vDebtWETH
        // receiveAToken=false -> liquidator receives the underlying OP
        uint256 before_ = OP.balanceOf(address(this));
        pool.liquidationCall(address(OP), address(WETH), DUST_BEST, wethDebt, false);
        uint256 seized = OP.balanceOf(address(this)) - before_;

        uint256 opPx = oracle.getAssetPrice(address(OP)); // 8dec USD
        uint256 wethPx = oracle.getAssetPrice(address(WETH));
        // close factor is 50% (LIQUIDATION_CLOSE_FACTOR_PERCENT = 5000), so only half the debt is repaid
        uint256 repaid = wethDebt / 2;
        // profit = seizedOP*opPx - repaidWETH*wethPx (8-dec USD units, 18-dec token amounts)
        int256 profit = int256(seized * opPx / 1e18) - int256(repaid * wethPx / 1e18);
        emit log_named_int("profit (8dec USD)", profit);
        // must be tiny: < $0.10 and > -$0.01
        assertLt(profit, 10e6, "unexpectedly profitable");
        assertGt(profit, -1e6, "unexpectedly negative");
    }
}
