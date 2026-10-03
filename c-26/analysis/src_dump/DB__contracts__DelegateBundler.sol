// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.30;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {IDelegateBundler} from "./interfaces/IDelegateBundler.sol";

contract DelegateBundler is IDelegateBundler, EIP712, ReentrancyGuard, Nonces {
    using Address for address;

    bytes32 public constant EXECUTE_TYPEHASH =
        keccak256("Execute(bytes32 callsDataHash,uint256 nonce,uint256 deadline)");

    address public currentDelegate;

    constructor() EIP712("DelegateBundler", "v1.0.0") {}

    /// @inheritdoc IDelegateBundler
    function execute(
        address delegate,
        uint256 deadline,
        Call[] calldata callsArr,
        bytes calldata signature
    ) external payable nonReentrant {
        bytes32 executeHash = getExecuteHash(callsArr, _useNonce(delegate), deadline);

        _checkSignature(delegate, executeHash, signature);
        _checkDeadline(deadline);

        currentDelegate = delegate;

        _executeCallsWithVerify(callsArr);

        delete currentDelegate;
    }

    /// @inheritdoc IDelegateBundler
    function simulateExecuteAndRevert(
        address delegate,
        uint256 deadline,
        Call[] calldata callsArr,
        bytes calldata signature
    ) external payable {
        bytes32 executeHash = getExecuteHash(callsArr, _useNonce(delegate), deadline);

        _checkSignature(delegate, executeHash, signature);
        _checkDeadline(deadline);

        currentDelegate = delegate;

        CallResult[] memory callResultArr = _executeCalls(callsArr);

        delete currentDelegate;

        _emitSimulationResultAndRevert(callResultArr);
    }

    /// @inheritdoc IDelegateBundler
    function getExecuteHash(
        Call[] calldata callsArr,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(EXECUTE_TYPEHASH, getCallsArrHash(callsArr), nonce, deadline))
            );
    }

    /// @inheritdoc IDelegateBundler
    function getCallsArrHash(Call[] calldata callsArr) public pure returns (bytes32) {
        return keccak256(abi.encode(callsArr));
    }

    function _executeCallsWithVerify(Call[] calldata callsArr) internal {
        require(callsArr.length > 0, ZeroCallsArr());

        for (uint256 i = 0; i < callsArr.length; ++i) {
            _executeCallWithVerify(callsArr[i]);
        }
    }

    function _executeCalls(
        Call[] calldata callsArr
    ) internal returns (CallResult[] memory callResultArr) {
        require(callsArr.length > 0, ZeroCallsArr());

        callResultArr = new CallResult[](callsArr.length);

        for (uint256 i = 0; i < callsArr.length; ++i) {
            callResultArr[i] = _executeCall(callsArr[i]);
        }
    }

    function _executeCallWithVerify(Call calldata call) internal returns (bytes memory) {
        CallResult memory callResult = _executeCall(call);

        return
            Address.verifyCallResultFromTarget(call.to, callResult.success, callResult.returnData);
    }

    function _executeCall(Call calldata call) internal returns (CallResult memory) {
        (bool success, bytes memory returnData) = call.to.call{value: call.value}(call.data);

        return CallResult({success: success, returnData: returnData});
    }

    function _emitSimulationResultAndRevert(CallResult[] memory callResultArr) internal pure {
        bool[] memory successArr = new bool[](callResultArr.length);

        for (uint256 i = 0; i < callResultArr.length; ++i) {
            successArr[i] = callResultArr[i].success;
        }

        revert SimulationResult(successArr);
    }

    function _checkSignature(
        address delegate,
        bytes32 executeHash,
        bytes memory signature
    ) internal view {
        require(
            SignatureChecker.isValidSignatureNow(delegate, executeHash, signature),
            InvalidDelegateSignature()
        );
    }

    function _checkDeadline(uint256 deadline) internal view {
        require(deadline > block.timestamp, SignatureExpired(deadline));
    }
}
