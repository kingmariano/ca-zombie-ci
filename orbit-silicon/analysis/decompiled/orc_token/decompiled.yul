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
            * @custom:signature    totalSupply() public view returns (uint256)
            */
            case 0x18160ddd {
                mstore(0x80, sload(0x02))
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    approve(address arg0, uint256 arg1) public payable returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x095ea7b3 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        if and(caller(), 0xffffffffffffffffffffffffffffffffffffffff) {
                            if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) { revert(0, 0); } else {
                                mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                mstore(0x20, 0x01)
                                mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                mstore(0x20, sha3(0, 0x40))
                                sstore(sha3(0, 0x40), calldataload(0x24))
                                mstore(0x80, calldataload(0x24))
                                log3(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)), 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, and(0xffffffffffffffffffffffffffffffffffffffff, caller()), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                mstore(0x80, iszero(iszero(0x01)))
                                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                mstore(0x84, 0x20)
                                mstore(0xa4, 0x22)
                                mstore(0xc4, 0x45524332303a20617070726f766520746f20746865207a65726f206164647265)
                                mstore(0xe4, 0x7373000000000000000000000000000000000000000000000000000000000000)
                                mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                mstore(0x84, 0x20)
                                mstore(0xa4, 0x24)
                                mstore(0xc4, 0x45524332303a20617070726f76652066726f6d20746865207a65726f20616464)
                                mstore(0xe4, 0x7265737300000000000000000000000000000000000000000000000000000000)
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    decimals() public pure returns (uint256)
            */
            case 0x313ce567 {
                mstore(0x80, 0x12)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    transfer(address arg0, uint256 arg1) public payable returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0xa9059cbb {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        if and(caller(), 0xffffffffffffffffffffffffffffffffffffffff) {
                            if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) {
                                mstore(0, and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                                mstore(0x20, 0)
                                if iszero(lt(sload(sha3(0, 0x40)), calldataload(0x24))) { revert(0, 0); } else {
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x26)
                                    mstore(0xc4, 0x45524332303a207472616e7366657220616d6f756e7420657863656564732062)
                                    mstore(0xe4, 0x616c616e63650000000000000000000000000000000000000000000000000000)
                                    mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                    mstore(0x20, 0)
                                    sstore(sha3(0, 0x40), sub(sload(sha3(0, 0x40)), calldataload(0x24)))
                                    mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    sstore(sha3(0, 0x40), add(calldataload(0x24), sload(sha3(0, 0x40))))
                                    mstore(0x80, calldataload(0x24))
                                    log3(mload(0x40), sub(add(mload(0x40), 0x20), mload(0x40)), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, and(0xffffffffffffffffffffffffffffffffffffffff, caller()), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x80, iszero(iszero(0x01)))
                                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x23)
                                    mstore(0xc4, 0x45524332303a207472616e7366657220746f20746865207a65726f2061646472)
                                    mstore(0xe4, 0x6573730000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x25)
                                    mstore(0xc4, 0x45524332303a207472616e736665722066726f6d20746865207a65726f206164)
                                    mstore(0xe4, 0x6472657373000000000000000000000000000000000000000000000000000000)
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    DOMAIN_TYPEHASH() public pure returns (uint256)
            */
            case 0x20606b70 {
                mstore(0x80, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    fopwCDKKK() public view returns (uint256)
            */
            case 0x3644e515 {
                if eq(chainid(), 0x0933) {
                    mstore(0x80, 0xa8196fb20dbba1a79cf9fc363fd9e28568d48c913a8261c49baa97a1fbdb138e)
                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                    if and(sload(0x03), 0x01) {
                        if sub(and(sload(0x03), 0x01), lt(shr(0x01, sload(0x03)), 0x20)) {
                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                            mstore(0x04, 0x22)
                            mstore(0x40, add(mload(0x40), add(0x20, mul(div(add(0x1f, shr(0x01, sload(0x03))), 0x20), 0x20))))
                            mstore(0x80, shr(0x01, sload(0x03)))
                            if and(sload(0x03), 0x01) {
                                if sub(and(sload(0x03), 0x01), lt(shr(0x01, sload(0x03)), 0x20)) {
                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                    mstore(0x04, 0x22)
                                    if iszero(shr(0x01, sload(0x03))) {
                                        if lt(0x1f, shr(0x01, sload(0x03))) {
                                            mstore(0, 0x03)
                                            mstore(0xa0, sload(sha3(0, 0x20)))
                                            if gt(add(add(0x20, mload(0x40)), shr(0x01, sload(0x03))), add(0x20, add(0x20, mload(0x40)))) {
                                                mstore(0x40, add(0x40, mload(0x40)))
                                                mstore(0xa0, 0x01)
                                                mstore(0xc0, 0x3100000000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x0100, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
                                                mstore(0x0120, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                mstore(0x0140, 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6)
                                                mstore(0x0160, chainid())
                                                mstore(0x0180, address())
                                                mstore(0xe0, sub(sub(add(0xc0, mload(0x40)), mload(0x40)), 0x20))
                                                mstore(0x40, add(0xc0, mload(0x40)))
                                                mstore(0x01a0, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                                mstore(0xa0, mul(div(sload(0x03), 0x0100), 0x0100))
                                                mstore(0x40, add(0x40, mload(0x40)))
                                                mstore(0xa0, 0x01)
                                                mstore(0xc0, 0x3100000000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x0100, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
                                                mstore(0x0120, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                mstore(0x0140, 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6)
                                                mstore(0x0160, chainid())
                                                mstore(0x0180, address())
                                                mstore(0xe0, sub(sub(add(0xc0, mload(0x40)), mload(0x40)), 0x20))
                                                mstore(0x40, add(0xc0, mload(0x40)))
                                                mstore(0x01a0, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                                mstore(0x40, add(0x40, mload(0x40)))
                                                mstore(0xa0, 0x01)
                                                mstore(0xc0, 0x3100000000000000000000000000000000000000000000000000000000000000)
                                                mstore(0x0100, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
                                                mstore(0x0120, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                mstore(0x0140, 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6)
                                                mstore(0x0160, chainid())
                                                mstore(0x0180, address())
                                                mstore(0xe0, sub(sub(add(0xc0, mload(0x40)), mload(0x40)), 0x20))
                                                mstore(0x40, add(0xc0, mload(0x40)))
                                                mstore(0x01a0, sha3(add(0x20, mload(0x40)), mload(mload(0x40))))
                                                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
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
            * @custom:signature    balanceOf(address arg0) public view returns (uint256)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x70a08231 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, calldataload(0x04)))
                        mstore(0x20, 0)
                        mstore(0x80, sload(sha3(0, 0x40)))
                        return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_23b872dd(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x23b872dd {
                if iszero(slt(sub(calldatasize(), 0x04), 0x60)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                    }
                }
            }
            
            /*
            * @custom:signature    VERSION() public pure returns (bytes memory)
            */
            case 0xffa1ad74 {
                mstore(0x40, add(0x40, mload(0x40)))
                mstore(0x80, 0x01)
                mstore(0xa0, 0x3100000000000000000000000000000000000000000000000000000000000000)
                mstore(0xc0, 0x20)
                mstore(0xe0, mload(mload(0x40)))
                if iszero(lt(0, mload(mload(0x40)))) {
                    mstore(0x0101, 0)
                    return(mload(0x40), sub(add(add(mload(0x40), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x40), mload(0x40)))
                    mstore(0x0100, mload(add(0x20, add(0, mload(0x40)))))
                    if iszero(lt(0x20, mload(mload(0x40)))) {
                        mstore(0x0101, 0)
                        return(mload(0x40), sub(add(add(mload(0x40), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x40), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    bridgeAddress() public pure returns (uint256)
            */
            case 0xa3c573eb {
                mstore(0x80, 0x2a3dd3eb832af982ec71669e178424b10dca2ede)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    decreaseAllowance(address arg0, uint256 arg1) public payable returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0xa457c2d7 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0, caller())
                        mstore(0x20, 0x01)
                        mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                        mstore(0x20, sha3(0, 0x40))
                        if iszero(lt(sload(sha3(0, 0x40)), calldataload(0x24))) { revert(mload(0x40), sub(add(0x84, mload(0x40)), mload(0x40))); } else {
                            mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                            mstore(0x84, 0x20)
                            mstore(0xa4, 0x25)
                            mstore(0xc4, 0x45524332303a2064656372656173656420616c6c6f77616e63652062656c6f77)
                            mstore(0xe4, 0x207a65726f000000000000000000000000000000000000000000000000000000)
                            if and(caller(), 0xffffffffffffffffffffffffffffffffffffffff) {
                                if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) { revert(0, 0); } else {
                                    mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                    mstore(0x20, 0x01)
                                    mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x20, sha3(0, 0x40))
                                    sstore(sha3(0, 0x40), sub(sload(sha3(0, 0x40)), calldataload(0x24)))
                                    mstore(0x80, sub(sload(sha3(0, 0x40)), calldataload(0x24)))
                                    log3(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)), 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, and(0xffffffffffffffffffffffffffffffffffffffff, caller()), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x80, iszero(iszero(0x01)))
                                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x22)
                                    mstore(0xc4, 0x45524332303a20617070726f766520746f20746865207a65726f206164647265)
                                    mstore(0xe4, 0x7373000000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x24)
                                    mstore(0xc4, 0x45524332303a20617070726f76652066726f6d20746865207a65726f20616464)
                                    mstore(0xe4, 0x7265737300000000000000000000000000000000000000000000000000000000)
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    burn(address arg0, uint256 arg1) public payable
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x9dc29fac {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        if eq(0x2a3dd3eb832af982ec71669e178424b10dca2ede, caller()) {
                            if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) {
                                mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                mstore(0x20, 0)
                                if iszero(lt(sload(sha3(0, 0x40)), calldataload(0x24))) { revert(0, 0); } else {
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x22)
                                    mstore(0xc4, 0x45524332303a206275726e20616d6f756e7420657863656564732062616c616e)
                                    mstore(0xe4, 0x6365000000000000000000000000000000000000000000000000000000000000)
                                    mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x20, 0)
                                    sstore(sha3(0, 0x40), sub(sload(sha3(0, 0x40)), calldataload(0x24)))
                                    sstore(0x02, sub(sload(0x02), calldataload(0x24)))
                                    mstore(0x80, calldataload(0x24))
                                    log3(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff), 0)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x21)
                                    mstore(0xc4, 0x45524332303a206275726e2066726f6d20746865207a65726f20616464726573)
                                    mstore(0xe4, 0x7300000000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x30)
                                    mstore(0xc4, 0x546f6b656e577261707065643a3a6f6e6c794272696467653a204e6f7420506f)
                                    mstore(0xe4, 0x6c79676f6e5a6b45564d42726964676500000000000000000000000000000000)
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    nonces(address arg0) public view returns (uint256)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0x7ecebe00 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x20)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0x20, 0x05)
                        mstore(0, calldataload(0x04))
                        mstore(0x80, sload(sha3(0, 0x40)))
                        return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                    }
                }
            }
            
            /*
            * @custom:signature    mint(address arg0, uint256 arg1) public payable
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x40c10f19 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        if eq(0x2a3dd3eb832af982ec71669e178424b10dca2ede, caller()) {
                            if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) {
                                if iszero(gt(sload(0x02), add(calldataload(0x24), sload(0x02)))) { revert(0, 0); } else {
                                    mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                    mstore(0x04, 0x11)
                                    sstore(0x02, add(calldataload(0x24), sload(0x02)))
                                    mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x20, 0)
                                    sstore(sha3(0, 0x40), add(calldataload(0x24), sload(sha3(0, 0x40))))
                                    mstore(0x80, calldataload(0x24))
                                    log3(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)), 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x1f)
                                    mstore(0xc4, 0x45524332303a206d696e7420746f20746865207a65726f206164647265737300)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x30)
                                    mstore(0xc4, 0x546f6b656e577261707065643a3a6f6e6c794272696467653a204e6f7420506f)
                                    mstore(0xe4, 0x6c79676f6e5a6b45564d42726964676500000000000000000000000000000000)
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    PERMIT_TYPEHASH() public pure returns (uint256)
            */
            case 0x30adf81f {
                mstore(0x80, 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    Unresolved_d505accf(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xd505accf {
                if iszero(slt(sub(calldatasize(), 0x04), 0xe0)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                    }
                }
            }
            
            /*
            * @custom:signature    Unresolved_dd62ed3e(address arg0) public pure
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            */
            case 0xdd62ed3e {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                    }
                }
            }
            
            /*
            * @custom:signature    deploymentChainId() public pure returns (uint256)
            */
            case 0xcd0d0096 {
                mstore(0x80, 0x0933)
                return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
            }
            
            /*
            * @custom:signature    name() public view returns (string memory)
            */
            case 0x06fdde03 {
                if and(sload(0x03), 0x01) {
                    if sub(and(sload(0x03), 0x01), lt(shr(0x01, sload(0x03)), 0x20)) {
                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                        mstore(0x04, 0x22)
                        mstore(0x40, add(mload(0x40), add(0x20, mul(div(add(0x1f, shr(0x01, sload(0x03))), 0x20), 0x20))))
                        mstore(0x80, shr(0x01, sload(0x03)))
                        if and(sload(0x03), 0x01) {
                            if sub(and(sload(0x03), 0x01), lt(shr(0x01, sload(0x03)), 0x20)) {
                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                mstore(0x04, 0x22)
                                if iszero(shr(0x01, sload(0x03))) {
                                    if lt(0x1f, shr(0x01, sload(0x03))) {
                                        mstore(0, 0x03)
                                        mstore(0xa0, sload(sha3(0, 0x20)))
                                        if gt(add(add(0x20, mload(0x40)), shr(0x01, sload(0x03))), add(0x20, add(0x20, mload(0x40)))) {
                                            mstore(0xa0, 0x20)
                                            mstore(0xc0, mload(mload(0x40)))
                                            if iszero(lt(0, mload(mload(0x40)))) {
                                                mstore(0xe0, 0)
                                                return(mload(0x40), sub(add(add(mload(0x40), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x40), mload(0x40)))
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
            * @custom:signature    increaseAllowance(address arg0, uint256 arg1) public payable returns (bool)
            * @param                arg0 ["address", "uint160", "bytes20", "int160"]
            * @param                arg1 ["uint256", "bytes32", "int256"]
            */
            case 0x39509351 {
                if iszero(slt(sub(calldatasize(), 0x04), 0x40)) {
                    if eq(calldataload(0x04), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff)) { revert(0, 0); } else {
                        mstore(0, caller())
                        mstore(0x20, 0x01)
                        mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                        mstore(0x20, sha3(0, 0x40))
                        if iszero(gt(sload(sha3(0, 0x40)), add(calldataload(0x24), sload(sha3(0, 0x40))))) {
                            mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                            mstore(0x04, 0x11)
                            if and(caller(), 0xffffffffffffffffffffffffffffffffffffffff) {
                                if and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff) { revert(0, 0); } else {
                                    mstore(0, and(0xffffffffffffffffffffffffffffffffffffffff, caller()))
                                    mstore(0x20, 0x01)
                                    mstore(0, and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x20, sha3(0, 0x40))
                                    sstore(sha3(0, 0x40), add(calldataload(0x24), sload(sha3(0, 0x40))))
                                    mstore(0x80, add(calldataload(0x24), sload(sha3(0, 0x40))))
                                    log3(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)), 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, and(0xffffffffffffffffffffffffffffffffffffffff, caller()), and(calldataload(0x04), 0xffffffffffffffffffffffffffffffffffffffff))
                                    mstore(0x80, iszero(iszero(0x01)))
                                    return(mload(0x40), sub(add(0x20, mload(0x40)), mload(0x40)))
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x22)
                                    mstore(0xc4, 0x45524332303a20617070726f766520746f20746865207a65726f206164647265)
                                    mstore(0xe4, 0x7373000000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                                    mstore(0x84, 0x20)
                                    mstore(0xa4, 0x24)
                                    mstore(0xc4, 0x45524332303a20617070726f76652066726f6d20746865207a65726f20616464)
                                    mstore(0xe4, 0x7265737300000000000000000000000000000000000000000000000000000000)
                                }
                            }
                        }
                    }
                }
            }
            
            /*
            * @custom:signature    symbol() public view returns (string memory)
            */
            case 0x95d89b41 {
                if and(sload(0x04), 0x01) {
                    if sub(and(sload(0x04), 0x01), lt(shr(0x01, sload(0x04)), 0x20)) {
                        mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                        mstore(0x04, 0x22)
                        mstore(0x40, add(mload(0x40), add(0x20, mul(div(add(0x1f, shr(0x01, sload(0x04))), 0x20), 0x20))))
                        mstore(0x80, shr(0x01, sload(0x04)))
                        if and(sload(0x04), 0x01) {
                            if sub(and(sload(0x04), 0x01), lt(shr(0x01, sload(0x04)), 0x20)) {
                                mstore(0, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                                mstore(0x04, 0x22)
                                if iszero(shr(0x01, sload(0x04))) {
                                    if lt(0x1f, shr(0x01, sload(0x04))) {
                                        mstore(0, 0x04)
                                        mstore(0xa0, sload(sha3(0, 0x20)))
                                        if gt(add(add(0x20, mload(0x40)), shr(0x01, sload(0x04))), add(0x20, add(0x20, mload(0x40)))) {
                                            mstore(0xa0, 0x20)
                                            mstore(0xc0, mload(mload(0x40)))
                                            if iszero(lt(0, mload(mload(0x40)))) {
                                                mstore(0xe0, 0)
                                                return(mload(0x40), sub(add(add(mload(0x40), and(add(mload(mload(0x40)), 0x1f), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0)), 0x40), mload(0x40)))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            default { revert(0, 0) }
        }
    }
}