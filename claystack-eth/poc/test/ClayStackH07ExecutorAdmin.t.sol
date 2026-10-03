// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";

contract ClayStackH07ExecutorAdminTest is Test {
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant IMPL = 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59;
    address constant PROXYADMIN = 0x084A0738A29a3Bfc233D3cb318FF7B63d97d49e4;
    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
    }

    function test_h07_proxyadmin_can_upgrade_executor() public {
        // (address,bytes)
        vm.prank(PROXYADMIN);
        (bool ok1, bytes memory r1) = EXECUTOR.call(abi.encodeWithSelector(0x278f7943, IMPL, ""));
        emit log_named_string("0x278f7943(impl,bytes) as ProxyAdmin", ok1 ? "ok" : "revert");
        if (!ok1) emit log_named_bytes("  revert", r1);
        // (address,uint256)
        vm.prank(PROXYADMIN);
        (bool ok2, bytes memory r2) = EXECUTOR.call(abi.encodeWithSelector(0x278f7943, IMPL, uint256(0)));
        emit log_named_string("0x278f7943(impl,uint) as ProxyAdmin", ok2 ? "ok" : "revert");
        if (!ok2) emit log_named_bytes("  revert", r2);
        // (address,address)
        vm.prank(PROXYADMIN);
        (bool ok3, bytes memory r3) = EXECUTOR.call(abi.encodeWithSelector(0x278f7943, IMPL, address(this)));
        emit log_named_string("0x278f7943(impl,addr) as ProxyAdmin", ok3 ? "ok" : "revert");
        if (!ok3) emit log_named_bytes("  revert", r3);
        emit log_named_address("executor impl (unchanged expected)", address(uint160(uint256(vm.load(EXECUTOR, IMPL_SLOT)))));
    }
}
