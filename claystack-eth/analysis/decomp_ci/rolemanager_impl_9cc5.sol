[2m2026-10-03T15:31:04.550334Z[0m [33m WARN[0m calldata is not a standard size. if decoding fails, consider using the `--truncate-calldata` flag.
ABI:

[
  {
    "type": "function",
    "name": "CS_SERVICE_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "TIMELOCK_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "TIMELOCK_UPGRADES_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "Unresolved_40540056",
    "inputs": [
      {
        "name": "arg0",
        "type": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "Unresolved_4f1ef286",
    "inputs": [
      {
        "name": "arg0",
        "type": "address"
      },
      {
        "name": "arg1",
        "type": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "Unresolved_dc5b68a6",
    "inputs": [
      {
        "name": "arg0",
        "type": "address"
      },
      {
        "name": "arg1",
        "type": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "checkRole",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "proxiableUUID",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setupRoleAdmin",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      },
      {
        "name": "arg1",
        "type": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes4"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "upgradeTo",
    "inputs": [
      {
        "name": "arg0",
        "type": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32",
        "indexed": false
      },
      {
        "name": "arg1",
        "type": "bytes32",
        "indexed": false
      },
      {
        "name": "arg2",
        "type": "bytes32",
        "indexed": false
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32",
        "indexed": false
      },
      {
        "name": "arg1",
        "type": "address",
        "indexed": false
      },
      {
        "name": "arg2",
        "type": "address",
        "indexed": false
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32",
        "indexed": false
      },
      {
        "name": "arg1",
        "type": "address",
        "indexed": false
      },
      {
        "name": "arg2",
        "type": "address",
        "indexed": false
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Upgraded",
    "inputs": [
      {
        "name": "arg0",
        "type": "address",
        "indexed": false
      }
    ],
    "anonymous": false
  }
]
Source:

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
    uint256 public constant proxiableUUID = 3963877391197344453575983046348115674221700746820753546331534351508065746944;
    uint256 public constant CS_SERVICE_ROLE = 50969625018062186103731630628322885896603545177040135287051760480604829306312;
    uint256 public constant TIMELOCK_ROLE = 111453197730673426114603501735896717599949682338553564746049185532460826636037;
    uint256 public constant DEFAULT_ADMIN_ROLE = 0;
    uint256 public constant TIMELOCK_UPGRADES_ROLE = 83639863513482901010632355603723075341073824202588754445460323710951243399601;
    
    mapping(bytes32 => bytes32) storage_map_c;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_e;
    mapping(bytes32 => bytes32) storage_map_f;
    address store_b;
    bytes32 store_d;
    
    event RoleAdminChanged(bytes32, bytes32, bytes32);
    event Upgraded(address);
    event RoleRevoked(bytes32, address, address);
    event RoleGranted(bytes32, address, address);
    
    /// @custom:selector    0x248a9ca3
    /// @custom:signature   getRoleAdmin(bytes32 arg0) public view returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getRoleAdmin(bytes32 arg0) public view returns (uint256) {
        uint256 var_a = arg0;
        return storage_map_a[var_a];
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
        require(!(0x9cc565bcc55aa20e122bfe14cb316632a86970cb == address(this)), "Function must be called through delegatecall");
        var_a = var_a;
        require(address(store_b) == 0x9cc565bcc55aa20e122bfe14cb316632a86970cb, "Implementation is not a contract");
        address var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Implementation is not a contract");
        require(!(!address(arg0).code.length), "Implementation is not a contract");
        require(!(bytes1(store_d)), "ERC1967: new implementation is not a contract");
        require(!(!address(arg0).code.length), "ERC1967: new implementation is not a contract");
        store_b = (address(arg0)) | (uint96(store_b));
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        var_a = var_a;
        require(0x01 == var_a, "ERC1967: new implementation is not a contract");
        require(address(0x04fa).code.length, "ERC1967: new implementation is not a contract");
        store_b = 0x04fa | (uint96(store_b));
        emit Upgraded(0x04fa);
        require(var_l > 0, "Address: delegate call to non-contract");
        require(!(var_l > 0), "Address: delegate call to non-contract");
        require(address(0x04fa).code.length, "Address: delegate call to non-contract");
        require(!0 < var_l);
        require(!0 > var_l);
        (bool success, bytes memory ret0) = address(0x04fa).Unresolved_(var_m); // delegatecall
        require(ret0.length == 0);
        var_c = 0x60 + var_c;
        require(!var_o);
        require(!(0 > var_c.length), "                                       ");
        var_c = 0x60 + var_c;
        require(!var_c.length);
        require(!var_c, "ERC1967Upgrade: unsupported proxiableUUID");
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!(((var_c + ret0.length) - var_c) < 0x20), "ERC1967Upgrade: new implementation is not UUPS");
        require(0x01, "ERC1967Upgrade: new implementation is not UUPS");
        var_a = var_a;
        require(var_c.length == var_a, "ERC1967: new implementation is not a contract");
        require(!(!address(arg0).code.length), "ERC1967: new implementation is not a contract");
        store_b = (address(arg0)) | (uint96(store_b));
        emit Upgraded(address(arg0));
        require(var_c.length > 0, "Address: delegate call to non-contract");
        require(!(var_c.length > 0), "Address: delegate call to non-contract");
        require(!(!address(arg0).code.length), "Address: delegate call to non-contract");
        require(!0x01, "ERC1967Upgrade: unsupported proxiableUUID");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x02 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x2a > 0xffffffffffffffff), "Strings: hex length insufficient");
        var_c = var_c + 0x60;
        require(!0x2a, "Strings: hex length insufficient");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x01 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x29 > 0x01), "Strings: hex length insufficient");
        require(!(address(msg.sender)), "Strings: hex length insufficient");
        require(bytes1(address(msg.sender)) < 0x10, "Function must be called through active proxy");
        require(0x29 < var_c.length, "Function must be called through active proxy");
        require(0x29, "Function must be called through active proxy");
        var_a = var_a;
    }
    
    /// @custom:selector    0x40540056
    /// @custom:signature   Unresolved_40540056(uint256 arg0) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_40540056(uint256 arg0) public pure returns (uint256) {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248(0x3f + (arg0 + 0x1f)))) < var_c) | ((var_c + (uint248(0x3f + (arg0 + 0x1f)))) > 0xffffffffffffffff));
        var_e = msg.data[36:36];
        return keccak256(var_e);
    }
    
    /// @custom:selector    0x12d9a6ad
    /// @custom:signature   checkRole(bytes32 arg0, address arg1) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function checkRole(bytes32 arg0, address arg1) public view returns (bool) {
        require(arg1 == (address(arg1)));
        require(!(address(arg1)) == 0x36e655069464be6202e0e4d5ee9f76034c0ad9b6);
        return 0x01;
        var_b = address(arg1);
        return !(!bytes1(storage_map_e[var_b]));
    }
    
    /// @custom:selector    0xa1ea2c00
    /// @custom:signature   setupRoleAdmin(bytes32 arg0, bytes32 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setupRoleAdmin(bytes32 arg0, bytes32 arg1) public {
        address var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Strings: hex length insufficient");
        var_a = arg0;
        storage_map_a[var_a] = arg1;
        emit RoleAdminChanged(arg0, storage_map_a[var_a], arg1);
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x02 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x2a > 0xffffffffffffffff), "Strings: hex length insufficient");
        uint256 var_e = var_e + 0x60;
        require(!0x2a, "Strings: hex length insufficient");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x01 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x29 > 0x01), "Strings: hex length insufficient");
        require(!(address(msg.sender)), "Strings: hex length insufficient");
        require(bytes1(address(msg.sender)) < 0x10);
        require(0x29 < var_e.length);
        require(0x29);
    }
    
    /// @custom:selector    0x3659cfe6
    /// @custom:signature   upgradeTo(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function upgradeTo(address arg0) public {
        require(arg0 == (address(arg0)));
        address var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Function must be called through delegatecall");
        require(!(0x9cc565bcc55aa20e122bfe14cb316632a86970cb == address(this)), "Function must be called through delegatecall");
        var_a = var_a;
        require(address(store_b) == 0x9cc565bcc55aa20e122bfe14cb316632a86970cb, "Implementation is not a contract");
        var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Implementation is not a contract");
        require(!(!address(arg0).code.length), "Implementation is not a contract");
        require(!(!address(arg0).code.length), "ERC1967: new implementation is not a contract");
        store_b = (address(arg0)) | (uint96(store_b));
        emit Upgraded(address(arg0));
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x02 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x2a > 0xffffffffffffffff), "Strings: hex length insufficient");
        uint256 var_i = var_i + 0x60;
        require(!0x2a, "Strings: hex length insufficient");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x01 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x29 > 0x01), "Strings: hex length insufficient");
        require(!(address(msg.sender)), "Strings: hex length insufficient");
        require(bytes1(address(msg.sender)) < 0x10, "Function must be called through active proxy");
        require(0x29 < var_i.length, "Function must be called through active proxy");
        require(0x29, "Function must be called through active proxy");
        var_a = var_a;
    }
    
    /// @custom:selector    0xdc5b68a6
    /// @custom:signature   Unresolved_dc5b68a6(address arg0, uint256 arg1) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_dc5b68a6(address arg0, uint256 arg1) public pure {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x2f2ff15d
    /// @custom:signature   grantRole(bytes32 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function grantRole(bytes32 arg0, address arg1) public {
        require(arg1 == (address(arg1)));
        var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Time Lock role can't be granted");
        var_a = var_a;
        require(!(arg0 == var_a), "Time Lock role can't be granted");
        var_a = var_a;
        require(!(arg0 == var_a), "Time Lock Upgrade role can't be granted");
        var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Strings: hex length insufficient");
        var_a = address(arg1);
        require(bytes1(storage_map_c[var_a]), "Strings: hex length insufficient");
        var_a = address(arg1);
        storage_map_c[var_a] = 0x01 | (uint248(storage_map_c[var_a]));
        emit RoleGranted(arg0, address(arg1), address(msg.sender));
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x02 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x2a > 0xffffffffffffffff), "Strings: hex length insufficient");
        uint256 var_i = var_i + 0x60;
        require(!0x2a, "Strings: hex length insufficient");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x01 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x29 > 0x01), "Strings: hex length insufficient");
        require(!(address(msg.sender)), "Strings: hex length insufficient");
        require(bytes1(address(msg.sender)) < 0x10);
        require(0x29 < var_i.length);
        require(0x29);
    }
    
    /// @custom:selector    0x91d14854
    /// @custom:signature   hasRole(bytes32 arg0, address arg1) public view returns (bool)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function hasRole(bytes32 arg0, address arg1) public view returns (bool) {
        require(arg1 == (address(arg1)));
        var_a = address(arg1);
        return !(!bytes1(storage_map_c[var_a]));
    }
    
    /// @custom:selector    0x36568abe
    /// @custom:signature   renounceRole(bytes32 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function renounceRole(bytes32 arg0, address arg1) public {
        require(arg1 == (address(arg1)));
        require(msg.sender == (address(arg1)), "AccessControl: can only renounce roles for self");
        var_f = address(arg1);
        require(!bytes1(storage_map_f[var_f]));
        var_f = address(arg1);
        storage_map_f[var_f] = uint248(storage_map_f[var_f]);
        emit RoleRevoked(arg0, address(arg1), msg.sender);
    }
    
    /// @custom:selector    0x01ffc9a7
    /// @custom:signature   supportsInterface(bytes4 arg0) public pure returns (bool)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function supportsInterface(bytes4 arg0) public pure returns (bool) {
        require(arg0 == (uint32(arg0)));
        require(0x7965db0b00000000000000000000000000000000000000000000000000000000 == (uint32(arg0)));
        return !(!0x7965db0b00000000000000000000000000000000000000000000000000000000 == (uint32(arg0)));
        return !(!(uint32(arg0)) == 0x01ffc9a700000000000000000000000000000000000000000000000000000000);
    }
    
    /// @custom:selector    0xd547741f
    /// @custom:signature   revokeRole(bytes32 arg0, address arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    function revokeRole(bytes32 arg0, address arg1) public {
        require(arg1 == (address(arg1)));
        var_a = address(msg.sender);
        require(bytes1(storage_map_c[var_a]), "Strings: hex length insufficient");
        var_a = address(arg1);
        require(!(bytes1(storage_map_c[var_a])), "Strings: hex length insufficient");
        var_a = address(arg1);
        storage_map_c[var_a] = uint248(storage_map_c[var_a]);
        emit RoleRevoked(arg0, address(arg1), msg.sender);
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x02 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x2a > 0xffffffffffffffff), "Strings: hex length insufficient");
        uint256 var_e = var_e + 0x60;
        require(!0x2a, "Strings: hex length insufficient");
        require(!(0x02 & (0x14 > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)), "Strings: hex length insufficient");
        require(!(0x01 > 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7), "Strings: hex length insufficient");
        require(!(0x29 > 0x01), "Strings: hex length insufficient");
        require(!(address(msg.sender)), "Strings: hex length insufficient");
        require(bytes1(address(msg.sender)) < 0x10);
        require(0x29 < var_e.length);
        require(0x29);
    }
}
