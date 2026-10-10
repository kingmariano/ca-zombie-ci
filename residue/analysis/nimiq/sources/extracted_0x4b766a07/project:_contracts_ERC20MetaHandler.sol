// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "./BaseERC20MetaHandler.sol";

/**
 * @title An OpenGSN-powered meta transaction handler for ERC20 tokens
 * @notice This contract allows sending ERC20 tokens without having to acquire the chains native token first.
 * The network fee is paid using the ERC20 token, which is converted automatically using UniSwap.
 */
contract ERC20MetaHandler is BaseERC20MetaHandler {

    function transferPrivate(address userAddress, TransferRequestData memory requestData) private {
        require(requestData.token.transferFrom(userAddress, requestData.target, requestData.amount), "Meta: Value transfer failed");
    }

    function checkTransferPrivate(address userAddress, TransferRequestData memory requestData, FeeInformation memory feeInformation) private view onlyWithSwapRouter onlyWithWrappedChainToken onlyRegisteredToken(requestData.token) {
        require(requestData.token.balanceOf(userAddress) >= requestData.amount + feeInformation.fee, "Meta: balance too low");
    }

    function checkTransferWithApproval(address userAddress, TransferRequestData memory requestData, FeeInformation memory feeInformation, ApprovalRequestData memory approvalRequestData) internal view {
        checkTransferPrivate(userAddress, requestData, feeInformation);
        if (requestData.token.allowance(userAddress, address(this)) < requestData.amount + feeInformation.fee) {
            require(approvalRequestData.approval >= requestData.amount + feeInformation.fee, "Meta: approval too low");
        }
    }

    function approvePrivate(address userAddress, TransferRequestData memory requestData, FeeInformation memory feeInformation, ApprovalRequestData memory approvalRequestData) private {
        approveIfRequiredInternal(userAddress, approvalRequestData, requestData.amount + feeInformation.fee);
    }

    /**
     * @notice Transfers `amount` of `token` to `target`. Includes an approval for `approval` `token`.
     */
    function transferWithApproval(IERC20Meta token, uint256 amount, address target, uint256 fee, uint256 chainTokenFee, uint256 approval, bytes32 sigR, bytes32 sigS, uint8 sigV) public {
        TransferRequestData memory requestData = TransferRequestData(token, amount, target);
        FeeInformation memory feeInformation = FeeInformation(token, fee, chainTokenFee);
        ApprovalRequestData memory approvalRequestData = ApprovalRequestData(token, approval, sigR, sigS, sigV);

        checkTransferWithApproval(msg.sender, requestData, feeInformation, approvalRequestData);
        approvePrivate(msg.sender, requestData, feeInformation, approvalRequestData);
        retrieveFeeInternal(msg.sender, feeInformation);
        transferPrivate(msg.sender, requestData);
        finishFeeInternal(feeInformation);
    }

    function checkTransfer(address userAddress, TransferRequestData memory requestData, FeeInformation memory feeInformation) internal view {
        checkTransferPrivate(userAddress, requestData, feeInformation);
        require(requestData.token.allowance(userAddress, address(this)) >= requestData.amount + feeInformation.fee, "Meta: allowance too low");
    }

    /**
     * @notice Transfers `amount` of `token` to `target`.
     */
    function transfer(IERC20Meta token, uint256 amount, address target, uint256 fee, uint256 chainTokenFee) public {
        TransferRequestData memory requestData = TransferRequestData(token, amount, target);
        FeeInformation memory feeInformation = FeeInformation(token, fee, chainTokenFee);

        checkTransfer(msg.sender, requestData, feeInformation);
        retrieveFeeInternal(msg.sender, feeInformation);
        transferPrivate(msg.sender, requestData);
        finishFeeInternal(feeInformation);
    }

    struct TransferRequestData {
        IERC20Meta token;
        uint256 amount;
        address target;
    }

    function decodeTransferRequestDataPrivate(bytes memory data, uint tokenIndex, uint amountIndex, uint targetIndex) private pure returns (TransferRequestData memory requestData) {
        requestData = TransferRequestData({
            token : IERC20Meta(address(uint160(GsnUtils.getParam(data, tokenIndex)))),
            amount : uint256(GsnUtils.getParam(data, amountIndex)),
            target : address(uint160(GsnUtils.getParam(data, targetIndex)))
        });
    }

    function decodeRequestDataPrivate(bytes memory data) private pure returns (bytes4 methodId, TransferRequestData memory requestData, FeeInformation memory feeInformation) {
        methodId = GsnUtils.getMethodSig(data);
        if (methodId == this.transfer.selector || methodId == this.transferWithApproval.selector) {
            requestData = decodeTransferRequestDataPrivate(data, 0, 1, 2);
            feeInformation = decodeFeeInformationInternal(data, 0, 3, 4);
        } else {
            require(false, "Meta: unsupported method");
        }
    }

    function verifyCallPrivate(IForwarder.ForwardRequest memory request, GsnTypes.RelayData calldata relayData, bytes memory signature, bytes memory approvalData) private view returns (bytes4 methodId, TransferRequestData memory requestData, FeeInformation memory feeInformation, ApprovalRequestData memory approvalRequestData) {
        (approvalData);
        bytes memory suffixData = abi.encode(GsnEip712Library.hashRelayData(relayData));
        bytes32 _domainSeparator = GsnEip712Library.domainSeparator(relayData.forwarder);
        verifyInternal(request, _domainSeparator, GsnEip712Library.RELAY_REQUEST_TYPEHASH, suffixData, signature);

        (methodId, requestData, feeInformation) = decodeRequestDataPrivate(request.data);

        if (methodId == this.transfer.selector) {
            require(feeInformation.chainTokenFee >= relayHub.calculateCharge(requiredRelayGas() - preApprovedGasDiscount, relayData), "Meta: fee too low");
            checkTransfer(request.from, requestData, feeInformation);
        } else if (methodId == this.transferWithApproval.selector) {
            require(feeInformation.chainTokenFee >= relayHub.calculateCharge(requiredRelayGas(), relayData), "Meta: fee too low");
            approvalRequestData = decodeApprovalRequestDataInternal(request.data, 0, 5, 6);
            checkTransferWithApproval(request.from, requestData, feeInformation, approvalRequestData);
        }
    }

    function preRelayedCall(GsnTypes.RelayRequest calldata relayRequest, bytes calldata signature, bytes calldata approvalData, uint256 maxPossibleGas) external override virtual onlyRelayHub onlyToSelf(relayRequest) returns (bytes memory context, bool revertOnRecipientRevert) {
        (relayRequest, signature, approvalData, maxPossibleGas);
        require(relayRequest.request.nonce == getNonce(relayRequest.request.from), "Meta: Invalid nonce");

        (bytes4 methodId, TransferRequestData memory requestData, FeeInformation memory feeInformation, ApprovalRequestData memory approvalRequestData) = verifyCallPrivate(relayRequest.request, relayRequest.relayData, signature, approvalData);
        (methodId);
        if (approvalRequestData.approval != 0) {
            approvePrivate(relayRequest.request.from, requestData, feeInformation, approvalRequestData);
        }
        retrieveFeeInternal(relayRequest.request.from, feeInformation);

        context = abi.encode(relayRequest.request, signature);
        revertOnRecipientRevert = true;
    }

    function execute(ForwardRequest calldata request, bytes32 domainSeparator, bytes32 requestTypeHash, bytes calldata suffixData, bytes calldata signature) public override payable returns (bool success, bytes memory ret) {
        (request, domainSeparator, requestTypeHash, suffixData, signature);
        verifyInternal(request, domainSeparator, requestTypeHash, suffixData, signature);
        require(request.nonce == getNonce(request.from), "Meta: Invalid nonce");

        (bytes4 methodId, TransferRequestData memory requestData, FeeInformation memory feeInformation) = decodeRequestDataPrivate(request.data);
        (methodId, feeInformation);
        nonces[request.from] = nonces[request.from] + 1;
        transferPrivate(request.from, requestData);

        success = true;
        ret = "";
    }

    function postRelayedCall(bytes calldata context, bool success, uint256 gasUseWithoutPost, GsnTypes.RelayData calldata relayData) external override virtual onlyRelayHub {
        (context, success, gasUseWithoutPost, relayData);

        (IForwarder.ForwardRequest memory request, bytes memory signature) = abi.decode(context, (IForwarder.ForwardRequest, bytes));
        bytes memory suffixData = abi.encode(GsnEip712Library.hashRelayData(relayData));
        bytes32 _domainSeparator = GsnEip712Library.domainSeparator(relayData.forwarder);
        verifyInternal(request, _domainSeparator, GsnEip712Library.RELAY_REQUEST_TYPEHASH, suffixData, signature);
        require(request.to == address(this), "POST: illegal request.to");

        (bytes4 methodId, TransferRequestData memory requestData, FeeInformation memory feeInformation) = decodeRequestDataPrivate(request.data);
        (methodId, requestData);
        finishFeeInternal(feeInformation);
    }

    function versionRecipient() external override virtual view returns (string memory) {
        return "2.2.6+opengsn.recipient.erc20meta.handler";
    }

    function versionPaymaster() external override virtual view returns (string memory) {
        return "2.2.6+opengsn.paymaster.erc20meta.handler";
    }

    constructor() {
        registerRequestTypeInternal(string(abi.encodePacked("ForwardRequest(", GsnEip712Library.GENERIC_PARAMS, ")")));
        registerRequestTypeInternal(GsnEip712Library.RELAY_REQUEST_NAME, GsnEip712Library.RELAY_REQUEST_SUFFIX);
        registerDomainSeparatorInternal("GSN Relayed Transaction", "2");
    }
}