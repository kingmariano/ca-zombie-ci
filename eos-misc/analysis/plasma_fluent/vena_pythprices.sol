// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IPythLazer} from "./interfaces/IPythLazer.sol";
import {PythLazerLib} from "@pyth-lazer/lazer/contracts/evm/src/PythLazerLib.sol";
import {PythLazerStructs} from "@pyth-lazer/lazer/contracts/evm/src/PythLazerStructs.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IVenaPythPrices} from "./interfaces/IVenaPythPrices.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title VenaPythPrices
/// @notice Stores and manages Pyth Lazer price updates for multiple feeds
/// @dev Verifies and parses Pyth Lazer price updates, storing price history for each feed.
///      Writes are gated by `PRICE_UPDATER_ROLE` so single-feed updates cannot be used to
///      desynchronize aggregator consumers' timestamp invariants. The constructor-supplied
///      `defaultAdmin` receives `DEFAULT_ADMIN_ROLE` and can grant or revoke
///      `PRICE_UPDATER_ROLE` thereafter. The deployer (`msg.sender`) is not auto-granted
///      any role, so a multisig / timelock can be set as admin atomically at deploy time
///      without a follow-up transfer step.
contract VenaPythPrices is IVenaPythPrices, AccessControl {
    using SafeCast for int64;
    using SafeCast for int256;
    using SafeCast for uint256;
    using PythLazerLib for PythLazerStructs.Feed;

    /// @notice Role granted to addresses authorized to call `updatePrices`
    bytes32 public constant PRICE_UPDATER_ROLE = keccak256("PRICE_UPDATER_ROLE");

    /// @notice The Pyth Lazer contract instance
    IPythLazer private immutable i_pythLazer;

    /// @notice Mapping of feed ID to price history array
    mapping(uint32 feedId => FeedPrice[] priceHistory) private s_priceHistoryByFeedId;

    /// @notice Emitted when a price is updated for a feed
    /// @param feedId The feed identifier
    /// @param price The updated price
    /// @param timestamp The timestamp of the price update
    event PriceUpdated(uint32 indexed feedId, uint64 price, uint64 timestamp);

    /// @notice Thrown when PythLazer address is zero
    error InvalidPythLazerAddress();

    /// @notice Thrown when the default admin address is zero
    error InvalidDefaultAdminAddress();

    /// @notice Thrown when no price data is available for a feed
    /// @param feedId The feed identifier with no data
    error NoPriceData(uint32 feedId);

    /// @notice Thrown when array index is out of bounds
    /// @param index The requested index
    /// @param length The array length
    error IndexOutOfBounds(uint256 index, uint256 length);

    /// @notice Thrown when refund of excess payment fails
    error RefundFailed();

    /// @notice Constructs the VenaPythPrices contract
    /// @dev `defaultAdmin` is granted `DEFAULT_ADMIN_ROLE` (deployer gets no role).
    ///      Each address in `priceUpdaters` is granted `PRICE_UPDATER_ROLE` so the contract
    ///      is usable in a single deploy tx without a follow-up grant. Pass an empty array
    ///      to defer authorization until after deploy.
    /// @param pythLazerAddress The address of the Pyth Lazer contract
    /// @param defaultAdmin Address granted `DEFAULT_ADMIN_ROLE` (typically a multisig / timelock)
    /// @param priceUpdaters Initial set of addresses to grant `PRICE_UPDATER_ROLE`
    constructor(address pythLazerAddress, address defaultAdmin, address[] memory priceUpdaters) {
        if (pythLazerAddress == address(0)) revert InvalidPythLazerAddress();
        if (defaultAdmin == address(0)) revert InvalidDefaultAdminAddress();
        i_pythLazer = IPythLazer(pythLazerAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        for (uint256 i; i < priceUpdaters.length; ++i) {
            _grantRole(PRICE_UPDATER_ROLE, priceUpdaters[i]);
        }
    }

    /// @notice Updates prices from a Pyth Lazer price update payload
    /// @dev Verifies the update through Pyth Lazer and parses all feeds in the payload
    /// @dev Restricted to holders of `PRICE_UPDATER_ROLE`
    /// @dev Refund at end follows checks-effects-interactions pattern, safe from reentrancy
    /// @param priceUpdate The encoded price update data from Pyth Lazer
    function updatePrices(bytes calldata priceUpdate) external payable onlyRole(PRICE_UPDATER_ROLE) {
        uint256 verificationFee = i_pythLazer.verification_fee();
        (bytes memory payload,) = i_pythLazer.verifyUpdate{value: verificationFee}(priceUpdate);

        // Use Pyth's parser to extract all feed data
        PythLazerStructs.Update memory update = PythLazerLib.parseUpdateFromPayload(payload);

        // Convert timestamp from microseconds to seconds
        uint64 _timestamp = update.timestamp / 1_000_000;

        // Process each feed
        for (uint8 i; i < update.feeds.length; ++i) {
            PythLazerStructs.Feed memory feed = update.feeds[i];

            // Only process if price is present (check tri-state map, not just non-zero)
            if (feed.hasPrice() && feed.hasExponent() && feed.hasConfidence()) {
                uint64 _price = int256(feed._price).toUint256().toUint64();
                int16 _exponent = feed._exponent;
                uint64 _confidence = feed._confidence;

                // Only update if this timestamp is newer than the latest
                FeedPrice[] storage history = s_priceHistoryByFeedId[feed.feedId];

                uint256 historyLength = history.length;
                unchecked {
                    if (historyLength == 0 || _timestamp > history[historyLength - 1].timestamp) {
                        history.push(
                            FeedPrice({
                                timestamp: _timestamp, price: _price, exponent: _exponent, confidence: _confidence
                            })
                        );
                        emit PriceUpdated(feed.feedId, _price, _timestamp);
                    }
                }
            }
        }

        // Refund any excess payment (follows CEI pattern, all state changes complete)
        if (msg.value > verificationFee) {
            (bool success,) = msg.sender.call{value: msg.value - verificationFee}("");
            if (!success) {
                revert RefundFailed();
            }
        }
    }

    /// @inheritdoc IVenaPythPrices
    function getLatestPrice(uint32 feedId) external view returns (uint64) {
        FeedPrice[] storage history = s_priceHistoryByFeedId[feedId];
        if (history.length == 0) revert NoPriceData(feedId);

        unchecked {
            return history[history.length - 1].price;
        }
    }

    /// @inheritdoc IVenaPythPrices
    function getLatestTimestamp(uint32 feedId) external view returns (uint64) {
        FeedPrice[] storage history = s_priceHistoryByFeedId[feedId];
        if (history.length == 0) revert NoPriceData(feedId);

        unchecked {
            return history[history.length - 1].timestamp;
        }
    }

    /// @inheritdoc IVenaPythPrices
    function getLatestPriceAndTimestamp(uint32 feedId) external view returns (uint64 price, uint64 timestamp) {
        FeedPrice[] storage history = s_priceHistoryByFeedId[feedId];
        if (history.length == 0) revert NoPriceData(feedId);

        unchecked {
            FeedPrice storage latest = history[history.length - 1];
            return (latest.price, latest.timestamp);
        }
    }

    /// @inheritdoc IVenaPythPrices
    function getPriceHistoryLength(uint32 feedId) external view returns (uint256) {
        return s_priceHistoryByFeedId[feedId].length;
    }

    /// @notice Gets the Pyth Lazer contract instance
    /// @return The Pyth Lazer contract
    function getPythLazer() external view returns (IPythLazer) {
        return i_pythLazer;
    }

    /// @inheritdoc IVenaPythPrices
    function getPriceAtRound(uint32 feedId, uint256 index) external view returns (FeedPrice memory) {
        FeedPrice[] storage history = s_priceHistoryByFeedId[feedId];
        if (index >= history.length) {
            revert IndexOutOfBounds(index, history.length);
        }
        return history[index];
    }
}
