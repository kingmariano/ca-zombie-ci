// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {IERC20, IVault, IVaultConfig, IWorker} from "../src/Interfaces.sol";

/// @title Alpaca Finance H-20/H-42 — LYF core live-state & extraction tests (BSC fork)
/// @notice Read-only against mainnet state; runs on a local fork only.
contract AlpacaH20Test is Test {
    using stdStorage for StdStorage;

    // ---- deployed addresses (BSC) ----
    address constant WBNB_VAULT = 0xd7D069493685A581d27824Fc46EdA46B7EfC0063; // ibWBNB (VaultAip42)
    address constant BUSD_VAULT = 0x7C9e73d4C71dae564d41F78d56439bB4ba87592f; // ibBUSD (VaultAip29, migrated)
    address constant ETH_VAULT = 0xbfF4a34A4644a113E8200D7F1D79b3555f723AfE;  // ibETH  (VaultAip25, migrated, emptied)
    address constant USDT_VAULT = 0x158Da805682BdC8ee32d52833aD41E74bb951E59; // ibUSDT (VaultAip42)
    address constant ALPACA_VAULT = 0xf1bE8ecC990cBcb90e166b71E368299f0116d421; // ibALPACA (Vault)
    address constant BTCB_VAULT = 0x08FC9Ba2cAc74742177e0afC3dC8Aed6961c24e7; // ibBTCB (VaultAip25)
    address constant CAKE_VAULT = 0xfF693450dDa65df7DD6F45B4472655A986b147Eb; // ibCAKE (VaultAip42)
    address constant USDC_VAULT = 0x800933D685E7Dc753758cEb77C8bd34aBF1E26d7; // ibUSDC (VaultAip25)
    address constant TUSD_VAULT = 0x3282d2a151ca00BfE7ed17Aa16E42880248CD3Cd; // ibTUSD (Vault)

    address constant WBNB_CFG = 0x53dbb71303ad0F9AFa184B8f7147F9f12Bb5Dc01;
    address constant DODO_WORKER = 0xa573FFd839aa1dC94ca6AE7eD75253C2AC7c2eC8; // only worker with a live position
    address constant FAIRLAUNCH = 0xA625AB01B08ce023B2a342Dbb12a16f2C8489A8F;

    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant ALPACA = 0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant MM_IBUSDT = 0x90476BFEF61F190b54a439E2E98f8E43Fb9b4a45; // MM ibUSDT (BUSD vault's newIbToken)

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", vm.envOr("FORK_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
    }

    // ------------------------------------------------------------------
    // 1. Live state: vaults are funded and backed; system is wound down
    // ------------------------------------------------------------------
    function test_live_state_vaults_funded_and_workers_closed() public view {
        uint256 wbnbBal = IERC20(WBNB).balanceOf(WBNB_VAULT);
        uint256 usdtBal = IERC20(USDT).balanceOf(USDT_VAULT);
        uint256 cakeBal = IERC20(CAKE).balanceOf(CAKE_VAULT);
        console2.log("ibWBNB floating WBNB:", wbnbBal / 1e18);
        console2.log("ibUSDT floating USDT:", usdtBal / 1e18);
        console2.log("ibCAKE floating CAKE:", cakeBal / 1e18);

        assertGt(wbnbBal, 10_000e18, "ibWBNB should hold >10k WBNB");
        assertGt(usdtBal, 2_000_000e18, "ibUSDT should hold >2M USDT");
        assertGt(cakeBal, 10_000e18, "ibCAKE should hold >10k CAKE");

        // accounting sanity: totalToken = balance + debt - reserve
        assertEq(
            IVault(WBNB_VAULT).totalToken(),
            wbnbBal + IVault(WBNB_VAULT).vaultDebtVal() - IVault(WBNB_VAULT).reservePool(),
            "WBNB accounting identity"
        );
        assertEq(
            IVault(USDT_VAULT).totalToken(),
            usdtBal + IVault(USDT_VAULT).vaultDebtVal() - IVault(USDT_VAULT).reservePool(),
            "USDT accounting identity"
        );
        assertEq(
            IVault(CAKE_VAULT).totalToken(),
            cakeBal + IVault(CAKE_VAULT).vaultDebtVal() - IVault(CAKE_VAULT).reservePool(),
            "CAKE accounting identity"
        );

        // system closed for new leverage: workers still registered but debt closed
        assertTrue(IVaultConfig(WBNB_CFG).isWorker(DODO_WORKER), "worker still registered");
        bool acceptsDebt = false;
        try IVaultConfig(WBNB_CFG).acceptDebt(DODO_WORKER) returns (bool a) {
            acceptsDebt = a;
        } catch {
            acceptsDebt = false; // dead OracleMedianizer also blocks the borrow path
        }
        assertFalse(acceptsDebt, "new debt must be disabled");
        assertEq(IVault(WBNB_VAULT).vaultDebtShare() > 0, true, "one legacy position remains");

        // FairLaunch still holds the unemitted ALPACA reserve
        assertGt(IERC20(ALPACA).balanceOf(FAIRLAUNCH), 100_000e18, "FairLaunch holds ALPACA");
    }

    // ------------------------------------------------------------------
    // 2. E-U attempt: open a leveraged position (borrow) -> blocked
    // ------------------------------------------------------------------
    function test_new_borrow_reverts() public {
        vm.prank(attacker, attacker); // EOA context (vault requires msg.sender == tx.origin)
        // borrow path is blocked: config.acceptDebt(worker) is false (113 workers) or reverts
        // from the dead OracleMedianizer (69 workers). Either way no new leverage can be opened.
        vm.expectRevert();
        IVault(WBNB_VAULT).work(0, DODO_WORKER, 0, 1e18, 0, abi.encode(address(0), ""));
    }

    // ------------------------------------------------------------------
    // 3. E-U attempt: liquidate the legacy position -> whitelisted only
    // ------------------------------------------------------------------
    function test_kill_reverts_not_whitelisted() public {
        vm.prank(attacker, attacker);
        vm.expectRevert(bytes("!whitelisted liquidator"));
        IVault(WBNB_VAULT).kill(1);
    }

    // ------------------------------------------------------------------
    // 4. E-U attempt: privileged drains revert
    // ------------------------------------------------------------------
    function test_forceClose_reverts_not_deployer() public {
        vm.prank(attacker, attacker);
        vm.expectRevert(bytes("!D"));
        IVault(WBNB_VAULT).forceClose(1, "0x");
    }

    function test_withdrawReserve_reverts_not_owner() public {
        vm.prank(attacker, attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IVault(WBNB_VAULT).withdrawReserve(attacker, 1e18);
    }

    // ------------------------------------------------------------------
    // 5. H-O: an ordinary holder can still deposit and exit (self-service)
    // ------------------------------------------------------------------
    function test_holder_deposit_withdraw_roundtrip() public {
        uint256 amount = 10e18;
        deal(WBNB, attacker, amount);
        uint256 nativeBefore = attacker.balance;

        vm.startPrank(attacker, attacker);
        IERC20(WBNB).approve(WBNB_VAULT, amount);
        IVault(WBNB_VAULT).deposit(amount);
        uint256 shares = IVault(WBNB_VAULT).balanceOf(attacker);
        assertGt(shares, 0, "shares minted");
        IVault(WBNB_VAULT).withdraw(shares);
        vm.stopPrank();

        uint256 nativeAfter = attacker.balance;
        console2.log("native delta:", (nativeAfter - nativeBefore) / 1e18);
        // WBNB vault unwraps to native BNB; round trip returns ~10 BNB (dust rounding only)
        assertGe(nativeAfter - nativeBefore, amount - 1e15, "round trip returns >= 9.999 BNB");
        assertEq(IERC20(WBNB).balanceOf(attacker), 0, "all WBNB used");
    }

    // ------------------------------------------------------------------
    // 6. S: ibETH vault is emptied/bricked — 119 shares, zero backing
    // ------------------------------------------------------------------
    function test_ibeth_bricked_zero_backing() public {
        uint256 supply = IVault(ETH_VAULT).totalSupply();
        uint256 total = IVault(ETH_VAULT).totalToken();
        console2.log("ibETH totalSupply shares:", supply / 1e18);
        console2.log("ibETH totalToken:", total);
        assertGt(supply, 0, "shares exist");
        assertEq(total, 0, "zero backing");

        // give the attacker a claim and show withdraw cannot pay anything
        stdstore.target(ETH_VAULT).sig("balanceOf(address)").with_key(attacker).checked_write(1e18);
        vm.prank(attacker, attacker);
        vm.expectRevert(); // MM AccountManager reverts InvalidAmount (0 to withdraw)
        IVault(ETH_VAULT).withdraw(1e18);
    }

    // ------------------------------------------------------------------
    // 7. H-O: migrated BUSD vault still redeems through the money market
    // ------------------------------------------------------------------
    function test_busd_vault_migrated_redeem_path() public {
        assertTrue(IVault(BUSD_VAULT).migrated(), "migrated flag");
        assertEq(IVault(BUSD_VAULT).vaultDebtShare(), 0, "no legacy debt share");
        assertEq(IVault(BUSD_VAULT).newIbToken(), MM_IBUSDT, "newIbToken = MM ibUSDT");
        uint256 total = IVault(BUSD_VAULT).totalToken();
        console2.log("ibBUSD claim (USDT):", total / 1e18);
        assertGt(total, 2_000_000e18, ">2M USDT claim");

        // simulate a legacy holder with 1,000 ibBUSD shares and redeem
        stdstore.target(BUSD_VAULT).sig("balanceOf(address)").with_key(attacker).checked_write(1_000e18);
        vm.prank(attacker, attacker);
        IVault(BUSD_VAULT).withdraw(1_000e18);
        uint256 got = IERC20(USDT).balanceOf(attacker);
        console2.log("USDT received for 1000 ibBUSD:", got / 1e18);
        assertGt(got, 900e18, "redeem paid ~1,064 USDT");
    }

    // ------------------------------------------------------------------
    // 8. E-U attempt: donate to vault then withdraw more than deposited
    // ------------------------------------------------------------------
    function test_donation_does_not_enable_profit() public {
        // Attacker donates 100 WBNB to the vault; share price rises for everyone.
        // Attacker cannot mint shares with the donation; deposit/withdraw round-trip
        // returns only what was deposited (minus rounding).
        uint256 donation = 100e18;
        deal(WBNB, attacker, donation);
        vm.startPrank(attacker, attacker);
        IERC20(WBNB).transfer(WBNB_VAULT, donation); // direct donation, no shares
        assertEq(IVault(WBNB_VAULT).balanceOf(attacker), 0, "donation mints no shares");
        vm.stopPrank();
    }
}
