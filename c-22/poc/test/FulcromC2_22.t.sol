// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {IVault, IOrderBook, IPositionManager, IRouter, ITimelock, IShortsTracker, IFlpManager, IWETH} from "../src/IFulcrom.sol";

/// @title C2-22 Fulcrom (GMX V1 fork) — order-execution reentrancy, fork verification
/// @notice READ-ONLY on mainnet; all state changes happen on a local Cronos fork only.
///         Verified source: explorer.cronos.com (status "Matched"), recovered 2026-10-09.
///
/// Claims verified here:
///  A. Cronos live state: Vault.isLeverageEnabled() == false is the *resting* state of the
///     GMX-V1 "leverage window" design (the PositionRouter/PositionManager open it around
///     executions; the router's own trading flag is true). A direct increasePosition reverts
///     with "Vault: leverage not enabled" outside an execution window.
///  B. The leverage switch is not permissionless (Timelock.enableLeverage reverts "Timelock: forbidden").
///  C. OrderBook rejects contract accounts for decrease orders ("account cannot be a contract")
///     at both creation and execution — the exact July-2025 GMX callback target is blocked.
///  D. Callback mechanics: OrderBook._transferOutETH(order.executionFee, _feeReceiver) uses
///     OZ sendValue (full gas) and _feeReceiver is caller-chosen on the permissionless
///     OrderBook.executeDecreaseOrder path. On that path the window is CLOSED, so the
///     in-callback direct Vault.increasePosition reverts with the leverage guard (D1);
///     with leverage on it succeeds mechanically (D2).
///  D3. On the keeper path (PositionManager.executeDecreaseOrder) the leverage window is OPEN
///     during the OrderBook callbacks and the in-window reentrancy works mechanically — but
///     the in-window `_feeReceiver` is chosen by the keeper, not the attacker.
///  E. The GMX-2025 profit primitive (ShortsTracker average-price skew -> FLP AUM inflation)
///     is disabled: isGlobalShortDataReady == false, shortsTrackerAveragePriceWeight == 0,
///     updateGlobalShortData is not callable by anyone and no handler calls it.
///
/// NOTE on units: Fulcrom/GMX V1 position `sizeDelta` and `collateralDelta` are USD amounts
/// with 1e30 precision (see Vault.tokenToUsdMin / _validatePosition), not token amounts.

contract ReentrantReceiver {
    IVault public immutable vault;
    IWETH public immutable wcro;

    bool public entered;
    bool public leverageSeenAtCallback;
    bool public innerOpened;
    bytes public innerRevert;
    uint256 public innerPositionSize;

    constructor(IVault _vault, IWETH _wcro) {
        vault = _vault;
        wcro = _wcro;
    }

    function fund() external payable {
        wcro.deposit{value: msg.value}();
    }

    /// @dev Callback target: OrderBook._transferOutETH(order.executionFee, _feeReceiver)
    ///      uses OZ sendValue -> this receive() runs with (almost) all remaining gas.
    receive() external payable {
        entered = true;
        leverageSeenAtCallback = vault.isLeverageEnabled();

        uint256 bal = wcro.balanceOf(address(this));
        if (bal >= 5_000 ether) {
            // deposit collateral into the Vault (Vault._transferIn is balance-delta based)
            wcro.transfer(address(vault), 5_000 ether);

            uint256 price = vault.getMaxPrice(address(wcro));
            uint256 collateralUsd = 5_000 ether * price / 1e18;
            uint256 sizeUsd = collateralUsd * 2; // ~2x leverage

            // msg.sender == account, so Vault._validateRouter allows this direct call
            try vault.increasePosition(address(this), address(wcro), address(wcro), sizeUsd, true) {
                innerOpened = true;
                (uint256 size, , , , , , ) = vault.getPosition(address(this), address(wcro), address(wcro), true);
                innerPositionSize = size;
            } catch (bytes memory reason) {
                innerRevert = reason;
            }
        } else {
            // live configuration: no funding, exercise the guard directly
            try vault.increasePosition(address(this), address(wcro), address(wcro), 1e28, true) {
                innerOpened = true;
            } catch (bytes memory reason) {
                innerRevert = reason;
            }
        }
    }
}

contract FulcromC2_22Test is Test {
    using stdStorage for StdStorage;

    // --- Cronos mainnet addresses (Fulcrom docs + verified on-chain) ---
    address internal constant VAULT = 0x8C7Ef34aa54210c76D6d5E475f43e0c11f876098;
    address internal constant ORDER_BOOK = 0x1c29aeE30B5B101eDEa936Cd0cAeEc724e3B0045;
    address internal constant POSITION_MANAGER = 0xFC399dbb0Ed942D206Ee34Cc6FcbaF1CFd60dB16;
    address internal constant ROUTER = 0xcC46b79eBEaA1D834B707624977Ec261592E0C9a;
    address internal constant TIMELOCK = 0x880a34751D8452df466ae27Ac341F987f0dAf3AE;
    address internal constant TIMELOCK_ADMIN = 0x04Fc879C9068Dc265424949128851Ca19D96eC02;
    address internal constant SHORTS_TRACKER = 0xd996bE6DBdEaa8429Ff9E2D86725197Eb663148a;
    address internal constant FLP_MANAGER = 0x6148107BcAC794d3fC94239B88fA77634983891F;
    address internal constant WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address internal constant EOA_ACCOUNT = address(0xA11CE); // must not be a contract

    // live fixedLiquidationFeeUsd is ~$30, so positions must carry >$31 of collateral
    uint256 internal constant COLLATERAL_TOKENS = 5_000 ether; // 5,000 WCRO ~ $300

    IVault internal vault = IVault(VAULT);
    IOrderBook internal orderBook = IOrderBook(ORDER_BOOK);
    IPositionManager internal positionManager = IPositionManager(POSITION_MANAGER);
    IRouter internal router = IRouter(ROUTER);
    IShortsTracker internal shortsTracker = IShortsTracker(SHORTS_TRACKER);
    IFlpManager internal flpManager = IFlpManager(FLP_MANAGER);
    IWETH internal wcro = IWETH(WCRO);

    ReentrantReceiver internal receiver;

    function setUp() public {
        string memory rpc = vm.envOr("CRONOS_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = "https://evm.cronos.org";
        }
        vm.createSelectFork(rpc);
        receiver = new ReentrantReceiver(vault, wcro);
    }

    // ------------------------------------------------------------------
    // A. Live gates
    // ------------------------------------------------------------------
    function test_A_live_gates_leverage_off_tracker_off() public {
        assertFalse(vault.isLeverageEnabled(), "Vault leverage must be disabled on live Cronos");
        assertFalse(shortsTracker.isGlobalShortDataReady(), "ShortsTracker data must not be ready");
        assertEq(flpManager.shortsTrackerAveragePriceWeight(), 0, "FlpManager must not weight the tracker");
        assertEq(vault.errors(28), "Vault: leverage not enabled", "errors[28] mismatch");
        assertEq(vault.gov(), TIMELOCK, "gov must be the Timelock");
    }

    function test_A_direct_increase_reverts_with_leverage_guard() public {
        vm.prank(DEAD);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Vault: leverage not enabled"));
        vault.increasePosition(DEAD, WCRO, WCRO, 1e28, true);
    }

    // ------------------------------------------------------------------
    // B. Leverage switch gating
    // ------------------------------------------------------------------
    function test_B_timelock_enableLeverage_not_permissionless() public {
        vm.prank(DEAD);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Timelock: forbidden"));
        ITimelock(TIMELOCK).enableLeverage(VAULT);
    }

    // ------------------------------------------------------------------
    // C. OrderBook blocks contract accounts
    // ------------------------------------------------------------------
    function test_C_orderbook_rejects_contract_account() public {
        uint256 fee = orderBook.minExecutionFee();
        vm.deal(address(receiver), fee + 1);
        vm.prank(address(receiver));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "OrderBook: account cannot be a contract"));
        orderBook.createDecreaseOrder{value: fee}(WCRO, 1e28, WCRO, 0, true, type(uint256).max, false);
    }

    // ------------------------------------------------------------------
    // D1. Live config: callback reachable, inner Vault call blocked by leverage guard
    // ------------------------------------------------------------------
    function test_D1_callback_reaches_vault_but_guard_blocks_live() public {
        // gov re-enables leverage only to set up a real position for the EOA account
        vm.prank(TIMELOCK); // Timelock is Vault.gov; direct setIsLeverageEnabled is the gov path
        vault.setIsLeverageEnabled(true);
        _openEoaPosition();

        uint256 fee = orderBook.minExecutionFee();
        uint256 sizeHalf = _positionSizeUsd() / 2; // computed BEFORE the prank (consumes no prank)
        vm.prank(EOA_ACCOUNT);
        orderBook.createDecreaseOrder{value: fee}(WCRO, sizeHalf, WCRO, 0, true, type(uint256).max, false);

        // restore the live configuration before executing the order
        vm.prank(TIMELOCK);
        vault.setIsLeverageEnabled(false);
        assertFalse(vault.isLeverageEnabled(), "leverage must be off again");

        // anyone may execute; _feeReceiver is caller-chosen and receives full-gas sendValue
        orderBook.executeDecreaseOrder(EOA_ACCOUNT, 0, payable(address(receiver)));

        assertTrue(receiver.entered(), "fee-refund callback must fire");
        assertFalse(receiver.leverageSeenAtCallback(), "leverage window must be CLOSED on the direct path");
        assertFalse(receiver.innerOpened(), "inner increase must be blocked while leverage is off");
        assertEq(
            keccak256(receiver.innerRevert()),
            keccak256(abi.encodeWithSignature("Error(string)", "Vault: leverage not enabled")),
            "inner revert must be the leverage guard"
        );
    }

    // ------------------------------------------------------------------
    // D2. Hypothetical: if gov re-enables leverage, the cross-contract reentrancy succeeds
    // ------------------------------------------------------------------
    function test_D2_reenabled_leverage_allows_cross_contract_reentrancy() public {
        vm.prank(TIMELOCK);
        vault.setIsLeverageEnabled(true);
        _openEoaPosition();

        uint256 fee = orderBook.minExecutionFee();
        uint256 sizeHalf = _positionSizeUsd() / 2; // computed BEFORE the prank (consumes no prank)
        vm.prank(EOA_ACCOUNT);
        orderBook.createDecreaseOrder{value: fee}(WCRO, sizeHalf, WCRO, 0, true, type(uint256).max, false);

        // fund the receiver with WCRO for the inner position
        vm.deal(address(this), 6_000 ether);
        receiver.fund{value: 6_000 ether}();

        orderBook.executeDecreaseOrder(EOA_ACCOUNT, 0, payable(address(receiver)));

        assertTrue(receiver.entered(), "fee-refund callback must fire");
        assertTrue(receiver.leverageSeenAtCallback(), "leverage must be on in this hypothetical");
        assertTrue(receiver.innerOpened(), "inner direct Vault.increasePosition must succeed");
        assertGt(receiver.innerPositionSize(), 0, "reentrant position must exist");
    }

    // ------------------------------------------------------------------
    // D3. Keeper window: PositionManager opens the leverage window around order execution;
    //     an in-window callback CAN reenter the Vault (mechanism live), but in production
    //     the callback target (`_feeReceiver`) is chosen by the keeper, not the attacker.
    // ------------------------------------------------------------------
    function test_D3_keeper_window_opens_and_in_window_reentrancy_works() public {
        address keeper = address(0xbeef);
        // simulate the protocol's order keeper so the onlyOrderKeeper path can be exercised
        stdstore.target(POSITION_MANAGER).sig("isOrderKeeper(address)").with_key(keeper).checked_write(true);

        vm.prank(TIMELOCK);
        vault.setIsLeverageEnabled(true);
        _openEoaPosition();

        uint256 fee = orderBook.minExecutionFee();
        uint256 sizeHalf = _positionSizeUsd() / 2; // computed BEFORE the prank (consumes no prank)
        vm.prank(EOA_ACCOUNT);
        orderBook.createDecreaseOrder{value: fee}(WCRO, sizeHalf, WCRO, 0, true, type(uint256).max, false);

        // resting state: leverage window closed
        vm.prank(TIMELOCK);
        vault.setIsLeverageEnabled(false);
        assertFalse(vault.isLeverageEnabled(), "resting state must have leverage off");

        vm.deal(address(this), 6_000 ether);
        receiver.fund{value: 6_000 ether}();

        // keeper executes through PositionManager -> PM opens the window around OrderBook call
        vm.prank(keeper);
        positionManager.executeDecreaseOrder(EOA_ACCOUNT, 0, payable(address(receiver)));

        assertTrue(receiver.entered(), "fee-refund callback must fire");
        assertTrue(receiver.leverageSeenAtCallback(), "leverage window must be OPEN during keeper execution");
        assertTrue(receiver.innerOpened(), "in-window cross-contract reentrancy works mechanically");
    }

    // ------------------------------------------------------------------
    // E. Profit primitive disabled
    // ------------------------------------------------------------------
    function test_E_shorts_tracker_not_updatable() public {
        vm.prank(DEAD);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ShortsTracker: forbidden"));
        shortsTracker.updateGlobalShortData(DEAD, WCRO, WCRO, false, 1e18, 0, true);
        assertFalse(shortsTracker.isGlobalShortDataReady());
        assertEq(flpManager.shortsTrackerAveragePriceWeight(), 0);
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function _collateralUsd() internal view returns (uint256) {
        return COLLATERAL_TOKENS * vault.getMaxPrice(WCRO) / 1e18;
    }

    function _positionSizeUsd() internal view returns (uint256) {
        return _collateralUsd() * 2; // ~2x leverage
    }

    function _openEoaPosition() internal {
        vm.deal(EOA_ACCOUNT, 7_000 ether); // leave CRO for the 0.6 CRO execution fee
        vm.startPrank(EOA_ACCOUNT);
        wcro.deposit{value: 6_000 ether}();
        wcro.transfer(VAULT, COLLATERAL_TOKENS);
        vault.increasePosition(EOA_ACCOUNT, WCRO, WCRO, _positionSizeUsd(), true);
        router.approvePlugin(ORDER_BOOK); // GMX V1: the account must approve the OrderBook plugin
        vm.stopPrank();

        (uint256 size, , , , , , ) = vault.getPosition(EOA_ACCOUNT, WCRO, WCRO, true);
        assertGt(size, 0, "EOA position must open on the fork");
    }
}
