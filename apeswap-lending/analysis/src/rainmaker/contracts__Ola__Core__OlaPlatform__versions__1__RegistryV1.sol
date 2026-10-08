pragma solidity ^0.5.16;

import "../../Registry/RegistryInterface.sol";
import "../../Registry/RegistryStorage.sol";
import "../../Registry/Ministry.sol";
import "../../../LendingNetwork/Comptroller/ComptrollerInterface.sol";
import "../../../LendingNetwork/PriceOracle/PriceOracle.sol";

interface ICTokenForRegistryV1 {
    function underlying() external view returns (address);
}

interface OTokensFactoryForRegistry {
    function deployODelegator(
        address underlying,
        bytes32 contractNameHash,
        bytes calldata params,
        address comptroller,
        address interestRateModel,
        address admin,
        bytes calldata becomeImplementationData
    ) external returns (address);
}

interface PeripheralFactoryForRegistry {
    function deployPeripheryContract(bytes32 contractNameHash, address _comptroller, address _admin, bytes calldata params) external returns (address);
}

/**
 * @title Ola's Registry Contract V1
 * @author Ola
 */
contract RegistryV1 is RegistryV1Storage, RegistryV1Interface {
    /// @notice Emitted when an admin changes Ola reserve factor
    event NewOlaReserveFactor(uint oldOlaReserveFactorMantissa, uint newOlaReserveFactorMantissa);

    /// @notice Emitted when an admin changes Ola reserve factor
    event NewOlaBankAddress(address oldOlaBankAddress, address newOlaBankAddress);

    /// @notice Emitted when an admin changes the price oracle of an asset
    event NewOracleForAsset(address indexed asset, address indexed oldOracle, address indexed newOracle);

    /// @notice Emitted when an admin changes the factory for a peripheral contract
    event NewPeripheralFactory(bytes32 indexed contracNameHash, address indexed oldFactory, address indexed newFactory);

    /// @notice Emitted when Ola network publishes a new system version
    event OlaSystemVersionPublished(uint indexed systemVersion);

    /// @notice Emitted when Ola network publishes a new system version
    event OlaLatestSystemVersionUpdated(uint indexed oldLatestystemVersion, uint indexed newLatestystemVersion);

    /// @notice Emitted when a LeN has been registered
    event LendingNetworkRegistered(address indexed lnUnitroller, uint indexed systemVersion);

    /// @notice Emitted when a LeN has upgraded it's system version
    event LendingNetworkVersionUpdated(address indexed lnUnitroller, uint indexed oldVersion, uint indexed newVersion);

    /// @notice Emitted when a new OToken is deployed
    event OTokenDeployed(address indexed lendingNetwork, address indexed underlying, address oTokenAddress, address indexed admin);

    /// @notice Emitted when a new peripheral contract is deployed
    event PeripheralContractDeployed(address indexed lendingNetwork, address indexed admin, bytes32 indexed contracNameHash);

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
        return getPriceForAssetInternal(ICTokenForRegistryV1(cToken).underlying());
    }

    /*** Interest rate model ***/
    function isSupportedInterestRateModel(address interestRateModel) external view returns (bool) {
        return isInterestRateModelSupportedInternal(interestRateModel);
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

    /**
     * @notice Returns implementation address for the given contract name hash for the version of the given LeN
     */
    function getImplementationForLn(address lnUnitroller, bytes32 contractNameHash) external view returns (address) {
        uint256 lnSystemVersion = getLnVersion(lnUnitroller);

        require(isLnRegistered(lnUnitroller), "No version found");

        return getImplementation(lnSystemVersion, contractNameHash);
    }

    /**
     * @notice Returns the implementation address for the given contract name hash and system version
     */
    function getImplementation(uint256 systemVersion, bytes32 contractNameHash) public view returns (address) {
        return implementations[systemVersion][contractNameHash];
    }

    /**
     * @notice Returns the version that is associated with the given LeN
     */
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

    /**
     * @notice Called by the comptroller in order to create a new oToken instance.
     * @param underlying The asset to be managed by the created oToken
     * @param contractNameHash The hash of the wanted contract identifier
     * @param params Dynamic array to allow expansion of logic without interface change
     * @param interestRateModel The address for the wanted IRM
     * @param contractAdmin The admin address for the newly created oToken
     * @param becomeImplementationData Legacy byte array to pass to 'become implementation'
     */
    function deployOToken(address underlying,
        bytes32 contractNameHash,
        bytes calldata params,
        address interestRateModel,
        address contractAdmin,
        bytes calldata becomeImplementationData) external returns (address) {
        address lnUnitroller = msg.sender;

        // Only the Unitroller can ask for oToken deployment
        require(isLnRegistered(lnUnitroller), "Not Registered");

        // Must provide supported interest rate model
        require(isInterestRateModelSupportedInternal(interestRateModel), "IRM not supported");

        uint256 currentLnVersion = lnVersions[lnUnitroller];

        // Must be a supported contract name for current LeN current LeN version
        require(isContractNameHashSupportedForVersion(currentLnVersion, contractNameHash), "Contract not supported for LeN version");

        // Ensure the underlying is supported (has price oracle)
        require(isAssetSupported(underlying), "Asset not supported");

        address oTokensFactory = tokenFactories[currentLnVersion];
        require(oTokensFactory != address(0), "No OTokensFactory found");

        address deployedOToken =  OTokensFactoryForRegistry(oTokensFactory).deployODelegator(underlying, contractNameHash, params, lnUnitroller, interestRateModel, contractAdmin, becomeImplementationData);

        emit OTokenDeployed(lnUnitroller, underlying, deployedOToken, contractAdmin);

        return deployedOToken;
    }

    /**
     * @notice Called by the comptroller in order to create a new peripheral contract instance.
     * @param contractNameHash The hash of the wanted contract identifier
     * @param params Dynamic array to allow expansion of logic without interface change
     * @param contractAdmin The admin address for the newly created contract
     */
    function deployPeripheralContract(bytes32 contractNameHash,
        bytes calldata params,
        address contractAdmin) external returns (address) {
        address lnUnitroller = msg.sender;

        // Only the Unitroller can ask for a peripheral contract deployment
        require(isLnRegistered(lnUnitroller), "Not Registered");

        address peripheralFactory = peripheralFactories[contractNameHash];
        require(peripheralFactory != address(0), "No peripheral factory found");

        address deployedPeripheralContract = PeripheralFactoryForRegistry(peripheralFactory).deployPeripheryContract(contractNameHash, lnUnitroller, contractAdmin, params);

        emit PeripheralContractDeployed(lnUnitroller, contractAdmin, contractNameHash);

        return deployedPeripheralContract;
    }

    /*** Initialization functions ***/
    function _become(Ministry ministry) public {
        require(msg.sender == ministry.admin(), "only Ministry admin can change brains");
        require(ministry._acceptImplementation() == 0, "change not authorized");
    }

    /*** Admin functions ***/

    function publishNewSystemVersion(uint256 systemVersion, bytes32[] calldata contractNameHashes, address[] calldata contractImplementations, address oTokensFactory) external {
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

        // Set the OTokens Factory
        require(oTokensFactory != address(0), "Must have oTokens factory");
        tokenFactories[systemVersion] = oTokensFactory;

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

    function registerNewLnInternal(address lnUnitroller) internal {
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
        // TODO : Add price fetching check
        require(msg.sender == admin, "Not Admin");

        address oldOracle = priceOracles[asset];

        priceOracles[asset] = oracleAddress;

        emit NewOracleForAsset(asset, oldOracle, oracleAddress);

        return true;
    }

    function setFactoryForPeripheralContract(bytes32 contractNameHash, address factory) external returns (bool) {
        require(msg.sender == admin, "Not Admin");

        address oldFactory = peripheralFactories[contractNameHash];

        peripheralFactories[contractNameHash] = factory;

        emit NewPeripheralFactory(contractNameHash, oldFactory, factory);

        return true;
    }

    function setSupportedInterestRateModel(address interestRateModel) external returns (bool) {
        require(msg.sender == admin, "Not Admin");

        supportedInterestRateModels[interestRateModel] = true;

        return true;
    }

    function removeSupportedInterestRateModel(address interestRateModel) external returns (bool) {
        require(msg.sender == admin, "Not Admin");
        require(supportedInterestRateModels[interestRateModel], "IRM is not supported");

        supportedInterestRateModels[interestRateModel] = false;

        return true;
    }

    /*** Util checkers ***/

    /**
     * @notice Asset is considered supported if it has a price oracle
     */
    function isAssetSupported(address asset) public view returns (bool) {
        return priceOracles[asset] != address(0);
    }

    /**
     * @notice Check if the given contract name hash is supported for the given version
     */
    function isContractNameHashSupportedForVersion(uint systemVersion, bytes32 contractNameHash) public view returns (bool) {
        return implementations[systemVersion][contractNameHash] != address(0);
    }

    function isInterestRateModelSupportedInternal(address interestRateModel) internal view returns (bool) {
        return supportedInterestRateModels[interestRateModel];
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
