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
    uint256 public constant pool = 1418314935965746761362003521499603841435224473645;
    
    uint256 public totalWeight;
    bool public paused;
    mapping(bytes32 => bytes32) storage_map_f;
    uint256 store_c;
    mapping(bytes32 => bytes32) storage_map_d;
    bytes32 store_e;
    bytes32 store_k;
    bytes32 store_g;
    bytes32 store_l;
    bytes32 store_m;
    bytes32 store_h;
    bytes32 store_i;
    bytes32 store_j;
    
    error InvalidAddress();
    event FeeTokensSet(address[]);
    event Paused(address);
    event Unpaused(address);
    event FeeWithdrawn();
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x767bc1bf
    /// @custom:signature   setSplits(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function setSplits(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3) public view {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(!arg0 > ~(arg1));
    }
    
    /// @custom:selector    0x363bf964
    /// @custom:signature   Unresolved_363bf964(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_363bf964(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0x8ef4403c
    /// @custom:signature   feeTokens(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function feeTokens(uint256 arg0) public view returns (address) {
        require(arg0 < store_c);
        var_a = 0x02;
        return address(storage_map_d[var_a]);
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        paused = (address(arg0)) | (uint96(paused));
        emit OwnershipTransferred(address(paused), address(arg0));
    }
    
    /// @custom:selector    0xe941fa78
    /// @custom:signature   withdrawFee() public payable
    function withdrawFee() public payable {
        require(!(bytes1(paused / 0x010000000000000000000000000000000000000000)), "ReentrancyGuard: reentrant call");
        require(store_e - 0x02, "ReentrancyGuard: reentrant call");
        store_e = 0x02;
        require(!0 < store_c);
        require(0 < store_c);
        var_e = 0x02;
        address var_b = address(storage_map_f[var_e]);
        (bool success, bytes memory ret0) = address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).Unresolved_1ce9cb8f(var_b); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(!var_f.length);
        require(0x01);
        var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        address var_c = address(storage_map_f[var_e]);
        require(address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).code.length);
        (bool success, bytes memory ret0) = address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).{ value: 0 ether }Unresolved_c879c6d8(var_c); // call
        emit FeeWithdrawn();
        store_e = 0x01;
    }
    
    /// @custom:selector    0x8456cb59
    /// @custom:signature   pause() public payable
    function pause() public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(!(bytes1(paused / 0x010000000000000000000000000000000000000000)), "Pausable: paused");
        paused = 0x010000000000000000000000000000000000000000 | (uint248(paused));
        emit Paused(address(msg.sender));
    }
    
    /// @custom:selector    0x3f4ba83a
    /// @custom:signature   unpause() public payable
    function unpause() public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(bytes1(paused / 0x010000000000000000000000000000000000000000), "Pausable: not paused");
        paused = uint248(paused);
        emit Unpaused(address(msg.sender));
    }
    
    /// @custom:selector    0xb293fdc5
    /// @custom:signature   setFeeTokens(address[] arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setFeeTokens(address[] arg0) public payable {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        uint256 var_e = var_e + (0x20 + (0x20 * (arg0)));
        var_f = msg.data[36:36];
        require(address(var_f) - 0, CustomError_e6c4247b());
        require(0x01, CustomError_e6c4247b());
        store_c = var_e.length;
        var_h = 0x02;
        require(!var_e.length);
        require(!((var_e + 0x20) + (0x20 * var_e.length)) > (var_e + 0x20));
        require(!(keccak256(var_h) + store_c) > keccak256(var_h));
        emit FeeTokensSet(0x20, var_e.length);
    }
    
    /// @custom:selector    0xb069bec2
    /// @custom:signature   Unresolved_b069bec2() public payable
    function Unresolved_b069bec2() public payable {
        require(!(bytes1(paused / 0x010000000000000000000000000000000000000000)), "Pausable: paused");
        require(store_e - 0x02, "ReentrancyGuard: reentrant call");
        store_e = 0x02;
        require(address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).code.length);
        (bool success, bytes memory ret0) = address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).{ value: 0 ether }distributeSurplus(); // call
        require(!0 < store_c);
        require(0 < store_c);
        var_e = 0x02;
        address var_b = address(this);
        (bool success, bytes memory ret0) = address(storage_map_f[var_e]).Unresolved_70a08231(var_b); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(!(var_f.length) & (store_h > (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff / var_f.length)));
        require(0x64);
        require(!(var_f.length) & (store_i > (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff / var_f.length)));
        require(0x64);
        require(!(var_f.length) & (store_j > (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff / var_f.length)));
        require(0x64);
        require(!(var_f.length) & (store_k > (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff / var_f.length)));
        require(0x64);
        var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(var_f.length * store_h) / 0x64);
        var_c = 0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d;
        (bool success, bytes memory ret0) = address(storage_map_f[var_e]).{ value: 0 ether }Unresolved_095ea7b3(var_c); // call
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == var_f.length);
        require(0 < store_c);
        var_e = 0x02;
        var_d = address(storage_map_f[var_e]);
        uint256 var_k = 0;
        require(address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).code.length);
        (bool success, bytes memory ret0) = address(0xf86f70fb4959a9fcf1e7dd67a05dc0ac95c3802d).{ value: var_k ether }Unresolved_12fef692(var_d); // call
        require(!(var_f.length * store_i) / 0x64);
        var_d = address(store_l);
        (bool success, bytes memory ret0) = address(storage_map_f[var_e]).{ value: var_k ether }Unresolved_a9059cbb(var_d); // call
        require(!(var_f.length * store_j) / 0x64);
        var_d = address(store_m);
        (bool success, bytes memory ret0) = address(storage_map_f[var_e]).{ value: var_k ether }Unresolved_a9059cbb(var_d); // call
        require(!(var_f.length * store_k) / 0x64);
        var_d = address(store_g);
        (bool success, bytes memory ret0) = address(storage_map_f[var_e]).{ value: var_k ether }Unresolved_a9059cbb(var_d); // call
        require(0x01);
        store_e = 0x01;
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        paused = 0 | (uint96(paused));
        emit OwnershipTransferred(address(paused), 0);
    }
}