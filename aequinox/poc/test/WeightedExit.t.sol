// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/interfaces.sol";

/// WeightedPool (Aequinox fork) exit behaviour for non-gauge BPT holders.
contract WeightedExitTest is Test {
    IVault constant VAULT = IVault(0xEE1c8DbfBf958484c6a4571F5FB7b99B74A54AA7);
    address constant WP = 0x0256C70B89b3c0ED888b7B7d7767a701B2a67Bea; // ETH/BTCB/WBNB pool
    address[4] holders = [
        0x6Bfaa30eD20A83777180e14fcB07Bb329e0D9FcC,
        0x3C44F9C61a605a32b54D7daBD7a98b5eF0D35Dab,
        0x86B0c97E8B7385eAcF08D3505f363D12B7C45F2c,
        0x678D861a8989c04d813365698c8e65f4aB95a5a1
    ];

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.bnbchain.org")));
    }

    function test_weighted_holder_exits() public {
        (bool okp, bytes memory pidb) = WP.staticcall(abi.encodeWithSignature("getPoolId()"));
        require(okp, "getPoolId");
        bytes32 pid = abi.decode(pidb, (bytes32));
        (address[] memory toks, , ) = VAULT.getPoolTokens(pid);

        address holder;
        uint256 bpt;
        for (uint256 i = 0; i < holders.length; i++) {
            uint256 b = IERC20(WP).balanceOf(holders[i]);
            if (b > 0) { holder = holders[i]; bpt = b; break; }
        }
        require(bpt > 0, "no live holder");
        emit log_named_address("holder", holder);
        emit log_named_uint("bpt", bpt);
        uint256 amount = bpt < 1e15 ? bpt : 1e15; // tiny amount to isolate mechanics

        uint256[] memory mins = new uint256[](toks.length);
        vm.prank(holder);
        (bool ok2, ) = address(VAULT).call(abi.encodeWithSignature(
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            pid, holder, holder, IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(2), amount), false)));
        emit log_named_string("weighted kind2 (proportional) exit", ok2 ? "OK" : "REVERT");

        uint256 before0 = IERC20(toks[0]).balanceOf(holder);
        vm.prank(holder);
        (bool ok0, ) = address(VAULT).call(abi.encodeWithSignature(
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            pid, holder, holder, IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(0), amount, uint256(0)), false)));
        uint256 got = IERC20(toks[0]).balanceOf(holder) - before0;
        emit log_named_string("weighted kind0 (one token) exit", ok0 ? "OK" : "REVERT");
        emit log_named_uint("token0 received", got);

        // Fork behaviour: proportional exit (kind 2) reverts (fork bug); one-token exit (kind 0) works.
        assertFalse(ok2, "weighted proportional exit unexpectedly works");
        assertTrue(ok0, "weighted one-token exit must work");
        assertGt(got, 0, "holder received tokens");
        emit log_string("weighted exits: kind2 broken, kind0 works -> holders can recover (H-O)");
    }
}
