// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

interface IHordRestakingManager {
    function launchNewValidatorWithEigenLayer(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;
}
