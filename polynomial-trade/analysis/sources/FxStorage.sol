{{
  "language": "Solidity",
  "sources": {
    "src/utils/Storage.sol": {
      "content": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.9;\n\n/**\n * @title FxStorage.\n * @dev Store Data For Cast Function.\n */\n\ncontract FxStorage {\n    // Memory Bytes (Smart Account Address => Storage ID => Bytes).\n    mapping(address => mapping(uint256 => bytes32)) internal mbytes; // Use it to store execute data and delete in the same transaction\n    // Memory Uint (Smart Account Address => Storage ID => Uint).\n    mapping(address => mapping(uint256 => uint256)) internal muint; // Use it to store execute data and delete in the same transaction\n    // Memory Address (Smart Account Address => Storage ID => Address).\n    mapping(address => mapping(uint256 => address)) internal maddr; // Use it to store execute data and delete in the same transaction\n\n    /**\n     * @dev Store Bytes.\n     * @param _id Storage ID.\n     * @param _byte bytes data to store.\n     */\n    function setBytes(uint256 _id, bytes32 _byte) public {\n        mbytes[msg.sender][_id] = _byte;\n    }\n\n    /**\n     * @dev Get Stored Bytes.\n     * @param _id Storage ID.\n     */\n    function getBytes(uint256 _id) public returns (bytes32 _byte) {\n        _byte = mbytes[msg.sender][_id];\n        delete mbytes[msg.sender][_id];\n    }\n\n    /**\n     * @dev Store Uint.\n     * @param _id Storage ID.\n     * @param _num uint data to store.\n     */\n    function setUint(uint256 _id, uint256 _num) public {\n        muint[msg.sender][_id] = _num;\n    }\n\n    /**\n     * @dev Get Stored Uint.\n     * @param _id Storage ID.\n     */\n    function getUint(uint256 _id) public returns (uint256 _num) {\n        _num = muint[msg.sender][_id];\n        delete muint[msg.sender][_id];\n    }\n\n    /**\n     * @dev Store Address.\n     * @param _id Storage ID.\n     * @param _addr Address data to store.\n     */\n    function setAddr(uint256 _id, address _addr) public {\n        maddr[msg.sender][_id] = _addr;\n    }\n\n    /**\n     * @dev Get Stored Address.\n     * @param _id Storage ID.\n     */\n    function getAddr(uint256 _id) public returns (address _addr) {\n        _addr = maddr[msg.sender][_id];\n        delete maddr[msg.sender][_id];\n    }\n}\n"
    }
  },
  "settings": {
    "remappings": [
      "ds-test/=lib/forge-std/lib/ds-test/src/",
      "forge-std/=lib/forge-std/src/"
    ],
    "optimizer": {
      "enabled": true,
      "runs": 200
    },
    "metadata": {
      "bytecodeHash": "ipfs"
    },
    "outputSelection": {
      "*": {
        "*": [
          "evm.bytecode",
          "evm.deployedBytecode",
          "devdoc",
          "userdoc",
          "metadata",
          "abi"
        ]
      }
    },
    "evmVersion": "london",
    "libraries": {}
  }
}}