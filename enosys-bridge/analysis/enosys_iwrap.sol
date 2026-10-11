interface IWrap is IAccessControlEnumerable {
    /// @dev Thrown when an operation is performed on a paused Wrap contract.
    error ContractPaused();

    /// @dev Thrown when the contract is not paused.
    error ContractNotPaused();

    /// @dev Thrown when the contract is already migrated.
    error ContractMigrated();

    /// @dev Thrown when the token is not allowlisted or the amount
    /// being deposited/approved is not in the range of min/maxAmount.
    error InvalidTokenAmount();

    /// @dev Thrown when the token config is invalid.
    error InvalidTokenConfig();

    /// @dev Thrown when the fee being set is higher than the maximum
    /// fee allowed.
    error FeeExceedsMaxFee();

    /// @dev Thrown when the recipient address is the zero address.
    error InvalidToAddress();

    /// @dev Thrown when the provided blocknumber is not of the most recent 256 blocks.
    error InvalidBlockHash();

    /// @dev Thrown when the daily volume exceeds the dailyLimit.
    error DailyLimitExhausted();

    /// @dev Thrown when the fee recipient address is the zero address.
    error InvalidFeeRecipient();

    /// @dev Emitted when a user deposits.
    /// @param id ID associated with the request.
    /// @param token Token deposited.
    /// @param amount Amount of tokens deposited, minus the fee.
    /// @param to Address to release the funds to.
    /// @param fee Fee subtracted from the original deposited amount.
    event Deposit(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    /// @dev Emitted when a new request is created.
    /// @param id ID associated with the request.
    /// @param mirrorToken Mirror token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    event Requested(
        uint256 indexed id,
        address indexed mirrorToken,
        uint256 amount,
        address to
    );

    /// @dev Emitted when a request gets executed.
    /// @param id ID associated with the request.
    /// @param mirrorToken Mirror token requested.
    /// @param token Token approved.
    /// @param amount Amount approved, minus the fee.
    /// @param to Address to release the funds to.
    /// @param fee Fee charged on top of the approved amount.
    event Executed(
        uint256 indexed id,
        address indexed mirrorToken,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    /// @dev Token information.
    /// @param maxAmount Maximum amount to deposit.
    /// @param minAmount Minimum amount to deposit, including fees..
    /// @notice Set max amount to zero to disable the token.
    /// @param dailyLimit Daily volume limit.
    struct TokenInfo {
        uint256 maxAmount;
        uint256 minAmount;
        uint256 dailyLimit;
    }

    /// @dev Token info that is stored in the contact storage.
    /// @param maxAmount Maximum amount to deposit.
    /// @param minAmount Minimum amount to deposit, with fees included.
    /// @param dailyLimit Daily volume limit.
    /// @param consumedLimit Consumed daily volume limit.
    /// @param lastUpdated Last timestamp when the consumed limit was set to 0.
    /// @notice Set max amount to zero to disable the token.
    /// @notice Set daily limit to 0 to disable the daily limit. Consumed limit should
    /// always be less than equal to dailyLimit.
    struct TokenInfoStore {
        uint256 maxAmount;
        uint256 minAmount;
        uint256 dailyLimit;
        uint256 consumedLimit;
        uint256 lastUpdated;
    }

    /// @dev Request information.
    /// @param id ID associated with the request.
    /// @param token Token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    struct RequestInfo {
        uint256 id;
        address token;
        uint256 amount;
        address to;
    }

    /// @dev Returns whether or not the contract has been paused.
    /// @return paused True if the contract is paused, false otherwise.
    function paused() external view returns (bool paused);

    /// @dev Returns the number of deposits.
    function depositIndex() external view returns (uint256);

    /// @dev Returns the index of the request that will be executed next.
    function nextExecutionIndex() external view returns (uint256);

    /// @dev Returns info about a given validator.
    function validatorInfo(
        address validator
    ) external view returns (Multisig.SignerInfo memory);

    /// @dev Returns the number of attesters and their indeces for a given request hash.
    function attesters(
        bytes32 hash
    ) external view returns (uint16[] memory attesters, uint16 count);

    /// @dev Returns the validator fee basis points.
    function validatorFeeBPS() external view returns (uint16);

    /// @dev Update a token's configuration information.
    /// @param tokenInfo The token's new configuration info.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the weak-admin.
    function configureToken(
        address token,
        TokenInfo calldata tokenInfo
    ) external;

    /// @dev Set the multisig configuration.
    /// @param config Multisig config.
    /// @notice Can only be called by the admin.
    function configureMultisig(Multisig.Config calldata config) external;

    /// @dev Configure validator fees.
    /// @param validatorFeeBPS Validator fee in basis points.
    /// @notice Can only be called by the weak-admin.
    function configureValidatorFees(uint16 validatorFeeBPS) external;

    /// @dev Deposit tokens to bridge to the other side.
    /// @param token Token being deposited.
    /// @param amount Amount of tokens being deposited.
    /// @param to Address to release the tokens to on the other side.
    /// @return The ID associated to the request.
    function deposit(
        address token,
        uint256 amount,
        address to
    ) external returns (uint256);

    /// @dev Approve and/or execute a given request.
    /// @param id ID associated with the request.
    /// @param token Token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    /// @param recentBlockhash Block hash of `recentBlocknumber`
    /// @param recentBlocknumber Recent block number
    function approveExecute(
        uint256 id,
        address token,
        uint256 amount,
        address to,
        bytes32 recentBlockhash,
        uint256 recentBlocknumber
    ) external;

    /// @dev Approve and/or execute requests.
    /// @param requests Requests to approve and/or execute.
    function batchApproveExecute(
        RequestInfo[] calldata requests,
        bytes32 recentBlockhash,
        uint256 recentBlocknumber
    ) external;

    /// @dev Pauses the contract.
    /// @notice The contract can be paused by all addresses
    /// with pause role but can only be unpaused by the weak-admin.
    function pause() external;

    /// @dev Unpauses the contract.
    /// @notice The contract can be paused by all addresses
    /// with pause role but can only be unpaused by the weak-admin.
    function unpause() external;

    /// @dev Add a new validator to the contract.
    /// @param validator Address of the validator.
    /// @param isFirstCommittee True when adding the validator to the first committee.
    /// @param feeRecipient Address of the fee recipient.
    /// false when adding the validator to the second committee.
    /// @notice Can only be called by the admin.
    function addValidator(
        address validator,
        bool isFirstCommittee,
        address feeRecipient
    ) external;

    /// @dev Change fee recipient for a validator.
    /// @param validator Address of the validator.
    /// @param feeRecipient Address of the new fee recipient.
    function configureValidatorFeeRecipient(
        address validator,
        address feeRecipient
    ) external;

    /// @dev Remove existing validator from the contract.
    /// @param validator Address of the validator.
    /// @notice Can only be called by the weak-admin.
    /// @notice The fees accumulated by the validator are distributed before being removed.
    function removeValidator(address validator) external;

    /// @dev Allows to claim accumulated fees for a validator.
    /// @param validator Address of the validator.
    /// @notice Can be triggered by anyone but the fee is transfered to the
    /// set feeRecepient for the validator.
    function claimValidatorFees(address validator) external;

    /// @dev Forcefully set next next execution index.
    /// @param index The new next execution index.
    /// @notice Can only be called by the admin of the contract.
    function forceSetNextExecutionIndex(uint256 index) external;

    /// @dev Migrates the contract to a new address.
    /// @param _newContract Address of the new contract.
    /// @notice This function can only be called once in the lifetime of this
    /// contract by the admin.
    function migrate(address _newContract) external;
}

// src/interfaces/IWrapDepositRedeem.sol

/**
 * Copyright (C) 2023 Flare Finance B.V. - All Rights Reserved.
 *
 * This source code and any functionality deriving from it are owned by Flare
 * Finance BV and the use of it is only permitted within the official platforms
 * and/or original products of Flare Finance B.V. and its licensed parties. Any
 * further enquiries regarding this copyright and possible licenses can be directed
 * to partners[at]flr.finance.
 *
 * The source code and any functionality deriving from it are provided "as is",
 * without warranty of any kind, express or implied, including but not limited to
 * the warranties of merchantability, fitness for a particular purpose and
 * noninfringement. In no event shall the authors or copyright holder be liable
 * for any claim, damages or other liability, whether in an action of contract,
 * tort or otherwise, arising in any way out of the use or other dealings or in
 * connection with the source code and any functionality deriving from it.
 */

/// @title Interface for the side of Wraps where tokens are deposited and
/// redeemed.
interface IWrapDepositRedeem is IWrap {
    /// @dev Allowlist a new token.
    /// @param token Address of the token that will be allowlisted.
    /// @param mirrorToken Address of the token that will be minted
    /// on the other side.
    /// @param tokenInfo Information associated with the token.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the weak-admin.
    function addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external;
}

// lib/openzeppelin-contracts/contracts/access/AccessControl.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// lib/openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol

// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }
}

// src/Wrap.sol

/**
 * Copyright (C) 2023 Flare Finance B.V. - All Rights Reserved.
 *
 * This source code and any functionality deriving from it are owned by Flare
 * Finance BV and the use of it is only permitted within the official platforms
 * and/or original products of Flare Finance B.V. and its licensed parties. Any
 * further enquiries regarding this copyright and possible licenses can be directed
 * to partners[at]flr.finance.
 *
 * The source code and any functionality deriving from it are provided "as is",
 * without warranty of any kind, express or implied, including but not limited to
 * the warranties of merchantability, fitness for a particular purpose and
 * noninfringement. In no event shall the authors or copyright holder be liable
 * for any claim, damages or other liability, whether in an action of contract,
 * tort or otherwise, arising in any way out of the use or other dealings or in
 * connection with the source code and any functionality deriving from it.
 */

