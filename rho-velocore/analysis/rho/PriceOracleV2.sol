// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "src/interface/IPriceOracleV2.sol";
import "src/utils/FixedPointMath.sol";
import "src/interface/IPythFeed.sol";

/**
 * @title PriceFeedStorage
 * @dev PriceFeedStorage Contract to hold state variables to ensure continuity across upgrades.
 */
contract PriceOracleV2 is OwnableUpgradeable, IPriceOracleV2 {
    // Chainlink state
    uint256 public freshCheck;
    uint256 public gracePeriodTime;
    mapping(address => address) public chainlinkPriceFeeds;
    AggregatorV3Interface public sequencerUptimeFeed;

    // Pyth state
    mapping(address => bytes32) public pythPriceFeedIDs;
    IPythFeed public pythOracle;

    // General price state
    mapping(address => uint256) public prices;

    // Asset specific oracle configurations
    mapping(address => OracleData[]) public assetConfigs;
    mapping(address => RTokenConfig) public configs;

    /**
     * @dev Constructor initializes the contract using OpenZeppelin's Initializable.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract with the OpenZeppelin's Ownable for upgradeable contracts.
     */
    function initialize() external initializer {
        __Ownable_init(msg.sender);
    }

    // External functions related to price feeds
    function setChainlinkPriceFeed(RToken rToken, address priceFeed_) external onlyOwner {
        address underlyingAddr = address(getUnderlying(rToken));
        chainlinkPriceFeeds[underlyingAddr] = priceFeed_;
        emit ChainlinkPriceUpdated(underlyingAddr, priceFeed_);
    }

    function setSequencerUptimeFeed(address sequencerUptimeFeed_) external onlyOwner {
        address oldSequencerUptimeFeed = address(sequencerUptimeFeed);
        sequencerUptimeFeed = AggregatorV3Interface(sequencerUptimeFeed_);
        emit UpdateSequencerUptimeFeed(oldSequencerUptimeFeed, sequencerUptimeFeed_);
    }

    function setGracePeriodTime(uint256 gracePeriodTime_) external onlyOwner {
        uint256 oldGracePeriodTime = gracePeriodTime;
        gracePeriodTime = gracePeriodTime_;
        emit UpdateGracePeriodTime(oldGracePeriodTime, gracePeriodTime_);
    }

    function setFreshCheck(uint256 freshCheck_) external onlyOwner {
        uint256 oldFreshCheck = freshCheck;
        freshCheck = freshCheck_;
        emit UpdateFreshCheck(oldFreshCheck, freshCheck_);
    }

    function getGracePeriodTime() external view override returns (uint256) {
        return gracePeriodTime;
    }

    function getFreshCheck() external view override returns (uint256) {
        return freshCheck;
    }

    function getSequencerUptimeFeed() external view override returns (address) {
        return address(sequencerUptimeFeed);
    }

    function getChainlinkPriceFeed(RToken rToken) external view override returns (address) {
        address underlyingAddr = address(getUnderlying(rToken));
        return chainlinkPriceFeeds[underlyingAddr];
    }

    // Public view functions to fetch price feed data
    function getPythPrice(RToken rToken) public view override returns (int64, int32) {
        address underlyingAddr = address(getUnderlying(rToken));

        bytes32 priceFeedID = pythPriceFeedIDs[underlyingAddr];
        IPythFeed priceFeed = IPythFeed(pythOracle);

        IPythFeed.Price memory priceInfo = priceFeed.getPrice(priceFeedID);

        if (priceInfo.price < 0) {
            revert NegativeOraclePrice();
        }

        return (priceInfo.price, priceInfo.expo);
    }

    function setPythPriceFeed(RToken rToken, bytes32 priceFeed_) external override onlyOwner {
        address underlyingAddr = address(getUnderlying(rToken));

        bytes32 priceFeedID = pythPriceFeedIDs[underlyingAddr];

        if (priceFeedID != bytes32(0)) {
            revert PythID_Initialized();
        }

        pythPriceFeedIDs[underlyingAddr] = priceFeed_;

        emit AssetPriceUpdated(underlyingAddr, priceFeed_);
    }

    function setPyth(address pythOracle_) external override onlyOwner {
        if (pythOracle_ == address(0)) {
            revert SetupZeroAddress();
        }

        pythOracle = IPythFeed(pythOracle_);

        emit PythContractInit(pythOracle_);
    }

    function getChainlinkPrice(RToken rToken) public view returns (uint256, uint256, uint256) {
        address underlyingAddr = address(getUnderlying(rToken));

        address priceFeed = chainlinkPriceFeeds[underlyingAddr];

        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= gracePeriodTime) {
            revert GracePeriodNotOver();
        }

        AggregatorV3Interface aggregator = AggregatorV3Interface(priceFeed);
        (, int256 price,, uint256 updatedAt,) = aggregator.latestRoundData();

        bool isPriceFresh = (block.timestamp - updatedAt) < freshCheck;
        if (!isPriceFresh) {
            revert PriceNotFresh();
        }

        uint256 rawPrice = uint256(price);
        uint256 decimals = uint256(aggregator.decimals());
        uint256 decimalDelta = 18 - uint256(aggregator.decimals());

        uint256 scaledPrice = rawPrice * (10 ** decimalDelta);

        return (rawPrice, scaledPrice, decimals);
    }

    function setRTokenConfig(RToken rToken, address underlyingAddr, uint8 decimals) external onlyOwner {
        address rTokenAddr = address(rToken);

        configs[rTokenAddr] = RTokenConfig({underlying: ERC20(underlyingAddr), rToken: rToken, decimals: decimals});

        emit RTokenConfigUpdate(rTokenAddr, underlyingAddr);
    }

    function getUnderlying(RToken rToken) public view returns (ERC20 underlying) {
        return configs[address(rToken)].underlying;
    }

    function getRTokenConfig(RToken rToken) public view returns (RTokenConfig memory) {
        RTokenConfig memory data = configs[address(rToken)];
        return data;
    }

    function addOracle(RToken rToken, bytes4 functionSelector, uint256 priority) public onlyOwner {
        address underlyingAddr = address(getUnderlying(rToken));

        assetConfigs[underlyingAddr].push(OracleData(priority, functionSelector));
        emit OracleAdded(underlyingAddr, functionSelector, priority);
    }

    function removeOracle(RToken rToken, bytes4 functionSelector) public onlyOwner {
        address underlyingAddr = address(getUnderlying(rToken));

        OracleData[] storage config = assetConfigs[underlyingAddr];
        int256 oracleIndex = -1;

        for (uint256 i = 0; i < config.length; i++) {
            if (config[i].functionSelector == functionSelector) {
                oracleIndex = int256(i);
                break;
            }
        }

        if (oracleIndex == -1) {
            revert OracleNotFound();
        }

        config[uint256(oracleIndex)] = config[config.length - 1];
        config.pop();
        emit OracleRemoved(underlyingAddr, functionSelector);
    }

    function updateOraclePriority(RToken rToken, bytes4 functionSelector, uint256 newPriority) public onlyOwner {
        address underlyingAddr = address(getUnderlying(rToken));
        OracleData[] storage config = assetConfigs[underlyingAddr];
        bool updated = false;

        for (uint256 i = 0; i < config.length; i++) {
            if (config[i].functionSelector == functionSelector) {
                config[i].priority = newPriority;
                updated = true;
                emit OraclePriorityUpdated(underlyingAddr, functionSelector, newPriority);
                break;
            }
        }

        if (!updated) {
            revert OracleWithGivenSelectorNotFound();
        }
    }

    function getPrice(RToken rToken) public view override returns (uint256) {
        return getPriceCommon(rToken, false);
    }

    function getUnderlyingPrice(RToken rToken) public view override returns (uint256) {
        return getPriceCommon(rToken, true);
    }

    function getPriceCommon(RToken rToken, bool isUnderlying) internal view returns (uint256 price) {
        address underlyingAddr = address(getUnderlying(rToken));
        OracleData[] storage config = assetConfigs[underlyingAddr];

        if (config.length == 0) {
            revert NoOraclesAvailable();
        }

        OracleData[] memory sortedOracles = new OracleData[](config.length);
        for (uint256 i = 0; i < config.length; i++) {
            sortedOracles[i] = config[i];
        }

        sortOraclesByPriority(sortedOracles);

        // return highest priority oracle price
        bytes4 functionSig = sortedOracles[0].functionSelector;

        if (isUnderlying) {
            price = getUnderlyingScaledPrice(rToken, functionSig);
            return price;
        } else {
            price = getStandardizedPrice(rToken, functionSig);
            return price;
        }
    }

    function getStandardizedPrice(RToken rToken, bytes4 functionSig) internal view returns (uint256 price) {
        if (PriceOracleV2(this).getChainlinkPrice.selector == functionSig) {
            (, uint256 price_,) = getChainlinkPrice(rToken);
            price = price_;
        } else if (PriceOracleV2(this).getPythPrice.selector == functionSig) {
            (int64 pythPrice, int32 expo) = getPythPrice(rToken);
            price = uint256(uint64(pythPrice)) * 10 ** uint256(uint32(18 - expo));
        }
    }

    function getUnderlyingScaledPrice(RToken rToken, bytes4 functionSig) internal view returns (uint256 price) {
        ERC20 underlying = getUnderlying(rToken);
        uint256 decimals = address(underlying) == address(0) ? 18 : underlying.decimals();

        uint256 feedDecimals;

        if (functionSig == PriceOracleV2(this).getChainlinkPrice.selector) {
            (uint256 rawPrice,, uint256 decimals_) = getChainlinkPrice(rToken);
            feedDecimals = decimals_;
            price = scalePrice(rawPrice, feedDecimals, decimals);
        } else if (functionSig == PriceOracleV2(this).getPythPrice.selector) {
            (int64 pythPrice, int32 expo) = getPythPrice(rToken);
            feedDecimals = uint256(uint32(expo));
            price = uint256(uint64(pythPrice));
            price = scalePrice(price, feedDecimals, decimals);
        }

        // Multiply by 10^36 and then divide by the square of the underlying token's decimals
        price = price * 10 ** (36 - 2 * decimals);
    }

    function scalePrice(uint256 price, uint256 fromDecimals, uint256 toDecimals) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return price / 10 ** (fromDecimals - toDecimals);
        } else {
            return price * 10 ** (toDecimals - fromDecimals);
        }
    }

    function sortOraclesByPriority(OracleData[] memory oracles) internal pure {
        uint256 length = oracles.length;
        for (uint256 i = 1; i < length; i++) {
            OracleData memory key = oracles[i];
            int256 j = int256(i) - 1;

            while (j >= 0 && oracles[uint256(j)].priority < key.priority) {
                oracles[uint256(j + 1)] = oracles[uint256(j)];
                j--;
            }

            oracles[uint256(j + 1)] = key;
        }
    }
}

