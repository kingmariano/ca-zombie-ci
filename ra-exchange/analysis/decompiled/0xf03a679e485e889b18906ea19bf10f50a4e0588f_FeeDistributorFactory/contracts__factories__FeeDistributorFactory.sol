// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./../interfaces/IFeeDistributor.sol";

contract FeeDistributorFactory is IBeacon, Initializable {
    address public lastFeeDistributor;
    address public implementation;
    address public owner;

    /// @notice Emitted when pairs implementation is changed
    /// @param oldImplementation The previous implementation
    /// @param newImplementation The new implementation
    event ImplementationChanged(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _implementation
    ) external initializer {
        owner = _owner;
        implementation = _implementation;
        emit OwnerChanged(address(0), _owner);
        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("setDelegationForSelf(address)", _owner)
        );
        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("disableSelfManagingDelegations()")
        );
    }

    function createFeeDistributor(address pairFees) external returns (address) {
        lastFeeDistributor = address(
            new BeaconProxy(
                address(this),
                abi.encodeWithSelector(
                    IFeeDistributor.initialize.selector,
                    msg.sender,
                    pairFees
                )
            )
        );

        return lastFeeDistributor;
    }

    function setImplementation(address _implementation) external {
        require(msg.sender == owner, "AUTH");
        emit ImplementationChanged(implementation, _implementation);
        implementation = _implementation;
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, "AUTH");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
}
