// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.23;

import {BaseHealthCheck, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {ITokenizedStrategy} from "@tokenized-strategy/interfaces/ITokenizedStrategy.sol";
import {AuctionSwapper} from "@periphery/swappers/AuctionSwapper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ICurvanceVault, ICurvanceMarket, ICurvanceMarketManager} from "./interfaces/ICurvance.sol";
import {ILendingOptimizer} from "./interfaces/ILendingOptimizer.sol";
import {IMerklDistributor} from "./interfaces/IMerklDistributor.sol";

/**
 * @title CurvanceOptimizer
 * @notice One Yearn strategy allocating one asset across Curvance borrowable markets and lending optimizers.
 * @dev Management sets asset targets. Keepers rebalance through tend(); reports
 * accrue all held positions. Market order controls deposits and withdrawals.
 */
contract CurvanceOptimizer is BaseHealthCheck, AuctionSwapper {
    using SafeERC20 for ERC20;

    uint256 public constant MAX_MARKETS = 16;
    address[] public markets;
    /// @notice Zero for lending optimizers and unregistered destinations.
    mapping(address => address) public marketManagers;
    mapping(address => bool) public isLendingOptimizer;
    mapping(address => uint256) public allocationTargets;

    IMerklDistributor public constant MERKL_DISTRIBUTOR = IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);

    event MarketAdded(address indexed market);
    event MarketRemoved(address indexed market);
    event AllocationTargetSet(address indexed market, uint256 assets);
    event MarketOrderSet(address[] markets);

    constructor(address _asset, string memory _name, address[] memory _markets) BaseHealthCheck(_asset, _name) {
        require(_markets.length != 0, "no markets");
        for (uint256 i; i < _markets.length; ++i) {
            _addMarket(_markets[i]);
        }
    }

    /// @notice One-call role bootstrap used by the factory at deployment.
    /// @dev Forwards to the four individual setters so their validation and
    /// events are preserved, while the caller pays for a single external call.
    function initializeFactoryAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) external onlyManagement {
        _delegateCall(abi.encodeCall(ITokenizedStrategy.setPerformanceFeeRecipient, (_performanceFeeRecipient)));
        _delegateCall(abi.encodeCall(ITokenizedStrategy.setKeeper, (_keeper)));
        _delegateCall(abi.encodeCall(ITokenizedStrategy.setPendingManagement, (_management)));
        _delegateCall(abi.encodeCall(ITokenizedStrategy.setEmergencyAdmin, (_emergencyAdmin)));
    }

    function addMarket(address market) external onlyManagement {
        _addMarket(market);
    }

    function _addMarket(address market) private {
        require(markets.length < MAX_MARKETS, "too many markets");
        require(market != address(this) && !_registered(market), "invalid market");
        require(ICurvanceVault(market).asset() == address(asset), "wrong asset");
        address manager = address(0);
        try ILendingOptimizer(market).numApprovedMarkets() returns (uint256 count) {
            require(count != 0, "no optimizer markets");
            isLendingOptimizer[market] = true;
        } catch {
            manager = ICurvanceMarket(market).marketManager();
            require(manager != address(0), "zero manager");
            ICurvanceMarket(market).assetsHeld();
            ICurvanceMarketManager(manager).redeemPaused();
        }
        markets.push(market);
        marketManagers[market] = manager;
        asset.forceApprove(market, type(uint256).max);
        emit MarketAdded(market);
    }

    /// @notice A market must hold no redeemable value before removal.
    function removeMarket(address market) external onlyManagement {
        require(_registered(market), "unknown market");
        // Exact zero prevents removal from hiding any remaining shares.
        uint256 shares = ICurvanceVault(market).balanceOf(address(this));
        // slither-disable-next-line incorrect-equality
        require(ICurvanceVault(market).previewRedeem(shares) == 0, "position remains");
        delete marketManagers[market];
        delete isLendingOptimizer[market];
        delete allocationTargets[market];
        for (uint256 i; i < markets.length; ++i) {
            if (markets[i] != market) continue;
            for (uint256 j = i; j + 1 < markets.length; ++j) {
                markets[j] = markets[j + 1];
            }
            markets.pop();
            break;
        }
        emit MarketRemoved(market);
        asset.forceApprove(market, 0);
    }

    /// @notice Targets are underlying asset amounts, not percentages or guaranteed allocations.
    function setAllocationTargets(address[] calldata _markets, uint256[] calldata targets) external onlyManagement {
        require(_markets.length == targets.length, "length mismatch");
        for (uint256 i; i < _markets.length; ++i) {
            require(_registered(_markets[i]), "unknown market");
            allocationTargets[_markets[i]] = targets[i];
            emit AllocationTargetSet(_markets[i], targets[i]);
        }
    }

    function setMarketOrder(address[] calldata order) external onlyManagement {
        require(order.length == markets.length, "length mismatch");
        for (uint256 i; i < order.length; ++i) {
            require(_registered(order[i]), "unknown market");
            for (uint256 j; j < i; ++j) {
                require(order[j] != order[i], "duplicate market");
            }
        }
        markets = order;
        emit MarketOrderSet(order);
    }

    function _registered(address market) private view returns (bool) {
        return marketManagers[market] != address(0) || isLendingOptimizer[market];
    }

    function marketsLength() external view returns (uint256) {
        return markets.length;
    }

    function positionValue(address market) public view returns (uint256) {
        require(_registered(market), "unknown market");
        return _positionValue(market);
    }

    function _positionValue(address market) private view returns (uint256) {
        ICurvanceVault target = ICurvanceVault(market);
        return target.convertToAssets(target.balanceOf(address(this)));
    }

    function marketMaxWithdraw(address market) public view returns (uint256) {
        address manager = marketManagers[market];
        require(_registered(market), "unknown market");
        ICurvanceVault target = ICurvanceVault(market);
        if (isLendingOptimizer[market]) return target.convertToAssets(target.maxRedeem(address(this)));
        if (ICurvanceMarketManager(manager).redeemPaused() == 2) return 0;
        return Math.min(target.convertToAssets(target.maxRedeem(address(this))), ICurvanceMarket(market).assetsHeld());
    }

    function availableWithdrawLimit(address) public view override returns (uint256 amount) {
        amount = asset.balanceOf(address(this));
        for (uint256 i; i < markets.length; ++i) {
            amount += marketMaxWithdraw(markets[i]);
        }
    }

    /// @dev Deposits above configured targets stay idle. Access remains closed by default.
    function _deployFunds(uint256 amount) internal override {
        _accrue();
        _invest(amount);
    }

    function _invest(uint256 amount) private {
        for (uint256 i; i < markets.length && amount != 0; ++i) {
            address market = markets[i];
            uint256 value = _positionValue(market);
            uint256 target = allocationTargets[market];
            if (value >= target) continue;
            uint256 deposit =
                Math.min(amount, Math.min(target - value, ICurvanceVault(market).maxDeposit(address(this))));
            // Keep amounts that cannot mint a share idle.
            // slither-disable-next-line incorrect-equality
            if (deposit == 0 || ICurvanceVault(market).previewDeposit(deposit) == 0) continue;
            ICurvanceVault(market).deposit(deposit, address(this));
            amount -= deposit;
        }
    }

    function _accrue() private {
        for (uint256 i; i < markets.length; ++i) {
            ICurvanceVault(markets[i]).accrueIfNeeded();
        }
    }

    function _positionAssets() private view returns (uint256 amount) {
        for (uint256 i; i < markets.length; ++i) {
            amount += _positionValue(markets[i]);
        }
    }

    function _freeFunds(uint256 amount) internal override {
        if (amount == 0) return;
        _accrue();
        // Only position loss may reduce the request; illiquidity must revert.
        _withdraw(Math.min(amount, _positionAssets()));
    }

    // All callers enter through Yearn nonReentrant functions; BaseStrategy hooks are onlySelf.
    // Callback regression: test_nestedAndDirectCallbacksCannotReenterMoneyPaths.
    // slither-disable-next-line reentrancy-balance
    function _withdraw(uint256 amount) private {
        for (uint256 i; i < markets.length && amount != 0; ++i) {
            address market = markets[i];
            uint256 withdraw = Math.min(amount, marketMaxWithdraw(market));
            // Zero liquidity must be skipped, including paused markets.
            // slither-disable-next-line incorrect-equality
            if (withdraw == 0) continue;
            uint256 freed = _withdrawMarket(market, withdraw);
            amount -= Math.min(amount, freed);
        }
        // Unfilled value still held in a market is illiquidity, not a user loss.
        // slither-disable-next-line incorrect-equality
        require(amount == 0, "insufficient liquidity");
    }

    /// @dev Optimizers redeem shares to avoid their extra withdraw share rounding.
    /// Count value actually consumed, including redemption loss, which Yearn checks
    /// against the user's maxLoss. Value left invested cannot satisfy the request.
    function _withdrawMarket(address market, uint256 amount) private returns (uint256) {
        if (!isLendingOptimizer[market]) {
            ICurvanceMarket(market).withdraw(amount, address(this), address(this));
            return amount;
        }
        ICurvanceVault target = ICurvanceVault(market);
        uint256 shares = target.previewWithdraw(amount);
        uint256 valueBefore = _positionValue(market);
        uint256 balanceBefore = asset.balanceOf(address(this));
        if (shares != 0) target.redeem(shares, address(this), address(this));
        uint256 valueAfter = _positionValue(market);
        uint256 received = asset.balanceOf(address(this)) - balanceBefore;
        return Math.max(received, valueBefore > valueAfter ? valueBefore - valueAfter : 0);
    }

    /// @dev availableWithdrawLimit double-counts cash shared between a direct
    /// market and a lending optimizer allocating into it, so type(uint256).max
    /// reverts "insufficient liquidity"; pass an explicit amount instead.
    function _emergencyWithdraw(uint256 amount) internal override {
        if (amount == 0) return;
        _accrue();
        uint256 liquid = availableWithdrawLimit(address(this)) - asset.balanceOf(address(this));
        _withdraw(Math.min(amount, liquid));
    }

    function _tend(uint256) internal override {
        require(!TokenizedStrategy.isShutdown(), "shutdown");
        _accrue();
        for (uint256 i; i < markets.length; ++i) {
            address market = markets[i];
            uint256 value = _positionValue(market);
            uint256 target = allocationTargets[market];
            if (value <= target) continue;
            uint256 amount = Math.min(value - target, marketMaxWithdraw(market));
            if (amount != 0) _withdrawMarket(market, amount);
        }
        _invest(asset.balanceOf(address(this)));
    }

    function _harvestAndReport() internal override returns (uint256) {
        _accrue();
        return asset.balanceOf(address(this)) + _positionAssets();
    }

    /*//////////////////////////////////////////////////////////////
                        MERKL REWARD CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        MERKL_DISTRIBUTOR.claim(users, tokens, amounts, proofs);
    }

    /*//////////////////////////////////////////////////////////////
                        AUCTION SWAPPER
    //////////////////////////////////////////////////////////////*/

    function setAuction(address _auction) external onlyManagement {
        _setAuction(_auction);
    }

    function setUseAuction(bool enabled) external onlyManagement {
        _setUseAuction(enabled);
    }

    function setMinAmountToSell(address token, uint256 amount) external onlyManagement {
        _setMinAmountToSell(token, amount);
    }

    function protectedTokens() public view override returns (address[] memory tokens) {
        tokens = new address[](markets.length + 2);
        tokens[0] = address(asset);
        tokens[1] = address(this);
        for (uint256 i; i < markets.length; ++i) {
            tokens[i + 2] = markets[i];
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";

/**
 *   @title Base Health Check
 *   @author Yearn.finance
 *   @notice This contract can be inherited by any Yearn
 *   V3 strategy wishing to implement a health check during
 *   the `report` function in order to prevent any unexpected
 *   behavior from being permanently recorded as well as the
 *   `checkHealth` modifier.
 *
 *   A strategist simply needs to inherit this contract. Set
 *   the limit ratios to the desired amounts and then
 *   override `_harvestAndReport()` just as they otherwise
 *  would. If the profit or loss that would be recorded is
 *   outside the acceptable bounds the tx will revert.
 *
 *   The healthcheck does not prevent a strategy from reporting
 *   losses, but rather can make sure manual intervention is
 *   needed before reporting an unexpected loss or profit.
 */
abstract contract BaseHealthCheck is BaseStrategy {
    event OpenSet(bool indexed open);
    event AllowedSet(address indexed depositor, bool indexed allowed);

    // Can be used to determine if a healthcheck should be called.
    // Defaults to true;
    bool public doHealthCheck = true;

    // If open is true, anyone can deposit. Else only `allowed[_owner]`.
    bool public open;

    // Per depositor whitelist when `open == false`.
    mapping(address => bool) public allowed;

    uint256 internal constant MAX_BPS = 10_000;

    // Default profit limit to 100%.
    uint16 private _profitLimitRatio = uint16(MAX_BPS);

    // Defaults loss limit to 0.
    uint16 private _lossLimitRatio;

    constructor(address _asset, string memory _name) BaseStrategy(_asset, _name) {}

    /**
     * @notice Returns the current profit limit ratio.
     * @dev Use a getter function to keep the variable private.
     * @return . The current profit limit ratio.
     */
    function profitLimitRatio() public view returns (uint256) {
        return _profitLimitRatio;
    }

    /**
     * @notice Returns the current loss limit ratio.
     * @dev Use a getter function to keep the variable private.
     * @return . The current loss limit ratio.
     */
    function lossLimitRatio() public view returns (uint256) {
        return _lossLimitRatio;
    }

    /**
     * @notice Set the `profitLimitRatio`.
     * @dev Denominated in basis points. I.E. 1_000 == 10%.
     * @param _newProfitLimitRatio The mew profit limit ratio.
     */
    function setProfitLimitRatio(uint256 _newProfitLimitRatio) external onlyManagement {
        _setProfitLimitRatio(_newProfitLimitRatio);
    }

    /**
     * @dev Internally set the profit limit ratio. Denominated
     * in basis points. I.E. 1_000 == 10%.
     * @param _newProfitLimitRatio The mew profit limit ratio.
     */
    function _setProfitLimitRatio(uint256 _newProfitLimitRatio) internal {
        require(_newProfitLimitRatio > 0, "!zero profit");
        require(_newProfitLimitRatio <= type(uint16).max, "!too high");
        _profitLimitRatio = uint16(_newProfitLimitRatio);
    }

    /**
     * @notice Set the `lossLimitRatio`.
     * @dev Denominated in basis points. I.E. 1_000 == 10%.
     * @param _newLossLimitRatio The new loss limit ratio.
     */
    function setLossLimitRatio(uint256 _newLossLimitRatio) external onlyManagement {
        _setLossLimitRatio(_newLossLimitRatio);
    }

    /**
     * @dev Internally set the loss limit ratio. Denominated
     * in basis points. I.E. 1_000 == 10%.
     * @param _newLossLimitRatio The new loss limit ratio.
     */
    function _setLossLimitRatio(uint256 _newLossLimitRatio) internal {
        require(_newLossLimitRatio < MAX_BPS, "!loss limit");
        _lossLimitRatio = uint16(_newLossLimitRatio);
    }

    /**
     * @notice Turns the healthcheck on and off.
     * @dev If turned off the next report will auto turn it back on.
     * @param _doHealthCheck Bool if healthCheck should be done.
     */
    function setDoHealthCheck(bool _doHealthCheck) public onlyManagement {
        doHealthCheck = _doHealthCheck;
    }

    /**
     * @notice Open or close strategy deposits globally.
     * @dev If closed, only `allowed[_owner]` addresses can deposit.
     */
    function setOpen(bool _open) external onlyManagement {
        open = _open;
        emit OpenSet(_open);
    }

    /**
     * @notice Set whitelist status for a single depositor.
     */
    function setAllowed(address _depositor, bool _allowed) external onlyManagement {
        allowed[_depositor] = _allowed;
        emit AllowedSet(_depositor, _allowed);
    }

    /**
     * @notice OVerrides the default {harvestAndReport} to include a healthcheck.
     * @return _totalAssets New totalAssets post report.
     */
    function harvestAndReport() external override onlySelf returns (uint256 _totalAssets) {
        // Let the strategy report.
        _totalAssets = _harvestAndReport();

        // Run the healthcheck on the amount returned.
        _executeHealthCheck(_totalAssets);
    }

    /**
     * @dev To be called during a report to make sure the profit
     * or loss being recorded is within the acceptable bound.
     *
     * @param _newTotalAssets The amount that will be reported.
     */
    function _executeHealthCheck(uint256 _newTotalAssets) internal virtual {
        if (!doHealthCheck) {
            doHealthCheck = true;
            return;
        }

        // Get the current total assets from the implementation.
        uint256 currentTotalAssets = TokenizedStrategy.totalAssets();

        if (_newTotalAssets > currentTotalAssets) {
            require(
                ((_newTotalAssets - currentTotalAssets) <= (currentTotalAssets * uint256(_profitLimitRatio)) / MAX_BPS),
                "healthCheck"
            );
        } else if (currentTotalAssets > _newTotalAssets) {
            require(
                (currentTotalAssets - _newTotalAssets <= ((currentTotalAssets * uint256(_lossLimitRatio)) / MAX_BPS)),
                "healthCheck"
            );
        }
    }

    /**
     * @notice Deposit limit with whitelist gating.
     * @dev Open mode allows all deposits. Closed mode requires `allowed[_owner]`.
     */
    function availableDepositLimit(address _owner) public view virtual override returns (uint256) {
        if (!open && !allowed[_owner]) return 0;
        return super.availableDepositLimit(_owner);
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Interface that implements the 4626 standard and the implementation functions
interface ITokenizedStrategy is IERC4626, IERC20Permit {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyShutdown();

    event NewTokenizedStrategy(
        address indexed strategy,
        address indexed asset,
        string apiVersion
    );

    event Reported(
        uint256 profit,
        uint256 loss,
        uint256 protocolFees,
        uint256 performanceFees
    );

    event UpdatePerformanceFeeRecipient(
        address indexed newPerformanceFeeRecipient
    );

    event UpdateKeeper(address indexed newKeeper);

    event UpdatePerformanceFee(uint16 newPerformanceFee);

    event UpdateManagement(address indexed newManagement);

    event UpdateEmergencyAdmin(address indexed newEmergencyAdmin);

    event UpdateProfitMaxUnlockTime(uint256 newProfitMaxUnlockTime);

    event UpdatePendingManagement(address indexed newPendingManagement);

    /*//////////////////////////////////////////////////////////////
                           INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address _asset,
        string memory _name,
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external;

    /*//////////////////////////////////////////////////////////////
                    NON-STANDARD 4626 OPTIONS
    //////////////////////////////////////////////////////////////*/

    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external returns (uint256);

    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external returns (uint256);

    function maxWithdraw(
        address owner,
        uint256 /*maxLoss*/
    ) external view returns (uint256);

    function maxRedeem(
        address owner,
        uint256 /*maxLoss*/
    ) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        MODIFIER HELPERS
    //////////////////////////////////////////////////////////////*/

    function requireManagement(address _sender) external view;

    function requireKeeperOrManagement(address _sender) external view;

    function requireEmergencyAuthorized(address _sender) external view;

    /*//////////////////////////////////////////////////////////////
                        KEEPERS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function tend() external;

    function report() external returns (uint256 _profit, uint256 _loss);

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    function MAX_FEE() external view returns (uint16);

    function FACTORY() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    function apiVersion() external view returns (string memory);

    function pricePerShare() external view returns (uint256);

    function management() external view returns (address);

    function pendingManagement() external view returns (address);

    function keeper() external view returns (address);

    function emergencyAdmin() external view returns (address);

    function performanceFee() external view returns (uint16);

    function performanceFeeRecipient() external view returns (address);

    function fullProfitUnlockDate() external view returns (uint256);

    function profitUnlockingRate() external view returns (uint256);

    function profitMaxUnlockTime() external view returns (uint256);

    function lastReport() external view returns (uint256);

    function isShutdown() external view returns (bool);

    function unlockedShares() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    function setPendingManagement(address) external;

    function acceptManagement() external;

    function setKeeper(address _keeper) external;

    function setEmergencyAdmin(address _emergencyAdmin) external;

    function setPerformanceFee(uint16 _performanceFee) external;

    function setPerformanceFeeRecipient(
        address _performanceFeeRecipient
    ) external;

    function setProfitMaxUnlockTime(uint256 _profitMaxUnlockTime) external;

    function setName(string calldata _newName) external;

    function shutdownStrategy() external;

    function emergencyWithdraw(uint256 _amount) external;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AuctionFactory, Auction} from "../Auctions/AuctionFactory.sol";
import {BaseSwapper} from "./BaseSwapper.sol";

/**
 *   @title AuctionSwapper
 *   @author yearn.fi
 *   @dev Helper contract for a strategy to use dutch auctions for token sales.
 *
 *   This contract is meant to be inherited by a V3 strategy in order
 *   to easily integrate dutch auctions into a contract for token swaps.
 *
 *   AUCTION SETUP:
 *   - The strategist needs to implement a way to call `_setAuction()`
 *     to set the auction contract address for token sales
 *   - `useAuction` defaults to false but is automatically set to true
 *     when a non-zero auction address is set via `_setAuction()`
 *   - Auctions can be manually enabled/disabled using `_setUseAuction()`
 *
 *   PERMISSIONLESS OPERATIONS:
 *   - `kickAuction()` is public and permissionless - anyone can trigger
 *     auctions when conditions are met (sufficient balance, auctions enabled)
 *   - This allows for automated auction triggering by bots or external systems
 *
 *   AUCTION TRIGGER INTEGRATION:
 *   - Implements `auctionTrigger()` for integration with CommonAuctionTrigger
 *   - Returns encoded calldata for `kickAuction()` when conditions are met
 *   - Provides smart logic to prevent duplicate auctions and handle edge cases
 *
 *   HOOKS:
 *   - The contract can act as a `hook` contract for the auction with the
 *     ability to override functions to implement custom hooks
 *   - If hooks are not desired, call `setHookFlags()` on the auction contract
 *     to avoid unnecessary gas for unused functions
 */
abstract contract AuctionSwapper is BaseSwapper {
    using SafeERC20 for ERC20;

    event AuctionSet(address indexed auction);
    event UseAuctionSet(bool indexed useAuction);

    /// @notice Address of the specific Auction contract this strategy uses for token sales.
    address public auction;

    /// @notice Whether to use auctions for token swaps.
    /// @dev Defaults to false but automatically set to true when setting a non-zero auction address.
    ///      Can be manually controlled via _setUseAuction() for fine-grained control.
    bool public useAuction;

    /// @notice Tokens that should never be kicked into auction.
    function protectedTokens() public view virtual returns (address[] memory);

    /*//////////////////////////////////////////////////////////////
                    AUCTION STARTING AND STOPPING
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the auction contract to use.
    /// @dev Automatically enables auctions (useAuction = true) when setting a non-zero address.
    /// @param _auction The auction contract address. Must have this contract as receiver.
    function _setAuction(address _auction) internal virtual {
        if (_auction != address(0)) {
            require(Auction(_auction).receiver() == address(this), "wrong receiver");
            // Automatically enable auctions when setting a non-zero auction address
            if (!useAuction) {
                useAuction = true;
                emit UseAuctionSet(true);
            }
        }
        auction = _auction;
        emit AuctionSet(_auction);
    }

    /// @notice Manually enable or disable auction usage.
    /// @dev Can be used to override the auto-enable behavior or temporarily disable auctions.
    /// @param _useAuction Whether to use auctions for token swaps.
    function _setUseAuction(bool _useAuction) internal virtual {
        useAuction = _useAuction;
        emit UseAuctionSet(_useAuction);
    }

    /**
     * @notice Return how much of a token could currently be kicked into auction.
     * @dev Includes both contract balance and tokens already in the auction contract.
     * @param _token The token that could be sold in auction.
     * @return The total amount of `_token` available for auction (0 if auctions disabled).
     */
    function kickable(address _token) public view virtual returns (uint256) {
        if (_isProtectedToken(_token)) return 0;
        if (!useAuction) return 0;

        address _auction = auction;
        if (_auction == address(0)) return 0;

        if (Auction(_auction).isActive(_token) && Auction(_auction).available(_token) > 0) {
            return 0;
        }

        return ERC20(_token).balanceOf(address(this)) + ERC20(_token).balanceOf(_auction);
    }

    /**
     * @notice Kick an auction for a given token (PERMISSIONLESS).
     * @dev Anyone can call this function to trigger auctions when conditions are met.
     *      Useful for automated systems, bots, or manual triggering.
     * @param _from The token to be sold in the auction.
     * @return The amount of tokens that were kicked into the auction.
     */
    function kickAuction(address _from) external virtual returns (uint256) {
        return _kickAuction(_from);
    }

    /**
     * @dev Internal function to kick an auction for a given token.
     * @param _from The token that was being sold.
     */
    function _kickAuction(address _from) internal virtual returns (uint256) {
        require(_from != address(this) && !_isProtectedToken(_from), "protected token");
        require(useAuction, "useAuction is false");
        address _auction = auction;

        if (Auction(_auction).isActive(_from)) {
            if (Auction(_auction).available(_from) > 0) {
                return 0;
            }

            Auction(_auction).settle(_from);
        }

        uint256 _balance = ERC20(_from).balanceOf(address(this));
        if (_balance > 0) {
            ERC20(_from).safeTransfer(_auction, _balance);
        }

        return Auction(_auction).kick(_from);
    }

    /*//////////////////////////////////////////////////////////////
                        AUCTION TRIGGER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Default auction trigger implementation for CommonAuctionTrigger integration.
     * @dev Returns whether an auction should be kicked and the encoded calldata to do so.
     *      This enables automated auction triggering through external trigger systems.
     * @param _from The token that could be sold in an auction.
     * @return shouldKick True if an auction should be kicked for this token.
     * @return data Encoded calldata for `kickAuction(_from)` if shouldKick is true,
     *              otherwise a descriptive error message explaining why not.
     */
    function auctionTrigger(address _from) external view virtual returns (bool shouldKick, bytes memory data) {
        if (_isProtectedToken(_from)) {
            return (false, bytes("protected token"));
        }

        address _auction = auction;
        if (_auction == address(0)) {
            return (false, bytes("No auction set"));
        }

        if (!useAuction) {
            return (false, bytes("Auctions disabled"));
        }

        uint256 kickableAmount = kickable(_from);

        if (
            kickableAmount != 0 && kickableAmount >= minAmountToSell[_from]
        ) {
            return (true, abi.encodeCall(this.kickAuction, (_from)));
        }

        return (false, bytes("not enough kickable"));
    }

    function _isProtectedToken(
        address _token
    ) internal view virtual returns (bool) {
        address[] memory _protectedTokens = protectedTokens();
        uint256 length = _protectedTokens.length;

        for (uint256 i; i < length; ++i) {
            if (_protectedTokens[i] == _token) return true;
        }

        return false;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @notice Accrual surface shared by Curvance cTokens and lending optimizers.
interface ICurvanceVault is IERC4626 {
    function accrueIfNeeded() external;

    function centralRegistry() external view returns (address);
}

interface ICurvanceMarket is ICurvanceVault {
    function marketManager() external view returns (address);

    function assetsHeld() external view returns (uint256);

    function marketOutstandingDebt() external view returns (uint256);
}

interface ICurvanceMarketManager {
    function actionsPaused(address market) external view returns (bool, bool, bool);

    function setMintPaused(address market, bool paused) external;

    function setRedeemPaused(bool paused) external;

    function redeemPaused() external view returns (uint8);
}

interface ICurvanceCentralRegistry {
    function emergencyCouncil() external view returns (address);

    function hasMarketPermissions(address account) external view returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ICurvanceVault} from "./ICurvance.sol";

/// @notice Minimal interface for the Curvance LendingOptimizer 4626 vault.
interface ILendingOptimizer is ICurvanceVault {
    /// @notice Deposit pause state machine.
    /// @dev 0 = uninitialized, 1 = active, 2 = paused. NOT a bool.
    function mintPaused() external view returns (uint8);

    /// @notice Pauses or unpauses deposits. Requires market permissions.
    function setMintPaused(bool state) external;

    /// @notice Performance fee in BPS charged on yield above the high watermark.
    function fee() external view returns (uint256);

    function numApprovedMarkets() external view returns (uint256);

    function getApprovedMarkets() external view returns (address[] memory);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IMerklDistributor {
    /// @notice Claims rewards for a given set of users
    /// @dev Anyone may call this function for anyone else, funds go to destination regardless, it's just a question of
    /// who provides the proof and pays the gas: `msg.sender` is used only for addresses that require a trusted operator
    /// @param users Recipient of tokens
    /// @param tokens ERC20 claimed
    /// @param amounts Amount of tokens that will be sent to the corresponding users
    /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

    /// @notice Toggles whitelisting for a given user and a given operator
    /// @dev When an operator is whitelisted for a user, the operator can claim rewards on behalf of the user
    function toggleOperator(address user, address operator) external;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TokenizedStrategy interface used for internal view delegateCalls.
import {ITokenizedStrategy} from "./interfaces/ITokenizedStrategy.sol";

/**
 * @title YearnV3 Base Strategy
 * @author yearn.finance
 * @notice
 *  BaseStrategy implements all of the required functionality to
 *  seamlessly integrate with the `TokenizedStrategy` implementation contract
 *  allowing anyone to easily build a fully permissionless ERC-4626 compliant
 *  Vault by inheriting this contract and overriding three simple functions.

 *  It utilizes an immutable proxy pattern that allows the BaseStrategy
 *  to remain simple and small. All standard logic is held within the
 *  `TokenizedStrategy` and is reused over any n strategies all using the
 *  `fallback` function to delegatecall the implementation so that strategists
 *  can only be concerned with writing their strategy specific code.
 *
 *  This contract should be inherited and the three main abstract methods
 *  `_deployFunds`, `_freeFunds` and `_harvestAndReport` implemented to adapt
 *  the Strategy to the particular needs it has to generate yield. There are
 *  other optional methods that can be implemented to further customize
 *  the strategy if desired.
 *
 *  All default storage for the strategy is controlled and updated by the
 *  `TokenizedStrategy`. The implementation holds a storage struct that
 *  contains all needed global variables in a manual storage slot. This
 *  means strategists can feel free to implement their own custom storage
 *  variables as they need with no concern of collisions. All global variables
 *  can be viewed within the Strategy by a simple call using the
 *  `TokenizedStrategy` variable. IE: TokenizedStrategy.globalVariable();.
 */
abstract contract BaseStrategy {
    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Used on TokenizedStrategy callback functions to make sure it is post
     * a delegateCall from this address to the TokenizedStrategy.
     */
    modifier onlySelf() {
        _onlySelf();
        _;
    }

    /**
     * @dev Use to assure that the call is coming from the strategies management.
     */
    modifier onlyManagement() {
        TokenizedStrategy.requireManagement(msg.sender);
        _;
    }

    /**
     * @dev Use to assure that the call is coming from either the strategies
     * management or the keeper.
     */
    modifier onlyKeepers() {
        TokenizedStrategy.requireKeeperOrManagement(msg.sender);
        _;
    }

    /**
     * @dev Use to assure that the call is coming from either the strategies
     * management or the emergency admin.
     */
    modifier onlyEmergencyAuthorized() {
        TokenizedStrategy.requireEmergencyAuthorized(msg.sender);
        _;
    }

    /**
     * @dev Require that the msg.sender is this address.
     */
    function _onlySelf() internal view {
        require(msg.sender == address(this), "!self");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This is the address of the TokenizedStrategy implementation
     * contract that will be used by all strategies to handle the
     * accounting, logic, storage etc.
     *
     * Any external calls to the that don't hit one of the functions
     * defined in this base or the strategy will end up being forwarded
     * through the fallback function, which will delegateCall this address.
     *
     * This address should be the same for every strategy, never be adjusted
     * and always be checked before any integration with the Strategy.
     */
    address public constant tokenizedStrategyAddress =
        0xD377919FA87120584B21279a491F82D5265A139c;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Underlying asset the Strategy is earning yield on.
     * Stored here for cheap retrievals within the strategy.
     */
    ERC20 internal immutable asset;

    /**
     * @dev This variable is set to address(this) during initialization of each strategy.
     *
     * This can be used to retrieve storage data within the strategy
     * contract as if it were a linked library.
     *
     *       i.e. uint256 totalAssets = TokenizedStrategy.totalAssets()
     *
     * Using address(this) will mean any calls using this variable will lead
     * to a call to itself. Which will hit the fallback function and
     * delegateCall that to the actual TokenizedStrategy.
     */
    ITokenizedStrategy internal immutable TokenizedStrategy;

    /**
     * @notice Used to initialize the strategy on deployment.
     *
     * This will set the `TokenizedStrategy` variable for easy
     * internal view calls to the implementation. As well as
     * initializing the default storage variables based on the
     * parameters and using the deployer for the permissioned roles.
     *
     * @param _asset Address of the underlying asset.
     * @param _name Name the strategy will use.
     */
    constructor(address _asset, string memory _name) {
        asset = ERC20(_asset);

        // Set instance of the implementation for internal use.
        TokenizedStrategy = ITokenizedStrategy(address(this));

        // Initialize the strategy's storage variables.
        _delegateCall(
            abi.encodeCall(
                ITokenizedStrategy.initialize,
                (_asset, _name, msg.sender, msg.sender, msg.sender)
            )
        );

        // Store the tokenizedStrategyAddress at the standard implementation
        // address storage slot so etherscan picks up the interface. This gets
        // stored on initialization and never updated.
        assembly {
            sstore(
                // keccak256('eip1967.proxy.implementation' - 1)
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,
                tokenizedStrategyAddress
            )
        }
    }

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Can deploy up to '_amount' of 'asset' in the yield source.
     *
     * This function is called at the end of a {deposit} or {mint}
     * call. Meaning that unless a whitelist is implemented it will
     * be entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * @param _amount The amount of 'asset' that the strategy can attempt
     * to deposit in the yield source.
     */
    function _deployFunds(uint256 _amount) internal virtual;

    /**
     * @dev Should attempt to free the '_amount' of 'asset'.
     *
     * NOTE: The amount of 'asset' that is already loose has already
     * been accounted for.
     *
     * This function is called during {withdraw} and {redeem} calls.
     * Meaning that unless a whitelist is implemented it will be
     * entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * Should not rely on asset.balanceOf(address(this)) calls other than
     * for diff accounting purposes.
     *
     * Any difference between `_amount` and what is actually freed will be
     * counted as a loss and passed on to the withdrawer. This means
     * care should be taken in times of illiquidity. It may be better to revert
     * if withdraws are simply illiquid so not to realize incorrect losses.
     *
     * @param _amount, The amount of 'asset' to be freed.
     */
    function _freeFunds(uint256 _amount) internal virtual;

    /**
     * @dev Internal function to harvest all rewards, redeploy any idle
     * funds and return an accurate accounting of all funds currently
     * held by the Strategy.
     *
     * This should do any needed harvesting, rewards selling, accrual,
     * redepositing etc. to get the most accurate view of current assets.
     *
     * NOTE: All applicable assets including loose assets should be
     * accounted for in this function.
     *
     * Care should be taken when relying on oracles or swap values rather
     * than actual amounts as all Strategy profit/loss accounting will
     * be done based on this returned value.
     *
     * This can still be called post a shutdown, a strategist can check
     * `TokenizedStrategy.isShutdown()` to decide if funds should be
     * redeployed or simply realize any profits/losses.
     *
     * @return _totalAssets A trusted and accurate account for the total
     * amount of 'asset' the strategy currently holds including idle funds.
     */
    function _harvestAndReport()
        internal
        virtual
        returns (uint256 _totalAssets);

    /*//////////////////////////////////////////////////////////////
                    OPTIONAL TO OVERRIDE BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Optional function for strategist to override that can
     *  be called in between reports.
     *
     * If '_tend' is used tendTrigger() will also need to be overridden.
     *
     * This call can only be called by a permissioned role so may be
     * through protected relays.
     *
     * This can be used to harvest and compound rewards, deposit idle funds,
     * perform needed position maintenance or anything else that doesn't need
     * a full report for.
     *
     *   EX: A strategy that can not deposit funds without getting
     *       sandwiched can use the tend when a certain threshold
     *       of idle to totalAssets has been reached.
     *
     * This will have no effect on PPS of the strategy till report() is called.
     *
     * @param _totalIdle The current amount of idle funds that are available to deploy.
     */
    function _tend(uint256 _totalIdle) internal virtual {}

    /**
     * @dev Optional trigger to override if tend() will be used by the strategy.
     * This must be implemented if the strategy hopes to invoke _tend().
     *
     * @return . Should return true if tend() should be called by keeper or false if not.
     */
    function _tendTrigger() internal view virtual returns (bool) {
        return false;
    }

    /**
     * @notice Returns if tend() should be called by a keeper.
     *
     * @return . Should return true if tend() should be called by keeper or false if not.
     * @return . Calldata for the tend call.
     */
    function tendTrigger() external view virtual returns (bool, bytes memory) {
        return (
            // Return the status of the tend trigger.
            _tendTrigger(),
            // And the needed calldata either way.
            abi.encodeWithSelector(ITokenizedStrategy.tend.selector)
        );
    }

    /**
     * @notice Gets the max amount of `asset` that an address can deposit.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any deposit or mints to enforce
     * any limits desired by the strategist. This can be used for either a
     * traditional deposit limit or for implementing a whitelist etc.
     *
     *   EX:
     *      if(isAllowed[_owner]) return super.availableDepositLimit(_owner);
     *
     * This does not need to take into account any conversion rates
     * from shares to assets. But should know that any non max uint256
     * amounts may be converted to shares. So it is recommended to keep
     * custom amounts low enough as not to cause overflow when multiplied
     * by `totalSupply`.
     *
     * @param . The address that is depositing into the strategy.
     * @return . The available amount the `_owner` can deposit in terms of `asset`
     */
    function availableDepositLimit(
        address /*_owner*/
    ) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Gets the max amount of `asset` that can be withdrawn.
     * @dev Defaults to an unlimited amount for any address. But can
     * be overridden by strategists.
     *
     * This function will be called before any withdraw or redeem to enforce
     * any limits desired by the strategist. This can be used for illiquid
     * or sandwichable strategies. It should never be lower than `totalIdle`.
     *
     *   EX:
     *       return TokenIzedStrategy.totalIdle();
     *
     * This does not need to take into account the `_owner`'s share balance
     * or conversion rates from shares to assets.
     *
     * @param . The address that is withdrawing from the strategy.
     * @return . The available amount that can be withdrawn in terms of `asset`
     */
    function availableWithdrawLimit(
        address /*_owner*/
    ) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev Optional function for a strategist to override that will
     * allow management to manually withdraw deployed funds from the
     * yield source if a strategy is shutdown.
     *
     * This should attempt to free `_amount`, noting that `_amount` may
     * be more than is currently deployed.
     *
     * NOTE: This will not realize any profits or losses. A separate
     * {report} will be needed in order to record any profit/loss. If
     * a report may need to be called after a shutdown it is important
     * to check if the strategy is shutdown during {_harvestAndReport}
     * so that it does not simply re-deploy all funds that had been freed.
     *
     * EX:
     *   if(freeAsset > 0 && !TokenizedStrategy.isShutdown()) {
     *       depositFunds...
     *    }
     *
     * @param _amount The amount of asset to attempt to free.
     */
    function _emergencyWithdraw(uint256 _amount) internal virtual {}

    /*//////////////////////////////////////////////////////////////
                        TokenizedStrategy HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Can deploy up to '_amount' of 'asset' in yield source.
     * @dev Callback for the TokenizedStrategy to call during a {deposit}
     * or {mint} to tell the strategy it can deploy funds.
     *
     * Since this can only be called after a {deposit} or {mint}
     * delegateCall to the TokenizedStrategy msg.sender == address(this).
     *
     * Unless a whitelist is implemented this will be entirely permissionless
     * and thus can be sandwiched or otherwise manipulated.
     *
     * @param _amount The amount of 'asset' that the strategy can
     * attempt to deposit in the yield source.
     */
    function deployFunds(uint256 _amount) external virtual onlySelf {
        _deployFunds(_amount);
    }

    /**
     * @notice Should attempt to free the '_amount' of 'asset'.
     * @dev Callback for the TokenizedStrategy to call during a withdraw
     * or redeem to free the needed funds to service the withdraw.
     *
     * This can only be called after a 'withdraw' or 'redeem' delegateCall
     * to the TokenizedStrategy so msg.sender == address(this).
     *
     * @param _amount The amount of 'asset' that the strategy should attempt to free up.
     */
    function freeFunds(uint256 _amount) external virtual onlySelf {
        _freeFunds(_amount);
    }

    /**
     * @notice Returns the accurate amount of all funds currently
     * held by the Strategy.
     * @dev Callback for the TokenizedStrategy to call during a report to
     * get an accurate accounting of assets the strategy controls.
     *
     * This can only be called after a report() delegateCall to the
     * TokenizedStrategy so msg.sender == address(this).
     *
     * @return . A trusted and accurate account for the total amount
     * of 'asset' the strategy currently holds including idle funds.
     */
    function harvestAndReport() external virtual onlySelf returns (uint256) {
        return _harvestAndReport();
    }

    /**
     * @notice Will call the internal '_tend' when a keeper tends the strategy.
     * @dev Callback for the TokenizedStrategy to initiate a _tend call in the strategy.
     *
     * This can only be called after a tend() delegateCall to the TokenizedStrategy
     * so msg.sender == address(this).
     *
     * We name the function `tendThis` so that `tend` calls are forwarded to
     * the TokenizedStrategy.

     * @param _totalIdle The amount of current idle funds that can be
     * deployed during the tend
     */
    function tendThis(uint256 _totalIdle) external virtual onlySelf {
        _tend(_totalIdle);
    }

    /**
     * @notice Will call the internal '_emergencyWithdraw' function.
     * @dev Callback for the TokenizedStrategy during an emergency withdraw.
     *
     * This can only be called after a emergencyWithdraw() delegateCall to
     * the TokenizedStrategy so msg.sender == address(this).
     *
     * We name the function `shutdownWithdraw` so that `emergencyWithdraw`
     * calls are forwarded to the TokenizedStrategy.
     *
     * @param _amount The amount of asset to attempt to free.
     */
    function shutdownWithdraw(uint256 _amount) external virtual onlySelf {
        _emergencyWithdraw(_amount);
    }

    /**
     * @dev Function used to delegate call the TokenizedStrategy with
     * certain `_calldata` and return any return values.
     *
     * This is used to setup the initial storage of the strategy, and
     * can be used by strategist to forward any other call to the
     * TokenizedStrategy implementation.
     *
     * @param _calldata The abi encoded calldata to use in delegatecall.
     * @return . The return value if the call was successful in bytes.
     */
    function _delegateCall(
        bytes memory _calldata
    ) internal returns (bytes memory) {
        // Delegate call the tokenized strategy with provided calldata.
        (bool success, bytes memory result) = tokenizedStrategyAddress
            .delegatecall(_calldata);

        // If the call reverted. Return the error.
        if (!success) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }

        // Return the result.
        return result;
    }

    /**
     * @dev Execute a function on the TokenizedStrategy and return any value.
     *
     * This fallback function will be executed when any of the standard functions
     * defined in the TokenizedStrategy are called since they wont be defined in
     * this contract.
     *
     * It will delegatecall the TokenizedStrategy implementation with the exact
     * calldata and return any relevant values.
     *
     */
    fallback() external {
        // load our target address
        address _tokenizedStrategyAddress = tokenizedStrategyAddress;
        // Execute external function using delegatecall and return any value.
        assembly {
            // Copy function selector and any arguments.
            calldatacopy(0, 0, calldatasize())
            // Execute function delegatecall.
            let result := delegatecall(
                gas(),
                _tokenizedStrategyAddress,
                0,
                calldatasize(),
                0,
                0
            )
            // Get any return value
            returndatacopy(0, 0, returndatasize())
            // Return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";
import "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 *
 * _Available since v4.7._
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Auction} from "./Auction.sol";
import {ClonableCreate2} from "../utils/ClonableCreate2.sol";

/// @title AuctionFactory
/// @notice Deploy a new Auction.
contract AuctionFactory is ClonableCreate2 {
    event DeployedNewAuction(address indexed auction, address indexed want);

    /// @notice The amount to start the auction with.
    uint256 public constant DEFAULT_STARTING_PRICE = 1_000_000;

    /// @notice Full array of all auctions deployed through this factory.
    address[] public auctions;

    constructor() {
        // Deploy the original
        original = address(new Auction());
    }

    function version() external pure returns (string memory) {
        return "1.0.4";
    }

    /**
     * @notice Creates a new auction contract.
     * @param _want Address of the token users will bid with.
     * @return _newAuction Address of the newly created auction contract.
     */
    function createNewAuction(address _want) external returns (address) {
        return _createNewAuction(_want, msg.sender, msg.sender, DEFAULT_STARTING_PRICE, bytes32(0));
    }

    /**
     * @notice Creates a new auction contract.
     * @param _want Address of the token users will bid with.
     * @param _receiver Address that will receive the funds in the auction.
     * @return _newAuction Address of the newly created auction contract.
     */
    function createNewAuction(address _want, address _receiver) external returns (address) {
        return _createNewAuction(_want, _receiver, msg.sender, DEFAULT_STARTING_PRICE, bytes32(0));
    }

    /**
     * @notice Creates a new auction contract.
     * @param _want Address of the token users will bid with.
     * @param _receiver Address that will receive the funds in the auction.
     * @param _governance Address allowed to enable and disable auctions.
     * @return _newAuction Address of the newly created auction contract.
     */
    function createNewAuction(address _want, address _receiver, address _governance) external returns (address) {
        return _createNewAuction(_want, _receiver, _governance, DEFAULT_STARTING_PRICE, bytes32(0));
    }

    /**
     * @notice Creates a new auction contract.
     * @param _want Address of the token users will bid with.
     * @param _receiver Address that will receive the funds in the auction.
     * @param _governance Address allowed to enable and disable auctions.
     * @param _startingPrice Starting price for the auction (no decimals).
     *  NOTE: The starting price should be without decimals (1k == 1_000).
     * @return _newAuction Address of the newly created auction contract.
     */
    function createNewAuction(address _want, address _receiver, address _governance, uint256 _startingPrice)
        external
        returns (address)
    {
        return _createNewAuction(_want, _receiver, _governance, _startingPrice, bytes32(0));
    }

    /**
     * @notice Creates a new auction contract.
     * @param _want Address of the token users will bid with.
     * @param _receiver Address that will receive the funds in the auction.
     * @param _governance Address allowed to enable and disable auctions.
     * @param _startingPrice Starting price for the auction (no decimals).
     * @param _salt The salt to use for deterministic deployment.
     * @return _newAuction Address of the newly created auction contract.
     */
    function createNewAuction(
        address _want,
        address _receiver,
        address _governance,
        uint256 _startingPrice,
        bytes32 _salt
    ) external returns (address) {
        return _createNewAuction(_want, _receiver, _governance, _startingPrice, _salt);
    }

    /**
     * @dev Deploys and initializes a new Auction
     */
    function _createNewAuction(
        address _want,
        address _receiver,
        address _governance,
        uint256 _startingPrice,
        bytes32 _salt
    ) internal returns (address _newAuction) {
        if (_salt == bytes32(0)) {
            // If none set, generate unique salt. msg.sender gets encoded in getSalt()
            _salt = keccak256(abi.encodePacked(_want, _receiver, _governance));
        }

        _newAuction = _cloneCreate2(_salt);

        Auction(_newAuction).initialize(_want, _receiver, _governance, _startingPrice);

        auctions.push(_newAuction);

        emit DeployedNewAuction(_newAuction, _want);
    }

    /**
     * @notice Get the full list of auctions deployed through this factory.
     */
    function getAllAuctions() external view returns (address[] memory) {
        return auctions;
    }

    /**
     * @notice Get the total number of auctions deployed through this factory.
     */
    function numberOfAuctions() external view returns (uint256) {
        return auctions.length;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

/**
 * @title BaseSwapper
 * @author yearn.fi
 * @dev Base contract for all swapper contracts except TradeFactorySwapper.
 *      Contains the common minAmountToSell mapping that most swappers need.
 */
contract BaseSwapper {
    /// @notice Minimum amount of tokens to sell in a swap.
    mapping(address => uint256) public minAmountToSell;

    /**
     * @dev Set the minimum amount to sell in a swap.
     * @param _token Token to set the minimum for.
     * @param _minAmountToSell Minimum amount of tokens needed to execute a swap.
     */
    function _setMinAmountToSell(
        address _token,
        uint256 _minAmountToSell
    ) internal virtual {
        minAmountToSell[_token] = _minAmountToSell;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Maths} from "../libraries/Maths.sol";
import {ITaker} from "../interfaces/ITaker.sol";
import {GPv2Order} from "../libraries/GPv2Order.sol";
import {Governance2Step} from "../utils/Governance2Step.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICowSettlement {
    function domainSeparator() external view returns (bytes32);
}

/**
 *   @title Auction
 *   @author yearn.fi
 *   @notice General use dutch auction contract for token sales.
 */
contract Auction is Governance2Step, ReentrancyGuard {
    using GPv2Order for GPv2Order.Data;
    using SafeERC20 for ERC20;

    /// @notice Emitted when a new auction is enabled
    event AuctionEnabled(address indexed from, address indexed to);

    /// @notice Emitted when an auction is disabled.
    event AuctionDisabled(address indexed from, address indexed to);

    /// @notice Emitted when auction has been kicked.
    event AuctionKicked(address indexed from, uint256 available);

    /// @notice Emitted when the receiver is updated.
    event UpdatedReceiver(address indexed receiver);

    /// @notice Emitted when the minimum price is updated.
    event UpdatedMinimumPrice(uint256 indexed minimumPrice);

    /// @notice Emitted when the starting price is updated.
    event UpdatedStartingPrice(uint256 indexed startingPrice);

    /// @notice Emitted when the step decay rate is updated.
    event UpdatedStepDecayRate(uint256 indexed stepDecayRate);

    /// @notice Emitted when the step duration is updated.
    event UpdatedStepDuration(uint256 indexed stepDuration);

    /// @notice Emitted when the auction is settled.
    event AuctionSettled(address indexed from);

    /// @notice Emitted when the auction is swept.
    event AuctionSwept(address indexed token, address indexed to);

    /// @dev Store address and scaler in one slot.
    struct TokenInfo {
        address tokenAddress;
        uint96 scaler;
    }

    /// @notice Store all the auction specific information.
    struct AuctionInfo {
        uint64 kicked;
        uint64 scaler;
        uint128 initialAvailable;
    }

    uint256 internal constant WAD = 1e18;

    address internal constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    address internal constant VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    /// @notice The time that each auction lasts.
    uint256 internal constant AUCTION_LENGTH = 1 days;

    /// @notice Struct to hold the info for `want`.
    TokenInfo internal wantInfo;

    /// @notice Whether only governance can kick auctions.
    /// @dev Default is false.
    bool public governanceOnlyKick;

    /// @notice The address that will receive the funds in the auction.
    address public receiver;

    /// @notice The minimum price for the auction, scaled to 1e18.
    /// @dev If the price per auction goes below this, the auction is considered inactive.
    /// @dev Default is 0 (i.e. no minimum).
    uint256 public minimumPrice;

    /// @notice The amount to start the auction at.
    /// @dev This is an unscaled "lot size" essentially to start the pricing in "want".
    ///   The kicked amount of _from is divided by this to get the per auction initial price.
    uint256 public startingPrice;

    /// @notice The time period for each price step in seconds.
    uint256 public stepDuration;

    /// @notice The decay rate per step in basis points (e.g., 50 for 0.5% decrease per step).
    uint256 public stepDecayRate;

    /// @notice Mapping from `from` token to its struct.
    mapping(address => AuctionInfo) public auctions;

    /// @notice Array of all the enabled auction for this contract.
    address[] public enabledAuctions;

    constructor() Governance2Step(msg.sender) {}

    /**
     * @notice Initializes the Auction contract with initial parameters.
     * @param _want Address this auction is selling to.
     * @param _receiver Address that will receive the funds from the auction.
     * @param _governance Address of the contract governance.
     * @param _startingPrice Starting price for each auction.
     */
    function initialize(address _want, address _receiver, address _governance, uint256 _startingPrice) public virtual {
        require(stepDecayRate == 0, "initialized");
        require(_want != address(0), "ZERO ADDRESS");
        require(_startingPrice != 0, "starting price");
        require(_receiver != address(0), "receiver");
        // Cannot have more than 18 decimals.
        uint256 decimals = ERC20(_want).decimals();
        require(decimals <= 18, "unsupported decimals");

        // Set variables
        wantInfo = TokenInfo({tokenAddress: _want, scaler: uint96(WAD / 10 ** decimals)});

        receiver = _receiver;
        governance = _governance;
        emit GovernanceTransferred(address(0), _governance);
        startingPrice = _startingPrice;
        emit UpdatedStartingPrice(_startingPrice);

        // Default to 50bps every 60 seconds
        stepDuration = 60;
        emit UpdatedStepDuration(stepDuration);
        stepDecayRate = 50; // 50 basis points = 0.5% decay per step
        emit UpdatedStepDecayRate(stepDecayRate);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function version() external pure returns (string memory) {
        return "1.0.4";
    }

    /**
     * @notice Get the address of this auctions want token.
     * @return . The want token.
     */
    function want() public view virtual returns (address) {
        return wantInfo.tokenAddress;
    }

    function auctionLength() public view virtual returns (uint256) {
        return AUCTION_LENGTH;
    }

    /**
     * @notice Get the available amount for the auction.
     * @param _from The address of the token to be auctioned.
     * @return . The available amount for the auction.
     */
    function available(address _from) public view virtual returns (uint256) {
        if (!isActive(_from)) return 0;

        return Maths.min(auctions[_from].initialAvailable, ERC20(_from).balanceOf(address(this)));
    }

    /**
     * @notice Get the kicked timestamp for the auction.
     * @param _from The address of the token to be auctioned.
     * @return . The kicked timestamp for the auction.
     */
    function kicked(address _from) external view virtual returns (uint256) {
        return auctions[_from].kicked;
    }

    /**
     * @notice Check if the auction is active.
     * @param _from The address of the token to be auctioned.
     * @return . Whether the auction is active.
     */
    function isActive(address _from) public view virtual returns (bool) {
        return price(_from, block.timestamp) > 0;
    }

    /**
     * @notice Get all the enabled auctions.
     */
    function getAllEnabledAuctions() external view virtual returns (address[] memory) {
        return enabledAuctions;
    }

    /**
     * @notice Get the pending amount available for the next auction.
     * @dev Defaults to the auctions balance of the from token if no hook.
     * @param _from The address of the token to be auctioned.
     * @return uint256 The amount that can be kicked into the auction.
     */
    function kickable(address _from) external view virtual returns (uint256) {
        // If not enough time has passed then `kickable` is 0.
        if (isActive(_from)) return 0;

        // Use the full balance of this contract.
        return ERC20(_from).balanceOf(address(this));
    }

    /**
     * @notice Gets the amount of `want` needed to buy the available amount of `from`.
     * @param _from The address of the token to be auctioned.
     * @return . The amount of `want` needed to fulfill the take amount.
     */
    function getAmountNeeded(address _from) external view virtual returns (uint256) {
        return _getAmountNeeded(auctions[_from], available(_from), block.timestamp);
    }

    /**
     * @notice Gets the amount of `want` needed to buy a specific amount of `from`.
     * @param _from The address of the token to be auctioned.
     * @param _amountToTake The amount of `from` to take in the auction.
     * @return . The amount of `want` needed to fulfill the take amount.
     */
    function getAmountNeeded(address _from, uint256 _amountToTake) external view virtual returns (uint256) {
        return _getAmountNeeded(auctions[_from], _amountToTake, block.timestamp);
    }

    /**
     * @notice Gets the amount of `want` needed to buy a specific amount of `from` at a specific timestamp.
     * @param _from The address of the token to be auctioned.
     * @param _amountToTake The amount `from` to take in the auction.
     * @param _timestamp The specific timestamp for calculating the amount needed.
     * @return . The amount of `want` needed to fulfill the take amount.
     */
    function getAmountNeeded(address _from, uint256 _amountToTake, uint256 _timestamp)
        external
        view
        virtual
        returns (uint256)
    {
        return _getAmountNeeded(auctions[_from], _amountToTake, _timestamp);
    }

    /**
     * @dev Return the amount of `want` needed to buy `_amountToTake`.
     */
    function _getAmountNeeded(AuctionInfo memory _auction, uint256 _amountToTake, uint256 _timestamp)
        internal
        view
        virtual
        returns (uint256)
    {
        return
        // Scale _amountToTake to 1e18
        (_amountToTake
                * _auction.scaler
                // Price is always 1e18
                * _price(_auction.kicked, _auction.initialAvailable * _auction.scaler, _timestamp)) / 1e18
            // Scale back down to want.
            / wantInfo.scaler;
    }

    /**
     * @notice Gets the price of the auction at the current timestamp.
     * @param _from The address of the token to be auctioned.
     * @return . The price of the auction.
     */
    function price(address _from) external view virtual returns (uint256) {
        return price(_from, block.timestamp);
    }

    /**
     * @notice Gets the price of the auction at a specific timestamp.
     * @param _from The address of the token to be auctioned.
     * @param _timestamp The specific timestamp for calculating the price.
     * @return . The price of the auction.
     */
    function price(address _from, uint256 _timestamp) public view virtual returns (uint256) {
        // Get unscaled price and scale it down.
        return _price(auctions[_from].kicked, auctions[_from].initialAvailable * auctions[_from].scaler, _timestamp)
            / wantInfo.scaler;
    }

    /**
     * @dev Internal function to calculate the scaled price based on auction parameters.
     * @param _kicked The timestamp the auction was kicked.
     * @param _available The initial available amount scaled 1e18.
     * @param _timestamp The specific timestamp for calculating the price.
     * @return . The calculated price scaled to 1e18.
     */
    function _price(uint256 _kicked, uint256 _available, uint256 _timestamp) internal view virtual returns (uint256) {
        if (_available == 0) return 0;

        uint256 secondsElapsed = _timestamp - _kicked;

        if (secondsElapsed > AUCTION_LENGTH) return 0;

        // Calculate the number of price steps that have passed
        uint256 steps = secondsElapsed / stepDuration;

        // Convert basis points to ray multiplier (e.g., 50 bps = 0.995 * 1e27)
        // rayMultiplier = 1e27 - (basisPoints * 1e23)
        uint256 rayMultiplier = 1e27 - (stepDecayRate * 1e23);

        // Calculate the decay multiplier using the configurable decay rate per step
        uint256 decayMultiplier = Maths.rpow(rayMultiplier, steps);

        // Calculate initial price per token
        uint256 initialPrice = Maths.wdiv(startingPrice * 1e18, _available);

        // Apply the decay to get the current price
        uint256 currentPrice = Maths.rmul(initialPrice, decayMultiplier);

        // Return price `0` if below the minimum price
        return currentPrice < minimumPrice ? 0 : currentPrice;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables a new auction.
     * @param _from The address of the token to be auctioned.
     */
    function enable(address _from) external virtual onlyGovernance {
        address _want = want();
        require(_from != address(0) && _from != _want, "ZERO ADDRESS");
        require(auctions[_from].scaler == 0, "already enabled");

        // Cannot have more than 18 decimals.
        uint256 decimals = ERC20(_from).decimals();
        require(decimals <= 18, "unsupported decimals");

        // Store all needed info.
        auctions[_from].scaler = uint64(WAD / 10 ** decimals);

        ERC20(_from).forceApprove(VAULT_RELAYER, type(uint256).max);

        // Add to the array.
        enabledAuctions.push(_from);

        emit AuctionEnabled(_from, _want);
    }

    /**
     * @notice Disables an existing auction.
     * @dev Only callable by governance.
     * @param _from The address of the token being sold.
     */
    function disable(address _from) external virtual {
        disable(_from, 0);
    }

    /**
     * @notice Disables an existing auction.
     * @dev Only callable by governance.
     * @param _from The address of the token being sold.
     * @param _index The index the auctionId is at in the array.
     */
    function disable(address _from, uint256 _index) public virtual onlyGovernance {
        // Make sure the auction was enabled.
        require(auctions[_from].scaler != 0, "not enabled");

        // Remove the struct.
        delete auctions[_from];

        ERC20(_from).forceApprove(VAULT_RELAYER, 0);

        // Remove the auction ID from the array.
        address[] memory _enabledAuctions = enabledAuctions;
        if (_enabledAuctions[_index] != _from) {
            // If the _index given is not the id find it.
            for (uint256 i = 0; i < _enabledAuctions.length; ++i) {
                if (_enabledAuctions[i] == _from) {
                    _index = i;
                    break;
                }
            }
        }

        // Move the id to the last spot if not there.
        if (_index < _enabledAuctions.length - 1) {
            _enabledAuctions[_index] = _enabledAuctions[_enabledAuctions.length - 1];
            // Update the array.
            enabledAuctions = _enabledAuctions;
        }

        // Pop the id off the array.
        enabledAuctions.pop();

        emit AuctionDisabled(_from, want());
    }

    function isAnActiveAuction() public view returns (bool) {
        address[] memory _enabledAuctions = enabledAuctions;
        for (uint256 i = 0; i < _enabledAuctions.length; ++i) {
            if (isActive(_enabledAuctions[i])) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Sets whether only governance can kick auctions.
     * @param _governanceOnlyKick The new governance only kick setting.
     */
    function setGovernanceOnlyKick(bool _governanceOnlyKick) external virtual onlyGovernance {
        governanceOnlyKick = _governanceOnlyKick;
    }

    /**
     * @notice Sets the receiver address for the auction funds.
     * @param _receiver The new receiver address.
     */
    function setReceiver(address _receiver) external virtual onlyGovernance {
        require(_receiver != address(0), "ZERO ADDRESS");

        // Don't change the receiver when an auction is active.
        require(!isAnActiveAuction(), "active auction");

        receiver = _receiver;

        emit UpdatedReceiver(_receiver);
    }

    /**
     * @notice Sets the minimum price for the auction.
     * @dev If the price per auction goes below this, the auction is considered inactive.
     * @dev Default is 0 (i.e. no minimum).
     * @param _minimumPrice The new minimum price per auction, scaled to 1e18.
     */
    function setMinimumPrice(uint256 _minimumPrice) external virtual onlyGovernance {
        // Don't change the min price when an auction is active.
        require(!isAnActiveAuction(), "active auction");

        minimumPrice = _minimumPrice;

        emit UpdatedMinimumPrice(_minimumPrice);
    }

    /**
     * @notice Sets the starting price for the auction.
     * @dev This is an unscaled "lot size" essentially to start the pricing in "want".
     *   The kicked amount of _from is divided by this to get the per auction initial price.
     * @param _startingPrice The new starting price for the auction.
     */
    function setStartingPrice(uint256 _startingPrice) external virtual onlyGovernance {
        require(_startingPrice != 0, "starting price");

        // Don't change the price when an auction is active.
        require(!isAnActiveAuction(), "active auction");

        startingPrice = _startingPrice;

        emit UpdatedStartingPrice(_startingPrice);
    }

    /**
     * @notice Sets the step decay rate for the auction.
     * @dev The decay rate is in basis points (e.g., 50 for 0.5% decay per step).
     * @param _stepDecayRate The new decay rate per step in basis points (max 10000 = 100%).
     */
    function setStepDecayRate(uint256 _stepDecayRate) external virtual onlyGovernance {
        require(_stepDecayRate > 0 && _stepDecayRate < 10_000, "invalid decay rate");

        // Don't change the decay rate when an auction is active.
        require(!isAnActiveAuction(), "active auction");

        stepDecayRate = _stepDecayRate;

        emit UpdatedStepDecayRate(_stepDecayRate);
    }

    /**
     * @notice Sets the step duration for the auction.
     * @param _stepDuration The new step duration in seconds.
     */
    function setStepDuration(uint256 _stepDuration) external virtual onlyGovernance {
        require(_stepDuration != 0 && _stepDuration < AUCTION_LENGTH, "invalid step duration");

        require(!isAnActiveAuction(), "active auction");

        stepDuration = _stepDuration;

        emit UpdatedStepDuration(_stepDuration);
    }

    /*//////////////////////////////////////////////////////////////
                      PARTICIPATE IN AUCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Kicks off an auction, updating its status and making funds available for bidding.
     * @param _from The address of the token to be auctioned.
     * @return _available The available amount for bidding on in the auction.
     */
    function kick(address _from) external virtual nonReentrant returns (uint256 _available) {
        return _kick(_from);
    }

    function _kick(address _from) internal virtual returns (uint256 _available) {
        if (governanceOnlyKick) _checkGovernance();

        require(auctions[_from].scaler != 0, "not enabled");
        require(!isActive(_from), "too soon");

        // Just use current balance.
        _available = ERC20(_from).balanceOf(address(this));

        require(_available != 0, "nothing to kick");

        // Update the auctions status.
        auctions[_from].kicked = uint64(block.timestamp);
        auctions[_from].initialAvailable = uint128(_available);

        emit AuctionKicked(_from, _available);
    }

    /**
     * @notice Take the token being sold in a live auction.
     * @dev Defaults to taking the full amount and sending to the msg sender.
     * @param _from The address of the token to be auctioned.
     * @return . The amount of fromToken taken in the auction.
     */
    function take(address _from) external virtual returns (uint256) {
        return _take(_from, type(uint256).max, msg.sender, new bytes(0));
    }

    /**
     * @notice Take the token being sold in a live auction with a specified maximum amount.
     * @dev Will send the funds to the msg sender.
     * @param _from The address of the token to be auctioned.
     * @param _maxAmount The maximum amount of fromToken to take in the auction.
     * @return . The amount of fromToken taken in the auction.
     */
    function take(address _from, uint256 _maxAmount) external virtual returns (uint256) {
        return _take(_from, _maxAmount, msg.sender, new bytes(0));
    }

    /**
     * @notice Take the token being sold in a live auction.
     * @param _from The address of the token to be auctioned.
     * @param _maxAmount The maximum amount of fromToken to take in the auction.
     * @param _takerReceiver The address that will receive the fromToken.
     * @return _amountTaken The amount of fromToken taken in the auction.
     */
    function take(address _from, uint256 _maxAmount, address _takerReceiver) external virtual returns (uint256) {
        return _take(_from, _maxAmount, _takerReceiver, new bytes(0));
    }

    /**
     * @notice Take the token being sold in a live auction.
     * @param _from The address of the token to be auctioned.
     * @param _maxAmount The maximum amount of fromToken to take in the auction.
     * @param _takerReceiver The address that will receive the fromToken.
     * @param _data The data signify the callback should be used and sent with it.
     * @return _amountTaken The amount of fromToken taken in the auction.
     */
    function take(address _from, uint256 _maxAmount, address _takerReceiver, bytes calldata _data)
        external
        virtual
        returns (uint256)
    {
        return _take(_from, _maxAmount, _takerReceiver, _data);
    }

    /// @dev Implements the take of the auction.
    function _take(address _from, uint256 _maxAmount, address _takerReceiver, bytes memory _data)
        internal
        virtual
        nonReentrant
        returns (uint256 _amountTaken)
    {
        AuctionInfo memory auction = auctions[_from];

        // Max amount that can be taken.
        uint256 _available = Maths.min(auction.initialAvailable, ERC20(_from).balanceOf(address(this)));
        _amountTaken = _available > _maxAmount ? _maxAmount : _available;

        // Get the amount needed. Returns 0 if auction not active.
        uint256 needed = _getAmountNeeded(auction, _amountTaken, block.timestamp);

        require(needed != 0, "zero needed");

        // Send `from`.
        ERC20(_from).safeTransfer(_takerReceiver, _amountTaken);

        // If the caller has specified data.
        if (_data.length != 0) {
            // Do the callback.
            ITaker(_takerReceiver).auctionTakeCallback(_from, msg.sender, _amountTaken, needed, _data);
        }

        // Cache the want address.
        address _want = want();

        // Pull `want`.
        ERC20(_want).safeTransferFrom(msg.sender, receiver, needed);

        // If the full amount is taken, end the auction.
        if (_amountTaken == _available) {
            auctions[_from].kicked = uint64(0);

            emit AuctionSettled(_from);
        }
    }

    /// @dev Validates a COW order signature.
    function isValidSignature(bytes32 _hash, bytes calldata signature) external view returns (bytes4) {
        // Make sure `_take` has not already been entered.
        require(!_reentrancyGuardEntered(), "ReentrancyGuard: reentrant call");

        // Decode the signature to get the order.
        GPv2Order.Data memory order = abi.decode(signature, (GPv2Order.Data));

        AuctionInfo memory auction = auctions[address(order.sellToken)];

        // Get the current amount needed for the auction.
        uint256 paymentAmount = _getAmountNeeded(auction, order.sellAmount, block.timestamp);

        // Verify the order details.
        // Retreive domain seperator each time for chains it is not deployed on yet
        require(_hash == order.hash(ICowSettlement(COW_SETTLEMENT).domainSeparator()), "bad order");
        require(paymentAmount != 0, "zero amount");
        require(available(address(order.sellToken)) != 0, "zero available");
        require(order.feeAmount == 0, "fee");
        require(order.partiallyFillable, "partial fill");
        require(order.validTo < auction.kicked + AUCTION_LENGTH, "expired");
        require(order.appData == bytes32(0), "app data");
        require(order.buyAmount >= paymentAmount, "bad price");
        require(address(order.buyToken) == want(), "bad token");
        require(order.receiver == receiver, "bad receiver");
        require(order.sellAmount <= auction.initialAvailable, "bad amount");
        require(order.sellTokenBalance == keccak256("erc20"), "bad sell token balance");
        require(order.buyTokenBalance == keccak256("erc20"), "bad buy token balance");

        // If all checks pass, return the magic value
        return this.isValidSignature.selector;
    }

    /**
     * @notice Forces the auction to be kicked.
     * @dev Only callable by governance in replace of sweep settle and kick.
     * @param _from The address of the token to be auctioned.
     */
    function forceKick(address _from) external onlyGovernance {
        auctions[_from].kicked = uint64(0);
        _kick(_from);
    }

    /**
     * @notice Allows the auction to be stopped if the full amount is taken.
     * @param _from The address of the token to be auctioned.
     */
    function settle(address _from) external virtual {
        require(isActive(_from), "!active");
        require(ERC20(_from).balanceOf(address(this)) == 0, "!empty");

        auctions[_from].kicked = uint64(0);

        emit AuctionSettled(_from);
    }

    function sweep(address _token) external virtual onlyGovernance {
        ERC20(_token).safeTransfer(msg.sender, ERC20(_token).balanceOf(address(this)));

        emit AuctionSwept(_token, msg.sender);
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Clonable} from "./Clonable.sol";

contract ClonableCreate2 is Clonable {
    /**
     * @notice Clone the contracts default `original` contract using CREATE2.
     * @param salt The salt to use for deterministic deployment.
     * @return Address of the new Minimal Proxy clone.
     */
    function _cloneCreate2(bytes32 salt) internal virtual returns (address) {
        return _cloneCreate2(original, salt);
    }

    /**
     * @notice Clone any `_original` contract using CREATE2.
     * @param _original The address of the contract to clone.
     * @param salt The salt to use for deterministic deployment.
     * @return _newContract Address of the new Minimal Proxy clone.
     */
    function _cloneCreate2(address _original, bytes32 salt) internal virtual returns (address _newContract) {
        // Hash the salt with msg.sender to protect deployments for specific callers
        bytes32 finalSalt = getSalt(salt, msg.sender);
        address predicted = computeCreate2Address(_original, salt, msg.sender);

        bytes20 addressBytes = bytes20(_original);
        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(clone_code, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(add(clone_code, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _newContract := create2(0, clone_code, 0x37, finalSalt)
        }

        require(_newContract != address(0) && _newContract == predicted, "ClonableCreate2: create2 failed");
    }

    /**
     * @notice Compute the address where a clone would be deployed using CREATE2.
     * @param salt The salt to use for address computation.
     * @return The address where the clone would be deployed.
     */
    function computeCreate2Address(bytes32 salt) external view virtual returns (address) {
        return computeCreate2Address(original, salt, msg.sender);
    }

    /**
     * @notice Compute the address where a clone would be deployed using CREATE2.
     * @param _original The address of the contract to clone.
     * @param salt The salt to use for address computation.
     * @return predicted address where the clone would be deployed.
     */
    function computeCreate2Address(address _original, bytes32 salt) external view virtual returns (address predicted) {
        return computeCreate2Address(_original, salt, msg.sender);
    }

    /**
     * @notice Compute the address where a clone would be deployed using CREATE2.
     * @param _original The address of the contract to clone.
     * @param salt The salt to use for address computation.
     * @return predicted The address where the clone would be deployed.
     */
    function computeCreate2Address(address _original, bytes32 salt, address deployer)
        public
        view
        virtual
        returns (address predicted)
    {
        // Hash the salt with msg.sender to match deployment behavior
        bytes32 finalSalt = getSalt(salt, deployer);

        bytes20 addressBytes = bytes20(_original);
        assembly {
            let ptr := mload(0x40)

            // Store the prefix
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // Store the address
            mstore(add(ptr, 0x14), addressBytes)
            // Store the suffix
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

            // Compute init code hash
            let initCodeHash := keccak256(ptr, 0x37)

            // Compute the CREATE2 address
            // 0xff ++ address(this) ++ salt ++ initCodeHash
            mstore(ptr, 0xff)
            mstore8(ptr, 0xff)
            mstore(add(ptr, 0x01), shl(96, address()))
            mstore(add(ptr, 0x15), finalSalt)
            mstore(add(ptr, 0x35), initCodeHash)

            predicted := keccak256(ptr, 0x55)
        }
    }

    /**
     * @dev Internal function to compute the final salt by hashing with msg.sender.
     * This ensures that different callers get different deployment addresses
     * even when using the same salt value.
     * @param salt The user-provided salt.
     * @return The final salt to use for CREATE2.
     */
    function getSalt(bytes32 salt, address deployer) public view virtual returns (bytes32) {
        return keccak256(abi.encodePacked(salt, deployer));
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.18;

// Math library from https://github.com/ajna-finance/ajna-core/blob/master/src/libraries/internal/Maths.sol

/**
 * @title  Maths library
 *     @notice Internal library containing common maths.
 */
library Maths {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + WAD / 2) / WAD;
    }

    function floorWmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / WAD;
    }

    function ceilWmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + WAD - 1) / WAD;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * WAD + y / 2) / y;
    }

    function floorWdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * WAD) / y;
    }

    function ceilWdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * WAD + y - 1) / y;
    }

    function ceilDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x + y - 1) / y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    function wad(uint256 x) internal pure returns (uint256) {
        return x * WAD;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + RAY / 2) / RAY;
    }

    function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }

    /**
     *
     */
    /**
     * Integer Functions **
     */
    /**
     *
     */
    function maxInt(int256 x, int256 y) internal pure returns (int256) {
        return x >= y ? x : y;
    }

    function minInt(int256 x, int256 y) internal pure returns (int256) {
        return x <= y ? x : y;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

interface ITaker {
    function auctionTakeCallback(
        address _from,
        address _sender,
        uint256 _amountTaken,
        uint256 _amountNeeded,
        bytes calldata _data
    ) external;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Gnosis Protocol v2 Order Library
/// @author Gnosis Developers
library GPv2Order {
    /// @dev The complete data for a Gnosis Protocol order. This struct contains
    /// all order parameters that are signed for submitting to GP.
    struct Data {
        ERC20 sellToken;
        ERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    /// @dev The order EIP-712 type hash for the [`GPv2Order.Data`] struct.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256(
    ///     "Order(" +
    ///         "address sellToken," +
    ///         "address buyToken," +
    ///         "address receiver," +
    ///         "uint256 sellAmount," +
    ///         "uint256 buyAmount," +
    ///         "uint32 validTo," +
    ///         "bytes32 appData," +
    ///         "uint256 feeAmount," +
    ///         "string kind," +
    ///         "bool partiallyFillable" +
    ///         "string sellTokenBalance" +
    ///         "string buyTokenBalance" +
    ///     ")"
    /// )
    /// ```
    bytes32 internal constant TYPE_HASH = hex"d5a25ba2e97094ad7d83dc28a6572da797d6b3e7fc6663bd93efb789fc17e489";

    /// @dev The marker value for a sell order for computing the order struct
    /// hash. This allows the EIP-712 compatible wallets to display a
    /// descriptive string for the order kind (instead of 0 or 1).
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("sell")
    /// ```
    bytes32 internal constant KIND_SELL = hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    /// @dev The OrderKind marker value for a buy order for computing the order
    /// struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("buy")
    /// ```
    bytes32 internal constant KIND_BUY = hex"6ed88e868af0a1983e3886d5f3e95a2fafbd6c3450bc229e27342283dc429ccc";

    /// @dev The TokenBalance marker value for using direct ERC20 balances for
    /// computing the order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("erc20")
    /// ```
    bytes32 internal constant BALANCE_ERC20 = hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";

    /// @dev The TokenBalance marker value for using Balancer Vault external
    /// balances (in order to re-use Vault ERC20 approvals) for computing the
    /// order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("external")
    /// ```
    bytes32 internal constant BALANCE_EXTERNAL = hex"abee3b73373acd583a130924aad6dc38cfdc44ba0555ba94ce2ff63980ea0632";

    /// @dev The TokenBalance marker value for using Balancer Vault internal
    /// balances for computing the order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("internal")
    /// ```
    bytes32 internal constant BALANCE_INTERNAL = hex"4ac99ace14ee0a5ef932dc609df0943ab7ac16b7583634612f8dc35a4289a6ce";

    /// @dev Marker address used to indicate that the receiver of the trade
    /// proceeds should the owner of the order.
    ///
    /// This is chosen to be `address(0)` for gas efficiency as it is expected
    /// to be the most common case.
    address internal constant RECEIVER_SAME_AS_OWNER = address(0);

    /// @dev The byte length of an order unique identifier.
    uint256 internal constant UID_LENGTH = 56;

    /// @dev Returns the actual receiver for an order. This function checks
    /// whether or not the [`receiver`] field uses the marker value to indicate
    /// it is the same as the order owner.
    ///
    /// @return receiver The actual receiver of trade proceeds.
    function actualReceiver(Data memory order, address owner) internal pure returns (address receiver) {
        if (order.receiver == RECEIVER_SAME_AS_OWNER) {
            receiver = owner;
        } else {
            receiver = order.receiver;
        }
    }

    /// @dev Return the EIP-712 signing hash for the specified order.
    ///
    /// @param order The order to compute the EIP-712 signing hash for.
    /// @param domainSeparator The EIP-712 domain separator to use.
    /// @return orderDigest The 32 byte EIP-712 struct hash.
    function hash(Data memory order, bytes32 domainSeparator) internal pure returns (bytes32 orderDigest) {
        bytes32 structHash;

        // NOTE: Compute the EIP-712 order struct hash in place. As suggested
        // in the EIP proposal, noting that the order struct has 10 fields, and
        // including the type hash `(12 + 1) * 32 = 416` bytes to hash.
        // <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#rationale-for-encodedata>
        assembly {
            let dataStart := sub(order, 32)
            let temp := mload(dataStart)
            mstore(dataStart, TYPE_HASH)
            structHash := keccak256(dataStart, 416)
            mstore(dataStart, temp)
        }

        // NOTE: Now that we have the struct hash, compute the EIP-712 signing
        // hash using scratch memory past the free memory pointer. The signing
        // hash is computed from `"\x19\x01" || domainSeparator || structHash`.
        // <https://docs.soliditylang.org/en/v0.7.6/internals/layout_in_memory.html#layout-in-memory>
        // <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#specification>
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, "\x19\x01")
            mstore(add(freeMemoryPointer, 2), domainSeparator)
            mstore(add(freeMemoryPointer, 34), structHash)
            orderDigest := keccak256(freeMemoryPointer, 66)
        }
    }

    /// @dev Packs order UID parameters into the specified memory location. The
    /// result is equivalent to `abi.encodePacked(...)` with the difference that
    /// it allows re-using the memory for packing the order UID.
    ///
    /// This function reverts if the order UID buffer is not the correct size.
    ///
    /// @param orderUid The buffer pack the order UID parameters into.
    /// @param orderDigest The EIP-712 struct digest derived from the order
    /// parameters.
    /// @param owner The address of the user who owns this order.
    /// @param validTo The epoch time at which the order will stop being valid.
    function packOrderUidParams(bytes memory orderUid, bytes32 orderDigest, address owner, uint32 validTo)
        internal
        pure
    {
        require(orderUid.length == UID_LENGTH, "GPv2: uid buffer overflow");

        // NOTE: Write the order UID to the allocated memory buffer. The order
        // parameters are written to memory in **reverse order** as memory
        // operations write 32-bytes at a time and we want to use a packed
        // encoding. This means, for example, that after writing the value of
        // `owner` to bytes `20:52`, writing the `orderDigest` to bytes `0:32`
        // will **overwrite** bytes `20:32`. This is desirable as addresses are
        // only 20 bytes and `20:32` should be `0`s:
        //
        //        |           1111111111222222222233333333334444444444555555
        //   byte | 01234567890123456789012345678901234567890123456789012345
        // -------+---------------------------------------------------------
        //  field | [.........orderDigest..........][......owner.......][vT]
        // -------+---------------------------------------------------------
        // mstore |                         [000000000000000000000000000.vT]
        //        |                     [00000000000.......owner.......]
        //        | [.........orderDigest..........]
        //
        // Additionally, since Solidity `bytes memory` are length prefixed,
        // 32 needs to be added to all the offsets.
        //
        assembly {
            mstore(add(orderUid, 56), validTo)
            mstore(add(orderUid, 52), owner)
            mstore(add(orderUid, 32), orderDigest)
        }
    }

    /// @dev Extracts specific order information from the standardized unique
    /// order id of the protocol.
    ///
    /// @param orderUid The unique identifier used to represent an order in
    /// the protocol. This uid is the packed concatenation of the order digest,
    /// the validTo order parameter and the address of the user who created the
    /// order. It is used by the user to interface with the contract directly,
    /// and not by calls that are triggered by the solvers.
    /// @return orderDigest The EIP-712 signing digest derived from the order
    /// parameters.
    /// @return owner The address of the user who owns this order.
    /// @return validTo The epoch time at which the order will stop being valid.
    function extractOrderUidParams(bytes calldata orderUid)
        internal
        pure
        returns (bytes32 orderDigest, address owner, uint32 validTo)
    {
        require(orderUid.length == UID_LENGTH, "GPv2: invalid uid");

        // Use assembly to efficiently decode packed calldata.
        assembly {
            orderDigest := calldataload(orderUid.offset)
            owner := shr(96, calldataload(add(orderUid.offset, 32)))
            validTo := shr(224, calldataload(add(orderUid.offset, 52)))
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Governance} from "./Governance.sol";

contract Governance2Step is Governance {
    /// @notice Emitted when the pending governance address is set.
    event UpdatePendingGovernance(address indexed newPendingGovernance);

    /// @notice Address that is set to take over governance.
    address public pendingGovernance;

    constructor(address _governance) Governance(_governance) {}

    /**
     * @notice Sets a new address as the `pendingGovernance` of the contract.
     * @dev Throws if the caller is not current governance.
     * @param _newGovernance The new governance address.
     */
    function transferGovernance(address _newGovernance) external virtual override onlyGovernance {
        require(_newGovernance != address(0), "ZERO ADDRESS");
        pendingGovernance = _newGovernance;

        emit UpdatePendingGovernance(_newGovernance);
    }

    /**
     * @notice Allows the `pendingGovernance` to accept the role.
     */
    function acceptGovernance() external virtual {
        require(msg.sender == pendingGovernance, "!pending governance");

        emit GovernanceTransferred(governance, msg.sender);

        governance = msg.sender;
        pendingGovernance = address(0);
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

contract Clonable {
    /// @notice Set to the address to auto clone from.
    address public original;

    /**
     * @notice Clone the contracts default `original` contract.
     * @return Address of the new Minimal Proxy clone.
     */
    function _clone() internal virtual returns (address) {
        return _clone(original);
    }

    /**
     * @notice Clone any `_original` contract.
     * @return _newContract Address of the new Minimal Proxy clone.
     */
    function _clone(address _original) internal virtual returns (address _newContract) {
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(_original);
        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(clone_code, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(add(clone_code, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _newContract := create(0, clone_code, 0x37)
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

contract Governance {
    /// @notice Emitted when the governance address is updated.
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);

    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    /// @notice Checks if the msg sender is the governance.
    function _checkGovernance() internal view virtual {
        require(governance == msg.sender, "!governance");
    }

    /// @notice Address that can set the default base fee and provider
    address public governance;

    constructor(address _governance) {
        governance = _governance;

        emit GovernanceTransferred(address(0), _governance);
    }

    /**
     * @notice Sets a new address as the governance of the contract.
     * @dev Throws if the caller is not current governance.
     * @param _newGovernance The new governance address.
     */
    function transferGovernance(address _newGovernance) external virtual onlyGovernance {
        require(_newGovernance != address(0), "ZERO ADDRESS");
        address oldGovernance = governance;
        governance = _newGovernance;

        emit GovernanceTransferred(oldGovernance, _newGovernance);
    }
}


