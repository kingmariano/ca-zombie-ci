// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import "./FtsoV2.sol";


contract FtsoV2Proxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                FtsoV2.initialize,
                (_governanceSettings, _initialGovernance, _addressUpdater)
            )
        )
    { }
}


// ===== additional: contracts/userInterfaces/IBn256.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

// G1Point implements a point in G1 group.
struct G1Point {
  uint256 x;
  uint256 y;
}


// ===== additional: contracts/userInterfaces/IFastUpdater.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


import { SortitionCredential } from "./ISortition.sol";

/**
 * Fast updater interface.
 */
interface IFastUpdater {

    /// Signature structure
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// Fast update structure
    struct FastUpdates {
        uint256 sortitionBlock;
        SortitionCredential sortitionCredential;
        bytes deltas;
        Signature signature;
    }

    /// Event emitted when a new set of updates is submitted.
    event FastUpdateFeedsSubmitted(
        uint32 indexed votingRoundId,
        address indexed signingPolicyAddress
    );

    /// Event emitted when a feed is added or reset.
    event FastUpdateFeedReset(
        uint256 indexed votingRoundId,
        uint256 indexed index,
        bytes21 indexed id,
        uint256 value,
        int8 decimals);

    /// Event emitted when a feed is removed.
    event FastUpdateFeedRemoved(
        uint256 indexed index);

    /// Event emitted at the start of a new voting epoch - current feeds' values and decimals.
    event FastUpdateFeeds(uint256 indexed votingEpochId, uint256[] feeds, int8[] decimals);

    /**
     * The entry point for providers to submit an update transaction.
     * @param _updates Data of an update transaction, which in addition to the actual list of updates,
     * includes the sortition credential proving the provider's eligibility to make updates in the also-included
     * sortition round, as well as a signature allowing a single registered provider to submit from multiple
     * EVM accounts.
     */
    function submitUpdates(FastUpdates calldata _updates) external;

    /**
     * Public access to the stored data of all feeds.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * **NOTE:** Overpayment is not refunded.
     * @return _feedIds The list of feed ids.
     * @return _feeds The list of feeds.
     * @return _decimals The list of decimal places for feeds.
     * @return _timestamp The timestamp of the last update.
     */
    function fetchAllCurrentFeeds()
        external payable
        returns (
            bytes21[] memory _feedIds,
            uint256[] memory _feeds,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    /**
     * Public access to the stored data of each feed, allowing controlled batch access to the lengthy complete data.
     * Feeds should be sorted for better performance.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * **NOTE:** Overpayment is not refunded.
     * @param _indices Index numbers of the feeds for which data should be returned, corresponding to `feedIds` in
     * the `FastUpdatesConfiguration` contract.
     * @return _feeds The list of data for the requested feeds, in the same order as the feed indices were given
     * (which may not be their sorted order).
     * @return _decimals The list of decimal places for the requested feeds, in the same order as the feed indices were
     * given (which may not be their sorted order).
     * @return _timestamp The timestamp of the last update.
     */
    function fetchCurrentFeeds(
        uint256[] calldata _indices
    )
        external payable
        returns (
            uint256[] memory _feeds,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    /**
     * Informational getter concerning the eligibility criterion for being chosen by sortition.
     * @return _cutoff The upper endpoint of the acceptable range of "scores" that providers generate for sortition.
     * A score below the cutoff indicates eligibility to submit updates in the present sortition round.
     */
    function currentScoreCutoff() external view returns (uint256 _cutoff);

    /**
     * Informational getter concerning the eligibility criterion for being chosen by sortition in a given block.
     * @param _blockNum The block for which the cutoff is requested.
     * @return _cutoff The upper endpoint of the acceptable range of "scores" that providers generate for sortition.
     * A score below the cutoff indicates eligibility to submit updates in the present sortition round.
     */
    function blockScoreCutoff(uint256 _blockNum) external view returns (uint256 _cutoff);

    /**
     * Informational getter concerning a provider's likelihood of being chosen by sortition.
     * @param _signingPolicyAddress The signing policy address of the specified provider. This is different from the
     * sender of an update transaction, due to the signature included in the `FastUpdates` type.
     * @return _weight The specified provider's weight for sortition purposes. This is derived from the provider's
     * delegation weight for the FTSO, but rescaled against a fixed number of "virtual providers", indicating how many
     * potential updates a single provider may make in a sortition round.
     */
    function currentSortitionWeight(address _signingPolicyAddress) external view returns (uint256 _weight);

    /**
     * The submission window is a number of blocks forming a "grace period" after a round of sortition starts,
     * during which providers may submit updates for that round. In other words, each block starts a new round of
     * sortition and that round lasts `submissionWindow` blocks.
     */
    function submissionWindow() external view returns (uint8);

    /**
     * Id of the current reward epoch.
     */
    function currentRewardEpochId() external view returns (uint24);

    /**
     * The number of updates submitted in each block for the last `_historySize` blocks (up to `MAX_BLOCKS_HISTORY`).
     * @param _historySize The number of blocks for which the number of updates should be returned.
     * @return _noOfUpdates The number of updates submitted in each block for the last `_historySize` blocks.
     * The array is ordered from the current block to the oldest block.
     */
    function numberOfUpdates(uint256 _historySize) external view returns (uint256[] memory _noOfUpdates);

    /**
     * The number of updates submitted in a block - available only for the last `MAX_BLOCKS_HISTORY` blocks.
     * @param _blockNumber The block number for which the number of updates should be returned.
     * @return _noOfUpdates The number of updates submitted in the specified block.
     */
    function numberOfUpdatesInBlock(uint256 _blockNumber) external view returns (uint256 _noOfUpdates);
}


// ===== additional: @openzeppelin/contracts/interfaces/draft-IERC1822.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}


// ===== additional: @openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.20;

import {Proxy} from "../Proxy.sol";
import {ERC1967Utils} from "./ERC1967Utils.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `implementation`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `implementation`. This will typically be an
     * encoded function call, and allows initializing the storage of the proxy like a Solidity constructor.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address implementation, bytes memory _data) payable {
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }

    /**
     * @dev Returns the current implementation address.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }
}


// ===== additional: @openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

import {IBeacon} from "../beacon/IBeacon.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}


// ===== additional: @openzeppelin/contracts/proxy/Proxy.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

pragma solidity ^0.8.20;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }
}


// ===== additional: @openzeppelin/contracts/proxy/beacon/IBeacon.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


// ===== additional: @openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.20;

import {IERC1822Proxiable} from "../../interfaces/draft-IERC1822.sol";
import {ERC1967Utils} from "../ERC1967/ERC1967Utils.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}


// ===== additional: @openzeppelin/contracts/utils/Address.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}


// ===== additional: @openzeppelin/contracts/utils/StorageSlot.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}


// ===== additional: @openzeppelin/contracts/utils/cryptography/MerkleProof.sol =====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.20;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the Merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates Merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     *@dev The multiproof provided is not valid.
     */
    error MerkleProofInvalidMultiproof();

    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a Merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Sorts the pair (a, b) and hashes the result.
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @dev Implementation of keccak256(abi.encode(a, b)) that doesn't allocate or expand memory.
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}


// ===== additional: contracts/customFeeds/interface/IICustomFeed.sol =====

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IICustomFeed interface.
 */
interface IICustomFeed {

    /**
     * Returns the feed id.
     * @return _feedId The feed id.
     */
    function feedId() external view returns (bytes21 _feedId);

    /**
     * Returns the current feed.
     * @return _value The value of the feed.
     * @return _decimals The decimals of the feed.
     * @return _timestamp The timestamp of the feed.
     */
    function getCurrentFeed() external payable returns (uint256 _value, int8 _decimals, uint64 _timestamp);

    /**
     * Calculates the fee for fetching the feed.
     * @return _fee The fee for fetching the feed.
     */
    function calculateFee() external view returns (uint256 _fee);
}


// ===== additional: contracts/governance/implementation/GovernedBase.sol =====
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";


/**
 * @title Governed Base
 * This abstract base class defines behaviors for a governed contract.
 * @dev This class is abstract so that specific behaviors can be defined for the constructor.
 *   Contracts should not be left ungoverned, but not all contract will have a constructor
 *   (for example those pre-defined in genesis).
 * @dev This version is compatible with both Flare (where governance settings is in genesis at the address
 *   0x1000000000000000000000000000000000000007) and Songbird (where governance settings is a deployed contract).
 **/
abstract contract GovernedBase {
    struct TimelockedCall {
        uint256 allowedAfterTimestamp;
        bytes encodedCall;
    }

    IGovernanceSettings public governanceSettings;

    bool private initialised;

    bool public productionMode;

    bool private executing;

    address private initialGovernance;

    mapping(bytes4 selector => TimelockedCall) public timelockedCalls;

    event GovernanceCallTimelocked(bytes4 selector, uint256 allowedAfterTimestamp, bytes encodedCall);
    event TimelockedGovernanceCallExecuted(bytes4 selector, uint256 timestamp);
    event TimelockedGovernanceCallCanceled(bytes4 selector, uint256 timestamp);

    event GovernanceInitialised(address initialGovernance);
    event GovernedProductionModeEntered(address governanceSettings);

    modifier onlyGovernance {
        if (executing || !productionMode) {
            _beforeExecute();
            _;
        } else {
            _recordTimelockedCall(msg.data);
        }
    }

    modifier onlyImmediateGovernance () {
        _checkOnlyGovernance();
        _;
    }

    constructor() {
    }

    /**
     * Execute the timelocked governance calls once the timelock period expires.
     * @dev Only executor can call this method.
     * @param _selector The method selector (only one timelocked call per method is stored).
     */
    function executeGovernanceCall(bytes4 _selector) external {
        require(isExecutor(msg.sender), "only executor");
        TimelockedCall storage call = timelockedCalls[_selector];
        require(call.allowedAfterTimestamp != 0, "timelock: invalid selector");
        require(block.timestamp >= call.allowedAfterTimestamp, "timelock: not allowed yet");
        bytes memory encodedCall = call.encodedCall;
        delete timelockedCalls[_selector];
        executing = true;
        //solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(this).call(encodedCall);
        executing = false;
        emit TimelockedGovernanceCallExecuted(_selector, block.timestamp);
        _passReturnOrRevert(success);
    }

    /**
     * Cancel a timelocked governance call before it has been executed.
     * @dev Only governance can call this method.
     * @param _selector The method selector.
     */
    function cancelGovernanceCall(bytes4 _selector) external onlyImmediateGovernance {
        require(timelockedCalls[_selector].allowedAfterTimestamp != 0, "timelock: invalid selector");
        emit TimelockedGovernanceCallCanceled(_selector, block.timestamp);
        delete timelockedCalls[_selector];
    }

    /**
     * Enter the production mode after all the initial governance settings have been set.
     * This enables timelocks and the governance is afterwards obtained by calling
     * governanceSettings.getGovernanceAddress().
     */
    function switchToProductionMode() external {
        _checkOnlyGovernance();
        require(!productionMode, "already in production mode");
        initialGovernance = address(0);
        productionMode = true;
        emit GovernedProductionModeEntered(address(governanceSettings));
    }

    /**
     * Initialize the governance address if not first initialized.
     */
    function initialise(IGovernanceSettings _governanceSettings, address _initialGovernance) public virtual {
        require(initialised == false, "initialised != false");
        require(address(_governanceSettings) != address(0), "governance settings zero");
        require(_initialGovernance != address(0), "_governance zero");
        initialised = true;
        governanceSettings = _governanceSettings;
        initialGovernance = _initialGovernance;
        emit GovernanceInitialised(_initialGovernance);
    }

    /**
     * Returns the current effective governance address.
     */
    function governance() public view returns (address) {
        return productionMode ? governanceSettings.getGovernanceAddress() : initialGovernance;
    }

    /**
     * Internal function to check if an address is executor.
     */
    function isExecutor(address _address) public view returns (bool) {
        return initialised && governanceSettings.isExecutor(_address);
    }

    function _beforeExecute() private {
        if (executing) {
            // can only be run from executeGovernanceCall(), where we check that only executor can call
            // make sure nothing else gets executed, even in case of reentrancy
            assert(msg.sender == address(this));
            executing = false;
        } else {
            // must be called with: productionMode=false
            // must check governance in this case
            _checkOnlyGovernance();
        }
    }

    function _recordTimelockedCall(bytes calldata _data) private {
        _checkOnlyGovernance();
        bytes4 selector;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            selector := calldataload(_data.offset)
        }
        uint256 timelock = governanceSettings.getTimelock();
        uint256 allowedAt = block.timestamp + timelock;
        timelockedCalls[selector] = TimelockedCall({
            allowedAfterTimestamp: allowedAt,
            encodedCall: _data
        });
        emit GovernanceCallTimelocked(selector, allowedAt, _data);
    }

    function _checkOnlyGovernance() private view {
        require(msg.sender == governance(), "only governance");
    }

    function _passReturnOrRevert(bool _success) private pure {
        // pass exact return or revert data - needs to be done in assembly
        //solhint-disable-next-line no-inline-assembly
        assembly {
            let size := returndatasize()
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
            returndatacopy(ptr, 0, size)
            if _success {
                return(ptr, size)
            }
            revert(ptr, size)
        }
    }
}


// ===== additional: contracts/governance/implementation/GovernedProxyImplementation.sol =====
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GovernedBase } from "./GovernedBase.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";


/**
 * Base class for proxy implementations or diamond facets that expose governed methods -
 * prevents initialization of the implementation/facet as contract (to avoid selfdestruct by attackers).
 *
 * The GovernedBase.initialise can later be called only through a proxy. It should be
 * called through proxy constructor or in diamond cut initializer.
 **/
abstract contract GovernedProxyImplementation is GovernedBase {
    address private constant EMPTY_ADDRESS = 0x0000000000000000000000000000000000001111;

    // Mark as initialised and set governance to an invalid address.
    constructor() {
        initialise(IGovernanceSettings(EMPTY_ADDRESS), EMPTY_ADDRESS);
    }
}


// ===== additional: contracts/protocol/implementation/FtsoV2.sol =====
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/LTS/FtsoV2Interface.sol";
import "../../userInterfaces/IFastUpdater.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IFeeCalculator.sol";
import "../../userInterfaces/IRelay.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../customFeeds/interface/IICustomFeed.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract FtsoV2 is FtsoV2Interface, UUPSUpgradeable, GovernedProxyImplementation, AddressUpdatable {
    using MerkleProof for bytes32[];

    /// Custom feed structure
    struct CustomFeed {
        bytes21 feedId;
        IICustomFeed customFeed;
    }
    /// Custom feed data structure
    struct CustomFeedData {
        IICustomFeed customFeed;
        uint96 index;  // index is 1-based, 0 means non-existent
    }
    /// Feed id change data structure
    struct FeedIdChangeData {
        bytes21 newFeedId;
        uint88 index;  // index is 1-based, 0 means non-existent
    }

    /// The FTSO protocol id.
    uint256 public constant FTSO_PROTOCOL_ID = 100;

    /// The FastUpdater contract.
    IFastUpdater public fastUpdater;
    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;
    /// The FeeCalculator contract.
    IFeeCalculator public feeCalculator;
    /// The Relay contract.
    IRelay public relay;

    bytes21[] private customFeedIds;
    mapping(bytes21 customFeedId => CustomFeedData) private customFeeds; // custom feed id -> custom feed contract
    bytes21[] private changedFeedIds;
    mapping(bytes21 changedFeedId => FeedIdChangeData) private feedIdChanges; // old feed id -> new feed id

    /// Event emitted when a custom feed is added.
    event CustomFeedAdded(bytes21 indexed feedId, IICustomFeed customFeed);
    /// Event emitted when a custom feed is replaced.
    event CustomFeedReplaced(bytes21 indexed feedId, IICustomFeed oldCustomFeed, IICustomFeed newCustomFeed);
    /// Event emitted when a custom feed is removed.
    event CustomFeedRemoved(bytes21 indexed feedId);

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFtsoProtocolId() external pure returns (uint256) {
        return FTSO_PROTOCOL_ID;
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool) {
        bytes32 feedHash = keccak256(abi.encode(_feedData.body));
        bytes32 merkleRoot = relay.merkleRoots(FTSO_PROTOCOL_ID, _feedData.body.votingRoundId);
        require(_feedData.proof.verifyCalldata(merkleRoot, feedHash), "merkle proof invalid");
        return true;
    }

    /////////////////////////////// FEED_ID FUNCTIONS ///////////////////////////////

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getSupportedFeedIds() external view returns (bytes21[] memory _feedIds) {
        bytes21[] memory fastUpdateFeedIds = fastUpdatesConfiguration.getFeedIds();
        uint256 unusedIndicesLength = fastUpdatesConfiguration.getUnusedIndices().length;
        // unusedIndicesLength <= fastUpdateFeedIds.length
        _feedIds = new bytes21[](fastUpdateFeedIds.length - unusedIndicesLength + customFeedIds.length);
        uint256 index = 0;
        // add fast update feed ids that are not removed (bytes21(0))
        for (uint256 i = 0; i < fastUpdateFeedIds.length; i++) {
            if (fastUpdateFeedIds[i] != bytes21(0)) {
                _feedIds[index] = fastUpdateFeedIds[i];
                index++;
            }
        }
        // add custom feed ids
        for (uint256 i = 0; i < customFeedIds.length; i++) {
            _feedIds[index] = customFeedIds[i];
            index++;
        }
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedIdChanges() external view returns (FeedIdChange[] memory _changedFeedIds) {
        _changedFeedIds = new FeedIdChange[](changedFeedIds.length);
        for (uint256 i = 0; i < _changedFeedIds.length; i++) {
            bytes21 feedId = changedFeedIds[i];
            _changedFeedIds[i] = FeedIdChange(feedId, feedIdChanges[feedId].newFeedId);
        }
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedById(bytes21 _feedId) external payable returns (uint256, int8, uint64) {
        return _getFeedById(_feedId);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedsById(bytes21[] memory _feedIds)
        external payable
        returns(
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        return _getFeedsById(_feedIds);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedByIdInWei(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        )
    {
        int8 decimals;
        (_value, decimals, _timestamp) = _getFeedById(_feedId);
        _value = _convertToWei(_value, decimals);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedsByIdInWei(bytes21[] memory _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        )
    {
        int8[] memory decimals;
        (_values, decimals, _timestamp) = _getFeedsById(_feedIds);
        _convertToWei(_values, decimals);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function calculateFeeById(bytes21 _feedId) external view returns (uint256 _fee) {
        // first check for feed id changes
        _feedId = _getCurrentFeedId(_feedId);
        if (_isCustomFeedId(_feedId)) {
            IICustomFeed customFeed = customFeeds[_feedId].customFeed;
            require(address(customFeed) != address(0), "custom feed id not supported");
            return customFeed.calculateFee();
        } else {
            fastUpdatesConfiguration.getFeedIndex(_feedId); // check if feed id is supported
            bytes21[] memory feedIds = new bytes21[](1);
            feedIds[0] = _feedId;
            return feeCalculator.calculateFeeByIds(feedIds);
        }
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee) {
        // first check for feed id changes
        for (uint256 i = 0; i < _feedIds.length; i++) {
            _feedIds[i] = _getCurrentFeedId(_feedIds[i]);
        }
        bytes21[] memory fastUpdateFeedIds = new bytes21[](_getNumberOfFastUpdateFeedIds(_feedIds));
        uint256 index = 0;
        for (uint256 i = 0; i < _feedIds.length; i++) {
            if (_isCustomFeedId(_feedIds[i])) {
                IICustomFeed customFeed = customFeeds[_feedIds[i]].customFeed;
                require(address(customFeed) != address(0), "custom feed id not supported");
                _fee += customFeed.calculateFee();
            } else {
                fastUpdatesConfiguration.getFeedIndex(_feedIds[i]); // check if feed id is supported
                fastUpdateFeedIds[index] = _feedIds[i];
                index++;
            }
        }
        if (index > 0) {
            _fee += feeCalculator.calculateFeeByIds(fastUpdateFeedIds);
        }
    }

    /////////////////////////////// FEED_INDEX FUNCTIONS ///////////////////////////////

    /**
     * Returns the feed id at a given index. Removed (unused) feed index will return bytes21(0).
     * NOTE: Only works for feed index in the FastUpdatesConfiguration contract.
     * @param _index The index.
     * @return _feedId The feed id.
     */
    function getFeedId(uint256 _index) external view returns (bytes21) {
        return fastUpdatesConfiguration.getFeedId(_index);
    }

    /**
     * Returns the index of a feed id.
     * NOTE: Only works for feed id in the FastUpdatesConfiguration contract.
     * @param _feedId The feed id.
     * @return _index The index of the feed.
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256) {
        return fastUpdatesConfiguration.getFeedIndex(_feedId);
    }

    /**
     * Returns stored data of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _index The index of the feed, corresponding to feed id in
     * the FastUpdatesConfiguration contract.
     * @return _value The value for the requested feed.
     * @return _decimals The decimal places for the requested feed.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedByIndex(uint256 _index) external payable returns (uint256, int8, uint64) {
        return _getFeedByIndex(_index);
    }

    /**
     * Returns stored data of each feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
     * @return _values The list of values for the requested feeds.
     * @return _decimals The list of decimal places for the requested feeds.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsByIndex(uint256[] memory _indices)
        external payable
        returns (
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        return fastUpdater.fetchCurrentFeeds{value: msg.value} (_indices);
    }

    /**
     * Returns value in wei and timestamp of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _index The index of the feed, corresponding to feed id in
     * the FastUpdatesConfiguration contract.
     * @return _value The value for the requested feed in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedByIndexInWei(uint256 _index) external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        )
    {
        int8 decimals;
        (_value, decimals, _timestamp) = _getFeedByIndex(_index);
        _value = _convertToWei(_value, decimals);
    }

    /** Returns value in wei of each feed and a timestamp.
     * For some feeds, a fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
     * @return _values The list of values for the requested feeds in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsByIndexInWei(uint256[] memory _indices)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        )
    {
        int8[] memory decimals;
        (_values, decimals, _timestamp) = fastUpdater.fetchCurrentFeeds{value: msg.value} (_indices);
        _convertToWei(_values, decimals);
    }

    /**
     * Calculates the fee for fetching a feed.
     * @param _index The index of the feed, corresponding to feed id in
     * the FastUpdatesConfiguration contract.
     * @return _fee The fee for fetching the feed.
     */
    function calculateFeeByIndex(uint256 _index) external view returns (uint256 _fee) {
        uint256[] memory indices = new uint256[](1);
        indices[0] = _index;
        return feeCalculator.calculateFeeByIndices(indices);
    }

    /**
     * Calculates the fee for fetching feeds.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
     * @return _fee The fee for fetching the feeds.
     */
    function calculateFeeByIndices(uint256[] memory _indices) external view returns (uint256 _fee) {
        return feeCalculator.calculateFeeByIndices(_indices);
    }

    /////////////////////////////// GOVERNANCE FUNCTIONS ///////////////////////////////

    /**
     * Adds custom feeds. Valid feed categories are 32 (0x20) - 63 (0x3F).
     * @param _customFeeds The custom feeds to add.
     * @dev The feed category is the first byte of the feed id.
     * @dev Only governance can call this method.
     */
    function addCustomFeeds(IICustomFeed[] calldata _customFeeds) external onlyGovernance {
        for (uint256 i = 0; i < _customFeeds.length; i++) {
            bytes21 feedId = _customFeeds[i].feedId();
            require(_isCustomFeedId(feedId), "invalid feed category");
            CustomFeedData storage customFeedData = customFeeds[feedId];
            require(customFeedData.index == 0, "feed already exists");
            customFeedIds.push(feedId);
            customFeedData.customFeed = _customFeeds[i];
            customFeedData.index = uint96(customFeedIds.length);
            emit CustomFeedAdded(feedId, _customFeeds[i]);
        }
    }

    /**
     * Replaces custom feeds.
     * @param _customFeeds The custom feeds to replace.
     * @dev Only governance can call this method.
     */
    function replaceCustomFeeds(IICustomFeed[] calldata _customFeeds) external onlyGovernance {
        for (uint256 i = 0; i < _customFeeds.length; i++) {
            bytes21 feedId = _customFeeds[i].feedId();
            CustomFeedData storage customFeedData = customFeeds[feedId];
            require(customFeedData.index != 0, "feed does not exist");
            emit CustomFeedReplaced(feedId, customFeedData.customFeed, _customFeeds[i]);
            customFeedData.customFeed = _customFeeds[i];
        }
    }

    /**
     * Removes custom feeds.
     * @param _feedIds The feed ids to remove.
     * @dev Only governance can call this method.
     */
    function removeCustomFeeds(bytes21[] calldata _feedIds) external onlyGovernance {
        for (uint256 i = 0; i < _feedIds.length; i++) {
            CustomFeedData storage customFeedData = customFeeds[_feedIds[i]];
            uint96 index = customFeedData.index;
            require(index != 0, "feed does not exist");
            uint256 length = customFeedIds.length; // length >= index > 0
            if (index != length) {
                bytes21 lastFeedId = customFeedIds[length - 1];
                customFeedIds[index - 1] = lastFeedId;
                customFeeds[lastFeedId].index = index;
            }
            customFeedIds.pop();
            delete customFeeds[_feedIds[i]];
            emit CustomFeedRemoved(_feedIds[i]);
        }
    }

    /**
     * Change feed ids. This is used when a feed id is updated (e.g. feed renamed).
     * @param _feedIdChanges The feed id changes to apply.
     * @dev Only governance can call this method.
     */
    function changeFeedIds(FeedIdChange[] calldata _feedIdChanges) external onlyGovernance {
        for (uint256 i = 0; i < _feedIdChanges.length; i++) {
            bytes21 oldFeedId = _feedIdChanges[i].oldFeedId;
            bytes21 newFeedId = _feedIdChanges[i].newFeedId;
            require(oldFeedId != newFeedId, "feed ids are the same");
            uint88 index = feedIdChanges[oldFeedId].index;
            if (newFeedId == bytes21(0)) { // remove feed id change
                if (index != 0) {
                    uint256 length = changedFeedIds.length; // length >= index > 0
                    if (index != length) {
                        bytes21 lastFeedId = changedFeedIds[length - 1];
                        feedIdChanges[lastFeedId].index = index;
                        changedFeedIds[index - 1] = lastFeedId;
                    }
                    changedFeedIds.pop();
                    delete feedIdChanges[oldFeedId];
                } else {
                    revert("feed id change does not exist");
                }
            } else { // add or update feed id change
                // check first if new feed id is supported
                if (_isCustomFeedId(newFeedId)) {
                    require(customFeeds[newFeedId].index != 0, "custom feed id not supported");
                } else {
                    fastUpdatesConfiguration.getFeedIndex(newFeedId); // check if feed id is supported
                }

                if (index == 0) { // add feed id change
                    changedFeedIds.push(oldFeedId);
                    feedIdChanges[oldFeedId] = FeedIdChangeData(newFeedId, uint88(changedFeedIds.length));
                } else { // update feed id change
                    feedIdChanges[oldFeedId].newFeedId = newFeedId;
                }
            }
            emit FeedIdChanged(oldFeedId, newFeedId);
        }
    }

    /**
     * Returns the custom feed ids and corresponding custom feed contracts.
     * @return _customFeeds The list of custom feed ids and corresponding custom feed contracts.
     */
    function getCustomFeeds() external view returns(CustomFeed[] memory _customFeeds) {
        _customFeeds = new CustomFeed[](customFeedIds.length);
        for (uint256 i = 0; i < _customFeeds.length; i++) {
            bytes21 feedId = customFeedIds[i];
            _customFeeds[i] = CustomFeed(feedId, customFeeds[feedId].customFeed);
        }
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * Unused. just to present to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeTo and upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /////////////////////////////// INTERNAL FUNCTIONS ///////////////////////////////

    // Valid categories are 32 (0x20) - 63 (0x3F).
    function _isCustomFeedId(bytes21 _feedId) internal pure returns (bool) {
        uint8 category = uint8(bytes1(_feedId[0]));
        return 32 <= category && category < 64;
    }

    // Returns the number of fast update feed ids in the list.
    function _getNumberOfFastUpdateFeedIds(bytes21[] memory _feedIds)
        internal pure
        returns (uint256 _numberOfFastUpdateFeedIds)
    {
        for (uint256 i = 0; i < _feedIds.length; i++) {
            if (!_isCustomFeedId(_feedIds[i])) {
                _numberOfFastUpdateFeedIds++;
            }
        }
    }

    // Returns the indices of the fast update feeds - all that are not custom feeds
    function _getFastUpdateIndices(bytes21[] memory _feedIds)
        internal view
        returns (uint256[] memory _fastUpdateIndices)
    {
        uint256 length = _feedIds.length;
        uint256 count = _getNumberOfFastUpdateFeedIds(_feedIds);
        _fastUpdateIndices = new uint256[](count);
        while (count > 0) {
            length--;
            if (!_isCustomFeedId(_feedIds[length])) {
                count--;
                _fastUpdateIndices[count] = fastUpdatesConfiguration.getFeedIndex(_feedIds[length]);
            }
        }
    }

    // Returns the feed data for all feed ids.
    // NOTE: _timestamp is the same for all feeds (this is not checked), but even if custom feeds are included,
    // we as well get the referenced feeds values from the FastUpdater contract which will return the same timestamp.
    function _getFeedsById(bytes21[] memory _feedIds)
        internal
        returns(
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        )
    {
        // first check for feed id changes
        for (uint256 i = 0; i < _feedIds.length; i++) {
            _feedIds[i] = _getCurrentFeedId(_feedIds[i]);
        }
        uint256[] memory indices = _getFastUpdateIndices(_feedIds);
        if (_feedIds.length == indices.length) { // all feeds are fast update feeds
            return fastUpdater.fetchCurrentFeeds{value: msg.value} (indices);
        } else {
            _values = new uint256[](_feedIds.length);
            _decimals = new int8[](_feedIds.length);
            // set custom feeds data first
            for (uint256 i = 0; i < _feedIds.length; i++) {
                if (_isCustomFeedId(_feedIds[i])) {
                    IICustomFeed customFeed = customFeeds[_feedIds[i]].customFeed;
                    require(address(customFeed) != address(0), "custom feed id not supported");
                    uint256 fee = customFeed.calculateFee();
                    (_values[i], _decimals[i], _timestamp) = customFeed.getCurrentFeed{value: fee} ();
                }
            }
            if (indices.length > 0) {
                uint256[] memory values;
                int8[] memory decimals;
                // set fast update feeds data - use all remaining balance for fees
                //slither-disable-next-line arbitrary-send-eth
                (values, decimals, _timestamp) = fastUpdater.fetchCurrentFeeds{value: address(this).balance} (indices);
                uint256 index = 0;
                for (uint256 i = 0; i < _feedIds.length; i++) {
                    if (!_isCustomFeedId(_feedIds[i])) {
                        _values[i] = values[index];
                        _decimals[i] = decimals[index];
                        index++;
                    }
                }
            }
        }
    }

    // Returns the feed data for a feed id.
    function _getFeedById(bytes21 _feedId)
        internal
        returns(
            uint256,
            int8,
            uint64
        )
    {
        // first check for feed id changes
        _feedId = _getCurrentFeedId(_feedId);
        if (_isCustomFeedId(_feedId)) {
            IICustomFeed customFeed = customFeeds[_feedId].customFeed;
            require(address(customFeed) != address(0), "custom feed id not supported");
            return customFeed.getCurrentFeed{value: msg.value} ();
        } else {
            return _getFeedByIndex(fastUpdatesConfiguration.getFeedIndex(_feedId));
        }
    }

    // Returns the feed data for a feed index.
    function _getFeedByIndex(uint256 _index)
        internal
        returns (
            uint256,
            int8,
            uint64
        )
    {
        uint256[] memory indices = new uint256[](1);
        indices[0] = _index;
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            fastUpdater.fetchCurrentFeeds{value: msg.value} (indices);
        return (values[0], decimals[0], timestamp);
    }

    // Returns the current feed id if it has been changed.
    function _getCurrentFeedId(bytes21 _feedId)
        internal view
        returns (bytes21)
    {
        bytes21 updatedFeedId = feedIdChanges[_feedId].newFeedId;
        if (updatedFeedId != bytes21(0)) {
            return updatedFeedId;
        } else {
            return _feedId;
        }
    }

    // Converts values to wei - updates _values in place.
    function _convertToWei(uint256[] memory _values, int8[] memory _decimals)
        internal pure
    {
        assert(_values.length == _decimals.length);
        for (uint256 i = 0; i < _values.length; i++) {
            _values[i] = _convertToWei(_values[i], _decimals[i]);
        }
    }

    // Converts a value to wei.
    function _convertToWei(uint256 _value, int8 _decimals)
        internal pure
        returns (uint256)
    {
        int256 decimalsDiff = 18 - _decimals;
        // value in wei (18 decimals)
        if (decimalsDiff < 0) {
            return _value / (10 ** uint256(-decimalsDiff));
        } else {
            return _value * (10 ** uint256(decimalsDiff));
        }
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fastUpdater = IFastUpdater(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
        feeCalculator = IFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FeeCalculator"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}

// ===== additional: contracts/userInterfaces/IFastUpdatesConfiguration.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FastUpdatesConfiguration interface.
 */
interface IFastUpdatesConfiguration {

    /**
     * The feed configuration struct.
     */
    struct FeedConfiguration {
        // feed id
        bytes21 feedId;
        // reward band value (interpreted off-chain) in relation to the median
        uint32 rewardBandValue;
        // inflation share
        uint24 inflationShare;
    }

    /// Event emitted when a feed is added.
    event FeedAdded(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    /// Event emitted when a feed is updated.
    event FeedUpdated(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    /// Event emitted when a feed is removed.
    event FeedRemoved(bytes21 indexed feedId, uint256 index);

    /**
     * Returns the index of a feed.
     * @param _feedId The feed id.
     * @return _index The index of the feed.
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256 _index);

    /**
     * Returns the feed id at a given index. Removed (unused) feed index will return bytes21(0).
     * @param _index The index.
     * @return _feedId The feed id.
     */
    function getFeedId(uint256 _index) external view returns (bytes21 _feedId);

    /**
     * Returns all feed ids. For removed (unused) feed indices, the feed id will be bytes21(0).
     */
    function getFeedIds() external view returns (bytes21[] memory);

    /**
     * Returns the number of feeds, including removed ones.
     */
    function getNumberOfFeeds() external view returns (uint256);

    /**
     * Returns the feed configurations, including removed ones.
     */
    function getFeedConfigurations() external view returns (FeedConfiguration[] memory);

    /**
     * Returns the unused indices - indices of removed feeds.
     */
    function getUnusedIndices() external view returns (uint256[] memory);
}


// ===== additional: contracts/userInterfaces/IFeeCalculator.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FeeCalculator interface.
 */
interface IFeeCalculator {
    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _feedIds List of feed ids.
    */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee);

    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
    */
    function calculateFeeByIndices(uint256[] memory _indices) external view returns (uint256 _fee);
}



// ===== additional: contracts/userInterfaces/IRelay.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./LTS/RandomNumberV2Interface.sol";

/**
 * Relay interface.
 */
interface IRelay is RandomNumberV2Interface {

    struct FeeConfig {
        uint8 protocolId;   // Protocol id for which the fee is set
        uint256 feeInWei;   // Fee in wei
    }

    struct RelayInitialConfig {
        uint32 initialRewardEpochId;                           // The initial reward epoch id.
        uint32 startingVotingRoundIdForInitialRewardEpochId;   // The starting voting round id for the initial
                                                               // reward epoch.
        bytes32 initialSigningPolicyHash;                      // The initial signing policy hash.
        uint8 randomNumberProtocolId;                          // The protocol id of the random number protocol.
        uint32 firstVotingRoundStartTs;                        // The timestamp of the first voting round start.
        uint8 votingEpochDurationSeconds;                      // The duration of a voting epoch in seconds.
        uint32 firstRewardEpochStartVotingRoundId;             // The start voting round id of the first reward epoch.
        uint16 rewardEpochDurationInVotingEpochs;              // The duration of a reward epoch in voting epochs.
        uint16 thresholdIncreaseBIPS;                          // The threshold increase in BIPS for signing with
                                                               // old signing policy.
        uint32 messageFinalizationWindowInRewardEpochs;        // The window of reward epochs for finalizing
                                                               // the protocol messages.
        address payable feeCollectionAddress;                  // Fee collection address
        FeeConfig[] feeConfigs;                                // Fee configurations
    }

    struct RelayGovernanceConfig {
        bytes32 descriptionHash;        // Description hash (should be keccak256("RelayGovernance")
        uint256 chainId;                // Chain id on which is the relay is deployed
        FeeConfig[] newFeeConfigs;      // Fee configurations
    }

    // Event is emitted when a new signing policy is initialized by the signing policy setter.
    event SigningPolicyInitialized(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint32 startVotingRoundId,      // First voting round id of validity.
                                        // Usually it is the first voting round of reward epoch rewardEpochId.
                                        // It can be later,
                                        // if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint16 threshold,               // Confirmation threshold (absolute value of noramalised weights).
        uint256 seed,                   // Random seed.
        address[] voters,               // The list of eligible voters in the canonical order.
        uint16[] weights,               // The corresponding list of normalised signing weights of eligible voters.
                                        // Normalisation is done by compressing the weights from 32-byte values to
                                        // 2 bytes, while approximately keeping the weight relations.
        bytes signingPolicyBytes,       // The full signing policy byte encoded.
        uint64 timestamp                // Timestamp when this happened
    );

    // Event is emitted when a signing policy is relayed.
    // It contains minimalistic data in order to save gas. Data about the signing policy are
    // extractable from the calldata, assuming prefered usage of direct top-level call to relay().
    event SigningPolicyRelayed(
        uint256 indexed rewardEpochId        // Reward epoch id
    );

    // Event is emitted when a protocol message is relayed.
    event ProtocolMessageRelayed(
        uint8 indexed protocolId,           // Protocol id
        uint32 indexed votingRoundId,       // Voting round id
        bool isSecureRandom,                // Secure random flag
        bytes32 merkleRoot                  // Merkle root of the protocol message
    );

    /**
     * Checks the relay message for sufficient weight of signatures for the _messageHash
     * signed for protocol message Merkle root of the form (1, 0, 0, _messageHash).
     * If the check is successful, reward epoch id of the signing policy is returned.
     * Otherwise the function reverts.
     * @param _relayMessage The relay message.
     * @param _messageHash The hash of the message.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifyCustomSignature(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    )
        external
        returns (uint256 _rewardEpochId);

    /**
     * Checks the relay message for sufficient weight of signatures of the hash of the _config data.
     * If the check is successful, the relay contract is configured with the new _config data, which
     * in particular means that fee configurations are updated.
     * Otherwise the function reverts.
     * @param _relayMessage The relay message.
     * @param _config The new relay configuration.
     */
    function governanceFeeSetup(bytes calldata _relayMessage, RelayGovernanceConfig calldata _config) external;

    /**
     * Finalization function for new signing policies and protocol messages.
     * It can be used as finalization contract on Flare chain or as relay contract on other EVM chain.
     * Can be called in two modes. It expects calldata that is parsed in a custom manner.
     * Hence the transaction calls should assemble relevant calldata in the 'data' field.
     * Depending on the data provided, the contract operations in essentially two modes:
     * (1) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy
     *             + 0 (1 byte) + new signing policy,
     *     total of exactly 4423 bytes.
     * (2) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy
     *           + signed message (38 bytes) + ECDSA signatures with indices (67 bytes each)
     *     This case splits into two subcases:
     *     - protocolMessageId = 1: Message id must be of the form (protocolMessageId, 0, 0, merkleRoot).
     *       The validity of the signatures of sufficient weight is checked and if
     *       successful, the merkleRoot from the message is returned (32 bytes) and the
     *       reward epoch id of the signing policy as well (additional 3 bytes)
     *     - protocolMessageId > 1: The validity of the signatures of sufficient weight is checked and if
     *       it is valid, the merkleRoot is published for protocolId and votingRoundId.
     * Reverts if relaying is not successful.
     */
    function relay() external returns (bytes memory);

    /**
     * Verifies the leaf (or intermediate node) with the Merkle proof against the Merkle root
     * for given protocol id and voting round id.
     * A fee may need to be paid. It is protocol specific.
     * **NOTE:** Overpayment is not refunded.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     * @param _leaf The leaf (or intermediate node) to verify.
     * @param _proof The Merkle proof.
     * @return True if the verification is successful.
     */
    function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)
        external payable
        returns (bool);

    /**
     * Returns the signing policy hash for given reward epoch id.
     * The function is reverted if signingPolicySetter is set, hence on all
     * deployments where the contract is used as a pure relay.
     * @param _rewardEpochId The reward epoch id.
     * @return _signingPolicyHash The signing policy hash.
     */
    function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32 _signingPolicyHash);

    /**
     * Returns true if there is finalization for a given protocol id and voting round id.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     */
    function isFinalized(uint256 _protocolId, uint256 _votingRoundId) external view returns (bool);

    /**
     * Returns the Merkle root for given protocol id and voting round id.
     * The function is reverted if signingPolicySetter is set, hence on all
     * deployments where the contract is used as a pure relay.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     * @return _merkleRoot The Merkle root.
     */
    function merkleRoots(uint256 _protocolId, uint256 _votingRoundId) external view returns (bytes32 _merkleRoot);

    /**
     * Returns the start voting round id for given reward epoch id.
     * @param _rewardEpochId The reward epoch id.
     * @return _startingVotingRoundId The start voting round id.
     */
    function startingVotingRoundIds(uint256 _rewardEpochId) external view returns (uint256 _startingVotingRoundId);

    /**
     * Returns the voting round id for given timestamp.
     * @param _timestamp The timestamp.
     * @return _votingRoundId The voting round id.
     */
    function getVotingRoundId(uint256 _timestamp) external view returns (uint256 _votingRoundId);

    /**
     * Returns last initialized reward epoch data.
     * @return _lastInitializedRewardEpoch Last initialized reward epoch.
     * @return _startingVotingRoundIdForLastInitializedRewardEpoch Starting voting round id for it.
     */
    function lastInitializedRewardEpochData()
        external view
        returns (
            uint32 _lastInitializedRewardEpoch,
            uint32 _startingVotingRoundIdForLastInitializedRewardEpoch
        );

    /**
     * Returns fee collection address.
     */
    function feeCollectionAddress() external view returns (address payable);

    /**
     * Returns fee in wei for one verification of a given protocol id.
     * @param _protocolId The protocol id.
     */
    function protocolFeeInWei(uint256 _protocolId) external view returns (uint256);

}


// ===== additional: contracts/userInterfaces/ISortition.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {G1Point} from "./IBn256.sol";

struct SortitionCredential {
  uint256 replicate;
  G1Point gamma;
  uint256 c;
  uint256 s;
}


// ===== additional: contracts/userInterfaces/LTS/FtsoV2Interface.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoV2 long term support interface.
 */
interface FtsoV2Interface {

    /// Feed data structure
    struct FeedData {
        uint32 votingRoundId;
        bytes21 id;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    /// Feed data with proof structure
    struct FeedDataWithProof {
        bytes32[] proof;
        FeedData body;
    }

    /// Feed id change structure
    struct FeedIdChange {
        bytes21 oldFeedId;
        bytes21 newFeedId;
    }

    /// Event emitted when a feed id is changed (e.g. feed renamed).
    event FeedIdChanged(bytes21 indexed oldFeedId, bytes21 indexed newFeedId);

    /**
     * Returns the FTSO protocol id.
     */
    function getFtsoProtocolId() external view returns (uint256);

    /**
     * Returns the list of supported feed ids (currently active feed ids).
     * To get the list of all available feed ids, combine with `getFeedIdChanges()`.
     * @return _feedIds The list of supported feed ids.
     */
    function getSupportedFeedIds() external view returns (bytes21[] memory _feedIds);

    /**
     * Returns the list of feed id changes.
     * @return _feedIdChanges The list of changed feed id pairs (old and new feed id).
     */
    function getFeedIdChanges() external view returns (FeedIdChange[] memory _feedIdChanges);

    /**
     * Calculates the fee for fetching a feed.
     * @param _feedId The id of the feed.
     * @return _fee The fee for fetching the feed.
     */
    function calculateFeeById(bytes21 _feedId) external view returns (uint256 _fee);

    /**
     * Calculates the fee for fetching feeds.
     * @param _feedIds The list of feed ids.
     * @return _fee The fee for fetching the feeds.
     */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee);

    /**
     * Returns stored data of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed.
     * @return _decimals The decimal places for the requested feed.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedById(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            int8 _decimals,
            uint64 _timestamp
        );

    /**
     * Returns stored data of each feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _feedIds The list of feed ids.
     * @return _values The list of values for the requested feeds.
     * @return _decimals The list of decimal places for the requested feeds.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsById(bytes21[] memory _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    /**
     * Returns value in wei and timestamp of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedByIdInWei(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        );

    /** Returns value of each feed and a timestamp.
     * For some feeds, a fee (calculated by the FeeCalculator contract) may need to be paid.
     * @param _feedIds Ids of the feeds.
     * @return _values The list of values for the requested feeds in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsByIdInWei(bytes21[] memory _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        );

    /**
     * Checks if the feed data is valid (i.e. is part of the confirmed Merkle tree).
     * @param _feedData Structure containing data about the feed (FeedData structure) and Merkle proof.
     * @return true if the feed data is valid.
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool);
}


// ===== additional: contracts/userInterfaces/LTS/RandomNumberV2Interface.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Random number V2 long term support interface.
 */
interface RandomNumberV2Interface {
    /**
     * Returns the current random number, its timestamp and the flag indicating if it is secure.
     * @return _randomNumber The current random number.
     * @return _isSecureRandom The flag indicating if the random number is secure.
     * @return _randomTimestamp The timestamp of the random number.
     */
    function getRandomNumber()
        external view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        );

    /**
     * Returns the historical random number for a given _votingRoundId,
     * its timestamp and the flag indicating if it is secure.
     * If no finalization in the _votingRoundId, the function reverts.
     * @param _votingRoundId The voting round id.
     * @return _randomNumber The current random number.
     * @return _isSecureRandom The flag indicating if the random number is secure.
     * @return _randomTimestamp The timestamp of the random number.
     */
    function getRandomNumberHistorical(uint256 _votingRoundId)
        external view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        );
}

// ===== additional: contracts/utils/implementation/AddressUpdatable.sol =====
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/addressUpdater/interface/IIAddressUpdatable.sol";


abstract contract AddressUpdatable is IIAddressUpdatable {

    // https://docs.soliditylang.org/en/v0.8.7/contracts.html#constant-and-immutable-state-variables
    // No storage slot is allocated
    bytes32 internal constant ADDRESS_STORAGE_POSITION =
        keccak256("flare.diamond.AddressUpdatable.ADDRESS_STORAGE_POSITION");

    modifier onlyAddressUpdater() {
        require(msg.sender == getAddressUpdater(), "only address updater");
        _;
    }

    constructor(address _addressUpdater) {
        setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * external method called from AddressUpdater only
     */
    function updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        external
        onlyAddressUpdater
    {
        // update addressUpdater address
        setAddressUpdaterValue(_getContractAddress(_contractNameHashes, _contractAddresses, "AddressUpdater"));
        // update all other addresses
        _updateContractAddresses(_contractNameHashes, _contractAddresses);
    }

    function getAddressUpdater() public view returns (address _addressUpdater) {
        // Only direct constants are allowed in inline assembly, so we assign it here
        bytes32 position = ADDRESS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _addressUpdater := sload(position)
        }
    }

    /**
     * virtual method that a contract extending AddressUpdatable must implement
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    ) internal virtual;

    function setAddressUpdaterValue(address _addressUpdater) internal {
        // Only direct constants are allowed in inline assembly, so we assign it here
        bytes32 position = ADDRESS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(position, _addressUpdater)
        }
    }

    /**
     * helper method to get contract address
     * @dev it reverts if contract name does not exist
     */
    function _getContractAddress(
        bytes32[] memory _nameHashes,
        address[] memory _addresses,
        string memory _nameToFind
    )
        internal pure
        returns(address)
    {
        bytes32 nameHash = keccak256(abi.encode(_nameToFind));
        address a = address(0);
        for (uint256 i = 0; i < _nameHashes.length; i++) {
            if (nameHash == _nameHashes[i]) {
                a = _addresses[i];
                break;
            }
        }
        require(a != address(0), "address zero");
        return a;
    }
}


// ===== additional: flare-smart-contracts/contracts/addressUpdater/interface/IIAddressUpdatable.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * Internal interface for contracts that depend on other contracts whose addresses can change.
 *
 * See `AddressUpdatable`.
 */
interface IIAddressUpdatable {
    /**
     * Updates contract addresses.
     * Can only be called from the `AddressUpdater` contract typically set at construction time.
     * @param _contractNameHashes List of keccak256(abi.encode(...)) contract names.
     * @param _contractAddresses List of contract addresses corresponding to the contract names.
     */
    function updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
        ) external;
}


// ===== additional: flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol =====
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * Interface for the `GovernanceSettings` that hold the Flare governance address and its timelock.
 *
 * All governance calls are delayed by the timelock specified in this contract.
 *
 * **NOTE**: This contract enables updating the governance address and timelock only
 * by hard-forking the network, meaning only by updating validator code.
 */
interface IGovernanceSettings {
    /**
     * Gets the governance account address.
     * The governance address can only be changed by a hard fork.
     * @return _address The governance account address.
     */
    function getGovernanceAddress() external view returns (address _address);

    /**
     * Gets the time in seconds that must pass between a governance call and its execution.
     * The timelock value can only be changed by a hard fork.
     * @return _timelock Time in seconds that passes between the governance call and execution.
     */
    function getTimelock() external view returns (uint256 _timelock);

    /**
     * Gets the addresses of the accounts that are allowed to execute the timelocked governance calls,
     * once the timelock period expires.
     * Executors can be changed without a hard fork, via a normal governance call.
     * @return _addresses Array of executor addresses.
     */
    function getExecutors() external view returns (address[] memory _addresses);

    /**
     * Checks whether an address is one of the allowed executors. See `getExecutors`.
     * @param _address The address to check.
     * @return True if `_address` is in the executors list.
     */
    function isExecutor(address _address) external view returns (bool);
}
