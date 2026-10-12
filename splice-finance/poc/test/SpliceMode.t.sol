// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface ISYM is IERC20M {
    function exchangeRate() external view returns (uint256);
    function assetInfo() external view returns (uint8, address, uint8);
    function redeem(address receiver, uint256 amountShares, address tokenOut, uint256 minOut, bool burnFromInternalBalance) external returns (uint256);
    function paused() external view returns (bool);
}

interface IMarketM is IERC20M {
    function expiry() external view returns (uint256);
    function burn(address receiverSy, address receiverPt, uint256 netLpToBurn) external returns (uint256, uint256);
    function _storage() external view returns (int128 totalPt, int128 totalSy, uint96 a, uint16 b, uint16 c, uint16 d);
}

interface IYTM is IERC20M {
    function redeemPY(address receiver) external returns (uint256);
    function PT() external view returns (address);
    function SY() external view returns (address);
}

/// Splice Finance (Mode) — same treatment as Blast: prove no outsider path + holder paths live.
/// Read-only against mainnet; runs on a fork only.
contract SpliceModeTest is Test {
    uint256 constant FORK_BLOCK = 45_796_981;

    address constant MKT_MODE  = 0xb950A73Ea0842B0Cd06D0e369aE974799BB346f1;
    address constant PT_MODE   = 0xF5C6f1F14Cc37CF58d3738907E344C4943348E49;
    address constant SY_MODE   = 0x5763BA22463ffBef84d5aa1a6Df983420852bED7;
    address constant YT_MODE   = 0x7A1f3D6313a89B68a14233EAA709180F649Ebe32;
    address constant MODE      = 0xDfc7C877a950e49D2610114102175A06C2e3167a;

    address constant MKT_EZETH = 0x34cf9BF641bd5f34197060A3f3478a1f97f78f0a;
    address constant PT_EZETH  = 0x347773B3415efb658E1eb9548223A8e4FeE7647D;
    address constant SY_EZETH  = 0x0Cd0F94bBEAd98b6A05773426a783eFE8588A559;
    address constant YT_EZETH  = 0xD8291cb561D4B116B29714BBc8dbf13b51E46d74;
    address constant EZETH     = 0x2416092f143378750bb29b79eD961ab195CcEea5;

    function setUp() public {
        string memory rpc = vm.envOr("MODE_RPC_URL", string("https://mainnet.mode.network"));
        vm.createSelectFork(rpc, FORK_BLOCK);
    }

    /// No SY self-balance on Mode either -> burnFromInternalBalance is not abusable.
    function test_mode_sy_self_balances_zero() public {
        address[2] memory sys = [SY_MODE, SY_EZETH];
        for (uint256 i = 0; i < sys.length; i++) {
            assertEq(IERC20M(sys[i]).balanceOf(sys[i]), 0);
            assertFalse(ISYM(sys[i]).paused());
            (uint8 t, address u, ) = ISYM(sys[i]).assetInfo();
            assertEq(t, 0);
            vm.expectRevert();
            ISYM(sys[i]).redeem(address(this), 1e18, u, 0, true);
        }
    }

    /// YT contracts hold 0 PT on Mode too -> no redeemPY sweep.
    function test_mode_yt_pt_zero_and_no_sweep() public {
        address[2] memory yts = [YT_MODE, YT_EZETH];
        for (uint256 i = 0; i < yts.length; i++) {
            address pt = IYTM(yts[i]).PT();
            assertEq(IERC20M(pt).balanceOf(yts[i]), 0);
            uint256 out = IYTM(yts[i]).redeemPY(address(this));
            assertEq(out, 0);
        }
    }

    /// Outsider cannot burn market LP.
    function test_mode_outsider_cannot_burn() public {
        vm.expectRevert();
        IMarketM(MKT_MODE).burn(address(this), address(this), 1e18);
    }

    /// Holder path live on Mode: SY redeems 1:1 for the exact underlying held by the SY.
    function test_mode_sy_redeem_live() public {
        uint256 shares = 1e18;
        // ERC20/L2 SYs redeem the underlying 1:1 with the burned SY shares.
        vm.prank(YT_MODE);
        uint256 out = ISYM(SY_MODE).redeem(YT_MODE, shares, MODE, 0, false);
        assertEq(out, shares);

        vm.prank(YT_EZETH);
        uint256 out2 = ISYM(SY_EZETH).redeem(YT_EZETH, shares, EZETH, 0, false);
        assertEq(out2, shares);
    }

    /// Market internal accounting vs actual balances (context for skim / LP burns).
    function test_mode_market_context() public {
        assertEq(IMarketM(MKT_MODE).expiry(), 1_724_198_400);
        assertTrue(block.timestamp > IMarketM(MKT_MODE).expiry());
        (int128 tPt, int128 tSy, , , , ) = IMarketM(MKT_MODE)._storage();
        assertGt(tPt, 0);
        assertGt(tSy, 0);
        assertGe(IERC20M(PT_MODE).balanceOf(MKT_MODE), uint256(uint128(tPt))); // actual >= internal
        assertGe(IERC20M(SY_MODE).balanceOf(MKT_MODE), uint256(uint128(tSy)));
    }
}
