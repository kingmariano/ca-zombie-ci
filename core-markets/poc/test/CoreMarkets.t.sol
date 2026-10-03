// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------ */
/*  Minimal interfaces for the live Core Markets (Blast) deployment    */
/*  All calls are read-only or executed on a local fork only.          */
/* ------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IxCore is IERC20 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function withdrawFee() external view returns (uint256);
    function paused() external view returns (bool);
    function owner() external view returns (address);
    function recoverAsset(uint256 amount) external;
}

interface ICoreMultiRewarder {
    function deposit(uint256 amount, address receiver) external;
    function withdraw(uint256 amount, address to) external;
    function getReward(bool restake) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function earned(address account, address rewardsToken) external view returns (uint256);
    function rewards(address account, address rewardsToken) external view returns (uint256);
    function rewardTokens(uint256) external view returns (address);
    function rewardTokensLength() external view returns (uint256);
    function notifyRewardAmount(address[] memory tokens, uint256[] memory amounts) external;
    function CORE() external view returns (address);
    function xCore() external view returns (address);
    function owner() external view returns (address);
}

interface ISymmioDiamond {
    function withdraw(uint256 amount) external;
    function depositFor(address user, uint256 amount) external;
    function balanceOf(address user) external view returns (uint256);
    function allocatedBalanceOfPartyA(address partyA) external view returns (uint256);
    function getCollateral() external view returns (address);
    function withdrawCooldownOf(address) external view returns (uint256);
    function deallocateCooldown() external view returns (uint256);
}

interface ILiquidityBootstrapPool {
    function swapExactAssetsForShares(uint256 assetsIn, uint256 minSharesOut, address recipient) external returns (uint256);
    function swapExactSharesForAssets(uint256 sharesIn, uint256 minAssetsOut, address recipient) external returns (uint256);
    function close() external;
    function redeem() external returns (uint256);
    function closed() external view returns (bool);
    function cancelled() external view returns (bool);
    function purchasedShares(address) external view returns (uint256);
    function totalPurchased() external view returns (uint256);
    function asset() external view returns (address);
    function share() external view returns (address);
}

interface IMultiAccount {
    function _call(address account, bytes[] memory callDatas) external;
    function owners(address account) external view returns (address);
    function delegatedAccesses(address account, address target, bytes4 selector) external view returns (bool);
    function addAccount(string memory name) external;
}

interface IxCoreRewarder {
    function claim(address user, uint256 amountCore, uint256 timestamp, uint256 day, bytes memory signature) external;
    function claimed(address) external view returns (uint256);
    function coreTrustedAddress() external view returns (address);
    function fill(uint256 day, uint256 amount) external;
}

interface IVesting {
    function claim() external;
    function claimableAmount(address) external view returns (uint256);
    function owner() external view returns (address);
}

interface ICoreToken is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function paused() external view returns (bool);
    function owner() external view returns (address);
}

interface ISymmExecutor {
    function _call(address account, bytes[] memory callDatas) external;
    function owner() external view returns (address);
}

interface ISymmioPartyB {
    function _call(bytes[] memory callDatas) external;
    function paused() external view returns (bool);
}

/* ------------------------------------------------------------------ */

contract CoreMarketsTest is Test {
    // ---- live addresses (Blast, chain id 81457) ----
    address constant USDB   = 0x4300000000000000000000000000000000000003;
    address constant CORE   = 0x233b23DE890A8c21F6198D03425a2b986AE05536;
    address constant XCORE  = 0xE659f8e705f86845e9De5C4d1e6f785697ac85e5;
    address constant REWARDER = 0x5cba6447894BC1D765A35300f1FBa3ab3a932b21;
    address constant FARM   = 0xF1337755aBe2f7bcac0b10736dc2B646C754A886;
    address constant SYMMIO = 0x3d17f073cCb9c3764F105550B0BCF9550477D266;
    address constant LBP    = 0x9fb9af399c7E9bda57b89905c7D96091B895bfAe;
    address constant MA     = 0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e;
    address constant TEAMVEST = 0x9cD047D06A2daCf09cAC42324aD2b6cBa1CA8b44;
    address constant SEEDVEST = 0x769d266F54d407655cb6637AFe6b769f36FDfa0C;
    address constant EXEC   = 0x27ba1168a6df3681Dd2f74c8f6DAe165AaB23229;
    address constant PARTYB = 0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456;

    // a real PartyA account deployed by MultiAccount (from AddAccount log #1)
    address constant ACCOUNT = 0x5e66A6769D2FE1A3072CbDB28E2Da835edA720b8;

    address attacker = address(0xBADBEEF);

    function _selectFork() internal {
        string[3] memory urls = [
            vm.envOr("BLAST_RPC_URL", string("https://rpc.blast.io")),
            "https://blast-rpc.publicnode.com",
            "https://blast.drpc.org"
        ];
        for (uint256 i; i < urls.length; i++) {
            try vm.createSelectFork(urls[i]) {
                return;
            } catch {}
        }
        revert("no working Blast RPC");
    }

    function setUp() public {
        _selectFork();
        vm.deal(attacker, 10 ether);
    }

    /* ---------------- live-state snapshot ---------------- */

    function test_state_headline() public view {
        uint256 farmUsdb = IERC20(USDB).balanceOf(FARM);
        uint256 symmioUsdb = IERC20(USDB).balanceOf(SYMMIO);
        uint256 vaultCore = IERC20(CORE).balanceOf(XCORE);
        uint256 vaultSupply = IxCore(XCORE).totalSupply();
        uint256 vaultAssets = IxCore(XCORE).totalAssets();
        uint256 lbpCore = IERC20(CORE).balanceOf(LBP);
        uint256 rewarderCore = IERC20(CORE).balanceOf(REWARDER);
        uint256 teamCore = IERC20(CORE).balanceOf(TEAMVEST);

        console2.log("fork block", block.number);
        console2.log("farm USDB (unclaimed rewards)", farmUsdb);
        console2.log("Symmio diamond USDB", symmioUsdb);
        console2.log("xCORE vault CORE/totalAssets", vaultAssets);
        console2.log("xCORE vault shares", vaultSupply);
        console2.log("LBP CORE", lbpCore);
        console2.log("rewarder CORE", rewarderCore);
        console2.log("team vesting CORE", teamCore);

        assertEq(IxCore(XCORE).asset(), CORE, "vault asset");
        assertGt(vaultAssets, 0, "vault has assets");
        assertEq(vaultAssets, vaultCore, "totalAssets == balance");
        // These are the only meaningful live balances found by the audit.
        assertGt(farmUsdb + symmioUsdb, 0, "USDB present");
    }

    /* ---------------- E-U candidate paths (all must fail) ---------------- */

    function test_EU_symmio_withdraw_no_balance_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISymmioDiamond(SYMMIO).withdraw(1e18);
        assertEq(ISymmioDiamond(SYMMIO).balanceOf(attacker), 0);
    }

    function test_EU_symmio_depositFor_requires_payment() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISymmioDiamond(SYMMIO).depositFor(attacker, 1e18);
    }

    function test_EU_farm_claim_without_stake_is_zero() public {
        vm.prank(attacker);
        ICoreMultiRewarder(FARM).getReward(false);
        assertEq(IERC20(USDB).balanceOf(attacker), 0, "no USDB");
        assertEq(IERC20(CORE).balanceOf(attacker), 0, "no CORE");
        assertEq(ICoreMultiRewarder(FARM).earned(attacker, USDB), 0);
    }

    function test_EU_farm_notify_without_payment_reverts() public {
        address[] memory toks = new address[](1);
        uint256[] memory amts = new uint256[](1);
        toks[0] = USDB;
        amts[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert();
        ICoreMultiRewarder(FARM).notifyRewardAmount(toks, amts);
    }

    function test_EU_vault_roundtrip_not_profitable() public {
        uint256 before_ = IxCore(XCORE).totalAssets();
        // fund attacker with CORE taken from the protocol treasury (impersonated on fork)
        address treasury = 0xC793Bec2483465F9220852eeb614242e9a62C1d2;
        vm.prank(treasury);
        IERC20(CORE).transfer(attacker, 2_000_000e18);
        uint256 start = IERC20(CORE).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(CORE).approve(XCORE, type(uint256).max);
        uint256 shares = IxCore(XCORE).deposit(1_000_000e18, attacker);
        // donation to try to inflate the share price
        IERC20(CORE).transfer(XCORE, 500_000e18);
        uint256 got = IxCore(XCORE).redeem(shares, attacker, attacker);
        vm.stopPrank();
        uint256 left = IERC20(CORE).balanceOf(attacker);
        console2.log("start", start);
        console2.log("got back", got);
        console2.log("final", left);
        assertLt(left, start, "attacker must lose on round trip");
        assertGe(IxCore(XCORE).totalAssets(), before_, "vault not drained");
    }

    function test_EU_vault_recover_not_owner_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IxCore(XCORE).recoverAsset(1e18);
    }

    function test_EU_lbp_buy_after_sale_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityBootstrapPool(LBP).swapExactAssetsForShares(1e18, 0, attacker);
    }

    function test_EU_lbp_sell_after_sale_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityBootstrapPool(LBP).swapExactSharesForAssets(1e18, 0, attacker);
    }

    function test_EU_lbp_close_again_reverts() public {
        assertTrue(ILiquidityBootstrapPool(LBP).closed(), "already closed");
        vm.prank(attacker);
        vm.expectRevert();
        ILiquidityBootstrapPool(LBP).close();
    }

    function test_EU_lbp_redeem_without_shares_yields_nothing() public {
        assertEq(ILiquidityBootstrapPool(LBP).purchasedShares(attacker), 0);
        vm.prank(attacker);
        uint256 shares = ILiquidityBootstrapPool(LBP).redeem();
        assertEq(shares, 0);
        assertEq(IERC20(CORE).balanceOf(attacker), 0);
    }

    function test_EU_rewarder_claim_wrong_signature_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IxCoreRewarder(REWARDER).claim(attacker, 1_000_000e18, block.timestamp, 1, hex"00");
    }

    function test_EU_teamvesting_claim_without_allocation_reverts() public {
        assertEq(IVesting(TEAMVEST).claimableAmount(attacker), 0);
        vm.prank(attacker);
        vm.expectRevert();
        IVesting(TEAMVEST).claim();
    }

    function test_EU_seedvesting_claim_without_allocation_reverts() public {
        assertEq(IVesting(SEEDVEST).claimableAmount(attacker), 0);
        vm.prank(attacker);
        vm.expectRevert();
        IVesting(SEEDVEST).claim();
    }

    function test_EU_core_token_has_no_mint() public {
        uint256 supply = IERC20(CORE).totalSupply();
        vm.prank(attacker);
        (bool ok,) = CORE.call(abi.encodeWithSignature("mint(uint256)", 1_000_000e18));
        assertFalse(ok, "mint must not exist");
        assertEq(IERC20(CORE).totalSupply(), supply);
    }

    function test_EU_core_token_burnFrom_without_allowance_reverts() public {
        // find an address that holds CORE and try to burn from it without allowance
        address victim = 0xC793Bec2483465F9220852eeb614242e9a62C1d2; // treasury (holds CORE)
        assertGt(IERC20(CORE).balanceOf(victim), 0);
        vm.prank(attacker);
        vm.expectRevert();
        ICoreToken(CORE).burnFrom(victim, 1e18);
    }

    function test_EU_multiaccount_unauthorized_call_reverts() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("withdrawTo(address,uint256)", attacker, 1e18);
        vm.prank(attacker);
        vm.expectRevert("MultiAccount: Unauthorized access");
        IMultiAccount(MA)._call(ACCOUNT, calls);
    }

    function test_EU_multiaccount_delegation_is_close_only() public {
        bytes4 withdrawSel = bytes4(keccak256("withdrawTo(address,uint256)"));
        assertFalse(IMultiAccount(MA).delegatedAccesses(ACCOUNT, EXEC, withdrawSel), "no withdraw delegation to executor");
        assertFalse(IMultiAccount(MA).delegatedAccesses(ACCOUNT, attacker, withdrawSel), "no attacker delegation");
        assertTrue(IMultiAccount(MA).owners(ACCOUNT) != attacker, "attacker is not owner");
    }

    function test_EU_symmexecutor_call_always_reverts() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("requestToClosePosition(uint256,uint256,uint256,uint8,uint256)", 1, 1, 1, 0, block.timestamp);
        vm.prank(attacker);
        vm.expectRevert();
        ISymmExecutor(EXEC)._call(ACCOUNT, calls);
    }

    function test_EU_partyb_call_unauthorized_reverts() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("withdraw(uint256)", 1e18);
        vm.prank(attacker);
        vm.expectRevert();
        ISymmioPartyB(PARTYB)._call(calls);
    }

    /* ---------------- H-O paths (holder self-service, no attacker value) ---------------- */

    function test_HO_vault_holder_can_redeem() public {
        address[8] memory holders = [
            0x62C6eDe90b1D4ce89bCD0224DD92DC80C983836e,
            0xF2830011799AdB2Ae035E033607254B25bfAFD97,
            0x29a44Ee57541c9a676fa979d55F304EA0AaD0857,
            0x194dC167c13120B0937809e5974366b1037d4A65,
            0x1ba6B82641C77aB1Fc7Bc734C5C3628199A8967D,
            0x26602Bf417c4e57bA3d2268d7f93A1E16F29E069,
            0x8E3389fe0d995278Ba77107f6b7868c22a47f4Ec,
            0x10C0014602516A154f8883aE4CBF09322d84cb81
        ];
        address best = address(0);
        uint256 bestBal = 0;
        for (uint256 i; i < holders.length; i++) {
            uint256 b = IERC20(XCORE).balanceOf(holders[i]);
            if (b > bestBal) { bestBal = b; best = holders[i]; }
        }
        if (bestBal == 0) { vm.skip(true); return; }
        uint256 shares = bestBal / 2;
        uint256 preview = IxCore(XCORE).previewRedeem(shares);
        vm.prank(best);
        uint256 got = IxCore(XCORE).redeem(shares, best, best);
        console2.log("holder redeemed shares", shares, "got CORE", got);
        assertGt(got, 0, "holder receives CORE");
        assertEq(got, preview, "preview matches");
    }

    function test_HO_farm_staker_can_claim_usdb() public {
        address[10] memory stakers = [
            0x730A3a201C8EdAF8Af2ab3a47fC1bcFd7d2A2D51,
            0x58a4e22CfD7894A5938df10CE4d09D272D076Fd0,
            0x21592320f0D90Ee01392d60aA28bA47a6aFEfEB2,
            0x287614fbB4273C31c2a12fE35AE642b4A4fBb286,
            0x07Eac6Dc2AF876d2F0402f6804cc6cEAa0cd20Cd,
            0x4171E82CfC894613baD44ecb64C942D4cEea0d54,
            0x22728187a951EfaD8976f96F584830Ab8dE13162,
            0xcA93e23041Cf87A1305b4199aA74d3cCC992498a,
            0xacd4ae6abF36817Fb89A39fe6C2d3093f41DFceF,
            0x9C6662cC5Dab171cf64DB3D06E65B25df5e954CE
        ];
        address best = address(0);
        uint256 bestEarned = 0;
        for (uint256 i; i < stakers.length; i++) {
            uint256 e = ICoreMultiRewarder(FARM).earned(stakers[i], USDB);
            if (e > bestEarned) { bestEarned = e; best = stakers[i]; }
        }
        if (bestEarned == 0) { vm.skip(true); return; }
        uint256 before_ = IERC20(USDB).balanceOf(best);
        vm.prank(best);
        ICoreMultiRewarder(FARM).getReward(false);
        uint256 delta = IERC20(USDB).balanceOf(best) - before_;
        console2.log("staker claimed USDB", delta);
        assertEq(delta, bestEarned, "staker receives own rewards");
    }
}
