[2m2026-10-03T15:30:55.331872Z[0m [33m WARN[0m discovered no function selectors in the bytecode.
ABI:

[]
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
    uint32 store_a;
    
    error FailedCall();
    fallback() external payable {
        var_a = 0x80;
        require(msg.sender - 0x084a0738a29a3bfc233d3cb318ff7b63d97d49e4);
        require(0x4f1ef28600000000000000000000000000000000000000000000000000000000 == (uint32(msg.data[0])));
        require(!msg.data.length > msg.data.length);
        require(arg0 == (address(arg0)));
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1 > 0xffffffffffffffff), CustomError_4c9c8ce3());
        require(!(((var_a + (uint248(0x3f + (arg1 + 0x1f)))) < var_a) | ((var_a + (uint248(0x3f + (arg1 + 0x1f)))) > 0xffffffffffffffff)), CustomError_4c9c8ce3());
        uint256 var_a = var_a + (uint248(0x3f + (arg1 + 0x1f)));
        require(0 - (address(arg0).code.length), CustomError_4c9c8ce3());
        store_a = (address(arg0)) | (uint96(store_a));
        require(!var_a.length);
        (bool success, bytes memory ret0) = address(arg0).Unresolved_(var_h); // delegatecall
        require(ret0.length == 0);
        require(!var_i);
        require(var_i, CustomError_9996b315());
        require(var_i, CustomError_9996b315());
        require(!(!address(arg0).code.length), CustomError_9996b315());
        var_a = var_a + (uint248(ret0.length + 0x3f));
        require(!var_a.length, CustomError_d6bda275());
        require(var_a.length, CustomError_9996b315());
        require(!(!address(arg0).code.length), CustomError_9996b315());
        (bool success, bytes memory ret0) = address(store_a).Unresolved_(var_l); // delegatecall
        return 0x4e487b7100000000000000000000000000000000000000000000000000000000;
    }
    
}
