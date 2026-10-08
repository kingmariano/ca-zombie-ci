// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../ErrorReporter/ErrorReporter.sol";
import "./ComptrollerStorage.sol";

interface RegistryForUnitroller {
    function getImplementationForLn(address lnUnitroller, bytes32 contractNameHash) external returns (address);
    function getLnVersion(address lnUnitroller) external returns (uint256);
    function updateLnVersion(uint256 newVersion) external returns (bool);
}

/**
 * @title ComptrollerCore
 * @dev Storage for the Comptroller is at this address, while execution is delegated to the `comptrollerImplementation`.
 * CTokens should reference this contract as their Comptroller.
 */
contract Unitroller is UnitrollerAdminStorage, ComptrollerErrorReporter {
    /**
     * @notice Emitted when pendingComptrollerImplementation is accepted, which means Comptroller implementation is updated
     */
    event NewImplementation(address indexed oldImplementation, address indexed newImplementation);

    /**
     * @notice Emitted when implementation is not changed under a system version update
     */
    event ImplementationDidNotChange(address indexed implementation);

    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor(address registry_) public {
        // Set admin to caller
        admin = msg.sender;

        // Set once and do not change
        registry = registry_;
    }

    /**
     * OLA_ADDITIONS : This function.
     * Should be registered before calling this function.
     */
    function initialize() external {
        require(msg.sender == admin, "Not Admin");
        require(implementation == address(0), "Already initialized");

        address comptrollerImplementation = RegistryForUnitroller(address(registry)).getImplementationForLn(address(this), unitrollerContractHash);

        implementation = comptrollerImplementation;
    }

    /*** Admin Functions ***/

    /**
     * @notice Updates the LN to the given version. And then refreshes implementation addresses from the Registry
     * for this contract (unitroller) and for all markets (OTokenDelegators)
     * @dev Admin function to update version on LN
     * @return uint true=success, otherwise a failure (Will revert on failure)
     */
    function _upgradeLnSystemVersion(uint256 newSystemVersion, bytes calldata becomeImplementationData) external returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.UPDATE_LN_VERSION_ADMIN_OWNER_CHECK);
        }

        // Update Version
        bool updateSuccessful = RegistryForUnitroller(registry).updateLnVersion(newSystemVersion);
        require(updateSuccessful, "Version update failed");

        // First, update the implementation used by the unitroller
        address comptrollerImplementation = RegistryForUnitroller(registry).getImplementationForLn(address(this), unitrollerContractHash);

        if (comptrollerImplementation != implementation) {
            address oldImplementation = implementation;
            implementation = comptrollerImplementation;
            emit NewImplementation(oldImplementation, implementation);
        } else {
            emit ImplementationDidNotChange(implementation);
        }

        // Update all of the implementation addresses
        delegateToImplementation(abi.encodeWithSignature("updateDelegatedImplementations(bytes)", becomeImplementationData));

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_ADMIN_OWNER_CHECK);
        }

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || pendingAdmin == address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
        }

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementation(bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = implementation.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return returnData;
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function () payable external {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize)

              switch success
              case 0 { revert(free_mem_ptr, returndatasize) }
              default { return(free_mem_ptr, returndatasize) }
        }
    }
}
