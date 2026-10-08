// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IOffchainBtcVault} from "./interfaces/IOffchainBtcVault.sol";
import {IStBTCReserve} from "./interfaces/IStBTCReserve.sol";

/**
 * @title StBTC
 * @notice ERC-4626 vault shares for WBTC, with custody and off-chain accounting handled by {OffchainBtcVault}.
 * @dev This contract is the ERC-4626 "shares" token (ERC20). Assets are routed to/from `vault`.
 *
 * COMPLIANCE SCOPE: Whitelist/blacklist controls only apply to stBTC share transfers,
 * mints, and burns. Direct WBTC transfers to the vault are not prevented by these controls.
 * If stricter compliance is required for the underlying asset, implement additional
 * monitoring or use a compliance-aware WBTC wrapper.
 *
 * SECURITY: ERC-4626 First Depositor Protection
 * - Zero-share minting is prevented in deposit() and mint()
 * - OpenZeppelin's virtual offset (_decimalsOffset) provides additional protection
 * - Consider seeding initial shares to dead address in production deployment
 *
 * IMPORTANT - WITHDRAWAL QUEUE WHITELIST REQUIREMENT:
 * If whitelist is enabled, the WithdrawalQueue contract MUST be manually whitelisted
 * by the compliance admin using setWhitelisted(withdrawalQueueAddress, true).
 * Failure to whitelist the queue will cause withdrawal finalization to fail,
 * blocking users from claiming their queued withdrawals (DoS via misconfiguration).
 */
contract StBTC is
    Initializable,
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable,
    IStBTCReserve
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    // External dependencies
    IOffchainBtcVault public vault;

    // Deposit caps (denominated in assets, i.e. WBTC satoshis)
    uint256 public globalDepositCap;
    mapping(address => uint256) public perUserDepositCap;

    // Compliance storage
    bool public whitelistEnabled;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;

    // Errors (keep custom errors for integrations/tests)
    error InvalidAmount();
    error InvalidAddress();
    error InvalidRecipient();
    error GlobalDepositCapExceeded();
    error UserDepositCapExceeded();
    error Blacklisted();
    error WhitelistRequired();
    error RescueWbtcNotAllowed();
    error InsufficientLiquidity();

    // Events
    event CapsSet(uint256 globalCap, address indexed user, uint256 userCap);
    event WhitelistEnabled(bool enabled);
    event WhitelistUpdated(address indexed account, bool whitelisted);
    event BlacklistUpdated(address indexed account, bool blacklisted);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _admin The address of the admin (DEFAULT_ADMIN_ROLE).
     * @param _wbtc The address of the WBTC token (ERC-20).
     * @param _vault The address of the OffchainBtcVault contract.
     */
    function initialize(address _admin, address _wbtc, address _vault) public initializer {
        if (_wbtc == address(0)) revert InvalidAddress();
        if (_admin == address(0)) revert InvalidAddress();
        if (_vault == address(0)) revert InvalidAddress();

        __ERC20_init("Staked WBTC", "stBTC");
        __ERC4626_init(IERC20(_wbtc));
        __AccessControl_init();
        __Pausable_init();

        vault = IOffchainBtcVault(_vault);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(COMPLIANCE_ROLE, _admin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // =========================================================================
    // ERC-4626 overrides (custody in OffchainBtcVault)
    // =========================================================================

    /**
     * @notice Total assets under management (on-chain in vault + off-chain accounting in vault).
     */
    function totalAssets() public view override returns (uint256) {
        return vault.totalManagedAssets();
    }

    /**
     * @dev ERC-4626 deposit/mint workflow override to route assets into `vault`.
     * Mirrors OpenZeppelin's ordering: transfer assets first, then mint shares, then emit event.
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // Pull assets into this contract
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);

        // Route custody to OffchainBtcVault
        IERC20(asset()).forceApprove(address(vault), assets);
        vault.depositFromStBTC(assets);

        // Mint ERC-4626 shares
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev ERC-4626 withdraw/redeem workflow override to route assets out of `vault`.
     *      Uses vault.minLiquidityBps() as the single source of truth for liquidity reserve.
     *      IMPORTANT: Allowance is spent AFTER shares are burned to prevent allowance DoS on revert.
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // Enforce liquidity reserve check FIRST - before any state changes
        // Uses vault's minLiquidityBps as the single source of truth
        uint256 minLiquidityBps = vault.minLiquidityBps();
        if (minLiquidityBps > 0) {
            uint256 vaultBalance = vault.availableBalance();
            uint256 managed = vault.totalManagedAssets();
            uint256 reserve = (managed * minLiquidityBps) / 10_000;
            if (vaultBalance < assets + reserve) revert InsufficientLiquidity();
        }

        // Burn shares first to ensure state consistency
        _burn(owner, shares);

        // Spend allowance AFTER burning to prevent allowance reduction on revert
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        vault.withdrawToUser(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    // =========================================================================
    // Pause + compliance enforcement (covers transfers + mint/burn)
    // =========================================================================

    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable) {
        _requireNotPaused();

        if (from != address(0)) _enforceAccountAllowed(from);
        if (to != address(0)) _enforceAccountAllowed(to);

        super._update(from, to, value);
    }

    // =========================================================================
    // ERC-4626 user entrypoints: add pause + explicit compliance checks
    // =========================================================================

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (assets == 0) revert InvalidAmount();
        if (receiver == address(0)) revert InvalidRecipient();
        _enforceAccountAllowed(_msgSender());
        _enforceAccountAllowed(receiver);

        // Preserve legacy revert reasons for caps
        if (globalDepositCap > 0) {
            uint256 managed = vault.totalManagedAssets();
            if (managed + assets > globalDepositCap) revert GlobalDepositCapExceeded();
        }
        if (perUserDepositCap[receiver] > 0) {
            uint256 currentAssets = _convertToAssets(balanceOf(receiver), Math.Rounding.Ceil);
            if (currentAssets + assets > perUserDepositCap[receiver]) revert UserDepositCapExceeded();
        }

        // Prevent zero-share mints (donations/slippage can make small deposits unsafe)
        if (previewDeposit(assets) == 0) revert InvalidAmount();

        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        if (shares == 0) revert InvalidAmount();
        if (receiver == address(0)) revert InvalidRecipient();
        _enforceAccountAllowed(_msgSender());
        _enforceAccountAllowed(receiver);

        // Preserve legacy revert reasons for caps (cap is denominated in assets)
        uint256 requiredAssets = previewMint(shares);
        if (requiredAssets == 0) revert InvalidAmount();
        if (globalDepositCap > 0) {
            uint256 managed = vault.totalManagedAssets();
            if (managed + requiredAssets > globalDepositCap) revert GlobalDepositCapExceeded();
        }
        if (perUserDepositCap[receiver] > 0) {
            uint256 currentAssets = _convertToAssets(balanceOf(receiver), Math.Rounding.Ceil);
            if (currentAssets + requiredAssets > perUserDepositCap[receiver]) revert UserDepositCapExceeded();
        }

        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (assets == 0) revert InvalidAmount();
        if (receiver == address(0)) revert InvalidRecipient();
        if (owner == address(0)) revert InvalidAddress();
        _enforceAccountAllowed(_msgSender());
        _enforceAccountAllowed(receiver);
        _enforceAccountAllowed(owner);
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        if (shares == 0) revert InvalidAmount();
        if (receiver == address(0)) revert InvalidRecipient();
        if (owner == address(0)) revert InvalidAddress();
        _enforceAccountAllowed(_msgSender());
        _enforceAccountAllowed(receiver);
        _enforceAccountAllowed(owner);
        return super.redeem(shares, receiver, owner);
    }

    // =========================================================================
    // Caps (denominated in assets)
    // =========================================================================

    function maxDeposit(address receiver) public view override returns (uint256) {
        uint256 cap = _remainingUserDepositCap(receiver);
        uint256 gcap = _remainingGlobalDepositCap();
        return cap < gcap ? cap : gcap;
    }

    function maxMint(address receiver) public view override returns (uint256) {
        // Convert remaining asset caps to shares using conservative rounding (Floor),
        // so mint cannot exceed caps due to rounding artifacts.
        uint256 maxAssets = maxDeposit(receiver);
        return _convertToShares(maxAssets, Math.Rounding.Floor);
    }

    function _remainingGlobalDepositCap() internal view returns (uint256) {
        if (globalDepositCap == 0) return type(uint256).max;
        uint256 managed = vault.totalManagedAssets();
        if (managed >= globalDepositCap) return 0;
        return globalDepositCap - managed;
    }

    function _remainingUserDepositCap(address receiver) internal view returns (uint256) {
        uint256 cap = perUserDepositCap[receiver];
        if (cap == 0) return type(uint256).max;

        // Use Ceil when converting shares->assets to avoid cap bypass by rounding down
        uint256 currentAssets = _convertToAssets(balanceOf(receiver), Math.Rounding.Ceil);
        if (currentAssets >= cap) return 0;
        return cap - currentAssets;
    }

    // =========================================================================
    // Instant-withdraw liquidity + reserve
    // =========================================================================

    function getAvailableInstantWithdrawal() public view returns (uint256) {
        return _availableInstantWithdrawal();
    }

    /**
     * @notice Maximum assets that can be instantly withdrawn by owner.
     * @dev IMPORTANT FOR INTEGRATORS: This is a point-in-time value. Vault state
     *      can change between calling this function and executing withdraw/redeem,
     *      causing reverts. Best practices:
     *      - Use try/catch when calling withdraw/redeem
     *      - Implement retry logic with updated maxWithdraw checks
     *      - Consider using WithdrawalQueue for guaranteed execution
     *      - Never assume this value is "locked" for your transaction
     * @param owner The address to check
     * @return Maximum assets withdrawable at current block
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 instant = _availableInstantWithdrawal();
        uint256 ownerAssets = previewRedeem(balanceOf(owner));
        return instant < ownerAssets ? instant : ownerAssets;
    }

    /**
     * @notice Maximum shares that can be instantly redeemed by owner.
     * @dev IMPORTANT FOR INTEGRATORS: This is a point-in-time value. Vault state
     *      can change between calling this function and executing withdraw/redeem,
     *      causing reverts. Best practices:
     *      - Use try/catch when calling withdraw/redeem
     *      - Implement retry logic with updated maxRedeem checks
     *      - Consider using WithdrawalQueue for guaranteed execution
     *      - Never assume this value is "locked" for your transaction
     * @param owner The address to check
     * @return Maximum shares redeemable at current block
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 instant = _availableInstantWithdrawal();
        uint256 instantShares = _convertToShares(instant, Math.Rounding.Floor);
        uint256 ownerShares = balanceOf(owner);
        return instantShares < ownerShares ? instantShares : ownerShares;
    }

    function _availableInstantWithdrawal() internal view returns (uint256) {
        uint256 vaultBalance = vault.availableBalance();
        uint256 managed = vault.totalManagedAssets();
        uint256 minLiquidityBps = vault.minLiquidityBps();

        if (minLiquidityBps == 0 || managed == 0) return vaultBalance;

        uint256 reserve = (managed * minLiquidityBps) / 10_000;
        if (vaultBalance <= reserve) return 0;
        return vaultBalance - reserve;
    }

    // =========================================================================
    // Admin functions
    // =========================================================================

    function setGlobalDepositCap(uint256 _cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalDepositCap = _cap;
        emit CapsSet(_cap, address(0), 0);
    }

    function setPerUserDepositCap(address user, uint256 cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (user == address(0)) revert InvalidAddress();
        perUserDepositCap[user] = cap;
        emit CapsSet(globalDepositCap, user, cap);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // =========================================================================
    // Compliance admin
    // =========================================================================

    /**
     * @notice Enables or disables the whitelist for compliance.
     * @dev When enabling whitelist, verify that the WithdrawalQueue contract is whitelisted
     *      to prevent DoS where queued withdrawals cannot be finalized.
     * @param enabled True to enable whitelist, false to disable.
     */
    function setWhitelistEnabled(bool enabled) external onlyRole(COMPLIANCE_ROLE) {
        whitelistEnabled = enabled;
        emit WhitelistEnabled(enabled);
    }

    function setWhitelisted(address account, bool whitelisted) external onlyRole(COMPLIANCE_ROLE) {
        if (account == address(0)) revert InvalidAddress();
        isWhitelisted[account] = whitelisted;
        emit WhitelistUpdated(account, whitelisted);
    }

    function setBlacklisted(address account, bool blacklisted) external onlyRole(COMPLIANCE_ROLE) {
        if (account == address(0)) revert InvalidAddress();
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    // =========================================================================
    // Admin utilities
    // =========================================================================

    function rescueTokens(address token, address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (token == asset()) revert RescueWbtcNotAllowed();
        IERC20(token).safeTransfer(recipient, amount);
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _enforceAccountAllowed(address account) internal view {
        if (isBlacklisted[account]) revert Blacklisted();
        if (whitelistEnabled && !isWhitelisted[account]) revert WhitelistRequired();
    }
}
