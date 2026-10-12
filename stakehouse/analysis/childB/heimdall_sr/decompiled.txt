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
    uint256 public unresolved_4b705bd0;
    bytes32 store_o;
    address store_k;
    mapping(bytes32 => bytes32) storage_map_q;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_j;
    bytes32 store_b;
    bytes32 store_a;
    mapping(bytes32 => bytes32) storage_map_i;
    mapping(bytes32 => bytes32) storage_map_p;
    mapping(bytes32 => bytes32) storage_map_m;
    address public universe;
    bytes32 store_l;
    address public unresolved_a68645a3;
    mapping(bytes32 => bytes32) storage_map_e;
    mapping(bytes32 => bytes32) storage_map_n;
    mapping(bytes32 => bytes32) storage_map_c;
    
    event Event_22c8ccdb();
    
    /// @custom:selector    0x67fbfe86
    /// @custom:signature   Unresolved_67fbfe86(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint64 arg5, uint256 arg6, uint64 arg7, uint64 arg8) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint64", "bytes8", "int64"]
    /// @param              arg6 ["uint256", "bytes32", "int256"]
    /// @param              arg7 ["uint64", "bytes8", "int64"]
    /// @param              arg8 ["uint64", "bytes8", "int64"]
    function Unresolved_67fbfe86(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint64 arg5, uint256 arg6, uint64 arg7, uint64 arg8) public {
        require(arg0 == arg0);
        require(!arg1 > 0xffffffffffffffff);
        require(!(msg.data.length - 0x44) < 0x80);
        require(!arg6 > 0xffffffffffffffff);
        require((0x60 + (arg1)) > 0);
        require(arg2 > block.number);
        require(!(arg1 + (arg1 + 0x20)) > 0xffffffffffffffff);
        require(!(arg6 + (arg6)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(keccak256(var_a) == keccak256(var_a), "Key mismatch");
        require(!(arg1 + (arg1 + 0x20)) > 0xffffffffffffffff);
        require(!(arg1 + (0x80 + (arg1))) > 0xffffffffffffffff);
        require(!0 < (arg1 + (0x80 + (arg1))));
        require(0 < (arg1 + (0x80 + (arg1))));
        require(0 < (arg1 + (0x80 + (arg1))));
        require(0 < (arg1 + (0x80 + (arg1))));
        require(!(((0x40 + (0 + (0x20 + ((0x04 + arg1) + (0x80 + (arg1)))))) + 0x20) - (0x40 + (0 + (0x20 + ((0x04 + arg1) + (0x80 + (arg1))))))) < 0x20);
        require((0x40 + (0 + (0x20 + (arg1 + (0x80 + (arg1)))))) == (address(0x40 + (0 + (0x20 + (arg1 + (0x80 + (arg1))))))));
        require(0 < (arg1 + (0x80 + (arg1))));
        uint256 var_j = 0x80 + (0x20 + var_j);
        var_j = 0x60 + (0x80 + (0x20 + var_j));
        require(0x01);
        require(!(arg1 + (arg1 + 0x80)) > 0xffffffffffffffff);
        require(0 < (arg1 + (arg1 + 0x80)));
        require(!(arg6 + (arg6)) > 0xffffffffffffffff);
        require(!(arg6 + (arg6 + 0x20)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!(((0x40 + (0x04 + arg6)) + 0x20) - (0x40 + (0x04 + arg6))) < 0x20);
        require((0x40 + (arg6)) == (0x40 + (arg6)));
        require(!(((0x04 + arg6) + 0x80) - ((0x04 + arg6) + 0x60)) < 0x20);
        require((arg6 + 0x60) == (uint64(arg6 + 0x60)));
        require(!(((0x04 + arg6) + 0xa0) - ((0x04 + arg6) + 0x80)) < 0x20);
        require((arg6 + 0x80) == (uint64(arg6 + 0x80)));
        require(!(((0x04 + arg6) + 0xc0) - ((0x04 + arg6) + 0xa0)) < 0x20);
        require((arg6 + 0xa0) == (uint64(arg6 + 0xa0)));
        require(!(((0x04 + arg6) + 0xe0) - ((0x04 + arg6) + 0xc0)) < 0x20);
        require((arg6 + 0xc0) == (uint64(arg6 + 0xc0)));
        require(!(((0x04 + arg6) + 0x0100) - ((0x04 + arg6) + 0xe0)) < 0x20);
        require((arg6 + 0xe0) == (uint64(arg6 + 0xe0)));
        require(!(((0x04 + arg6) + 0x0120) - ((0x04 + arg6) + 0x0100)) < 0x20);
        require((arg6 + 0x0100) == (uint64(arg6 + 0x0100)));
        var_j = 0x0180 + var_j;
        var_j = 0x0100 + var_j;
        var_j = 0xc0 + var_j;
        require(!0x20 < 0x20);
        require(arg3 == (bytes1(arg3)));
        require(!(arg5 > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0), "Invalid Report");
        require(!(0x03 > 0x04), "Invalid Report");
        require(0x03, "Invalid Report");
        uint256 var_o = 0;
        var_am = 0xcc;
        require(bytes1(storage_map_c[var_o]), "Invalid Report");
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x02, "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature length");
        require(0x01, "ECDSA: invalid signature length");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0, "ECDSA: invalid signature 'v' value");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "ECDSA: invalid signature 'v' value");
        require(0x1b == (bytes1(arg3)));
        require(0x1b == (bytes1(arg3)));
        require(var_am);
        if (address(var_ax)) {
        }
    }
    
    /// @custom:selector    0x83147048
    /// @custom:signature   Unresolved_83147048(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_83147048(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(0x3b9aca00) & ((arg0 + 0x60) > 0x044b82fa09b5a52cb98b405447c4a98187eebb22f008d5d64f9c394ae9));
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(arg0 + (arg0 + 0x80)) > 0xffffffffffffffff);
        require(0 < (arg0 + (arg0 + 0x80)));
        require(!((0 + (0x20 + (arg0 + (arg0 + 0x80)))) + 0x20) < unresolved_4b705bd0);
        var_c = msg.data[36:36];
        require(bytes1(storage_map_e[var_c]));
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(0x3b9aca00) & ((arg0 + 0x40) > 0x044b82fa09b5a52cb98b405447c4a98187eebb22f008d5d64f9c394ae9));
        require(!(0x3b9aca00 * (arg0 + 0x40)) < 0x01bc16d674ec800000);
        var_c = msg.data[36:36];
        require(!storage_map_e[var_c] < ((0x3b9aca00 * (arg0 + 0x40)) - 0x01bc16d674ec800000));
        return 0x3b9aca00 * (arg0 + 0x60);
        require(!((0x3b9aca00 * (arg0 + 0x40)) - 0x01bc16d674ec800000) < storage_map_e[var_c]);
        require(!(0x3b9aca00 * (arg0 + 0x60)) < (((0x3b9aca00 * (arg0 + 0x40)) - 0x01bc16d674ec800000) - storage_map_e[var_c]));
        require(!(0x3b9aca00 * (arg0 + 0x60)) < (((0x3b9aca00 * (arg0 + 0x40)) - 0x01bc16d674ec800000) - storage_map_e[var_c]));
        return (0x3b9aca00 * (arg0 + 0x60)) - (((0x3b9aca00 * (arg0 + 0x40)) - 0x01bc16d674ec800000) - storage_map_e[var_c]);
        require(!(((0 + (0x20 + (arg0 + (arg0 + 0x80)))) + 0x20) < (0 + (0x20 + (arg0 + (arg0 + 0x80))))), "Not first sweep");
        (bool success, bytes memory ret0) = address(universe).saveETHRegistry(); // staticcall
        uint256 var_h = var_h + (uint248(ret0.length + 0x1f));
        require(!((var_h + ret0.length) - var_h) < 0x20);
        require(var_h.length == (address(var_h.length)));
        var_f = 0x20;
        (bool success, bytes memory ret0) = address(var_h.length).Unresolved_8ed759a0(var_f); // staticcall
        var_h = var_h + (uint248(ret0.length + 0x1f));
        require(!((var_h + ret0.length) - var_h) < 0x20);
        require(!var_h.length);
        require((0x60 + (0 + (0x20 + (arg0 + (arg0 + 0x80))))) > 0);
        require(var_h.length > (0x60 + (0 + (0x20 + (arg0 + (arg0 + 0x80))))));
        require(!(0x3b9aca00 * (arg0 + 0x60)) < var_h.length);
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(0x3b9aca00) & ((arg0 + 0x40) > 0x044b82fa09b5a52cb98b405447c4a98187eebb22f008d5d64f9c394ae9));
        require(!(0x3b9aca00 * (arg0 + 0x60)) < (0x60 + (0 + (0x20 + (arg0 + (arg0 + 0x80))))));
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(0x3b9aca00) & ((arg0 + 0x40) > 0x044b82fa09b5a52cb98b405447c4a98187eebb22f008d5d64f9c394ae9));
        if (!((0 + (0x20 + (arg0 + (arg0 + 0x80)))) + 0x20) < unresolved_4b705bd0) {
        }
    }
    
    /// @custom:selector    0xb8f0a9ab
    /// @custom:signature   isSweepReported(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function isSweepReported(uint256 arg0) public view returns (bool) {
        uint256 var_b = arg0;
        return !(!bytes1(storage_map_g[var_b]));
    }
    
    /// @custom:selector    0x5d007a99
    /// @custom:signature   Unresolved_5d007a99(uint256 arg0, uint256 arg1, uint256 arg2) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_5d007a99(uint256 arg0, uint256 arg1, uint256 arg2) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(!arg2 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x17ab1b56
    /// @custom:signature   Unresolved_17ab1b56(uint256 arg0) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_17ab1b56(uint256 arg0) public pure returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        return keccak256(var_a);
    }
    
    /// @custom:selector    0x17ffd8af
    /// @custom:signature   Unresolved_17ffd8af(uint256 arg0, uint256 arg1) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_17ffd8af(uint256 arg0, uint256 arg1) public view returns (bytes memory) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!0 < (arg0));
        require(0 < (arg0));
        uint256 var_a = (0 + (arg0 + 0x20));
        require(bytes1(storage_map_i[var_a]));
        require(0x01);
        require(!0 > 0xffffffffffffffff);
        uint256 var_e = var_e + 0x20;
        require(!0);
        require(!0 < (arg0));
        require(0 < (arg0));
        var_a = (0 + (arg0 + 0x20));
        require(bytes1(storage_map_i[var_a]));
        require(0x01);
        require(0 < (arg0));
        return abi.encodePacked(0x20, var_e.length);
    }
    
    /// @custom:selector    0x6184bf91
    /// @custom:signature   Unresolved_6184bf91(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    function Unresolved_6184bf91(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public {
        require(!arg0 > 0xffffffffffffffff);
        require(!(msg.data.length - 0x24) < 0x80);
        require(!arg5 > 0xffffffffffffffff);
        (bool success, bytes memory ret0) = address(universe / 0x01).accountManager(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == (address(var_b.length)));
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        var_d = 0x20;
        (bool success, bytes memory ret0) = address(var_b.length).Unresolved_424de0c4(var_d); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!(((var_b + ret0.length) - var_b) < 0x20), "Signature expired");
        require(var_b.length < 0x06, "Signature expired");
        require(!(var_b.length > 0x05), "Signature expired");
        require(0x04 == var_b.length, "Signature expired");
        require((0x60 + (arg0)) > 0, "Signature expired");
        require(arg1 > block.number, "Signature expired");
    }
    
    /// @custom:selector    0x86863ec6
    /// @custom:signature   Unresolved_86863ec6(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_86863ec6(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0x22bbe554
    /// @custom:signature   Unresolved_22bbe554(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_22bbe554(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return !(!bytes1(storage_map_g[var_b]));
    }
    
    /// @custom:selector    0x8e33771f
    /// @custom:signature   validatorIndexToBLSKey(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function validatorIndexToBLSKey(uint256 arg0) public view returns (bytes memory) {
        uint256 var_b = arg0;
        require(bytes1(storage_map_g[var_b]));
        require(bytes1(storage_map_g[var_b]) - ((storage_map_g[var_b] >> 0x01) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_d = var_d + (0x20 + (((0x1f + (storage_map_g[var_b] >> 0x01)) / 0x20) * 0x20));
        require(bytes1(storage_map_g[var_b]));
        require(bytes1(storage_map_g[var_b]) - ((storage_map_g[var_b] >> 0x01) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!storage_map_g[var_b] >> 0x01);
        require(0x1f < (storage_map_g[var_b] >> 0x01));
        var_b = keccak256(var_b);
        require((0x20 + var_d) + (storage_map_g[var_b] >> 0x01) > (0x20 + (0x20 + var_d)));
        require(!0 > var_d.length);
        return abi.encodePacked(0x20, var_d.length);
        return abi.encodePacked(0x20, var_d.length);
    }
    
    /// @custom:selector    0xf78844a6
    /// @custom:signature   Unresolved_f78844a6(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_f78844a6(uint256 arg0) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return storage_map_j[var_e];
    }
    
    /// @custom:selector    0x678e15d9
    /// @custom:signature   Unresolved_678e15d9(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_678e15d9(uint256 arg0) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return storage_map_j[var_e];
    }
    
    /// @custom:selector    0x4f1ef286
    /// @custom:signature   Unresolved_4f1ef286(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_4f1ef286(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 > 0xffffffffffffffff), "Function must be called through delegatecall");
        require(!(((var_c + (uint248(0x3f + (arg1 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg1 + 0x1f)))) > 0xffffffffffffffff)), "Function must be called through delegatecall");
        var_e = msg.data[36:36];
        require(address(this) - 0xdf39face16519376e47bba3b9be15e69d8a66f2c, "Function must be called through delegatecall");
        require(address(store_k) == 0xdf39face16519376e47bba3b9be15e69d8a66f2c);
        require(address(universe));
        (bool success, bytes memory ret0) = address(universe).accessControls(); // staticcall
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(var_c.length == (address(var_c.length)));
        address var_h = address(this);
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_3b6cd6ff(var_h); // staticcall
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(var_c.length == var_c.length);
        require(var_c.length);
        address var_i = msg.sender;
        (bool success, bytes memory ret0) = address(var_c.length).Unresolved_f47f2f1d(var_i); // staticcall
        require(!var_c.length, "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_k = (address(arg0)) | (uint96(store_k));
        require(var_c.length > 0, "Address: delegate call to non-contract");
        require(!(var_c.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        require(!0 > var_c.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_o); // delegatecall
        require(ret0.length == 0);
        var_c = 0x60 + var_c;
        require(!var_q);
        require(!(0 > var_c.length), "                                       ");
        require(bytes1(store_l), "Address: delegate call to non-contract");
        store_l = 0x01 | (uint248(store_l));
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        var_c = 0x60 + var_c;
        require(!var_c.length);
        if (!0x01) {
        }
    }
    
    /// @custom:selector    0x3659cfe6
    /// @custom:signature   upgradeTo(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function upgradeTo(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(this) - 0xdf39face16519376e47bba3b9be15e69d8a66f2c, "Function must be called through delegatecall");
        require(address(store_k) == 0xdf39face16519376e47bba3b9be15e69d8a66f2c);
        require(address(universe));
        (bool success, bytes memory ret0) = address(universe).accessControls(); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        address var_c = address(this);
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_3b6cd6ff(var_c); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == var_f.length);
        require(var_f.length);
        address var_d = msg.sender;
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_f47f2f1d(var_d); // staticcall
        require(!var_f.length, "ERC1967: new implementation is not a contract");
        var_f = var_f + 0x20;
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_k = (address(arg0)) | (uint96(store_k));
        require(var_f.length > 0, "Address: delegate call to non-contract");
        require(!(var_f.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        require(!0 > var_f.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_m); // delegatecall
        require(ret0.length == 0);
        var_f = 0x60 + var_f;
        require(!var_o);
        require(!(0 > var_f.length), "                                       ");
        require(bytes1(store_l), "Address: delegate call to non-contract");
        store_l = 0x01 | (uint248(store_l));
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        var_f = 0x60 + var_f;
        require(!var_f.length);
    }
    
    /// @custom:selector    0x2b98c640
    /// @custom:signature   batchUnwrapDETH(bytes[] arg0, uint256[] arg1) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function batchUnwrapDETH(bytes[] arg0, uint256[] arg1) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!arg1 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0xe6618789
    /// @custom:signature   Unresolved_e6618789(uint256 arg0, uint256 arg1, uint256 arg2, address arg3, uint256 arg4) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_e6618789(uint256 arg0, uint256 arg1, uint256 arg2, address arg3, uint256 arg4) public pure returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!0 < (arg0));
        require(0 < (arg0));
        require(0 < (arg0));
        require(0 < (arg0));
        require(!(((0x40 + (0 + ((0x04 + arg0) + 0x20))) + 0x20) - (0x40 + (0 + ((0x04 + arg0) + 0x20)))) < 0x20);
        require((0x40 + (0 + (arg0 + 0x20))) == (address(0x40 + (0 + (arg0 + 0x20)))));
        require(0 < (arg0));
        uint256 var_f = 0x80 + (0x20 + var_f);
        require(0x01);
        return 0;
    }
    
    /// @custom:selector    0x7b172270
    /// @custom:signature   Unresolved_7b172270(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg18446744073709551615 ["uint256", "bytes32", "int256"]
    function Unresolved_7b172270(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!(0 < (arg0)), "Reported");
        require(0 < (arg0), "Reported");
        uint256 var_a = (0 + (arg0 + 0x20));
        require(!(bytes1(storage_map_i[var_a])), "Reported");
        require(!0, "Duplicate");
        require(!(0 < 0x01), "Duplicate");
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff < (arg0), "Duplicate");
        require(0 < (arg0), "Duplicate");
        require((0 + (0 + (arg0 + 0x20))) > (0 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff80 + (arg0 + 0x20))), "Duplicate");
        require(0 < (arg0), "Duplicate");
        require(!(0 > (~(0x60 + (0 + (arg0 + 0x20))))), "Duplicate");
        require(0x01, "Duplicate");
        return 0;
    }
    
    /// @custom:selector    0x61cd11e1
    /// @custom:signature   Unresolved_61cd11e1(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_61cd11e1(uint256 arg0) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return storage_map_j[var_e];
    }
    
    /// @custom:selector    0x80ca2193
    /// @custom:signature   Unresolved_80ca2193() public returns (address)
    function Unresolved_80ca2193() public returns (address) {
        (bool success, bytes memory ret0) = address(universe).saveETHRegistry(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == (address(var_b.length)));
        return address(var_b.length);
    }
    
    /// @custom:selector    0x7ec2e278
    /// @custom:signature   Unresolved_7ec2e278(address arg0, uint256 arg1) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_7ec2e278(address arg0, uint256 arg1) public {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        (bool success, bytes memory ret0) = address(universe / 0x01).accessControls(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == (address(var_b.length)));
        address var_d = msg.sender;
        (bool success, bytes memory ret0) = address(var_b.length).Unresolved_956c1ca5(var_d); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!(((var_b + ret0.length) - var_b) < 0x20), "Only manager");
        require(var_b.length == var_b.length, "Only manager");
        require(var_b.length, "Only manager");
        address var_i = address(arg0);
        storage_map_m[var_i] = arg1 | (uint248(storage_map_m[var_i]));
        emit Event_22c8ccdb(address(arg0), arg1);
    }
    
    /// @custom:selector    0xa4850c03
    /// @custom:signature   Unresolved_a4850c03(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_a4850c03(uint256 arg0) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!storage_map_i[var_a] < 0x01bc16d674ec800000);
        return storage_map_i[var_a] - 0x01bc16d674ec800000;
    }
    
    /// @custom:selector    0x4a1a8df6
    /// @custom:signature   Unresolved_4a1a8df6(uint256 arg0, uint256 arg1, uint256 arg2) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_4a1a8df6(uint256 arg0, uint256 arg1, uint256 arg2) public {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        (bool success, bytes memory ret0) = address(universe / 0x01).accessControls(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == (address(var_b.length)));
        address var_d = msg.sender;
        (bool success, bytes memory ret0) = address(var_b.length).Unresolved_18dc0325(var_d); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!(((var_b + ret0.length) - var_b) < 0x20), "Only core");
        require(var_b.length == var_b.length, "Only core");
        require(var_b.length, "Only core");
        require(!(arg1 < 0x01bc16d674ec800000), "Smaller not possible");
        var_i = msg.data[36:36];
        require(!(arg1 < storage_map_m[var_i]), "Smaller not possible");
        uint256 var_j = arg2;
        require(!(bytes1(storage_map_n[var_j])), "Sweep already reported");
        var_i = msg.data[36:36];
        storage_map_m[var_i] = arg1;
        var_j = arg2;
        storage_map_n[var_j] = 0x01 | (uint248(storage_map_n[var_j]));
    }
    
    /// @custom:selector    0x556b7541
    /// @custom:signature   Unresolved_556b7541(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["uint64", "bytes8", "int64"]
    /// @param              arg7 ["uint64", "bytes8", "int64"]
    /// @param              arg8 ["uint64", "bytes8", "int64"]
    function Unresolved_556b7541(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public {
        require(!arg0 > 0xffffffffffffffff);
        require(!(msg.data.length - 0x24) < 0x80);
        require(!arg5 > 0xffffffffffffffff);
        require((0x60 + (arg0)) > 0);
        require(arg1 > block.number);
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(arg5 + (arg5)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(keccak256(var_a) == keccak256(var_a), "Key mismatch");
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(arg0 + (0x80 + (arg0))) > 0xffffffffffffffff);
        require(!0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(!(((0x40 + (0 + (0x20 + ((0x04 + arg0) + (0x80 + (arg0)))))) + 0x20) - (0x40 + (0 + (0x20 + ((0x04 + arg0) + (0x80 + (arg0))))))) < 0x20);
        require((0x40 + (0 + (0x20 + (arg0 + (0x80 + (arg0)))))) == (address(0x40 + (0 + (0x20 + (arg0 + (0x80 + (arg0))))))));
        require(0 < (arg0 + (0x80 + (arg0))));
        uint256 var_j = 0x80 + (0x20 + var_j);
        var_j = 0x60 + (0x80 + (0x20 + var_j));
        require(0x01);
        require(!(arg0 + (arg0 + 0x80)) > 0xffffffffffffffff);
        require(0 < (arg0 + (arg0 + 0x80)));
        require(!(arg5 + (arg5)) > 0xffffffffffffffff);
        require(!(arg5 + (arg5 + 0x20)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!(((0x40 + (0x04 + arg5)) + 0x20) - (0x40 + (0x04 + arg5))) < 0x20);
        require((0x40 + (arg5)) == (0x40 + (arg5)));
        require(!(((0x04 + arg5) + 0x80) - ((0x04 + arg5) + 0x60)) < 0x20);
        require((arg5 + 0x60) == (uint64(arg5 + 0x60)));
        require(!(((0x04 + arg5) + 0xa0) - ((0x04 + arg5) + 0x80)) < 0x20);
        require((arg5 + 0x80) == (uint64(arg5 + 0x80)));
        require(!(((0x04 + arg5) + 0xc0) - ((0x04 + arg5) + 0xa0)) < 0x20);
        require((arg5 + 0xa0) == (uint64(arg5 + 0xa0)));
        require(!(((0x04 + arg5) + 0xe0) - ((0x04 + arg5) + 0xc0)) < 0x20);
        require((arg5 + 0xc0) == (uint64(arg5 + 0xc0)));
        require(!(((0x04 + arg5) + 0x0100) - ((0x04 + arg5) + 0xe0)) < 0x20);
        require((arg5 + 0xe0) == (uint64(arg5 + 0xe0)));
        require(!(((0x04 + arg5) + 0x0120) - ((0x04 + arg5) + 0x0100)) < 0x20);
        require((arg5 + 0x0100) == (uint64(arg5 + 0x0100)));
        var_j = 0x0180 + var_j;
        var_j = 0x0100 + var_j;
        var_j = 0xc0 + var_j;
        require(!0x20 < 0x20);
        require(arg2 == (bytes1(arg2)));
        require(!(arg4 > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0), "Invalid Report");
        require(!(0x03 > 0x04), "Invalid Report");
        require(0x03, "Invalid Report");
        uint256 var_o = 0;
        var_am = 0xcc;
        require(bytes1(storage_map_c[var_o]), "Invalid Report");
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x02, "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature length");
        require(0x01, "ECDSA: invalid signature length");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0, "ECDSA: invalid signature 'v' value");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "ECDSA: invalid signature 'v' value");
        require(0x1b == (bytes1(arg2)));
        require(0x1b == (bytes1(arg2)));
        require(var_am);
        if (address(var_ax)) {
        }
    }
    
    /// @custom:selector    0x690b4c40
    /// @custom:signature   Unresolved_690b4c40(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_690b4c40(uint256 arg0, uint256 arg1) public {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(store_o - 0x02, "ReentrancyGuard: reentrant call");
        store_o = 0x02;
        (bool success, bytes memory ret0) = address(universe).saveETHRegistry(); // staticcall
        uint256 var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(var_e.length == (address(var_e.length)));
        (bool success, bytes memory ret0) = address(universe).accountManager(); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(var_e.length == (address(var_e.length)));
        var_g = msg.data[36:36];
        require(!storage_map_p[var_g] < arg1);
        storage_map_p[var_g] = storage_map_p[var_g] - arg1;
        var_d = 0x60;
        uint256 var_m = 0;
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_m ether }Unresolved_f2556a85(var_d); // call
        address var_d = msg.sender;
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_m ether }Unresolved_4782f779(var_d); // call
        store_o = 0x01;
    }
    
    /// @custom:selector    0x0626f5ac
    /// @custom:signature   Unresolved_0626f5ac(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["uint64", "bytes8", "int64"]
    /// @param              arg7 ["uint64", "bytes8", "int64"]
    /// @param              arg8 ["uint64", "bytes8", "int64"]
    function Unresolved_0626f5ac(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public returns (bool) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(msg.data.length - 0x24) < 0x80);
        require(!arg5 > 0xffffffffffffffff);
        require(!(arg0 + (arg0 + 0x20)) > 0xffffffffffffffff);
        require(!(arg0 + (0x80 + (arg0))) > 0xffffffffffffffff);
        require(!0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(0 < (arg0 + (0x80 + (arg0))));
        require(!(((0x40 + (0 + (0x20 + ((0x04 + arg0) + (0x80 + (arg0)))))) + 0x20) - (0x40 + (0 + (0x20 + ((0x04 + arg0) + (0x80 + (arg0))))))) < 0x20);
        require((0x40 + (0 + (0x20 + (arg0 + (0x80 + (arg0)))))) == (address(0x40 + (0 + (0x20 + (arg0 + (0x80 + (arg0))))))));
        require(0 < (arg0 + (0x80 + (arg0))));
        uint256 var_g = 0x80 + (0x20 + var_g);
        var_g = 0x60 + (0x80 + (0x20 + var_g));
        require(0x01);
        require(!(arg0 + (arg0 + 0x80)) > 0xffffffffffffffff);
        require(0 < (arg0 + (arg0 + 0x80)));
        require(!(arg5 + (arg5)) > 0xffffffffffffffff);
        require(!(arg5 + (arg5 + 0x20)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!(((0x40 + (0x04 + arg5)) + 0x20) - (0x40 + (0x04 + arg5))) < 0x20);
        require((0x40 + (arg5)) == (0x40 + (arg5)));
        require(!(((0x04 + arg5) + 0x80) - ((0x04 + arg5) + 0x60)) < 0x20);
        require((arg5 + 0x60) == (uint64(arg5 + 0x60)));
        require(!(((0x04 + arg5) + 0xa0) - ((0x04 + arg5) + 0x80)) < 0x20);
        require((arg5 + 0x80) == (uint64(arg5 + 0x80)));
        require(!(((0x04 + arg5) + 0xc0) - ((0x04 + arg5) + 0xa0)) < 0x20);
        require((arg5 + 0xa0) == (uint64(arg5 + 0xa0)));
        require(!(((0x04 + arg5) + 0xe0) - ((0x04 + arg5) + 0xc0)) < 0x20);
        require((arg5 + 0xc0) == (uint64(arg5 + 0xc0)));
        require(!(((0x04 + arg5) + 0x0100) - ((0x04 + arg5) + 0xe0)) < 0x20);
        require((arg5 + 0xe0) == (uint64(arg5 + 0xe0)));
        require(!(((0x04 + arg5) + 0x0120) - ((0x04 + arg5) + 0x0100)) < 0x20);
        require((arg5 + 0x0100) == (uint64(arg5 + 0x0100)));
        var_g = 0x0180 + var_g;
        var_g = 0x0100 + var_g;
        var_g = 0xc0 + var_g;
        require(!0x20 < 0x20);
        require(arg2 == (bytes1(arg2)));
        require(!(arg4 > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0), "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x03, "ECDSA: invalid signature");
        uint256 var_l = 0;
        return !(!bytes1(storage_map_q[var_l]));
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x02, "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature length");
        require(0x01, "ECDSA: invalid signature length");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0, "ECDSA: invalid signature 'v' value");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "ECDSA: invalid signature 'v' value");
        var_l = 0;
        var_aj = 0xcc;
        return !(!bytes1(storage_map_q[var_l]));
        require(0x1b == (bytes1(arg2)));
        require(0x1b == (bytes1(arg2)));
        require(var_aj);
        if (address(var_au)) {
        }
    }
    
    /// @custom:selector    0xa9956aef
    /// @custom:signature   Unresolved_a9956aef() public returns (address)
    function Unresolved_a9956aef() public returns (address) {
        (bool success, bytes memory ret0) = address(universe).accountManager(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == (address(var_b.length)));
        return address(var_b.length);
    }
    
    /// @custom:selector    0xb6797489
    /// @custom:signature   Unresolved_b6797489(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint64 arg4, uint64 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint64", "bytes8", "int64"]
    /// @param              arg4 ["uint64", "bytes8", "int64"]
    /// @param              arg5 ["uint64", "bytes8", "int64"]
    /// @param              arg6 ["uint64", "bytes8", "int64"]
    /// @param              arg7 ["uint64", "bytes8", "int64"]
    /// @param              arg8 ["uint64", "bytes8", "int64"]
    function Unresolved_b6797489(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint64 arg4, uint64 arg5, uint64 arg6, uint64 arg7, uint64 arg8) public pure returns (uint256) {
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 + (arg1)) > 0xffffffffffffffff);
        require(!(arg1 + (arg1 + 0x20)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!(((0x40 + (0x04 + arg1)) + 0x20) - (0x40 + (0x04 + arg1))) < 0x20);
        require((0x40 + (arg1)) == (0x40 + (arg1)));
        require(!(((0x04 + arg1) + 0x80) - ((0x04 + arg1) + 0x60)) < 0x20);
        require((arg1 + 0x60) == (uint64(arg1 + 0x60)));
        require(!(((0x04 + arg1) + 0xa0) - ((0x04 + arg1) + 0x80)) < 0x20);
        require((arg1 + 0x80) == (uint64(arg1 + 0x80)));
        require(!(((0x04 + arg1) + 0xc0) - ((0x04 + arg1) + 0xa0)) < 0x20);
        require((arg1 + 0xa0) == (uint64(arg1 + 0xa0)));
        require(!(((0x04 + arg1) + 0xe0) - ((0x04 + arg1) + 0xc0)) < 0x20);
        require((arg1 + 0xc0) == (uint64(arg1 + 0xc0)));
        require(!(((0x04 + arg1) + 0x0100) - ((0x04 + arg1) + 0xe0)) < 0x20);
        require((arg1 + 0xe0) == (uint64(arg1 + 0xe0)));
        require(!(((0x04 + arg1) + 0x0120) - ((0x04 + arg1) + 0x0100)) < 0x20);
        require((arg1 + 0x0100) == (uint64(arg1 + 0x0100)));
        return keccak256(var_p);
    }
    
    /// @custom:selector    0x04c32fd2
    /// @custom:signature   Unresolved_04c32fd2(uint256 arg0, uint256 arg1, uint256 arg2) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_04c32fd2(uint256 arg0, uint256 arg1, uint256 arg2) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(!arg2 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x86421457
    /// @custom:signature   Unresolved_86421457(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_86421457(uint256 arg0) public view returns (bool) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return !(!bytes1(storage_map_j[var_e]));
    }
}