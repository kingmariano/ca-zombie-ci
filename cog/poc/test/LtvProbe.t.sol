// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import "forge-std/Test.sol";
import {IERC20, ICogPair} from "../src/ICogPair.sol";

/// Empirical LTV probe for factory-1 Cog pairs (blueprint constant is not visible in Sourcify).
/// Tries to borrow the full pool balance with collateral set at 0.99x the amount required for
/// LTV = 75% / 80% / 85%; success brackets the deployed COLLATERIZATION_RATE.
contract LtvProbeTest is Test {
    address constant ATTACKER = address(0xA11CE);
    address constant CRV = 0xB755039eDc7910C1F1BD985D48322E55A31AC0bF;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant WETH = 0x5300000000000000000000000000000000000004;
    address constant RETH = 0x53878B874283351D26d206FA512aEcE1Bef6C0dD;
    address constant P_WCRV = 0x0C502351461904cd9430EeFdc7b9df1c30E74032;
    address constant P_RETH = 0xDeFeBD03E8E339737f24B67737E9d002CB03f00b;

    function setUp() public {
        vm.createSelectFork(vm.envOr("SCROLL_FORK_RPC", string("https://rpc.scroll.io")));
        vm.deal(ATTACKER, 1 ether);
    }

    function _need(uint256 B, uint256 rate, uint256 ltvE18) internal pure returns (uint256) {
        // ceil(B * 10005 * rate / (10000 * ltvE18))
        return (B * 10005 * rate) / (10000 * ltvE18) + 2;
    }

    function _try(PairCfg memory c) internal returns (bool) {
        uint256 snap = vm.snapshotState();
        deal(c.coll, ATTACKER, c.cs);
        vm.startPrank(ATTACKER);
        IERC20(c.coll).approve(c.pair, c.cs);
        ICogPair(c.pair).add_collateral(ATTACKER, c.cs);
        (bool ok, ) = c.pair.call(abi.encodeWithSelector(ICogPair.borrow.selector, c.B, ATTACKER, ATTACKER));
        vm.stopPrank();
        vm.revertToState(snap);
        return ok;
    }

    struct PairCfg { address pair; address coll; uint256 cs; uint256 B; }

    function _probe(string memory label, address pair, address coll, uint256 B) internal {
        ICogPair p = ICogPair(pair);
        (, uint256 rate) = p.get_exchange_rate();
        emit log_named_string("pair_label", label);
        emit log_named_uint("B", B);
        emit log_named_uint("rate", rate);
        for (uint256 i = 0; i < 4; i++) {
            uint256 ltv = i == 0 ? 75e16 : (i == 1 ? 80e16 : (i == 2 ? 85e16 : 75e16));
            uint256 cs = _need(B, rate, ltv);
            if (i < 3) cs = cs * 99 / 100; // 0.99x => fails unless real LTV > this
            if (i == 3) cs = cs * 102 / 100; // positive control: needs LTV >= 73.5%
            PairCfg memory c = PairCfg(pair, coll, cs, B);
            bool ok = _try(c);
            if (i == 0) emit log_named_uint("ok_at_0.99x_need75", ok ? 1 : 0);
            else if (i == 1) emit log_named_uint("ok_at_0.99x_need80", ok ? 1 : 0);
            else if (i == 2) emit log_named_uint("ok_at_0.99x_need85", ok ? 1 : 0);
            else emit log_named_uint("ok_positive_control_1.02x_need75", ok ? 1 : 0);
        }
    }

    function test_probe_ltv_weth_crv() public {
        _probe("weth/crv", P_WCRV, CRV, IERC20(WETH).balanceOf(P_WCRV));
    }

    function test_probe_ltv_reth_usdc() public {
        _probe("reth/usdc", P_RETH, USDC, IERC20(RETH).balanceOf(P_RETH));
    }
}
