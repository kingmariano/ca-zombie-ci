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
    address public getManager;
    address public getStorageContractAddress;
    address public unresolved_7457bbf7;
    mapping(bytes32 => bytes32) storage_map_d;
    
    event ManagerUpdate(address, address);
    event ApprovalForAll(address, address, bool);
    
    /// @custom:selector    0xe985e9c5
    /// @custom:signature   isApprovedForAll(address arg0, address arg1) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function isApprovedForAll(address arg0, address arg1) public payable returns (bool) {
        uint256 var_b = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_e.length;
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xa22cb465
    /// @custom:signature   Unresolved_a22cb465(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_a22cb465(address arg0, uint256 arg1) public payable {
        uint256 var_b = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_bf73f5b2(var_b); // call
        emit ApprovalForAll(msg.sender, address(arg0), arg1);
    }
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_d[var_b]);
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        require(!(address(getManager) == (address(arg0))), "Managed: New manager needs to be different");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0x4e1273f4
    /// @custom:signature   balanceOfBatch(address[] arg0, uint256[] arg1) public payable returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function balanceOfBatch(address[] arg0, uint256[] arg1) public payable returns (bytes memory) {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        require(arg0 == (arg1), "CryptoItems1155: _ids.length is different from _owners.length");
        uint256 var_c = (var_c + (arg1 * 0x20)) + 0x20;
        require(!arg1);
        require(!0 < (arg1));
        require(0 < (arg1));
        require(uint64(0 + (0x20 + (arg1))));
        uint256 var_d = (0 + (0x20 + (arg1)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_7d686379(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(0 < (arg0));
        require(address(var_c.length) == (address(0 + (0x20 + (arg0)))));
        require(0 < (arg0));
        var_d = (0 + (0x20 + (arg1)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_b0a79459(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!0 < (var_c.length * 0x20));
        return abi.encodePacked(0x20, var_c.length);
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x0e89341c
    /// @custom:signature   Unresolved_0e89341c(uint64 arg0) public payable returns (bytes memory)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_0e89341c(uint64 arg0) public payable returns (bytes memory) {
        require(!uint0(arg0));
        require(uint0(arg0));
        uint64 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_1aa347dc(var_b); // staticcall
        uint256 var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x20);
        require(!var_c.length > 0x0100000000);
        require(!((var_c + var_c.length) + 0x20) > (var_c + ret0.length));
        require(!((var_c + ret0.length) < (var_d + ((var_c + var_c.length) + 0x20))) | (var_d > 0x0100000000));
        require(!0 < (var_f));
        require(!bytes1(var_f));
        var_c = 0x20 + (var_d + (0x20 + var_c) - (bytes1(var_d)));
        require(!bytes1(var_c.length));
        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_l));
        return abi.encodePacked(0x20, var_c.length);
        require(!uint64(arg0));
        var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_e5230867(var_b, var_m); // staticcall
        require(!(ret0.length < 0x20), "CryptoItems1155: Invalid NFI index");
        require(!(uint64(arg0) > (uint64(var_c.length))), "CryptoItems1155: Invalid NFI index");
        if (!uint0(arg0)) {
        }
    }
}