// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol';

import './libs/IOperable.sol';

contract Operators is Ownable, IOperable {
    mapping(address => bool) public operators;

    event OperatorUpdated(address indexed operator, bool indexed status);

    constructor () internal {
        operators[msg.sender] = true;
        emit OperatorUpdated(msg.sender, true);
    }

    modifier onlyOperator() {
        require(operators[msg.sender], 'Operator: caller is not the operator');
        _;
    }

    // Update the status of the operator
    function updateOperator(address _operator, bool _status) external override onlyOwner {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }
}
