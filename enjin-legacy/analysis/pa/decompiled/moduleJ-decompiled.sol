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
    
    /// @custom:selector    0x4049ddd2
    /// @custom:signature   Unresolved_4049ddd2(uint0 arg0) public pure returns (uint256)
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    function Unresolved_4049ddd2(uint0 arg0) public pure returns (uint256) {
        require(uint0(arg0));
        require(!0x40000000000000000000000000000000000000000000000000000000000000 == (uint0(arg0)));
        return 0x01;
        require(!0x20000000000000000000000000000000000000000000000000000000000000 == (uint0(arg0)));
        return 0x02;
        return 0x03;
        return 0;
    }
    
    /// @custom:selector    0x7e2c20ad
    /// @custom:signature   Unresolved_7e2c20ad(uint0 arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_7e2c20ad(uint0 arg0, uint256 arg1, uint256 arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        uint256 var_c = var_c + 0x26;
        var_e = keccak256(var_f);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_e); // staticcall
        require(!ret0.length < 0x20);
        require(address(var_c.length) == msg.sender);
        uint0 var_e = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_e); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsReplicate: Bridge is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsReplicate: Bridge is not the creator of _id");
        require(uint0(arg0));
        var_e = address(getStorageContractAddress);
        require(address(0xd00eb8c4630601f76504acb642069752d22e87e0).code.length);
        (bool success, bytes memory ret0) = address(0xd00eb8c4630601f76504acb642069752d22e87e0).Unresolved_1abbfb97(var_e); // delegatecall
    }
    
    /// @custom:selector    0xfb2b9992
    /// @custom:signature   Unresolved_fb2b9992(uint0 arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_fb2b9992(uint0 arg0, uint256 arg1, uint256 arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        uint256 var_c = var_c + 0x26;
        var_e = keccak256(var_f);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_e); // staticcall
        require(!ret0.length < 0x20);
        require(address(var_c.length) == msg.sender);
        uint0 var_e = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_e); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsReplicate: Bridge is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsReplicate: Bridge is not the creator of _id");
        require(uint0(arg0));
        var_e = address(getStorageContractAddress);
        require(address(0xd00eb8c4630601f76504acb642069752d22e87e0).code.length);
        (bool success, bytes memory ret0) = address(0xd00eb8c4630601f76504acb642069752d22e87e0).Unresolved_8b7f0348(var_e); // delegatecall
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
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
    
    /// @custom:selector    0x28dbff7b
    /// @custom:signature   Unresolved_28dbff7b(uint0 arg0, uint256 arg1, address arg2, uint32 arg3, uint256 arg4, address arg5, uint256 arg6, uint16 arg7, bool arg8) public payable
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint32", "bytes4", "int32"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg6 ["uint256", "bytes32", "int256"]
    /// @param              arg7 ["uint16", "bytes2", "int16"]
    /// @param              arg8 ["bool", "uint8", "bytes1", "int8"]
    function Unresolved_28dbff7b(uint0 arg0, uint256 arg1, address arg2, uint32 arg3, uint256 arg4, address arg5, uint256 arg6, uint16 arg7, bool arg8) public payable {
        require(!arg1 > 0x0100000000);
        uint256 var_c = var_c + 0x26;
        var_e = keccak256(var_f);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_e); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsReplicate: _id is from the current chain");
        require(address(var_c.length) == msg.sender, "CryptoItemsReplicate: _id is from the current chain");
        require(uint0(arg0), "CryptoItemsReplicate: _id is from the current chain");
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xa3c4f748
    /// @custom:signature   Unresolved_a3c4f748(uint0 arg0) public payable returns (bool)
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    function Unresolved_a3c4f748(uint0 arg0) public payable returns (bool) {
        require(!uint0(arg0));
        uint0 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f521a982(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length > 0);
        require(!(uint0(arg0)) == 0x80000000000000000000000000000000000000000000000000000000000000);
        var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_7d686379(var_b); // staticcall
        require(!ret0.length < 0x20);
        return !(address(var_c.length) == 0);
        return !(!var_c.length > 0);
        return 0;
    }
    
    /// @custom:selector    0x2df3f42a
    /// @custom:signature   Unresolved_2df3f42a(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_2df3f42a(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xd00eb8c4630601f76504acb642069752d22e87e0).code.length);
        (bool success, bytes memory ret0) = address(0xd00eb8c4630601f76504acb642069752d22e87e0).Unresolved_7ab00f4e(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0x3941412b
    /// @custom:signature   Unresolved_3941412b(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_3941412b(uint256 arg0, uint256 arg1) public payable {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        uint256 var_c = var_c + 0x26;
        var_e = keccak256(var_f);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_e); // staticcall
        require(!ret0.length < 0x20);
        require(address(var_c.length) == msg.sender);
        address var_e = address(getStorageContractAddress);
        require(address(0xd00eb8c4630601f76504acb642069752d22e87e0).code.length);
        (bool success, bytes memory ret0) = address(0xd00eb8c4630601f76504acb642069752d22e87e0).Unresolved_be460500(var_e); // delegatecall
    }
}