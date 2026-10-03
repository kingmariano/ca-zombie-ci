// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @title H-07 ClayStack ETH — live extractability boundary tests
/// @notice READ-ONLY against an Ethereum fork. No mainnet transactions.
///         All calls are simulated on a local fork only.
contract ClayStackH07Test is Test {
    // ---- live addresses (Ethereum mainnet) ----
    address constant CSETH = 0x5d74468b69073f809D4FaE90AfeC439e69Bf6263;
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8; // csETH clayMain
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051; // 2nd frozen proxy
    address constant IMPL = 0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59; // current shared impl
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519; // executor proxy
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA; // executor admin EOA
    address constant ROLEMGR = 0x574e6bc316d4032d2Bd6D847ae6166FC7aC81bc3;
    address constant TIMELOCK = 0x7a1104Feb0D460Aa437008e54D7D6Db0bA7e8876;
    address constant TIMELOCK_UPGRADES = 0x376b467dFf007dD8d3f24404cAddff7F72257Fe4;
    address constant XCSETH_MAIN = 0x19C1bF1Ff06E5702aef056b41290C6a7FF231c88;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 100 ether);
    }

    // ------------------------------------------------------------------
    // 1. live state snapshot / invariants
    // ------------------------------------------------------------------
    function test_h07_live_state() public {
        assertGt(CLAYMAIN.code.length, 0, "clayMain has code");
        assertGt(CLAYMAIN2.code.length, 0, "clayMain2 has code");
        assertGt(IMPL.code.length, 0, "impl has code");

        // csETH supply is small (wind-down complete)
        uint256 supply = IERC20(CSETH).totalSupply();
        emit log_named_decimal_uint("csETH totalSupply", supply, 18);
        assertLt(supply, 3e18, "csETH supply < 3");

        emit log_named_decimal_uint("clayMain ETH", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("clayMain2 ETH", CLAYMAIN2.balance, 18);
        emit log_named_decimal_uint("xcsETH-main csETH", IERC20(CSETH).balanceOf(XCSETH_MAIN), 18);

        // both clayMain proxies point at the same frozen implementation
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assertEq(address(uint160(uint256(vm.load(CLAYMAIN, implSlot)))), IMPL, "clayMain impl");
        assertEq(address(uint160(uint256(vm.load(CLAYMAIN2, implSlot)))), IMPL, "clayMain2 impl");
        // admin slots are zero -> proxy admin functions unusable by anyone
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        assertEq(uint256(vm.load(CLAYMAIN, adminSlot)), 0, "clayMain admin=0");
        assertEq(uint256(vm.load(CLAYMAIN2, adminSlot)), 0, "clayMain2 admin=0");
        // executor admin is an EOA
        assertEq(address(uint160(uint256(vm.load(EXECUTOR, adminSlot)))), ADMIN_EOA, "executor admin");

        // role manager roles
        assertTrue(_hasRole(TIMELOCK, "TIMELOCK_ROLE"), "timelock role");
        assertTrue(_hasRole(TIMELOCK_UPGRADES, "TIMELOCK_UPGRADES_ROLE"), "timelock upgrades role");
    }

    // ------------------------------------------------------------------
    // 2. legacy user functions are gone -> unknown selector reverts
    // ------------------------------------------------------------------
    function test_h07_legacy_user_paths_revert() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        _expectRevertFrom(attacker, CLAYMAIN, abi.encodeWithSignature("claim(uint256[])", ids), "claim");
        _expectRevertFrom(attacker, CLAYMAIN, abi.encodeWithSignature("withdraw(uint256)", 1e18), "withdraw");
        _expectRevertFrom(attacker, CLAYMAIN, abi.encodeWithSignature("deposit()"), "deposit");
        _expectRevertFrom(attacker, CLAYMAIN, abi.encodeWithSignature("instantWithdraw(uint256)", 1e18), "instantWithdraw");
        _expectRevertFrom(attacker, CLAYMAIN2, abi.encodeWithSignature("claim(uint256[])", ids), "claim2");
    }

    // ------------------------------------------------------------------
    // 3. every custom selector on the frozen proxies from an unprivileged
    //    caller: does any path pay the attacker or move protocol ETH?
    // ------------------------------------------------------------------
    function test_h07_unprivileged_candidates() public {
        uint256 attackerBefore = attacker.balance;
        uint256 clayBefore = CLAYMAIN.balance;
        uint256 clay2Before = CLAYMAIN2.balance;
        uint256 moved;

        // admin/proxy surface
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x3659cfe6, address(this)), "upgradeTo");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x8f283970, attacker), "changeAdmin");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x4f1ef286, address(this), ""), "upgradeToAndCall");

        // custom selectors (args guessed from evmole; reverts are expected)
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x108ed7ac, CLAYMAIN, new bytes4[](0), new bool[](0)), "108ed7ac");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x1c0f5759, CLAYMAIN, false, false), "1c0f5759");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x3267593f, CLAYMAIN, CLAYMAIN, new uint256[](0), ""), "3267593f");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x3727e769, CLAYMAIN, new uint256[](0), new uint256[](0), false, new bytes4[](0)), "3727e769");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x3b11ad99, CLAYMAIN, new bytes4[](0), 0), "3b11ad99");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x3e923b8c, CLAYMAIN, new bytes[](0)), "3e923b8c");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x42294bb0, CLAYMAIN, 0, 0), "42294bb0");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x58ee48cf, CLAYMAIN, new bytes4[](0), new address[](0), new bool[](0)), "58ee48cf");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x63c22a3b, CLAYMAIN, CLAYMAIN, new address[](0), 0), "63c22a3b");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x753d02bd, attacker), "753d02bd");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x8078438b, CLAYMAIN, new uint256[](0), new uint256[](0), new uint256[](0)), "8078438b");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x8c84497d, attacker, new address[](0)), "8c84497d-sweep");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x9441e515, CLAYMAIN, new uint256[](0), new uint256[](0), false), "9441e515");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x9eb6ef66, CLAYMAIN, attacker), "9eb6ef66");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0xaa4ee5a6, CLAYMAIN, new bytes4[](0), attacker, attacker), "aa4ee5a6");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0xe0c30834, CLAYMAIN, uint256(1)), "e0c30834");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0xf3314a61, attacker), "f3314a61");
        _tryCall(attacker, CLAYMAIN, abi.encodeWithSelector(0x04964aeb, CLAYMAIN, address(this), new uint256[](0), "", uint8(0), uint256(0), uint256(0)), "04964aeb-onclay");

        // same on the second proxy
        _tryCall(attacker, CLAYMAIN2, abi.encodeWithSelector(0x8c84497d, attacker, new address[](0)), "8c84497d-sweep2");
        _tryCall(attacker, CLAYMAIN2, abi.encodeWithSelector(0xf3314a61, attacker), "f3314a61-2");
        _tryCall(attacker, CLAYMAIN2, abi.encodeWithSelector(0x3659cfe6, address(this)), "upgradeTo2");

        // executor surface from unprivileged caller
        _tryCall(attacker, EXECUTOR, abi.encodeWithSelector(0x04964aeb, CLAYMAIN, address(this), new uint256[](0), "", uint8(0), uint256(0), uint256(0)), "04964aeb-on-exec");
        _tryCall(attacker, EXECUTOR, abi.encodeWithSelector(0x3659cfe6, address(this)), "exec-upgradeTo");

        moved = (clayBefore - CLAYMAIN.balance) + (clay2Before - CLAYMAIN2.balance);
        emit log_named_decimal_uint("protocol ETH moved by unprivileged calls", moved, 18);
        emit log_named_decimal_uint("attacker balance delta", attacker.balance - attackerBefore, 18);
        assertEq(moved, 0, "no protocol ETH moved");
        assertEq(attacker.balance, attackerBefore, "attacker did not profit");
    }

    // ------------------------------------------------------------------
    // 4. who (if anyone) can move the ETH: privileged sweep probe
    // ------------------------------------------------------------------
    function test_h07_privileged_sweep_probe() public {
        uint256 clayBefore = CLAYMAIN.balance;
        // as the executor contract (the only address that may satisfy stor_a checks)
        vm.prank(EXECUTOR);
        (bool ok1, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, ADMIN_EOA, new address[](0)));
        emit log_named_string("sweep as executor ok?", ok1 ? "yes" : "no");
        emit log_named_decimal_uint("clayMain ETH after", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("admin EOA ETH after", ADMIN_EOA.balance, 18);
        // as the admin EOA
        vm.prank(ADMIN_EOA);
        (bool ok2, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, ADMIN_EOA, new address[](0)));
        emit log_named_string("sweep as admin EOA ok?", ok2 ? "yes" : "no");
        // as a timelock role holder
        vm.prank(TIMELOCK);
        (bool ok3, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, ADMIN_EOA, new address[](0)));
        emit log_named_string("sweep as timelock ok?", ok3 ? "yes" : "no");
        // as the upgrade timelock
        vm.prank(TIMELOCK_UPGRADES);
        (bool ok4, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, ADMIN_EOA, new address[](0)));
        emit log_named_string("sweep as timelock_upgrades ok?", ok4 ? "yes" : "no");
        // record what happened (no assertion: informational for classification P/S)
        emit log_named_uint("clayBefore", clayBefore);
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function _hasRole(address who, string memory role) internal view returns (bool) {
        (bool ok, bytes memory ret) = ROLEMGR.staticcall(
            abi.encodeWithSignature("hasRole(bytes32,address)", keccak256(bytes(role)), who));
        return ok && ret.length >= 32 && abi.decode(ret, (bool));
    }

    function _expectRevertFrom(address who, address target, bytes memory data, string memory label) internal {
        vm.prank(who);
        (bool ok, ) = target.call(data);
        emit log_named_string(string.concat("legacy ", label, " reverted?"), ok ? "NO" : "yes");
        assertFalse(ok, string.concat(label, " should revert"));
    }

    function _tryCall(address who, address target, bytes memory data, string memory label) internal {
        vm.prank(who);
        (bool ok, bytes memory ret) = target.call(data);
        emit log_named_string(string.concat("call ", label, " ok?"), ok ? "YES" : "no");
        if (ok && ret.length > 0) {
            emit log_named_bytes(string.concat("call ", label, " ret"), ret);
        }
    }
}
