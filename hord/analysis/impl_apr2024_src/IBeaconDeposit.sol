//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * HETH contract.
 * @author Srdjan Simonovic
 * Date created: 01.12.22.
 * Github: s2imonovic
 */
interface IBeaconDeposit {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;
}
