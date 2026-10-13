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
    
    /// @custom:selector    0x6138889b
    /// @custom:signature   distribute(address[] arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function distribute(address[] arg0) public {
        require(!arg0 > 0x0100000000);
        uint256 var_a = var_a + (0x20 + (0x20 * (arg0)));
        var_c = msg.data[36:36];
        require(msg.sender == (address(keeper)), "caller is not the keeper or owner");
        require(address(msg.sender) == (address(owner)), "caller is not the keeper or owner");
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).token0(); // staticcall
        require(!ret0.length < 0x20);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).token1(); // staticcall
        require(!ret0.length < 0x20);
        var_e = address(this);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).Unresolved_70a08231(var_e); // staticcall
        require(!ret0.length < 0x20);
        var_e = address(this);
        require(address(var_a.length).code.length);
        (bool success, bytes memory ret0) = address(var_a.length).Unresolved_dd62ed3e(var_e); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_e = address(router);
        require(address(var_a.length).code.length);
        (bool success, bytes memory ret0) = address(var_a.length).{ value: 0 ether }Unresolved_095ea7b3(var_e); // call
        require(!ret0.length < 0x20);
        var_e = address(this);
        require(address(0xdd97ab35e3c0820215bc85a395e13671d84ccba2).code.length);
        (bool success, bytes memory ret0) = address(0xdd97ab35e3c0820215bc85a395e13671d84ccba2).Unresolved_70a08231(var_e); // staticcall
        require(!ret0.length < 0x20);
        var_e = address(owner);
        require(address(0xdd97ab35e3c0820215bc85a395e13671d84ccba2).code.length);
        (bool success, bytes memory ret0) = address(0xdd97ab35e3c0820215bc85a395e13671d84ccba2).{ value: 0 ether }Unresolved_a9059cbb(var_e); // call
        require(!ret0.length < 0x20);
        var_e = address(this);
        var_h = var_h;
        require(address(var_h).code.length);
        (bool success, bytes memory ret0) = address(var_h).Unresolved_70a08231(var_e); // staticcall
        require(!ret0.length < 0x20);
        var_e = address(owner);
        require(address(var_h).code.length);
        (bool success, bytes memory ret0) = address(var_h).{ value: 0 ether }Unresolved_a9059cbb(var_e); // call
        require(!ret0.length < 0x20);
        var_e = address(this);
        var_h = var_h;
        require(address(var_h).code.length);
        (bool success, bytes memory ret0) = address(var_h).Unresolved_70a08231(var_e); // staticcall
        require(!ret0.length < 0x20);
        var_e = address(owner);
        require(address(var_h).code.length);
        (bool success, bytes memory ret0) = address(var_h).{ value: 0 ether }Unresolved_a9059cbb(var_e); // call
        require(!ret0.length < 0x20);
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
        require(!(address(var_c)) == 0);
        var_e = address(this);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).Unresolved_dd62ed3e(var_e); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_e = address(router);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).{ value: 0 ether }Unresolved_095ea7b3(var_e); // call
        require(!ret0.length < 0x20);
        var_e = address(this);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).Unresolved_70a08231(var_e); // staticcall
        require(!(ret0.length < 0x20), "");
        require(var_a.length, "");
        var_a = 0x40 + var_a;
        require(0x02, "");
        require(!(bytes1(var_a.length)), "");
        require(0x02);
        var_o = var_o;
        require(!var_o == (address(var_c)));
        var_o = var_o;
        require(!(address(var_c)) == (address(var_o)));
        var_o = var_o;
        var_j = address(this);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).Unresolved_dd62ed3e(var_j); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_j = address(router);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).{ value: 0 ether }Unresolved_095ea7b3(var_j); // call
        require(!(ret0.length < 0x20), "");
        var_o = var_o;
        var_a = 0x40 + var_a;
        require(!((var_a.length / 0x02) > var_a.length), "");
        require(!var_a.length, "");
        require(!(bytes1(var_a.length)), "");
        var_l = address(var_c);
        uint256 var_w = 0;
        require(address(router).code.length);
        (bool success, bytes memory ret0) = address(router).{ value: var_w ether }Unresolved_e8e33700(var_l); // call
        require(!ret0.length < 0x60);
        var_l = address(this);
        require(address(0x14b5a6d26577970953f9e6608d6604e4676ac5b7).code.length);
        (bool success, bytes memory ret0) = address(0x14b5a6d26577970953f9e6608d6604e4676ac5b7).Unresolved_70a08231(var_l); // staticcall
        require(!ret0.length < 0x20);
        var_l = 0xee8c659c08ada7ae879404eb31b69acbb1f19ff8;
        require(address(0x14b5a6d26577970953f9e6608d6604e4676ac5b7).code.length);
        (bool success, bytes memory ret0) = address(0x14b5a6d26577970953f9e6608d6604e4676ac5b7).{ value: var_w ether }Unresolved_a9059cbb(var_l); // call
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_j = address(this);
        var_k = address(router);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).allowance(var_j, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_a.length);
        var_j = address(router);
        var_k = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).{ value: var_w ether }approve(var_j, var_k); // call
        require(!ret0.length < 0x20);
        require(0xe9e7cea3dedca5984780bafc599bd69add087d56 == (address(var_c)));
        require(0xe9e7cea3dedca5984780bafc599bd69add087d56 == (address(var_c)));
        require(!0xe9e7cea3dedca5984780bafc599bd69add087d56 == (address(var_c)));
        var_o = var_o;
        require(!var_o == (address(var_o)));
        var_a = var_a + 0x80;
        var_o = var_o;
        require(0x02 < var_a.length);
        var_s = address(this);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).Unresolved_70a08231(var_s); // staticcall
        require(!ret0.length < 0x20);
        var_s = var_a.length / 0x02;
        var_v = 0;
        require(!0 < (var_a.length * 0x20));
        require(address(router).code.length);
        (bool success, bytes memory ret0) = address(router).{ value: var_v ether }Unresolved_5c11d795(var_s); // call
        var_s = address(this);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).Unresolved_70a08231(var_s); // staticcall
        require(!(ret0.length < 0x20), "j�");
        var_a = 0x40 + var_a;
        require(!(var_a.length > var_a.length), "j�");
        require(!var_a.length, "j�");
        require(!(bytes1(var_a.length)), "j�");
        var_a = var_a + 0xa0;
        var_o = var_o;
        require(0x02 < var_a.length);
        require(0x03 < var_a.length);
        var_v = address(this);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).balanceOf(var_v); // staticcall
        require(!ret0.length < 0x20);
        require(!0x55d398326f99059ff775485246999027b3197955 == (address(var_c)));
        var_o = var_o;
        require(!var_o == (address(var_o)));
        var_r = address(this);
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).balanceOf(var_r); // staticcall
        require(!ret0.length < 0x20);
        var_a = var_a + 0x80;
        var_o = var_o;
        require(0x02 < var_a.length);
        var_o = var_o;
        require(var_o == (address(var_c)));
        require(!var_o == (address(var_c)));
        var_a = var_a + 0x80;
        var_o = var_o;
        require(0x02 < var_a.length);
        var_o = var_o;
        require(address(var_o).code.length);
        (bool success, bytes memory ret0) = address(var_o).{ value: address(this).balance }deposit(); // call
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
    
    /// @custom:selector    0x6c5d6156
    /// @custom:signature   burn(address[] arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function burn(address[] arg0) public {
        require(!arg0 > 0x0100000000);
        uint256 var_a = var_a + (0x20 + (0x20 * (arg0)));
        var_c = msg.data[36:36];
        require(msg.sender == (address(keeper)), "caller is not the keeper or owner");
        require(address(msg.sender) == (address(owner)), "caller is not the keeper or owner");
        var_e = address(this);
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).Unresolved_70a08231(var_e); // staticcall
        require(!ret0.length < 0x20);
        var_e = 0xdead;
        require(address(var_c).code.length);
        (bool success, bytes memory ret0) = address(var_c).{ value: 0 ether }Unresolved_a9059cbb(var_e); // call
        require(!ret0.length < 0x20);
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