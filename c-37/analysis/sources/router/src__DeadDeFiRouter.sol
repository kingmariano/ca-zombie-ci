// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IAdapter.sol";

/**
 * @title DeadDeFiRouter
 * @notice Single-entry-point router for redeeming tokens from dead DeFi protocols
 * @dev Delegates protocol-specific logic to registered Adapter contracts.
 *      Users approve the Router once; new protocols are added via lightweight adapters.
 */
contract DeadDeFiRouter is ReentrancyGuard, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    // ============ State ============
    uint256 public feeBps = 300; // 3% in basis points
    uint256 public constant MAX_FEE_BPS = 500; // Cap at 5%
    uint256 private constant BPS_DENOMINATOR = 10000;
    address public feeRecipient;

    mapping(address => bool) public registeredAdapters;

    // ============ Events ============
    event Redeemed(
        address indexed user,
        address indexed adapter,
        address indexed inputToken,
        uint256 amountIn,
        address[] tokensOut,
        uint256[] amountsOut,
        uint256[] feesCollected
    );
    event FeeCollected(address indexed token, uint256 amount);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FeeBpsChanged(uint256 oldBps, uint256 newBps);
    event AdapterRegistered(address indexed adapter);
    event AdapterRemoved(address indexed adapter);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);
    event ETHRescued(address indexed to, uint256 amount);

    // ============ Errors ============
    error ZeroAddress();
    error FeeTooHigh();
    error EmptyOutputTokens();
    error ArrayLengthMismatch();
    error AdapterNotRegistered(address adapter);
    error AdapterAlreadyRegistered(address adapter);
    error SlippageExceeded(uint256 index, uint256 received, uint256 minimum);
    error ETHTransferFailed();
    error InsufficientBalance(address token, uint256 requested, uint256 available);
    error NoETHToRescue();

    // ============ Constructor ============
    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    /// @notice Accept ETH forwarded from adapters
    receive() external payable {}

    // ============ Core Redemption ============

    /**
     * @notice Redeem tokens through a registered adapter
     * @param adapter The adapter contract to use
     * @param inputToken The token to redeem
     * @param amount Amount of input tokens
     * @param outputTokens Expected output token addresses
     * @param minAmountsOut Minimum amounts per token after fees (slippage protection)
     */
    function redeem(
        address adapter,
        address inputToken,
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external nonReentrant whenNotPaused {
        // Validate
        if (!registeredAdapters[adapter]) revert AdapterNotRegistered(adapter);
        if (outputTokens.length == 0) revert EmptyOutputTokens();
        if (outputTokens.length != minAmountsOut.length) revert ArrayLengthMismatch();

        // Pull input tokens from user
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amount);

        // Snapshot output token balances before
        uint256[] memory balancesBefore = new uint256[](outputTokens.length);
        for (uint256 i = 0; i < outputTokens.length; i++) {
            balancesBefore[i] = IERC20(outputTokens[i]).balanceOf(address(this));
        }

        // Send input tokens to adapter and call redeem
        IERC20(inputToken).safeTransfer(adapter, amount);
        IAdapter(adapter).redeem(inputToken, amount, outputTokens);

        // Process outputs: measure diff, take fee, check slippage, distribute
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
                revert SlippageExceeded(i, 0, minAmountsOut[i]);
            }
        }

        // Forward any ETH received during redemption
        _forwardETH();

        emit Redeemed(msg.sender, adapter, inputToken, amount, outputTokens, amountsOut, fees);
    }

    // ============ Adapter Registry ============

    function registerAdapter(address adapter) external onlyOwner {
        if (adapter == address(0)) revert ZeroAddress();
        if (registeredAdapters[adapter]) revert AdapterAlreadyRegistered(adapter);
        registeredAdapters[adapter] = true;
        emit AdapterRegistered(adapter);
    }

    function removeAdapter(address adapter) external onlyOwner {
        if (!registeredAdapters[adapter]) revert AdapterNotRegistered(adapter);
        registeredAdapters[adapter] = false;
        emit AdapterRemoved(adapter);
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Rescue Functions ============

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance(token, amount, balance);
        IERC20(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    function rescueETH(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoETHToRescue();
        (bool success,) = to.call{value: balance}("");
        if (!success) revert ETHTransferFailed();
        emit ETHRescued(to, balance);
    }

    // ============ View Functions ============

    function previewFee(uint256 amount) external view returns (uint256 fee, uint256 userAmount) {
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        userAmount = amount - fee;
    }

    // ============ Internal ============

    /// @notice Forward ETH balance to caller with fee deduction (matches ERC20 fee logic)
    function _forwardETH() private {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 fee = (ethBalance * feeBps) / BPS_DENOMINATOR;
            uint256 userAmount = ethBalance - fee;

            if (fee > 0) {
                (bool feeSuccess,) = feeRecipient.call{value: fee}("");
                if (!feeSuccess) revert ETHTransferFailed();
                emit FeeCollected(address(0), fee);
            }

            (bool success,) = msg.sender.call{value: userAmount}("");
            if (!success) revert ETHTransferFailed();
        }
    }
}
