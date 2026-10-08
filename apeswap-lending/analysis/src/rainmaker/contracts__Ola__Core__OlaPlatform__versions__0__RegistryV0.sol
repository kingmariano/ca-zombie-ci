pragma solidity ^0.5.16;

import "../../Registry/RegistryInterface.sol";
import "../../Registry/RegistryStorage.sol";
import "../../Registry/Ministry.sol";
import "../../../LendingNetwork/Comptroller/ComptrollerInterface.sol";
import "../../../LendingNetwork/PriceOracle/PriceOracle.sol";

interface ICTokenForRegistryV0 {
    function underlying() external view returns (address);
}

/**
 * @title Ola's Registry Contract
 * @author Ola
 */
contract RegistryV0 is RegistryV0Storage, RegistryV0Interface {
    /// @notice Emitted when an admin changes Ola reserve factor
    event NewOlaReserveFactor(uint oldOlaReserveFactorMantissa, uint newOlaReserveFactorMantissa);

    /// @notice Emitted when an admin changes Ola reserve factor
    event NewOlaBankAddress(address oldOlaBankAddress, address newOlaBankAddress);

    /// @notice Emitted when an admin changes the price oracle of an asset
    event NewOracleForAsset(address indexed asset, address indexed oldOracle, address indexed newOracle);

    /// @notice Emitted when Ola network publishes a new system version
    event OlaSystemVersionPublished(uint indexed systemVersion);

    /// @notice Emitted when Ola network publishes a new system version
    event OlaLatestSystemVersionUpdated(uint indexed oldLatestystemVersion, uint indexed newLatestystemVersion);

    /// @notice Emitted when a LeN has been registered
    event LendingNetworkRegistered(address indexed lnUnitroller, uint indexed systemVersion);

    /// @notice Emitted when a LeN has upgraded it's system version
    event LendingNetworkVersionUpdated(address indexed lnUnitroller, uint indexed oldVersion, uint indexed newVersion);



    constructor() public {
        admin = msg.sender;
    }

    /*** Price oracles ***/

    /**
     * Returns the oracle address for the given asset
     */
    function getOracleForAsset(address asset) external view returns (address) {
        return priceOracles[asset];
    }

    /**
     * Returns the oracle price for the given asset
     */
    function getPriceForAsset(address asset) external view returns (uint256) {
        return getPriceForAssetInternal(asset);
    }

    /**
     * Returns the oracle price for the given cToken's underlying asset
     */
    function getPriceForUnderling(address cToken) external view returns (uint256) {
        return getPriceForAssetInternal(ICTokenForRegistryV0(cToken).underlying());
    }

    /*** Interest rate model ***/
    function isSupportedInterestRateModel(address interestRateModel) external view returns (bool) {
        return supportedInterestRateModels[interestRateModel];
    }

    /*** Versions and implementations ***/

    /**
     *
     */
    function isSystemVersionSupported(uint256 systemVersion) public view returns (bool) {
        return supportedSystemVersions[systemVersion];
    }

    function isLnRegistered(address lnUnitroller) public view returns (bool) {
        return lnVersions[lnUnitroller] != 0;
    }

    function getImplementationForLn(address lnUnitroller, bytes32 contractNameHash) external view returns (address) {
        uint256 lnSystemVersion = getLnVersion(lnUnitroller);

        require(isLnRegistered(lnUnitroller), "No version found");

        return getImplementation(lnSystemVersion, contractNameHash);
    }

    function getImplementation(uint256 systemVersion, bytes32 contractNameHash) public view returns (address) {
        return implementations[systemVersion][contractNameHash];
    }

    function getLnVersion(address lnUnitroller) public view returns (uint256) {
        return lnVersions[lnUnitroller];
    }

    /*** LN Admin functions ***/

    function updateLnVersion(uint256 newVersion) external returns (bool) {
        address lnUnitroller = msg.sender;

        // Only the Unitroller can update itself
        require(isLnRegistered(lnUnitroller), "Not Registered");

        // Ensure valid version
        require(isSystemVersionSupported(newVersion), "Wrong Version");

        // Only going forward
        uint256 currentLnVersion = lnVersions[lnUnitroller];
        require(currentLnVersion < newVersion, "Only going forward");

        // Ensure it is in range
        require(newVersion <= latestSystemVersion, "Too high version");

        // Finally, update the ln version
        return updateLnVersionInternal(lnUnitroller, newVersion);
    }

    /*** Initialization functions ***/
    function _become(Ministry ministry) public {
        require(msg.sender == ministry.admin(), "only Ministry admin can change brains");
        require(ministry._acceptImplementation() == 0, "change not authorized");
    }

    /*** Admin functions ***/

    function publishNewSystemVersion(uint256 systemVersion, bytes32[] calldata contractNameHashes, address[] calldata contractImplementations) external {
        require(msg.sender == admin, "Not Admin");
        require(contractNameHashes.length == contractImplementations.length, "Arrays must be 1:1");

        require(!supportedSystemVersions[systemVersion], "Already published");

        // Adds the flag.
        supportedSystemVersions[systemVersion] = true;

        // Set the implementations
        for (uint i = 0; i < contractNameHashes.length; i++) {
            bytes32 contractNameHash = contractNameHashes[i];
            address contractImplementation = contractImplementations[i];

            implementations[systemVersion][contractNameHash] = contractImplementation;
        }

        if (systemVersion > latestSystemVersion) {
            uint oldLatestSystemVersion  = latestSystemVersion;
            latestSystemVersion = systemVersion;
            emit OlaLatestSystemVersionUpdated(oldLatestSystemVersion, latestSystemVersion);
        }

        emit OlaSystemVersionPublished(systemVersion);
    }


    function registerNewLn(address lnUnitroller) external {
        require(msg.sender == admin, "Not Admin");
        require(lnUnitroller != address(0), "Empty unitroller");
        require(!isLnRegistered(lnUnitroller), "Already registered");

        registerNewLnInternal(lnUnitroller);
    }

    function setOlaBankAddress(address olaBankAddress_) external {
        require(msg.sender == admin, "Not admin");
        address oldOlaBankAddress = olaBankAddress;
        olaBankAddress = olaBankAddress_;
        emit NewOlaBankAddress(oldOlaBankAddress, olaBankAddress);
    }

    function setOlaReserveFactorMantissa(uint256 olaReserveFactorMantissa_) external {
        require(msg.sender == admin, "Not admin");
        uint oldOlaReservesFactorMantissa = olaReservesFactorMantissa;
        olaReservesFactorMantissa = olaReserveFactorMantissa_;
        emit NewOlaReserveFactor(oldOlaReservesFactorMantissa, olaReservesFactorMantissa);
    }

    function registerNewLnInternal(address lnUnitroller) internal {
        uint256 latestSystemVersion = latestSystemVersion;

        lnVersions[lnUnitroller] = latestSystemVersion;

        emit LendingNetworkRegistered(lnUnitroller, latestSystemVersion);
    }

    function updateLnVersionInternal(address lnUnitroller, uint256 newVersion) internal returns (bool) {
        uint previousVersion = lnVersions[lnUnitroller];

        lnVersions[lnUnitroller] = newVersion;

        emit LendingNetworkVersionUpdated(lnUnitroller, previousVersion, newVersion);

        return true;
    }

    function setOracleForAsset(address asset, address oracleAddress) external returns (bool) {
        require(msg.sender == admin, "Not Admin");

        address oldOracle = priceOracles[asset];

        priceOracles[asset] = oracleAddress;

        emit NewOracleForAsset(asset, oldOracle, oracleAddress);

        return true;
    }

    function setSupportedInterestRateModel(address interestRateModel) external returns (bool) {
        require(msg.sender == admin, "Not Admin");

        supportedInterestRateModels[interestRateModel] = true;

        return true;
    }

    /**
     * Fetches the oracle price for the given asset (Or 0 if no oracle is defined)
     */
    function getPriceForAssetInternal(address asset) internal view returns (uint256) {
        address priceOracle = priceOracles[asset];

        if (priceOracle != address(0)) {
            return PriceOracle(priceOracle).getAssetPrice(asset);
        } else {
            return 0;
        }
    }
}
