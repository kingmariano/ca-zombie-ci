// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../tokens/interfaces/IMintable.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultUtils.sol";
import "./interfaces/IVaultPriceFeed.sol";
import "../referrals/interfaces/IReferralManager.sol";

contract Vault is ReentrancyGuardUpgradeable, IVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Position {
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 entryFundingRate;
        uint256 reserveAmount;
        int256 realisedPnl;
        uint256 lastIncreasedTime;
        address brokerAddress; 
        uint256 brokerFeeBasisPoints;
    }

    EnumerableSet.AddressSet private _whitelistedTokens;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant FUNDING_RATE_PRECISION = 1000000;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant MIN_LEVERAGE = 10000; // 1x
    uint256 public constant USDG_DECIMALS = 18;
    uint256 public constant MAX_FEE_BASIS_POINTS = 500; // 5%
    uint256 public constant MAX_LIQUIDATION_FEE_USD = 100 * PRICE_PRECISION; // 100 USD
    uint256 public constant MIN_FUNDING_RATE_INTERVAL = 1 hours;
    uint256 public constant MAX_FUNDING_RATE_FACTOR = 10000; // 1%

    bool public override isInitialized;
    bool public override isSwapEnabled;
    bool public override isLeverageEnabled;

    IVaultUtils public vaultUtils;

    address public errorController;

    address public override router;
    address public override priceFeed;

    address public override usdg;
    address public override gov;

    uint256 public override maxLeverage; // 50x

    uint256 public override fixedLiquidationFeeUsd;
    uint256 public override dynLiquidationFeeBasisPoints; // 5%
    uint256 public override taxBasisPoints; // 0.5%
    uint256 public override stableTaxBasisPoints; // 0.2%
    uint256 public override mintBurnFeeBasisPoints; // 0.3%
    uint256 public override swapFeeBasisPoints; // 0.3%
    uint256 public override stableSwapFeeBasisPoints; // 0.04%
    uint256 public override marginFeeBasisPoints; // 0.1%

    uint256 public override minProfitTime;
    bool public override hasDynamicFees;

    uint256 public override fundingInterval;
    uint256 public override fundingRateFactor;
    uint256 public override stableFundingRateFactor;
    uint256 public override totalTokenWeights;

    bool public override inManagerMode;
    bool public override inPrivateLiquidationMode;

    uint256 public override maxGasPrice;

    mapping (address => mapping (address => bool)) public override approvedRouters;
    mapping (address => bool) public override isLiquidator;
    mapping (address => bool) public override isManager;

    mapping (address => uint256) public override tokenDecimals;
    mapping (address => uint256) public override minProfitBasisPoints;
    mapping (address => bool) public override stableTokens;
    mapping (address => bool) public override shortableTokens;

    // tokenBalances is used only to determine _transferIn values
    mapping (address => uint256) public override tokenBalances;

    // tokenWeights allows customisation of index composition
    mapping (address => uint256) public override tokenWeights;

    // usdgAmounts tracks the amount of USDG debt for each whitelisted token
    mapping (address => uint256) public override usdgAmounts;

    // maxUsdgAmounts allows setting a max amount of USDG debt for a token
    mapping (address => uint256) public override maxUsdgAmounts;

    // poolAmounts tracks the number of received tokens that can be used for leverage
    // this is tracked separately from tokenBalances to exclude funds that are deposited as margin collateral
    mapping (address => uint256) public override poolAmounts;

    // reservedAmounts tracks the number of tokens reserved for open leverage positions
    mapping (address => uint256) public override reservedAmounts;

    // bufferAmounts allows specification of an amount to exclude from swaps
    // this can be used to ensure a certain amount of liquidity is available for leverage positions
    mapping (address => uint256) public override bufferAmounts;

    // guaranteedUsd tracks the amount of USD that is "guaranteed" by opened leverage positions
    // this value is used to calculate the redemption values for selling of USDG
    // this is an estimated amount, it is possible for the actual guaranteed value to be lower
    // in the case of sudden price decreases, the guaranteed value should be corrected
    // after liquidations are carried out
    mapping (address => uint256) public override guaranteedUsd;

    // cumulativeFundingRates tracks the funding rates based on utilization
    mapping (address => uint256) public override cumulativeFundingRates;
    // lastFundingTimes tracks the last time funding was updated for a token
    mapping (address => uint256) public override lastFundingTimes;

    // positions tracks all open positions
    mapping (bytes32 => Position) public override positions;

    // feeReserves tracks the amount of fees per token
    mapping (address => uint256) public override feeReserves;

    mapping (address => uint256) public override globalShortSizes;
    mapping (address => uint256) public override globalShortAveragePrices;
    mapping (address => uint256) public override maxGlobalShortSizes;

    mapping (uint256 => string) public errors;

    // The admin who can withdraw fees
    address public feeAdmin;
    IReferralManager public referralManager;

    event BuyUSDG(address account, address token, uint256 tokenAmount, uint256 usdgAmount, uint256 feeBasisPoints);
    event SellUSDG(address account, address token, uint256 usdgAmount, uint256 tokenAmount, uint256 feeBasisPoints);
    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 amountOutAfterFees, uint256 feeBasisPoints);

    event IncreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event DecreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event LiquidatePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 markPrice
    );
    event PartialLiquidation(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 leftTokenAmount,
        uint256 markPrice
    );
    event UpdatePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl,
        uint256 markPrice
    );
    event ClosePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl
    );

    event UpdateFundingRate(address token, uint256 fundingRate);
    event UpdatePnl(bytes32 key, bool hasProfit, uint256 delta);

    event CollectLiquidationFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectSwapFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectMarginFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectBrokerFees(address token, uint256 feeUsd, uint256 feeTokens, uint256 sizeDelta, address brokerAddress, uint256 brokerFeeBasisPoints);

    event DirectPoolDeposit(address token, uint256 amount);
    event IncreasePoolAmount(address token, uint256 amount);
    event DecreasePoolAmount(address token, uint256 amount);
    event IncreaseUsdgAmount(address token, uint256 amount);
    event DecreaseUsdgAmount(address token, uint256 amount);
    event IncreaseReservedAmount(address token, uint256 amount);
    event DecreaseReservedAmount(address token, uint256 amount);
    event IncreaseGuaranteedUsd(address token, uint256 amount);
    event DecreaseGuaranteedUsd(address token, uint256 amount);

    event UpdateGov(address gov);

    event IncreasePositionByBroker(bytes32 key, address brokerAddress, uint256 brokerFeeBasisPoints);
    event DecreasePositionByBroker(bytes32 key, address brokerAddress, uint256 brokerFeeBasisPoints);

    // once the parameters are verified to be working correctly,
    // gov should be set to a timelock contract or a governance contract
    function initialize() public initializer {
        __ReentrancyGuard_init();

        gov = msg.sender;
        isSwapEnabled = true;
        isLeverageEnabled = true;
        maxLeverage = 50 * 10000; // 50x
        dynLiquidationFeeBasisPoints = 500; // 5%
        taxBasisPoints = 50; // 0.5%
        stableTaxBasisPoints = 20; // 0.2%
        mintBurnFeeBasisPoints = 30; // 0.3%
        swapFeeBasisPoints = 30; // 0.3%
        stableSwapFeeBasisPoints = 4; // 0.04%
        marginFeeBasisPoints = 10; // 0.1%
        fundingInterval = 8 hours;
    }

    function setParams(
        address _router,
        address _usdg,
        address _priceFeed,
        uint256 _fixedLiquidationFeeUsd,
        uint256 _fundingRateFactor,
        uint256 _stableFundingRateFactor
    ) public {
        _onlyGov();
        _validate(!isInitialized, 1);
        isInitialized = true;
        router = _router;
        usdg = _usdg;
        priceFeed = _priceFeed;
        fixedLiquidationFeeUsd = _fixedLiquidationFeeUsd;
        fundingRateFactor = _fundingRateFactor;
        stableFundingRateFactor = _stableFundingRateFactor;
    }

    function setReferralManager(IReferralManager _referralManager) external {
        _onlyGov();
        if (address(referralManager) != address(0)) {
            isManager[address(referralManager)] = false;
        }
        referralManager = _referralManager;
        isManager[address(_referralManager)] = true;
    }

    function setVaultUtils(IVaultUtils _vaultUtils) external override {
        _onlyGov();
        vaultUtils = _vaultUtils;
    }

    function setErrorController(address _errorController) external {
        _onlyGov();
        errorController = _errorController;
    }

    function setError(uint256 _errorCode, string calldata _error) external override {
        _validate(msg.sender == errorController, 60);
        errors[_errorCode] = _error;
    }

    function whitelistedTokenCount() external override view returns (uint256) {
        return _whitelistedTokens.length();
    }

    function whitelistedTokens(uint256 _index) external override view returns (address) {
        return _whitelistedTokens.at(_index);
    }

    function isWhitelistedToken(address _token) external override view returns (bool) {
        return _whitelistedTokens.contains(_token);
    }

    function setInManagerMode(bool _inManagerMode) external override {
        _onlyGov();
        inManagerMode = _inManagerMode;
    }

    function setManager(address _manager, bool _isManager) external override {
        _onlyGov();

        isManager[_manager] = _isManager;
    }

    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external override {
        _onlyGov();
        inPrivateLiquidationMode = _inPrivateLiquidationMode;
    }

    function setLiquidator(address _liquidator, bool _isActive) external override {
        _onlyGov();
        isLiquidator[_liquidator] = _isActive;
    }

    function setIsSwapEnabled(bool _isSwapEnabled) external override {
        _onlyGov();
        isSwapEnabled = _isSwapEnabled;
    }

    function setIsLeverageEnabled(bool _isLeverageEnabled) external override {
        _onlyGov();
        isLeverageEnabled = _isLeverageEnabled;
    }

    function setMaxGasPrice(uint256 _maxGasPrice) external override {
        _onlyGov();
        maxGasPrice = _maxGasPrice;
    }

    function setGov(address _gov) external {
        _onlyGov();
        _validate(_gov != address(0), 0);
        gov = _gov;
        emit UpdateGov(gov);
    }

    function setFeeAdmin(address _feeAdmin) external {
        _onlyGov();
        feeAdmin = _feeAdmin;
    }

    function setPriceFeed(address _priceFeed) external override {
        _onlyGov();
        priceFeed = _priceFeed;
    }

    function setMaxLeverage(uint256 _maxLeverage) external override {
        _onlyGov();
        _validate(_maxLeverage > MIN_LEVERAGE, 2);
        maxLeverage = _maxLeverage;
    }

    function setBufferAmount(address _token, uint256 _amount) external override {
        _onlyGov();
        bufferAmounts[_token] = _amount;
    }

    function setMaxGlobalShortSize(address _token, uint256 _amount) external override {
        _onlyGov();
        maxGlobalShortSizes[_token] = _amount;
    }

    function setFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _dynLiquidationFeeBasisPoints,
        uint256 _fixedLiquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external override {
        _onlyGov();
        _validate(_taxBasisPoints <= MAX_FEE_BASIS_POINTS, 3);
        _validate(_stableTaxBasisPoints <= MAX_FEE_BASIS_POINTS, 4);
        _validate(_mintBurnFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 5);
        _validate(_swapFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 6);
        _validate(_stableSwapFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 7);
        _validate(_marginFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 8);
        _validate(_fixedLiquidationFeeUsd <= MAX_LIQUIDATION_FEE_USD, 9);
        taxBasisPoints = _taxBasisPoints;
        stableTaxBasisPoints = _stableTaxBasisPoints;
        mintBurnFeeBasisPoints = _mintBurnFeeBasisPoints;
        swapFeeBasisPoints = _swapFeeBasisPoints;
        stableSwapFeeBasisPoints = _stableSwapFeeBasisPoints;
        marginFeeBasisPoints = _marginFeeBasisPoints;
        dynLiquidationFeeBasisPoints = _dynLiquidationFeeBasisPoints;
        fixedLiquidationFeeUsd = _fixedLiquidationFeeUsd;
        minProfitTime = _minProfitTime;
        hasDynamicFees = _hasDynamicFees;
    }

    function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external override {
        _onlyGov();
        _validate(_fundingInterval >= MIN_FUNDING_RATE_INTERVAL, 10);
        _validate(_fundingRateFactor <= MAX_FUNDING_RATE_FACTOR, 11);
        _validate(_stableFundingRateFactor <= MAX_FUNDING_RATE_FACTOR, 12);
        fundingInterval = _fundingInterval;
        fundingRateFactor = _fundingRateFactor;
        stableFundingRateFactor = _stableFundingRateFactor;
    }

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdgAmount,
        bool _isStable,
        bool _isShortable
    ) external override {
        _onlyGov();
        _whitelistedTokens.add(_token);

        uint256 _totalTokenWeights = totalTokenWeights;
        _totalTokenWeights = _totalTokenWeights - tokenWeights[_token];

        tokenDecimals[_token] = _tokenDecimals;
        tokenWeights[_token] = _tokenWeight;
        minProfitBasisPoints[_token] = _minProfitBps;
        maxUsdgAmounts[_token] = _maxUsdgAmount;
        stableTokens[_token] = _isStable;
        shortableTokens[_token] = _isShortable;

        totalTokenWeights = _totalTokenWeights + _tokenWeight;

        // validate price feed
        getMaxPrice(_token);
    }

    function clearTokenConfig(address _token) external {
        _onlyGov();
        _validate(_whitelistedTokens.contains(_token), 13);
        totalTokenWeights = totalTokenWeights - tokenWeights[_token];
        delete tokenDecimals[_token];
        delete tokenWeights[_token];
        delete minProfitBasisPoints[_token];
        delete maxUsdgAmounts[_token];
        delete stableTokens[_token];
        delete shortableTokens[_token];
        _whitelistedTokens.remove(_token);
    }

    function withdrawFees(address _token, address _receiver) external override returns (uint256) {
        _onlyFeeAdminOrGov();
        uint256 amount = feeReserves[_token];
        if(amount == 0) { return 0; }
        feeReserves[_token] = 0;
        _transferOut(_token, amount, _receiver);
        return amount;
    }

    function setRouter(address _router, bool isActive) external {
        approvedRouters[msg.sender][_router] = isActive;
    }

    function setUsdgAmount(address _token, uint256 _amount) external override {
        _onlyGov();

        uint256 usdgAmount = usdgAmounts[_token];
        if (_amount > usdgAmount) {
            _increaseUsdgAmount(_token, _amount - usdgAmount);
            return;
        }

        _decreaseUsdgAmount(_token, usdgAmount - _amount);
    }

    // deposit into the pool without minting USDG tokens
    // useful in allowing the pool to become over-collaterised
    function directPoolDeposit(address _token) external override nonReentrant {
        _validate(_whitelistedTokens.contains(_token), 14);
        uint256 tokenAmount = _transferIn(_token);
        _validate(tokenAmount > 0, 15);
        _increasePoolAmount(_token, tokenAmount);
        emit DirectPoolDeposit(_token, tokenAmount);
    }

    function buyUSDG(address _token, address _receiver) external override nonReentrant returns (uint256) {
        _validateManager();
        _validate(_whitelistedTokens.contains(_token), 16);

        uint256 tokenAmount = _transferIn(_token);
        _validate(tokenAmount > 0, 17);

        updateCumulativeFundingRate(_token, _token);

        uint256 price = getMinPrice(_token);

        uint256 usdgAmount = tokenAmount * price / PRICE_PRECISION;
        usdgAmount = adjustForDecimals(usdgAmount, _token, usdg);
        _validate(usdgAmount > 0, 18);

        uint256 feeBasisPoints = vaultUtils.getBuyUsdgFeeBasisPoints(_token, usdgAmount);
        uint256 amountAfterFees = _collectSwapFees(_token, tokenAmount, feeBasisPoints);
        uint256 mintAmount = amountAfterFees * price / PRICE_PRECISION;
        mintAmount = adjustForDecimals(mintAmount, _token, usdg);

        _increaseUsdgAmount(_token, mintAmount);
        _increasePoolAmount(_token, amountAfterFees);

        IMintable(usdg).mint(_receiver, mintAmount);

        emit BuyUSDG(_receiver, _token, tokenAmount, mintAmount, feeBasisPoints);

        return mintAmount;
    }

    function sellUSDG(address _token, address _receiver) external override nonReentrant returns (uint256) {
        _validateManager();
        _validate(_whitelistedTokens.contains(_token), 19);

        uint256 usdgAmount = _transferIn(usdg);
        _validate(usdgAmount > 0, 20);

        updateCumulativeFundingRate(_token, _token);

        uint256 redemptionAmount = getRedemptionAmount(_token, usdgAmount);
        _validate(redemptionAmount > 0, 21);

        _decreaseUsdgAmount(_token, usdgAmount);
        _decreasePoolAmount(_token, redemptionAmount);

        IMintable(usdg).burn(address(this), usdgAmount);

        // the _transferIn call increased the value of tokenBalances[usdg]
        // usually decreases in token balances are synced by calling _transferOut
        // however, for usdg, the tokens are burnt, so _updateTokenBalance should
        // be manually called to record the decrease in tokens
        _updateTokenBalance(usdg);

        uint256 feeBasisPoints = vaultUtils.getSellUsdgFeeBasisPoints(_token, usdgAmount);
        uint256 amountOut = _collectSwapFees(_token, redemptionAmount, feeBasisPoints);
        _validate(amountOut > 0, 22);

        _transferOut(_token, amountOut, _receiver);

        emit SellUSDG(_receiver, _token, usdgAmount, amountOut, feeBasisPoints);

        return amountOut;
    }

    function swap(address _tokenIn, address _tokenOut, address _receiver) external override nonReentrant returns (uint256) {
        _validate(isSwapEnabled, 23);
        _validate(_whitelistedTokens.contains(_tokenIn), 24);
        _validate(_whitelistedTokens.contains(_tokenOut), 25);
        _validate(_tokenIn != _tokenOut, 26);


        updateCumulativeFundingRate(_tokenIn, _tokenIn);
        updateCumulativeFundingRate(_tokenOut, _tokenOut);

        uint256 amountIn = _transferIn(_tokenIn);
        _validate(amountIn > 0, 27);

        uint256 priceIn = getMinPrice(_tokenIn);
        uint256 priceOut = getMaxPrice(_tokenOut);

        uint256 amountOut = amountIn * priceIn / priceOut;
        amountOut = adjustForDecimals(amountOut, _tokenIn, _tokenOut);

        // adjust usdgAmounts by the same usdgAmount as debt is shifted between the assets
        uint256 usdgAmount = amountIn * priceIn / PRICE_PRECISION;
        usdgAmount = adjustForDecimals(usdgAmount, _tokenIn, usdg);

        uint256 feeBasisPoints = vaultUtils.getSwapFeeBasisPoints(_tokenIn, _tokenOut, usdgAmount);
        uint256 amountOutAfterFees = _collectSwapFees(_tokenOut, amountOut, feeBasisPoints);

        _increaseUsdgAmount(_tokenIn, usdgAmount);
        _decreaseUsdgAmount(_tokenOut, usdgAmount);

        _increasePoolAmount(_tokenIn, amountIn);
        _decreasePoolAmount(_tokenOut, amountOut);

        vaultUtils.validateBufferAmount(_tokenOut);

        _transferOut(_tokenOut, amountOutAfterFees, _receiver);

        emit Swap(_receiver, _tokenIn, _tokenOut, amountIn, amountOut, amountOutAfterFees, feeBasisPoints);

        return amountOutAfterFees;
    }

    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external override nonReentrant {
        IncreasePositionParams memory increasePositionParams = IncreasePositionParams({
            account: _account,
            collateralToken: _collateralToken,
            indexToken: _indexToken,
            sizeDelta: _sizeDelta,
            isLong: _isLong,
            brokerAddress: address(0),
            brokerFeeBasisPoints: 0
        });

        return _increasePositionInternal(increasePositionParams);
    }

    function increasePositionV2(IncreasePositionParams memory increasePositionParams) external nonReentrant {
        return _increasePositionInternal(increasePositionParams);
    }

    function _increasePositionInternal(IncreasePositionParams memory increasePositionParams) private {
        _validate(isLeverageEnabled, 28);
        _validateGasPrice();
        _validateRouter(increasePositionParams.account);
        _validateTokens(increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.isLong);
        vaultUtils.validateIncreasePosition(increasePositionParams.account, increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.sizeDelta, increasePositionParams.isLong);

        updateCumulativeFundingRate(increasePositionParams.collateralToken, increasePositionParams.indexToken);

        bytes32 key = getPositionKey(increasePositionParams.account, increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.isLong);
        Position storage position = positions[key];

        {
            position.brokerAddress = increasePositionParams.brokerAddress;
            position.brokerFeeBasisPoints = increasePositionParams.brokerFeeBasisPoints;
        }

        uint256 price = increasePositionParams.isLong ? getMaxPrice(increasePositionParams.indexToken) : getMinPrice(increasePositionParams.indexToken);

        if (position.size == 0) {
            position.averagePrice = price;
        }

        if (position.size > 0 && increasePositionParams.sizeDelta > 0) {
            position.averagePrice = vaultUtils.getNextAveragePrice(increasePositionParams.indexToken, position.size, position.averagePrice, increasePositionParams.isLong, price, increasePositionParams.sizeDelta, position.lastIncreasedTime);
        }

        uint256 collateralDelta = _transferIn(increasePositionParams.collateralToken);
        uint256 collateralDeltaUsd = tokenToUsdMin(increasePositionParams.collateralToken, collateralDelta);
        position.collateral = position.collateral + collateralDeltaUsd;

        (uint256 fee, uint256 brokerFeeUsd, uint256 brokerFeeAmount) = _collectMarginFees(CollectFeeParams(increasePositionParams.account, increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.isLong, increasePositionParams.sizeDelta, position.size, position.entryFundingRate, increasePositionParams.brokerAddress, increasePositionParams.brokerFeeBasisPoints));

        _validate(position.collateral >= fee, 29);

        position.collateral = position.collateral - fee;
        position.entryFundingRate = getEntryFundingRate(increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.isLong);
        position.size = position.size + increasePositionParams.sizeDelta;
        position.lastIncreasedTime = block.timestamp;

        _validate(position.size > 0, 30);
        _validatePosition(position.size, position.collateral);
        validateLiquidation(increasePositionParams.account, increasePositionParams.collateralToken, increasePositionParams.indexToken, increasePositionParams.isLong, true);

        // reserve tokens to pay profits on the position
        {
            uint256 reserveDelta = usdToTokenMax(increasePositionParams.collateralToken, increasePositionParams.sizeDelta);
            position.reserveAmount = position.reserveAmount + reserveDelta;
            _increaseReservedAmount(increasePositionParams.collateralToken, reserveDelta);
        }
        
        if (increasePositionParams.isLong) {
            // guaranteedUsd stores the sum of (position.size - position.collateral) for all positions
            // if a fee is charged on the collateral then guaranteedUsd should be increased by that fee amount
            // since (position.size - position.collateral) would have increased by `fee`
            _increaseGuaranteedUsd(increasePositionParams.collateralToken, increasePositionParams.sizeDelta + fee);
            _decreaseGuaranteedUsd(increasePositionParams.collateralToken, collateralDeltaUsd);
            // treat the deposited collateral as part of the pool
            // There is no brokerFee in poolAmount change because it was transferred out of Fulcrom during collectMarginFee of previous step
            _increasePoolAmount(increasePositionParams.collateralToken, collateralDelta - brokerFeeAmount);
            // fees need to be deducted from the pool since fees are deducted from position.collateral
            // and collateral is treated as part of the pool
            _decreasePoolAmount(increasePositionParams.collateralToken, usdToTokenMin(increasePositionParams.collateralToken, fee - brokerFeeUsd));
        } else {
            if (globalShortSizes[increasePositionParams.indexToken] == 0) {
                globalShortAveragePrices[increasePositionParams.indexToken] = price;
            } else {
                globalShortAveragePrices[increasePositionParams.indexToken] = vaultUtils.getNextGlobalShortAveragePrice(increasePositionParams.indexToken, price, increasePositionParams.sizeDelta);
            }

            _increaseGlobalShortSize(increasePositionParams.indexToken, increasePositionParams.sizeDelta);
        }

        emit IncreasePositionByBroker(key, increasePositionParams.brokerAddress, increasePositionParams.brokerFeeBasisPoints);
        emit IncreasePosition(key, increasePositionParams.account, increasePositionParams.collateralToken, increasePositionParams.indexToken, collateralDeltaUsd, increasePositionParams.sizeDelta, increasePositionParams.isLong, price, fee);
        emit UpdatePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl, price);
    }

    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external override nonReentrant returns (uint256) {
        _validateGasPrice();
        _validateRouter(_account);
        return _decreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    }

    function _decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) private returns (uint256) {
        vaultUtils.validateDecreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
        updateCumulativeFundingRate(_collateralToken, _indexToken);

        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position storage position = positions[key];
        
        _validate(position.size > 0, 31);
        _validate(position.size >= _sizeDelta, 32);
        _validate(position.collateral >= _collateralDelta, 33);

        uint256 collateral = position.collateral;
        // scrop variables to avoid stack too deep errors
        {
        uint256 reserveDelta = position.reserveAmount * _sizeDelta / position.size;
        position.reserveAmount = position.reserveAmount - reserveDelta;
        _decreaseReservedAmount(_collateralToken, reserveDelta);
        }

        (uint256 usdOut, uint256 usdOutAfterFee) = _reduceCollateral(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong);

        emit DecreasePositionByBroker(key, position.brokerAddress, position.brokerFeeBasisPoints);

        if (position.size != _sizeDelta) {
            position.entryFundingRate = getEntryFundingRate(_collateralToken, _indexToken, _isLong);
            position.size = position.size - _sizeDelta;

            _validatePosition(position.size, position.collateral);
            validateLiquidation(_account, _collateralToken, _indexToken, _isLong, true);

            if (_isLong) {
                _increaseGuaranteedUsd(_collateralToken, collateral - position.collateral);
                _decreaseGuaranteedUsd(_collateralToken, _sizeDelta);
            }

            uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
            emit DecreasePosition(key, _account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, price, usdOut - usdOutAfterFee);
            emit UpdatePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl, price);
        } else {
            if (_isLong) {
                _increaseGuaranteedUsd(_collateralToken, collateral);
                _decreaseGuaranteedUsd(_collateralToken, _sizeDelta);
            }

            uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
            emit DecreasePosition(key, _account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, price, usdOut - usdOutAfterFee);
            emit ClosePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl);

            delete positions[key];
        }

        if (!_isLong) {
            _decreaseGlobalShortSize(_indexToken, _sizeDelta);
        }

        if (usdOut > 0) {
            if (_isLong) {
                _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, usdOut));
            }
            uint256 amountOutAfterFees = usdToTokenMin(_collateralToken, usdOutAfterFee);
            _transferOut(_collateralToken, amountOutAfterFees, _receiver);
            return amountOutAfterFees;
        }

        return 0;
    }

    function partialLiquidate(bytes32 key, address _account, address _collateralToken, address _indexToken, bool _isLong, Position memory position) private {
        uint256 amountOutAfterFees = _decreasePosition(_account, _collateralToken, _indexToken, 0, position.size, _isLong, _account);
        uint256 markPrice = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
        emit PartialLiquidation(key, _account, _collateralToken, _indexToken, _isLong, position.size, position.collateral, amountOutAfterFees, markPrice);
    }

    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external override nonReentrant {
        if (inPrivateLiquidationMode) {
            _validate(isLiquidator[msg.sender], 34);
        }

        updateCumulativeFundingRate(_collateralToken, _indexToken);

        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position memory position = positions[key];
        _validate(position.size > 0, 35);

        (uint256 liquidationState, uint256 marginFees) = validateLiquidation(_account, _collateralToken, _indexToken, _isLong, false);
        _validate(liquidationState != 0, 36);
        if (liquidationState == 2) {
            // max leverage exceeded but there is collateral remaining after deducting losses so decreasePosition instead
            partialLiquidate(key, _account, _collateralToken, _indexToken, _isLong, position);

            return;
        }

        uint256 feeTokens = usdToTokenMin(_collateralToken, marginFees);
        feeReserves[_collateralToken] = feeReserves[_collateralToken] + feeTokens;
        emit CollectMarginFees(_collateralToken, marginFees, feeTokens);

        _decreaseReservedAmount(_collateralToken, position.reserveAmount);
        if (_isLong) {
            _decreaseGuaranteedUsd(_collateralToken, position.size - position.collateral);
            _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, marginFees));
        }

        uint256 markPrice = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
        emit LiquidatePosition(key, _account, _collateralToken, _indexToken, _isLong, position.size, position.collateral, markPrice);

        if (!_isLong && marginFees < position.collateral) {
            _increasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, position.collateral - marginFees));
        }

        if (!_isLong) {
            _decreaseGlobalShortSize(_indexToken, position.size);
        }

        delete positions[key];

        // transfer out broker fee during liquidation process
        if (position.brokerAddress != address(0) && position.brokerFeeBasisPoints > 0) {
            (, uint256 brokerFeeAmount) = _chargeBrokerFee(position.size, _collateralToken, position.brokerAddress, position.brokerFeeBasisPoints);

            // update fee reserve if transfer out since added from validateLiquidation step
            feeReserves[_collateralToken] = feeReserves[_collateralToken] - brokerFeeAmount;
        }

        // pay the fee receiver using the pool, we assume that in general the liquidated amount should be sufficient to cover
        // the liquidation fees
        uint256 liquidationFee = fixedLiquidationFeeUsd;
        if (marginFees < position.collateral) {
            liquidationFee = vaultUtils.getLiquidationFee(position.collateral - marginFees);
        }

        _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, liquidationFee));
        _collectLiquidationFees(_collateralToken, usdToTokenMin(_collateralToken, liquidationFee));
    }

    function _chargeBrokerFee(uint256 _sizeDelta, address _collateralToken, address _brokerAddress, uint256 _brokerFeeBasisPoints) private returns (uint256, uint256) {
        uint256 brokerFeeUsd = vaultUtils.getBrokerFee(_sizeDelta, _brokerFeeBasisPoints);
        uint256 brokerFeeAmount = usdToTokenMin(_collateralToken, brokerFeeUsd);
        
        _transferOut(_collateralToken, brokerFeeAmount, _brokerAddress);
        emit CollectBrokerFees(_collateralToken, brokerFeeUsd, brokerFeeAmount, _sizeDelta, _brokerAddress, _brokerFeeBasisPoints);

        return (brokerFeeUsd, brokerFeeAmount);
    }

    // validateLiquidation returns (state, fees)
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) override public view returns (uint256, uint256) {
        return vaultUtils.validateLiquidation(_account, _collateralToken, _indexToken, _isLong, _raise);
    }

    function getMaxPrice(address _token) public override view returns (uint256) {
        return IVaultPriceFeed(priceFeed).getPrice(_token, true);
    }

    function getMinPrice(address _token) public override view returns (uint256) {
        return IVaultPriceFeed(priceFeed).getPrice(_token, false);
    }

    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) public view returns (uint256) {
        return vaultUtils.adjustForDecimals(_amount, _tokenDiv, _tokenMul);
    }

    function tokenToUsdMin(address _token, uint256 _tokenAmount) public override view returns (uint256) {
        if (_tokenAmount == 0) { return 0; }
        uint256 decimals = tokenDecimals[_token];
        return _tokenAmount * getMinPrice(_token) / (10 ** decimals);
    }

    function usdToTokenMax(address _token, uint256 _usdAmount) public view returns (uint256) {
        if (_usdAmount == 0) { return 0; }
        return usdToToken(_token, _usdAmount, getMinPrice(_token));
    }

    function usdToTokenMin(address _token, uint256 _usdAmount) public view returns (uint256) {
        if (_usdAmount == 0) { return 0; }
        return usdToToken(_token, _usdAmount, getMaxPrice(_token));
    }

    function usdToToken(address _token, uint256 _usdAmount, uint256 _price) public view returns (uint256) {
        if (_usdAmount == 0) { return 0; }
        uint256 decimals = tokenDecimals[_token];
        return _usdAmount * (10 ** decimals) / _price;
    }

    // Many of the contracts rely on this function
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) public override view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256) {
        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position memory position = positions[key];
        uint256 realisedPnl = position.realisedPnl > 0 ? uint256(position.realisedPnl) : uint256(-position.realisedPnl);
        return (
            position.size, // 0
            position.collateral, // 1
            position.averagePrice, // 2
            position.entryFundingRate, // 3
            position.reserveAmount, // 4
            realisedPnl, // 5
            position.realisedPnl >= 0, // 6
            position.lastIncreasedTime // 7
        );
    }

    function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _account,
            _collateralToken,
            _indexToken,
            _isLong
        ));
    }

    function updateCumulativeFundingRate(address _collateralToken, address _indexToken) public {
        if (lastFundingTimes[_collateralToken] == 0) {
            lastFundingTimes[_collateralToken] = block.timestamp / fundingInterval * fundingInterval;
            return;
        }

        if (lastFundingTimes[_collateralToken] + fundingInterval > block.timestamp) {
            return;
        }

        uint256 fundingRate = getNextFundingRate(_collateralToken);
        cumulativeFundingRates[_collateralToken] = cumulativeFundingRates[_collateralToken] + fundingRate;
        lastFundingTimes[_collateralToken] = block.timestamp / fundingInterval * fundingInterval;

        emit UpdateFundingRate(_collateralToken, cumulativeFundingRates[_collateralToken]);
    }

    function getNextFundingRate(address _token) public override view returns (uint256) {
        return vaultUtils.getNextFundingRate(_token);
    }

    function getPositionLeverage(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
        return vaultUtils.getPositionLeverage(_account, _collateralToken, _indexToken, _isLong);
    }

    function getGlobalShortDelta(address _token) public view returns (bool, uint256) {
        return vaultUtils.getGlobalShortDelta(_token);
    }

    function getEntryFundingRate(address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
        return vaultUtils.getEntryFundingRate(_collateralToken, _indexToken, _isLong);
    }

    function getPositionFee(uint256 _sizeDelta) public view returns (uint256) {
        return vaultUtils.getPositionFee(_sizeDelta);
    }

    function getRedemptionAmount(address _token, uint256 _usdgAmount) public override view returns (uint256) {
        return vaultUtils.getRedemptionAmount(_token, _usdgAmount);
    }

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) public override view returns (bool, uint256) {
        return vaultUtils.getDelta(_indexToken, _size, _averagePrice, _isLong, _lastIncreasedTime);
    }

    function transferOutTokens(address[] calldata _tokens, uint[] calldata _amounts, address _receiver) external nonReentrant {
        _validateManager();
        for (uint256 i = 0; i < _tokens.length;) {
            _transferOut(_tokens[i], _amounts[i], _receiver);

            unchecked { i++; }
        }
    }

    function _reduceCollateral(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong) private returns (uint256, uint256) {
        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position storage position = positions[key];

        uint256 fee = 0;
        {
            (uint256 _fee, , ) = _collectMarginFees(CollectFeeParams(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, position.size, position.entryFundingRate, position.brokerAddress, position.brokerFeeBasisPoints));
            fee = _fee;
        }

        bool hasProfit;
        uint256 adjustedDelta;

        // scope variables to avoid stack too deep errors
        {
            (bool _hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
            hasProfit = _hasProfit;
            // get the proportional change in pnl
            adjustedDelta = _sizeDelta * delta / position.size;
        }

        uint256 usdOut;
        // transfer profits out
        if (hasProfit && adjustedDelta > 0) {
            usdOut = adjustedDelta;
            position.realisedPnl = position.realisedPnl + int256(adjustedDelta);

            // pay out realised profits from the pool amount for short positions
            if (!_isLong) {
                _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, adjustedDelta));
            }
        }

        if (!hasProfit && adjustedDelta > 0) {
            position.collateral = position.collateral - adjustedDelta;

            // transfer realised losses to the pool for short positions
            // realised losses for long positions are not transferred here as
            // _increasePoolAmount was already called in increasePosition for longs
            if (!_isLong) {
                _increasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, adjustedDelta));
            }

            position.realisedPnl = position.realisedPnl - int256(adjustedDelta);
        }

        // reduce the position's collateral by _collateralDelta
        // transfer _collateralDelta out
        if (_collateralDelta > 0) {
            usdOut = usdOut + _collateralDelta;
            position.collateral = position.collateral - _collateralDelta;
        }

        // if the position will be closed, then transfer the remaining collateral out
        if (position.size == _sizeDelta) {
            usdOut = usdOut + position.collateral;
            position.collateral = 0;
        }

        // if the usdOut is more than the fee then deduct the fee from the usdOut directly
        // else deduct the fee from the position's collateral
        uint256 usdOutAfterFee = usdOut;
        if (usdOut > fee) {
            usdOutAfterFee = usdOut - fee;
        } else {
            position.collateral = position.collateral - fee;
            if (_isLong) {
                uint256 feeTokens = usdToTokenMin(_collateralToken, fee);
                _decreasePoolAmount(_collateralToken, feeTokens);
            }
        }

        emit UpdatePnl(key, hasProfit, adjustedDelta);

        return (usdOut, usdOutAfterFee);
    }

    function _validatePosition(uint256 _size, uint256 _collateral) private view {
        if (_size == 0) {
            _validate(_collateral == 0, 39);
            return;
        }
        _validate(_size >= _collateral, 40);
    }

    function _validateRouter(address _account) private view {
        if (msg.sender == _account) { return; }
        if (msg.sender == router) { return; }
        _validate(approvedRouters[_account][msg.sender], 41);
    }

    function _validateTokens(address _collateralToken, address _indexToken, bool _isLong) private view {
        if (_isLong) {
            _validate(_collateralToken == _indexToken, 42);
            _validate(_whitelistedTokens.contains(_collateralToken), 43);
            _validate(!stableTokens[_collateralToken], 44);
            return;
        }

        _validate(_whitelistedTokens.contains(_collateralToken), 45);
        _validate(stableTokens[_collateralToken], 46);
        _validate(!stableTokens[_indexToken], 47);
        _validate(shortableTokens[_indexToken], 48);
    }

    function _collectLiquidationFees(address _token, uint256 _amount) private returns (uint256) {
        feeReserves[_token] = feeReserves[_token] + _amount;
        uint256 feeUsd = tokenToUsdMin(_token, _amount);

        emit CollectLiquidationFees(_token, feeUsd, _amount);

        return feeUsd;
    }

    function _collectSwapFees(address _token, uint256 _amount, uint256 _feeBasisPoints) private returns (uint256) {
        uint256 afterFeeAmount = _amount * (BASIS_POINTS_DIVISOR - _feeBasisPoints) / BASIS_POINTS_DIVISOR;
        uint256 feeAmount = _amount - afterFeeAmount;
        feeReserves[_token] = feeReserves[_token] + feeAmount;
        emit CollectSwapFees(_token, tokenToUsdMin(_token, feeAmount), feeAmount);
        return afterFeeAmount;
    }

    function _collectMarginFees(CollectFeeParams memory feeParams) private returns (uint256, uint256, uint256) {
        uint tokenPrice = getMaxPrice(feeParams.collateralToken);
        uint256 positionFeeUsd = getPositionFee(feeParams.sizeDelta);

        ReferralPositionFee memory referralPositionFee;
        if (address(referralManager) != address(0)) {
            referralPositionFee = referralManager.discountPositionFee(feeParams.account, feeParams.collateralToken, tokenPrice, positionFeeUsd, feeParams.sizeDelta);
        } else {
            referralPositionFee.feeForPoolUsd = positionFeeUsd;
            referralPositionFee.feeForPoolAmount = usdToToken(feeParams.collateralToken, positionFeeUsd, tokenPrice);
        }

        uint256 feeUsd = vaultUtils.getFundingFee(feeParams.account, feeParams.collateralToken, feeParams.indexToken, feeParams.isLong, feeParams.size, feeParams.entryFundingRate);
        uint256 feeAmount = usdToToken(feeParams.collateralToken, feeUsd, tokenPrice);

        unchecked {
            feeUsd += referralPositionFee.feeForPoolUsd;
            feeAmount += referralPositionFee.feeForPoolAmount;
        }

        //  CollectMarginFees and feeReserves only for fees collected on the fulcrom side
        feeReserves[feeParams.collateralToken] = feeReserves[feeParams.collateralToken] + feeAmount;
        emit CollectMarginFees(feeParams.collateralToken, feeUsd, feeAmount);

        if (feeParams.brokerAddress != address(0) && feeParams.brokerFeeBasisPoints > 0) {
            (uint256 brokerFeeUsd, uint256 brokerFeeAmount) = _chargeBrokerFee(feeParams.sizeDelta, feeParams.collateralToken, feeParams.brokerAddress, feeParams.brokerFeeBasisPoints);
            
            unchecked {
                feeUsd += brokerFeeUsd;
            }

            return (feeUsd + referralPositionFee.rebateUsd, brokerFeeUsd, brokerFeeAmount);
        }

        // it's import to plus the rebate, because we also charge the rebate from trader
        return (feeUsd + referralPositionFee.rebateUsd, 0, 0);
    }

    function _transferIn(address _token) private returns (uint256) {
        uint256 prevBalance = tokenBalances[_token];
        uint256 nextBalance = IERC20Upgradeable(_token).balanceOf(address(this));
        tokenBalances[_token] = nextBalance;

        return nextBalance - prevBalance;
    }

    function _transferOut(address _token, uint256 _amount, address _receiver) private {
        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
        tokenBalances[_token] = IERC20Upgradeable(_token).balanceOf(address(this));
    }

    function _updateTokenBalance(address _token) private {
        uint256 nextBalance = IERC20Upgradeable(_token).balanceOf(address(this));
        tokenBalances[_token] = nextBalance;
    }

    function _increasePoolAmount(address _token, uint256 _amount) private {
        poolAmounts[_token] = poolAmounts[_token] + _amount;
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        _validate(poolAmounts[_token] <= balance, 49);
        emit IncreasePoolAmount(_token, _amount);
    }

    function _decreasePoolAmount(address _token, uint256 _amount) private {
        _validate(poolAmounts[_token] >= _amount, 57);
        poolAmounts[_token] = poolAmounts[_token] - _amount;
        _validate(reservedAmounts[_token] <= poolAmounts[_token], 50);
        emit DecreasePoolAmount(_token, _amount);
    }

    function _increaseUsdgAmount(address _token, uint256 _amount) private {
        usdgAmounts[_token] = usdgAmounts[_token] + _amount;
        uint256 maxUsdgAmount = maxUsdgAmounts[_token];
        if (maxUsdgAmount != 0) {
            _validate(usdgAmounts[_token] <= maxUsdgAmount, 51);
        }
        emit IncreaseUsdgAmount(_token, _amount);
    }

    function _decreaseUsdgAmount(address _token, uint256 _amount) private {
        uint256 value = usdgAmounts[_token];
        // since USDG can be minted using multiple assets
        // it is possible for the USDG debt for a single asset to be less than zero
        // the USDG debt is capped to zero for this case
        if (value <= _amount) {
            usdgAmounts[_token] = 0;
            emit DecreaseUsdgAmount(_token, value);
            return;
        }
        usdgAmounts[_token] = value - _amount;
        emit DecreaseUsdgAmount(_token, _amount);
    }

    function _increaseReservedAmount(address _token, uint256 _amount) private {
        reservedAmounts[_token] = reservedAmounts[_token] + _amount;
        _validate(reservedAmounts[_token] <= poolAmounts[_token], 52);
        emit IncreaseReservedAmount(_token, _amount);
    }

    function _decreaseReservedAmount(address _token, uint256 _amount) private {
        _validate(reservedAmounts[_token] >= _amount, 58);
        reservedAmounts[_token] = reservedAmounts[_token] - _amount;
        emit DecreaseReservedAmount(_token, _amount);
    }

    function _increaseGuaranteedUsd(address _token, uint256 _usdAmount) private {
        guaranteedUsd[_token] = guaranteedUsd[_token] + _usdAmount;
        emit IncreaseGuaranteedUsd(_token, _usdAmount);
    }

    function _decreaseGuaranteedUsd(address _token, uint256 _usdAmount) private {
        guaranteedUsd[_token] = guaranteedUsd[_token] - _usdAmount;
        emit DecreaseGuaranteedUsd(_token, _usdAmount);
    }

    function _increaseGlobalShortSize(address _token, uint256 _amount) internal {
        globalShortSizes[_token] = globalShortSizes[_token] + _amount;

        uint256 maxSize = maxGlobalShortSizes[_token];
        if (maxSize != 0) {
            _validate(globalShortSizes[_token] <= maxSize, 59);
        }
    }

    function _decreaseGlobalShortSize(address _token, uint256 _amount) private {
        uint256 size = globalShortSizes[_token];
        if (_amount > size) {
          globalShortSizes[_token] = 0;
          return;
        }

        globalShortSizes[_token] = size - _amount;
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _onlyGov() private view {
        _validate(msg.sender == gov, 53);
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _validateManager() private view {
        if (inManagerMode) {
            _validate(isManager[msg.sender], 54);
        }
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _validateGasPrice() private view {
        if (maxGasPrice == 0) { return; }
        _validate(tx.gasprice <= maxGasPrice, 55);
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _onlyFeeAdminOrGov() private view {
        _validate(msg.sender == feeAdmin || msg.sender == gov, 56);
    }

    function _validate(bool _condition, uint256 _errorCode) private view {
        require(_condition, errors[_errorCode]);
    }
}
