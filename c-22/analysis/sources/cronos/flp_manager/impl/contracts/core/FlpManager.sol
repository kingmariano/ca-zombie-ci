// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IFlpManager.sol";
import "./interfaces/IShortsTracker.sol";
import "../tokens/interfaces/IMintable.sol";
import "../access/Governable.sol";

pragma solidity ^0.8.0;

contract FlpManager is ReentrancyGuardUpgradeable, Governable, IFlpManager {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDG_DECIMALS = 18;
    uint256 public constant FLP_PRECISION = 10 ** 18;
    uint256 public constant MAX_COOLDOWN_DURATION = 48 hours;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    IVault public vault;
    IShortsTracker public shortsTracker;
    address public override usdg;
    address public flp;

    uint256 public override cooldownDuration;
    mapping (address => uint256) public override lastAddedAt;

    uint256 public aumAddition;
    uint256 public aumDeduction;

    bool public inPrivateMode;
    uint256 public shortsTrackerAveragePriceWeight;
    mapping (address => bool) public isHandler;

    event AddLiquidity(
        address account,
        address token,
        uint256 amount,
        uint256 aumInUsdg,
        uint256 flpSupply,
        uint256 usdgAmount,
        uint256 mintAmount
    );

    event RemoveLiquidity(
        address account,
        address token,
        uint256 flpAmount,
        uint256 aumInUsdg,
        uint256 flpSupply,
        uint256 usdgAmount,
        uint256 amountOut
    );

    function initialize(
        address _vault,
        address _usdg,
        address _flp,
        address _shortsTracker,
        uint256 _cooldownDuration
    ) public initializer {
        __ReentrancyGuard_init();
        __Governable_init();

        vault = IVault(_vault);
        usdg = _usdg;
        flp = _flp;
        shortsTracker = IShortsTracker(_shortsTracker);
        cooldownDuration = _cooldownDuration;
    }

    function setInPrivateMode(bool _inPrivateMode) external onlyGov {
        inPrivateMode = _inPrivateMode;
    }

    function setShortsTracker(IShortsTracker _shortsTracker) external onlyGov {
        shortsTracker = _shortsTracker;
    }

    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external override onlyGov {
        require(shortsTrackerAveragePriceWeight <= BASIS_POINTS_DIVISOR, "FlpManager: invalid weight");
        shortsTrackerAveragePriceWeight = _shortsTrackerAveragePriceWeight;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function setCooldownDuration(uint256 _cooldownDuration) external override onlyGov {
        require(_cooldownDuration <= MAX_COOLDOWN_DURATION, "FlpManager: invalid _cooldownDuration");
        cooldownDuration = _cooldownDuration;
    }

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external onlyGov {
        aumAddition = _aumAddition;
        aumDeduction = _aumDeduction;
    }

    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minFlp) external override nonReentrant returns (uint256) {
        if (inPrivateMode) { revert("FlpManager: action not enabled"); }
        return _addLiquidity(msg.sender, msg.sender, _token, _amount, _minUsdg, _minFlp);
    }

    function addLiquidityForAccount(address _fundingAccount, address _account, address _token, uint256 _amount, uint256 _minUsdg, uint256 _minFlp) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _addLiquidity(_fundingAccount, _account, _token, _amount, _minUsdg, _minFlp);
    }

    function removeLiquidity(address _tokenOut, uint256 _flpAmount, uint256 _minOut, address _receiver) external override nonReentrant returns (uint256) {
        if (inPrivateMode) { revert("FlpManager: action not enabled"); }
        return _removeLiquidity(msg.sender, _tokenOut, _flpAmount, _minOut, _receiver);
    }

    function removeLiquidityForAccount(address _account, address _tokenOut, uint256 _flpAmount, uint256 _minOut, address _receiver) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _removeLiquidity(_account, _tokenOut, _flpAmount, _minOut, _receiver);
    }

    function getPrice(bool _maximise) external view returns (uint256) {
        uint256 aum = getAum(_maximise);
        uint256 supply = IERC20Upgradeable(flp).totalSupply();
        return aum * FLP_PRECISION / supply;
    }

    function getAums() public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = getAum(true);
        amounts[1] = getAum(false);
        return amounts;
    }

    function getAumInUsdg(bool maximise) public override view returns (uint256) {
        uint256 aum = getAum(maximise);
        return aum * (10 ** USDG_DECIMALS) / PRICE_PRECISION;
    }

    function getAum(bool maximise) public view returns (uint256) {
        uint256 aum = aumAddition;
        uint256 shortProfits = 0;
        IVault _vault = vault;

        uint256 length = vault.whitelistedTokenCount();
        for (uint256 i = 0; i < length; i++) {
            address token = vault.whitelistedTokens(i);
            uint256 price = maximise ? _vault.getMaxPrice(token) : _vault.getMinPrice(token);
            uint256 poolAmount = _vault.poolAmounts(token);
            uint256 decimals = _vault.tokenDecimals(token);

            if (_vault.stableTokens(token)) {
                aum = aum + (poolAmount * price / 10 ** decimals);
            } else {
                // add global short profit / loss
                uint256 size = _vault.globalShortSizes(token);

                if (size > 0) {
                    (uint256 delta, bool hasProfit) = getGlobalShortDelta(token, price, size);
                    if (!hasProfit) {
                        // add losses from shorts
                        aum = aum + delta;
                    } else {
                        shortProfits = shortProfits + delta;
                    }
                }

                aum = aum + _vault.guaranteedUsd(token);

                uint256 reservedAmount = _vault.reservedAmounts(token);
                aum = aum + ((poolAmount - reservedAmount) * price / 10 ** decimals);
            }
        }

        aum = shortProfits > aum ? 0 : aum - shortProfits;
        return aumDeduction > aum ? 0 : aum - aumDeduction;
    }

    function getGlobalShortDelta(address _token, uint256 _price, uint256 _size) public view returns (uint256, bool) {
        uint256 averagePrice = getGlobalShortAveragePrice(_token);
        uint256 priceDelta = averagePrice > _price ? averagePrice - _price : _price - averagePrice;
        uint256 delta = _size * priceDelta / averagePrice;
        return (delta, averagePrice > _price);
    }

    function getGlobalShortAveragePrice(address _token) public view returns (uint256) {
        IShortsTracker _shortsTracker = shortsTracker;
        if (address(_shortsTracker) == address(0) || !_shortsTracker.isGlobalShortDataReady()) {
            return vault.globalShortAveragePrices(_token);
        }

        uint256 _shortsTrackerAveragePriceWeight = shortsTrackerAveragePriceWeight;
        if (_shortsTrackerAveragePriceWeight == 0) {
            return vault.globalShortAveragePrices(_token);
        } else if (_shortsTrackerAveragePriceWeight == BASIS_POINTS_DIVISOR) {
            return _shortsTracker.globalShortAveragePrices(_token);
        }

        uint256 vaultAveragePrice = vault.globalShortAveragePrices(_token);
        uint256 shortsTrackerAveragePrice = _shortsTracker.globalShortAveragePrices(_token);

        return (vaultAveragePrice * (BASIS_POINTS_DIVISOR - _shortsTrackerAveragePriceWeight)
             + shortsTrackerAveragePrice * _shortsTrackerAveragePriceWeight)
             / BASIS_POINTS_DIVISOR;
    }

    function _addLiquidity(address _fundingAccount, address _account, address _token, uint256 _amount, uint256 _minUsdg, uint256 _minFlp) private returns (uint256) {
        require(_amount > 0, "FlpManager: invalid _amount");

        // calculate aum before buyUSDG
        uint256 aumInUsdg = getAumInUsdg(true);
        uint256 flpSupply = IERC20Upgradeable(flp).totalSupply();

        IERC20Upgradeable(_token).safeTransferFrom(_fundingAccount, address(vault), _amount);
        uint256 usdgAmount = vault.buyUSDG(_token, address(this));
        require(usdgAmount >= _minUsdg, "FlpManager: insufficient USDG output");

        uint256 mintAmount = aumInUsdg == 0 ? usdgAmount : usdgAmount * flpSupply / aumInUsdg;
        require(mintAmount >= _minFlp, "FlpManager: insufficient FLP output");

        IMintable(flp).mint(_account, mintAmount);

        lastAddedAt[_account] = block.timestamp;

        emit AddLiquidity(_account, _token, _amount, aumInUsdg, flpSupply, usdgAmount, mintAmount);

        return mintAmount;
    }

    function _removeLiquidity(address _account, address _tokenOut, uint256 _flpAmount, uint256 _minOut, address _receiver) private returns (uint256) {
        require(_flpAmount > 0, "FlpManager: invalid _flpAmount");
        require(lastAddedAt[_account] + cooldownDuration <= block.timestamp, "FlpManager: cooldown duration not yet passed");

        // calculate aum before sellUSDG
        uint256 aumInUsdg = getAumInUsdg(false);
        uint256 flpSupply = IERC20Upgradeable(flp).totalSupply();

        uint256 usdgAmount = _flpAmount * aumInUsdg / flpSupply;
        uint256 usdgBalance = IERC20Upgradeable(usdg).balanceOf(address(this));
        if (usdgAmount > usdgBalance) {
            IMintable(usdg).mint(address(this), usdgAmount - usdgBalance);
        }

        IMintable(flp).burn(_account, _flpAmount);

        IERC20Upgradeable(usdg).transfer(address(vault), usdgAmount);
        uint256 amountOut = vault.sellUSDG(_tokenOut, _receiver);
        require(amountOut >= _minOut, "FlpManager: insufficient output");

        emit RemoveLiquidity(_account, _tokenOut, _flpAmount, aumInUsdg, flpSupply, usdgAmount, amountOut);

        return amountOut;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "FlpManager: forbidden");
    }
}
