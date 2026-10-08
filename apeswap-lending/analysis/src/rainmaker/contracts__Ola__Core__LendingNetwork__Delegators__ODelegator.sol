pragma solidity ^0.5.16;

import "../OTokens/CTokenInterfaces.sol";
import "../OTokens/CToken.sol";

interface RegistryForODelegator {
    function getImplementationForLn(address lnUnitroller, bytes32 contractNameHash) external returns (address);
}

/**
 * @title Ola's ODelegator Contract
 * @notice OTokens which delegate to an implementation
 * @author Ola
 */
contract ODelegator is CTokenAdminStorage, CTokenDelegatorInterface {

    /**
     * @notice Called by the Comptroller (most of the time) or by the admin (only via the constructor) to update the
     *         implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) internal {
        if (allowResign) {
            delegateToImplementation(abi.encodeWithSignature("_resignImplementation()"));
        }

        // Basic sanity
        require(CToken(implementation_).isCToken(), "Not CTokens");

        address oldImplementation = implementation;
        implementation = implementation_;


        delegateToImplementation(abi.encodeWithSignature("_becomeImplementation(bytes)", becomeImplementationData));

        emit NewImplementation(oldImplementation, implementation);
    }

    /**
     * @notice Internal method to delegate execution to another contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param callee The contract to delegatecall
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return returnData;
    }

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementation(bytes memory data) public returns (bytes memory) {
        return delegateTo(implementation, data);
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     *  There are an additional 2 prefix uints from the wrapper returndata, which we ignore since we make an extra hop.
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToViewImplementation(bytes memory data) public view returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).staticcall(abi.encodeWithSignature("delegateToImplementation(bytes)", data));
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return abi.decode(returnData, (bytes));
    }

    function updateImplementationFromRegistry(bool allowResign, bytes calldata becomeImplementationData) external returns (bool) {
        require(msg.sender == address(comptroller), "Not comptroller");
        address implementationToSet = RegistryForODelegator(comptroller.getRegistry()).getImplementationForLn(address(comptroller), contractNameHash);
        require(implementationToSet != address(0), "No implementation");

        if (implementationToSet != implementation) {
            // New implementations always get set via the setter (post-initialize)
            _setImplementation(implementationToSet, allowResign, becomeImplementationData);
        } else {
            emit ImplementationDidNotChange(implementation);
        }

        return true;
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     */
    function () external payable {
        require(msg.value == 0,"ODelegator:fallback: cannot send value to fallback");

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
