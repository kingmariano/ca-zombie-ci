// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IOffchainBtcVault} from "./IOffchainBtcVault.sol";

/**
 * @title IStBTCReserve
 * @notice Interface for StBTC to expose parameters to OffchainBtcVault.
 * @dev Used by OffchainBtcVault to validate cross-contract consistency during setStBTC.
 *      Returns IOffchainBtcVault type (which is implicitly convertible to address) to match
 *      StBTC's auto-generated getter from the public vault variable.
 */
interface IStBTCReserve {
    /**
     * @notice Returns the vault contract that StBTC is configured to use.
     * @return The OffchainBtcVault contract interface (implicitly convertible to address).
     */
    function vault() external view returns (IOffchainBtcVault);
}
