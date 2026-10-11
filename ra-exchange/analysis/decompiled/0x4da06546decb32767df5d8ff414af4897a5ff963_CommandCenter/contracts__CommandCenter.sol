// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVoter.sol";
import "./interfaces/IXToken.sol";
import "./interfaces/IPairFactory.sol";
import "./v2/interfaces/pool/IClPoolImmutables.sol";
import "./v2/interfaces/IClPoolFactory.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract CommandCenter is Initializable, AccessControlEnumerableUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IXToken public xToken;
    IVoter public voter;
    IPairFactory public legacyFactory;
    IClPoolFactory public factoryCL;

    uint256 public constant MAX_BPS_LEGACY = 500; //Max fee of 500bps = 5%
    uint24 public constant MAX_BPS_CL = 100_000; // Max fee of 10%

    event feeChangeV1(address _pair, uint256 _newrate);
    event feeChangeV2(address _pair, uint256 _newrate);
    event newGlobalVolatileFee(uint256 _newBps);
    event newGlobalCorrelatedFee(uint256 _newBps);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        IVoter _voter,
        IXToken _xToken,
        address _multisig,
        address _operator,
        IPairFactory _legacyFactory,
        IClPoolFactory _factoryCL
    ) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _multisig);
        _grantRole(OPERATOR_ROLE, _multisig);
        _grantRole(OPERATOR_ROLE, _operator);

        voter = _voter;
        xToken = _xToken;

        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("setDelegationForSelf(address)", _multisig)
        );
        0x4392dC16867D53DBFE227076606455634d4c2795.call(
            abi.encodeWithSignature("disableSelfManagingDelegations()")
        );

        legacyFactory = _legacyFactory;
        factoryCL = _factoryCL;
    }

    /********************************************** */
    // Whitelisting Functions
    /********************************************** */

    /// @notice add an xToken whitelist
    function whitelistAddress(
        address _whitelistee
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.addWhitelist(_whitelistee);
    }

    /// @notice remove an xToken whitelist
    function removeWhitelistedAddress(
        address _whitelistee
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.removeWhitelist(_whitelistee);
    }

    /// @notice whitelist xToken addresses in batches
    function batchAddWhitelist(
        address[] calldata _whitelistees
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i; i < _whitelistees.length; ++i) {
            xToken.addWhitelist(_whitelistees[i]);
        }
    }

    /// @notice remove xToken whitelists in batches
    function batchRemoveWhitelist(
        address[] calldata _whitelistees
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i; i < _whitelistees.length; ++i) {
            xToken.removeWhitelist(_whitelistees[i]);
        }
    }

    /********************************************** */
    // Ratio-Setting Functions
    /********************************************** */

    /// @notice sets the default xTokenRatio
    function setDefaultRatio(
        uint256 _xTokenRatio
    ) external onlyRole(OPERATOR_ROLE) {
        voter.setXRatio(_xTokenRatio);
    }

    /// @notice sets the xTokenRatio of specifics gauges
    function setGaugeRatios(
        address[] calldata _gauges,
        uint256[] calldata _xTokenRatios
    ) external onlyRole(OPERATOR_ROLE) {
        voter.setGaugeXRatio(_gauges, _xTokenRatios);
    }

    /// @notice set gauge ratios using the pair address
    function setGaugeRatiosByPair(
        address[] calldata _pairs,
        uint256[] calldata _xTokenRatios
    ) external onlyRole(OPERATOR_ROLE) {
        require(_pairs.length == _xTokenRatios.length, "len!");

        address[] memory _gauges = new address[](_pairs.length);
        for (uint256 i; i < _pairs.length; i++) {
            _gauges[i] = voter.gauges(_pairs[i]);
        }
        voter.setGaugeXRatio(_gauges, _xTokenRatios);
    }

    /// @notice resets the xToken Ratio of specific gauges back to default
    function resetGaugeRatios(
        address[] calldata _gauges
    ) external onlyRole(OPERATOR_ROLE) {
        voter.resetGaugeXRatio(_gauges);
    }

    /// @notice reset xToken ratios back to default by specific pairs
    function resetRatiosByPair(
        address[] calldata _pairs
    ) external onlyRole(OPERATOR_ROLE) {
        address[] memory _gauges = new address[](_pairs.length);

        for (uint256 i; i < _pairs.length; ++i) {
            _gauges[i] = voter.gauges(_pairs[i]);
        }

        voter.resetGaugeXRatio(_gauges);
    }

    /// @notice reset xToken ratios back to the default through given indices
    function batchChangeDefaultRatiosByIndex(
        uint256 startIndex,
        uint256 endIndex
    ) external onlyRole(OPERATOR_ROLE) {
        uint256 len = voter.length();
        address[] memory _gauges = new address[](endIndex - startIndex);
        require(startIndex < len && endIndex <= len, "!R");
        uint256 x;
        for (uint256 i = startIndex; i < endIndex; ++i) {
            _gauges[x] = voter.gauges(voter.pools(i));
            unchecked {
                ++x;
            }
        }
        voter.resetGaugeXRatio(_gauges);
    }

    /********************************************** */
    // Gauge Controller Functions
    /********************************************** */

    /// @notice whitelists a token to be used in gauge creation
    function whitelistToken(address _token) external onlyRole(OPERATOR_ROLE) {
        voter.whitelist(_token);
    }

    /// @notice forbids a non-supported token from creating a new gauge
    function forbidToken(
        address _token,
        bool _status
    ) external onlyRole(OPERATOR_ROLE) {
        voter.forbid(_token, _status);
    }

    function killGauge(address gauge) external onlyRole(OPERATOR_ROLE) {
        voter.killGauge(gauge);
    }

    function reviveGauge(address gauge) external onlyRole(OPERATOR_ROLE) {
        voter.reviveGauge(gauge);
    }

    function whitelistGaugeReward(
        address _gauge,
        address _reward
    ) external onlyRole(OPERATOR_ROLE) {
        voter.whitelistGaugeReward(_gauge, _reward);
    }

    function removeGaugeReward(
        address _gauge,
        address _reward
    ) external onlyRole(OPERATOR_ROLE) {
        voter.removeGaugeReward(_gauge, _reward);
    }

    /********************************************** */
    // Reserve Contract Functionality
    /********************************************** */

    /// @notice accept the candidate position
    function acceptFeeAccess() external onlyRole(DEFAULT_ADMIN_ROLE) {
        legacyFactory.acceptFeeManager();
    }

    /// @notice changes the Fee of a V1 pair
    /// @param _pair is an array of all the V1 pairs that are to be altered
    /// @param _bps is an array of all the fee variables to adjust the pairs
    function setFeeLegacy(
        address[] calldata _pair,
        uint256[] calldata _bps
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pair.length; ++i) {
            require((_bps[i] > 0) && (_bps[i] <= MAX_BPS_LEGACY), "!valid");
            if (legacyFactory.pairFee(_pair[i]) == _bps[i]) continue;
            legacyFactory.setPairFee(_pair[i], _bps[i]);
            emit feeChangeV1(_pair[i], _bps[i]);
        }
    }

    ///@notice sets the default fee split for all new pairs
    function setFeeSplitDefault(
        uint8 _feeDist,
        uint8 _treasury
    ) external onlyRole(OPERATOR_ROLE) {
        legacyFactory.setFeeSplit(_feeDist, _treasury);
    }

    ///@notice set Pool(s) fee splits individually
    function setPoolSplit(
        address[] calldata _pools,
        uint8[] calldata _feeDist,
        uint8[] calldata _treasury
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _pools.length == _feeDist.length &&
                _feeDist.length == _treasury.length,
            "!L"
        );
        for (uint256 i = 0; i < _pools.length; ++i) {
            legacyFactory.setPoolFeeSplit(_pools[i], _feeDist[i], _treasury[i]);
        }
    }

    /// @notice sets the uint24 fee variable for each V2 pair in the array
    /// @param _pair is an array of all the V2 (CL) pairs that are to be changed
    /// @param _fee is an array of all the fee variables (as uint24) to adjust to
    function setFeeCL(
        address[] calldata _pair,
        uint24[] calldata _fee
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pair.length; ++i) {
            require((_fee[i] > 0) && (_fee[i] <= MAX_BPS_CL), "!valid");
            factoryCL.setFee(_pair[i], _fee[i]);
            emit feeChangeV2(_pair[i], _fee[i]);
        }
    }

    /// @notice Changes the fees of all CorrelatedPairs
    /// @param _bps is the global fee to change the correlated pairs to
    function changeDefaultCorrelated(
        uint256 _bps
    ) external onlyRole(OPERATOR_ROLE) {
        require(_bps <= MAX_BPS_LEGACY && _bps > 0);
        legacyFactory.setFee(true, _bps);
        emit newGlobalCorrelatedFee(_bps);
    }

    /// @notice Changes the fees of all volatile pairs
    /// @param _bps is the global fee to change the volatile pairs to
    function changeDefaultVolatile(
        uint256 _bps
    ) external onlyRole(OPERATOR_ROLE) {
        require(_bps <= MAX_BPS_LEGACY && _bps > 0);
        legacyFactory.setFee(false, _bps);
        emit newGlobalVolatileFee(_bps);
    }

    /// @notice for altering the addresses of the factories if something was the be upgraded/migrated
    /// @param _newFactory is the new factory's address
    function setLegacyFactory(
        address _newFactory
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        legacyFactory = IPairFactory(_newFactory);
    }

    /// @notice for altering the addresses of the factories if something was the be upgraded/migrated
    /// @param _newFactory is the new factory's address
    function setClFactory(
        address _newFactory
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        factoryCL = IClPoolFactory(_newFactory);
    }

    /********************************************** */
    // Getter/Read Functions
    /********************************************** */

    /// @notice checks to ensure this contract has the proper permissions to perform its tasks
    function isActive() public view returns (bool) {
        if (
            xToken.whitelistOperator() == address(this) &&
            voter.whitelistOperator() == address(this)
        ) return true;
        return false;
    }

    /// @notice get the xToken ratio for the gauge through the pair
    function getRatioByPair(address _pair) external view returns (uint256) {
        return voter.gaugeXRatio(voter.gauges(_pair));
    }

    /// @notice get the xToken ratio for the gauge
    function getRatioByGauge(address _gauge) external view returns (uint256) {
        return voter.gaugeXRatio(_gauge);
    }
}
