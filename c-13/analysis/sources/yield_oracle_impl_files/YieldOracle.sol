// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IYieldOracle} from "./interfaces/IYieldOracle.sol";

interface IVaultForOracle {
    function strategyPrincipal(address strategy) external view returns (uint256);
    function strategyDebt(address strategy) external view returns (uint256);
    function isStrategyAllowed(address strategy) external view returns (bool);
    function reportYield(address strategy, uint256 addedYield) external;
    function reportLoss(address strategy, uint256 loss) external;
}

/**
 * @title YieldOracle (Minimal)
 * @notice Calculates per-strategy yield using simple interest and reports to vault.
 * @dev Design priorities: SIMPLICITY and SECURITY
 *      - No state accumulation (calculate fresh each report)
 *      - No principal caching (always read from vault)
 *      - No unbounded arrays (use events for enumeration)
 *      - Minimum report interval prevents rounding-to-zero DoS
 *      - Vault caps provide defense in depth
 */
contract YieldOracle is Initializable, AccessControlUpgradeable, ReentrancyGuard, UUPSUpgradeable, IYieldOracle {
    bytes32 public constant OPERATIONS_ROLE = keccak256("OPERATIONS_ROLE");

    IVaultForOracle public vault;
    uint256 public maxApyBps;
    uint256 public minApyBps;

    // Minimal per-strategy state
    mapping(address => uint256) public strategyApyBps;
    mapping(address => uint256) public lastReportAt;

    /// @notice Minimum time (seconds) between yield reports for any strategy.
    /// @dev Prevents rounding-to-zero DoS: without this, an attacker can call the
    ///      permissionless reportYield() every block, resetting lastReportAt each time.
    ///      When timeElapsed is tiny the integer division rounds yield to 0, so no yield
    ///      ever accrues.  A floor of e.g. 1 hour makes the attack uneconomical.
    uint256 public minReportInterval;

    // Tracking (optional, for transparency)
    uint256 public totalYieldReported;
    uint256 public totalLossReported;

    // NOTE: No __gap needed - OZ v5.x uses ERC-7201 namespaced storage

    // Events and Errors are inherited from IYieldOracle

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address operations, address vaultAddress, uint256 maxApy) public initializer {
        __AccessControl_init();
        if (admin == address(0) || operations == address(0) || vaultAddress == address(0)) {
            revert InvalidAddress();
        }
        if (maxApy > 10_000) revert InvalidApy();

        vault = IVaultForOracle(vaultAddress);
        maxApyBps = maxApy;
        minApyBps = 0; // Explicit initialization
        minReportInterval = 1 hours; // Default: prevent rounding-to-zero DoS

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATIONS_ROLE, operations);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ═══════════════════════════════════════════════════════════════════════
    // OPERATIONS: Configure strategy APY rates
    // ═══════════════════════════════════════════════════════════════════════

    function setStrategyApy(address strategy, uint256 apyBps) external onlyRole(OPERATIONS_ROLE) {
        if (strategy == address(0)) revert InvalidAddress();
        if (apyBps < minApyBps || apyBps > maxApyBps) revert InvalidApy();

        strategyApyBps[strategy] = apyBps;

        // Initialize timestamp on first configuration
        if (lastReportAt[strategy] == 0) {
            lastReportAt[strategy] = block.timestamp;
        }

        emit StrategyApySet(strategy, apyBps);
    }

    function disableStrategy(address strategy) external onlyRole(OPERATIONS_ROLE) {
        strategyApyBps[strategy] = 0;
        emit StrategyApySet(strategy, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PUBLIC: Calculate and report yield (permissionless)
    // ═══════════════════════════════════════════════════════════════════════

    function reportYield(address strategy) external nonReentrant returns (uint256 yield) {
        uint256 apyBps = strategyApyBps[strategy];
        if (apyBps == 0) revert StrategyNotConfigured();
        if (!vault.isStrategyAllowed(strategy)) revert StrategyNotAllowed();

        // Calculate time elapsed since last report
        uint256 timeElapsed = block.timestamp - lastReportAt[strategy];

        // Enforce minimum interval to prevent rounding-to-zero DoS.
        // Without this check an attacker can call every block, keep timeElapsed tiny,
        // and the integer division below rounds yield to 0 — permanently blocking accrual.
        if (timeElapsed < minReportInterval) revert ReportTooSoon();

        // Always read fresh principal from vault (no sync needed)
        uint256 principal = vault.strategyPrincipal(strategy);

        if (principal == 0) revert NoYieldToReport();

        // Simple interest: yield = principal × APY × time
        yield = (principal * apyBps * timeElapsed) / (10_000 * 365 days);

        if (yield > 0) {
            // Vault enforces window-based limits and BPS caps
            vault.reportYield(strategy, yield);
            totalYieldReported += yield;

            // Only reset timestamp when yield is actually reported.
            // If yield rounds to 0 (shouldn't happen with minReportInterval, but defense
            // in depth), we preserve lastReportAt so time continues to accumulate.
            lastReportAt[strategy] = block.timestamp;
        }

        emit YieldReported(strategy, yield, principal, apyBps, timeElapsed);
    }

    function reportLoss(address strategy, uint256 loss) external onlyRole(OPERATIONS_ROLE) nonReentrant {
        uint256 apyBps = strategyApyBps[strategy];
        if (apyBps == 0) revert StrategyNotConfigured();
        if (!vault.isStrategyAllowed(strategy)) revert StrategyNotAllowed();
        if (loss == 0) revert InvalidLoss();

        // Calculate time elapsed for event
        uint256 timeElapsed = block.timestamp - lastReportAt[strategy];

        // Read current values from vault for event context
        uint256 principal = vault.strategyPrincipal(strategy);

        // Report loss to vault (vault handles all validations: caps, windows, etc.)
        vault.reportLoss(strategy, loss);

        // Update tracking and reset yield calculation
        totalLossReported += loss;
        lastReportAt[strategy] = block.timestamp;

        // Read updated debt after loss for event
        uint256 newStrategyDebt = vault.strategyDebt(strategy);

        emit LossReported(strategy, loss, principal, newStrategyDebt, timeElapsed);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW: Query pending yield
    // ═══════════════════════════════════════════════════════════════════════

    function getPendingYield(address strategy) external view returns (uint256) {
        uint256 apyBps = strategyApyBps[strategy];
        if (apyBps == 0) return 0;

        uint256 principal = vault.strategyPrincipal(strategy);
        uint256 timeElapsed = block.timestamp - lastReportAt[strategy];
        if (principal == 0 || timeElapsed == 0) return 0;

        return (principal * apyBps * timeElapsed) / (10_000 * 365 days);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN: Configure bounds
    // ═══════════════════════════════════════════════════════════════════════

    function setMaxApyBps(uint256 newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMax > 10_000) revert InvalidApy();
        emit MaxApyBpsUpdated(maxApyBps, newMax);
        maxApyBps = newMax;
    }

    function setMinApyBps(uint256 newMin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMin > maxApyBps) revert InvalidApy();
        emit MinApyBpsUpdated(minApyBps, newMin);
        minApyBps = newMin;
    }

    /**
     * @notice Sets the minimum time between yield reports for any strategy.
     * @dev Prevents rounding-to-zero DoS on the permissionless reportYield().
     *      Setting to 0 disables the check (NOT recommended).
     * @param newInterval Time in seconds. Recommended: 1 hours – 1 days.
     */
    function setMinReportInterval(uint256 newInterval) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit MinReportIntervalUpdated(minReportInterval, newInterval);
        minReportInterval = newInterval;
    }
}
