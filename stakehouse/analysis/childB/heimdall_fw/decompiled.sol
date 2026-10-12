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
    address public universe;
    mapping(bytes32 => bytes32) storage_map_d;
    bytes32 store_e;
    address public unresolved_0d9bce21;
    bytes32 store_f;
    bytes32 store_g;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_h;
    address store_i;
    bytes32 store_j;
    mapping(bytes32 => bytes32) storage_map_c;
    
    event Event_22c8ccdb();
    
    /// @custom:selector    0xff31dc1c
    /// @custom:signature   Unresolved_ff31dc1c(uint256 arg0, uint256 arg1) public pure returns (uint256)
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    function Unresolved_ff31dc1c(uint256 arg0, uint256 arg1) public pure returns (uint256) {
        return keccak256(var_g);
    }
    
    /// @custom:selector    0xbed651b7
    /// @custom:signature   Unresolved_bed651b7(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_bed651b7(uint256 arg0) public view returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return storage_map_a[var_e];
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
    
    /// @custom:selector    0x184b9559
    /// @custom:signature   Unresolved_184b9559(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_184b9559(address arg0) public pure {
        require(arg0 == (address(arg0)));
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
        storage_map_c[var_i] = arg1 | (uint248(storage_map_c[var_i]));
        emit Event_22c8ccdb(address(arg0), arg1);
    }
    
    /// @custom:selector    0x22bbe554
    /// @custom:signature   Unresolved_22bbe554(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_22bbe554(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return !(!bytes1(storage_map_d[var_b]));
    }
    
    /// @custom:selector    0xfeef0108
    /// @custom:signature   isFullSweepReported(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function isFullSweepReported(uint256 arg0) public view returns (bool) {
        uint256 var_b = arg0;
        return !(!bytes1(storage_map_d[var_b]));
    }
    
    /// @custom:selector    0x7c1f56bc
    /// @custom:signature   Unresolved_7c1f56bc(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint256 arg4, uint256 arg5) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg7 ["uint64", "bytes8", "int64"]
    /// @param              arg8 ["uint256", "bytes32", "int256"]
    /// @param              arg9 ["uint256", "bytes32", "int256"]
    function Unresolved_7c1f56bc(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint256 arg4, uint256 arg5) public {
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(!arg2 > 0xffffffffffffffff);
        require(!(arg2) > 0xffffffffffffffff);
        require(!(msg.data.length - 0x64) < 0xc0);
        require(!arg9 > 0xffffffffffffffff);
        require(!((msg.data.length - 0x0144) < 0x80), "ReentrancyGuard: reentrant call");
        require(store_e - 0x02, "ReentrancyGuard: reentrant call");
        store_e = 0x02;
        require(arg8 < block.number, "Not in the past");
        require(!(((0x04 + arg9) + 0x0100) - ((0x04 + arg9) + 0xe0)) < 0x20);
        require((arg9 + 0xe0) == (uint64(arg9 + 0xe0)));
        require(uint64(arg9 + 0xe0) - 0xffffffffffffffff, "Withdrawal epoch not set");
    }
    
    /// @custom:selector    0x927cc9b4
    /// @custom:signature   Unresolved_927cc9b4(uint256 arg0, uint256 arg1, address arg2, uint256 arg3) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_927cc9b4(uint256 arg0, uint256 arg1, address arg2, uint256 arg3) public pure returns (uint256) {
        require(!0x20 < 0x20);
        require(arg2 == (address(arg2)));
        return keccak256(var_i);
    }
    
    /// @custom:selector    0x0f823581
    /// @custom:signature   Unresolved_0f823581(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint64 arg4, uint64 arg5, uint64 arg6, uint256 arg7, uint256 arg8, uint256 arg9, bool arg10, uint256 arg11, uint256 arg12) public returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint64", "bytes8", "int64"]
    /// @param              arg4 ["uint64", "bytes8", "int64"]
    /// @param              arg5 ["uint64", "bytes8", "int64"]
    /// @param              arg6 ["uint64", "bytes8", "int64"]
    /// @param              arg7 ["uint256", "bytes32", "int256"]
    /// @param              arg8 ["uint256", "bytes32", "int256"]
    /// @param              arg9 ["uint256", "bytes32", "int256"]
    /// @param              arg10 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg11 ["uint256", "bytes32", "int256"]
    /// @param              arg12 ["uint256", "bytes32", "int256"]
    function Unresolved_0f823581(uint256 arg0, uint256 arg1, uint256 arg2, uint64 arg3, uint64 arg4, uint64 arg5, uint64 arg6, uint256 arg7, uint256 arg8, uint256 arg9, bool arg10, uint256 arg11, uint256 arg12) public returns (bool) {
        require(!(msg.data.length - 0x24) < 0xc0);
        require(!arg7 > 0xffffffffffffffff);
        require(!(arg7) > 0xffffffffffffffff);
        require(!arg8 > 0xffffffffffffffff);
        require(!(msg.data.length - 0x0124) < 0x80);
        require(!(arg8 + (arg8)) > 0xffffffffffffffff);
        require(!(arg8 + (arg8)) > 0xffffffffffffffff);
        require(!(arg8 + (arg8 + 0x20)) > 0xffffffffffffffff);
        var_a = msg.data[36:36];
        require(!(((0x40 + (0x04 + arg8)) + 0x20) - (0x40 + (0x04 + arg8))) < 0x20);
        require((0x40 + (arg8)) == (0x40 + (arg8)));
        require(!(((0x04 + arg8) + 0x80) - ((0x04 + arg8) + 0x60)) < 0x20);
        require((arg8 + 0x60) == (uint64(arg8 + 0x60)));
        require(!(((0x04 + arg8) + 0xa0) - ((0x04 + arg8) + 0x80)) < 0x20);
        require((arg8 + 0x80) == (uint64(arg8 + 0x80)));
        require(!(((0x04 + arg8) + 0xc0) - ((0x04 + arg8) + 0xa0)) < 0x20);
        require((arg8 + 0xa0) == (uint64(arg8 + 0xa0)));
        require(!(((0x04 + arg8) + 0xe0) - ((0x04 + arg8) + 0xc0)) < 0x20);
        require((arg8 + 0xc0) == (uint64(arg8 + 0xc0)));
        require(!(((0x04 + arg8) + 0x0100) - ((0x04 + arg8) + 0xe0)) < 0x20);
        require((arg8 + 0xe0) == (uint64(arg8 + 0xe0)));
        require(!(((0x04 + arg8) + 0x0120) - ((0x04 + arg8) + 0x0100)) < 0x20);
        require((arg8 + 0x0100) == (uint64(arg8 + 0x0100)));
        uint256 var_n = 0x0180 + var_n;
        require(!0x20 < 0x20);
        require(arg3 == (address(arg3)));
        var_n = 0xc0 + var_n;
        var_n = 0x80 + var_n;
        require(!0 < (arg7));
        require(0 < (arg7));
        require(0 < (arg7));
        require(0 < (arg7));
        require(!(((0x40 + (0 + ((0x04 + arg7) + 0x20))) + 0x20) - (0x40 + (0 + ((0x04 + arg7) + 0x20)))) < 0x20);
        require((0x40 + (0 + (arg7 + 0x20))) == (address(0x40 + (0 + (arg7 + 0x20)))));
        require(0 < (arg7));
        var_n = 0x80 + (0x20 + var_n);
        var_n = 0x60 + (0x80 + (0x20 + var_n));
        require(0x01);
        var_n = 0x0120 + var_n;
        var_n = 0xc0 + var_n;
        require(!0x20 < 0x20);
        require(arg10 == (bytes1(arg10)));
        require(!(arg12 > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0), "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x03, "ECDSA: invalid signature");
        uint256 var_ah = 0;
        return !(!bytes1(storage_map_h[var_ah]));
        require(!(0x03 > 0x04), "ECDSA: invalid signature");
        require(0x02, "ECDSA: invalid signature");
        require(!(0x03 > 0x04), "ECDSA: invalid signature length");
        require(0x01, "ECDSA: invalid signature length");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0, "ECDSA: invalid signature 'v' value");
        require(!(0x03 > 0x04), "ECDSA: invalid signature 'v' value");
        require(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "ECDSA: invalid signature 'v' value");
        var_ah = 0;
        var_au = 0xcc;
        return !(!bytes1(storage_map_h[var_ah]));
        require(0x1b == (bytes1(arg10)));
        require(0x1b == (bytes1(arg10)));
        require(var_au);
        if (address(var_bf)) {
        }
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
        require(address(this) - 0xb4d61d73d4f66ad07132fd71b073ba67f67db149, "Function must be called through delegatecall");
        require(address(store_i) == 0xb4d61d73d4f66ad07132fd71b073ba67f67db149);
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
        store_i = (address(arg0)) | (uint96(store_i));
        require(var_c.length > 0, "Address: delegate call to non-contract");
        require(!(var_c.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        require(!0 > var_c.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_o); // delegatecall
        require(ret0.length == 0);
        var_c = 0x60 + var_c;
        require(!var_q);
        require(!(0 > var_c.length), "                                       ");
        require(bytes1(store_j), "Address: delegate call to non-contract");
        store_j = 0x01 | (uint248(store_j));
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        var_c = 0x60 + var_c;
        require(!var_c.length);
        if (!0x01) {
        }
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
    
    /// @custom:selector    0x3659cfe6
    /// @custom:signature   upgradeTo(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function upgradeTo(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(this) - 0xb4d61d73d4f66ad07132fd71b073ba67f67db149, "Function must be called through delegatecall");
        require(address(store_i) == 0xb4d61d73d4f66ad07132fd71b073ba67f67db149);
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
        store_i = (address(arg0)) | (uint96(store_i));
        require(var_f.length > 0, "Address: delegate call to non-contract");
        require(!(var_f.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        require(!0 > var_f.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_m); // delegatecall
        require(ret0.length == 0);
        var_f = 0x60 + var_f;
        require(!var_o);
        require(!(0 > var_f.length), "                                       ");
        require(bytes1(store_j), "Address: delegate call to non-contract");
        store_j = 0x01 | (uint248(store_j));
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        var_f = 0x60 + var_f;
        require(!var_f.length);
    }
}