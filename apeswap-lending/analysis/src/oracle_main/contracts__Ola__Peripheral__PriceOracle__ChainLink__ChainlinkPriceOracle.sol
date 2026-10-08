// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title Ola's ChainLink based price oracle.
 * @author Ola
 */
contract ChainlinkPriceOracle is IPriceOracle, Ownable {


    // Underlying -> ChainLink Feed address
    mapping(address => address) public chainLinkFeeds;

    // Underlying -> ChainLink Feed decimals
    mapping(address => uint8) public chainLinkFeedDecimals;

    // Underlying -> assets decimals
    mapping(address => uint8) public assetsDecimals;

    event NewFeedForAsset(address indexed asset, address oldFeed, address newFeed);
    event NewFeedDecimalsForAsset(address indexed asset, uint8 oldFeedDecimals, uint8 newFeedDecimals);


    /**
     * @notice Get the price an asset
     * @param asset The asset to get the price of
     * @return The asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getAssetPrice(address asset) external override view returns (uint) {
        return _getPriceForAssetInternal(asset);
    }

    /**
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

    function _setPriceFeedForUnderlying(address _underlying, address _chainlinkFeed, uint8 _priceFeedDecimals) onlyOwner external {
        _setPriceFeedForUnderlyingInternal(_underlying, _chainlinkFeed, _priceFeedDecimals);
    }

    function _setPriceFeedsForUnderlyings(address[] calldata _underlyings, address[] calldata _chainlinkFeeds, uint8[] calldata _priceFeedsDecimals) onlyOwner external {
        require(_underlyings.length == _chainlinkFeeds.length, "underlyings and chainlinkFeeds should be 1:1");
        require(_underlyings.length == _priceFeedsDecimals.length, "underlyings and priceFeedsDecimals should be 1:1");

        for (uint i = 0; i < _underlyings.length; i++) {
            _setPriceFeedForUnderlyingInternal(_underlyings[i], _chainlinkFeeds[i], _priceFeedsDecimals[i]);
        }
    }

    function getPriceForAsset(address asset) public view returns (uint) {
        return _getPriceForAssetInternal(asset);
    }

    function hasFeedForAsset(address asset) public view returns (bool) {
        return chainLinkFeeds[asset] != address(0);
    }

    function chainLinkRawReportedPrice(address asset) public view returns (int) {
        return getChainLinkPrice(AggregatorV3Interface(chainLinkFeeds[asset]));
    }

    function isPriceOracle() public override pure returns (bool) {
        return true;
    }


    function _setPriceFeedForUnderlyingInternal(address underlying, address chainlinkFeed, uint8 priceFeedDecimals) internal {
        address existingFeed = chainLinkFeeds[underlying];
        uint8 existingDecimals = chainLinkFeedDecimals[underlying];

        require(existingFeed == address(0), "Cannot reassign feed");

        uint8 decimalsForAsset;

        if (underlying == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            decimalsForAsset = 18;
        } else {
            decimalsForAsset = ERC20(underlying).decimals();
        }

        // Update if the feed is different
        if (existingFeed != chainlinkFeed) {
            chainLinkFeeds[underlying] = chainlinkFeed;
            chainLinkFeedDecimals[underlying] = priceFeedDecimals;
            assetsDecimals[underlying] = decimalsForAsset;
            emit NewFeedForAsset(underlying, existingFeed, chainlinkFeed);
            emit NewFeedDecimalsForAsset(underlying, existingDecimals, priceFeedDecimals);
        }
    }

    /**
      * @notice Get the underlying price of a cToken asset
      * @param asset The asset (Erc20 or native)
      * @return The asset price mantissa (scaled by 1e(36 - assetDecimals)).
      *  Zero means the price is unavailable.
      */
    function _getPriceForAssetInternal(address asset) internal view returns (uint) {
        if (hasFeedForAsset(asset)) {
            uint8 feedDecimals = chainLinkFeedDecimals[asset];
            uint8 assetDecimals = assetsDecimals[asset];
            address feed = chainLinkFeeds[asset];
            int feedPriceRaw = getChainLinkPrice(AggregatorV3Interface(feed));
            uint feedPrice = uint(feedPriceRaw);

            // Safety
            require(feedPriceRaw == int(feedPrice), "Price Conversion error");

            // Needs to be scaled to e36 and then divided by the asset's decimals
            if (feedDecimals == 8) {
                return (mul(1e28, feedPrice) / (10 ** assetDecimals));
            } else if (feedDecimals == 18) {
                return (mul(1e18, feedPrice) / (10 ** assetDecimals));
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    function _getPriceUpdateTimestampForAssetInternal(address asset) internal view returns (uint) {
        if (hasFeedForAsset(asset)) {
            return getChainLinkUpdateTimestamp(AggregatorV3Interface(chainLinkFeeds[asset]));
        } else {
            return 0;
        }
    }

    function getChainLinkPrice(AggregatorV3Interface priceFeed) internal view returns (int) {
        (
        uint80 roundID,
        int price,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function getChainLinkUpdateTimestamp(AggregatorV3Interface priceFeed) internal view returns (uint) {
        (
        uint80 roundID,
        int price,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return timeStamp;
    }

    /// @dev Overflow proof multiplication
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) return 0;
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
}