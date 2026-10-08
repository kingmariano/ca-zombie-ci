// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../../Registry/RegistryInterface.sol";
import "../../Registry/RegistryStorage.sol";
import "../../Registry/Ministry.sol";
import "../../../LendingNetwork/Comptroller/ComptrollerInterface.sol";
import "../../../LendingNetwork/PriceOracle/PriceOracle.sol";
import "./RegistryV1.sol";

/**
 * @title Ola's Registry Contract V1.1
 * @author Ola
 * Changes from V1:
 * - Custom 'OlaBankAddress'
 * - Supports 'VersionedContractType' to differentiate between different code requirements.
 * - 'deployOToken' now supports stakeable tokens as well. (Previous function version left, to allow comptrollers V4 compatability)
 * ) Adds validations by specific contract type
 * - 'publishNewSystemVersion' now supports stakeable tokens as well + distinguishes between different token types.
 *    (Previous function version removed)
 * -- Adds pre oToken deployment verifications and hooks
 */
contract RegistryV1_1 is RegistryV1, RegistryV1_1Storage, RegistryV1_1Interface {
    /**
     *  @notice Emitted when an admin changes Ola custom bank address for a target.
     */
    event NewCustomOlaBankAddress(address indexed target, address oldCustomOlaBankAddress, address newCustomOlaBankAddress);
    /**
     *  @notice Emitted when an admin sets a staking target combination as allowed.
     */
    event StakingTargetAllowed(bytes32 indexed contractNameHash, address indexed assetAddress, address indexed stakingTarget);
    /**
     *  @notice Emitted when an admin sets a staking target combination as forbidden.
     */
    event StakingTargetForbidden(bytes32 indexed contractNameHash, address indexed assetAddress, address indexed stakingTarget);

    constructor() public {
        admin = msg.sender;
    }

    /*** Public Views ***/

    /**
     * @return The Ola Bank address associated with the msg.sender
     */
    function olaBankAddress() external view returns (address) {
        return customOrDefaultOlaBankAddressInternal(msg.sender);
    }

    /**
     * @return The Ola Bank address associated with the given target
     */
    function olaBankAddressForTarget(address target) external view returns (address) {
        return customOrDefaultOlaBankAddressInternal(target);
    }

    /**
     * @return True it the given target has a custom Ola bank address set for
     */
    function hasCustomBankAddress(address target) external view returns (bool) {
        return customOlaBankAddresses[target] != address(0);
    }

    /**
     * @return The matching 'VersionedContractType' for the given contract type
     */
    function getMarketTypeInVersion(uint systemVersion, bytes32 contractNameHash) public view returns (VersionedContractType) {
        return VersionedContractType(versionedContractTypes[systemVersion][contractNameHash]);
    }

    /**
     * @return The true if the given staking market combination (contract-asset-target) is allowed
     */
    function isStakingTargetAllowed(bytes32 contractNameHash, address asset, address stakingTarget) public view returns (bool) {
        return supportedStakingTargets[contractNameHash][asset][stakingTarget];
    }

    /*** Admin Functions ***/

    function setOlaBankAddressForTarget(address target, address customOlaBankAddress) external returns (bool) {
        require(msg.sender == admin, "Not Admin");

        address oldCustomBankAddress = customOlaBankAddresses[target];

        customOlaBankAddresses[target] = customOlaBankAddress;

        emit NewCustomOlaBankAddress(target, oldCustomBankAddress, customOlaBankAddress);

        return true;
    }

    function publishNewSystemVersion(uint256 systemVersion,
                                     bytes32[] calldata contractNameHashes, address[] calldata contractImplementations, VersionedContractType[] calldata contractTypes,
                                     address oTokensFactory) external {
        require(msg.sender == admin, "Not Admin");
        require(contractNameHashes.length == contractImplementations.length, "Arrays must be 1:1");
        require(contractNameHashes.length == contractTypes.length, "Arrays must be 1:1");

        require(!supportedSystemVersions[systemVersion], "Already published");

        // Adds the flag.
        supportedSystemVersions[systemVersion] = true;

        // Set the implementations
        for (uint i = 0; i < contractNameHashes.length; i++) {
            bytes32 contractNameHash = contractNameHashes[i];
            address contractImplementation = contractImplementations[i];

            implementations[systemVersion][contractNameHash] = contractImplementation;
            versionedContractTypes[systemVersion][contractNameHash] = uint(contractTypes[i]);
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

    function allowStStakingTarget(bytes32 contractNameHash, address asset, address stakingTarget) external returns (bool) {
        require(msg.sender == admin, "Not Admin");
        require(!supportedStakingTargets[contractNameHash][asset][stakingTarget], "Staking target already supported");

        supportedStakingTargets[contractNameHash][asset][stakingTarget] = true;
        emit StakingTargetAllowed(contractNameHash, asset, stakingTarget);

        return true;
    }

    function forbidStakingTarget(bytes32 contractNameHash, address asset, address stakingTarget) external returns (bool) {
        require(msg.sender == admin, "Not Admin");
        require(supportedStakingTargets[contractNameHash][asset][stakingTarget], "Staking target is not supported");

        supportedStakingTargets[contractNameHash][asset][stakingTarget] = false;
        emit StakingTargetForbidden(contractNameHash, asset, stakingTarget);

        return true;
    }

    /*** LN Comptroller Functions ***/

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

        uint256 currentLnVersion = lnVersions[lnUnitroller];

        // Must be a supported contract name for current LeN current LeN version
        require(isContractNameHashSupportedForVersion(currentLnVersion, contractNameHash), "Contract not supported for LeN version");

        // Ensure the underlying is supported (has price oracle)
        require(isAssetSupported(underlying), "Asset not supported");

        address oTokensFactory = tokenFactories[currentLnVersion];
        require(oTokensFactory != address(0), "No OTokensFacgtory found");

        // Ensure all params are valid for the matching market type
        handleTokenConstraintsPreDeployInternal(currentLnVersion, contractNameHash, underlying, interestRateModel, params);

        address deployedOToken =  OTokensFactoryForRegistry(oTokensFactory).deployODelegator(underlying, contractNameHash, params, lnUnitroller, interestRateModel, contractAdmin, becomeImplementationData);

        emit OTokenDeployed(lnUnitroller, underlying, deployedOToken, contractAdmin);

        return deployedOToken;
    }

    /*** Internal OToken Deployment Functions ***/

    /**
     * @notice This function enforces logic restriction related to specifics market types.
     */
    function handleTokenConstraintsPreDeployInternal(uint lnVersion, bytes32 contractNameHash, address underlying, address interestRateModel, bytes memory params) internal {
        VersionedContractType marketType = getMarketTypeInVersion(lnVersion, contractNameHash);

        if (marketType == VersionedContractType.CompoundingStakeable || marketType == VersionedContractType.RewardingStakeable) {
            // Must provide zero address for IRM (extra safety mechanism)
            require(interestRateModel == address(0), "No IRM for Stakeable markets");

            // Validate staking target
            address stakingTarget = abi.decode(params, (address));

            require(isStakingTargetAllowed(contractNameHash, underlying, stakingTarget), "Staking target not allowed");
        } else {
            // Must provide supported interest rate model
            require(isInterestRateModelSupportedInternal(interestRateModel), "IRM not supported");
        }
    }

    /*** Internal Views ***/

    /**
     * @notice Returns either the custom bank address for target (if one exists) or the default ola bank address.
     */
    function customOrDefaultOlaBankAddressInternal(address target) internal view returns (address) {
        address customOlaBankAddress = customOlaBankAddresses[target];

        return customOlaBankAddress == address(0) ? _olaBankAddress : customOlaBankAddress;
    }
}
