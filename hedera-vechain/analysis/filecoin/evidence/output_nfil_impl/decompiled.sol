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
    uint256 public constant decimals = 18;
    uint256 public constant proxiableUUID = 3963877391197344453575983046348115674221700746820753546331534351508065746944;
    
    uint256 public totalSupply;
    address public owner;
    address store_c;
    bytes32 store_e;
    bytes32 store_k;
    address public liquidStakingContractAddress;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_g;
    bytes32 store_h;
    bytes32 store_i;
    address store_j;
    
    event LiquidStakingContractSet(address, address);
    event Approval(address, address, uint256);
    event Transfer(address, address, uint256);
    event Upgraded(address);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x095ea7b3
    /// @custom:signature   approve(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function approve(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(address(msg.sender), "ERC20: approve to the zero address");
        require(address(arg0), "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_a[var_a] = arg1;
        emit Approval(address(msg.sender), address(arg0), arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x4f1ef286
    /// @custom:signature   Unresolved_4f1ef286(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_4f1ef286(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 > 0xffffffffffffffff), "Function must be called through delegatecall");
        require(!(((var_c + (uint248(0x3f + (arg1 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg1 + 0x1f)))) > 0xffffffffffffffff)), "Function must be called through delegatecall");
        require(address(this) - 0xb95292314adf18f2c8c4c9996df83ed22b28b0f0, "Function must be called through delegatecall");
        require(address(store_c) == 0xb95292314adf18f2c8c4c9996df83ed22b28b0f0, "Ownable: caller is not the owner");
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(!(bytes1(store_e)), "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_c = (address(arg0)) | (uint96(store_c));
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        var_a = var_a;
        require(0x01 == var_a, "ERC1967: new implementation is not a contract");
        require(address(0x0770).code.length, "ERC1967: new implementation is not a contract");
        store_c = 0x0770 | (uint96(store_c));
        emit Upgraded(0x0770);
        require(var_k > 0, "Address: delegate call to non-contract");
        require(!(var_k > 0), "Address: delegate call to non-contract");
        require(address(0x0770).code.length, "Address: delegate call to non-contract");
        require(!0 < var_k);
        (bool success, bytes memory ret0) = address(0x0770).Unresolved_(var_l); // delegatecall
        require(ret0.length == 0);
        var_c = 0x60 + var_c;
        require(!var_n);
        var_c = 0x60 + var_c;
        require(!var_c.length);
        require(!var_c, "ERC1967Upgrade: unsupported proxiableUUID");
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!(((var_c + ret0.length) - var_c) < 0x20), "ERC1967Upgrade: new implementation is not UUPS");
        require(0x01, "ERC1967Upgrade: new implementation is not UUPS");
        var_a = var_a;
        require(var_c.length == var_a, "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_c = (address(arg0)) | (uint96(store_c));
        emit Upgraded(address(arg0));
        require(var_c.length > 0, "Address: delegate call to non-contract");
        require(!(var_c.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
        require(!0x01, "ERC1967Upgrade: unsupported proxiableUUID");
    }
    
    /// @custom:selector    0x39509351
    /// @custom:signature   increaseAllowance(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function increaseAllowance(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        var_a = address(arg0);
        require(!(storage_map_a[var_a] > (arg1 + storage_map_a[var_a])), "ERC20: approve to the zero address");
        require(address(msg.sender), "ERC20: approve to the zero address");
        require(address(arg0), "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_a[var_a] = arg1 + storage_map_a[var_a];
        emit Approval(address(msg.sender), address(arg0), arg1 + storage_map_a[var_a]);
        return 0x01;
    }
    
    /// @custom:selector    0xa9059cbb
    /// @custom:signature   transfer(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function transfer(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(address(msg.sender), "ERC20: transfer amount exceeds balance");
        require(address(arg0), "ERC20: transfer amount exceeds balance");
        address var_a = address(msg.sender);
        require(!(storage_map_a[var_a] < arg1), "ERC20: transfer amount exceeds balance");
        var_a = address(msg.sender);
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        var_a = address(arg0);
        storage_map_a[var_a] = arg1 + storage_map_a[var_a];
        emit Transfer(address(msg.sender), address(arg0), arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x23b872dd
    /// @custom:signature   Unresolved_23b872dd(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_23b872dd(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public
    function renounceOwnership() public {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        owner = 0 | (uint96(owner));
        emit OwnershipTransferred(address(owner), 0);
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        owner = (address(arg0)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(arg0));
    }
    
    /// @custom:selector    0x8e433bc7
    /// @custom:signature   whiteListBurn(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function whiteListBurn(uint256 arg0, address arg1) public {
        require(arg1 == (address(arg1)));
        require(msg.sender == (address(liquidStakingContractAddress)), "Not allowed to touch funds");
        require(address(arg1), "ERC20: burn amount exceeds balance");
        address var_e = address(arg1);
        require(!(storage_map_g[var_e] < arg0), "ERC20: burn amount exceeds balance");
        var_e = address(arg1);
        storage_map_g[var_e] = storage_map_g[var_e] - arg0;
        totalSupply = totalSupply - arg0;
        emit Transfer(address(arg1), 0, arg0);
    }
    
    /// @custom:selector    0x70a08231
    /// @custom:signature   balanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function balanceOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0xa457c2d7
    /// @custom:signature   decreaseAllowance(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function decreaseAllowance(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        var_a = address(arg0);
        require(!(storage_map_a[var_a] < arg1), "ERC20: decreased allowance below zero");
        require(address(msg.sender), "ERC20: approve to the zero address");
        require(address(arg0), "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_a[var_a] = storage_map_a[var_a] - arg1;
        emit Approval(address(msg.sender), address(arg0), storage_map_a[var_a] - arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x8129fc1c
    /// @custom:signature   initialize() public
    function initialize() public {
        if (store_h / 0x0100) {
            if (!store_h / 0x0100) {
                require(!(!bytes1(store_h / 0x0100)), "Initializable: contract is not initializing");
                require(!(bytes1(store_h / 0x0100)), "Initializable: contract is not initializing");
                store_h = 0x01 | (uint248(store_h));
                require(address(this).code.length, "Initializable: contract is not initializing");
                require(0x01 == (bytes1(store_h)), "Initializable: contract is not initializing");
                require(!(!bytes1(store_h / 0x0100)), "Initializable: contract is not initializing");
                owner = (address(msg.sender)) | (uint96(owner));
                emit OwnershipTransferred(address(owner), address(msg.sender));
                require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
                var_a = 0x40 + var_a;
                require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
                require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
                require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
                require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
                require(!(var_a.length > 0xffffffffffffffff), "Initializable: contract is not initializing");
                require(bytes1(store_i), "Initializable: contract is not initializing");
                require(bytes1(store_i) - ((store_i >> 0x01) < 0x20), "Initializable: contract is not initializing");
                require(!((store_i >> 0x01) > 0x1f), "Initializable: contract is not initializing");
                require(!(var_a.length < 0x20), "Initializable: contract is not initializing");
                var_f = 0x68;
                require(!(keccak256(var_f) + ((var_a.length + 0x1f) >> 0x05) < (keccak256(var_f) + (((store_i >> 0x01) + 0x1f) >> 0x05))), "Initializable: contract is not initializing");
                require((var_a.length > 0x1f) == 0x01, "Initializable: contract is not initializing");
            }
            require(!(0 < (uint248(var_a.length))), "Initializable: contract is not initializing");
        }
        store_h = 0x0100 | (uint248(store_h));
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        owner = (address(msg.sender)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(msg.sender));
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(!(bytes1(store_h / 0x0100)), "Initializable: contract is already initialized");
    }
    
    /// @custom:selector    0xdd62ed3e
    /// @custom:signature   Unresolved_dd62ed3e(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_dd62ed3e(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0x08211be5
    /// @custom:signature   setLiquidStaking(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setLiquidStaking(address arg0) public {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "LiquidStaking address invalid");
        emit LiquidStakingContractSet(address(liquidStakingContractAddress), address(arg0));
        liquidStakingContractAddress = (address(arg0)) | (uint96(liquidStakingContractAddress));
    }
    
    /// @custom:selector    0x06fdde03
    /// @custom:signature   name() public view returns (string memory)
    function name() public view returns (string memory) {
        if (store_i) {
            if (store_i - ((store_i >> 0x01) < 0x20)) {
                uint256 var_c = var_c + (0x20 + (((0x1f + (store_i >> 0x01)) / 0x20) * 0x20));
                if (store_i) {
                    if (store_i - ((store_i >> 0x01) < 0x20)) {
                        if (!store_i >> 0x01) {
                            if (0x1f < (store_i >> 0x01)) {
                                var_a = 0x68;
                                if ((0x20 + var_c) + (store_i >> 0x01) > (0x20 + (0x20 + var_c))) {
                                    return abi.encodePacked(0x20, var_c.length);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x3659cfe6
    /// @custom:signature   upgradeTo(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function upgradeTo(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(this) - 0xb95292314adf18f2c8c4c9996df83ed22b28b0f0, "Function must be called through delegatecall");
        require(address(store_j) == 0xb95292314adf18f2c8c4c9996df83ed22b28b0f0, "Ownable: caller is not the owner");
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(!(bytes1(store_e)), "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_j = (address(arg0)) | (uint96(store_j));
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        var_f = var_f;
        require(0 == var_f, "ERC1967: new implementation is not a contract");
        require(address(0x067f).code.length, "ERC1967: new implementation is not a contract");
        store_j = 0x067f | (uint96(store_j));
        emit Upgraded(0x067f);
        require(var_j > 0, "Address: delegate call to non-contract");
        require(!(var_j > 0), "Address: delegate call to non-contract");
        require(address(0x067f).code.length, "Address: delegate call to non-contract");
        require(!0 < var_j);
        (bool success, bytes memory ret0) = address(0x067f).Unresolved_(var_k); // delegatecall
        require(ret0.length == 0);
        var_g = 0x60 + var_g;
        require(!var_m);
        var_g = 0x60 + var_g;
        require(!var_g.length);
        require(!var_g, "ERC1967Upgrade: unsupported proxiableUUID");
        var_g = var_g + (uint248(ret0.length + 0x1f));
        require(!(((var_g + ret0.length) - var_g) < 0x20), "ERC1967Upgrade: new implementation is not UUPS");
        require(0x01, "ERC1967Upgrade: new implementation is not UUPS");
        var_f = var_f;
        require(var_g.length == var_f, "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_j = (address(arg0)) | (uint96(store_j));
        emit Upgraded(address(arg0));
        require(var_g.length > 0, "Address: delegate call to non-contract");
        require(!(var_g.length > 0), "Address: delegate call to non-contract");
        require(address(arg0).code.length, "Address: delegate call to non-contract");
    }
    
    /// @custom:selector    0x6455feac
    /// @custom:signature   whiteListMint(uint256 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function whiteListMint(uint256 arg0, address arg1) public {
        require(arg1 == (address(arg1)));
        require(msg.sender == (address(liquidStakingContractAddress)), "Not allowed to touch funds");
        require(address(arg1), "ERC20: mint to the zero address");
        require(!(totalSupply > (arg0 + totalSupply)), "ERC20: mint to the zero address");
        totalSupply = arg0 + totalSupply;
        address var_e = address(arg1);
        storage_map_g[var_e] = arg0 + storage_map_g[var_e];
        emit Transfer(0, address(arg1), arg0);
    }
    
    /// @custom:selector    0x95d89b41
    /// @custom:signature   symbol() public view returns (string memory)
    function symbol() public view returns (string memory) {
        if (store_k) {
            if (store_k - ((store_k >> 0x01) < 0x20)) {
                uint256 var_c = var_c + (0x20 + (((0x1f + (store_k >> 0x01)) / 0x20) * 0x20));
                if (store_k) {
                    if (store_k - ((store_k >> 0x01) < 0x20)) {
                        if (!store_k >> 0x01) {
                            if (0x1f < (store_k >> 0x01)) {
                                var_a = 0x69;
                                if ((0x20 + var_c) + (store_k >> 0x01) > (0x20 + (0x20 + var_c))) {
                                    return abi.encodePacked(0x20, var_c.length);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}