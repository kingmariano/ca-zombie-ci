pragma solidity ^0.5.16;

contract UnistryAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of Ministry
    */
    address public implementation;

    /**
    * @notice Pending brains of Ministry
    */
    address public pendingImplementation;

    // Indicates if calculations should be block based or time based
    bool public blocksBased;
}

contract RegistryV0Storage is UnistryAdminStorage {
    // The address to send the 'Ola Part' when reducing reserves.
    address public olaBankAddress;

    // Part of reserves that are allocated to Ola (Deprecated)
    uint256 public olaReservesFactorMantissa;

    // Asset address -> Price oracle address
    mapping(address => address) public priceOracles;

    // The latest system version
    uint256 public latestSystemVersion;

    // Unitroller address -> System version (MAX_INT means always take latest)
    mapping(address => uint256) public lnVersions;

    // System version -> (contract name hash -> implementation)
    mapping(uint256 => mapping(bytes32 => address)) public implementations;

    // System versions => isSupported
    mapping(uint256 => bool) public supportedSystemVersions;

    // Interest rate model address => isSupported
    mapping(address => bool) public supportedInterestRateModels;
}

contract RegistryV1Storage is RegistryV0Storage {
    // System version -> OTokens Factory
    mapping(uint256 => address) public tokenFactories;

    // Contract name hash => Contract factory
    mapping(bytes32 => address) public peripheralFactories;
}
