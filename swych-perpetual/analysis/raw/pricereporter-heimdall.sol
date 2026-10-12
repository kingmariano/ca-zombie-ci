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
    address public owner;
    uint256 public getReporterCount;
    mapping(bytes32 => bytes32) storage_map_b;
    address storage_map_j[getReporterCount + keccak256(var_e)];
    address store_f;
    mapping(bytes32 => bytes32) storage_map_h;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_e;
    mapping(bytes32 => bytes32) storage_map_i;
    mapping(bytes32 => bytes32) storage_map_j;
    
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x044ad7be
    /// @custom:signature   isReporter(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function isReporter(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return !(!bytes1(storage_map_a[var_b]));
    }
    
    /// @custom:selector    0x07b99f37
    /// @custom:signature   Unresolved_07b99f37(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_07b99f37(uint256 arg0, uint256 arg1) public payable {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        address var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]));
        require(!arg0);
        require(!0 < (arg0));
        require(0 < (arg0));
        uint256 var_d = (0 + (arg0 + 0x20));
        require(address(0x092d00a4965a6336c9c52bdf522b012c2dd42dce).code.length);
        (bool success, bytes memory ret0) = address(0x092d00a4965a6336c9c52bdf522b012c2dd42dce).{ value: 0 ether }Unresolved_04358662(var_d); // call
        require(0x01, "PriceReporter:unauthorized");
    }
    
    /// @custom:selector    0x93a91e33
    /// @custom:signature   Unresolved_93a91e33(uint256 arg0, uint256 arg1) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_93a91e33(uint256 arg0, uint256 arg1) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!arg1 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0xdd8755f2
    /// @custom:signature   addReporter(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function addReporter(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "PriceReporter:reporterAlreadyAdded");
        address var_e = address(arg0);
        require(!(bytes1(storage_map_e[var_e])), "PriceReporter:reporterAlreadyAdded");
        var_e = address(arg0);
        var_f = 0x01;
        storage_map_e[var_e] = var_f | (uint248(storage_map_e[var_e]));
        getReporterCount = getReporterCount + 0x01;
        store_f = (address(arg0)) | (uint96(store_f));
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        owner = 0 | (uint96(owner));
        emit OwnershipTransferred(address(owner), 0);
    }
    
    /// @custom:selector    0x5e02cb7d
    /// @custom:signature   reporters(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function reporters(uint256 arg0) public view returns (address) {
        require(arg0 < getReporterCount);
        var_a = 0x02;
        return address(storage_map_g[var_a]);
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        owner = (address(arg0)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(arg0));
    }
    
    /// @custom:selector    0x5de5c212
    /// @custom:signature   removeReporter(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function removeReporter(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        require(bytes1(storage_map_e[var_e]), "PriceReporter:reporterNotExists");
        var_e = address(arg0);
        storage_map_e[var_e] = uint248(storage_map_e[var_e]);
        require(!(0 < getReporterCount), "PriceReporter:reporterNotExists");
        require(0 < getReporterCount, "PriceReporter:reporterNotExists");
        var_e = 0x02;
        require(address(storage_map_h[var_e]) - (address(arg0)), "PriceReporter:reporterNotExists");
        require(0x01, "PriceReporter:reporterNotExists");
        require(!(getReporterCount < 0x01), "PriceReporter:reporterNotExists");
        require((getReporterCount - 0x01) < getReporterCount, "PriceReporter:reporterNotExists");
        require(0 < getReporterCount, "PriceReporter:reporterNotExists");
        var_e = 0x02;
        storage_map_h[var_e] = (address(storage_map_i[var_e]) * 0x01) | (uint96(storage_map_h[var_e]));
        require(getReporterCount, "PriceReporter:reporterNotExists");
        var_e = 0x02;
        storage_map_j[getReporterCount + keccak256(var_e)] = uint96(storage_map_j[getReporterCount + keccak256(var_e)]);
        getReporterCount = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff + getReporterCount;
    }
    
    /// @custom:selector    0x5bf9ac5b
    /// @custom:signature   Unresolved_5bf9ac5b(uint256 arg0, uint256 arg1) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_5bf9ac5b(uint256 arg0, uint256 arg1) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!arg1 > 0xffffffffffffffff);
    }
}