// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseAdapter.sol";

interface IPickleJar {
    function withdraw(uint256 _shares) external;
    function token() external view returns (address);
}

/// @title PickleAdapter
/// @notice Adapter for redeeming Pickle Finance pTokens (jar shares) for underlying
contract PickleAdapter is BaseAdapter {
    constructor(address _router) BaseAdapter(_router) {}

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        address[] memory outputs = new address[](1);
        outputs[0] = IPickleJar(inputToken).token();
        return outputs;
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IPickleJar(inputToken).withdraw(amount);
        _sweep(outputTokens);
    }
}
