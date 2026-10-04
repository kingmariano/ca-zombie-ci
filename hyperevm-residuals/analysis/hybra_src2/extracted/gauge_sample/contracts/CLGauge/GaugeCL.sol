// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
 import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import '../interfaces/IGaugeFactoryCL.sol';
import '../interfaces/IGaugeManager.sol';
import './interface/ICLPool.sol';
import './interface/ICLFactory.sol';
import './interface/INonfungiblePositionManager.sol';
import '../interfaces/IBribe.sol';
import '../interfaces/IRHYBR.sol';
import {HybraTimeLibrary} from "../libraries/HybraTimeLibrary.sol";
import {CLRewardMath} from "./libraries/CLRewardMath.sol";



contract GaugeCL is ReentrancyGuard, Ownable, IERC721Receiver {

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint128;
    using CLRewardMath for CLRewardMath.GlobalRewardSnapshot;

    /// @dev Structure for tracking position reward state and checkpoints
    /// @notice Encapsulates all reward-related data for a staked NFT position
    struct PositionRewardCheckpoint {
        uint256 growthInsideLastX128;    // Last recorded reward growth inside position's tick range
        uint256 accumulatedRewards;      // Total unclaimed rewards accumulated
        uint256 lastCheckpointTime;      // Timestamp of last checkpoint update
    }

    IERC20 public immutable rewardToken;
    address public immutable rHYBR;
    address public VE;
    address public DISTRIBUTION;
    address public internal_bribe;
    address public external_bribe;

    uint256 public DURATION;
    uint256 internal _periodFinish;
    uint256 public rewardRate;
    ICLPool public clPool;
    address public poolAddress;
    INonfungiblePositionManager public nonfungiblePositionManager;

    bool public emergency;
    bool public immutable isForPair;
    address immutable factory;

    mapping(uint256 => uint256) public rewardRateByEpoch; // epoch => reward rate
    mapping(address => EnumerableSet.UintSet) internal _user_positions;

    /// @dev Position reward checkpoints indexed by tokenId
    mapping(uint256 => PositionRewardCheckpoint) internal _positionCheckpoints;

    event RewardAdded(uint256 reward);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 reward);
    event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
    event EmergencyActivated(address indexed gauge, uint256 timestamp);
    event EmergencyDeactivated(address indexed gauge, uint256 timestamp);

    constructor(address _rewardToken, address _rHYBR, address _ve, address _pool, address _distribution, address _internal_bribe, 
        address _external_bribe, bool _isForPair, address nfpm,  address _factory) {
        factory = _factory;
        rewardToken = IERC20(_rewardToken);     // main reward
        rHYBR = _rHYBR;
        VE = _ve;                               // vested
        poolAddress = _pool;
        clPool = ICLPool(_pool);
        DISTRIBUTION = _distribution;           // distro address (GaugeManager)
        DURATION = HybraTimeLibrary.WEEK;                   

        internal_bribe = _internal_bribe;       // lp fees goes here
        external_bribe = _external_bribe;       // bribe fees goes here
        isForPair = _isForPair;
        nonfungiblePositionManager = INonfungiblePositionManager(nfpm);
        emergency = false;
    }

    modifier onlyDistribution() {
        require(msg.sender == DISTRIBUTION, "Caller is not RewardsDistribution contract");
        _;
    }

    modifier isNotEmergency() {
        require(emergency == false, "emergency");
        _;
    }


    /// @dev Synchronizes global reward state with pool
    function _syncGlobalRewardState() internal {
        clPool.updateRewardsGrowthGlobal();
    }

    /// @dev Records a position's current reward checkpoint
    function _recordPositionCheckpoint(
        uint256 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint256 pendingRewards
    ) internal {
        PositionRewardCheckpoint storage checkpoint = _positionCheckpoints[tokenId];

        // Accumulate pending rewards
        if (pendingRewards > 0) {
            checkpoint.accumulatedRewards += pendingRewards;
        }

        // Update growth checkpoint to current value
        checkpoint.growthInsideLastX128 = clPool.getRewardGrowthInside(
            tickLower,
            tickUpper,
            0  // Use current global growth
        );

        // Record checkpoint timestamp
        checkpoint.lastCheckpointTime = block.timestamp;
    }

    /// @notice Accrues pending rewards to position checkpoint
    function _accruePositionRewards(uint256 tokenId, int24 tickLower, int24 tickUpper) internal {
        // Skip if already updated this block
        if (_positionCheckpoints[tokenId].lastCheckpointTime == block.timestamp) {
            return;
        }
        // First sync pool's global state
        _syncGlobalRewardState();
        // Calculate pending rewards since last checkpoint
        uint256 pendingRewards = _earned(tokenId);

        // Record new checkpoint with accumulated rewards
        _recordPositionCheckpoint(tokenId, tickLower, tickUpper, pendingRewards);
    }

    function activateEmergencyMode() external onlyOwner {
        require(emergency == false, "emergency");
        emergency = true;
        emit EmergencyActivated(address(this), block.timestamp);
    }

    function stopEmergencyMode() external onlyOwner {

        require(emergency == true,"emergency");

        emergency = false;
        emit EmergencyDeactivated(address(this), block.timestamp);
    }

    function balanceOf(uint256 tokenId) external view returns (uint256) {
        (,,,,,,,uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        return liquidity;
    }

    function _getPoolAddress(address token0, address token1, int24 tickSpacing) internal view returns (address) {
        return ICLFactory(nonfungiblePositionManager.factory()).getPool(token0, token1, tickSpacing);
    }

    function earned(uint256 tokenId) external view returns (uint256) {
        require(_user_positions[msg.sender].contains(tokenId), "Not Staked");

        uint256 pendingReward = _earned(tokenId);
        return pendingReward;
    }

    /// @notice Calculate pending rewards for a staked NFT position
    function _earned(uint256 tokenId) internal view returns (uint256) {
        // Build snapshot of current pool state
        CLRewardMath.GlobalRewardSnapshot memory poolSnapshot = CLRewardMath.GlobalRewardSnapshot({
            rewardGrowthGlobalX128: clPool.rewardGrowthGlobalX128(),
            totalStakedLiquidity: clPool.stakedLiquidity(),
            availableReserve: clPool.rewardReserve(),
            secondsSinceLastUpdate: block.timestamp - clPool.lastUpdated()
        });

        // Project global growth including pending rewards
        uint256 projectedGlobalX128 = CLRewardMath.projectGlobalGrowth(
            poolSnapshot,
            rewardRate,
            block.timestamp
        );

        // Get position tick range and liquidity
        (,,,,, int24 tickLower, int24 tickUpper, uint128 positionLiquidity,,,,) =
            nonfungiblePositionManager.positions(tokenId);

        // Calculate growth within this position's range
        uint256 currentGrowthInsideX128 = clPool.getRewardGrowthInside(
            tickLower,
            tickUpper,
            projectedGlobalX128
        );

        // Compute rewards using standard CL formula
        uint256 earnedAmount = CLRewardMath.calculatePositionEarnings(
            currentGrowthInsideX128,
            _positionCheckpoints[tokenId].growthInsideLastX128,
            positionLiquidity
        );

        return earnedAmount;
    }

    /// @notice Stakes an NFT position to earn rewards
    function deposit(uint256 tokenId) external nonReentrant isNotEmergency {
        require(msg.sender == nonfungiblePositionManager.ownerOf(tokenId));

        // Read position data from NFT manager
        (
            ,,
            address tok0,
            address tok1,
            int24 spacing,
            int24 lowerTick,
            int24 upperTick,
            uint128 liquidityAmount,
            ,,,
        ) = nonfungiblePositionManager.positions(tokenId);

        // Verify position has liquidity and matches this gauge's pool
        require(liquidityAmount > 0, "Zero liquidity position");
        address derivedPoolAddr = _getPoolAddress(tok0, tok1, spacing);
        require(derivedPoolAddr == poolAddress, "Position pool mismatch");

        // Collect any accrued fees to user before staking
        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Transfer NFT from user to gauge
        nonfungiblePositionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        // Stake liquidity in the pool's virtual layer
        clPool.stake(int128(liquidityAmount), lowerTick, upperTick, true);

        // Initialize reward checkpoint for this position
        PositionRewardCheckpoint storage checkpoint = _positionCheckpoints[tokenId];
        checkpoint.growthInsideLastX128 = clPool.getRewardGrowthInside(lowerTick, upperTick, 0);
        checkpoint.accumulatedRewards = 0;
        checkpoint.lastCheckpointTime = block.timestamp;

        // Track this stake for the user
        _user_positions[msg.sender].add(tokenId);

        emit Deposit(msg.sender, tokenId);
    }

    /// @notice Unstakes NFT position and claims accumulated rewards
    function withdraw(uint256 tokenId, uint8 redeemType) external nonReentrant isNotEmergency {
        address withdrawer = msg.sender;
        require(_user_positions[withdrawer].contains(tokenId), "Position not staked");

        // Collect position fees before withdrawal
        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: withdrawer,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Read position ticks and current liquidity
        (,,,,, int24 lowerTick, int24 upperTick, uint128 currentLiq,,,,) =
            nonfungiblePositionManager.positions(tokenId);

        // Process reward claim for this position
        _getReward(lowerTick, upperTick, tokenId, withdrawer, redeemType);

        // Unstake from virtual pool if liquidity still exists
        // (could be 0 if removed externally via position manager)
        if (currentLiq > 0) {
            clPool.stake(-int128(currentLiq), lowerTick, upperTick, true);
        }

        // Remove from tracking and return NFT
        _user_positions[withdrawer].remove(tokenId);
        nonfungiblePositionManager.safeTransferFrom(address(this), withdrawer, tokenId);

        emit Withdraw(withdrawer, tokenId);
    }

    

    function getReward(uint256 tokenId, address account,uint8 redeemType ) public nonReentrant onlyDistribution {

        require(_user_positions[account].contains(tokenId), "NA");

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nonfungiblePositionManager.positions(tokenId);
        _getReward(tickLower, tickUpper, tokenId, account, redeemType);
    }


    function _getReward(int24 tickLower, int24 tickUpper, uint256 tokenId, address account, uint8 redeemType) internal {
        _accruePositionRewards(tokenId, tickLower, tickUpper);

        PositionRewardCheckpoint storage checkpoint = _positionCheckpoints[tokenId];
        uint256 rewardAmount = checkpoint.accumulatedRewards;

        if (rewardAmount > 0) {
            // Clear accumulated rewards
            checkpoint.accumulatedRewards = 0;

            // Process reward through rHYBR contract
            rewardToken.safeApprove(rHYBR, rewardAmount);
            IRHYBR(rHYBR).depostionEmissionsToken(rewardAmount);
            IRHYBR(rHYBR).redeemFor(rewardAmount, redeemType, account);
        }

        emit Harvest(msg.sender, rewardAmount);
    }

    /// @dev Structure for epoch reward distribution parameters
    struct EpochDistributionParams {
        uint256 newRewardAmount;
        uint256 rolledOverAmount;
        uint256 timeUntilEpochEnd;
        uint256 epochEndTime;
        bool isNewPeriod;
    }

    /// @dev Calculates epoch timing and determines if starting new period
    function _prepareEpochParameters(uint256 incomingRewards) internal view returns (
        EpochDistributionParams memory params
    ) {
        uint256 now_ = block.timestamp;

        params.newRewardAmount = incomingRewards;
        params.rolledOverAmount = clPool.rollover();
        params.timeUntilEpochEnd = HybraTimeLibrary.epochNext(now_) - now_;
        params.epochEndTime = now_ + params.timeUntilEpochEnd;
        params.isNewPeriod = (now_ >= _periodFinish);
    }

    /// @dev Computes new reward rate based on epoch parameters
    function _calculateNewRewardRate(
        EpochDistributionParams memory params
    ) internal view returns (uint256 newRate, uint256 totalReserve) {
        if (params.isNewPeriod) {
            // Starting fresh epoch - include rolled over rewards in rate calculation
            newRate = CLRewardMath.calculateDistributionRate(
                params.newRewardAmount,
                params.rolledOverAmount,  // Include rolled over rewards from previous periods
                params.timeUntilEpochEnd
            );
            totalReserve = params.newRewardAmount + params.rolledOverAmount;
        } else {
            // Ongoing epoch - include existing pending rewards and rolled over amount
            uint256 existingPending = CLRewardMath.calculatePendingRewards(
                rewardRate,
                params.timeUntilEpochEnd
            );

            newRate = CLRewardMath.calculateDistributionRate(
                params.newRewardAmount,
                existingPending + params.rolledOverAmount,  // Include both pending and rolled over rewards
                params.timeUntilEpochEnd
            );

            totalReserve = params.newRewardAmount + params.rolledOverAmount + existingPending;
        }
    }

    /// @dev Synchronizes reward state with pool contract
    function _synchronizePoolRewardState(
        uint256 rate,
        uint256 reserve,
        uint256 finishTime
    ) internal {
        clPool.syncReward({
            rewardRate: rate,
            rewardReserve: reserve,
            periodFinish: finishTime
        });
    }

    /// @dev Validates reward rate against contract balance
    function _validateRewardRateFeasibility(
        uint256 rate,
        uint256 duration
    ) internal view {
        uint256 availableBalance = rewardToken.balanceOf(address(this));
        require(
            rate <= availableBalance / duration,
            "Insufficient balance for reward rate"
        );
    }

    /// @notice Processes new reward allocation for the current epoch
    function notifyRewardAmount(address token, uint256 rewardAmount) external nonReentrant
        isNotEmergency onlyDistribution returns (uint256 currentRate) {

        require(token == address(rewardToken), "Invalid reward token");

        // Sync global state before calculations
        _syncGlobalRewardState();

        // Calculate epoch timing and parameters
        EpochDistributionParams memory params = _prepareEpochParameters(rewardAmount);

        // Compute new distribution rate
        (uint256 newRate, uint256 totalReserve) = _calculateNewRewardRate(params);

        // Transfer tokens before updating state
        rewardToken.safeTransferFrom(DISTRIBUTION, address(this), rewardAmount);

        // Validate feasibility of calculated rate
        _validateRewardRateFeasibility(newRate, params.timeUntilEpochEnd);

        // Sync new parameters to pool
        _synchronizePoolRewardState(newRate, totalReserve, params.epochEndTime);

        // Update gauge state
        rewardRate = newRate;
        _periodFinish = params.epochEndTime;
        rewardRateByEpoch[HybraTimeLibrary.epochStart(block.timestamp)] = newRate;

        emit RewardAdded(rewardAmount);

        return newRate;
    }

    function gaugeBalances() external view returns (uint256 token0, uint256 token1){
        
        (token0, token1) = clPool.gaugeFees();

    }

  



    function claimFees() external nonReentrant returns (uint256 claimed0, uint256 claimed1) {
        return _claimFees();
    }

    function _claimFees() internal returns (uint256 claimed0, uint256 claimed1) {
        if (!isForPair) {
            return (0, 0);
        }
        
        (claimed0, claimed1) = clPool.collectFees();
        address _token0 = clPool.token0();
        address _token1 = clPool.token1();

        if (claimed0 > 0 || claimed1 > 0) {
    

            uint256 _fees0 = claimed0;
            uint256 _fees1 = claimed1;

            if (_fees0  > 0) {
                IERC20(_token0).safeApprove(internal_bribe, 0);
                IERC20(_token0).safeApprove(internal_bribe, _fees0);
                IBribe(internal_bribe).notifyRewardAmount(_token0, _fees0);
            } 
            if (_fees1  > 0) {
                IERC20(_token1).safeApprove(internal_bribe, 0);
                IERC20(_token1).safeApprove(internal_bribe, _fees1);
                IBribe(internal_bribe).notifyRewardAmount(_token1, _fees1);
            } 
            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }

    ///@notice get total reward for the duration
    function rewardForDuration() external view returns (uint256) {
        return rewardRate * DURATION;
    }

    ///@notice set new internal bribe contract (where to send fees)
    function setInternalBribe(address _int) external onlyOwner {
        require(_int >= address(0), "zero");
        internal_bribe = _int;
    }

    function _safeTransfer(address token,address to,uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /**
     * @dev Handle the receipt of an NFT
     * @param operator The address which called `safeTransferFrom` function
     * @param from The address which previously owned the token
     * @param tokenId The NFT identifier which is being transferred
     * @param data Additional data with no specified format
     * @return bytes4 `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}


