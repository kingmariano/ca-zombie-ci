// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPositionRouter {
    function increasePositionRequestKeysStart() external returns (uint256);
    function decreasePositionRequestKeysStart() external returns (uint256);
    function executeIncreasePositions(uint256 _count, address payable _executionFeeReceiver) external;
    function executeDecreasePositions(uint256 _count, address payable _executionFeeReceiver) external;
    function maxGlobalLongSizes(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function feeReserves(address _token) external returns (uint256);
    function withdrawFees(address _token, address _receiver) external;
}
