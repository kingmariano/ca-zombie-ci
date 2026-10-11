// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICvxCrvRewards {
    function withdraw(uint256 amount, bool claim) external returns (bool);
    function withdrawAll(bool claim) external;
    function stakeFor(address, uint256) external;
}
