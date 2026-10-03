// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20Like, IPhuxPool, I9inchMCV2, IV3Pool} from "../src/Interfaces.sol";

/// @title C-39 secondary-venue checks (PulseChain fork, read-only against the real chain)
contract DormantVenuesTest is Test {
    address constant PHUX_STABLE = 0xF96d60e9444f19Fe5126888BD53BdE80e58c2851;
    address constant PHUX_VAULT = 0x7F51AC3df6A034273FB09BB29e383FCF655e473c;
    address constant NINCH_MCV2 = 0x444775Ae2C82560337c86f6D62909a63381De4fd;
    address constant NINCH_FACTORY = 0x5b9F077A77db37F3Be0A5b5d31BAeff4bc5C0bD7;
    address constant NINCH_LP = 0x1164daB36Cd7036668dDCBB430f7e0B15416EF0b; // 9INCH/WPLS LP (MCV2 pool 1)
    address constant MM9_V3_POOL = 0xC2E13C31Fa3B87Bb5b59f98F1D2E6b4eD3eD855e; // USDL/DAI 0.05%
    address constant LIB_BXUSD_DAI = 0x7E73Afa060feC3320862e707Eb73b6b4C84FDEA2; // Liberty V3
    address constant BXUSD = 0x25B714AD96322CfCeFcF11eb501D2Fb2152173B4;
    address constant DAI_BRIDGED = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;

    address attacker = address(0xBEEF);
    uint256 forkBlock;

    function setUp() public {
        string memory rpc =
            vm.envOr("PULSECHAIN_RPC", string("https://pulsechain-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        forkBlock = block.number;
    }

    /// Phux is a Balancer V2 fork; the Nov-2025 rounding exploit needs non-unitary scaling factors.
    /// All live pools return factors divisible by 1e18 (unitary rates) => mulDown truncation is exact.
    function test_phux_scaling_factors_unitary_no_balancer_rounding_bug() public view {
        uint256[] memory sfs = IPhuxPool(PHUX_STABLE).getScalingFactors();
        assertGt(sfs.length, 0, "stable pool has scaling factors");
        for (uint256 i = 0; i < sfs.length; i++) {
            assertEq(sfs[i] % 1e18, 0, "scaling factor is unitary");
        }
        address[] memory rps = IPhuxPool(PHUX_STABLE).getRateProviders();
        for (uint256 i = 0; i < rps.length; i++) {
            assertEq(rps[i], address(0), "no rate provider");
        }
        // vault authorizer exists; setPaused is authenticate-gated
        (bool ok, bytes memory ret) =
            PHUX_VAULT.staticcall(abi.encodeWithSignature("getAuthorizer()"));
        assertTrue(ok, "vault getAuthorizer");
        assertEq(abi.decode(ret, (address)), 0x3a68EE6D3849C4776130f13Cd86F0BcC0738F4C3, "authorizer");
    }

    /// 9inch MasterChefV2: an outsider cannot withdraw someone else's stake, and emergencyWithdraw with no
    /// stake pays nothing.
    function test_9inch_masterchef_outsider_cannot_withdraw() public {
        assertEq(I9inchMCV2(NINCH_MCV2).owner(), 0xC3dddAAaEb5257D46b241e7A43b26fBf2121D94B);
        assertEq(NINCH_MCV2.code.length > 0 ? 1 : 0, 1, "masterchef code");
        assertEq(NINCH_FACTORY.code.length > 0 ? 1 : 0, 1, "factory code");
        // pool 1 holds staked 9INCH/WPLS LP
        assertGt(IERC20Like(NINCH_LP).balanceOf(NINCH_MCV2), 0, "staked LP present");
        uint256 before = IERC20Like(NINCH_LP).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(bytes("withdraw: Insufficient"));
        I9inchMCV2(NINCH_MCV2).withdraw(1, 1);
        // emergencyWithdraw with zero stake moves nothing
        vm.prank(attacker);
        I9inchMCV2(NINCH_MCV2).emergencyWithdraw(1);
        assertEq(IERC20Like(NINCH_LP).balanceOf(attacker), before, "no LP gained");
        (uint256 amt,) = I9inchMCV2(NINCH_MCV2).userInfo(1, attacker);
        assertEq(amt, 0, "attacker stake zero");
    }

    /// 9mm V3 pools are live; the fork's factory owner is an EOA (privileged only).
    function test_9mm_v3_pool_live_and_factory_owner_eoa() public view {
        assertGt(uint256(IV3Pool(MM9_V3_POOL).liquidity()), 0, "9mm v3 pool live");
        address f = IV3Pool(MM9_V3_POOL).factory();
        assertEq(f, 0xe50DbDC88E87a2C92984d794bcF3D1d76f619C68, "factory");
        (bool ok, bytes memory ret) = f.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok, "owner()");
        address owner = abi.decode(ret, (address));
        assertEq(owner.code.length, 0, "factory owner EOA");
    }

    /// Liberty Swap "BXUSD" pools show fake $9.6B GT reserves; real stablecoin side is a few hundred USD.
    function test_liberty_bxusd_pools_hold_only_dust() public view {
        address t0 = IV3Pool(LIB_BXUSD_DAI).token0();
        address t1 = IV3Pool(LIB_BXUSD_DAI).token1();
        assertEq(t0, BXUSD, "token0 BXUSD");
        assertEq(t1, DAI_BRIDGED, "token1 bridged DAI");
        uint256 bxusd = IERC20Like(BXUSD).balanceOf(LIB_BXUSD_DAI);
        uint256 dai = IERC20Like(DAI_BRIDGED).balanceOf(LIB_BXUSD_DAI);
        assertGt(bxusd, 1e27, "fake supply side");
        assertLt(dai, 100e18, "real DAI side < $100");
    }
}
