// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IYieldOracle
 * @notice Interface for the minimal YieldOracle contract.
 * @dev Design priorities: SIMPLICITY and SECURITY
 *      - No state accumulation (calculate fresh each report)
 *      - No principal caching (always read from vault)
 *      - No unbounded arrays (use events for enumeration)
 *      - Uses SIMPLE INTEREST model: yield = principal × APY × time
 */
interface IYieldOracle {
    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event StrategyApySet(address indexed strategy, uint256 apyBps);
    event YieldReported(
        address indexed strategy, uint256 yield, uint256 principal, uint256 apyBps, uint256 timeElapsed
    );
    event LossReported(
        address indexed strategy, uint256 loss, uint256 principal, uint256 strategyDebt, uint256 timeElapsed
    );
    event MaxApyBpsUpdated(uint256 oldMax, uint256 newMax);
    event MinApyBpsUpdated(uint256 oldMin, uint256 newMin);
    event MinReportIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    // ═══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error InvalidAddress();
    error InvalidApy();
    error InvalidLoss();
    error NoYieldToReport();
    error ReportTooSoon();
    error StrategyNotConfigured();
    error StrategyNotAllowed();

    // ═══════════════════════════════════════════════════════════════════════
    // OPERATIONS FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Set the APY rate for a strategy.
     * @dev On first call for a strategy, initializes lastReportAt to current timestamp.
     *      APY must be within [minApyBps, maxApyBps] bounds.
     * @param strategy The strategy address
     * @param apyBps Annual yield rate in basis points (e.g., 500 = 5%)
     */
    function setStrategyApy(address strategy, uint256 apyBps) external;

    /**
     * @notice Disable a strategy (set APY to 0).
     * @dev Strategy can be re-enabled by calling setStrategyApy with non-zero APY.
     * @param strategy The strategy address
     */
    function disableStrategy(address strategy) external;

    // ═══════════════════════════════════════════════════════════════════════
    // REPORTER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Calculate and report yield for a single strategy to the vault.
     * @dev Reads fresh principal from vault, calculates yield, reports to vault.
     *      Reverts if strategy not configured or no yield to report.
     * @param strategy The strategy to report yield for
     * @return yield The amount of yield reported
     */
    function reportYield(address strategy) external returns (uint256 yield);

    /**
     * @notice Report a loss for a specific strategy to the vault.
     * @dev Updates lastReportAt to reset yield calculation baseline.
     *      All loss validations (amount, caps, windows) happen in vault.
     *      Requires strategy to be configured (APY > 0).
     * @param strategy The strategy that incurred the loss
     * @param loss The amount of loss to report
     */
    function reportLoss(address strategy, uint256 loss) external;

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Get pending yield for a specific strategy (not yet reported).
     * @param strategy The strategy address
     * @return Yield that would be reported if reportYield was called now
     */
    function getPendingYield(address strategy) external view returns (uint256);

    // Note: vault() getter is typed as IVaultForOracle in the contract
    // Use address(oracle.vault()) to get the address

    /**
     * @notice Get the maximum allowed APY in basis points.
     * @return Maximum APY bound
     */
    function maxApyBps() external view returns (uint256);

    /**
     * @notice Get the minimum allowed APY in basis points.
     * @return Minimum APY bound
     */
    function minApyBps() external view returns (uint256);

    /**
     * @notice Get the configured APY for a strategy.
     * @param strategy The strategy address
     * @return APY in basis points (0 if not configured or disabled)
     */
    function strategyApyBps(address strategy) external view returns (uint256);

    /**
     * @notice Get the timestamp of the last yield report for a strategy.
     * @param strategy The strategy address
     * @return Timestamp of last report (0 if never reported)
     */
    function lastReportAt(address strategy) external view returns (uint256);

    /**
     * @notice Get total yield reported to vault over lifetime.
     * @return Cumulative yield reported
     */
    function totalYieldReported() external view returns (uint256);

    /**
     * @notice Get total losses reported to vault over lifetime.
     * @return Cumulative losses reported
     */
    function totalLossReported() external view returns (uint256);

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Set the maximum allowed APY bound.
     * @param newMax New maximum APY in basis points (max 10_000 = 100%)
     */
    function setMaxApyBps(uint256 newMax) external;

    /**
     * @notice Set the minimum allowed APY bound.
     * @param newMin New minimum APY in basis points (must be <= maxApyBps)
     */
    function setMinApyBps(uint256 newMin) external;

    /**
     * @notice Get the minimum time between yield reports for any strategy.
     * @return Time in seconds
     */
    function minReportInterval() external view returns (uint256);

    /**
     * @notice Set the minimum time between yield reports for any strategy.
     * @dev Prevents rounding-to-zero DoS on the permissionless reportYield().
     *      Setting to 0 disables the check (NOT recommended).
     * @param newInterval Time in seconds. Recommended: 1 hours – 1 days.
     */
    function setMinReportInterval(uint256 newInterval) external;
}
