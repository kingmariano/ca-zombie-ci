// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "contracts/interfaces/IRewardsDistributor.sol";

interface IMinter {
    function updatePeriod() external returns (uint256);

    function activePeriod() external view returns (uint256);

    function rewardsDistributor() external view returns (IRewardsDistributor);

    function timelock() external view returns (address);

    function msig() external view returns (address);
}
