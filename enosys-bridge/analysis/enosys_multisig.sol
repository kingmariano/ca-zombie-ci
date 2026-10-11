library Multisig {
    /// @dev Thrown when an already existing signer is added.
    error SignerAlreadyExists(address signer);

    /// @dev Thrown when an account that is performing some
    /// signer-only action is not an active signer.
    error SignerNotActive(address signer);

    /// @dev Thrown when attempting to add a new signer
    /// after the max committee size has been reached.
    error MaxCommitteeSizeReached();

    /// @dev Thrown when the configuration parmeters that are
    /// being set are not valid.
    error InvalidConfiguration();

    /// @dev Thrown when a given ID has already been assigned
    /// to an apprroved request.
    error InvalidId();

    /// @dev Thrown when the current next execution index is
    /// greater equal to the new next execution index.
    error InvalidNextExecutionIndex();

    /// @dev Emitted when a new signer is added.
    /// @param signer Address of signer that was added.
    /// @param isFirstCommittee True if the signer was
    /// added to the first committee and false if they were
    /// added to the second committee.
    event AddSigner(address indexed signer, bool indexed isFirstCommittee);

    /// @dev Emitted when an existing signer is removed.
    /// @param signer Address of signer that was removed.
    event RemoveSigner(address indexed signer);

    /// @dev Maximum number of members in each committee.
    /// @notice This number cannot be increased further
    /// with the current implementation. Our implementation
    /// uses bitmasks and the uint8 data type to optimize gas.
    /// These data structures will overflow if maxCommitteeSize
    /// is greater than 128.
    uint8 constant maxCommitteeSize = 128;

    /// @dev Maximum number of members in both committees
    /// combined.
    /// @notice Similarly to maxCommitteeSize, maxSignersSize
    /// also cannot be further increased to more than 256.
    uint16 constant maxSignersSize = 256; // maxCommitteeSize * 2

    /// @dev Request statuses.
    /// @notice `NULL` should be the first element as the first value is used
    /// as the default value in Solidity. The sequence of the other
    /// elements also shouldn't be changed.
    enum RequestStatus {
        NULL, // request which doesn't exist
        Undecided, // request hasn't reached quorum
        Accepted // request has been approved
    }

    /// @notice `Unchanged` should be the first element as the first value is used
    /// as the default value in Solidity. The sequence of the other
    /// elements also shouldn't be changed.
    enum RequestStatusTransition {
        Unchanged,
        NULLToUndecided,
        UndecidedToAccepted
    }

    /// @dev Signer statuses.
    /// @notice `Uninitialized` should be the first element as the first value is used
    /// as the default value in Solidity. The sequence of the other
    /// elements also shouldn't be changed.
    enum SignerStatus {
        Uninitialized,
        Removed,
        FirstCommittee,
        SecondCommittee
    }

    /// @dev Request info.
    /// @param approvalsFirstCommittee Number of approvals
    /// by the first committee.
    /// @param approvalsSecondCommittee Number of approvals
    /// by the second committee.
    /// @param status Status of the request.
    /// @param approvers Bitmask for signers from the two
    /// committees who have accepted the request.
    /// @notice Approvers is a bitmask. For example, a set bit at
    /// position 2 in the approvers bitmask indicates that the
    /// signer with index 2 has approved the request.
    struct Request {
        uint8 approvalsFirstCommittee; // slot 1 (0 - 7 bits)
        uint8 approvalsSecondCommittee; // slot 1 (8 - 15 bits)
        RequestStatus status; // slot 1 (16 - 23 bits)
        // slot 1 (23 - 255 spare bits)
        uint256 approvers; // slot 2
    }

    /// @dev Signer information.
    /// @param status Status of the signer.
    /// @param index Index of the signer.
    struct SignerInfo {
        SignerStatus status;
        uint8 index;
    }

    /// @dev DualMultisig
    /// @param firstCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the second committee.
    /// @param firstCommitteeSize Size of the first committee.
    /// @param secondCommitteeSize Size of the second committee.
    /// @param nextExecutionIndex Index of the request that will be executed next.
    /// @param signers Mapping from signer address to signer info.
    /// @param requests Mapping from request hash to request info.
    /// @param approvedRequests Mapping request ID to request hash.
    struct DualMultisig {
        uint8 firstCommitteeAcceptanceQuorum; // slot 1 (0 - 7bits)
        uint8 secondCommitteeAcceptanceQuorum; // slot 1 (8 - 15bits)
        uint8 firstCommitteeSize; // slot 1 (16 - 23bits)
        uint8 secondCommitteeSize; // slot 1 (24 - 31bits)
        // slot1 (32 - 255 spare bits)
        uint256 nextExecutionIndex;
        mapping(address => SignerInfo) signers;
        mapping(bytes32 => Request) requests;
        mapping(uint256 => bytes32) approvedRequests;
    }

    /// @param firstCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the second committee.
    /// @notice Both acceptance quorums should be greater than zero
    /// and less than or equal to maxCommitteeSize.
    struct Config {
        uint8 firstCommitteeAcceptanceQuorum;
        uint8 secondCommitteeAcceptanceQuorum;
    }

    /// @dev Returns a request status for a given request hash.
    /// @param s The relevant multisig to check.
    /// @param hash The hash of the request being checked.
    /// @return The status of the request with the given hash.
    function status(
        DualMultisig storage s,
        bytes32 hash
    ) internal view returns (RequestStatus) {
        return s.requests[hash].status;
    }

    /// @dev Returns whether or not a given address is a signer
    /// in the multisig.
    /// @param s The relevant multisig to check.
    /// @param signer The address of the potential signer.
    /// @return True if the provided address is a signer.
    function isSigner(
        DualMultisig storage s,
        address signer
    ) internal view returns (bool) {
        return s.signers[signer].status >= SignerStatus.FirstCommittee;
    }

    /// @dev Updates a multisig's configuration.
    function configure(DualMultisig storage s, Config memory c) internal {
        if (
            c.firstCommitteeAcceptanceQuorum == 0 ||
            c.firstCommitteeAcceptanceQuorum > maxCommitteeSize ||
            c.secondCommitteeAcceptanceQuorum == 0 ||
            c.secondCommitteeAcceptanceQuorum > maxCommitteeSize
        ) {
            revert InvalidConfiguration();
        }
        s.firstCommitteeAcceptanceQuorum = c.firstCommitteeAcceptanceQuorum;
        s.secondCommitteeAcceptanceQuorum = c.secondCommitteeAcceptanceQuorum;
    }

    /// @dev Adds a new signer.
    /// @param s The multisig to add the signer to.
    /// @param signer The address of the signer to add.
    /// @param isFirstCommittee True if the signer is to be
    /// added to the first committee and false if they are
    /// to be added to the second committee.
    function addSigner(
        DualMultisig storage s,
        address signer,
        bool isFirstCommittee
    ) internal {
        uint8 committeeSize = (
            isFirstCommittee ? s.firstCommitteeSize : s.secondCommitteeSize
        );
        if (committeeSize == maxCommitteeSize) {
            revert MaxCommitteeSizeReached();
        }

        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status != SignerStatus.Uninitialized) {
            revert SignerAlreadyExists(signer);
        }

        signerInfo.index = s.firstCommitteeSize + s.secondCommitteeSize;
        if (isFirstCommittee) {
            s.firstCommitteeSize++;
            signerInfo.status = SignerStatus.FirstCommittee;
        } else {
            s.secondCommitteeSize++;
            signerInfo.status = SignerStatus.SecondCommittee;
        }

        emit AddSigner(signer, isFirstCommittee);
    }

    /// @dev Removes a signer.
    /// @param s The multisig to remove the signer from.
    /// @param signer The signer to be removed.
    function removeSigner(DualMultisig storage s, address signer) internal {
        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        signerInfo.status = SignerStatus.Removed;
        emit RemoveSigner(signer);
    }

    /// @dev Approve a request if its has not already been approved.
    /// @param s The multisig for which to approve the given request.
    /// @param signer The signer approving the request.
    /// @param hash The hash of the request being approved.
    /// @return The request's status transition.
    /// @dev Notice that this code assumes that the hash is generated from
    /// the ID and other data outside of this function. It is important to include
    /// the ID in the hash.
    function tryApprove(
        DualMultisig storage s,
        address signer,
        bytes32 hash,
        uint256 id
    ) internal returns (RequestStatusTransition) {
        Request storage request = s.requests[hash];
        // If the request has already been accepted
        // then simply return.
        if (request.status == RequestStatus.Accepted) {
            return RequestStatusTransition.Unchanged;
        }

        SignerInfo memory signerInfo = s.signers[signer];
        // Make sure that the signer is valid.
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }

        // Revert if another request with the same ID has
        // already been approved.
        if (s.approvedRequests[id] != bytes32(0)) {
            revert InvalidId();
        }

        uint256 signerMask = 1 << signerInfo.index;
        // Check if the signer has already signed.
        if ((signerMask & request.approvers) != 0) {
            return RequestStatusTransition.Unchanged;
        }

        // Add the signer to the bitmask of approvers.
        request.approvers |= signerMask;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            ++request.approvalsFirstCommittee;
        } else {
            ++request.approvalsSecondCommittee;
        }

        if (
            request.approvalsFirstCommittee >=
            s.firstCommitteeAcceptanceQuorum &&
            request.approvalsSecondCommittee >=
            s.secondCommitteeAcceptanceQuorum
        ) {
            request.status = RequestStatus.Accepted;
            s.approvedRequests[id] = hash;
            return RequestStatusTransition.UndecidedToAccepted;
        } else if (request.status == RequestStatus.NULL) {
            // If this is the first approval, change the request status
            // to undecided.
            request.status = RequestStatus.Undecided;
            return RequestStatusTransition.NULLToUndecided;
        }
        return RequestStatusTransition.Unchanged;
    }

    /// @dev Get approvers for a given request.
    /// @param s The multisig to get the approvers for.
    /// @param hash The hash of the request.
    /// @return approvers List of approvers.
    /// @return count Count of approvers.
    function getApprovers(
        DualMultisig storage s,
        bytes32 hash
    ) internal view returns (uint16[] memory approvers, uint16 count) {
        uint256 mask = s.requests[hash].approvers;
        uint16 signersCount = s.firstCommitteeSize + s.secondCommitteeSize;
        approvers = new uint16[](signersCount);
        count = 0;
        for (uint16 i = 0; i < signersCount; i++) {
            if ((mask & (1 << i)) != 0) {
                approvers[count] = i;
                count++;
            }
        }

        return (approvers, count);
    }

    /// @dev Forcefully set next next execution index.
    /// @param s The multisig to set the next execution index for.
    /// @param index The new next execution index.
    function forceSetNextExecutionIndex(
        DualMultisig storage s,
        uint256 index
    ) internal {
        if (s.nextExecutionIndex >= index) {
            revert InvalidNextExecutionIndex();
        }
        s.nextExecutionIndex = index;
    }

    /// @dev Try to execute the next approved request.
    /// @param s The multisig whose next request should
    /// be executed.
    /// @param hash The hash of the request being executed.
    /// @param id The ID of the request being executed.
    /// @return True if the execution was successful.
    function tryExecute(
        DualMultisig storage s,
        bytes32 hash,
        uint256 id
    ) internal returns (bool) {
        if (id == s.nextExecutionIndex && s.approvedRequests[id] == hash) {
            s.nextExecutionIndex++;
            return true;
        }
        return false;
    }
}

// lib/openzeppelin-contracts/contracts/access/IAccessControlEnumerable.sol

// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
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
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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
        IERC20Permit token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// src/interfaces/IWrap.sol

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

/// @title Common interface for Wrap contracts on FLR and EVM chains.
