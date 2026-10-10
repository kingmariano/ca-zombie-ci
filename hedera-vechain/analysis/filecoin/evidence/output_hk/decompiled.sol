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
    
    mapping(bytes32 => bytes32) storage_map_c;
    mapping(bytes32 => bytes32) storage_map_f;
    mapping(bytes32 => bytes32) storage_map_w;
    bytes32 store_u;
    address public governance;
    uint256 public unresolved_f953c51f;
    address unresolved_f6344fd9a;
    uint256 public unresolved_3d5edc7c;
    mapping(bytes32 => bytes32) storage_map_ac;
    uint256 public equityPointLength;
    uint256 public unresolved_f6344fd9;
    address storage_map_v[storage_map_t[var_e] - 0x01];
    bytes32 store_l;
    bytes32 store_h;
    uint256 public unresolved_60bf0477;
    mapping(bytes32 => bytes32) storage_map_e;
    address public owner;
    uint256 public unresolved_2ca41d40;
    mapping(bytes32 => bytes32) storage_map_v;
    mapping(bytes32 => bytes32) storage_map_d;
    uint256 store_k;
    uint256 public unresolved_8846ee0f;
    mapping(bytes32 => bytes32) storage_map_ab;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_t;
    uint256 public unresolved_267385b0;
    address public unresolved_b9ccba42;
    bytes32 store_y;
    address store_x;
    address public hubPool;
    
    event Initialized(uint8);
    event FilRepayment(address, uint256);
    event Upgraded(address);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x36b0a5ef
    /// @custom:signature   lastEquityPoint(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function lastEquityPoint(uint256 arg0) public view returns (bytes memory) {
        require(!arg0 > equityPointLength);
        require(!equityPointLength > 0xffffffffffffffff);
        require(!equityPointLength);
        var_d = 0x40 + var_d;
        require(equityPointLength - 0x01);
        require(0x01 > equityPointLength);
        require(!(equityPointLength - 0x01) > equityPointLength);
        require((equityPointLength - 0x01) < equityPointLength);
        var_a = 0xd1;
        var_d = 0x40 + var_d;
        require(!(equityPointLength - 0x01) > equityPointLength);
        require((equityPointLength - 0x01) < var_d.length);
        require(0x02);
        return abi.encodePacked(0x20, var_d.length);
    }
    
    /// @custom:selector    0xb77a8bc4
    /// @custom:signature   Unresolved_b77a8bc4(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_b77a8bc4(uint256 arg0) public view returns (bytes memory) {
        require(arg0 < equityPointLength);
        var_a = 0xd1;
        return abi.encodePacked(storage_map_e[arg0 * 0x02], storage_map_f[(arg0 * 0x02) + keccak256(var_a)]);
    }
    
    /// @custom:selector    0x8f240148
    /// @custom:signature   hasBeneficiary(address arg0) public view returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function hasBeneficiary(address arg0) public view returns (bool) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_g[var_a];
    }
    
    /// @custom:selector    0xc4d66de8
    /// @custom:signature   initialize(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function initialize(address arg0) public {
        require(arg0 == (address(arg0)));
        require(!(!bytes1(store_h / 0x0100)), "nfil address must != address(0)");
        require(!(bytes1(store_h / 0x0100)), "nfil address must != address(0)");
        require(address(this).code.length, "nfil address must != address(0)");
        require(0x01 == (bytes1(store_h)), "nfil address must != address(0)");
        store_h = 0x01 | (uint248(store_h));
        require(!(!bytes1(store_h / 0x0100)), "nfil address must != address(0)");
        require(bytes1(store_h / 0x0100), "nfil address must != address(0)");
        require(bytes1(store_h / 0x0100), "nfil address must != address(0)");
        owner = (address(msg.sender)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(msg.sender));
        require(bytes1(store_h / 0x0100), "nfil address must != address(0)");
        require(address(arg0), "nfil address must != address(0)");
        unresolved_b9ccba42 = (address(arg0)) | (uint96(unresolved_b9ccba42));
        uint256 var_a = 0x40 + var_a;
        equityPointLength = equityPointLength + 0x01;
        store_k = var_a.length;
        store_l = var_e;
        require(!(!bytes1(store_h / 0x0100)), "nfil address must != address(0)");
        store_h = uint248(store_h);
        emit Initialized(0x01);
        store_h = 0x0100 | (uint248(store_h));
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        owner = (address(msg.sender)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(msg.sender));
        require(bytes1(store_h / 0x0100), "Initializable: contract is not initializing");
        require(!(bytes1(store_h / 0x0100)), "Initializable: contract is already initialized");
    }
    
    /// @custom:selector    0x0e6878a3
    /// @custom:signature   Unresolved_0e6878a3(uint256 arg0) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_0e6878a3(uint256 arg0) public view {
        require(arg0 == arg0);
        address var_a = address(msg.sender);
        require(storage_map_g[var_a], "reward must > 0");
        require(msg.value > 0, "reward must > 0");
        require(!(msg.value > (unresolved_3d5edc7c + msg.value)), "reward must > 0");
    }
    
    /// @custom:selector    0x1dfb2d02
    /// @custom:signature   setHubPool(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setHubPool(address arg0) public {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        hubPool = (address(arg0)) | (uint96(hubPool));
    }
    
    /// @custom:selector    0xa3603ca6
    /// @custom:signature   depositFil(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function depositFil(uint256 arg0) public {
        address var_a = address(msg.sender);
        require(storage_map_g[var_a]);
        (bool success, bytes memory ret0) = address(msg.sender).operator(); // staticcall
        uint256 var_d = var_d + (uint248(ret0.length + 0x1f));
        require(!((var_d + ret0.length) - var_d) < 0x20);
        (bool success, bytes memory ret0) = address(msg.sender).nodeId(); // staticcall
        var_d = var_d + (uint248(ret0.length + 0x1f));
        require(!(((var_d + ret0.length) - var_d) < 0x20), "address to not allow");
        require(var_d.length > 0, "address to not allow");
        require(!arg0, "amount not allow");
        require(!(arg0 > address(this).balance), "amount not allow");
        var_d = var_d + 0x20;
        require(0, "amount not allow");
        require(arg0, "amount not allow");
    }
    
    /// @custom:selector    0xcebbfa44
    /// @custom:signature   Unresolved_cebbfa44(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_cebbfa44(uint256 arg0) public {
        require(arg0 > 0, "unstake balance limit");
        require(!(unresolved_2ca41d40 > (arg0 + unresolved_2ca41d40)), "unstake balance limit");
        unresolved_2ca41d40 = arg0 + unresolved_2ca41d40;
        require(!(unresolved_267385b0 < (arg0 + unresolved_2ca41d40)), "unstake balance limit");
        require(!((unresolved_3d5edc7c - arg0) > unresolved_3d5edc7c), "unstake amount must > 0");
    }
    
    /// @custom:selector    0xab033ea9
    /// @custom:signature   setGovernance(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setGovernance(address arg0) public {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        governance = (address(arg0)) | (uint96(governance));
    }
    
    /// @custom:selector    0x68f02ab2
    /// @custom:signature   getNFilOut(uint256 arg0) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getNFilOut(uint256 arg0) public pure returns (uint256) {
        return arg0;
    }
    
    /// @custom:selector    0x16a58509
    /// @custom:signature   delBeneficiary(address arg0) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function delBeneficiary(address arg0) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        address var_e = address(arg0);
        require(storage_map_t[var_e], "address not in beneficiary");
        var_e = address(arg0);
        require(!storage_map_t[var_e], "address not in beneficiary");
        require(!((storage_map_t[var_e] - 0x01) > storage_map_t[var_e]), "address not in beneficiary");
        require(!((store_u - 0x01) > store_u), "address not in beneficiary");
        require((store_u - 0x01) == (storage_map_t[var_e] - 0x01), "address not in beneficiary");
        require((store_u - 0x01) < store_u, "address not in beneficiary");
        var_e = 0xca;
        require((storage_map_t[var_e] - 0x01) < store_u, "address not in beneficiary");
        var_e = 0xca;
        storage_map_v[storage_map_t[var_e] - 0x01] = storage_map_w[var_e];
        var_e = storage_map_w[var_e];
        storage_map_t[var_e] = storage_map_t[var_e];
        require(store_u, "address not in beneficiary");
        var_e = 0xca;
        storage_map_w[var_e] = 0;
        store_u = store_u - 0x01;
        var_e = address(arg0);
        storage_map_t[var_e] = 0;
        return 0x01;
        return 0;
    }
    
    /// @custom:selector    0x17cd802d
    /// @custom:signature   repayment() public view
    function repayment() public view {
        address var_a = address(msg.sender);
        require(storage_map_g[var_a], "value must > 0");
        require(msg.value > 0, "value must > 0");
        emit FilRepayment(msg.sender, msg.value);
    }
    
    /// @custom:selector    0x4f1ef286
    /// @custom:signature   Unresolved_4f1ef286(address arg0, uint256 arg1) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_4f1ef286(address arg0, uint256 arg1) public payable {
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 > 0xffffffffffffffff), "Function must be called through delegatecall");
        require(!(((var_c + (uint248((0x20 + (0x1f + (arg1))) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (0x1f + (arg1))) + 0x1f))) > 0xffffffffffffffff)), "Function must be called through delegatecall");
        require(address(this) - 0x73d1ef868bd977292151b6e309e389d4035aca9c, "Function must be called through delegatecall");
        require(address(store_x) == 0x73d1ef868bd977292151b6e309e389d4035aca9c, "Ownable: caller is not the owner");
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(!(bytes1(store_y)), "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_x = (address(arg0)) | (uint96(store_x));
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        var_a = var_a;
        require(0x01 == var_a, "ERC1967: new implementation is not a contract");
        require(address(0x089a).code.length, "ERC1967: new implementation is not a contract");
        store_x = 0x089a | (uint96(store_x));
        emit Upgraded(0x089a);
        require(var_k > 0);
        require(!var_k > 0);
        var_c = 0x60 + var_c;
        require(!0 < var_k);
        (bool success, bytes memory ret0) = address(0x089a).Unresolved_(var_n); // delegatecall
        require(ret0.length == 0);
        require(!var_o);
        require(0 - var_o, "Address: call to non-contract");
        require(address(0x089a).code.length, "Address: call to non-contract");
        var_c = var_c + (uint248(ret0.length + 0x3f));
        require(!var_c.length);
        require(0 - var_c.length, "Address: call to non-contract");
        require(address(0x089a).code.length, "Address: call to non-contract");
        require(!var_c, "ERC1967Upgrade: unsupported proxiableUUID");
        var_c = var_c + (uint248(ret0.length + 0x1f));
        require(!(((var_c + ret0.length) - var_c) < 0x20), "ERC1967Upgrade: new implementation is not UUPS");
        require(0x01, "ERC1967Upgrade: new implementation is not UUPS");
        var_a = var_a;
        require(var_c.length == var_a, "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        store_x = (address(arg0)) | (uint96(store_x));
        emit Upgraded(address(arg0));
        require(var_c.length > 0, "ERC1967Upgrade: unsupported proxiableUUID");
        require(!(var_c.length > 0), "ERC1967Upgrade: unsupported proxiableUUID");
        require(!0x01, "ERC1967Upgrade: unsupported proxiableUUID");
    }
    
    /// @custom:selector    0x3659cfe6
    /// @custom:signature   upgradeTo(address arg0) public
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function upgradeTo(address arg0) public {
        require(arg0 == (address(arg0)));
        require(address(this) - 0x73d1ef868bd977292151b6e309e389d4035aca9c, "Function must be called through delegatecall");
        require(address(unresolved_f6344fd9a) == 0x73d1ef868bd977292151b6e309e389d4035aca9c, "Ownable: caller is not the owner");
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(!(bytes1(store_y)), "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        unresolved_f6344fd9a = (address(arg0)) | (uint96(unresolved_f6344fd9a));
        (bool success, bytes memory ret0) = address(arg0).proxiableUUID(); // staticcall
        var_f = var_f;
        require(0 == var_f, "ERC1967: new implementation is not a contract");
        require(address(0x089c).code.length, "ERC1967: new implementation is not a contract");
        unresolved_f6344fd9a = 0x089c | (uint96(unresolved_f6344fd9a));
        emit Upgraded(0x089c);
        require(var_j > 0);
        require(!var_j > 0);
        var_g = 0x60 + var_g;
        require(!0 < var_j);
        (bool success, bytes memory ret0) = address(0x089c).Unresolved_(var_m); // delegatecall
        require(ret0.length == 0);
        require(!var_n);
        require(0 - var_n, "Address: call to non-contract");
        require(address(0x089c).code.length, "Address: call to non-contract");
        var_g = var_g + (uint248(ret0.length + 0x3f));
        require(!var_g.length);
        require(0 - var_g.length, "Address: call to non-contract");
        require(address(0x089c).code.length, "Address: call to non-contract");
        require(!var_g, "ERC1967Upgrade: unsupported proxiableUUID");
        var_g = var_g + (uint248(ret0.length + 0x1f));
        require(!(((var_g + ret0.length) - var_g) < 0x20), "ERC1967Upgrade: new implementation is not UUPS");
        require(0x01, "ERC1967Upgrade: new implementation is not UUPS");
        var_f = var_f;
        require(var_g.length == var_f, "ERC1967: new implementation is not a contract");
        require(address(arg0).code.length, "ERC1967: new implementation is not a contract");
        unresolved_f6344fd9a = (address(arg0)) | (uint96(unresolved_f6344fd9a));
        emit Upgraded(address(arg0));
        require(var_g.length > 0, "ERC1967Upgrade: unsupported proxiableUUID");
        require(!(var_g.length > 0), "ERC1967Upgrade: unsupported proxiableUUID");
    }
    
    /// @custom:selector    0x5926651d
    /// @custom:signature   addBeneficiary(address arg0) public returns (bool)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function addBeneficiary(address arg0) public returns (bool) {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(address(arg0), "address already in beneficiary");
        address var_e = address(arg0);
        require(!storage_map_t[var_e], "address already in beneficiary");
        var_e = address(arg0);
        require(storage_map_t[var_e], "address must != address(0)");
        return 0;
        store_u = 0x01 + store_u;
        var_e = 0xca;
        storage_map_ab[var_e] = address(arg0);
        var_e = address(arg0);
        storage_map_t[var_e] = store_u;
        return 0x01;
    }
    
    /// @custom:selector    0xc3178389
    /// @custom:signature   Unresolved_c3178389(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_c3178389(uint256 arg0) public {
        require(arg0 > 0, "unstake amount must > 0");
        require(!(unresolved_2ca41d40 > (arg0 + unresolved_2ca41d40)), "unstake amount must > 0");
        unresolved_2ca41d40 = arg0 + unresolved_2ca41d40;
        require(!((unresolved_3d5edc7c - arg0) > unresolved_3d5edc7c), "unstake amount must > 0");
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
    
    /// @custom:selector    0x88f9184f
    /// @custom:signature   Unresolved_88f9184f(address arg0) public view
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_88f9184f(address arg0) public view {
        require(arg0 == (address(arg0)));
        require(!(address(hubPool)), "caller is not hubpool");
        require(msg.sender == (address(hubPool)), "caller is not hubpool");
        require(msg.value > 0, "stake amount must > 0");
        require(!(unresolved_3d5edc7c > (msg.value + unresolved_3d5edc7c)), "stake amount must > 0");
        require(!(!address(hubPool)), "caller is not hubpool");
    }
    
    /// @custom:selector    0xca718c65
    /// @custom:signature   stakeFil() public view
    function stakeFil() public view {
        require(msg.value > 0, "stake amount must > 0");
        require(!(unresolved_3d5edc7c > (msg.value + unresolved_3d5edc7c)), "stake amount must > 0");
    }
    
    /// @custom:selector    0x427e5241
    /// @custom:signature   Unresolved_427e5241(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_427e5241(uint256 arg0) public {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        unresolved_267385b0 = arg0;
    }
    
    /// @custom:selector    0x655ada5f
    /// @custom:signature   setTotalPoolFilLimit(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function setTotalPoolFilLimit(uint256 arg0) public {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        unresolved_8846ee0f = arg0;
    }
    
    /// @custom:selector    0xe057aa26
    /// @custom:signature   getFilOut(uint256 arg0) public pure returns (uint256)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getFilOut(uint256 arg0) public pure returns (uint256) {
        return arg0;
    }
    
    /// @custom:selector    0xd5dc5b4a
    /// @custom:signature   beneficiarys() public view returns (bytes memory)
    function beneficiarys() public view returns (bytes memory) {
        if (!store_u > 0xffffffffffffffff) {
            uint256 var_d = var_d + (0x20 + (0x20 * store_u));
            if (!store_u) {
                if (!0 < store_u) {
                    if (0 < store_u) {
                        var_a = 0xca;
                        if (0x01) {
                            return abi.encodePacked(0x20, var_d.length);
                        }
                    }
                }
            }
        }
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public
    function renounceOwnership() public {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        owner = 0 | (uint96(owner));
        emit OwnershipTransferred(address(owner), 0);
    }
}