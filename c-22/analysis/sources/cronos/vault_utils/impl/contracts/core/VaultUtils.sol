// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/IVault.sol";
import "../peripherals/interfaces/ITimelock.sol";

import "../access/Governable.sol";

contract VaultUtils is IVaultUtils, Governable {
    IVault public vault;
    ITimelock public timelock;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant FUNDING_RATE_PRECISION = 1000000;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDG_DECIMALS = 18;

    function initialize(IVault _vault, ITimelock _timelock) public initializer {
        __Governable_init();
        vault = _vault;
        timelock = _timelock;
    }

    function setTimelock(ITimelock _timelock) external onlyGov {
        timelock = _timelock;
    }

    function updateCumulativeFundingRate(address /* _collateralToken */, address /* _indexToken */) public override returns (bool) {
        return true;
    }

    function validateIncreasePosition(address /* _account */, address /* _collateralToken */, address /* _indexToken */, uint256 /* _sizeDelta */, bool /* _isLong */) external override view {
        // no additional validations
    }

    function validateDecreasePosition(address /* _account */, address /* _collateralToken */, address /* _indexToken */ , uint256 /* _collateralDelta */, uint256 /* _sizeDelta */, bool /* _isLong */, address /* _receiver */) external override view {
        // no additional validations
    }

    function getPositionBroker(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (address, uint256) {
        IVault _vault = vault;
        bytes32 key = _vault.getPositionKey(_account, _collateralToken, _indexToken, _isLong);

        (,,,,,,, address brokerAddress, uint256 brokerFeeBasisPoints) = _vault.positions(key);

        return (brokerAddress, brokerFeeBasisPoints);
    }

    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (Position memory) {
        IVault _vault = vault;

        bytes32 key = _vault.getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        (
            uint256 size,
            uint256 collateral,
            uint256 averagePrice,
            uint256 entryFundingRate,
            /* uint256 reserveAmount */,
            /* int256 realisedPnl */,
            uint256 lastIncreasedTime,
            address brokerAddress,
            uint256 brokerFeeBasisPoints
        ) = _vault.positions(key);

        Position memory position;

        {
            position.size = size;
            position.collateral = collateral;
            position.averagePrice = averagePrice;
            position.entryFundingRate = entryFundingRate;
            position.lastIncreasedTime = lastIncreasedTime;
            position.brokerAddress = brokerAddress;
            position.brokerFeeBasisPoints = brokerFeeBasisPoints;
        }
        return position;
    }


    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) public view override returns (uint256, uint256) {
        Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);
        IVault _vault = vault;

        (bool hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
        uint256 marginFees = getFundingFee(_account, _collateralToken, _indexToken, _isLong, position.size, position.entryFundingRate);
        uint256 positionFee = getPositionFee(position.size);
        uint256 brokerFee = getBrokerFee(position.size, position.brokerFeeBasisPoints);
        marginFees = marginFees + positionFee + brokerFee;

        if (!hasProfit && position.collateral < delta) {
            if (_raise) { revert("Vault: losses exceed collateral"); }
            return (1, marginFees);
        }

        uint256 remainingCollateral = position.collateral;
        if (!hasProfit) {
            remainingCollateral = position.collateral - delta;
        }

        if (remainingCollateral < marginFees) {
            if (_raise) { revert("Vault: fees exceed collateral"); }
            // cap the fees to the remainingCollateral
            return (1, remainingCollateral);
        }

        if (remainingCollateral < marginFees + _vault.fixedLiquidationFeeUsd()) {
            if (_raise) { revert("Vault: liquidation fees exceed collateral"); }
            return (1, marginFees);
        }

        if (remainingCollateral * _vault.maxLeverage() < position.size * BASIS_POINTS_DIVISOR) {
            if (_raise) { revert("Vault: maxLeverage exceeded"); }
            return (2, marginFees);
        }

        return (0, marginFees);
    }

    function validateLiquidationForBot(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view override returns (uint256, uint256) {
        Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);
        IVault _vault = vault;

        (bool hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
        uint256 marginFees = getFundingFee(_account, _collateralToken, _indexToken, _isLong, position.size, position.entryFundingRate);
        uint256 positionFee = getPositionFeeForBot(position.size);
        uint256 brokerFee = getBrokerFee(position.size, position.brokerFeeBasisPoints);
        marginFees = marginFees + positionFee + brokerFee;

        if (!hasProfit && position.collateral < delta) {
            if (_raise) { revert("Vault: losses exceed collateral"); }
            return (1, marginFees);
        }

        uint256 remainingCollateral = position.collateral;
        if (!hasProfit) {
            remainingCollateral = position.collateral - delta;
        }

        if (remainingCollateral < marginFees) {
            if (_raise) { revert("Vault: fees exceed collateral"); }
            // cap the fees to the remainingCollateral
            return (1, remainingCollateral);
        }

        if (remainingCollateral < marginFees + _vault.fixedLiquidationFeeUsd()) {
            if (_raise) { revert("Vault: liquidation fees exceed collateral"); }
            return (1, marginFees);
        }

        if (remainingCollateral * _vault.maxLeverage() < position.size * BASIS_POINTS_DIVISOR) {
            if (_raise) { revert("Vault: maxLeverage exceeded"); }
            return (2, marginFees);
        }

        return (0, marginFees);
    }

    function getLiquidationFee(uint256 remainingCollateralUsd) public override view returns (uint256) {
        // ensures that remainingCollateralUsd > 0, as early revert when called
        uint256 afterfixedLiquidationFeeUsd = remainingCollateralUsd * (BASIS_POINTS_DIVISOR - vault.dynLiquidationFeeBasisPoints()) / BASIS_POINTS_DIVISOR;
        uint256 liquidationFee = remainingCollateralUsd - afterfixedLiquidationFeeUsd;
        return liquidationFee > vault.fixedLiquidationFeeUsd() ? liquidationFee : vault.fixedLiquidationFeeUsd();
    }

    function getEntryFundingRate(address _collateralToken, address /* _indexToken */, bool /* _isLong */) public override view returns (uint256) {
        return vault.cumulativeFundingRates(_collateralToken);
    }

    function getBrokerFee(uint256 _sizeDelta, uint256 _brokerFeeBasisPoints) public override pure returns (uint256) {
        if (_sizeDelta == 0 || _brokerFeeBasisPoints == 0) { return 0; }

        uint256 afterFeeUsd = _sizeDelta * (BASIS_POINTS_DIVISOR - _brokerFeeBasisPoints) / BASIS_POINTS_DIVISOR;
        uint256 brokerFee = _sizeDelta - afterFeeUsd;

        return brokerFee;
    }

    function getPositionFee(uint256 _sizeDelta) public override view returns (uint256) {
        if (_sizeDelta == 0) { return 0; }
        uint256 afterFeeUsd = _sizeDelta * (BASIS_POINTS_DIVISOR - vault.marginFeeBasisPoints()) / BASIS_POINTS_DIVISOR;
        return _sizeDelta - afterFeeUsd;
    }

    function getPositionFeeForBot(uint256 _sizeDelta) public override view returns (uint256) {
        if (_sizeDelta == 0) { return 0; }
        uint256 afterFeeUsd = _sizeDelta * (BASIS_POINTS_DIVISOR - timelock.marginFeeBasisPoints()) / BASIS_POINTS_DIVISOR;
        return _sizeDelta - afterFeeUsd;
    }

    function getFundingFee(address /* _account */, address _collateralToken, address /* _indexToken */, bool /* _isLong */, uint256 _size, uint256 _entryFundingRate) public override view returns (uint256) {
        if (_size == 0) { return 0; }

        uint256 fundingRate = vault.cumulativeFundingRates(_collateralToken) - _entryFundingRate;
        if (fundingRate == 0) { return 0; }

        return _size * fundingRate / FUNDING_RATE_PRECISION;
    }

    function getBuyUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) public override view returns (uint256) {
        return getFeeBasisPoints(_token, _usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), true);
    }

    function getSellUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) public override view returns (uint256) {
        return getFeeBasisPoints(_token, _usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), false);
    }

    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdgAmount) public override view returns (uint256) {
        bool isStableSwap = vault.stableTokens(_tokenIn) && vault.stableTokens(_tokenOut);
        uint256 baseBps = isStableSwap ? vault.stableSwapFeeBasisPoints() : vault.swapFeeBasisPoints();
        uint256 taxBps = isStableSwap ? vault.stableTaxBasisPoints() : vault.taxBasisPoints();
        uint256 feesBasisPoints0 = getFeeBasisPoints(_tokenIn, _usdgAmount, baseBps, taxBps, true);
        uint256 feesBasisPoints1 = getFeeBasisPoints(_tokenOut, _usdgAmount, baseBps, taxBps, false);
        // use the higher of the two fee basis points
        return feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;
    }

    // cases to consider
    // 1. initialAmount is far from targetAmount, action increases balance slightly => high rebate
    // 2. initialAmount is far from targetAmount, action increases balance largely => high rebate
    // 3. initialAmount is close to targetAmount, action increases balance slightly => low rebate
    // 4. initialAmount is far from targetAmount, action reduces balance slightly => high tax
    // 5. initialAmount is far from targetAmount, action reduces balance largely => high tax
    // 6. initialAmount is close to targetAmount, action reduces balance largely => low tax
    // 7. initialAmount is above targetAmount, nextAmount is below targetAmount and vice versa
    // 8. a large swap should have similar fees as the same trade split into multiple smaller swaps
    function getFeeBasisPoints(address _token, uint256 _usdgDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) public override view returns (uint256) {
        if (!vault.hasDynamicFees()) { return _feeBasisPoints; }

        uint256 initialAmount = vault.usdgAmounts(_token);
        uint256 nextAmount = initialAmount + _usdgDelta;
        if (!_increment) {
            nextAmount = _usdgDelta > initialAmount ? 0 : initialAmount - _usdgDelta;
        }

        uint256 targetAmount = getTargetUsdgAmount(_token);
        if (targetAmount == 0) { return _feeBasisPoints; }

        uint256 initialDiff = initialAmount > targetAmount ? initialAmount - targetAmount : targetAmount - initialAmount;
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount - targetAmount : targetAmount - nextAmount;

        // action improves relative asset balance
        if (nextDiff < initialDiff) {
            uint256 rebateBps = _taxBasisPoints * initialDiff / targetAmount;
            return rebateBps > _feeBasisPoints ? 0 : _feeBasisPoints - rebateBps;
        }

        uint256 averageDiff = (initialDiff + nextDiff) / 2;
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = _taxBasisPoints * averageDiff / targetAmount;
        return _feeBasisPoints + taxBps;
    }

    function getTargetUsdgAmount(address _token) public view returns (uint256) {
        IVault _vault = vault;

        uint256 supply = IERC20Upgradeable(_vault.usdg()).totalSupply();
        if (supply == 0) { return 0; }
        uint256 weight = _vault.tokenWeights(_token);
        return weight * supply / _vault.totalTokenWeights();
    }

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) public view returns (bool, uint256) {
        _validate(_averagePrice > 0, 38);

        IVault _vault = vault;

        uint256 price = _isLong ? _vault.getMinPrice(_indexToken) : _vault.getMaxPrice(_indexToken);
        uint256 priceDelta = _averagePrice > price ? _averagePrice - price : price - _averagePrice;
        uint256 delta = _size * priceDelta / _averagePrice;

        bool hasProfit;

        if (_isLong) {
            hasProfit = price > _averagePrice;
        } else {
            hasProfit = _averagePrice > price;
        }

        // if the minProfitTime has passed then there will be no min profit threshold
        // the min profit threshold helps to prevent front-running issues
        uint256 minBps = block.timestamp > _lastIncreasedTime + _vault.minProfitTime() ? 0 : _vault.minProfitBasisPoints(_indexToken);
        if (hasProfit && delta * BASIS_POINTS_DIVISOR <= _size * minBps) {
            delta = 0;
        }

        return (hasProfit, delta);
    }

    // for longs: nextAveragePrice = (nextPrice * nextSize)/ (nextSize + delta)
    // for shorts: nextAveragePrice = (nextPrice * nextSize) / (nextSize - delta)
    function getNextAveragePrice(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _nextPrice, uint256 _sizeDelta, uint256 _lastIncreasedTime) public view returns (uint256) {
        (bool hasProfit, uint256 delta) = getDelta(_indexToken, _size, _averagePrice, _isLong, _lastIncreasedTime);

        uint256 nextSize = _size + _sizeDelta;

        uint256 divisor;

        if (_isLong) {
            divisor = hasProfit ? nextSize + delta : nextSize - delta;
        } else {
            divisor = hasProfit ? nextSize - delta : nextSize + delta;
        }
        return _nextPrice * nextSize / divisor;
    }

    // for longs: nextAveragePrice = (nextPrice * nextSize)/ (nextSize + delta)
    // for shorts: nextAveragePrice = (nextPrice * nextSize) / (nextSize - delta)
    function getNextGlobalShortAveragePrice(address _indexToken, uint256 _nextPrice, uint256 _sizeDelta) external view returns (uint256) {
        IVault _vault = vault;

        uint256 size = _vault.globalShortSizes(_indexToken);
        uint256 averagePrice = _vault.globalShortAveragePrices(_indexToken);
        uint256 priceDelta = averagePrice > _nextPrice ? averagePrice - _nextPrice : _nextPrice - averagePrice;
        uint256 delta = size * priceDelta / averagePrice;
        bool hasProfit = averagePrice > _nextPrice;

        uint256 nextSize = size + _sizeDelta;
        uint256 divisor = hasProfit ? nextSize - delta : nextSize + delta;

        return _nextPrice * nextSize / divisor;
    }

    function getGlobalShortDelta(address _token) external view returns (bool, uint256) {
        IVault _vault = vault;

        uint256 size = _vault.globalShortSizes(_token);
        if (size == 0) { return (false, 0); }

        uint256 nextPrice = _vault.getMaxPrice(_token);
        uint256 averagePrice = _vault.globalShortAveragePrices(_token);
        uint256 priceDelta = averagePrice > nextPrice ? averagePrice - nextPrice : nextPrice - averagePrice;
        uint256 delta = size * priceDelta / averagePrice;
        bool hasProfit = averagePrice > nextPrice;

        return (hasProfit, delta);
    }

    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (bool, uint256) {
        IVault _vault = vault;

        (
            uint256 size, 
            /* uint256 collateral */,
            uint256 averagePrice,
            /* uint256 entryFundingRate */,
            /* uint256 reserveAmount */, 
            /* uint256 realisedPnl */,
            /* bool hasProfit */,
            uint256 lastIncreasedTime
        ) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);

        return getDelta(_indexToken, size, averagePrice, _isLong, lastIncreasedTime);
    }

    function getNextFundingRate(address _token) external view returns (uint256) {
        IVault _vault = vault;

        if (_vault.lastFundingTimes(_token) + _vault.fundingInterval() > block.timestamp) { return 0; }

        uint256 intervals = (block.timestamp - _vault.lastFundingTimes(_token)) / _vault.fundingInterval();
        uint256 poolAmount = _vault.poolAmounts(_token);
        if (poolAmount == 0) { return 0; }

        uint256 _fundingRateFactor = _vault.stableTokens(_token) ? _vault.stableFundingRateFactor() : _vault.fundingRateFactor();
        return _fundingRateFactor * _vault.reservedAmounts(_token) * intervals / poolAmount;
    }

    function getPositionLeverage(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
        IVault _vault = vault;

        (
            uint256 size, 
            uint256 collateral,
            /* uint256 averagePrice */,
            /* uint256 entryFundingRate */,
            /* uint256 reserveAmount */, 
            /* uint256 realisedPnl */,
            /* bool hasProfit */,
            /* uint256 lastIncreasedTime */
        ) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);

        _validate(collateral > 0, 37);

        return size * BASIS_POINTS_DIVISOR / collateral;
    }

    function getRedemptionAmount(address _token, uint256 _usdgAmount) public view returns (uint256) {
        IVault _vault = vault;

        uint256 price = _vault.getMaxPrice(_token);
        uint256 redemptionAmount = _usdgAmount * PRICE_PRECISION / price;
        return _vault.adjustForDecimals(redemptionAmount, _vault.usdg(), _token);
    }

    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) public view returns (uint256) {
        IVault _vault = vault;

        uint256 decimalsDiv = _tokenDiv == _vault.usdg() ? USDG_DECIMALS : _vault.tokenDecimals(_tokenDiv);
        uint256 decimalsMul = _tokenMul == _vault.usdg() ? USDG_DECIMALS : _vault.tokenDecimals(_tokenMul);
        return _amount * (10 ** decimalsMul) / (10 ** decimalsDiv);
    }

    function validateBufferAmount(address _token) external view {
        IVault _vault = vault;

        if (_vault.poolAmounts(_token) < _vault.bufferAmounts(_token)) {
            revert("Vault: poolAmount < buffer");
        }
    }

    function _validate(bool _condition, uint256 _errorCode) private view {
        IVault _vault = vault;
        
        require(_condition, _vault.errors(_errorCode));
    }
}
