// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAdapter
/// @notice Interface for protocol-specific redemption adapters
/// @dev Adapters are called by the Router after input tokens have been transferred
interface IAdapter {
    /// @notice Returns expected output tokens for a given input token
    /// @dev View function for frontend token discovery, not enforced on-chain
    /// @param inputToken The token being redeemed
    /// @return outputTokens Array of expected output token addresses
    function getExpectedOutputs(address inputToken) external view returns (address[] memory outputTokens);

    /// @notice Redeem input tokens for underlying assets
    /// @dev Called by Router AFTER input tokens are transferred to this adapter.
    ///      Adapter MUST sweep all output tokens to msg.sender (the Router).
    /// @param inputToken The token being redeemed
    /// @param amount Amount of input tokens to redeem
    /// @param outputTokens Array of output tokens to sweep back to Router
    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external;
}
