// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IOffchainBtcVault
 * @notice Interface for the OffchainBtcVault contract used by StBTC.
 */
interface IOffchainBtcVault {
    /**
     * @notice Returns the available WBTC balance in the vault.
     * @return The available WBTC balance.
     */
    function availableBalance() external view returns (uint256);

    /**
     * @notice Returns total assets under management (on-chain + off-chain).
     * @dev This is the single source of truth for all value calculations.
     * @return Total WBTC value managed by the vault
     */
    function totalManagedAssets() external view returns (uint256);

    /**
     * @notice Returns the minimum liquidity basis points.
     * @return The minimum on-chain liquidity as basis points.
     */
    function minLiquidityBps() external view returns (uint256);

    /**
     * @notice Returns the off-chain balance.
     * @return The balance deployed to off-chain strategies.
     */
    function offchainBalance() external view returns (uint256);

    /**
     * @notice Accepts WBTC deposits from StBTC contract.
     * @param amount The amount of WBTC deposited.
     */
    function depositFromStBTC(uint256 amount) external;

    /**
     * @notice Withdraws WBTC to a user (instant withdrawal).
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function withdrawToUser(address to, uint256 amount) external;
}
