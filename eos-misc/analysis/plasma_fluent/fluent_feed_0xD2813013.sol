// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {
    AggregatorInterface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorInterface.sol";
import {PythProAggregatorAdapter} from "./PythProAggregatorAdapter.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title AggregatedPythPriceAdapter
/// @notice Composes two `PythProAggregatorAdapter` instances into a single price by either
///         multiplying or dividing them, exposed through the Chainlink AggregatorInterface
/// @dev Each child adapter performs its own staleness, empty-history, and exponent handling, so
///      this contract is purely arithmetic. The result carries `primary.decimals()` decimal places.
///      Multiply: priceOut = (primaryPrice * secondaryPrice) / 10^secondary.decimals()
///      Divide:   priceOut = (primaryPrice * 10^secondary.decimals()) / secondaryPrice
/// @dev Operational invariant: both child feeds are expected to be updated atomically (i.e. via
///      a single upstream Pyth Lazer bundle that includes both feeds), so their stored timestamps
///      always match. `latestAnswer` enforces this with a `TimestampMismatch` revert; `latestRound`
///      and `latestTimestamp` trust the invariant for cheap reads. Operators must therefore push
///      the aggregator's two feeds together; a single-feed update will cause `latestAnswer` to
///      revert until the next atomic bundle restores equality.
contract AggregatedPythPriceAdapter is AggregatorInterface {
    using SafeCast for int256;
    using SafeCast for uint256;

    /// @notice Primary feed adapter (numerator in divide mode; left operand in multiply mode)
    PythProAggregatorAdapter private immutable i_primaryAdapter;

    /// @notice Secondary feed adapter (denominator in divide mode; right operand in multiply mode)
    PythProAggregatorAdapter private immutable i_secondaryAdapter;

    /// @notice If true, divide primary by secondary; otherwise multiply
    bool private immutable i_divide;

    /// @notice Thrown when the primary adapter address is zero
    error InvalidPrimaryAdapterAddress();

    /// @notice Thrown when the secondary adapter address is zero
    error InvalidSecondaryAdapterAddress();

    /// @notice Thrown when both adapters are the same address (degenerate configuration)
    error DuplicateAdapter();

    /// @notice Thrown when the primary adapter returns a non-positive price
    error NonPositivePrimaryPrice(int256 price);

    /// @notice Thrown when the secondary adapter returns a non-positive price
    error NonPositiveSecondaryPrice(int256 price);

    /// @notice Thrown when the two children's stored timestamps don't match for the requested read.
    /// @dev The aggregator's math is only meaningful when both legs reflect the same instant.
    ///      Requiring exact equality means both feeds must come from the same upstream Pyth Lazer
    ///      bundle (which carries a single timestamp for all feeds it contains).
    error TimestampMismatch(
        uint256 primaryTimestamp,
        uint256 secondaryTimestamp
    );

    /// @notice Constructs the adapter
    /// @param primaryAdapter Address of the primary `PythProAggregatorAdapter` (or a subclass)
    /// @param secondaryAdapter Address of the secondary `PythProAggregatorAdapter` (or a subclass)
    /// @param divide If true, divide primary by secondary; if false, multiply them
    constructor(address primaryAdapter, address secondaryAdapter, bool divide) {
        if (primaryAdapter == address(0)) revert InvalidPrimaryAdapterAddress();
        if (secondaryAdapter == address(0)) {
            revert InvalidSecondaryAdapterAddress();
        }
        if (primaryAdapter == secondaryAdapter) revert DuplicateAdapter();

        i_primaryAdapter = PythProAggregatorAdapter(primaryAdapter);
        i_secondaryAdapter = PythProAggregatorAdapter(secondaryAdapter);
        i_divide = divide;
    }

    /// @notice Returns the aggregated price using the latest values from both child adapters
    /// @dev Reverts with `TimestampMismatch` if the two children's latest stored timestamps differ,
    ///      preventing cross-feed timing skew within the per-leg staleness window.
    /// @return The latest combined price as an int256, scaled to the primary adapter's decimals
    function latestAnswer() external view override returns (int256) {
        uint256 primaryTimestamp = i_primaryAdapter.latestTimestamp();
        uint256 secondaryTimestamp = i_secondaryAdapter.latestTimestamp();
        if (primaryTimestamp != secondaryTimestamp) {
            revert TimestampMismatch(primaryTimestamp, secondaryTimestamp);
        }
        int256 primaryPrice = i_primaryAdapter.latestAnswer();
        int256 secondaryPrice = i_secondaryAdapter.latestAnswer();
        return _aggregate(primaryPrice, secondaryPrice);
    }

    /// @notice Returns the timestamp of the latest aggregate read
    /// @dev Returns the primary adapter's latest timestamp directly. Per the contract-level
    ///      operational invariant, both children share the same timestamp on every update, so
    ///      this also equals the secondary's latest timestamp. If the invariant is broken (e.g.
    ///      a single-feed update slipped through), `latestAnswer` will revert with
    ///      `TimestampMismatch`; consumers gating on freshness should ultimately validate by
    ///      calling `latestAnswer` rather than trusting this value alone.
    /// @return The latest aggregate timestamp
    function latestTimestamp() external view override returns (uint256) {
        return i_primaryAdapter.latestTimestamp();
    }

    /// @notice Returns the primary adapter's latest round
    /// @dev Round indexing follows the primary feed; the secondary feed's history is not consulted
    ///      here. Per the contract-level operational invariant the primary and secondary advance
    ///      together, so this round corresponds to the same atomic update on the secondary side.
    /// @return The latest round id from the primary feed
    function latestRound() external view override returns (uint256) {
        return i_primaryAdapter.latestRound();
    }

    /// @notice Returns the aggregated price at `roundId` for both children
    /// @dev Reads `roundId` from both primary and secondary. Under the operational invariant that
    ///      both feeds are updated atomically (same Pyth Lazer bundle), `history[roundId]` on each
    ///      side comes from the same atomic update and the timestamps match by construction. The
    ///      `TimestampMismatch` revert acts as a runtime canary — it should never fire under
    ///      correct operation, but catches misconfiguration (e.g. wrong children, mid-deploy state)
    ///      before serving a skewed answer.
    /// @param roundId The round id to read from both children
    /// @return The aggregate price at `roundId`
    function getAnswer(
        uint256 roundId
    ) external view override returns (int256) {
        uint256 primaryTimestamp = i_primaryAdapter.getTimestamp(roundId);
        uint256 secondaryTimestamp = i_secondaryAdapter.getTimestamp(roundId);
        if (primaryTimestamp != secondaryTimestamp) {
            revert TimestampMismatch(primaryTimestamp, secondaryTimestamp);
        }
        int256 primaryPrice = i_primaryAdapter.getAnswer(roundId);
        int256 secondaryPrice = i_secondaryAdapter.getAnswer(roundId);
        return _aggregate(primaryPrice, secondaryPrice);
    }

    /// @notice Returns the timestamp at the primary adapter's `roundId`
    function getTimestamp(
        uint256 roundId
    ) external view override returns (uint256) {
        return i_primaryAdapter.getTimestamp(roundId);
    }

    /// @notice Decimals of the aggregate output (matches the primary adapter)
    function decimals() external view returns (uint8) {
        return i_primaryAdapter.decimals();
    }

    /// @notice Gets the primary child adapter
    function getPrimaryAdapter()
        external
        view
        returns (PythProAggregatorAdapter)
    {
        return i_primaryAdapter;
    }

    /// @notice Gets the secondary child adapter
    function getSecondaryAdapter()
        external
        view
        returns (PythProAggregatorAdapter)
    {
        return i_secondaryAdapter;
    }

    /// @notice Returns whether the adapter divides (true) or multiplies (false) the two feeds
    function isDivide() external view returns (bool) {
        return i_divide;
    }

    /// @dev Aggregation core. Reverts on non-positive inputs.
    ///      Multiply: result = (primaryPrice * secondaryPrice) / 10^secondaryDecimals
    ///      Divide:   result = (primaryPrice * 10^secondaryDecimals) / secondaryPrice
    function _aggregate(
        int256 primaryPrice,
        int256 secondaryPrice
    ) private view returns (int256) {
        if (primaryPrice <= 0) revert NonPositivePrimaryPrice(primaryPrice);
        if (secondaryPrice <= 0) {
            revert NonPositiveSecondaryPrice(secondaryPrice);
        }

        uint256 secondaryScale = 10 ** uint256(i_secondaryAdapter.decimals());
        uint256 p = primaryPrice.toUint256();
        uint256 s = secondaryPrice.toUint256();

        if (i_divide) {
            return ((p * secondaryScale) / s).toInt256();
        }
        return ((p * s) / secondaryScale).toInt256();
    }
}
