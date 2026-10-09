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
    bytes public constant unresolved_6a47c80a = ;
    
    mapping(bytes32 => bytes32) storage_map_f;
    mapping(bytes32 => bytes32) storage_map_q;
    bytes32 store_m;
    mapping(bytes32 => bytes32) storage_map_s;
    uint256 public unresolved_8e628636;
    bytes32 storage_map_v[unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff];
    mapping(bytes32 => bytes32) storage_map_ac;
    mapping(bytes32 => bytes32) storage_map_k;
    uint32 public unresolved_1d0a9c61;
    mapping(bytes32 => bytes32) storage_map_b;
    bytes32 store_e;
    uint256 public unresolved_ee28d7a3;
    mapping(bytes32 => bytes32) storage_map_x;
    address public unresolved_fed57875;
    mapping(bytes32 => bytes32) storage_map_n;
    bool public isGlobalLocked;
    address public getManager;
    mapping(bytes32 => bytes32) storage_map_o;
    mapping(bytes32 => bytes32) storage_map_v;
    uint256 public unresolved_b10c4d2a;
    mapping(bytes32 => bytes32) storage_map_h;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_t;
    mapping(bytes32 => bytes32) storage_map_r;
    uint256 public unresolved_5a12c0a5;
    uint16 public unresolved_1c2fef80;
    mapping(bytes32 => bytes32) storage_map_ad;
    uint256 public unresolved_717eced5;
    mapping(bytes32 => bytes32) storage_map_u;
    address public unresolved_42f6b6ce;
    
    event ManagerUpdate(address, address);
    event Event_3c4f2701();
    event Event_d8d7d71f();
    
    /// @custom:selector    0xbf73f5b2
    /// @custom:signature   Unresolved_bf73f5b2(uint256 arg0, address arg1, address arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_bf73f5b2(uint256 arg0, address arg1, address arg2, uint256 arg3) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        var_a = address(arg2);
        storage_map_a[var_a] = arg3 | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xca446dd9
    /// @custom:signature   setAddress(bytes32 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function setAddress(bytes32 arg0, address arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x91686f53
    /// @custom:signature   setCreator(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function setCreator(uint256 arg0, address arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x874047a8
    /// @custom:signature   Unresolved_874047a8(uint248 arg0) public view returns (uint88)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_874047a8(uint248 arg0) public view returns (uint88) {
        uint248 var_a = uint248(arg0);
        return uint88(storage_map_b[var_a] / 0x01000000000000000000000000000000000000000000);
    }
    
    /// @custom:selector    0x8c160095
    /// @custom:signature   deleteInt(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteInt(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = 0;
    }
    
    /// @custom:selector    0x862440e2
    /// @custom:signature   Unresolved_862440e2(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_862440e2(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = keccak256(var_a);
        require(0x1f < (arg1));
        storage_map_a[var_a] = 0x01 + (arg1 + (arg1));
        require(!arg1);
        require(!((arg1 + 0x24) + (arg1)) > (arg1 + 0x24));
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0xcaee2b1a
    /// @custom:signature   Unresolved_caee2b1a(uint248 arg0, uint16 arg1, bool arg2, uint256 arg3, uint96 arg4) public
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    /// @param              arg2 ["bool", "uint8", "bytes1", "int8"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint96", "bytes12", "int96"]
    function Unresolved_caee2b1a(uint248 arg0, uint16 arg1, bool arg2, uint256 arg3, uint96 arg4) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "exist");
        var_a = uint248(arg0);
        require(!(uint32(storage_map_b[var_a] / 0x0100)), "exist");
        require(!(arg3 > 0), "overflow");
        var_a = arg0;
        storage_map_a[var_a] = arg3;
        require(arg4 == (uint96(arg4)), "overflow");
        var_a = var_a;
        uint256 var_g = var_g + 0xa0;
        var_a = arg0;
        storage_map_a[var_a] = (address(uint248(uint240(uint240(storage_map_a[var_a]) | (uint16(var_g.length))) | (0x010000 * (uint16(var_l)))) | (0x0100000000 * (bytes1(var_m))) | (0x010000000000 * (uint96(var_n))))) | (0x010000000000000000000000000000000000 * (uint96(var_o)));
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(address(getManager) == (address(arg0))), "same");
        store_e = (address(arg0)) | (uint96(store_e));
    }
    
    /// @custom:selector    0x39ac0f39
    /// @custom:signature   Unresolved_39ac0f39(uint256 arg0, address arg1, address arg2) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_39ac0f39(uint256 arg0, address arg1, address arg2) public view returns (uint256) {
        var_a = address(arg1);
        var_a = address(arg2);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x1427cb84
    /// @custom:signature   Unresolved_1427cb84(uint256 arg0, address arg1, address arg2, uint256 arg3, uint256 arg4) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_1427cb84(uint256 arg0, address arg1, address arg2, uint256 arg3, uint256 arg4) public {
        address var_a = msg.sender;
        if (uint32(storage_map_a[var_a])) {
            var_c = var_c + (0x20 + (0x20 * (arg3)));
            var_c = var_c + (0x20 + (0x20 * (arg4 )));
            var_g = msg.data[36:36];
            var_a = arg0;
            storage_map_a[var_a] = (uint96(storage_map_a[var_a])) | (address(var_c.length));
            storage_map_f[var_a] = (uint96(storage_map_f[var_a])) | (address(var_g));
            storage_map_g[var_a] = var_m;
            var_a = keccak256(var_a) + 0x02;
            require(uint32(storage_map_a[var_a]));
            require(!var_m);
            require(!((0x20 + (var_n)) + (0x20 * (var_o))) > (0x20 + (var_n)));
            storage_map_a[var_a] = address(storage_map_a[var_a]);
            require(!0);
            require(!0x10);
        }
    }
    
    /// @custom:selector    0x64d4ae28
    /// @custom:signature   Unresolved_64d4ae28(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_64d4ae28(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * (storage_map_h[var_a])));
        if (!storage_map_h[var_a]) {
            var_a = 0x02 + keccak256(var_a);
            if ((var_c + 0x20) + (0x20 * (storage_map_h[var_a])) > (0x20 + (var_c + 0x20))) {
                if (!0 < (var_c.length * 0x20)) {
                    return abi.encodePacked(0x20, var_c.length);
                }
            }
        }
    }
    
    /// @custom:selector    0xcbc1a626
    /// @custom:signature   Unresolved_cbc1a626(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_cbc1a626(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x6c04e3c0
    /// @custom:signature   Unresolved_6c04e3c0(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_6c04e3c0(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        require(!arg1 > storage_map_a[var_a]);
        var_a = arg0;
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
    }
    
    /// @custom:selector    0xe6e21c75
    /// @custom:signature   Unresolved_e6e21c75(uint256 arg0, address arg1, address arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_e6e21c75(uint256 arg0, address arg1, address arg2, uint256 arg3) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        var_a = address(arg2);
        storage_map_a[var_a] = arg3 | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x5dbc33e7
    /// @custom:signature   Unresolved_5dbc33e7(uint256 arg0, address arg1, address arg2) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_5dbc33e7(uint256 arg0, address arg1, address arg2) public view returns (bool) {
        var_a = address(arg1);
        var_a = address(arg2);
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public
    function removeManager() public {
        require(msg.sender == (address(getManager)));
        getManager = uint96(getManager);
        store_e = uint96(store_e);
    }
    
    /// @custom:selector    0xe2b202bf
    /// @custom:signature   deleteUint(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteUint(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = 0;
    }
    
    /// @custom:selector    0x7843e5dd
    /// @custom:signature   Unresolved_7843e5dd(address arg0, uint256 arg1) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_7843e5dd(address arg0, uint256 arg1) public {
        address var_a = msg.sender;
        uint256 var_b = 0;
        require(uint32(storage_map_a[var_a]));
        address var_d = address(arg0);
        require(address(unresolved_fed57875).code.length);
        (bool success, bytes memory ret0) = address(unresolved_fed57875).{ value: var_b ether }Unresolved_a9059cbb(var_d); // call
        require(!ret0.length < 0x20);
    }
    
    /// @custom:selector    0xf7250826
    /// @custom:signature   Unresolved_f7250826(uint256 arg0, address arg1, address arg2) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_f7250826(uint256 arg0, address arg1, address arg2) public view returns (bool) {
        var_a = address(arg1);
        var_a = address(arg2);
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x198d2d64
    /// @custom:signature   setDecimals(uint256 arg0, uint8 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["bool", "uint8", "bytes1", "int8"]
    function setDecimals(uint256 arg0, uint8 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (bytes1(arg1)) | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xb0a79459
    /// @custom:signature   getBalance(uint256 arg0, address arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function getBalance(uint256 arg0, address arg1) public view returns (uint256) {
        var_a = address(arg1);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0xe137a82e
    /// @custom:signature   Unresolved_e137a82e(uint16 arg0) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_e137a82e(uint16 arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(uint16(arg0) > 0x2710), "div");
        unresolved_1c2fef80 = (uint16(arg0)) | (uint240(unresolved_1c2fef80));
    }
    
    /// @custom:selector    0xeb5f144d
    /// @custom:signature   Unresolved_eb5f144d(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_eb5f144d(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * (storage_map_k[var_a])));
        if (!storage_map_k[var_a]) {
            var_a = 0x03 + keccak256(var_a);
            if ((var_c + 0x20) + (0x20 * (storage_map_k[var_a])) > ((var_c + 0x20) + 0x20)) {
                if ((var_c + 0x20) + (0x20 * (storage_map_k[var_a])) > (0x20 + ((var_c + 0x20) + 0x20))) {
                    if (!0 < (var_c.length * 0x20)) {
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x2df3f42a
    /// @custom:signature   Unresolved_2df3f42a(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_2df3f42a(uint256 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x06aec0ef
    /// @custom:signature   globalUnlock() public
    function globalUnlock() public {
        require(msg.sender == (address(getManager)));
        require(!(uint32(unresolved_1d0a9c61)), "0");
        require(!(0 < store_m), "len");
        require(0 < store_m, "len");
        address var_e = address(storage_map_n[var_e]);
        require(!(!uint32(storage_map_o[var_e])), "len");
        require(0xffffffff > unresolved_1d0a9c61, "len");
        store_m = 0;
        if (!store_m > 0) {
            var_e = 0x03;
            if (!(keccak256(var_e) + store_m) > (0 + keccak256(var_e))) {
                isGlobalLocked = uint248(isGlobalLocked);
                emit Event_d8d7d71f(0);
                isGlobalLocked = uint248(isGlobalLocked);
                emit Event_d8d7d71f(0);
            }
        }
    }
    
    /// @custom:selector    0x2c4fa099
    /// @custom:signature   Unresolved_2c4fa099(uint256 arg0, uint256 arg1, address arg2, uint64 arg3, uint64 arg4, uint88 arg5, uint256 arg6) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint64", "bytes8", "int64"]
    /// @param              arg4 ["uint64", "bytes8", "int64"]
    /// @param              arg5 ["uint88", "bytes11", "int88"]
    /// @param              arg6 ["uint256", "bytes32", "int256"]
    function Unresolved_2c4fa099(uint256 arg0, uint256 arg1, address arg2, uint64 arg3, uint64 arg4, uint88 arg5, uint256 arg6) public {
        address var_d = msg.sender;
        require(!(!uint32(storage_map_q[var_d])), "exist");
        require(0x3c, "exist");
        require(!((arg6 / 0x3c) > 0), "exist");
        var_d = uint248(arg0);
        require(!(uint32(storage_map_r[var_d] / 0x0100)), "exist");
        require(!(arg3 == (uint64(arg3))), "overflow");
        require(!(arg3 == (uint64(arg3))), "overflow");
        require(!(arg3 == (uint64(arg3))), "overflow");
        require(!(!arg3 == (uint64(arg3))), "overflow");
        var_d = var_d;
        var_a = var_a + 0xc0;
        var_d = keccak256(var_d);
        require(0x1f < var_o, "exist");
        storage_map_q[var_d] = 0x01 + (var_o + var_o);
        require(!var_o, "exist");
        require(!(((var_a.length + 0x20) + var_p) > (var_a.length + 0x20)), "exist");
        require(!(keccak256(var_d) + ((0x1f + (((0x0100 * (!bytes1(storage_map_q[var_d]))) - 0x01) & (storage_map_q[var_d]) / 0x02)) / 0x20) > keccak256(var_d)), "exist");
        storage_map_r[var_d] = (uint88(var_q) * 0x01000000000000000000000000000000000000000000) | (uint168((uint64(var_r) * 0x0100000000000000000000000000) | (uint192((uint64(var_s) * 0x010000000000) | (uint192((uint32(var_t) * 0x0100) | (uint224(bytes1(var_u) | (uint248(storage_map_r[var_d]))))))))));
        var_d = arg0;
        storage_map_q[var_d] = arg4;
        require(!(address(arg2) > 0), "exist");
        var_d = arg0;
        storage_map_q[var_d] = (address(arg2)) | (uint96(storage_map_q[var_d]));
        require(!(!(arg6 / 0x3c) > 0), "exist");
    }
    
    /// @custom:selector    0x8e1f81bb
    /// @custom:signature   globalLock() public
    function globalLock() public {
        require(msg.sender == (address(getManager)));
        require(!(bytes1(isGlobalLocked / 0x0100)), "disabled");
        require(!(uint32(store_m)), "0");
        require(!(0 < unresolved_1d0a9c61), "len");
        require(0 < unresolved_1d0a9c61, "len");
        address var_e = address(storage_map_n[var_e]);
        require(!(!uint32(storage_map_o[var_e])), "len");
        require(0xffffffff > store_m, "len");
        unresolved_1d0a9c61 = 0;
        if (!unresolved_1d0a9c61 > 0) {
            var_e = 0x01;
            if (!(keccak256(var_e) + unresolved_1d0a9c61) > (0 + keccak256(var_e))) {
                isGlobalLocked = var_e | (uint248(isGlobalLocked));
                emit Event_d8d7d71f(0x01);
                isGlobalLocked = var_e | (uint248(isGlobalLocked));
                emit Event_d8d7d71f(0x01);
            }
        }
    }
    
    /// @custom:selector    0x1e453367
    /// @custom:signature   Unresolved_1e453367(uint256 arg0) public view returns (uint16)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_1e453367(uint256 arg0) public view returns (uint16) {
        uint256 var_a = arg0;
        return uint16(storage_map_a[var_a] / 0x010000);
    }
    
    /// @custom:selector    0x902a8fc3
    /// @custom:signature   Unresolved_902a8fc3(address arg0) public view returns (uint32)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_902a8fc3(address arg0) public view returns (uint32) {
        address var_a = address(arg0);
        require(!(!uint32(storage_map_a[var_a])), "null");
        var_a = address(arg0);
        return uint32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + (storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xb4c8c5c4
    /// @custom:signature   isApprovedAddress(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function isApprovedAddress(address arg0) public view returns (bool) {
        address var_a = address(arg0);
        return !(!uint32(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x76feea52
    /// @custom:signature   Unresolved_76feea52(uint256 arg0, uint96 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint96", "bytes12", "int96"]
    function Unresolved_76feea52(uint256 arg0, uint96 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "overflow");
        require(arg1 == (uint96(arg1)), "overflow");
        var_a = var_a;
        var_a = arg0;
        require(!(uint96(arg1) > (uint96(storage_map_a[var_a] / 0x010000000000000000000000000000000000))), "max");
        var_a = arg0;
        storage_map_a[var_a] = (address(storage_map_a[var_a])) | (0x010000000000 * (uint96(arg1)));
    }
    
    /// @custom:selector    0xf13e6c7d
    /// @custom:signature   Unresolved_f13e6c7d(uint256 arg0, address arg1, address arg2, uint256 arg3) public returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_f13e6c7d(uint256 arg0, address arg1, address arg2, uint256 arg3) public returns (uint256) {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        var_a = address(arg2);
        require(!arg3 > storage_map_a[var_a]);
        var_a = address(arg1);
        var_a = address(arg2);
        storage_map_a[var_a] = storage_map_a[var_a] - arg3;
        return storage_map_a[var_a] - arg3;
    }
    
    /// @custom:selector    0x9c64c948
    /// @custom:signature   Unresolved_9c64c948(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_9c64c948(address arg0) public {
        require(msg.sender == (address(getManager)));
        address var_a = address(arg0);
        storage_map_a[var_a] = 0x01 | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x7ae1cfca
    /// @custom:signature   getBool(bytes32 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getBool(bytes32 arg0) public view returns (bool) {
        uint256 var_a = arg0;
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x21f8a721
    /// @custom:signature   getAddress(bytes32 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getAddress(bytes32 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0xf807393a
    /// @custom:signature   mintFungible(uint256 arg0, address arg1, uint256 arg2) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function mintFungible(uint256 arg0, address arg1, uint256 arg2) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        require(!(arg2 + storage_map_a[var_a]) < storage_map_a[var_a]);
        var_a = address(arg1);
        storage_map_a[var_a] = arg2 + storage_map_a[var_a];
    }
    
    /// @custom:selector    0x20f1d85b
    /// @custom:signature   removeApprovedAddress(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function removeApprovedAddress(address arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(bytes1(isGlobalLocked)), "rem");
        require(!(bytes1(isGlobalLocked / 0x01000000)), "rem");
        address var_e = address(arg0);
        require(!(bytes1(storage_map_o[var_e])), "freeze");
        var_e = address(arg0);
        if (!uint32(storage_map_o[var_e])) {
            require(!(uint32(storage_map_o[var_e])), "lock");
            require(!(uint32(storage_map_o[var_e]) < unresolved_1d0a9c61), "lock");
            require((unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) < unresolved_1d0a9c61, "lock");
            var_e = 0x01;
            storage_map_s[var_e] = (address(storage_map_t[var_e])) | (uint96(storage_map_u[var_e]));
            var_e = address(storage_map_t[var_e]);
            storage_map_o[var_e] = (uint32(storage_map_o[var_e])) | (uint224(storage_map_o[var_e]));
            var_e = address(arg0);
            storage_map_o[var_e] = uint224(storage_map_o[var_e]);
            unresolved_1d0a9c61 = unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            require(uint32(storage_map_o[var_e] + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) < unresolved_1d0a9c61, "lock");
            var_e = 0x01;
            require(!(unresolved_1d0a9c61 > (unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "lock");
            require(!((keccak256(var_e) + unresolved_1d0a9c61) > ((unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) + keccak256(var_e))), "lock");
            emit Event_3c4f2701(address(arg0), 0);
            storage_map_v[unresolved_1d0a9c61 + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff] = 0;
            require(!0x01, "lock");
        }
        require(!0, "lock");
        emit Event_3c4f2701(address(arg0), 0);
    }
    
    /// @custom:selector    0xe8e71f0c
    /// @custom:signature   releaseETH(address arg0, uint256 arg1) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function releaseETH(address arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        (bool success, bytes memory ret0) = address(arg0).transfer(arg1);
    }
    
    /// @custom:selector    0xdc97d962
    /// @custom:signature   getInt(bytes32 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getInt(bytes32 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x3f93ee4f
    /// @custom:signature   Unresolved_3f93ee4f(uint256 arg0, address arg1, uint256 arg2) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_3f93ee4f(uint256 arg0, address arg1, uint256 arg2) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        require(!arg2 > storage_map_a[var_a]);
        var_a = address(arg1);
        storage_map_a[var_a] = storage_map_a[var_a] - arg2;
    }
    
    /// @custom:selector    0x3a57ec5d
    /// @custom:signature   Unresolved_3a57ec5d(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_3a57ec5d(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_b[var_a]);
    }
    
    /// @custom:selector    0x620a3cbe
    /// @custom:signature   Unresolved_620a3cbe(uint248 arg0) public view returns (uint64)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_620a3cbe(uint248 arg0) public view returns (uint64) {
        uint248 var_a = uint248(arg0);
        if (!(uint64(storage_map_f[var_a] / 0x0100000000000000000000000000)) > (uint64(storage_map_f[var_a] / 0x010000000000))) {
            return (uint64(storage_map_f[var_a] / 0x010000000000)) - (uint64(storage_map_f[var_a] / 0x0100000000000000000000000000));
        }
    }
    
    /// @custom:selector    0x1e78bf08
    /// @custom:signature   getTransferable(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getTransferable(uint256 arg0) public view returns (bool) {
        uint256 var_a = arg0;
        return bytes1(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x6e899550
    /// @custom:signature   Unresolved_6e899550(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_6e899550(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        uint256 var_c = var_c + (0x20 + (((0x1f + (arg1)) / 0x20) * 0x20));
        var_a = keccak256(var_a);
        require(0x1f < var_c.length);
        storage_map_a[var_a] = 0x01 + (var_c.length + var_c.length);
        require(!var_c.length);
        require(!((var_c + 0x20) + var_c.length) > (var_c + 0x20));
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0x9e9b99ae
    /// @custom:signature   Unresolved_9e9b99ae(uint32 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function Unresolved_9e9b99ae(uint32 arg0) public view returns (address) {
        if (uint32(arg0) < unresolved_1d0a9c61) {
            var_a = 0x01;
            return address(storage_map_x[var_a]);
        }
    }
    
    /// @custom:selector    0xbd3184f1
    /// @custom:signature   Unresolved_bd3184f1(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_bd3184f1(uint256 arg0, uint256 arg1) public view returns (uint256) {
        var_a = arg1;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x61f861c0
    /// @custom:signature   Unresolved_61f861c0() public
    function Unresolved_61f861c0() public {
        require(msg.sender == (address(getManager)));
        isGlobalLocked = 0x0100 | (uint248(0x01000000 | (isGlobalLocked)));
    }
    
    /// @custom:selector    0xe2a4853a
    /// @custom:signature   setUint(bytes32 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setUint(bytes32 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = arg1;
    }
    
    /// @custom:selector    0x7384ce67
    /// @custom:signature   Unresolved_7384ce67(uint256 arg0, uint64 arg1) public returns (uint64)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_7384ce67(uint256 arg0, uint64 arg1) public returns (uint64) {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        require(!(uint64(arg1 + (storage_map_a[var_a]))) < (uint64(storage_map_a[var_a])));
        var_a = arg0;
        storage_map_a[var_a] = (uint64(arg1 + (storage_map_a[var_a]))) | (uint192(storage_map_a[var_a]));
        return uint64(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x696361ec
    /// @custom:signature   Unresolved_696361ec(address arg0, uint256 arg1) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_696361ec(address arg0, uint256 arg1) public {
        require(msg.sender == (address(getManager)));
        address var_a = address(arg0);
        storage_map_a[var_a] = arg1 | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x653ae674
    /// @custom:signature   Unresolved_653ae674(address arg0, address arg1, uint256 arg2, uint256 arg3) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_653ae674(address arg0, address arg1, uint256 arg2, uint256 arg3) public {
        address var_a = msg.sender;
        uint256 var_b = 0;
        require(uint32(storage_map_a[var_a]));
        address var_d = address(this);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_b ether }Unresolved_fe99049a(var_d); // call
    }
    
    /// @custom:selector    0xffaf6633
    /// @custom:signature   Unresolved_ffaf6633(uint256 arg0, address arg1, address arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_ffaf6633(uint256 arg0, address arg1, address arg2, uint256 arg3) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        require(!arg3 > storage_map_a[var_a]);
        var_a = address(arg1);
        storage_map_a[var_a] = storage_map_a[var_a] - arg3;
        var_a = address(arg2);
        require(!(arg3 + storage_map_a[var_a]) < storage_map_a[var_a]);
        var_a = address(arg2);
        storage_map_a[var_a] = arg3 + storage_map_a[var_a];
    }
    
    /// @custom:selector    0xe5230867
    /// @custom:signature   Unresolved_e5230867(uint256 arg0) public view returns (uint64)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_e5230867(uint256 arg0) public view returns (uint64) {
        uint256 var_a = arg0;
        return uint64(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0xee6ab318
    /// @custom:signature   Unresolved_ee6ab318(uint256 arg0, uint256 arg1) public returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_ee6ab318(uint256 arg0, uint256 arg1) public returns (uint256) {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        require(!arg1 < storage_map_a[var_a]);
        require(!arg1 > storage_map_a[var_a]);
        var_a = arg0;
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        return arg1;
        var_a = arg0;
        storage_map_a[var_a] = 0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x7d686379
    /// @custom:signature   Unresolved_7d686379(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_7d686379(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x69326b68
    /// @custom:signature   Unresolved_69326b68(address arg0, address arg1, uint256 arg2) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_69326b68(address arg0, address arg1, uint256 arg2) public {
        address var_a = msg.sender;
        uint256 var_b = 0;
        require(uint32(storage_map_a[var_a]));
        address var_d = address(arg1);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_b ether }Unresolved_a9059cbb(var_d); // call
        require(!ret0.length < 0x20);
    }
    
    /// @custom:selector    0x1e3a67bf
    /// @custom:signature   getMeltFee(uint256 arg0) public view returns (uint16)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getMeltFee(uint256 arg0) public view returns (uint16) {
        uint256 var_a = arg0;
        return uint16(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x85f8744e
    /// @custom:signature   Unresolved_85f8744e(uint256 arg0, uint96 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint96", "bytes12", "int96"]
    function Unresolved_85f8744e(uint256 arg0, uint96 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "overflow");
        require(arg1 == (uint96(arg1)), "overflow");
        var_a = var_a;
        var_a = arg0;
        require(uint96(arg1) < (uint96(storage_map_a[var_a] / 0x010000000000000000000000000000000000)), "decrease");
        var_a = arg0;
        require(!(uint96(arg1) < (uint96(storage_map_a[var_a] / 0x010000000000))), "decrease");
        var_a = arg0;
        storage_map_a[var_a] = (uint96(arg1) * 0x010000000000) | (address(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(storage_map_a[var_a])) | (0x010000000000000000000000000000000000 * (uint96(arg1)));
        var_a = arg0;
        storage_map_a[var_a] = (address(storage_map_a[var_a])) | (0x010000000000000000000000000000000000 * (uint96(arg1)));
    }
    
    /// @custom:selector    0x2e28d084
    /// @custom:signature   Unresolved_2e28d084(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_2e28d084(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        uint256 var_c = var_c + (0x20 + (((0x1f + (arg1)) / 0x20) * 0x20));
        var_a = keccak256(var_a);
        require(0x1f < var_c.length);
        storage_map_a[var_a] = 0x01 + (var_c.length + var_c.length);
        require(!var_c.length);
        require(!((var_c + 0x20) + var_c.length) > (var_c + 0x20));
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0x92ab723e
    /// @custom:signature   Unresolved_92ab723e(uint248 arg0) public view returns (uint64)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_92ab723e(uint248 arg0) public view returns (uint64) {
        uint248 var_a = uint248(arg0);
        return uint64(storage_map_b[var_a] / 0x010000000000);
    }
    
    /// @custom:selector    0xb0a4d7d3
    /// @custom:signature   Unresolved_b0a4d7d3(uint248 arg0, uint64 arg1) public
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    /// @param              arg1 ["uint64", "bytes8", "int64"]
    function Unresolved_b0a4d7d3(uint248 arg0, uint64 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "overflow");
        require(arg1 == (uint64(arg1)), "overflow");
        var_a = var_a;
        var_a = uint248(arg0);
        storage_map_b[var_a] = (uint192(storage_map_b[var_a])) | (0x010000000000 * (uint64(arg1)));
    }
    
    /// @custom:selector    0x20ec4a86
    /// @custom:signature   Unresolved_20ec4a86(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_20ec4a86(uint256 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x616b59f6
    /// @custom:signature   deleteBytes(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteBytes(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = 0;
        require(0x1f < (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02));
        var_a = keccak256(var_a);
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0x73ab66b2
    /// @custom:signature   Unresolved_73ab66b2(uint256 arg0, address arg1, uint256 arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_73ab66b2(uint256 arg0, address arg1, uint256 arg2, uint256 arg3) public {
        var_a = 0x20 + ((0x20 * (arg3)) + var_a);
        address var_e = msg.sender;
        uint256 var_f = 0;
        require(uint32(storage_map_o[var_e]));
        address var_h = address(this);
        require(!0 < (var_a.length * 0x20));
        require(!0 < (0x20 * var_a.length));
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_f ether }Unresolved_17fad7fc(var_h); // call
    }
    
    /// @custom:selector    0x77778db3
    /// @custom:signature   getReserve(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getReserve(uint256 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x40550b94
    /// @custom:signature   Unresolved_40550b94(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_40550b94(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = keccak256(var_a);
        require(0x1f < (arg1));
        storage_map_a[var_a] = 0x01 + (arg1 + (arg1));
        require(!arg1);
        require(!((arg1 + 0x24) + (arg1)) > (arg1 + 0x24));
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0xbd143872
    /// @custom:signature   Unresolved_bd143872(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_bd143872(address arg0) public {
        require(!(address(unresolved_42f6b6ce)), "addr");
        require(!(!msg.sender == (address(unresolved_42f6b6ce))), "addr");
        unresolved_42f6b6ce = (address(arg0)) | (uint96(unresolved_42f6b6ce));
    }
    
    /// @custom:selector    0xf8057921
    /// @custom:signature   Unresolved_f8057921(uint256 arg0) public view returns (uint96)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_f8057921(uint256 arg0) public view returns (uint96) {
        uint256 var_a = arg0;
        return uint96(storage_map_a[var_a] / 0x010000000000000000000000000000000000);
    }
    
    /// @custom:selector    0x2b3ae9c3
    /// @custom:signature   Unresolved_2b3ae9c3(uint256 arg0, uint16 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    function Unresolved_2b3ae9c3(uint256 arg0, uint16 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "decrease");
        var_a = arg0;
        require(uint16(arg1) < (uint16(storage_map_a[var_a] / 0x010000)), "decrease");
        var_a = arg0;
        require(!(uint16(arg1) < (uint16(storage_map_a[var_a]))), "decrease");
        var_a = arg0;
        storage_map_a[var_a] = (uint16(arg1)) | (uint240(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (uint240(storage_map_a[var_a])) | (0x010000 * (uint16(arg1)));
        var_a = arg0;
        storage_map_a[var_a] = (uint240(storage_map_a[var_a])) | (0x010000 * (uint16(arg1)));
    }
    
    /// @custom:selector    0xfec272c4
    /// @custom:signature   setReserve(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setReserve(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = arg1;
    }
    
    /// @custom:selector    0x986e791a
    /// @custom:signature   getString(bytes32 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getString(bytes32 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * (((storage_map_a[var_a] & ((0x0100 * (!bytes1(storage_map_a[var_a]))) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) + 0x1f) / 0x20)));
        if (!(storage_map_a[var_a] & ((0x0100 * (!storage_map_a[var_a])) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)) / 0x02) {
            if (0x1f < (storage_map_a[var_a] & ((0x0100 * (!storage_map_a[var_a])) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02)) {
                var_a = keccak256(var_a);
                if ((var_c + 0x20) + (storage_map_a[var_a] & ((0x0100 * (!storage_map_a[var_a])) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) > (0x20 + (var_c + 0x20))) {
                    if (!var_c.length) {
                        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_h));
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x1aa347dc
    /// @custom:signature   getURI(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getURI(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        var_b = 0x20;
        uint256 var_c = var_b + (var_c + (0x20 * (((storage_map_a[var_a] & (((!bytes1(storage_map_a[var_a])) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) + 0x1f) / 0x20)));
        if (!(storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)) / 0x02) {
            if (0x1f < (storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02)) {
                var_a = keccak256(var_a);
                if ((var_c + 0x20) + (storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) > (0x20 + (var_c + 0x20))) {
                    if (!var_c.length) {
                        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_h));
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0xa14ecd20
    /// @custom:signature   Unresolved_a14ecd20(uint256 arg0, address arg1, address arg2, uint256 arg3) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_a14ecd20(uint256 arg0, address arg1, address arg2, uint256 arg3) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = address(arg1);
        var_a = address(arg2);
        storage_map_a[var_a] = arg3;
    }
    
    /// @custom:selector    0x17d26816
    /// @custom:signature   Unresolved_17d26816(address arg0, address arg1, uint256 arg2) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_17d26816(address arg0, address arg1, uint256 arg2) public {
        address var_a = msg.sender;
        uint256 var_b = 0;
        require(uint32(storage_map_a[var_a]));
        address var_d = address(this);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: var_b ether }Unresolved_23b872dd(var_d); // call
    }
    
    /// @custom:selector    0xd5a38eb8
    /// @custom:signature   Unresolved_d5a38eb8(uint16 arg0) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_d5a38eb8(uint16 arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(uint16(arg0) > 0x2710), "div");
        unresolved_1c2fef80 = (uint240(unresolved_1c2fef80)) | (0x010000 * (uint16(arg0)));
    }
    
    /// @custom:selector    0xcd066c1c
    /// @custom:signature   Unresolved_cd066c1c(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_cd066c1c(uint256 arg0, address arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x7b129b06
    /// @custom:signature   Unresolved_7b129b06(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_7b129b06(uint256 arg0, address arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x93fb8f39
    /// @custom:signature   Unresolved_93fb8f39(uint248 arg0, address arg1, bool arg2) public
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["bool", "uint8", "bytes1", "int8"]
    function Unresolved_93fb8f39(uint248 arg0, address arg1, bool arg2) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "exist");
        var_a = uint248(arg0);
        require(!(uint32(storage_map_b[var_a] / 0x0100)), "exist");
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
        require(!(bytes1(arg2)) > 0);
        var_a = address(arg1);
        var_a = 0x01;
        storage_map_a[var_a] = 0x01 | (uint248(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (uint248(storage_map_a[var_a])) | (bytes1(arg2));
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public
    function acceptManager() public {
        require(msg.sender == (address(store_e)), "new");
        emit ManagerUpdate(address(getManager), address(store_e));
        getManager = (address(store_e)) | (uint96(getManager));
        store_e = uint96(store_e);
    }
    
    /// @custom:selector    0x6418413c
    /// @custom:signature   getSymbol(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getSymbol(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * (((storage_map_a[var_a] & (((!bytes1(storage_map_a[var_a])) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) + 0x1f) / 0x20)));
        if (!(storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)) / 0x02) {
            if (0x1f < (storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02)) {
                var_a = keccak256(var_a);
                if ((var_c + 0x20) + (storage_map_a[var_a] & (((!storage_map_a[var_a]) * 0x0100) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 0x02) > (0x20 + (var_c + 0x20))) {
                    if (!var_c.length) {
                        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_h));
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0xbc7a17c5
    /// @custom:signature   Unresolved_bc7a17c5(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_bc7a17c5(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x465b17de
    /// @custom:signature   Unresolved_465b17de(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_465b17de(address arg0) public view returns (bool) {
        address var_a = address(arg0);
        return !(!bytes1(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x518a45b5
    /// @custom:signature   Unresolved_518a45b5(uint256 arg0, bool arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["bool", "uint8", "bytes1", "int8"]
    function Unresolved_518a45b5(uint256 arg0, bool arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_ac[var_a] = (uint248(storage_map_ac[var_a])) | (0x0100000000000000000000000000000000 * (bytes1(arg1)));
    }
    
    /// @custom:selector    0x73007500
    /// @custom:signature   Unresolved_73007500(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_73007500(uint256 arg0) public view returns (bool) {
        uint256 var_a = arg0;
        return bytes1(storage_map_a[var_a] / 0x0100000000);
    }
    
    /// @custom:selector    0x270c373e
    /// @custom:signature   Unresolved_270c373e(uint256 arg0, address arg1, address arg2) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_270c373e(uint256 arg0, address arg1, address arg2) public view returns (bool) {
        uint256 var_a = arg0;
        if (storage_map_a[var_a] < 0x02) {
            var_a = address(arg1);
            var_a = 0x01;
            if (storage_map_a[var_a]) {
                if (storage_map_a[var_a]) {
                    if (storage_map_a[var_a]) {
                        if (storage_map_a[var_a]) {
                            if (storage_map_a[var_a]) {
                                return !(!bytes1(storage_map_a[var_a]));
                                var_a = address(arg2);
                                var_a = address(arg1);
                                return !(!bytes1(storage_map_a[var_a]));
                                if (storage_map_a[var_a] < 0x02) {
                                    if (storage_map_a[var_a] < 0x02) {
                                        if (storage_map_a[var_a] < 0x02) {
                                            if (storage_map_a[var_a] < 0x02) {
                                                if (storage_map_a[var_a] < 0x02) {
                                                    var_a = address(arg2);
                                                    var_a = address(arg1);
                                                    return !(!bytes1(storage_map_a[var_a]));
                                                    return !(!(bytes1(storage_map_a[var_a])) < 0x02);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x8d42e29c
    /// @custom:signature   Unresolved_8d42e29c(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint128", "bytes16", "int128"]
    function Unresolved_8d42e29c(uint256 arg0, address arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "overflow");
        require(arg1 == (address(arg1)), "overflow");
        var_a = var_a;
        var_a = arg0;
        storage_map_ac[var_a] = (address(arg1)) | (address(storage_map_ac[var_a]));
    }
    
    /// @custom:selector    0xf6bb3cc4
    /// @custom:signature   deleteString(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteString(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = 0;
        require(0x1f < (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02));
        var_a = keccak256(var_a);
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0xbd02d0f5
    /// @custom:signature   getUint(bytes32 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getUint(bytes32 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x3e49bed0
    /// @custom:signature   setInt(bytes32 arg0, int256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setInt(bytes32 arg0, int256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = arg1;
    }
    
    /// @custom:selector    0xd48e638a
    /// @custom:signature   getCreator(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getCreator(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x0e14a376
    /// @custom:signature   deleteAddress(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteAddress(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = uint96(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x745c8b45
    /// @custom:signature   Unresolved_745c8b45(uint248 arg0) public view returns (bool)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_745c8b45(uint248 arg0) public view returns (bool) {
        uint248 var_a = uint248(arg0);
        return bytes1(storage_map_b[var_a]);
    }
    
    /// @custom:selector    0xeab99bb0
    /// @custom:signature   Unresolved_eab99bb0(uint64 arg0, address arg1) public
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_eab99bb0(uint64 arg0, address arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = (address(arg1)) | (uint96(storage_map_a[var_a]));
        var_a = address(arg1);
        require(!(0x01 + storage_map_a[var_a]) < storage_map_a[var_a]);
        var_a = address(arg1);
        storage_map_a[var_a] = 0x01 + storage_map_a[var_a];
    }
    
    /// @custom:selector    0xd2ac1c8e
    /// @custom:signature   addApprovedAddress(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function addApprovedAddress(address arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(bytes1(isGlobalLocked)), "add");
        require(!(bytes1(isGlobalLocked / 0x010000)), "add");
        address var_e = address(arg0);
        require(!(!uint32(storage_map_o[var_e])), "len");
        require(!0, "len");
        var_g = 0x01;
        emit Event_3c4f2701(address(arg0), 0x01);
        require(0xffffffff > unresolved_1d0a9c61, "len");
        unresolved_1d0a9c61 = var_g + unresolved_1d0a9c61;
        var_e = 0x01;
        storage_map_ad[var_e] = (address(arg0)) | (uint96(storage_map_ad[var_e]));
        var_e = address(arg0);
        storage_map_o[var_e] = (uint32(0x01 + unresolved_1d0a9c61)) | (uint224(storage_map_o[var_e]));
        require(!0x01, "lock");
        emit Event_3c4f2701(address(arg0), 0x01);
    }
    
    /// @custom:selector    0xfe55932a
    /// @custom:signature   Unresolved_fe55932a(uint248 arg0, uint256 arg1) public
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_fe55932a(uint248 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = keccak256(var_a);
        require(0x1f < (arg1));
        storage_map_a[var_a] = 0x01 + (arg1 + (arg1));
        require(!arg1);
        require(!((arg1 + 0x24) + (arg1)) > (arg1 + 0x24));
        require(!(keccak256(var_a) + ((0x1f + (((0x0100 * (!bytes1(storage_map_a[var_a]))) - 0x01) & (storage_map_a[var_a]) / 0x02)) / 0x20)) > keccak256(var_a));
    }
    
    /// @custom:selector    0x6b8ff574
    /// @custom:signature   Unresolved_6b8ff574(uint248 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_6b8ff574(uint248 arg0) public view returns (bytes memory) {
        uint248 var_a = uint248(arg0);
        uint248 var_c = 0x20 + (var_c + (0x20 * (((storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!bytes1(storage_map_a[var_a])) * 0x0100)) / 0x02) + 0x1f) / 0x20)));
        if (!(storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100))) / 0x02) {
            if (0x1f < (storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100)) / 0x02)) {
                var_a = keccak256(var_a);
                if ((var_c + 0x20) + (storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100)) / 0x02) > (0x20 + (var_c + 0x20))) {
                    if (!var_c.length) {
                        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_h));
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0xc59694cf
    /// @custom:signature   getTradeState(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getTradeState(uint256 arg0) public view returns (bool) {
        uint256 var_a = arg0;
        return bytes1(storage_map_ac[var_a] / 0x0100000000000000000000000000000000);
    }
    
    /// @custom:selector    0xabfdcced
    /// @custom:signature   Unresolved_abfdcced(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_abfdcced(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = arg1 | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0x2c62ff2d
    /// @custom:signature   deleteBool(bytes32 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deleteBool(bytes32 arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = uint248(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0xd2aa85ed
    /// @custom:signature   Unresolved_d2aa85ed(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_d2aa85ed(uint256 arg0) public {
        require(msg.sender == (address(getManager)));
        require(!(0x03f480 > block.timestamp), "cooldown");
        require(unresolved_717eced5 < (block.timestamp - 0x03f480), "cooldown");
        unresolved_ee28d7a3 = arg0;
        unresolved_717eced5 = block.timestamp;
    }
    
    /// @custom:selector    0xb920ee00
    /// @custom:signature   Unresolved_b920ee00(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_b920ee00(address arg0) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        unresolved_fed57875 = (address(arg0)) | (uint96(unresolved_fed57875));
    }
    
    /// @custom:selector    0xf521a982
    /// @custom:signature   Unresolved_f521a982(uint248 arg0) public view returns (uint32)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_f521a982(uint248 arg0) public view returns (uint32) {
        uint248 var_a = uint248(arg0);
        if (uint32(storage_map_b[var_a] / 0x0100)) {
            if (uint32(storage_map_b[var_a] / 0x0100)) {
                if ((0x3c * (uint32(storage_map_b[var_a] / 0x0100))) / (uint32(storage_map_b[var_a] / 0x0100)) == 0x3c) {
                    return 0x3c * (uint32(storage_map_b[var_a] / 0x0100));
                    return 0;
                }
            }
        }
    }
    
    /// @custom:selector    0xff42fe18
    /// @custom:signature   getDecimals(uint256 arg0) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getDecimals(uint256 arg0) public view returns (bool) {
        uint256 var_a = arg0;
        return bytes1(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x95760fb9
    /// @custom:signature   Unresolved_95760fb9(uint64 arg0, address arg1, address arg2) public
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_95760fb9(uint64 arg0, address arg1, address arg2) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "owner");
        var_a = arg0;
        require(!(address(storage_map_a[var_a]) == (address(arg1))), "owner");
        require(!(!(address(storage_map_a[var_a])) == (address(arg1))), "owner");
        var_a = arg0;
        storage_map_a[var_a] = (address(arg2)) | (uint96(storage_map_a[var_a]));
        var_a = address(arg1);
        require(!0x01 > storage_map_a[var_a]);
        var_a = address(arg1);
        storage_map_a[var_a] = storage_map_a[var_a] - 0x01;
        var_a = address(arg2);
        require(!(0x01 + storage_map_a[var_a]) < storage_map_a[var_a]);
        var_a = address(arg2);
        storage_map_a[var_a] = 0x01 + storage_map_a[var_a];
    }
    
    /// @custom:selector    0xeaf457dd
    /// @custom:signature   Unresolved_eaf457dd(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_eaf457dd(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        require(!(arg1 + storage_map_a[var_a]) < storage_map_a[var_a]);
        var_a = arg0;
        storage_map_a[var_a] = arg1 + storage_map_a[var_a];
    }
    
    /// @custom:selector    0xc1f337cd
    /// @custom:signature   Unresolved_c1f337cd(uint256 arg0, uint256 arg1, uint256 arg2) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_c1f337cd(uint256 arg0, uint256 arg1, uint256 arg2) public {
        require(msg.sender == (address(getManager)));
        var_a = arg1;
        require(!(0x03f480 > block.timestamp), "cooldown");
        require(storage_map_a[var_a] < (block.timestamp - 0x03f480), "cooldown");
        var_a = arg1;
        storage_map_a[var_a] = arg2;
        var_a = arg1;
        storage_map_a[var_a] = block.timestamp;
    }
    
    /// @custom:selector    0xc031a180
    /// @custom:signature   getBytes(bytes32 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getBytes(bytes32 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * (((storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!bytes1(storage_map_a[var_a])) * 0x0100)) / 0x02) + 0x1f) / 0x20)));
        if (!(storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100))) / 0x02) {
            if (0x1f < (storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100)) / 0x02)) {
                var_a = keccak256(var_a);
                if ((var_c + 0x20) + (storage_map_a[var_a] & (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + ((!storage_map_a[var_a]) * 0x0100)) / 0x02) > (0x20 + (var_c + 0x20))) {
                    if (!var_c.length) {
                        return abi.encodePacked(0x20, var_c.length, (~((0x0100 ** (0x20 - (bytes1(var_c.length)))) - 0x01)) & (var_h));
                        return abi.encodePacked(0x20, var_c.length);
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0xe6dfa245
    /// @custom:signature   Unresolved_e6dfa245() public
    function Unresolved_e6dfa245() public {
        require(msg.sender == (address(getManager)));
        isGlobalLocked = 0x010000 | (uint248(isGlobalLocked));
    }
    
    /// @custom:selector    0xa6566f8d
    /// @custom:signature   setMeltFee(uint256 arg0, uint16 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    function setMeltFee(uint256 arg0, uint16 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "max");
        var_a = arg0;
        require(!(uint16(arg1) > (uint16(storage_map_a[var_a] / 0x010000))), "max");
        var_a = arg0;
        storage_map_a[var_a] = (uint16(arg1)) | (uint240(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xd44f2e29
    /// @custom:signature   Unresolved_d44f2e29(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_d44f2e29(uint256 arg0, uint256 arg1) public view returns (uint256) {
        var_a = arg1;
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x34e07ff3
    /// @custom:signature   setTransferable(uint256 arg0, uint8 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["bool", "uint8", "bytes1", "int8"]
    function setTransferable(uint256 arg0, uint8 arg1) public {
        address var_a = msg.sender;
        require(!(!uint32(storage_map_a[var_a])), "permanent");
        var_a = arg0;
        require(bytes1(storage_map_a[var_a]) > 0, "permanent");
        var_a = arg0;
        storage_map_a[var_a] = (bytes1(arg1)) | (uint248(storage_map_a[var_a]));
    }
    
    /// @custom:selector    0xec9d633d
    /// @custom:signature   Unresolved_ec9d633d(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_ec9d633d(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x42d98f71
    /// @custom:signature   Unresolved_42d98f71(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_42d98f71(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_a[var_a]);
    }
    
    /// @custom:selector    0x7e686648
    /// @custom:signature   Unresolved_7e686648(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_7e686648(uint256 arg0, uint256 arg1) public {
        address var_a = msg.sender;
        require(uint32(storage_map_a[var_a]));
        var_a = arg0;
        storage_map_a[var_a] = arg1;
    }
    
    /// @custom:selector    0xde2ac4e4
    /// @custom:signature   Unresolved_de2ac4e4(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_de2ac4e4(uint256 arg0) public view returns (address) {
        uint256 var_a = arg0;
        return address(storage_map_ac[var_a]);
    }
    
    /// @custom:selector    0x0a432df0
    /// @custom:signature   Unresolved_0a432df0(uint256 arg0) public view returns (uint96)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_0a432df0(uint256 arg0) public view returns (uint96) {
        uint256 var_a = arg0;
        return uint96(storage_map_a[var_a] / 0x010000000000);
    }
    
    /// @custom:selector    0x796cc911
    /// @custom:signature   Unresolved_796cc911(uint248 arg0) public view returns (uint64)
    /// @param              arg0 ["uint248", "bytes31", "int248"]
    function Unresolved_796cc911(uint248 arg0) public view returns (uint64) {
        uint248 var_a = uint248(arg0);
        return uint64(storage_map_b[var_a] / 0x0100000000000000000000000000);
    }
}