// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * IStakingConfiguration contract.
 * @author SrdjanSimonovic
 * Date created: 25.10.22.
 * Github: s2imonovic
 */
interface IStakingConfiguration {
    function feeRecipient() external view returns(address);
    function financeAddress() external view returns(address);
    function stakeETHTokenName() external view returns(string memory);
    function stakeETHTokenSymbol() external view returns(string memory);
    function amountETHInValidator() external view returns(uint256);
    function rewardFeePercentage() external view returns(uint256);
    function tolerancePercentageForRewards() external view returns(uint256);
    function tolerancePercentageForFee() external view returns(uint256);
    function shortCoolDownPeriod() external view returns(uint256);
    function longCoolDownPeriod() external view returns(uint256);
    function percentPrecision() external view returns(uint256);
    function percentFeeFromWithdrawal() external view returns(uint256);
    function percentFeeFromWithdrawalMicroTx() external view returns(uint256);
    function ethWithdrawalMicroTxThreshold() external view returns(uint256);
    function priceSlippageThreshold() external view returns(uint256);
    function timeBetweenSetStatsCalls() external view returns(uint256);
}
