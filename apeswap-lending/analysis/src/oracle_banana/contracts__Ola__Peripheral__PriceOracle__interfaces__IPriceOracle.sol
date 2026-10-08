// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

// Price oracle interface for solidity 0.7

interface ICTokenForPriceOracle {
    function underlying() external view returns (address);
}

/**
 * 0.7.6 Interface for "PriceOracle.sol"
 */
interface IPriceOracle {
    function isPriceOracle() external view returns (bool);
    function getAssetPrice(address asset) external view returns (uint);
    function getAssetPriceUpdateTimestamp(address asset) external view returns (uint);
    function getUnderlyingPrice(address cToken) external view returns (uint);
    function getUnderlyingPriceUpdateTimestamp(address cToken) external view returns (uint);
}