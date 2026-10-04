/// @title            Decompiled Contract
/// @author           Jonathan Becker <jonathan@jbecker.dev>
/// @custom:version   heimdall-rs v0.9.2
///
/// @notice           This contract was decompiled using the heimdall-rs decompiler.
///                     It was generated directly by tracing the EVM opcodes from this contract.
///                     As a result, it may not compile or even be valid yul code.
///                     Despite this, it should be obvious what each function does. Overall
///                     logic should have been preserved throughout decompiling.
///
/// @custom:github    You can find the open-source decompiler here:
///                       https://heimdall.rs

object "DecompiledContract" {
    object "runtime" {
        code {
            
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }
            
            function castToAddress(x) -> a {
                a := and(x, 0xffffffffffffffffffffffffffffffffffffffff)
            }
            
            switch selector()
            
            /*
            * @custom:signature    admin_() public payable returns (address)
            */
            case 0xa4baf750 {
                mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                    returndatacopy(0, 0, returndatasize())
                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                        if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0xa0, and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    MIN_PROPOSAL_THRESHOLD_RATE() public pure returns (uint256)
            */
            case 0x4c43f1f9 {
                mstore(0x80, 0x01)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    latestProposalIds(address arg0) public view returns (uint256)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x17977c61 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0x20, 0x0b)
                        mstore(0, calldataload(0x04))
                        mstore(0x80, sload(sha3(0, 0x40)))
                        return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    setProposalFee(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x10bf5068 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    votingPeriod() public view returns (uint256)
            */
            case 0x02a251a3 {
                mstore(0x80, sload(0x05))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    setVotingDelay(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x70b0f660 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    version() public pure returns (bytes memory)
            */
            case 0x54fd4d50 {
                mstore(0x40, add(0x40, mload(0x40)))
                mstore(0x80, 0x12)
                mstore(0xa0, 0x476f7665726e616e636532303235303532330000000000000000000000000000)
                mstore(0xc0, 0x20)
                mstore(0xe0, mload(mload(0x40)))
                if iszero(lt(0, mload(mload(0x40)))) {
                    mstore(0x0112, 0)
                    return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                    mstore(0x0100, mload(add(0x20, add(mload(0x40), 0))))
                    if iszero(lt(0x20, mload(mload(0x40)))) {
                        mstore(0x0112, 0)
                        return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    MAX_QUORUM_VOTES_RATE() public pure returns (uint256)
            */
            case 0xdb69142b {
                mstore(0x80, 0x2710)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    setVotingPeriod(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xea0217cf {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    proposalFee() public view returns (uint256)
            */
            case 0xc27cabb5 {
                mstore(0x80, sload(0x01))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    votingDelay() public view returns (uint256)
            */
            case 0x3932abb1 {
                mstore(0x80, sload(0x04))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    MAX_VOTING_DELAY() public pure returns (uint256)
            */
            case 0xb1126263 {
                mstore(0x80, 0x093a80)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    name() public pure returns (string memory)
            */
            case 0x06fdde03 {
                mstore(0x40, add(0x40, mload(0x40)))
                mstore(0x80, 0x0a)
                mstore(0xa0, 0x476f7665726e616e636500000000000000000000000000000000000000000000)
                mstore(0xc0, 0x20)
                mstore(0xe0, mload(mload(0x40)))
                if iszero(lt(0, mload(mload(0x40)))) {
                    mstore(0x010a, 0)
                    return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                    mstore(0x0100, mload(add(0x20, add(mload(0x40), 0))))
                    if iszero(lt(0x20, mload(mload(0x40)))) {
                        mstore(0x010a, 0)
                        return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    MIN_VOTING_PERIOD() public pure returns (uint256)
            */
            case 0x215809ca {
                mstore(0x80, 0x015180)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    _withdrawFee(address arg0) public payable
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xf536642f {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                        staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                        if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                            returndatacopy(0, 0, returndatasize())
                            mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                            if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                    mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                        returndatacopy(0, 0, returndatasize())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_33b9087a(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x33b9087a {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_5d3e6602(uint256 arg0, uint256 arg1, uint256 arg2) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            * @param                arg2 ["uint256", "bytes32", "int256"]
            */
            case 0x5d3e6602 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x60)) {
                    if eq(calldataload(0x24), iszero(iszero(calldataload(0x24)))) { revert(0, 0); } else {
                        if iszero(gt(calldataload(0x44), 0xffffffffffffffff)) { revert(0, 0); } else {
                            if slt(add(add(0x04, calldataload(0x44)), 0x1f), calldatasize()) {
                                if iszero(gt(calldataload(add(0x04, calldataload(0x44))), 0xffffffffffffffff)) { revert(0, 0); } else {
                                    if iszero(gt(add(add(add(0x04, calldataload(0x44)), calldataload(add(0x04, calldataload(0x44)))), 0x20), calldatasize())) {
                                        if iszero(iszero(lt(sload(0x08), calldataload(0x04)))) {
                                            if iszero(lt(sload(0x08), calldataload(0x04))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x84, 0x20)
                                                mstore(0xa4, 0x13)
                                                mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                                                mstore(0, calldataload(0x04))
                                                mstore(0x20, 0x09)
                                                if iszero(gt(number(), sload(add(sha3(0, 0x40), 0x02)))) {
                                                    mstore(0x80, 0x165defa400000000000000000000000000000000000000000000000000000000)
                                                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                        returndatacopy(0, 0, returndatasize())
                                                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                            if iszero(and(0xff, sload(add(sha3(0, 0x40), 0x06)))) {
                                                                if iszero(gt(0x02, 0x05)) {
                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                    mstore(0x04, 0x21)
                                                                    if eq(0x02, 0x01) {
                                                                        mstore(0, calldataload(0x04))
                                                                        mstore(0x20, 0x09)
                                                                        mstore(0x20, 0x0a)
                                                                        mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                        mstore(0x20, sha3(0, 0x40))
                                                                        if iszero(and(0xff, sload(sha3(0, 0x40)))) { revert(mload(0x40), sub(add(0x84, mload(0x40)), mload(0x40))); } else {
                                                                            mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                            mstore(0xa4, 0x20)
                                                                            mstore(0xc4, 0x2f)
                                                                            mstore(0xe4, 0x476f7665726e6f723a3a63617374566f7465496e7465726e616c3a20766f7465)
                                                                            mstore(0x0104, 0x7220616c726561647920766f7465640000000000000000000000000000000000)
                                                                            sstore(sha3(0, 0x40), or(0x01, and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00, sload(sha3(0, 0x40)))))
                                                                            mstore(0xa0, 0xdfe33f1a00000000000000000000000000000000000000000000000000000000)
                                                                            mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                            mstore(0xc4, sload(add(sha3(0, 0x40), 0x02)))
                                                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x60)
                                                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x60))) { revert(0, returndatasize()); } else {
                                                                                returndatacopy(0, 0, returndatasize())
                                                                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x60)) {
                                                                                    if sub(0, mload(add(mload(0x40), 0x20))) {
                                                                                        if iszero(calldataload(0x24)) {
                                                                                            if iszero(gt(sload(add(0x04, sha3(0, 0x40))), add(mload(add(mload(0x40), 0x20)), sload(add(0x04, sha3(0, 0x40)))))) {
                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0x04, 0x11)
                                                                                                sstore(add(sha3(0, 0x40), 0x04), add(mload(add(mload(0x40), 0x20)), sload(add(0x04, sha3(0, 0x40)))))
                                                                                                sstore(sha3(0, 0x40), or(mul(iszero(iszero(calldataload(0x24))), 0x0100), and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff, sload(sha3(0, 0x40)))))
                                                                                                sstore(add(sha3(0, 0x40), 0x01), mload(add(mload(0x40), 0x20)))
                                                                                                mstore(0xc0, 0x2b431acd00000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0xc4, sload(add(sha3(0, 0x40), 0x02)))
                                                                                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                                                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                                                    returndatacopy(0, 0, returndatasize())
                                                                                                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                                                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                                                        if or(eq(sload(0x02), div(mul(sload(0x02), mload(mload(0x40))), mload(mload(0x40)))), iszero(mload(mload(0x40)))) {
                                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                            mstore(0x04, 0x11)
                                                                                                            if 0x2710 { revert(mload(0x40), sub(add(0x84, mload(0x40)), mload(0x40))); } else {
                                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                mstore(0x04, 0x12)
                                                                                                                codecopy(0, 0x2016, 0x20)
                                                                                                                mstore(0, mload(0))
                                                                                                                mstore(0xe0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                                                mstore(0x0100, calldataload(0x04))
                                                                                                                mstore(0x0120, iszero(iszero(calldataload(0x24))))
                                                                                                                mstore(0x0140, mload(add(mload(0x40), 0x20)))
                                                                                                                mstore(0x0160, sload(add(sha3(0, 0x40), 0x05)))
                                                                                                                mstore(0x0180, sload(add(sha3(0, 0x40), 0x04)))
                                                                                                                mstore(0x01a0, div(mul(sload(0x02), mload(mload(0x40))), 0x2710))
                                                                                                                mstore(0x01c0, 0x0100)
                                                                                                                mstore(0x01e0, calldataload(add(0x04, calldataload(0x44))))
                                                                                                                calldatacopy(add(mload(0x40), 0x0120), add(0x20, add(0x04, calldataload(0x44))), calldataload(add(0x04, calldataload(0x44))))
                                                                                                                mstore(0x0200, 0)
                                                                                                                log1(mload(0x40), sub(add(0x0120, add(mload(0x40), and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0, add(calldataload(add(0x04, calldataload(0x44))), 0x1f)))), mload(0x40)), mload(0))
                                                                                                                mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                mstore(0xa4, 0x20)
                                                                                                                mstore(0xc4, 0x2c)
                                                                                                                mstore(0xe4, 0x476f7665726e6f723a3a63617374566f7465496e7465726e616c3a20766f7469)
                                                                                                                mstore(0x0104, 0x6e6720697320636c6f7365640000000000000000000000000000000000000000)
                                                                                                                if gt(number(), sload(add(0x02, sha3(0, 0x40)))) {
                                                                                                                    if gt(number(), sload(add(0x03, sha3(0, 0x40)))) {
                                                                                                                        if iszero(gt(sload(add(0x04, sha3(0, 0x40))), sload(add(0x05, sha3(0, 0x40))))) {
                                                                                                                            if iszero(lt(sload(add(0x04, sha3(0, 0x40))), mload(mload(0x40)))) {
                                                                                                                                if and(0xff, div(sload(add(sha3(0, 0x40), 0x06)), 0x0100)) { revert(0, 0); } else {
                                                                                                                                }
                                                                                                                                mstore(0x80, 0x2b431acd00000000000000000000000000000000000000000000000000000000)
                                                                                                                                mstore(0x84, sload(add(sha3(0, 0x40), 0x02)))
                                                                                                                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                                                                                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                                                                                    returndatacopy(0, 0, returndatasize())
                                                                                                                                    if gt(calldataload(0x04), 0) { revert(0, 0); } else {
                                                                                                                                        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                        mstore(0x84, 0x20)
                                                                                                                                        mstore(0xa4, 0x13)
                                                                                                                                        mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                                                                                                                                    }
                                                                                                                                }
                                                                                                                            }
                                                                                                                        }
                                                                                                                    }
                                                                                                                }
                                                                                                            }
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_1e84c725(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x1e84c725 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x60)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                    }
                }
            }
            
            /*
            * @custom:signature    proposals(uint256 arg0) public view returns (bool)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x013cf08b {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) { revert(0, 0); } else {
                    mstore(0x20, 0x09)
                    mstore(0, calldataload(0x04))
                    mstore(0x80, sload(sha3(0, 0x40)))
                    mstore(0xa0, and(and(sload(add(sha3(0, 0x40), 0x01)), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff))
                    mstore(0xc0, sload(add(sha3(0, 0x40), 0x02)))
                    mstore(0xe0, sload(add(sha3(0, 0x40), 0x03)))
                    mstore(0x0100, sload(add(sha3(0, 0x40), 0x04)))
                    mstore(0x0120, sload(add(sha3(0, 0x40), 0x05)))
                    mstore(0x0140, iszero(iszero(and(sload(add(sha3(0, 0x40), 0x06)), 0xff))))
                    mstore(0x0160, iszero(iszero(and(div(sload(add(sha3(0, 0x40), 0x06)), 0x0100), 0xff))))
                    return(mload(0x40), sub(add(0x0100, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    MIN_QUORUM_VOTES_RATE() public pure returns (uint256)
            */
            case 0x2f5e00a8 {
                mstore(0x80, 0x64)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    Unresolved_190c6d40(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x190c6d40 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    MAX_VOTING_PERIOD() public pure returns (uint256)
            */
            case 0xa64e024a {
                mstore(0x80, 0x093a80)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    proposalState(uint256 arg0) public payable returns (uint256)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xd26331d4 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    if iszero(iszero(lt(sload(0x08), calldataload(0x04)))) {
                        if iszero(lt(sload(0x08), calldataload(0x04))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                            mstore(0x84, 0x20)
                            mstore(0xa4, 0x13)
                            mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                            mstore(0, calldataload(0x04))
                            mstore(0x20, 0x09)
                            if iszero(gt(number(), sload(add(sha3(0, 0x40), 0x02)))) {
                                mstore(0x80, 0x165defa400000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                    returndatacopy(0, 0, returndatasize())
                                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                        if iszero(and(0xff, sload(add(sha3(0, 0x40), 0x06)))) {
                                            if lt(0x02, 0x06) {
                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                mstore(0x04, 0x21)
                                                mstore(0xa0, 0x02)
                                                return(mload(0x40), sub(add(mload(0x40), 0x20), mload(0x40)))
                                                if gt(number(), sload(add(0x02, sha3(0, 0x40)))) {
                                                    if gt(number(), sload(add(0x03, sha3(0, 0x40)))) {
                                                        if iszero(gt(sload(add(0x04, sha3(0, 0x40))), sload(add(0x05, sha3(0, 0x40))))) {
                                                            if iszero(lt(sload(add(0x04, sha3(0, 0x40))), mload(mload(0x40)))) {
                                                                if and(0xff, div(sload(add(sha3(0, 0x40), 0x06)), 0x0100)) { revert(0, 0); } else {
                                                                }
                                                                mstore(0x80, 0x2b431acd00000000000000000000000000000000000000000000000000000000)
                                                                mstore(0x84, sload(add(sha3(0, 0x40), 0x02)))
                                                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                    returndatacopy(0, 0, returndatasize())
                                                                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                        if or(eq(sload(0x02), div(mul(sload(0x02), mload(mload(0x40))), mload(mload(0x40)))), iszero(mload(mload(0x40)))) {
                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                            mstore(0x04, 0x11)
                                                                            if 0x2710 {
                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0x04, 0x12)
                                                                                if iszero(and(0xff, sload(add(sha3(0, 0x40), 0x06)))) {
                                                                                    if gt(number(), sload(add(0x02, sha3(0, 0x40)))) {
                                                                                        if gt(number(), sload(add(0x03, sha3(0, 0x40)))) {
                                                                                            if iszero(gt(sload(add(0x04, sha3(0, 0x40))), sload(add(0x05, sha3(0, 0x40))))) {
                                                                                                if iszero(lt(sload(add(0x04, sha3(0, 0x40))), div(mul(sload(0x02), mload(mload(0x40))), 0x2710))) {
                                                                                                    if and(0xff, div(sload(add(sha3(0, 0x40), 0x06)), 0x0100)) {
                                                                                                    }
                                                                                                    if iszero(iszero(gt(sload(add(0x04, sha3(0, 0x40))), sload(add(0x05, sha3(0, 0x40)))))) { revert(0, 0); } else {
                                                                                                    }
                                                                                                    if gt(calldataload(0x04), 0) { revert(0, 0); } else {
                                                                                                        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                        mstore(0x84, 0x20)
                                                                                                        mstore(0xa4, 0x13)
                                                                                                        mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_1c4afc57(uint256 arg0, uint256 arg1) public pure
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x1c4afc57 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if iszero(gt(calldataload(0x04), 0xffffffffffffffff)) { revert(0, 0); } else {
                        if slt(add(add(0x04, calldataload(0x04)), 0x1f), calldatasize()) {
                            if iszero(gt(calldataload(add(0x04, calldataload(0x04))), 0xffffffffffffffff)) {
                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                mstore(0x04, 0x41)
                                if iszero(or(lt(add(mload(0x40), and(add(0x3f, and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0, add(calldataload(add(0x04, calldataload(0x04))), 0x1f))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), mload(0x40)), gt(add(mload(0x40), and(add(0x3f, and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0, add(calldataload(add(0x04, calldataload(0x04))), 0x1f))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0xffffffffffffffff))) {
                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                    mstore(0x04, 0x41)
                                    mstore(0x40, add(mload(0x40), and(add(0x3f, and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0, add(calldataload(add(0x04, calldataload(0x04))), 0x1f))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                    mstore(0x80, calldataload(add(0x04, calldataload(0x04))))
                                    if iszero(gt(add(add(add(0x04, calldataload(0x04)), calldataload(add(0x04, calldataload(0x04)))), 0x20), calldatasize())) {
                                        calldatacopy(add(mload(0x40), 0x20), add(add(0x04, calldataload(0x04)), 0x20), calldataload(add(0x04, calldataload(0x04))))
                                        mstore(0xa0, 0)
                                        if iszero(gt(calldataload(0x24), 0xffffffffffffffff)) { revert(0, 0); } else {
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    proposalCount() public view returns (uint256)
            */
            case 0xda35c664 {
                mstore(0x80, sload(0x08))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    RATE_DENOM() public pure returns (uint256)
            */
            case 0xed9e7b2f {
                mstore(0x80, 0x2710)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    owner_() public payable
            */
            case 0xe7663079 {
                mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                    returndatacopy(0, 0, returndatasize())
                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                        if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                            mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                returndatacopy(0, 0, returndatasize())
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    execute(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xfe0d94c1 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    proposalReceipts(uint256 arg0, address arg1) public view returns (bool)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x66176743 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x24), and(calldataload(0x24), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0x20, 0x0a)
                        mstore(0, calldataload(0x04))
                        mstore(0x20, sha3(0, 0x40))
                        mstore(0, calldataload(0x24))
                        mstore(0x80, iszero(iszero(and(sload(sha3(0, 0x40)), 0xff))))
                        mstore(0xa0, iszero(iszero(and(div(sload(sha3(0, 0x40)), 0x0100), 0xff))))
                        mstore(0xc0, sload(add(sha3(0, 0x40), 0x01)))
                        return(mload(0x40), sub(add(0x60, mload(0x40)), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    orc() public view returns (address)
            */
            case 0x0a0d8525 {
                mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    MIN_VOTING_DELAY() public pure returns (uint256)
            */
            case 0xe48083fe {
                mstore(0x80, 0)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    cancel(uint256 arg0) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x40e58ee5 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                        returndatacopy(0, 0, returndatasize())
                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                            if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                    returndatacopy(0, 0, returndatasize())
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_105d6f9e(address arg0, uint256 arg1) public payable
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x105d6f9e {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0x80, 0x6e9960c300000000000000000000000000000000000000000000000000000000)
                        staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                        if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, address()), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                            returndatacopy(0, 0, returndatasize())
                            mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                            if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                    mstore(0xa0, 0x8da5cb5b00000000000000000000000000000000000000000000000000000000)
                                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, 0); } else {
                                        returndatacopy(0, 0, returndatasize())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    proposalThresholdRate() public view returns (uint256)
            */
            case 0x9c0784fd {
                mstore(0x80, sload(0x03))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    MAX_PROPOSAL_THRESHOLD_RATE() public pure returns (uint256)
            */
            case 0x5eff165c {
                mstore(0x80, 0x03e8)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    Unresolved_15373e3d(uint256 arg0, uint256 arg1) public payable
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x15373e3d {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x24), iszero(iszero(calldataload(0x24)))) { revert(0, 0); } else {
                        if iszero(iszero(lt(sload(0x08), calldataload(0x04)))) {
                            if iszero(lt(sload(0x08), calldataload(0x04))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                mstore(0x84, 0x20)
                                mstore(0xa4, 0x13)
                                mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                                mstore(0, calldataload(0x04))
                                mstore(0x20, 0x09)
                                if iszero(gt(number(), sload(add(sha3(0, 0x40), 0x02)))) {
                                    mstore(0x80, 0x165defa400000000000000000000000000000000000000000000000000000000)
                                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, div(sload(0x07), 0x01))), mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                        returndatacopy(0, 0, returndatasize())
                                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                            if iszero(and(0xff, sload(add(sha3(0, 0x40), 0x06)))) {
                                                if iszero(gt(0x02, 0x05)) {
                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                    mstore(0x04, 0x21)
                                                    if eq(0x02, 0x01) {
                                                        mstore(0, calldataload(0x04))
                                                        mstore(0x20, 0x09)
                                                        mstore(0x20, 0x0a)
                                                        mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                        mstore(0x20, sha3(0, 0x40))
                                                        if iszero(and(0xff, sload(sha3(0, 0x40)))) { revert(mload(0x40), sub(add(0x84, mload(0x40)), mload(0x40))); } else {
                                                            mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                            mstore(0xa4, 0x20)
                                                            mstore(0xc4, 0x2f)
                                                            mstore(0xe4, 0x476f7665726e6f723a3a63617374566f7465496e7465726e616c3a20766f7465)
                                                            mstore(0x0104, 0x7220616c726561647920766f7465640000000000000000000000000000000000)
                                                            sstore(sha3(0, 0x40), or(0x01, and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00, sload(sha3(0, 0x40)))))
                                                            mstore(0xa0, 0xdfe33f1a00000000000000000000000000000000000000000000000000000000)
                                                            mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                            mstore(0xc4, sload(add(sha3(0, 0x40), 0x02)))
                                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x60)
                                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x60))) { revert(0, returndatasize()); } else {
                                                                returndatacopy(0, 0, returndatasize())
                                                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x60)) {
                                                                    if sub(0, mload(add(mload(0x40), 0x20))) {
                                                                        if iszero(calldataload(0x24)) {
                                                                            if iszero(gt(sload(add(0x04, sha3(0, 0x40))), add(mload(add(mload(0x40), 0x20)), sload(add(0x04, sha3(0, 0x40)))))) {
                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0x04, 0x11)
                                                                                sstore(add(sha3(0, 0x40), 0x04), add(mload(add(mload(0x40), 0x20)), sload(add(0x04, sha3(0, 0x40)))))
                                                                                sstore(sha3(0, 0x40), or(mul(iszero(iszero(calldataload(0x24))), 0x0100), and(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff, sload(sha3(0, 0x40)))))
                                                                                sstore(add(sha3(0, 0x40), 0x01), mload(add(mload(0x40), 0x20)))
                                                                                mstore(0xc0, 0x2b431acd00000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0xc4, sload(add(sha3(0, 0x40), 0x02)))
                                                                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                                    returndatacopy(0, 0, returndatasize())
                                                                                    mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                                    if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                                        if or(eq(sload(0x02), div(mul(sload(0x02), mload(mload(0x40))), mload(mload(0x40)))), iszero(mload(mload(0x40)))) {
                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x04, 0x11)
                                                                                            if 0x2710 { revert(mload(0x40), sub(add(0x84, mload(0x40)), mload(0x40))); } else {
                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0x04, 0x12)
                                                                                                mstore(0xe0, caller())
                                                                                                mstore(0x0100, calldataload(0x04))
                                                                                                mstore(0x0120, iszero(iszero(calldataload(0x24))))
                                                                                                mstore(0x0140, mload(add(mload(0x40), 0x20)))
                                                                                                mstore(0x0160, sload(add(sha3(0, 0x40), 0x05)))
                                                                                                mstore(0x0180, sload(add(sha3(0, 0x40), 0x04)))
                                                                                                mstore(0x01a0, div(mul(sload(0x02), mload(mload(0x40))), 0x2710))
                                                                                                mstore(0x01c0, 0x0100)
                                                                                                mstore(0x01e0, 0)
                                                                                                codecopy(0, 0x2016, 0x20)
                                                                                                mstore(0, mload(0))
                                                                                                log1(mload(0x40), add(0x0120, sub(mload(0x40), mload(0x40))), mload(0))
                                                                                                mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0xa4, 0x20)
                                                                                                mstore(0xc4, 0x2c)
                                                                                                mstore(0xe4, 0x476f7665726e6f723a3a63617374566f7465496e7465726e616c3a20766f7469)
                                                                                                mstore(0x0104, 0x6e6720697320636c6f7365640000000000000000000000000000000000000000)
                                                                                                if gt(number(), sload(add(0x02, sha3(0, 0x40)))) {
                                                                                                    if gt(number(), sload(add(0x03, sha3(0, 0x40)))) {
                                                                                                        if iszero(gt(sload(add(0x04, sha3(0, 0x40))), sload(add(0x05, sha3(0, 0x40))))) {
                                                                                                            if iszero(lt(sload(add(0x04, sha3(0, 0x40))), mload(mload(0x40)))) {
                                                                                                                if and(0xff, div(sload(add(sha3(0, 0x40), 0x06)), 0x0100)) { revert(0, 0); } else {
                                                                                                                }
                                                                                                                mstore(0x80, 0x2b431acd00000000000000000000000000000000000000000000000000000000)
                                                                                                                mstore(0x84, sload(add(sha3(0, 0x40), 0x02)))
                                                                                                                staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20)
                                                                                                                if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07)), mload(0x40), sub(add(0x24, mload(0x40)), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                                                                    returndatacopy(0, 0, returndatasize())
                                                                                                                    if gt(calldataload(0x04), 0) { revert(0, 0); } else {
                                                                                                                        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                        mstore(0x84, 0x20)
                                                                                                                        mstore(0xa4, 0x13)
                                                                                                                        mstore(0xc4, 0x696e76616c69642070726f706f73616c20696400000000000000000000000000)
                                                                                                                    }
                                                                                                                }
                                                                                                            }
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    voting() public view returns (address)
            */
            case 0xfce1ccca {
                mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x07))))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    quorumVotesRate() public view returns (uint256)
            */
            case 0x76769ee5 {
                mstore(0x80, sload(0x02))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    Unresolved_edbf4ac2(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xedbf4ac2 {
                if iszero(slt(sub(calldatasize(), 0x04), 0xe0)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                    }
                }
            }
            default { revert(0, 0) }
        }
    }
}