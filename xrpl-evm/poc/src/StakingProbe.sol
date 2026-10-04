// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal helper used to show what the attack contract would call if
///         the staking precompile were active. Kept for documentation: the
///         PoC test calls the precompile directly.
contract StakingProbe {
    address internal constant STAKING = 0x0000000000000000000000000000000000000800;

    /// @dev Calls the staking precompile's delegate(). On XRPL EVM this is an
    ///      empty-account call: no delegation is created, nothing reverts.
    function attemptDelegate(string calldata validator, uint256 amount) external returns (bool ok, bytes memory data) {
        (ok, data) = STAKING.call(
            abi.encodeWithSignature("delegate(address,string,uint256)", address(this), validator, amount)
        );
    }
}
