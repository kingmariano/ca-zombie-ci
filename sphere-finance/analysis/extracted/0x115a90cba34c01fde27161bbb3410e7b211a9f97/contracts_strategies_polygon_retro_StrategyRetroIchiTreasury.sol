pragma solidity ^0.8.0;

import "./StrategyRetroIchi.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract StrategyRetroIchiTreasury is StrategyRetroIchi {
  using SafeERC20Upgradeable for IERC20Upgradeable;


  uint256 public nativeProfit;

  function initialize(
    address _want,
    bytes calldata _outputToNativePath,
    bytes calldata _nativeToLpPath,
    Flash calldata _flash,
    address[] memory _addresses
  ) public virtual override initializer {
    StrategyRetroIchi.initialize(_want, _outputToNativePath, _nativeToLpPath, _flash, _addresses);
  }

  // compounds earnings and charges performance fee
  function _harvest() internal whenNotPaused virtual override {
    uint256 outputBal = IERC20Upgradeable(oRetro).balanceOf(address(this));
    if (outputBal > 0) {
      swapRewardsToNative();
      chargeFees();

      lastHarvest = block.timestamp;
      emit StratHarvest(msg.sender, 0, balanceOf());
    }
  }

  /**
   * @dev Charges performance fees.
   */
  function chargeFees() internal virtual override {
    uint256 generalFeeOnProfits = (IERC20Upgradeable(cash).balanceOf(address(this)));
    nativeProfit += generalFeeOnProfits;

    // Calculating the Fee to be distributed
    uint256 feeAmount1 = (generalFeeOnProfits * fee1) / MAX_FEE;
    uint256 feeAmount2 = (generalFeeOnProfits * fee2) / MAX_FEE;
    uint256 strategistFeeAmount = (generalFeeOnProfits * strategistFee) / MAX_FEE;

    // Transfer fees to recipients
    if (feeAmount1 > 0) {
      IERC20Upgradeable(cash).safeTransfer(feeRecipient1, feeAmount1);
    }
    if (feeAmount2 > 0) {
      IERC20Upgradeable(cash).safeTransfer(feeRecipient2, feeAmount2);
    }
    if (strategistFeeAmount > 0) {
      IERC20Upgradeable(cash).safeTransfer(strategist, strategistFeeAmount);
    }
  }

  function uniswapV3FlashCallback(uint256 _fee0, uint256 _fee1, bytes calldata) external override {
    if (msg.sender != flash.pool) revert NotPair();
    if (!flash.flashEntered) revert InvalidFlash();

    uint256 cashAmount = IERC20Upgradeable(cash).balanceOf(address(this));
    uint256 oRetroAmt = IERC20Upgradeable(oRetro).balanceOf(address(this));
    IOToken(oRetro).exercise(oRetroAmt, cashAmount, address(this));

    UniV3Actions.swapV3WithDeadline(dystRouter, flash.outputToCash, IERC20Upgradeable(output).balanceOf(address(this)));

    uint256 fee = flash.token0 ? _fee0 : _fee1;
    uint256 pairDebt = cashAmount + fee;
    IERC20Upgradeable(cash).transfer(flash.pool, pairDebt);
    flash.flashEntered = false;
  }
}
