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
    bytes32 store_b;
    address public router;
    address public keeper;
    address public owner;
    
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x485cc955
    /// @custom:signature   initialize(address arg0, address arg1) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function initialize(address arg0, address arg1) public {
        if (store_b / 0x0100) {
            if (store_b / 0x0100) {
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(!(!bytes1(store_b / 0x0100)), "Initializable: contract is already initialized");
                require(!(!bytes1(store_b / 0x0100)), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(bytes1(store_b / 0x0100), "Initializable: contract is already initialized");
                require(!(!bytes1(store_b / 0x0100)), "Initializable: contract is already initialized");
                owner = (address(msg.sender)) | (uint96(owner));
                emit OwnershipTransferred(0, address(msg.sender));
                require(!(!bytes1(store_b / 0x0100)), "Initializable: contract is already initialized");
            }
        }
        require(!(bytes1(store_b)), "Initializable: contract is already initialized");
        store_b = 0x01 | (uint248(0x0100 | (store_b)));
        if (store_b / 0x0100) {
            if (store_b / 0x0100) {
                require(!(!bytes1(store_b / 0x0100)), "Initializable: contract is already initialized");
            }
        }
        require(!(bytes1(store_b)), "Initializable: contract is already initialized");
        store_b = 0x01 | (uint248(0x0100 | (store_b)));
        if (store_b / 0x0100) {
            if (store_b / 0x0100) {
            }
        }
        require(!(bytes1(store_b)), "Initializable: contract is already initialized");
        store_b = 0x01 | (uint248(0x0100 | (store_b)));
        if (store_b / 0x0100) {
            if (store_b / 0x0100) {
            }
        }
        require(!(bytes1(store_b)), "Initializable: contract is already initialized");
    }
    
    /// @custom:selector    0x7c72d7aa
    /// @custom:signature   distributeSingle(address[] arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function distributeSingle(address[] arg0) public {
        require(!arg0 > 0x0100000000);
        uint256 var_a = var_a + (0x20 + (0x20 * (arg0)));
        var_c = msg.data[36:36];
        require(msg.sender == (address(keeper)), "caller is not the keeper or owner");
        require(address(msg.sender) == (address(owner)), "caller is not the keeper or owner");
        var_e = address(this);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).Unresolved_70a08231(var_e); // staticcall
        require(!(ret0.length < 0x20), "");
        var_a = 0x40 + var_a;
        require(0x06, "");
        require(!(bytes1(var_a.length)), "");
        if (0x06) {
            require(0x06);
            var_a = 0x40 + var_a;
            require(var_a.length / 0x06);
            require(!0 > var_a.length);
        }
        var_l = 0x91d6136a45c10a8567ae9e2aac193d65fd4c7e01;
        var_q = 0;
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).{ value: var_q ether }Unresolved_a9059cbb(var_l); // call
        require(!ret0.length < 0x20);
        var_l = address(owner);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).{ value: 0 ether }Unresolved_a9059cbb(var_l); // call
        require(!ret0.length < 0x20);
        require(var_a.length / 0x06, "SafeMath: multiplication overflow");
        require((0x05 * (var_a.length / 0x06)) / (var_a.length / 0x06) == 0x05, "SafeMath: multiplication overflow");
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_d = var_d;
        require(address(arg0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(address(owner), address(arg0));
        owner = (address(arg0)) | (uint96(owner));
    }
    
    /// @custom:selector    0xc0d78655
    /// @custom:signature   setRouter(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setRouter(address arg0) public {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_d = var_d;
        router = (address(arg0)) | (uint96(router));
    }
    
    /// @custom:selector    0x047e4086
    /// @custom:signature   withdrawBEP20(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function withdrawBEP20(address arg0) public {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_d = var_d;
        address var_b = address(this);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_70a08231(var_b); // staticcall
        require(!ret0.length < 0x20);
        var_b = address(msg.sender);
        require(address(arg0).code.length);
        (bool success, bytes memory ret0) = address(arg0).{ value: 0 ether }Unresolved_a9059cbb(var_b); // call
        require(!ret0.length < 0x20);
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public
    function renounceOwnership() public {
        require(address(owner) == (address(msg.sender)), "Ownable: caller is not the owner");
        var_d = var_d;
        emit OwnershipTransferred(address(owner), 0);
        owner = uint96(owner);
    }
}