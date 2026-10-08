// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

contract RegistryBaseInterface {
    /// @notice Indicator that this is a Registry contract (for inspection)
    bool public constant isRegistry = true;

    /*** Interest rate model ***/
    function isSupportedInterestRateModel(address interestRateModel) external view returns (bool);

    /*** Price oracles ***/
    function getOracleForAsset(address asset) external view returns (address);
    function getPriceForAsset(address asset) external view returns (uint256);
    function getPriceForUnderling(address cToken) external view returns (uint256);

    /*** Versions and implementations ***/
    function isSystemVersionSupported(uint256 systemVersion) public view returns (bool);
    function isLnRegistered(address lnUnitroller) external view  returns (bool);
    function getImplementationForLn(address lnUnitroller, bytes32 contractNameHash) external view returns (address);
    function getImplementation(uint256 systemVersion, bytes32 contractNameHash) external view returns (address);
    function getLnVersion(address lnUnitroller) public view returns (uint256);

    /*** LN Admin functions ***/
    function updateLnVersion(uint256 newVersion) external returns (bool);
}

contract RegistryV0Interface is RegistryBaseInterface {
    /*** Admin functions ***/
    function publishNewSystemVersion(uint256 systemVersion, bytes32[] calldata contractNameHashes, address[] calldata implementations) external;
    function registerNewLn(address lnUnitroller) external;
    function setOlaBankAddress(address olaAddress_) external;
    function setOlaReserveFactorMantissa(uint256 olaReserveFactorMantissa_) external;
    function setOracleForAsset(address asset, address oracleAddress) external returns (bool);
    function setSupportedInterestRateModel(address interestRateModel) external returns (bool);
}

contract RegistryV1Interface is RegistryBaseInterface {
    /*** LN Admin functions ***/
    function deployOToken(address underlying,
        bytes32 contractNameHash,
        bytes calldata params,
        address interestRateModel,
        address admin,
        bytes calldata becomeImplementationData) external returns (address);

    /*** Admin functions ***/
    // Note : Replaced on V1.1
    // function publishNewSystemVersion(uint256 systemVersion, bytes32[] calldata contractNameHashes, address[] calldata implementations, address oTokensFactory) external;
    function registerNewLn(address lnUnitroller) external;
    function setOlaBankAddress(address olaAddress_) external;
    function setOracleForAsset(address asset, address oracleAddress) external returns (bool);
    function setSupportedInterestRateModel(address interestRateModel) external returns (bool);
}

contract RegistryV1_1Interface is RegistryV1Interface {
    enum VersionedContractType { None, Unitroller, CToken, CompoundingStakeable, RewardingStakeable}

    function publishNewSystemVersion(uint256 systemVersion,
        bytes32[] calldata contractNameHashes, address[] calldata contractImplementations, VersionedContractType[] calldata contractTypes,
        address oTokensFactory) external;

    function olaBankAddress() external view returns (address);
    function olaBankAddressForTarget(address target) external view returns (address);
    function hasCustomBankAddress(address target) external view returns (bool);

    function isStakingTargetAllowed(bytes32 contractNameHash, address asset, address stakingTarget) external view returns (bool);
}