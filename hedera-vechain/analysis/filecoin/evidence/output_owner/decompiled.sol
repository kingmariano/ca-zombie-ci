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
    mapping(bytes32 => bytes32) storage_map_o;
    uint256 storage_map_c[storage_map_a[var_a] - 0x01];
    mapping(bytes32 => bytes32) storage_map_w;
    mapping(bytes32 => bytes32) storage_map_d;
    mapping(bytes32 => bytes32) storage_map_v;
    uint256 public minDelay;
    mapping(bytes32 => bytes32) storage_map_h;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_q;
    mapping(bytes32 => bytes32) storage_map_r;
    mapping(bytes32 => bytes32) storage_map_t;
    mapping(bytes32 => bytes32) storage_map_s;
    mapping(bytes32 => bytes32) storage_map_j;
    bytes32 store_b;
    mapping(bytes32 => bytes32) storage_map_k;
    mapping(bytes32 => bytes32) storage_map_p;
    uint256 public threshold;
    mapping(bytes32 => bytes32) storage_map_m;
    bytes32 store_f;
    mapping(bytes32 => bytes32) storage_map_x;
    mapping(bytes32 => bytes32) storage_map_l;
    bytes32 store_i;
    mapping(bytes32 => bytes32) storage_map_n;
    mapping(bytes32 => bytes32) storage_map_c;
    
    event Activate(address, bytes32);
    event Disable(address, address);
    event UnBan(address, bytes32);
    event MinDelayChange(uint256, uint256);
    event Enable(address, address);
    event Ban(address, bytes32);
    event Sign(address, bytes32);
    event ThresholdChange(uint256, uint256);
    event Cancel(address, bytes32);
    
    /// @custom:selector    0xe6c09edf
    /// @custom:signature   disable(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function disable(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(this) == msg.sender);
        address var_a = address(arg0);
        require(!storage_map_a[var_a], "Msign.Disable nonexist");
        require(!((storage_map_a[var_a] - 0x01) > storage_map_a[var_a]), "Msign.Disable nonexist");
        require(!((store_b - 0x01) > store_b), "Msign.Disable nonexist");
        require((store_b - 0x01) == (storage_map_a[var_a] - 0x01), "Msign.Disable nonexist");
        require((store_b - 0x01) < store_b, "Msign.Disable nonexist");
        var_a = 0x01;
        require((storage_map_a[var_a] - 0x01) < store_b, "Msign.Disable nonexist");
        var_a = 0x01;
        storage_map_c[storage_map_a[var_a] - 0x01] = storage_map_d[var_a];
        var_a = storage_map_d[var_a];
        storage_map_a[var_a] = storage_map_a[var_a];
        require(store_b, "Msign.Disable nonexist");
        var_a = 0x01;
        storage_map_d[var_a] = 0;
        store_b = store_b - 0x01;
        var_a = address(arg0);
        storage_map_a[var_a] = 0;
        require(0x01, "Msign.Disable nonexist");
        require(!(store_b < 0x01), "Msign.Invalid set");
        require(!(threshold > store_b), "threshold must <= signer length");
        emit Disable(msg.sender, address(arg0));
        require(0, "Msign.Invalid set");
        require(!(store_b < 0x01), "Msign.Invalid set");
    }
    
    /// @custom:selector    0x30bffd34
    /// @custom:signature   unban(bytes4 arg0) public payable
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function unban(bytes4 arg0) public payable {
        require(arg0 == (uint32(arg0)));
        require(address(this) == msg.sender);
        uint32 var_a = uint32(arg0);
        require(!storage_map_a[var_a], "unban function fail");
        require(!(((storage_map_a[var_a] - 0x01) > storage_map_a[var_a])), "unban function fail");
        require(!(((store_f - 0x01) > store_f)), "unban function fail");
        require((store_f - 0x01) == (storage_map_a[var_a] - 0x01), "unban function fail");
        require((store_f - 0x01) < store_f, "unban function fail");
        var_a = 0x05;
        require((storage_map_a[var_a] - 0x01) < store_f, "unban function fail");
        var_a = 0x05;
        storage_map_c[storage_map_a[var_a] - 0x01] = storage_map_g[var_a];
        var_a = storage_map_g[var_a];
        storage_map_a[var_a] = storage_map_a[var_a];
        require(store_f, "unban function fail");
        var_a = 0x05;
        storage_map_g[var_a] = 0;
        store_f = store_f - 0x01;
        var_a = uint32(arg0);
        storage_map_a[var_a] = 0;
        require(0x01, "unban function fail");
        emit UnBan(msg.sender, uint32(arg0));
        require(0, "unban function fail");
        emit UnBan(msg.sender, uint32(arg0));
    }
    
    /// @custom:selector    0xc4d252f5
    /// @custom:signature   cancel(bytes32 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function cancel(bytes32 arg0) public payable {
        require(address(this) == msg.sender);
        uint256 var_a = arg0;
        require(!(storage_map_h[var_a]), "Msign.Proposal has been remove or executed");
        var_a = arg0;
        storage_map_h[var_a] = 0x02;
        var_a = arg0;
        require(!storage_map_a[var_a]);
        require(!(storage_map_a[var_a] - 0x01) > storage_map_a[var_a]);
        require(!(store_i - 0x01) > store_i);
        require((store_i - 0x01) == (storage_map_a[var_a] - 0x01));
        require((store_i - 0x01) < store_i);
        var_a = 0x03;
        require((storage_map_a[var_a] - 0x01) < store_i);
        var_a = 0x03;
        storage_map_c[storage_map_a[var_a] - 0x01] = storage_map_j[var_a];
        var_a = storage_map_j[var_a];
        storage_map_a[var_a] = storage_map_a[var_a];
        require(store_i);
        var_a = 0x03;
        storage_map_j[var_a] = 0;
        store_i = store_i - 0x01;
        var_a = arg0;
        storage_map_a[var_a] = 0;
        emit Cancel(msg.sender, arg0);
        emit Cancel(msg.sender, arg0);
    }
    
    /// @custom:selector    0x351ff34a
    /// @custom:signature   Unresolved_351ff34a(address arg0, uint256 arg1) public payable returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_351ff34a(address arg0, uint256 arg1) public payable returns (uint256) {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        if (!(arg1) > 0xffffffffffffffff) {
            require(!(arg1 > 0xffffffffffffffff), "Msign.Invalid args");
            uint256 var_c = var_c + (uint248(0x3f + (arg1 + 0x1f)));
            address var_a = address(msg.sender);
            require(!(((var_c + (uint248(0x3f + (arg1 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg1 + 0x1f)))) > 0xffffffffffffffff)), "Msign.Invalid args");
            require(storage_map_a[var_a], "Msign.Invalid args");
            require(address(arg0), "Msign.Invalid args");
            var_c = 0x34 + (var_c.length + (0x20 + var_c));
            var_a = keccak256(var_k);
            storage_map_a[var_a] = (address(arg0)) | (uint96(storage_map_a[var_a]));
            require(!(var_c.length < 0x04), "Msign.Invalid args");
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(var_c.length > 0xffffffffffffffff), "Msign.Invalid args");
            require(bytes1(storage_map_k[var_a]), "Msign.Invalid args");
            var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(bytes1(storage_map_k[var_a]) - ((storage_map_k[var_a] >> 0x01) < 0x20), "Msign.Invalid args");
            var_a = 0x01 + keccak256(var_a);
            require(!((storage_map_k[var_a] >> 0x01) > 0x1f), "Msign.Invalid args");
            require(!(var_c.length < 0x20), "Msign.Invalid args");
            require(!(keccak256(var_a) + ((var_c.length + 0x1f) >> 0x05) < (keccak256(var_a) + (((storage_map_k[var_a] >> 0x01) + 0x1f) >> 0x05))), "Msign.Invalid args");
            var_a = 0x01 + keccak256(var_a);
            require((var_c.length > 0x1f) == 0x01, "Msign.Invalid args");
            require(!(0 < (uint248(var_c.length))), "Msign.Invalid args");
            storage_map_a[var_a] = (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (bytes1(var_c.length << 0x03)))) & (var_l);
            storage_map_k[var_a] = (var_c.length << 0x01) + 0x01;
            var_a = keccak256(var_k);
            storage_map_l[var_a] = block.number;
            require(!(uint248(var_c.length) < var_c.length), "Msign.Invalid args");
            emit Activate(msg.sender, keccak256(var_k));
            return keccak256(var_k);
            store_i = 0x01 + store_i;
            var_a = 0x03;
            storage_map_m[var_a] = keccak256(var_k);
            var_a = keccak256(var_k);
            storage_map_a[var_a] = store_i;
            emit Activate(msg.sender, keccak256(var_k));
            return keccak256(var_k);
            require(storage_map_a[var_a], "Msign.Invalid args");
        }
    }
    
    /// @custom:selector    0x5bfa1b68
    /// @custom:signature   enable(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function enable(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(this) == msg.sender);
        address var_a = address(arg0);
        require(storage_map_a[var_a], "Msign.Duplicate signer");
        require(0, "Msign.Duplicate signer");
        emit Enable(msg.sender, address(arg0));
        store_b = 0x01 + store_b;
        var_a = 0x01;
        storage_map_n[var_a] = address(arg0);
        var_a = address(arg0);
        storage_map_a[var_a] = store_b;
        require(0x01, "Msign.Duplicate signer");
        emit Enable(msg.sender, address(arg0));
    }
    
    /// @custom:selector    0xcf6106ed
    /// @custom:signature   banList() public view returns (bytes memory)
    function banList() public view returns (bytes memory) {
        if (!store_f > 0xffffffffffffffff) {
            uint256 var_d = var_d + (0x20 + (0x20 * store_f));
            if (!store_f) {
                if (!0 < store_f) {
                    if (0 < store_f) {
                        var_a = 0x05;
                        if (0x01) {
                            return abi.encodePacked(0x20, var_d.length);
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x799cd333
    /// @custom:signature   sign(bytes32 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function sign(bytes32 arg0) public payable {
        address var_a = address(msg.sender);
        require(storage_map_a[var_a], "Msign.Duplicate sign");
        var_a = msg.sender;
        require(!storage_map_a[var_a], "Msign.Duplicate sign");
        var_a = msg.sender;
        storage_map_a[var_a] = 0x01;
        emit Sign(msg.sender, arg0);
    }
    
    /// @custom:selector    0x78bc635b
    /// @custom:signature   ban(bytes4 arg0) public payable
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function ban(bytes4 arg0) public payable {
        require(arg0 == (uint32(arg0)));
        require(address(this) == msg.sender);
        uint32 var_a = uint32(arg0);
        require(storage_map_a[var_a], "ban function fail");
        require(0, "ban function fail");
        emit Ban(msg.sender, uint32(arg0));
        store_f = 0x01 + store_f;
        var_a = 0x05;
        storage_map_p[var_a] = uint32(arg0);
        var_a = uint32(arg0);
        storage_map_a[var_a] = store_f;
        require(0x01, "ban function fail");
        emit Ban(msg.sender, uint32(arg0));
    }
    
    /// @custom:selector    0x32ed5b12
    /// @custom:signature   proposals(bytes32 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function proposals(bytes32 arg0) public view returns (bytes memory) {
        uint256 var_b = arg0;
        require(bytes1(storage_map_q[var_b]));
        require(bytes1(storage_map_q[var_b]) - ((storage_map_q[var_b] >> 0x01) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_d = var_d + (0x20 + (((0x1f + (storage_map_q[var_b] >> 0x01)) / 0x20) * 0x20));
        require(bytes1(storage_map_q[var_b]));
        require(bytes1(storage_map_q[var_b]) - ((storage_map_q[var_b] >> 0x01) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_q[var_b]) >> 0x01);
        require(0x1f < (storage_map_q[var_b] >> 0x01));
        var_b = keccak256(var_b) + 0x01;
        require((0x20 + var_d) + (storage_map_q[var_b] >> 0x01) > (0x20 + (0x20 + var_d)));
        return abi.encodePacked(address(storage_map_r[var_b]), 0x80, storage_map_s[var_b], storage_map_t[var_b], var_d.length);
    }
    
    /// @custom:selector    0x27dcc4ef
    /// @custom:signature   Unresolved_27dcc4ef(uint256 arg0) public pure returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_27dcc4ef(uint256 arg0) public pure returns (bool) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        uint256 var_c = var_c + (uint248(0x3f + (arg0 + 0x1f)));
        require(0x03 < var_c.length);
        require(0x02 < var_c.length);
        require(var_c.length);
        return uint32(bytes1(var_g) | (bytes1(var_h) >> 0x08) | (bytes1(var_i) >> 0x10) | (bytes1(var_j) >> 0x18));
    }
    
    /// @custom:selector    0x960bfe04
    /// @custom:signature   setThreshold(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setThreshold(uint256 arg0) public payable {
        require(address(this) == msg.sender);
        require(arg0 > 0, "threshold must <= signer length");
        require(!(arg0 > store_b), "threshold must <= signer length");
        emit ThresholdChange(threshold, arg0);
        threshold = arg0;
    }
    
    /// @custom:selector    0xb61d07ae
    /// @custom:signature   isBanFunc(bytes4 arg0) public view returns (bool)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function isBanFunc(bytes4 arg0) public view returns (bool) {
        require(arg0 == (uint32(arg0)));
        uint32 var_a = uint32(arg0);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x96c08766
    /// @custom:signature   unDoneIdList() public view returns (bytes memory)
    function unDoneIdList() public view returns (bytes memory) {
        if (!store_i > 0xffffffffffffffff) {
            uint256 var_d = var_d + (0x20 + (0x20 * store_i));
            if (!store_i) {
                if (!0 < store_i) {
                    if (0 < store_i) {
                        var_a = 0x03;
                        if (0x01) {
                            return abi.encodePacked(0x20, var_d.length);
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0xe751f271
    /// @custom:signature   execute(bytes32 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function execute(bytes32 arg0) public payable {
        require(!(0 < store_b), "Msign.Threshold unreached");
        require(0 < store_b, "Msign.Threshold unreached");
        var_a = address(storage_map_o[var_a]);
        require(!(0 > (storage_map_a[var_a] + 0)), "Msign.Threshold unreached");
        require(0x01, "Msign.Threshold unreached");
        require(!(0 < threshold), "Msign.Threshold unreached");
        var_a = arg0;
        require(bytes1(storage_map_v[var_a]), "Msign.timelock unreached");
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20), "Msign.timelock unreached");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_h = var_h + (0x20 + (((0x1f + (storage_map_v[var_a] >> 0x01)) / 0x20) * 0x20));
        require(bytes1(storage_map_v[var_a]), "Msign.timelock unreached");
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20), "Msign.timelock unreached");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_v[var_a] >> 0x01), "Msign.timelock unreached");
        require(0x1f < (storage_map_v[var_a] >> 0x01), "Msign.timelock unreached");
        var_a = keccak256(var_a) + 0x01;
        require((0x20 + var_h) + (storage_map_v[var_a] >> 0x01) > (0x20 + (0x20 + var_h)), "Msign.timelock unreached");
        require(0x03 < var_h.length, "Msign.timelock unreached");
        require(0x02 < var_h.length, "Msign.timelock unreached");
        require(var_h.length, "Msign.timelock unreached");
        var_a = uint32(bytes1(var_j) | (bytes1(var_k) >> 0x08) | (bytes1(var_l) >> 0x10) | (bytes1(var_m) >> 0x18));
        require(!storage_map_a[var_a], "Msign.timelock unreached");
        require(!(storage_map_w[var_a] > (0 + (storage_map_w[var_a]))), "Msign.timelock unreached");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!((0 + (storage_map_w[var_a])) > block.number), "Msign.timelock unreached");
        var_a = arg0;
        require(!(storage_map_h[var_a]), "Msign.Proposal has been remove or executed");
        var_a = arg0;
        storage_map_x[var_a] = 0x01;
        var_a = arg0;
        require(!storage_map_a[var_a]);
        require(!(storage_map_a[var_a] - 0x01) > storage_map_a[var_a]);
        require(!(store_i - 0x01) > store_i);
        require((store_i - 0x01) == (storage_map_a[var_a] - 0x01));
        require((store_i - 0x01) < store_i);
        var_a = 0x03;
        require((storage_map_a[var_a] - 0x01) < store_i);
        var_a = 0x03;
        storage_map_c[storage_map_a[var_a] - 0x01] = storage_map_j[var_a];
        var_a = storage_map_j[var_a];
        storage_map_a[var_a] = storage_map_a[var_a];
        require(store_i);
    }
    
    /// @custom:selector    0x29ee11b2
    /// @custom:signature   getTimeExecute(bytes32 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getTimeExecute(bytes32 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        require(bytes1(storage_map_v[var_a]));
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint256 var_d = var_d + (0x20 + (((0x1f + (storage_map_v[var_a] >> 0x01)) / 0x20) * 0x20));
        require(bytes1(storage_map_v[var_a]));
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_v[var_a]) >> 0x01);
        require(0x1f < (storage_map_v[var_a] >> 0x01));
        var_a = keccak256(var_a) + 0x01;
        require((0x20 + var_d) + (storage_map_v[var_a] >> 0x01) > (0x20 + (0x20 + var_d)));
        require(0x03 < var_d.length);
        require(0x02 < var_d.length);
        require(var_d.length);
        var_a = uint32(bytes1(var_g) | (bytes1(var_h) >> 0x08) | (bytes1(var_i) >> 0x10) | (bytes1(var_j) >> 0x18));
        require(!storage_map_a[var_a]);
        require(!(storage_map_w[var_a]) > (0 + (storage_map_w[var_a])));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        return 0 + (storage_map_w[var_a]);
    }
    
    /// @custom:selector    0x61c41934
    /// @custom:signature   signable(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function signable(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0x77e1ab03
    /// @custom:signature   mulsignweight(bytes32 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function mulsignweight(bytes32 arg0) public view returns (uint256) {
        require(!0 < store_b);
        require(0 < store_b);
        var_a = address(storage_map_o[var_a]);
        require(!0 > (storage_map_a[var_a] + 0));
        require(0x01);
        return 0;
    }
    
    /// @custom:selector    0xb9892326
    /// @custom:signature   Unresolved_b9892326(address arg0, uint256 arg1, uint256 arg2) public pure returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_b9892326(address arg0, uint256 arg1, uint256 arg2) public pure returns (uint256) {
        require(arg0 == (address(arg0)));
        require(!arg2 > 0xffffffffffffffff);
        require(!(arg2) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg2 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg2 + 0x1f)))) > 0xffffffffffffffff));
        uint256 var_c = var_c + (uint248(0x3f + (arg2 + 0x1f)));
        return keccak256(var_j);
    }
    
    /// @custom:selector    0x29ee00ac
    /// @custom:signature   canSign(address arg0, bytes32 arg1) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function canSign(address arg0, bytes32 arg1) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        require(!storage_map_a[var_a]);
        var_a = arg1;
        require(bytes1(storage_map_v[var_a]));
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        address var_d = var_d + (0x20 + (((0x1f + (storage_map_v[var_a] >> 0x01)) / 0x20) * 0x20));
        require(bytes1(storage_map_v[var_a]));
        require(bytes1(storage_map_v[var_a]) - ((storage_map_v[var_a] >> 0x01) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_v[var_a]) >> 0x01);
        require(0x1f < (storage_map_v[var_a] >> 0x01));
        var_a = keccak256(var_a) + 0x01;
        require((0x20 + var_d) + (storage_map_v[var_a] >> 0x01) > (0x20 + (0x20 + var_d)));
        require(!arg1 == (keccak256(var_j)));
        require(storage_map_x[var_a]);
        return 0;
        var_a = address(arg0);
        return !storage_map_a[var_a];
        require(!arg1 == (keccak256(var_j)));
        var_a = address(arg0);
        return !storage_map_a[var_a];
        return 0;
        return 0;
    }
    
    /// @custom:selector    0xba29482f
    /// @custom:signature   setMinDelay(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setMinDelay(uint256 arg0) public payable {
        require(address(this) == msg.sender);
        emit MinDelayChange(minDelay, arg0);
        minDelay = arg0;
    }
    
    /// @custom:selector    0x46f0975a
    /// @custom:signature   signers() public view returns (bytes memory)
    function signers() public view returns (bytes memory) {
        if (!store_b > 0xffffffffffffffff) {
            uint256 var_d = var_d + (0x20 + (0x20 * store_b));
            if (!store_b) {
                if (!0 < store_b) {
                    if (0 < store_b) {
                        var_a = 0x01;
                        if (0x01) {
                            return abi.encodePacked(0x20, var_d.length);
                        }
                    }
                }
            }
        }
    }
}