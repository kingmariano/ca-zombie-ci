// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../CErc20V0_05.sol";

/**
 * @title Ola's CErc20Delegate V0_05 Contract
 * @notice OTokens which wrap an EIP-20 underlying and are delegated to
 * @author Ola
 */
contract CErc20DelegateV0_05 is CErc20V0_05, CDelegateInterface {
    /**
     * @notice Construct an empty delegate
     */
    constructor() public {}

    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) public {
        // Shh -- currently unused
        data;

        // Shh -- we don't ever want this hook to be marked pure
        if (false) {
            implementation = address(0);
        }

        // OLA_ADDITION : The 'or Comptroller'
        // The only time where msg.sender is the admin is during construction of the 'delegator' contract
        require(msg.sender == admin || msg.sender == address(comptroller), "only the admin and comptroller may call _becomeImplementation");
    }

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() public {
        // Shh -- we don't ever want this hook to be marked pure
        if (false) {
            implementation = address(0);
        }

        // OLA_ADDITION : Was 'only admin'. Now, 'only Comptroller'
        require(msg.sender == address(comptroller), "only the comptroller may call _resignImplementation");
    }
}
