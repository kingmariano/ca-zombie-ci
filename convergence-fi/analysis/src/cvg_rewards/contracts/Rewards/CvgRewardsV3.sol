// SPDX-License-Identifier: MIT
/**
 _____
/  __ \
| /  \/ ___  _ ____   _____ _ __ __ _  ___ _ __   ___ ___
| |    / _ \| '_ \ \ / / _ \ '__/ _` |/ _ \ '_ \ / __/ _ \
| \__/\ (_) | | | \ V /  __/ | | (_| |  __/ | | | (_|  __/
 \____/\___/|_| |_|\_/ \___|_|  \__, |\___|_| |_|\___\___|
                                 __/ |
                                |___/
 */
pragma solidity ^0.8.0;

import "../interfaces/ICvgControlTower.sol";
import "../interfaces/ICvgAssetStaking.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title Cvg-Finance - CvgRewardsV3
/// @notice Pass the internal cycle on all Staking services
contract CvgRewardsV3 is Ownable2StepUpgradeable {
    enum State {
        CHECKPOINT,
        DISTRIBUTE,
        CONTROL_TOWER_SYNC
    }

    struct InflationInfo {
        address gauge;
        uint256 cvgDistributed;
        uint256 gaugeWeight;
    }

    struct CvgRewardsConfig {
        uint128 maxChunkCheckpoint;
        uint128 maxChunkDistribute;
    }

    event Checkpoints();
    event EventChunkWriteStakingRewards(uint256 cvgCycle);
    event InflationAdjustment(uint256 indexed cycleId, uint256 adjustment);
    event StakingDistribution(uint256 indexed cycleId, address indexed gaugeAddress, uint256 amount);

    /// @dev 60,576.92 CVG distributed each cycle on the first 105 cycles
    uint256 public constant INITIAL_CYCLE_INFLATION = 60576923076923076923076;

    /// @dev On cycle 1041, inflation doesn't reduce anymore
    uint256 public constant END_INFLATION_CYCLE = 1041;

    /// @dev After the 1041 cycle, 1893.028846 CVG are distributed by cycle
    uint256 public constant END_INFLATION_AMOUNT = 1893028846153846164575;

    /// @dev approximation value for square root of 2
    uint256 private constant SQRT_2 = 1414213562373095048;

    /// @dev each 105 cycles, inflation is reduced by SRQT2
    uint256 private constant INFLATION_CHANGE_INTERVAL_CYCLE = 105;

    /// @dev convergence ecosystem address
    ICvgControlTower public cvgControlTower;

    /// @dev Gauge Controller
    IGaugeController public gaugeController;

    /// @dev Percentage of CVG to distribute weekly. Can be between 80% and 120% of the planned inflation.
    ///      This can be used to augment or reduce the APR in CVG after votes from the DAO.
    uint256 public inflationRatio;

    /// @dev current rewards distribution state
    State public state;

    /// @dev current cursor, used to determine the starting index of the next chunk
    uint128 public cursor;

    /// @dev timestamp corresponding to the last update of the cvg cycle
    uint256 public lastUpdatedTimestamp;

    /// @dev Timestamp in second of the beginning of the first cycle.
    uint256 public firstCycleStartTimestamp;

    /// @dev configuration of the distribution process, contains chunks length to process
    CvgRewardsConfig public cvgRewardsConfig;

    /// @dev array containing the addresses of all gauges
    address[] public gauges;

    /// @dev mapping containing the ID of a gauge by its address
    mapping(address => uint256) public gaugesId; // gauge address => ID

    ///@dev STORAGE V2 STARTS HERE

    /// @dev Total weight stored during last distribution
    uint256 public lastTotalWeight;

    /// @dev mapping weight gauges on last cycle triggering
    mapping(address => uint256) public lastWeights; // gauge address => weight on last snapshot

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        ADMIN FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Add a gauge in the gauge list
     *  @param gaugeAddress gaugeAddress to add
     */
    function addGauge(address gaugeAddress) external {
        require(address(gaugeController) == msg.sender, "NOT_GAUGE_CONTROLLER");
        gauges.push(gaugeAddress);
        gaugesId[gaugeAddress] = gauges.length - 1;
    }

    /**
     *  @notice Remove a gauge from the array, replace it by the last gauge of the array
     *  @param gaugeAddress gaugeAddress to remove
     */
    function removeGauge(address gaugeAddress) external {
        require(address(gaugeController) == msg.sender, "NOT_GAUGE_CONTROLLER");
        uint256 idGaugeToRemove = gaugesId[gaugeAddress];
        address lastGauge = gauges[gauges.length - 1];

        /// @dev replace id of last gauge by deleted one
        gaugesId[lastGauge] = idGaugeToRemove;
        /// @dev Set ID of gauge as 0
        gaugesId[gaugeAddress] = 0;

        /// @dev moove last gauge address to the id of the deleted one
        gauges[idGaugeToRemove] = lastGauge;

        /// @dev remove last array element
        gauges.pop();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEW FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    EXTERNAL FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @notice start or continue the rewards distribution process
    /// @param _uselessParam We keep this param, even if useless in order to don't change our contract that passes cycles every weeks

    function writeStakingRewards(uint256 _uselessParam) external {
        /// @dev Update the time of cycle triggering from midnight UTC to 8 am UTC for easier maintenance
        require(lastUpdatedTimestamp + (1 weeks + 8 hours) <= block.timestamp, "NEED_WAIT_7_DAYS");
        _incrementCycleOnStakings();
        _triggerCvgCycle();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    INTERNAL FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @dev Loops over all gauges and pass the internal cycle through calling the "processStakersRewards"
     */
    function _incrementCycleOnStakings() internal {
        address[] memory _gauges = gauges;

        for (uint256 i; i < _gauges.length; ) {
            /// @dev Write the amount of CVG to distribute in the staking contract
            ICvgAssetStaking(_gauges[i]).processStakersRewards(0);
            unchecked {
                ++i;
            }
        }
        emit EventChunkWriteStakingRewards(cvgControlTower.cvgCycle());
    }

    /// @notice Synchronize the Global Cvg Cycle on the CvgControlTower and update the next time of cycle triggering
    function _triggerCvgCycle() internal {
        cvgControlTower.updateCvgCycle();
        lastUpdatedTimestamp += 1 weeks;
    }

    function _getGaugeChunk(uint256 from, uint256 to) internal view returns (address[] memory) {
        address[] memory chunk = new address[](to - from);
        for (uint256 i = from; i < to; ) {
            chunk[i - from] = gauges[i];
            unchecked {
                ++i;
            }
        }
        return chunk;
    }

    struct GaugeView {
        string symbol;
        address stakingAddress;
        uint256 weight;
        uint256 typeWeight;
        int128 gaugeType;
    }

    /**
     * @notice Get the cycle id regarding the timestamp
     * @param timestamp Timestamp we want to check the cycle ID corresponding
     * @return number of gauges
     */
    function getCycleLocking(uint256 timestamp) public view returns (uint256) {
        return ((timestamp - firstCycleStartTimestamp) / 1 weeks) + 1;
    }

    /**
     * @notice get the total number of gauges
     * @return number of gauges
     */
    function gaugesLength() external view returns (uint256) {
        return gauges.length;
    }

    /**
     * @notice get a list of gauges with pagination
     * @param from beginning of the pagination
     * @param to end of the pagination
     * @return array containing gauges information
     */
    function getGaugeChunk(uint256 from, uint256 to) external view returns (GaugeView[] memory) {
        uint256 _gaugesLength = gauges.length;
        address[] memory chunk = _getGaugeChunk(from, to > _gaugesLength ? _gaugesLength : to);
        uint256 chunkLength = chunk.length;
        IGaugeController.WeightType[] memory votes = gaugeController.get_gauge_weights_and_types(chunk);

        GaugeView[] memory gaugesView = new GaugeView[](chunkLength);
        for (uint256 i; i < chunk.length; ) {
            gaugesView[i] = GaugeView({
                symbol: ICvgAssetStaking(chunk[i]).symbol(),
                stakingAddress: chunk[i],
                weight: votes[i].weight,
                gaugeType: votes[i].gauge_type,
                typeWeight: votes[i].type_weight
            });
            unchecked {
                ++i;
            }
        }
        return gaugesView;
    }
}
