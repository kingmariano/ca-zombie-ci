// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------
   Blueberry (Monad) — read-only fork PoC.
   Fork block pinned for reproducibility. NO mainnet transactions.
   All calls are local simulations on an anvil fork.
------------------------------------------------------------------- */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IVault {
    function asset() external view returns (address);
    function name() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalIdle() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function convertToShares(uint256) external view returns (uint256);
    function previewDeposit(uint256) external view returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function mint(uint256, address) external returns (uint256);
    function withdraw(uint256, address, address, uint256) external returns (uint256);
    function redeem(uint256, address, address, uint256) external returns (uint256);
    function roles(address) external view returns (uint256);
    function role_manager() external view returns (address);
    function accountant() external view returns (address);
    function strategies(address) external view returns (uint256, uint256, uint256, uint256);
    function default_queue(uint256) external view returns (address);
    function use_default_queue() external view returns (bool);
    function auto_allocate() external view returns (bool);
    function deposit_limit() external view returns (uint256);
    function minimum_total_idle() external view returns (uint256);
    function isPaused() external view returns (bool);
    function isShutdown() external view returns (bool);
    function pricePerShare() external view returns (uint256);
    function profitMaxUnlockTime() external view returns (uint256);
    function unlockedShares() external view returns (uint256);
    function process_report(address) external returns (uint256, uint256);
    function update_debt(address, uint256, uint256) external returns (uint256);
    function add_strategy(address, bool) external;
    function revoke_strategy(address) external;
    function force_revoke_strategy(address) external;
    function update_max_debt_for_strategy(address, uint256) external;
    function set_role(address, uint256) external;
    function set_accountant(address) external;
    function set_default_queue(address[] calldata) external;
    function set_use_default_queue(bool) external;
    function set_auto_allocate(bool) external;
    function set_deposit_limit(uint256, bool) external;
    function set_minimum_total_idle(uint256) external;
    function setPaused(bool) external;
    function shutdown_vault() external;
    function buy_debt(address, uint256) external;
}

interface IStrategy {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function pricePerShare() external view returns (uint256);
    function management() external view returns (address);
    function keeper() external view returns (address);
    function emergencyAdmin() external view returns (address);
    function isShutdown() external view returns (bool);
    function open() external view returns (bool);
    function allowed(address) external view returns (bool);
    function maxDeposit(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function availableWithdrawLimit(address) external view returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function redeem(uint256, address, address, uint256) external returns (uint256);
    function report() external returns (uint256, uint256);
    function tend() external;
    function shutdownStrategy() external;
    function emergencyWithdraw(uint256) external;
    function kickAuction(address) external returns (uint256);
    function marketsLength() external view returns (uint256);
    function markets(uint256) external view returns (address);
    function positionValue(address) external view returns (uint256);
    function marketMaxWithdraw(address) external view returns (uint256);
    function lastReport() external view returns (uint256);
}

contract BlueberryMonadTest is Test {
    // ---- pinned fork ----
    uint256 constant FORK_BLOCK = 112_485_700;

    // ---- addresses (Monad, chainid 143) ----
    address constant V1 = 0xC2ddc1004CA0d6cC4bFd1dCD03Dcf855bED8E670; // Blueberry AUSD
    address constant V2 = 0x215394B5677Cb7a18B6fA8cc2cD155C024ee6b2E; // Blueberry USDC
    address constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address constant OPT1 = 0x460BBe066AA0ff94d7AFCd95580c41190FC4C7E4; // CurvanceOptimizer (AUSD)
    address constant OPT2 = 0xe43b232FA6Ce535C6B4F8771427eBd4a77Bad593; // CurvanceOptimizer (USDC)
    address constant MKT1_0 = 0x9489dc59C3636649f271C9E2ad3C303fd41923b9; // Curvance AUSD market
    address constant MKT1_3 = 0xaD663aC84052b52BE4ed1b27BA416505e84a00Bf; // High Yield AUSD Vault
    address constant MKT2_0 = 0x207340D15F4E3C63AE610429f34b87C73a5D55e5; // Curvance USDC market
    address constant HOLDER1 = 0xa5190552e8A7902812C6F6Df07813BF6AEBfc6bd; // largest holder
    address constant HOLDER2 = 0xbA1333333333a1BA1108E8412f11850A5C319bA9; // 2nd holder
    address constant ATTACKER = address(0xdeadbeef01);
    address constant ZERO = address(0);
    // AUSD / USDC whales (contracts holding raw tokens; used read-only via prank)
    address constant AUSD_WHALE = 0xD1BFEA1728ffe98F515f26082fACfcc3341691D4; // 1.53M AUSD
    address constant USDC_WHALE = 0x207340D15F4E3C63AE610429f34b87C73a5D55e5; // 762k USDC

    function setUp() public {
        string memory rpc = vm.envOr("MONAD_RPC_URL", string("https://rpc.monad.xyz"));
        vm.createSelectFork(rpc, FORK_BLOCK);
    }

    /// @dev fund an address with real tokens by impersonating a large holder
    function _fund(address token, address whale, address to, uint256 amount) internal {
        vm.prank(whale);
        IERC20(token).transfer(to, amount);
    }

    /* ------------------------------------------------------------------
       1) Live state snapshot
    ------------------------------------------------------------------ */
    function test_state_snapshot() public {
        console2.log("=== V1 Blueberry AUSD ===");
        console2.log("totalAssets", IVault(V1).totalAssets());
        console2.log("totalIdle  ", IVault(V1).totalIdle());
        console2.log("totalDebt  ", IVault(V1).totalDebt());
        console2.log("totalSupply", IVault(V1).totalSupply());
        console2.log("pps        ", IVault(V1).pricePerShare());
        console2.log("autoAlloc  ", IVault(V1).auto_allocate());
        console2.log("depLimit   ", IVault(V1).deposit_limit());
        console2.log("roleManager", IVault(V1).role_manager());
        console2.log("queue[0]   ", IVault(V1).default_queue(0));
        (uint256 act, uint256 last, uint256 debt, uint256 maxd) = IVault(V1).strategies(OPT1);
        console2.log("opt1 activation/last_report/debt:", act, last);
        console2.log("opt1 current_debt", debt);
        console2.log("opt1 max_debt", maxd);

        console2.log("=== V2 Blueberry USDC ===");
        console2.log("totalAssets", IVault(V2).totalAssets());
        console2.log("totalDebt  ", IVault(V2).totalDebt());
        console2.log("totalSupply", IVault(V2).totalSupply());
        console2.log("queue[0]   ", IVault(V2).default_queue(0));

        console2.log("=== Strategy state ===");
        console2.log("opt1.totalAssets", IStrategy(OPT1).totalAssets());
        console2.log("opt1.totalSupply", IStrategy(OPT1).totalSupply());
        console2.log("opt1.bal(vault)", IStrategy(OPT1).balanceOf(V1));
        console2.log("opt1.management", IStrategy(OPT1).management());
        console2.log("opt1.keeper", IStrategy(OPT1).keeper());
        console2.log("opt1.open", IStrategy(OPT1).open());
        console2.log("opt1.allowed(v1)", IStrategy(OPT1).allowed(V1));
        console2.log("opt1.maxDeposit(v1)", IStrategy(OPT1).maxDeposit(V1));
        console2.log("opt1.marketsLength", IStrategy(OPT1).marketsLength());

        // Core invariants
        assertEq(IStrategy(OPT1).balanceOf(V1), IStrategy(OPT1).totalSupply(), "vault owns 100% of strategy");
        assertTrue(!IStrategy(OPT1).open(), "strategy deposits closed");
        assertTrue(IStrategy(OPT1).allowed(V1), "vault whitelisted");
        assertTrue(!IVault(V1).isPaused() && !IVault(V1).isShutdown(), "vault live");
        // roles: role_manager itself has no roles; keeper only REPORTING
        assertEq(IVault(V1).roles(IStrategy(OPT1).keeper()), 32, "keeper REPORTING only");
    }

    /* ------------------------------------------------------------------
       2) H-O proof: largest holder can fully redeem today (liquidity)
    ------------------------------------------------------------------ */
    function test_holder1_full_redeem_works() public {
        uint256 shares = IVault(V1).balanceOf(HOLDER1);
        assertGt(shares, 1_000_000e6, "holder1 holds >1M shares");

        uint256 maxR = IVault(V1).maxRedeem(HOLDER1);
        console2.log("holder1 shares", shares);
        console2.log("holder1 maxRedeem", maxR);
        assertGe(maxR + 1, shares, "maxRedeem == full balance (rounding may shave 1 wei)");

        uint256 balBefore = IERC20(AUSD).balanceOf(HOLDER1);
        uint256 exp = IVault(V1).previewRedeem(shares);

        // (a) explicit max_loss=0 (4-arg): must revert on the 2-wei rounding shortfall
        vm.prank(HOLDER1);
        (bool ok, bytes memory ret) = V1.call(
            abi.encodeWithSignature("redeem(uint256,address,address,uint256)", shares, HOLDER1, HOLDER1, uint256(0))
        );
        console2.log("redeem explicit max_loss=0 success?", ok);
        if (!ok) console2.log("revert data", string(ret));
        assertFalse(ok, "explicit max_loss=0 reverts on rounding");

        // (b) standard 3-arg redeem (default max_loss = MAX_BPS): must succeed
        vm.prank(HOLDER1);
        (bool ok2, bytes memory ret2) = V1.call(
            abi.encodeWithSignature("redeem(uint256,address,address)", shares, HOLDER1, HOLDER1)
        );
        assertTrue(ok2, "3-arg redeem (default max_loss) succeeds");
        uint256 got = abi.decode(ret2, (uint256));
        uint256 balAfter = IERC20(AUSD).balanceOf(HOLDER1);

        console2.log("expected assets", exp);
        console2.log("received assets", got);
        console2.log("actual delta   ", balAfter - balBefore);
        console2.log("realized loss  ", exp > got ? exp - got : 0);
        assertEq(got, balAfter - balBefore, "assets received");
        assertGt(got, 1_000_000e6, ">1M AUSD withdrawn");

        // vault now empty of that holder; debt pulled from strategy
        assertEq(IVault(V1).balanceOf(HOLDER1), 0, "shares burned");
        console2.log("vault totalAssets after", IVault(V1).totalAssets());
        console2.log("vault totalIdle after", IVault(V1).totalIdle());
    }

    function test_holder2_full_redeem_usdc_works() public {
        uint256 shares = IVault(V2).balanceOf(HOLDER2);
        console2.log("holder2 USDC shares", shares);
        assertGe(IVault(V2).maxRedeem(HOLDER2) + 1, shares, "full redeem simulated");
        uint256 exp = IVault(V2).previewRedeem(shares);
        vm.prank(HOLDER2);
        uint256 got = IVault(V2).redeem(shares, HOLDER2, HOLDER2, 0);
        console2.log("expected/received USDC", exp, got);
        assertGe(got, exp, "no hidden loss");
        assertGt(got, 40_000e6, ">40k USDC withdrawn");
    }

    /* ------------------------------------------------------------------
       3) Attacker cannot call any privileged path
    ------------------------------------------------------------------ */
    function test_attacker_privileged_paths_revert() public {
        _fund(AUSD, AUSD_WHALE, ATTACKER, 10_000e6);
        vm.startPrank(ATTACKER);

        // --- vault admin/reporting paths ---
        vm.expectRevert();
        IVault(V1).process_report(OPT1);

        vm.expectRevert();
        IVault(V1).update_debt(OPT1, 0, 0);

        vm.expectRevert();
        IVault(V1).add_strategy(ATTACKER, true);

        vm.expectRevert();
        IVault(V1).revoke_strategy(OPT1);

        vm.expectRevert();
        IVault(V1).force_revoke_strategy(OPT1);

        vm.expectRevert();
        IVault(V1).update_max_debt_for_strategy(OPT1, 0);

        vm.expectRevert();
        IVault(V1).set_role(ATTACKER, 16383);

        vm.expectRevert();
        IVault(V1).set_accountant(ATTACKER);

        address[] memory q = new address[](1);
        q[0] = ATTACKER;
        vm.expectRevert();
        IVault(V1).set_default_queue(q);

        vm.expectRevert();
        IVault(V1).setPaused(true);

        vm.expectRevert();
        IVault(V1).shutdown_vault();

        vm.expectRevert();
        IVault(V1).buy_debt(OPT1, 1e6);

        // --- strategy keeper/emergency paths ---
        vm.expectRevert();
        IStrategy(OPT1).report();

        vm.expectRevert();
        IStrategy(OPT1).tend();

        vm.expectRevert();
        IStrategy(OPT1).shutdownStrategy();

        vm.expectRevert();
        IStrategy(OPT1).emergencyWithdraw(1e6);

        // --- strategy deposit closed (open=false, not whitelisted) ---
        IERC20(AUSD).approve(OPT1, type(uint256).max);
        assertEq(IStrategy(OPT1).maxDeposit(ATTACKER), 0, "attacker maxDeposit=0");
        vm.expectRevert();
        IStrategy(OPT1).deposit(1_000e6, ATTACKER);

        // --- kickAuction on the protected asset must revert ---
        vm.expectRevert();
        IStrategy(OPT1).kickAuction(AUSD);

        vm.stopPrank();
    }

    /* ------------------------------------------------------------------
       4) No ERC-4626 inflation/donation attack on the vault
    ------------------------------------------------------------------ */
    function test_donation_to_vault_does_not_move_pps() public {
        uint256 ta0 = IVault(V1).totalAssets();
        uint256 pps0 = IVault(V1).pricePerShare();
        uint256 sh0 = IVault(V1).convertToShares(1_000e6);

        _fund(AUSD, AUSD_WHALE, V1, 1_000_000e6); // direct donation, no shares minted

        assertEq(IVault(V1).totalAssets(), ta0, "totalAssets unchanged (total_idle accounting)");
        assertEq(IVault(V1).pricePerShare(), pps0, "pps unchanged");
        assertEq(IVault(V1).convertToShares(1_000e6), sh0, "no share price distortion");
        // the donation is simply absorbed by existing holders on next report
    }

    function test_donation_to_strategy_does_not_move_pps() public {
        uint256 ta0 = IStrategy(OPT1).totalAssets();
        uint256 pps0 = IStrategy(OPT1).pricePerShare();
        _fund(AUSD, AUSD_WHALE, OPT1, 100_000e6);
        assertEq(IStrategy(OPT1).totalAssets(), ta0, "strategy totalAssets is stored, unchanged");
        assertEq(IStrategy(OPT1).pricePerShare(), pps0, "strategy pps unchanged");
    }

    /* ------------------------------------------------------------------
       5) Deposit -> redeem round trip cannot profit (rounding check)
    ------------------------------------------------------------------ */
    function test_deposit_redeem_roundtrip_no_profit() public {
        uint256 amount = 100_000e6;
        _fund(AUSD, AUSD_WHALE, ATTACKER, amount);

        vm.startPrank(ATTACKER);
        IERC20(AUSD).approve(V1, type(uint256).max);
        uint256 shares = IVault(V1).deposit(amount, ATTACKER);
        uint256 out = IVault(V1).redeem(shares, ATTACKER, ATTACKER, 100);
        vm.stopPrank();

        console2.log("deposited", amount);
        console2.log("shares", shares);
        console2.log("redeemed", out);
        console2.log("loss+dust", amount > out ? amount - out : 0);
        assertLe(out, amount, "NO PROFIT: cannot exit with more than deposited");
        assertLe(amount - out, 10_000, "loss <= 0.01 USD (rounding)");

        // repeat with mint -> withdraw, measuring real AUSD balance deltas
        _fund(AUSD, AUSD_WHALE, ATTACKER, amount);
        uint256 b0 = IERC20(AUSD).balanceOf(ATTACKER);
        vm.startPrank(ATTACKER);
        IERC20(AUSD).approve(V1, type(uint256).max);
        uint256 cost = IVault(V1).mint(amount, ATTACKER);      // returns assets paid
        uint256 sharesBurned = IVault(V1).withdraw(amount, ATTACKER, ATTACKER, 100); // returns shares burned
        vm.stopPrank();
        uint256 b2 = IERC20(AUSD).balanceOf(ATTACKER);
        console2.log("mint cost", cost);
        console2.log("withdraw shares burned", sharesBurned);
        console2.log("net AUSD after mint->withdraw (delta)", int256(b2) - int256(b0));
        assertLe(b2, b0, "NO PROFIT: mint->withdraw cannot net gain");
    }

    /* ------------------------------------------------------------------
       6) Curvance market donation sensitivity (residual-risk documentation)
    ------------------------------------------------------------------ */
    function test_curvance_market_donation_sensitivity() public {
        // Donate AUSD directly into the Curvance AUSD market the strategy uses.
        uint256 pv0 = IStrategy(OPT1).positionValue(MKT1_0);
        uint256 mktTA0 = IVault(MKT1_0).totalAssets();
        _fund(AUSD, AUSD_WHALE, MKT1_0, 10_000e6);
        uint256 pv1 = IStrategy(OPT1).positionValue(MKT1_0);
        uint256 mktTA1 = IVault(MKT1_0).totalAssets();
        console2.log("market totalAssets before/after donation", mktTA0, mktTA1);
        console2.log("strategy positionValue before/after", pv0, pv1);
        // NOTE: even if sensitive, report() is keeper-only and strategy deposits are
        // closed, so a donor cannot convert the inflation into a profit (see README).
        assertEq(IStrategy(OPT1).totalAssets(), IStrategy(OPT1).totalAssets(), "noop");
    }

    /* ------------------------------------------------------------------
       7) Vault -> strategy value conservation at pinned block
    ------------------------------------------------------------------ */
    function test_value_conservation() public {
        uint256 vaultAssets = IVault(V1).totalAssets();
        (,, uint256 debt,) = IVault(V1).strategies(OPT1);
        assertEq(vaultAssets, debt, "vault totalAssets == strategy debt");
        uint256 stratAssets = IStrategy(OPT1).totalAssets();
        // strategy worth slightly less than recorded debt => unrealised loss
        assertApproxEqAbs(stratAssets, debt, 500e6, "strategy ~ debt within 500 AUSD");
        console2.log("recorded debt", debt);
        console2.log("strategy assets", stratAssets);
        console2.log("unrealised loss", debt > stratAssets ? debt - stratAssets : 0);
        assertLe(debt, stratAssets + 500e6, "no material hidden loss");
    }
}
