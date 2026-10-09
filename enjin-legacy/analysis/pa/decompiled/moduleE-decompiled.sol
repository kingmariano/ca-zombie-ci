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
    event TransferSingle(address, address, address, uint256, uint256);
    
    /// @custom:selector    0x621b0df6
    /// @custom:signature   Unresolved_621b0df6(address arg0, uint248 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint248", "bytes31", "int248"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_621b0df6(address arg0, uint248 arg1, uint256 arg2) public payable {
        require(!address(this) == 0x9a67aef2fd5669e2add4cbf87e310c29d9800252);
        require(!arg2 > 0x0100000000);
        require(uint0(arg1) == 0x80000000000000000000000000000000000000000000000000000000000000);
        require(bytes1(arg1));
        uint248 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_6c04e3c0(var_b); // call
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_ee6ab318(var_b); // call
        require(!ret0.length < 0x20);
        require(!var_d.length < (arg2));
        require(!var_d.length > (arg2));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(arg2 - var_d.length);
        require(!0);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_fed57875(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = msg.sender;
        uint256 var_e = 0;
        require(address(var_d.length).code.length);
        (bool success, bytes memory ret0) = address(var_d.length).{ value: var_e ether }Unresolved_23b872dd(var_b); // call
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_e ether }Unresolved_7384ce67(var_b); // call
        require(!ret0.length < 0x20);
        require(!0 < (arg2));
        require(0 < (arg2));
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        var_b = arg1 | (0 + (0x01 + (uint64(var_d.length))));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_e ether }Unresolved_eab99bb0(var_b); // call
        emit TransferSingle(msg.sender, 0, address(0 + (0x20 + (arg2))), arg1 | (0 + (0x01 + (uint64(var_d.length)))), 0x01);
        require(!address(0 + (0x20 + (arg2))).code.length);
        var_b = msg.sender;
        var_c = 0;
        uint256 var_i = 0;
        require(address(0 + (0x20 + (arg2))).code.length);
        (bool success, bytes memory ret0) = address(0 + (0x20 + (arg2))).{ value: var_i ether }Unresolved_f23a6e61(var_b, var_c); // call
        require(!(ret0.length < 0x20), "LibItemNonFungible: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_d.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemNonFungible: Receiving contract did not return ERC1155_ACCEPTED");
        require(arg2 - var_d.length, "SafeMath: mul overflow");
        require((var_d.length * (arg2 - var_d.length)) / (arg2 - var_d.length) == var_d.length, "SafeMath: mul overflow");
        var_c = 0x17;
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_b, var_c); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreatedTime(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        var_c = var_d.length;
        require(address(var_d.length).code.length);
        (bool success, bytes memory ret0) = address(var_d.length).Unresolved_4ccf9e93(var_b, var_c); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getTotalSupply(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_b, var_c); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_d.length > var_d.length), "SafeMath: sub underflow");
        require(!(arg2 + (var_d.length - var_d.length) < (var_d.length - var_d.length)), "SafeMath: add overflow");
        require(!(arg2 + (var_d.length - var_d.length) > var_d.length), "SafeMath: sub underflow");
        require(!(arg2 > var_d.length), "SafeMath: sub underflow");
        require(!(var_d.length > var_d.length), "SafeMath: sub underflow");
        require(!(arg2 + (var_d.length - var_d.length) < (var_d.length - var_d.length)), "SafeMath: add overflow");
        var_b = arg1;
        var_c = (arg2) + (var_d.length - var_d.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_b0a4d7d3(var_b, var_c); // call
        var_b = arg1;
        var_c = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_7e686648(var_b, var_c); // call
        var_b = arg1;
        var_c = (arg2);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_i ether }Unresolved_6c04e3c0(var_b, var_c); // call
        require(!(var_d.length - var_d.length) < var_d.length);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getReserve(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Trying to mint more than is allowed by suply model");
        require(!(arg2 > var_d.length), "LibItemCommon: Trying to mint more than is allowed by suply model");
    }
    
    /// @custom:selector    0x8f916b31
    /// @custom:signature   Unresolved_8f916b31(address arg0, uint0 arg1, uint256 arg2) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_8f916b31(address arg0, uint0 arg1, uint256 arg2) public payable returns (bytes memory) {
        require(!address(this) == 0x9a67aef2fd5669e2add4cbf87e310c29d9800252);
        uint0 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(uint0(arg1));
        require(uint0(arg1));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_95760fb9(var_b); // call
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_eaf457dd(var_b); // call
        emit TransferSingle(msg.sender, msg.sender, 0, arg1, 0x01);
        return abi.encodePacked(var_f.length, 0, 0);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltFee(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!uint16(var_f.length));
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreator(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(address(var_f.length) == msg.sender, "SafeMath: sub underflow");
        require(var_f.length, "SafeMath: sub underflow");
        require(0x2710, "SafeMath: sub underflow");
        require(!(0 > var_f.length), "SafeMath: sub underflow");
        require(!arg2, "SafeMath: mul overflow");
        require(0, "SafeMath: mul overflow");
        require(0, "SafeMath: mul overflow");
        require(((arg2 * 0) / 0) == arg2, "SafeMath: mul overflow");
        require(var_f.length);
    }
    
    /// @custom:selector    0xc3b0ef8d
    /// @custom:signature   Unresolved_c3b0ef8d(address arg0, uint248 arg1, uint256 arg2, uint256 arg3) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint248", "bytes31", "int248"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_c3b0ef8d(address arg0, uint248 arg1, uint256 arg2, uint256 arg3) public payable {
        require(!address(this) == 0x9a67aef2fd5669e2add4cbf87e310c29d9800252);
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
        require(arg3 == (arg2), "LibItemNonFungible: _to and _values have different lengths");
        require(uint0(arg1) == 0x80000000000000000000000000000000000000000000000000000000000000, "SafeMath: add overflow");
        require(!(0 < (arg2)), "SafeMath: add overflow");
        require(0 < (arg3), "SafeMath: add overflow");
        require(!(((0 + (0x20 + (arg3))) + 0) < 0), "SafeMath: add overflow");
        require(bytes1(arg1));
        var_b = arg1;
        uint256 var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_6c04e3c0(var_b); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_ee6ab318(var_b); // call
        require(!ret0.length < 0x20);
        require(!var_c.length < 0);
        require(!var_c.length > 0);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(0 - var_c.length);
        require(!0);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_fed57875(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = msg.sender;
        uint256 var_f = 0;
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_f ether }Unresolved_23b872dd(var_b); // call
        require(!ret0.length < 0x20);
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_7384ce67(var_b); // call
        require(!ret0.length < 0x20);
        require(!0 < (arg2));
        require(0 < (arg2));
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        require(0 < (arg3));
        require((0 + (0x20 + (arg3))) > 0);
        require(!0 + (0x20 + (arg3)));
        var_c = var_c + (0x20 + (0x20 * (0 + (0x20 + (arg3)))));
        require(!0 + (0x20 + (arg3)));
        require(!0 < (0 + (0x20 + (arg3))));
        var_f = var_b | (0x01 + (uint64(var_c.length)));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_eab99bb0(var_f); // call
        require(!address(0 + (0x20 + (arg2))).code.length);
        var_f = msg.sender;
        uint256 var_n = 0;
        require(address(0 + (0x20 + (arg2))).code.length);
        (bool success, bytes memory ret0) = address(0 + (0x20 + (arg2))).{ value: var_d ether }Unresolved_f23a6e61(var_f); // call
        require(!(ret0.length < 0x20), "LibItemNonFungible: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_c.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemNonFungible: Receiving contract did not return ERC1155_ACCEPTED");
        if (!0 < (0x20 * var_c.length)) {
            if (!0 < (0x20 * var_c.length)) {
            }
        }
        require(0 - var_c.length, "SafeMath: mul overflow");
        require((var_c.length * (0 - var_c.length)) / (0 - var_c.length) == var_c.length, "SafeMath: mul overflow");
        var_d = 0x17;
        var_f = 0x536166654d6174683a2073756220756e646572666c6f77000000000000000000;
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreatedTime(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        var_d = var_c.length;
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_4ccf9e93(var_b, var_d, var_f); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getTotalSupply(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_b, var_d); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!((0 + (var_c.length - var_c.length)) < (var_c.length - var_c.length)), "SafeMath: add overflow");
        require(!((0 + (var_c.length - var_c.length)) > var_c.length), "SafeMath: sub underflow");
        require(!(0 > var_c.length), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!((0 + (var_c.length - var_c.length)) < (var_c.length - var_c.length)), "SafeMath: add overflow");
        var_f = 0x536166654d6174683a20616464206f766572666c6f7700000000000000000000;
        var_b = arg1;
        var_d = var_n + (var_c.length - var_c.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_n ether }setTotalSupply(var_b, var_d); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_n ether }Unresolved_7e686648(var_b, var_d, var_f); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_n ether }Unresolved_6c04e3c0(var_b, var_d, var_f); // call
        require(!(var_c.length - var_c.length) < var_c.length);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getReserve(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Trying to mint more than is allowed by suply model");
        require(!(0 > var_c.length), "LibItemCommon: Trying to mint more than is allowed by suply model");
    }
    
    /// @custom:selector    0x025d6b26
    /// @custom:signature   Unresolved_025d6b26(address arg0, uint256 arg1, address arg2, uint256 arg3) public payable returns (address)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_025d6b26(address arg0, uint256 arg1, address arg2, uint256 arg3) public payable returns (address) {
        require(!(arg1 > 0), "LibItemNonFungible: _baseType contains an index");
        require(!(uint64(arg1)), "LibItemNonFungible: _baseType contains an index");
        require(uint0(arg1));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_b0a79459(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemNonFungible: _index is out of bounds");
        require(arg3 < var_c.length, "LibItemNonFungible: _index is out of bounds");
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_e5230867(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!0 < (uint64(var_c.length)));
        uint256 var_c = 0x20 + (0x04 + (0x20 + var_c));
        var_h = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_h); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(0x01 + (arg1 | 0))) == 0x01);
        uint256 var_h = (address(var_c.length)) | (0x01 + (arg1 | 0));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_7d686379(var_h); // staticcall
        require(!ret0.length < 0x20);
        require(!(address(var_c.length)) == (address(arg2)));
        require(arg3);
        return (address(var_c.length)) | (0x01 + (arg1 | 0));
        var_h = (var_c.length >> 0x80) | (0x01 + (arg1 | 0));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_7d686379(var_h); // staticcall
        require(!ret0.length < 0x20);
        return 0;
        require(arg1 > 0, "LibItemNonFungible: _baseType contains an index");
    }
    
    /// @custom:selector    0xbc65de05
    /// @custom:signature   Unresolved_bc65de05(address arg0, uint256 arg1, uint256 arg2, uint256 arg3) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_bc65de05(address arg0, uint256 arg1, uint256 arg2, uint256 arg3) public pure {
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
    }
    
    /// @custom:selector    0xc40035d3
    /// @custom:signature   Unresolved_c40035d3(address arg0, uint256 arg1, uint256 arg2) public payable returns (address)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_c40035d3(address arg0, uint256 arg1, uint256 arg2) public payable returns (address) {
        require(uint0(arg1) == 0x80000000000000000000000000000000000000000000000000000000000000, "LibItemNonFungible: _baseType contains an index");
        require(!(uint64(arg1)), "LibItemNonFungible: _baseType contains an index");
        require(uint0(arg1));
        uint256 var_d = (arg1 | arg2) >> 0x01;
        uint256 var_c = 0x20 + (0x04 + (0x20 + var_c));
        var_h = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_h); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(0x01 + (arg1 | arg2))) == 0x01);
        return (address(var_c.length)) | (0x01 + (arg1 | arg2));
        return (var_c.length >> 0x80) | (0x01 + (arg1 | arg2));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_e5230867(var_b, var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemNonFungible: _index is out of bounds");
        require(arg2 < (uint64(var_c.length)), "LibItemNonFungible: _index is out of bounds");
    }
}