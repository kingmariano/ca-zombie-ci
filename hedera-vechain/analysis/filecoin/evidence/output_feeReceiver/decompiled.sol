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
    address public getFactors;
    
    event Transferred(address, uint256);
    event OwnerChanged(address);
    
    /// @custom:selector    0xa6f9dae1
    /// @custom:signature   changeOwner(address arg0) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function changeOwner(address arg0) public payable returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(arg0 - (address(arg0)));
        require(!(msg.sender == (address(getFactors))), "Not owner");
        require(!(address(arg0)), "Invalid owner");
        getFactors = (address(arg0)) | (uint96(getFactors));
        emit OwnerChanged(address(arg0));
        return ;
    }
    
    /// @custom:selector    0xa9059cbb
    /// @custom:signature   transfer(address arg0, uint256 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function transfer(address arg0, uint256 arg1) public payable returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x40);
        require(arg0 - (address(arg0)));
        require(!(msg.sender == (address(getFactors))), "Not owner");
        require(arg1 > address(this).balance, "Invalid amount");
        emit Transferred(address(arg0), arg1);
        require(!arg1);
        (bool success, bytes memory ret0) = address(arg0).transfer(arg1);
        return ;
    }
    
    /// @custom:selector    0xa3a7e7f3
    /// @custom:signature   transferAll(address arg0) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferAll(address arg0) public payable returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(arg0 - (address(arg0)));
        require(!(msg.sender == (address(getFactors))), "Not owner");
        emit Transferred(address(arg0), address(this).balance);
        require(!address(this).balance);
        (bool success, bytes memory ret0) = address(arg0).transfer(address(this).balance);
        return ;
        (bool success, bytes memory ret0) = address(arg0).transfer(address(this).balance);
        return ;
    }
}