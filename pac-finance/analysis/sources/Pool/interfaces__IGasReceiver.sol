// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IGasReceiver {
    function claimRefundedGas(address recipient) external;
}
