// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20, ILendingPool, IFlashLoanReceiver} from "./IMoola.sol";

/// Minimal permissionless Aave-v2 flash-loan receiver used to prove that the
/// Moola pool's flashLoan path is open to any caller. It simply approves the
/// pool to pull the owed principal+fee back (the pool transferred the funds
/// to this contract before the callback).
contract TestFlashLoanReceiver is IFlashLoanReceiver {
    address public immutable POOL;

    constructor(address pool) { POOL = pool; }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, /* initiator */
        bytes calldata /* params */
    ) external override returns (bool) {
        require(msg.sender == POOL, "caller not pool");
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(POOL, amounts[i] + premiums[i]);
        }
        return true;
    }
}
