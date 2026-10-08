pragma solidity ^0.5.16;

interface IComptrollerPeripheral {
    /**
     * Called when the contract is connected to the comptroller
     */
    function connect(bytes calldata params) external;

    /**
     * Called when the contract is disconnected from the comptroller
     */
    function retire(bytes calldata params) external;
}