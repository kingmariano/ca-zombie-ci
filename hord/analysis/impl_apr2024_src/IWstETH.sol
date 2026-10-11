//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}
