// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// Minimal interfaces for Splice (Pendle V2 fork) on Blast.
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface ISY is IERC20 {
    function exchangeRate() external view returns (uint256);
    function yieldToken() external view returns (address);
    function assetInfo() external view returns (uint8, address, uint8);
    function redeem(address receiver, uint256 amountShares, address tokenOut, uint256 minOut, bool burnFromInternalBalance) external returns (uint256);
}

interface IMarket is IERC20 {
    function expiry() external view returns (uint256);
    function burn(address receiverSy, address receiverPt, uint256 netLpToBurn) external returns (uint256, uint256);
    function skim() external;
    function _storage() external view returns (int128 totalPt, int128 totalSy, uint96 lastLnImpliedRate, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext);
    function readTokens() external view returns (address, address, address);
}

interface IYT is IERC20 {
    function redeemPY(address receiver) external returns (uint256);
    function redeemPYMulti(address[] calldata receivers, uint256[] calldata amounts) external returns (uint256[] memory);
    function redeemInterestAndRewardsPostExpiryForTreasury() external returns (uint256, uint256[] memory);
    function redeemDueInterestAndRewards(address user, bool redeemInterest, bool redeemRewards) external returns (uint256, uint256[] memory);
    function userInterest(address) external view returns (uint128, uint128);
    function pyIndexStored() external view returns (uint256);
    function syReserve() external view returns (uint256);
    function PT() external view returns (address);
    function SY() external view returns (address);
    function expiry() external view returns (uint256);
}

/// Splice Finance (Blast) — external-unprivileged extraction PoC.
/// Read-only against mainnet; runs on a fork only. No mainnet transactions.
contract SpliceExtractionTest is Test {
    // Blast mainnet (pinned to the state-dump block)
    uint256 constant FORK_BLOCK = 41_475_467;

    // ---- Blast addresses (verified live at FORK_BLOCK) ----
    address constant SY_hUSDB  = 0x13293Dacab830D8fA2E0e961Fb997b3f37186f46;
    address constant SY_hWETH  = 0xB80aD10DFfDD415C2159962C1B35eF6edCf1B505;
    address constant SY_wUSDB  = 0xF904fA59d1eaCEC21D758ccd2FE43261A1dD5470;
    address constant SY_sWETH  = 0xc28fb4cc69081f9F72C643C47E8FeF7B4AB2E7AA;
    address constant SY_sUSDB  = 0x0e999EB7F4e553348703D4eD804079c89E8C92F5;
    address constant USDB      = 0x4300000000000000000000000000000000000003;
    address constant WETH      = 0x4300000000000000000000000000000000000004;

    address constant MKT_hUSDB_1 = 0x6B61cFce05AaF44eBA5dA45DEF48C0FBD26390A1; // holds PT+SY for hUSDB
    address constant MKT_hUSDB_2 = 0x258133c3ECD19591544c01884227E4Ae03F0Dbd0;
    address constant MKT_hWETH_1 = 0xb9612aF20a0143661A695Fcb0D176AA2bda2a332;
    address constant YT_hUSDB    = 0xC878aEb90E6C35d81A8CeAA8dBB89B35aEE81C87;
    address constant PT_hUSDB    = 0x1CDE6a099A1Cb14f3093d2B7cB5B7cBb2145cB64;
    address constant TREASURY_f1 = 0x88653cb81db25dA4136448BDf561B41B77b052C4; // factory-1 owner & treasury (EOA)

    // real holders discovered from on-chain transfer history (block 41475467)
    address constant YT_HOLDER   = 0x13FeFdD563A930F07B1aC8A2227Acc27c3C12946; // 112,085.60 YT, index 1.0120778 < firstPYIndex
    address constant LP_HOLDER   = 0x45D2E8929D394C87b29aCa423c12CBE3154b61b8; // 1,799.0701 LP of MKT_hUSDB_1

    function setUp() public {
        string memory rpc = vm.envOr("BLAST_RPC_URL", string("https://rpc.blast.io")); // archive-capable
        vm.createSelectFork(rpc, FORK_BLOCK);
    }

    // ------------------------------------------------------------------
    // PART 1 — NEGATIVE: outsider with no PT/YT/LP/SY cannot take value
    // ------------------------------------------------------------------

    /// @notice No SY holds its own tokens; burnFromInternalBalance cannot be abused.
    function test_outsider_cannot_drain_sy_internal_balance() public {
        address[5] memory sys = [SY_hUSDB, SY_hWETH, SY_wUSDB, SY_sWETH, SY_sUSDB];
        for (uint256 i = 0; i < sys.length; i++) {
            assertEq(IERC20(sys[i]).balanceOf(sys[i]), 0, "SY self-balance must be 0");
            (uint8 t, address u, ) = ISY(sys[i]).assetInfo();
            assertEq(t, 0);
            vm.expectRevert();
            ISY(sys[i]).redeem(address(this), 1e18, u, 0, true); // burn from SY's own balance
        }
        // outsider with zero SY balance cannot redeem either
        vm.expectRevert();
        ISY(SY_hUSDB).redeem(address(this), 1e18, USDB, 0, false);
    }

    /// @notice The YT contract holds 0 PT; redeemPY cannot sweep anything to a stranger.
    function test_outsider_cannot_sweep_yt() public {
        assertEq(IERC20(PT_hUSDB).balanceOf(YT_hUSDB), 0, "YT must hold no PT");
        uint256 before = IERC20(SY_hUSDB).balanceOf(address(this));
        uint256 out = IYT(YT_hUSDB).redeemPY(address(this));
        assertEq(out, 0, "redeemPY must pay nothing");
        assertEq(IERC20(SY_hUSDB).balanceOf(address(this)), before);
        // huge bogus amounts revert (burn from YT's own PT balance = 0)
        address[] memory recv = new address[](1);
        uint256[] memory amts = new uint256[](1);
        recv[0] = address(this);
        amts[0] = 1e30;
        vm.expectRevert();
        IYT(YT_hUSDB).redeemPYMulti(recv, amts);
    }

    /// @notice Market burn requires actually owning LP.
    function test_outsider_cannot_burn_market() public {
        assertEq(IERC20(MKT_hUSDB_1).balanceOf(address(this)), 0);
        vm.expectRevert();
        IMarket(MKT_hUSDB_1).burn(address(this), address(this), 1e18);
    }

    /// @notice skim() sends donated surplus to the protocol treasury, not to the caller.
    function test_skim_surplus_goes_to_treasury_not_caller() public {
        (int128 tPt, int128 tSy, , , , ) = IMarket(MKT_hUSDB_1)._storage();
        uint256 excessPt = IERC20(PT_hUSDB).balanceOf(MKT_hUSDB_1) - uint256(uint128(tPt));
        uint256 excessSy = IERC20(SY_hUSDB).balanceOf(MKT_hUSDB_1) - uint256(uint128(tSy));
        assertGt(excessSy, 0, "known donated surplus exists");

        uint256 attSyBefore = IERC20(SY_hUSDB).balanceOf(address(this));
        uint256 attPtBefore = IERC20(PT_hUSDB).balanceOf(address(this));
        uint256 tSyBefore = IERC20(SY_hUSDB).balanceOf(TREASURY_f1);
        uint256 tPtBefore = IERC20(PT_hUSDB).balanceOf(TREASURY_f1);

        IMarket(MKT_hUSDB_1).skim();

        assertEq(IERC20(SY_hUSDB).balanceOf(address(this)), attSyBefore, "caller got SY");
        assertEq(IERC20(PT_hUSDB).balanceOf(address(this)), attPtBefore, "caller got PT");
        assertEq(IERC20(SY_hUSDB).balanceOf(TREASURY_f1) - tSyBefore, excessSy, "treasury got SY");
        assertEq(IERC20(PT_hUSDB).balanceOf(TREASURY_f1) - tPtBefore, excessPt, "treasury got PT");
    }

    /// @notice Post-expiry treasury sweep is permissionless but pays only the factory treasury.
    function test_treasury_sweep_pays_treasury_only() public {
        // The YT contract holds accumulated post-expiry interest owed to the factory treasury.
        uint256 tBefore = IERC20(SY_hUSDB).balanceOf(TREASURY_f1);
        uint256 aBefore = IERC20(SY_hUSDB).balanceOf(address(this));
        vm.prank(address(0x1111111111111111111111111111111111111111));
        (uint256 interestOut, ) = IYT(YT_hUSDB).redeemInterestAndRewardsPostExpiryForTreasury();
        assertGt(interestOut, 15_000e18, "expected ~15158.78 SY to treasury");
        assertEq(IERC20(SY_hUSDB).balanceOf(address(this)), aBefore, "caller got SY");
        assertEq(IERC20(SY_hUSDB).balanceOf(TREASURY_f1) - tBefore, interestOut, "treasury got the SY");
    }

    // ------------------------------------------------------------------
    // PART 2 — POSITIVE: the live value is redeemable by its holders (H-O)
    // ------------------------------------------------------------------

    /// @notice Real YT holder can claim accrued interest (SY) from the deployed contract.
    function test_real_yt_holder_can_claim_interest() public {
        (uint128 idx, uint128 accrued) = IYT(YT_hUSDB).userInterest(YT_HOLDER);
        assertEq(uint256(accrued), 0);
        assertLt(uint256(idx), IYT(YT_hUSDB).pyIndexStored(), "index below stored => unaccrued interest exists");

        uint256 syBefore = IERC20(SY_hUSDB).balanceOf(YT_HOLDER);
        vm.prank(YT_HOLDER);
        (uint256 interestOut, ) = IYT(YT_hUSDB).redeemDueInterestAndRewards(YT_HOLDER, true, false);
        assertGt(interestOut, 1_400e18, "expected ~1411.47 SY");
        assertEq(IERC20(SY_hUSDB).balanceOf(YT_HOLDER) - syBefore, interestOut);
    }

    /// @notice Real LP holder can burn LP and receive PT+SY pro-rata.
    function test_real_lp_holder_can_burn() public {
        uint256 lp = IERC20(MKT_hUSDB_1).balanceOf(LP_HOLDER);
        assertGt(lp, 0, "LP holder must hold LP");
        uint256 syBefore = IERC20(SY_hUSDB).balanceOf(LP_HOLDER);
        uint256 ptBefore = IERC20(PT_hUSDB).balanceOf(LP_HOLDER);
        uint256 lpTotal = IERC20(MKT_hUSDB_1).totalSupply();
        (int128 tPt, int128 tSy, , , , ) = IMarket(MKT_hUSDB_1)._storage(); // BEFORE burn

        vm.startPrank(LP_HOLDER);
        IERC20(MKT_hUSDB_1).transfer(MKT_hUSDB_1, lp);
        (uint256 syOut, uint256 ptOut) = IMarket(MKT_hUSDB_1).burn(LP_HOLDER, LP_HOLDER, lp);
        vm.stopPrank();

        assertGt(syOut, 0);
        assertGt(ptOut, 0);
        assertEq(IERC20(SY_hUSDB).balanceOf(LP_HOLDER) - syBefore, syOut);
        assertEq(IERC20(PT_hUSDB).balanceOf(LP_HOLDER) - ptBefore, ptOut);
        // pro-rata sanity: lp/lpTotal of pre-burn internal balances
        assertApproxEqRel(syOut, lp * uint256(uint128(tSy)) / lpTotal, 0.001e18);
        assertApproxEqRel(ptOut, lp * uint256(uint128(tPt)) / lpTotal, 0.001e18);
    }

    /// @notice SY is a live 1:1 wrapper of the ERC4626 vault: shares redeem for the underlying.
    function test_sy_redeem_pays_underlying() public {
        uint256 shares = 1e18;
        uint256 rate = ISY(SY_hUSDB).exchangeRate();
        uint256 syBefore = IERC20(SY_hUSDB).balanceOf(YT_hUSDB);
        vm.prank(YT_hUSDB);
        uint256 out = ISY(SY_hUSDB).redeem(YT_hUSDB, shares, USDB, 0, false);
        assertApproxEqAbs(out, shares * rate / 1e18, 2); // vault rounds down
        assertEq(syBefore - IERC20(SY_hUSDB).balanceOf(YT_hUSDB), shares);
    }

    /// @notice PT redemption path pays SY to the redeemer (PT sourced via forge deal: holder simulation).
    function test_pt_redemption_pays_redeemer() public {
        address holder = address(0xBEEF);
        uint256 ptAmount = 1_000e18;
        deal(PT_hUSDB, holder, ptAmount);
        uint256 rate = ISY(SY_hUSDB).exchangeRate(); // _pyIndexCurrent = max(exchangeRate, stored)
        vm.startPrank(holder);
        IERC20(PT_hUSDB).transfer(YT_hUSDB, ptAmount);
        uint256 syOut = IYT(YT_hUSDB).redeemPY(holder);
        vm.stopPrank();
        assertEq(syOut, ptAmount * 1e18 / rate);
        assertEq(IERC20(SY_hUSDB).balanceOf(holder), syOut);
    }

    // ------------------------------------------------------------------
    // PART 3 — context assertions used in the report
    // ------------------------------------------------------------------

    function test_context_state() public {
        assertEq(IMarket(MKT_hUSDB_1).expiry(), 1_719_446_400); // 27JUN2024 (expired)
        assertTrue(block.timestamp > IMarket(MKT_hUSDB_1).expiry());
        assertEq(IERC20(PT_hUSDB).balanceOf(YT_hUSDB), 0);
        assertEq(IERC20(SY_hUSDB).balanceOf(SY_hUSDB), 0);
        assertGt(IERC20(SY_hUSDB).balanceOf(YT_hUSDB), 99_000e18); // PY backing held by YT contract
        assertGt(IERC20(SY_hUSDB).balanceOf(MKT_hUSDB_1), 478e18);  // LP backing held by market
    }
}
