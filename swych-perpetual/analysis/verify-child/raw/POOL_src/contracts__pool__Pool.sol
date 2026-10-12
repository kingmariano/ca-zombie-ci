// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SignedIntOps} from "../lib/SignedInt.sol";
import {MathUtils} from "../lib/MathUtils.sol";
import {PositionUtils} from "../lib/PositionUtils.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {ILPToken} from "../interfaces/ILPToken.sol";
import {IOrderManager} from "../interfaces/IOrderManager.sol";
import {IPool, Side, TokenWeight} from "../interfaces/IPool.sol";
import {
    PoolStorage,
    Position,
    PoolTokenInfo,
    Fee,
    AssetInfo,
    PRECISION,
    LP_INITIAL_PRICE,
    MAX_BASE_SWAP_FEE,
    MAX_TAX_BASIS_POINT,
    MAX_POSITION_FEE,
    MAX_LIQUIDATION_FEE,
    MAX_TRANCHES,
    MAX_INTEREST_RATE,
    MAX_ASSETS,
    MAX_MAINTENANCE_MARGIN
} from "./PoolStorage.sol";
import {PoolErrors} from "./PoolErrors.sol";
import {IPoolHook} from "../interfaces/IPoolHook.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";


uint256 constant USD_VALUE_DECIMAL = 30;

struct IncreasePositionVars {
    uint256 reserveAdded;
    uint256 collateralAmount;
    uint256 collateralValueAdded;
    uint256 feeValue;
    uint256 daoFee;
    uint256 indexPrice;
    uint256 sizeChanged;
    uint256 feeAmount;
    uint256 totalLpFee;
}

/// @notice common variable used across decrease process
struct DecreasePositionVars {
    /// @notice santinized input: collateral value able to be withdraw
    uint256 collateralReduced;
    /// @notice santinized input: position size to decrease, capped to position's size
    uint256 sizeChanged;
    /// @notice current price of index
    uint256 indexPrice;
    /// @notice current price of collateral
    uint256 collateralPrice;
    /// @notice position's remaining collateral value in USD after decrease position
    uint256 remainingCollateral;
    /// @notice reserve reduced due to reduction process
    uint256 reserveReduced;
    /// @notice total value of fee to be collect (include dao fee and LP fee)
    uint256 feeValue;
    /// @notice amount of collateral taken as fee
    uint256 daoFee;
    /// @notice real transfer out amount to user
    uint256 payout;
    /// @notice 'net' PnL (fee not counted)
    int256 pnl;
    int256 poolAmountReduced;
    uint256 totalLpFee;
}

contract Pool is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PoolStorage, IPool {
    using SignedIntOps for int256;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    /* =========== MODIFIERS ========== */
    modifier onlyOrderManager() {
        _requireOrderManager();
        _;
    }

    modifier onlyAsset(address _token) {
        _validateAsset(_token);
        _;
    }

    modifier onlyListedToken(address _token) {
        _requireListedToken(_token);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* ======== INITIALIZERS ========= */
    function initialize(
        uint256 _maxLeverage,
        uint256 _positionFee,
        uint256 _liquidationFee,
        uint256 _interestRate,
        uint256 _accrualInterval,
        uint256 _maintenanceMargin
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _setMaxLeverage(_maxLeverage);
        _setPositionFee(_positionFee, _liquidationFee);
        _setInterestRate(_interestRate, _accrualInterval);
        _setMaintenanceMargin(_maintenanceMargin);
        fee.daoFee = PRECISION;
    }

    // ========= View functions =========

    function version() external pure returns (string memory) {
        return "1.0.1";
    }

    function validateToken(address _indexToken, address _collateralToken, Side _side, bool _isIncrease)
        external
        view
        returns (bool)
    {
        return _validateToken(_indexToken, _collateralToken, _side, _isIncrease);
    }

    function getPoolAsset(address _token) external view returns (AssetInfo memory) {
        return _getPoolAsset(_token);
    }

    function calcSwapOutput(address _tokenIn, address _tokenOut, uint256 _amountIn)
        external
        view
        returns (uint256 amountOut, uint256 feeAmount)
    {
        return _calcSwapOutput(_tokenIn, _tokenOut, _amountIn);
    }

    function feeReserves(
        address _token
    ) external view returns (uint256) {
        return poolTokens[_token].feeReserve;
    }

    // ============= Mutative functions =============

    function addLiquidity(address _token, uint256 _amountIn, uint256 _minLpAmount, address _to)
        external
        nonReentrant
        onlyListedToken(_token)
    {
        require(lpToken != address(0), "LP_NOT_INITIALIZED");
        require(isLiquidityProvider[msg.sender], "NOT_AUTHORIZED");
        _accrueInterest(_token);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amountIn);
        _amountIn = _requireAmount(_getAmountIn(_token));

        (uint256 amountInAfterDaoFee, uint256 lpAmount) = _calcAddLiquidity(_token, _amountIn);
        if (lpAmount < _minLpAmount) {
            revert PoolErrors.SlippageExceeded();
        }

        trancheAssets[lpToken][_token].poolAmount += amountInAfterDaoFee;
        addedLiquidity[_token] += amountInAfterDaoFee;
        refreshVirtualPoolValue();

        ILPToken(lpToken).mint(_to, lpAmount);
        emit LiquidityAdded(lpToken, msg.sender, _token, _amountIn, lpAmount);
    }

    function removeLiquidity(address _tokenOut, uint256 _lpAmount, uint256 _minOut, address _to)
        external
        nonReentrant
        onlyAsset(_tokenOut)
    {
        require(lpToken != address(0), "LP_NOT_INITIALIZED");
        require(isLiquidityProvider[msg.sender], "NOT_AUTHORIZED");
        _distributeSurplus();

        _accrueInterest(_tokenOut);
        _requireAmount(_lpAmount);

        (uint256 outAmount, uint256 tokenOutPrice) = _calcRemoveLiquidity(_tokenOut, _lpAmount);
        if (outAmount < _minOut) {
            revert PoolErrors.SlippageExceeded();
        }

        _decreaseTranchePoolAmount(_tokenOut, outAmount, tokenOutPrice);
        refreshVirtualPoolValue();
        ILPToken(lpToken).burnFrom(msg.sender, _lpAmount);
        _doTransferOut(_tokenOut, _to, outAmount);
        addedLiquidity[_tokenOut] = MathUtils.zeroCapSub(addedLiquidity[_tokenOut], outAmount);
        emit LiquidityRemoved(lpToken, msg.sender, _tokenOut, _lpAmount, outAmount);
    }

    function distributeSurplus() external nonReentrant {
        if (msg.sender != feeDistributor) {
            revert PoolErrors.FeeDistributorOnly();
        }
        _distributeSurplus();
        refreshVirtualPoolValue();
    }

    function getTotalAddedLiquidityUsd() public view returns (uint256 _totalAddedLiquidityUsd) {
        for (uint256 i = 0; i < allAssets.length; i++) {
            address _token = allAssets[i];
            uint256 _tokenPrice = (_getPrice(_token, true) + _getPrice(_token, false)) / 2;
            _totalAddedLiquidityUsd += addedLiquidity[_token] * _tokenPrice;
        }
    }

    function getAllPoolUsd() internal view returns(uint aum) {
        for (uint256 i = 0; i < allAssets.length; i++) {
            address _token = allAssets[i];
            uint256 price = (_getPrice(_token, true) + _getPrice(_token, false)) / 2;
            aum = aum + price * trancheAssets[lpToken][_token].poolAmount;
        } 
    }

    function _distributeSurplus() internal {
        refreshVirtualPoolValue();
        uint256 _totalAddedLiquidityUsd = getTotalAddedLiquidityUsd();
        uint256 totalValue = getAllPoolUsd();
        if (virtualPoolValue > _totalAddedLiquidityUsd * 101/100) {
            uint256 surplusFraction = 800000 * (virtualPoolValue - _totalAddedLiquidityUsd) / totalValue; // Only remove 80% of the surplus.
            for (uint256 i = 0; i < allAssets.length; i++) {
                address _token = allAssets[i];
                AssetInfo memory asset = trancheAssets[lpToken][_token];
                uint256 surplus = (asset.poolAmount * surplusFraction) / 1000000;
                uint256 tokenPrice = (_getPrice(_token, true) + _getPrice(_token, false)) / 2;
                if (surplus > 0) {
                    _decreaseTranchePoolAmount(_token, surplus, tokenPrice);
                    _doTransferOut(_token, feeDistributor, surplus);
                }
            }
        }
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _minOut, address _to, bytes calldata extradata)
        external
        nonReentrant
        onlyListedToken(_tokenIn)
        onlyAsset(_tokenOut)
    {
        require(msg.sender == orderManager || isLiquidityProvider[msg.sender], "NOT_AUTHORIZED");

        if (_tokenIn == _tokenOut) {
            revert PoolErrors.SameTokenSwap(_tokenIn);
        }

        _accrueInterest(_tokenIn);
        _accrueInterest(_tokenOut);
        uint256 amountIn = _requireAmount(_getAmountIn(_tokenIn));
        (uint256 amountOutAfterFee, uint256 swapFee) = _calcSwapOutput(_tokenIn, _tokenOut, amountIn);
        if (amountOutAfterFee < _minOut) {
            revert PoolErrors.SlippageExceeded();
        }
        poolTokens[_tokenIn].feeReserve += swapFee;
        _rebalanceTranches(_tokenIn, amountIn - swapFee, _tokenOut, amountOutAfterFee);
        _doTransferOut(_tokenOut, _to, amountOutAfterFee);
        emit Swap(msg.sender, _tokenIn, _tokenOut, amountIn, amountOutAfterFee, swapFee);
        
        if (address(poolHook) != address(0)) {
            poolHook.postSwap(_to, _tokenIn, _tokenOut, abi.encode(amountIn, amountOutAfterFee, swapFee, extradata));
        }

        refreshVirtualPoolValue();
    }

    function increasePosition(
        address _owner,
        address _indexToken,
        address _collateralToken,
        uint256 _sizeChanged,
        Side _side
    ) external onlyOrderManager nonReentrant {
        _requireValidTokenPair(_indexToken, _collateralToken, _side, true);
        IncreasePositionVars memory vars;
        vars.collateralAmount = _requireAmount(_getAmountIn(_collateralToken));
        uint256 collateralPrice = _getCollateralPrice(_collateralToken, true);
        vars.collateralValueAdded = collateralPrice * vars.collateralAmount;
        uint256 borrowIndex = _accrueInterest(_collateralToken);
        bytes32 key = getPositionKey(_owner, _indexToken, _collateralToken, _side);
        Position memory position = positions[key];
        vars.indexPrice = _getIndexPrice(_indexToken, _side, true);
        vars.sizeChanged = _sizeChanged;
        // update position
        vars.feeValue = _calcPositionFee(position, vars.sizeChanged, borrowIndex);
        vars.feeAmount = vars.feeValue / collateralPrice;
        vars.daoFee = vars.feeAmount;
        vars.reserveAdded = vars.sizeChanged / collateralPrice;
        position.entryPrice = PositionUtils.calcAveragePrice(
            _side, position.size, position.size + vars.sizeChanged, position.entryPrice, vars.indexPrice, 0
        );

        position.collateralValue =
            MathUtils.zeroCapSub(position.collateralValue + vars.collateralValueAdded, vars.feeValue);
        position.size = position.size + vars.sizeChanged;
        position.borrowIndex = borrowIndex;
        position.reserveAmount += vars.reserveAdded;
        position.lastIncreasedTime = block.timestamp;
        _validatePosition(position, _collateralToken, _side, true, vars.indexPrice);

        // update pool assets
        _reservePoolAsset(vars, _indexToken, _collateralToken, _side);
        positions[key] = position;

        emit IncreasePosition(
            key,
            _owner,
            _collateralToken,
            _indexToken,
            vars.collateralAmount,
            vars.sizeChanged,
            _side,
            vars.indexPrice,
            vars.feeValue
        );

        emit UpdatePosition(
            key,
            position.size,
            position.collateralValue,
            position.entryPrice,
            position.borrowIndex,
            position.reserveAmount,
            vars.indexPrice
        );

        if (address(poolHook) != address(0)) {
            poolHook.postIncreasePosition(
                _owner,
                _indexToken,
                _collateralToken,
                _side,
                abi.encode(_sizeChanged, vars.collateralValueAdded, vars.feeValue)
            );
        }
    }

    function decreasePosition(
        address _owner,
        address _indexToken,
        address _collateralToken,
        uint256 _collateralChanged,
        uint256 _sizeChanged,
        Side _side,
        address _receiver
    ) external onlyOrderManager nonReentrant {
        _requireValidTokenPair(_indexToken, _collateralToken, _side, false);
        uint256 borrowIndex = _accrueInterest(_collateralToken);
        bytes32 key = getPositionKey(_owner, _indexToken, _collateralToken, _side);
        Position memory position = positions[key];

        if (position.size == 0) {
            revert PoolErrors.PositionNotExists(_owner, _indexToken, _collateralToken, _side);
        }

        DecreasePositionVars memory vars =
            _calcDecreasePayout(position, _indexToken, _collateralToken, _side, _sizeChanged, _collateralChanged, false);

        // reset to actual reduced value instead of user input
        vars.collateralReduced = position.collateralValue - vars.remainingCollateral;
        _releasePoolAsset(vars, _indexToken, _collateralToken, _side);
        position.size = position.size - vars.sizeChanged;
        position.borrowIndex = borrowIndex;
        position.reserveAmount = position.reserveAmount - vars.reserveReduced;
        position.collateralValue = vars.remainingCollateral;

        _validatePosition(position, _collateralToken, _side, false, vars.indexPrice);

        emit DecreasePosition(
            key,
            _owner,
            _collateralToken,
            _indexToken,
            vars.collateralReduced,
            vars.sizeChanged,
            _side,
            vars.indexPrice,
            vars.pnl.asTuple(),
            vars.feeValue
        );
        if (position.size == 0) {
            emit ClosePosition(
                key,
                position.size,
                position.collateralValue,
                position.entryPrice,
                position.borrowIndex,
                position.reserveAmount
            );
            // delete position when closed
            delete positions[key];
        } else {
            emit UpdatePosition(
                key,
                position.size,
                position.collateralValue,
                position.entryPrice,
                position.borrowIndex,
                position.reserveAmount,
                vars.indexPrice
            );
            positions[key] = position;
        }
        _doTransferOut(_collateralToken, _receiver, vars.payout);
        
        if (address(poolHook) != address(0)) {
            poolHook.postDecreasePosition(
                _owner,
                _indexToken,
                _collateralToken,
                _side,
                abi.encode(vars.sizeChanged, vars.collateralReduced, vars.feeValue)
            );
        }
    }

    function liquidatePosition(address _account, address _indexToken, address _collateralToken, Side _side, address _feeTo) external nonReentrant {
        require(tx.gasprice <= maxLiquidationGasPrice || authorizedLiquidators[msg.sender], "Gas price too high");
        _requireValidTokenPair(_indexToken, _collateralToken, _side, false);
        uint256 borrowIndex = _accrueInterest(_collateralToken);

        bytes32 key = getPositionKey(_account, _indexToken, _collateralToken, _side);
        Position memory position = positions[key];
        uint256 markPrice = _getIndexPrice(_indexToken, _side, false);
        if (!_liquidatePositionAllowed(position, _side, markPrice, borrowIndex)) {
            revert PoolErrors.PositionNotLiquidated(key);
        }

        DecreasePositionVars memory vars = _calcDecreasePayout(
            position, _indexToken, _collateralToken, _side, position.size, position.collateralValue, true
        );

        _releasePoolAsset(vars, _indexToken, _collateralToken, _side);

        emit LiquidatePosition(
            key,
            _account,
            _collateralToken,
            _indexToken,
            _side,
            position.size,
            position.collateralValue - vars.remainingCollateral,
            position.reserveAmount,
            vars.indexPrice,
            vars.pnl.asTuple(),
            vars.feeValue
        );

        delete positions[key];
        _doTransferOut(_collateralToken, _account, vars.payout);
        _doTransferOut(_collateralToken, _feeTo, fee.liquidationFee / vars.collateralPrice);    
    
        if (address(poolHook) != address(0)) {
            poolHook.postLiquidatePosition(
                _account, _indexToken, _collateralToken, _side, abi.encode(position.size, position.collateralValue, vars.feeValue)
            );
        }

        IOrderManager(orderManager).cancelTpslOrders(key);
        refreshVirtualPoolValue();
    }

    function refreshVirtualPoolValue() public {
        virtualPoolValue = (getPoolValue(true) + getPoolValue(false)) / 2;
    }

    // ========= ADMIN FUNCTIONS ========
    function setLpToken(address _lpToken) external onlyOwner {
        require(_lpToken != address(0), "INVALID_LP_TOKEN");
        lpToken = _lpToken;
    }

    function addToken(address _token, bool _isStableCoin) external onlyOwner {
        if (!isAsset[_token]) {
            isAsset[_token] = true;
            isListed[_token] = true;
            allAssets.push(_token);
            isStableCoin[_token] = _isStableCoin;
            if (allAssets.length > MAX_ASSETS) {
                revert PoolErrors.TooManyTokenAdded(allAssets.length, MAX_ASSETS);
            }
            emit TokenWhitelisted(_token);
            return;
        }

        if (isListed[_token]) {
            revert PoolErrors.DuplicateToken(_token);
        }

        // token is added but not listed
        isListed[_token] = true;
        emit TokenWhitelisted(_token);
    }

    function delistToken(address _token) external onlyOwner {
        if (!isListed[_token]) {
            revert PoolErrors.AssetNotListed(_token);
        }
        isListed[_token] = false;
        uint256 weight = targetWeights[_token];
        totalWeight -= weight;
        targetWeights[_token] = 0;
        emit TokenDelisted(_token);
    }

    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        _setMaxLeverage(_maxLeverage);
    }

    function setOracle(address _oracle) external onlyOwner {
        _requireAddress(_oracle);
        address oldOracle = address(oracle);
        oracle = IPriceOracle(_oracle);
        emit OracleChanged(oldOracle, _oracle);
    }

    function setSwapFee(
        uint256 _baseSwapFee,
        uint256 _taxBasisPoint,
        uint256 _stableCoinBaseSwapFee,
        uint256 _stableCoinTaxBasisPoint
    ) external onlyOwner {
        _validateMaxValue(_baseSwapFee, MAX_BASE_SWAP_FEE);
        _validateMaxValue(_stableCoinBaseSwapFee, MAX_BASE_SWAP_FEE);
        _validateMaxValue(_taxBasisPoint, MAX_TAX_BASIS_POINT);
        _validateMaxValue(_stableCoinTaxBasisPoint, MAX_TAX_BASIS_POINT);
        fee.baseSwapFee = _baseSwapFee;
        fee.taxBasisPoint = _taxBasisPoint;
        fee.stableCoinBaseSwapFee = _stableCoinBaseSwapFee;
        fee.stableCoinTaxBasisPoint = _stableCoinTaxBasisPoint;
        emit SwapFeeSet(_baseSwapFee, _taxBasisPoint, _stableCoinBaseSwapFee, _stableCoinTaxBasisPoint);
    }

    function setPositionFee(uint256 _positionFee, uint256 _liquidationFee) external onlyOwner {
        _setPositionFee(_positionFee, _liquidationFee);
    }

    function setInterestRate(uint256 _interestRate, uint256 _accrualInterval) external onlyOwner {
        _setInterestRate(_interestRate, _accrualInterval);
    }

    function setOrderManager(address _orderManager) external onlyOwner {
        _requireAddress(_orderManager);
        orderManager = _orderManager;
    }

    function setLiquidityProvider(address liquidityProvider, bool flag) external onlyOwner {
        _requireAddress(liquidityProvider);
        isLiquidityProvider[liquidityProvider] = flag;
    }

    function withdrawFee(address _token, address _recipient) external onlyAsset(_token) {
        if (msg.sender != feeDistributor) {
            revert PoolErrors.FeeDistributorOnly();
        }
        uint256 amount = poolTokens[_token].feeReserve;
        poolTokens[_token].feeReserve = 0;
        _doTransferOut(_token, _recipient, amount);
        emit DaoFeeWithdrawn(_token, _recipient, amount);
    }

    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        _requireAddress(_feeDistributor);
        feeDistributor = _feeDistributor;
        emit FeeDistributorSet(feeDistributor);
    }

    function setTargetWeight(TokenWeight[] memory tokens) external onlyOwner {
        uint nTokens = tokens.length;
        if (nTokens != allAssets.length) {
            revert PoolErrors.RequireAllTokens();
        }
        uint256 total;
        for (uint256 i = 0; i < nTokens; ++i) {
            TokenWeight memory item = tokens[i];
            assert(isAsset[item.token]);
            // unlisted token always has zero weight
            uint256 weight = isListed[item.token] ? item.weight : 0;
            targetWeights[item.token] = weight;
            total += weight;
        }
        totalWeight = total;
        emit TokenWeightSet(tokens);
    }

    function setPoolHook(address _hook) external onlyOwner {
        poolHook = IPoolHook(_hook);
        emit PoolHookChanged(_hook);
    }

    function setMaxGlobalShortSize(address _token, uint256 _value) external onlyOwner onlyAsset(_token) {
        if (isStableCoin[_token]) {
            revert PoolErrors.NotApplicableForStableCoin();
        }
        maxGlobalShortSizes[_token] = _value;
        emit MaxGlobalShortSizeSet(_token, _value);
    }

    function setMaxGlobalLongSizeRatio(address _token, uint256 _ratio) external onlyOwner onlyAsset(_token) {
        if (isStableCoin[_token]) {
            revert PoolErrors.NotApplicableForStableCoin();
        }
        _validateMaxValue(_ratio, PRECISION);
        maxGlobalLongSizeRatios[_token] = _ratio;
        emit MaxGlobalLongSizeRatioSet(_token, _ratio);
    }

    function setAuthorizedLiquidator(address liquidator, bool isAuthorized) external onlyOwner {
        _requireAddress(liquidator);
        authorizedLiquidators[liquidator] = isAuthorized;
        emit LiquidatorAuthorized(liquidator, isAuthorized);
    }

    function setMaxLiquidationGasPrice(uint256 maxGasPrice) external onlyOwner {
        require(maxGasPrice >= 3 gwei, "GAS_PRICE_TOO_LOW");
        maxLiquidationGasPrice = maxGasPrice;
        emit MaxLiquidationGasPriceSet(maxGasPrice);
    }

    // ======== internal functions =========
    function _setMaxLeverage(uint256 _maxLeverage) internal {
        if (_maxLeverage == 0) {
            revert PoolErrors.InvalidMaxLeverage();
        }
        maxLeverage = _maxLeverage;
        emit MaxLeverageChanged(_maxLeverage);
    }

    function _setMaintenanceMargin(uint256 _ratio) internal {
        _validateMaxValue(_ratio, MAX_MAINTENANCE_MARGIN);
        maintenanceMargin = _ratio;
        emit MaintenanceMarginChanged(_ratio);
    }

    function _setInterestRate(uint256 _interestRate, uint256 _accrualInterval) internal {
        if (_accrualInterval < 1) {
            revert PoolErrors.InvalidInterval();
        }
        _validateMaxValue(_interestRate, MAX_INTEREST_RATE);
        interestRate = _interestRate;
        accrualInterval = _accrualInterval;
        emit InterestRateSet(_interestRate, _accrualInterval);
    }

    function _setPositionFee(uint256 _positionFee, uint256 _liquidationFee) internal {
        _validateMaxValue(_positionFee, MAX_POSITION_FEE);
        _validateMaxValue(_liquidationFee, MAX_LIQUIDATION_FEE);
        fee.positionFee = _positionFee;
        fee.liquidationFee = _liquidationFee;
        emit PositionFeeSet(_positionFee, _liquidationFee);
    }

    function _validateToken(address _indexToken, address _collateralToken, Side _side, bool _isIncrease)
        internal
        view
        returns (bool)
    {
        if (!isAsset[_indexToken] || !isAsset[_collateralToken]) {
            return false;
        }

        if (_isIncrease && (!isListed[_indexToken] || !isListed[_collateralToken])) {
            return false;
        }

        return _side == Side.LONG ? _indexToken == _collateralToken && !isStableCoin[_indexToken] : isStableCoin[_collateralToken];
    }

    function _calcAddLiquidity(address _token, uint256 _amountIn)
        internal
        view
        returns (uint256 amountInAfterFee, uint256 lpAmount)
    {
        uint256 tokenPrice = (_getPrice(_token, true) + _getPrice(_token, false)) / 2;
        amountInAfterFee = _amountIn;

        uint256 trancheValue = (_getPoolValue(true) + _getPoolValue(false)) / 2;
        uint256 lpSupply = ILPToken(lpToken).totalSupply();
        if (lpSupply == 0 || trancheValue == 0) {
            lpAmount = MathUtils.frac(_amountIn, tokenPrice, LP_INITIAL_PRICE);
        } else {
            lpAmount = (_amountIn * tokenPrice * lpSupply) / trancheValue;
        }
    }

    function _calcRemoveLiquidity(address _tokenOut, uint256 _lpAmount)
        internal
        view
        returns (uint256 outAmount, uint256 tokenPrice)
    {
        tokenPrice = (_getPrice(_tokenOut, true) + _getPrice(_tokenOut, false)) / 2;
        uint256 poolValue = (_getPoolValue(true) + _getPoolValue(false)) / 2;
        uint256 totalSupply = ILPToken(lpToken).totalSupply();
        outAmount = (_lpAmount * poolValue) / totalSupply / tokenPrice;
    }

    function _calcSwapOutput(address _tokenIn, address _tokenOut, uint256 _amountIn)
        internal
        view
        returns (uint256 amountOutAfterFee, uint256 feeAmount)
    {
        uint256 priceIn = _getPrice(_tokenIn, false);
        uint256 priceOut = _getPrice(_tokenOut, true);
        uint256 valueChange = _amountIn * priceIn;
        uint256 feeIn = _calcSwapFee(_tokenIn, priceIn, valueChange, true);
        uint256 feeOut = _calcSwapFee(_tokenOut, priceOut, valueChange, false);
        uint256 _fee = feeIn > feeOut ? feeIn : feeOut;

        amountOutAfterFee = valueChange * (PRECISION - _fee) / priceOut / PRECISION;
        feeAmount = (valueChange * _fee) / priceIn / PRECISION;
    }

    function getPositionKey(address _owner, address _indexToken, address _collateralToken, Side _side)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_owner, _indexToken, _collateralToken, _side));
    }

    function _validatePosition(
        Position memory _position,
        address _collateralToken,
        Side _side,
        bool _isIncrease,
        uint256 _indexPrice
    ) internal view {
        if ((_isIncrease && _position.size == 0)) {
            revert PoolErrors.InvalidPositionSize();
        }

        uint256 borrowIndex = poolTokens[_collateralToken].borrowIndex;

        if (_position.size < _position.collateralValue || _position.size > _position.collateralValue * maxLeverage) {
            revert PoolErrors.InvalidLeverage(_position.size, _position.collateralValue, maxLeverage);
        }
        if (_liquidatePositionAllowed(_position, _side, _indexPrice, borrowIndex)) {
            revert PoolErrors.UpdateCauseLiquidation();
        }
    }

    function _requireValidTokenPair(address _indexToken, address _collateralToken, Side _side, bool _isIncrease)
        internal
        view
    {
        if (!_validateToken(_indexToken, _collateralToken, _side, _isIncrease)) {
            revert PoolErrors.InvalidTokenPair(_indexToken, _collateralToken);
        }
    }

    function _validateAsset(address _token) internal view {
        if (!isAsset[_token]) {
            revert PoolErrors.UnknownToken(_token);
        }
    }

    function _requireAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert PoolErrors.ZeroAddress();
        }
    }

    function _requireAmount(uint256 _amount) internal pure returns (uint256) {
        if (_amount == 0) {
            revert PoolErrors.ZeroAmount();
        }

        return _amount;
    }

    function _requireListedToken(address _token) internal view {
        if (!isListed[_token]) {
            revert PoolErrors.AssetNotListed(_token);
        }
    }

    function _requireOrderManager() internal view {
        if (msg.sender != orderManager) {
            revert PoolErrors.OrderManagerOnly();
        }
    }

    function _validateMaxValue(uint256 _input, uint256 _max) internal pure {
        if (_input > _max) {
            revert PoolErrors.ValueTooHigh(_max);
        }
    }

    function _getAmountIn(address _token) internal returns (uint256 amount) {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        amount = balance - poolTokens[_token].poolBalance;
        poolTokens[_token].poolBalance = balance;
    }

    function _doTransferOut(address _token, address _to, uint256 _amount) internal {
        if (_amount != 0) {
            IERC20 token = IERC20(_token);
            token.safeTransfer(_to, _amount);
            poolTokens[_token].poolBalance = token.balanceOf(address(this));
        }
    }

    function _accrueInterest(address _token) internal returns (uint256) {
        PoolTokenInfo memory tokenInfo = poolTokens[_token];
        AssetInfo memory asset = _getPoolAsset(_token);
        uint256 _now = block.timestamp;
        if (tokenInfo.lastAccrualTimestamp == 0 || asset.poolAmount == 0) {
            tokenInfo.lastAccrualTimestamp = (_now / accrualInterval) * accrualInterval;
        } else {
            uint256 nInterval = (_now - tokenInfo.lastAccrualTimestamp) / accrualInterval;
            if (nInterval == 0) {
                return tokenInfo.borrowIndex;
            }

            tokenInfo.borrowIndex += (nInterval * interestRate * asset.reservedAmount) / asset.poolAmount;
            tokenInfo.lastAccrualTimestamp += nInterval * accrualInterval;
        }

        poolTokens[_token] = tokenInfo;
        emit InterestAccrued(_token, tokenInfo.borrowIndex);
        return tokenInfo.borrowIndex;
    }

    /// @notice calculate adjusted fee rate
    /// fee is increased or decreased based on action's effect to pool amount
    /// each token has their target weight set by gov
    /// if action make the weight of token far from its target, fee will be increase, vice versa
    function _calcSwapFee(address _token, uint256 _tokenPrice, uint256 _valueChange, bool _isSwapIn)
        internal
        view
        returns (uint256)
    {
        (uint256 baseSwapFee, uint256 taxBasisPoint) = isStableCoin[_token]
            ? (fee.stableCoinBaseSwapFee, fee.stableCoinTaxBasisPoint)
            : (fee.baseSwapFee, fee.taxBasisPoint);
        return _calcFeeRate(_token, _tokenPrice, _valueChange, baseSwapFee, taxBasisPoint, _isSwapIn);
    }

    function _calcFeeRate(
        address _token,
        uint256 _tokenPrice,
        uint256 _valueChange,
        uint256 _baseFee,
        uint256 _taxBasisPoint,
        bool _isIncrease
    ) internal view returns (uint256) {
        uint256 _targetValue = totalWeight == 0 ? 0 : (targetWeights[_token] * virtualPoolValue) / totalWeight;
        if (_targetValue == 0) {
            return _baseFee;
        }
        uint256 _currentValue = _tokenPrice * _getPoolAsset(_token).poolAmount;
        uint256 _nextValue = _isIncrease ? _currentValue + _valueChange : _currentValue - _valueChange;
        uint256 initDiff = MathUtils.diff(_currentValue, _targetValue);
        uint256 nextDiff = MathUtils.diff(_nextValue, _targetValue);
        if (nextDiff < initDiff) {
            uint256 feeAdjust = (_taxBasisPoint * initDiff) / _targetValue;
            return MathUtils.zeroCapSub(_baseFee, feeAdjust);
        } else {
            uint256 avgDiff = (initDiff + nextDiff) / 2;
            uint256 feeAdjust = avgDiff > _targetValue ? _taxBasisPoint : (_taxBasisPoint * avgDiff) / _targetValue;
            return _baseFee + feeAdjust;
        }
    }

    function getPoolValue(bool _max) public view returns (uint256 sum) {
        sum = _getPoolValue(_max);
    }

    function _getAllPrices(bool _max) internal view returns (uint256[] memory) {
        return oracle.getMultiplePrices(allAssets, _max);
    }

    function _getPoolValue(bool _max) internal view returns (uint256 sum) {
        return _getPoolValue(_getAllPrices(_max));
    }

    function _getPoolValue(uint256[] memory prices) internal view returns (uint256 sum) {
        int256 aum;

        for (uint256 i = 0; i < allAssets.length;) {
            address token = allAssets[i];
            assert(isAsset[token]); // double check
            AssetInfo memory asset = trancheAssets[lpToken][token];
            uint256 price = prices[i];
            if (isStableCoin[token]) {
                aum = aum + (price * asset.poolAmount).toInt256();
            } else {
                uint256 averageShortPrice = averageShortPrices[lpToken][token];
                int256 shortPnl = PositionUtils.calcPnl(Side.SHORT, asset.totalShortSize, averageShortPrice, price);
                aum = aum + ((asset.poolAmount - asset.reservedAmount) * price + asset.guaranteedValue).toInt256() - shortPnl;            
            }
            unchecked {
                ++i;
            }
        }

        // aum MUST not be negative. If it is, please debug
        return aum.toUint256();
    }

    function _decreaseTranchePoolAmount(address _token, uint256 _amount, uint256 _assetPrice) internal {
        AssetInfo memory asset = trancheAssets[lpToken][_token];
        asset.poolAmount -= _amount;
        if (asset.poolAmount < asset.reservedAmount) {
            revert PoolErrors.InsufficientPoolAmount(_token);
        }
        if (!isStableCoin[_token]) {
            _validateGlobalShortSize(_token, asset, _assetPrice);
        }
        trancheAssets[lpToken][_token] = asset;
    }

    /**
     * @notice ensure max short pnl (which equal to short size) cannot higher than pool value
     */
    function _validateGlobalShortSize(address _token, AssetInfo memory _asset, uint256 _assetPrice) internal pure {
        if ((_asset.poolAmount - _asset.reservedAmount) * _assetPrice + _asset.guaranteedValue < _asset.totalShortSize)
        {
            revert PoolErrors.InsufficientPoolAmount(_token);
        }
    }

    /// @notice return pseudo pool asset by sum all tranches asset
    function _getPoolAsset(address _token) internal view returns (AssetInfo memory asset) {
        asset.poolAmount = trancheAssets[lpToken][_token].poolAmount;
        asset.reservedAmount = trancheAssets[lpToken][_token].reservedAmount;
        asset.totalShortSize = trancheAssets[lpToken][_token].totalShortSize;
        asset.guaranteedValue = trancheAssets[lpToken][_token].guaranteedValue;
    }

    /// @notice reserve asset when open position
    function _reservePoolAsset(
        IncreasePositionVars memory _vars,
        address _indexToken,
        address _collateralToken,
        Side _side
    ) internal {
        AssetInfo memory collateral = _getPoolAsset(_collateralToken);

        uint256 maxReserve = collateral.poolAmount;
        if (_side == Side.LONG) {
            uint256 maxReserveRatio = maxGlobalLongSizeRatios[_indexToken];
            if (maxReserveRatio != 0) {
                maxReserve = MathUtils.frac(maxReserve, maxReserveRatio, PRECISION);
            }
        } else {
            uint256 maxGlobalShortSize = maxGlobalShortSizes[_indexToken];
            uint256 globalShortSize = trancheAssets[lpToken][_indexToken].totalShortSize + _vars.sizeChanged;
            if (maxGlobalShortSize != 0 && maxGlobalShortSize < globalShortSize) {
                revert PoolErrors.MaxGlobalShortSizeExceeded(_indexToken, globalShortSize);
            }
        }

        if (collateral.reservedAmount + _vars.reserveAdded > maxReserve) {
            revert PoolErrors.InsufficientPoolAmount(_collateralToken);
        }

        poolTokens[_collateralToken].feeReserve += _vars.daoFee;
        _reserveTrancheAsset(_vars, _indexToken, _collateralToken, _side);
    }

    /// @notice release asset and take or distribute realized PnL when close position
    function _releasePoolAsset(
        DecreasePositionVars memory _vars,
        address _indexToken,
        address _collateralToken,
        Side _side
    ) internal {
        AssetInfo memory collateral = _getPoolAsset(_collateralToken);

        if (collateral.reservedAmount < _vars.reserveReduced) {
            revert PoolErrors.ReserveReduceTooMuch(_collateralToken);
        }

        poolTokens[_collateralToken].feeReserve += _vars.daoFee;
        _releaseTranchesAsset(_vars, _indexToken, _collateralToken, _side);
    }

    function _reserveTrancheAsset(
        IncreasePositionVars memory _vars,
        address _indexToken,
        address _collateralToken,
        Side _side
    ) internal {
        AssetInfo memory collateral = trancheAssets[lpToken][_collateralToken];
        uint256 reserveAmount = _vars.reserveAdded;
        collateral.reservedAmount += reserveAmount;

        if (_side == Side.LONG) {
            collateral.poolAmount = MathUtils.zeroCapSub(
                collateral.poolAmount + _vars.collateralAmount,
                _vars.feeAmount
            );
            // ajust guaranteed
            // guaranteed value = total(size - (collateral - fee))
            // delta_guaranteed value = sizechange + fee - collateral
            collateral.guaranteedValue = MathUtils.zeroCapSub(
                collateral.guaranteedValue + _vars.sizeChanged + _vars.feeValue,
                _vars.collateralValueAdded
            );
        } else {
            AssetInfo memory indexAsset = trancheAssets[lpToken][_indexToken];
            uint256 sizeChanged = _vars.sizeChanged;
            uint256 indexPrice = _vars.indexPrice;
            _updateGlobalShortPrice(_indexToken, sizeChanged, true, indexPrice, 0);
            indexAsset.totalShortSize += sizeChanged;
            _validateGlobalShortSize(_indexToken, indexAsset, indexPrice);
            trancheAssets[lpToken][_indexToken] = indexAsset;
        }

        trancheAssets[lpToken][_collateralToken] = collateral;
    }

    function _releaseTranchesAsset(
        DecreasePositionVars memory _vars,
        address _indexToken,
        address _collateralToken,
        Side _side
    ) internal {
        AssetInfo memory collateral = trancheAssets[lpToken][_collateralToken];
        collateral.reservedAmount -= _vars.reserveReduced;
        collateral.poolAmount = (
            (collateral.poolAmount).toInt256() - _vars.poolAmountReduced
        ).toUint256();

        if (_side == Side.LONG) {
            collateral.guaranteedValue = MathUtils.zeroCapSub(
                collateral.guaranteedValue + _vars.collateralReduced, _vars.sizeChanged
            );
        } else {
            AssetInfo memory indexAsset = trancheAssets[lpToken][_indexToken];
            uint256 indexPrice = _vars.indexPrice;
            _updateGlobalShortPrice(_indexToken, _vars.sizeChanged, false, indexPrice, _vars.pnl);
            indexAsset.totalShortSize = MathUtils.zeroCapSub(indexAsset.totalShortSize, _vars.sizeChanged);
            trancheAssets[lpToken][_indexToken] = indexAsset;
        }
        // TODO: probably realized pnl can be taken here
        trancheAssets[lpToken][_collateralToken] = collateral;
        emit PnLDistributed(_collateralToken, lpToken, _vars.pnl.abs(), _vars.pnl >= 0);
    }

    /// @notice rebalance fund between tranches after swap token
    function _rebalanceTranches(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _amountOut
    ) internal {
        trancheAssets[lpToken][_tokenOut].poolAmount -= _amountOut;
        trancheAssets[lpToken][_tokenIn].poolAmount += _amountIn;
    }

    function _liquidatePositionAllowed(Position memory _position, Side _side, uint256 _indexPrice, uint256 _borrowIndex)
        internal
        view
        returns (bool allowed)
    {
        if (_position.size == 0) {
            return false;
        }
        // calculate fee needed when close position
        uint256 feeValue = _calcPositionFee(_position, _position.size, _borrowIndex);
        int256 pnl = PositionUtils.calcPnl(_side, _position.size, _position.entryPrice, _indexPrice);
        int256 collateral = pnl + _position.collateralValue.toInt256();

        // liquidation occur when collateral cannot cover margin fee or lower than maintenance margin
        return collateral < 0 || uint256(collateral) * PRECISION < _position.size * maintenanceMargin
            || uint256(collateral) < (feeValue + fee.liquidationFee);
    }

    function _calcDecreasePayout(
        Position memory _position,
        address _indexToken,
        address _collateralToken,
        Side _side,
        uint256 _sizeChanged,
        uint256 _collateralChanged,
        bool isLiquidate
    ) internal view returns (DecreasePositionVars memory vars) {
        // clean user input
        vars.sizeChanged = MathUtils.min(_position.size, _sizeChanged);
        vars.collateralReduced = _position.collateralValue < _collateralChanged || _position.size == vars.sizeChanged
            ? _position.collateralValue
            : _collateralChanged;

        vars.indexPrice = _getIndexPrice(_indexToken, _side, false);
        vars.collateralPrice = _getCollateralPrice(_collateralToken, false);

        // vars is santinized, only trust these value from now on
        vars.reserveReduced = (_position.reserveAmount * vars.sizeChanged) / _position.size;
        vars.pnl = PositionUtils.calcPnl(_side, vars.sizeChanged, _position.entryPrice, vars.indexPrice);
        vars.feeValue = _calcPositionFee(_position, vars.sizeChanged, poolTokens[_collateralToken].borrowIndex);

        
        // first try to deduct fee and lost (if any) from withdrawn collateral
        int256 payoutValue = vars.pnl + vars.collateralReduced.toInt256() - vars.feeValue.toInt256();
        if (isLiquidate) {
            payoutValue = payoutValue - fee.liquidationFee.toInt256();
        }
        int256 remainingCollateral = (_position.collateralValue - vars.collateralReduced).toInt256(); // subtraction never overflow, checked above
        // if the deduction is too much, try to deduct from remaining collateral
        if (payoutValue < 0) {
            remainingCollateral = remainingCollateral + payoutValue;
            payoutValue = 0;
        }
        int256 collateralPrice = vars.collateralPrice.toInt256();
        vars.payout = uint256(payoutValue / collateralPrice);

        int256 poolValueReduced = vars.pnl;
        if (remainingCollateral < 0) {
            if (!isLiquidate) {
                revert PoolErrors.UpdateCauseLiquidation();
            }
            // if liquidate too slow, pool must take the lost
            poolValueReduced = poolValueReduced - remainingCollateral;
            vars.remainingCollateral = 0;
        } else {
            vars.remainingCollateral = uint256(remainingCollateral);
        }

        if (_side == Side.LONG) {
            poolValueReduced = poolValueReduced + vars.collateralReduced.toInt256();
        } else if (poolValueReduced < 0) {
            // in case of SHORT, trader can lost unlimited value but pool can only increase at most collateralValue - liquidationFee
            poolValueReduced = poolValueReduced.cap(
                MathUtils.zeroCapSub(_position.collateralValue, vars.feeValue + fee.liquidationFee)
            );
        }
        vars.poolAmountReduced = poolValueReduced / collateralPrice;
        vars.daoFee = vars.feeValue / vars.collateralPrice;
    }
    
    function _calcPositionFee(Position memory _position, uint256 _sizeChanged, uint256 _borrowIndex)
        internal
        view
        returns (uint256 feeValue)
    {  
        uint256 borrowFee = ((_borrowIndex - _position.borrowIndex) * _position.size) / PRECISION;
        uint256 positionFee = (_sizeChanged * fee.positionFee) / PRECISION;
        feeValue = borrowFee + positionFee;
    }

    function _getIndexPrice(address _token, Side _side, bool _isIncrease) internal view returns (uint256) {
        return _getPrice(_token, _isIncrease == (_side == Side.LONG));
    }

    function _getCollateralPrice(address _token, bool _isIncrease) internal view returns (uint256) {        
        return (isStableCoin[_token])
            // force collateral price = 1 incase of using stablecoin as collateral
            ? 10 ** (USD_VALUE_DECIMAL - IERC20Metadata(_token).decimals())
            : _getPrice(_token, !_isIncrease);
    }

    function _getPrice(address _token, bool _max) internal view returns (uint256) {
        return oracle.getPrice(_token, _max);
    }

    function _updateGlobalShortPrice(
        address _indexToken,
        uint256 _sizeChanged,
        bool _isIncrease,
        uint256 _indexPrice,
        int256 _realizedPnl
    ) internal {
        uint256 lastSize = trancheAssets[lpToken][_indexToken].totalShortSize;
        uint256 nextSize = _isIncrease ? lastSize + _sizeChanged : MathUtils.zeroCapSub(lastSize, _sizeChanged);
        uint256 entryPrice = averageShortPrices[lpToken][_indexToken];
        uint256 shortPrice =
            PositionUtils.calcAveragePrice(Side.SHORT, lastSize, nextSize, entryPrice, _indexPrice, _realizedPnl);
        averageShortPrices[lpToken][_indexToken] = shortPrice;
    }

}