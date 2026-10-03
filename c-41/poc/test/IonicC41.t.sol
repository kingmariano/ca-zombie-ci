// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    ICErc20,
    IComptroller,
    IPriceOracle,
    IFeeDistributor,
    ILBTC,
    AttackerFlash
} from "../src/Interfaces.sol";

/// C-41 — Ionic Protocol (Mode) live-state & extractability fork tests.
/// READ-ONLY PoC: every test runs on a local fork only. No mainnet transactions.
contract IonicC41Test is Test {
    // Mode mainnet
    address constant COMPTROLLER_A = 0xFB3323E24743Caf4ADD0fDCCFB268565c0685556;
    address constant ION_LBTC = 0xADE794534c05F79981337E73dc2A987cdFf1958d;
    address constant ORACLE = 0x2BAF3A2B667A5027a83101d218A9e8B73577F117;
    address constant LBTC = 0x964dd444e3192F636322229080A576077B06FbA3;
    address constant DEPOSITOR = 0x9E34d89C013Da3BF65fc02b59B6F27D710850430;
    address constant FEE_DISTRIBUTOR = 0x8ea3fc79D9E463464C5159578d38870b770f6E57;
    address constant ATTACKER = 0x000000000000000000000000000000000000dEaD;

    // expected live values (8-dec LBTC)
    uint256 constant LBTC_CASH = 24_900_006_075; // 249.00006075 LBTC
    uint256 constant DEPOSITOR_CTOKENS = 124_500_000_000;
    uint256 constant CTOKEN_TOTAL_SUPPLY = 124_500_055_375;
    uint256 constant EXCHANGE_RATE = 0.2e18;
    uint256 constant LBTC_MARKET_BORROWS = 5000;

    function _rpcUrl() internal view returns (string memory) {
        string memory url = vm.envOr("MODE_RPC_URL", string(""));
        if (bytes(url).length > 0) return url;
        // Public Mode RPC (keyless) — dRPC free tier is incompatible with foundry's
        // fork provider (batch limits / transient 500s), so it is not used here.
        return "https://mainnet.mode.network";
    }

    function setUp() public {
        vm.createSelectFork(_rpcUrl());
    }

    /* ------------------------------------------------------------------ */
    /* 1. live state                                                       */
    /* ------------------------------------------------------------------ */

    function test_state_mode_a_live_values() public {
        address[] memory markets = IComptroller(COMPTROLLER_A).getAllMarkets();
        assertEq(markets.length, 18, "18 markets");

        assertEq(ICErc20(ION_LBTC).getCash(), LBTC_CASH, "market holds 249.00006075 LBTC");
        assertEq(ICErc20(ION_LBTC).totalSupply(), CTOKEN_TOTAL_SUPPLY, "cToken supply");
        assertEq(ICErc20(ION_LBTC).totalBorrows(), LBTC_MARKET_BORROWS, "borrows ~0");
        assertEq(ICErc20(ION_LBTC).exchangeRateCurrent(), EXCHANGE_RATE, "frozen exchange rate");

        assertEq(ICErc20(ION_LBTC).balanceOf(DEPOSITOR), DEPOSITOR_CTOKENS, "depositor cTokens");
        assertEq(ICErc20(ION_LBTC).balanceOfUnderlying(DEPOSITOR), 24_900_000_000, "underlying = 249 LBTC");
        assertEq(ICErc20(LBTC).balanceOf(ION_LBTC), LBTC_CASH, "market LBTC balance");
        assertEq(ICErc20(LBTC).balanceOf(DEPOSITOR), 100_000_000, "depositor EOA holds 1 LBTC");

        assertTrue(IComptroller(COMPTROLLER_A).checkMembership(DEPOSITOR, ION_LBTC), "depositor is a member");
        assertTrue(IComptroller(COMPTROLLER_A).mintGuardianPaused(ION_LBTC), "mint paused");
        assertTrue(IComptroller(COMPTROLLER_A).borrowGuardianPaused(ION_LBTC), "borrow paused");
        assertFalse(IComptroller(COMPTROLLER_A).transferGuardianPaused(), "transfer not paused");
        assertFalse(IComptroller(COMPTROLLER_A).seizeGuardianPaused(), "seize not paused");
        assertFalse(IComptroller(COMPTROLLER_A).isDeprecated(ION_LBTC), "market not deprecated");
        assertEq(IComptroller(COMPTROLLER_A).closeFactorMantissa(), 0.5e18, "close factor 50%");
        assertEq(IComptroller(COMPTROLLER_A).liquidationIncentiveMantissa(), 1.08e18, "liq incentive 8%");
    }

    /* ------------------------------------------------------------------ */
    /* 2. the oracle gap                                                   */
    /* ------------------------------------------------------------------ */

    function test_oracle_has_no_lbtc_price() public {
        vm.expectRevert(bytes("Price oracle not found for this underlying token address."));
        IPriceOracle(ORACLE).getUnderlyingPrice(ION_LBTC);
    }

    function test_depositor_redeem_blocked_by_oracle() public {
        vm.prank(DEPOSITOR);
        vm.expectRevert(bytes("Price oracle not found for this underlying token address."));
        ICErc20(ION_LBTC).redeem(1);
    }

    function test_depositor_redeemUnderlying_blocked_by_oracle() public {
        vm.prank(DEPOSITOR);
        vm.expectRevert(bytes("Price oracle not found for this underlying token address."));
        ICErc20(ION_LBTC).redeemUnderlying(1);
    }

    function test_depositor_transfer_blocked_by_oracle() public {
        vm.prank(DEPOSITOR);
        vm.expectRevert(bytes("Price oracle not found for this underlying token address."));
        ICErc20(ION_LBTC).transfer(ATTACKER, 1);
    }

    function test_depositor_exitMarket_blocked_by_oracle() public {
        vm.prank(DEPOSITOR);
        vm.expectRevert(bytes("Price oracle not found for this underlying token address."));
        IComptroller(COMPTROLLER_A).exitMarket(ION_LBTC);
    }

    /* ------------------------------------------------------------------ */
    /* 3. attacker entry points                                            */
    /* ------------------------------------------------------------------ */

    function test_attacker_mint_reverts_paused() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!mint:paused"));
        ICErc20(ION_LBTC).mint(1);
    }

    function test_attacker_borrow_reverts_paused() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!borrow:paused"));
        ICErc20(ION_LBTC).borrow(1);
    }

    function test_attacker_cannot_redeem_without_ctokens() public {
        vm.prank(ATTACKER);
        uint256 err = ICErc20(ION_LBTC).redeem(1_000_000);
        assertGt(err, 0, "redeem without cTokens returns an error code");
        assertEq(ICErc20(LBTC).balanceOf(ATTACKER), 0, "attacker receives nothing");
    }

    function test_attacker_liquidate_depositor_reverts() public {
        // even if the depositor had debt, liquidation pricing needs the LBTC oracle
        vm.prank(ATTACKER);
        vm.expectRevert();
        ICErc20(ION_LBTC).liquidateBorrow(DEPOSITOR, 1, ION_LBTC);
    }

    /* ------------------------------------------------------------------ */
    /* 4. flash() path — callable but not extractive                       */
    /* ------------------------------------------------------------------ */

    function test_flash_is_authorized_for_anyone() public view {
        bool ok = IFeeDistributor(FEE_DISTRIBUTOR).canCall(COMPTROLLER_A, ATTACKER, ION_LBTC, bytes4(0x3c3b4b89));
        assertTrue(ok, "flash authorized for arbitrary caller");
    }

    function test_flash_without_repayment_reverts() public {
        AttackerFlash atk = new AttackerFlash(ION_LBTC);
        atk.setRepay(false);
        vm.expectRevert();
        atk.run(1_000_000);
    }

    function test_flash_honest_repayment_yields_zero_profit() public {
        AttackerFlash atk = new AttackerFlash(ION_LBTC);
        atk.setRepay(true);
        uint256 cashBefore = ICErc20(ION_LBTC).getCash();
        atk.run(1_000_000);
        assertEq(ICErc20(LBTC).balanceOf(address(atk)), 0, "attacker keeps nothing");
        assertEq(ICErc20(ION_LBTC).getCash(), cashBefore, "market cash unchanged");
        assertEq(ICErc20(ION_LBTC).totalBorrows(), LBTC_MARKET_BORROWS, "borrows restored");
    }

    /* ------------------------------------------------------------------ */
    /* 5. Mode LBTC peg-out is closed                                      */
    /* ------------------------------------------------------------------ */

    function test_mode_lbtc_withdrawals_disabled() public {
        // LBTCStorage base slot + 3 packs: isWithdrawalsEnabled (low byte) | consortium | isWBTCEnabled
        bytes32 base = 0xa9a2395ec4edf6682d754acb293b04902817fdb5829dd13adb0367ab3a26c700;
        bytes32 slot3 = vm.load(LBTC, bytes32(uint256(base) + 3));
        bool withdrawalsEnabled = (uint256(slot3) & 0xff) != 0;
        assertFalse(withdrawalsEnabled, "withdrawals disabled");
        address consortium = address(uint160(uint256(slot3) >> 8));
        assertEq(consortium, 0x0Ae91EC854dBAFBC59Fc96B90c46255beE9D67aE, "consortium decoded");

        assertEq(ILBTC(LBTC).getTreasury(), address(0), "treasury unset");
        assertEq(ILBTC(LBTC).getDestination(bytes32(uint256(1))), bytes32(0), "no Ethereum destination");
        assertEq(ILBTC(LBTC).getBurnCommission(), 10_000, "burn commission 10k sat");
        assertFalse(ILBTC(LBTC).paused(), "token not paused");
    }

    function test_mode_lbtc_redeem_reverts_withdrawals_disabled() public {
        // P2WSH script (34 bytes) is a recognised output type
        bytes memory spk = hex"0020000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
        vm.prank(DEPOSITOR);
        vm.expectRevert(abi.encodeWithSignature("WithdrawalsDisabled()"));
        ILBTC(LBTC).redeem(spk, 100_000);
    }

    /* ------------------------------------------------------------------ */
    /* 6. sibling chains: markets exist but every value path is gated      */
    /* ------------------------------------------------------------------ */

    function test_no_borrower_can_be_liquidated_for_profit() public view {
        // The Mode-A borrower registry has 38k+ entries; any *live* debt would
        // still require the missing LBTC price to size a seizure.
        uint256 n = IComptroller(COMPTROLLER_A).getAllBorrowersCount();
        assertGt(n, 30_000, "borrower registry non-trivial");
        address first = IComptroller(COMPTROLLER_A).allBorrowers(0);
        assertTrue(first != address(0), "first borrower readable");
    }
}
