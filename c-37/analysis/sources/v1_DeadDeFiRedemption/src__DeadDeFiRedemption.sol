// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

// ============ Protocol Interfaces ============
// Minimal interfaces for compile-time safety (vs brittle abi.encodeWithSignature)

interface IPieDAO {
    function exitPool(uint256 _amount) external;
}

interface IIndexedPool {
    function exitPool(uint256 poolAmountIn, uint256[] calldata minAmountsOut) external;
}

interface ISetV1Module {
    function redeemRebalancingSet(
        address _rebalancingSetAddress,
        uint256 _rebalancingSetQuantity,
        bool _keepChangeInVault
    ) external;
}

// IBabylonGarden removed - moved to v2 (Permit2 + Flashbots)
// Babylon's withdraw() requires _to == msg.sender, incompatible with wrapper pattern

interface IBasketDAO {
    function burn(uint256 _amount) external;
}

interface ICookFinanceModule {
    function redeem(address _ckToken, uint256 _quantity, address _to) external;
}

// Interface for Compound-style fTokens (Rari Fuse)
interface ICToken {
    function underlying() external view returns (address);
    function redeem(uint256 redeemTokens) external returns (uint256);
}

/**
 * @title DeadDeFiRedemption
 * @notice Wrapper contract for redeeming tokens from dead DeFi protocols with fee
 * @dev Supports PieDAO exitPool, Indexed Finance exitPool, Set Protocol V1
 *      Uses Ownable2Step for safe ownership transfer (new owner must accept)
 */
contract DeadDeFiRedemption is ReentrancyGuard, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    // ============ State ============
    address public feeRecipient;
    uint256 public feeBps = 300; // 3% in basis points (300/10000)

    uint256 public constant MAX_FEE_BPS = 500; // Cap at 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // Protocol addresses (mainnet)
    address public constant SET_V1_MODULE = 0xcEDA8318522D348f1d1aca48B24629b8FbF09020;
    address public constant BDI = 0x0309c98B1bffA350bcb3F9fB9780970CA32a5060;
    address public constant CLI = 0xA6156492fC79616035F644C71b01e3099819F8EC;
    address public constant COOK_MODULE = 0x59E799B58f1F4bc778E126B0D1D2774Ae05432B7;

    // ============ Events ============
    event Redeemed(
        address indexed user,
        address indexed protocol,
        uint256 amountIn,
        address[] tokensOut,
        uint256[] amountsOut,
        uint256[] feesCollected
    );
    event FeeCollected(address indexed token, uint256 amount);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FeeBpsChanged(uint256 oldBps, uint256 newBps);
    event ProtocolOutputsSet(address indexed protocol, address[] tokens);
    event ProtocolOutputAdded(address indexed protocol, address indexed token);
    event ProtocolOutputRemoved(address indexed protocol, address indexed token);
    event StrictOutputsSet(address indexed protocol, bool strict);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);
    event ETHRescued(address indexed to, uint256 amount);

    // ============ Errors ============
    error FeeTooHigh();
    error ZeroAddress();
    error EmptyOutputTokens();
    error ArrayLengthMismatch();
    error RedemptionFailed(bytes reason);
    error SlippageExceeded(uint256 index, uint256 received, uint256 minimum);
    error InvalidOutputToken(address token);
    error DuplicateOutputToken(address token);
    error OutputTokensMismatch();
    error EmptyAllowlist(address protocol);
    error UnsupportedFuseMarket(address fToken);
    error ETHTransferFailed();
    error InsufficientBalance(address token, uint256 requested, uint256 available);
    error NoETHToRescue();

    // ============ Output Token Allowlist ============
    // Protocol address => array of allowed output tokens
    mapping(address => address[]) public protocolOutputs;
    // Protocol => token => is allowed (for O(1) validation)
    mapping(address => mapping(address => bool)) public isProtocolOutput;
    // Protocol => strict mode (user must provide EXACT allowlist, not subset)
    mapping(address => bool) public strictOutputs;

    // ============ Constructor ============
    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    // ============ Internal Validation ============

    /**
     * @notice Validate that all output tokens are in the protocol's allowlist
     * @dev Also checks for duplicates and strict mode compliance
     */
    function _validateOutputTokens(address protocol, address[] calldata tokens) internal view {
        // Check for duplicates and zero addresses in user's list (O(n²) but n <= 13)
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] == tokens[j]) revert DuplicateOutputToken(tokens[i]);
            }
        }

        // Validate all tokens are in allowlist
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!isProtocolOutput[protocol][tokens[i]]) {
                revert InvalidOutputToken(tokens[i]);
            }
        }

        // Strict mode: user must provide EXACT allowlist (true set equality)
        if (strictOutputs[protocol]) {
            address[] storage allowed = protocolOutputs[protocol];
            // Length must match
            if (tokens.length != allowed.length) {
                revert OutputTokensMismatch();
            }
            // Every allowlisted token must be in user's list (O(n²) but n <= 13)
            for (uint256 i = 0; i < allowed.length; i++) {
                bool found = false;
                for (uint256 j = 0; j < tokens.length; j++) {
                    if (allowed[i] == tokens[j]) {
                        found = true;
                        break;
                    }
                }
                if (!found) revert OutputTokensMismatch();
            }
        }
    }


    // ============ PieDAO Redemption ============

    /**
     * @notice Redeem PieDAO tokens (DEFI++, BCP, PLAY) for underlying assets
     * @param pie The PieDAO token address
     * @param amount Amount of pie tokens to redeem
     * @param outputTokens Array of expected output token addresses (for fee calculation)
     * @param minAmountsOut Minimum amounts to receive per token after fees (slippage protection)
     */
    function redeemPieDAO(
        address pie,
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        // Validate inputs
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();
        _validateOutputTokens(pie, outputTokens);

        // Transfer pie tokens from user
        IERC20(pie).safeTransferFrom(msg.sender, address(this), amount);

        // Record balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Call exitPool on PieDAO contract
        IPieDAO(pie).exitPool(amount);

        // Calculate received amounts, take fees, send to user
        uint256[] memory amountsOut = new uint256[](outputTokens.length);
        uint256[] memory fees = new uint256[](outputTokens.length);

        for (uint256 i = 0; i < outputTokens.length; i++) {
            uint256 received = IERC20(outputTokens[i]).balanceOf(address(this)) - balancesBefore[i];
            if (received > 0) {
                uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
                uint256 userAmount = received - fee;

                // Slippage check (post-fee)
                if (userAmount < minAmountsOut[i]) revert SlippageExceeded(i, userAmount, minAmountsOut[i]);

                amountsOut[i] = userAmount;
                fees[i] = fee;

                // Send fee to recipient
                if (fee > 0) {
                    IERC20(outputTokens[i]).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(outputTokens[i], fee);
                }
                // Send remainder to user
                IERC20(outputTokens[i]).safeTransfer(msg.sender, userAmount);
            } else if (minAmountsOut[i] > 0) {
                // User expected tokens but got none - revert to protect them
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        _forwardETH();
        emit Redeemed(msg.sender, pie, amount, outputTokens, amountsOut, fees);
    }

    // ============ Indexed Finance Redemption ============

    /**
     * @notice Redeem Indexed Finance tokens (DEFI5, CC10) for underlying assets
     * @param pool The Indexed pool address
     * @param amount Amount of pool tokens to redeem
     * @param outputTokens Array of expected output token addresses
     * @param minAmountsOut Minimum amounts to receive after wrapper fee (post-fee slippage protection)
     * @dev Indexed pools have 0% exit fee. User's minAmountsOut are enforced post-wrapper-fee.
     */
    function redeemIndexed(
        address pool,
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        // Validate inputs
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();
        _validateOutputTokens(pool, outputTokens);

        // Transfer pool tokens from user
        IERC20(pool).safeTransferFrom(msg.sender, address(this), amount);

        // Record balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Pass zeros to protocol - user's minAmountsOut are post-wrapper-fee semantics.
        // Safe because: (1) Indexed pools have 0% exit fee (verified on-chain: DEFI5, CC10)
        // (2) Dead protocol with deterministic pro-rata redemptions (no MEV/slippage risk)
        // (3) Slippage protection enforced post-fee at wrapper level below
        uint256[] memory zeros = new uint256[](outputTokens.length);
        IIndexedPool(pool).exitPool(amount, zeros);

        // Calculate received amounts, take fees, send to user
        uint256[] memory amountsOut = new uint256[](outputTokens.length);
        uint256[] memory fees = new uint256[](outputTokens.length);

        for (uint256 i = 0; i < outputTokens.length; i++) {
            uint256 received = IERC20(outputTokens[i]).balanceOf(address(this)) - balancesBefore[i];
            if (received > 0) {
                uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
                uint256 userAmount = received - fee;

                // Slippage check (post-fee)
                if (userAmount < minAmountsOut[i]) revert SlippageExceeded(i, userAmount, minAmountsOut[i]);

                amountsOut[i] = userAmount;
                fees[i] = fee;

                if (fee > 0) {
                    IERC20(outputTokens[i]).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(outputTokens[i], fee);
                }
                IERC20(outputTokens[i]).safeTransfer(msg.sender, userAmount);
            } else if (minAmountsOut[i] > 0) {
                // User expected tokens but got none - revert to protect them
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        _forwardETH();
        emit Redeemed(msg.sender, pool, amount, outputTokens, amountsOut, fees);
    }

    // ============ Set Protocol V1 Redemption ============

    /**
     * @notice Redeem Set Protocol V1 tokens (ETH20SMACO, ETH50SMACO, etc.) for underlying assets
     * @param setToken The Set token address
     * @param amount Amount of Set tokens to redeem
     * @param outputTokens Array of expected output token addresses
     * @param minAmountsOut Minimum amounts to receive per token after fees (slippage protection)
     * @dev Calls RebalancingSetIssuanceModule at 0xceda8318522d348f1d1aca48b24629b8fbf09020
     */
    function redeemSetV1(
        address setToken,
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();
        _validateOutputTokens(setToken, outputTokens);

        // Transfer Set tokens from user
        IERC20(setToken).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the module to spend our Set tokens (forceApprove for USDT compatibility)
        IERC20(setToken).forceApprove(SET_V1_MODULE, amount);

        // Record balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Call redeemRebalancingSet on the module
        ISetV1Module(SET_V1_MODULE).redeemRebalancingSet(
            setToken,
            amount,
            false // Don't keep change in vault, send to us
        );

        // Calculate received amounts, take fees, send to user
        uint256[] memory amountsOut = new uint256[](outputTokens.length);
        uint256[] memory fees = new uint256[](outputTokens.length);

        for (uint256 i = 0; i < outputTokens.length; i++) {
            uint256 received = IERC20(outputTokens[i]).balanceOf(address(this)) - balancesBefore[i];
            if (received > 0) {
                uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
                uint256 userAmount = received - fee;

                // Slippage check (post-fee)
                if (userAmount < minAmountsOut[i]) revert SlippageExceeded(i, userAmount, minAmountsOut[i]);

                amountsOut[i] = userAmount;
                fees[i] = fee;

                if (fee > 0) {
                    IERC20(outputTokens[i]).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(outputTokens[i], fee);
                }
                IERC20(outputTokens[i]).safeTransfer(msg.sender, userAmount);
            } else if (minAmountsOut[i] > 0) {
                // User expected tokens but got none - revert to protect them
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        _forwardETH();
        emit Redeemed(msg.sender, setToken, amount, outputTokens, amountsOut, fees);
    }

    // ============ Babylon Finance ============
    // NOTE: Babylon Finance moved to v2 (Permit2 + Flashbots)
    // Babylon's withdraw() requires _to == msg.sender (ONLY_CONTRIBUTOR error)
    // Our wrapper pattern sends to address(this) to take fees, which Babylon rejects.
    // v2 will use atomic Permit2 signature + Flashbots bundle for fee collection.
    // See docs/PROJECT_PLAN.md "v2 Features" section

    // ============ APY Finance ============
    // NOTE: APY Finance tokens are non-transferable (_beforeTokenTransfer blocks all transfers)
    // Moved to v2 which uses Permit2 + Flashbots for atomic fee collection
    // See docs/PROJECT_PLAN.md "v2 Features" section

    // ============ BasketDAO Redemption ============

    /**
     * @notice Redeem BasketDAO BDI tokens for underlying DeFi tokens
     * @param amount Amount of BDI tokens to redeem
     * @param outputTokens Array of expected output token addresses (13 tokens)
     * @param minAmountsOut Minimum amounts to receive per token after fees (slippage protection)
     * @dev BDI=0x0309c98b1bffa350bcb3f9fb9780970ca32a5060, 0% burn fee
     */
    function redeemBasketDAO(
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();
        _validateOutputTokens(BDI, outputTokens);

        // Transfer BDI from user
        IERC20(BDI).safeTransferFrom(msg.sender, address(this), amount);

        // Record balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Call burn on BDI
        IBasketDAO(BDI).burn(amount);

        // Calculate received, take fees, send to user
        uint256[] memory amountsOut = new uint256[](outputTokens.length);
        uint256[] memory fees = new uint256[](outputTokens.length);

        for (uint256 i = 0; i < outputTokens.length; i++) {
            uint256 received = IERC20(outputTokens[i]).balanceOf(address(this)) - balancesBefore[i];
            if (received > 0) {
                uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
                uint256 userAmount = received - fee;

                // Slippage check (post-fee)
                if (userAmount < minAmountsOut[i]) revert SlippageExceeded(i, userAmount, minAmountsOut[i]);

                amountsOut[i] = userAmount;
                fees[i] = fee;

                if (fee > 0) {
                    IERC20(outputTokens[i]).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(outputTokens[i], fee);
                }
                IERC20(outputTokens[i]).safeTransfer(msg.sender, userAmount);
            } else if (minAmountsOut[i] > 0) {
                // User expected tokens but got none - revert to protect them
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        _forwardETH();
        emit Redeemed(msg.sender, BDI, amount, outputTokens, amountsOut, fees);
    }

    // ============ Cook Finance Redemption ============

    /**
     * @notice Redeem Cook Finance CLI tokens for underlying assets (WBTC + WETH)
     * @param amount Amount of CLI tokens to redeem
     * @param outputTokens Array of expected output token addresses
     * @param minAmountsOut Minimum amounts to receive per token after fees (slippage protection)
     * @dev CLI=0xA6156492fC79616035F644C71b01e3099819F8EC,
     *      BasicIssuanceModule=0x59E799B58f1F4bc778E126B0D1D2774Ae05432B7
     */
    function redeemCookFinance(
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();
        _validateOutputTokens(CLI, outputTokens);

        // Transfer CLI from user
        IERC20(CLI).safeTransferFrom(msg.sender, address(this), amount);

        // Approve module to spend CLI (forceApprove for USDT compatibility)
        IERC20(CLI).forceApprove(COOK_MODULE, amount);

        // Record balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Call redeem on BasicIssuanceModule
        ICookFinanceModule(COOK_MODULE).redeem(CLI, amount, address(this));

        // Calculate received, take fees, send to user
        uint256[] memory amountsOut = new uint256[](outputTokens.length);
        uint256[] memory fees = new uint256[](outputTokens.length);

        for (uint256 i = 0; i < outputTokens.length; i++) {
            uint256 received = IERC20(outputTokens[i]).balanceOf(address(this)) - balancesBefore[i];
            if (received > 0) {
                uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
                uint256 userAmount = received - fee;

                // Slippage check (post-fee)
                if (userAmount < minAmountsOut[i]) revert SlippageExceeded(i, userAmount, minAmountsOut[i]);

                amountsOut[i] = userAmount;
                fees[i] = fee;

                if (fee > 0) {
                    IERC20(outputTokens[i]).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(outputTokens[i], fee);
                }
                IERC20(outputTokens[i]).safeTransfer(msg.sender, userAmount);
            } else if (minAmountsOut[i] > 0) {
                // User expected tokens but got none - revert to protect them
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        _forwardETH();
        emit Redeemed(msg.sender, CLI, amount, outputTokens, amountsOut, fees);
    }

    // ============ Rari Fuse Redemption ============
    // NOTE: Rari Fuse intentionally skips the allowlist system used by other protocols.
    // Fuse is a dead protocol with a frozen pool set (~130 fTokens). No new pools can
    // be created, so the attack surface is fixed. We read underlying() on-chain directly.
    // If the underlying is a weird LP token, user deals with it - that's not our problem.

    /**
     * @notice Redeem Rari Fuse fTokens for underlying assets (Compound-style)
     * @param fToken The fToken address to redeem
     * @param amount Amount of fTokens to redeem
     * @param minAmountOut Minimum amount to receive after fees (slippage protection)
     * @dev Works with any Fuse pool fToken. Returns 0 on success (Compound convention).
     *      Underlying token is read directly from fToken.underlying() on-chain.
     */
    function redeemRariFuse(
        address fToken,
        uint256 amount,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused {
        // Get underlying token from fToken (reverts for cETH-like markets)
        address underlyingToken;
        try ICToken(fToken).underlying() returns (address underlying) {
            underlyingToken = underlying;
        } catch {
            // cETH-like markets (no underlying()) are not supported in v1
            revert UnsupportedFuseMarket(fToken);
        }

        // Transfer fTokens from user
        IERC20(fToken).safeTransferFrom(msg.sender, address(this), amount);

        // Record balance before
        uint256 balanceBefore = IERC20(underlyingToken).balanceOf(address(this));

        // Call redeem on fToken (Compound-style: returns 0 on success)
        uint256 errorCode = ICToken(fToken).redeem(amount);
        if (errorCode != 0) revert RedemptionFailed(abi.encode(errorCode));

        // Calculate received, take fee, send to user
        uint256 received = IERC20(underlyingToken).balanceOf(address(this)) - balanceBefore;

        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOut = new uint256[](1);
        uint256[] memory fees = new uint256[](1);
        tokensOut[0] = underlyingToken;

        if (received > 0) {
            uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
            uint256 userAmount = received - fee;

            // Slippage check (post-fee)
            if (userAmount < minAmountOut) revert SlippageExceeded(0, userAmount, minAmountOut);

            amountsOut[0] = userAmount;
            fees[0] = fee;

            if (fee > 0) {
                IERC20(underlyingToken).safeTransfer(feeRecipient, fee);
                emit FeeCollected(underlyingToken, fee);
            }
            IERC20(underlyingToken).safeTransfer(msg.sender, userAmount);
        } else if (minAmountOut > 0) {
            // User expected tokens but got none - revert to protect them
            revert SlippageExceeded(0, 0, minAmountOut);
        }

        _forwardETH();
        emit Redeemed(msg.sender, fToken, amount, tokensOut, amountsOut, fees);
    }

    // ============ Admin Functions ============

    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientChanged(feeRecipient, _newRecipient);
        feeRecipient = _newRecipient;
    }

    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeBpsChanged(feeBps, _newFeeBps);
        feeBps = _newFeeBps;
    }

    // NOTE: Ownership transfer uses Ownable2Step pattern (inherited)
    // Call transferOwnership(newOwner), then newOwner calls acceptOwnership()

    // ============ Output Token Allowlist Admin ============

    /**
     * @notice Set allowed output tokens for a protocol (replaces existing)
     * @param protocol The protocol/pool address
     * @param tokens Array of allowed output token addresses (no duplicates)
     */
    function setProtocolOutputs(address protocol, address[] calldata tokens) external onlyOwner {
        // Check for duplicates in input first (O(n²), don't reuse storage mapping)
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] == tokens[j]) revert DuplicateOutputToken(tokens[i]);
            }
        }

        // Clear old tokens
        address[] storage oldTokens = protocolOutputs[protocol];
        for (uint256 i = 0; i < oldTokens.length; i++) {
            isProtocolOutput[protocol][oldTokens[i]] = false;
        }
        delete protocolOutputs[protocol];

        // Set new tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            protocolOutputs[protocol].push(tokens[i]);
            isProtocolOutput[protocol][tokens[i]] = true;
        }

        emit ProtocolOutputsSet(protocol, tokens);
    }

    /**
     * @notice Set strict mode for a protocol
     * @param protocol The protocol/pool address
     * @param strict If true, user must provide exact allowlist (not subset)
     * @dev Requires non-empty allowlist if enabling strict mode
     */
    function setStrictOutputs(address protocol, bool strict) external onlyOwner {
        if (strict && protocolOutputs[protocol].length == 0) {
            revert EmptyAllowlist(protocol);
        }
        strictOutputs[protocol] = strict;
        emit StrictOutputsSet(protocol, strict);
    }

    /**
     * @notice Add a single output token to a protocol's allowlist
     */
    function addProtocolOutput(address protocol, address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isProtocolOutput[protocol][token]) return; // Already added

        protocolOutputs[protocol].push(token);
        isProtocolOutput[protocol][token] = true;

        emit ProtocolOutputAdded(protocol, token);
    }

    /**
     * @notice Remove a single output token from a protocol's allowlist
     */
    function removeProtocolOutput(address protocol, address token) external onlyOwner {
        if (!isProtocolOutput[protocol][token]) return; // Not in list

        // Remove from array (swap and pop)
        address[] storage tokens = protocolOutputs[protocol];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }

        isProtocolOutput[protocol][token] = false;

        emit ProtocolOutputRemoved(protocol, token);
    }

    /**
     * @notice Get all allowed output tokens for a protocol
     */
    function getProtocolOutputs(address protocol) external view returns (address[] memory) {
        return protocolOutputs[protocol];
    }

    // ============ View Functions ============

    /**
     * @notice Preview fee calculation for a given amount
     * @param amount The input amount to calculate fee for
     * @return fee The fee that would be deducted
     * @return userAmount The amount user would receive after fee
     */
    function previewFee(uint256 amount) external view returns (uint256 fee, uint256 userAmount) {
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        userAmount = amount - fee;
    }

    /**
     * @notice Preview fees for multiple amounts (batch)
     * @param amounts Array of amounts to calculate fees for
     * @return fees Array of fees that would be deducted
     * @return userAmounts Array of amounts users would receive after fees
     */
    function previewFees(uint256[] calldata amounts) external view returns (uint256[] memory fees, uint256[] memory userAmounts) {
        fees = new uint256[](amounts.length);
        userAmounts = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            fees[i] = (amounts[i] * feeBps) / BPS_DENOMINATOR;
            userAmounts[i] = amounts[i] - fees[i];
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Rescue Functions ============
    // These functions allow the owner to recover tokens stuck in the contract.
    // Stuck tokens can occur from: misconfigured allowlists, unexpected protocol
    // behavior, or tokens accidentally sent to this contract.
    //
    // Trust model: Users trust the operator to use these functions honestly.
    // This is the same trust already required for fees, pausing, and allowlists.
    // Rescue functions cannot intercept in-progress redemptions (txs are atomic).

    /**
     * @notice Rescue ERC20 tokens stuck in contract
     * @dev Use for: misconfigured allowlist redemptions, accidental transfers
     * @param token The ERC20 token address to rescue
     * @param to The recipient address (e.g., affected user or treasury)
     * @param amount The amount to rescue
     */
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance(token, amount, balance);

        IERC20(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    /**
     * @notice Rescue native ETH stuck in contract
     * @dev Sends entire ETH balance. Use for: accidental ETH transfers
     * @param to The recipient address
     */
    function rescueETH(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoETHToRescue();

        (bool success,) = to.call{value: balance}("");
        if (!success) revert ETHTransferFailed();
        emit ETHRescued(to, balance);
    }

    // ============ ETH Handling ============

    /// @notice Forward any ETH received during redemption to user (with fee)
    /// @dev Called at the end of each redemption function to handle native ETH returns
    function _forwardETH() private {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 fee = (ethBalance * feeBps) / BPS_DENOMINATOR;
            if (fee > 0) {
                (bool feeSuccess,) = feeRecipient.call{value: fee}("");
                if (!feeSuccess) revert ETHTransferFailed();
                emit FeeCollected(address(0), fee); // address(0) represents native ETH
            }
            uint256 userAmount = ethBalance - fee;
            (bool userSuccess,) = msg.sender.call{value: userAmount}("");
            if (!userSuccess) revert ETHTransferFailed();
        }
    }

    /// @notice Accept ETH from protocols that return native ETH
    receive() external payable {}
}
