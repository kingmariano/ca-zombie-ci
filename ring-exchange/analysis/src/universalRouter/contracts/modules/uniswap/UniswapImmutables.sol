// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct UniswapParameters {
    address uniswapV2Factory;
    address ringSwapV2Factory;
    address uniswapV3Factory;
    bytes32 uniswapV2PairInitCodeHash;
    bytes32 ringSwapV2PairInitCodeHash;
    bytes32 uniswapV3PoolInitCodeHash;
    address fwrng;
}

contract UniswapImmutables {
    /// @notice The address of UniswapV2Factory
    address internal immutable UNISWAP_V2_FACTORY;

    /// @notice The address of RING_SWAP_V2_FACTORY
    address internal immutable RING_SWAP_V2_FACTORY;

    /// @notice The UniswapV2Pair initcodehash
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @notice The RING_SWAP_V2_PAIR initcodehash
    bytes32 internal immutable RING_SWAP_V2_PAIR_INIT_CODE_HASH;

    /// @notice The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @notice The UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    /// @notice The address of FWRNG
    address internal immutable FWRNG;

    constructor(UniswapParameters memory params) {
        UNISWAP_V2_FACTORY = params.uniswapV2Factory;
        RING_SWAP_V2_FACTORY = params.ringSwapV2Factory;
        UNISWAP_V3_FACTORY = params.uniswapV3Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.uniswapV2PairInitCodeHash;
        RING_SWAP_V2_PAIR_INIT_CODE_HASH = params.ringSwapV2PairInitCodeHash;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.uniswapV3PoolInitCodeHash;
        FWRNG = params.fwrng;
    }
}
