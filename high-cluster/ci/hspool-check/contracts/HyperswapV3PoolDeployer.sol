// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import './interfaces/IHyperswapV3PoolDeployer.sol';

import './HyperswapV3Pool.sol';

contract HyperswapV3PoolDeployer is IHyperswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    event NewPoolDeployed(address indexed _address);

    Parameters public override parameters;

    /// @dev Deploys a pool
    /// @param factory Hyperswap V3 factory contract address
    /// @param token0 first token of the pool / address (sort order)
    /// @param token1 second token of the pool / address (sort order)
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new HyperswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
        emit NewPoolDeployed(pool);
    }
}
