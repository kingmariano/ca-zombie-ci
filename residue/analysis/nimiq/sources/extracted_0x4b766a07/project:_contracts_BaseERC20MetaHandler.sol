// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "./interfaces/IERC20Meta.sol";
import "./interfaces/IWrappedChainToken.sol";
import "./BaseCombinedGsnHandler.sol";

abstract contract BaseERC20MetaHandler is BaseCombinedGsnHandler {
    IV3SwapRouter public swapRouter;

    IWrappedChainToken public wrappedChainToken;
    uint256 public preApprovedGasDiscount = 0;

    mapping(IERC20Meta => uint24) public registeredTokenPoolFee;
    uint256 private registeredTokenCount = 0;

    mapping(address => uint256) internal nonces;

    struct FeeInformation {
        IERC20Meta token;
        uint256 fee;
        uint256 chainTokenFee;
    }

    struct ApprovalRequestData {
        IERC20Meta token;
        uint256 approval;
        bytes32 sigR;
        bytes32 sigS;
        uint8 sigV;
    }

    modifier onlyRegisteredToken(IERC20Meta token) {
        require(registeredTokenPoolFee[token] > 0, "Base: token not registered");
        _;
    }

    modifier onlyWithSwapRouter() {
        require(address(swapRouter) != address(0), "Base: no swap router");
        _;
    }

    modifier onlyWithWrappedChainToken() {
        require(address(wrappedChainToken) != address(0), "Base: no wrapped chain token");
        _;
    }

    function setSwapRouter(IV3SwapRouter _swapRouter) public onlyOwner {
        require(registeredTokenCount == 0, "Base: tokens registered");
        swapRouter = _swapRouter;
    }

    function setWrappedChainToken(IWrappedChainToken _wrappedChainToken) public onlyOwner {
        require(registeredTokenCount == 0, "Base: tokens registered");
        wrappedChainToken = _wrappedChainToken;
        require(wrappedChainToken.approve(owner(), type(uint256).max), "Base: owner approval failed");
    }

    function registerToken(IERC20Meta token, uint24 poolFee) public onlyOwner onlyWithSwapRouter {
        require(address(swapRouter) != address(0), "Base: No swap router defined");
        require(poolFee > 0, "Base: No pool fee defined");
        require(registeredTokenPoolFee[token] == 0, "Base: token already registered");
        require(token.approve(address(swapRouter), type(uint256).max), "Base: swap approval failed");
        require(token.approve(owner(), type(uint256).max), "Base: owner approval failed");
        registeredTokenPoolFee[token] = poolFee;
        registeredTokenCount = registeredTokenCount + 1;
    }

    function unregisterToken(IERC20Meta token) public onlyOwner onlyWithSwapRouter onlyRegisteredToken(token) {
        delete registeredTokenPoolFee[token];
        token.approve(address(swapRouter), 0);
        registeredTokenCount = registeredTokenCount - 1;
    }

    function updatePreApprovedGasDiscount(uint256 _preApprovedGasDiscount) public onlyOwner {
        preApprovedGasDiscount = _preApprovedGasDiscount;
    }

    function retrieveFeeInternal(address userAddress, FeeInformation memory feeInformation) internal {
        if (feeInformation.fee > 0) {
            require(feeInformation.token.transferFrom(userAddress, address(this), feeInformation.fee), "Base: Fee transfer failed");
            deductFeeInternal(feeInformation);
        } else {
            require(feeInformation.chainTokenFee == 0, "Base: Fee too low");
        }
    }

    function deductFeeInternal(FeeInformation memory feeInformation) internal {
        if (feeInformation.chainTokenFee > 0) {
            IV3SwapRouter.ExactOutputSingleParams memory params = IV3SwapRouter.ExactOutputSingleParams({
                tokenIn : address(feeInformation.token),
                tokenOut : address(wrappedChainToken),
                fee : registeredTokenPoolFee[feeInformation.token],
                recipient : address(this),
                amountOut : feeInformation.chainTokenFee,
                amountInMaximum : feeInformation.fee,
                sqrtPriceLimitX96 : 0
            });
            swapRouter.exactOutputSingle(params);
        }
    }

    function finishFeeInternal(FeeInformation memory feeInformation) internal {
        if (feeInformation.chainTokenFee > 0) {
            wrappedChainToken.withdraw(feeInformation.chainTokenFee);
            relayHub.depositFor{value : feeInformation.chainTokenFee}(address(this));
        }
    }

    function executeApproveInternal(address userAddress, ApprovalRequestData memory approvalRequestData) internal {
        bytes memory functionSignature = abi.encodeCall(IERC20.approve, (address(this), approvalRequestData.approval));
        approvalRequestData.token.executeMetaTransaction(userAddress, functionSignature, approvalRequestData.sigR, approvalRequestData.sigS, approvalRequestData.sigV);
    }

    function approveIfRequiredInternal(address userAddress, ApprovalRequestData memory approvalRequestData, uint256 required) internal {
        if (approvalRequestData.token.allowance(userAddress, address(this)) < required) {
            executeApproveInternal(userAddress, approvalRequestData);
        }
    }

    function decodeFeeInformationInternal(bytes memory data, uint tokenIndex, uint feeIndex, uint chainTokenFeeIndex) internal pure returns(FeeInformation memory feeInformation) {
        feeInformation = FeeInformation({
            token : IERC20Meta(address(uint160(GsnUtils.getParam(data, tokenIndex)))),
            fee : uint256(GsnUtils.getParam(data, feeIndex)),
            chainTokenFee : uint256(GsnUtils.getParam(data, chainTokenFeeIndex))
        });
    }

    function decodeFeeInformationKnownTokenInternal(bytes memory data, IERC20Meta token, uint feeIndex, uint chainTokenFeeIndex) internal pure returns(FeeInformation memory feeInformation) {
        feeInformation = FeeInformation({
            token : token,
            fee : uint256(GsnUtils.getParam(data, feeIndex)),
            chainTokenFee : uint256(GsnUtils.getParam(data, chainTokenFeeIndex))
        });
    }

    function decodeApprovalRequestDataInternal(bytes memory data, uint tokenIndex, uint approvalIndex, uint sigIndex) internal pure returns(ApprovalRequestData memory approvalRequestData) {
        approvalRequestData = ApprovalRequestData({
            token : IERC20Meta(address(uint160(GsnUtils.getParam(data, tokenIndex)))),
            approval : uint256(GsnUtils.getParam(data, approvalIndex)),
            sigR : bytes32(GsnUtils.getParam(data, sigIndex)),
            sigS : bytes32(GsnUtils.getParam(data, sigIndex + 1)),
            sigV : uint8(GsnUtils.getParam(data, sigIndex + 2))
        });
    }

    function getNonce(address from) public override view returns (uint256) {
        return nonces[from];
    }

    function withdraw(uint amount, address payable target) public onlyOwner {
        target.transfer(amount);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external virtual payable {}
}
