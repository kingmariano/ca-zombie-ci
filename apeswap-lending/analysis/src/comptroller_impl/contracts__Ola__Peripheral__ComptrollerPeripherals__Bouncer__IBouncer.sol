pragma solidity ^0.5.16;

contract IBouncer {
    bool public isBouncer = true;
    bytes32 public contractNameHash;

    function isAccountApproved(address account) external view returns (bool);
}