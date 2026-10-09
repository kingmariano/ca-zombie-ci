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
    
    /// @custom:selector    0x54c11483
    /// @custom:signature   Unresolved_54c11483(address arg0, uint0 arg1, uint256 arg2, uint256 arg3) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_54c11483(address arg0, uint0 arg1, uint256 arg2, uint256 arg3) public payable {
        require(!address(this) == 0xd257ea244160b2177fbc27b04e600e28cb9efdef);
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
        require(arg3 == (arg2), "LibItemFungible: _to and _values have different lengths");
        require(!(uint0(arg1)), "LibItemFungible: _id is a NF type");
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
        require(!0 < (arg2));
        require(0 < (arg2));
        require(!(address(0 + (0x20 + (arg2)))) == 0);
        require(0 < (arg3));
        require((0 + (0x20 + (arg3))) > 0);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_f807393a(var_b); // call
        emit TransferSingle(msg.sender, 0, address(0 + (0x20 + (arg2))), arg1, (0 + (0x20 + (arg3))));
        require(!address(0 + (0x20 + (arg2))).code.length);
        var_b = msg.sender;
        var_d = 0;
        uint256 var_j = 0;
        require(address(0 + (0x20 + (arg2))).code.length);
        (bool success, bytes memory ret0) = address(0 + (0x20 + (arg2))).{ value: var_j ether }Unresolved_f23a6e61(var_b, var_d); // call
        require(!(ret0.length < 0x20), "LibItemFungible: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_c.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemFungible: Receiving contract did not return ERC1155_ACCEPTED");
        require(0 - var_c.length, "SafeMath: mul overflow");
        require((var_c.length * (0 - var_c.length)) / (0 - var_c.length) == var_c.length, "SafeMath: mul overflow");
        var_d = 0x17;
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
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_4ccf9e93(var_b, var_d); // staticcall
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
        var_b = arg1;
        var_d = var_j + (var_c.length - var_c.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_j ether }Unresolved_b0a4d7d3(var_b, var_d); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_j ether }Unresolved_7e686648(var_b, var_d); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_j ether }Unresolved_6c04e3c0(var_b, var_d); // call
        require(!(var_c.length - var_c.length) < var_c.length);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getReserve(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Trying to mint more than is allowed by suply model");
        require(!(0 > var_c.length), "LibItemCommon: Trying to mint more than is allowed by suply model");
    }
    
    /// @custom:selector    0x2dd0208f
    /// @custom:signature   Unresolved_2dd0208f(address arg0, uint256 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_2dd0208f(address arg0, uint256 arg1) public payable returns (uint256) {
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_8e628636(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemFungible: _index is invalid");
        require(arg1 < var_c.length, "LibItemFungible: _index is invalid");
        var_b = (arg1 + 0x01) << 0xc0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        return (var_c.length << 0xf8) | ((arg1 + 0x01) << 0xc0);
    }
    
    /// @custom:selector    0xbebb7b01
    /// @custom:signature   Unresolved_bebb7b01(address arg0, uint0 arg1, uint256 arg2, uint256 arg3) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_bebb7b01(address arg0, uint0 arg1, uint256 arg2, uint256 arg3) public payable returns (bytes memory) {
        require(!address(this) == 0xd257ea244160b2177fbc27b04e600e28cb9efdef);
        require(arg2 > 0);
        address var_b = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = address(arg0);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_fc148139(var_b); // delegatecall
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(arg2);
        require(arg2);
        require(((var_c.length * arg2) / arg2) == var_c.length);
        require(uint0(arg1));
        require(uint0(arg1));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_3f93ee4f(var_b); // call
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_eaf457dd(var_b); // call
        emit TransferSingle(msg.sender, msg.sender, 0, arg1, arg2);
        var_f = 0;
        return abi.encodePacked(var_c.length * arg2, 0, 0);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltFee(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!uint16(var_c.length));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreator(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: mul overflow");
        require(address(var_c.length) == msg.sender, "SafeMath: mul overflow");
        require(var_c.length * arg2, "SafeMath: mul overflow");
        require(var_c.length * arg2, "SafeMath: mul overflow");
        require(uint16(var_c.length) * (var_c.length * arg2) / (var_c.length * arg2) == (uint16(var_c.length)), "SafeMath: mul overflow");
        require(0x2710, "SafeMath: sub underflow");
        require(!((uint16(var_c.length) * (var_c.length * arg2) / 0x2710) > (var_c.length * arg2)), "SafeMath: sub underflow");
        require(!arg3);
        var_b = arg1;
        var_d = msg.sender;
        var_e = arg2;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_f ether }Unresolved_3f93ee4f(var_b, var_d, var_e); // call
        var_b = arg1;
        var_d = arg2;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_f ether }Unresolved_eaf457dd(var_b, var_d, var_e); // call
        emit TransferSingle(msg.sender, msg.sender, 0, arg1, arg2);
        return abi.encodePacked((var_c.length * arg2) - (uint16(var_c.length) * (var_c.length * arg2) / 0x2710), (uint16(var_c.length) * (var_c.length * arg2)) / 0x2710, 0);
        if (!(var_c.length * arg2) > 0) {
        }
    }
}