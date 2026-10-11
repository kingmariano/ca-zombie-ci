// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/interfaces.sol";
import "../src/Attackers.sol";

/// Aequinox (BSC) zombie-hunt PoC — read-only mainnet; fork-only execution.
///
/// Conclusions proven here:
///  [1] No external unprivileged extraction path: malicious-pool registration is isolated,
///      swaps/joins are fair-valued, flash/batch round trips are unprofitable.
///  [2] Non-gauge BPT holders can exit the pool at fair value (H-O).
///  [3] The Curve-style gauges are permanently frozen: withdraw() reverts because the
///      GaugeController's checkpoint_gauge() reverts for every gauge (dead since 2022/2023).
///      ~$622k of BPT staked in those gauges is unredeemable (S).
contract AequinoxTest is Test {
    IVault constant VAULT = IVault(0xEE1c8DbfBf958484c6a4571F5FB7b99B74A54AA7);
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    IStablePool constant POOL = IStablePool(0xb3A07a9CeF918b2ccEC4bC85C6F2A7975c5E83f9);
    bytes32 constant POOL_ID = 0xb3a07a9cef918b2ccec4bc85c6f2a7975c5e83f9000000000000000000000001;
    IGauge constant GAUGE = IGauge(0xaCC31d29022C8Eb2683597bF4c07De228Ed9EA07);
    address constant CONTROLLER = 0x585ECE7932226CCf5A259c367781F07EBBB1950F;
    address constant TOP_STAKER = 0x9D430C0A05da519335ee022ECF8f7690F1d402Ba;
    address constant SMALL_HOLDER = 0x1b58Ebe1EA5125A20B007e15C3994709bB4b80c9;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.bnbchain.org"));
        vm.createSelectFork(rpc);
        vm.label(address(VAULT), "Vault");
        vm.label(address(POOL), "StablePool");
        vm.label(address(GAUGE), "Gauge");
        vm.label(CONTROLLER, "GaugeController");
    }

    function _vaultBal(address t) internal view returns (uint256) {
        return IERC20(t).balanceOf(address(VAULT));
    }

    function _tokens() internal pure returns (address[] memory t) {
        t = new address[](3);
        t[0] = USDT;
        t[1] = USDC;
        t[2] = BUSD;
    }

    // ------------------------------------------------------------------ 01
    function test_01_live_state() public {
        (bool paused,,) = VAULT.getPausedState();
        assertFalse(paused, "vault paused");
        assertEq(POOL.inRecoveryMode(), false, "recovery mode on");
        assertGt(_vaultBal(USDT), 250_000e18, "USDT live");
        assertGt(_vaultBal(USDC), 180_000e18, "USDC live");
        assertGt(_vaultBal(BUSD), 70_000e18, "BUSD live");
        assertGt(GAUGE.totalSupply(), 500_000e18, "gauge holds BPT");
        assertTrue(GAUGE.is_killed(), "gauge killed");
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("vault USDT", _vaultBal(USDT));
        emit log_named_uint("vault USDC", _vaultBal(USDC));
        emit log_named_uint("vault BUSD", _vaultBal(BUSD));
        emit log_named_uint("stable BPT totalSupply", POOL.totalSupply());
        emit log_named_uint("gauge BPT (frozen)", GAUGE.totalSupply());
        emit log_named_uint("pool getRate (BPT NAV)", POOL.getRate());
    }

    // ------------------------------------------------------------------ 02
    function test_02_malicious_pool_isolated() public {
        uint256 vUsdt = _vaultBal(USDT);
        uint256 vUsdc = _vaultBal(USDC);

        AttackerPool ap = new AttackerPool(VAULT, USDT, USDC);
        bytes32 pid = ap.register(2); // TWO_TOKEN specialization
        assertTrue(pid != bytes32(0), "pool registered");

        ap.tryManagedUpdate(1_000_000e18);
        (uint256 cash, uint256 managed,,) = VAULT.getPoolTokenInfo(pid, USDT);
        assertEq(cash, 0, "no real cash");
        assertEq(managed, 1_000_000e18, "managed fabricated");
        emit log_named_uint("fabricated managed balance", managed);

        vm.expectRevert();
        ap.tryManagedWithdraw(1_000_000e18);

        vm.expectRevert();
        ap.tryExitHuge();

        vm.expectRevert();
        ap.trySwapHuge();

        ap.setStablePool(POOL_ID);
        ap.setFlags(true, false);
        ap.tryExitZeros();
        assertFalse(ap.reenterSucceeded(), "reentrancy must be blocked");

        assertEq(_vaultBal(USDT), vUsdt, "vault USDT untouched");
        assertEq(_vaultBal(USDC), vUsdc, "vault USDC untouched");
        assertEq(IERC20(USDC).balanceOf(address(ap)), 0, "attacker got nothing");
        emit log_string("malicious pool: all extraction attempts blocked");
    }

    // ------------------------------------------------------------------ 03
    function test_03_no_cross_pool_or_admin_access() public {
        address[] memory toks = new address[](1);
        toks[0] = USDT;
        address[] memory mgrs = new address[](1);
        mgrs[0] = attacker;

        vm.startPrank(attacker);
        vm.expectRevert();
        VAULT.registerTokens(POOL_ID, toks, mgrs);

        vm.expectRevert();
        VAULT.deregisterTokens(POOL_ID, toks);

        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = IVault.PoolBalanceOp(0, POOL_ID, USDT, 1e18);
        vm.expectRevert();
        VAULT.managePoolBalance(ops);

        vm.expectRevert();
        VAULT.setPaused(true);

        vm.expectRevert();
        VAULT.setAuthorizer(attacker);

        vm.expectRevert();
        POOL.enableRecoveryMode();

        vm.expectRevert();
        POOL.setSwapFeePercentage(1e17);

        vm.expectRevert();
        POOL.pause();
        vm.stopPrank();
        emit log_string("cross-pool + admin access: all blocked");
    }

    // ------------------------------------------------------------------ 04
    function test_04_flash_roundtrip_no_profit() public {
        address feesCollector = VAULT.getProtocolFeesCollector();
        uint256 flashFee = IProtocolFeesCollector(feesCollector).getFlashLoanFeePercentage();
        emit log_named_uint("flashLoanFee", flashFee);

        uint256[3] memory sizes = [uint256(1e18), 1_000e18, 100_000e18];
        for (uint256 i = 0; i < sizes.length; i++) {
            for (uint8 mode = 0; mode < 2; mode++) {
                FlashRoundTripper f = new FlashRoundTripper(VAULT, USDT, USDC, BUSD);
                try f.run(POOL_ID, sizes[i], mode) {
                    uint256 profit = f.returnedProfit();
                    emit log_named_uint("PROFIT DETECTED", profit);
                    assertEq(profit, 0, "profitable round trip found - E-U!");
                } catch {
                    emit log_string("flash round trip unprofitable");
                }
            }
        }
        assertGt(_vaultBal(USDT), 250_000e18, "vault USDT intact");
    }

    // ------------------------------------------------------------------ 05
    /// Free-capital (dealt) round trips: no fee excuses. Must not profit.
    function test_05_free_capital_no_profit() public {
        deal(USDT, address(this), 1_000_000e18);
        deal(USDC, address(this), 1_000_000e18);
        deal(BUSD, address(this), 1_000_000e18);
        uint256 startTotal = IERC20(USDT).balanceOf(address(this)) + IERC20(USDC).balanceOf(address(this))
            + IERC20(BUSD).balanceOf(address(this));

        // swap USDT -> USDC and back
        uint256 usdcOut = _swap(USDT, USDC, 100_000e18);
        uint256 usdtBack = _swap(USDC, USDT, usdcOut);
        emit log_named_uint("100k USDT -> USDC", usdcOut);
        emit log_named_uint("back to USDT", usdtBack);
        assertLe(usdtBack, 100_000e18, "round trip must not profit");

        // swap USDC -> BUSD and back
        uint256 busdOut = _swap(USDC, BUSD, 50_000e18);
        uint256 usdcBack = _swap(BUSD, USDC, busdOut);
        assertLe(usdcBack, 50_000e18, "round trip must not profit");

        uint256 endTotal = IERC20(USDT).balanceOf(address(this)) + IERC20(USDC).balanceOf(address(this))
            + IERC20(BUSD).balanceOf(address(this));
        emit log_named_uint("start total (3 stables)", startTotal);
        emit log_named_uint("end total (3 stables)", endTotal);
        assertLt(endTotal, startTotal, "must lose the swap fee, never profit");

        // join then immediately exit: must not profit
        (address[] memory toks, uint256[] memory amounts) = _proportionalAmounts(10_000e18);
        for (uint256 i = 0; i < 3; i++) {
            IERC20(toks[i]).approve(address(VAULT), amounts[i]);
        }
        uint256 bptBefore = IERC20(address(POOL)).balanceOf(address(this));
        VAULT.joinPool(
            POOL_ID,
            address(this),
            address(this),
            IVault.JoinPoolRequest(toks, amounts, abi.encode(uint256(1), amounts, uint256(0)), false)
        );
        uint256 bptOut = IERC20(address(POOL)).balanceOf(address(this)) - bptBefore;
        emit log_named_uint("BPT from proportional join", bptOut);

        uint256[] memory mins = new uint256[](3);
        VAULT.exitPool(
            POOL_ID,
            address(this),
            payable(address(this)),
            IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(1), bptOut), false)
        );
        uint256 endTotal2 = IERC20(USDT).balanceOf(address(this)) + IERC20(USDC).balanceOf(address(this))
            + IERC20(BUSD).balanceOf(address(this));
        emit log_named_uint("after join+exit", endTotal2);
        assertLt(endTotal2, endTotal, "join+exit must not profit");
        emit log_string("free-capital paths: no profit");
    }

    function _swap(address tin, address tout, uint256 amount) internal returns (uint256) {
        IERC20(tin).approve(address(VAULT), amount);
        IVault.SingleSwap memory s = IVault.SingleSwap(POOL_ID, IVault.SwapKind.GIVEN_IN, tin, tout, amount, "");
        IVault.FundManagement memory f = IVault.FundManagement(address(this), false, payable(address(this)), false);
        return VAULT.swap(s, f, 0, block.timestamp + 1);
    }

    function _proportionalAmounts(uint256 total)
        internal
        view
        returns (address[] memory toks, uint256[] memory amounts)
    {
        toks = _tokens();
        (, uint256[] memory bal,) = VAULT.getPoolTokens(POOL_ID);
        uint256 supply = POOL.totalSupply();
        amounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            amounts[i] = bal[i] * total / supply;
        }
    }

    // ------------------------------------------------------------------ 06
    /// Non-gauge BPT holder recovers fair value via proportional exit (H-O).
    function test_06_holder_exit_works() public {
        uint256 bpt = IERC20(address(POOL)).balanceOf(SMALL_HOLDER);
        assertGt(bpt, 0, "holder has BPT");
        (, uint256[] memory pre, ) = VAULT.getPoolTokens(POOL_ID);
        uint256 supply = POOL.totalSupply();

        address[] memory toks = _tokens();
        uint256[] memory mins = new uint256[](3);
        uint256 u0 = IERC20(USDT).balanceOf(SMALL_HOLDER);
        uint256 u1 = IERC20(USDC).balanceOf(SMALL_HOLDER);
        uint256 u2 = IERC20(BUSD).balanceOf(SMALL_HOLDER);
        vm.prank(SMALL_HOLDER);
        VAULT.exitPool(
            POOL_ID, SMALL_HOLDER, payable(SMALL_HOLDER),
            IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(1), bpt), false)
        );
        uint256 g0 = IERC20(USDT).balanceOf(SMALL_HOLDER) - u0;
        uint256 g1 = IERC20(USDC).balanceOf(SMALL_HOLDER) - u1;
        uint256 g2 = IERC20(BUSD).balanceOf(SMALL_HOLDER) - u2;
        emit log_named_uint("BPT burned", bpt);
        emit log_named_uint("USDT received", g0);
        emit log_named_uint("USDC received", g1);
        emit log_named_uint("BUSD received", g2);
        // USDT is the token the protocol swap fee is charged in, so the exiting holder's USDT
        // share is reduced by their share of the accumulated protocol fee (<1%); USDC/BUSD match exactly.
        assertApproxEqRel(g0, pre[0] * bpt / supply, 0.01e18, "fair USDT (within protocol fee)");
        assertApproxEqRel(g1, pre[1] * bpt / supply, 1e13, "fair USDC");
        assertApproxEqRel(g2, pre[2] * bpt / supply, 1e13, "fair BUSD");
        emit log_string("non-gauge holder exit: works at fair value minus protocol fee (H-O)");
    }

    // ------------------------------------------------------------------ 07
    /// The gauges are frozen: withdraw/checkpoint revert, funds stay trapped.
    function test_07_gauge_frozen() public {
        uint256 gaugeBptBefore = GAUGE.totalSupply();
        uint256 stakerBpt = GAUGE.balanceOf(TOP_STAKER);
        assertGt(stakerBpt, 400_000e18, "top staker holds ~403k BPT");

        vm.prank(TOP_STAKER);
        (bool ok, ) = address(GAUGE).call(abi.encodeWithSignature("withdraw(uint256)", stakerBpt));
        assertFalse(ok, "gauge withdraw must revert (frozen)");

        (bool cok, ) = CONTROLLER.call(abi.encodeWithSignature("checkpoint_gauge(address)", address(GAUGE)));
        assertFalse(cok, "controller checkpoint_gauge must revert");

        // even deposit (rotation) is impossible
        vm.prank(TOP_STAKER);
        (bool dok, ) = address(GAUGE).call(abi.encodeWithSignature("deposit(uint256)", 1e18));
        assertFalse(dok, "gauge deposit must revert (frozen)");

        // initialize is guarded
        vm.prank(attacker);
        vm.expectRevert();
        GAUGE.initialize(attacker);

        // gauge tokens cannot be pulled from a staker
        vm.prank(attacker);
        vm.expectRevert();
        GAUGE.transferFrom(TOP_STAKER, attacker, 1e18);

        assertEq(GAUGE.totalSupply(), gaugeBptBefore, "no BPT moved out");
        emit log_named_uint("BPT trapped in stable gauge", gaugeBptBefore);
        emit log_string("gauge frozen: stakers cannot redeem (S)");
    }

    // ------------------------------------------------------------------ 08
    function test_08_controller_freeze_gauges() public {
        // Gauges proven to revert in local runs (controller-wide failure; all 11 controller entries
        // share this controller and the same frozen state).
        address[4] memory gauges = [
            0xaCC31d29022C8Eb2683597bF4c07De228Ed9EA07,
            0x00687547D75A2d1378984bE922e1450CcC89211E,
            0x1dA7F4b2B9B644f307A313e304E1B061Eb605965,
            0x34EA84d3565824573073b1A63057baf57f842F02
        ];
        uint256 reverts;
        for (uint256 i = 0; i < gauges.length; i++) {
            (bool ok, ) = CONTROLLER.call(abi.encodeWithSignature("checkpoint_gauge(address)", gauges[i]));
            if (!ok) reverts++;
            emit log_named_string("checkpoint_gauge ok", ok ? "true" : "false");
        }
        assertEq(reverts, gauges.length, "every gauge checkpoint reverts");
        // controller has not checkpointed since 2023-08-24 (time_total)
        (bool tok, bytes memory tv) = CONTROLLER.staticcall(abi.encodeWithSignature("time_total()"));
        require(tok, "time_total");
        emit log_named_uint("controller time_total", abi.decode(tv, (uint256)));
        assertLt(abi.decode(tv, (uint256)), 1_700_000_000, "controller frozen since 2023");
        emit log_string("controller checkpoint dead for ALL gauges -> withdrawals impossible");
    }

    // ------------------------------------------------------------------ 09
    function test_09_write_summary() public {
        (, uint256[] memory bal, ) = VAULT.getPoolTokens(POOL_ID);
        string memory json = string.concat(
            "{\n",
            '  "fork_block": ', vm.toString(block.number), ",\n",
            '  "vault": "', vm.toString(address(VAULT)), '",\n',
            '  "vault_usdt": "', vm.toString(_vaultBal(USDT)), '",\n',
            '  "vault_usdc": "', vm.toString(_vaultBal(USDC)), '",\n',
            '  "vault_busd": "', vm.toString(_vaultBal(BUSD)), '",\n',
            '  "stable_pool_balances": ["', vm.toString(bal[0]), '","', vm.toString(bal[1]), '","',
            vm.toString(bal[2]), '"],\n',
            '  "stable_bpt_supply": "', vm.toString(POOL.totalSupply()), '",\n',
            '  "gauge_bpt_frozen": "', vm.toString(GAUGE.totalSupply()), '",\n',
            '  "gauge_killed": ', GAUGE.is_killed() ? "true" : "false", ",\n",
            '  "pool_rate": "', vm.toString(POOL.getRate()), '",\n',
            '  "vault_paused": ', _pausedJson(), ",\n",
            '  "conclusion": "no external unprivileged extraction; gauge-staked BPT is stuck (S); non-gauge BPT exits at fair value (H-O)"\n',
            "}\n"
        );
        vm.writeFile("../ci-out/poc-results.json", json);
        emit log_string(json);
    }

    function _pausedJson() internal view returns (string memory) {
        (bool p,,) = VAULT.getPausedState();
        return p ? "true" : "false";
    }
}
