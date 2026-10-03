// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// Attacker-controlled implementation (attempted executor takeover).
contract AttackerExecutor {
    function pwn(address target, address newImpl) external returns (bool ok) {
        (ok, ) = target.call(abi.encodeWithSelector(0x3659cfe6, newImpl));
    }
}

/// Attacker-controlled drainer implementation (attempted proxy takeover).
contract AttackerDrainer {
    function drain(address payable to) external {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @title H-07 — executor-takeover -> proxy-takeover -> drain: CLOSED
/// @notice Documents (with assertions) that the naive takeover chain does NOT
///         work live. Read-only fork simulation; no mainnet transactions.
contract ClayStackH07AttackTest is Test {
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8;
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA;

    address attacker = address(0xB0B);
    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 10 ether);
    }

    function _implOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPL_SLOT))));
    }

    /// Step 1: an unprivileged EOA cannot overwrite the executor's implementation.
    /// upgradeTo() returns success but is a no-op (the ERC1967 slot is unchanged).
    function test_h07_step1_executor_upgrade_is_noop() public {
        address before = _implOf(EXECUTOR);
        assertEq(before, 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59, "executor impl is the frozen manager");

        AttackerExecutor evil = new AttackerExecutor();
        vm.prank(attacker);
        (bool ok, ) = EXECUTOR.call(abi.encodeWithSelector(0x3659cfe6, address(evil)));
        emit log_named_string("executor.upgradeTo returned ok?", ok ? "yes (no-op)" : "reverted");
        address afterImpl = _implOf(EXECUTOR);
        emit log_named_address("executor impl after", afterImpl);
        assertEq(afterImpl, before, "executor impl must NOT change");
    }

    /// Step 2: the full takeover chain fails; no ETH leaves the protocol.
    function test_h07_step2_takeover_chain_is_closed() public {
        AttackerExecutor evil = new AttackerExecutor();
        AttackerDrainer drainer = new AttackerDrainer();

        uint256 clayBefore = CLAYMAIN.balance;
        uint256 clay2Before = CLAYMAIN2.balance;
        uint256 attBefore = attacker.balance;

        // 1) take over executor (no-op)
        vm.prank(attacker);
        (bool ok1, ) = EXECUTOR.call(abi.encodeWithSelector(0x3659cfe6, address(evil)));
        assertEq(_implOf(EXECUTOR), 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59, "executor not taken over");
        emit log_named_string("1) executor takeover", ok1 ? "no-op" : "reverted");

        // 2) use executor to upgrade clayMain (impossible: executor cannot reach a working upgrade path)
        vm.prank(attacker);
        (bool ok2, ) = EXECUTOR.call(abi.encodeWithSelector(AttackerExecutor.pwn.selector, CLAYMAIN, address(drainer)));
        emit log_named_string("2) executor->clayMain upgrade", ok2 ? "call ok" : "reverted");
        assertEq(_implOf(CLAYMAIN), 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59, "clayMain not taken over");

        // 3) drain attempt reverts (unknown selector on the frozen manager)
        vm.prank(attacker);
        (bool ok3, ) = CLAYMAIN.call(abi.encodeWithSelector(AttackerDrainer.drain.selector, attacker));
        emit log_named_string("3) clayMain.drain", ok3 ? "ok" : "reverted");
        assertFalse(ok3, "drain must revert");

        // 4) same for clayMain2
        vm.prank(attacker);
        (bool ok4, ) = EXECUTOR.call(abi.encodeWithSelector(AttackerExecutor.pwn.selector, CLAYMAIN2, address(drainer)));
        vm.prank(attacker);
        (bool ok5, ) = CLAYMAIN2.call(abi.encodeWithSelector(AttackerDrainer.drain.selector, attacker));
        assertFalse(ok4 && ok5, "clayMain2 chain must fail");

        // invariants: no protocol ETH moved, attacker did not profit
        assertEq(CLAYMAIN.balance, clayBefore, "clayMain ETH unchanged");
        assertEq(CLAYMAIN2.balance, clay2Before, "clayMain2 ETH unchanged");
        assertEq(attacker.balance, attBefore, "attacker did not profit");
        emit log_named_decimal_uint("clayMain ETH (stuck)", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("clayMain2 ETH (stuck)", CLAYMAIN2.balance, 18);
    }

    /// Share math: outstanding csETH vs ETH held by its clayMain.
    function test_h07_share_math() public {
        (bool ok, bytes memory ret) = CLAYMAIN.staticcall(abi.encodeWithSignature("totalSupply()"));
        // clayMain has no totalSupply; read the token instead
        (bool ok2, bytes memory ret2) = 0x5d74468b69073f809D4FaE90AfeC439e69Bf6263.staticcall(
            abi.encodeWithSignature("totalSupply()"));
        require(ok2, "token supply");
        uint256 supply = abi.decode(ret2, (uint256));
        uint256 backing = CLAYMAIN.balance;
        emit log_named_decimal_uint("csETH supply", supply, 18);
        emit log_named_decimal_uint("clayMain ETH backing", backing, 18);
        emit log_named_decimal_uint("backing per csETH (1e18)", backing * 1e18 / supply, 18);
        assertGt(backing, supply, "backing exceeds supply (dust surplus)");
        assertLt(backing, supply * 102 / 100, "backing within 2% of supply");
        ok;
        ret;
    }
}
