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
    uint256 public constant unresolved_d74f8edd = 50;
    
    bytes32 store_d;
    mapping(bytes32 => bytes32) storage_map_f;
    address store_k;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    bytes32 store_m;
    bytes32 store_n;
    mapping(bytes32 => bytes32) storage_map_j;
    uint248 store_c;
    mapping(bytes32 => bytes32) storage_map_b;
    uint256 public unresolved_dc8452cd;
    bytes32 store_l;
    uint256 public unresolved_b77bf600;
    uint256 public unresolved_5bebd9d7;
    
    event Event_f39e6e1e();
    event Event_a3f1ee91();
    event Event_526441bb();
    event Event_4a504a94();
    event Event_8001553a();
    event Event_f6a31715();
    event Event_c0ba8fe4();
    event Event_33e13ecb();
    
    /// @custom:selector    0xc01a8c84
    /// @custom:signature   Unresolved_c01a8c84(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_c01a8c84(uint256 arg0) public payable {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20, "Confirmed transaction.");
        address var_a = msg.sender;
        require(!(bytes1(storage_map_a[var_a])), "Confirmed transaction.");
        var_a = arg0;
        require(!(address(storage_map_a[var_a])), "Confirmed transaction.");
        var_a = msg.sender;
        require(bytes1(storage_map_a[var_a]), "Confirmed transaction.");
        var_a = msg.sender;
        storage_map_a[var_a] = (uint248(storage_map_a[var_a])) | 0x01;
        emit Event_4a504a94(msg.sender, arg0);
        var_a = arg0;
        require(bytes1(storage_map_b[var_a]), "Executed transaction.");
        require(0 < store_c, "Existed transaction id.");
        require(!(0 < store_c), "Existed transaction id.");
        var_a = address(store_d >> 0);
        require(bytes1(storage_map_a[var_a]), "Existed transaction id.");
        require(0 == unresolved_dc8452cd, "Existed transaction id.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Existed transaction id.");
        require(0x01, "Existed transaction id.");
        var_a = arg0;
        storage_map_b[var_a] = (uint248(storage_map_b[var_a])) | 0x01;
        require(!(bytes1(storage_map_f[var_a])), "Existed transaction id.");
        require(((storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0 == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
        require(0x01 == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
        var_a = keccak256(var_a) + 0x02;
        require(0 < (storage_map_f[var_a] >> 0x01), "Existed transaction id.");
        (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
        require(!ret0.length, "Existed transaction id.");
        emit Event_526441bb(arg0);
        storage_map_b[var_a] = uint248(storage_map_b[var_a]);
        emit Event_33e13ecb(arg0);
        require(ret0.length > 0xffffffffffffffff, "Existed transaction id.");
        require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h), "Existed transaction id.");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
        require(!ret0.length, "Existed transaction id.");
        require(ret0.length > 0xffffffffffffffff, "Existed transaction id.");
        require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h), "Existed transaction id.");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
        require(!ret0.length, "Existed transaction id.");
        require(ret0.length > 0xffffffffffffffff, "Existed transaction id.");
        require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h), "Existed transaction id.");
        require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Existed transaction id.");
        require(0x01 == unresolved_dc8452cd, "Existed transaction id.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Existed transaction id.");
        require(0, "Existed transaction id.");
    }
    
    /// @custom:selector    0xb5dc40c3
    /// @custom:signature   Unresolved_b5dc40c3(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_b5dc40c3(uint256 arg0) public view returns (bytes memory) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20);
        require(store_c > 0xffffffffffffffff);
        require(((var_c + (uint248((0x20 + (store_c << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + (store_c << 0x05)) + 0x1f))) < var_c));
        uint248 var_c = var_c + (uint248((0x20 + (store_c << 0x05)) + 0x1f));
        require(store_c > 0xffffffffffffffff);
        require(0 < store_c);
        require(!0 < store_c);
        var_a = address(store_d >> 0);
        require(bytes1(storage_map_a[var_a]));
        require(!0 < store_c);
        require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        require(0 > 0xffffffffffffffff);
        require(((var_c + 0x20) > 0xffffffffffffffff) | ((var_c + 0x20) < var_c));
        var_c = var_c + 0x20;
        require(0 > 0xffffffffffffffff);
        require(0 < 0);
        return abi.encodePacked(0x20, var_c.length);
    }
    
    /// @custom:selector    0xa8abe69a
    /// @custom:signature   Unresolved_a8abe69a(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_a8abe69a(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view returns (bytes memory) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x80);
        require(arg2 - arg2);
        require(arg3 - arg3);
        if (unresolved_b77bf600 > 0xffffffffffffffff) {
            if (((var_c + (uint248((0x20 + (unresolved_b77bf600 << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + (unresolved_b77bf600 << 0x05)) + 0x1f))) < var_c)) {
                uint248 var_c = var_c + (uint248((0x20 + (unresolved_b77bf600 << 0x05)) + 0x1f));
                require(unresolved_b77bf600 > 0xffffffffffffffff);
                require(((var_c + (uint248((0x20 + (unresolved_b77bf600 << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + (unresolved_b77bf600 << 0x05)) + 0x1f))) < var_c));
                require(unresolved_b77bf600 > 0xffffffffffffffff);
                require(0 < unresolved_b77bf600);
                require(arg2);
                var_a = 0;
                require(bytes1(storage_map_b[var_a]));
                require(!arg3);
                var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
                require(bytes1(storage_map_b[var_a]));
                require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
            }
            require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        require(arg1 < arg0);
        require((arg1 - arg0) > 0xffffffffffffffff);
        require(((var_c + (uint248((0x20 + ((arg1 - arg0) << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + ((arg1 - arg0) << 0x05)) + 0x1f))) < var_c));
        var_c = var_c + (uint248((0x20 + ((arg1 - arg0) << 0x05)) + 0x1f));
        require((arg1 - arg0) > 0xffffffffffffffff);
        require(arg0 < arg1);
        require(arg0 < arg0);
        require(!(arg0 - arg0) < var_c.length);
        require(arg0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        return abi.encodePacked(0x20, var_c.length);
    }
    
    /// @custom:selector    0x14fb0530
    /// @custom:signature   Unresolved_14fb0530(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_14fb0530(uint256 arg0, uint256 arg1) public view returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        var_a = arg1;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x9ace38c2
    /// @custom:signature   Unresolved_9ace38c2(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_9ace38c2(uint256 arg0) public view returns (bool) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20);
        uint256 var_a = arg0;
        require(!bytes1(storage_map_f[var_a]));
        require(((storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0 == (bytes1(storage_map_f[var_a])));
        require(0x01 == (bytes1(storage_map_f[var_a])));
        var_a = keccak256(var_a) + 0x02;
        require(0 < (storage_map_f[var_a] >> 0x01));
        require(((var_e + (uint248((((var_e + 0) + 0x20) - var_e) + 0x1f))) > 0xffffffffffffffff) | ((var_e + (uint248((((var_e + 0) + 0x20) - var_e) + 0x1f))) < var_e));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint248 var_e = var_e + (uint248((((var_e + 0) + 0x20) - var_e) + 0x1f));
        require(0 > var_e.length);
        return abi.encodePacked(address(storage_map_a[var_a]), storage_map_g[var_a], 0x80, !(!bytes1(storage_map_b[var_a])), var_e.length);
        return abi.encodePacked(address(storage_map_a[var_a]), storage_map_g[var_a], 0x80, !(!bytes1(storage_map_b[var_a])), var_e.length);
        require(((var_e + (uint248((0 - var_e) + 0x1f))) > 0xffffffffffffffff) | ((var_e + (uint248((0 - var_e) + 0x1f))) < var_e));
    }
    
    /// @custom:selector    0x2f54bf6e
    /// @custom:signature   Unresolved_2f54bf6e(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2f54bf6e(address arg0) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(arg0 - (address(arg0)));
        address var_a = address(arg0);
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x54741525
    /// @custom:signature   Unresolved_54741525(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_54741525(uint256 arg0, uint256 arg1) public view returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        require(arg0 - arg0);
        require(arg1 - arg1);
        if (0 < unresolved_b77bf600) {
            if (arg0) {
                require(0 < unresolved_b77bf600);
                require(arg0);
                var_a = 0;
                require(bytes1(storage_map_b[var_a]));
                require(!arg1);
                var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
                require(bytes1(storage_map_b[var_a]));
                require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
            }
            require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        return 0;
    }
    
    /// @custom:selector    0xee22610b
    /// @custom:signature   Unresolved_ee22610b(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_ee22610b(uint256 arg0) public payable {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20, "Executed transaction.");
        uint256 var_a = arg0;
        require(bytes1(storage_map_b[var_a]), "Executed transaction.");
        if (0 < store_c) {
            require(0 < store_c);
            var_a = address(store_d >> 0);
            require(!0 < store_c);
            require(bytes1(storage_map_a[var_a]));
            require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
            require(0x01 == unresolved_dc8452cd);
            var_a = arg0;
            storage_map_b[var_a] = (uint248(storage_map_b[var_a])) | 0x01;
            require(0x01);
            require(!bytes1(storage_map_f[var_a]));
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(((storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])));
            require(0 == (bytes1(storage_map_f[var_a])));
            var_a = keccak256(var_a) + 0x02;
            require(0x01 == (bytes1(storage_map_f[var_a])));
            (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
            require(0 < (storage_map_f[var_a] >> 0x01));
            emit Event_526441bb(arg0);
            storage_map_b[var_a] = uint248(storage_map_b[var_a]);
            emit Event_33e13ecb(arg0);
            require(!ret0.length);
            require(ret0.length > 0xffffffffffffffff);
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
            require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h));
            require(!ret0.length);
            require(ret0.length > 0xffffffffffffffff);
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
            require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h));
            require(!ret0.length);
            require(ret0.length > 0xffffffffffffffff);
            require(((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) > 0xffffffffffffffff) | ((var_h + (uint248((0x20 + (0x1f + ret0.length)) + 0x1f))) < var_h));
            require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
        require(0);
    }
    
    /// @custom:selector    0xdcfc4699
    /// @custom:signature   Unresolved_dcfc4699(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_dcfc4699(uint256 arg0, uint256 arg1) public view returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        var_a = arg1;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x8b51d13f
    /// @custom:signature   Unresolved_8b51d13f(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_8b51d13f(uint256 arg0) public view returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20);
        require(0 < store_c);
        require(!0 < store_c);
        var_a = address(store_d >> 0);
        require(bytes1(storage_map_a[var_a]));
        require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        return 0;
    }
    
    /// @custom:selector    0xa0e67e2b
    /// @custom:signature   Unresolved_a0e67e2b() public view returns (bytes memory)
    function Unresolved_a0e67e2b() public view returns (bytes memory) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0);
        if (0 < store_c) {
            if (((var_c + (uint248(((var_c + 0x20) - var_c) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248(((var_c + 0x20) - var_c) + 0x1f))) < var_c)) {
                uint248 var_c = var_c + (uint248(((var_c + 0x20) - var_c) + 0x1f));
                return abi.encodePacked(0x20, var_c.length);
            }
        }
    }
    
    /// @custom:selector    0xd1fdc4c7
    /// @custom:signature   Unresolved_d1fdc4c7(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_d1fdc4c7(uint256 arg0) public view returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0xec096f8d
    /// @custom:signature   Unresolved_ec096f8d(address arg0, uint256 arg1, uint256 arg2) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_ec096f8d(address arg0, uint256 arg1, uint256 arg2) public payable returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x60);
        require(arg0 - (address(arg0)));
        require(arg2 > 0xffffffffffffffff);
        if (!(arg2 + 0x23) < msg.data.length) {
            require(!((arg2 + 0x23) < msg.data.length), "Address is null");
            require(arg2 > 0xffffffffffffffff, "Address is null");
            uint256 var_c = var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f));
            require(((var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f))) < var_c), "Address is null");
            var_e = msg.data[36:36];
            require(((arg2 + (arg2)) + 0x24) > msg.data.length, "Address is null");
            require(!(address(arg0)), "Address is null");
            var_c = var_c + 0x80;
            var_a = unresolved_b77bf600;
            storage_map_a[var_a] = (uint96(storage_map_a[var_a])) | (address(var_c.length));
            storage_map_g[var_a] = var_e;
            require(((var_c + 0x80) > 0xffffffffffffffff) | ((var_c + 0x80) < var_c), "Address is null");
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(var_k > 0xffffffffffffffff, "Address is null");
            require(!(bytes1(storage_map_f[var_a])), "Address is null");
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(((storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])), "Address is null");
            uint256 var_a = keccak256(var_a) + 0x02;
            require((storage_map_f[var_a] >> 0x01) > 0x1f, "Address is null");
            require(var_k < 0x20, "Address is null");
            require(keccak256(var_a) + ((var_k + 0x1f) >> 0x05) < (((0x1f + (storage_map_f[var_a] >> 0x01)) >> 0x05) + keccak256(var_a)), "Address is null");
            var_a = keccak256(var_a) + 0x02;
            require(0x01 == (var_k > 0x1f), "Address is null");
            require(0 < (uint248(var_k)), "Address is null");
            storage_map_a[var_a] = (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (bytes1(var_k << 0x03)))) & (var_l);
            storage_map_f[var_a] = (var_k << 0x01) + 0x01;
            storage_map_b[var_a] = (bytes1(var_m)) | (uint248(storage_map_b[var_a]));
            require(uint248(var_k) < (var_k), "Address is null");
            unresolved_b77bf600 = unresolved_b77bf600 + 0x01;
            emit Event_c0ba8fe4(unresolved_b77bf600);
            return unresolved_b77bf600;
            require(unresolved_b77bf600 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Address is null");
        }
    }
    
    /// @custom:selector    0x9672d576
    /// @custom:signature   Unresolved_9672d576(uint256 arg0, uint256 arg1) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_9672d576(uint256 arg0, uint256 arg1) public view returns (address) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        var_a = arg1;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x6f18879a
    /// @custom:signature   Unresolved_6f18879a(uint256 arg0) public payable returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_6f18879a(uint256 arg0) public payable returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20, "Validated hash.");
        uint256 var_a = arg0;
        require(!(!bytes1(storage_map_a[var_a])), "Validated hash.");
        var_a = arg0;
        require(!0 < storage_map_a[var_a]);
        var_a = 0;
        var_a = address(storage_map_a[var_a]);
        require(bytes1(storage_map_a[var_a]));
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        require(!unresolved_dc8452cd > 0);
        var_a = arg0;
        return !(!bytes1(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = 0x01 | (uint248(storage_map_a[var_a]));
        var_a = arg0;
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x72f22493
    /// @custom:signature   Unresolved_72f22493(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_72f22493(uint256 arg0) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        uint256 var_a = arg0;
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x7065cb48
    /// @custom:signature   Unresolved_7065cb48(address arg0) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_7065cb48(address arg0) public payable returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(arg0 - (address(arg0)));
        require(msg.sender - address(this), "Unauthorized.");
        address var_e = address(arg0);
        require(bytes1(storage_map_j[var_e]), "Unauthorized.");
        require(!(address(arg0)), "Invalid requirement");
        require(store_c > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Invalid requirement");
        require(!((0x01 + store_c) > 0x32), "Invalid requirement");
        require(!((0x01 + store_c) > 0x32), "Invalid requirement");
        require(!((0x01 + store_c) > 0x32), "Invalid requirement");
        require((0x01 + store_c) > 0x32, "Invalid requirement");
        var_e = address(arg0);
        storage_map_j[var_e] = (uint248(storage_map_j[var_e])) | 0x01;
        require(!(store_c < 0x010000000000000000), "Invalid requirement");
        store_c = store_c + 0x01;
        require(!(store_c < store_c), "Invalid requirement");
        store_k = (uint96(store_k)) | (address(arg0 << 0));
        emit Event_f39e6e1e(address(arg0));
        return ;
        require(unresolved_dc8452cd, "Invalid requirement");
        require(!unresolved_dc8452cd, "Invalid requirement");
    }
    
    /// @custom:selector    0xa322da5a
    /// @custom:signature   Unresolved_a322da5a(address arg0, uint256 arg1, bool arg2, uint256 arg3, uint256 arg4) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_a322da5a(address arg0, uint256 arg1, bool arg2, uint256 arg3, uint256 arg4) public payable returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0xa0);
        require(arg0 - (address(arg0)));
        require(arg2 - (bytes1(arg2)));
        address var_a = address(arg0);
        require(!(bytes1(storage_map_a[var_a])), "Validated hash.");
        var_a = arg1;
        var_b = 0x06;
        require(!(!bytes1(storage_map_a[var_a])), "Validated hash.");
        address var_a = ecrecover(arg1, bytes1(arg2), arg3, arg4);
        require(!var_b);
        require(address(var_a) - (address(arg0)), "Validation signature mismatch.");
        var_a = arg1;
        require(!(0 < storage_map_a[var_a]), "Transaction already verified by this validator.");
        var_a = 0;
        require(address(storage_map_a[var_a]) == (address(arg0)), "Transaction already verified by this validator.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Transaction already verified by this validator.");
        var_a = arg1;
        require(!storage_map_a[var_a], "Validated hash.");
        var_a = arg1;
        require(storage_map_a[var_a] > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Validated hash.");
        var_a = arg1;
        storage_map_a[var_a] = storage_map_a[var_a] + 0x01;
        var_a = storage_map_a[var_a];
        storage_map_a[var_a] = (uint248(storage_map_a[var_a])) | (bytes1(arg2));
        var_a = storage_map_a[var_a];
        storage_map_a[var_a] = arg3;
        var_a = storage_map_a[var_a];
        storage_map_a[var_a] = arg4;
        var_a = storage_map_a[var_a];
        storage_map_a[var_a] = (uint96(storage_map_a[var_a])) | (address(arg0));
        var_a = arg1;
        require(!(!bytes1(storage_map_a[var_a])), "Validated hash.");
        var_a = arg1;
        require(!(0 < storage_map_a[var_a]), "Unauthorized.");
        require(!(unresolved_dc8452cd > 0), "Unauthorized.");
        var_a = arg1;
        return !(!bytes1(storage_map_a[var_a]));
        var_a = arg1;
        storage_map_a[var_a] = 0x01 | (uint248(storage_map_a[var_a]));
        var_a = arg1;
        return !(!bytes1(storage_map_a[var_a]));
        var_a = 0;
        var_a = address(storage_map_a[var_a]);
        require(bytes1(storage_map_a[var_a]), "Unauthorized.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Unauthorized.");
        var_a = unresolved_5bebd9d7;
        storage_map_a[var_a] = arg1;
        require(unresolved_5bebd9d7 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Unauthorized.");
    }
    
    /// @custom:selector    0x784547a7
    /// @custom:signature   Unresolved_784547a7(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_784547a7(uint256 arg0) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(0 < store_c);
        require(!0 < store_c);
        var_a = address(store_d >> 0);
        require(bytes1(storage_map_a[var_a]));
        require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe);
        require(0x01 == unresolved_dc8452cd);
        return 0x01;
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        require(0 == unresolved_dc8452cd);
        return 0x01;
        return 0;
    }
    
    /// @custom:selector    0x20ea8d86
    /// @custom:signature   Unresolved_20ea8d86(uint256 arg0) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_20ea8d86(uint256 arg0) public payable returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20, "Executed transaction.");
        address var_a = msg.sender;
        require(!(bytes1(storage_map_a[var_a])), "Executed transaction.");
        var_a = msg.sender;
        require(!(bytes1(storage_map_a[var_a])), "Executed transaction.");
        var_a = arg0;
        require(bytes1(storage_map_b[var_a]), "Executed transaction.");
        var_a = msg.sender;
        storage_map_a[var_a] = uint248(storage_map_a[var_a]);
        emit Event_f6a31715(msg.sender, arg0);
        return ;
    }
    
    /// @custom:selector    0x025e7c27
    /// @custom:signature   Unresolved_025e7c27(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_025e7c27(uint256 arg0) public view returns (address) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        require(!arg0 < store_c);
        return address(store_l);
    }
    
    /// @custom:selector    0xe20056e6
    /// @custom:signature   Unresolved_e20056e6(address arg0, address arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_e20056e6(address arg0, address arg1) public payable returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        require(arg0 - (address(arg0)));
        require(arg1 - (address(arg1)));
        require(msg.sender - address(this), "Unauthorized.");
        address var_e = address(arg0);
        require(!(bytes1(storage_map_j[var_e])), "Unauthorized.");
        var_e = address(arg1);
        require(bytes1(storage_map_j[var_e]), "Unauthorized.");
        require(!(address(arg1)), "Address is null");
        require(!(0 < store_c), "Address is null");
        require(!(0 < store_c), "Address is null");
        require(address(store_m >> 0) == (address(arg0)), "Address is null");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Address is null");
        var_e = address(arg0);
        storage_map_j[var_e] = uint248(storage_map_j[var_e]);
        var_e = address(arg1);
        storage_map_j[var_e] = (uint248(storage_map_j[var_e])) | 0x01;
        emit Event_8001553a(address(arg0));
        emit Event_f39e6e1e(address(arg1));
        return ;
    }
    
    /// @custom:selector    0xba51a6df
    /// @custom:signature   Unresolved_ba51a6df(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_ba51a6df(uint256 arg0) public payable {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20, "Unauthorized.");
        require(msg.sender - address(this), "Unauthorized.");
        require(!(store_c > 0x32), "Invalid requirement");
        require(!(store_c > 0x32), "Invalid requirement");
        require(!(store_c > 0x32), "Invalid requirement");
        require(store_c > 0x32, "Invalid requirement");
        unresolved_dc8452cd = arg0;
        emit Event_a3f1ee91(arg0);
        require(!store_c, "Invalid requirement");
        unresolved_dc8452cd = arg0;
        emit Event_a3f1ee91(arg0);
        if (arg0) {
        }
    }
    
    /// @custom:selector    0x88687117
    /// @custom:signature   Unresolved_88687117(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_88687117(uint256 arg0) public view returns (uint256) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x528a4124
    /// @custom:signature   Unresolved_528a4124(uint256 arg0, uint256 arg1) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_528a4124(uint256 arg0, uint256 arg1) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        var_a = arg1;
        return bytes1(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x173825d9
    /// @custom:signature   Unresolved_173825d9(address arg0) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_173825d9(address arg0) public payable returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20);
        require(arg0 - (address(arg0)));
        require(msg.sender - address(this), "Unauthorized.");
        address var_e = address(arg0);
        require(!(bytes1(storage_map_j[var_e])), "Invalid requirement");
        var_e = address(arg0);
        storage_map_j[var_e] = uint248(storage_map_j[var_e]);
        require(store_c < 0x01, "Invalid requirement");
        require(!(0 < (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + store_c)), "Invalid requirement");
        require(store_c < 0x01, "Invalid requirement");
        require((store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) > 0xffffffffffffffff, "Invalid requirement");
        require(((var_g + (uint248((0x20 + ((store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_g + (uint248((0x20 + ((store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) << 0x05)) + 0x1f))) < var_g), "Invalid requirement");
        uint248 var_g = var_g + (uint248((0x20 + ((store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) << 0x05)) + 0x1f));
        require((store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) > 0xffffffffffffffff, "Invalid requirement");
        require(0x01, "Invalid requirement");
        require(var_g.length > 0x010000000000000000, "Invalid requirement");
        store_c = var_g.length;
        require(var_g.length < store_c, "Invalid requirement");
        var_e = var_e;
        require((var_e + var_g.length) < (var_e + store_c), "Invalid requirement");
        var_e = var_e;
        require(unresolved_dc8452cd > store_c, "Invalid requirement");
        require(!(store_c > 0x32), "Invalid requirement");
        require(!0, "Invalid requirement");
        require(!0, "Invalid requirement");
        require(0, "Invalid requirement");
        unresolved_dc8452cd = store_c;
        emit Event_a3f1ee91(store_c);
        emit Event_8001553a(address(arg0));
        return ;
        require(!(store_c > 0x32), "Invalid requirement");
        require(!(store_c > 0x32), "Invalid requirement");
        require(store_c > 0x32, "Invalid requirement");
        unresolved_dc8452cd = store_c;
        emit Event_a3f1ee91(store_c);
        emit Event_8001553a(address(arg0));
        return ;
        emit Event_8001553a(address(arg0));
        return ;
        store_n = 0;
        if ((0x01 + (var_e + var_g.length)) < (var_e + store_c)) {
        }
        require(store_c < 0x01, "Unauthorized.");
        require(!(0 < (store_c + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Unauthorized.");
        require(!(0 < store_c), "Unauthorized.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Unauthorized.");
    }
    
    /// @custom:selector    0x9d4cdbe6
    /// @custom:signature   Unresolved_9d4cdbe6(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_9d4cdbe6(uint256 arg0) public view returns (bytes memory) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x20);
        uint256 var_a = arg0;
        require(storage_map_a[var_a] > 0xffffffffffffffff);
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(((var_d + (uint248((0x20 + (storage_map_a[var_a] << 0x05)) + 0x1f))) > 0xffffffffffffffff) | ((var_d + (uint248((0x20 + (storage_map_a[var_a] << 0x05)) + 0x1f))) < var_d));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_d = var_d + (uint248((0x20 + (storage_map_a[var_a] << 0x05)) + 0x1f));
        require(storage_map_a[var_a] > 0xffffffffffffffff);
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0 < storage_map_a[var_a]);
        var_a = 0;
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        return abi.encodePacked(0x20, var_d.length);
    }
    
    /// @custom:selector    0x478c3905
    /// @custom:signature   Unresolved_478c3905(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_478c3905(uint256 arg0) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x20);
        uint256 var_a = arg0;
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xc6427474
    /// @custom:signature   Unresolved_c6427474(address arg0, uint256 arg1, uint256 arg2) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_c6427474(address arg0, uint256 arg1, uint256 arg2) public payable returns (uint256) {
        require(msg.value);
        require((msg.data.length + 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc) < 0x60);
        require(arg0 - (address(arg0)));
        require(arg2 > 0xffffffffffffffff);
        require(!((arg2 + 0x23) < msg.data.length), "Confirmed transaction.");
        require(arg2 > 0xffffffffffffffff, "Confirmed transaction.");
        require(((var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f))) < var_c), "Confirmed transaction.");
        uint256 var_c = var_c + (uint248((0x20 + (0x1f + (arg2))) + 0x1f));
        require(((arg2 + (arg2)) + 0x24) > msg.data.length, "Confirmed transaction.");
        var_e = msg.data[36:36];
        require(!(address(arg0)), "Confirmed transaction.");
        require(((var_c + 0x80) > 0xffffffffffffffff) | ((var_c + 0x80) < var_c), "Confirmed transaction.");
        var_c = var_c + 0x80;
        var_a = unresolved_b77bf600;
        storage_map_a[var_a] = (uint96(storage_map_a[var_a])) | (address(var_c.length));
        storage_map_g[var_a] = var_e;
        require(var_k > 0xffffffffffffffff, "Confirmed transaction.");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(bytes1(storage_map_f[var_a])), "Confirmed transaction.");
        require(((storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])), "Confirmed transaction.");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require((storage_map_f[var_a] >> 0x01) > 0x1f, "Confirmed transaction.");
        uint256 var_a = keccak256(var_a) + 0x02;
        require(var_k < 0x20, "Confirmed transaction.");
        require(keccak256(var_a) + ((var_k + 0x1f) >> 0x05) < (((0x1f + (storage_map_f[var_a] >> 0x01)) >> 0x05) + keccak256(var_a)), "Confirmed transaction.");
        require(0x01 == (var_k > 0x1f), "Confirmed transaction.");
        var_a = keccak256(var_a) + 0x02;
        require(0 < (uint248(var_k)), "Confirmed transaction.");
        require(uint248(var_k) < (var_k), "Confirmed transaction.");
        storage_map_a[var_a] = (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (bytes1(var_k << 0x03)))) & (var_l);
        storage_map_f[var_a] = (var_k << 0x01) + 0x01;
        storage_map_b[var_a] = (bytes1(var_m)) | (uint248(storage_map_b[var_a]));
        require(unresolved_b77bf600 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Confirmed transaction.");
        unresolved_b77bf600 = unresolved_b77bf600 + 0x01;
        emit Event_c0ba8fe4(unresolved_b77bf600);
        var_a = msg.sender;
        require(!(bytes1(storage_map_a[var_a])), "Confirmed transaction.");
        var_a = unresolved_b77bf600;
        require(!(address(storage_map_a[var_a])), "Confirmed transaction.");
        var_a = msg.sender;
        require(bytes1(storage_map_a[var_a]), "Confirmed transaction.");
        var_a = msg.sender;
        storage_map_a[var_a] = (uint248(storage_map_a[var_a])) | 0x01;
        emit Event_4a504a94(msg.sender, unresolved_b77bf600);
        var_a = unresolved_b77bf600;
        require(bytes1(storage_map_b[var_a]), "Executed transaction.");
        if (0 < store_c) {
            if (!0 < store_c) {
                var_a = address(store_d >> 0);
                if (storage_map_a[var_a]) {
                    require(0 < store_c, "Existed transaction id.");
                    require(!(0 < store_c), "Existed transaction id.");
                    var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
                    require(bytes1(storage_map_a[var_a]), "Existed transaction id.");
                    return unresolved_b77bf600;
                    var_a = unresolved_b77bf600;
                    storage_map_b[var_a] = (uint248(storage_map_b[var_a])) | 0x01;
                    require(0 == unresolved_dc8452cd, "Existed transaction id.");
                    require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Existed transaction id.");
                    require(0x01, "Existed transaction id.");
                    (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
                    require(!(bytes1(storage_map_f[var_a])), "Existed transaction id.");
                    emit Event_526441bb(unresolved_b77bf600);
                    storage_map_b[var_a] = uint248(storage_map_b[var_a]);
                    return unresolved_b77bf600;
                    emit Event_33e13ecb(unresolved_b77bf600);
                    return unresolved_b77bf600;
                    require((bytes1(storage_map_f[var_a] >> 0x01) < 0x20) == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
                    (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
                    require(0 == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
                }
                var_a = keccak256(var_a) + 0x02;
                require(0x01 == (bytes1(storage_map_f[var_a])), "Existed transaction id.");
                (bool success, bytes memory ret0) = address(storage_map_a[var_a]).transfer(storage_map_g[var_a]);
                require(0 < (bytes1(storage_map_f[var_a] >> 0x01)), "Existed transaction id.");
            }
        }
        require(0 > 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, "Existed transaction id.");
        require(0x01 == unresolved_dc8452cd, "Existed transaction id.");
        require(0 == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Existed transaction id.");
        require(0, "Existed transaction id.");
        return unresolved_b77bf600;
        if (var_k) {
        }
    }
    
    /// @custom:selector    0x3411c81c
    /// @custom:signature   Unresolved_3411c81c(uint256 arg0, address arg1) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_3411c81c(uint256 arg0, address arg1) public view returns (bool) {
        require(msg.value);
        require((0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc + msg.data.length) < 0x40);
        require(arg1 - (address(arg1)));
        var_a = address(arg1);
        return !(!bytes1(storage_map_a[var_a]));
    }
}