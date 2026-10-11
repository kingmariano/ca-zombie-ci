// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import './../../v2/interfaces/IClPoolFactory.sol';
import './../../v2/interfaces/IClPool.sol';

/// @title Creates and initializes CL Pools
library PoolInitializer {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96,
        address factory
    ) external returns (address pool) {
        pool = IClPoolFactory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = IClPoolFactory(factory).createPool(token0, token1, fee, sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , , ) = IClPool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IClPool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
