// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20, IPair, IFactory, IMasterChef, IFeeDistributor, ITokenMintable, IJawsPool, ILaunchpad, IMasterSquidFarm} from "../src/IAutoShark.sol";

/// @title AutoShark (BSC) live extractability PoC — READ-ONLY fork test.
/// @notice Proves on a BSC fork that the live value in AutoShark is NOT extractable by a
///         fresh unprivileged attacker: every candidate payout path is access-gated or empty,
///         while legitimate user self-service (farm withdraw, LP redemption) still works.
contract AutoSharkLiveTest is Test {
    address constant FACTORY = 0xe759Dd4B9f99392Be64f1050a6A8018f73B53a13;
    address constant FEE_TO = 0x593CC303170367FCB249abdd08Aaaa736d552BA5; // FeeDistributor proxy
    address constant FEE_VAULT = 0xe0B4Add509BAB9d04cA92541272C87CDB822FA32; // Squid fee vault proxy
    address constant MASTER_OCEAN = 0x8857Af8205F224870dea119e2c75AF386EFB192a;
    address constant MASTER_SQUID = 0x86A47ddD4c6522251d6a5A5800f3F24c03332CB4;
    address constant JAWS_POOL = 0x5D2112Ba0969EC66012380C1fb88F2A3D182Eb90;
    address constant LAUNCHPAD = 0xa9F48feE822530037628Fcbbe2d7724221B1536D;
    address constant JAWS = 0xdD97AB35e3C0820215bc85a395e13671d84CCBa2;
    address constant FINS = 0x1b219Aca875f8C74c33CFF9fF98f3a9b62fCbff5;
    address constant SQUID = 0xAE61e7dc989718E700C046a2483e93513eDCA484;

    address constant PAIR_WETH_BTCB = 0x3942940EfeEF8C6435b722082beB3Eb2837EBD69; // ~$67k real assets
    address constant PAIR_DAI_USDT = 0xbD78f8Cf00e03C00afAf684B72D08CF8F997d4Bb;  // ~$31k, 99.95% staked in MasterOcean
    address constant PAIR_USDT_BUSD = 0x06347b91DaBc757cCD5A5AA2aF802cEc78e4D239; // ~$20.5k, MasterSquid + fee vault
    address constant PAIR_FINS_WBNB = 0x14B5a6d26577970953F9E6608d6604e4676Ac5b7;
    address constant PAIR_EXCESS = 0xD5278CA7b099aF5a8690115DC25EDeF5d575132B;    // donation pair (dust)

    address constant HOLDER_EOA = 0x91d6136a45c10A8567aE9E2AaC193d65fD4C7E01; // holds ~97% of WETH/BTCB LP

    address attacker = address(0xA77ACC);

    function rpcUrl() internal view returns (string memory) {
        return vm.envOr(
            "BSC_RPC_URL",
            vm.envOr("BSC_ARCHIVE_RPC", string("https://bsc-rpc.publicnode.com"))
        );
    }

    function setUp() public {
        uint256 blk = vm.envOr("FORK_BLOCK", uint256(0));
        if (blk == 0) {
            vm.createSelectFork(rpcUrl());
        } else {
            vm.createSelectFork(rpcUrl(), blk);
        }
    }

    // ---------------------------------------------------------------- live value
    function test_live_value_concentration() public view {
        IPair wethbtcb = IPair(PAIR_WETH_BTCB);
        (uint112 r0, uint112 r1,) = wethbtcb.getReserves();
        assertGt(r0, 13 ether, "WETH reserve");
        assertGt(r1, 0.3 ether, "BTCB reserve");
        // ~97% of this LP belongs to a single EOA (holder-only)
        assertGt(wethbtcb.balanceOf(HOLDER_EOA), 2.1 ether);

        IPair daiusdt = IPair(PAIR_DAI_USDT);
        (uint112 d0, uint112 d1,) = daiusdt.getReserves();
        assertGt(d0, 15_000 ether, "DAI reserve");
        assertGt(d1, 15_000 ether, "USDT reserve");
        // ~99.95% of that LP is staked inside MasterOcean (farm deposits)
        assertGt(daiusdt.balanceOf(MASTER_OCEAN), 15_000 ether);

        IPair usdtbusd = IPair(PAIR_USDT_BUSD);
        assertGt(usdtbusd.balanceOf(MASTER_SQUID), 5_000 ether);
        assertGt(usdtbusd.balanceOf(FEE_VAULT), 4_300 ether, "fee vault LP position");

        // feeTo distributor accumulated protocol fee LP (7.61 LP of the DAI/USDT pair)
        assertGt(IPair(PAIR_DAI_USDT).balanceOf(FEE_TO), 7 ether, "feeTo LP fees");
    }

    // -------------------------------------------------- no free skim on value pairs
    function test_no_excess_on_value_pairs() public view {
        address[4] memory pairs = [PAIR_WETH_BTCB, PAIR_DAI_USDT, PAIR_USDT_BUSD, PAIR_FINS_WBNB];
        for (uint256 i = 0; i < pairs.length; i++) {
            IPair p = IPair(pairs[i]);
            (uint112 x0, uint112 x1,) = p.getReserves();
            assertEq(IERC20(p.token0()).balanceOf(pairs[i]), uint256(x0), "token0 excess");
            assertEq(IERC20(p.token1()).balanceOf(pairs[i]), uint256(x1), "token1 excess");
        }
    }

    /// The only donation pair found; skim pays out dust only (and the zombie token
    /// charges a ~10% transfer tax, so the attacker receives less than the nominal excess).
    function test_skim_only_dust() public {
        IPair p = IPair(PAIR_EXCESS);
        (uint112 x0, uint112 x1,) = p.getReserves();
        address t0 = p.token0();
        address t1 = p.token1();
        uint256 ex0 = IERC20(t0).balanceOf(PAIR_EXCESS) - uint256(x0);
        uint256 ex1 = IERC20(t1).balanceOf(PAIR_EXCESS) - uint256(x1);
        uint256 a0 = IERC20(t0).balanceOf(attacker);
        uint256 a1 = IERC20(t1).balanceOf(attacker);
        p.skim(attacker);
        uint256 g0 = IERC20(t0).balanceOf(attacker) - a0;
        uint256 g1 = IERC20(t1).balanceOf(attacker) - a1;
        assertEq(g0, ex0, "no-fee side pays exact excess");
        assertLe(g1, ex1, "fee-on-transfer side pays <= excess");
        assertGt(g1, 0);
        // bound: sub-1-unit dust of an unpriced zombie token (9 decimals)
        assertLe(ex1, 1 ether, "skim gain must be dust");
    }

    // ------------------------------------------------ privileged paths are closed
    function test_fee_distributors_revert_for_fresh_attacker() public {
        address[] memory targets = new address[](1);
        targets[0] = PAIR_USDT_BUSD;
        uint256 fv0 = IPair(PAIR_USDT_BUSD).balanceOf(FEE_VAULT);
        uint256 ft0 = IPair(PAIR_DAI_USDT).balanceOf(FEE_TO);
        vm.startPrank(attacker, attacker);
        vm.expectRevert();
        IFeeDistributor(FEE_TO).distribute(targets);
        vm.expectRevert();
        IFeeDistributor(FEE_VAULT).distributeSingle(targets);
        vm.stopPrank();
        // nothing moved
        assertEq(IPair(PAIR_USDT_BUSD).balanceOf(FEE_VAULT), fv0);
        assertEq(IPair(PAIR_DAI_USDT).balanceOf(FEE_TO), ft0);
        // the privileged roles are EOAs / distinct from attacker
        assertTrue(IFeeDistributor(FEE_TO).owner() != attacker);
        assertTrue(IFeeDistributor(FEE_TO).keeper() != attacker);
    }

    function test_token_mints_revert_for_fresh_attacker() public {
        vm.startPrank(attacker, attacker);
        vm.expectRevert();
        ITokenMintable(FINS).mint(1 ether);
        vm.expectRevert();
        ITokenMintable(FINS).mint(attacker, 1 ether);
        vm.expectRevert();
        ITokenMintable(SQUID).mint(1 ether);
        vm.expectRevert();
        ITokenMintable(JAWS).mint(attacker, 1 ether);
        vm.stopPrank();
        assertEq(IERC20(FINS).balanceOf(attacker), 0);
        assertEq(IERC20(SQUID).balanceOf(attacker), 0);
        assertEq(IERC20(JAWS).balanceOf(attacker), 0);
    }

    // -------------------------------------------------- farm accounting integrity
    /// A real LP holder can deposit and withdraw — user-only recovery (H-O) works.
    /// A fresh attacker cannot touch anyone else's stake.
    function test_farm_deposit_withdraw_self_service() public {
        uint256 lpBefore = IPair(PAIR_WETH_BTCB).balanceOf(HOLDER_EOA);
        assertGt(lpBefore, 2 ether);

        vm.startPrank(HOLDER_EOA, HOLDER_EOA);
        IERC20(PAIR_WETH_BTCB).approve(MASTER_OCEAN, type(uint256).max);
        uint256 farmBefore = IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN);
        IMasterChef(MASTER_OCEAN).deposit(25, 1 ether);
        assertEq(IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN), farmBefore + 1 ether);
        IMasterChef(MASTER_OCEAN).withdraw(25, 1 ether);
        assertEq(IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN), farmBefore);
        // emergency path returns principal too
        IMasterChef(MASTER_OCEAN).deposit(25, 1 ether);
        IMasterChef(MASTER_OCEAN).emergencyWithdraw(25);
        assertEq(IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN), farmBefore);
        vm.stopPrank();
        assertEq(IPair(PAIR_WETH_BTCB).balanceOf(HOLDER_EOA), lpBefore);
    }

    function test_fresh_attacker_cannot_withdraw_others() public {
        uint256 farmBefore = IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN);
        vm.startPrank(attacker, attacker);
        vm.expectRevert();
        IMasterChef(MASTER_OCEAN).withdraw(25, 1 ether);
        IMasterChef(MASTER_OCEAN).emergencyWithdraw(25); // no stake -> pays 0
        vm.stopPrank();
        assertEq(IERC20(PAIR_WETH_BTCB).balanceOf(MASTER_OCEAN), farmBefore);
        assertEq(IPair(PAIR_WETH_BTCB).balanceOf(attacker), 0);
    }

    // ----------------------------------------------------------- empty custody
    function test_jawsPool_custody_is_empty() public {
        IJawsPool jp = IJawsPool(JAWS_POOL);
        assertGt(jp.totalSupply(), 0, "shares exist");
        assertEq(IERC20(JAWS).balanceOf(JAWS_POOL), 0, "but no JAWS backing");
        uint256 before_ = IERC20(JAWS).balanceOf(attacker);
        vm.startPrank(attacker, attacker);
        (bool ok,) = JAWS_POOL.call(abi.encodeWithSignature("withdraw(uint256)", uint256(1 ether)));
        ok;
        (bool ok2,) = JAWS_POOL.call(abi.encodeWithSignature("getReward()"));
        ok2;
        vm.stopPrank();
        assertEq(IERC20(JAWS).balanceOf(attacker), before_);
    }

    function test_launchpad_claims_and_withdrawals_gated() public {
        ILaunchpad lp = ILaunchpad(LAUNCHPAD);
        assertTrue(lp.allowClaim());
        assertGt(IPair(PAIR_FINS_WBNB).balanceOf(LAUNCHPAD), 3_000 ether, "launchpad LP custody");
        vm.startPrank(attacker, attacker);
        vm.expectRevert();
        lp.harvest();
        vm.expectRevert();
        lp.finalWithdraw(1, 0);
        vm.stopPrank();
    }

    /// MasterSquid's NFT controller is the zero address, so getBoost() is inert
    /// (returns 0, no boost minting), but the farm itself is fully functional:
    /// deposit / withdraw / emergencyWithdraw all work for a fresh user.
    function test_mastersquid_farm_paths_work() public {
        IMasterSquidFarm ms = IMasterSquidFarm(MASTER_SQUID);
        assertEq(ms.controller(), address(0));
        assertEq(ms.getBoost(attacker, 3), 0); // inert boost, no revert
        deal(PAIR_USDT_BUSD, attacker, 10 ether);
        vm.startPrank(attacker, attacker);
        IERC20(PAIR_USDT_BUSD).approve(MASTER_SQUID, type(uint256).max);
        uint256 farmBefore = IERC20(PAIR_USDT_BUSD).balanceOf(MASTER_SQUID);
        ms.deposit(3, 1 ether, address(0)); // 3% deposit fee on pid 3
        vm.roll(block.number + 1);
        // normal withdraw works (returns what accounting allows; fee is lost by design)
        ms.withdraw(3, 0.4 ether);
        uint256 afterWithdraw = IERC20(PAIR_USDT_BUSD).balanceOf(attacker);
        assertGt(afterWithdraw, 0);
        ms.emergencyWithdraw(3); // and the rest is recoverable
        assertGt(IERC20(PAIR_USDT_BUSD).balanceOf(attacker), afterWithdraw);
        vm.stopPrank();
        assertGt(IERC20(PAIR_USDT_BUSD).balanceOf(MASTER_SQUID), farmBefore - 10 ether);
    }
}
