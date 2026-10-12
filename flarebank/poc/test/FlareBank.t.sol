// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IWFLR, IBank, IVault} from "../src/IFlareBank.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
}

/// @title FlareBank (Flare) — live extraction PoC (read-only mainnet fork)
/// @notice Phase-2 zombie-hunt deep dive. All tests run on a local fork of Flare
///         mainnet; NO transaction is ever broadcast to the real network.
contract FlareBankTest is Test {
    IWFLR constant WFLR = IWFLR(0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d);
    IBank constant BANK = IBank(0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059);
    IVault constant VAULT = IVault(0x90679234FE693B39BFdf5642060Cb10571Adc59b);

    // top BANK holder (36.6% of supply), also a big IBDP user
    address constant TOP_HOLDER = 0x3c1c84132DFdef572E74672917700c065581871D;
    // largest IBDP depositor: 11,347,812.03 WFLR, last deposit 2026-02-05
    address constant BIG_DEPOSITOR = 0x728Eb0118757207fcBb396f40FE3b8E472896c24;
    address constant ATTACKER = address(0xA11CE);
    address constant NOBODY = address(0xBEEF);

    function _forkUrl() internal view returns (string memory) {
        return vm.envOr("FLARE_RPC_URL", string("https://flare-api.flare.network/ext/C/rpc"));
    }

    /// append a measured fork result to ci-out/ (uploaded as CI artifact)
    function _dump(string memory k, uint256 v) internal {
        if (vm.exists("../ci-out")) {
            vm.writeLine("../ci-out/fork_results.txt", string.concat(k, "=", vm.toString(v)));
        }
    }

    function setUp() public {
        vm.createSelectFork(_forkUrl());
    }

    // ------------------------------------------------------------------
    // live state snapshot
    // ------------------------------------------------------------------
    function test_00_live_state() public {
        uint256 supply = BANK.totalSupply();
        uint256 reserve = WFLR.balanceOf(address(BANK));
        uint256 vaultBal = WFLR.balanceOf(address(VAULT));
        emit log_named_decimal_uint("BANK totalSupply", supply, 18);
        emit log_named_decimal_uint("Bank WFLR reserve", reserve, 18);
        emit log_named_decimal_uint("Bank buyPrice (FLR/token)", BANK.buyPrice(), 18);
        emit log_named_decimal_uint("Bank sellPrice (token/FLR)", BANK.sellPrice(), 18);
        emit log_named_decimal_uint("unclaimedDividendTotal", BANK.unclaimedDividendTotal(), 18);
        emit log_named_decimal_uint("unclaimedTeamFees", BANK.unclaimedTeamFees(), 18);
        emit log_named_decimal_uint("unclaimedFeeReceiverFees", BANK.unclaimedFeeReceiverFees(), 18);
        emit log_named_decimal_uint("Vault WFLR balance", vaultBal, 18);
        emit log_named_decimal_uint("TOP_HOLDER BANK", BANK.balanceOf(TOP_HOLDER), 18);
        emit log_named_decimal_uint("BIG_DEPOSITOR vault balance", VAULT.getBalance(BIG_DEPOSITOR), 18);
        assertGt(supply, 2_000_000e18);
        assertGt(reserve, 18_000_000e18);
        assertGt(vaultBal, 13_000_000e18);
        assertEq(VAULT.bank(), address(BANK));
    }

    // ------------------------------------------------------------------
    // H-O: existing holder / depositor self-service extraction
    // ------------------------------------------------------------------

    /// Sell a holder's entire balance in chunks respecting the contract's
    /// per-sell cap (taxedEth < MAX_BUY = 50,001 NAT), then withdraw.
    function _sellAllAndWithdraw(address holder) internal returns (uint256 gained) {
        uint256 before = WFLR.balanceOf(holder);
        uint256 guard;
        while (BANK.balanceOf(holder) > 0 && guard < 3000) {
            uint256 bal = BANK.balanceOf(holder);
            uint256 chunk = bal > 2_500e18 ? 2_500e18 : bal;
            while (BANK.calculateEthereumReceived(chunk) >= 50_001e18 && chunk > 1e18) {
                chunk = chunk * 95 / 100;
            }
            vm.prank(holder);
            BANK.sell(chunk);
            guard++;
        }
        vm.prank(holder);
        BANK.withdraw();
        gained = WFLR.balanceOf(holder) - before;
    }

    /// Top BANK holder sells its entire balance and withdraws: ~9.6M WFLR out.
    function test_10_ho_top_holder_sells_full_balance() public {
        uint256 bal = BANK.balanceOf(TOP_HOLDER);
        assertGt(bal, 800_000e18);
        uint256 quoted = BANK.calculateEthereumReceived(bal);
        emit log_named_decimal_uint("quoted WFLR if one-shot (blocked by cap)", quoted, 18);

        uint256 gained = _sellAllAndWithdraw(TOP_HOLDER);
        _dump("top_holder_wflr", gained);
        emit log_named_decimal_uint("WFLR actually withdrawn by top holder", gained, 18);
        assertGt(gained, 9_000_000e18); // curve price far above NAV; ~9.6M+ expected
        assertEq(BANK.balanceOf(TOP_HOLDER), 0);
    }

    /// Largest IBDP depositor withdraws its full principal (30-day lock long expired).
    function test_11_ho_vault_depositor_withdraws_principal() public {
        uint256 bal = VAULT.getBalance(BIG_DEPOSITOR);
        assertGt(bal, 11_000_000e18);
        uint256 before = WFLR.balanceOf(BIG_DEPOSITOR);

        vm.prank(BIG_DEPOSITOR);
        VAULT.withdraw(bal);

        assertEq(WFLR.balanceOf(BIG_DEPOSITOR) - before, bal);
        assertEq(VAULT.getBalance(BIG_DEPOSITOR), 0);
        _dump("vault_depositor_wflr", bal);
        emit log_named_decimal_uint("vault principal withdrawn", bal, 18);
    }

    /// Five largest holders sell out sequentially — aggregate holder extraction.
    function test_12_ho_top5_holders_sell_out() public {
        address[5] memory hs = [
            0x3c1c84132DFdef572E74672917700c065581871D,
            0xDc2dA37e7B01Fe04EFD3560307e634e736A0d251,
            0x0B465f43db2F05a3A68F838c5080aCae649f28d4,
            0xaA68BC4BAb9a63958466f49f5a58c54A412D4906,
            0xa3161e2aA17ea25745240Ef06692452ad62a6e7d
        ];
        uint256 totalOut;
        for (uint256 i = 0; i < hs.length; i++) {
            if (BANK.balanceOf(hs[i]) == 0) continue;
            uint256 gained = _sellAllAndWithdraw(hs[i]);
            totalOut += gained;
            emit log_named_decimal_uint("holder withdrew", gained, 18);
        }
        emit log_named_decimal_uint("TOP-5 total WFLR withdrawn", totalOut, 18);
        _dump("top5_total_wflr", totalOut);
        assertGt(totalOut, 12_000_000e18);
    }

    // ------------------------------------------------------------------
    // E-U negatives: unprivileged attacker paths all fail / lose money
    // ------------------------------------------------------------------

    /// Non-depositor cannot withdraw from the vault.
    function test_20_eu_vault_non_depositor_reverts() public {
        vm.prank(NOBODY);
        vm.expectRevert("No funds to withdraw");
        VAULT.withdraw(1);
    }

    /// Fresh deposit is locked for 30 days (no immediate round-trip).
    function test_21_eu_vault_fresh_deposit_locked() public {
        vm.deal(ATTACKER, 1_000 ether);
        vm.prank(ATTACKER);
        VAULT.deposit{value: 1_000 ether}();
        assertEq(VAULT.getBalance(ATTACKER), 1_000 ether);
        vm.prank(ATTACKER);
        vm.expectRevert("Funds are locked");
        VAULT.withdraw(1 ether);
    }

    /// Anyone can poke the vault's reward claims, but the rewards go to the Bank, not the caller.
    function test_22_eu_permissionless_claim_goes_to_bank() public {
        uint256 a0 = WFLR.balanceOf(ATTACKER);
        try VAULT.tryClaimAllTsoRewards() {} catch {}
        assertEq(WFLR.balanceOf(ATTACKER), a0);
    }

    /// No dividends to steal without holding BANK.
    function test_23_eu_bank_withdraw_without_tokens_reverts() public {
        vm.prank(NOBODY);
        vm.expectRevert("No dividends");
        BANK.withdraw();
    }

    /// Re-initialization (role takeover) is blocked on both proxies.
    function test_24_eu_reinitialize_reverts() public {
        address[] memory delegates = new address[](0);
        uint256[] memory bips = new uint256[](0);

        vm.prank(NOBODY);
        vm.expectRevert("Initializable: contract is already initialized");
        BANK.initialize(NOBODY, NOBODY, NOBODY, address(VAULT), delegates, bips);

        vm.prank(NOBODY);
        vm.expectRevert("Initializable: contract is already initialized");
        VAULT.initialize(address(BANK), address(WFLR), delegates, bips);
    }

    /// Unauthorized upgrade (admin is the team's ProxyAdmin contract 0x9e199934...) is blocked.
    function test_25_eu_unauthorized_upgrade_reverts() public {
        vm.prank(NOBODY);
        vm.expectRevert();
        BANK.upgradeTo(address(0x0000000000000000000000000000000000000005));

        vm.prank(NOBODY);
        vm.expectRevert();
        VAULT.upgradeTo(address(0x0000000000000000000000000000000000000005));
    }

    /// buy -> sell round trip loses money (10% buy tax + 1% sell tax + curve drag):
    /// there is no unprivileged arbitrage against the bonding curve.
    function test_26_eu_buy_sell_roundtrip_loses() public {
        uint256 spend = 50_000 ether; // MAX_BUY is 50,001 NAT
        vm.deal(ATTACKER, spend);
        assertEq(WFLR.balanceOf(ATTACKER), 0);

        vm.prank(ATTACKER);
        BANK.buy{value: spend}(address(0));
        uint256 tokens = BANK.balanceOf(ATTACKER);
        assertGt(tokens, 0);

        vm.prank(ATTACKER);
        BANK.sell(tokens);
        vm.prank(ATTACKER);
        BANK.withdraw();

        uint256 out = WFLR.balanceOf(ATTACKER);
        _dump("roundtrip_spent_wflr", spend);
        _dump("roundtrip_recovered_wflr", out);
        emit log_named_decimal_uint("spent (native FLR)", spend, 18);
        emit log_named_decimal_uint("recovered (WFLR)", out, 18);
        assertLt(out, spend * 95 / 100); // >5% loss guaranteed
    }

    /// Self-referral does not turn a loss into a profit (referral = 2.4% of buy value).
    function test_27_eu_self_referral_still_loses() public {
        uint256 spend = 10_000 ether;
        vm.deal(ATTACKER, spend);

        vm.prank(ATTACKER);
        BANK.buy{value: spend}(ATTACKER); // refer self
        uint256 tokens = BANK.balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        BANK.sell(tokens);
        vm.prank(ATTACKER);
        BANK.withdraw();

        uint256 out = WFLR.balanceOf(ATTACKER);
        emit log_named_decimal_uint("self-referral round trip recovered", out, 18);
        assertLt(out, spend); // still a net loss
    }

    /// Only material E-U path found: a sub-$1 mint-from-Bank -> dump-on-DEX-V2
    /// arbitrage (DEX price ~20.92 vs all-in mint cost ~20.67 WFLR/BANK).
    /// Fork-proven; profit is bounded by ~1% of pair depth and funded by DEX LPs.
    function test_28_eu_dex_vs_curve_arb_tiny() public {
        IUniswapV2Pair pair = IUniswapV2Pair(0x5F29C8d049e47DD180c2B83E3560E8e271110335);
        uint256 spend = 10_000 ether;

        // wrap native FLR properly (WFLR tracks vote-power checkpoints; vm.deal on the
        // token would break its bookkeeping) then mint BANK from the curve
        vm.deal(ATTACKER, spend);
        vm.startPrank(ATTACKER);
        WFLR.deposit{value: spend}();
        WFLR.approve(address(BANK), type(uint256).max);
        BANK.buy(spend, address(0));
        uint256 tokens = BANK.balanceOf(ATTACKER);
        assertGt(tokens, 0);

        (uint112 r0, , ) = pair.getReserves(); // r0=BANK
        // BANK transfers charge 1% burn, so the pair receives 99% of `tokens`
        BANK.transfer(address(pair), tokens);
        uint256 received = BANK.balanceOf(address(pair)) - uint256(r0);
        (uint112 r0b, uint112 r1b, ) = pair.getReserves();
        uint256 dx = received * 997 / 1000;
        uint256 out = (uint256(r1b) * dx) / (uint256(r0b) + dx);
        pair.swap(0, out - 1, ATTACKER, "");
        vm.stopPrank();

        uint256 got = WFLR.balanceOf(ATTACKER);
        _dump("dex_arb_spent_wflr", spend);
        _dump("dex_arb_out_wflr", got);
        emit log_named_decimal_uint("WFLR in", spend, 18);
        emit log_named_decimal_uint("WFLR out of pair", got, 18);
        if (got > spend) {
            emit log_named_decimal_uint("arb profit WFLR", got - spend, 18);
        }
        // materiality bound: profit must stay far below any headline number
        assertLt(got, spend + 200e18); // < 200 WFLR (~$1.40) even if positive
    }

    /// Same route but with self-referral (2.4% rebate): the only variant that turns
    /// positive — fork-measured ≈ +$1.8 at the optimum size, one-time, DEX-LP-funded.
    function test_29_eu_self_referral_dex_arb_small() public {
        IUniswapV2Pair pair = IUniswapV2Pair(0x5F29C8d049e47DD180c2B83E3560E8e271110335);
        uint256 spend = 20_000 ether;

        vm.deal(ATTACKER, spend);
        vm.startPrank(ATTACKER);
        WFLR.deposit{value: spend}();
        WFLR.approve(address(BANK), type(uint256).max);
        BANK.buy(spend, ATTACKER); // self-referral
        BANK.withdraw();           // claim the 2.4% referral rebate in WFLR

        uint256 tokens = BANK.balanceOf(ATTACKER);
        (uint112 r0, , ) = pair.getReserves();
        BANK.transfer(address(pair), tokens); // 1% transfer burn
        uint256 received = BANK.balanceOf(address(pair)) - uint256(r0);
        (uint112 r0b, uint112 r1b, ) = pair.getReserves();
        uint256 dx = received * 997 / 1000;
        uint256 out = (uint256(r1b) * dx) / (uint256(r0b) + dx);
        pair.swap(0, out - 1, ATTACKER, "");
        vm.stopPrank();

        uint256 got = WFLR.balanceOf(ATTACKER);
        _dump("selfref_arb_spent_wflr", spend);
        _dump("selfref_arb_out_wflr", got);
        emit log_named_decimal_uint("self-referral arb out WFLR", got, 18);
        assertLt(got, spend + 1_000e18); // strictly < $7 even in the best case
    }
}
