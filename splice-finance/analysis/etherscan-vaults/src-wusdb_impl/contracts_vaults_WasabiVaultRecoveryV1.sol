// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./WasabiVault.sol";

/// @title WasabiVaultRecoveryV1
/// @notice Minimal upgrade impl for the WasabiVault contracts that were drained on 2026-04-30.
///         Inherits the existing WasabiVault unchanged and adds a single one-shot
///         reinitializer that migrates the strategyDebt entry from the attacker's
///         malicious strategy address to a fresh team-controlled RecoveryStrategy.
///
///         Design notes:
///         - No new storage. The reinitializer mechanism (OZ Initializable) tracks
///           the version counter in the existing namespaced Initializable slot.
///         - No new always-callable surface. `initializeRecovery` can only run
///           when called atomically with `upgradeToAndCall(this, encodeCall(initializeRecovery, ...))`,
///           and only once per vault (reinitializer counter advances).
///         - No tokens move during migration. Pure bookkeeping update of the
///           `strategyDebt` mapping.
///
///         Deployment flow (per chain):
///         1. Deploy this implementation contract.
///         2. Deploy a RecoveryStrategy per drained vault (one each, vault-bound).
///         3. Multisig calls `PerpManager.upgradeVaults(this, [vaults...], [calls...])`
///            where each `calls[i]` is `abi.encodeCall(initializeRecovery, (malicious, recovery_i))`.
///         4. Verify post-state: strategyDebt[malicious] == 0, strategyDebt[recovery] == prior_debt.
contract WasabiVaultRecoveryV1 is WasabiVault {
    /// @dev Emitted when strategy debt is migrated from a (malicious) strategy address to
    ///      a fresh recovery strategy contract. Amount is the balance moved.
    event StrategyDebtMigrated(address indexed from, address indexed to, uint256 amount);

    error NoDebtToMigrate();
    error InvalidMigrationAddress();

    /// @notice One-shot debt migration. Reassigns `strategyDebt[from]` to `strategyDebt[to]`
    ///         without moving any tokens. Intended to redirect a malicious-strategy debt entry
    ///         to a team-controlled RecoveryStrategy so that recovered funds can be routed
    ///         back to the vault via the existing strategyWithdraw() path.
    /// @dev    `reinitializer(2)` gates this to a single execution after the original
    ///         `initialize()` (which leaves Initializable._initialized == 1).
    ///
    ///         If a vault has previously been reinitialized to a higher version, the
    ///         deployer must redeploy this contract with a higher reinitializer constant
    ///         (e.g., reinitializer(N+1) where N is the current `_initialized` value).
    ///         The deployment script reads the current value on each vault and aborts if
    ///         it cannot use reinitializer(2). Override the constant only after verifying.
    ///
    ///         `onlyAdmin` is redundant given the reinitializer gate (you can only enter
    ///         this function via `upgradeToAndCall`, which requires `_authorizeUpgrade`'s
    ///         own `onlyAdmin`), but is kept for defense-in-depth and explicit intent.
    /// @param from The address whose existing strategyDebt entry to clear.
    /// @param to   The address to receive the strategyDebt entry. Must be a deployed
    ///             RecoveryStrategy (or other team-controlled IStrategy) bound to this vault.
    function initializeRecovery(address from, address to) external reinitializer(2) onlyAdmin {
        if (from == address(0) || to == address(0) || from == to) {
            revert InvalidMigrationAddress();
        }
        uint256 debt = strategyDebt[from];
        if (debt == 0) revert NoDebtToMigrate();

        strategyDebt[from] = 0;
        strategyDebt[to]   = debt;

        emit StrategyDebtMigrated(from, to, debt);
    }
}
