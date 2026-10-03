// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseAdapter.sol";

interface IPieDAO {
    function exitPool(uint256 _amount) external;
    function getTokens() external view returns (address[] memory);
}

/// @title PieDAOAdapter
/// @notice Adapter for redeeming PieDAO tokens (DEFI++, BCP, PLAY) for underlying
contract PieDAOAdapter is BaseAdapter {
    constructor(address _router) BaseAdapter(_router) {}

    /// @notice Accept ETH from PieDAO exitPool (some pools return native ETH)
    receive() external payable {}

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        return IPieDAO(inputToken).getTokens();
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IPieDAO(inputToken).exitPool(amount);
        _sweep(outputTokens);
        _sweepETH();
    }
}
