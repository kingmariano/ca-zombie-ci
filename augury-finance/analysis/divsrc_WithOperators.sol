// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WithOperators is Ownable {
    
    mapping(address => bool) public operators;

    event OperatorUpdated(address indexed operator, bool indexed status);

    constructor() {
        operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Operable: caller is not the operator");
        _;
    }

    function updateOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
        
        emit OperatorUpdated(_operator, _status);
    }
}
