// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IBounceBitToken {
    function mint(address to, uint256 amount) external;

    function burnFor(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
