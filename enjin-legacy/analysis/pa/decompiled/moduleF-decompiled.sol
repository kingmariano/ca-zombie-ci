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
    event Name(string, uint256);
    event Event_c0ac0a69();
    event ReserveReleased(uint256, uint256);
    event Event_14d81f43();
    event TransferSingle(address, address, address, uint256, uint256);
    event AcceptAssignment(uint256, address);
    event Event_9be972ea();
    event Assign(uint256, address, address);
    event IdsAddedToScope(uint256, uint256, bytes32);
    
    /// @custom:selector    0x748e850e
    /// @custom:signature   Unresolved_748e850e(address arg0, uint256 arg1, uint256 arg2, uint256 arg3, address arg4, uint256 arg5, uint16 arg6, bool arg7, uint256 arg8, uint256 arg9) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["uint16", "bytes2", "int16"]
    /// @param              arg7 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg8 ["uint256", "bytes32", "int256"]
    /// @param              arg11 ["uint256", "bytes32", "int256"]
    function Unresolved_748e850e(address arg0, uint256 arg1, uint256 arg2, uint256 arg3, address arg4, uint256 arg5, uint16 arg6, bool arg7, uint256 arg8, uint256 arg9) public payable returns (uint256) {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        require(!arg1 > 0x0100000000);
        require(address(arg4) < 0xffffffffffffffffffffffffffffffffffffffff);
        require(!uint16(arg6));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1c2fef80(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _meltFeeRatio is too high");
        require(!(uint16(arg6) > (uint16(var_c.length))), "LibItemCommon: _meltFeeRatio is too high");
        require(!(arg2 < arg3), "LibItemCommon: _totalSupply is lower than _initialReserve");
        require(!(bytes1(arg7) > 0x02), "LibItemCommon: Invalid _transferable value");
        var_b = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: mul overflow");
        require(var_c.length, "SafeMath: mul overflow");
        require(arg3 > 0, "SafeMath: mul overflow");
        require(arg5, "SafeMath: mul overflow");
        require(arg5, "SafeMath: mul overflow");
        require(((arg3 * arg5) / arg5) == arg3, "SafeMath: mul overflow");
        var_b = 0x20;
        require(0x03847d63c711be);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_ee28d7a3(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: mul overflow");
        require((arg3 * arg5) / 0x03847d63c711be, "SafeMath: mul overflow");
        require((arg3 * arg5) / 0x03847d63c711be, "SafeMath: mul overflow");
        require((0x3b9aca00 * ((arg3 * arg5) / 0x03847d63c711be)) / ((arg3 * arg5) / 0x03847d63c711be) == 0x3b9aca00, "SafeMath: mul overflow");
        require(var_c.length, "SafeMath: mul overflow");
        var_b = 0x20;
        require(!arg5);
        require(!arg11);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_5a12c0a5(var_b); // call
        require(!ret0.length < 0x20);
        require(arg8);
        require(bytes1(arg7));
        require(0);
        require(uint16(arg6));
        uint256 var_c = var_b + (0x05 + (0x20 + var_c));
        var_j = keccak256(var_k);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_e2a4853a(var_j); // call
        uint256 var_j = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_7e686648(var_j); // call
        require(!arg8 > 0);
        var_c = var_c + 0x60;
        require(0x05 > var_c.length);
        require(var_o);
        require(0x03 == var_c.length);
        require(!0x03 == var_c.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d45c47cc(var_p); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Transfer fee value is higher than maximum");
        require(!(var_q > (uint16(var_c.length))), "LibItemCommon: Transfer fee value is higher than maximum");
        require(!uint0((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        var_p = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        require(!0 < 0x60);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_caee2b1a(var_p); // call
        var_p = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_93fb8f39(var_p); // call
        require(arg5 > 0);
        var_p = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        var_s = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_2c4fa099(var_p); // call
        require(!0);
        var_p = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        require(address(0).code.length);
        (bool success, bytes memory ret0) = address(0).{ value: var_s ether }Unresolved_d66d6c10(var_p); // call
        emit TransferSingle(msg.sender, 0, 0, (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000, 0);
        emit Name((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000, (0x20 + var_c) - var_c, (arg1));
        require(!arg11, "LibItemCommon: NF types do not support RatioCut or RatioExtra");
        emit IdsAddedToScope((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000, ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000) + 0xffffffffffffffffffffffffffffffffffffffffffffffff, msg.sender);
        return (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        emit IdsAddedToScope((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000, (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000, msg.sender);
        return (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        var_r = 0x3d;
        require(!uint0((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        require(!uint0((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        var_p = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_p, var_r); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_p = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_p, var_r); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_p = 0;
        var_r = var_c.length;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d44f2e29(var_p, var_r, var_s); // staticcall
        require(!(ret0.length < 0x20), "unsupported");
        require(var_ad, "unsupported");
        require(!(bytes1(var_ad)), "unsupported");
        require(!(uint0(var_ad)), "LibItemCommon: Fee currency is not fungible");
        var_r = 0x2b;
        var_p = var_ad;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_p, var_r); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Fee currency cannot itself have transfer fees");
        require(!(bytes1(var_c.length)), "LibItemCommon: Fee currency cannot itself have transfer fees");
        require(!var_c.length);
        require(!var_c.length);
        var_p = var_k;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreator(var_p); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Fee currency is not from the same creator");
        require(address(var_c.length) == msg.sender, "LibItemCommon: Fee currency is not from the same creator");
        require(!(0xffffffffffffffff < (var_o)), "LibItemCommon: Fee value is too high");
        require(arg5);
        require(arg5);
        require(((var_c.length * arg5) / arg5) == var_c.length);
        require(0x2710);
        var_p = var_ad;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltValue(var_p); // staticcall
        require(!ret0.length < 0x20);
        var_p = 0x941994b789829d71f650dfab713d4117323b17985fd80961c2512bbba4f42e50;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getBool(var_p); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: ENJ fees are not allowed");
        require(0x01 == var_c.length, "LibItemCommon: ENJ fees are not allowed");
        require(!var_c.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(!var_c.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(arg5, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(arg5, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(((var_c.length * arg5) / arg5) == var_c.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(0x2710, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(!(var_o > ((var_c.length * arg5) / 0x2710)), "LibItemCommon: Transfer fee value is too high for _meltValue");
        if (!0x02 == var_c.length) {
        }
        var_p = (0x20 + (0x04 + var_c)) - (0x04 + var_c);
        require(!uint16(arg6));
        var_j = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        var_l = uint16(arg6);
        var_s = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_caee2b1a(var_j, var_l, var_af, var_p); // call
        var_j = (var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000;
        var_l = msg.sender;
        uint256 var_af = bytes1(arg7);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_93fb8f39(var_j, var_l); // call
        var_c = var_b + (0x05 + (0x20 + var_c));
        var_j = keccak256(var_k);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_e2a4853a(var_j); // call
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_7e686648(var_j); // call
        require(!arg8 > 0);
        require(!uint16(arg6));
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = uint16(arg6);
        var_s = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_caee2b1a(var_j, var_l, var_af, var_p); // call
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_93fb8f39(var_j, var_l); // call
        require(arg5 > 0);
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_af = 0;
        var_p = arg2;
        var_r = arg3;
        var_l = (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x04 + var_c)))))))) - (0x04 + var_c);
        var_v = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_v ether }Unresolved_2c4fa099(var_j, var_l, var_af, var_p); // call
        require(!0);
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        require(address(0).code.length);
        (bool success, bytes memory ret0) = address(0).{ value: var_af ether }Unresolved_d66d6c10(var_j); // call
        emit TransferSingle(msg.sender, 0, 0, 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000), 0);
        uint256 var_ah = 0;
        emit Name(0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000), (0x20 + var_c) - var_c, (arg1));
        require(!arg11);
        emit IdsAddedToScope(0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000), (0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000)) + 0xffffffffffffffffffffffffffffffffffffffffffffffff, msg.sender);
        return 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        emit IdsAddedToScope(0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000), 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000), msg.sender);
        return 0x4000000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        require(uint16(arg6));
        var_c = var_b + (0x05 + (0x20 + var_c));
        var_j = keccak256(var_k);
        var_l = address(msg.sender);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }setUint(var_j, var_l); // call
        var_j = 0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = arg2;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }Unresolved_7e686648(var_j, var_l, var_af); // call
        require(!arg8 > 0);
        require(!uint16(arg6));
        var_j = 0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = uint16(arg6);
        var_s = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }Unresolved_caee2b1a(var_j, var_l, var_af, var_p, var_r, var_s); // call
        var_j = 0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = msg.sender;
        var_af = bytes1(arg7);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_93fb8f39(var_j, var_l, var_af, var_p); // call
        require(arg5 > 0);
        var_j = 0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_af = 0;
        var_p = arg2;
        var_r = arg3;
        var_s = arg5;
        var_l = (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x20 + (0x04 + var_c)))))))) - (0x04 + var_c);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }Unresolved_2c4fa099(var_j, var_l, var_af, var_p, var_r, var_s); // call
        require(!0);
        var_j = 0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000);
        var_l = arg2;
        require(address(0).code.length);
        (bool success, bytes memory ret0) = address(0).{ value: var_ah ether }register(var_j, var_l); // call
        var_c = var_b + (0x05 + (0x20 + var_c));
        var_j = keccak256(var_k);
        var_l = address(msg.sender);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }setUint(var_j, var_l); // call
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | (0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        var_l = arg2;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }Unresolved_7e686648(var_j, var_l, var_af); // call
        require(!arg8 > 0);
        require(!uint16(arg6));
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | (0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        var_l = uint16(arg6);
        var_s = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_ah ether }Unresolved_caee2b1a(var_j, var_l, var_af, var_p, var_r, var_s); // call
        var_j = 0x4000000000000000000000000000000000000000000000000000000000000000 | (0x0800000000000000000000000000000000000000000000000000000000000000 | ((var_c.length << 0xc0) | 0x80000000000000000000000000000000000000000000000000000000000000));
        var_l = msg.sender;
        var_af = bytes1(arg7);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_93fb8f39(var_j, var_l, var_af, var_p); // call
        if (0) {
            if (uint16(arg6)) {
            }
            if (uint16(arg6)) {
            }
            if (arg7) {
                if (0) {
                }
                require(bytes1(arg7));
            }
        }
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_c9f68037(var_b); // call
        if (!ret0.length < 0x20) {
            if (arg8) {
                require(!ret0.length < 0x20);
            }
            require(arg8);
        }
        require(!uint16(arg6));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1c2fef80(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _meltFeeRatio is too high");
        require(!(uint16(arg6) > (uint16(var_c.length))), "LibItemCommon: _meltFeeRatio is too high");
        require(!(arg2 < arg3), "LibItemCommon: _totalSupply is lower than _initialReserve");
        require(!(bytes1(arg7) > 0x02), "LibItemCommon: Invalid _transferable value");
        var_d = 0x2a;
        var_b = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b, var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_b, var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _supply is 0");
        require(var_c.length, "LibItemCommon: _supply is 0");
        require(arg3 > 0, "LibItemCommon: _supply is 0");
        var_b = 0x20;
        require(!arg5);
        require(!arg11);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_5a12c0a5(var_b); // call
        if (!ret0.length < 0x20) {
            if (arg8) {
                require(!ret0.length < 0x20);
            }
            require(arg8);
        }
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_s ether }Unresolved_c9f68037(var_b); // call
        if (!ret0.length < 0x20) {
            if (arg8) {
                require(!ret0.length < 0x20);
            }
            require(arg8);
        }
    }
    
    /// @custom:selector    0x20255621
    /// @custom:signature   Unresolved_20255621(address arg0, uint0 arg1) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    function Unresolved_20255621(address arg0, uint0 arg1) public payable returns (bool) {
        var_a = 0x80 + var_a;
        uint0 var_d = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_a.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        var_a = var_a + 0x44;
        var_h = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_h); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(arg1), "LibItemCommon: _id is malformed");
        require(address(arg1 >> 0x40) == (address(var_a.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        uint0 var_h = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_6b8ff574(var_h); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x20);
        require(!var_a.length > 0x0100000000);
        require(!((var_a + var_a.length) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_l + ((var_a + var_a.length) + 0x20))) | (var_l > 0x0100000000));
        require(!0 < (var_n));
        require(!bytes1(var_n));
        uint0 var_r = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1aa347dc(var_r); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x20);
        require(!var_a.length > 0x0100000000);
        require(!((var_a + var_a.length) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_l + ((var_a + var_a.length) + 0x20))) | (var_l > 0x0100000000));
        require(!0 < (var_n));
        require(!bytes1(var_n));
        var_a = 0x20 + (var_l + (0x20 + var_a) - (bytes1(var_l)));
        uint0 var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d48e638a(var_v); // staticcall
        require(!ret0.length < 0x20);
        var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_v); // staticcall
        require(!ret0.length < 0x20);
        var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e3a67bf(var_v); // staticcall
        require(!ret0.length < 0x20);
        var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e453367(var_v); // staticcall
        require(!ret0.length < 0x20);
        var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_v); // staticcall
        require(!ret0.length < 0x20);
        var_v = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_v); // staticcall
        require(!ret0.length < 0x20);
        require(!(uint64(arg1) >> 0xf8) == var_a.length);
        require(!uint0(uint64(arg1)));
        require(!uint64(arg1));
        var_a = var_a + 0x44;
        uint256 var_ab = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_ab); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(uint64(arg1)), "LibItemCommon: _id is malformed");
        require(address(uint64(arg1) >> 0x40) == (address(var_a.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_ab); // staticcall
        require(!ret0.length < 0x20);
        require(bytes1(uint64(arg1)));
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_ab); // staticcall
        require(!ret0.length < 0x20);
        require(!(uint64(arg1) >> 0xf8) == var_a.length);
        require(!uint0(uint64(arg1)));
        require(!uint64(arg1));
        var_ac = (address(uint64(arg1)) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) >> 0x01;
        var_a = var_a + 0x44;
        uint256 var_ag = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_ag); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(uint64(arg1)), "LibItemCommon: _id is malformed");
        require(address(uint64(arg1) >> 0x40) == (address(var_a.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_ag); // staticcall
        require(!ret0.length < 0x20);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_ag); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_a.length > var_a.length), "SafeMath: sub underflow");
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_77778db3(var_ag); // staticcall
        require(!ret0.length < 0x20);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e78bf08(var_ag); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_a.length)) > 0x02);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_ag); // staticcall
        require(!ret0.length < 0x20);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_20ec4a86(var_ag); // staticcall
        require(!ret0.length < 0x20);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_0a432df0(var_ag); // staticcall
        require(!ret0.length < 0x20);
        var_ag = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f8057921(var_ag); // staticcall
        require(!ret0.length < 0x20);
        require(!0 < 0x40);
        require(!0 < 0x60);
        require(!(bytes1(var_a.length)) > 0x02);
        require(!0 < 0x80);
        require(!bytes1(var_a.length));
        require(!bytes1(var_a.length));
        return abi.encodePacked((0x20 + (0x80 + (0x20 + (0x60 + (0x20 + ((0x20 + (0x20 + (0x20 + (0x20 + var_a)))) + 0x40)))))) - var_a, (var_a.length + (0x20 + (0x20 + (0x80 + (0x20 + (0x60 + (0x20 + ((0x20 + (0x20 + (0x20 + (0x20 + var_a)))) + 0x40)))))))) - var_a, address(var_a.length), var_a.length, address(var_a.length), bytes1(var_a.length), !(!uint0(arg1)), var_a.length, var_a.length, (~((0x0100 ** (0x20 - (bytes1(var_a.length)))) - 0x01)) & (var_ay));
        return abi.encodePacked((0x20 + (0x80 + (0x20 + (0x60 + (0x20 + ((0x20 + (0x20 + (0x20 + (0x20 + var_a)))) + 0x40)))))) - var_a, (var_a.length + (0x20 + (0x20 + (0x80 + (0x20 + (0x60 + (0x20 + ((0x20 + (0x20 + (0x20 + (0x20 + var_a)))) + 0x40)))))))) - var_a, address(var_a.length), var_a.length, address(var_a.length), bytes1(var_a.length), !(!uint0(arg1)), var_a.length, var_a.length);
        require(0, "LibItemCommon: _id is malformed");
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_ab, var_ac); // staticcall
        require(!ret0.length < 0x20);
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreatedTime(var_ab); // staticcall
        require(!ret0.length < 0x20);
        var_ab = uint64(arg1);
        var_ac = var_a.length;
        require(address(var_a.length).code.length);
        (bool success, bytes memory ret0) = address(var_a.length).Unresolved_4ccf9e93(var_ab, var_ac); // staticcall
        if (!ret0.length < 0x20) {
            require(!(ret0.length < 0x20), "SafeMath: sub underflow");
            require(!(var_a.length < var_a.length), "SafeMath: sub underflow");
            require(!(var_a.length > var_a.length), "SafeMath: sub underflow");
        }
        require(!(var_a.length > var_a.length), "SafeMath: sub underflow");
        var_ac = 0x17;
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_ab, var_ac); // staticcall
        require(!ret0.length < 0x20);
        var_ab = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getReserve(var_ab); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_a.length > var_a.length), "SafeMath: sub underflow");
        require(!((var_a.length + (var_a.length - var_a.length)) < (var_a.length - var_a.length)), "SafeMath: add overflow");
        if (!(var_a.length - var_a.length) < var_a.length) {
        }
        require(0, "LibItemCommon: _id is malformed");
        var_a = (var_l) + (0x20 + var_a);
        uint256 var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreator(var_az); // staticcall
        require(!ret0.length < 0x20);
        var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltValue(var_az); // staticcall
        require(!ret0.length < 0x20);
        var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltFee(var_az); // staticcall
        require(!ret0.length < 0x20);
        var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e453367(var_az, var_v); // staticcall
        require(!ret0.length < 0x20);
        var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_az, var_v); // staticcall
        require(!ret0.length < 0x20);
        var_az = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_az, var_v); // staticcall
        require(!ret0.length < 0x20);
        uint0 var_k = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getURI(var_k); // staticcall
        require(!ret0.length < 0x20);
        require(0, "LibItemCommon: _id is malformed");
    }
    
    /// @custom:selector    0xc7209e4a
    /// @custom:signature   Unresolved_c7209e4a(address arg0, uint256 arg1, uint16 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint16", "bytes2", "int16"]
    function Unresolved_c7209e4a(address arg0, uint256 arg1, uint16 arg2) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_2b3ae9c3(var_b); // call
        emit Event_9be972ea(arg1, uint16(arg2));
    }
    
    /// @custom:selector    0x0df381aa
    /// @custom:signature   Unresolved_0df381aa(address arg0, uint0 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    function Unresolved_0df381aa(address arg0, uint0 arg1) public payable returns (uint256) {
        uint0 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_c.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        uint256 var_c = var_c + 0x44;
        var_g = keccak256(var_h);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_g); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(arg1), "LibItemCommon: _id is malformed");
        require(address(arg1 >> 0x40) == (address(var_c.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        uint0 var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_g); // staticcall
        require(!ret0.length < 0x20);
        require(bytes1(arg1));
        return var_c.length;
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_4ccf9e93(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_g); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!(var_c.length < var_c.length), "SafeMath: add overflow");
        require(!(var_c.length > var_c.length), "SafeMath: add overflow");
        require(!(var_c.length > var_c.length), "SafeMath: add overflow");
        require(!(((var_c.length - var_c.length) + var_c.length) < var_c.length), "SafeMath: add overflow");
        require(!((var_c.length - var_c.length) + ((var_c.length - var_c.length) + var_c.length) < ((var_c.length - var_c.length) + var_c.length)), "SafeMath: add overflow");
        require(!((var_c.length - var_c.length) + ((var_c.length - var_c.length) + var_c.length) > 0xffffffffffffffff), "SafeMath: add overflow");
        return (var_c.length - var_c.length) + var_c.length;
        require(!(((var_c.length - var_c.length) + var_c.length) < var_c.length), "SafeMath: add overflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!(var_c.length - var_c.length) < var_c.length);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_77778db3(var_g); // staticcall
        require(!ret0.length < 0x20);
        require(0, "LibItemCommon: _id is malformed");
    }
    
    /// @custom:selector    0x59356146
    /// @custom:signature   Unresolved_59356146(address arg0, uint64 arg1) public payable returns (address)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_59356146(address arg0, uint64 arg1) public payable returns (address) {
        uint256 var_d = var_d + 0x4c;
        var_f = keccak256(var_g);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_21f8a721(var_f); // staticcall
        require(!ret0.length < 0x20);
        require(!address(var_d.length));
        uint64 var_f = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d48e638a(var_f); // staticcall
        require(!ret0.length < 0x20);
        return address(var_d.length);
        return address(var_d.length);
    }
    
    /// @custom:selector    0xc3ea4147
    /// @custom:signature   Unresolved_c3ea4147(address arg0, uint0 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    function Unresolved_c3ea4147(address arg0, uint0 arg1) public payable returns (uint256) {
        uint0 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_c.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        uint256 var_c = var_c + 0x44;
        var_g = keccak256(var_h);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_g); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(arg1), "LibItemCommon: _id is malformed");
        require(address(arg1 >> 0x40) == (address(var_c.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        uint0 var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_g); // staticcall
        require(!ret0.length < 0x20);
        require(bytes1(arg1));
        return var_c.length;
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_4ccf9e93(var_g); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_c.length < var_c.length), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!(var_c.length > 0xffffffffffffffff), "SafeMath: sub underflow");
        return var_c.length;
        return 0xffffffffffffffff;
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_77778db3(var_g); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        require(!((var_c.length + (var_c.length - var_c.length)) < (var_c.length - var_c.length)), "SafeMath: add overflow");
        if (!(var_c.length - var_c.length) < var_c.length) {
        }
        require(0, "LibItemCommon: _id is malformed");
    }
    
    /// @custom:selector    0xfba6f0f4
    /// @custom:signature   Unresolved_fba6f0f4(address arg0, uint64 arg1, address arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    /// @param              arg2 ["address", "uint128", "bytes16", "int128"]
    function Unresolved_fba6f0f4(address arg0, uint64 arg1, address arg2) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
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
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length > block.timestamp);
        require((block.timestamp - var_c.length) > 0x24ea00);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_77778db3(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: add overflow");
        require(!(var_c.length > var_c.length), "SafeMath: add overflow");
        require(!(address(arg2) + (var_c.length - var_c.length) < (var_c.length - var_c.length)), "SafeMath: add overflow");
        require(0x03);
        require(!((block.timestamp - var_c.length) / 0x03) < (address(arg2) + (var_c.length - var_c.length)));
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_ee6ab318(var_b); // call
        require(!ret0.length < 0x20);
        require(!var_c.length);
        require(!var_c.length);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_b = address(msg.sender);
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_7843e5dd(var_b); // call
        emit ReserveReleased(arg1, var_c.length);
        require(var_c.length, "SafeMath: mul overflow");
        require(((var_c.length * var_c.length) / var_c.length) == var_c.length, "SafeMath: mul overflow");
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length > 0);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_620a3cbe(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: add overflow");
        require((var_c.length - var_c.length) > var_c.length, "SafeMath: add overflow");
        require(!((address(arg2) + 0) < 0), "SafeMath: add overflow");
        require(0x03, "LibItemCommon: Melting _value would melt over the minimum reserve");
        require(!(((block.timestamp - var_c.length) / 0x03) < (address(arg2) + 0)), "LibItemCommon: Melting _value would melt over the minimum reserve");
        require(!(var_c.length > (var_c.length - var_c.length)), "SafeMath: sub underflow");
    }
    
    /// @custom:selector    0x6add6a01
    /// @custom:signature   Unresolved_6add6a01(address arg0, uint256 arg1, address arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_6add6a01(address arg0, uint256 arg1, address arg2) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_cd066c1c(var_b); // call
        emit Assign(arg1, msg.sender, address(arg2));
    }
    
    /// @custom:selector    0xdb3d65e4
    /// @custom:signature   Unresolved_db3d65e4(address arg0, uint64 arg1) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_db3d65e4(address arg0, uint64 arg1) public payable returns (bytes memory) {
        var_a = 0x40 + var_a;
        uint64 var_d = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_a.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        var_a = var_a + 0x44;
        var_h = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_h); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(arg1), "LibItemCommon: _id is malformed");
        require(address(arg1 >> 0x40) == (address(var_a.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        uint64 var_h = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_6b8ff574(var_h); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!ret0.length < 0x20);
        require(!var_a.length > 0x0100000000);
        require(!((var_a + var_a.length) + 0x20) > (var_a + ret0.length));
        require(!((var_a + ret0.length) < (var_l + ((var_a + var_a.length) + 0x20))) | (var_l > 0x0100000000));
        require(!0 < (var_n));
        require(!bytes1(var_n));
        var_a = 0x20 + (var_l + (0x20 + var_a) - (bytes1(var_l)));
        uint64 var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_20ec4a86(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_0a432df0(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_a = var_a + 0x4c;
        uint256 var_ac = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_21f8a721(var_ac); // staticcall
        require(!ret0.length < 0x20);
        require(!address(var_a.length));
        var_ac = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d48e638a(var_ac); // staticcall
        require(!ret0.length < 0x20);
        var_ac = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bc7a17c5(var_ac); // staticcall
        require(!ret0.length < 0x20);
        var_ac = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e3a67bf(var_ac); // staticcall
        require(!ret0.length < 0x20);
        var_ac = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e78bf08(var_ac); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_a.length)) > 0x02);
        require(!(bytes1(var_a.length)) > 0x02);
        require(!0 < 0xe0);
        require(!0 < 0x40);
        require(!bytes1(var_a.length));
        return abi.encodePacked((0x20 + (0x20 + (0x40 + (0xe0 + (var_a + 0x20))))) - var_a, uint16(var_a.length), bytes1(var_a.length), var_a.length, (~((0x0100 ** (0x20 - (bytes1(var_a.length)))) - 0x01)) & (var_aj));
        return abi.encodePacked((0x20 + (0x20 + (0x40 + (0xe0 + (var_a + 0x20))))) - var_a, uint16(var_a.length), bytes1(var_a.length), var_a.length);
        var_a = (var_l) + (0x20 + var_a);
        uint64 var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getMeltValue(var_k); // staticcall
        require(!ret0.length < 0x20);
        var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getTotalSupply(var_k); // staticcall
        require(!ret0.length < 0x20);
        var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_k, var_s); // staticcall
        require(!ret0.length < 0x20);
        var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_20ec4a86(var_k, var_s); // staticcall
        require(!ret0.length < 0x20);
        var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_0a432df0(var_k, var_s); // staticcall
        require(!ret0.length < 0x20);
        var_k = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getCreatedTime(var_k); // staticcall
        require(!ret0.length < 0x20);
        uint256 var_al = keccak256(var_i);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).getAddress(var_al); // staticcall
        require(!ret0.length < 0x20);
        require(0, "LibItemCommon: _id is malformed");
    }
    
    /// @custom:selector    0x9ba9e0a7
    /// @custom:signature   Unresolved_9ba9e0a7(address arg0, uint256 arg1, uint16 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint16", "bytes2", "int16"]
    function Unresolved_9ba9e0a7(address arg0, uint256 arg1, uint16 arg2) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e3a67bf(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(uint16(arg2) < (uint16(var_c.length)));
        require(uint16(arg2) < (uint16(var_c.length)));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_a6566f8d(var_b); // call
        emit Event_14d81f43(arg1, uint16(arg2));
        var_b = 0x20;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1c2fef80(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _fee too high");
        require(!(uint16(arg2) > (uint16(var_c.length))), "LibItemCommon: _fee too high");
    }
    
    /// @custom:selector    0xd8964500
    /// @custom:signature   Unresolved_d8964500(address arg0, uint0 arg1) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    function Unresolved_d8964500(address arg0, uint0 arg1) public payable returns (bool) {
        uint0 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_c.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        uint256 var_c = var_c + 0x44;
        var_g = keccak256(var_h);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_g); // staticcall
        require(!ret0.length < 0x20);
        require(bytes1(arg1));
        require(address(arg1 >> 0x40) == (address(var_c.length)));
        return 0x01;
        return 0;
        return 0x01;
        return 0x01;
        return 0;
    }
    
    /// @custom:selector    0xfc148139
    /// @custom:signature   Unresolved_fc148139(address arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_fc148139(address arg0, uint256 arg1, uint256 arg2) public payable {
        uint256 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length > block.timestamp);
        require((block.timestamp - var_c.length) > 0x24ea00);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_77778db3(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: add overflow");
        require(!(var_c.length > var_c.length), "SafeMath: add overflow");
        require(!((arg2 + (var_c.length - var_c.length)) < (var_c.length - var_c.length)), "SafeMath: add overflow");
        require(0x03);
        require(!((block.timestamp - var_c.length) / 0x03) < (arg2 + (var_c.length - var_c.length)));
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length > 0);
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_620a3cbe(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: add overflow");
        require((var_c.length - var_c.length) > var_c.length, "SafeMath: add overflow");
        require(!((arg2 + 0) < 0), "SafeMath: add overflow");
        require(0x03, "LibItemCommon: Melting _value would melt over the minimum reserve");
        require(!(((block.timestamp - var_c.length) / 0x03) < (arg2 + 0)), "LibItemCommon: Melting _value would melt over the minimum reserve");
        require(!(var_c.length > (var_c.length - var_c.length)), "SafeMath: sub underflow");
    }
    
    /// @custom:selector    0x3ef2b102
    /// @custom:signature   Unresolved_3ef2b102(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_3ef2b102(address arg0, uint256 arg1) public payable {
        require(arg1);
        require(arg1);
        require(((0x03e8 * arg1) / arg1) == 0x03e8);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_ee28d7a3(var_b); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: add overflow");
        require(arg1, "SafeMath: add overflow");
        require(arg1, "SafeMath: add overflow");
        require(((0x0f4240 * arg1) / arg1) == 0x0f4240, "SafeMath: add overflow");
        require(!((0x01 + (0x0f4240 * arg1)) < (0x0f4240 * arg1)), "SafeMath: add overflow");
        require(0x02, "SafeMath: mul overflow");
        require(!(((0x01 + (0x0f4240 * arg1)) / 0x02) < (0x0f4240 * arg1)), "SafeMath: mul overflow");
        require((0x01 + (0x0f4240 * arg1)) / 0x02, "SafeMath: mul overflow");
    }
    
    /// @custom:selector    0x7b2bae64
    /// @custom:signature   Unresolved_7b2bae64(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_7b2bae64(address arg0, uint256 arg1) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_d = 0x20 + (0x0f + (0x20 + var_d));
        var_f = keccak256(var_g);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_21f8a721(var_f); // staticcall
        require(!ret0.length < 0x20);
        require(address(var_d.length) == msg.sender);
        var_d = 0x20 + (0x0c + (0x20 + var_d));
        var_k = keccak256(var_g);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_ca446dd9(var_k); // call
        var_d = var_d + 0x2f;
        var_o = keccak256(var_g);
        uint256 var_p = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_p ether }Unresolved_ca446dd9(var_o); // call
        emit Event_c0ac0a69(arg1, address(var_d.length));
    }
    
    /// @custom:selector    0x3874f484
    /// @custom:signature   Unresolved_3874f484(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_3874f484(address arg0, uint256 arg1) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_42d98f71(var_b); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Sender must be assignee");
        require(address(var_c.length) == msg.sender, "LibItemCommon: Sender must be assignee");
        var_b = arg1;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_91686f53(var_b); // call
        var_b = arg1;
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_d ether }Unresolved_cd066c1c(var_b); // call
        emit AcceptAssignment(arg1, address(var_c.length));
    }
    
    /// @custom:selector    0x8bf1be36
    /// @custom:signature   Unresolved_8bf1be36(address arg0, uint64 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_8bf1be36(address arg0, uint64 arg1) public payable returns (uint256) {
        uint64 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_745c8b45(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(arg1 >> 0xf8) == var_c.length);
        require(!uint0(arg1));
        require(!uint64(arg1));
        uint256 var_c = var_c + 0x44;
        var_g = keccak256(var_h);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_bd02d0f5(var_g); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: _id is malformed");
        require(bytes1(arg1), "LibItemCommon: _id is malformed");
        require(address(arg1 >> 0x40) == (address(var_c.length)), "LibItemCommon: _id is malformed");
        require(0x01, "LibItemCommon: _id is malformed");
        uint64 var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_2df3f42a(var_g); // staticcall
        require(!ret0.length < 0x20);
        var_g = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_92ab723e(var_g); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!(var_c.length > var_c.length), "SafeMath: sub underflow");
        return var_c.length - var_c.length;
        require(0, "LibItemCommon: _id is malformed");
    }
    
    /// @custom:selector    0x60522718
    /// @custom:signature   Unresolved_60522718(address arg0, uint0 arg1, uint256 arg2, uint16 arg3) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint0", "bytes0", "int0"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["uint16", "bytes2", "int16"]
    function Unresolved_60522718(address arg0, uint0 arg1, uint256 arg2, uint16 arg3) public payable {
        require(!address(this) == 0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5);
        uint256 var_a = 0x60 + var_a;
        require(0x05 > var_a.length, "LibItemCommon: Transfer fee type is invalid");
        uint256 var_d = (0x20 + (0x04 + var_a)) - (0x04 + var_a);
        require(var_g);
        require(0x03 == var_a.length);
        require(!0x03 == var_a.length);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d45c47cc(var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Transfer fee value is higher than maximum");
        require(!(var_h > (uint16(var_a.length))), "LibItemCommon: Transfer fee value is higher than maximum");
        require(!(uint0(arg1)), "LibItemCommon: NF types do not support RatioCut or RatioExtra");
        var_d = arg1;
        require(!0 < 0x60);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_caee2b1a(var_d); // call
        require(!uint0(arg1));
        require(!0x02 == var_a.length);
        var_d = msg.sender;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_465b17de(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_d = 0;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d44f2e29(var_d); // staticcall
        require(!(ret0.length < 0x20), "unsupported");
        require(var_j, "unsupported");
        require(!(bytes1(var_j)), "unsupported");
        require(!(uint0(var_j)), "LibItemCommon: Fee currency is not fungible");
        var_d = var_j;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Fee currency cannot itself have transfer fees");
        require(!(bytes1(var_a.length)), "LibItemCommon: Fee currency cannot itself have transfer fees");
        require(!var_a.length);
        require(!var_a.length);
        var_d = var_l;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_d48e638a(var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: Fee currency is not from the same creator");
        require(address(var_a.length) == msg.sender, "LibItemCommon: Fee currency is not from the same creator");
        require(!(0xffffffffffffffff < (var_g)), "LibItemCommon: Fee value is too high");
        require(arg5);
        require(arg5);
        require(((var_a.length * arg5) / arg5) == var_a.length);
        require(0x2710);
        var_d = var_j;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_874047a8(var_d); // staticcall
        require(!ret0.length < 0x20);
        var_d = 0x941994b789829d71f650dfab713d4117323b17985fd80961c2512bbba4f42e50;
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_7ae1cfca(var_d); // staticcall
        require(!(ret0.length < 0x20), "LibItemCommon: ENJ fees are not allowed");
        require(0x01 == var_a.length, "LibItemCommon: ENJ fees are not allowed");
        require(!var_a.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(!var_a.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(arg5, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(arg5, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(((var_a.length * arg5) / arg5) == var_a.length, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(0x2710, "LibItemCommon: Transfer fee value is too high for _meltValue");
        require(!(var_g > ((var_a.length * arg5) / 0x2710)), "LibItemCommon: Transfer fee value is too high for _meltValue");
    }
    
    /// @custom:selector    0x8f5398de
    /// @custom:signature   Unresolved_8f5398de(address arg0, uint64 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_8f5398de(address arg0, uint64 arg1) public payable returns (uint256) {
        uint64 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f521a982(var_b); // staticcall
        require(!ret0.length < 0x20);
        return var_c.length;
    }
    
    /// @custom:selector    0xb370e739
    /// @custom:signature   Unresolved_b370e739(address arg0, uint64 arg1) public payable returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_b370e739(address arg0, uint64 arg1) public payable returns (bytes memory) {
        uint64 var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_1e78bf08(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x02);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_73007500(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_20ec4a86(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_0a432df0(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = uint64(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_f8057921(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x02);
        require(!(bytes1(var_c.length)) > 0x05);
        return abi.encodePacked(bytes1(var_c.length), bytes1(var_c.length), var_c.length, var_c.length, var_c.length);
    }
}