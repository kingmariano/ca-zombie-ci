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
            * @custom:signature    claimReward(address arg0) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xd279c191 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    admin_() public returns (address)
            */
            case 0xa4baf750 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    lockupPeriod() public view returns (uint256)
            */
            case 0xee947a7c {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x02))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    setLockupPeriod(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xc771c390 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    registerCost() public view returns (uint256)
            */
            case 0x1871f761 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x07))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    version() public pure returns (bytes memory)
            */
            case 0x54fd4d50 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x40, add(0x40, mload(0x40)))
                    mstore(0x80, 0x16)
                    mstore(0xa0, 0x566f74696e67436f6e7472616374323032353034313000000000000000000000)
                    mstore(0xc0, 0x20)
                    mstore(0xe0, mload(mload(0x40)))
                    if iszero(lt(0, mload(mload(0x40)))) {
                        mstore(0x0116, 0)
                        return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                        mstore(0x0100, mload(add(0x20, add(mload(0x40), 0))))
                        if iszero(lt(0x20, mload(mload(0x40)))) {
                            mstore(0x0116, 0)
                            return(mload(0x40), sub(add(add(add(mload(0x40), 0x20), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x20), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_9d674b56(uint256 arg0, uint256 arg1) public pure
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x9d674b56 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x60)) {
                        if iszero(gt(calldataload(0x04), 0xffffffffffffffff)) { revert(0, 0); } else {
                            if slt(add(add(0x04, calldataload(0x04)), 0x1f), calldatasize()) {
                                if iszero(gt(calldataload(add(0x04, calldataload(0x04))), 0xffffffffffffffff)) { revert(0, 0); } else {
                                    if iszero(gt(add(add(add(0x04, calldataload(0x04)), calldataload(add(0x04, calldataload(0x04)))), 0x20), calldatasize())) {
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
            * @custom:signature    extensionContract() public view returns (address)
            */
            case 0x24351da6 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0c))))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    setMinVotingAmount(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xa781b6af {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    isDelegatedVoter(address arg0) public view returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x489a0162 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, calldataload(0x04)))
                            mstore(0x20, 0x0d)
                            mstore(0x80, iszero(iszero(iszero(iszero(sload(sha3(0, 0x40)))))))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    claimReward() public
            */
            case 0xb88a802f {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if sub(sload(0x13), 0x02) { revert(mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40))); } else {
                        mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
                        sstore(0x13, 0x02)
                        if sub(0, sload(0)) {
                            mstore(0x80, 0xfc0c546a00000000000000000000000000000000000000000000000000000000)
                            staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                            if iszero(iszero(staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                returndatacopy(0, 0, returndatasize())
                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                    if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                        if eq(and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                            mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                            mstore(0xa4, 0x20)
                                            mstore(0xc4, 0x14)
                                            mstore(0xe4, 0x696e76616c69642072657761726420746f6b656e000000000000000000000000)
                                            mstore(0xa0, 0xc1fc006a00000000000000000000000000000000000000000000000000000000)
                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, 0); } else {
                                                returndatacopy(0, 0, returndatasize())
                                                mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                mstore(0x20, 0x0f)
                                                mstore(0, 0)
                                                mstore(0x20, 0x0a)
                                                codecopy(0, 0x3c9c, 0x20)
                                                mstore(0, mload(0))
                                                if gt(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))) {
                                                    if iszero(gt(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(mload(0)))) {
                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                        mstore(0x04, 0x11)
                                                        if or(eq(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), sload(add(0x01, sha3(0, 0x40))))), iszero(sload(add(0x01, sha3(0, 0x40))))) {
                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                            mstore(0x04, 0x11)
                                                            if 0x0de0b6b3a7640000 {
                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                mstore(0x04, 0x12)
                                                                if iszero(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000)) {
                                                                    mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                    mstore(0xc4, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                    mstore(0x80, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                                    mstore(0x40, add(0x64, mload(0x40)))
                                                                    mstore(0xa0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                                    call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                                    if call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                        returndatacopy(mload(0x40), 0, returndatasize())
                                                                        if iszero(returndatasize()) {
                                                                            if iszero(iszero(extcodesize(and(and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                mstore(0x40, add(0xa0, mload(0x40)))
                                                                                if iszero(gt(0x03, 0x04)) {
                                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                    mstore(0x04, 0x21)
                                                                                    mstore(0xe4, 0x03)
                                                                                    mstore(0x0104, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                    mstore(0x0124, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                    mstore(0x0144, timestamp())
                                                                                    mstore(0x0164, timestamp())
                                                                                    mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                    mstore(0x20, 0x0f)
                                                                                    if iszero(gt(sload(add(sha3(0, 0x40), 0x05)), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))) {
                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x04, 0x11)
                                                                                        sstore(add(sha3(0, 0x40), 0x05), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))
                                                                                        sstore(add(sha3(0, 0x40), 0x06), add(0x01, sload(add(sha3(0, 0x40), 0x06))))
                                                                                        mstore(0, add(sha3(0, 0x40), 0x06))
                                                                                        if iszero(gt(mload(mload(0x40)), 0x04)) {
                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x04, 0x21)
                                                                                            sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(mul(mload(mload(0x40)), 0x01), and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00)))
                                                                                            sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffff0000000000000000000000000000000000000000ff), mul(0x0100, and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffff))))
                                                                                            sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x01), mload(add(mload(0x40), 0x40)))
                                                                                            sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x02), mload(add(mload(0x40), 0x60)))
                                                                                            sstore(add(0x03, add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), mload(add(mload(0x40), 0x80)))
                                                                                            if iszero(gt(0x03, 0x04)) {
                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0x04, 0x21)
                                                                                                if 0 {
                                                                                                    if iszero(gt(0x03, 0x04)) {
                                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                        mstore(0x04, 0x21)
                                                                                                        if 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
                                                                                                            codecopy(0, 0x3bdc, 0x20)
                                                                                                            mstore(0, mload(0))
                                                                                                            mstore(0x0184, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                            mstore(0x01a4, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))))
                                                                                                            mstore(0x01c4, 0x01)
                                                                                                            mstore(0x01e4, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                                            log1(mload(0x40), sub(add(0x80, mload(0x40)), mload(0x40)), mload(0))
                                                                                                            sstore(add(sha3(0, 0x40), 0x04), sload(mload(0)))
                                                                                                            codecopy(0, 0x3c1c, 0x20)
                                                                                                            mstore(0, mload(0))
                                                                                                            mstore(0x0184, 0)
                                                                                                            mstore(0x01a4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                            mstore(0x01c4, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))))
                                                                                                            mstore(0x01e4, sload(mload(0)))
                                                                                                            log1(mload(0x40), sub(add(0x80, mload(0x40)), mload(0x40)), mload(0))
                                                                                                            mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                            mstore(0x20, 0x0d)
                                                                                                            mstore(0, 0x01)
                                                                                                            mstore(0x20, 0x0a)
                                                                                                            codecopy(0, 0x3cbc, 0x20)
                                                                                                            mstore(0, mload(0))
                                                                                                            if gt(sload(mload(0)), sload(add(sha3(0, 0x40), 0x03))) {
                                                                                                                sstore(0x13, 0x01)
                                                                                                                if iszero(iszero(eq(0x01, mload(0)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                                                    mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                                                    mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
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
            * @custom:signature    Unresolved_ac00abf7() public view returns (address)
            */
            case 0xac00abf7 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b))))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    Unresolved_d13ca888(address arg0) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xd13ca888 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    Unresolved_7f81932d() public
            */
            case 0x7f81932d {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if sub(sload(0x13), 0x02) {
                        sstore(0x13, 0x02)
                        mstore(0, caller())
                        mstore(0x20, 0x0f)
                        if lt(sload(add(sha3(0, 0x40), 0x0b)), sload(add(sha3(0, 0x40), 0x0a))) {
                            if iszero(lt(sload(add(sha3(0, 0x40), 0x0b)), sload(add(sha3(0, 0x40), 0x0a)))) {
                                if lt(sload(add(0x0b, sha3(0, 0x40))), sload(add(0x0a, sha3(0, 0x40)))) {
                                    mstore(0, add(0x0a, sha3(0, 0x40)))
                                    mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x20, 0x0f)
                                    if lt(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), sload(add(sha3(0, 0x40), 0x08))) {
                                        mstore(0, add(sha3(0, 0x40), 0x08))
                                        if iszero(gt(and(0xff, sload(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), 0x04)) {
                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                            mstore(0x04, 0x21)
                                            if eq(and(0xff, sload(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), 0x02) {
                                                if iszero(sload(add(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)), 0x03))) {
                                                    if iszero(0x01) {
                                                        sstore(0x13, 0x01)
                                                        if add(sload(add(sha3(0, 0x40), 0x0b)), 0x01) {
                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                            mstore(0x04, 0x11)
                                                            if iszero(gt(sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), add(sload(0x02), sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))))) {
                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                mstore(0x04, 0x11)
                                                                if iszero(lt(timestamp(), add(sload(0x02), sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))))) {
                                                                    if iszero(0) {
                                                                        sstore(0x13, 0x01)
                                                                        mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                        mstore(0xc4, sload(add(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)), 0x01)))
                                                                        mstore(0x80, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                                        mstore(0x40, add(0x64, mload(0x40)))
                                                                        mstore(0xa0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                                        call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                                        if call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                            returndatacopy(mload(0x40), 0, returndatasize())
                                                                            if iszero(returndatasize()) {
                                                                                if iszero(iszero(extcodesize(and(and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                    mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                    mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                    mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                    mstore(0x20, 0x0f)
                                                                                    if iszero(gt(sub(sload(add(0x02, sha3(0, 0x40))), sload(add(0x01, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))), sload(add(0x02, sha3(0, 0x40))))) {
                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x04, 0x11)
                                                                                        if iszero(iszero(eq(0x01, mload(0)))) { revert(mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40))); } else {
                                                                                            mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x84, 0x20)
                                                                                            mstore(0xa4, 0x0e)
                                                                                            mstore(0xc4, 0x696e76616c696420616374696f6e000000000000000000000000000000000000)
                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x04, 0x32)
                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x04, 0x32)
                                                                                            sstore(0x13, 0x01)
                                                                                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x84, 0x20)
                                                                                            mstore(0xa4, 0x0b)
                                                                                            mstore(0xc4, 0x616c6c20636c61696d6564000000000000000000000000000000000000000000)
                                                                                            mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
            * @custom:signature    Unresolved_d3c22e09(address arg0) public view returns (uint256)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xd3c22e09 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0x20, 0x12)
                            mstore(0, calldataload(0x04))
                            mstore(0x80, sload(sha3(0, 0x40)))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    voting(address arg0, uint256 arg1) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x2f558a8f {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            if sub(sload(0x13), 0x02) {
                                sstore(0x13, 0x02)
                                mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, calldataload(0x04)))
                                mstore(0x20, 0x0d)
                                if iszero(iszero(sload(sha3(0, 0x40)))) {
                                    if iszero(gt(calldataload(0x24), 0)) {
                                        if iszero(lt(calldataload(0x24), sload(0x08))) { revert(mload(0x40), sub(add(0x60, add(0x04, mload(0x40))), mload(0x40))); } else {
                                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                            mstore(0x84, 0x20)
                                            mstore(0xa4, 0x13)
                                            mstore(0xc4, 0x616d6f756e7420697320746f6f20736d616c6c00000000000000000000000000)
                                            mstore(0x80, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
                                            mstore(0x84, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                            mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, address()))
                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x05)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x20)
                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x05)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                returndatacopy(0, 0, returndatasize())
                                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                    if iszero(lt(mload(mload(0x40)), calldataload(0x24))) { revert(mload(0x40), sub(add(0x60, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                        mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                        mstore(0xa4, 0x20)
                                                        mstore(0xc4, 0x17)
                                                        mstore(0xe4, 0x616c6c6f77616e6365206973206e6f7420656e6f756768000000000000000000)
                                                        if sub(0, sload(0)) {
                                                            mstore(0xa0, 0xfc0c546a00000000000000000000000000000000000000000000000000000000)
                                                            staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                                            if iszero(iszero(staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                returndatacopy(0, 0, returndatasize())
                                                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                    if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                                                        if eq(and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                                            mstore(0xc0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                            mstore(0xc4, 0x20)
                                                                            mstore(0xe4, 0x14)
                                                                            mstore(0x0104, 0x696e76616c69642072657761726420746f6b656e000000000000000000000000)
                                                                            mstore(0xc0, 0xc1fc006a00000000000000000000000000000000000000000000000000000000)
                                                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, 0); } else {
                                                                                returndatacopy(0, 0, returndatasize())
                                                                                if gt(calldataload(0x24), 0) {
                                                                                    mstore(0xa0, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
                                                                                    mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                    mstore(0xc4, and(0xffffffffffffffffffffffffffffffffffffffff, address()))
                                                                                    staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x05)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x20)
                                                                                    if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x05)), mload(0x40), sub(add(0x40, add(0x04, mload(0x40))), mload(0x40)), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                                                        returndatacopy(0, 0, returndatasize())
                                                                                        mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                                                        if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                                            if iszero(lt(mload(mload(0x40)), calldataload(0x24))) { revert(mload(0x40), sub(add(0x60, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                                mstore(0xc0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0xc4, 0x20)
                                                                                                mstore(0xe4, 0x17)
                                                                                                mstore(0x0104, 0x616c6c6f77616e6365206973206e6f7420656e6f756768000000000000000000)
                                                                                                mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                mstore(0x20, 0x0f)
                                                                                                mstore(0, 0)
                                                                                                mstore(0x20, 0x0a)
                                                                                                codecopy(0, 0x3c9c, 0x20)
                                                                                                mstore(0, mload(0))
                                                                                                if gt(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))) {
                                                                                                    if iszero(gt(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(mload(0)))) {
                                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                        mstore(0x04, 0x11)
                                                                                                        if or(eq(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), sload(add(0x01, sha3(0, 0x40))))), iszero(sload(add(0x01, sha3(0, 0x40))))) {
                                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                            mstore(0x04, 0x11)
                                                                                                            if 0x0de0b6b3a7640000 {
                                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                mstore(0x04, 0x12)
                                                                                                                if iszero(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000)) {
                                                                                                                    mstore(0xe4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                                    mstore(0x0104, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                                                    mstore(0xc0, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                                                                                    mstore(0x40, add(0x64, mload(0x40)))
                                                                                                                    mstore(0xe0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                                                                                    call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                                                                                    if call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                                                                        returndatacopy(mload(0x40), 0, returndatasize())
                                                                                                                        if iszero(returndatasize()) {
                                                                                                                            if iszero(iszero(extcodesize(and(and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                                                                mstore(0x0124, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                                                                mstore(0x0128, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                                                                mstore(0x40, add(0xa0, mload(0x40)))
                                                                                                                                if iszero(gt(0x03, 0x04)) {
                                                                                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                    mstore(0x04, 0x21)
                                                                                                                                    mstore(0x0124, 0x03)
                                                                                                                                    mstore(0x0144, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                                                                    mstore(0x0164, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                                                                    mstore(0x0184, timestamp())
                                                                                                                                    mstore(0x01a4, timestamp())
                                                                                                                                    mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                                                                    mstore(0x20, 0x0f)
                                                                                                                                    if iszero(gt(sload(add(sha3(0, 0x40), 0x05)), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))) {
                                                                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                        mstore(0x04, 0x11)
                                                                                                                                        sstore(add(sha3(0, 0x40), 0x05), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))
                                                                                                                                        sstore(add(sha3(0, 0x40), 0x06), add(0x01, sload(add(sha3(0, 0x40), 0x06))))
                                                                                                                                        mstore(0, add(sha3(0, 0x40), 0x06))
                                                                                                                                        if iszero(gt(mload(mload(0x40)), 0x04)) {
                                                                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                            mstore(0x04, 0x21)
                                                                                                                                            sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(mul(mload(mload(0x40)), 0x01), and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00)))
                                                                                                                                            sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffff0000000000000000000000000000000000000000ff), mul(0x0100, and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffff))))
                                                                                                                                            sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x01), mload(add(mload(0x40), 0x40)))
                                                                                                                                            sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x02), mload(add(mload(0x40), 0x60)))
                                                                                                                                            sstore(add(0x03, add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), mload(add(mload(0x40), 0x80)))
                                                                                                                                            if iszero(gt(0x03, 0x04)) {
                                                                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                                mstore(0x04, 0x21)
                                                                                                                                                if 0 {
                                                                                                                                                    if iszero(gt(0x03, 0x04)) {
                                                                                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                                        mstore(0x04, 0x21)
                                                                                                                                                        if 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
                                                                                                                                                        }
                                                                                                                                                        if iszero(iszero(eq(0x01, mload(0)))) { revert(0, 0); } else {
                                                                                                                                                            mstore(0x0124, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                                                                                            mstore(0x0128, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                                                                                            mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                            mstore(0xa4, 0x20)
                                                                                                                                                            mstore(0xc4, 0x0b)
                                                                                                                                                            mstore(0xe4, 0x616d6f756e742069732030000000000000000000000000000000000000000000)
                                                                                                                                                            if gt(calldataload(0x24), 0) { revert(0, 0); } else {
                                                                                                                                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                                mstore(0x84, 0x20)
                                                                                                                                                                mstore(0xa4, 0x13)
                                                                                                                                                                mstore(0xc4, 0x616d6f756e7420697320746f6f20736d616c6c00000000000000000000000000)
                                                                                                                                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                                mstore(0x84, 0x20)
                                                                                                                                                                mstore(0xa4, 0x12)
                                                                                                                                                                mstore(0xc4, 0x6e6f742064656c656761746564566f7465720000000000000000000000000000)
                                                                                                                                                                mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_65aea2ca() public view returns (uint256)
            */
            case 0x65aea2ca {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x04))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    Unresolved_acb0082a(uint256 arg0) public view returns (address)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xacb0082a {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if lt(calldataload(0x04), sload(0x0e)) { revert(0, 0); } else {
                            mstore(0, 0x0e)
                            mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(add(sha3(0, 0x20), calldataload(0x04))))))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_e4e8f2d8() public
            */
            case 0xe4e8f2d8 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if sub(sload(0x13), 0x02) {
                        sstore(0x13, 0x02)
                        mstore(0, caller())
                        mstore(0x20, 0x0f)
                        if lt(sload(add(sha3(0, 0x40), 0x0b)), sload(add(sha3(0, 0x40), 0x0a))) {
                            if lt(sload(add(0x0b, sha3(0, 0x40))), sload(add(0x0a, sha3(0, 0x40)))) {
                                mstore(0, add(0x0a, sha3(0, 0x40)))
                                mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                mstore(0x20, 0x0f)
                                if lt(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), sload(add(sha3(0, 0x40), 0x08))) {
                                    mstore(0, add(sha3(0, 0x40), 0x08))
                                    if iszero(gt(and(0xff, sload(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), 0x04)) {
                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                        mstore(0x04, 0x21)
                                        if eq(and(0xff, sload(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), 0x02) {
                                            if iszero(sload(add(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)), 0x03))) {
                                                if iszero(0x01) {
                                                    sstore(0x13, 0x01)
                                                    if add(sload(add(sha3(0, 0x40), 0x0b)), 0x01) {
                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                        mstore(0x04, 0x11)
                                                        sstore(add(sha3(0, 0x40), 0x0b), add(0x01, sload(add(sha3(0, 0x40), 0x0b))))
                                                        sstore(0x13, 0x01)
                                                        if iszero(gt(sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)))), add(sload(0x02), sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))))) {
                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                            mstore(0x04, 0x11)
                                                            if iszero(lt(timestamp(), add(sload(0x02), sload(add(0x02, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))))) {
                                                                if iszero(0) {
                                                                    sstore(0x13, 0x01)
                                                                    mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                    mstore(0xc4, sload(add(add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20)), 0x01)))
                                                                    mstore(0x80, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                                    mstore(0x40, add(0x64, mload(0x40)))
                                                                    mstore(0xa0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                                    call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                                    if call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                        returndatacopy(mload(0x40), 0, returndatasize())
                                                                        if iszero(returndatasize()) {
                                                                            if iszero(iszero(extcodesize(and(and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                mstore(0x20, 0x0f)
                                                                                if iszero(gt(sub(sload(add(0x02, sha3(0, 0x40))), sload(add(0x01, add(mul(sload(add(sha3(0, 0x20), sload(add(0x0b, sha3(0, 0x40))))), 0x04), sha3(0, 0x20))))), sload(add(0x02, sha3(0, 0x40))))) {
                                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                    mstore(0x04, 0x11)
                                                                                    if iszero(iszero(eq(0x01, mload(0)))) { revert(mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40))); } else {
                                                                                        mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x84, 0x20)
                                                                                        mstore(0xa4, 0x0e)
                                                                                        mstore(0xc4, 0x696e76616c696420616374696f6e000000000000000000000000000000000000)
                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x04, 0x32)
                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x04, 0x32)
                                                                                        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                        mstore(0x84, 0x20)
                                                                                        mstore(0xa4, 0x0b)
                                                                                        mstore(0xc4, 0x616c6c20636c61696d6564000000000000000000000000000000000000000000)
                                                                                        mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
            * @custom:signature    Unresolved_1814abbd() public pure returns (uint256)
            */
            case 0x1814abbd {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, 0x0de0b6b3a7640000)
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    setRegisterCost(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x0189b4f2 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    Unresolved_1e84c725(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x1e84c725 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x60)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_3d59a0e2(uint256 arg0, uint256 arg1, uint256 arg2) public pure
            * @param                arg0 ["uint256", "bytes32", "int256"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            * @param                arg2 ["uint256", "bytes32", "int256"]
            */
            case 0x3d59a0e2 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x80)) {
                        if iszero(gt(calldataload(0x24), 0xffffffffffffffff)) { revert(0, 0); } else {
                            if slt(add(add(0x04, calldataload(0x24)), 0x1f), calldatasize()) {
                                if iszero(gt(calldataload(add(0x04, calldataload(0x24))), 0xffffffffffffffff)) { revert(0, 0); } else {
                                    if iszero(gt(add(add(add(0x04, calldataload(0x24)), calldataload(add(0x04, calldataload(0x24)))), 0x20), calldatasize())) {
                                        if iszero(gt(calldataload(0x44), 0xffffffffffffffff)) { revert(0, 0); } else {
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    minVotingAmount() public view returns (uint256)
            */
            case 0x7c1ac4b8 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x08))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    Unresolved_a1733937(address arg0) public view
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xa1733937 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0x20, 0x0d)
                            mstore(0, calldataload(0x04))
                            if and(sload(add(sha3(0, 0x40), 0x05)), 0x01) {
                                if sub(and(sload(add(sha3(0, 0x40), 0x05)), 0x01), lt(shr(0x01, sload(add(sha3(0, 0x40), 0x05))), 0x20)) {
                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                    mstore(0x04, 0x22)
                                    mstore(0x40, add(mload(0x40), add(0x20, mul(div(add(0x1f, shr(0x01, sload(add(sha3(0, 0x40), 0x05)))), 0x20), 0x20))))
                                    mstore(0x80, shr(0x01, sload(add(sha3(0, 0x40), 0x05))))
                                    if and(sload(add(sha3(0, 0x40), 0x05)), 0x01) {
                                        if sub(and(sload(add(sha3(0, 0x40), 0x05)), 0x01), lt(shr(0x01, sload(add(sha3(0, 0x40), 0x05))), 0x20)) {
                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                            mstore(0x04, 0x22)
                                            if iszero(shr(0x01, sload(add(sha3(0, 0x40), 0x05)))) {
                                                if lt(0x1f, shr(0x01, sload(add(sha3(0, 0x40), 0x05)))) {
                                                    mstore(0, add(sha3(0, 0x40), 0x05))
                                                    mstore(0xa0, sload(sha3(0, 0x20)))
                                                    if gt(add(add(0x20, mload(0x40)), shr(0x01, sload(add(sha3(0, 0x40), 0x05)))), add(0x20, add(0x20, mload(0x40)))) { revert(0, 0); } else {
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
            * @custom:signature    Unresolved_a6c6e460(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0xa6c6e460 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    Unresolved_cace1cef() public view returns (uint256)
            */
            case 0xcace1cef {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x03))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    Unresolved_da82dd41(address arg0, uint256 arg1) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0xda82dd41 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            if sub(sload(0x13), 0x02) {
                                sstore(0x13, 0x02)
                                mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, calldataload(0x04)))
                                mstore(0x20, 0x0d)
                                if iszero(iszero(sload(sha3(0, 0x40)))) {
                                    if iszero(gt(calldataload(0x24), 0)) {
                                        if iszero(lt(calldataload(0x24), sload(0x09))) {
                                            mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                            mstore(0x20, 0x0d)
                                            mstore(0, caller())
                                            mstore(0x20, add(0x04, sha3(0, 0x40)))
                                            if eq(calldataload(0x24), sload(sha3(0, 0x40))) { revert(mload(0x40), sub(add(0x60, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x84, 0x20)
                                                mstore(0xa4, 0x13)
                                                mstore(0xc4, 0x616d6f756e7420697320746f6f20736d616c6c00000000000000000000000000)
                                                mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                                mstore(0x20, 0x0d)
                                                mstore(0, caller())
                                                mstore(0x20, add(0x04, sha3(0, 0x40)))
                                                if iszero(gt(calldataload(0x24), sload(sha3(0, 0x40)))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                    mstore(0x84, 0x20)
                                                    mstore(0xa4, 0x11)
                                                    mstore(0xc4, 0x616d6f756e7420697320746f6f20626967000000000000000000000000000000)
                                                    if sub(0, sload(0)) {
                                                        mstore(0x80, 0xfc0c546a00000000000000000000000000000000000000000000000000000000)
                                                        staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                                        if iszero(iszero(staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                                            returndatacopy(0, 0, returndatasize())
                                                            mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                                            if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                                                if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                                                    if eq(and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                                        mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                        mstore(0xa4, 0x20)
                                                                        mstore(0xc4, 0x14)
                                                                        mstore(0xe4, 0x696e76616c69642072657761726420746f6b656e000000000000000000000000)
                                                                        mstore(0xa0, 0xc1fc006a00000000000000000000000000000000000000000000000000000000)
                                                                        staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                                                        if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, 0); } else {
                                                                            returndatacopy(0, 0, returndatasize())
                                                                            if gt(calldataload(0x24), 0) {
                                                                                mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                mstore(0x20, 0x0f)
                                                                                if iszero(gt(calldataload(0x24), sload(add(0x01, sha3(0, 0x40))))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                    mstore(0x84, 0x20)
                                                                                    mstore(0xa4, 0x15)
                                                                                    mstore(0xc4, 0x7374616b696e67206973206e6f7420656e6f7567680000000000000000000000)
                                                                                    mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                    mstore(0x20, 0x0f)
                                                                                    mstore(0, 0)
                                                                                    mstore(0x20, 0x0a)
                                                                                    codecopy(0, 0x3c9c, 0x20)
                                                                                    mstore(0, mload(0))
                                                                                    if gt(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))) {
                                                                                        if iszero(gt(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(mload(0)))) {
                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                            mstore(0x04, 0x11)
                                                                                            if or(eq(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), sload(add(0x01, sha3(0, 0x40))))), iszero(sload(add(0x01, sha3(0, 0x40))))) {
                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                mstore(0x04, 0x11)
                                                                                                if 0x0de0b6b3a7640000 {
                                                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                    mstore(0x04, 0x12)
                                                                                                    if iszero(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000)) {
                                                                                                        mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                                                                        mstore(0xc4, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                                        mstore(0x80, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                                                                        mstore(0x40, add(0x64, mload(0x40)))
                                                                                                        mstore(0xa0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                                                                        call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                                                                        if call(gas(), and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                                                            returndatacopy(mload(0x40), 0, returndatasize())
                                                                                                            if iszero(returndatasize()) {
                                                                                                                if iszero(iszero(extcodesize(and(and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                                                    mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                                                    mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                                                    mstore(0x40, add(0xa0, mload(0x40)))
                                                                                                                    if iszero(gt(0x03, 0x04)) {
                                                                                                                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                        mstore(0x04, 0x21)
                                                                                                                        mstore(0xe4, 0x03)
                                                                                                                        mstore(0x0104, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                                                        mstore(0x0124, div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000))
                                                                                                                        mstore(0x0144, timestamp())
                                                                                                                        mstore(0x0164, timestamp())
                                                                                                                        mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                                                                        mstore(0x20, 0x0f)
                                                                                                                        if iszero(gt(sload(add(sha3(0, 0x40), 0x05)), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))) {
                                                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                            mstore(0x04, 0x11)
                                                                                                                            sstore(add(sha3(0, 0x40), 0x05), add(div(mul(sub(sload(mload(0)), sload(add(sha3(0, 0x40), 0x04))), sload(add(0x01, sha3(0, 0x40)))), 0x0de0b6b3a7640000), sload(add(sha3(0, 0x40), 0x05))))
                                                                                                                            sstore(add(sha3(0, 0x40), 0x06), add(0x01, sload(add(sha3(0, 0x40), 0x06))))
                                                                                                                            mstore(0, add(sha3(0, 0x40), 0x06))
                                                                                                                            if iszero(gt(mload(mload(0x40)), 0x04)) {
                                                                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                mstore(0x04, 0x21)
                                                                                                                                sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(mul(mload(mload(0x40)), 0x01), and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00)))
                                                                                                                                sstore(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), or(and(sload(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), 0xffffffffffffffffffffff0000000000000000000000000000000000000000ff), mul(0x0100, and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffff))))
                                                                                                                                sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x01), mload(add(mload(0x40), 0x40)))
                                                                                                                                sstore(add(add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06)))), 0x02), mload(add(mload(0x40), 0x60)))
                                                                                                                                sstore(add(0x03, add(sha3(0, 0x20), mul(0x04, sload(add(sha3(0, 0x40), 0x06))))), mload(add(mload(0x40), 0x80)))
                                                                                                                                if iszero(gt(0x03, 0x04)) {
                                                                                                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                    mstore(0x04, 0x21)
                                                                                                                                    if 0 {
                                                                                                                                        if iszero(gt(0x03, 0x04)) {
                                                                                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                                                                            mstore(0x04, 0x21)
                                                                                                                                            if 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff {
                                                                                                                                            }
                                                                                                                                            if iszero(iszero(eq(0x01, mload(0)))) { revert(mload(0x40), sub(add(0x60, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                                                                                                mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                                                                                mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06)), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                                                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                mstore(0x84, 0x20)
                                                                                                                                                mstore(0xa4, 0x0b)
                                                                                                                                                mstore(0xc4, 0x616d6f756e742069732030000000000000000000000000000000000000000000)
                                                                                                                                                if gt(calldataload(0x24), 0) { revert(0, 0); } else {
                                                                                                                                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                    mstore(0x84, 0x20)
                                                                                                                                                    mstore(0xa4, 0x13)
                                                                                                                                                    mstore(0xc4, 0x616d6f756e7420697320746f6f20736d616c6c00000000000000000000000000)
                                                                                                                                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                                                                                    mstore(0x84, 0x20)
                                                                                                                                                    mstore(0xa4, 0x12)
                                                                                                                                                    mstore(0xc4, 0x6e6f742064656c656761746564566f7465720000000000000000000000000000)
                                                                                                                                                    mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_260e4cd5(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x260e4cd5 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if sub(sload(0x13), 0x02) {
                            sstore(0x13, 0x02)
                            mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                            mstore(0x20, 0x0f)
                            if lt(calldataload(0x04), sload(add(sha3(0, 0x40), 0x08))) {
                                mstore(0, add(sha3(0, 0x40), 0x08))
                                if iszero(gt(and(0xff, sload(add(mul(calldataload(0x04), 0x04), sha3(0, 0x20)))), 0x04)) {
                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                    mstore(0x04, 0x21)
                                    if eq(and(0xff, sload(add(mul(calldataload(0x04), 0x04), sha3(0, 0x20)))), 0x02) {
                                        if iszero(sload(add(add(mul(calldataload(0x04), 0x04), sha3(0, 0x20)), 0x03))) {
                                            if 0x01 { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x84, 0x20)
                                                mstore(0xa4, 0x0b)
                                                mstore(0xc4, 0x6e6f7420696e2074696d65000000000000000000000000000000000000000000)
                                                sstore(0x13, 0x01)
                                                if iszero(gt(sload(add(0x02, add(mul(calldataload(0x04), 0x04), sha3(0, 0x20)))), add(sload(0x02), sload(add(0x02, add(mul(calldataload(0x04), 0x04), sha3(0, 0x20))))))) {
                                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                    mstore(0x04, 0x11)
                                                    if iszero(lt(timestamp(), add(sload(0x02), sload(add(0x02, add(mul(calldataload(0x04), 0x04), sha3(0, 0x20))))))) {
                                                        if 0 { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                                            sstore(0x13, 0x01)
                                                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                            mstore(0x84, 0x20)
                                                            mstore(0xa4, 0x0b)
                                                            mstore(0xc4, 0x6e6f7420696e2074696d65000000000000000000000000000000000000000000)
                                                            mstore(0xa4, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                                            mstore(0xc4, sload(add(add(mul(calldataload(0x04), 0x04), sha3(0, 0x20)), 0x01)))
                                                            mstore(0x80, sub(sub(add(0x64, mload(0x40)), mload(0x40)), 0x20))
                                                            mstore(0x40, add(0x64, mload(0x40)))
                                                            mstore(0xa0, or(and(mload(add(mload(0x40), 0x20)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 0xa9059cbb00000000000000000000000000000000000000000000000000000000))
                                                            call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20)
                                                            if call(gas(), and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0, add(mload(0x40), 0x20), mload(mload(0x40)), 0, 0x20) { revert(mload(0x40), returndatasize()); } else {
                                                                returndatacopy(mload(0x40), 0, returndatasize())
                                                                if iszero(returndatasize()) {
                                                                    if iszero(iszero(extcodesize(and(and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff), 0xffffffffffffffffffffffffffffffffffffffff)))) { revert(mload(0x40), sub(add(0x20, add(0x04, mload(0x40))), mload(0x40))); } else {
                                                                        mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                        mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                        mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                                                        mstore(0x20, 0x0f)
                                                                        if iszero(gt(sub(sload(add(0x02, sha3(0, 0x40))), sload(add(0x01, add(mul(calldataload(0x04), 0x04), sha3(0, 0x20))))), sload(add(0x02, sha3(0, 0x40))))) {
                                                                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                            mstore(0x04, 0x11)
                                                                            if iszero(iszero(eq(0x01, mload(0)))) { revert(0, 0); } else {
                                                                                mstore(0xe4, 0x5274afe700000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0xe8, and(0xffffffffffffffffffffffffffffffffffffffff, and(sload(0x05), 0xffffffffffffffffffffffffffffffffffffffff)))
                                                                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0x84, 0x20)
                                                                                mstore(0xa4, 0x0e)
                                                                                mstore(0xc4, 0x696e76616c696420616374696f6e000000000000000000000000000000000000)
                                                                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                                                                mstore(0x04, 0x32)
                                                                                mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
            * @custom:signature    _voters(address arg0) public view returns (bytes memory)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x9029e1cf {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0x20, 0x0f)
                            mstore(0, calldataload(0x04))
                            mstore(0x80, sload(sha3(0, 0x40)))
                            mstore(0xa0, sload(add(sha3(0, 0x40), 0x01)))
                            mstore(0xc0, sload(add(sha3(0, 0x40), 0x02)))
                            mstore(0xe0, sload(add(sha3(0, 0x40), 0x03)))
                            mstore(0x0100, sload(add(sha3(0, 0x40), 0x04)))
                            mstore(0x0120, sload(add(sha3(0, 0x40), 0x05)))
                            mstore(0x0140, sload(add(sha3(0, 0x40), 0x0b)))
                            mstore(0x0160, sload(add(sha3(0, 0x40), 0x0c)))
                            return(mload(0x40), sub(add(0x0100, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    owner_() public
            */
            case 0xe7663079 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            * @custom:signature    Unresolved_f8c8765e(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xf8c8765e {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x80)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    setExtensionContract(address arg0) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xfced9c3f {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    setMinDistributeAmount(uint256 arg0) public
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x120724c4 {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    stakingToken() public view returns (address)
            */
            case 0x72f702f3 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x05))))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    distribute() public
            */
            case 0xe4fc6b6d {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if sub(sload(0x13), 0x02) {
                        sstore(0x13, 0x02)
                        if sub(0, sload(0)) {
                            mstore(0x80, 0xfc0c546a00000000000000000000000000000000000000000000000000000000)
                            staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                            if iszero(iszero(staticcall(gas(), and(sload(0x0b), 0xffffffffffffffffffffffffffffffffffffffff), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(0, returndatasize()); } else {
                                returndatacopy(0, 0, returndatasize())
                                mstore(0x40, add(mload(0x40), and(add(returndatasize(), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)))
                                if iszero(slt(sub(add(mload(0x40), returndatasize()), mload(0x40)), 0x20)) {
                                    if eq(mload(mload(0x40)), and(mload(mload(0x40)), 0xffffffffffffffffffffffffffffffffffffffff)) {
                                        if eq(and(0xffffffffffffffffffffffffffffffffffffffff, mload(mload(0x40))), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))) { revert(mload(0x40), sub(add(0x64, mload(0x40)), mload(0x40))); } else {
                                            mstore(0xa0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                            mstore(0xa4, 0x20)
                                            mstore(0xc4, 0x14)
                                            mstore(0xe4, 0x696e76616c69642072657761726420746f6b656e000000000000000000000000)
                                            mstore(0xa0, 0xc1fc006a00000000000000000000000000000000000000000000000000000000)
                                            staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20)
                                            if iszero(iszero(staticcall(gas(), and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x0b)), mload(0x40), add(sub(mload(0x40), mload(0x40)), 0x04), mload(0x40), 0x20))) { revert(mload(0x40), sub(add(0x04, mload(0x40)), mload(0x40))); } else {
                                                returndatacopy(0, 0, returndatasize())
                                                sstore(0x13, 0x01)
                                                mstore(0x80, 0x3ee5aeb500000000000000000000000000000000000000000000000000000000)
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
            * @custom:signature    totalPending() public view returns (uint256)
            */
            case 0x3f90916a {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x01))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    Unresolved_105d6f9e(address arg0, uint256 arg1) public
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x105d6f9e {
                if iszero(callvalue()) { revert(0, 0); } else {
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
            }
            
            /*
            * @custom:signature    Unresolved_062154a7(uint256 arg0) public view returns (uint256)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x062154a7 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) { revert(0, 0); } else {
                        mstore(0x20, 0x0a)
                        mstore(0, calldataload(0x04))
                        mstore(0x80, sload(sha3(0, 0x40)))
                        return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    rewardToken() public view returns (address)
            */
            case 0xf7c618c1 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(0x06))))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    totalStaking() public view returns (uint256)
            */
            case 0x165defa4 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    isVoter(address arg0) public view returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xa7771ee3 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, calldataload(0x04)))
                            mstore(0x20, 0x0f)
                            mstore(0x80, iszero(iszero(iszero(iszero(sload(sha3(0, 0x40)))))))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    _snapshots(address arg0, uint256 arg1) public view returns (bytes memory)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x2acbf823 {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                        if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                            mstore(0x20, 0x11)
                            mstore(0, calldataload(0x04))
                            mstore(0x20, sha3(0, 0x40))
                            mstore(0, calldataload(0x24))
                            mstore(0x80, sload(sha3(0, 0x40)))
                            mstore(0xa0, sload(add(sha3(0, 0x40), 0x01)))
                            mstore(0xc0, sload(add(sha3(0, 0x40), 0x02)))
                            return(mload(0x40), sub(add(0x60, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_41e68f6c() public view returns (uint256)
            */
            case 0x41e68f6c {
                if iszero(callvalue()) { revert(0, 0); } else {
                    mstore(0x80, sload(0x09))
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                }
            }
            
            /*
            * @custom:signature    voterList(uint256 arg0) public view returns (address)
            * @param                arg0 ["uint256", "bytes32", "int256"]
            */
            case 0x50e2e8af {
                if iszero(callvalue()) { revert(0, 0); } else {
                    if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                        if lt(calldataload(0x04), sload(0x10)) { revert(0, 0); } else {
                            mstore(0, 0x10)
                            mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, and(0xffffffffffffffffffffffffffffffffffffffff, sload(add(sha3(0, 0x20), calldataload(0x04))))))
                            return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                        }
                    }
                }
            }
            default { revert(0, 0) }
        }
    }
}