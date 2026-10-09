// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface ICircuitBreaker {
    function pauseStartTime(address _token) external returns (uint);

    function pauseEndTime(address _token) external returns (uint);

    function maxLongToShortRatio(address _token) external returns (uint);

    function maxShortToLongRatio(address _token) external returns (uint);

    function oiRatioCheckThreshold(address _token) external returns (uint);

    function validateCircuitBreaker(address _indexToken, uint _sizeDelta, bool _isLong) external;
}
