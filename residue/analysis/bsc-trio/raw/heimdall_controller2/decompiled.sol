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
    uint256 public _lastTime;
    mapping(bytes32 => bytes32) storage_map_f;
    uint256 public everyDiv;
    mapping(bytes32 => bytes32) storage_map_w;
    bytes32 store_k;
    mapping(bytes32 => bytes32) storage_map_v;
    uint256 public getUserCount;
    mapping(bytes32 => bytes32) storage_map_z;
    mapping(bytes32 => bytes32) storage_map_a;
    bytes32 store_m;
    bytes32 store_n;
    address public ROUTER;
    mapping(bytes32 => bytes32) storage_map_s;
    address public owner;
    mapping(bytes32 => bytes32) storage_map_aa;
    mapping(bytes32 => bytes32) storage_map_y;
    bool public status;
    mapping(bytes32 => bytes32) storage_map_b;
    address public config;
    uint256 public _current;
    uint256 public airDropCount;
    uint256 public minPeriod;
    uint256 store_l;
    mapping(bytes32 => bytes32) storage_map_u;
    uint256 public getWeek;
    mapping(bytes32 => bytes32) storage_map_x;
    uint256 public _count;
    
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x7521d3a3
    /// @custom:signature   Unresolved_7521d3a3(address arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_7521d3a3(address arg0, uint256 arg1) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        require(arg1 < storage_map_a[var_b]);
        var_b = keccak256(var_b);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0x2b334dac
    /// @custom:signature   Unresolved_2b334dac(uint256 arg0, address arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2b334dac(uint256 arg0, address arg1) public view returns (uint256) {
        require(arg1 == (address(arg1)));
        uint256 var_b = arg0;
        var_b = arg1;
        return storage_map_a[var_b];
    }
    
    /// @custom:selector    0x6d705ebb
    /// @custom:signature   register(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function register(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(address(msg.sender) == (address(var_i)));
        require(arg1 < 0x056bc75e2d63100000);
        address var_d = address(arg0);
        require(!storage_map_f[var_d] > (arg1 + storage_map_f[var_d]));
        var_d = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require((arg1 + storage_map_f[var_d]) > 0x021e19e0c9bab2400000);
        require(!(arg1 + storage_map_f[var_d]) > 0x021e19e0c9bab2400000);
        require(0);
        require(0x01);
        if (0x8ac7230489e80000) {
            require(0x8ac7230489e80000);
            require(arg1 < 0x056bc75e2d63100000);
        }
    }
    
    /// @custom:selector    0x2b7b8838
    /// @custom:signature   levelPower(uint256 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function levelPower(uint256 arg0) public view returns (uint256) {
        uint256 var_b = arg0;
        return storage_map_a[var_b];
    }
    
    /// @custom:selector    0x53fe7d7e
    /// @custom:signature   Unresolved_53fe7d7e(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_53fe7d7e(uint256 arg0, uint256 arg1) public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(!var_e.length > 0xffffffffffffffff);
        require((var_e + ret0.length) > ((var_e + var_e.length) + 0x1f));
        require(!(var_f) > 0xffffffffffffffff);
        require(!((var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f))) < var_e) | ((var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_e = var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f));
        require(!(0x20 + ((var_e + var_e.length) + (var_i << 0x05))) > (var_e + ret0.length));
        require(!(0x20 + (var_e + var_e.length)) < (0x20 + ((var_e + var_e.length) + (var_i << 0x05))));
        require(var_k == (address(var_k)));
        require(!arg0 < arg1);
        require(0x08 < var_e.length);
        uint256 var_d = arg0;
        (bool success, bytes memory ret0) = address(var_m).Unresolved_b0467deb(var_d); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
    }
    
    /// @custom:selector    0xddcde7cb
    /// @custom:signature   isRealUser(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function isRealUser(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return !(!bytes1(storage_map_a[var_b]));
    }
    
    /// @custom:selector    0x87d8d643
    /// @custom:signature   Unresolved_87d8d643() public payable
    function Unresolved_87d8d643() public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(!var_e.length > 0xffffffffffffffff);
        require((var_e + ret0.length) > ((var_e + var_e.length) + 0x1f));
        require(!(var_f) > 0xffffffffffffffff);
        require(!((var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f))) < var_e) | ((var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_e = var_e + (uint248((0x20 + (var_i << 0x05)) + 0x1f));
        require(!(0x20 + ((var_e + var_e.length) + (var_i << 0x05))) > (var_e + ret0.length));
        require(!(0x20 + (var_e + var_e.length)) < (0x20 + ((var_e + var_e.length) + (var_i << 0x05))));
        require(var_k == (address(var_k)));
        require(!0 < 0x0a);
        require(0x08 < var_e.length);
        uint256 var_d = 0;
        (bool success, bytes memory ret0) = address(var_n).Unresolved_adee8014(var_d); // staticcall
        require(!0);
        require(0x08 < var_e.length);
        var_d = 0;
        (bool success, bytes memory ret0) = address(var_n).Unresolved_70e16b80(var_d); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        var_g = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_g);
        var_m = 0;
        (bool success, bytes memory ret0) = address(var_q).Unresolved_70e16b80(var_m); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        var_g = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!0x01 < 0x0a);
        require(0x08 < var_g);
        var_m = 0;
        (bool success, bytes memory ret0) = address(var_q).Unresolved_adee8014(var_m); // staticcall
        require(!0);
        require(0x08 < var_g);
        var_m = 0;
        (bool success, bytes memory ret0) = address(var_q).Unresolved_70e16b80(var_m); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        var_p = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_p); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(var_e.length == (address(var_e.length)));
        store_k = store_k + 0x01;
        store_l = (address(var_e.length)) | (uint96(store_l));
        store_m = store_m + 0x01;
        store_n = 0;
        require(!0x01 < 0x0a);
        require(0x08 < var_r);
        var_t = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_t); // staticcall
        require(!0);
        require(0x08 < var_r);
        var_t = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_t); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_w = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_w); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_y = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_y); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_aa = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_aa); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_ac = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_ac); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_ae = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_ae); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_ag = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_ag); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_ai = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_ai); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_ak = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_ak); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_am = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_am); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_ao = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_ao); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_aq = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_aq); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_as = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_as); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_au = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_au); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_aw = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_aw); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_ay = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_ay); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_ba = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_ba); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_bc = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_bc); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_be = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_be); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_bg = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_bg); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_bi = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_bi); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_bk = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_bk); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_bm = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_bm); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_bo = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_bo); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        if (!((var_e + ret0.length) - var_e) < 0x20) {
            require(!((var_e + ret0.length) - var_e) < 0x20);
            store_k = store_k + 0x01;
            store_l = (address(var_e.length)) | (uint96(store_l));
            store_m = store_m + 0x01;
            store_n = 0;
            require(var_e.length == (address(var_e.length)));
            require(!0x01 < 0x0a);
            var_bq = 0;
            (bool success, bytes memory ret0) = address(var_u).Unresolved_adee8014(var_bq); // staticcall
            require(0x08 < var_r);
        }
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(0x01);
        require(!0);
        require(0x08 < var_r);
        uint256 var_bs = 0;
        (bool success, bytes memory ret0) = address(var_u).Unresolved_70e16b80(var_bs); // staticcall
        var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!((var_e + ret0.length) - var_e) < 0x20);
        require(var_e.length == (address(var_e.length)));
        store_k = store_k + 0x01;
        store_l = (address(var_e.length)) | (uint96(store_l));
        store_m = store_m + 0x01;
        store_n = 0;
        require(!0x01 < 0x0a);
    }
    
    /// @custom:selector    0x2c4e3db0
    /// @custom:signature   Unresolved_2c4e3db0(uint256 arg0, address arg1) public payable returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2c4e3db0(uint256 arg0, address arg1) public payable returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_c = var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f));
        require(!((0x04 + arg0) + 0x20) < ((0x04 + arg0) + (arg0 << 0x05) + 0x20));
        require((arg0 + 0x20) == (address(arg0 + 0x20)));
        address var_f = arg1;
        (bool success, bytes memory ret0) = address(0x10ed43c718714eb63d5aa57b78b54704e256024e).Unresolved_d06ca61f(var_f); // staticcall
        return 0;
        require(0x01 < var_a);
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(!var_c.length > 0xffffffffffffffff);
        require((var_c + ret0.length) > ((var_c + var_c.length) + 0x1f));
    }
    
    /// @custom:selector    0xc9f54be0
    /// @custom:signature   Unresolved_c9f54be0(address arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_c9f54be0(address arg0, uint256 arg1) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        require(arg1 < storage_map_a[var_b]);
        var_b = keccak256(var_b);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0x70e16b80
    /// @custom:signature   Unresolved_70e16b80(uint256 arg0, uint256 arg1) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_70e16b80(uint256 arg0, uint256 arg1) public view returns (address) {
        uint256 var_b = arg0;
        require(arg1 < storage_map_a[var_b]);
        var_b = keccak256(var_b);
        return address(storage_map_b[var_b]);
    }
    
    /// @custom:selector    0x3931092d
    /// @custom:signature   mintRecords(address arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function mintRecords(address arg0, uint256 arg1) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        require(arg1 < storage_map_a[var_b]);
        var_b = keccak256(var_b);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0xf4c6aa92
    /// @custom:signature   Unresolved_f4c6aa92(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_f4c6aa92(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        storage_map_s[var_e] = arg1;
    }
    
    /// @custom:selector    0x473a9ad9
    /// @custom:signature   Unresolved_473a9ad9(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_473a9ad9(uint256 arg0, uint256 arg1) public payable {
        require(arg1 == arg1);
        (bool success, bytes memory ret0) = address(config / 0x01).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(address(msg.sender) == (address(var_i)));
        require(0x19 < var_b.length);
        require(address(msg.sender) == (address(var_j)));
        require(0x0c < var_b.length);
        require((arg0 == ((arg0 * 0x23) / 0x23)) | !0x23);
        require(0x64);
        var_b = var_b + 0x60;
        uint256 var_q = (arg0 * 0x23) / 0x64;
        (bool success, bytes memory ret0) = address(ROUTER).Unresolved_d06ca61f(var_q); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_i == ((var_i * 0x5a) / 0x5a) | !0x5a);
        require(0x64);
        var_s = address(ROUTER);
        (bool success, bytes memory ret0) = address(var_i).Unresolved_095ea7b3(var_s); // call
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        var_v = address(this);
        (bool success, bytes memory ret0) = address(var_o).Unresolved_70a08231(var_v); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!0xc8 > (block.timestamp + 0xc8));
        uint256 var_y = (arg0 * 0x23) / 0x64;
        (bool success, bytes memory ret0) = address(ROUTER).Unresolved_38ed1739(var_y); // call
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        address var_aa = address(this);
        (bool success, bytes memory ret0) = address(var_o).Unresolved_70a08231(var_aa); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!(var_b.length - var_b.length) > var_b.length);
    }
    
    /// @custom:selector    0x6f016bc8
    /// @custom:signature   Unresolved_6f016bc8(address arg0) public payable returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_6f016bc8(address arg0) public payable returns (bool) {
        require(arg0 == (address(arg0)));
        (bool success, bytes memory ret0) = address(config / 0x01).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        address var_d = address(arg0);
        require(!bytes1(storage_map_f[var_d]));
        return 0x01;
        require(0x07 < var_b.length);
        address var_k = address(arg0);
        (bool success, bytes memory ret0) = address(var_l).Unresolved_01750152(var_k); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x40);
        require(var_m == (var_m));
        require(!var_m);
        return 0x01;
        require(0x04 < var_b.length);
        address var_o = address(arg0);
        (bool success, bytes memory ret0) = address(var_p).Unresolved_70a08231(var_o); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0);
        require(0x13 < var_b.length);
        address var_r = address(arg0);
        (bool success, bytes memory ret0) = address(var_s).Unresolved_db2c50a8(var_r); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        require(!var_b.length);
        return 0;
        return 0x01;
        return 0x01;
    }
    
    /// @custom:selector    0xdcd15367
    /// @custom:signature   teamPower(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function teamPower(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_a[var_b];
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(address(owner), address(arg0));
        owner = (address(arg0)) | (uint96(owner));
    }
    
    /// @custom:selector    0xdf526413
    /// @custom:signature   Unresolved_df526413(address arg0) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_df526413(address arg0) public payable returns (uint256) {
        require(arg0 == (address(arg0)));
        (bool success, bytes memory ret0) = address(config / 0x01).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0x02 < var_b.length);
        address var_j = address(arg0);
        (bool success, bytes memory ret0) = address(var_k).Unresolved_a0571075(var_j); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0 - var_b.length);
        require(0x04 < var_b.length);
        address var_n = address(var_o);
        (bool success, bytes memory ret0) = address(var_p).Unresolved_c6c70c0c(var_n); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        require(!var_b.length);
        require(0x01);
        return 0;
        return 0;
    }
    
    /// @custom:selector    0x2b606426
    /// @custom:signature   Unresolved_2b606426(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2b606426(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_a[var_b];
    }
    
    /// @custom:selector    0x714e4b9b
    /// @custom:signature   setEveryDiv(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setEveryDiv(uint256 arg0) public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(arg0 > 0, "Count must be greater than zero");
        everyDiv = arg0;
    }
    
    /// @custom:selector    0x280e31cc
    /// @custom:signature   userLevel(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function userLevel(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_a[var_b];
    }
    
    /// @custom:selector    0x0e35201b
    /// @custom:signature   Unresolved_0e35201b(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_0e35201b(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0x04 < var_b.length);
        require(address(msg.sender) == (address(var_i)));
        address var_d = address(arg0);
        require(!0x01 > storage_map_f[var_d]);
        var_d = address(arg0);
        require(storage_map_f[var_d]);
        require(!arg1);
        require(0x13 < var_b.length);
        address var_l = address(arg0);
        (bool success, bytes memory ret0) = address(var_m).Unresolved_db2c50a8(var_l); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        require(var_b.length);
        (bool success, bytes memory ret0) = address(config / 0x01).getAllConfig(); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0x02 < var_b.length);
        address var_q = address(arg0);
        (bool success, bytes memory ret0) = address(var_r).Unresolved_a0571075(var_q); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0 - var_b.length);
        require(0x04 < var_b.length);
        address var_u = address(var_v);
        (bool success, bytes memory ret0) = address(var_i).Unresolved_c6c70c0c(var_u); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        require(!var_b.length);
        require(0x01);
        require(!0 > 0x02);
        require(0x02 < var_b.length);
        var_u = address(arg0);
        (bool success, bytes memory ret0) = address(var_r).Unresolved_4a9fefc7(var_u); // staticcall
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
    }
    
    /// @custom:selector    0x2c00983e
    /// @custom:signature   Unresolved_2c00983e(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_2c00983e(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0xec715a31
    /// @custom:signature   releaseToken() public payable
    function releaseToken() public payable {
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0x14 < var_b.length);
        require(address(msg.sender) == (address(var_i)));
        require(0 - _current);
        require(!(_count - _current) > _count);
        require(everyDiv < (_count - _current));
        require(!_current > (everyDiv + _current));
        require(!_current < (everyDiv + _current));
        require(_current < getUserCount);
        var_d = 0x03;
        require(address(storage_map_u[var_d]));
        address var_d = address(storage_map_u[var_d]);
        var_b = 0x20 + (var_b + (0x20 * storage_map_f[var_d]));
        require(!storage_map_f[var_d]);
        var_d = keccak256(var_d);
        require((var_b + 0x20) + (0x20 * storage_map_f[var_d]) > (0x20 + (var_b + 0x20)));
        var_d = address(storage_map_u[var_d]);
        require(0 < storage_map_f[var_d]);
        var_d = keccak256(var_d);
        require(!(storage_map_v[var_d]) < 0x64);
        require(!bytes1(status));
        var_d = address(storage_map_u[var_d]);
        require(0 < storage_map_f[var_d]);
        var_d = keccak256(var_d);
        require(!(0x64 - (storage_map_v[var_d])) > 0x64);
        var_d = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require((0x64 - (storage_map_v[var_d])) == ((0x64 - (storage_map_v[var_d])) * (var_m) / (var_m)) | (!var_m));
        require(0x64);
        var_d = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!0 > (((0x64 - (storage_map_v[var_d])) * (var_m) / 0x64) + 0));
        var_d = address(storage_map_u[var_d]);
        require(0 < storage_map_f[var_d]);
        var_d = keccak256(var_d);
        storage_map_w[var_d] = 0x64;
        var_d = address(storage_map_u[var_d]);
        require(0 < storage_map_f[var_d]);
        var_d = address(storage_map_u[var_d]);
        require(!(storage_map_f[var_d] - (storage_map_v[var_d])) > storage_map_f[var_d]);
        require(0x64);
        require(!0);
        require(0x01);
        require((0 == 0) | !0x41);
        require(0x64);
        var_b = var_b + 0x60;
        require(0x0c < var_b.length);
        uint256 var_t = 0;
        (bool success, bytes memory ret0) = address(0x10ed43c718714eb63d5aa57b78b54704e256024e).Unresolved_d06ca61f(var_t); // staticcall
        require(0x0c < var_b.length);
        var_t = address(var_w);
        (bool success, bytes memory ret0) = address(var_p).Unresolved_a9059cbb(var_t); // call
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(var_b.length == var_b.length);
        var_d = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0x01 < var_d);
        var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(0x01);
        require(_current + 0x01);
        require(_current < _count);
        _count = 0;
        _current = 0;
    }
    
    /// @custom:selector    0xb110544f
    /// @custom:signature   updateUserLevel(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function updateUserLevel(address arg0) public payable {
        require(arg0 == (address(arg0)));
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        uint256 var_b = var_b + (uint248(ret0.length + 0x1f));
        require(!((var_b + ret0.length) - var_b) < 0x20);
        require(!var_b.length > 0xffffffffffffffff);
        require((var_b + ret0.length) > ((var_b + var_b.length) + 0x1f));
        require(!(var_c) > 0xffffffffffffffff);
        require(!((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) < var_b) | ((var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_b = var_b + (uint248((0x20 + (var_f << 0x05)) + 0x1f));
        require(!(0x20 + ((var_b + var_b.length) + (var_f << 0x05))) > (var_b + ret0.length));
        require(!(0x20 + (var_b + var_b.length)) < (0x20 + ((var_b + var_b.length) + (var_f << 0x05))));
        require(var_h == (address(var_h)));
        require(0x13 < var_b.length);
        require(address(msg.sender) == (address(var_i)));
        address var_d = address(arg0);
        require(!0x03 > storage_map_f[var_d]);
        var_d = address(arg0);
        storage_map_f[var_d] = 0x03;
    }
    
    /// @custom:selector    0xfa302aec
    /// @custom:signature   Unresolved_fa302aec(uint256 arg0, address arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_fa302aec(uint256 arg0, address arg1) public payable {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        uint256 var_c = var_c + (uint248((0x20 + (arg0 << 0x05)) + 0x1f));
        require(!((0x04 + arg0) + 0x20) < ((0x04 + arg0) + (arg0 << 0x05) + 0x20));
        require((arg0 + 0x20) == (address(arg0 + 0x20)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        var_f = 0x20;
        require(!var_c.length);
        require(!airDropCount < 0x03e8);
        address var_a = address(var_i);
        storage_map_x[var_a] = 0x01 + storage_map_x[var_a];
        var_a = keccak256(var_a);
        storage_map_y[var_a] = 0x056bc75e2d63100000;
        var_a = address(var_i);
        storage_map_x[var_a] = 0x01 + storage_map_x[var_a];
        var_a = keccak256(var_a);
        storage_map_y[var_a] = 0;
        var_a = address(var_i);
        storage_map_x[var_a] = storage_map_x[var_a] + 0x01;
        var_a = keccak256(var_a);
        storage_map_y[var_a] = 0;
        require(!0);
        (bool success, bytes memory ret0) = address(config).getAllConfig(); // staticcall
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(!var_c.length > 0xffffffffffffffff);
        require((var_c + ret0.length) > ((var_c + var_c.length) + 0x1f));
        require(!(var_k) > 0xffffffffffffffff);
        require(!((var_c + (uint248((0x20 + (var_l << 0x05)) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (var_l << 0x05)) + 0x1f))) > 0xffffffffffffffff));
        var_c = var_c + (uint248((0x20 + (var_l << 0x05)) + 0x1f));
        require(!(0x20 + ((var_c + var_c.length) + (var_l << 0x05))) > (var_c + ret0.length));
        require(!(0x20 + (var_c + var_c.length)) < (0x20 + ((var_c + var_c.length) + (var_l << 0x05))));
        require(var_n == (address(var_n)));
        var_a = address(var_i);
        var_c = var_f + (var_c + (0x20 * storage_map_x[var_a]));
        require(!storage_map_x[var_a]);
        require(0 < 0x3635c9adc5dea00000);
        require(0x15 < var_c.length);
        address var_q = address(var_i);
        require(address(var_s).code.length);
        (bool success, bytes memory ret0) = address(var_s).Unresolved_c9f6712a(var_q); // call
        if (!airDropCount > (0x01 + airDropCount)) {
            airDropCount = 0x01 + airDropCount;
            var_a = address(var_i);
            if (storage_map_x[var_a]) {
            }
            require(!airDropCount > (0x01 + airDropCount));
            var_a = keccak256(var_a);
            require(0 < storage_map_x[var_a]);
            var_a = address(var_i);
            require(!0 > (storage_map_z[var_a] + 0));
            var_a = keccak256(var_a);
            require(0x01 < storage_map_x[var_a]);
        }
    }
    
    /// @custom:selector    0xadee8014
    /// @custom:signature   Unresolved_adee8014(uint256 arg0, uint256 arg1) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_adee8014(uint256 arg0, uint256 arg1) public view returns (uint256) {
        uint256 var_b = arg0;
        require(arg1 < storage_map_a[var_b]);
        var_b = keccak256(var_b);
        return storage_map_b[var_b];
    }
    
    /// @custom:selector    0x1e359efd
    /// @custom:signature   Unresolved_1e359efd(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_1e359efd(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * storage_map_x[var_a]));
        require(!storage_map_x[var_a]);
        var_a = keccak256(var_a);
        require((var_c + 0x20) + (0x20 * storage_map_x[var_a]) > (0x20 + (var_c + 0x20)));
        return abi.encodePacked(0x20, var_c.length);
    }
    
    /// @custom:selector    0xb0467deb
    /// @custom:signature   getUser(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getUser(uint256 arg0) public view returns (address) {
        require(arg0 < getUserCount);
        var_a = 0x03;
        return address(storage_map_aa[var_a]);
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        emit OwnershipTransferred(address(owner), 0);
        owner = uint96(owner);
    }
}