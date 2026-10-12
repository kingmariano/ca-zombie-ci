// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// Minimal interfaces for the Timeswap V2 core (v2.0–v2.5 deployed code; identical to
/// Timeswap-Labs/Timeswap-V2-Contracts @ main, verified via Sourcify exact-match on 2026-10-12).

enum OptionPosition { Long0, Long1, Short }
enum OptionMint { GivenTokensAndLongs, GivenShorts }
enum OptionBurn { GivenTokensAndLongs, GivenShorts }
enum OptionSwap { GivenToken0AndLong0, GivenToken1AndLong1 }
enum OptionCollect { GivenShort, GivenToken0, GivenToken1 }

struct OptionMintParam {
    uint256 strike;
    uint256 maturity;
    address long0To;
    address long1To;
    address shortTo;
    OptionMint transaction;
    uint256 amount0;
    uint256 amount1;
    bytes data;
}

struct OptionBurnParam {
    uint256 strike;
    uint256 maturity;
    address token0To;
    address token1To;
    OptionBurn transaction;
    uint256 amount0;
    uint256 amount1;
    bytes data;
}

struct OptionSwapParam {
    uint256 strike;
    uint256 maturity;
    address tokenTo;
    address longTo;
    bool isLong0ToLong1;
    OptionSwap transaction;
    uint256 amount;
    bytes data;
}

struct OptionCollectParam {
    uint256 strike;
    uint256 maturity;
    address token0To;
    address token1To;
    OptionCollect transaction;
    uint256 amount;
    bytes data;
}

struct PoolMintParam {
    uint256 strike;
    uint256 maturity;
    address to;
    uint8 transaction; // 0..3
    uint256 delta;
    bytes data;
}

struct PoolBurnParam {
    uint256 strike;
    uint256 maturity;
    address long0To;
    address long1To;
    address shortTo;
    uint8 transaction; // 0..3
    uint256 delta;
    bytes data;
}

struct PoolDeleverageParam {
    uint256 strike;
    uint256 maturity;
    address to;
    uint8 transaction; // 0..3
    uint256 delta;
    bytes data;
}

struct PoolLeverageParam {
    uint256 strike;
    uint256 maturity;
    address long0To;
    address long1To;
    uint8 transaction; // 0..3
    uint256 delta;
    bytes data;
}

struct PoolRebalanceParam {
    uint256 strike;
    uint256 maturity;
    address to;
    bool isLong0ToLong1;
    uint8 transaction; // 0..1
    uint256 delta;
    bytes data;
}

struct PoolCollectProtocolFeesParam {
    uint256 strike;
    uint256 maturity;
    address long0To;
    address long1To;
    address shortTo;
    uint256 long0Requested;
    uint256 long1Requested;
    uint256 shortRequested;
}

struct PoolCollectTxnFeesParam {
    uint256 strike;
    uint256 maturity;
    address long0FeesTo;
    address long1FeesTo;
    address shortFeesTo;
    address shortReturnedTo;
    uint256 long0FeesRequested;
    uint256 long1FeesRequested;
    uint256 shortFeesRequested;
    uint256 shortReturnedRequested;
}

struct TokenBurnParam {
    address token0;
    address token1;
    uint256 strike;
    uint256 maturity;
    address long0To;
    address long1To;
    address shortTo;
    uint256 long0Amount;
    uint256 long1Amount;
    uint256 shortAmount;
    bytes data;
}

struct LiquidityTokenCollectParam {
    address token0;
    address token1;
    uint256 strike;
    uint256 maturity;
    address from;
    address long0FeesTo;
    address long1FeesTo;
    address shortFeesTo;
    address shortReturnedTo;
    uint256 long0FeesDesired;
    uint256 long1FeesDesired;
    uint256 shortFeesDesired;
    uint256 shortReturnedDesired;
    bytes data;
}

interface ITimeswapV2Option {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalPosition(uint256 strike, uint256 maturity, OptionPosition position) external view returns (uint256);
    function positionOf(uint256 strike, uint256 maturity, address owner, OptionPosition position) external view returns (uint256);
    function transferPosition(uint256 strike, uint256 maturity, address to, OptionPosition position, uint256 amount) external;
    function mint(OptionMintParam calldata param) external returns (uint256, uint256, uint256, bytes memory);
    function burn(OptionBurnParam calldata param) external returns (uint256, uint256, uint256, bytes memory);
    function swap(OptionSwapParam calldata param) external returns (uint256, uint256, bytes memory);
    function collect(OptionCollectParam calldata param) external returns (uint256, uint256, uint256, bytes memory);
}

interface ITimeswapV2Pool {
    function numberOfPools() external view returns (uint256);
    function getByIndex(uint256 id) external view returns (uint256 strike, uint256 maturity);
    function totalLiquidity(uint256 strike, uint256 maturity) external view returns (uint160);
    function liquidityOf(uint256 strike, uint256 maturity, address owner) external view returns (uint160);
    function protocolFeesEarned(uint256 strike, uint256 maturity) external view returns (uint256, uint256, uint256);
    function feesEarnedAndShortReturnedOf(uint256 strike, uint256 maturity, address owner) external view returns (uint256, uint256, uint256, uint256);
    function initialize(uint256 strike, uint256 maturity, uint160 rate) external;
    function transferLiquidity(uint256 strike, uint256 maturity, address to, uint160 liquidityAmount) external;
    function mint(PoolMintParam calldata param) external returns (uint160, uint256, uint256, uint256, bytes memory);
    function burn(PoolBurnParam calldata param) external returns (uint160, uint256, uint256, uint256, bytes memory);
    function deleverage(PoolDeleverageParam calldata param) external returns (uint256, uint256, uint256, bytes memory);
    function leverage(PoolLeverageParam calldata param) external returns (uint256, uint256, uint256, bytes memory);
    function rebalance(PoolRebalanceParam calldata param) external returns (uint256, uint256, bytes memory);
    function collectProtocolFees(PoolCollectProtocolFeesParam calldata param) external returns (uint256, uint256, uint256);
    function collectTransactionFeesAndShortReturned(PoolCollectTxnFeesParam calldata param) external returns (uint256, uint256, uint256, uint256);
}

interface ITimeswapV2PoolFactory {
    function owner() external view returns (address);
    function get(address optionPair) external view returns (address poolPair);
}

interface ITimeswapV2Token {
    function positionOf(address owner, bytes calldata positionKey) external view returns (uint256);
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function burn(TokenBurnParam calldata param) external returns (bytes memory);
}

interface ITimeswapV2LiquidityToken {
    function collect(LiquidityTokenCollectParam calldata param) external returns (uint256, uint256, uint256, uint256, bytes memory);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}
