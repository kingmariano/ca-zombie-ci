[2m2026-10-03T15:31:12.536864Z[0m [33m WARN[0m calldata is not a standard size. if decoding fails, consider using the `--truncate-calldata` flag.
[2m2026-10-03T15:31:12.573767Z[0m [33m WARN[0m calldata is not a standard size. if decoding fails, consider using the `--truncate-calldata` flag.
[2m2026-10-03T15:31:12.750535Z[0m [33m WARN[0m couldn't find any resolved matches for '70a08231'
[2m2026-10-03T15:31:12.750970Z[0m [33m WARN[0m calldata is not a standard size. if decoding fails, consider using the `--truncate-calldata` flag.
[2m2026-10-03T15:31:12.904132Z[0m [33m WARN[0m couldn't find any resolved matches for 'a9059cbb'
ABI:

[
  {
    "type": "function",
    "name": "UPGRADE_INTERFACE_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes"
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
    "name": "Unresolved_5ddb3500",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
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
  },
  {
    "type": "error",
    "name": "AddressEmptyCode",
    "inputs": [
      {
        "name": "arg0",
        "type": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ERC1967InvalidImplementation",
    "inputs": [
      {
        "name": "arg0",
        "type": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ERC1967NonPayable",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FailedCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UUPSUnauthorizedCallContext",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UUPSUnsupportedProxiableUUID",
    "inputs": [
      {
        "name": "arg0",
        "type": "bytes32"
      }
    ]
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
    uint256 public constant proxiableUUID = e07c8dba;
    bytes public constant UPGRADE_INTERFACE_VERSION = 0xBytes([53, 46, 48, 46, 48]);
    
    address store_a;
    
    event Upgraded(address);
    error ERC1967NonPayable();
    
    /// @custom:selector    0x5ddb3500
    /// @custom:signature   Unresolved_5ddb3500() public
    function Unresolved_5ddb3500() public {
        address var_b = address(this);
        (bool success, bytes memory ret0) = address(0x9d65ff81a3c488d585bbfb0bfe3c7707c7917f54).Unresolved_70a08231(var_b); // staticcall
        uint256 var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(var_d == (var_d));
        var_f = 0xcc7fc65f319c7b8a5fae5c5bce6b2d2b29c19c2b;
        (bool success, bytes memory ret0) = address(0x9d65ff81a3c488d585bbfb0bfe3c7707c7917f54).Unresolved_a9059cbb(var_f); // call
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(var_d == (var_d));
        (bool success, bytes memory ret0) = address(0xcc7fc65f319c7b8a5fae5c5bce6b2d2b29c19c2b).transfer(address(this).balance);
        require(ret0.length == 0);
    }
    
    /// @custom:selector    0x4f1ef286
    /// @custom:signature   Unresolved_4f1ef286(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_4f1ef286(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 > 0xffffffffffffffff), CustomError_e07c8dba());
        require(!(((var_c + (uint248(((arg1 + 0x1f) + 0x20) + 0x1f))) > 0xffffffffffffffff) | ((var_c + (uint248(((arg1 + 0x1f) + 0x20) + 0x1f))) < var_c)), CustomError_e07c8dba());
        uint256 var_c = var_c + (uint248(((arg1 + 0x1f) + 0x20) + 0x1f));
        require(address(this) == 0x471627b16214a31dd0fa6f5531abb0fdc14d3207, CustomError_e07c8dba());
        require(!(address(this) == 0x471627b16214a31dd0fa6f5531abb0fdc14d3207), CustomError_e07c8dba());
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        require(var_c == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, CustomError_4c9c8ce3());
        require(address(0xe3).code.length - 0, CustomError_4c9c8ce3());
        var_g = 0xe3;
        store_a = var_g | (uint96(store_a));
        emit Upgraded(0xe3);
        require(!var_h > 0);
        (bool success, bytes memory ret0) = address(0xe3).Unresolved_(var_i); // delegatecall
        require(ret0.length == 0);
        require(!var_j > 0);
        require(!(var_j == 0), CustomError_9996b315());
        require(!(var_j == 0), CustomError_9996b315());
        require(!(address(0xe3).code.length == 0), CustomError_9996b315());
        var_c = var_c + (uint248(ret0.length + 0x3f));
        require(!(var_c.length > 0), CustomError_d6bda275());
        require(!(var_c.length == 0), CustomError_9996b315());
        require(!(address(0xe3).code.length == 0), CustomError_9996b315());
        require(!(msg.value > 0), CustomError_b398979f());
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!((var_c + ret0.length) - var_c) < 0x20);
        require(var_m == (var_m));
        require(0x01, CustomError_4c9c8ce3());
        require(var_m == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, CustomError_4c9c8ce3());
        require(address(arg0).code.length - 0, CustomError_4c9c8ce3());
        store_a = (address(arg0) * 0x01) | (uint96(store_a));
        emit Upgraded(address(arg0));
        require(!var_c.length > 0);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_p); // delegatecall
        require(ret0.length == 0);
        require(!var_j > 0);
        require(!(var_j == 0), CustomError_9996b315());
        require(!(var_j == 0), CustomError_9996b315());
        require(!(address(arg0).code.length == 0), CustomError_9996b315());
        var_c = var_c + (uint248(ret0.length + 0x3f));
        require(!(var_c.length > 0), CustomError_d6bda275());
        require(!(var_c.length == 0), CustomError_9996b315());
        require(!(address(arg0).code.length == 0), CustomError_9996b315());
        require(!(msg.value > 0), CustomError_b398979f());
        require(!(!(address(store_a / 0x01)) == 0x471627b16214a31dd0fa6f5531abb0fdc14d3207), CustomError_e07c8dba());
    }
}
