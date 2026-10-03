// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.7.5;

import './IERC20.sol';

interface ISphereToken is IERC20 {
    function currentIndex() external view returns (uint256);
}
