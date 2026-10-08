// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IStBTCReserve} from "./interfaces/IStBTCReserve.sol";
import {IOffchainBtcVault} from "./interfaces/IOffchainBtcVault.sol";

/**
 * @title OffchainBtcVault
 * @notice Simplified vault for holding WBTC with operator-managed off-chain strategies.
 * @dev Pure custody contract - no complex accounting, no withdrawal queues.
 *      Balance tracking uses wbtc.balanceOf(this) for simplicity and security.
 */
contract OffchainBtcVault is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    // State Variables
    IERC20 public wbtc;
    address public stBTC;
    bool private stBTCSet;

    /// @notice Balance of BTC deployed to off-chain strategies
    uint256 public offchainBalance;

    /// @notice Minimum on-chain liquidity as basis points of totalManagedAssets
    uint256 public minLiquidityBps;

    /// @notice Maximum allocation to any single strategy as basis points of totalManagedAssets
    uint256 public maxStrategyAllocationBps;

    /// @notice Mapping of whitelisted strategy addresses
    mapping(address => bool) public isStrategyAllowed;

    /// @notice Mapping of strategy addresses to their current value (principal + yield - loss)
    mapping(address => uint256) public strategyDebt;

    /// @notice Mapping of strategy addresses to their original principal (NOT affected by yield/loss)
    mapping(address => uint256) public strategyPrincipal;

    // Yield reporting parameters
    uint256 public maxWindowYieldBps; // max yield per window as BPS of offchain principal
    uint256 public lastYieldReportAt;
    uint256 public yieldReportWindow; // minimum time between yield reports in seconds
    uint256 public maxYieldReportedInWindow; // accumulated yield in current window
    uint256 public yieldWindowStartPrincipal; // offchain principal at start of current yield window

    // Loss reporting parameters
    uint256 public maxWindowLossBps; // max loss per window as BPS of offchain principal
    uint256 public lastLossReportAt;
    uint256 public lossReportWindow; // time window for loss accumulation
    uint256 public lossReportedInWindow; // accumulated loss in current window
    uint256 public lossWindowStartPrincipal; // offchain principal at start of current loss window

    /// @notice Total principal sent to strategies (NOT affected by yield/loss reports)
    /// @dev Used for P&L calculation: netPnL = offchainBalance - totalStrategyPrincipal
    uint256 public totalStrategyPrincipal;

    /// @notice Cumulative yield reported (for transparency/reconciliation)
    uint256 public totalReportedYield;

    /// @notice Cumulative losses reported (for transparency/reconciliation)
    uint256 public totalReportedLoss;

    // Errors
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error StrategyNotAllowed();
    error ExceedsDebt();
    error OnlyStBTC();
    error StBTCAlreadySet();
    error StBTCNotSet();
    error InvalidBps();
    error InsufficientLiquidity();
    error YieldTooHigh();
    error InvalidWindow();
    error LossTooHigh();
    error ExceedsStrategyAllocationLimit();

    // Events
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event SentToStrategy(address indexed strategy, uint256 amount, uint256 remainingBalance);
    event ReturnedFromStrategy(address indexed strategy, uint256 amount, uint256 newBalance);
    event StrategyAllowedUpdated(address indexed strategy, bool allowed);
    event StBTCSet(address indexed stBTC);
    event MinLiquidityBpsUpdated(uint256 bps);
    event YieldReported(
        address indexed strategy, uint256 addedYield, uint256 newStrategyDebt, uint256 newTotalManagedAssets
    );
    event LossReported(address indexed strategy, uint256 loss, uint256 newStrategyDebt, uint256 newTotalManagedAssets);
    event MaxWindowYieldBpsUpdated(uint256 bps);
    event YieldReportWindowUpdated(uint256 window);
    event MaxWindowLossBpsUpdated(uint256 bps);
    event LossReportWindowUpdated(uint256 window);
    event MaxStrategyAllocationBpsUpdated(uint256 bps);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the vault.
     * @param _admin The address of the admin.
     * @param _operator The address of the operator.
     * @param _wbtc The address of the WBTC token.
     */
    function initialize(address _admin, address _operator, address _wbtc) public initializer {
        __AccessControl_init();
        __Pausable_init();

        if (_admin == address(0)) revert InvalidAddress();
        if (_operator == address(0)) revert InvalidAddress();
        if (_wbtc == address(0)) revert InvalidAddress();

        wbtc = IERC20(_wbtc);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _operator);

        // Initialize yield/loss parameters with sensible defaults
        // These prevent unlimited yield/loss reporting before admin configures them
        maxWindowYieldBps = 100; // 1% max yield per window (conservative default)
        yieldReportWindow = 1 days; // 24 hour minimum between yield reports
        maxWindowLossBps = 500; // 5% max loss per window
        lossReportWindow = 1 days; // 24 hour window for loss accumulation
        maxStrategyAllocationBps = 4000; // 40% max per strategy (balanced default)
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    modifier onlyStBTC() {
        if (stBTC == address(0)) revert StBTCNotSet();
        if (msg.sender != stBTC) revert OnlyStBTC();
        _;
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /**
     * @notice Returns the available WBTC balance in the vault.
     * @dev Uses wbtc.balanceOf() for accurate, tamper-proof balance tracking.
     */
    function availableBalance() public view returns (uint256) {
        return wbtc.balanceOf(address(this));
    }

    /**
     * @notice Returns total assets under management (on-chain + off-chain).
     * @dev This is the single source of truth for all value calculations.
     *      StBTC queries this for share price calculations.
     * @return Total WBTC value managed by the vault
     */
    function totalManagedAssets() public view returns (uint256) {
        return availableBalance() + offchainBalance;
    }

    // =========================================================================
    // StBTC Functions (Called by StBTC contract only)
    // =========================================================================

    /**
     * @notice Accepts WBTC deposits from StBTC contract.
     * @dev Called when users deposit through StBTC.
     *      No accounting needed - totalManagedAssets() derives from wbtc.balanceOf + offchainBalance.
     * @param amount The amount of WBTC deposited.
     */
    function depositFromStBTC(uint256 amount) external onlyStBTC {
        if (amount == 0) revert InvalidAmount();

        // Transfer WBTC from StBTC to vault
        wbtc.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraws WBTC to a user (instant withdrawal).
     * @dev Called when users withdraw through StBTC. Reverts if insufficient balance.
     *      No accounting needed - totalManagedAssets() derives from wbtc.balanceOf + offchainBalance.
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function withdrawToUser(address to, uint256 amount) external onlyStBTC nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 available = availableBalance();
        if (amount > available) revert InsufficientBalance();

        wbtc.safeTransfer(to, amount);

        emit Withdrawal(to, amount);
    }

    // =========================================================================
    // Operator Functions (Strategy Management)
    // =========================================================================

    /**
     * @notice Sends WBTC to an off-chain strategy address.
     * @dev Strategy must be whitelisted by admin before funds can be sent.
     *      Enforces minLiquidityBps to prevent over-allocation to strategies.
     * @param strategy The destination address (operator-controlled wallet/contract).
     * @param amount The amount of WBTC to send.
     */
    function sendToStrategy(address strategy, uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        if (strategy == address(0)) revert InvalidAddress();
        if (!isStrategyAllowed[strategy]) revert StrategyNotAllowed();
        if (amount == 0) revert InvalidAmount();

        uint256 currentBalance = availableBalance();
        if (amount > currentBalance) revert InsufficientBalance();

        // Enforce per-strategy allocation limit
        if (maxStrategyAllocationBps > 0) {
            uint256 totalAssets = totalManagedAssets();
            if (totalAssets > 0) {
                uint256 maxAllowed = (totalAssets * maxStrategyAllocationBps) / 10_000;
                uint256 newStrategyDebt = strategyDebt[strategy] + amount;
                if (newStrategyDebt > maxAllowed) revert ExceedsStrategyAllocationLimit();
            }
        }

        // Enforce minimum on-chain liquidity based on total managed assets
        if (minLiquidityBps > 0) {
            uint256 totalAssets = totalManagedAssets();
            if (totalAssets > 0) {
                uint256 minRequired = (totalAssets * minLiquidityBps) / 10_000;
                if (currentBalance - amount < minRequired) revert InsufficientLiquidity();
            }
        }

        // CEI: Effects before Interaction
        strategyDebt[strategy] += amount;
        strategyPrincipal[strategy] += amount;
        totalStrategyPrincipal += amount;
        offchainBalance += amount;

        wbtc.safeTransfer(strategy, amount);

        emit SentToStrategy(strategy, amount, currentBalance - amount);
    }

    /**
     * @notice Returns WBTC from off-chain strategies back to the vault.
     * @dev Operator transfers WBTC back when liquidity is needed or to harvest yield.
     *      strategyDebt tracks current value (principal + yield - loss).
     *      Can return up to strategyDebt (what the strategy currently owes).
     *      Note: Does NOT require strategy to be whitelisted - allows recovery from
     *      de-whitelisted strategies that still have outstanding debt.
     * @param strategy The strategy address returning funds.
     * @param amount The amount of WBTC to return (must be <= strategyDebt).
     */
    function returnFromStrategy(address strategy, uint256 amount) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (strategy == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > strategyDebt[strategy]) revert ExceedsDebt();

        // CEI: Effects before Interaction
        // Calculate principal returned: min(amount, strategyPrincipal[strategy])
        // This means returns reduce principal first, then any excess is realized yield
        uint256 principalReturned = amount > strategyPrincipal[strategy] ? strategyPrincipal[strategy] : amount;

        strategyDebt[strategy] -= amount;
        strategyPrincipal[strategy] -= principalReturned;
        totalStrategyPrincipal -= principalReturned;
        offchainBalance -= amount;

        // Operator must approve vault to transfer WBTC from strategy address
        wbtc.safeTransferFrom(strategy, address(this), amount);

        emit ReturnedFromStrategy(strategy, amount, availableBalance());
    }

    /**
     * @notice Reports yield earned from a specific off-chain strategy.
     * @dev Increases offchainBalance and strategyDebt, which increases totalManagedAssets().
     *      strategyDebt = principal + yield - loss (current value strategy owes).
     *      Uses sliding window accumulator pattern to enforce true per-window limits.
     *      Requires maxWindowYieldBps to be configured (non-zero) to prevent unlimited yield.
     * @param strategy The strategy that generated the yield
     * @param addedYield The amount of yield earned
     */
    function reportYield(address strategy, uint256 addedYield) external onlyRole(REPORTER_ROLE) {
        if (strategy == address(0)) revert InvalidAddress();
        if (!isStrategyAllowed[strategy]) revert StrategyNotAllowed();
        if (addedYield == 0) revert InvalidAmount();
        if (strategyDebt[strategy] == 0) revert InvalidAmount(); // Must have active debt

        // Check if we need to start a new window or initialize
        if (lastYieldReportAt == 0 || block.timestamp >= lastYieldReportAt + yieldReportWindow) {
            // Snapshot current offchain value at window start (yield cap based on current value)
            yieldWindowStartPrincipal = offchainBalance;
            maxYieldReportedInWindow = 0;
            lastYieldReportAt = block.timestamp;
        }

        // Validate we have value to report yield against
        if (yieldWindowStartPrincipal == 0) revert InvalidAmount();

        // Enforce accumulated yield cap within current window using SNAPSHOT
        uint256 maxAllowed = (yieldWindowStartPrincipal * maxWindowYieldBps) / 10_000;
        if (maxAllowed == 0 || maxYieldReportedInWindow + addedYield > maxAllowed) revert YieldTooHigh();

        // Update accumulator and balances
        maxYieldReportedInWindow += addedYield;
        offchainBalance += addedYield;

        // Add yield to strategy debt (strategyDebt = principal + yield - loss)
        // Note: totalStrategyPrincipal is NOT updated - yield doesn't change principal
        strategyDebt[strategy] += addedYield;
        totalReportedYield += addedYield;

        emit YieldReported(strategy, addedYield, strategyDebt[strategy], totalManagedAssets());
    }

    /**
     * @notice Reports losses from a specific off-chain strategy.
     * @dev Decreases offchainBalance and strategyDebt, which decreases totalManagedAssets().
     *      strategyDebt = principal + yield - loss (current value strategy owes).
     *      Uses sliding window accumulator pattern to enforce true per-window limits.
     *      Requires maxWindowLossBps to be configured (non-zero) to prevent unlimited loss.
     * @param strategy The strategy that incurred the loss
     * @param loss The amount of loss incurred
     */
    function reportLoss(address strategy, uint256 loss) external onlyRole(REPORTER_ROLE) {
        if (strategy == address(0)) revert InvalidAddress();
        if (!isStrategyAllowed[strategy]) revert StrategyNotAllowed();
        if (loss == 0) revert InvalidAmount();
        if (loss > offchainBalance) revert InvalidAmount();
        if (loss > strategyDebt[strategy]) revert ExceedsDebt(); // Can't lose more than strategy has

        // Check if we need to start a new window or initialize
        if (lastLossReportAt == 0 || block.timestamp >= lastLossReportAt + lossReportWindow) {
            // Snapshot current value at window start (loss cap based on current value)
            lossWindowStartPrincipal = offchainBalance;
            lossReportedInWindow = 0;
            lastLossReportAt = block.timestamp;
        }

        // Enforce accumulated loss cap within current window using SNAPSHOT
        if (lossWindowStartPrincipal > 0) {
            uint256 maxAllowed = (lossWindowStartPrincipal * maxWindowLossBps) / 10_000;
            if (lossReportedInWindow + loss > maxAllowed) revert LossTooHigh();
        }

        // Update accumulator and balances
        lossReportedInWindow += loss;
        offchainBalance -= loss;

        // Subtract loss from strategy debt (strategyDebt = principal + yield - loss)
        // Note: totalStrategyPrincipal is NOT updated - loss doesn't change original principal
        strategyDebt[strategy] -= loss;
        totalReportedLoss += loss;

        emit LossReported(strategy, loss, strategyDebt[strategy], totalManagedAssets());
    }

    // =========================================================================
    // Admin Functions
    // =========================================================================

    /**
     * @notice Sets the StBTC contract address (one-time only).
     * @dev Must be called after deployment to connect StBTC contract.
     *      Can only be set once to prevent accidental changes.
     *      Validates that the address is a contract and implements expected interface.
     * @param _stBTC The address of the StBTC contract.
     */
    function setStBTC(address _stBTC) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stBTCSet) revert StBTCAlreadySet();
        if (_stBTC == address(0)) revert InvalidAddress();

        // Validate it's a contract
        if (_stBTC.code.length == 0) revert InvalidAddress();

        // Validate interface - verify StBTC implements IStBTCReserve and references this vault
        try IStBTCReserve(_stBTC).vault() returns (IOffchainBtcVault vaultAddress) {
            // Verify the vault reference points back to this contract
            if (address(vaultAddress) != address(this)) revert InvalidAddress();
        } catch {
            // If call fails, StBTC doesn't implement interface correctly
            revert InvalidAddress();
        }

        stBTC = _stBTC;
        stBTCSet = true;
        emit StBTCSet(_stBTC);
    }

    /**
     * @notice Sets the minimum on-chain liquidity in basis points of totalManagedAssets.
     * @dev Prevents operator from over-allocating funds to strategies.
     *
     *      IMPORTANT - SINGLE SOURCE OF TRUTH:
     *      This parameter (minLiquidityBps) is THE authoritative parameter for instant withdrawal
     *      liquidity requirements. StBTC reads vault.minLiquidityBps() directly when enforcing
     *      withdrawal reserve checks.
     *
     *      OPERATIONAL CONSIDERATIONS:
     *      - Changes to this value immediately affect maxWithdraw/maxRedeem calculations in StBTC
     *      - Lowering this value increases instant withdrawal capacity
     *      - Raising this value may reduce instant withdrawal capacity
     *
     *      RECOMMENDED VALUES:
     *      - Conservative: 2000-3000 bps (20-30% on-chain)
     *      - Moderate: 1000-2000 bps (10-20% on-chain)
     *      - Aggressive: 500-1000 bps (5-10% on-chain)
     *
     * @param bps Basis points (0-10_000). E.g., 2000 = 20% minimum on-chain liquidity.
     */
    function setMinLiquidityBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > 10_000) revert InvalidBps();
        minLiquidityBps = bps;
        emit MinLiquidityBpsUpdated(bps);
    }

    /**
     * @notice Sets the maximum allocation to any single strategy in basis points.
     * @dev Prevents concentration risk by limiting per-strategy exposure.
     *      Setting to 0 disables the limit (not recommended).
     * @param bps Basis points (0-10_000). E.g., 4000 = 40% max per strategy.
     */
    function setMaxStrategyAllocationBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > 10_000) revert InvalidBps();
        maxStrategyAllocationBps = bps;
        emit MaxStrategyAllocationBpsUpdated(bps);
    }

    /**
     * @notice Sets whether a strategy address is allowed to receive funds.
     * @dev Admin must whitelist strategies before operator can send funds to them.
     * @param strategy The strategy address to whitelist or unwhitelist.
     * @param allowed True to whitelist, false to remove from whitelist.
     */
    function setStrategyAllowed(address strategy, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (strategy == address(0)) revert InvalidAddress();
        isStrategyAllowed[strategy] = allowed;
        emit StrategyAllowedUpdated(strategy, allowed);
    }

    /**
     * @notice Sets the maximum yield that can be reported per window as BPS of offchain principal.
     * @param bps Basis points (0-10_000). Set to 0 to disable the cap.
     */
    function setMaxWindowYieldBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > 10_000) revert InvalidBps();
        maxWindowYieldBps = bps;
        emit MaxWindowYieldBpsUpdated(bps);
    }

    /**
     * @notice Sets the minimum time window between yield reports.
     * @param window Time in seconds (must be > 0).
     */
    function setYieldReportWindow(uint256 window) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (window == 0) revert InvalidWindow();
        yieldReportWindow = window;
        emit YieldReportWindowUpdated(window);
    }

    /**
     * @notice Sets the maximum loss that can be reported per window as BPS of offchain principal.
     * @param bps Basis points (0-10_000). Set to 0 to disable the cap.
     */
    function setMaxWindowLossBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > 10_000) revert InvalidBps();
        maxWindowLossBps = bps;
        emit MaxWindowLossBpsUpdated(bps);
    }

    /**
     * @notice Sets the minimum time window between loss reports (cooldown).
     * @param window Time in seconds. Minimum time that must pass between loss reports.
     */
    function setLossReportWindow(uint256 window) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (window == 0) revert InvalidWindow();
        lossReportWindow = window;
        emit LossReportWindowUpdated(window);
    }

    /**
     * @notice Pauses operator fund movements (sendToStrategy).
     * @dev Emergency function to halt operator actions.
     *      Does NOT pause returnFromStrategy - funds can still be recovered.
     *      Does NOT pause StBTC deposits/withdrawals - users can still interact.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses operator fund movements.
     * @dev Restores normal operation after emergency is resolved.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency function to rescue tokens (except WBTC).
     * @param token The token address to rescue.
     * @param to The recipient address.
     * @param amount The amount to rescue.
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        if (token == address(wbtc)) revert InvalidAddress(); // Cannot rescue WBTC
        emit TokensRescued(token, to, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Get detailed statistics for a strategy.
     * @dev Useful for reconciliation and monitoring of strategy allocations.
     * @param strategy The strategy address to query.
     * @return debt The current debt (amount sent but not returned).
     * @return allowed Whether the strategy is currently whitelisted.
     * @return percentOfOffchain The percentage of offchain balance allocated to this strategy (in basis points).
     */
    function getStrategyStats(address strategy)
        external
        view
        returns (uint256 debt, bool allowed, uint256 percentOfOffchain)
    {
        debt = strategyDebt[strategy];
        allowed = isStrategyAllowed[strategy];
        percentOfOffchain = offchainBalance > 0 ? (debt * 10_000) / offchainBalance : 0;
    }

    /**
     * @notice Get breakdown of offchain balance components for transparency.
     * @dev Useful for reconciliation and auditing.
     *      - principal: Total original principal deployed (totalStrategyPrincipal)
     *      - currentValue: Current value (offchainBalance = principal + yield - loss)
     *      - netPnL: offchainBalance - totalStrategyPrincipal
     * @return principal Total original principal deployed to strategies
     * @return currentValue Current total value (offchainBalance)
     * @return yield Cumulative yield reported over lifetime
     * @return loss Cumulative losses reported over lifetime
     * @return netPnL Net profit/loss (currentValue - principal)
     */
    function getOffchainBreakdown()
        external
        view
        returns (uint256 principal, uint256 currentValue, uint256 yield, uint256 loss, int256 netPnL)
    {
        principal = totalStrategyPrincipal;
        currentValue = offchainBalance;
        yield = totalReportedYield;
        loss = totalReportedLoss;
        netPnL = int256(currentValue) - int256(principal);
    }
}
