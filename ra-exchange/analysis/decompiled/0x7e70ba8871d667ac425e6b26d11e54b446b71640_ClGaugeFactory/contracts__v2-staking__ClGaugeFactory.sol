// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "./interfaces/IClGaugeFactory.sol";
import "./ClGaugeDeployer.sol";
import "@openzeppelin-3.4.2/contracts/proxy/Initializable.sol";

/// @title Canonical CL gauge factory
/// @notice Deploys CL gauges
contract ClGaugeFactory is IClGaugeFactory, ClGaugeDeployer, Initializable {
    /// @inheritdoc IClGaugeFactory
    address public override owner;
    /// @inheritdoc IClGaugeFactory
    address public override nfpManager;
    /// @inheritdoc IClGaugeFactory
    address public override votingEscrow;
    /// @inheritdoc IClGaugeFactory
    address public override voter;

    /// @inheritdoc IClGaugeFactory
    mapping(address => address) public override getGauge;

    /// @inheritdoc IClGaugeFactory
    address public override feeCollector;

    /// @dev prevents implementation from being initialized later
    constructor() initializer() {}

    function initialize(
        address _nfpManager,
        address _votingEscrow,
        address _voter,
        address _feeCollector,
        address _implementation,
        address _owner
    ) public initializer {
        owner = _owner;
        nfpManager = _nfpManager;
        votingEscrow = _votingEscrow;
        voter = _voter;
        feeCollector = _feeCollector;
        implementation = _implementation;

        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("setDelegationForSelf(address)", _owner)
        );
        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("disableSelfManagingDelegations()")
        );

        emit OwnerChanged(address(0), _owner);
    }

    /// @inheritdoc IClGaugeFactory
    function createGauge(
        address pool
    ) external override returns (address gauge) {
        require(msg.sender == voter, "AUTH");
        require(getGauge[pool] == address(0), "GE");
        gauge = _deploy(voter, nfpManager, feeCollector, pool);
        getGauge[pool] = gauge;
        emit GaugeCreated(pool, gauge);
    }

    /// @inheritdoc IClGaugeFactory
    function setOwner(address _owner) external override {
        require(msg.sender == owner, "AUTH");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @dev Sets implementation for beacon proxies
    /// @param _implementation new implementation address
    function setImplementation(address _implementation) external {
        require(msg.sender == owner, "AUTH");
        emit ImplementationChanged(implementation, _implementation);
        implementation = _implementation;
    }
}
