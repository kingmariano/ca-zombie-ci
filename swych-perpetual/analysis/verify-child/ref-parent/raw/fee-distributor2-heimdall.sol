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
    bytes32 store_d;
    bool public paused;
    mapping(bytes32 => bytes32) storage_map_f;
    bytes public getRecipients;
    mapping(bytes32 => bytes32) storage_map_b;
    mapping(bytes32 => bytes32) storage_map_i;
    mapping(bytes32 => bytes32) storage_map_h;
    address storage_map_e[storage_map_b[var_e] - 0x01];
    uint256 store_g;
    mapping(bytes32 => bytes32) storage_map_e;
    
    error InvalidAddress();
    event Paused(address);
    event Unpaused(address);
    event RecipientUpdated(address, uint256);
    event RecipientAdded(address, uint256);
    event FeeTokensSet(address[]);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0xa08dc47e
    /// @custom:signature   setRecipient(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setRecipient(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(address(arg0), CustomError_3f75e463());
        require(0 - arg1, CustomError_3f75e463());
        address var_e = address(arg0);
        require(storage_map_b[var_e], CustomError_3f75e463());
        var_e = address(arg0);
        storage_map_b[var_e] = arg1;
        var_e = address(arg0);
        require(storage_map_b[var_e], CustomError_3f75e463());
        require(!(getRecipients > ~(arg1)), CustomError_3f75e463());
        var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!((getRecipients + arg1) < storage_map_b[var_e]), CustomError_3f75e463());
        var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        getRecipients = (getRecipients + arg1) - storage_map_b[var_e];
        require(!0x01, CustomError_3f75e463());
        emit RecipientAdded(address(arg0), arg1);
        emit RecipientUpdated(address(arg0), arg1);
    }
    
    /// @custom:selector    0x12a29198
    /// @custom:signature   removeRecipient(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function removeRecipient(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        require(storage_map_b[var_e], CustomError_62bb890e());
        require(0x01, CustomError_62bb890e());
        var_e = address(arg0);
        storage_map_b[var_e] = 0;
        var_e = address(arg0);
        require(!storage_map_b[var_e], CustomError_62bb890e());
        require(!(storage_map_b[var_e] < 0x01), CustomError_62bb890e());
        require(!(store_d < 0x01), CustomError_62bb890e());
        require((store_d - 0x01) == (storage_map_b[var_e] - 0x01), CustomError_62bb890e());
        require((store_d - 0x01) < store_d, CustomError_62bb890e());
        var_e = 0x03;
        require((storage_map_b[var_e] - 0x01) < store_d, CustomError_62bb890e());
        var_e = 0x03;
        storage_map_e[storage_map_b[var_e] - 0x01] = storage_map_f[var_e];
        var_e = storage_map_f[var_e];
        storage_map_b[var_e] = storage_map_b[var_e];
        require(store_d, CustomError_62bb890e());
        var_e = address(arg0);
        require(storage_map_b[var_e], CustomError_62bb890e());
    }
    
    /// @custom:selector    0x8ef4403c
    /// @custom:signature   feeTokens(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function feeTokens(uint256 arg0) public view returns (address) {
        require(arg0 < store_g);
        var_a = 0x02;
        return address(storage_map_h[var_a]);
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
    
    /// @custom:selector    0x15cd4cb5
    /// @custom:signature   distributeTreasury(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function distributeTreasury(uint256 arg0) public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(!store_d);
        require(getRecipients);
        require(!0 < store_g);
        require(0 < store_g);
        var_e = 0x02;
        address var_b = address(this);
        (bool success, bytes memory ret0) = address(storage_map_i[var_e]).Unresolved_70a08231(var_b); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(!(var_f.length) & (arg0 > (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff / var_f.length)));
        require(0x64);
        require(0 - ((var_f.length * arg0) / 0x64));
        require(!0 < store_d);
        require(0x01);
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
        store_g = var_e.length;
        var_h = 0x02;
        require(!var_e.length);
        require(!((var_e + 0x20) + (0x20 * var_e.length)) > (var_e + 0x20));
        require(!(keccak256(var_h) + store_g) > keccak256(var_h));
        emit FeeTokensSet(0x20, var_e.length);
    }
    
    /// @custom:selector    0x8456cb59
    /// @custom:signature   pause() public payable
    function pause() public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        require(!(bytes1(paused / 0x010000000000000000000000000000000000000000)), "Pausable: paused");
        paused = 0x010000000000000000000000000000000000000000 | (uint248(paused));
        emit Paused(address(msg.sender));
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(msg.sender == (address(paused)), "Ownable: caller is not the owner");
        paused = 0 | (uint96(paused));
        emit OwnershipTransferred(address(paused), 0);
    }
}