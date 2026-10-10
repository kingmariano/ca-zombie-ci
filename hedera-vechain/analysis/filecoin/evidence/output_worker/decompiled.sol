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
    uint256 public constant controller = 270280320065459219056952542332805843503045711996;
    
    bytes32 store_b;
    uint64 public unresolved_3ee9cfd9;
    uint256 public unresolved_983a8932;
    uint256 public unresolved_9efc15be;
    uint256 public unresolved_82cb98c0;
    
    
    /// @custom:selector    0xce746024
    /// @custom:signature   recover() public
    function recover() public {
        require(0x2f57c9e9703f6b04a711206e0cab4eb42408987c == msg.sender, "invalid recovery phase");
        require(!(bytes1(unresolved_3ee9cfd9) > 0x03), "invalid recovery phase");
        require(bytes1(unresolved_3ee9cfd9) == 0, "invalid recovery phase");
        (bool success, bytes memory ret0) = address(0xfd669bddfbb0d085135cbd92521785c39c95ba4b).availableFIL(); // staticcall
        var_a = var_a + (uint248(ret0.length + 0x1f));
        if (!((var_a + ret0.length) - var_a) < 0x20) {
            var_a = 0x36 + var_a;
            if (!var_a.length > 0xffffffffffffffff) {
                require(!((var_a + ret0.length) - var_a) < 0x20);
                require(!var_a.length > 0xffffffffffffffff);
                require(bytes1(store_b));
                require(bytes1(store_b) - ((store_b >> 0x01) < 0x20));
                require(!(store_b >> 0x01) > 0x1f);
                require(!var_a.length < 0x20);
                var_l = 0x04;
                require(!(keccak256(var_l) + ((var_a.length + 0x1f) >> 0x05)) < (keccak256(var_l) + (((store_b >> 0x01) + 0x1f) >> 0x05)));
                require((var_a.length > 0x1f) == 0x01);
            }
            require(!0 < (uint248(var_a.length)));
        }
    }
    
    /// @custom:selector    0xaccf537e
    /// @custom:signature   Unresolved_accf537e(uint64 arg0) public
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_accf537e(uint64 arg0) public {
        require(arg0 == (uint64(arg0)));
        require(0x2f57c9e9703f6b04a711206e0cab4eb42408987c == msg.sender, "invalid cleanup phase");
        require(!(bytes1(unresolved_3ee9cfd9) > 0x03), "invalid cleanup phase");
        require(!(bytes1(unresolved_3ee9cfd9) == 0x01), "invalid cleanup phase");
        require(uint64(unresolved_3ee9cfd9 / 0x0100) == (uint64(arg0)), "invalid cleanup phase");
        unresolved_3ee9cfd9 = 0x02 | (uint248(unresolved_3ee9cfd9));
        uint64 var_d = uint64(arg0);
        require(address(0xfd669bddfbb0d085135cbd92521785c39c95ba4b).code.length);
        (bool success, bytes memory ret0) = address(0xfd669bddfbb0d085135cbd92521785c39c95ba4b).{ value: 0 ether }Unresolved_0a165167(var_d); // call
        require(bytes1(unresolved_3ee9cfd9) == 0x01, "invalid cleanup phase");
    }
    
    /// @custom:selector    0x35faa416
    /// @custom:signature   sweep() public returns (uint256)
    function sweep() public returns (uint256) {
        require(0x2f57c9e9703f6b04a711206e0cab4eb42408987c == msg.sender, "recovery transfer failed");
        require(!(bytes1(unresolved_3ee9cfd9) > 0x03), "recovery transfer failed");
        require(bytes1(unresolved_3ee9cfd9) == 0x02, "recovery transfer failed");
        unresolved_3ee9cfd9 = 0x03 | (uint248(unresolved_3ee9cfd9));
        (bool success, bytes memory ret0) = address(0x5c3c4e041af89e7009f7ddc23d6ca34cb28672).transfer(address(this).balance);
        require(ret0.length == 0, "recovery transfer failed");
        return address(this).balance;
    }
    
    /// @custom:selector    0x868e10c4
    /// @custom:signature   Unresolved_868e10c4(uint64 arg0) public pure
    /// @param              arg0 ["uint64", "bytes8", "int64"]
    function Unresolved_868e10c4(uint64 arg0) public pure {
        require(arg0 == (uint64(arg0)));
    }
}