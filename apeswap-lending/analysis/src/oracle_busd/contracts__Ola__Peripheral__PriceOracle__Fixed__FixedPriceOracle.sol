// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPriceOracle.sol";


/**
 * @title Ola's Fixed price(s) oracle.
 * @author Ola
 */
contract FixedPriceOracle is IPriceOracle, Ownable {

    bytes32 constant public emptySymbolHash = keccak256("");

    // Asset address -> Fixed price for asset
    // Prices should be scaled by 10^6
    mapping(address => uint) public prices;

    // Underlying -> assets decimals
    mapping(address => uint8) public assetsDecimals;

    event NewFixedPriceForAsset(address indexed asset, uint price);

    constructor() {}

    //// **** INTERFACE FUNCTIONS ****

    /**
     * Sanity flag
     */
    function isPriceOracle() public override pure returns (bool) {
        return true;
    }

    /**
     * @notice Get the price an asset
     * @param asset The asset to get the price of
     * @return The asset price mantissa (scaled by 1e(36 - assetDecimals))
     *  Zero means the price is unavailable.
     */
    function getAssetPrice(address asset) external override view returns (uint) {
        return _getPriceForAssetInternal(asset);
    }

    /**
     * OLA_ADDITIONS : This function
     * @notice Get the price update timestamp for the asset
     * @param asset The asset address for price update timestamp retrieval.
     * @return Last price update timestamp for the asset
     */
    function getAssetPriceUpdateTimestamp(address asset) external override view returns (uint) {
        return _getPriceUpdateTimestampForAssetInternal(asset);
    }

    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e(36 - assetDecimals)).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(address cToken) external override view returns (uint) {
        return _getPriceForAssetInternal(ICTokenForPriceOracle(cToken).underlying());
    }

    /**
     * @notice Get the price update timestamp for the cToken underlying
     * @param cToken The cToken address for price update timestamp retrieval.
     * @return Last price update timestamp for the cToken underlying asset
     */
    function getUnderlyingPriceUpdateTimestamp(address cToken) external override view returns (uint) {
        return _getPriceUpdateTimestampForAssetInternal(ICTokenForPriceOracle(cToken).underlying());
    }

    //// **** INTERFACE FUNCTIONS - END ****

    /**
     * Sets the fixed price for the given undedrlying.
     * Price should be scaled by 10^6
     */
    function _setFixedPriceForUnderlying(address _underlying, uint _price) onlyOwner external {
        _setFixedPriceForUnderlyingInternal(_underlying, _price);
    }

    /**
     * Sets the fixed prices for the given undedrlyings.
     * Prices should be scaled by 10^6
     */
    function _setFixedPricesForUnderlyings(address[] calldata _underlyings, uint[] calldata _prices) onlyOwner external {
        require(_underlyings.length == _prices.length, "underlyings and prices should be 1:1");

        for (uint i = 0; i < _underlyings.length; i++) {
            _setFixedPriceForUnderlyingInternal(_underlyings[i], _prices[i]);
        }
    }

    function getPriceForAsset(address asset) public view returns (uint) {
        return _getPriceForAssetInternal(asset);
    }

    function _setFixedPriceForUnderlyingInternal(address underlying, uint price) internal {
        uint existingPrice = prices[underlying];

        require(existingPrice == 0, "Cannot reassign price");

        uint8 decimalsForAsset;

        if (underlying == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            decimalsForAsset = 18;
        } else {
            decimalsForAsset = ERC20(underlying).decimals();
        }

        prices[underlying] = price;
        assetsDecimals[underlying] = decimalsForAsset;
        emit NewFixedPriceForAsset(underlying, price);
    }

    /**
      * @notice Get the underlying price of a cToken asset
      * @param asset The asset (Erc20 or native)
      * @return The asset price mantissa (scaled by 1e(36 - assetDecimals)).
      *  Zero means the price is unavailable.
      */
    function _getPriceForAssetInternal(address asset) internal view returns (uint) {
        uint storedFixedPrice = prices[asset];
        uint8 assetDecimals = assetsDecimals[asset];

        if (storedFixedPrice == 0) {
            return 0;
        } else {
            // All fixed prices are scaled by 1e6
            return (mul(1e30, storedFixedPrice) / (10 ** assetDecimals));
        }
    }

    /**
     * @notice Price will never change
     */
    function _getPriceUpdateTimestampForAssetInternal(address asset) internal view returns (uint) {
        return 0;
    }

    /// @dev Overflow proof multiplication
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) return 0;
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
}