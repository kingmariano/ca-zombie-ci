{{
  "language": "Solidity",
  "sources": {
    "src/accounts/DefaultImpl.sol": {
      "content": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.9;\n\nimport {Variables} from \"./Variables.sol\";\n\ninterface IndexInterface {\n    function list() external view returns (address);\n}\n\ninterface ListInterface {\n    function addAuth(address user) external;\n\n    function removeAuth(address user) external;\n}\n\ncontract Constants is Variables {\n    uint256 public constant implementationVersion = 1;\n    // PolyIndex Address.\n    address public immutable polyIndex;\n    // The Account Module Version.\n    uint256 public constant version = 1;\n\n    constructor(address _polyIndex) {\n        polyIndex = _polyIndex;\n    }\n}\n\ncontract Record is Constants {\n    constructor(address _polyIndex) Constants(_polyIndex) {}\n\n    event LogEnableUser(address indexed user);\n    event LogDisableUser(address indexed user);\n    event LogBetaMode(bool indexed beta);\n\n    /**\n     * @dev Check for Auth if enabled.\n     * @param user address/user/owner.\n     */\n    function isAuth(address user) public view returns (bool) {\n        return _auth[user];\n    }\n\n    /**\n     * @dev Check if Beta mode is enabled or not\n     */\n    function isBeta() public view returns (bool) {\n        return _beta;\n    }\n\n    /**\n     * @dev Enable New User.\n     * @param user Owner address\n     */\n    function enable(address user) public {\n        require(msg.sender == address(this) || msg.sender == polyIndex, \"not-self-index\");\n        require(user != address(0), \"not-valid\");\n        require(!_auth[user], \"already-enabled\");\n        _auth[user] = true;\n        ListInterface(IndexInterface(polyIndex).list()).addAuth(user);\n        emit LogEnableUser(user);\n    }\n\n    /**\n     * @dev Disable User.\n     * @param user Owner address\n     */\n    function disable(address user) public {\n        require(msg.sender == address(this), \"not-self\");\n        require(user != address(0), \"not-valid\");\n        require(_auth[user], \"already-disabled\");\n        delete _auth[user];\n        ListInterface(IndexInterface(polyIndex).list()).removeAuth(user);\n        emit LogDisableUser(user);\n    }\n\n    function toggleBeta() public {\n        require(msg.sender == address(this), \"not-self\");\n        _beta = !_beta;\n        emit LogBetaMode(_beta);\n    }\n\n    /**\n     * @dev ERC721 token receiver\n     */\n    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {\n        return 0x150b7a02; // bytes4(keccak256(\"onERC721Received(address,address,uint256,bytes)\"))\n    }\n\n    /**\n     * @dev ERC1155 token receiver\n     */\n    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4) {\n        return 0xf23a6e61; // bytes4(keccak256(\"onERC1155Received(address,address,uint256,uint256,bytes)\"))\n    }\n\n    /**\n     * @dev ERC1155 token receiver\n     */\n    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)\n        external\n        returns (bytes4)\n    {\n        return 0xbc197c81; // bytes4(keccak256(\"onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)\"))\n    }\n}\n\ncontract DefaultImplementation is Record {\n    constructor(address _polyIndex) Record(_polyIndex) {}\n\n    receive() external payable {}\n}\n"
    },
    "src/accounts/Variables.sol": {
      "content": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.9;\n\ncontract Variables {\n    // Auth Module(Address of Auth => bool).\n    mapping(address => bool) internal _auth;\n    // enable beta mode to access all the beta features.\n    bool internal _beta;\n}\n"
    }
  },
  "settings": {
    "remappings": [
      "ds-test/=lib/forge-std/lib/ds-test/src/",
      "forge-std/=lib/forge-std/src/",
      "openzeppelin/=lib/openzeppelin-contracts/contracts/"
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