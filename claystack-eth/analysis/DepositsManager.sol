// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
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

// OpenZeppelin Contracts (last updated v4.8.3) (proxy/ERC1967/ERC1967Upgrade.sol)

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// OpenZeppelin Contracts (last updated v4.8.3) (interfaces/IERC1967.sol)

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.9._
 */
interface IERC1967Upgradeable {
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
}

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
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
}

// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable, IERC1967Upgradeable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
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
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

interface IDepositsManager {
    /// @notice Status of orders at strategy
    enum Status {
        Unbonding,
        Claimable,
        Claimed
    }

    /// @notice WithdrawOrder struct
    /// @param token - Address liquid token
    /// @param owner - Address owner of the order and tokens
    /// @param id - Unique id on the underlying protocol
    /// @param amount - Total amount of liquid token on order
    /// @param amountCsETH - Total amount of csETH claimed
    /// @param startTime - Timestamp when unbonding has started
    /// @param isClaimed - already claimed from owner
    struct WithdrawOrder {
        address token;
        address owner;
        uint256 id;
        uint256 amount;
        uint256 amountCsETH;
        uint256 startTime;
        bool isClaimed;
    }

    /// @notice Struct used on when returning user withdraw order
    /// @param token - Address liquid token
    /// @param orderId : Withdraw order id.
    /// @param amount - Total amount of liquid token on order
    /// @param amountCsETH - Total amount of csETH claimed
    /// @param startTime - Timestamp when unbonding has started
    /// @param status - Status of order
    struct UserWithdrawOrderInfo {
        address token;
        uint256 orderId;
        uint256 amount;
        uint256 amountCsETH;
        uint256 startTime;
        Status status;
    }

    /// @notice Event for new withdraw request.
    /// @param user : Address of user withdrawing.
    /// @param token : Address liquid token.
    /// @param orderId : Withdraw order id.
    /// @param id : Unique id at strategy to be used at claim.
    /// @param amount : Amount of liquid token withdrawn.
    /// @param amountCsETH : Amount of csETH tokens received.
    /// @param startTime : Unstake start time.
    event LogWithdraw(
        address indexed user,
        address indexed token,
        uint256 indexed orderId,
        uint256 id,
        uint256 amount,
        uint256 amountCsETH,
        uint256 startTime
    );

    /// @notice Event for claim a withdraw order.
    /// @param user : Address of user.
    /// @param orderId : Claiming order id.
    /// @param amount : Amount of liquid tokens received.
    /// @param amountCsETH : Amount of csETH tokens received.
    event LogClaim(address indexed user, uint256 indexed orderId, uint256 amount, uint256 amountCsETH);

    /// @notice Starts withdraw order of liquid token triggering strategy.
    function withdraw(address token, uint256 amount, address delegateTo) external returns (uint256);

    /// @notice Starts withdraw order of all given liquid token triggering strategy.
    function withdrawAll(
        address[] calldata token,
        uint256[] calldata amount,
        address delegateTo
    ) external returns (bool);
}

interface IRoleManager {
    /// @dev Returns a boolean value indicating whether `_account` has role `_roleName` or not.
    function checkRole(bytes32 _roleName, address _account) external view returns (bool);
}

interface ICSToken {
    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by `_account`.
    function balanceOf(address _account) external view returns (uint256);

    /// @notice Mints `_amount` of tokens `_to` user.
    function mint(address _to, uint256 _amount) external returns (bool);

    /// @notice Burns `_amount` of tokens `_from` user.
    function burn(address _from, uint256 _amount) external returns (bool);

    /// @notice Transfers `_amount` of tokens `_to` user.
    function transfer(address _to, uint256 _amount) external returns (bool);
}

interface IClayMain {
    /// @notice Supported fee types. Matches fees ordering.
    enum SetFee {
        DepositFee,
        WithdrawFee,
        InstantWithdrawFee
    }

    /// @notice Struct used on ClayMatic fees
    struct Fees {
        uint256 depositFee;
        uint256 withdrawFee;
        uint256 instantWithdrawFee;
    }

    /// @notice Struct used on ClayMatic for returning user withdraw order
    struct UserWithdrawOrderInfo {
        uint256 orderId;
        uint256 amount;
        uint256 fee;
        uint256 claimableAt;
        bool isClaimable;
    }

    /// @notice Struct to track internal funds accounting
    /// @param currentDeposit : Total user deposits backing csETH
    /// @param withdrawQueue :  Current amount of ETH waiting in the queue to be withdrawn by users
    /// @param stakedDeposit : Amount of ETH currently staked with validators without including exit requests
    /// @param unstakeExternal : Amount of ETH staked, yet in the process to be withdrawn due user withdraw requests
    /// @param unstakeInternal : Amount of ETH staked, yet in the process to be withdrawn due to protocol balancing
    /// @param withdrawQueueOpen : Amount of ETH to be claimed from withdrawals on open batches
    /// @param claimablePool : ETH balance reserved on contract for claims.
    struct Funds {
        uint256 currentDeposit;
        uint256 withdrawQueue;
        uint256 stakedDeposit;
        uint256 unstakeExternal;
        uint256 unstakeInternal;
        uint256 withdrawQueueOpen;
        uint256 claimablePool;
    }

    /// @notice WithdrawOrder struct
    /// @param amount : Total amount unstaked from from ethereum.
    /// @param fee : Fee percentage to be paid by the user at claim time.
    /// @param claimableAt timestamp when batch claims can be processed
    /// @param batchId : Id of the batch process to be sent to ethereum.
    struct WithdrawOrder {
        uint256 amount;
        uint256 fee;
        uint256 claimableAt;
        uint256 batchId;
    }

    /// @notice Information on batches for withdraws
    /// @param claimableAt timestamp when batch claims can be processed
    /// @param amount : Total amount unstaked from from ethereum.
    /// @param amountCs : Total amount of csToken burned on batch.
    /// @param multiplier : Multiplier for batch accounting for slashing
    struct BatchWithdraw {
        uint256 claimableAt;
        uint256 amount;
        uint256 amountCs;
        uint256 multiplier;
    }

    /// @notice Exchange rate allowed percentage deviation.
    /// @param exchangeDecreaseLimit - Max allowed rate decrease percentage based on last valid exchange rate
    /// @param exchangeIncreaseLimit - Max allowed rate increase percentage based on last valid exchange rate
    struct ExchangeDeviation {
        uint256 exchangeDecreaseLimit;
        uint256 exchangeIncreaseLimit;
    }

    /// @notice Event for new deposit.
    /// @param user : Address of depositor.
    /// @param amount : Amount of Token deposited.
    /// @param amountCs : Amount of csToken minted.
    /// @param fee : Fee paid by user on deposit in Token
    event LogDeposit(address indexed user, uint256 amount, uint256 amountCs, uint256 fee);

    /// @notice Event for new withdraw request.
    /// @param user : Address of user withdrawing.
    /// @param orderId : Withdraw order id.
    /// @param amountCs : Amount of csToken burned.
    /// @param amount : Amount of Token withdrawn.
    /// @param fee : Fee percentage to be paid by the user
    /// @param timestamp : Epoch at the moment of request
    event LogWithdraw(
        address indexed user,
        uint256 orderId,
        uint256 amountCs,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    /// @notice Event for withdraw claims by user.
    /// @param user : Address of user.
    /// @param orderId : Withdraw order id.
    /// @param amount : Amount of Token unstaked in order.
    /// @param received : Amount of Token received in order.
    /// @param fee : Fee paid by user.
    event LogClaim(address indexed user, uint256 orderId, uint256 amount, uint256 received, uint256 fee);

    /// @notice Event for instant withdraw.
    /// @param user : Address of user.
    /// @param amountCs : Amount of csToken burned.
    /// @param amount : Amount of Token withdrawn.
    /// @param fee : Fee paid by user on instant withdraw in Token
    event LogInstantWithdraw(address indexed user, uint256 amountCs, uint256 amount, uint256 fee);

    /// @notice Event for new deposit.
    /// @param updatedBy : Address of Updating entity.
    /// @param feeType : Fee type being updated.
    /// @param oldFee : Existing fee percent for given fee type.
    /// @param newFee : New fee percent for given fee type.
    event LogFeeUpdate(address indexed updatedBy, SetFee feeType, uint256 oldFee, uint256 newFee);

    /// @notice Event emitted when AutoBalance is run.
    /// @param batchId : Id of the current processed batch.
    /// @param isNetStaking : Flag denoting net tx type of batch.
    /// @param amount : Amount of Token to be deposited or expected at claim.
    event LogAutoBalance(uint256 indexed batchId, bool indexed isNetStaking, uint256 amount);

    /// @notice Event for rewards recognized.
    /// @param rewards : Amount of rewards recognized.
    event LogRewards(uint256 rewards);

    /// @notice Event for Donations recognized.
    /// @param amount : Amount of donations recognized.
    event LogDonation(uint256 amount);

    /// @notice Event for batch closed.
    /// @param batchId : Id of the current processed batch.
    /// @param amount : Amount of Token to be deposited or expected at claim.
    /// @param amountCs : Amount of csToken burned on batch.
    /// @param multiplier : Multiplier for batch accounting for slashing
    event LogBatchClosed(uint256 indexed batchId, uint256 amount, uint256 amountCs, uint256 multiplier);

    /// @notice Event for imposed penalties.
    /// @param penaltiesToHolders : Amount of penalties to cs holders.
    /// @param penaltiesToClaims : Amount of penalties to be claimed.
    event LogPenalties(uint256 indexed penaltiesToHolders, uint256 indexed penaltiesToClaims);

    /// @notice Event for updated value of exchange rate
    /// @param rate : Updated rate value.
    /// @param time : Timestamp on which info is updated.
    event LogUpdateExchangeRate(uint256 rate, uint256 time);

    /// @notice Event for updating minimum claim delay.
    /// @param newMinClaimSeconds : New claim delay.
    event LogSetMinClaimTime(uint256 indexed newMinClaimSeconds);

    /// @notice Event for updating withdrawals.
    /// @param flag : bool for enabling/disabling withdrawals.
    event LogSetWithdrawalsDisabled(bool indexed flag);

    /// @notice Event for updating change update limits.
    /// @param newDecreaseLimit : New fx change limit floor.
    /// @param newIncreaseLimit : New fx change limit ceil.
    event LogSetExchangeDeviation(uint256 indexed newDecreaseLimit, uint256 indexed newIncreaseLimit);

    /// @notice Sends msg.value Token to ClayMain contract and mints csToken to msg.sender.
    function deposit() external payable returns (uint256);

    /// @notice Sends msg.value Token to ClayMain contract and mints csToken to `_delegatedTo`.
    function depositDelegate(address _delegatedTo) external payable returns (uint256);

    /// @notice Burns `_amountCs` csToken tokens from user and unstake respective amounts of Token tokens from node.
    function withdraw(uint256 _amountCs) external returns (uint256);

    /// @notice Allows user to claim unstaked tokens.
    function claim(uint256[] calldata _orderIds) external returns (bool);

    /// @notice Performs claiming of rewards & staking of Token tokens for ClayStack.
    function autoBalance(
        uint256 validatorCapacity
    ) external returns (uint256 currentBatchId, bool netStaking, uint256 validatorCount);

    /// @notice Exchange rate from csETH to ETH.
    function getExchangeRate() external view returns (uint256);

    /// @notice Returns amount of csTokens for given `_amountToken`.
    function exchangeToken(uint256 _amountToken) external view returns (uint256);

    /// @notice Returns amount of Tokens for given `_amountCsToken`.
    function exchangeCsToken(uint256 amountCsToken) external view returns (uint256);

    /// @notice Receives confirmation from NodeManager on batch finalization
    function closeBatches(uint256[] calldata _batchIds) external;

    /// @notice Receives liquidity from NodeManager for exits and rewards
    function receiveLiquidity(uint256 rewards, uint256 exited) external payable;

    /// @notice Returns instance of csToken
    function csToken() external returns (ICSToken);

    /// @notice enforceAndUpdateBalance public call
    function updateBalances() external;

    /// @notice Whether withdrawals & claims are disabled given slashing protection or other reasons
    function withdrawalsDisabled() external view returns (bool);

    /// @notice Disables withdrawals and claims
    function setWithdrawalsDisabled(bool _disabled) external;
}

interface IStrategy {
    struct Strategy {
        address strategy;
        bool isActive;
    }

    /// @notice Returns id of the withdraw order processed, and amount immediately minted
    function withdraw(uint256 amount, address token, address owner) external returns (uint256, uint256);

    /// @notice Returns csETH mining after user claims past unbonding period
    function claim(uint256 id, address owner, bytes memory data) external returns (uint256);

    /// @notice Whether the strategy supports withdraws
    function isUnstakingActive() external view returns (bool);

    /// @notice Whether the strategy supports claiming the provided token
    function isValidToken(address token) external view returns (bool);

    /// @notice Returns the claimable status of a given unstake order, true if claimable, false if not
    function getClaimableStatus(uint256 id) external view returns (bool);

    /// @notice Returns the amount of base tokens on a given order
    /// @dev If order is claimed, but return zero
    function getAmountTokenOrder(uint256 id) external view returns (uint256);

    /// @notice Exchanges amount of liquid tokens to ETH at current exchange rate
    /// @dev Assumed 1e18 precision otherwise the strategy must account for it
    function exchangeLiquidTokens(uint256 amount) external view returns (uint256);
}

contract DepositsManager is IDepositsManager, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice ClayStack's default list of access-control roles.
    bytes32 private constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 private constant TIMELOCK_UPGRADES_ROLE = keccak256("TIMELOCK_UPGRADES_ROLE");
    bytes32 private constant CS_SERVICE_ROLE = keccak256("CS_SERVICE_ROLE");
    uint256 private constant MAX_DECIMALS = 1e18;

    /// @notice RoleManager instance.
    IRoleManager private roleManager;

    /// @notice instance of clayMain contract.
    IClayMain private clayMain;

    /// @notice Maps liquid token to strategy struct
    mapping(address => IStrategy.Strategy) public strategies;

    /// @notice Mapping of unstaking withdraw order id to struct.
    mapping(uint256 => WithdrawOrder) public withdrawOrders;

    /// @notice maps user to the list of claims they have
    mapping(address => uint256[]) public userWithdrawIds;

    /// @notice Linear incremental order nonce. Increases by one after each withdraw request.
    uint256 public orderNonce;

    /// @notice Check if the msg.sender has permission.
    /// @param _roleName : bytes32 hash of the role.
    modifier onlyRole(bytes32 _roleName) {
        _onlyRole(_roleName);
        _;
    }

    /// @notice Initializes the contract's state vars.
    /// @param _roleManager : Address of ClayStack's role manager contract.
    /// @param _clayMain : Address of ClayStack's main contract.
    function initialize(address _roleManager, address _clayMain) external initializer onlyProxy {
        require(_roleManager != address(0), "Invalid roleManager address");
        require(_clayMain != address(0), "Invalid clayMain address");

        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        roleManager = IRoleManager(_roleManager);
        clayMain = IClayMain(_clayMain);
    }

    /** USER OPERATIONS **/

    /// @notice Starts withdraw order of all given liquid token triggering strategy.
    /// @param _token - list of address of token to be deposited.
    /// @param _amount - list of amount of token to be deposited.
    /// @param _delegateTo - address of delegate to receive the tokens.
    /// @return bool on success.
    function withdrawAll(
        address[] calldata _token,
        uint256[] calldata _amount,
        address _delegateTo
    ) external whenNotPaused nonReentrant returns (bool) {
        require(_token.length != 0 && _token.length == _amount.length, "Invalid param lengths");

        for (uint256 i = 0; i < _token.length; i++) {
            _withdraw(_token[i], _amount[i], _delegateTo);
        }
        return true;
    }

    /// @notice Starts withdraw order of liquid token triggering strategy
    /// @param _token - address of token to be deposited.
    /// @param _amount - amount of token to be deposited.
    /// @param _delegateTo - address of delegate to receive the tokens.
    /// @return deposit order id.
    function withdraw(
        address _token,
        uint256 _amount,
        address _delegateTo
    ) external whenNotPaused nonReentrant returns (uint256) {
        return _withdraw(_token, _amount, _delegateTo);
    }

    /// @notice Internal implementation to starts withdraw order of liquid token triggering strategy
    /// @param _token - address of token to be deposited.
    /// @param _amount - amount of token to be deposited.
    /// @param _delegateTo - address of delegate to receive the tokens.
    /// @return deposit order id.
    function _withdraw(address _token, uint256 _amount, address _delegateTo) internal returns (uint256) {
        require(_token != address(0), "Invalid token");
        require(_amount != 0, "Zero amount");
        require(strategies[_token].isActive, "Strategy inactive");

        IStrategy strategy = IStrategy(strategies[_token].strategy);
        require(strategy.isUnstakingActive(), "Strategy withdrawals not enabled");

        // Transfer tokens to strategy
        if (_delegateTo == address(0)) {
            _delegateTo = msg.sender;
        }
        IERC20Upgradeable token = IERC20Upgradeable(_token);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        token.safeTransferFrom(msg.sender, address(strategy), _amount);

        // Start withdraw
        (uint256 id, uint256 amountCsETH) = strategy.withdraw(_amount, _token, _delegateTo);

        // Create Order
        uint256 orderId = ++orderNonce;
        uint256 startTime = block.timestamp;
        withdrawOrders[orderId] = WithdrawOrder({
            token: _token,
            owner: _delegateTo,
            id: id,
            amount: _amount,
            amountCsETH: amountCsETH,
            startTime: startTime,
            isClaimed: id == 0 // If id is 0, then it's a direct withdraw
        });

        userWithdrawIds[_delegateTo].push(orderId);

        emit LogWithdraw(_delegateTo, _token, orderId, id, _amount, amountCsETH, startTime);
        return orderId;
    }

    /// @notice Allows the user to claim several orders at once.
    /// @param _orderIds - array of number of ids issued at withdraw()
    /// @param _data - metadata for claims.
    /// @return Bool confirmation of transaction
    function claim(
        uint256[] calldata _orderIds,
        bytes[] memory _data
    ) external whenNotPaused nonReentrant returns (bool) {
        require(_orderIds.length == _data.length, "Param length mismatch");
        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 id = _orderIds[i];
            WithdrawOrder memory order = withdrawOrders[id];
            require(!order.isClaimed, "Already claimed");
            require(strategies[order.token].strategy != address(0), "Strategy does not exist for this order token");

            // Claim from strategy
            IStrategy strategy = IStrategy(strategies[order.token].strategy);
            uint256 amountCsETH = strategy.claim(order.id, order.owner, _data[i]);
            require(amountCsETH != 0, "csETH mint failed");
            withdrawOrders[id].amountCsETH = amountCsETH;
            withdrawOrders[id].isClaimed = true;

            emit LogClaim(order.owner, id, order.amount, amountCsETH);
        }
        return true;
    }

    /** VIEWS **/

    /// @notice Returns order info with calculated values
    /// @param _orderId - id of the order.
    /// @return order UserWithdrawOrderInfo struct.
    function getOrder(uint256 _orderId) public view returns (UserWithdrawOrderInfo memory) {
        WithdrawOrder memory order = withdrawOrders[_orderId];
        require(strategies[order.token].strategy != address(0), "Strategy does not exist for this order token");

        // Determine status
        Status status;
        IStrategy strategy = IStrategy(strategies[order.token].strategy);
        uint256 amountCsETH = order.amountCsETH;
        if (order.isClaimed) {
            status = Status.Claimed;
        } else {
            bool isClaimable = strategy.getClaimableStatus(order.id);
            if (isClaimable) {
                status = Status.Claimable;
            } else {
                status = Status.Unbonding;
            }

            // Calculate csETH value
            uint256 ethValue = strategy.getAmountTokenOrder(order.id);
            amountCsETH = clayMain.exchangeToken(ethValue);
        }

        return
            UserWithdrawOrderInfo({
                token: order.token,
                orderId: _orderId,
                amount: order.amount,
                amountCsETH: amountCsETH,
                startTime: order.startTime,
                status: status
            });
    }

    /// @notice Returns the given page of the withdraw orders in descending order
    /// @dev Max 10 results starting at page 0
    /// @param _user  - Address of user.
    /// @param _page  - Page to query.
    /// @return info Array for struct of user withdraw orders
    /// @return timeStamp current time of current chain
    /// @return totalPages supported for given user.
    function getUserOrders(
        address _user,
        uint256 _page
    ) external view returns (UserWithdrawOrderInfo[] memory, uint256, uint256) {
        UserWithdrawOrderInfo[] memory info = new UserWithdrawOrderInfo[](10);
        uint256 pageSize = 10;
        uint256 length = userWithdrawIds[_user].length;
        uint256 totalPages = length / pageSize;
        if (length > 0 && length % pageSize == 0) {
            totalPages--;
        }
        if (_page <= totalPages && length != 0) {
            for (uint256 i = 0; i < pageSize; i++) {
                uint256 index = length - _page * pageSize - i - 1;
                uint256 orderId = userWithdrawIds[_user][index];
                info[i] = getOrder(orderId);
                if (index == 0) break;
            }
        }
        return (info, block.timestamp, totalPages);
    }

    /// @notice Returns the current exchange rate from strategy
    /// @param _token - Liquid token to be withdrawn.
    /// @return Exchange Rate token to ETH, Slashing occurred.
    function getExchangeRate(address _token) external view returns (uint256) {
        IStrategy strategy = IStrategy(strategies[_token].strategy);
        return strategy.exchangeLiquidTokens(MAX_DECIMALS);
    }

    /** ADMIN **/

    /// @notice Adds new liquid strategy contract
    /// @dev Token address is required given strategies may have multiple tokens
    /// @param _strategy Contract address implementing IStrategy
    /// @param _token Address of token for which strategy is being added
    function addStrategy(address _strategy, address _token) external nonReentrant onlyRole(TIMELOCK_ROLE) {
        require(_strategy != address(0), "Invalid strategy");
        require(strategies[_token].strategy == address(0), "Strategy already set");
        IStrategy strategy = IStrategy(_strategy);
        require(strategy.isValidToken(_token), "Invalid token in strategy");
        strategies[_token] = IStrategy.Strategy({strategy: _strategy, isActive: true});
    }

    /// @notice Updates liquid strategy contract
    /// @param _token Address of token for which strategy is being updated
    /// @param _isActive whether to enable strategy
    function updateStrategy(address _token, bool _isActive) external nonReentrant onlyRole(TIMELOCK_ROLE) {
        require(_token != address(0), "Invalid token in strategy");
        require(strategies[_token].strategy != address(0), "Strategy does not exist for this token");
        strategies[_token].isActive = _isActive;
    }

    /** SUPPORT **/

    /// @notice Triggers stopped state.
    function pause() external onlyRole(CS_SERVICE_ROLE) whenNotPaused {
        _pause();
    }

    /// @notice Returns to normal state.
    function unpause() external onlyRole(CS_SERVICE_ROLE) whenPaused {
        _unpause();
    }

    /// @notice Checks caller has the given `_roleName` or not.
    /// @param _roleName supported by RoleManager
    function _onlyRole(bytes32 _roleName) internal view {
        require(roleManager.checkRole(_roleName, msg.sender), "Auth Failed");
    }

    /// @notice Upgrade the implementation of the proxy to `_newImplementation`.
    /// @param _newImplementation : Address of new implementation of the contract
    function upgradeTo(
        address _newImplementation
    ) external virtual override onlyRole(TIMELOCK_UPGRADES_ROLE) onlyProxy {
        _authorizeUpgrade(_newImplementation);
        _upgradeTo(_newImplementation);
    }

    /// @notice Function that should revert when `msg.sender` is not authorized to upgrade the contract or
    /// @param _newImplementation : Address of new implementation of the contract.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyRole(TIMELOCK_UPGRADES_ROLE) {
        require(_newImplementation.code.length > 0, "!contract");
    }
}