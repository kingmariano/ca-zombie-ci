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
    uint256 public constant PT_SEND = 0;
    uint256 public constant decimals = 18;
    uint256 public constant lzEndpoint = 863507117382096603994605986240616377028580399588;
    uint256 public constant NO_EXTRA_GAS = 0;
    
    uint256 public totalSupply;
    mapping(bytes32 => bytes32) storage_map_f;
    mapping(bytes32 => bytes32) storage_map_d;
    mapping(bytes32 => bytes32) storage_map_b;
    address public owner;
    bytes32 store_e;
    bytes32 store_g;
    bytes32 store_h;
    mapping(bytes32 => bytes32) storage_map_k;
    bool public useCustomAdapterParams;
    address public precrime;
    
    event SetTrustedRemote(uint16, bytes);
    event Transfer(address, address, uint256);
    event SetPrecrime(address);
    event SetUseCustomAdapterParams(bool);
    event Approval(address, address, uint256);
    event SetTrustedRemoteAddress(uint16, bytes);
    event Withdrawal(address, uint256);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x095ea7b3
    /// @custom:signature   approve(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function approve(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        require(address(msg.sender) - 0, "ERC20: approve to the zero address");
        require(address(arg0) - 0, "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_b[var_a] = arg1;
        emit Approval(address(msg.sender), address(arg0), arg1);
        return 0x01;
    }
    
    /// @custom:selector    0xa6c3d165
    /// @custom:signature   Unresolved_a6c3d165(uint16 arg0, uint256 arg1) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_a6c3d165(uint16 arg0, uint256 arg1) public {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        uint256 var_c = ((0x20 + var_c) + (arg1)) + 0x14;
        require(!var_c.length > 0xffffffffffffffff);
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(bytes1(storage_map_d[var_h]));
        require(bytes1(storage_map_d[var_h]) - ((storage_map_d[var_h] / 0x02) < 0x20));
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_d[var_h] / 0x02) > 0x1f);
        var_h = keccak256(var_h);
        require(!var_c.length < 0x20);
        require(!(keccak256(var_h) + ((var_c.length + 0x1f) / 0x20)) < (keccak256(var_h) + (((storage_map_d[var_h] / 0x02) + 0x1f) / 0x20)));
        require((var_c.length > 0x1f) == 0x01);
        var_h = keccak256(var_h);
        require(!0 < (uint248(var_c.length)));
        require(!(uint248(var_c.length)) < var_c.length);
        storage_map_d[var_h] = (var_c.length * 0x02) + 0x01;
        emit SetTrustedRemoteAddress(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        storage_map_d[var_h] = (var_p) & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * (bytes1(var_c.length)))));
        storage_map_d[var_h] = (var_c.length * 0x02) + 0x01;
        emit SetTrustedRemoteAddress(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        require(!var_c.length);
        storage_map_d[var_h] = (0 & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * var_c.length)))) | (0x02 * var_c.length);
        emit SetTrustedRemoteAddress(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        storage_map_d[var_h] = (var_p & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * var_c.length)))) | (0x02 * var_c.length);
        emit SetTrustedRemoteAddress(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
    }
    
    /// @custom:selector    0xa9059cbb
    /// @custom:signature   transfer(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function transfer(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        require(address(msg.sender) - 0, "ERC20: transfer amount exceeds balance");
        require(address(arg0) - 0, "ERC20: transfer amount exceeds balance");
        address var_a = address(msg.sender);
        require(!(storage_map_b[var_a] < arg1), "ERC20: transfer amount exceeds balance");
        var_a = address(msg.sender);
        storage_map_b[var_a] = storage_map_b[var_a] - arg1;
        var_a = address(arg0);
        require(!(storage_map_b[var_a] > (storage_map_b[var_a] + arg1)), "ERC20: transfer to the zero address");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        storage_map_b[var_a] = storage_map_b[var_a] + arg1;
        emit Transfer(address(msg.sender), address(arg0), arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x5b8c41e6
    /// @custom:signature   Unresolved_5b8c41e6(uint16 arg0, uint256 arg1, uint64 arg2) public view returns (uint256)
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint64", "bytes8", "int64"]
    function Unresolved_5b8c41e6(uint16 arg0, uint256 arg1, uint64 arg2) public view returns (uint256) {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(!((var_c + (uint248(((arg1 + 0x1f) + 0x20) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248(((arg1 + 0x1f) + 0x20) + 0x1f))) < var_c));
        var_e = msg.data[36:36];
        require(arg2 == (uint64(arg2)));
        uint16 var_a = arg0;
        var_a = arg2;
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0xa457c2d7
    /// @custom:signature   decreaseAllowance(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function decreaseAllowance(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        var_a = address(arg0);
        require(!(storage_map_b[var_a] < arg1), "ERC20: decreased allowance below zero");
        require(address(msg.sender) - 0, "ERC20: approve to the zero address");
        require(address(arg0) - 0, "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_b[var_a] = storage_map_b[var_a] - arg1;
        emit Approval(address(msg.sender), address(arg0), storage_map_b[var_a] - arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x01ffc9a7
    /// @custom:signature   supportsInterface(bytes4 arg0) public pure returns (bool)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function supportsInterface(bytes4 arg0) public pure returns (bool) {
        require(arg0 == (uint32(arg0)));
        require(uint32(arg0) == 0);
        require(uint32(arg0) == 0x36372b0700000000000000000000000000000000000000000000000000000000);
        return !(!(uint32(arg0)) == 0x36372b0700000000000000000000000000000000000000000000000000000000);
        require(uint32(arg0) == 0xe8e89a8000000000000000000000000000000000000000000000000000000000);
        return !(!(uint32(arg0)) == 0xe8e89a8000000000000000000000000000000000000000000000000000000000);
        return !(!(uint32(arg0)) == 0x01ffc9a700000000000000000000000000000000000000000000000000000000);
        require(uint32(arg0) == 0);
        return !(!(uint32(arg0)) == 0);
    }
    
    /// @custom:selector    0x51905636
    /// @custom:signature   Unresolved_51905636(address arg0, uint16 arg1, uint256 arg2, uint256 arg3, address arg4) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint16", "bytes2", "int16"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_51905636(address arg0, uint16 arg1, uint256 arg2, uint256 arg3, address arg4) public pure {
        require(arg0 == (address(arg0)));
        require(arg1 == (uint16(arg1)));
        require(!arg2 > 0xffffffffffffffff);
        require(!(arg2) > 0xffffffffffffffff);
        require(arg3 == arg3);
        require(arg4 == (address(arg4)));
    }
    
    /// @custom:selector    0x3d8b38f6
    /// @custom:signature   Unresolved_3d8b38f6(uint16 arg0, uint256 arg1) public view returns (bool)
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_3d8b38f6(uint16 arg0, uint256 arg1) public view returns (bool) {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        uint16 var_a = uint16(arg0);
        require(bytes1(storage_map_b[var_a]));
        require(bytes1(storage_map_b[var_a]) - ((storage_map_b[var_a] / 0x02) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint16 var_d = var_d + (0x20 + (((0x1f + (storage_map_b[var_a] / 0x02)) / 0x20) * 0x20));
        require(bytes1(storage_map_b[var_a]));
        require(bytes1(storage_map_b[var_a]) - ((storage_map_b[var_a] / 0x02) < 0x20));
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!storage_map_b[var_a] / 0x02);
        require(0x1f < (storage_map_b[var_a] / 0x02));
        var_a = keccak256(var_a);
        require((0x20 + var_d) + (storage_map_b[var_a] / 0x02) > (0x20 + (0x20 + var_d)));
        var_g = msg.data[36:36];
        return !(!(keccak256(var_h)) == keccak256(var_g));
        var_g = msg.data[36:36];
        return !(!(keccak256(var_h)) == keccak256(var_g));
        var_g = msg.data[36:36];
        return !(!(keccak256(var_h)) == keccak256(var_g));
    }
    
    /// @custom:selector    0xdd62ed3e
    /// @custom:signature   Unresolved_dd62ed3e(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_dd62ed3e(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0x2a205e3d
    /// @custom:signature   Unresolved_2a205e3d(uint16 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_2a205e3d(uint16 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public pure {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(arg2 == arg2);
        require(arg3 == arg3);
        require(!arg4 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x2e1a7d4d
    /// @custom:signature   withdraw(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function withdraw(uint256 arg0) public {
        require(arg0 == arg0);
        require(store_e - 0x02, "ReentrancyGuard: reentrant call");
        store_e = 0x02;
        address var_f = address(msg.sender);
        require(!(storage_map_f[var_f] < arg0), "NativeOFT: Insufficient balance.");
        require(address(msg.sender) - 0, "ERC20: burn amount exceeds balance");
        var_f = address(msg.sender);
        require(!(storage_map_f[var_f] < arg0), "ERC20: burn amount exceeds balance");
        var_f = address(msg.sender);
        storage_map_f[var_f] = storage_map_f[var_f] - arg0;
        require(!((totalSupply - arg0) > totalSupply), "NativeOFT: failed to unwrap");
        totalSupply = totalSupply - arg0;
        emit Transfer(address(msg.sender), 0, arg0);
        (bool success, bytes memory ret0) = address(msg.sender).transfer(arg0);
        require(ret0.length == 0, "NativeOFT: failed to unwrap");
        emit Withdrawal(address(msg.sender), arg0);
        store_e = 0x01;
    }
    
    /// @custom:selector    0x06fdde03
    /// @custom:signature   name() public view returns (string memory)
    function name() public view returns (string memory) {
        if (store_g) {
            if (store_g - ((store_g / 0x02) < 0x20)) {
                uint256 var_c = var_c + (0x20 + (((0x1f + (store_g / 0x02)) / 0x20) * 0x20));
                if (store_g) {
                    if (store_g - ((store_g / 0x02) < 0x20)) {
                        if (!store_g / 0x02) {
                            if (0x1f < (store_g / 0x02)) {
                                var_a = 0x09;
                                if ((0x20 + var_c) + (store_g / 0x02) > (0x20 + (0x20 + var_c))) {
                                    return abi.encodePacked((var_c + 0x20) - var_c, var_c.length);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x39509351
    /// @custom:signature   increaseAllowance(address arg0, uint256 arg1) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function increaseAllowance(address arg0, uint256 arg1) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(arg1 == arg1);
        var_a = address(arg0);
        require(!(storage_map_b[var_a] > (storage_map_b[var_a] + arg1)), "ERC20: approve to the zero address");
        require(address(msg.sender) - 0, "ERC20: approve to the zero address");
        require(address(arg0) - 0, "ERC20: approve to the zero address");
        var_a = address(arg0);
        storage_map_b[var_a] = storage_map_b[var_a] + arg1;
        emit Approval(address(msg.sender), address(arg0), storage_map_b[var_a] + arg1);
        return 0x01;
    }
    
    /// @custom:selector    0x95d89b41
    /// @custom:signature   symbol() public view returns (string memory)
    function symbol() public view returns (string memory) {
        if (store_h) {
            if (store_h - ((store_h / 0x02) < 0x20)) {
                uint256 var_c = var_c + (0x20 + (((0x1f + (store_h / 0x02)) / 0x20) * 0x20));
                if (store_h) {
                    if (store_h - ((store_h / 0x02) < 0x20)) {
                        if (!store_h / 0x02) {
                            if (0x1f < (store_h / 0x02)) {
                                var_a = 0x0a;
                                if ((0x20 + var_c) + (store_h / 0x02) > (0x20 + (0x20 + var_c))) {
                                    return abi.encodePacked((var_c + 0x20) - var_c, var_c.length);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x10ddb137
    /// @custom:signature   setReceiveVersion(uint16 arg0) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function setReceiveVersion(uint16 arg0) public {
        require(arg0 == (uint16(arg0)));
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_b = uint16(arg0);
        require(address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).code.length);
        (bool success, bytes memory ret0) = address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).{ value: 0 ether }Unresolved_10ddb137(var_b); // call
    }
    
    /// @custom:selector    0xf5ecbdbc
    /// @custom:signature   Unresolved_f5ecbdbc(uint16 arg0) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_f5ecbdbc(uint16 arg0) public pure {
        require(arg0 == (uint16(arg0)));
    }
    
    /// @custom:selector    0x23b872dd
    /// @custom:signature   Unresolved_23b872dd(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_23b872dd(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0xdf2a5b3b
    /// @custom:signature   Unresolved_df2a5b3b(uint16 arg0) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_df2a5b3b(uint16 arg0) public pure {
        require(arg0 == (uint16(arg0)));
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(address(arg0) - 0, "Ownable: new owner is the zero address");
        owner = (address(arg0) * 0x01) | (uint96(owner));
        emit OwnershipTransferred(address(owner / 0x01), address(arg0));
    }
    
    /// @custom:selector    0xd1deba1f
    /// @custom:signature   Unresolved_d1deba1f(uint16 arg0, uint256 arg1, uint64 arg2, uint256 arg3) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint64", "bytes8", "int64"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_d1deba1f(uint16 arg0, uint256 arg1, uint64 arg2, uint256 arg3) public pure {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(arg2 == (uint64(arg2)));
        require(!arg3 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x8cfd8f5c
    /// @custom:signature   Unresolved_8cfd8f5c(uint16 arg0) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_8cfd8f5c(uint16 arg0) public pure {
        require(arg0 == (uint16(arg0)));
    }
    
    /// @custom:selector    0xeb8d72b7
    /// @custom:signature   Unresolved_eb8d72b7(uint16 arg0, uint256 arg1) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_eb8d72b7(uint16 arg0, uint256 arg1) public {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        require(!(arg1) > 0xffffffffffffffff);
        var_f = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(bytes1(storage_map_f[var_f]));
        require(bytes1(storage_map_f[var_f]) - ((storage_map_f[var_f] / 0x02) < 0x20));
        var_f = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_f[var_f] / 0x02) > 0x1f);
        var_f = keccak256(var_f);
        require(!(arg1) < 0x20);
        require(!(keccak256(var_f) + ((arg1 + 0x1f) / 0x20)) < (keccak256(var_f) + (((storage_map_f[var_f] / 0x02) + 0x1f) / 0x20)));
        require((arg1 > 0x1f) == 0x01);
        var_f = keccak256(var_f);
        require(!0 < (uint248(arg1)));
        require(!(uint248(arg1)) < (arg1));
        storage_map_f[var_f] = ((arg1 + 0x20) + 0) & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * (bytes1(arg1)))));
        storage_map_f[var_f] = (arg1 * 0x02) + 0x01;
        emit SetTrustedRemote(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        storage_map_f[var_f] = (arg1 * 0x02) + 0x01;
        emit SetTrustedRemote(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        require(!arg1);
        storage_map_f[var_f] = (((arg1 + 0x20) + 0) & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * (arg1))))) | (0x02 * (arg1));
        emit SetTrustedRemote(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
        storage_map_f[var_f] = (0 & (~(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (0x08 * (arg1))))) | (0x02 * (arg1));
        emit SetTrustedRemote(uint16(arg0), (var_c + 0x40) - var_c, (arg1));
    }
    
    /// @custom:selector    0x66ad5c8a
    /// @custom:signature   Unresolved_66ad5c8a(uint16 arg0, uint256 arg1, uint64 arg2, uint256 arg3) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint64", "bytes8", "int64"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    function Unresolved_66ad5c8a(uint16 arg0, uint256 arg1, uint64 arg2, uint256 arg3) public pure {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(arg2 == (uint64(arg2)));
        require(!arg3 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x7533d788
    /// @custom:signature   trustedRemoteLookup(uint16 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function trustedRemoteLookup(uint16 arg0) public view returns (bytes memory) {
        require(arg0 == (uint16(arg0)));
        uint16 var_b = arg0;
        require(bytes1(storage_map_k[var_b]));
        require(bytes1(storage_map_k[var_b]) - ((storage_map_k[var_b] / 0x02) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint16 var_d = var_d + (0x20 + (((0x1f + (storage_map_k[var_b] / 0x02)) / 0x20) * 0x20));
        require(bytes1(storage_map_k[var_b]));
        require(bytes1(storage_map_k[var_b]) - ((storage_map_k[var_b] / 0x02) < 0x20));
        var_b = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!storage_map_k[var_b] / 0x02);
        require(0x1f < (storage_map_k[var_b] / 0x02));
        var_b = keccak256(var_b);
        require((0x20 + var_d) + (storage_map_k[var_b] / 0x02) > (0x20 + (0x20 + var_d)));
        return abi.encodePacked((var_d + 0x20) - var_d, var_d.length);
    }
    
    /// @custom:selector    0xeab45d9c
    /// @custom:signature   Unresolved_eab45d9c(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_eab45d9c(uint256 arg0) public {
        require(arg0 == arg0);
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        useCustomAdapterParams = (arg0 * 0x01) | (uint248(useCustomAdapterParams));
        emit SetUseCustomAdapterParams(arg0);
    }
    
    /// @custom:selector    0x70a08231
    /// @custom:signature   balanceOf(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function balanceOf(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_b[var_a];
    }
    
    /// @custom:selector    0xd0e30db0
    /// @custom:signature   deposit() public view
    function deposit() public view {
        require(address(msg.sender) - 0, "ERC20: mint to the zero address");
        require(!(totalSupply > (totalSupply + msg.value)), "ERC20: mint to the zero address");
    }
    
    /// @custom:selector    0x9f38369a
    /// @custom:signature   getTrustedRemoteAddress(uint16 arg0) public view
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function getTrustedRemoteAddress(uint16 arg0) public view {
        require(arg0 == (uint16(arg0)));
        uint16 var_a = uint16(arg0);
        require(bytes1(storage_map_b[var_a]), "slice_overflow");
        require(bytes1(storage_map_b[var_a]) - ((storage_map_b[var_a] / 0x02) < 0x20), "slice_overflow");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        uint16 var_d = var_d + (0x20 + (((0x1f + (storage_map_b[var_a] / 0x02)) / 0x20) * 0x20));
        require(bytes1(storage_map_b[var_a]), "slice_overflow");
        require(bytes1(storage_map_b[var_a]) - ((storage_map_b[var_a] / 0x02) < 0x20), "slice_overflow");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(storage_map_b[var_a] / 0x02), "slice_overflow");
        require(0x1f < (storage_map_b[var_a] / 0x02), "slice_overflow");
        var_a = keccak256(var_a);
        require((0x20 + var_d) + (storage_map_b[var_a] / 0x02) > (0x20 + (0x20 + var_d)), "slice_overflow");
        require(var_d.length - 0, "slice_overflow");
        require(!((var_d.length - 0x14) > var_d.length), "slice_overflow");
        require(!((var_d.length - 0x14) > ((var_d.length - 0x14) + 0x1f)), "slice_overflow");
        require(!(((var_d.length - 0x14) + 0x1f) < (var_d.length - 0x14)), "slice_overflow");
    }
    
    /// @custom:selector    0x07e0db17
    /// @custom:signature   setSendVersion(uint16 arg0) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function setSendVersion(uint16 arg0) public {
        require(arg0 == (uint16(arg0)));
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_b = uint16(arg0);
        require(address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).code.length);
        (bool success, bytes memory ret0) = address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).{ value: 0 ether }Unresolved_07e0db17(var_b); // call
    }
    
    /// @custom:selector    0x42d65a8d
    /// @custom:signature   Unresolved_42d65a8d(uint16 arg0, uint256 arg1) public
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_42d65a8d(uint16 arg0, uint256 arg1) public {
        require(arg0 == (uint16(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_b = uint16(arg0);
        uint256 var_g = 0;
        require(address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).code.length);
        (bool success, bytes memory ret0) = address(0x9740ff91f1985d8d2b71494ae1a2f723bb3ed9e4).{ value: var_g ether }Unresolved_42d65a8d(var_b); // call
    }
    
    /// @custom:selector    0xcbed8b9c
    /// @custom:signature   Unresolved_cbed8b9c(uint16 arg0) public pure
    /// @param              arg0 ["uint16", "bytes2", "int16"]
    function Unresolved_cbed8b9c(uint16 arg0) public pure {
        require(arg0 == (uint16(arg0)));
    }
    
    /// @custom:selector    0xbaf3292d
    /// @custom:signature   setPrecrime(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setPrecrime(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        precrime = (address(arg0) * 0x01) | (uint96(precrime));
        emit SetPrecrime(address(arg0));
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public
    function renounceOwnership() public {
        require(address(owner / 0x01) == (address(msg.sender)), "Ownable: caller is not the owner");
        owner = 0 | (uint96(owner));
        emit OwnershipTransferred(address(owner / 0x01), 0);
    }
}