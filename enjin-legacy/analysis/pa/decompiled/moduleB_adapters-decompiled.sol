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
    event TransferSingle(address, address, address, uint256, uint256);
    event Event_402d6583();
    event Event_f5d46ba3();
    event ApprovalForAll(address, address, bool);
    
    /// @custom:selector    0xddeadbb6
    /// @custom:signature   getAdapter(uint256 arg0) public payable returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getAdapter(uint256 arg0) public payable returns (address) {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ec9d633d(var_b); // staticcall
        require(!ret0.length < 0x20);
        return address(var_c.length);
    }
    
    /// @custom:selector    0x33d332ab
    /// @custom:signature   Unresolved_33d332ab(uint0 arg0, uint256 arg1, bool arg2) public payable returns (address)
    /// @param              arg0 ["uint0", "bytes0", "int0"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["bool", "uint8", "bytes1", "int8"]
    function Unresolved_33d332ab(uint0 arg0, uint256 arg1, bool arg2) public payable returns (address) {
        require(!arg1 > 0x0100000000);
        uint0 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(address(var_c.length)) == msg.sender);
        var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ec9d633d(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: Cannot deploy an adaptor on a single non fungible id");
        require(address(var_c.length), "CryptoItemsAdapters: Cannot deploy an adaptor on a single non fungible id");
        return address(var_c.length);
        require(uint0(arg0), "CryptoItemsAdapters: Cannot deploy an adaptor on a single non fungible id");
        require(!(uint64(arg0)), "CryptoItemsAdapters: Cannot deploy an adaptor on a single non fungible id");
        var_b = 0x7f089af0eea9a5635be3f57a5189d3be94e003da50158cba8b832b03bed17b53;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: vtable is 0");
        require(address(var_c.length), "CryptoItemsAdapters: vtable is 0");
        var_b = 0x20;
        assembly { addr := create(0, var_c, var_b + ((0x01c9 + var_c) - var_c)) }
        require(240);
        var_b = arg0;
        require(address(240).code.length);
        (bool success, bytes memory ret0) = address(240).{ value: 0 ether }Unresolved_fe4b84df(var_b); // call
        var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_7b129b06(var_b); // call
        emit Event_f5d46ba3(arg0, msg.sender, address(240));
        return address(240);
        var_b = 0x3f55d0c208b5fd6b37166a1ac11406796c96750b055a0d4cb66f259f872ba288;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_21f8a721(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!arg1);
        var_b = arg0;
        uint256 var_j = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_j ether }Unresolved_40550b94(var_b); // call
        uint256 var_m = 0;
        emit Event_402d6583(arg0, (0x20 + var_c) - var_c, (arg1));
        require(uint0(arg0));
        require(!bytes1(arg2));
        var_b = arg0;
        var_d = bytes1(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_m ether }setDecimals(var_b, var_d); // call
    }
    
    /// @custom:selector    0x41c1df0e
    /// @custom:signature   Unresolved_41c1df0e(address arg0, address arg1, address arg2, uint64 arg3) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint64", "bytes8", "int64"]
    function Unresolved_41c1df0e(address arg0, address arg1, address arg2, uint64 arg3) public payable returns (uint256) {
        uint64 var_b = uint64(arg3);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ec9d633d(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: Sender is not the adapter for _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsAdapters: Sender is not the adapter for _id");
        require(address(arg2));
        require(uint0(arg3));
        require(uint0(arg3));
        var_b = arg3;
        address var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_95760fb9(var_b); // call
        emit TransferSingle(address(arg0), address(arg1), address(arg2), arg3, 0x01);
        return 0;
        var_b = uint64(arg3);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0);
        var_b = uint64(arg3);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = arg3;
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_95760fb9(var_b, var_d); // call
        emit TransferSingle(address(arg0), address(arg1), address(arg2), arg3, 0x01);
        return 0;
        var_b = address(getStorageContractAddress);
        var_d = arg3;
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_b, var_d); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_c.length)));
        require(address(var_c.length) == (address(arg1)));
        require(address(var_c.length) == (address(arg2)));
        var_b = uint64(arg3);
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(address(arg1) == msg.sender);
        var_b = uint64(arg3);
        var_d = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_b = uint64(arg3);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_b = arg3;
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_95760fb9(var_b, var_d); // call
        emit TransferSingle(address(arg0), address(arg1), address(arg2), arg3, 0x01);
        return var_c.length;
        var_b = var_c.length;
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_ffaf6633(var_b, var_d); // call
        if (address(arg1) == msg.sender) {
        }
        var_b = uint64(arg3);
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = uint64(arg3);
        var_d = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_b, var_d); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: _id is bound");
        require(var_c.length, "CryptoItemsAdapters: _id is bound");
    }
    
    /// @custom:selector    0xb97f0eb7
    /// @custom:signature   Unresolved_b97f0eb7(address arg0, address arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_b97f0eb7(address arg0, address arg1) public payable {
        require(address(msg.sender) == (address(getManager)), "CryptoItemsAdapters: Sender is not the manager");
        var_b = 0x3f55d0c208b5fd6b37166a1ac11406796c96750b055a0d4cb66f259f872ba288;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_ca446dd9(var_b); // call
        var_b = 0x7f089af0eea9a5635be3f57a5189d3be94e003da50158cba8b832b03bed17b53;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_ca446dd9(var_b); // call
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x9bb7f44e
    /// @custom:signature   Unresolved_9bb7f44e(address arg0, address arg1, uint256 arg2) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_9bb7f44e(address arg0, address arg1, uint256 arg2) public payable returns (bool) {
        uint256 var_b = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_e.length;
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        require(!(address(getManager) == (address(arg0))), "Managed: New manager needs to be different");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_d[var_b]);
    }
    
    /// @custom:selector    0x6352211e
    /// @custom:signature   ownerOf(uint256 arg0) public payable returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function ownerOf(uint256 arg0) public payable returns (address) {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_7d686379(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: owner query for nonexistent token");
        require(address(var_c.length), "CryptoItemsAdapters: owner query for nonexistent token");
        return address(var_c.length);
    }
    
    /// @custom:selector    0xf95d7da3
    /// @custom:signature   Unresolved_f95d7da3(address arg0, address arg1, address arg2, uint64 arg3, uint256 arg4) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint64", "bytes8", "int64"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_f95d7da3(address arg0, address arg1, address arg2, uint64 arg3, uint256 arg4) public payable returns (bytes memory) {
        uint64 var_b = arg3;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ec9d633d(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: Sender is not the adapter for _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsAdapters: Sender is not the adapter for _id");
        require(address(arg2));
        require(uint0(arg3));
        require(uint0(arg3));
        var_b = arg3;
        address var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_ffaf6633(var_b); // call
        emit TransferSingle(address(arg0), address(arg1), address(arg2), arg3, arg4);
        var_h = 0;
        return abi.encodePacked(arg4, 0);
        var_b = arg3;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0);
        var_b = arg3;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = arg3;
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_h ether }Unresolved_ffaf6633(var_b, var_d); // call
        emit TransferSingle(address(arg0), address(arg1), address(arg2), arg3, arg4);
        return abi.encodePacked(arg4, 0);
        var_b = address(getStorageContractAddress);
        var_d = arg3;
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_b, var_d); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_c.length)));
        require(address(var_c.length) == (address(arg1)));
        require(address(var_c.length) == (address(arg2)));
        var_b = arg3;
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(address(arg1) == msg.sender);
        var_b = arg3;
        var_d = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_b = arg3;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) == 0x02);
        require(var_c.length);
        require(0);
        require(!var_c.length);
        var_b = var_c.length;
        var_d = address(arg1);
        var_g = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_g ether }Unresolved_ffaf6633(var_b, var_d); // call
        require(var_c.length, "SafeMath: mul overflow");
        require(((arg4 * var_c.length) / var_c.length) == arg4, "SafeMath: mul overflow");
        require(!(bytes1(var_c.length) > 0x05), "SafeMath: sub underflow");
        require(!(bytes1(var_c.length) == 0x03), "SafeMath: sub underflow");
        require(arg4, "SafeMath: sub underflow");
        require(arg4, "SafeMath: sub underflow");
        require(((var_c.length * arg4) / arg4) == var_c.length, "SafeMath: sub underflow");
        require(0x2710, "SafeMath: sub underflow");
        require(!(((var_c.length * arg4) / 0x2710) > arg4), "SafeMath: sub underflow");
        require(!(bytes1(var_c.length) > 0x05), "SafeMath: mul overflow");
        require(!(bytes1(var_c.length) == 0x04), "SafeMath: mul overflow");
        require(arg4, "SafeMath: mul overflow");
        require(arg4, "SafeMath: mul overflow");
        require(((var_c.length * arg4) / arg4) == var_c.length, "SafeMath: mul overflow");
        require(0x2710, "SafeMath: mul overflow");
        if (var_c.length) {
        }
        if (address(arg1) == msg.sender) {
        }
        var_b = uint64(arg3);
        var_d = address(arg1);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = uint64(arg3);
        var_d = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_b, var_d); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: _id is bound");
        require(var_c.length, "CryptoItemsAdapters: _id is bound");
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xfed9dc6a
    /// @custom:signature   Unresolved_fed9dc6a(address arg0, uint256 arg1, uint256 arg2, address arg3) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_fed9dc6a(address arg0, uint256 arg1, uint256 arg2, address arg3) public payable {
        uint256 var_b = arg1;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ec9d633d(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsAdapters: Sender is not the adapter for _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsAdapters: Sender is not the adapter for _id");
        var_b = arg1;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_bf73f5b2(var_b); // call
        emit ApprovalForAll(address(arg3), address(arg0), arg2);
    }
}