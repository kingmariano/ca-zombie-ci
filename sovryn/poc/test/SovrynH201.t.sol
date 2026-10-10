// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// H2-01 — Sovryn legacy Lend/Borrow (RSK) — read-only fork verification.
//
// Status of the finding as published in ZOMBIE-HUNT-II:
//   "Every call reverts LoanTokenLogicProxy:target not active; owner Safe
//    0x967c84b7... can reactivate -> the Oct-2022 iToken price-manipulation
//    recipe applies immediately."
//
// What this suite proves on a public RSK fork (read-only; no mainnet writes):
//   1. The iToken pools are LIVE today: mint/burn works for arbitrary users
//      (iWRBTC via native RBTC; iUSDT via rUSDT). -> the "frozen $7.1M" premise
//      is wrong.
//   2. Only a handful of *auxiliary* selectors revert "target not active"
//      (e.g. flashBorrow, iToken-level withdrawAccruedInterest) — the kernel
//      of truth behind the finding's observation.
//   3. The Oct-2022 cross-contract reentrancy (nested iToken mint inside the
//      native-RBTC / ERC-777 payout callback of a guarded call) is BLOCKED by
//      the deployed global Mutex guard (`globallyNonReentrant`) + the
//      `iTokenSupplyUnchanged` invariant in the closing modules.
//   4. "Reactivation" is privileged-only: the beacon/protocol owner is a 48h
//      Timelock (Bitocracy governance), not a Safe; arbitrary callers cannot
//      re-register modules. Even a governance rollback to the oldest module
//      in the beacon's upgrade log keeps the guard — the recipe is not
//      resurrected.
//   5. Before/after structural evidence: the Mutex guard address is compiled
//      into every live module, and was absent from the Oct-2022 logic.
// ---------------------------------------------------------------------------

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ILoanToken {
    function mint(address, uint256) external returns (uint256);
    function burn(address, uint256) external returns (uint256);
    function mintWithBTC(address, bool) external payable returns (uint256);
    function burnToBTC(address, uint256, bool) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function tokenPrice() external view returns (uint256);
    function totalAssetBorrow() external view returns (uint256);
    function checkPause(string calldata) external view returns (bool);
    function flashBorrow(uint256, address, bytes calldata) external;
    function withdrawAccruedInterest(address) external;
}

interface ILoanTokenLogicBeacon {
    function getTarget(bytes4) external view returns (address);
    function owner() external view returns (address);
    function registerLoanTokenModule(address) external;
    function paused() external view returns (bool);
}

interface ISovrynProtocol {
    function logicTargets(bytes4) external view returns (address);
    function owner() external view returns (address);
    function isProtocolPaused() external view returns (bool);
}

/// @dev Attacker contract that attempts the Oct-2022 call shape: nested iToken
///      mint inside the native-RBTC payout callback of a guarded iToken call.
contract Reenterer {
    ILoanToken public immutable iToken;
    bool public armed;
    bool public propagate = true;
    bool public innerAttempted;
    bool public innerOk;
    bytes public innerRevert;

    constructor(ILoanToken _t) {
        iToken = _t;
    }

    receive() external payable {
        if (armed && !innerAttempted) {
            innerAttempted = true;
            (bool ok, bytes memory data) = address(iToken).call{value: msg.value}(
                abi.encodeWithSignature("mintWithBTC(address,bool)", address(this), false)
            );
            innerOk = ok;
            innerRevert = data;
            if (!ok && propagate) {
                // propagate the guard revert so the whole (simulated) exploit tx fails,
                // exactly as the Oct-2022 recipe would need the nested mint to succeed
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
        }
    }

    function mintSelf() external payable {
        iToken.mintWithBTC{value: msg.value}(address(this), false);
    }

    function burnSelf(uint256 amt) external {
        iToken.burnToBTC(address(this), amt, false);
    }

    function setArmed(bool a) external {
        armed = a;
    }

    function setPropagate(bool p) external {
        propagate = p;
    }

    function resetAttempt() external {
        innerAttempted = false;
    }
}

contract SovrynH201Test is Test {
    // --- live addresses (RSK mainnet, chain id 30) -------------------------
    address constant PROTO = 0x5A0D867e0D70Fcc6Ade25C3F1B89d618b5B4Eaa7;
    address constant IWRBTC = 0xa9DcDC63eaBb8a2b6f39D7fF9429d88340044a7A;
    address constant IUSDT = 0x849C47f9C259E9D62F289BF1b2729039698D8387;
    address constant IXUSD = 0x8F77ecf69711a4b346f23109c40416BE3dC7f129;
    address constant RUSDT = 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96;
    address constant BEACON_WRBTC = 0x845eF7Be59664899398282Ef42239634aBDd752C;
    address constant BEACON_LM = 0x5b155ECcC1dC31Ea59F2c12d2F168C956Ac0FFAa;
    address constant TIMELOCK = 0x967c84b731679E36A344002b8E3CE50620A7F69f; // 48h Timelock, admin=GovernorOwner (Bitocracy)
    address constant MUTEX = 0xba10edD6ABC7696Eae685839217BdcC42139612b; // SharedReentrancyGuard global mutex
    address constant CLOSINGS_WITH = 0xa3FCC9F88De9A7f0258eda6cD8d6F7D39ef6fb8d; // active LoanClosingsWith module
    address constant LT_LOGIC_WRBTC = 0xd0dbAe16eb51f7487A072979f765b4c5B5620537; // active iWRBTC borrow/margin logic
    address constant LT_LOGIC_STD = 0x455699500B2C8688dA944E5296a4078b71588675; // active LM iToken logic
    address constant LT_LOGIC_WRBTC_LM_NEW = 0x6c8f59D321560f4bEF84c99e83dd7FF31122e14f; // 2026 WrbtcLM (Perimeter)
    address constant LT_LOGIC_LM_NEW = 0x593DB96E61F59F1278068742486Fc85CDBe9D872; // 2026 LM
    address constant OLD_WRBTC_LM_2023 = 0x24B3687966C4f05e48ED5A3B9c14F56d9ad5BF6B; // beacon v0 module (Oct-2023)
    address constant OLD_LM_LOGIC_OCT2022 = 0x82C49eC67389B6e8c377eD1Da7816b9add4e3B1e; // iUSDT mint target at Oct-2022 exploit block

    // selectors
    bytes4 constant SEL_MINT = 0x40c10f19;
    bytes4 constant SEL_BORROW = 0x2ea295fa;
    bytes4 constant SEL_MARGINTRADE = 0x28a02f19;
    bytes4 constant SEL_FLASHBORROW = 0xd4299134;
    bytes4 constant SEL_LIQUIDATE = 0xe4f3e739;
    bytes4 constant SEL_MINTWITHTBC = 0xfb5f83df;

    function _rpc() internal view returns (string memory) {
        return vm.envOr("RSK_RPC_URL", string("https://public-node.rsk.co"));
    }

    function setUp() public {
        vm.createSelectFork(_rpc());
    }

    function _contains(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0 || haystack.length < needle.length) return false;
        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    // -----------------------------------------------------------------------
    // 1. LIVE TODAY: iWRBTC mint + burn by a fresh, unprivileged user
    // -----------------------------------------------------------------------
    function test_01_live_iWRBTC_mint_and_burn() public {
        address user = makeAddr("freshUser");
        vm.deal(user, 1 ether);

        vm.prank(user);
        uint256 minted = ILoanToken(IWRBTC).mintWithBTC{value: 0.2 ether}(user, false);
        assertGt(minted, 0, "mintWithBTC minted 0");

        uint256 bal = ILoanToken(IWRBTC).balanceOf(user);
        assertGt(bal, 0, "iWRBTC balance 0");

        uint256 ethBefore = user.balance;
        vm.prank(user);
        uint256 paid = ILoanToken(IWRBTC).burnToBTC(user, bal, false);
        assertGt(paid, 0, "burnToBTC paid 0");
        assertGt(user.balance, ethBefore, "native RBTC not returned");

        emit log_named_uint("iWRBTC minted (wei)", minted);
        emit log_named_uint("iWRBTC burned, gross RBTC paid (wei)", paid);
        emit log_named_uint("tokenPrice (1e18)", ILoanToken(IWRBTC).tokenPrice());
    }

    // -----------------------------------------------------------------------
    // 2. LIVE TODAY: iUSDT mint + burn (LM beacon route)
    // -----------------------------------------------------------------------
    function test_02_live_iUSDT_mint_and_burn() public {
        // top rUSDT holder, no ERC-777 sender/recipient hooks registered (verified)
        address whale = 0x040007b1804AD78a97F541beBeD377dcB60e4138;

        vm.startPrank(whale);
        IERC20Like(RUSDT).approve(IUSDT, type(uint256).max);
        uint256 minted = ILoanToken(IUSDT).mint(whale, 5_000e18);
        assertGt(minted, 0, "iUSDT minted 0");
        uint256 paid = ILoanToken(IUSDT).burn(whale, minted);
        vm.stopPrank();

        assertGt(paid, 0, "iUSDT burn paid 0");
        emit log_named_uint("iUSDT minted (1e18)", minted);
        emit log_named_uint("iUSDT burned, rUSDT paid (1e18)", paid);
    }

    // -----------------------------------------------------------------------
    // 3. The finding's kernel of truth: auxiliary selectors are dead
    // -----------------------------------------------------------------------
    function test_03_auxiliary_selectors_revert_target_not_active() public {
        vm.expectRevert(bytes("LoanTokenLogicProxy:target not active"));
        ILoanToken(IUSDT).flashBorrow(1, address(this), "");

        vm.expectRevert(bytes("LoanTokenLogicProxy:target not active"));
        ILoanToken(IUSDT).withdrawAccruedInterest(IUSDT);
    }

    // -----------------------------------------------------------------------
    // 4. Routing map: what is live vs dead (beacon + protocol registries)
    // -----------------------------------------------------------------------
    function test_04_routing_live_vs_dead() public {
        // iToken level (beacon) — live
        assertTrue(ILoanTokenLogicBeacon(BEACON_WRBTC).getTarget(SEL_MINT) != address(0), "mint not routed");
        assertTrue(ILoanTokenLogicBeacon(BEACON_WRBTC).getTarget(SEL_BORROW) != address(0), "borrow not routed");
        assertTrue(ILoanTokenLogicBeacon(BEACON_WRBTC).getTarget(SEL_MARGINTRADE) != address(0), "marginTrade not routed");
        assertTrue(ILoanTokenLogicBeacon(BEACON_LM).getTarget(SEL_MINT) != address(0), "LM mint not routed");
        // iToken level — dead
        assertEq(ILoanTokenLogicBeacon(BEACON_WRBTC).getTarget(SEL_FLASHBORROW), address(0), "flashBorrow unexpectedly routed");
        // protocol level — live
        assertTrue(ISovrynProtocol(PROTO).logicTargets(SEL_LIQUIDATE) != address(0), "liquidate not routed");
        // protocol level — dead (legacy entry points; iToken-level equivalents are live)
        assertEq(ISovrynProtocol(PROTO).logicTargets(SEL_MARGINTRADE), address(0), "protocol marginTrade routed");
        assertEq(ISovrynProtocol(PROTO).logicTargets(SEL_BORROW), address(0), "protocol borrow routed");
        // protocol not paused; no iToken function paused
        assertFalse(ISovrynProtocol(PROTO).isProtocolPaused(), "protocol paused");
        assertFalse(ILoanToken(IWRBTC).checkPause("borrow"), "iWRBTC borrow paused");
        assertFalse(ILoanToken(IWRBTC).checkPause("marginTrade"), "iWRBTC marginTrade paused");
        assertFalse(ILoanToken(IUSDT).checkPause("mint"), "iUSDT mint paused");
        assertFalse(ILoanTokenLogicBeacon(BEACON_WRBTC).paused(), "beacon paused");
    }

    // -----------------------------------------------------------------------
    // 5. Oct-2022 recipe class is BLOCKED (nested mint inside payout callback)
    // -----------------------------------------------------------------------
    function test_05_oct2022_recipe_class_blocked() public {
        Reenterer r = new Reenterer(ILoanToken(IWRBTC));
        vm.deal(address(r), 3 ether);

        r.mintSelf{value: 0.5 ether}();
        uint256 bal = ILoanToken(IWRBTC).balanceOf(address(r));
        assertGt(bal, 0, "setup mint failed");

        // control: burn without reentry succeeds (payout callback allowed)
        r.setArmed(false);
        r.burnSelf(bal / 3);

        // record mode: the nested mint is rejected by the guard; outer call completes
        r.setPropagate(false);
        r.setArmed(true);
        r.burnSelf(ILoanToken(IWRBTC).balanceOf(address(r)) / 2);
        assertFalse(r.innerOk(), "nested mint unexpectedly succeeded");
        assertTrue(
            _contains(r.innerRevert(), bytes("nonReentrant")),
            "nested mint did not revert with the nonReentrant guard"
        );
        emit log_string("nested mint inside payout callback reverted: nonReentrant");

        // propagate mode: the full exploit-shaped tx reverts
        r.setPropagate(true);
        r.resetAttempt();
        r.setArmed(true);
        uint256 bal2 = ILoanToken(IWRBTC).balanceOf(address(r));
        vm.expectRevert();
        r.burnSelf(bal2);
    }

    // -----------------------------------------------------------------------
    // 6. Reactivation is privileged-only; a rollback does not resurrect the recipe
    // -----------------------------------------------------------------------
    function test_06_reactivation_privileged_only_and_recipe_stays_blocked() public {
        // (a) arbitrary caller cannot re-register a module on the beacon
        vm.prank(makeAddr("mallory"));
        vm.expectRevert();
        ILoanTokenLogicBeacon(BEACON_WRBTC).registerLoanTokenModule(OLD_WRBTC_LM_2023);

        // (b) the Timelock owner can (this is the "reactivation switch")
        vm.prank(TIMELOCK);
        ILoanTokenLogicBeacon(BEACON_WRBTC).registerLoanTokenModule(OLD_WRBTC_LM_2023);
        assertEq(
            ILoanTokenLogicBeacon(BEACON_WRBTC).getTarget(SEL_MINTWITHTBC),
            OLD_WRBTC_LM_2023,
            "rollback did not take effect"
        );

        // (c) the recipe is still blocked after the "reactivation"
        Reenterer r = new Reenterer(ILoanToken(IWRBTC));
        vm.deal(address(r), 2 ether);
        r.mintSelf{value: 0.5 ether}();
        r.setArmed(true);
        uint256 bal = ILoanToken(IWRBTC).balanceOf(address(r));
        vm.expectRevert();
        r.burnSelf(bal);

        // restore (fork-only)
        vm.prank(TIMELOCK);
        ILoanTokenLogicBeacon(BEACON_WRBTC).registerLoanTokenModule(LT_LOGIC_WRBTC_LM_NEW);
    }

    // -----------------------------------------------------------------------
    // 7. Structural before/after: Mutex guard compiled into all live modules,
    //    absent from the Oct-2022 logic
    // -----------------------------------------------------------------------
    function test_07_before_after_guard_bytecode() public {
        bytes memory mutex = abi.encodePacked(MUTEX);
        assertTrue(_contains(CLOSINGS_WITH.code, mutex), "closings_with missing Mutex");
        assertTrue(_contains(LT_LOGIC_WRBTC.code, mutex), "wrbtc logic missing Mutex");
        assertTrue(_contains(LT_LOGIC_STD.code, mutex), "LM logic missing Mutex");
        assertTrue(_contains(LT_LOGIC_WRBTC_LM_NEW.code, mutex), "2026 WrbtcLM missing Mutex");
        assertTrue(_contains(LT_LOGIC_LM_NEW.code, mutex), "2026 LM missing Mutex");
        assertTrue(_contains(OLD_WRBTC_LM_2023.code, mutex), "2023 module missing Mutex");
        // invariant string present in the closing modules
        assertTrue(
            _contains(CLOSINGS_WITH.code, bytes("loan token supply invariant chec")),
            "closings invariant string missing"
        );

        // Oct-2022 (pre-fix): the then-active iUSDT mint logic has NO Mutex
        vm.createSelectFork(_rpc(), 4_689_412);
        assertFalse(
            _contains(OLD_LM_LOGIC_OCT2022.code, mutex),
            "Oct-2022 logic unexpectedly contains the guard"
        );
        emit log_string("Oct-2022 logic at block 4689412 lacks the global Mutex guard (fix deployed later)");
    }

    // -----------------------------------------------------------------------
    // 8. Live-state snapshot (logged; values asserted loosely)
    // -----------------------------------------------------------------------
    function test_08_live_state_snapshot() public {
        address[3] memory pools = [IWRBTC, IUSDT, IXUSD];
        for (uint256 i = 0; i < pools.length; i++) {
            emit log_named_address("pool", pools[i]);
            emit log_named_uint("  totalSupply", ILoanToken(pools[i]).totalSupply());
            emit log_named_uint("  tokenPrice", ILoanToken(pools[i]).tokenPrice());
            emit log_named_uint("  totalAssetBorrow", ILoanToken(pools[i]).totalAssetBorrow());
            assertGt(ILoanToken(pools[i]).totalSupply(), 0, "empty pool");
        }
        emit log_named_uint("block.number", block.number);
    }
}
