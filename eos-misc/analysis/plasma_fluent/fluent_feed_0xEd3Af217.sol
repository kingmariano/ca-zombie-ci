// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AggregatorInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorInterface.sol";
import {IVenaPythPrices} from "./interfaces/IVenaPythPrices.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PythProAggregatorAdapter
/// @notice Adapter contract that exposes Pyth Lazer prices through the Chainlink AggregatorInterface
/// @dev Queries VenaPythPrices contract and adapts the response to match Chainlink's interface
contract PythProAggregatorAdapter is AggregatorInterface, Ownable2Step {
    using SafeCast for uint256;

    /// @notice Maximum allowed staleness (24 hours)
    uint256 public constant MAX_STALENESS_LIMIT = 86_400;

    /// @notice The feed ID to query from VenaPythPrices
    uint32 internal immutable i_feedId;

    /// @notice The VenaPythPrices contract instance
    IVenaPythPrices internal immutable i_venaPythPrices;

    /// @notice Maximum allowed age of a price before it's considered stale
    uint256 internal s_maxStaleness;

    /// @notice Emitted when max staleness is updated
    event MaxStalenessUpdated(uint256 oldMaxStaleness, uint256 newMaxStaleness);

    /// @notice Thrown when VenaPythPrices address is zero
    error InvalidVenaPythPricesAddress();

    /// @notice Thrown when price is stale or timestamp is in the future
    /// @param timestamp The price timestamp
    /// @param currentTime Current block timestamp
    /// @param maxStaleness Maximum allowed staleness
    error StalePrice(uint64 timestamp, uint256 currentTime, uint256 maxStaleness);

    /// @notice Thrown when round ID is out of bounds
    /// @param roundId The requested round ID
    /// @param maxRound The maximum available round
    error RoundIdOutOfBounds(uint256 roundId, uint256 maxRound);

    /// @notice Thrown when staleness value is invalid
    /// @param staleness The invalid staleness value
    error InvalidStaleness(uint256 staleness);

    /// @notice Constructs the adapter
    /// @param venaPythPricesAddress The address of the VenaPythPrices contract
    /// @param feedId The feed ID to query (no validation - any uint32 value is accepted as Pyth may use feedId=0)
    /// @param maxStaleness Maximum allowed age of a price in seconds
    constructor(address venaPythPricesAddress, uint32 feedId, uint256 maxStaleness) Ownable(msg.sender) {
        if (venaPythPricesAddress == address(0)) {
            revert InvalidVenaPythPricesAddress();
        }
        if (maxStaleness > MAX_STALENESS_LIMIT) {
            revert InvalidStaleness(maxStaleness);
        }
        // Note: feedId is not validated as 0 may be a valid Pyth feed ID
        // The adapter will simply query whatever feedId is configured
        i_venaPythPrices = IVenaPythPrices(venaPythPricesAddress);
        i_feedId = feedId;
        s_maxStaleness = maxStaleness;
        emit MaxStalenessUpdated(0, maxStaleness);
    }

    /// @notice Updates the maximum staleness setting
    /// @param newMaxStaleness The new maximum staleness in seconds
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        if (newMaxStaleness > MAX_STALENESS_LIMIT) {
            revert InvalidStaleness(newMaxStaleness);
        }
        emit MaxStalenessUpdated(s_maxStaleness, newMaxStaleness);
        s_maxStaleness = newMaxStaleness;
    }

    /// @notice Returns the latest price for the configured feed
    /// @return The latest price as an int256
    function latestAnswer() external view virtual override returns (int256) {
        (uint64 price, uint64 timestamp) = i_venaPythPrices.getLatestPriceAndTimestamp(i_feedId);

        // Check for future timestamps or staleness
        // Safe to use unchecked since timestamp > block.timestamp check prevents underflow
        unchecked {
            if (timestamp > block.timestamp || block.timestamp - timestamp > s_maxStaleness) {
                revert StalePrice(timestamp, block.timestamp, s_maxStaleness);
            }
        }

        return uint256(price).toInt256();
    }

    /// @notice Returns the timestamp of the latest price update
    /// @return The timestamp as a uint256
    function latestTimestamp() external view override returns (uint256) {
        return i_venaPythPrices.getLatestTimestamp(i_feedId);
    }

    /// @notice Returns the latest round ID (0-based index of the latest price)
    /// @return The latest round ID
    function latestRound() external view override returns (uint256) {
        uint256 length = i_venaPythPrices.getPriceHistoryLength(i_feedId);
        require(length > 0, "No price history available");
        return length - 1;
    }

    /// @notice Returns the price for a specific round
    /// @param roundId The round ID (0-indexed, corresponding to array index)
    /// @return The price for the specified round as an int256
    function getAnswer(uint256 roundId) external view virtual override returns (int256) {
        uint256 historyLength = i_venaPythPrices.getPriceHistoryLength(i_feedId);
        if (roundId >= historyLength) {
            revert RoundIdOutOfBounds(roundId, historyLength);
        }

        // Use getPriceAtRound to avoid loading entire history into memory
        IVenaPythPrices.FeedPrice memory feedPrice = i_venaPythPrices.getPriceAtRound(i_feedId, roundId);
        return uint256(feedPrice.price).toInt256();
    }

    /// @notice Returns the timestamp for a specific round
    /// @param roundId The round ID (0-indexed, corresponding to array index)
    /// @return The timestamp for the specified round
    function getTimestamp(uint256 roundId) external view override returns (uint256) {
        uint256 historyLength = i_venaPythPrices.getPriceHistoryLength(i_feedId);
        if (roundId >= historyLength) {
            revert RoundIdOutOfBounds(roundId, historyLength);
        }

        // Use getPriceAtRound to avoid loading entire history into memory
        IVenaPythPrices.FeedPrice memory feedPrice = i_venaPythPrices.getPriceAtRound(i_feedId, roundId);
        return feedPrice.timestamp;
    }

    /// @notice Gets the VenaPythPrices contract instance
    /// @return The VenaPythPrices contract
    function getVenaPythPrices() external view returns (IVenaPythPrices) {
        return i_venaPythPrices;
    }

    /// @notice Gets the configured feed ID
    /// @return The feed ID
    function getFeedId() external view returns (uint32) {
        return i_feedId;
    }

    /// @notice Gets the maximum staleness setting
    /// @return The maximum staleness in seconds
    function getMaxStaleness() external view returns (uint256) {
        return s_maxStaleness;
    }

    /// @notice Gets the number of decimals for the price feed
    /// @dev Returns the absolute value of the exponent from the latest price update
    /// @return The number of decimals (e.g., 8 for a price with 8 decimal places)
    function decimals() external view returns (uint8) {
        IVenaPythPrices.FeedPrice memory latestPrice =
            i_venaPythPrices.getPriceAtRound(i_feedId, i_venaPythPrices.getPriceHistoryLength(i_feedId) - 1);
        // Pyth exponents are negative (e.g., -8 means 8 decimals)
        // Return the absolute value as uint8
        return uint8(uint16(-latestPrice.exponent));
    }
}
