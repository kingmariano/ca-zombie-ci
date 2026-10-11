// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IVeSDTFeeDistributor {
    function claim(address) external returns (uint256);
}
