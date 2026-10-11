// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "./interfaces/IGaugeV2.sol";

import "./../ClBeaconProxy.sol";

import "@openzeppelin-3.4.2/contracts/proxy/IBeacon.sol";

contract ClGaugeDeployer is IBeacon {
    /// @inheritdoc IBeacon
    address public override implementation;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param _voter The address of the voter to set.
    /// @param _feeCollector The address of the fee collector to set.
    /// @param _pool The address of the pool to set.
    function _deploy(
        address _voter,
        address _nfpManager,
        address _feeCollector,
        address _pool
    ) internal returns (address gauge) {
        gauge = address(
            new ClBeaconProxy{
                salt: keccak256(abi.encodePacked(msg.sender, _pool))
            }()
        );
        IGaugeV2(gauge).initialize(
            address(this),
            _voter,
            _nfpManager,
            _feeCollector,
            _pool
        );
    }
}
