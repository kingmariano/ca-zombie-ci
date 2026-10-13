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
    bytes public constant harvest = ;
    address public constant stakingToken = 0xAddress(0xdd97ab35e3c0820215bc85a395e13671d84ccba2);
    
    uint256 public rewardsDuration;
    address public rewardsDistribution;
    address public helper;
    address public rewardsToken;
    mapping(bytes32 => bytes32) storage_map_q;
    bool public paused;
    bytes32 store_n;
    mapping(bytes32 => bytes32) storage_map_t;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;
    bool public emergencyLock;
    mapping(bytes32 => bytes32) storage_map_b;
    bytes32 store_e;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;
    bytes32 store_l;
    uint256 public lastPauseTime;
    address public owner;
    mapping(bytes32 => bytes32) storage_map_o;
    
    event RewardsDurationUpdated(uint256);
    event Recovered(address, uint256);
    event PauseChanged(bool);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x9f75c9e0
    /// @custom:signature   Unresolved_9f75c9e0(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_9f75c9e0(uint256 arg0) public payable {
        require(arg0 == arg0);
        address var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "auth");
        emergencyLock = arg0 | (uint248(emergencyLock));
    }
    
    /// @custom:selector    0x3aa6c4f9
    /// @custom:signature   withdrawableBalanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function withdrawableBalanceOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0x3c6b16ab
    /// @custom:signature   notifyRewardAmount(uint256 arg0) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function notifyRewardAmount(uint256 arg0) public view {
        require(bytes1(store_e), "");
        require(bytes1(store_e), "");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_a = 0x40 + var_a;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_a.length), "");
        require(!(0x20 > var_a.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x55b2214d
    /// @custom:signature   Unresolved_55b2214d() public payable
    function Unresolved_55b2214d() public payable {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_e = var_e;
        address var_b = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_70a08231(var_b); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        address var_d = address(this);
        require(address(var_f.length).code.length);
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_70a08231(var_d); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        address var_j = address(this);
        require(address(0x9348b45c542db53fe750f01f014bf6ae04b1395a).code.length);
        (bool success, bytes memory ret0) = address(0x9348b45c542db53fe750f01f014bf6ae04b1395a).Unresolved_70a08231(var_j); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        address var_m = address(var_e);
        uint256 var_p = 0;
        require(address(0x10ed43c718714eb63d5aa57b78b54704e256024e).code.length);
        (bool success, bytes memory ret0) = address(0x10ed43c718714eb63d5aa57b78b54704e256024e).{ value: var_p ether }Unresolved_baa2abde(var_m); // call
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x40);
        var_e = var_e;
        var_n = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_70a08231(var_n); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!(((var_f + ret0.length) - var_f) < 0x20), "j�");
        var_f = 0x40 + var_f;
        require(!(var_f.length > var_f.length), "j�");
        require(!(0 > var_f.length), "j�");
        require(!(0x20 > var_f.length), "SafeMath: subtraction overflow");
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        var_r = address(this);
        require(address(var_f.length).code.length);
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_70a08231(var_r); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!(((var_f + ret0.length) - var_f) < 0x20), "");
        var_f = 0x40 + var_f;
        require(!(var_f.length > var_f.length), "");
        require(!(0 > var_f.length), "");
        require(!(0x20 > var_f.length), "SafeMath: subtraction overflow");
        var_e = var_e;
        address var_ad = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_dd62ed3e(var_ad); // staticcall
    }
    
    /// @custom:selector    0xcc1a378f
    /// @custom:signature   setRewardsDuration(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setRewardsDuration(uint256 arg0) public payable {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        rewardsDuration = arg0;
        emit RewardsDurationUpdated(arg0);
    }
    
    /// @custom:selector    0xf69e2046
    /// @custom:signature   compound() public payable
    function compound() public payable {
        require(!(store_l == 0x02), "ReentrancyGuard: reentrant call");
        store_l = 0x02;
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_e = 0x40 + var_e;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_e.length), "");
        require(!(0x20 > var_e.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x80faa57d
    /// @custom:signature   lastTimeRewardApplicable() public view returns (uint256)
    function lastTimeRewardApplicable() public view returns (uint256) {
        if (block.timestamp < periodFinish) {
            return block.timestamp;
            return periodFinish;
        }
    }
    
    /// @custom:selector    0xb6b55f25
    /// @custom:signature   deposit(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function deposit(uint256 arg0) public payable {
        require(!(store_l == 0x02), "PausableUpgradeable: cannot be performed while the contract is paused");
        store_l = 0x02;
        require(!(bytes1(paused)), "PausableUpgradeable: cannot be performed while the contract is paused");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_g = 0x40 + var_g;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_g.length), "");
        require(!(0x20 > var_g.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x8129fc1c
    /// @custom:signature   initialize() public payable
    function initialize() public payable {
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_n / 0x0100), "Initializable: contract is already initialized");
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
                owner = (address(msg.sender)) | (uint96(owner));
                emit OwnershipTransferred(0, address(msg.sender));
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = 0x01 | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
                require(!(!bytes1(store_n / 0x0100)), "Initializable: contract is already initialized");
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = 0x01 | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = 0x01 | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
        store_n = 0x01 | (uint248(0x0100 | (store_n)));
        if (store_n / 0x0100) {
            if (store_n / 0x0100) {
            }
        }
        require(!(bytes1(store_n)), "Initializable: contract is already initialized");
    }
    
    /// @custom:selector    0xd7e3433b
    /// @custom:signature   Unresolved_d7e3433b(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_d7e3433b(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        storage_map_o[var_e] = arg1 | (uint248(storage_map_o[var_e]));
    }
    
    /// @custom:selector    0xdfc6fbaa
    /// @custom:signature   presaleBalanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function presaleBalanceOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0x986ccc7f
    /// @custom:signature   setHelper(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setHelper(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(address(arg0), "zero address");
        helper = (address(arg0)) | (uint96(helper));
    }
    
    /// @custom:selector    0x19762143
    /// @custom:signature   setRewardsDistribution(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setRewardsDistribution(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        rewardsDistribution = (address(arg0)) | (uint96(rewardsDistribution));
    }
    
    /// @custom:selector    0xf57d65f4
    /// @custom:signature   Unresolved_f57d65f4(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_f57d65f4(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_q[var_b];
    }
    
    /// @custom:selector    0xde320cc1
    /// @custom:signature   setRewardsToken(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setRewardsToken(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(!(address(rewardsToken)), "set rewards token already");
        rewardsToken = (address(arg0)) | (uint96(rewardsToken));
        var_e = var_e;
        require(!0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Address: call to non-contract");
        require(!0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Address: call to non-contract");
        uint256 var_a = ((0x40 + (0x24 + var_f)) - var_f) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0;
        var_f = 0x40 + var_f;
        require(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(arg0).codehash), "Address: call to non-contract");
        require(!(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(arg0).codehash)), "Address: call to non-contract");
        var_l = 0x20;
        require(!0 > var_f.length);
        uint256 var_n = 0;
        (bool success, bytes memory ret0) = address(arg0).{ value: var_n ether }Unresolved_08c379a0(var_l); // call
        require(ret0.length == 0);
        require(!var_o);
        require(!var_o, "SafeBEP20: BEP20 operation did not succeed");
        require(!(((0x80 + var_o) - 0x80) < 0x20), "SafeBEP20: BEP20 operation did not succeed");
        require(var_a == var_a, "SafeBEP20: BEP20 operation did not succeed");
        require(var_a, "SafeBEP20: BEP20 operation did not succeed");
        var_f = var_f + (uint248(ret0.length + 0x3f));
        require(!var_f.length);
        require(!var_f.length, "Address: call to non-contract");
        require(!(!address(arg0).codehash), "Address: call to non-contract");
        address var_b = address(this);
        var_c = address(var_e);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_dd62ed3e(var_b, var_c); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        emit OwnershipTransferred(address(owner), 0);
        owner = uint96(owner);
    }
    
    /// @custom:selector    0xb1815f52
    /// @custom:signature   Unresolved_b1815f52() public payable
    function Unresolved_b1815f52() public payable {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_e = var_e;
        address var_b = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_70a08231(var_b); // staticcall
        uint256 var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        address var_d = address(this);
        require(address(var_f.length).code.length);
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_70a08231(var_d); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        address var_j = address(this);
        require(address(0x0cc7984b1d6cb4c709a84e012c6d9cd4886e143d).code.length);
        (bool success, bytes memory ret0) = address(0x0cc7984b1d6cb4c709a84e012c6d9cd4886e143d).Unresolved_70a08231(var_j); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        address var_m = address(var_e);
        uint256 var_p = 0;
        require(address(0x24f7c33ae5f77e2a9eceed7ea858b4ca2fa1b7ec).code.length);
        (bool success, bytes memory ret0) = address(0x24f7c33ae5f77e2a9eceed7ea858b4ca2fa1b7ec).{ value: var_p ether }Unresolved_baa2abde(var_m); // call
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x40);
        var_e = var_e;
        var_n = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_70a08231(var_n); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!(((var_f + ret0.length) - var_f) < 0x20), "j�");
        var_f = 0x40 + var_f;
        require(!(var_f.length > var_f.length), "j�");
        require(!(0 > var_f.length), "j�");
        require(!(0x20 > var_f.length), "SafeMath: subtraction overflow");
        var_e = var_e;
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).WETH(); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!((var_f + ret0.length) - var_f) < 0x20);
        require(var_f.length == (address(var_f.length)));
        var_r = address(this);
        require(address(var_f.length).code.length);
        (bool success, bytes memory ret0) = address(var_f.length).Unresolved_70a08231(var_r); // staticcall
        var_f = var_f + (uint248(ret0.length + 0x1f));
        require(!(((var_f + ret0.length) - var_f) < 0x20), "");
        var_f = 0x40 + var_f;
        require(!(var_f.length > var_f.length), "");
        require(!(0 > var_f.length), "");
        require(!(0x20 > var_f.length), "SafeMath: subtraction overflow");
        var_e = var_e;
        address var_ad = address(this);
        require(address(var_e).code.length);
        (bool success, bytes memory ret0) = address(var_e).Unresolved_dd62ed3e(var_ad); // staticcall
    }
    
    /// @custom:selector    0x2e1a7d4d
    /// @custom:signature   withdraw(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function withdraw(uint256 arg0) public payable {
        require(!(store_l == 0x02), "system locked");
        store_l = 0x02;
        address var_a = msg.sender;
        require(block.number > storage_map_b[var_a], "system locked");
        var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "system locked");
        require(!(bytes1(emergencyLock)), "system locked");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_g = 0x40 + var_g;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_g.length), "");
        require(!(0x20 > var_g.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
        require(block.number > storage_map_b[var_a], "no flash");
    }
    
    /// @custom:selector    0xefa08806
    /// @custom:signature   recoverBEP20(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function recoverBEP20(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        uint256 var_a = ((0x40 + (0x24 + var_e)) - var_e) + 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0;
        var_e = 0x40 + var_e;
        require(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(arg0).codehash), "Address: call to non-contract");
        require(!(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 == (address(arg0).codehash)), "Address: call to non-contract");
        var_k = 0x20;
        require(!0 > var_e.length);
        uint256 var_m = 0;
        (bool success, bytes memory ret0) = address(arg0).{ value: var_m ether }Unresolved_08c379a0(var_k); // call
        require(ret0.length == 0);
        require(!var_n);
        require(!var_n, "SafeBEP20: BEP20 operation did not succeed");
        require(!(((0x80 + var_n) - 0x80) < 0x20), "SafeBEP20: BEP20 operation did not succeed");
        require(var_a == var_a, "SafeBEP20: BEP20 operation did not succeed");
        require(var_a, "SafeBEP20: BEP20 operation did not succeed");
        emit Recovered(address(arg0), arg1);
        emit Recovered(address(arg0), arg1);
        var_e = var_e + (uint248(ret0.length + 0x3f));
        require(!var_e.length);
        require(!var_e.length, "Address: call to non-contract");
        emit Recovered(address(arg0), arg1);
        require(!(!address(arg0).codehash), "Address: call to non-contract");
    }
    
    /// @custom:selector    0x61e20a1c
    /// @custom:signature   principalOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function principalOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0x853828b6
    /// @custom:signature   withdrawAll() public payable
    function withdrawAll() public payable {
        address var_a = msg.sender;
        require(block.number > storage_map_b[var_a], "system locked");
        var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "system locked");
        require(!(bytes1(emergencyLock)), "system locked");
        var_a = address(msg.sender);
        require(!storage_map_b[var_a], "system locked");
        require(!(store_l == 0x02), "system locked");
        store_l = 0x02;
        var_a = msg.sender;
        require(block.number > storage_map_b[var_a], "system locked");
        var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "system locked");
        require(!(bytes1(emergencyLock)), "system locked");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_g = 0x40 + var_g;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_g.length), "");
        require(!(0x20 > var_g.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
        require(block.number > storage_map_b[var_a], "no flash");
        require(!(store_l == 0x02), "system locked");
        store_l = 0x02;
        var_a = msg.sender;
        require(block.number > storage_map_b[var_a], "system locked");
        var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "system locked");
        require(!(bytes1(emergencyLock)), "system locked");
        require(block.number > storage_map_b[var_a], "no flash");
        require(block.number > storage_map_b[var_a], "no flash");
    }
    
    /// @custom:selector    0x8b876347
    /// @custom:signature   userRewardPerTokenPaid(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function userRewardPerTokenPaid(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_q[var_b];
    }
    
    /// @custom:selector    0x3d18b912
    /// @custom:signature   getReward() public payable
    function getReward() public payable {
        require(!(store_l == 0x02), "system locked");
        store_l = 0x02;
        address var_a = msg.sender;
        require(block.number > storage_map_b[var_a], "system locked");
        var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "system locked");
        require(!(bytes1(emergencyLock)), "system locked");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_g = 0x40 + var_g;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_g.length), "");
        require(!(0x20 > var_g.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
        require(block.number > storage_map_b[var_a], "no flash");
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(address(owner), address(arg0));
        owner = (address(arg0)) | (uint96(owner));
    }
    
    /// @custom:selector    0x70a08231
    /// @custom:signature   balanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function balanceOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0x0aae7a6b
    /// @custom:signature   info(address arg0) public view
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function info(address arg0) public view {
        require(arg0 == (address(arg0)));
        var_a = 0x60 + var_a;
        var_a = 0x60 + var_a;
        var_a = 0x60 + var_a;
        var_a = 0x60 + var_a;
        address var_z = address(arg0);
        var_z = address(arg0);
        var_z = address(arg0);
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        var_a = 0x40 + var_a;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_a.length), "");
        require(!(0x20 > var_a.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x9e447fc6
    /// @custom:signature   setRewardRate(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setRewardRate(uint256 arg0) public payable {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(arg0 > 0, "cannot be zero");
        rewardRate = arg0;
    }
    
    /// @custom:selector    0x0700037d
    /// @custom:signature   rewards(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function rewards(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_b = arg0;
        return storage_map_q[var_b];
    }
    
    /// @custom:selector    0xde5f6268
    /// @custom:signature   depositAll() public payable
    function depositAll() public payable {
        var_b = var_b;
        address var_c = address(msg.sender);
        require(address(var_b).code.length);
        (bool success, bytes memory ret0) = address(var_b).Unresolved_70a08231(var_c); // staticcall
        uint256 var_d = var_d + (uint248(ret0.length + 0x1f));
        require(!(((var_d + ret0.length) - var_d) < 0x20), "PausableUpgradeable: cannot be performed while the contract is paused");
        require(!(store_l == 0x02), "PausableUpgradeable: cannot be performed while the contract is paused");
        store_l = 0x02;
        require(!(bytes1(paused)), "PausableUpgradeable: cannot be performed while the contract is paused");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        var_d = 0x40 + var_d;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_d.length), "");
        require(!(0x20 > var_d.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x53d6fd59
    /// @custom:signature   Unresolved_53d6fd59(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_53d6fd59(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        storage_map_o[var_e] = arg1 | (uint248(storage_map_o[var_e]));
    }
    
    /// @custom:selector    0x3bcfc4b8
    /// @custom:signature   apy() public payable
    function apy() public payable {
        require(totalSupply);
        require(rewardRate);
        require(rewardRate);
        require(((0x0de0b6b3a7640000 * rewardRate) / rewardRate) == 0x0de0b6b3a7640000);
        require(totalSupply);
        require(totalSupply);
        var_e = var_e;
        address var_f = address(var_e);
        require(address(helper).code.length);
        (bool success, bytes memory ret0) = address(helper).Unresolved_8e333ce5(var_f); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!((var_a + ret0.length) - var_a) < 0x20);
        address var_h = address(rewardsToken);
        require(address(helper).code.length);
        (bool success, bytes memory ret0) = address(helper).Unresolved_2fd6d7f7(var_h); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!(((var_a + ret0.length) - var_a) < 0x20), "SafeMath: multiplication overflow");
        require((0x0de0b6b3a7640000 * rewardRate) / totalSupply, "SafeMath: multiplication overflow");
        require((0x0de0b6b3a7640000 * rewardRate) / totalSupply, "SafeMath: multiplication overflow");
        require((0x01e13380 * ((0x0de0b6b3a7640000 * rewardRate) / totalSupply)) / ((0x0de0b6b3a7640000 * rewardRate) / totalSupply) == 0x01e13380, "SafeMath: multiplication overflow");
        require(!(0 > var_a.length), "");
        require(!(0x20 > var_a.length), "SafeMath: division by zero");
    }
    
    /// @custom:selector    0x257b7cd9
    /// @custom:signature   Unresolved_257b7cd9(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_257b7cd9(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        address var_e = address(arg0);
        storage_map_o[var_e] = arg1 | (uint248(storage_map_o[var_e]));
    }
    
    /// @custom:selector    0x16c38b3c
    /// @custom:signature   Unresolved_16c38b3c(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_16c38b3c(uint256 arg0) public payable {
        require(arg0 == arg0);
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(!arg0 == (bytes1(paused)));
        paused = arg0 | (uint248(paused));
        require(!bytes1(arg0 | (uint248(paused))));
        lastPauseTime = block.timestamp;
        emit PauseChanged(bytes1(paused));
        emit PauseChanged(bytes1(paused));
    }
    
    /// @custom:selector    0x54198ce9
    /// @custom:signature   profitOf(address arg0) public view
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function profitOf(address arg0) public view {
        require(arg0 == (address(arg0)));
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_c = 0x40 + var_c;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_c.length), "");
        require(!(0x20 > var_c.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0x54d39b34
    /// @custom:signature   stakeTo(uint256 arg0, address arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function stakeTo(uint256 arg0, address arg1) public payable {
        require(arg1 == (address(arg1)));
        address var_a = msg.sender;
        require(bytes1(storage_map_b[var_a]), "ReentrancyGuard: reentrant call");
        require(!(store_l == 0x02), "ReentrancyGuard: reentrant call");
        store_l = 0x02;
        require(!(bytes1(paused)), "PausableUpgradeable: cannot be performed while the contract is paused");
        require(!(0 == totalSupply), "");
        require(block.timestamp < periodFinish, "");
        uint256 var_i = 0x40 + var_i;
        require(!(lastUpdateTime > block.timestamp), "");
        require(!(0 > var_i.length), "");
        require(!(0x20 > var_i.length), "SafeMath: subtraction overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require(block.timestamp - lastUpdateTime, "SafeMath: multiplication overflow");
        require((rewardRate * (block.timestamp - lastUpdateTime)) / (block.timestamp - lastUpdateTime) == rewardRate, "SafeMath: multiplication overflow");
    }
}