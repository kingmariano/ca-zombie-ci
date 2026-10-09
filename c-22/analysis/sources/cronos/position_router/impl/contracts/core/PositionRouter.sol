// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPositionRouter.sol";
import "./interfaces/ICircuitBreaker.sol";
import "./interfaces/IOrderBook.sol";
import "./libraries/LibFeeHelper.sol";
import "../access/Governable.sol";
import "../peripherals/interfaces/ITimelock.sol";
import "../tokens/interfaces/IWETH.sol";


contract PositionRouter is IPositionRouter, ReentrancyGuardUpgradeable, Governable {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct IncreasePositionRequest {
        address account;
        address[] path;
        address indexToken;
        uint256 amountIn;
        uint256 minOut;
        uint256 sizeDelta;
        bool isLong;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 blockNumber;
        uint256 blockTime;
        bool hasCollateralInETH;
        address callbackTarget;
        uint256 tp;
        uint256 sl;
        address brokerAddress;
        uint256 brokerFeeBasisPoints;
        uint256 tpSlExecutionFee;
    }

    // Reduced subset of `IncreasePositionRequest` to be passed by the user as arguments
    struct IncreasePositionParams {
        address[] path;
        address indexToken;
        uint256 sizeDelta;
        bool isLong;
        uint256 acceptablePrice;
        uint256 minOut;
        uint256 executionFee;
        bytes32 referralCode;
        address callbackTarget;
        bytes[] priceData;
    }

    struct IncreasePositionParamsV2 {
        uint256 amountIn;
        uint256 minOut;
        uint256 sizeDelta;
        uint256 acceptablePrice;
        uint256 executionFee;
        bytes32 referralCode;
        uint256 tp;
        uint256 sl;
        uint256 brokerFeeBasisPoints;
        address indexToken;
        address brokerAddress;
        bool isLong;
        bool hasCollateralInETH;
        address[] path;
        bytes[] priceData;
    }

    struct DecreasePositionRequest {
        address account;
        address[] path;
        address indexToken;
        uint256 collateralDelta;
        uint256 sizeDelta;
        bool isLong;
        address receiver;
        uint256 acceptablePrice;
        uint256 minOut;
        uint256 executionFee;
        uint256 blockNumber;
        uint256 blockTime;
        bool withdrawETH;
        address callbackTarget; // deprecated
    }

    struct DecreasePositionParams {
        address[] path;
        address indexToken;
        uint256 collateralDelta;
        uint256 sizeDelta;
        bool isLong;
        address receiver;
        uint256 acceptablePrice;
        uint256 minOut;
        uint256 executionFee;
        bool withdrawETH;
        address callbackTarget;
        bytes[] priceData;
    }

    uint256 private constant BASIS_POINTS_DIVISOR = 10000;

    address public admin;    // admin can only call setMaxGlobalSizes()
    address public feeAdmin; // feeAdmin is the FeeDistributor contract that will withdraw fees

    address public vault;
    address private shortsTracker; // deprecated
    address public router;
    address public weth;

    // to prevent using the deposit and withdrawal of collateral as a zero fee swap,
    // there is a small depositFee charged if a collateral deposit results in the decrease
    // of leverage for an existing position
    // increasePositionBufferBps allows for a small amount of decrease of leverage
    uint256 public depositFee;
    uint256 public increasePositionBufferBps;

    address public referralStorage;

    mapping (address => uint256) public feeReserves;

    mapping (address => uint256) public override maxGlobalLongSizes;
    mapping (address => uint256) public override maxGlobalShortSizes;

    uint256 public minExecutionFee;

    uint256 public minBlockDelayKeeper;
    uint256 public minTimeDelayPublic;
    uint256 public maxTimeDelay;

    bool public isLeverageEnabled;

    bytes32[] public increasePositionRequestKeys;
    bytes32[] public decreasePositionRequestKeys;

    uint256 public override increasePositionRequestKeysStart;
    uint256 public override decreasePositionRequestKeysStart;

    uint256 private callbackGasLimit; // deprecated

    mapping(address => bool) public isPositionKeeper;

    mapping(address => uint256) public increasePositionsIndex;
    mapping(bytes32 => IncreasePositionRequest) private increasePositionRequests;

    mapping(address => uint256) public decreasePositionsIndex;
    mapping(bytes32 => DecreasePositionRequest) private decreasePositionRequests;

    IPyth public pythOracle;

    ICircuitBreaker public circuitBreaker;

    uint256 public ethTransferGasLimit;

    IOrderBook public orderBook;

    event IncreasePositionRequestCreated(
        address indexed account,
        uint256 index,
        uint256 queueIndex,
        IncreasePositionRequest request
    );

    event CreateIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex
    );

    event IncreasePositionRequestExecuted(
        address indexed account,
        uint256 blockGap,
        uint256 timeGap,
        uint256 executionPrice,
        IncreasePositionRequest request
    );

    event ExecuteIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 executionPrice,
        uint256 blockGap,
        uint256 timeGap
    );

    event IncreasePositionRequestCancelled(
        address indexed account,
        uint256 blockGap,
        uint256 timeGap,
        IncreasePositionRequest request
    );

    event CancelIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event CreateDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex
    );

    event ExecuteDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 executionPrice,
        uint256 amountOut,
        uint256 blockGap,
        uint256 timeGap
    );

    event CancelDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event SetPositionKeeper(address indexed account, bool isActive);

    event SetAdmin(address admin);
    event SetFeeAdmin(address feeAdmin);
    event WithdrawFees(address token, address receiver, uint256 amount);
    event SetMaxGlobalSizes(address[] tokens, uint256[] longSizes, uint256[] shortSizes);

    event SetConfigParams(
        uint256 minBlockDelayKeeper,
        uint256 minTimeDelayPublic,
        uint256 maxTimeDelay,
        uint256 ethTransferGasLimit,
        uint256 depositFee,
        uint256 increasePositionBufferBps,
        bool isLeverageEnabled
    );

    /*
    * @dev Error codes
    * 0: Forbidden
    * 1: Execution fee too low
    * 2: msg.value too low
    * 3: Invalid path length
    * 4: Last token in path must be WETH
    * 5: maxTimeDelay exceeded
    * 6: minTimeDelayPublic not exceeded
    * 7: First token in path must be WETH
    * 8: Zero address are not allowed
    * 9: max global longs exceeded
    * 10: max global shorts exceeded
    * 11: mark price lower than limit
    * 12: mark price higher than limit
    * 13: insufficient amountOut
    * 14: tx must be from position keeper if isLeverageEnabled is false
    * 15: msg.sender must be the position request owner
    */
    error PositionRouterError(uint code);

    function initialize() public initializer {
        __ReentrancyGuard_init();
        gov = msg.sender;
        admin = msg.sender;
    }

    receive() external payable {
        if (msg.sender != weth) revert PositionRouterError(0);
    }

    function setAdmin(address _admin) external {
        _onlyGov();
        admin = _admin;
        emit SetAdmin(_admin);
    }

    function setFeeAdmin(address _feeAdmin) external {
        _onlyGov();
        feeAdmin = _feeAdmin;
        emit SetFeeAdmin(_feeAdmin);
    }

    function setMaxGlobalSizes(
        address[] memory _tokens,
        uint256[] memory _longSizes,
        uint256[] memory _shortSizes
    ) external {
        _onlyAdminOrGov();
        for (uint256 i = 0; i < _tokens.length; ) {
            address token = _tokens[i];
            maxGlobalLongSizes[token] = _longSizes[i];
            maxGlobalShortSizes[token] = _shortSizes[i];
            unchecked {
                i++;
            }
        }

        emit SetMaxGlobalSizes(_tokens, _longSizes, _shortSizes);
    }

    function setDependentContracts(
        IOrderBook _orderBook,
        IPyth _pythOracle,
        ICircuitBreaker _circuitBreaker,
        address _referralManager,
        address _valut,
        address _router,
        address _weth
    ) external {
        _onlyGov();
        orderBook = _orderBook;
        pythOracle = _pythOracle;
        circuitBreaker = _circuitBreaker;
        referralStorage = _referralManager;
        vault = _valut;
        router = _router;
        weth = _weth;
    }

    function setMinExecutionFee(uint256 _minExecutionFee) external {
        _onlyGov();
        minExecutionFee = _minExecutionFee;
    }

    function setConfigParams(
        uint256 _minBlockDelayKeeper,
        uint256 _minTimeDelayPublic,
        uint256 _maxTimeDelay,
        uint256 _depositFee,
        uint256 _increasePositionBufferBps,
        uint256 _ethTransferGasLimit,
        bool _isLeverageEnabled
    ) external {
        _onlyGov();
        minBlockDelayKeeper = _minBlockDelayKeeper;
        minTimeDelayPublic = _minTimeDelayPublic;
        maxTimeDelay = _maxTimeDelay;
        depositFee = _depositFee;
        increasePositionBufferBps = _increasePositionBufferBps;
        ethTransferGasLimit = _ethTransferGasLimit;
        isLeverageEnabled = _isLeverageEnabled;

        emit SetConfigParams(
            _minBlockDelayKeeper,
            _minTimeDelayPublic,
            _maxTimeDelay,
            _depositFee,
            _increasePositionBufferBps,
            _ethTransferGasLimit,
            _isLeverageEnabled
        );
    }

    function setPositionKeeper(address _account, bool _isActive) external {
        _onlyGov();
        isPositionKeeper[_account] = _isActive;
        emit SetPositionKeeper(_account, _isActive);
    }

    function getIncreasePositionRequest(bytes32 _key) external view returns (IncreasePositionRequest memory) {
        return increasePositionRequests[_key];
    }

    function getDecreasePositionRequest(bytes32 _key) external view returns (DecreasePositionRequest memory) {
        return decreasePositionRequests[_key];
    }

    function withdrawFees(address _token, address _receiver) external {
        _onlyFeeAdminOrGov();

        uint256 amount = feeReserves[_token];
        if (amount == 0) { return; }

        feeReserves[_token] = 0;
        IERC20Upgradeable(_token).safeTransfer(_receiver, amount);

        emit WithdrawFees(_token, _receiver, amount);
    }

    function executeIncreasePositions(uint256 _endIndex, address payable _executionFeeReceiver) external override {
        _onlyPositionKeeper();
        uint256 index = increasePositionRequestKeysStart;
        uint256 length = increasePositionRequestKeys.length;

        if (index >= length) {return;}

        if (_endIndex > length) {
            _endIndex = length;
        }

        while (index < _endIndex) {
            bytes32 key = increasePositionRequestKeys[index];

            // if the request was executed then delete the key from the array
            // if the request was not executed then break from the loop, this can happen if the
            // minimum number of blocks has not yet passed
            // an error could be thrown if the request is too old or if the slippage is
            // higher than what the user specified, or if there is insufficient liquidity for the position
            // in case an error was thrown, cancel the request
            try this.executeIncreasePosition(key, _executionFeeReceiver) returns (bool _wasExecuted) {
                if (!_wasExecuted) {break;}
            } catch {
                // wrap this call in a try catch to prevent invalid cancels from blocking the loop
                try this.cancelIncreasePosition(key, _executionFeeReceiver) returns (bool _wasCancelled) {
                    if (!_wasCancelled) {break;}
                } catch {}
            }

            delete increasePositionRequestKeys[index];
            unchecked {
                index++;
            }
        }

        increasePositionRequestKeysStart = index;
    }

    function executeDecreasePositions(uint256 _endIndex, address payable _executionFeeReceiver) external override {
        _onlyPositionKeeper();
        uint256 index = decreasePositionRequestKeysStart;
        uint256 length = decreasePositionRequestKeys.length;

        if (index >= length) {return;}

        if (_endIndex > length) {
            _endIndex = length;
        }

        while (index < _endIndex) {
            bytes32 key = decreasePositionRequestKeys[index];

            // if the request was executed then delete the key from the array
            // if the request was not executed then break from the loop, this can happen if the
            // minimum number of blocks has not yet passed
            // an error could be thrown if the request is too old
            // in case an error was thrown, cancel the request
            try this.executeDecreasePosition(key, _executionFeeReceiver) returns (bool _wasExecuted) {
                if (!_wasExecuted) {break;}
            } catch {
                // wrap this call in a try catch to prevent invalid cancels from blocking the loop
                try this.cancelDecreasePosition(key, _executionFeeReceiver) returns (bool _wasCancelled) {
                    if (!_wasCancelled) {break;}
                } catch {}
            }

            delete decreasePositionRequestKeys[index];
            unchecked {
                index++;
            }
        }

        decreasePositionRequestKeysStart = index;
    }

    function createIncreasePositionV2(IncreasePositionParamsV2 calldata _params) external payable nonReentrant returns (bytes32) {
        return _createIncreasePositionInternal(msg.sender, _params);
    }

    function createIncreasePosition(IncreasePositionParams calldata _params, uint256 _amountIn) external payable nonReentrant returns (bytes32) {
        IncreasePositionParamsV2 memory paramsV2 = IncreasePositionParamsV2({
            path: _params.path,
            indexToken: _params.indexToken,
            sizeDelta: _params.sizeDelta,
            isLong: _params.isLong,
            acceptablePrice: _params.acceptablePrice,
            minOut: _params.minOut,
            executionFee: _params.executionFee,
            referralCode: _params.referralCode,
            priceData: _params.priceData,
            amountIn: _amountIn,
            hasCollateralInETH: false,
            tp: 0,
            sl: 0,
            brokerAddress: address(0),
            brokerFeeBasisPoints: 0
        });

        return _createIncreasePositionInternal(msg.sender, paramsV2);
    }

    function createIncreasePositionETH(IncreasePositionParams calldata _params) external payable nonReentrant returns (bytes32) {
        IncreasePositionParamsV2 memory paramsV2 = IncreasePositionParamsV2({
            path: _params.path,
            indexToken: _params.indexToken,
            sizeDelta: _params.sizeDelta,
            isLong: _params.isLong,
            acceptablePrice: _params.acceptablePrice,
            minOut: _params.minOut,
            executionFee: _params.executionFee,
            referralCode: _params.referralCode,
            priceData: _params.priceData,
            amountIn: 0,
            hasCollateralInETH: true,
            tp: 0,
            sl: 0,
            brokerAddress: address(0),
            brokerFeeBasisPoints: 0
        });
        return _createIncreasePositionInternal(msg.sender, paramsV2);
    }

    function createDecreasePosition(
        DecreasePositionParams calldata _params
    ) external payable nonReentrant returns (bytes32) {
        if (_params.executionFee < minExecutionFee) {
            revert PositionRouterError(1);
        }

        uint256 updateFee = _updatePythOracle(_params.priceData);
        if (msg.value < _params.executionFee + updateFee) {
            revert PositionRouterError(2);
        }

        if (_params.path.length != 1 && _params.path.length != 2) {
            revert PositionRouterError(3);
        }

        if (_params.withdrawETH) {
            if (_params.path[_params.path.length - 1] != weth) {
                revert PositionRouterError(4);
            }
        }

        _transferInETH(msg.value - updateFee);

        return _createDecreasePosition(
            msg.sender,
            _params
        );
    }

    function getRequestQueueLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (
            increasePositionRequestKeysStart,
            increasePositionRequestKeys.length,
            decreasePositionRequestKeysStart,
            decreasePositionRequestKeys.length
        );
    }

    function executeIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) external nonReentrant returns (bool) {
        IncreasePositionRequest memory request = increasePositionRequests[_key];

        // if the request was already executed or cancelled, return true so that the executeIncreasePositions loop will continue executing the next request
        if (request.account == address(0)) {return true;}

        circuitBreaker.validateCircuitBreaker(request.indexToken, request.sizeDelta, request.isLong);

        bool shouldExecute = _validateExecution(request.blockNumber, request.blockTime, request.account);
        if (!shouldExecute) {return false;}

        delete increasePositionRequests[_key];

        if (request.amountIn > 0) {
            uint256 amountIn = request.amountIn;

            if (request.path.length > 1) {
                IERC20Upgradeable(request.path[0]).safeTransfer(vault, request.amountIn);
                amountIn = _swap(request.path, request.minOut, address(this));
            }

            uint256 afterFeeAmount = _collectFees(msg.sender, request.path, amountIn, request.indexToken, request.isLong, request.sizeDelta);
            IERC20Upgradeable(request.path[request.path.length - 1]).safeTransfer(vault, afterFeeAmount);
        }

        uint256 executionPrice = _increasePosition(request.account, request.path[request.path.length - 1], request.indexToken, request.sizeDelta, request.isLong, request.acceptablePrice, request.brokerAddress, request.brokerFeeBasisPoints);

        IWETH(weth).withdraw(request.tpSlExecutionFee);
        (uint tpExecutionFee, uint slExecutionFee) = LibFeeHelper.splitTpSlExecutionFee(request.tp, request.sl, request.tpSlExecutionFee);
        if (request.tp > 0) {
            orderBook.createDecreaseOrderForAccount{value: tpExecutionFee}(
                request.account,
                request.indexToken,
                request.sizeDelta,
                request.path[request.path.length - 1],
                0,
                request.isLong,
                request.tp,
                request.isLong
            );
        }

        if (request.sl > 0) {
            orderBook.createDecreaseOrderForAccount{value: slExecutionFee}(
                request.account,
                request.indexToken,
                request.sizeDelta,
                request.path[request.path.length - 1],
                0,
                request.isLong,
                request.sl,
                !request.isLong
            );
        }

        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        emit IncreasePositionRequestExecuted(
            request.account,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime,
            executionPrice,
            request
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit ExecuteIncreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.amountIn,
            request.sizeDelta,
            request.isLong,
            request.acceptablePrice,
            request.executionFee,
            executionPrice,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        return true;
    }

    function cancelIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        IncreasePositionRequest memory request = increasePositionRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeIncreasePositions loop will continue executing the next request
        if (request.account == address(0)) {return true;}

        bool shouldCancel = _validateCallerAndTiming(request.blockNumber, request.blockTime, request.account);
        if (!shouldCancel) {return false;}

        delete increasePositionRequests[_key];

        if (request.hasCollateralInETH) {
            _transferOutETHWithGasLimitFallbackToWeth(request.amountIn, payable(request.account));
        } else {
            IERC20Upgradeable(request.path[0]).safeTransfer(request.account, request.amountIn);
        }

        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);
        _transferOutETHWithGasLimitFallbackToWeth(request.tpSlExecutionFee, payable(request.account));

        emit IncreasePositionRequestCancelled(
            request.account,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime,
            request
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit CancelIncreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.amountIn,
            request.sizeDelta,
            request.isLong,
            request.acceptablePrice,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        return true;
    }

    function executeDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) external nonReentrant returns (bool) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
        if (request.account == address(0)) {return true;}

        bool shouldExecute = _validateExecution(request.blockNumber, request.blockTime, request.account);
        if (!shouldExecute) {return false;}

        delete decreasePositionRequests[_key];

        (uint256 amountOut, uint256 executionPrice) = _decreasePosition(request.account, request.path[0], request.indexToken, request.collateralDelta, request.sizeDelta, request.isLong, address(this), request.acceptablePrice);

        if (amountOut > 0) {
            if (request.path.length > 1) {
                IERC20Upgradeable(request.path[0]).safeTransfer(vault, amountOut);
                amountOut = _swap(request.path, request.minOut, address(this));
            }

            if (request.withdrawETH) {
                _transferOutETHWithGasLimitFallbackToWeth(amountOut, payable(request.receiver));
            } else {
                IERC20Upgradeable(request.path[request.path.length - 1]).safeTransfer(request.receiver, amountOut);
            }
        }

        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        uint blockGap = block.number - request.blockNumber;
        uint timeGap = block.timestamp - request.blockTime;

        emit ExecuteDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.executionFee,
            amountOut,
            executionPrice,
            blockGap,
            timeGap
        );

        return true;
    }

    function cancelDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
        if (request.account == address(0)) {return true;}

        bool shouldCancel = _validateCallerAndTiming(request.blockNumber, request.blockTime, request.account);
        if (!shouldCancel) {return false;}

        delete decreasePositionRequests[_key];

        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        emit CancelDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        return true;
    }

    function getRequestKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function getIncreasePositionRequestPath(bytes32 _key) public view returns (address[] memory) {
        IncreasePositionRequest memory request = increasePositionRequests[_key];
        return request.path;
    }

    function getDecreasePositionRequestPath(bytes32 _key) public view returns (address[] memory) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        return request.path;
    }

    function _setTraderReferralCode(bytes32 _referralCode) internal {
        if (_referralCode != bytes32(0)) {
            IReferralManager(referralStorage).setTraderReferralCode(msg.sender, _referralCode);
        }
    }

    function _validateExecution(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) private view returns (bool) {
        if (_positionBlockTime + maxTimeDelay <= block.timestamp) {
            revert PositionRouterError(5);
        }
        return _validateCallerAndTiming(_positionBlockNumber, _positionBlockTime, _account);
    }

    function _validateCallerAndTiming(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) private view returns (bool) {
        bool isKeeperCall = msg.sender == address(this) || isPositionKeeper[msg.sender];

        if (!isLeverageEnabled && !isKeeperCall) {
            revert PositionRouterError(14);
        }

        if (isKeeperCall) {
            return _positionBlockNumber + minBlockDelayKeeper <= block.number;
        }

        if (msg.sender != _account) {
            revert PositionRouterError(15);
        }

        if (_positionBlockTime + minTimeDelayPublic > block.timestamp) {
            revert PositionRouterError(6);
        }

        return true;
    }

    function _createIncreasePositionInternal(address _account, IncreasePositionParamsV2 memory _params) internal returns (bytes32) {
        if (_params.path.length != 1 && _params.path.length != 2) {
            revert PositionRouterError(3);
        }

        uint tpSlExecutionFee = LibFeeHelper.getTpSlExecutionFee(
            _params.tp,
            _params.sl,
            address(orderBook) != address(0) ? orderBook.minExecutionFee() : 0
        );
        if (_params.executionFee < tpSlExecutionFee + minExecutionFee) {
            revert PositionRouterError(1);
        }

        uint256 updateFee = _updatePythOracle(_params.priceData);
        if (msg.value < _params.executionFee + updateFee) {
            revert PositionRouterError(2);
        }

        if (_params.hasCollateralInETH) {
            if (_params.path[0] != weth) {
                revert PositionRouterError(7);
            }
            _params.amountIn = msg.value - _params.executionFee - updateFee;
        } else {
            if (_params.amountIn > 0) {
                IRouter(router).pluginTransfer(_params.path[0], msg.sender, address(this), _params.amountIn);
            }
        }

        _transferInETH(msg.value - updateFee);
        _setTraderReferralCode(_params.referralCode);

        IncreasePositionRequest memory request = IncreasePositionRequest(
            _account,
            _params.path,
            _params.indexToken,
            _params.amountIn,
            _params.minOut,
            _params.sizeDelta,
            _params.isLong,
            _params.acceptablePrice,
            _params.executionFee - tpSlExecutionFee,
            block.number,
            block.timestamp,
            _params.hasCollateralInETH,
            address(0),
            _params.tp,
            _params.sl,
            _params.brokerAddress,
            _params.brokerFeeBasisPoints,
            tpSlExecutionFee
        );

        (uint256 index, bytes32 requestKey) = _storeIncreasePositionRequest(request);

        emit IncreasePositionRequestCreated(
            _account,
            index,
            increasePositionRequestKeys.length - 1,
            request
        );

        // Also emit old event for backward compatibility
        // TODO: remove this after all dependencies are upgraded
        emit CreateIncreasePosition(
            _account,
            request.path,
            request.indexToken,
            request.amountIn,
            request.minOut,
            request.sizeDelta,
            request.isLong,
            request.acceptablePrice,
            request.executionFee,
            index,
            increasePositionRequestKeys.length - 1
        );

        return requestKey;
    }

    function _storeIncreasePositionRequest(IncreasePositionRequest memory _request) internal returns (uint256, bytes32) {
        address account = _request.account;
        uint256 index = increasePositionsIndex[account] + 1;
        increasePositionsIndex[account] = index;
        bytes32 key = getRequestKey(account, index);

        increasePositionRequests[key] = _request;
        increasePositionRequestKeys.push(key);

        return (index, key);
    }

    function _storeDecreasePositionRequest(DecreasePositionRequest memory _request) internal returns (uint256, bytes32) {
        address account = _request.account;
        uint256 index = decreasePositionsIndex[account] + 1;
        decreasePositionsIndex[account] = index;
        bytes32 key = getRequestKey(account, index);

        decreasePositionRequests[key] = _request;
        decreasePositionRequestKeys.push(key);

        return (index, key);
    }

    function _createDecreasePosition(
        address _account,
        DecreasePositionParams calldata _params
    ) internal returns (bytes32) {
        DecreasePositionRequest memory request = DecreasePositionRequest(
            _account,
            _params.path,
            _params.indexToken,
            _params.collateralDelta,
            _params.sizeDelta,
            _params.isLong,
            _params.receiver,
            _params.acceptablePrice,
            _params.minOut,
            _params.executionFee,
            block.number,
            block.timestamp,
            _params.withdrawETH,
            address(0)
        );

        (uint256 index, bytes32 requestKey) = _storeDecreasePositionRequest(request);
        emit CreateDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.minOut,
            request.executionFee,
            index,
            decreasePositionRequestKeys.length - 1
        );
        return requestKey;
    }

    function _updatePythOracle(bytes[] memory priceUpdateData) internal returns (uint256) {
        if (priceUpdateData.length == 0) {
            return 0;
        }
        uint256 fee = pythOracle.getUpdateFee(priceUpdateData);
        if (fee > msg.value) {
            revert PositionRouterError(2);
        }
        pythOracle.updatePriceFeeds{value: fee}(priceUpdateData);
        return fee;
    }

    function _transferOutETHWithGasLimitFallbackToWeth(uint256 _amountOut, address payable _receiver) internal {
        IWETH _weth = IWETH(weth);
        _weth.withdraw(_amountOut);

        (bool success,) = _receiver.call{value: _amountOut, gas: ethTransferGasLimit}("");

        if (success) {return;}

        // if the transfer failed, re-wrap the token and send it to the receiver
        _weth.deposit{value: _amountOut}();
        _weth.transfer(address(_receiver), _amountOut);
    }

    function _validateMaxGlobalSize(address _indexToken, bool _isLong, uint256 _sizeDelta) internal view {
        if (_sizeDelta == 0) {
            return;
        }

        uint maxGlobalSize = _isLong ? maxGlobalLongSizes[_indexToken] : maxGlobalShortSizes[_indexToken];
        uint currentOI = _isLong ? IVault(vault).guaranteedUsd(_indexToken) : IVault(vault).globalShortSizes(_indexToken);
        if (maxGlobalSize > 0 && currentOI + _sizeDelta > maxGlobalSize) {
            revert PositionRouterError(_isLong ? 9 : 10);
        }
    }

    function _increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _price, address _brokerAddress, uint256 _brokerFeeBasisPoints) internal returns (uint256) {
        address _vault = vault;

        uint256 markPrice = _isLong ? IVault(_vault).getMaxPrice(_indexToken) : IVault(_vault).getMinPrice(_indexToken);
        if (_isLong) {
            if (markPrice > _price) revert PositionRouterError(12);
        } else {
            if (markPrice < _price) revert PositionRouterError(11);
        }

        _validateMaxGlobalSize(_indexToken, _isLong, _sizeDelta);

        address timelock = IVault(_vault).gov();

        ITimelock(timelock).enableLeverage(_vault);
        IRouter(router).pluginIncreasePositionV2(_account, _collateralToken, _indexToken, _sizeDelta, _isLong, _brokerAddress, _brokerFeeBasisPoints);
        ITimelock(timelock).disableLeverage(_vault);

        return markPrice;
    }

    function _decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price) internal returns (uint256, uint256) {
        address _vault = vault;

        uint256 markPrice = _isLong ? IVault(_vault).getMinPrice(_indexToken) : IVault(_vault).getMaxPrice(_indexToken);
        if (_isLong) {
            if (markPrice < _price) revert PositionRouterError(11);
        } else {
            if (markPrice > _price) revert PositionRouterError(12);
        }

        address timelock = IVault(_vault).gov();

        ITimelock(timelock).enableLeverage(_vault);
        uint256 amountOut = IRouter(router).pluginDecreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
        ITimelock(timelock).disableLeverage(_vault);

        return (amountOut, markPrice);
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) internal returns (uint256) {
        if (_path.length != 2) revert PositionRouterError(3);
        uint256 amountOut = IVault(vault).swap(_path[0], _path[1], _receiver);
        if (amountOut < _minOut) {
            revert PositionRouterError(13);
        }
        return amountOut;
    }

    function _transferInETH(uint _amount) internal {
        if (_amount != 0) {
            IWETH(weth).deposit{value: _amount}();
        }
    }

    function _collectFees(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta
    ) internal returns (uint256) {
        bool shouldDeductFee = _shouldDeductFee(
            _account,
            _path,
            _amountIn,
            _indexToken,
            _isLong,
            _sizeDelta
        );

        if (shouldDeductFee) {
            uint256 afterFeeAmount = _amountIn * (BASIS_POINTS_DIVISOR - depositFee) / BASIS_POINTS_DIVISOR;
            uint256 feeAmount = _amountIn - afterFeeAmount;
            address feeToken = _path[_path.length - 1];
            feeReserves[feeToken] = feeReserves[feeToken] + feeAmount;
            return afterFeeAmount;
        }

        return _amountIn;
    }

    function _shouldDeductFee(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta
    ) internal view returns (bool) {
        // if the position is a short, do not charge a fee
        if (!_isLong) { return false; }

        // if the position size is not increasing, this is a collateral deposit
        if (_sizeDelta == 0) { return true; }

        address collateralToken = _path[_path.length - 1];

        IVault _vault = IVault(vault);
        (uint256 size, uint256 collateral, , , , , , ) = _vault.getPosition(_account, collateralToken, _indexToken, _isLong);

        // if there is no existing position, do not charge a fee
        if (size == 0) { return false; }

        uint256 nextSize = size + _sizeDelta;
        uint256 collateralDelta = _vault.tokenToUsdMin(collateralToken, _amountIn);
        uint256 nextCollateral = collateral + collateralDelta;

        uint256 prevLeverage = size * BASIS_POINTS_DIVISOR / collateral;
        // allow for a maximum of a increasePositionBufferBps decrease since there might be some swap fees taken from the collateral
        uint256 nextLeverage = nextSize * (BASIS_POINTS_DIVISOR + increasePositionBufferBps) / nextCollateral;

        // deduct a fee if the leverage is decreased
        return nextLeverage < prevLeverage;
    }

    function _onlyGov() internal view {
        if (msg.sender != gov) revert PositionRouterError(0);
    }

    function _onlyAdminOrGov() internal view {
        if (msg.sender != admin && msg.sender != gov) revert PositionRouterError(0);
    }

    function _onlyFeeAdminOrGov() internal view {
        if (msg.sender != feeAdmin && msg.sender != gov) revert PositionRouterError(0);
    }

    function _onlyPositionKeeper() internal view {
        if (!isPositionKeeper[msg.sender]) revert PositionRouterError(0);
    }
}
