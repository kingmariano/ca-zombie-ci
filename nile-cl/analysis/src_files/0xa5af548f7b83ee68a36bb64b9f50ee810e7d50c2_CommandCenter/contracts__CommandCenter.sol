// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVoter.sol";
import "./interfaces/IXToken.sol";
import "./interfaces/IPairFactory.sol";
import "./v2/interfaces/pool/IClPoolImmutables.sol";
import "./v2/interfaces/IClPoolFactory.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/IMinter.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract CommandCenter is Initializable, AccessControlEnumerableUpgradeable {
    error InvalidFee();

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");

    IXToken public xToken;
    IVoter public voter;
    IPairFactory public legacyFactory;
    IClPoolFactory public factoryCL;

    address public multisig;

    uint256 public constant MAX_BPS_LEGACY = 500; //Max fee of 500bps = 5%
    uint24 public constant MAX_BPS_CL = 100_000; // Max fee of 10%
    uint256 public constant MAX_LOCK = 126144000; // 4 years

    address public votingEscrow;
    address public emissionsToken;
    address public minter;

    event feeChangeLegacy(address _pair, uint256 _newrate);
    event feeChangeV2(address _pair, uint256 _newrate);
    event newGlobalVolatileFee(uint256 _newBps);
    event newGlobalCorrelatedFee(uint256 _newBps);

    event Rebase(uint256 _veID, uint256 _amount);
    event AddNewNFT(address _for, uint256 _amount);
    event VoteIncentives(address[] _pools, uint256[] _amounts);
    event LPIncentives(address[] _gauge, uint256[] _amount);

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
        multisig = _multisig;
        _grantRole(DEFAULT_ADMIN_ROLE, _multisig);
        _grantRole(OPERATOR_ROLE, _multisig);
        _grantRole(OPERATOR_ROLE, _operator);

        voter = _voter;
        xToken = _xToken;

        legacyFactory = _legacyFactory;
        factoryCL = _factoryCL;
    }

    function initializeNewVars() external reinitializer(2) {
        votingEscrow = IVoter(voter)._ve();
        emissionsToken = IVoter(voter).base();
        multisig = IVoter(voter).governor();
        minter = IVoter(voter).minter();

        IERC20(emissionsToken).approve(address(xToken), type(uint256).max);
        IERC20(emissionsToken).approve(address(xToken), type(uint256).max);
    }

    function fixApproval() external reinitializer(3) {
        IERC20(emissionsToken).approve(votingEscrow, type(uint256).max);
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
    function setPoolXRatios(
        address[] calldata _pools,
        uint256[] calldata _xTokenRatios
    ) external onlyRole(OPERATOR_ROLE) {
        voter.setPoolXRatio(_pools, _xTokenRatios);
    }

    /// @notice set gauge ratios using the pair address
    function setPoolRatiosByGauge(
        address[] calldata _gauges,
        uint256[] calldata _xTokenRatios
    ) external onlyRole(OPERATOR_ROLE) {
        require(_gauges.length == _xTokenRatios.length, "len!");

        address[] memory _pairs = new address[](_gauges.length);
        for (uint256 i; i < _pairs.length; i++) {
            _pairs[i] = voter.poolForGauge(_pairs[i]);
        }
        voter.setPoolXRatio(_gauges, _xTokenRatios);
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

    function alterExitRatios(
        uint256 _newExitRatio,
        uint256 _newVeExitRatio
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.alterExitRatios(_newExitRatio, _newVeExitRatio);
    }

    function reinitializeVestingParameters(
        uint256 _min,
        uint256 _max,
        uint256 _veMax
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.reinitializeVestingParameters(_min, _max, _veMax);
    }

    function changeMinimumVestingLength(
        uint256 _minVest
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.changeMinimumVestingLength(_minVest);
    }

    function changeMaximumVestingLength(
        uint256 _maxVest
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.changeMaximumVestingLength(_maxVest);
    }

    function changeVeMaximumVestingLength(
        uint256 _veMax
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.changeVeMaximumVestingLength(_veMax);
    }

    /********************************************** */
    // Gauge Controller Functions
    /********************************************** */

    function clawBackEmissionsGivenPairs(
        address[] calldata _pair
    ) external onlyRole(OPERATOR_ROLE) {
        voter.clawBackUnusedEmissions(getGaugeArray(_pair));
    }

    function clawBackEmissionsGivenRanges(
        uint256 _start,
        uint256 _end
    ) external onlyRole(OPERATOR_ROLE) {
        address[] memory _pairs = new address[](_end - _start);
        uint256 x;
        for (uint256 i = _start; i < _end; ++i) {
            _pairs[x] = voter.pools(i);
            unchecked {
                x++;
            }
        }
        voter.clawBackUnusedEmissions(getGaugeArray(_pairs));
    }

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

    function killGauge(address _pair) external onlyRole(OPERATOR_ROLE) {
        voter.killGauge(getGauge(_pair));
    }

    function reviveGauge(address _pair) external onlyRole(OPERATOR_ROLE) {
        voter.reviveGauge(getGauge(_pair));
    }

    function addInitialRewardPerGauge(
        address gauge,
        address token
    ) external onlyRole(OPERATOR_ROLE) {
        voter.addInitialRewardPerGauge(gauge, token);
    }

    function stale(uint256 _id, bool _status) external onlyRole(OPERATOR_ROLE) {
        voter.designateStale(_id, _status);
    }

    function recoverFees(
        address[] calldata fees,
        address[][] calldata tokens
    ) external {
        voter.recoverFees(fees, tokens);
    }

    function addClGaugeReward(
        address pair,
        address reward
    ) external onlyRole(OPERATOR_ROLE) {
        address gauge = getGauge(pair);
        voter.addClGaugeReward(gauge, reward);
    }

    function removeClGaugeReward(
        address pair,
        address reward
    ) external onlyRole(OPERATOR_ROLE) {
        address gauge = getGauge(pair);
        voter.removeClGaugeReward(gauge, reward);
    }

    /********************************************** */
    // Reserve Contract Functionality
    /********************************************** */

    /// @notice changes the Fee of a legacy pair
    /// @param _pair is an array of all the legacy pairs that are to be altered
    /// @param _bps is an array of all the fee variables to adjust the pairs
    function setFeeLegacy(
        address[] calldata _pair,
        uint256[] calldata _bps
    ) external onlyRole(FEE_SETTER_ROLE) {
        for (uint256 i = 0; i < _pair.length; ++i) {
            require((_bps[i] > 0) && (_bps[i] <= MAX_BPS_LEGACY), "!valid");
            if (legacyFactory.pairFee(_pair[i]) == _bps[i]) continue;
            legacyFactory.setPairFee(_pair[i], _bps[i]);
            emit feeChangeLegacy(_pair[i], _bps[i]);
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
    ) external onlyRole(FEE_SETTER_ROLE) {
        for (uint256 i = 0; i < _pair.length; ++i) {
            if (isValidFee(false, _fee[i])) {
                factoryCL.setFee(_pair[i], _fee[i]);
                emit feeChangeV2(_pair[i], _fee[i]);
            } else {
                revert InvalidFee();
            }
        }
    }

    /// @notice Changes the fees of all CorrelatedPairs
    /// @param _bps is the global fee to change the correlated pairs to
    function changeDefaultCorrelated(
        uint256 _bps
    ) external onlyRole(OPERATOR_ROLE) {
        if (isValidFee(true, _bps)) {
            legacyFactory.setFee(true, _bps);
            emit newGlobalCorrelatedFee(_bps);
        } else {
            revert InvalidFee();
        }
    }

    /// @notice Changes the fees of all volatile pairs
    /// @param _bps is the global fee to change the volatile pairs to
    function changeDefaultVolatile(
        uint256 _bps
    ) external onlyRole(OPERATOR_ROLE) {
        if (isValidFee(true, _bps)) {
            legacyFactory.setFee(false, _bps);
            emit newGlobalVolatileFee(_bps);
        } else {
            revert InvalidFee();
        }
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

    function setFeeProtocol(
        uint8 _feeProtocol
    ) external onlyRole(OPERATOR_ROLE) {
        IClPoolFactory(factoryCL).setFeeProtocol(_feeProtocol);
    }

    function setPoolFeeProtocol(
        address pool,
        uint8 _feeProtocol
    ) external onlyRole(OPERATOR_ROLE) {
        IClPoolFactory(factoryCL).setPoolFeeProtocol(pool, _feeProtocol);
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

    /********************************************** */
    // Contract change or temporary return
    /********************************************** */

    ///@notice return all permissions to the multisig
    function returnPermissions() external onlyRole(DEFAULT_ADMIN_ROLE) {
        legacyFactory.setFeeManager(multisig);
        factoryCL.setFeeSetter(multisig);

        xToken.changeWhitelistOperator(multisig);
    }

    ///@dev send a direct rebase to an NFT ID
    function rebase(
        uint256 _veID,
        uint256 _amount
    ) external onlyRole(OPERATOR_ROLE) {
        IVotingEscrow(votingEscrow).depositFor(_veID, _amount);
        emit Rebase(_veID, _amount);
    }

    ///@dev initiate a new veNFT using amounts in the contract
    function newLock(
        uint256 _amount,
        address _for
    ) external onlyRole(OPERATOR_ROLE) {
        IVotingEscrow(votingEscrow).createLockFor(_amount, MAX_LOCK, _for);
        emit AddNewNFT(_for, _amount);
    }

    ///@dev distribute as xRAM voting incentives for a pool
    function incentivizeVotes(
        address[] calldata _pools,
        uint256[] calldata _xTokenAmounts
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pools.length; ++i) {
            xToken.convertEmissionsToken(_xTokenAmounts[i]);
            IFeeDistributor _feeDist = IFeeDistributor(
                voter.feeDistributors(voter.gauges(_pools[i]))
            );
            IERC20(address(xToken)).approve(
                address(_feeDist),
                _xTokenAmounts[i]
            );
            _feeDist.incentivize(address(xToken), _xTokenAmounts[i]);
        }
        emit VoteIncentives(_pools, _xTokenAmounts);
    }

    ///@dev distribute as xRAM LP incentives for a pool
    function incentivizePool(
        address[] calldata _pools,
        uint256[] calldata _xTokenAmounts
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pools.length; ++i) {
            xToken.convertEmissionsToken(_xTokenAmounts[i]);
            IGauge gauge = IGauge(voter.gauges(_pools[i]));
            IERC20(address(xToken)).approve(address(gauge), _xTokenAmounts[i]);
            gauge.notifyRewardAmount(address(xToken), _xTokenAmounts[i]);
        }
        emit LPIncentives(_pools, _xTokenAmounts);
    }

    function incentivizeVotesNative(
        address[] calldata _pools,
        uint256[] calldata _emissionsTokenAmounts
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pools.length; ++i) {
            IFeeDistributor _feeDist = IFeeDistributor(
                voter.feeDistributors(voter.gauges(_pools[i]))
            );
            IERC20(emissionsToken).approve(
                address(_feeDist),
                _emissionsTokenAmounts[i]
            );
            _feeDist.incentivize(emissionsToken, _emissionsTokenAmounts[i]);
        }
        emit VoteIncentives(_pools, _emissionsTokenAmounts);
    }

    function incentivizePoolNative(
        address[] calldata _pools,
        uint256[] calldata _emissionsTokenAmounts
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < _pools.length; ++i) {
            IGauge gauge = IGauge(getGauge(_pools[i]));
            IERC20(emissionsToken).approve(
                address(gauge),
                _emissionsTokenAmounts[i]
            );
            gauge.notifyRewardAmount(emissionsToken, _emissionsTokenAmounts[i]);
        }
        emit LPIncentives(_pools, _emissionsTokenAmounts);
    }

    ///@dev multisig gated call to get the underlying RAM
    function multisigWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) {
        IERC20(token).transfer(multisig, amount);
    }

    function updateIncentivesSize(
        uint256 _newSize
    ) external onlyRole(OPERATOR_ROLE) {
        IMinter(minter).updateIncentivesSize(_newSize);
    }

    function updateFlation(uint256 _newRate) external onlyRole(OPERATOR_ROLE) {
        IMinter(minter).updateFlation(_newRate);
    }

    function updateGrowthCap(
        uint256 _newGrowth
    ) external onlyRole(OPERATOR_ROLE) {
        IMinter(minter).updateGrowthCap(_newGrowth);
    }

    function setXRamPriceFeed(
        bool legacy,
        address pool
    ) external onlyRole(OPERATOR_ROLE) {
        xToken.useLegacyPair(legacy);
        xToken.setPool(pool);
    }

    function getGauge(address _pair) public view returns (address) {
        return voter.gauges(_pair);
    }

    function getGaugeArray(
        address[] memory _pair
    ) public view returns (address[] memory gauges) {
        for (uint256 i = 0; i < _pair.length; ++i) {
            _pair[i] = getGauge(_pair[i]);
        }
        return _pair;
    }

    function isValidFee(bool _legacy, uint256 _bps) public pure returns (bool) {
        if (_legacy) {
            if (_bps > 0 && _bps <= MAX_BPS_LEGACY) return true;
            return false;
        } else {
            if (_bps > 0 && _bps <= MAX_BPS_CL) return true;
        }
        return false;
    }
}
