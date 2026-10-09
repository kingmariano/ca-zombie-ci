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
    event ApprovalForScope(address, address, bytes32, bool);
    
    /// @custom:selector    0x610291ce
    /// @custom:signature   isApprovedForScope(address arg0, address arg1, bytes32 arg2) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function isApprovedForScope(address arg0, address arg1, bytes32 arg2) public payable returns (bool) {
        uint256 var_b = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_e.length;
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x4e41a1fb
    /// @custom:signature   Unresolved_4e41a1fb(uint64 arg0) public payable returns (bytes memory)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_4e41a1fb(uint64 arg0) public payable returns (bytes memory) {
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_6418413c(var_b); // staticcall
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
    }
    
    /// @custom:selector    0x443bf984
    /// @custom:signature   mintableSupply(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function mintableSupply(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_0df381aa(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0xb2aac5fb
    /// @custom:signature   whitelisted(uint256 arg0, address arg1, address arg2) public payable returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function whitelisted(uint256 arg0, address arg1, address arg2) public payable returns (bool) {
        uint256 var_b = arg0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_b); // staticcall
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
    
    /// @custom:selector    0x40e0051c
    /// @custom:signature   Unresolved_40e0051c(uint64 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_40e0051c(uint64 arg0) public payable returns (uint256) {
        require(!bytes1(arg0));
        return 0;
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsUsers: Invalid id");
        require(!(address(var_c.length) == 0), "CryptoItemsUsers: Invalid id");
        require(!(uint0(arg0)), "CryptoItemsUsers: Invalid id");
        require(uint64(arg0), "CryptoItemsUsers: Invalid id");
        return 0x04;
        return 0x03;
        return 0x03;
    }
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_d[var_b]);
    }
    
    /// @custom:selector    0xdcf0f7d3
    /// @custom:signature   Unresolved_dcf0f7d3(address arg0, address arg1, uint64 arg2) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint64", "bytes8", "int64"]
    function Unresolved_dcf0f7d3(address arg0, address arg1, uint64 arg2) public payable returns (bool) {
        uint64 var_b = uint64(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_b = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_e.length;
        return var_e.length;
    }
    
    /// @custom:selector    0xd5894752
    /// @custom:signature   scopeUri(bytes32 arg0) public payable returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function scopeUri(bytes32 arg0) public payable returns (bytes memory) {
        var_f = keccak256(var_g);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_986e791a(var_f); // staticcall
        var_d = var_d + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x20);
        require(!var_d.length > 0x0100000000);
        require(!((var_d + var_d.length) + 0x20) > (var_d + ret0.length));
        require(!((var_d + ret0.length) < (var_h + ((var_d + var_d.length) + 0x20))) | (var_h > 0x0100000000));
        require(!0 < (var_j));
        require(!bytes1(var_j));
        var_d = 0x20 + (var_h + (0x20 + var_d) - (bytes1(var_h)));
        require(!0 == var_d.length);
        require(!bytes1(var_d.length));
        return abi.encodePacked(0x20, var_d.length, (~((0x0100 ** (0x20 - (bytes1(var_d.length)))) - 0x01)) & (var_p));
        return abi.encodePacked(0x20, var_d.length);
        var_d = 0x60 + var_d;
        require(!bytes1(var_d.length));
        return abi.encodePacked(0x20, var_d.length);
        return abi.encodePacked(0x20, var_d.length, (~((0x0100 ** (0x20 - (bytes1(var_d.length)))) - 0x01)) & (var_p));
    }
    
    /// @custom:selector    0x9103d3ee
    /// @custom:signature   Unresolved_9103d3ee(uint64 arg0, uint32 arg1) public payable returns (uint256)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["uint32", "bytes4", "int32"]
    function Unresolved_9103d3ee(uint64 arg0, uint32 arg1) public payable returns (uint256) {
        require(!bytes1(arg0));
        require(uint32(arg1) < 0);
        require(uint32(arg1));
        require(!0x01 == (uint32(arg1)));
        uint256 var_d = var_d + 0x45;
        var_f = keccak256(var_g);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_f); // staticcall
        require(!ret0.length < 0x20);
        return var_d.length;
        require(!(uint0(arg0)), "CryptoItemsUsers: Scope index is out of range");
        require(!(0x02 == (uint32(arg1))), "CryptoItemsUsers: Scope index is out of range");
        return uint64(arg0);
        return arg0;
        return 0;
        var_h = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getCreator(var_h); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsUsers: Scope index is out of range");
        require(!(address(var_d.length) == 0), "CryptoItemsUsers: Scope index is out of range");
        require(!(uint0(arg0)), "CryptoItemsUsers: Scope index is out of range");
        require(uint64(arg0), "CryptoItemsUsers: Scope index is out of range");
        require(uint32(arg1) < 0x04, "CryptoItemsUsers: Scope index is out of range");
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        require(!(address(getManager) == (address(arg0))), "Managed: New manager needs to be different");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0xbd85b039
    /// @custom:signature   totalSupply(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function totalSupply(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_c3ea4147(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0x0565276f
    /// @custom:signature   Unresolved_0565276f(address arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_0565276f(address arg0, uint256 arg1, uint256 arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!0 < (arg1));
        require(0 < (arg1));
        uint256 var_b = (0 + (0x20 + (arg1)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_bf73f5b2(var_b); // call
    }
    
    /// @custom:selector    0xf521a982
    /// @custom:signature   getCreatedTime(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getCreatedTime(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_8f5398de(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0x92ff6aea
    /// @custom:signature   circulatingSupply(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function circulatingSupply(uint256 arg0) public payable returns (uint256) {
        address var_b = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_8bf1be36(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_d.length;
    }
    
    /// @custom:selector    0xf6089e12
    /// @custom:signature   melt(uint256[] arg0, uint256[] arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function melt(uint256[] arg0, uint256[] arg1) public payable {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        address var_b = address(getStorageContractAddress);
        require(address(0x553f1e2211fa375ed81c61e25bedecc46b83b25b).code.length);
        (bool success, bytes memory ret0) = address(0x553f1e2211fa375ed81c61e25bedecc46b83b25b).Unresolved_be460500(var_b); // delegatecall
    }
    
    /// @custom:selector    0x4aa8ade5
    /// @custom:signature   Unresolved_4aa8ade5(uint256 arg0) public payable returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_4aa8ade5(uint256 arg0) public payable returns (bytes memory) {
        address var_d = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_db3d65e4(var_d); // delegatecall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x0180);
        require(!var_a.length > 0x0100000000);
        require(!((var_a + var_a.length) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_f + ((var_a + var_a.length) + 0x20))) | (var_f > 0x0100000000));
        require(!0 < (var_h));
        require(!bytes1(var_h));
        var_a = 0x20 + (var_f + (0x20 + var_a) - (bytes1(var_f)));
        require(!0 < 0xe0);
        require(!0 < 0x40);
        require(!bytes1(var_a.length));
        return abi.encodePacked((0x20 + (0x20 + (0x40 + (0xe0 + (var_a + 0x20))))) - var_a, uint16(var_s), bytes1(var_t), var_a.length, (~((0x0100 ** (0x20 - (bytes1(var_a.length)))) - 0x01)) & (var_r));
        return abi.encodePacked((0x20 + (0x20 + (0x40 + (0xe0 + (var_a + 0x20))))) - var_a, uint16(var_s), bytes1(var_t), var_a.length);
    }
    
    /// @custom:selector    0x71f77a64
    /// @custom:signature   Unresolved_71f77a64(uint64 arg0) public pure returns (uint64)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_71f77a64(uint64 arg0) public pure returns (uint64) {
        return uint64(arg0);
    }
    
    /// @custom:selector    0x510b5158
    /// @custom:signature   Unresolved_510b5158(uint64 arg0) public payable returns (address)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_510b5158(uint64 arg0) public payable returns (address) {
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!ret0.length < 0x20);
        return address(var_c.length);
    }
    
    /// @custom:selector    0x6683de90
    /// @custom:signature   transferSettings(uint256 arg0) public payable returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function transferSettings(uint256 arg0) public payable returns (bytes memory) {
        address var_b = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_b370e739(var_b); // delegatecall
        require(!ret0.length < 0xa0);
        require(!var_d.length > 0x02);
        require(!(var_e) > 0x05);
        return abi.encodePacked(bytes1(var_d.length), bytes1(var_m), var_n, var_o, var_p);
    }
    
    /// @custom:selector    0x4341963e
    /// @custom:signature   typeData(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function typeData(uint256 arg0) public payable returns (uint256) {
        address var_d = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_20255621(var_d); // delegatecall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x0200);
        require(!var_a.length > 0x0100000000);
        require(!((var_a + var_a.length) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_f + ((var_a + var_a.length) + 0x20))) | (var_f > 0x0100000000));
        require(!0 < (var_h));
        require(!bytes1(var_h));
        var_a = 0x20 + (var_f + (0x20 + var_a) - (bytes1(var_f)));
        require(!(var_k) > 0x0100000000);
        require(!((var_a + (var_l)) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_m + ((var_a + (var_l)) + 0x20))) | (var_m > 0x0100000000));
        require(!0 < (var_o));
        require(!bytes1(var_o));
        var_a = 0x20 + (var_m + (0x20 + var_a) - (bytes1(var_m)));
        require(!0 < 0x40);
        require(!0 < 0x60);
        require(!(var_x) > 0x02);
        require(!0 < 0x80);
        require(!bytes1(var_a.length));
        require(!bytes1(var_a.length));
        return ;
        return ;
    }
    
    /// @custom:selector    0x557e8369
    /// @custom:signature   Unresolved_557e8369(address arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_557e8369(address arg0, uint256 arg1, uint256 arg2) public payable {
        uint256 var_b = arg1;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: 0 ether }Unresolved_bf73f5b2(var_b); // call
        emit ApprovalForScope(msg.sender, address(arg0), arg1, arg2);
    }
    
    /// @custom:selector    0x3f47e662
    /// @custom:signature   Unresolved_3f47e662(uint64 arg0) public payable returns (bool)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_3f47e662(uint64 arg0) public payable returns (bool) {
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_ff42fe18(var_b); // staticcall
        require(!ret0.length < 0x20);
        return bytes1(var_c.length);
    }
    
    /// @custom:selector    0xea6df23f
    /// @custom:signature   Unresolved_ea6df23f(uint64 arg0, address arg1) public payable returns (bool)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_ea6df23f(uint64 arg0, address arg1) public payable returns (bool) {
        uint64 var_b = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_d48e638a(var_b); // staticcall
        require(!ret0.length < 0x20);
        return !(!(address(var_c.length)) == (address(arg1)));
    }
}