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
    event URI(string, uint256);
    
    /// @custom:selector    0x0ef93508
    /// @custom:signature   Unresolved_0ef93508(address arg0, uint64 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_0ef93508(address arg0, uint64 arg1, uint256 arg2) public payable {
        require(!address(this) == 0x553f1e2211fa375ed81c61e25bedecc46b83b25b);
        require(!arg2 > 0x0100000000);
        require(uint0(arg1));
        uint64 var_b = arg1;
        var_c = 0x40;
        uint256 var_f = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_f ether }Unresolved_862440e2(var_b); // call
        emit URI(arg1, (0x20 + var_g) - var_g, (arg2));
        require(!uint64(arg1));
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_e5230867(var_b, var_c); // staticcall
        require(!(ret0.length < 0x20), "LibCryptoItemsExtension: _id is not a NF type");
        require(!(uint64(arg1) > (uint64(var_g.length))), "LibCryptoItemsExtension: _id is not a NF type");
    }
    
    /// @custom:selector    0x49a18089
    /// @custom:signature   Unresolved_49a18089(address arg0, uint64 arg1) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_49a18089(address arg0, uint64 arg1) public payable returns (bytes memory) {
        require(uint0(arg1));
        uint64 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1aa347dc(var_b); // staticcall
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
        require(!uint64(arg1));
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_e5230867(var_b, var_m); // staticcall
        require(!(ret0.length < 0x20), "LibCryptoItemsExtension: _id is not a NF type");
        require(!(uint64(arg1) > (uint64(var_c.length))), "LibCryptoItemsExtension: _id is not a NF type");
    }
    
    /// @custom:selector    0xbe460500
    /// @custom:signature   Unresolved_be460500(address arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_be460500(address arg0, uint256 arg1, uint256 arg2) public payable {
        require(!address(this) == 0x553f1e2211fa375ed81c61e25bedecc46b83b25b);
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        uint256 var_a = 0x60 + var_a;
        var_d = 0xe4b9bbf50ae955783b38f2e45f0892a3e74a819c95de68b2816206088d57d0ef;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_d); // staticcall
        require(!(ret0.length < 0x20), "LibCryptoItemsExtension: _id not created on current chain");
        require(!(0 < (arg1)), "LibCryptoItemsExtension: _id not created on current chain");
        require(0 < (arg1), "LibCryptoItemsExtension: _id not created on current chain");
        require(uint0(0 + (0x20 + (arg1))) == 0, "LibCryptoItemsExtension: _id not created on current chain");
        var_d = uint64(0 + (0x20 + (arg1)));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d48e638a(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(0 == (address(var_a.length)));
        require(!var_g);
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_7843e5dd(var_d); // call
        require(0x01 < 0x03);
        uint256 var_i = 0;
        var_a = 0x60 + var_a;
        require(!(uint0(0 + (0x20 + (arg1)))) == 0x80000000000000000000000000000000000000000000000000000000000000);
        address var_k = address(arg0);
        require(address(0x9a67aef2fd5669e2add4cbf87e310c29d9800252).code.length);
        (bool success, bytes memory ret0) = address(0x9a67aef2fd5669e2add4cbf87e310c29d9800252).Unresolved_8f916b31(var_k); // delegatecall
        require(!(ret0.length < 0x60), "SafeMath: add overflow");
        require(!((var_a.length + (var_q)) < (var_q)), "SafeMath: add overflow");
        require(0 < (arg2));
        var_k = address(arg0);
        require(address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).code.length);
        (bool success, bytes memory ret0) = address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).Unresolved_bebb7b01(var_k); // delegatecall
        require(!ret0.length < 0x60);
        require(!var_a.length);
        var_d = msg.sender;
        uint256 var_e = var_a.length;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_7843e5dd(var_d, var_e, var_s); // call
        require(!var_g);
        var_d = 0;
        var_e = var_h;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_7843e5dd(var_d, var_e, var_s); // call
        require(!var_t);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_d = address(var_a.length);
        var_e = var_t;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_7843e5dd(var_d, var_e, var_s); // call
    }
    
    /// @custom:selector    0x2dd0208f
    /// @custom:signature   Unresolved_2dd0208f(address arg0, uint256 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_2dd0208f(address arg0, uint256 arg1) public payable returns (uint256) {
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_8e628636(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(arg1 < var_c.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_8e628636(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length > arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_645cca84(var_b); // staticcall
        require(!ret0.length < 0x20);
        require((arg1 - var_c.length) < var_c.length);
        uint256 var_b = (((arg1 - var_c.length) + 0x01) << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        return (var_c.length << 0xf8) | ((((arg1 - var_c.length) + 0x01) << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_b = address(arg0);
        require(address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).code.length);
        (bool success, bytes memory ret0) = address(0xd257ea244160b2177fbc27b04e600e28cb9efdef).Unresolved_2dd0208f(var_b); // delegatecall
        require(!ret0.length < 0x20);
        return var_c.length;
    }
}