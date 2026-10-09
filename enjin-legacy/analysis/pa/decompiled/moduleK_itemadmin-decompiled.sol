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
    
    event Name(string, uint256);
    event ManagerUpdate(address, address);
    event ScopeURI(string, bytes32);
    event Log(uint256, address, string);
    event IdsRemovedFromScope(uint256, uint256, bytes32);
    event IdsAddedToScope(uint256, uint256, bytes32);
    
    /// @custom:selector    0x4a966a50
    /// @custom:signature   Unresolved_4a966a50(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, address arg5, address arg6, uint16 arg7, bool arg8, uint256 arg9) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg7 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg8 ["uint16", "bytes2", "int16"]
    /// @param              arg9 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg13 ["uint256", "bytes32", "int256"]
    function Unresolved_4a966a50(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, address arg5, address arg6, uint16 arg7, bool arg8, uint256 arg9) public view {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        require(!(bytes1(arg9)) > 0x02);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
    }
    
    /// @custom:selector    0x862440e2
    /// @custom:signature   Unresolved_862440e2(uint64 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_862440e2(uint64 arg0, uint256 arg1) public payable {
        require(!arg1 > 0x0100000000);
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0x553f1e2211fa375ed81c61e25bedecc46b83b25b).code.length);
        (bool success, bytes memory ret0) = address(0x553f1e2211fa375ed81c61e25bedecc46b83b25b).Unresolved_0ef93508(var_b); // delegatecall
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        require(!(address(getManager) == (address(arg0))), "Managed: New manager needs to be different");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0xdf0e9ddf
    /// @custom:signature   Unresolved_df0e9ddf(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, address arg4, address arg5, uint16 arg6, bool arg7, uint256 arg8) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg6 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg7 ["uint16", "bytes2", "int16"]
    /// @param              arg8 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg12 ["uint256", "bytes32", "int256"]
    function Unresolved_df0e9ddf(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, address arg4, address arg5, uint16 arg6, bool arg7, uint256 arg8) public view {
        require(!arg0 > 0x0100000000);
        require(!(bytes1(arg8)) > 0x02);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
    }
    
    /// @custom:selector    0xcd23dde0
    /// @custom:signature   Unresolved_cd23dde0(uint256 arg0, uint256 arg1, uint256 arg2, address arg3, uint256 arg4, uint16 arg5, bool arg6, uint256 arg7) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint16", "bytes2", "int16"]
    /// @param              arg6 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg10 ["uint256", "bytes32", "int256"]
    function Unresolved_cd23dde0(uint256 arg0, uint256 arg1, uint256 arg2, address arg3, uint256 arg4, uint16 arg5, bool arg6, uint256 arg7) public view {
        require(!arg0 > 0x0100000000);
        require(!(bytes1(arg6)) > 0x02);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
    }
    
    /// @custom:selector    0x6907be85
    /// @custom:signature   acceptAssignment(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function acceptAssignment(uint256 arg0) public payable {
        address var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_3874f484(var_b); // delegatecall
    }
    
    /// @custom:selector    0x819b25ba
    /// @custom:signature   reserve(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function reserve(uint256 arg0) public payable returns (uint256) {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_77778db3(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_c.length;
    }
    
    /// @custom:selector    0x239a46fc
    /// @custom:signature   acceptFeeRecipient(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function acceptFeeRecipient(uint256 arg0) public payable {
        address var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_7b2bae64(var_b); // delegatecall
    }
    
    /// @custom:selector    0xe6e21c75
    /// @custom:signature   Unresolved_e6e21c75(uint256 arg0, address arg1, address arg2, uint256 arg3) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_e6e21c75(uint256 arg0, address arg1, address arg2, uint256 arg3) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0x8601b003019fb3912f720d774d35912b879b57bd).code.length);
        (bool success, bytes memory ret0) = address(0x8601b003019fb3912f720d774d35912b879b57bd).Unresolved_0ccca063(var_b); // delegatecall
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x3d7d20a4
    /// @custom:signature   mintFungibles(uint256 arg0, address[] arg1, uint256[] arg2) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function mintFungibles(uint256 arg0, address[] arg1, uint256[] arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).code.length);
        (bool success, bytes memory ret0) = address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).Unresolved_54c11483(var_b); // delegatecall
    }
    
    /// @custom:selector    0xe07d3b5a
    /// @custom:signature   assign(uint256 arg0, address arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function assign(uint256 arg0, address arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_6add6a01(var_b); // delegatecall
    }
    
    /// @custom:selector    0x22000392
    /// @custom:signature   Unresolved_22000392(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, address arg5, uint16 arg6, bool arg7, uint256 arg8) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg6 ["uint16", "bytes2", "int16"]
    /// @param              arg7 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg11 ["uint256", "bytes32", "int256"]
    function Unresolved_22000392(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, address arg5, uint16 arg6, bool arg7, uint256 arg8) public view {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        require(!(bytes1(arg7)) > 0x02);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x8fa1cc21
    /// @custom:signature   decreaseMaxMeltFee(uint256 arg0, uint16 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    function decreaseMaxMeltFee(uint256 arg0, uint16 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_c7209e4a(var_b); // delegatecall
    }
    
    /// @custom:selector    0x36d10002
    /// @custom:signature   Unresolved_36d10002(uint256 arg0, uint256 arg1) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_36d10002(uint256 arg0, uint256 arg1) public view {
        require(!arg1 > 0x0100000000);
        emit Log(arg0, address(msg.sender), (0x20 + var_b) - var_b, (arg1));
    }
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_d[var_b]);
    }
    
    /// @custom:selector    0xa6566f8d
    /// @custom:signature   setMeltFee(uint256 arg0, uint16 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    function setMeltFee(uint256 arg0, uint16 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_9ba9e0a7(var_b); // delegatecall
    }
    
    /// @custom:selector    0x934930a1
    /// @custom:signature   setTransferFee(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setTransferFee(uint256 arg0, uint256 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0x8601b003019fb3912f720d774d35912b879b57bd).code.length);
        (bool success, bytes memory ret0) = address(0x8601b003019fb3912f720d774d35912b879b57bd).Unresolved_32ead744(var_b); // delegatecall
    }
    
    /// @custom:selector    0xc2eed0de
    /// @custom:signature   releaseReserve(uint256 arg0, uint128 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint128", "bytes16", "int128"]
    function releaseReserve(uint256 arg0, uint128 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_fba6f0f4(var_b); // delegatecall
    }
    
    /// @custom:selector    0x567db8ac
    /// @custom:signature   Unresolved_567db8ac(uint256 arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_567db8ac(uint256 arg0, uint256 arg1, uint256 arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0x9a67aef2fd5669e2add4cbf87e310c29d9800252).code.length);
        (bool success, bytes memory ret0) = address(0x9a67aef2fd5669e2add4cbf87e310c29d9800252).Unresolved_c3b0ef8d(var_b); // delegatecall
    }
    
    /// @custom:selector    0x34e07ff3
    /// @custom:signature   setTransferable(uint256 arg0, uint8 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["bool", "uint8", "bytes1", "int8"]
    function setTransferable(uint256 arg0, uint8 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(!(bytes1(arg1)) > 0x02);
        require(address(0x8601b003019fb3912f720d774d35912b879b57bd).code.length);
        (bool success, bytes memory ret0) = address(0x8601b003019fb3912f720d774d35912b879b57bd).Unresolved_4db8e97f(var_b); // delegatecall
    }
    
    /// @custom:selector    0x70fb2621
    /// @custom:signature   getFeeRecipient(uint256 arg0) public payable returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getFeeRecipient(uint256 arg0) public payable returns (address) {
        address var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_59356146(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return address(var_d.length);
    }
    
    /// @custom:selector    0xda8f728d
    /// @custom:signature   Unresolved_da8f728d(uint32 arg0, uint0 arg1) public payable
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    function Unresolved_da8f728d(uint32 arg0, uint0 arg1) public payable {
        uint0 var_b = arg1;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        uint0 var_g = arg1;
        uint256 var_c = var_c + 0x45;
        var_i = keccak256(var_j);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(!uint0(arg1));
        emit IdsRemovedFromScope(arg1, var_g + 0xffffffffffffffffffffffffffffffffffffffffffffffff, var_c.length);
        emit IdsAddedToScope(arg1, var_g + 0xffffffffffffffffffffffffffffffffffffffffffffffff, msg.sender | (uint32(arg0 << 0xa0)));
        var_i = keccak256(var_j);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_e2a4853a(var_i); // call
    }
    
    /// @custom:selector    0x30ce02bd
    /// @custom:signature   Unresolved_30ce02bd(uint32 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_30ce02bd(uint32 arg0, uint256 arg1) public payable {
        require(!arg1 > 0x0100000000);
        uint256 var_d = var_d + 0x49;
        var_f = keccak256(var_g);
        uint256 var_k = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_k ether }Unresolved_6e899550(var_f); // call
        emit ScopeURI(msg.sender | (uint32(arg0 << 0xa0)), (0x20 + var_d) - var_d, (arg1));
    }
    
    /// @custom:selector    0x11f7e404
    /// @custom:signature   minMeltValue(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function minMeltValue(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_3ef2b102(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0x2665bc1c
    /// @custom:signature   Unresolved_2665bc1c(uint256 arg0, address arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2665bc1c(uint256 arg0, address arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).code.length);
        (bool success, bytes memory ret0) = address(0xcbfb2843aaf56ea30c27439bebe5e303425acff2).Unresolved_00bcf743(var_b); // delegatecall
    }
    
    /// @custom:selector    0x53e76f2c
    /// @custom:signature   Unresolved_53e76f2c(uint64 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_53e76f2c(uint64 arg0, uint256 arg1) public payable {
        require(!arg1 > 0x0100000000);
        uint64 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = uint64(arg0);
        uint256 var_h = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_h ether }Unresolved_fe55932a(var_b); // call
        emit Name(arg0, (0x20 + var_c) - var_c, (arg1));
    }
    
    /// @custom:selector    0xc5817e1e
    /// @custom:signature   decreaseMaxTransferFee(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function decreaseMaxTransferFee(uint256 arg0, uint256 arg1) public payable {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsCreators: Sender is not the creator of _id");
        require(address(var_c.length) == msg.sender, "CryptoItemsCreators: Sender is not the creator of _id");
        var_b = address(getStorageContractAddress);
        require(address(0x8601b003019fb3912f720d774d35912b879b57bd).code.length);
        (bool success, bytes memory ret0) = address(0x8601b003019fb3912f720d774d35912b879b57bd).Unresolved_7b5cd724(var_b); // delegatecall
    }
}