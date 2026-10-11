// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

interface IWrappedToken {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function approve(address guy, uint wad) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}
