// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

contract SmokeTest is Test {
    function test_pure() public pure {
        assertEq(uint256(1), 1);
    }

    function test_fork() public {
        string memory url = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(url);
        assertEq(block.chainid, 1);
        assertGt(block.number, 20_000_000);
        emit log_named_uint("fork block", block.number);
    }
}
