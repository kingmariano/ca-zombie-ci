// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IOrderBook.sol";
import "./libraries/LibFeeHelper.sol";
import "../access/Governable.sol";
import "../tokens/interfaces/IWETH.sol";

contract OrderBook is ReentrancyGuardUpgradeable, IOrderBook, Governable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;

    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant USDG_PRECISION = 1e18;

    struct IncreaseOrder {
        address account;
        address purchaseToken;
        uint256 purchaseTokenAmount;
        address collateralToken;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        uint256 tp;
        uint256 sl;
        uint256 tpSlExecutionFee;
    }
    struct DecreaseOrder {
        address account;
        address collateralToken;
        uint256 collateralDelta;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
    }
    struct SwapOrder {
        address account;
        address[] path;
        uint256 amountIn;
        uint256 minOut;
        uint256 triggerRatio;
        bool triggerAboveThreshold;
        bool shouldUnwrap;
        uint256 executionFee;
    }
    struct IncreaseOrderParams {
        address[] path;
        uint256 amountIn;
        address indexToken;
        uint256 minOut;
        uint256 sizeDelta;
        address collateralToken;
        bool isLong;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
        uint256 executionFee;
        bool shouldWrap;
        uint256 tp;
        uint256 sl;
    }

    mapping (address => mapping(uint256 => IncreaseOrder)) public increaseOrders;
    mapping (address => uint256) public increaseOrdersIndex;
    mapping (address => mapping(uint256 => DecreaseOrder)) public decreaseOrders;
    mapping (address => uint256) public decreaseOrdersIndex;
    mapping (address => mapping(uint256 => SwapOrder)) public swapOrders;
    mapping (address => uint256) public swapOrdersIndex;

    address public weth;
    address public usdg;
    address public router;
    address public vault;
    uint256 public minExecutionFee;
    uint256 public minPurchaseTokenAmountUsd;
    bool public isInitialized;

    address public positionRouter;

    event IncreaseOrderCreated(
        address indexed account,
        uint256 orderIndex,
        IncreaseOrder order
    );

    event IncreaseOrderExecuted(
        address indexed account,
        uint256 orderIndex,
        uint256 executionPrice,
        IncreaseOrder order
    );

    event IncreaseOrderCancelled(
        address indexed account,
        uint256 orderIndex,
        IncreaseOrder order
    );

    event IncreaseOrderUpdated(
        address indexed account,
        uint256 orderIndex,
        IncreaseOrder order
    );

    event CreateIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );
    event CancelIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );
    event ExecuteIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice
    );
    event UpdateIncreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 sizeDelta,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    );
    event CreateDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );
    event CancelDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    );
    event ExecuteDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee,
        uint256 executionPrice
    );
    event UpdateDecreaseOrder(
        address indexed account,
        uint256 orderIndex,
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    );
    event CreateSwapOrder(
        address indexed account,
        uint256 orderIndex,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        uint256 triggerRatio,
        bool triggerAboveThreshold,
        bool shouldUnwrap,
        uint256 executionFee
    );
    event CancelSwapOrder(
        address indexed account,
        uint256 orderIndex,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        uint256 triggerRatio,
        bool triggerAboveThreshold,
        bool shouldUnwrap,
        uint256 executionFee
    );
    event UpdateSwapOrder(
        address indexed account,
        uint256 orderIndex,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        uint256 triggerRatio,
        bool triggerAboveThreshold,
        bool shouldUnwrap,
        uint256 executionFee
    );
    event ExecuteSwapOrder(
        address indexed account,
        uint256 orderIndex,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        uint256 amountOut,
        uint256 triggerRatio,
        bool triggerAboveThreshold,
        bool shouldUnwrap,
        uint256 executionFee
    );

    event Initialize(
        address router,
        address vault,
        address weth,
        address usdg,
        uint256 minExecutionFee,
        uint256 minPurchaseTokenAmountUsd
    );
    event UpdateMinExecutionFee(uint256 minExecutionFee);
    event UpdateMinPurchaseTokenAmountUsd(uint256 minPurchaseTokenAmountUsd);

    function initialize() public initializer {
        __Governable_init();
    }

    function initOrderBook(
        address _router,
        address _vault,
        address _weth,
        address _usdg,
        uint256 _minExecutionFee,
        uint256 _minPurchaseTokenAmountUsd
    ) external onlyGov {
        require(!isInitialized, "OrderBook: already initialized");
        isInitialized = true;

        router = _router;
        vault = _vault;
        weth = _weth;
        usdg = _usdg;
        minExecutionFee = _minExecutionFee;
        minPurchaseTokenAmountUsd = _minPurchaseTokenAmountUsd;

        emit Initialize(_router, _vault, _weth, _usdg, _minExecutionFee, _minPurchaseTokenAmountUsd);
    }

    receive() external payable {
        require(msg.sender == weth, "OrderBook: invalid sender");
    }

    function setPositionRouter(address _positionRouter) external onlyGov {
        positionRouter = _positionRouter;
    }

    function setMinExecutionFee(uint256 _minExecutionFee) external onlyGov {
        minExecutionFee = _minExecutionFee;

        emit UpdateMinExecutionFee(_minExecutionFee);
    }

    function setMinPurchaseTokenAmountUsd(uint256 _minPurchaseTokenAmountUsd) external onlyGov {
        minPurchaseTokenAmountUsd = _minPurchaseTokenAmountUsd;

        emit UpdateMinPurchaseTokenAmountUsd(_minPurchaseTokenAmountUsd);
    }

    function getSwapOrder(address _account, uint256 _orderIndex) override public view returns (
        address path0,
        address path1,
        address path2,
        uint256 amountIn,
        uint256 minOut,
        uint256 triggerRatio,
        bool triggerAboveThreshold,
        bool shouldUnwrap,
        uint256 executionFee
    ) {
        SwapOrder memory order = swapOrders[_account][_orderIndex];
        return (
            order.path.length > 0 ? order.path[0] : address(0),
            order.path.length > 1 ? order.path[1] : address(0),
            order.path.length > 2 ? order.path[2] : address(0),
            order.amountIn,
            order.minOut,
            order.triggerRatio,
            order.triggerAboveThreshold,
            order.shouldUnwrap,
            order.executionFee
        );
    }

    function createSwapOrder(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _triggerRatio, // tokenB / tokenA
        bool _triggerAboveThreshold,
        uint256 _executionFee,
        bool _shouldWrap,
        bool _shouldUnwrap
    ) external payable nonReentrant {
        require(_path.length == 2 || _path.length == 3, "OrderBook: invalid _path.length");
        require(_path[0] != _path[_path.length - 1], "OrderBook: invalid _path");
        require(_amountIn > 0, "OrderBook: invalid _amountIn");
        require(_executionFee >= minExecutionFee, "OrderBook: insufficient execution fee");

        // always need this call because of mandatory executionFee user has to transfer in ETH
        _transferInETH();

        if (_shouldWrap) {
            require(_path[0] == weth, "OrderBook: only weth could be wrapped");
            require(msg.value == _executionFee + _amountIn, "OrderBook: incorrect value transferred");
        } else {
            require(msg.value == _executionFee, "OrderBook: incorrect execution fee transferred");
            IRouter(router).pluginTransfer(_path[0], msg.sender, address(this), _amountIn);
        }

        _createSwapOrder(msg.sender, _path, _amountIn, _minOut, _triggerRatio, _triggerAboveThreshold, _shouldUnwrap, _executionFee);
    }

    function _createSwapOrder(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _triggerRatio,
        bool _triggerAboveThreshold,
        bool _shouldUnwrap,
        uint256 _executionFee
    ) private {
        uint256 _orderIndex = swapOrdersIndex[_account];
        SwapOrder memory order = SwapOrder(
            _account,
            _path,
            _amountIn,
            _minOut,
            _triggerRatio,
            _triggerAboveThreshold,
            _shouldUnwrap,
            _executionFee
        );
        swapOrdersIndex[_account] = _orderIndex + 1;
        swapOrders[_account][_orderIndex] = order;

        emit CreateSwapOrder(
            _account,
            _orderIndex,
            _path,
            _amountIn,
            _minOut,
            _triggerRatio,
            _triggerAboveThreshold,
            _shouldUnwrap,
            _executionFee
        );
    }

    function cancelMultiple(
        uint256[] memory _swapOrderIndexes,
        uint256[] memory _increaseOrderIndexes,
        uint256[] memory _decreaseOrderIndexes
    ) external {
        for (uint256 i = 0; i < _swapOrderIndexes.length; i++) {
            cancelSwapOrder(_swapOrderIndexes[i]);
        }
        for (uint256 i = 0; i < _increaseOrderIndexes.length; i++) {
            cancelIncreaseOrder(_increaseOrderIndexes[i]);
        }
        for (uint256 i = 0; i < _decreaseOrderIndexes.length; i++) {
            cancelDecreaseOrder(_decreaseOrderIndexes[i]);
        }
    }

    function cancelSwapOrder(uint256 _orderIndex) public nonReentrant {
        SwapOrder memory order = swapOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        delete swapOrders[msg.sender][_orderIndex];

        if (order.path[0] == weth) {
            _transferOutETH(order.executionFee + order.amountIn, payable(msg.sender));
        } else {
            IERC20Upgradeable(order.path[0]).safeTransfer(msg.sender, order.amountIn);
            _transferOutETH(order.executionFee, payable(msg.sender));
        }

        emit CancelSwapOrder(
            msg.sender,
            _orderIndex,
            order.path,
            order.amountIn,
            order.minOut,
            order.triggerRatio,
            order.triggerAboveThreshold,
            order.shouldUnwrap,
            order.executionFee
        );
    }

    function getUsdgMinPrice(address _otherToken) public view returns (uint256) {
        // USDG_PRECISION is the same as 1 USDG
        uint256 redemptionAmount = IVault(vault).getRedemptionAmount(_otherToken, USDG_PRECISION);
        uint256 otherTokenPrice = IVault(vault).getMinPrice(_otherToken);

        uint256 otherTokenDecimals = IVault(vault).tokenDecimals(_otherToken);
        return redemptionAmount * otherTokenPrice / (10 ** otherTokenDecimals);
    }

    function validateSwapOrderPriceWithTriggerAboveThreshold(
        address[] memory _path,
        uint256 _triggerRatio
    ) public view returns (bool) {
        require(_path.length == 2 || _path.length == 3, "OrderBook: invalid _path.length");

        // limit orders don't need this validation because minOut is enough
        // so this validation handles scenarios for stop orders only
        // when a user wants to swap when a price of tokenB increases relative to tokenA
        address tokenA = _path[0];
        address tokenB = _path[_path.length - 1];
        uint256 tokenAPrice;
        uint256 tokenBPrice;

        // 1. USDG doesn't have a price feed so we need to calculate it based on redepmtion amount of a specific token
        // That's why USDG price in USD can vary depending on the redepmtion token
        // 2. In complex scenarios with path=[USDG, BNB, BTC] we need to know how much BNB we'll get for provided USDG
        // to know how much BTC will be received
        // That's why in such scenario BNB should be used to determine price of USDG
        if (tokenA == usdg) {
            // with both _path.length == 2 or 3 we need usdg price against _path[1]
            tokenAPrice = getUsdgMinPrice(_path[1]);
        } else {
            tokenAPrice = IVault(vault).getMinPrice(tokenA);
        }

        if (tokenB == usdg) {
            tokenBPrice = PRICE_PRECISION;
        } else {
            tokenBPrice = IVault(vault).getMaxPrice(tokenB);
        }

        uint256 currentRatio = tokenBPrice * PRICE_PRECISION / tokenAPrice;

        bool isValid = currentRatio > _triggerRatio;
        return isValid;
    }

    function updateSwapOrder(uint256 _orderIndex, uint256 _minOut, uint256 _triggerRatio, bool _triggerAboveThreshold) external nonReentrant {
        SwapOrder storage order = swapOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        order.minOut = _minOut;
        order.triggerRatio = _triggerRatio;
        order.triggerAboveThreshold = _triggerAboveThreshold;

        emit UpdateSwapOrder(
            msg.sender,
            _orderIndex,
            order.path,
            order.amountIn,
            _minOut,
            _triggerRatio,
            _triggerAboveThreshold,
            order.shouldUnwrap,
            order.executionFee
        );
    }

    function executeSwapOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) override external nonReentrant {
        SwapOrder memory order = swapOrders[_account][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        if (order.triggerAboveThreshold) {
            // gas optimisation
            // order.minAmount should prevent wrong price execution in case of simple limit order
            require(
                validateSwapOrderPriceWithTriggerAboveThreshold(order.path, order.triggerRatio),
                "OrderBook: invalid price for execution"
            );
        }

        delete swapOrders[_account][_orderIndex];

        IERC20Upgradeable(order.path[0]).safeTransfer(vault, order.amountIn);

        uint256 _amountOut;
        if (order.path[order.path.length - 1] == weth && order.shouldUnwrap) {
            _amountOut = _swap(order.path, order.minOut, address(this));
            _transferOutETH(_amountOut, payable(order.account));
        } else {
            _amountOut = _swap(order.path, order.minOut, order.account);
        }

        // pay executor
        _transferOutETH(order.executionFee, _feeReceiver);

        emit ExecuteSwapOrder(
            _account,
            _orderIndex,
            order.path,
            order.amountIn,
            order.minOut,
            _amountOut,
            order.triggerRatio,
            order.triggerAboveThreshold,
            order.shouldUnwrap,
            order.executionFee
        );
    }

    function validatePositionOrderPrice(
        bool _triggerAboveThreshold,
        uint256 _triggerPrice,
        address _indexToken,
        bool _maximizePrice,
        bool _raise
    ) public view returns (uint256, bool) {
        uint256 currentPrice = _maximizePrice
            ? IVault(vault).getMaxPrice(_indexToken) : IVault(vault).getMinPrice(_indexToken);
        bool isPriceValid = _triggerAboveThreshold ? currentPrice > _triggerPrice : currentPrice < _triggerPrice;
        if (_raise) {
            require(isPriceValid, "OrderBook: invalid price for execution");
        }
        return (currentPrice, isPriceValid);
    }

    function getDecreaseOrder(address _account, uint256 _orderIndex) override public view returns (
        address collateralToken,
        uint256 collateralDelta,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    ) {
        DecreaseOrder memory order = decreaseOrders[_account][_orderIndex];
        return (
            order.collateralToken,
            order.collateralDelta,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee
        );
    }

    function getIncreaseOrder(address _account, uint256 _orderIndex) override public view returns (
        address purchaseToken,
        uint256 purchaseTokenAmount,
        address collateralToken,
        address indexToken,
        uint256 sizeDelta,
        bool isLong,
        uint256 triggerPrice,
        bool triggerAboveThreshold,
        uint256 executionFee
    ) {
        IncreaseOrder memory order = increaseOrders[_account][_orderIndex];
        return (
            order.purchaseToken,
            order.purchaseTokenAmount,
            order.collateralToken,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee
        );
    }
    
    function createIncreaseOrderV2(IncreaseOrderParams calldata params) external payable nonReentrant {
        _createIncreaseOrderInternal(params, msg.sender);
    }

    function createIncreaseOrder(
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        address _collateralToken,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee,
        bool _shouldWrap
    ) external payable nonReentrant {
        IncreaseOrderParams memory params = IncreaseOrderParams(
            _path,
            _amountIn,
            _indexToken,
            _minOut,
            _sizeDelta,
            _collateralToken,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee,
            _shouldWrap,
            0,
            0
        );
        _createIncreaseOrderInternal(params, msg.sender);
    }

    function _createIncreaseOrderInternal(IncreaseOrderParams memory _params, address _account) internal {
        require(!AddressUpgradeable.isContract(_account), "OrderBook: account cannot be a contract");
        // always need this call because of mandatory executionFee user has to transfer in ETH
        _transferInETH();

        uint tpSlExecutionFee = LibFeeHelper.getTpSlExecutionFee(_params.tp, _params.sl, minExecutionFee);

        require(_params.executionFee >= minExecutionFee + tpSlExecutionFee, "OrderBook: insufficient execution fee");
        if (_params.shouldWrap) {
            require(_params.path[0] == weth, "OrderBook: only weth could be wrapped");
            require(msg.value == _params.executionFee + _params.amountIn, "OrderBook: incorrect value transferred");
        } else {
            require(msg.value == _params.executionFee, "OrderBook: incorrect execution fee transferred");
            IRouter(router).pluginTransfer(_params.path[0], _account, address(this), _params.amountIn);
        }

        address _purchaseToken = _params.path[_params.path.length - 1];
        uint256 _purchaseTokenAmount;
        if (_params.path.length > 1) {
            require(_params.path[0] != _purchaseToken, "OrderBook: invalid _path");
            IERC20Upgradeable(_params.path[0]).safeTransfer(vault, _params.amountIn);
            _purchaseTokenAmount = _swap(_params.path, _params.minOut, address(this));
        } else {
            _purchaseTokenAmount = _params.amountIn;
        }

        {
            uint256 _purchaseTokenAmountUsd = IVault(vault).tokenToUsdMin(_purchaseToken, _purchaseTokenAmount);
            require(_purchaseTokenAmountUsd >= minPurchaseTokenAmountUsd, "OrderBook: insufficient collateral");
        }

        IncreaseOrder memory order = IncreaseOrder(
            _account,
            _params.path[_params.path.length - 1],
            _purchaseTokenAmount,
            _params.collateralToken,
            _params.indexToken,
            _params.sizeDelta,
            _params.isLong,
            _params.triggerPrice,
            _params.triggerAboveThreshold,
            _params.executionFee - tpSlExecutionFee,
            _params.tp,
            _params.sl,
            tpSlExecutionFee
        );

        uint256 _orderIndex = increaseOrdersIndex[msg.sender];
        increaseOrdersIndex[msg.sender] = _orderIndex + 1;
        increaseOrders[msg.sender][_orderIndex] = order;

        emit IncreaseOrderCreated(
            order.account,
            _orderIndex,
            order
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit CreateIncreaseOrder(
            order.account,
            _orderIndex,
            order.purchaseToken,
            order.purchaseTokenAmount,
            order.collateralToken,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee
        );
    }

    function updateIncreaseOrder(uint256 _orderIndex, uint256 _sizeDelta, uint256 _triggerPrice, bool _triggerAboveThreshold) external nonReentrant {
        _updateIncreaseOrderInternal(_orderIndex, _sizeDelta, _triggerPrice, _triggerAboveThreshold, 0, 0);
    }

    // Users should call ths function to get execution fee adjustment before calling updateIncreaseOrderV2
    // See docs in LibFeeHelper.quoteExecutionFeeAdjustment
    function quoteExecutionFeeAdjustment(address _account, uint256 _orderIndex, uint _newTp, uint _newSl) public view returns (int) {
        IncreaseOrder memory order = increaseOrders[_account][_orderIndex];
        if(order.account == address(0)) return 0;

        return LibFeeHelper.quoteExecutionFeeAdjustment(order.tp, order.sl, order.tpSlExecutionFee, _newTp, _newSl, minExecutionFee);
    }

    function updateIncreaseOrderV2(uint256 _orderIndex, uint256 _sizeDelta, uint256 _triggerPrice, bool _triggerAboveThreshold, uint _tp, uint _sl) external payable nonReentrant {
        _transferInETH();
        _updateIncreaseOrderInternal(_orderIndex, _sizeDelta, _triggerPrice, _triggerAboveThreshold, _tp, _sl);
    }

    function _updateIncreaseOrderInternal(uint256 _orderIndex, uint256 _sizeDelta, uint256 _triggerPrice, bool _triggerAboveThreshold, uint _tp, uint _sl) private {
        IncreaseOrder storage order = increaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        int netAdditionalFee = LibFeeHelper.quoteExecutionFeeAdjustment(order.tp, order.sl, order.tpSlExecutionFee, _tp, _sl, minExecutionFee);

        if (netAdditionalFee > 0) {
            require(msg.value >= uint(netAdditionalFee), "OrderBook: insufficient execution fee");
        } else if (netAdditionalFee < 0) {
            _transferOutETH(uint(-netAdditionalFee), payable(msg.sender));
        }

        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.sizeDelta = _sizeDelta;
        order.tp = _tp;
        order.sl = _sl;
        order.tpSlExecutionFee = uint(int(order.tpSlExecutionFee) + netAdditionalFee);

        emit IncreaseOrderUpdated(
            msg.sender,
            _orderIndex,
            order
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit UpdateIncreaseOrder(
            msg.sender,
            _orderIndex,
            order.collateralToken,
            order.indexToken,
            order.isLong,
            _sizeDelta,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }

    function cancelIncreaseOrder(uint256 _orderIndex) public nonReentrant {
        IncreaseOrder memory order = increaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        delete increaseOrders[msg.sender][_orderIndex];

        if (order.purchaseToken == weth) {
            _transferOutETH(order.executionFee + order.tpSlExecutionFee + order.purchaseTokenAmount, payable(msg.sender));
        } else {
            IERC20Upgradeable(order.purchaseToken).safeTransfer(msg.sender, order.purchaseTokenAmount);
            _transferOutETH(order.executionFee + order.tpSlExecutionFee, payable(msg.sender));
        }

        emit IncreaseOrderCancelled(
            msg.sender,
            _orderIndex,
            order
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit CancelIncreaseOrder(
            order.account,
            _orderIndex,
            order.purchaseToken,
            order.purchaseTokenAmount,
            order.collateralToken,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee
        );
    }

    function executeIncreaseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) override external nonReentrant {
        IncreaseOrder memory order = increaseOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(!AddressUpgradeable.isContract(order.account), "OrderBook: account cannot be a contract");

        // increase long should use max price
        // increase short should use min price
        (uint256 currentPrice, ) = validatePositionOrderPrice(
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.indexToken,
            order.isLong,
            true
        );

        delete increaseOrders[_address][_orderIndex];

        IERC20Upgradeable(order.purchaseToken).safeTransfer(vault, order.purchaseTokenAmount);

        if (order.purchaseToken != order.collateralToken) {
            address[] memory path = new address[](2);
            path[0] = order.purchaseToken;
            path[1] = order.collateralToken;

            uint256 amountOut = _swap(path, 0, address(this));
            IERC20Upgradeable(order.collateralToken).safeTransfer(vault, amountOut);
        }

        IRouter(router).pluginIncreasePosition(order.account, order.collateralToken, order.indexToken, order.sizeDelta, order.isLong);

        (uint tpExecutionFee, uint slExecutionFee) = LibFeeHelper.splitTpSlExecutionFee(order.tp, order.sl, order.tpSlExecutionFee);

        if (order.tp > 0) {
            _createDecreaseOrder(
                order.account,
                order.collateralToken,
                0, // don't need to specify collateralDelta as it's fully close position
                order.indexToken,
                order.sizeDelta,
                order.isLong,
                order.tp,
                order.isLong,
                tpExecutionFee
            );
        }

        if (order.sl > 0) {
            _createDecreaseOrder(
                order.account,
                order.collateralToken,
                0, // don't need to specify collateralDelta as it's fully close position
                order.indexToken,
                order.sizeDelta,
                order.isLong,
                order.sl,
                !order.isLong,
                slExecutionFee
            );
        }

        // pay executor
        _transferOutETH(order.executionFee, _feeReceiver);

        emit IncreaseOrderExecuted(
            order.account,
            _orderIndex,
            currentPrice,
            order
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit ExecuteIncreaseOrder(
            order.account,
            _orderIndex,
            order.purchaseToken,
            order.purchaseTokenAmount,
            order.collateralToken,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice
        );
    }

    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable nonReentrant {
        _transferInETH();

        require(msg.value >= minExecutionFee, "OrderBook: insufficient execution fee");

        _createDecreaseOrder(
            msg.sender,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value
        );
    }

    // only position router is allowed to call this function
    function createDecreaseOrderForAccount(
        address _account,
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable nonReentrant {
        require(msg.sender == positionRouter, "OrderBook: only position router is allowed");

        _transferInETH();
        _createDecreaseOrder(
            _account,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            msg.value
        );
    }

    function _createDecreaseOrder(
        address _account,
        address _collateralToken,
        uint256 _collateralDelta,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee
    ) private {
        require(!AddressUpgradeable.isContract(_account), "OrderBook: account cannot be a contract");
        uint256 _orderIndex = decreaseOrdersIndex[_account];
        DecreaseOrder memory order = DecreaseOrder(
            _account,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
        decreaseOrdersIndex[_account] = _orderIndex + 1;
        decreaseOrders[_account][_orderIndex] = order;

        emit CreateDecreaseOrder(
            _account,
            _orderIndex,
            _collateralToken,
            _collateralDelta,
            _indexToken,
            _sizeDelta,
            _isLong,
            _triggerPrice,
            _triggerAboveThreshold,
            _executionFee
        );
    }

    function executeDecreaseOrder(address _address, uint256 _orderIndex, address payable _feeReceiver) override external nonReentrant {
        DecreaseOrder memory order = decreaseOrders[_address][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");
        require(!AddressUpgradeable.isContract(order.account), "OrderBook: account cannot be a contract");

        // decrease long should use min price
        // decrease short should use max price
        (uint256 currentPrice, ) = validatePositionOrderPrice(
            order.triggerAboveThreshold,
            order.triggerPrice,
            order.indexToken,
            !order.isLong,
            true
        );

        delete decreaseOrders[_address][_orderIndex];

        uint256 amountOut = IRouter(router).pluginDecreasePosition(
            order.account,
            order.collateralToken,
            order.indexToken,
            order.collateralDelta,
            order.sizeDelta,
            order.isLong,
            address(this)
        );

        // transfer released collateral to user
        if (order.collateralToken == weth) {
            _transferOutETH(amountOut, payable(order.account));
        } else {
            IERC20Upgradeable(order.collateralToken).safeTransfer(order.account, amountOut);
        }

        // pay executor
        _transferOutETH(order.executionFee, _feeReceiver);

        emit ExecuteDecreaseOrder(
            order.account,
            _orderIndex,
            order.collateralToken,
            order.collateralDelta,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee,
            currentPrice
        );
    }

    function cancelDecreaseOrder(uint256 _orderIndex) public nonReentrant {
        DecreaseOrder memory order = decreaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        delete decreaseOrders[msg.sender][_orderIndex];
        _transferOutETH(order.executionFee, payable(msg.sender));

        emit CancelDecreaseOrder(
            order.account,
            _orderIndex,
            order.collateralToken,
            order.collateralDelta,
            order.indexToken,
            order.sizeDelta,
            order.isLong,
            order.triggerPrice,
            order.triggerAboveThreshold,
            order.executionFee
        );
    }

    function updateDecreaseOrder(
        uint256 _orderIndex,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external nonReentrant {
        DecreaseOrder storage order = decreaseOrders[msg.sender][_orderIndex];
        require(order.account != address(0), "OrderBook: non-existent order");

        order.triggerPrice = _triggerPrice;
        order.triggerAboveThreshold = _triggerAboveThreshold;
        order.sizeDelta = _sizeDelta;
        order.collateralDelta = _collateralDelta;

        emit UpdateDecreaseOrder(
            msg.sender,
            _orderIndex,
            order.collateralToken,
            _collateralDelta,
            order.indexToken,
            _sizeDelta,
            order.isLong,
            _triggerPrice,
            _triggerAboveThreshold
        );
    }

    function _transferInETH() private {
        if (msg.value != 0) {
            IWETH(weth).deposit{value: msg.value}();
        }
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) private {
        IWETH(weth).withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) private returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        if (_path.length == 3) {
            uint256 midOut = _vaultSwap(_path[0], _path[1], 0, address(this));
            IERC20Upgradeable(_path[1]).safeTransfer(vault, midOut);
            return _vaultSwap(_path[1], _path[2], _minOut, _receiver);
        }

        revert("OrderBook: invalid _path.length");
    }

    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) private returns (uint256) {
        uint256 amountOut;

        if (_tokenOut == usdg) { // buyUSDG
            amountOut = IVault(vault).buyUSDG(_tokenIn, _receiver);
        } else if (_tokenIn == usdg) { // sellUSDG
            amountOut = IVault(vault).sellUSDG(_tokenOut, _receiver);
        } else { // swap
            amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        }

        require(amountOut >= _minOut, "OrderBook: insufficient amountOut");
        return amountOut;
    }
}
