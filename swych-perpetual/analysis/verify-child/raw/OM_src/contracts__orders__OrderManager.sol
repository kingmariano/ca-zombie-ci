// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool, Side} from "../interfaces/IPool.sol";
import {SwapOrder, Order} from "../interfaces/IOrderManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPoolForOrderManager} from "../interfaces/IPoolForOrderManager.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IETHUnwrapper} from "../interfaces/IETHUnwrapper.sol";
import {IOrderHook} from "../interfaces/IOrderHook.sol";

enum UpdatePositionType {
    INCREASE,
    DECREASE
}

enum OrderType {
    MARKET,
    LIMIT
}

struct UpdatePositionRequest {
    Side side;
    uint256 sizeChange;
    uint256 collateral;
    UpdatePositionType updateType;
}

struct TpslOrderHelper {
    uint256[7] orderData;
    address payToken;
    bool isLong;
}

contract OrderManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    uint256 constant MARKET_ORDER_TIMEOUT = 5 minutes;
    uint256 constant MAX_MIN_EXECUTION_FEE = 1e17; // 0.1 ETH
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IWETH public weth;

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => UpdatePositionRequest) public requests;

    uint256 public nextSwapOrderId;
    mapping(uint256 => SwapOrder) public swapOrders;

    IPoolForOrderManager public pool;
    IPriceOracle public oracle;
    uint256 public minPerpetualExecutionFee;

    IOrderHook public orderHook;

    mapping(address => uint256[]) public userOrders;
    mapping(address => uint256[]) public userSwapOrders;

    IETHUnwrapper public ethUnwrapper;

    address public executor;
    uint256 public minSwapExecutionFee;

    bool isCancelingTpsl;
    mapping(bytes32 => uint256[]) public tpslOrders;

    modifier onlyExecutor() {
        _validateExecutor(msg.sender);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        // prevent send ETH directly to contract
        require(msg.sender == address(weth), "OrderManager:rejected");
    }

    /**
     * 
     * @param _weth The address of WETH.
     * @param _oracle  The address of the oracle contract.
     * @param _minExecutionFee The minimum execution fee.
     * @param _ethUnwrapper The address of the ETH unwrapper contract.
     */
    function initialize(address _weth, address _oracle, uint256 _minExecutionFee, uint256 _minSwapExecutionFee, address _ethUnwrapper)
        external
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_oracle != address(0), "OrderManager:invalidOracle");
        require(_weth != address(0), "OrderManager:invalidWeth");
        require(_minExecutionFee <= MAX_MIN_EXECUTION_FEE, "OrderManager:minExecutionFeeTooHigh");
        require(_ethUnwrapper != address(0), "OrderManager:invalidEthUnwrapper");
        minPerpetualExecutionFee = _minExecutionFee;
        minSwapExecutionFee = _minSwapExecutionFee;
        oracle = IPriceOracle(_oracle);
        nextOrderId = 1;
        nextSwapOrderId = 1;
        weth = IWETH(_weth);
        ethUnwrapper = IETHUnwrapper(_ethUnwrapper);
    }

    // ============= VIEW FUNCTIONS ==============
    function version() external pure returns (string memory) {
        return "1.0.1";
    }

    /**
     * @notice Get the orders of a user.
     * @param user The address of the user.
     * @param skip The number of orders to skip.
     * @param take The number of orders to return.
     * @return orderIds The order ids.
     */
    function getOrders(address user, uint256 skip, uint256 take)
        external
        view
        returns (uint256[] memory orderIds, uint256 total)
    {
        total = userOrders[user].length;
        uint256 toIdx = skip + take;
        toIdx = toIdx > total ? total : toIdx;
        uint256 nOrders = toIdx > skip ? toIdx - skip : 0;
        orderIds = new uint[](nOrders);
        for (uint256 i = skip; i < skip + nOrders; i++) {
            orderIds[i - skip] = userOrders[user][i];
        }
    }

    // =========== MUTATIVE FUNCTIONS ==========
    /**
     * @notice Place an order to increase or decrease position.
     * @dev the msg.value needs to be larger than minExecutionFee. If the payToken is ETH, the msg.value needs
     * to be larger than payAmount + minExecutionFee.
     * @dev emits OrderPlaced event.
     * @param _updateType increase or decrease.
     * @param _side long or short.
     * @param _indexToken index token address.
     * @param _collateralToken collateral token address.
     * @param _orderType market or limit.
     * @param data order data/
     * @dev data is encoded as follows:
     * - order.price: uint256
     * - payToken: address
     * - payAmount: uint256
     * - request.sizeChange: uint256
     * - request.collateral: uint256
     * - extradata: bytes
     * @dev extradata is encoded as follows:
     * - referral: address
    */

    function placeOrder(
        UpdatePositionType _updateType,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes calldata data
    ) external payable nonReentrant {
        bool isIncrease = _updateType == UpdatePositionType.INCREASE;
        require(pool.validateToken(_indexToken, _collateralToken, _side, isIncrease), "OrderManager:invalidTokens");
        uint256 orderId;
        if (isIncrease) {
            (, address payToken, uint256 payAmount, , , ) = abi.decode(data, (uint256, address, uint256, uint256, uint256, bytes));
            require(pool.isListed(payToken) || payToken == ETH, "OrderManager:invalidPayToken");
            uint256 fee = payToken == ETH ? msg.value - payAmount : msg.value;
            orderId = _createIncreasePositionOrder(_side, _indexToken, _collateralToken, _orderType, data, fee);
        } else {
            orderId = _createDecreasePositionOrder(_side, _indexToken, _collateralToken, _orderType, data, msg.value);
        }
        userOrders[msg.sender].push(orderId);
    }

    function placeTpslOrder(
        UpdatePositionType _updateType,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes calldata data,
        bytes calldata tpslData
    ) external payable nonReentrant {
        require(_updateType == UpdatePositionType.INCREASE, "OrderManager:onlyIncrease");
        require(
            pool.validateToken(_indexToken, _collateralToken, _side, true)
             && pool.validateToken(_indexToken, _collateralToken, _side, false), 
             "OrderManager:invalidTokens"
        );
        // Order data.
        // [0]: payAmount
        // [1]: sizeChange
        // [2]: collateral
        // [3]: tpPrice
        // [4]: slPrice
        // [5]: fee
        // [6]: orderId
        TpslOrderHelper memory helper;
        helper.isLong = _side == Side.LONG;
        (, helper.payToken, helper.orderData[0], helper.orderData[1], helper.orderData[2], ) =
            abi.decode(data, (uint256, address, uint256, uint256, uint256, bytes));
        (helper.orderData[3], helper.orderData[4]) = abi.decode(tpslData, (uint256, uint256));
        helper.orderData[5] = helper.payToken == ETH ? msg.value - helper.orderData[0] : msg.value;
        if (helper.orderData[3] > 0 && helper.orderData[4] > 0) {
            helper.orderData[5] /= 3;
        } else if (helper.orderData[3] + helper.orderData[4] > 0) {
            helper.orderData[5] /= 2;
        }
        helper.orderData[6] = _createIncreasePositionOrder(_side, _indexToken, _collateralToken, _orderType, data, helper.orderData[5]);
        userOrders[msg.sender].push(helper.orderData[6]);
        // Check if Take-Profit or Stop-Loss are set.
        if (helper.orderData[3] > 0) {
            // The order has take-profit set.
            // Create a decrease position limit order that will trigger when the price reaches the take-profit price.
            helper.orderData[6] = _createDecreasePositionOrder(
                _side, 
                _indexToken, 
                _collateralToken, 
                OrderType.LIMIT,
                abi.encode(
                    // price (take-profit price that will trigger the decrease position order)
                    helper.orderData[3],
                    // triggerAboveThreshold (for take-profit when longing trigger when price is above the take-profit price; 
                    // for shorting trigger when price is below the take-profit price)
                    helper.isLong, 
                    // payToken
                    _collateralToken, 
                    // sizeChange (the same as the size of the increase position order)
                    helper.orderData[1], 
                    // collateralChange (the same as the collateral of the increase position order)
                    helper.orderData[2],
                    // extra data
                    "0x"
                ),
                helper.orderData[5]
            );
            {
                userOrders[msg.sender].push(helper.orderData[6]);
                tpslOrders[pool.getPositionKey(msg.sender, _indexToken, _collateralToken, _side)].push(helper.orderData[6]);
            }
        }

        if (helper.orderData[4] > 0) {
            // The order has stop-loss set.
            // Create a decrease position limit order that will trigger when the price reaches the stop-loss price.
            helper.orderData[6] = _createDecreasePositionOrder(
                _side, 
                _indexToken, 
                _collateralToken, 
                OrderType.LIMIT,
                abi.encode(
                    // price (stop-loss price that will trigger the decrease position order)
                    helper.orderData[4],
                    // triggerAboveThreshold (for take-profit when longing trigger when price is below the stop-loss price;
                    // for shorting trigger when price is above the stop-loss price)
                    !helper.isLong,
                    // payToken
                    _collateralToken, 
                    // sizeChange (the same as the size of the increase position order)
                    helper.orderData[1], 
                    // collateralChange (the same as the collateral of the increase position order)
                    helper.orderData[2],
                    // extra data
                    "0x"
                ),
                helper.orderData[5]
            );
            {
                userOrders[msg.sender].push(helper.orderData[6]);
                tpslOrders[pool.getPositionKey(msg.sender, _indexToken, _collateralToken, _side)].push(helper.orderData[6]);
            }
        }
    }

    /**
     * @notice Executes an order.
     * @param _orderId order id
     * @param _feeTo fee receiver
     * @dev requires the msg.sender to be the executor.
     * @dev if expiration is due, the order will be expired and the collateral will be returned.
     * @dev emits an OrderExecuted event.
     */

    function executeOrder(uint256 _orderId, address payable _feeTo) external nonReentrant onlyExecutor {
        Order memory order = orders[_orderId];
        require(order.owner != address(0), "OrderManager:orderNotExists");
        require(order.pool == pool, "OrderManager:invalidOrPausedPool");
        require(block.number > order.submissionBlock, "OrderManager:blockNotPass");

        if (order.expiresAt != 0 && order.expiresAt < block.timestamp) {
            _expiresOrder(_orderId, order);
            return;
        }
        UpdatePositionRequest memory request = requests[_orderId];
        uint256 indexPrice = _getMarkPrice(order, request);
        bool isValid = order.triggerAboveThreshold ? indexPrice >= order.price : indexPrice <= order.price;
        if (!isValid) {
            return;
        }

        _executeRequest(order, request, _orderId);
        _removeUserOrder(order.owner, _orderId);
        delete orders[_orderId];
        delete requests[_orderId];
        _safeTransferETH(_feeTo, order.executionFee);
        emit OrderExecuted(_orderId, order, request, indexPrice);
    }

    /**
     * @notice Cancels an order.
     * @param _orderId order id
     * @dev requires the msg.sender to be the owner of the order.
     * @dev the execution fee will be returned.
     * @dev if the order is an increase position order, the collateral will be returned.
     * @dev emits an OrderCancelled event
     */
    function cancelOrder(uint256 _orderId) public nonReentrant {
        _cancelOrder(_orderId);
    }

    function cancelTpslOrders(bytes32 positionKey) external {
        require(msg.sender == address(pool), "OrderManager:unauthorizedCancellation");
        uint256 length = tpslOrders[positionKey].length;

        if (length == 0) {
            return;
        }

        isCancelingTpsl = true;
        for (uint256 i = 0; i < length; i++) {
            if (orders[tpslOrders[positionKey][i]].owner != address(0)) {
                _cancelOrder(tpslOrders[positionKey][i]);
            }
        }
        isCancelingTpsl = false;
        delete tpslOrders[positionKey];
    }

    // ========= INTERNAL FUNCTIONS ==========

    function _getMarkPrice(Order memory order, UpdatePositionRequest memory request) internal view returns (uint256) {
        bool max = (request.updateType == UpdatePositionType.INCREASE) == (request.side == Side.LONG);
        return oracle.getPrice(order.indexToken, max);
    }

    function _executeRequest(Order memory _order, UpdatePositionRequest memory _request, uint256 _orderId) internal {
        if (_request.updateType == UpdatePositionType.INCREASE) {
            bool noSwap = (_order.payToken == ETH && _order.collateralToken == address(weth))
                || (_order.payToken == _order.collateralToken);

            if (!noSwap) {
                address fromToken = _order.payToken == ETH ? address(weth) : _order.payToken;
                _request.collateral =
                    _poolSwap(fromToken, _order.collateralToken, _request.collateral, 0, address(this), _order.owner);
            }

            IERC20(_order.collateralToken).safeTransfer(address(_order.pool), _request.collateral);
            _order.pool.increasePosition(
                _order.owner, _order.indexToken, _order.collateralToken, _request.sizeChange, _request.side
            );
        } else {
            IERC20 collateralToken = IERC20(_order.collateralToken);
            uint256 priorBalance = collateralToken.balanceOf(address(this));
            _order.pool.decreasePosition(
                _order.owner,
                _order.indexToken,
                _order.collateralToken,
                _request.collateral,
                _request.sizeChange,
                _request.side,
                address(this)
            );
            uint256 payoutAmount = collateralToken.balanceOf(address(this)) - priorBalance;
            if (_order.collateralToken == address(weth) && _order.payToken == ETH) {
                _safeUnwrapETH(payoutAmount, _order.owner);
            } else if (_order.collateralToken != _order.payToken) {
                IERC20(_order.collateralToken).safeTransfer(address(_order.pool), payoutAmount);
                _order.pool.swap(_order.collateralToken, _order.payToken, 0, _order.owner, abi.encode(_order.owner));
            } else {
                collateralToken.safeTransfer(_order.owner, payoutAmount);
            }
            // Check if position is zero, if so, remove from tpslOrders.
            bytes32 positionKey = _order.pool.getPositionKey(_order.owner, _order.indexToken, _order.collateralToken, _request.side);
            if (_order.pool.positions(positionKey).size == 0) {
                uint256[] memory tpslOrderIds = tpslOrders[positionKey];
                isCancelingTpsl = true;
                for (uint256 i = 0; i < tpslOrderIds.length; i++) {
                    if (tpslOrderIds[i] != _orderId && orders[tpslOrderIds[i]].owner == _order.owner) {
                        _cancelOrder(tpslOrderIds[i]);
                    }
                }
                isCancelingTpsl = false;
                delete tpslOrders[positionKey];
            }
        }
    }

    function _cancelOrder(uint256 _orderId) internal {
        Order memory order = orders[_orderId];
        require(order.owner == msg.sender || isCancelingTpsl, "OrderManager:unauthorizedCancellation");
        UpdatePositionRequest memory request = requests[_orderId];

        _removeUserOrder(order.owner, _orderId);
        delete orders[_orderId];
        delete requests[_orderId];

        _safeTransferETH(order.owner, order.executionFee);
        if (request.updateType == UpdatePositionType.INCREASE) {
            _refundCollateral(order.payToken, request.collateral, order.owner);
        }

        emit OrderCancelled(_orderId);
    }

    function _createDecreasePositionOrder(
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes memory _data,
        uint256 _executionFee
    ) internal returns (uint256 orderId) {
        Order memory order;
        UpdatePositionRequest memory request;
        bytes memory extradata;

        if (_orderType == OrderType.MARKET) {
            (order.price, order.payToken, request.sizeChange, request.collateral, extradata) =
                abi.decode(_data, (uint256, address, uint256, uint256, bytes));
            order.triggerAboveThreshold = _side == Side.LONG;
        } else {
            (
                order.price,
                order.triggerAboveThreshold,
                order.payToken,
                request.sizeChange,
                request.collateral,
                extradata
            ) = abi.decode(_data, (uint256, bool, address, uint256, uint256, bytes));
        }

        order.pool = pool;
        order.owner = msg.sender;
        order.indexToken = _indexToken;
        order.collateralToken = _collateralToken;
        order.expiresAt = _orderType == OrderType.MARKET ? block.timestamp + MARKET_ORDER_TIMEOUT : 0;
        order.submissionBlock = block.number;
        order.executionFee = _executionFee;
        uint256 minExecutionFee = _calcMinPerpetualExecutionFee(order.collateralToken, order.payToken);
        require(order.executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");
        request.updateType = UpdatePositionType.DECREASE;
        request.side = _side;
        orderId = nextOrderId;
        nextOrderId = orderId + 1;
        orders[orderId] = order;
        requests[orderId] = request;

        if (address(orderHook) != address(0)) {
            orderHook.postPlaceOrder(orderId, extradata);
        }

        emit OrderPlaced(orderId, order, request);
    }

    function _createIncreasePositionOrder(
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes memory _data,
        uint256 _executionFee
    ) internal returns (uint256 orderId) {
        Order memory order;
        UpdatePositionRequest memory request;
        order.triggerAboveThreshold = _side == Side.SHORT;
        uint256 payAmount;
        bytes memory extradata;
        (order.price, order.payToken, payAmount, request.sizeChange, request.collateral, extradata) =
            abi.decode(_data, (uint256, address, uint256, uint256, uint256, bytes));

        require(payAmount != 0, "OrderManager:invalidPayAmount");
        require(order.payToken != address(0), "OrderManager:invalidPayToken");

        order.pool = pool;
        order.owner = msg.sender;
        order.indexToken = _indexToken;
        order.collateralToken = _collateralToken;
        order.expiresAt = _orderType == OrderType.MARKET ? block.timestamp + MARKET_ORDER_TIMEOUT : 0;
        order.submissionBlock = block.number;
        order.executionFee = _executionFee;

        uint256 minExecutionFee = _calcMinPerpetualExecutionFee(order.collateralToken, order.payToken);
        require(order.executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");
        request.updateType = UpdatePositionType.INCREASE;
        request.side = _side;
        request.collateral = payAmount;
        orderId = nextOrderId;
        nextOrderId = orderId + 1;
        orders[orderId] = order;
        requests[orderId] = request;

        if (order.payToken == ETH) {
            weth.deposit{value: payAmount}();
        } else {
            IERC20(order.payToken).safeTransferFrom(msg.sender, address(this), request.collateral);
        }

        if (address(orderHook) != address(0)) {
            orderHook.postPlaceOrder(orderId, extradata);
        }

        emit OrderPlaced(orderId, order, request);
    }

    function _poolSwap(
        address _fromToken,
        address _toToken,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address _beneficier
    ) internal returns (uint256 amountOut) {
        IERC20(_fromToken).safeTransfer(address(pool), _amountIn);
        return _doSwap(_fromToken, _toToken, _minAmountOut, _receiver, _beneficier);
    }

    function _doSwap(
        address _fromToken,
        address _toToken,
        uint256 _minAmountOut,
        address _receiver,
        address _beneficier
    ) internal returns (uint256 amountOut) {
        IERC20 tokenOut = IERC20(_toToken);
        uint256 priorBalance = tokenOut.balanceOf(_receiver);
        pool.swap(_fromToken, _toToken, _minAmountOut, _receiver, abi.encode(_beneficier));
        amountOut = tokenOut.balanceOf(_receiver) - priorBalance;
    }

    function _expiresOrder(uint256 _orderId, Order memory _order) internal {
        UpdatePositionRequest memory request = requests[_orderId];
        _removeUserOrder(_order.owner, _orderId);
        delete orders[_orderId];
        delete requests[_orderId];
        emit OrderExpired(_orderId);

        _safeTransferETH(_order.owner, _order.executionFee);
        if (request.updateType == UpdatePositionType.INCREASE) {
            _refundCollateral(_order.payToken, request.collateral, _order.owner);        
        }
    }

    function _removeUserOrder(address _user, uint256 _orderId) internal {
        uint256[] storage userOrderIds = userOrders[_user];
        uint256 nOrders = userOrderIds.length;
        for (uint256 i = 0; i < nOrders; i++) {
            if (userOrderIds[i] == _orderId) {
                userOrderIds[i] = userOrderIds[nOrders - 1];
                userOrderIds.pop();
                break;
            }
        }
    }

    function _refundCollateral(address _refundToken, uint256 _amount, address _orderOwner) internal {
        if (_refundToken == address(weth) || _refundToken == ETH) {
            _safeUnwrapETH(_amount, _orderOwner);
        } else {
            IERC20(_refundToken).safeTransfer(_orderOwner, _amount);
        }
    }

    function _safeTransferETH(address _to, uint256 _amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = _to.call{value: _amount}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }

    function _safeUnwrapETH(uint256 _amount, address _to) internal {
        weth.safeIncreaseAllowance(address(ethUnwrapper), _amount);
        ethUnwrapper.unwrap(_amount, _to);
    }

    function _validateExecutor(address _sender) internal view {
        require(_sender == executor, "OrderManager:onlyExecutor");
    }

    function _calcMinPerpetualExecutionFee(address _collateralToken, address _payToken)
        internal
        view
        returns (uint256)
    {
        bool noSwap = _collateralToken == _payToken || (_collateralToken == address(weth) && _payToken == ETH);
        return noSwap ? minPerpetualExecutionFee : minPerpetualExecutionFee + minSwapExecutionFee;
    }

    function _setMinExecutionFee(uint256 _perpExecutionFee, uint256 _swapExecutionFee) internal {
        require(_perpExecutionFee != 0, "OrderManager:invalidFeeValue");
        require(_perpExecutionFee <= MAX_MIN_EXECUTION_FEE, "OrderManager:minExecutionFeeTooHigh");
        require(_swapExecutionFee != 0, "OrderManager:invalidFeeValue");
        require(_swapExecutionFee <= MAX_MIN_EXECUTION_FEE, "OrderManager:minExecutionFeeTooHigh");
        minPerpetualExecutionFee = _perpExecutionFee;
        minSwapExecutionFee = _swapExecutionFee;
    }

    // ============ Administrative =============

    /** 
     * @notice Sets the address of the oracle contract.
     * @param _oracle The address of the oracle contract.
     * @dev Only the owner can call this function.
     * @dev The oracle contract must implement the IPriceOracle interface.
     * @dev Emits an OracleChanged event.
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "OrderManager:invalidOracleAddress");
        oracle = IPriceOracle(_oracle);
        emit OracleChanged(_oracle);
    }

    /** 
     * @notice Sets the address of the pool contract.
     * @param _pool The address of the pool contract.
     * @dev Only the owner can call this function.
     * @dev The pool contract must implement the IWhitelistedPool interface.
     * @dev Emits an PoolSet event.
     */
    function setPool(address _pool) external onlyOwner {
        require(_pool != address(0), "OrderManager:invalidPoolAddress");
        require(address(pool) != _pool, "OrderManager:poolAlreadyAdded");
        pool = IPoolForOrderManager(_pool);
        emit PoolSet(_pool);
    }

    /**
     * @notice Sets the minimum execution fees.
     * @param _perpExecutionFee The minimum execution fee for perpetual orders.
     * @param _swapExecutionFee The minimum execution fee for swap orders.
     * @dev Only the owner can call this function.
     * @dev Emits a MinExecutionFeeSet event.
     * @dev Emits a MinSwapExecutionFeeSet event.
     */
    function setMinExecutionFee(uint256 _perpExecutionFee, uint256 _swapExecutionFee) external onlyOwner {
        _setMinExecutionFee(_perpExecutionFee, _swapExecutionFee);
        emit MinExecutionFeeSet(_perpExecutionFee);
        emit MinSwapExecutionFeeSet(_swapExecutionFee);
    }

    /**
     * @notice Sets the address of the order hook contract.
     * @param _hook The address of the order hook contract.
     * @dev Only the owner can call this function.
     * @dev The order hook contract must implement the IOrderHook interface.
     * @dev Emits an OrderHookSet event.
     */
    function setOrderHook(address _hook) external onlyOwner {
        orderHook = IOrderHook(_hook);
        emit OrderHookSet(_hook);
    }

    /**
     * @notice Sets the address of the executor contract.
     * @param _executor The address of the executor contract.
     * @dev Only the owner can call this function.
     * @dev Emits an ExecutorSet event.
     */
    function setExecutor(address _executor) external onlyOwner {
        require(_executor != address(0), "OrderManager:invalidAddress");
        executor = _executor;
        emit ExecutorSet(_executor);
    }

    // ========== EVENTS =========

    event OrderPlaced(uint256 indexed key, Order order, UpdatePositionRequest request);
    event OrderCancelled(uint256 indexed key);
    event OrderExecuted(uint256 indexed key, Order order, UpdatePositionRequest request, uint256 fillPrice);
    event OrderExpired(uint256 indexed key);
    event OracleChanged(address);
    event PoolSet(address indexed pool);
    event MinExecutionFeeSet(uint256 fee);
    event MinSwapExecutionFeeSet(uint256 swapExecutionFee);
    event OrderHookSet(address indexed hook);
    event ExecutorSet(address indexed executor);
}
