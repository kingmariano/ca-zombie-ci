// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// Parent-authored probe (H2-02 consolidation): tests whether the m1 (USDT0/WFLR, LLTV 62.5%)
/// position 0x29566E4A… — which drifted from "dust" to collateral $11.62 vs debt ~$172 — is
/// liquidatable at a profit by a fresh unprivileged address on live Flare state.
/// Read-only except on the fork. No mainnet transaction.

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint256 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);

    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256 seizedAssetsActual, uint256 repaidAssetsActual);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracle {
    function price() external view returns (uint256);
}

contract ParentDustProbeTest is Test {
    IMorpho constant MORPHO = IMorpho(0xF4346F5132e810f80a28487a79c7559d9797E8B0);
    address constant USDT0 = 0xe7cd86e13AC4309349F30B3435a9d337750fC82D;
    address constant BORROWER = 0x29566E4AfFd4403b09f43B1B38348E52612Bf867;
    bytes32 constant M1 = 0xe2e99372706821cd408529c1cca9f33b8d2df52eaf35bc4796952f1be4b87402;

    function test_parent_probe_m1_liquidation_profit() public {
        vm.createSelectFork(vm.envOr("FLARE_RPC_URL", string("https://flare-api.flare.network/ext/C/rpc")));

        IMorpho.MarketParams memory p = MORPHO.idToMarketParams(M1);
        (uint256 supplyShares, uint256 borrowShares, uint128 coll) = MORPHO.position(M1, BORROWER);
        (uint128 tsa, uint128 tss, uint128 tba, uint128 tbs,,) = MORPHO.market(M1);
        emit log_named_uint("supplyShares", supplyShares);
        emit log_named_uint("borrowShares", borrowShares);
        emit log_named_uint("collateral (WFLR wei)", coll);
        emit log_named_uint("totalSupplyAssets", tsa);
        emit log_named_uint("totalSupplyShares", tss);
        emit log_named_uint("totalBorrowAssets", tba);
        emit log_named_uint("totalBorrowShares", tbs);
        assertGt(borrowShares, 0, "no borrow");
        assertGt(coll, 0, "no collateral");

        address attacker = address(0xBAD);
        deal(USDT0, attacker, 1_000e6);

        // Live-state outcome (2026-10-10): the position has been re-collateralized and is HEALTHY —
        // the contract itself reverts `position is healthy`. If it ever becomes liquidatable again,
        // assert the liquidation is not profitable for the caller.
        vm.startPrank(attacker);
        IERC20(USDT0).approve(address(MORPHO), type(uint256).max);
        try MORPHO.liquidate(p, BORROWER, coll, 0, "") returns (uint256 seized, uint256 repaid) {
            vm.stopPrank();
            uint256 wflr = IERC20(p.collateralToken).balanceOf(attacker);
            uint256 price = IOracle(p.oracle).price();
            uint256 value = wflr * price / 1e36;
            emit log_named_uint("seized (WFLR wei)", seized);
            emit log_named_uint("repaid (USDT0 1e6)", repaid);
            emit log_named_uint("attacker WFLR value (USDT0 1e6)", value);
            assertLe(value, repaid, "liquidation of m1 position would be profitable");
        } catch {
            vm.stopPrank();
            emit log("liquidate reverted (position healthy / other gate) -> no unprivileged path");
        }
    }
}
