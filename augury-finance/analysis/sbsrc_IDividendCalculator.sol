// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol';

import './IOperable.sol';

interface IDividendCalculator is IOperable {

  function calculateUnclaimedDividends(address _userAddress) external view returns (uint256);
  
  function collectDividends() external;
}
