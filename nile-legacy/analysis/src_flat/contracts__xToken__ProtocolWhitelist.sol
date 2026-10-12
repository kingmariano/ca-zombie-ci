// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IEnneadLpDepositor {
    function tokenForPool(address pool) external view returns (address);
}

interface IEnneadToken {
    function pool() external view returns (address);
}

/**
 * @title Protocol Whitelist for xToken
 * @author Ramses Exchange
 * @notice Used as a lens contract to get all L2 contracts that's whitelisted to transfer xToken
 */
contract ProtocolWhitelist {
    // Ennead Addresses
    IEnneadLpDepositor public lpDepositor;
    address public nfpDepositor;
    address public neadStake;
    address public feeHandler;
    address public immutable multisig;

    mapping(address sender => bool) public isWhitelisted;

    constructor(address _multisig) {
        multisig = _multisig;
    }

    function setAddresses(
        IEnneadLpDepositor _lpDepositor,
        address _nfpDepositor,
        address _neadStake,
        address _feeHandler
    ) external {
        require(msg.sender == multisig, "!msig");

        lpDepositor = _lpDepositor;
        nfpDepositor = _nfpDepositor;
        neadStake = _neadStake;
        feeHandler = _feeHandler;

        // whitelist Ennead addresses
        isWhitelisted[address(_lpDepositor)] = true;
        isWhitelisted[_nfpDepositor] = true;
        isWhitelisted[_neadStake] = true;
        isWhitelisted[_feeHandler] = true;
    }

    /**
     * @notice Returns whether an address is whitelisted to transfer xToken
     * @dev Writes Ennead pools to storage if not already stored
     * @param sender The address sending xToken
     */
    function syncAndCheckIsWhitelisted(address sender) external returns (bool) {
        // return true if already stored
        if (isWhitelisted[sender]) {
            return true;
        }

        // Validate if the sender is an Ennead token if not on whitelist

        (bool sucess, bytes memory data) = sender.staticcall(
            abi.encodeWithSelector(IEnneadToken.pool.selector)
        );

        if (!sucess || data.length != 32) {
            return false;
        }

        address pool = abi.decode(data, (address));

        address token = lpDepositor.tokenForPool(pool);

        bool isValidEnneadToken = (sender == token);

        // Update whitelist if sender is a valid Ennead token
        if (isValidEnneadToken) {
            isWhitelisted[token] = true;
        }

        return isValidEnneadToken;
    }
}
