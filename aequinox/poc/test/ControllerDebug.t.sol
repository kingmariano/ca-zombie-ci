// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// Diagnostic: why does the Aequinox GaugeController checkpoint revert?
/// Read-only fork diagnostics; kept as evidence.
contract ControllerDebugTest is Test {
    address constant CONTROLLER = 0x585ECE7932226CCf5A259c367781F07EBBB1950F;
    address constant GAUGE = 0xaCC31d29022C8Eb2683597bF4c07De228Ed9EA07;
    address constant MINTER = 0xDe3258Fce4Afe0aB38CA3A61B21ACAD802250880;
    address constant VE = 0x06Aba6E8F69A0Be680f96D923EFB682E63Db6a9f;
    address constant TOKEN = 0x7a09ddF458FdA6e324A97D1a8E4304856fb3e702;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.bnbchain.org"));
        vm.createSelectFork(rpc);
    }

    function test_debug_checkpoint_gauge() public {
        emit log_named_uint("block.timestamp", block.timestamp);
        (bool ok, bytes memory ret) = CONTROLLER.call(abi.encodeWithSignature("checkpoint_gauge(address)", GAUGE));
        emit log_named_string("checkpoint_gauge ok", ok ? "true" : "false");
        emit log_bytes(ret);

        // static getters
        (bool ok2, bytes memory r2) = CONTROLLER.staticcall(abi.encodeWithSignature("gauge_types(address)", GAUGE));
        emit log_named_string("gauge_types ok", ok2 ? "true" : "false");
        emit log_bytes(r2);

        (bool ok3, bytes memory r3) = CONTROLLER.staticcall(abi.encodeWithSignature("get_gauge_weight(address)", GAUGE));
        emit log_named_string("get_gauge_weight ok", ok3 ? "true" : "false");
        emit log_bytes(r3);

        (bool ok4, bytes memory r4) =
            CONTROLLER.staticcall(abi.encodeWithSignature("gauge_relative_weight(address)", GAUGE));
        emit log_named_string("gauge_relative_weight ok", ok4 ? "true" : "false");
        emit log_bytes(r4);

        for (uint256 i = 0; i < 11; i++) {
            (bool okg, bytes memory rg) = CONTROLLER.staticcall(abi.encodeWithSignature("gauges(uint256)", i));
            if (okg) emit log_named_address("gauge", abi.decode(rg, (address)));
        }

        // other gauges: does checkpoint also revert?
        address[3] memory others =
            [0x00687547D75A2d1378984bE922e1450CcC89211E, 0x1dA7F4b2B9B644f307A313e304E1B061Eb605965, 0x34EA84d3565824573073b1A63057baf57f842F02];
        for (uint256 i = 0; i < 3; i++) {
            (bool okc,) = CONTROLLER.call(abi.encodeWithSignature("checkpoint_gauge(address)", others[i]));
            emit log_named_string("checkpoint other gauge ok", okc ? "true" : "false");
        }
    }
}
