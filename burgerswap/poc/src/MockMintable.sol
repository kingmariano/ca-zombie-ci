// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Positive-control token: freely mintable by anyone (used ONLY on the fork
///      to prove the platform's stale-reserve/balance-inflation path is exploitable
///      when an inflatable token is paired with real value).
contract MockMintable {
    string public name = "Mock Mintable";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 v) external {
        balanceOf[to] += v;
        totalSupply += v;
    }

    function approve(address s, uint256 v) external returns (bool) {
        allowance[msg.sender][s] = v;
        return true;
    }

    function transfer(address to, uint256 v) external returns (bool) {
        require(balanceOf[msg.sender] >= v, "balance");
        balanceOf[msg.sender] -= v;
        balanceOf[to] += v;
        return true;
    }

    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        require(allowance[f][msg.sender] >= v, "allowance");
        allowance[f][msg.sender] -= v;
        require(balanceOf[f] >= v, "balance");
        balanceOf[f] -= v;
        balanceOf[t] += v;
        return true;
    }
}
