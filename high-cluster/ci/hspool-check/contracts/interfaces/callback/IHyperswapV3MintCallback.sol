// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @notice Any contract that calls IHyperswapV3PoolActions#mint must implement this interface
interface IHyperswapV3MintCallback {
    /// @notice Called to `msg.sender` after minting liquidity to a position from IHyperswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IHyperswapV3PoolActions#mint call
    function hyperswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
