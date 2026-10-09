// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPositionManager {
    function maxGlobalLongSizes(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function executeIncreaseOrder(address, uint256, address payable) external;
    function executeDecreaseOrder(address, uint256, address payable) external;
    function executeSwapOrder(address, uint256, address payable) external;
}
