// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface ISphereSettings {

  struct Fees {
    uint burnFee;
    uint buyGalaxyBondFee;
    uint liquidityFee;
    uint realFeePartyArray;
    uint riskFreeValueFee;
    uint sellBurnFee;
    uint sellFeeRFVAdded;
    uint sellFeeTreasuryAdded;
    uint sellGalaxyBond;
    uint treasuryFee;
    uint totalBuyFee;
    uint totalSellFee;
    bool isTaxBracketEnabledInMoveFee;
  }

  function currentFees() external view returns (Fees memory);

  event SetFees(Fees fees);


}
