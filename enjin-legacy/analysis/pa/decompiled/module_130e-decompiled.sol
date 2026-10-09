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
    address public unresolved_7457bbf7;
    address public getManager;
    address public getStorageContractAddress;
    mapping(bytes32 => bytes32) storage_map_d;
    
    event ManagerUpdate(address, address);
    event Event_dcc6ad3a();
    event TransferSingle(address, address, address, uint256, uint256);
    event Log(uint256, address, string);
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xc8b1d5e1
    /// @custom:signature   Unresolved_c8b1d5e1(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint256 arg6) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["uint256", "bytes32", "int256"]
    function Unresolved_c8b1d5e1(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint256 arg6) public payable {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
        require(!arg4 > 0x0100000000);
        require(!arg5 > 0x0100000000);
        require(address(getManager) == msg.sender);
        address var_b = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_b4c8c5c4(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsEvents: Sender is not manager or approved");
        require(var_c.length, "CryptoItemsEvents: Sender is not manager or approved");
        require(!0 < (arg0));
        require(0 < (arg0));
        require(!(uint32(0 + (0x20 + (arg0)))) == 0xc3d5816800000000000000000000000000000000000000000000000000000000);
        require(0 < (arg3));
        require(0 < (arg2));
        require(0 < (arg1));
        require(0 < (arg4));
        require(0 < (arg5));
        emit TransferSingle(address(0 + (0x20 + (arg1))), address(0 + (0x20 + (arg2))), address(0 + (0x20 + (arg3))), (0 + (0x20 + (arg4))), (0 + (0x20 + (arg5))));
        require(0 < (arg2));
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        require(0 < (arg4));
        require(0 < (arg4));
        var_b = uint64(0 + (0x20 + (arg4)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getName(var_b); // staticcall
        uint256 var_c = var_c + (uint248(ret0.length + 0x1f));
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
            require(!var_c.length > 0x0100000000);
            require(!((var_c + var_c.length) + 0x20) > (var_c + ret0.length));
            require(!((var_c + ret0.length) < (var_h + ((var_c + var_c.length) + 0x20))) | (var_h > 0x0100000000));
            require(!0 < (var_g));
            var_c = 0x20 + (var_h + (0x20 + var_c) - (bytes1(var_h)));
            var_k = 0x20;
            require(!bytes1(var_g));
        }
        require(0 < (arg5));
        require(0 < (arg3));
        require(!0x19eb765b00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(0 < (arg3));
        require(0 < (arg2));
        require(0 < (arg1));
        require(0 < (arg4));
        require(!0xc4d4c7ee00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(0 < (arg2));
        require(0 < (arg1));
        require(0 < (arg3));
        require(0 < (arg4));
        require(0 < (arg1));
        require(0 < (arg2));
        require(0 < (arg3));
        require(!0x17307eab00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0xec16055b00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0x288e588500000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0x1555f98e00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0x78eaa4bf00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0x918e15d400000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        require(!0xee1bb82f00000000000000000000000000000000000000000000000000000000 == (uint32(0 + (0x20 + (arg0)))));
        var_b = (0 + (0x20 + (arg1)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getURI(var_b); // staticcall
        var_c = var_c + (uint248(ret0.length + 0x1f));
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
            require(!var_c.length > 0x0100000000);
            require(!((var_c + var_c.length) + 0x20) > (var_c + ret0.length));
            require(!((var_c + ret0.length) < (var_h + ((var_c + var_c.length) + 0x20))) | (var_h > 0x0100000000));
            require(!0 < (var_g));
            var_c = var_k + (var_h + (0x20 + var_c) - (bytes1(var_h)));
            require(!bytes1(var_g));
        }
        emit Event_dcc6ad3a(arg6);
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
    
    /// @custom:selector    0x0aa6231e
    /// @custom:signature   Unresolved_0aa6231e(uint256 arg0, address arg1, uint256 arg2) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_0aa6231e(uint256 arg0, address arg1, uint256 arg2) public payable {
        require(!arg2 > 0x0100000000);
        require(address(getManager) == msg.sender);
        address var_b = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_b4c8c5c4(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsEvents: Sender is not manager or approved");
        require(var_c.length, "CryptoItemsEvents: Sender is not manager or approved");
        emit Log(arg0, address(arg1), (0x20 + var_c) - var_c, (arg2));
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
}