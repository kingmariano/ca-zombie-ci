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
    address public getManager;
    address public getStorageContractAddress;
    address public unresolved_7457bbf7;
    mapping(bytes32 => bytes32) storage_map_d;
    
    event ManagerUpdate(address, address);
    event TransferSingle(address, address, address, uint256, uint256);
    event TransferBatch(address, address, address, uint256[], uint256[]);
    
    /// @custom:selector    0x12ab550f
    /// @custom:signature   Unresolved_12ab550f(uint64 arg0, uint256 arg1, address arg2, address arg3) public payable returns (bytes memory)
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg3 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_12ab550f(uint64 arg0, uint256 arg1, address arg2, address arg3) public payable returns (bytes memory) {
        require(uint0(arg0));
        return abi.encodePacked(arg1, arg1, 0, 0, 0);
        uint64 var_f = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_f, var_g); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_h.length)) > 0x05);
        require(!(bytes1(var_h.length)) > 0x05);
        require(!(bytes1(var_h.length)) > 0);
        var_f = address(getStorageContractAddress);
        uint64 var_g = uint64(arg0);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_f, var_g, var_i); // delegatecall
        require(!ret0.length < 0x20);
        require(address(arg2) == (address(var_h.length)));
        require(!(address(var_h.length)) == (address(arg3)));
        var_f = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_f, var_g); // staticcall
        require(!ret0.length < 0x20);
        var_f = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_f, var_g); // staticcall
        require(!ret0.length < 0x20);
        var_f = uint64(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f8057921(var_f, var_g); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: mul overflow");
        require(!(bytes1(var_h.length) > 0x05), "SafeMath: mul overflow");
        require(!(bytes1(var_h.length) == 0x02), "SafeMath: mul overflow");
        require(var_h.length, "SafeMath: mul overflow");
        require(var_h.length, "SafeMath: mul overflow");
        require(((arg1 * var_h.length) / var_h.length) == arg1, "SafeMath: mul overflow");
        require(!(bytes1(var_h.length) > 0x05), "SafeMath: sub underflow");
        require(!(bytes1(var_h.length) == 0x03), "SafeMath: sub underflow");
        require(arg1, "SafeMath: sub underflow");
        require(arg1, "SafeMath: sub underflow");
        require(((var_h.length * arg1) / arg1) == var_h.length, "SafeMath: sub underflow");
        require(0x2710, "SafeMath: sub underflow");
        require(!(((var_h.length * arg1) / 0x2710) > arg1), "SafeMath: sub underflow");
        require(arg1, "SafeMath: mul overflow");
        require(arg1, "SafeMath: mul overflow");
        require(!(bytes1(var_h.length)) > 0x05);
        require(!(bytes1(var_h.length)) == 0x04);
        var_f = uint64(arg0);
        var_g = address(arg2);
        var_i = 0x04;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_f, var_g, var_i, var_j); // staticcall
        require(!ret0.length < 0x20);
        require(!var_h.length);
        return abi.encodePacked(arg1, arg1, var_h.length, var_h.length, var_h.length);
        return abi.encodePacked(arg1, arg1, var_h.length, 0, var_h.length);
        return abi.encodePacked(arg1, arg1, 0, 0, 0);
        return abi.encodePacked(arg1, arg1, 0, 0, 0);
    }
    
    /// @custom:selector    0x2eb2c2d6
    /// @custom:signature   Unresolved_2eb2c2d6(address arg0, address arg1, uint256 arg2, uint256 arg3, uint256 arg4) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_2eb2c2d6(address arg0, address arg1, uint256 arg2, uint256 arg3, uint256 arg4) public payable {
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
        require(!arg4 > 0x0100000000);
        require(address(arg1), "CryptoItemsTransfers: _ids and _values have different lengths");
        require(arg3 == (arg2), "CryptoItemsTransfers: _ids and _values have different lengths");
        uint256 var_c = (var_c + (arg2 * 0x20)) + 0x20;
        require(!arg2);
        var_f = this.code[13662:13662];
        require(msg.sender == (address(arg0)));
        uint256 var_d = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_d); // staticcall
        require(!ret0.length < 0x20);
        require(!0x01 == var_c.length);
        require(!0 < (arg2));
        require(0 < (arg2));
        var_c = var_c + 0x45;
        var_m = keccak256(var_f);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_m); // staticcall
        require(!ret0.length < 0x20);
        uint256 var_m = var_c.length;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(0x01 == var_c.length);
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(0x01 == var_c.length);
        var_m = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_m); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsTransfers: Sender is not approved");
        require(0x01 == var_c.length, "CryptoItemsTransfers: Sender is not approved");
        require(0 < (arg3), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        require(!(bytes1(0 + (0x20 + (arg2)))), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        require(!(uint16((0 + (0x20 + (arg2))) >> 0xe8)), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        var_m = address(arg0);
        require(address(uint224(0 + (0x20 + (arg2)))).code.length);
        (bool success, bytes memory ret0) = address(uint224(0 + (0x20 + (arg2)))).{ value: var_d ether }Unresolved_23b872dd(var_m); // call
        require(!ret0.length < 0x20);
        require(!uint0(0 + (0x20 + (arg2))));
        require(uint0(0 + (0x20 + (arg2))));
        require(0x01 == (0 + (0x20 + (arg3))));
        require(uint0(0 + (0x20 + (arg2))));
        var_m = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_d ether }Unresolved_95760fb9(var_m); // call
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0);
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_m = address(getStorageContractAddress);
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_m); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_c.length)));
        require(address(var_c.length) == (address(arg0)));
        require(address(var_c.length) == (address(arg1)));
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(address(arg0) == msg.sender);
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_m = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_m = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_m); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_c.length), "SafeMath: sub underflow");
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }Unresolved_23b872dd(var_m); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }Unresolved_23b872dd(var_m); // call
        require(!ret0.length < 0x20);
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }Unresolved_23b872dd(var_m); // call
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(((var_c.length * var_c.length) / var_c.length) == var_c.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_m); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_m = var_c.length;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_d ether }Unresolved_ffaf6633(var_m); // call
        emit TransferSingle(msg.sender, address(arg0), address(var_c.length), var_c.length, var_c.length);
        require(!address(var_c.length).code.length);
        var_m = msg.sender;
        var_n = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }Unresolved_f23a6e61(var_m, var_n); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_c.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(arg0) == msg.sender) {
        }
        var_m = uint64(0 + (0x20 + (arg2)));
        var_n = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_m = uint64(0 + (0x20 + (arg2)));
        var_n = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_m, var_n); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_c.length, "LibItemTransfers: _id is bound");
        require(uint0(0 + (0x20 + (arg2))));
        require(uint0(0 + (0x20 + (arg2))));
        var_m = (0 + (0x20 + (arg2)));
        var_n = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_d ether }Unresolved_ffaf6633(var_m, var_n); // call
        var_m = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) > 0);
        var_m = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(address(getStorageContractAddress).code.length);
        var_m = address(getStorageContractAddress);
        var_n = (0 + (0x20 + (arg2)));
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_m, var_n); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_c.length)));
        require(address(var_c.length) == (address(arg0)));
        require(address(var_c.length) == (address(arg1)));
        var_m = (0 + (0x20 + (arg2)));
        var_n = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(address(arg0) == msg.sender);
        var_m = (0 + (0x20 + (arg2)));
        var_n = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(!var_c.length);
        var_m = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) == 0x02);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) == 0x03);
        require(!(bytes1(var_c.length)) > 0x05);
        require(!(bytes1(var_c.length)) == 0x04);
        require(var_c.length);
        require(!var_c.length);
        var_m = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getUint(var_m); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_m); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_c.length), "SafeMath: sub underflow");
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }gasprice_bit_ether(var_m); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }gasprice_bit_ether(var_m); // call
        require(!ret0.length < 0x20);
        var_m = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }gasprice_bit_ether(var_m); // call
        require(!ret0.length < 0x20);
        require(var_c.length);
        require(((var_c.length * var_c.length) / var_c.length) == var_c.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_m); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_m = var_c.length;
        var_n = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_d ether }Unresolved_ffaf6633(var_m, var_n); // call
        emit TransferSingle(msg.sender, address(arg0), address(var_c.length), var_c.length, var_c.length);
        require(!address(var_c.length).code.length);
        var_m = msg.sender;
        var_n = address(arg0);
        require(address(var_c.length).code.length);
        (bool success, bytes memory ret0) = address(var_c.length).{ value: var_d ether }Unresolved_f23a6e61(var_m, var_n); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_c.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(arg0) == msg.sender) {
        }
        var_m = (0 + (0x20 + (arg2)));
        var_n = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_m, var_n); // staticcall
        require(!ret0.length < 0x20);
        require(var_c.length);
        var_m = (0 + (0x20 + (arg2)));
        var_n = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_m, var_n); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_c.length, "LibItemTransfers: _id is bound");
        require(!0 < (0x20 * var_c.length));
        emit TransferBatch(address(msg.sender), address(arg0), address(arg1), (0x20 + (0x20 + var_c)) - var_c, ((0x20 + (0x20 + (0x20 + var_c))) + (uint248((0x20 * (arg2)) + 0x1f))) - var_c, (arg2), var_c.length);
        require(!address(arg1).code.length);
        require(!0 < (0x20 * var_c.length));
        require(address(arg1).code.length);
        require(!0 < (arg2));
        require(0 < (arg2));
        require(0 < (arg3));
    }
    
    /// @custom:selector    0x48ff15b3
    /// @custom:signature   acceptManager() public payable
    function acceptManager() public payable {
        require(msg.sender == (address(unresolved_7457bbf7)), "Managed: Sender must be the new manager");
        emit ManagerUpdate(address(getManager), address(unresolved_7457bbf7));
        getManager = (address(unresolved_7457bbf7)) | (uint96(getManager));
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xa0a2daf0
    /// @custom:signature   delegates(bytes4 arg0) public view returns (address)
    /// @param              arg0 ["uint32", "bytes4", "int32"]
    function delegates(bytes4 arg0) public view returns (address) {
        uint32 var_b = uint32(arg0);
        return address(storage_map_d[var_b]);
    }
    
    /// @custom:selector    0xba0e930a
    /// @custom:signature   transferManager(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferManager(address arg0) public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        require(!(address(getManager) == (address(arg0))), "Managed: New manager needs to be different");
        unresolved_7457bbf7 = (address(arg0)) | (uint96(unresolved_7457bbf7));
    }
    
    /// @custom:selector    0xf242432a
    /// @custom:signature   Unresolved_f242432a(address arg0, address arg1, uint0 arg2, uint256 arg3, uint256 arg4) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg1 ["address", "uint160", "bytes20", "int160"]
    /// @param              arg2 ["uint0", "bytes0", "int0"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_f242432a(address arg0, address arg1, uint0 arg2, uint256 arg3, uint256 arg4) public payable {
        require(!arg4 > 0x0100000000);
        require(address(arg1));
        require(msg.sender == (address(arg0)));
        uint256 var_b = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        uint256 var_e = var_e + 0x45;
        var_i = keccak256(var_j);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_i); // staticcall
        require(!ret0.length < 0x20);
        uint256 var_i = var_e.length;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = uint64(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsTransfers: Sender is not approved");
        require(var_e.length, "CryptoItemsTransfers: Sender is not approved");
        require(!(bytes1(arg2)), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        require(!(uint16(arg2 >> 0xe8)), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        var_i = address(arg0);
        require(address(uint224(arg2)).code.length);
        (bool success, bytes memory ret0) = address(uint224(arg2)).{ value: var_b ether }Unresolved_23b872dd(var_i); // call
        require(!ret0.length < 0x20);
        emit TransferSingle(address(msg.sender), address(arg0), address(arg1), arg2, arg3);
        require(!address(arg1).code.length);
        var_i = msg.sender;
        var_k = address(arg0);
        uint256 var_s = 0;
        require(address(arg1).code.length);
        (bool success, bytes memory ret0) = address(arg1).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "CryptoItemsTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "CryptoItemsTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(!uint0(arg2));
        require(uint0(arg2));
        require(0x01 == arg3);
        require(uint0(arg2));
        var_i = arg2;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_95760fb9(var_i, var_k); // call
        var_i = uint64(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0);
        var_i = uint64(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = address(getStorageContractAddress);
        var_k = arg2;
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_i, var_k); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_e.length)));
        require(address(var_e.length) == (address(arg0)));
        require(address(var_e.length) == (address(arg1)));
        var_i = uint64(arg2);
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(arg0) == msg.sender);
        var_i = uint64(arg2);
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = uint64(arg2);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getUint(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_e.length), "SafeMath: sub underflow");
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(((var_e.length * var_e.length) / var_e.length) == var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_i = var_e.length;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        emit TransferSingle(msg.sender, address(arg0), address(var_e.length), var_e.length, var_e.length);
        require(!address(var_e.length).code.length);
        var_i = msg.sender;
        var_k = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(arg0) == msg.sender) {
        }
        var_i = uint64(arg2);
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = uint64(arg2);
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_e.length, "LibItemTransfers: _id is bound");
        require(uint0(arg2));
        require(uint0(arg2));
        var_i = arg2;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        var_i = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0);
        var_i = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(getStorageContractAddress).code.length);
        var_i = address(getStorageContractAddress);
        var_k = arg2;
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_i, var_k); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_e.length)));
        require(address(var_e.length) == (address(arg0)));
        require(address(var_e.length) == (address(arg1)));
        var_i = arg2;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(arg0) == msg.sender);
        var_i = arg2;
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = arg2;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x02);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x03);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x04);
        require(var_e.length);
        require(!var_e.length);
        var_i = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getUint(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_e.length), "SafeMath: sub underflow");
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        var_i = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(((var_e.length * var_e.length) / var_e.length) == var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_i = var_e.length;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        emit TransferSingle(msg.sender, address(arg0), address(var_e.length), var_e.length, var_e.length);
        require(!address(var_e.length).code.length);
        var_i = msg.sender;
        var_k = address(arg0);
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(arg0) == msg.sender) {
        }
        var_i = arg2;
        var_k = address(arg0);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = arg2;
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_e.length, "LibItemTransfers: _id is bound");
    }
    
    /// @custom:selector    0x8d0a3a08
    /// @custom:signature   removeManager() public payable
    function removeManager() public payable {
        require(msg.sender == (address(getManager)), "Managed: only manager");
        getManager = uint96(getManager);
        unresolved_7457bbf7 = uint96(unresolved_7457bbf7);
    }
    
    /// @custom:selector    0xff469a8e
    /// @custom:signature   Unresolved_ff469a8e(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    /// @param              arg3 ["uint256", "bytes32", "int256"]
    /// @param              arg4 ["uint256", "bytes32", "int256"]
    function Unresolved_ff469a8e(uint256 arg0, uint256 arg1, uint256 arg2, uint256 arg3, uint256 arg4) public payable {
        require(!arg0 > 0x0100000000);
        require(!arg1 > 0x0100000000);
        require(!arg2 > 0x0100000000);
        require(!arg3 > 0x0100000000);
        require(!arg4 > 0x0100000000);
        require(!0 < (arg0));
        require(0 < (arg1));
        require(!(address(0 + (0x20 + (arg1)))) == 0);
        require(0 < (arg0));
        require(0 < (arg2));
        require(address(0 + (0x20 + (arg0))) == (address(msg.sender)));
        uint256 var_b = 0;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_b); // staticcall
        require(!ret0.length < 0x20);
        require(0x01 == var_e.length);
        uint256 var_e = var_e + 0x45;
        var_i = keccak256(var_j);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_bd02d0f5(var_i); // staticcall
        require(!ret0.length < 0x20);
        uint256 var_i = var_e.length;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(0x01 == var_e.length);
        var_i = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(0x01 == var_e.length);
        var_i = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_f7250826(var_i); // staticcall
        require(!(ret0.length < 0x20), "CryptoItemsTransfers: Sender is not approved");
        require(0x01 == var_e.length, "CryptoItemsTransfers: Sender is not approved");
        require(0 < (arg3), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        require(!(bytes1(0 + (0x20 + (arg2)))), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        require(!(uint16((0 + (0x20 + (arg2))) >> 0xe8)), "LibItemTransfers: Fee currency for _id is not an external ERC currency");
        var_i = address(0 + (0x20 + (arg0)));
        require(address(uint224(0 + (0x20 + (arg2)))).code.length);
        (bool success, bytes memory ret0) = address(uint224(0 + (0x20 + (arg2)))).{ value: var_b ether }Unresolved_23b872dd(var_i); // call
        require(!ret0.length < 0x20);
        emit TransferSingle(address(msg.sender), address(0 + (0x20 + (arg0))), address(0 + (0x20 + (arg1))), (0 + (0x20 + (arg2))), (0 + (0x20 + (arg3))));
        require(!address(0 + (0x20 + (arg1))).code.length);
        var_i = address(msg.sender);
        var_k = address(0 + (0x20 + (arg0)));
        uint256 var_s = 0;
        require(address(0 + (0x20 + (arg1))).code.length);
        (bool success, bytes memory ret0) = address(0 + (0x20 + (arg1))).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "CryptoItemsTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "CryptoItemsTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(!uint0(0 + (0x20 + (arg2))));
        require(uint0(0 + (0x20 + (arg2))));
        require(0x01 == (0 + (0x20 + (arg3))));
        require(uint0(0 + (0x20 + (arg2))));
        var_i = (0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_95760fb9(var_i, var_k); // call
        var_i = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0);
        var_i = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = address(getStorageContractAddress);
        var_k = (0 + (0x20 + (arg2)));
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_i, var_k); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_e.length)));
        require(address(var_e.length) == (address(0 + (0x20 + (arg0)))));
        require(address(var_e.length) == (address(0 + (0x20 + (arg1)))));
        var_i = uint64(0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(0 + (0x20 + (arg0))) == msg.sender);
        var_i = uint64(0 + (0x20 + (arg2)));
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = uint64(0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getUint(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_e.length), "SafeMath: sub underflow");
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(((var_e.length * var_e.length) / var_e.length) == var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_i = var_e.length;
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        emit TransferSingle(msg.sender, address(0 + (0x20 + (arg0))), address(var_e.length), var_e.length, var_e.length);
        require(!address(var_e.length).code.length);
        var_i = msg.sender;
        var_k = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(0 + (0x20 + (arg0))) == msg.sender) {
        }
        var_i = uint64(0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = uint64(0 + (0x20 + (arg2)));
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_e.length, "LibItemTransfers: _id is bound");
        require(uint0(0 + (0x20 + (arg2))));
        require(uint0(0 + (0x20 + (arg2))));
        var_i = (0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        var_i = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_73007500(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) > 0);
        var_i = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_0a432df0(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(getStorageContractAddress).code.length);
        var_i = address(getStorageContractAddress);
        var_k = (0 + (0x20 + (arg2)));
        require(address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).code.length);
        (bool success, bytes memory ret0) = address(0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5).Unresolved_59356146(var_i, var_k); // delegatecall
        require(!ret0.length < 0x20);
        require(msg.sender == (address(var_e.length)));
        require(address(var_e.length) == (address(0 + (0x20 + (arg0)))));
        require(address(var_e.length) == (address(0 + (0x20 + (arg1)))));
        var_i = (0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(address(0 + (0x20 + (arg0))) == msg.sender);
        var_i = (0 + (0x20 + (arg2)));
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_5dbc33e7(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!var_e.length);
        var_i = (0 + (0x20 + (arg2)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_20ec4a86(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x02);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x03);
        require(!(bytes1(var_e.length)) > 0x05);
        require(!(bytes1(var_e.length)) == 0x04);
        require(var_e.length);
        require(!var_e.length);
        var_i = 0x2e230464d0e672cb48a042c401050c3dd9d5d24ee54b92d8dca91b6308eddb29;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getUint(var_i); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        require(!(ret0.length < 0x20), "SafeMath: sub underflow");
        require(!0, "SafeMath: sub underflow");
        require(!(0 > var_e.length), "SafeMath: sub underflow");
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).getManager(); // staticcall
        require(!ret0.length < 0x20);
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        var_i = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }gasprice_bit_ether(var_i); // call
        require(!ret0.length < 0x20);
        require(var_e.length);
        require(((var_e.length * var_e.length) / var_e.length) == var_e.length);
        require(0x2710);
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_fed57875(var_i); // staticcall
        if (!ret0.length < 0x20) {
            require(!ret0.length < 0x20);
        }
        var_i = var_e.length;
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).{ value: var_s ether }Unresolved_ffaf6633(var_i, var_k); // call
        emit TransferSingle(msg.sender, address(0 + (0x20 + (arg0))), address(var_e.length), var_e.length, var_e.length);
        require(!address(var_e.length).code.length);
        var_i = msg.sender;
        var_k = address(0 + (0x20 + (arg0)));
        require(address(var_e.length).code.length);
        (bool success, bytes memory ret0) = address(var_e.length).{ value: var_s ether }Unresolved_f23a6e61(var_i, var_k); // call
        require(!(ret0.length < 0x20), "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        require(uint32(var_e.length) == 0xf23a6e6100000000000000000000000000000000000000000000000000000000, "LibItemTransfers: Receiving contract did not return ERC1155_ACCEPTED");
        if (address(0 + (0x20 + (arg0))) == msg.sender) {
        }
        var_i = (0 + (0x20 + (arg2)));
        var_k = address(0 + (0x20 + (arg0)));
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!ret0.length < 0x20);
        require(var_e.length);
        var_i = (0 + (0x20 + (arg2)));
        var_k = msg.sender;
        require(address(getStorageContractAddress).code.length);
        (bool success, bytes memory ret0) = address(getStorageContractAddress).Unresolved_270c373e(var_i, var_k); // staticcall
        require(!(ret0.length < 0x20), "LibItemTransfers: _id is bound");
        require(var_e.length, "LibItemTransfers: _id is bound");
    }
}