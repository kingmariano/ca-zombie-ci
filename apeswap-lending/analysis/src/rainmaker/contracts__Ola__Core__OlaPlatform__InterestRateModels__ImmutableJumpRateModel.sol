pragma solidity ^0.5.16;

import "./BaseImmutableJumpRateModel.sol";
import "./InterestRateModel.sol";


/**
  * @title Compound's JumpRateModel Contract V2 for V2 cTokens
  * @author Arr00
  * @notice Supports only for V2 cTokens
  */
contract ImmutableJumpRateModel is InterestRateModel, BaseImmutableJumpRateModel  {

	/**
     * @notice Calculates the current borrow rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint) {
        return getBorrowRateInternal(cash, borrows, reserves);
    }

    constructor(uint blocksPerYear_, uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_)
        BaseImmutableJumpRateModel(blocksPerYear_, baseRatePerYear,multiplierPerYear,jumpMultiplierPerYear,kink_) public {}
}
