// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IRiftVault, IRiftCore, IERC20, IUniswapV2PairLike } from "../src/RiftInterfaces.sol";

/// @notice Ethereum-side PoC: an external unprivileged attacker (fresh address, no position,
/// no roles, flash-loan capital available) tries every value-moving entry point of the live
/// Rift vaults. All must revert; the only way in is an existing position (participant).
/// Read-only fork test: runs on a fork of mainnet, never touches the live chain.
contract RiftEthGatesTest is Test {
    address constant CORE = 0x5D7e616B2c0bf268494A482e315a60814F97dBC8;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ATTACKER = address(0xA11CE);

    // live ETH participants found on-chain (non-zero internal balance at the latest block)
    address constant PARTICIPANT_969A = 0x44d41Ad8c9Aeec1477559B367EACF7Ed7f224904; // holds 296,615.51 AURORA claimable
    address constant PARTICIPANT_969A_T0 = 0x93a71bfEC0180C51D8420C1EffDA104b2ac83c93; // holds 0.0103 WETH deposited

    address[9] vaults = [
        0x51C6f3433e8fF88726c09950ADD24726c28264d3, // WETH/OGN  (UniswapVault)
        0x40D23398d9D553C1406d44Ce020E15b702B308e4, // WETH/OGN
        0x5a999FEd5BD99f8a6a30CB1D411f689390514A61, // WETH/FTM  (MasterChefVault)
        0x820Fb78054e966bEe5e7D0421CB949cbA137bcf4, // WETH/OGN
        0x95F635a4116a805e83433B455eeB9A60Ee025408, // WETH/FTM  (MasterChefVault)
        0xe914B3E4adf87DBF5ff35895f8aEf5B169f82c9a, // WETH/FTM  (MasterChefVault)
        0x01ebD85a8ED9cdB99E17550FFc35B3d1E1C07fD6, // WETH/AURORA (verified gate target)
        0x969a4a1F3DD4Bb66eCbbF7b09e93C28F53D06e2A, // WETH/AURORA (biggest holder position)
        0x01875b967583cc3cE5046C1321b752c0Baf05FbD  // WETH/AURORA
    ];

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }

    function test_eth_live_state() public view {
        assertGt(block.number, 26_000_000, "expected mainnet fork");
        IRiftCore core = IRiftCore(CORE);
        assertEq(core.paused(), false, "core must be UNPAUSED");
        assertEq(core.feeTo(), 0x96c9570776157d3f0B5569F9e936cb0A9d5d31cD, "feeTo");
        for (uint256 i = 0; i < vaults.length; i++) {
            IRiftVault v = IRiftVault(vaults[i]);
            assertGt(vaults[i].code.length, 0, "vault must have code");
            assertEq(v.paused(), false, "vault must be unpaused");
            assertEq(v.depositsEnabled(), false, "deposits must be DISABLED");
            assertEq(v.core(), CORE, "vault core");
        }
    }

    /// Every value-moving path, called by a fresh unprivileged attacker, must revert.
    function test_eth_attacker_all_gates_revert() public {
        vm.deal(ATTACKER, 1000 ether);
        vm.startPrank(ATTACKER);
        for (uint256 i = 0; i < vaults.length; i++) {
            IRiftVault v = IRiftVault(vaults[i]);

            vm.expectRevert(bytes("DEPOSITS_DISABLED"));
            v.depositToken0{ value: 1 ether }(1 ether);

            vm.expectRevert(bytes("DEPOSITS_DISABLED"));
            v.depositToken1(1 ether);

            vm.expectRevert(bytes("NOT_PARTICIPANT_OR_STRATEGIST"));
            v.nextEpoch(0, 0);

            vm.expectRevert(bytes("NO_CLAIM"));
            v.claimToken0();

            vm.expectRevert(bytes("NO_CLAIM"));
            v.claimToken1();

            vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
            v.withdrawToken0(1 wei);

            vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
            v.withdrawToken1(1 wei);

            vm.expectRevert(bytes("NOT_GUARDIAN"));
            v.unstakeLiquidity();

            address[] memory toks = new address[](1);
            toks[0] = WETH;
            uint256[] memory amts = new uint256[](1);
            amts[0] = 0;
            vm.expectRevert(bytes("NOT_GUARDIAN"));
            v.rescueTokens(toks, amts);

            vm.expectRevert(bytes("NOT_PAUSER"));
            v.pause();

            vm.expectRevert(bytes("NOT_STRATEGIST"));
            v.setToken0Floor(1);

            vm.expectRevert(bytes("NOT_STRATEGIST"));
            v.setEpochDuration(1);
        }
        vm.stopPrank();
    }

    /// Core-level admin surface is also unreachable for the attacker.
    function test_eth_core_admin_gates_revert() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(); // AccessControlUnauthorizedAccount
        IRiftCore(CORE).pause();
        vm.expectRevert();
        IRiftCore(CORE).setFeeTo(ATTACKER);
        vm.expectRevert();
        IRiftCore(CORE).setProtocolFee(10_000);
        address[] memory vs = new address[](1);
        vs[0] = ATTACKER;
        vm.expectRevert();
        IRiftCore(CORE).registerVaults(vs);
        vm.stopPrank();
    }

    /// The ONLY way to call nextEpoch is to already hold a position (participant) or be strategist.
    function test_eth_participant_holds_the_only_open_door() public {
        IRiftVault v = IRiftVault(0x969a4a1F3DD4Bb66eCbbF7b09e93C28F53D06e2A);

        (uint256 dep0, uint256 pend0, uint256 claim0) = v.token0Balance(PARTICIPANT_969A_T0);
        (uint256 dep1, uint256 pend1, uint256 claim1) = v.token1Balance(PARTICIPANT_969A);
        emit log_named_uint("participant t0 deposited (wei)", dep0);
        emit log_named_uint("participant t1 claimable (wei)", claim1);
        assertGt(dep0 + pend0 + claim0 + dep1 + pend1 + claim1, 0, "participant has a position");

        // fresh attacker cannot enter the door
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("NOT_PARTICIPANT_OR_STRATEGIST"));
        v.nextEpoch(0, 0);
    }

    /// Holder-only (H-O) recovery path still works: the participant can claim their AURORA.
    function test_eth_holder_claim_still_works() public {
        IRiftVault v = IRiftVault(0x969a4a1F3DD4Bb66eCbbF7b09e93C28F53D06e2A);
        (, , uint256 claim1) = v.token1Balance(PARTICIPANT_969A);
        assertGt(claim1, 290_000e18, "expected large pending claim");

        address token1 = v.token1();
        uint256 balBefore = IERC20(token1).balanceOf(PARTICIPANT_969A);

        vm.prank(PARTICIPANT_969A);
        v.claimToken1();

        uint256 balAfter = IERC20(token1).balanceOf(PARTICIPANT_969A);
        assertEq(balAfter - balBefore, claim1, "claim paid out exactly");
        (, , uint256 claimAfter) = v.token1Balance(PARTICIPANT_969A);
        assertEq(claimAfter, 0, "claim zeroed");
    }

    /// Evidence about the (zero-slippage, position-gated) epoch rebalance. Captures exact revert
    /// data so the report can classify the residual value (holder-recoverable vs stuck).
    function test_eth_participant_trigger_nextEpoch() public {
        _tryEpoch(0x01ebD85a8ED9cdB99E17550FFc35B3d1E1C07fD6, PARTICIPANT_969A_T0, "01ebd (AURORA LP held, participant caller)");
        _tryEpoch(0x969a4a1F3DD4Bb66eCbbF7b09e93C28F53D06e2A, PARTICIPANT_969A, "969a (AURORA LP held, participant caller)");
        _tryEpoch(0xe914B3E4adf87DBF5ff35895f8aEf5B169f82c9a, 0x805300de5F8D8dE0bb7d78e30E3DD653B57eb94f, "e914 (unwound FTM vault, strategist caller)");
        _tryEpoch(0x51C6f3433e8fF88726c09950ADD24726c28264d3, 0x805300de5F8D8dE0bb7d78e30E3DD653B57eb94f, "51c6 (unwound OGN vault, strategist caller)");
    }

    function _tryEpoch(address vault, address caller, string memory label) internal {
        IRiftVault v = IRiftVault(vault);
        IUniswapV2PairLike pair = IUniswapV2PairLike(v.pair());
        (uint112 rA, uint112 rB, ) = pair.getReserves();
        uint256 exp0;
        uint256 exp1;
        if (pair.token0() == v.token0()) {
            (exp0, exp1) = (uint256(rA), uint256(rB));
        } else {
            (exp0, exp1) = (uint256(rB), uint256(rA));
        }
        uint256 epochBefore = v.epoch();
        vm.prank(caller);
        (bool ok, bytes memory ret) = vault.call(abi.encodeWithSignature("nextEpoch(uint256,uint256)", exp0, exp1));
        emit log_string(label);
        if (ok) {
            emit log_named_uint("  nextEpoch OK, epoch after", v.epoch());
            assertGt(v.epoch(), epochBefore, "epoch advanced");
        } else {
            emit log_named_bytes("  nextEpoch REVERT data", ret);
        }
    }

    /// Quantitative snapshot of what is at stake (used by the report).
    function test_eth_value_snapshot() public {
        uint256 total;
        for (uint256 i = 0; i < vaults.length; i++) {
            IRiftVault v = IRiftVault(vaults[i]);
            total += IERC20(v.token0()).balanceOf(vaults[i]);
            total += IERC20(v.token1()).balanceOf(vaults[i]);
            if (v.pair() != address(0)) {
                total += IERC20(v.pair()).balanceOf(vaults[i]);
            }
        }
        emit log_named_uint("aggregate raw token units locked (all 9 vaults)", total);
    }
}
