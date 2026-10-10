// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title            Decompiled Contract
/// @author           Jonathan Becker <jonathan@jbecker.dev>
/// @custom:version   heimdall-rs v0.9.2
///
/// @notice           This contract was decompiled using the heimdall-rs decompiler.
///                     It was generated directly by tracing the EVM opcodes from this contract.
///                     As a result, it may not compile or even be valid solidity code.
///                     Despite this, it should be obvious what each function does. Overall
///                     logic should have been preserved throughout decompiling.
///
/// @custom:github    You can find the open-source decompiler here:
///                       https://heimdall.rs

contract DecompiledContract {
    mapping(bytes32 => bytes32) storage_map_a;
    string public name;
    bool public decimals;
    mapping(bytes32 => bytes32) storage_map_b;
    string public symbol;
    
    event Approval(address, address, uint256);
    event Transfer(address, address, uint256);
    event Deposit(address, uint256);
    event Withdrawal(address, uint256);
    
    /// @custom:selector    0x095ea7b3
    /// @custom:signature   approve(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function approve(address arg0, uint256 arg1) public returns (bool) {
        var_a = address(arg0);
        storage_map_a[var_a] = arg1;
        emit Approval(address(msg.sender), address(arg0), arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x18160ddd
    /// @custom:signature   totalSupply() public view returns (uint256)
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }
    
    /// @custom:selector    0xd0e30db0
    /// @custom:signature   deposit() public payable
    function deposit() public payable {
        address var_a = address(msg.sender);
        storage_map_a[var_a] = msg.value + storage_map_a[var_a];
        emit Deposit(address(msg.sender), msg.value);
    }
    
    /// @custom:selector    0xdd62ed3e
    /// @custom:signature   allowance(address arg0, address arg1) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function allowance(address arg0, address arg1) public view returns (uint256) {
        address var_b = address(arg0);
        var_b = address(arg1);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0xa9059cbb
    /// @custom:signature   transfer(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function transfer(address arg0, uint256 arg1) public returns (bool) {
        address var_a = address(msg.sender);
        require(!storage_map_a[var_a] < arg1);
        require(address(msg.sender) == (address(msg.sender)));
        var_a = address(msg.sender);
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff == storage_map_a[var_a]);
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        var_a = address(arg0);
        storage_map_a[var_a] = arg1 + storage_map_a[var_a];
        emit Transfer(address(msg.sender), address(arg0), arg1);
        return 0x01;
        var_a = address(msg.sender);
        require(!storage_map_a[var_a] < arg1);
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        var_a = address(arg0);
        storage_map_a[var_a] = arg1 + storage_map_a[var_a];
        emit Transfer(address(msg.sender), address(arg0), arg1);
        return 0x01;
        if (address(msg.sender) == (address(msg.sender))) {
            var_a = address(msg.sender);
            storage_map_a[var_a] = storage_map_a[var_a] - arg1;
            var_a = address(arg0);
            storage_map_a[var_a] = arg1 + storage_map_a[var_a];
            emit Transfer(address(msg.sender), address(arg0), arg1);
            return 0x01;
        }
    }
    
    /// @custom:selector    0x23b872dd
    /// @custom:signature   transferFrom(address arg0, address arg1, uint256 arg2) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function transferFrom(address arg0, address arg1, uint256 arg2) public returns (bool) {
        address var_a = address(arg0);
        require(!storage_map_a[var_a] < arg2);
        require(address(arg0) == (address(msg.sender)));
        var_a = address(msg.sender);
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff == storage_map_a[var_a]);
        var_a = address(arg0);
        storage_map_a[var_a] = storage_map_a[var_a] - arg2;
        var_a = address(arg1);
        storage_map_a[var_a] = arg2 + storage_map_a[var_a];
        emit Transfer(address(arg0), address(arg1), arg2);
        return 0x01;
        var_a = address(msg.sender);
        require(!storage_map_a[var_a] < arg2);
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg2;
        var_a = address(arg0);
        storage_map_a[var_a] = storage_map_a[var_a] - arg2;
        var_a = address(arg1);
        storage_map_a[var_a] = arg2 + storage_map_a[var_a];
        emit Transfer(address(arg0), address(arg1), arg2);
        return 0x01;
        if (address(arg0) == (address(msg.sender))) {
            var_a = address(arg0);
            storage_map_a[var_a] = storage_map_a[var_a] - arg2;
            var_a = address(arg1);
            storage_map_a[var_a] = arg2 + storage_map_a[var_a];
            emit Transfer(address(arg0), address(arg1), arg2);
            return 0x01;
        }
    }
    
    /// @custom:selector    0x70a08231
    /// @custom:signature   balanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function balanceOf(address arg0) public view returns (uint256) {
        address var_b = address(arg0);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0x2e1a7d4d
    /// @custom:signature   withdraw(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function withdraw(uint256 arg0) public {
        address var_a = address(msg.sender);
        require(!storage_map_a[var_a] < arg0);
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg0;
        (bool success, bytes memory ret0) = address(msg.sender).transfer(arg0);
        emit Withdrawal(address(msg.sender), arg0);
    }
}