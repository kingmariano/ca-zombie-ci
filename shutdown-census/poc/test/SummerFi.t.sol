// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IAutomationExecutor {
    function execute(
        bytes calldata executionData,
        bytes calldata triggerData,
        address commandAddress,
        uint256 triggerId,
        uint256 txCoverage,
        uint256 minerBribe,
        int256 gasRefund,
        address coverageToken
    ) external;

    function owner() external view returns (address);

    function callers(address) external view returns (bool);
}

interface IAutomationBotV2 {
    function execute(
        bytes calldata executionData,
        bytes calldata triggerData,
        address commandAddress,
        uint256 triggerId,
        uint256 coverageAmount,
        address coverageToken
    ) external;

    function serviceRegistry() external view returns (address);
}

interface IServiceRegistry {
    function getRegisteredService(string calldata key) external view returns (address);
}

interface IGnosisSafe {
    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);
}

/// @title Summer.fi (AutomationBot V2 / AutomationExecutor) — permissionless-path negative proof
/// @notice Proves the V2 automation execution path is keeper-gated (P), not externally extractable.
contract SummerFi is Test {
    address constant EXECUTOR = 0xe145976Cba0383A44D8B46caEb36ab28fe0A9cC2;
    address constant BOT = 0x5743b5606E94Fb534a31e1ceFB3242C8A9422e5E;
    address constant OWNER_SAFE = 0x85f9b7408afE6CEb5E46223451f5d4b832B522dc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))));
    }

    /// @dev attacker is not in the executor's caller whitelist -> execute reverts before touching any position
    function test_attackerCannotExecuteViaExecutor() public {
        address attacker = makeAddr("attacker");
        IAutomationExecutor ex = IAutomationExecutor(EXECUTOR);
        assertFalse(ex.callers(attacker), "attacker unexpectedly whitelisted");

        vm.prank(attacker);
        vm.expectRevert(bytes("executor/not-authorized"));
        ex.execute("", "", address(0), 0, 0, 0, 0, address(0));
    }

    /// @dev attacker is not the registered executor -> bot.execute reverts
    function test_attackerCannotExecuteViaBot() public {
        address attacker = makeAddr("attacker");
        IAutomationBotV2 bot = IAutomationBotV2(BOT);
        vm.prank(attacker);
        vm.expectRevert(bytes("bot/not-executor"));
        bot.execute("", "", address(0), 0, 0, address(0));
    }

    /// @dev live governance facts: owner is a 2-of-4 Safe, registered executor is the AutomationExecutor
    function test_liveGovernanceFacts() public view {
        IGnosisSafe safe = IGnosisSafe(OWNER_SAFE);
        assertEq(safe.getThreshold(), 2, "threshold changed");
        assertEq(safe.getOwners().length, 4, "owner count changed");

        IAutomationBotV2 bot = IAutomationBotV2(BOT);
        IServiceRegistry sr = IServiceRegistry(bot.serviceRegistry());
        assertEq(sr.getRegisteredService("AUTOMATION_EXECUTOR_V2"), EXECUTOR, "executor registration changed");
    }
}
