// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @notice Minimal interface for Aave V1 aTokens
interface IAToken {
    function underlyingAssetAddress() external view returns (address);
    function redeem(uint256 _amount) external;
}

/**
 * @title AaveV1Redemption
 * @notice Standalone contract for redeeming Aave V1 aTokens with fee collection
 * @dev Handles both ERC20 and native ETH (aETH) redemptions
 *      Deployed separately from main DeadDeFiRedemption for faster shipping
 */
contract AaveV1Redemption is ReentrancyGuard, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    // ============ State ============
    uint256 public feeBps = 300; // 3% in basis points
    uint256 public constant MAX_FEE_BPS = 500; // Cap at 5%
    uint256 private constant BPS_DENOMINATOR = 10000;
    address public feeRecipient;

    // ETH marker used by Aave V1 for aETH underlying
    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ============ Events ============
    event Redeemed(
        address indexed user,
        address indexed aToken,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        uint256 fee
    );
    event FeeCollected(address indexed token, uint256 amount);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FeeBpsChanged(uint256 oldBps, uint256 newBps);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);
    event ETHRescued(address indexed to, uint256 amount);

    // ============ Errors ============
    error SlippageExceeded(uint256 received, uint256 minimum);
    error ETHTransferFailed();
    error ZeroAddress();
    error FeeTooHigh();
    error InsufficientBalance(address token, uint256 requested, uint256 available);
    error NoETHToRescue();

    // ============ Constructor ============
    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    /// @notice Accept ETH from aToken redemptions (aETH returns native ETH)
    receive() external payable {}

    // ============ Redemption ============

    /**
     * @notice Redeem Aave V1 aToken for underlying asset
     * @param aToken The aToken address to redeem
     * @param amount Amount of aTokens to redeem
     * @param minAmountOut Minimum amount to receive after fees (slippage protection)
     * @dev Handles both ERC20 and native ETH (aETH) automatically
     */
    function redeemAaveV1(
        address aToken,
        uint256 amount,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused {
        // Get underlying asset from aToken
        address underlying = IAToken(aToken).underlyingAssetAddress();
        bool isETH = underlying == ETH_ADDRESS;

        // Transfer aTokens from user to this contract
        IERC20(aToken).safeTransferFrom(msg.sender, address(this), amount);

        // Snapshot balance before redemption
        uint256 balanceBefore = isETH
            ? address(this).balance
            : IERC20(underlying).balanceOf(address(this));

        // Execute redemption
        IAToken(aToken).redeem(amount);

        // Calculate received amount
        uint256 received = isETH
            ? address(this).balance - balanceBefore
            : IERC20(underlying).balanceOf(address(this)) - balanceBefore;

        if (received > 0) {
            uint256 fee = (received * feeBps) / BPS_DENOMINATOR;
            uint256 userAmount = received - fee;

            // Slippage check (post-fee)
            if (userAmount < minAmountOut) revert SlippageExceeded(userAmount, minAmountOut);

            if (isETH) {
                // Send fee
                if (fee > 0) {
                    (bool feeOk,) = feeRecipient.call{value: fee}("");
                    if (!feeOk) revert ETHTransferFailed();
                    emit FeeCollected(address(0), fee);
                }
                // Send remainder to user
                (bool userOk,) = msg.sender.call{value: userAmount}("");
                if (!userOk) revert ETHTransferFailed();
            } else {
                // Send fee
                if (fee > 0) {
                    IERC20(underlying).safeTransfer(feeRecipient, fee);
                    emit FeeCollected(underlying, fee);
                }
                // Send remainder to user
                IERC20(underlying).safeTransfer(msg.sender, userAmount);
            }

            emit Redeemed(
                msg.sender,
                aToken,
                amount,
                isETH ? address(0) : underlying,
                userAmount,
                fee
            );
        } else if (minAmountOut > 0) {
            // User expected tokens but got none
            revert SlippageExceeded(0, minAmountOut);
        }
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

    /**
     * @notice Rescue ERC20 tokens stuck in contract
     * @param token The ERC20 token address
     * @param to The recipient address
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

    // ============ View Functions ============

    /**
     * @notice Preview fee calculation for a given amount
     * @param amount The input amount
     * @return fee The fee that would be deducted
     * @return userAmount The amount user would receive after fee
     */
    function previewFee(uint256 amount) external view returns (uint256 fee, uint256 userAmount) {
        fee = (amount * feeBps) / BPS_DENOMINATOR;
        userAmount = amount - fee;
    }
}
