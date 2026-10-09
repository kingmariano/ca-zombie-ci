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
    address public getManager;
    address public unresolved_7457bbf7;
    mapping(bytes32 => bytes32) storage_map_d;
    bytes32 store_f;
    mapping(bytes32 => bytes32) storage_map_h;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_e;
    bytes32 storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff];
    
    event ManagerUpdate(address, address);
    event CommitMessage(string);
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_a[var_b]);
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)));
        require(!(address(getManager) == (address(arg0))), "New manager needs to be different.");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0x61455567
    /// @custom:signature   Unresolved_61455567(address arg0, uint256 arg1, uint256 arg2) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_61455567(address arg0, uint256 arg1, uint256 arg2) public payable {
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        require(address(msg.sender) == (address(getManager)), "Sender is not manager.");
        require(!(address(arg0)), "_delegate address is not a contract and is not address(0)");
        require(address(arg0).code.length, "_delegate address is not a contract and is not address(0)");
        uint256 var_e = var_e + (0x20 + (((0x1f + (arg1)) / 0x20) * 0x20));
        var_g = msg.data[36:36];
        if (!(var_e + 0x20) < (0x20 + (var_e + var_e.length))) {
            require(!((var_e + 0x20) < (0x20 + (var_e + var_e.length))), "FuncId clash.");
            require(!(0x3b == (var_j)), "FuncId clash.");
            require(address(arg0), "FuncId clash.");
            require(var_e.length < 0x20, "FuncId clash.");
            require((var_e.length + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0) < 0x20, "FuncId clash.");
            require(storage_map_d[var_o], "FuncId clash.");
            var_i = uint32(keccak256(var_j));
            storage_map_e[var_i] = (address(arg0) * 0x01) | (uint96(storage_map_e[var_i]));
            require(address(storage_map_e[var_i] / 0x01) == (address(arg0)), "FuncId clash.");
        }
        require(!(address(storage_map_e[var_i])), "FuncId clash.");
        var_i = uint32(keccak256(var_j));
        storage_map_e[var_i] = (address(arg0) * 0x01) | (uint96(storage_map_e[var_i]));
        store_f = store_f + 0x01;
        var_i = keccak256(var_i) + ((store_f + 0x01) - 0x01);
        if (0x1f < var_e.length) {
            storage_map_g[var_i] = 0x01 + (var_e.length + var_e.length);
            if (!var_e.length) {
                if (!((0x20 + var_e) + var_e.length) > (0x20 + var_e)) {
                    if (!(keccak256(var_i) + ((0x1f + (((0x0100 * (!storage_map_g[var_i])) - 0x01) & (storage_map_g[var_i]) / 0x02)) / 0x20)) > keccak256(var_i)) {
                        require(0x1f < var_e.length, "Function does not exist.");
                        require(!var_e.length, "Function does not exist.");
                        storage_map_d[var_o] = store_f;
                        require(!(((0x20 + var_e) + var_e.length) > (0x20 + var_e)), "Function does not exist.");
                    }
                    require(!(keccak256(var_i) + ((0x1f + (((0x0100 * (!bytes1(storage_map_g[var_i]))) - 0x01) & (storage_map_g[var_i]) / 0x02)) / 0x20) > keccak256(var_i)), "Function does not exist.");
                    require(var_e.length < 0x20, "Function does not exist.");
                    require(var_e.length < 0x20, "Function does not exist.");
                    require(storage_map_d[var_o], "Function does not exist.");
                    require((0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + storage_map_d[var_o]) == (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + store_f), "Function does not exist.");
                    require((0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + store_f) < store_f, "Function does not exist.");
                    store_f = store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
                    require((0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + storage_map_d[var_o]) < store_f, "Function does not exist.");
                    var_i = 0x03;
                    require(!(store_f > (store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Function does not exist.");
                    require(!((keccak256(var_i) + store_f) > ((store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) + keccak256(var_i))), "Function does not exist.");
                    require(var_e.length < 0x20, "Function does not exist.");
                }
            }
            storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff] = 0;
            require((var_e.length + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0) < 0x20, "Function does not exist.");
            var_i = (store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) + keccak256(var_i);
            require(0x1f < (((0x0100 * (!bytes1(storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]))) - 0x01) & (storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]) / 0x02), "Function does not exist.");
            require(!(keccak256(var_i) + ((0x1f + (((0x0100 * (!bytes1(storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]))) - 0x01) & (storage_map_h[store_f + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]) / 0x02)) / 0x20) > keccak256(var_i)), "Function does not exist.");
        }
        emit CommitMessage((0x20 + var_e) - var_e, (arg2));
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)));
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Sender must be the new manager.");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
}