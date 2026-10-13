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
    uint256 public totalAmount;
    mapping(bytes32 => bytes32) storage_map_f;
    uint256 public getAddressListLength;
    mapping(bytes32 => bytes32) storage_map_q;
    mapping(bytes32 => bytes32) storage_map_s;
    bytes32 store_n;
    mapping(bytes32 => bytes32) storage_map_r;
    mapping(bytes32 => bytes32) storage_map_t;
    mapping(bytes32 => bytes32) storage_map_j;
    address public lpToken;
    address public adminAddress;
    mapping(bytes32 => bytes32) storage_map_k;
    address public offeringToken;
    uint256 public raisingAmount;
    mapping(bytes32 => bytes32) storage_map_m;
    uint256 public startBlock;
    bytes32 store_h;
    bool public allowClaim;
    uint256 public endBlock;
    uint256 public offeringAmount;
    
    
    /// @custom:selector    0x9f1b5248
    /// @custom:signature   finalWithdraw(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function finalWithdraw(uint256 arg0, uint256 arg1) public payable {
        require(msg.sender == (address(adminAddress)), "admin: wut?");
        address var_b = address(this);
        require(address(lpToken).code.length);
        (bool success, bytes memory ret0) = address(lpToken).Unresolved_70a08231(var_b); // staticcall
        require(!(ret0.length < 0x20), "not enough token 0");
        var_b = address(this);
        require(address(offeringToken).code.length);
        (bool success, bytes memory ret0) = address(offeringToken).Unresolved_70a08231(var_b); // staticcall
        require(!(ret0.length < 0x20), "not enough token 1");
        require(arg1 < var_e.length, "not enough token 1");
        require(!arg1, "Address: call to non-contract");
        uint256 var_a = 0x44 + (var_e - var_e);
        var_e = 0x40 + var_e;
        require(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(offeringToken).codehash), "Address: call to non-contract");
        require(!(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(offeringToken).codehash)), "Address: call to non-contract");
        require(var_e.length < 0x20);
        (bool success, bytes memory ret0) = address(offeringToken).{ value: 0 ether }adfepixw(); // call
        require(ret0.length == 0);
        require(!var_o);
        require(!var_e.length, "");
        require(!(bytes1(var_e.length)), "");
        require(!var_o, "SafeBEP20: BEP20 operation did not succeed");
        require(!(var_o < 0x20), "SafeBEP20: BEP20 operation did not succeed");
        require(var_a, "SafeBEP20: BEP20 operation did not succeed");
        require(!arg0);
        var_e = var_e + (uint248(ret0.length + 0x3f));
        require(!var_e.length);
        if (!var_e.length) {
        }
        require(!(!address(offeringToken).codehash), "Address: call to non-contract");
    }
    
    /// @custom:selector    0x87e97bc6
    /// @custom:signature   getOfferingAmount(address arg0) public view
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function getOfferingAmount(address arg0) public view {
        require(!(totalAmount > raisingAmount), "");
        address var_a = address(arg0);
        require(storage_map_f[var_a], "");
        require(storage_map_f[var_a], "");
        require((0xe8d4a51000 * storage_map_f[var_a]) / storage_map_f[var_a] == 0xe8d4a51000, "");
        uint256 var_c = 0x40 + var_c;
        require(totalAmount, "");
        require(totalAmount, "");
        require(!(bytes1(var_c.length)), "");
    }
    
    /// @custom:selector    0x4225c32f
    /// @custom:signature   setRaisingAmount(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setRaisingAmount(uint256 arg0) public payable {
        require(msg.sender == (address(adminAddress)), "admin: wut?");
        require(block.number < startBlock, "no");
        raisingAmount = arg0;
    }
    
    /// @custom:selector    0x4641257d
    /// @custom:signature   harvest() public payable
    function harvest() public payable {
        require(!(store_h == 0x02), "ReentrancyGuard: reentrant call");
        store_h = 0x02;
        require(block.number > endBlock, "not harvest time");
        address var_e = msg.sender;
        require(storage_map_j[var_e], "nothing to harvest");
        var_e = msg.sender;
        require(!(bytes1(storage_map_k[var_e])), "nothing to harvest");
        require(bytes1(allowClaim), "");
        require(!(totalAmount > raisingAmount), "");
        var_e = address(msg.sender);
        require(storage_map_j[var_e], "");
        require(storage_map_j[var_e], "");
        require((0xe8d4a51000 * storage_map_j[var_e]) / storage_map_j[var_e] == 0xe8d4a51000, "");
        uint256 var_g = 0x40 + var_g;
        require(totalAmount, "");
        require(totalAmount, "");
        require(!(bytes1(var_g.length)), "");
    }
    
    /// @custom:selector    0xb6b55f25
    /// @custom:signature   deposit(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deposit(uint256 arg0) public payable {
        require(!(store_h == 0x02), "not launchpad time");
        store_h = 0x02;
        require(!(block.number > startBlock), "not launchpad time");
        require(block.number > startBlock, "not launchpad time");
        require(arg0 > 0, "Address: call to non-contract");
        uint256 var_a = 0x64 + (var_f - var_f);
        var_f = 0x40 + var_f;
        require(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(lpToken).codehash), "Address: call to non-contract");
        require(!(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(lpToken).codehash)), "Address: call to non-contract");
        require(var_f.length < 0x20);
        (bool success, bytes memory ret0) = address(lpToken).{ value: 0 ether }adfepixw(); // call
        require(ret0.length == 0);
        require(!var_p);
        require(!var_f.length, "");
        require(!(bytes1(var_f.length)), "");
        require(!var_p, "SafeBEP20: BEP20 operation did not succeed");
        require(!(var_p < 0x20), "SafeBEP20: BEP20 operation did not succeed");
        require(var_a, "SafeBEP20: BEP20 operation did not succeed");
        address var_u = msg.sender;
        require(storage_map_m[var_u], "SafeMath: addition overflow");
        var_u = msg.sender;
        require(!((arg0 + storage_map_m[var_u]) < storage_map_m[var_u]), "SafeMath: addition overflow");
        var_f = var_f + (uint248(ret0.length + 0x3f));
        require(!var_f.length);
        if (!var_f.length) {
        }
        require(!(!address(lpToken).codehash), "Address: call to non-contract");
        require(block.number < endBlock, "not launchpad time");
    }
    
    /// @custom:selector    0x45d6a61a
    /// @custom:signature   flipAllowClaim() public payable
    function flipAllowClaim() public payable {
        require(msg.sender == (address(adminAddress)), "admin: wut?");
        allowClaim = (!bytes1(allowClaim)) | (uint248(allowClaim));
    }
    
    /// @custom:selector    0x2f5105f8
    /// @custom:signature   getRefundingAmount(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function getRefundingAmount(address arg0) public view returns (uint256) {
        require(totalAmount > raisingAmount, "");
        address var_a = address(arg0);
        require(storage_map_f[var_a], "");
        require(storage_map_f[var_a], "");
        require((0xe8d4a51000 * storage_map_f[var_a]) / storage_map_f[var_a] == 0xe8d4a51000, "");
        uint256 var_c = 0x40 + var_c;
        require(totalAmount, "");
        require(totalAmount, "");
        require(!(bytes1(var_c.length)), "");
        return 0;
    }
    
    /// @custom:selector    0x83a5041c
    /// @custom:signature   initialize(address arg0, address arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, address arg6) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    /// @param              arg5 ["uint256", "bytes32", "int256"]
    /// @param              arg6 ["address", "uint160", "bytes20", "int160"]
    function initialize(address arg0, address arg1, uint256 arg2, uint256 arg3, uint256 arg4, uint256 arg5, address arg6) public payable {
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        store_h = 0x01;
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        lpToken = (uint96(lpToken)) | (address(arg0));
        offeringToken = (uint96(offeringToken)) | (address(arg1));
        startBlock = arg2;
        endBlock = arg3;
        offeringAmount = arg4;
        raisingAmount = arg5;
        totalAmount = 0;
        adminAddress = (uint96(adminAddress)) | (address(arg6));
        require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
        store_n = uint248(store_n);
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = store_h | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = store_h | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
    }
    
    /// @custom:selector    0x1959a002
    /// @custom:signature   userInfo(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function userInfo(address arg0) public view returns (bool) {
        address var_b = address(arg0);
        return abi.encodePacked(storage_map_q[var_b], (bytes1(storage_map_r[var_b])));
    }
    
    /// @custom:selector    0xb810fb43
    /// @custom:signature   addressList(uint256 arg0) public view returns (address)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function addressList(uint256 arg0) public view returns (address) {
        require(arg0 < getAddressListLength);
        var_a = 0x3c;
        return address(storage_map_s[var_a]);
    }
    
    /// @custom:selector    0xb920ade2
    /// @custom:signature   getUserAllocation(address arg0) public view
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function getUserAllocation(address arg0) public view {
        address var_a = address(arg0);
        require(storage_map_f[var_a], "");
        require(storage_map_f[var_a], "");
        require((0xe8d4a51000 * storage_map_f[var_a]) / storage_map_f[var_a] == 0xe8d4a51000, "");
        uint256 var_c = 0x40 + var_c;
        require(totalAmount, "");
        require(totalAmount, "");
        require(!(bytes1(var_c.length)), "");
    }
    
    /// @custom:selector    0x64ce9fff
    /// @custom:signature   hasHarvest(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function hasHarvest(address arg0) public view returns (bool) {
        address var_a = address(arg0);
        return !(!bytes1(storage_map_t[var_a]));
    }
    
    /// @custom:selector    0x27d1b1a2
    /// @custom:signature   setOfferingAmount(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setOfferingAmount(uint256 arg0) public payable {
        require(msg.sender == (address(adminAddress)), "admin: wut?");
        offeringAmount = arg0;
    }
}