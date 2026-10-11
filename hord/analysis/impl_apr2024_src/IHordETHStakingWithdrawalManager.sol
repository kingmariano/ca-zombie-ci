// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * IHordETHStakingWithdrawalManager contract.
 * @author Srdjan Simonovic
 * Date created: 28.03.23.
 * Github: s2imonovic
 */
interface IHordETHStakingWithdrawalManager {
    function receiveETHInAssuredBalance() payable external;
    function payOfDebtFromValidatorsFunds(uint256 startIndex, uint256 endIndex) payable external;
    function totalPendingDebt() external view returns(uint256);
    function amountTakenFromBuffer() external view returns(uint256);
    function hordETHStakingManagerDebt() external view returns(uint256);
}
