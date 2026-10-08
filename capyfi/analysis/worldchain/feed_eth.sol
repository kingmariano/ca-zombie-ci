// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ^0.8.10;

// src/contracts/PriceOracle/AggregatorV3Interface.sol

/**
 * @title AggregatorInterface
 * @dev Interface for Chainlink Aggregator V2 functionality
 */
interface AggregatorInterface {
  /// @dev Returns the latest answer from the aggregator
  /// @return The latest price answer
  function latestAnswer() external view returns (int256);
  
  /// @dev Returns the timestamp of the latest answer
  /// @return The timestamp when the latest answer was updated
  function latestTimestamp() external view returns (uint256);
  
  /// @dev Returns the latest round ID
  /// @return The ID of the latest round
  function latestRound() external view returns (uint256);
  
  /// @dev Returns the answer for a specific round
  /// @param roundId The round ID to get the answer for
  /// @return The price answer for the specified round
  function getAnswer(uint256 roundId) external view returns (int256);
  
  /// @dev Returns the timestamp for a specific round
  /// @param roundId The round ID to get the timestamp for
  /// @return The timestamp when the specified round was updated
  function getTimestamp(uint256 roundId) external view returns (uint256);

  /// @dev Emitted when the answer is updated
  /// @param current The new answer value
  /// @param roundId The round ID associated with the answer
  /// @param updatedAt The timestamp when the answer was updated
  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
  
  /// @dev Emitted when a new round is started
  /// @param roundId The ID of the new round
  /// @param startedBy The address that started the round
  /// @param startedAt The timestamp when the round was started
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

/**
 * @title AggregatorV3Interface
 * @dev Interface for Chainlink Aggregator V3 functionality with enhanced round data
 */
interface AggregatorV3Interface {
  /// @dev Returns the number of decimals used in the price representation
  /// @return The number of decimals
  function decimals() external view returns (uint8);

  /// @dev Returns a description of what this price feed represents
  /// @return A string description of the price feed
  function description() external view returns (string memory);

  /// @dev Returns the version of this aggregator interface
  /// @return The version number
  function version() external view returns (uint256);

  /// @dev Returns round data for a specific round ID
  /// @param _roundId The round ID to retrieve data for
  /// @return roundId The round ID
  /// @return answer The price answer for this round
  /// @return startedAt The timestamp when the round started
  /// @return updatedAt The timestamp when the round was last updated
  /// @return answeredInRound The round ID in which the answer was computed
  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  /// @dev Returns data from the latest round
  /// @return roundId The latest round ID
  /// @return answer The latest price answer
  /// @return startedAt The timestamp when the latest round started
  /// @return updatedAt The timestamp when the latest round was last updated
  /// @return answeredInRound The round ID in which the latest answer was computed
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/**
 * @title AggregatorV2V3Interface
 * @dev Combined interface supporting both V2 and V3 aggregator functionality
 */
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }
}

// src/contracts/PriceOracle/CapyfiAggregatorV3.sol

contract CapyfiAggregatorV3 is AggregatorV2V3Interface, Ownable2Step {
    
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    uint8 private immutable _decimals;
    string private _description;
    uint256 private immutable _version;
    
    // Chainlink-compatible round ID management
    uint16 private currentPhaseId;
    uint64 private currentRoundId; // Original ID within phase
    mapping(uint80 => RoundData) private rounds;
    RoundData private _latestRound;
    
    // Optional price bounds 
    int256 public minAnswer;
    int256 public maxAnswer;
    bool public boundChecksEnabled;
    
    /// @dev Mapping of addresses authorized to update price feeds, in addition to the owner
    mapping(address => bool) public authorizedAddresses;

    /// @dev Emitted when an address is granted authorization to update prices
    /// @param addr The address that was granted authorization
    event AuthorizedAddressAdded(address indexed addr);
    
    /// @dev Emitted when an address has its authorization to update prices removed
    /// @param addr The address that had its authorization removed
    event AuthorizedAddressRemoved(address indexed addr);

    /// @dev Emitted when price bounds are configured
    /// @param minAnswer The minimum allowed price
    /// @param maxAnswer The maximum allowed price
    /// @param enabled Whether bounds checking is enabled
    event BoundsConfigured(int256 minAnswer, int256 maxAnswer, bool enabled);

    /// @dev Emitted when bounds checking is toggled
    /// @param enabled Whether bounds checking is enabled
    event BoundChecksToggled(bool enabled);

    error UnauthorizedCaller(address caller);
    error InvalidAddress(address addr);
    error InvalidPrice(int256 price);
    error PriceOutOfBounds(int256 price, int256 min, int256 max);
    error InvalidBounds(int256 min, int256 max);
    error NoRoundsAvailable();
    error AddressAlreadyAuthorized(address addr);
    error AddressNotAuthorized(address addr);

    modifier onlyAuthorized() {
        if (msg.sender != owner() && !authorizedAddresses[msg.sender]) {
            revert UnauthorizedCaller(msg.sender);
        }
        _;
    }

    /**
     * @notice Deploy the contract with initial parameters
     * @param decimals_ Number of decimals for the price feed
     * @param description_ Description of what this aggregator represents
     * @param version_ Version of the aggregator
     * @param initialPrice Initial price to set (cannot be 0)
     */
    constructor(
        uint8 decimals_,
        string memory description_,
        uint256 version_,
        int256 initialPrice
    ) {
        if (initialPrice <= 0) revert InvalidPrice(initialPrice);
        _decimals = decimals_;
        _description = description_;
        _version = version_;
        
        // Start with phase 1, round 1 (Chainlink-compatible)
        // This will create the first round ID as (1 << 64) + 1 = 18446744073709551617
        currentPhaseId = 1;
        currentRoundId = 1;
        
        _updateAnswer(initialPrice);
    }

    /**
     * @notice Add an authorized address that can update prices
     * @param addr Address to authorize
     */
    function addAuthorizedAddress(address addr) external onlyOwner {
        if (addr == address(0)) revert InvalidAddress(addr);
        if (authorizedAddresses[addr]) revert AddressAlreadyAuthorized(addr);
        authorizedAddresses[addr] = true;
        emit AuthorizedAddressAdded(addr);
    }

    /**
     * @notice Remove an authorized address
     * @param addr Address to remove authorization from
     */
    function removeAuthorizedAddress(address addr) external onlyOwner {
        if (addr == address(0)) revert InvalidAddress(addr);
        if (!authorizedAddresses[addr]) revert AddressNotAuthorized(addr);
        authorizedAddresses[addr] = false;
        emit AuthorizedAddressRemoved(addr);
    }

    /**
     * @notice Set price bounds (optional, like Chainlink)
     * @param _minAnswer Minimum allowed price
     * @param _maxAnswer Maximum allowed price
     * @param _enabled Whether to enable bounds checking
     */
    function setBounds(int256 _minAnswer, int256 _maxAnswer, bool _enabled) external onlyOwner {
        if (_minAnswer >= _maxAnswer) revert InvalidBounds(_minAnswer, _maxAnswer);
        
        minAnswer = _minAnswer;
        maxAnswer = _maxAnswer;
        boundChecksEnabled = _enabled;
        
        emit BoundsConfigured(_minAnswer, _maxAnswer, _enabled);
    }

    /**
     * @notice Toggle bounds checking on/off
     * @param _enabled Whether to enable bounds checking
     */
    function toggleBoundsChecking(bool _enabled) external onlyOwner {
        boundChecksEnabled = _enabled;
        emit BoundChecksToggled(_enabled);
    }

    /**
     * @notice Update the price (only owner or authorized addresses)
     * @param newAnswer New price to set
     */
    function updateAnswer(int256 newAnswer) external onlyAuthorized {
        if (newAnswer <= 0) revert InvalidPrice(newAnswer);
        
        // Optional bounds checking 
        if (boundChecksEnabled) {
            if (newAnswer < minAnswer || newAnswer > maxAnswer) {
                revert PriceOutOfBounds(newAnswer, minAnswer, maxAnswer);
            }
        }
        
        _updateAnswer(newAnswer);
    }

    /**
     * @notice Internal function to update the answer and create a new round
     * @param newAnswer New price to set
     */
    function _updateAnswer(int256 newAnswer) internal {
        uint256 timestamp = block.timestamp;
        
        // Create Chainlink-compatible round ID: (phaseId << 64) + originalId
        uint80 roundId = uint80((uint256(currentPhaseId) << 64) + currentRoundId);
        
        RoundData memory newRound = RoundData({
            roundId: roundId,
            answer: newAnswer,
            startedAt: timestamp,
            updatedAt: timestamp,
            answeredInRound: roundId
        });
        
        rounds[roundId] = newRound;
        _latestRound = newRound;
        
        emit AnswerUpdated(newAnswer, roundId, timestamp);
        emit NewRound(roundId, msg.sender, timestamp);
        
        currentRoundId++;
    }

    // AggregatorInterface (V2) implementation
    
    /**
     * @notice Get the latest answer without round data
     */
    function latestAnswer() external view override returns (int256) {
        if (_latestRound.roundId == 0) revert NoRoundsAvailable();
        return _latestRound.answer;
    }

    /**
     * @notice Get the timestamp of the latest update
     */
    function latestTimestamp() external view override returns (uint256) {
        if (_latestRound.roundId == 0) revert NoRoundsAvailable();
        return _latestRound.updatedAt;
    }

    /**
     * @notice Get the latest round ID (Chainlink-compatible format)
     */
    function latestRound() external view override returns (uint256) {
        return _latestRound.roundId;
    }

    /**
     * @notice Get the answer for a specific round (Chainlink-compatible)
     * @param roundId The round ID to get the answer for
     * @return answer The price, or 0 if round doesn't exist
     */
    function getAnswer(uint256 roundId) external view override returns (int256) {
        // Return 0 for invalid round IDs (like Chainlink)
        if (roundId > type(uint80).max) return 0;
        
        RoundData memory round = rounds[uint80(roundId)];
        return round.answer; // Returns 0 if round doesn't exist
    }

    /**
     * @notice Get the timestamp for a specific round (Chainlink-compatible)
     * @param roundId The round ID to get the timestamp for
     * @return timestamp The timestamp, or 0 if round doesn't exist
     */
    function getTimestamp(uint256 roundId) external view override returns (uint256) {
        // Return 0 for invalid round IDs (like Chainlink)
        if (roundId > type(uint80).max) return 0;
        
        RoundData memory round = rounds[uint80(roundId)];
        return round.updatedAt; // Returns 0 if round doesn't exist
    }

    // AggregatorV3Interface implementation

    /**
     * @notice Returns the number of decimals
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Returns the description
     */
    function description() external view override returns (string memory) {
        return _description;
    }

    /**
     * @notice Returns the version
     */
    function version() external view override returns (uint256) {
        return _version;
    }

    /**
     * @notice Get data from a specific round (Chainlink-compatible)
     * @param roundId The round ID to retrieve data for
     * @return roundId_ The round ID (0 if round doesn't exist)
     * @return answer The price (0 if round doesn't exist)
     * @return startedAt The timestamp when round started (0 if round doesn't exist)  
     * @return updatedAt The timestamp when round was updated (0 if round doesn't exist)
     * @return answeredInRound The round ID in which the answer was computed (0 if round doesn't exist)
     */
    function getRoundData(uint80 roundId) 
        external 
        view 
        override 
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        ) 
    {
        RoundData memory round = rounds[roundId];
        
        // Return zeros for non-existent rounds (like Chainlink)
        return (
            round.roundId,        
            round.answer,         
            round.startedAt,      
            round.updatedAt,     
            round.answeredInRound 
        );
    }

    /**
     * @notice Get data from the latest round
     */
    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        if (_latestRound.roundId == 0) revert NoRoundsAvailable();
        
        return (
            _latestRound.roundId,
            _latestRound.answer,
            _latestRound.startedAt,
            _latestRound.updatedAt,
            _latestRound.answeredInRound
        );
    }

    // Helper functions for Chainlink compatibility

    /**
     * @notice Helper function to check if a round exists
     * @param roundId The round ID to check
     * @return exists Whether the round exists
     */
    function roundExists(uint80 roundId) external view returns (bool) {
        return rounds[roundId].roundId != 0;
    }

    /**
     * @notice Get current phase and round info
     * @return phaseId Current phase ID
     * @return roundId Current round ID within the phase
     */
    function getCurrentPhaseInfo() external view returns (uint16 phaseId, uint64 roundId) {
        return (currentPhaseId, currentRoundId);
    }

    /**
     * @notice Extract phase ID from a round ID
     * @param roundId The round ID to extract from
     * @return phaseId The phase ID
     */
    function getPhaseId(uint80 roundId) external pure returns (uint16) {
        return uint16(roundId >> 64);
    }

    /**
     * @notice Extract original round ID from a round ID
     * @param roundId The round ID to extract from
     * @return originalRoundId The original round ID within the phase
     */
    function getOriginalRoundId(uint80 roundId) external pure returns (uint64) {
        return uint64(roundId);
    }
}