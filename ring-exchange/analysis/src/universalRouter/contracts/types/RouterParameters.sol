// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct RouterParameters {
    // Payment parameters
    address permit2;
    address weth9;
    address fewFactory;
    // Uniswap swapping parameters
    address uniswapV2Factory;
    address ringSwapV2Factory;
    address uniswapV3Factory;
    bytes32 uniswapV2PairInitCodeHash;
    bytes32 ringSwapV2PairInitCodeHash;
    bytes32 uniswapV3PoolInitCodeHash;
    address fwrng;
    address v4PoolManager;
    // Uniswap v3->v4 migration parameters
    address v3NFTPositionManager;
    address v4PositionManager;
}
