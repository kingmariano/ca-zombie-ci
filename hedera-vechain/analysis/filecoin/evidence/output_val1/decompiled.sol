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
    bytes32 store_a;
    
    fallback() external payable {
        require(msg.data.length);
        (bool success, bytes memory ret0) = address(store_a).implementation(); // staticcall
        uint256 var_a = var_a + (uint248(ret0.length + 0x1f));
        require(!((var_a + ret0.length) - var_a) < 0x20);
        require(var_a.length == (address(var_a.length)));
        (bool success, bytes memory ret0) = address(var_a.length).Unresolved_(var_d); // delegatecall
        return ;
    }
    
}