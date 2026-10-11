// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * IHordETHStakingManager contract.
 * @author Srdjan Simonovic
 * Date created: 28.03.23.
 * Github: s2imonovic
 */
interface IHordETHStakingManager {
    function balanceOf(address account) external view returns (uint256);
    function getAmountOfHETHforETH(uint256 amountETH, bool isContractCall, uint256 diffExecLayerRewardsForFeelCalc) external view returns (uint256 result);
    function burn(address account, uint256 amount) external;
    function moveETHToAssuredBalance(uint256 amountETH) external;
    function userDepositETH() payable external;
}
