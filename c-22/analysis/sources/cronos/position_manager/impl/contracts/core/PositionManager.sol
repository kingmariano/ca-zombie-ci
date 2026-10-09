// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../access/Governable.sol";
import "./interfaces/ICircuitBreaker.sol";
import "./interfaces/IPositionManager.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IOrderBook.sol";
import "../peripherals/interfaces/ITimelock.sol";
import "../tokens/interfaces/IWETH.sol";

contract PositionManager is IPositionManager, ReentrancyGuardUpgradeable, Governable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    address public admin;
    address public feeAdmin; // deprecated, this is inherited from BasePositionManager before, but not used in this contract

    address public vault;
    address public shortsTracker; // deprecated
    address public router; // deprecated
    address public weth;

    uint256 public depositFee; // deprecated, this is inherited from BasePositionManager before, but not used in this contract
    uint256 public increasePositionBufferBps;

    address public referralStorage; // deprecated, this is inherited from BasePositionManager before, but not used in this contract

    mapping (address => uint256) public feeReserves; // deprecated, this is inherited from BasePositionManager before, but not used in this contract

    mapping (address => uint256) public override maxGlobalLongSizes;
    mapping (address => uint256) public override maxGlobalShortSizes;

    address public orderBook;
    bool public inLegacyMode; // deprecated

    bool public shouldValidateIncreaseOrder;

    mapping (address => bool) public isOrderKeeper;
    mapping (address => bool) public isPartner; // deprecated
    mapping (address => bool) public isLiquidator;

    ICircuitBreaker public circuitBreaker;

    event SetDepositFee(uint256 depositFee);
    event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
    event SetReferralManager(address referralManager);
    event SetAdmin(address admin);
    event SetFeeAdmin(address feeAdmin);
    event WithdrawFees(address token, address receiver, uint256 amount);
    event SetMaxGlobalSizes(
        address[] tokens,
        uint256[] longSizes,
        uint256[] shortSizes
    );

    event SetOrderKeeper(address indexed account, bool isActive);
    event SetLiquidator(address indexed account, bool isActive);
    event SetPartner(address account, bool isActive);
    event SetInLegacyMode(bool inLegacyMode);
    event SetShouldValidateIncreaseOrder(bool shouldValidateIncreaseOrder);

    modifier onlyAdminOrGov() {
        require(msg.sender == admin || msg.sender == gov, "PositionManager: forbidden");
        _;
    }

    modifier onlyOrderKeeper() {
        require(isOrderKeeper[msg.sender], "PositionManager: forbidden");
        _;
    }

    modifier onlyLiquidator() {
        require(isLiquidator[msg.sender], "PositionManager: forbidden");
        _;
    }

    modifier onlyPartnersOrLegacyMode() {
        require(isPartner[msg.sender] || inLegacyMode, "PositionManager: forbidden");
        _;
    }

    function initialize(
        address _vault,
        address _weth,
        address _orderBook
    ) public initializer {
        __ReentrancyGuard_init();

        gov = msg.sender;
        vault = _vault;
        weth = _weth;
        increasePositionBufferBps = 100;
        admin = msg.sender;

        orderBook = _orderBook;
        shouldValidateIncreaseOrder = true;
    }

    receive() external payable {
        require(msg.sender == weth, "PositionManager: invalid sender");
    }

    function setAdmin(address _admin) external onlyGov {
        require(_admin != address(0), "PositionManager: zero address");
        admin = _admin;
        emit SetAdmin(_admin);
    }

    function setFeeAdmin(address _feeAdmin) external onlyGov {
        feeAdmin = _feeAdmin;
        emit SetFeeAdmin(_feeAdmin);
    }

    function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps) external onlyGov {
        increasePositionBufferBps = _increasePositionBufferBps;
        emit SetIncreasePositionBufferBps(_increasePositionBufferBps);
    }

    function setReferralManager(address _referralManager) external onlyGov {
        referralStorage = _referralManager;
        emit SetReferralManager(_referralManager);
    }

    function setCircuitBreaker(ICircuitBreaker _circuitBreaker) external onlyGov {
        circuitBreaker = _circuitBreaker;
    }

    function setMaxGlobalSizes(
        address[] memory _tokens,
        uint256[] memory _longSizes,
        uint256[] memory _shortSizes
    ) external onlyAdminOrGov {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            maxGlobalLongSizes[token] = _longSizes[i];
            maxGlobalShortSizes[token] = _shortSizes[i];
        }
        emit SetMaxGlobalSizes(_tokens, _longSizes, _shortSizes);
    }

    function _validateMaxGlobalSize(address _indexToken, bool _isLong, uint256 _sizeDelta) internal view {
        if (_sizeDelta == 0) {
            return;
        }
        if (_isLong) {
            uint256 maxGlobalLongSize = maxGlobalLongSizes[_indexToken];
            if (maxGlobalLongSize > 0 && IVault(vault).guaranteedUsd(_indexToken) + _sizeDelta > maxGlobalLongSize) {
                revert("PositionManager: max global longs exceeded");
            }
        } else {
            uint256 maxGlobalShortSize = maxGlobalShortSizes[_indexToken];
            if (maxGlobalShortSize > 0 && IVault(vault).globalShortSizes(_indexToken) + _sizeDelta > maxGlobalShortSize) {
                revert("PositionManager: max global shorts exceeded");
            }
        }
    }

    function setOrderKeeper(address _account, bool _isActive) external onlyGov {
        isOrderKeeper[_account] = _isActive;
        emit SetOrderKeeper(_account, _isActive);
    }

    function setLiquidator(address _account, bool _isActive) external onlyGov {
        isLiquidator[_account] = _isActive;
        emit SetLiquidator(_account, _isActive);
    }

    function setShouldValidateIncreaseOrder(bool _shouldValidateIncreaseOrder) external onlyGov {
        shouldValidateIncreaseOrder = _shouldValidateIncreaseOrder;
        emit SetShouldValidateIncreaseOrder(_shouldValidateIncreaseOrder);
    }

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external nonReentrant onlyLiquidator {
        address _vault = vault;
        address timelock = IVault(_vault).gov();

        ITimelock(timelock).enableLeverage(_vault);
        IVault(_vault).liquidatePosition(_account, _collateralToken, _indexToken, _isLong, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);
    }

    function executeSwapOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external onlyOrderKeeper {
        IOrderBook(orderBook).executeSwapOrder(_account, _orderIndex, _feeReceiver);
    }

    function executeIncreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external onlyOrderKeeper {
        _validateIncreaseOrder(_account, _orderIndex);

        address _vault = vault;
        address timelock = IVault(_vault).gov();

        (
            /*address purchaseToken*/,
            /*uint256 purchaseTokenAmount*/,
            /* address collateralToken*/,
            address indexToken,
            uint256 sizeDelta,
            bool isLong,
            /*uint256 triggerPrice*/,
            /*bool triggerAboveThreshold*/,
            /*uint256 executionFee*/
        ) = IOrderBook(orderBook).getIncreaseOrder(_account, _orderIndex);

        circuitBreaker.validateCircuitBreaker(indexToken, sizeDelta, isLong);

        ITimelock(timelock).enableLeverage(_vault);
        IOrderBook(orderBook).executeIncreaseOrder(_account, _orderIndex, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);
    }

    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external onlyOrderKeeper {
        address _vault = vault;
        address timelock = IVault(_vault).gov();

        ITimelock(timelock).enableLeverage(_vault);
        IOrderBook(orderBook).executeDecreaseOrder(_account, _orderIndex, _feeReceiver);
        ITimelock(timelock).disableLeverage(_vault);
    }

    function _validateIncreaseOrder(address _account, uint256 _orderIndex) internal view {
        (
            address _purchaseToken,
            uint256 _purchaseTokenAmount,
            address _collateralToken,
            address _indexToken,
            uint256 _sizeDelta,
            bool _isLong,
            , // triggerPrice
            , // triggerAboveThreshold
            // executionFee
        ) = IOrderBook(orderBook).getIncreaseOrder(_account, _orderIndex);

        _validateMaxGlobalSize(_indexToken, _isLong, _sizeDelta);

        if (!shouldValidateIncreaseOrder) { return; }

        // shorts are okay
        if (!_isLong) { return; }

        // if the position size is not increasing, this is a collateral deposit
        require(_sizeDelta > 0, "PositionManager: long deposit");

        IVault _vault = IVault(vault);
        (uint256 size, uint256 collateral, , , , , , ) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);

        // if there is no existing position, do not charge a fee
        if (size == 0) { return; }

        uint256 nextSize = size + _sizeDelta;
        uint256 collateralDelta = _vault.tokenToUsdMin(_purchaseToken, _purchaseTokenAmount);
        uint256 nextCollateral = collateral + collateralDelta;

        uint256 prevLeverage = size * BASIS_POINTS_DIVISOR / collateral;
        // allow for a maximum of a increasePositionBufferBps decrease since there might be some swap fees taken from the collateral
        uint256 nextLeverageWithBuffer = nextSize * (BASIS_POINTS_DIVISOR + increasePositionBufferBps) / nextCollateral;

        require(nextLeverageWithBuffer >= prevLeverage, "PositionManager: long leverage decrease");
    }
}
