// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseAdapter.sol";

interface ICToken {
    function redeem(uint256 redeemTokens) external returns (uint256);
    function underlying() external view returns (address);
}

/// @title RariFuseAdapter
/// @notice Adapter for redeeming Rari Fuse fTokens (Compound-style) for underlying
contract RariFuseAdapter is BaseAdapter {
    constructor(address _router) BaseAdapter(_router) {}

    error RedemptionFailed(uint256 errorCode);

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        address[] memory outputs = new address[](1);
        outputs[0] = ICToken(inputToken).underlying();
        return outputs;
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        uint256 err = ICToken(inputToken).redeem(amount);
        if (err != 0) revert RedemptionFailed(err);
        _sweep(outputTokens);
    }
}
