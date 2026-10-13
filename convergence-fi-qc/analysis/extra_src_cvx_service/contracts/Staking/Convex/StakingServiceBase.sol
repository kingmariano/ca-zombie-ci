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

/// @title Cvg-Finance - StakingServiceBase
/// @notice Base of the Staking contracts of Convex integration.
///         Contains all common logic to contracts
/// @dev    Tracks staking shares per CvgCycle even for a cycle in the past.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../../interfaces/ICvgControlTowerV2.sol";
import "../../interfaces/ICommonStruct.sol";

import "../../interfaces/IUniv2Router.sol";
import "../../interfaces/IUniv3Router.sol";
import "../../interfaces/ICrvPool.sol";

import "../../interfaces/Convex/IStakingServiceBase.sol";

contract StakingServiceBase is Initializable {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            STRUCTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @dev defines the information about an NFT
    struct AccountInfos {
        uint256 amountStaked;
        uint256 pendingStaked;
    }

    struct NextClaimableCycles {
        uint128 nextClaimableCvg;
        uint128 nextClaimableCvx;
    }

    /// @dev defines the information about a CVG cycle
    struct CycleInfo {
        uint256 cvgRewardsAmount;
        uint256 totalStaked;
        bool isCvxProcessed;
    }

    struct ClaimableCyclesAndAmounts {
        uint256 cycleClaimable;
        uint256 cvgRewards;
        ICommonStruct.TokenAmount[] cvxRewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            EVENTS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    event Deposit(address indexed account, uint256 indexed cycleId, uint256 amount);
    event Withdraw(address indexed account, uint256 indexed cycleId, uint256 amount);
    event CvgCycleProcess(uint256 indexed cycleId, uint256 rewardAmount);
    event ClaimCvgMultiple(address indexed account);
    event ClaimCvgCvxMultiple(address indexed account);
    event ProcessCvxRewards(uint256 indexed cycleId, address operator, ICommonStruct.TokenAmount[] tokenAmounts);

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniv3Router private constant UNISWAPV3_ROUTER = IUniv3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniv2Router private constant UNISWAPV2_ROUTER = IUniv2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /// @dev Convergence control tower
    ICvgControlTowerV2 public constant cvgControlTower = ICvgControlTowerV2(0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7);

    /// @dev Convergence token
    ICvg public constant CVG = ICvg(0x97efFB790f2fbB701D88f89DB4521348A2B77be8);

    /// @dev ID created for the reentrancy lock
    bytes32 private constant LOCK = keccak256("LOCK");

    string public name;

    string public symbol;

    uint256 public decimals;

    address public owner;

    address public pendingOwner;

    /// @notice Deposits are paused when true
    bool public depositPaused;

    /// @notice Receiver of all Convex rewards.
    ICvxRewardDistributor public cvxRewardDistributor;

    /// @notice Address of the paired buffer accumulating and sending rewards on procesCvxRewards call
    address public buffer;

    /// @dev Base underlying asset. ex : CRV
    IERC20 public asset;

    /// @notice Cvg staking cycle for this staking contract
    uint128 public stakingCycle;

    /// @notice Maximum amount of rewards claimable through CVX,
    ///         is incremented during the processCvxRewards each time a new reward ERC20 is distributed
    uint128 public numberOfUnderlyingRewards;

    /// @dev infos used to swap ETH into the staking asset
    IStakingServiceBase.PoolEthInfo public poolEthInfo;

    /**
     *  @notice Get the global information of a cycle.
     *  Contains the total staked and the distributed amount during the {cycleId}.
     *  Allows to know if rewards have been processed for a cycle or not.
     *  cycleId Id of the cycle to get the information
     *  Returns a struct containing the totalStaked on a cycle,
     */
    mapping(uint256 => CycleInfo) public cycleInfo; // cycleId => cycleInfos
    /**
     * @notice Returns the information of a Staking position at a specified cycle Id.
     *  cycleId Information of the token will be at this cycle
     *  account Token Id of the Staking position
     *         amountStaked : Amount used in the share computation.
     *         pendingStaked : Staked amount not yet eligible for rewards, is removed in priority during a withdraw.
     *         isCvgRewardsClaimed : Allows to know if the position has already claimed the Cvg rewards for this cycle.
     *         isCvxRewardsClaimed : Allows to know if the position has already claimed the StakeDao rewards for this cycle.
     */
    mapping(uint256 => mapping(address => AccountInfos)) public accountInfoByCycle; // cycleId => account => tokenInfos

    /** @notice Array of cycleId where staking/withdraw actions occured in the past.
     * We need this array in order to be able to claim for an old cycle.
     *  account : Reads the actions history of this Token ID
     *  index   : Index of the element to return from the history array
     *  A Cycle ID
     */
    mapping(address => uint256[]) public stakingHistoryByAccount; // account => cycleIds

    /// @notice Get the Id of the ERC20 distributed during the StakeDao distribution
    mapping(IERC20 => uint256) public tokenToId; // tokenAddress => cvxRewardId

    /** @notice Pair of token/amount distributed for all stakers per cycleId per Id of ERC20 CVX rewards.
     *   cycleId         CycleId where the rewards distribution occurred
     *   cvxRewardsIndex Index of the token rewarded
     *   The reward token and its amount
     */
    mapping(uint256 => mapping(uint256 => ICommonStruct.TokenAmount)) public cvxRewardsByCycle; // cycleId => cvxRewardId => TokenAmount

    /** @notice Next cycle to be claimed on a position for Cvg & StakeDao process.
     *   account Id of the position to get the next cycle claimable.
     *   The next claimable cycles where a claimed occured.
     */
    mapping(address => NextClaimableCycles) public nextClaims; // account => lastCycleClaimed

    mapping(address => mapping(address => uint256)) public allowances;

    uint256[50] private __gap;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      CONSTRUCTOR & INIT
  =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    MODIFIERS & PRE CHECKS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    modifier lockReentrancy() {
        /// @dev Reentrancy lock check
        require(_tload(LOCK) == 0, "NOT_LOCKED");

        /// @dev Reentrancy lock set
        _tstore(LOCK, 1);

        _;

        /// @dev Reentrancy lock clear
        _tstore(LOCK, 0);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER EXTERNAL
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Claim CVG rewards for a Staking Position on one OR several already passed AND not claimed cycles.
     * @dev    CVG are minted on the fly to the owner of the Staking Position
     */
    function claimCvgRewards(address account) external {
        uint128 actualCycle = stakingCycle;

        uint128 nextClaimableCvg = nextClaims[account].nextClaimableCvg;

        uint256 lengthHistory = stakingHistoryByAccount[account].length;

        require(lengthHistory != 0, "ACCOUNT_NOT_HISTORIZED");

        /// @dev If never claimed on this token
        if (nextClaimableCvg == 0) {
            /// @dev Set the lastClaimed as the first action.
            nextClaimableCvg = uint128(stakingHistoryByAccount[account][0]);
        }

        require(actualCycle > nextClaimableCvg, "ALL_CVG_CLAIMED_FOR_NOW");

        uint256 _totalAmount;
        for (; nextClaimableCvg < actualCycle; ) {
            /// @dev Retrieve the staked amount at the iterated cycle for the account
            uint256 eligibleStakedAmount = _stakedAmountEligibleAtCycle(nextClaimableCvg, account, lengthHistory);
            /// @dev If staked amount are eligible to rewards on the iterated cycle.
            if (eligibleStakedAmount != 0) {
                /// @dev Computes the staking share of the account compare to the total Staked.
                ///      By multiplying this share by the total CVG distributed for the cycle, we get the claimable amount.
                /// @dev increments the total amount in CVG to mint to the user
                _totalAmount +=
                    (eligibleStakedAmount * cycleInfo[nextClaimableCvg].cvgRewardsAmount) /
                    cycleInfo[nextClaimableCvg].totalStaked;
            }

            unchecked {
                ++nextClaimableCvg;
            }
        }
        require(_totalAmount > 0, "NO_CVG_TO_CLAIM");

        /// @dev set the cycle as claimed for the NFT
        nextClaims[account].nextClaimableCvg = actualCycle;

        /// @dev mint CVG to user
        CVG.mintStaking(account, _totalAmount);

        emit ClaimCvgMultiple(account);
    }

    /**
     * @notice Claim CVG and CVX rewards for a Staking Position on one OR several already passed AND not claimed cycles.
     *         Also allows to claim CVX rewards only if CVG rewards
     * @dev    CVG are minted on the fly to the owner of the Staking Position
     * @param _minCvgCvxAmountOut  Minimum amount of cvgCVX to receive in case of a pool exchange
     * @param _isConvert     If true, converts all CVX into CvgCVX.
     */
    function claimCvgCvxRewards(address account, uint256 _minCvgCvxAmountOut, bool _isConvert) external {
        /// @dev Blocks other user to claim while swaping
        if (_isConvert) {
            require(msg.sender == account, "CANT_CONVERT_CVX_FOR_OTHER_USER");
        }
        (uint256 cvgClaimable, ICommonStruct.TokenAmount[] memory tokenAmounts) = _claimCvgCvxRewards(account);

        cvxRewardDistributor.claimCvgCvxSimple(account, cvgClaimable, tokenAmounts, _minCvgCvxAmountOut, _isConvert);

        emit ClaimCvgCvxMultiple(account);
    }

    /**
     * @notice Claim CVG and CVX rewards for a Staking Position on one OR several already passed AND not claimed cycles.
     *         Also allows to claim CVX rewards only if CVG rewards haven't been already claimed.
     * @dev    CVG are minted on the fly to the owner of the Staking Position
     * @param operator   used if called by the Reward Distributor, allows to claim of several account at the same time
     */
    function claimCvgCvxMultiple(address operator) external returns (uint256, ICommonStruct.TokenAmount[] memory) {
        /// @dev Only the CvxRewardDistributor can claim this function.
        require(msg.sender == address(cvxRewardDistributor), "NOT_CVX_REWARD_DISTRIBUTOR");

        (uint256 cvgClaimable, ICommonStruct.TokenAmount[] memory cvxRewards) = _claimCvgCvxRewards(operator);

        emit ClaimCvgCvxMultiple(operator);
        return (cvgClaimable, cvxRewards);
    }

    /**
     * @notice Claim CVG and CVX rewards for a Staking Position on one OR several already passed AND not claimed cycles.
     *         Also allows to claim CVX rewards only if CVG rewards
     * @dev    CVG are minted on the fly to the owner of the Staking Position
     * @param account    of the Position to claim the rewards on.
     */
    function _claimCvgCvxRewards(
        address account
    ) internal returns (uint256, ICommonStruct.TokenAmount[] memory tokenAmounts) {
        uint128 nextClaimableCvg = nextClaims[account].nextClaimableCvg;
        uint128 nextClaimableCvx = nextClaims[account].nextClaimableCvx;
        uint128 actualCycle = stakingCycle;
        uint256 lengthHistory = stakingHistoryByAccount[account].length;
        require(lengthHistory != 0, "ACCOUNT_NOT_HISTORIZED");

        /// @dev If never claimed on this token
        if (nextClaimableCvx == 0) {
            /// @dev Set the lastClaimed as the first action.
            nextClaimableCvx = uint128(stakingHistoryByAccount[account][0]);
        }
        require(actualCycle > nextClaimableCvx, "ALL_CVX_CLAIMED_FOR_NOW");

        /// @dev Total amount of CVG, accumulated through all cycles and minted at the end of the function
        uint256 _cvgClaimable;

        uint256 maxLengthRewards = numberOfUnderlyingRewards;
        /// @dev Array of all rewards from StakeDao, all cycles are accumulated in this array and transfer at the end of the function
        ICommonStruct.TokenAmount[] memory _totalRewardsClaimable = new ICommonStruct.TokenAmount[](maxLengthRewards);

        uint256 newLastClaimCvx;
        bool isCvxRewards;
        for (; nextClaimableCvx < actualCycle; ) {
            /// @dev Retrieve the amount staked at the iterated cycle for this Staking position.
            uint256 eligibleStakedAmount = _stakedAmountEligibleAtCycle(nextClaimableCvx, account, lengthHistory);
            /// @dev Retrieve the total amount staked on the iterated cycle.
            uint256 totalStaked = cycleInfo[nextClaimableCvx].totalStaked;
            /// @dev If staked amount are eligible to rewards on the iterated cycle.
            if (eligibleStakedAmount != 0) {
                /// @dev CVG PART
                ///      If the CVG rewards haven't been claimed on the iterated cycle
                if (nextClaimableCvg <= nextClaimableCvx) {
                    /// @dev Computes the staking share of the Staking Position compared to the total Staked.
                    ///      By multiplying this share by the total CVG distributed for the cycle, we get the claimable amount.
                    /// @dev Increments the total amount in CVG to mint to the user
                    _cvgClaimable += ((eligibleStakedAmount * cycleInfo[nextClaimableCvx].cvgRewardsAmount) /
                        totalStaked);
                }

                /// @dev StakeDao PART
                /// @dev We only do the CVX computation when CVX has been processed for the iterated cycle.
                if (cycleInfo[nextClaimableCvx].isCvxProcessed) {
                    for (uint256 erc20Id; erc20Id < maxLengthRewards; ) {
                        /// @dev Get the ERC20 and the amount distributed on the iterated cycle.
                        ICommonStruct.TokenAmount memory rewardAsset = cvxRewardsByCycle[nextClaimableCvx][erc20Id + 1];

                        /// @dev If there is an amount of this rewardAsset distributed on this cycle
                        if (rewardAsset.amount != 0) {
                            isCvxRewards = true;
                            /// @dev if the token is set for the first time
                            if (address(_totalRewardsClaimable[erc20Id].token) == address(0)) {
                                /// @dev Get the ERC20 and the amount distributed on the iterated cycle
                                _totalRewardsClaimable[erc20Id].token = rewardAsset.token;
                            }
                            /// @dev Computes the staking share of the Staking Position compared to the total Staked.
                            ///      By multiplying this share by the total of the StakeDao reward distributed for the cycle, we get the claimable amount.
                            /// @dev increment the total rewarded amount for the iterated ERC20
                            _totalRewardsClaimable[erc20Id].amount += ((eligibleStakedAmount * rewardAsset.amount) /
                                totalStaked);
                        }
                        unchecked {
                            ++erc20Id;
                        }
                    }
                    newLastClaimCvx = nextClaimableCvx;
                }
            }

            unchecked {
                ++nextClaimableCvx;
            }
        }
        require(_cvgClaimable != 0 || isCvxRewards, "NO_REWARDS_CLAIMABLE");

        /// @dev If last CVX cycle claimed is the last cycle, we can setup the next cycle to claim as the actual cycle
        if (newLastClaimCvx == actualCycle - 1) {
            nextClaims[account].nextClaimableCvx = actualCycle;
        }
        /// @dev Else, we don't know yet if the last cycle has been distributed, so we put the last cycle as the next CVX Cycle to claim.
        else {
            nextClaims[account].nextClaimableCvx = actualCycle - 1;
        }

        nextClaims[account].nextClaimableCvg = actualCycle;

        return (_cvgClaimable, _totalRewardsClaimable);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    CYCLE PROCESSING 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice launches the CVG reward process.
     * @dev    Updates the internal stakingCycle, writes the amount of CVG distributed for the finished cycle and reports the totalStaked on the next cycle.
     * @param amount Amount of Cvg to distribute as rewards for the current cycle, computed by the CvgRewards
     */
    function processStakersRewards(uint256 amount) external {
        require(msg.sender == address(cvgControlTower.cvgRewards()), "NOT_CVG_REWARDS");

        /// @dev Increments the cvg cycle
        uint256 _cvgStakingCycle = stakingCycle++;

        /// @dev Sets the amount computed by the CvgRewards ( related to Gauge weights ) in the triggered cycle.
        cycleInfo[_cvgStakingCycle].cvgRewardsAmount = amount;
        /// @dev Reports the old totalStaked on the new cycle
        cycleInfo[_cvgStakingCycle + 2].totalStaked = cycleInfo[_cvgStakingCycle + 1].totalStaked;

        emit CvgCycleProcess(_cvgStakingCycle, amount);
    }

    /**
     * @notice Pull Rewards from the paired buffer.
     *         Associate these rewards to the last cycle.
     *         Is callable only one time per cycle, after Cvg rewards have been processed.
     * @dev    We need to wait that processCvgRewards writes the final totalStaked amount on a cycle before processing CVX rewards.
     *         As we are merging all rewards in the claimCvgCvx & that rewards from buffer may differ, rewards from StakeDao must always be written at the same index.
     *         We are so incrementing the numberOfCvxRewards for each new token distributed in the StakeDao rewards.
     */
    function processCvxRewards() external {
        /// @dev Retrieve last staking cycle
        uint256 _cvgStakingCycle = stakingCycle - 1;
        /// @dev Allows to don't distribute rewards if no stakers was staked for this cycle.
        require(cycleInfo[_cvgStakingCycle].totalStaked != 0, "NO_STAKERS");
        require(!cycleInfo[_cvgStakingCycle].isCvxProcessed, "CVX_REWARDS_ALREADY_PROCESSED");

        /// @dev call and returns tokens and amounts returned in rewards by the gauge
        ICommonStruct.TokenAmount[] memory _rewardAssets = ICvxAssetStakerBuffer(buffer).pullRewards(msg.sender);

        for (uint256 i; i < _rewardAssets.length; ) {
            IERC20 _token = _rewardAssets[i].token;
            uint256 erc20Id = tokenToId[_token];
            if (erc20Id == 0) {
                uint256 _numberOfCvxRewards = ++numberOfUnderlyingRewards;
                tokenToId[_token] = _numberOfCvxRewards;
                erc20Id = _numberOfCvxRewards;
            }

            cvxRewardsByCycle[_cvgStakingCycle][erc20Id] = ICommonStruct.TokenAmount({
                token: _token,
                amount: cvxRewardsByCycle[_cvgStakingCycle][erc20Id].amount + _rewardAssets[i].amount
            });

            unchecked {
                ++i;
            }
        }

        cycleInfo[_cvgStakingCycle].isCvxProcessed = true;

        emit ProcessCvxRewards(_cvgStakingCycle, msg.sender, _rewardAssets);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            PUBLIC
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Finds NFT staked amount eligible for rewards for a specified _cycleId.
     *          Finds the latest deposit or withdraw (last action) before the given _cycleId to retrieve the staked amount of the NFT at this period
     *  @param _cycleId  Cycle ID  where to find the staked amount eligible to rewards
     *  @param account  ID of the token to find the staked amount eligible to rewards
     *  @return The staked amount eligible to rewards
     */
    function stakedAmountEligibleAtCycle(
        uint256 _cycleId,
        address account,
        uint256 _actualCycle
    ) external view returns (uint256) {
        /// @dev _cycleId be greater or equal than the cycle of the contract
        if (_cycleId >= _actualCycle) return 0;

        /// @dev if no action has been performed on this position, it means it's not created so returns 0
        uint256 length = stakingHistoryByAccount[account].length;
        if (length == 0) return 0;

        /// @dev If the cycleId is smaller than the first time a staking action occured on
        if (_cycleId < stakingHistoryByAccount[account][0]) return 0;

        uint256 historyCycle;
        /// @dev Finds the cycle of the last first action performed before the {_cycleId}
        for (uint256 i = length - 1; ; ) {
            historyCycle = stakingHistoryByAccount[account][i];
            if (historyCycle > _cycleId) {
                unchecked {
                    --i;
                }
            } else {
                break;
            }
        }

        /// @dev Return the amount staked on this cycle
        return accountInfoByCycle[historyCycle][account].amountStaked;
    }

    /**
     *  @dev Finds NFT staked amount eligible for rewards for a specified _cycleId.
     *          Finds the latest deposit or withdraw (last action) before the given _cycleId to retrieve the staked amount of the NFT at this period
     *  @param cycleId  ID of the token to find the staked amount eligible to rewards
     *  @param account  Cycle ID  where to find the staked amount eligible to rewards
     *  @param lengthHistory  Cycle ID  where to find the staked amount eligible to rewards
     *  @return The staked amount eligible to rewards
     */
    function _stakedAmountEligibleAtCycle(
        uint256 cycleId,
        address account,
        uint256 lengthHistory
    ) internal view returns (uint256) {
        uint256 i = lengthHistory - 1;
        uint256 historyCycle = stakingHistoryByAccount[account][i];
        /// @dev Finds the cycle of the last first action performed before the {_cycleId}
        while (historyCycle > cycleId) {
            historyCycle = stakingHistoryByAccount[account][i];
            unchecked {
                --i;
            }
        }

        return accountInfoByCycle[historyCycle][account].amountStaked;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        INTERNALS/PRIVATES
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     *  @dev Updates NFT staking information on deposit.
     *       When a user stakes, it's always linking this staked amount for the next cycle.
     *       Increase also the total staked amount for the next cycle.
     *       Tracks also for cycle in the past the amount staked for each positions.
     *  @param amount     Amount of staked asset to deposit
     *  @param nextCycle  Id of the next cvg cycle
     */
    function _updateAmountStakedDeposit(uint256 amount, uint256 nextCycle) internal {
        /// @dev Get the amount already staked on this position and adds it the new deposited amount
        uint256 _newTokenStakedAmount = balanceOf(msg.sender) + amount;

        /// @dev updates the amount staked for this msg.sender for the next cvgCycle
        accountInfoByCycle[nextCycle][msg.sender].amountStaked = _newTokenStakedAmount;

        /**
         * @dev Increments the pending amount with the deposited amount.
         *      The pending amount is the staked amount still in accumulation mode.
         *      Is always removed from the witdhraw before the amountStaked.
         */
        accountInfoByCycle[nextCycle][msg.sender].pendingStaked += amount;

        /// @dev increments the total amount staked on the Staking Contract for the nextCycle
        cycleInfo[nextCycle].totalStaked += amount;

        uint256 cycleLength = stakingHistoryByAccount[msg.sender].length;

        /// @dev If it's the mint of the position
        if (cycleLength == 0) {
            stakingHistoryByAccount[msg.sender].push(nextCycle);
        }
        /// @dev Else it's not the mint of the position
        else {
            /// @dev fetches the _lastActionCycle where an action has been performed
            uint256 _lastActionCycle = stakingHistoryByAccount[msg.sender][cycleLength - 1];

            /// @dev if this _lastActionCycle is less than the next cycle => it's the first deposit done on this cycle
            if (_lastActionCycle < nextCycle) {
                uint256 currentCycle = nextCycle - 1;
                /// @dev if this _lastActionCycle is less than the current cycle =>
                ///      No deposits occurred on the last cycle & no withdraw on this cycle
                if (_lastActionCycle < currentCycle) {
                    /// @dev we have so to checkpoint the current cycle
                    stakingHistoryByAccount[msg.sender].push(currentCycle);
                    /// @dev and to report the amountStaked of the lastActionCycle to the currentCycle
                    accountInfoByCycle[currentCycle][msg.sender].amountStaked = accountInfoByCycle[_lastActionCycle][
                        msg.sender
                    ].amountStaked;
                }
                /// @dev checkpoint the next cycle
                stakingHistoryByAccount[msg.sender].push(nextCycle);
            }
        }

        emit Transfer(address(0), msg.sender, amount);
    }

    /**
     *  @dev Updates NFT and total amount staked for a account when a withdraw action occurs.
     *       It will first remove amount in pending on the next cycle to remove first the amount not eligible to rewards for the current cycle.
     *       If the withdrawn amount is greater than the pending, we start to withdraw staked token from the next cycle then the leftover from the staking eligible to rewards.
     *  @param amount       of stakedAsset to withdraw
     *  @param currentCycle id of the Cvg cycle
     */
    function _updateAmountStakedWithdraw(uint256 amount, uint256 currentCycle) internal {
        uint256 nextCycle = currentCycle + 1;
        /// @dev get pending staked amount not already eligible for rewards
        uint256 nextCyclePending = accountInfoByCycle[nextCycle][msg.sender].pendingStaked;
        /// @dev Get amount already staked on the token when the last operation occurred
        uint256 _tokenTotalStaked = balanceOf(msg.sender);

        /// @dev Verify that the withdrawn amount is lower than the total staked amount
        require(amount <= _tokenTotalStaked, "WITHDRAW_EXCEEDS_STAKED_AMOUNT");
        uint256 _newTokenStakedAmount = _tokenTotalStaked - amount;

        /// @dev update last amountStaked for current cycle
        uint256 _lastActionCycle = stakingHistoryByAccount[msg.sender][stakingHistoryByAccount[msg.sender].length - 1];
        uint256 _lastStakedAmount;

        /// @dev if this _lastActionCycle is less than the current cycle =>
        ///      No deposits occurred on the last cycle & no withdraw on this cycle
        if (_lastActionCycle < currentCycle) {
            /// @dev we have so to checkpoint the current cycle
            stakingHistoryByAccount[msg.sender].push(currentCycle);
            /// @dev and to report the amountStaked of the lastActionCycle to the currentCycle
            _lastStakedAmount = accountInfoByCycle[_lastActionCycle][msg.sender].amountStaked;
        } else {
            _lastStakedAmount = accountInfoByCycle[currentCycle][msg.sender].amountStaked;
        }

        /// @dev updates the amount staked for this position for the next cycle
        accountInfoByCycle[nextCycle][msg.sender].amountStaked = _newTokenStakedAmount;

        /// @dev Fully removes the amount from the totalStaked of next cycle.
        ///      This withdrawn amount is not anymore eligible to the distribution of the next cycle.
        cycleInfo[nextCycle].totalStaked -= amount;

        /// @dev If there is some token deposited on this cycle ( pending token )
        ///      We first must to remove them before the tokens that are already accumulating rewards
        if (nextCyclePending != 0) {
            /// @dev If the amount to withdraw is lower or equal to the pending amount
            if (nextCyclePending >= amount) {
                /// @dev we decrement this pending amount
                accountInfoByCycle[nextCycle][msg.sender].pendingStaked -= amount;
            }
            /// @dev Else, the amount to withdraw is greater than the pending
            else {
                /// @dev Computes the amount to remove from the staked amount eligible to rewards
                amount -= nextCyclePending;

                /// @dev Fully removes the pending amount for next cycle
                delete accountInfoByCycle[nextCycle][msg.sender].pendingStaked;

                /// @dev Removes the adjusted amount to the staked total amount eligible to rewards
                cycleInfo[currentCycle].totalStaked -= amount;

                /// @dev Removes the adjusted amount to the staked position amount eligible to rewards
                accountInfoByCycle[currentCycle][msg.sender].amountStaked = _lastStakedAmount - amount;
            }
        }
        /// @dev If nothing has been desposited on this cycle
        else {
            /// @dev removes the withdrawn amount to the staked total amount eligible to rewards
            cycleInfo[currentCycle].totalStaked -= amount;
            /// @dev removes the withdrawn amount to the staked token amount eligible to rewards
            accountInfoByCycle[currentCycle][msg.sender].amountStaked = _lastStakedAmount - amount;
        }

        emit Transfer(msg.sender, address(0), amount);
    }

    function _convertEthToAsset(uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut) {
        IStakingServiceBase.PoolEthInfo memory _poolEthInfo = poolEthInfo;
        require(_poolEthInfo.poolType != IStakingServiceBase.PoolType.DEACTIVATED, "DEPOSIT_ETH_PAUSED");
        require(amountOutMin != 0, "WRONG_SLIPPAGE");
        if (_poolEthInfo.poolType == IStakingServiceBase.PoolType.UNIV2) {
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = _poolEthInfo.token;
            uint256[] memory amounts = UNISWAPV2_ROUTER.swapExactETHForTokens{value: amountIn}(
                amountOutMin,
                path,
                address(this),
                block.timestamp + 1000
            );
            amountOut = amounts[1];
        } else if (_poolEthInfo.poolType == IStakingServiceBase.PoolType.UNIV3) {
            amountOut = UNISWAPV3_ROUTER.exactInputSingle{value: amountIn}(
                IUniv3Router.ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: _poolEthInfo.token,
                    fee: uint24(_poolEthInfo.fee),
                    recipient: address(this),
                    deadline: block.timestamp + 1000,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin,
                    sqrtPriceLimitX96: 0
                })
            );
        } else if (
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.CURVE_DUO ||
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.CURVE_TRI
        ) {
            amountOut = ICrvPool(_poolEthInfo.poolCurve).exchange{value: amountIn}(
                _poolEthInfo.indexEth,
                _poolEthInfo.indexAsset,
                amountIn,
                amountOutMin,
                true
            );
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            GETTERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function getHistoryLengthForAccount(address account) public view returns (uint256) {
        return stakingHistoryByAccount[account].length;
    }

    /**
     *  @notice Computes, for a {account}, the total rewards claimable in CVG and from CVX for a range of cycle bewteen {fromCycle} and {toCycle}.
     *          For CVX rewards, it aggregates amounts of same token from different cycles in the returned array.
     *  @param account  Staking position ID able ton claim the rewards
     *  @return total amount of Cvg claimable by the {account} in the cycle range
     *  @return array of total token / amount pair claimable by the {account} in the cycle range
     */
    function getAllClaimableAmounts(address account) public view returns (uint256, ICommonStruct.TokenAmount[] memory) {
        uint128 nextClaimableCvg = nextClaims[account].nextClaimableCvg;
        uint128 nextClaimableCvx = nextClaims[account].nextClaimableCvx;
        uint128 actualCycle = stakingCycle;
        uint256 lengthHistory = stakingHistoryByAccount[account].length;
        ICommonStruct.TokenAmount[] memory _cvxRewardsClaimable;
        uint256 _cvgClaimable;

        if (lengthHistory != 0) {
            /// @dev If never claimed on this token
            if (nextClaimableCvx == 0) {
                /// @dev Get the length of the history
                nextClaimableCvx = uint128(stakingHistoryByAccount[account][0]);
            }

            uint256 maxLengthRewards = numberOfUnderlyingRewards;
            uint256 realLengthRewards;
            ICommonStruct.TokenAmount[] memory _totalCvxRewardsClaimable = new ICommonStruct.TokenAmount[](
                maxLengthRewards
            );

            for (; nextClaimableCvx < actualCycle; ) {
                /// @dev Retrieve the amount staked at the iterated cycle for this Staking position.
                uint256 tokenStaked = _stakedAmountEligibleAtCycle(nextClaimableCvx, account, lengthHistory);
                /// @dev Retrieve the total amount staked on the iterated cycle.
                uint256 totalStaked = cycleInfo[nextClaimableCvx].totalStaked;
                /// @dev If staked amount are eligible to rewards on the iterated cycle.
                if (tokenStaked != 0) {
                    /// @dev CVG PART
                    ///      If the CVG rewards haven't been claimed on the iterated cycle
                    if (nextClaimableCvg <= nextClaimableCvx) {
                        /// @dev Computes the staking share of the Staking Position compared to the total Staked.
                        ///      By multiplying this share by the total CVG distributed for the cycle, we get the claimable amount.
                        uint256 cvgClaimableAmount = (tokenStaked * cycleInfo[nextClaimableCvx].cvgRewardsAmount) /
                            totalStaked;
                        /// @dev increments the total amount in CVG to mint to the user
                        _cvgClaimable += cvgClaimableAmount;
                    }

                    /// @dev StakeDao PART
                    /// @dev We only do the CVX computation when CVX has been processed for the iterated cycle.
                    if (cycleInfo[nextClaimableCvx].isCvxProcessed) {
                        for (uint256 erc20Id; erc20Id < maxLengthRewards; ) {
                            /// @dev Get the ERC20 and the amount distributed during on the iterated cycle
                            ICommonStruct.TokenAmount memory rewardAsset = cvxRewardsByCycle[nextClaimableCvx][
                                erc20Id + 1
                            ];

                            /// @dev If there is no amount of this rewardAsset distributed on this cycle
                            if (rewardAsset.amount != 0) {
                                /// @dev if the token is set for the first time
                                if (address(_totalCvxRewardsClaimable[erc20Id].token) == address(0)) {
                                    _totalCvxRewardsClaimable[erc20Id].token = rewardAsset.token;
                                    ++realLengthRewards;
                                }
                                /// @dev Computes the staking share of the Staking Position compare to the total Staked.
                                ///      By multiplying this share by the total of the StakeDao reward distributed for the cycle, we get the claimable amount.
                                uint256 rewardAmount = (tokenStaked * rewardAsset.amount) / totalStaked;

                                /// @dev increment the total rewarded amount for the iterated ERC20
                                _totalCvxRewardsClaimable[erc20Id].amount += rewardAmount;
                            }
                            unchecked {
                                ++erc20Id;
                            }
                        }
                    }
                }

                unchecked {
                    ++nextClaimableCvx;
                }
            }

            /// @dev this array should have the right length
            _cvxRewardsClaimable = new ICommonStruct.TokenAmount[](realLengthRewards);

            delete realLengthRewards;
            for (uint256 i; i < _totalCvxRewardsClaimable.length; ) {
                if (_totalCvxRewardsClaimable[i].amount != 0) {
                    _cvxRewardsClaimable[realLengthRewards++] = ICommonStruct.TokenAmount({
                        token: _totalCvxRewardsClaimable[i].token,
                        amount: _totalCvxRewardsClaimable[i].amount
                    });
                }
                unchecked {
                    ++i;
                }
            }
        }
        return (_cvgClaimable, _cvxRewardsClaimable);
    }

    /**
     * @notice Get an array of token and reward associated to the Staking position sorted by cycleId.
     * @param account Staking position ID to get amount claimable on.
     * @return An array of token and reward associated to the Staking position sorted by cycleId.
     */
    function getClaimableCyclesAndAmounts(address account) external view returns (ClaimableCyclesAndAmounts[] memory) {
        uint128 actualCycle = stakingCycle;
        uint128 nextClaimableCvg = nextClaims[account].nextClaimableCvg;
        uint128 nextClaimableCvx = nextClaims[account].nextClaimableCvx;
        uint256 lengthHistory = stakingHistoryByAccount[account].length;
        ClaimableCyclesAndAmounts[] memory claimableCyclesAndAmounts;
        if (lengthHistory != 0) {
            /// @dev If never claimed on this token
            if (nextClaimableCvx == 0) {
                /// @dev Get the length of the history
                nextClaimableCvx = uint128(stakingHistoryByAccount[account][0]);
            }

            /// @dev potential max length
            claimableCyclesAndAmounts = new ClaimableCyclesAndAmounts[](actualCycle - nextClaimableCvx);
            uint256 counter;
            uint256 maxLengthRewards = numberOfUnderlyingRewards;
            for (; nextClaimableCvx < actualCycle; ) {
                uint256 amountStaked = _stakedAmountEligibleAtCycle(nextClaimableCvx, account, lengthHistory);
                uint256 totalStaked = cycleInfo[nextClaimableCvx].totalStaked;
                /// @dev If the position is eligible to claim rewards for the iterated cycle.
                if (amountStaked != 0) {
                    uint256 cvgAmount;

                    /// @dev CVG PART
                    ///      If the CVG rewards haven't been claimed on the iterated cycle
                    if (nextClaimableCvg <= nextClaimableCvx) {
                        /// @dev Computes the staking share of the Staking Position compared to the total Staked.
                        ///      By multiplying this share by the total CVG distributed for the cycle, we get the claimable amount.
                        cvgAmount = (amountStaked * cycleInfo[nextClaimableCvx].cvgRewardsAmount) / totalStaked;
                    }

                    /// @dev Convex part
                    /// @dev We only do the CVX computation when CVX has been processed for the iterated cycle.
                    ICommonStruct.TokenAmount[] memory _cvxRewardsClaimable;
                    if (cycleInfo[nextClaimableCvx].isCvxProcessed) {
                        _cvxRewardsClaimable = new ICommonStruct.TokenAmount[](maxLengthRewards);
                        for (uint256 x; x < maxLengthRewards; ) {
                            ICommonStruct.TokenAmount memory rewardAsset = cvxRewardsByCycle[nextClaimableCvx][x + 1];
                            if (rewardAsset.amount != 0) {
                                _cvxRewardsClaimable[x] = ICommonStruct.TokenAmount({
                                    token: rewardAsset.token,
                                    amount: (amountStaked * rewardAsset.amount) / totalStaked
                                });
                            } else {
                                // solhint-disable-next-line no-inline-assembly
                                assembly {
                                    /// @dev this reduce the length of the array to not return some useless 0 at the end
                                    mstore(_cvxRewardsClaimable, sub(mload(_cvxRewardsClaimable), 1))
                                }
                            }
                            unchecked {
                                ++x;
                            }
                        }
                    }
                    claimableCyclesAndAmounts[counter++] = ClaimableCyclesAndAmounts({
                        cycleClaimable: nextClaimableCvx,
                        cvgRewards: cvgAmount,
                        cvxRewards: _cvxRewardsClaimable
                    });
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        /// @dev this reduce the length of the array to not return some useless 0 at the end
                        mstore(claimableCyclesAndAmounts, sub(mload(claimableCyclesAndAmounts), 1))
                    }
                }

                unchecked {
                    ++nextClaimableCvx;
                }
            }
        }

        return claimableCyclesAndAmounts;
    }

    /**
     *  @notice Get Convex rewards that have been processed for a cycleId.
     *  @param cycleId  Rewards have been processed for this cycleId
     *  @return An array of struct with the address of the ERC20 and the associated amount.
     */
    function getProcessedCvxRewards(uint256 cycleId) external view returns (ICommonStruct.TokenAmount[] memory) {
        uint256 maxLengthRewards = numberOfUnderlyingRewards;
        ICommonStruct.TokenAmount[] memory _rewards = new ICommonStruct.TokenAmount[](maxLengthRewards);
        uint256 index;
        for (uint256 x; x < maxLengthRewards; ) {
            if (cvxRewardsByCycle[cycleId][x + 1].amount != 0) {
                _rewards[index] = cvxRewardsByCycle[cycleId][x + 1];
                unchecked {
                    ++index;
                }
            } else {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    /// @dev this reduces the length of the _rewardsClaimable array not to return some useless 0 at the end
                    mstore(_rewards, sub(mload(_rewards), 1))
                }
            }
            unchecked {
                ++x;
            }
        }
        return _rewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            SETTERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @notice method for the owner to update the deposit status of the contract
    function toggleDepositPaused() external onlyOwner {
        depositPaused = !depositPaused;
    }

    /**
     *  @notice Set the {_buffer} linked to the contract
     *  @param _buffer to pair with this contract
     */
    function setBuffer(address _buffer) external {
        require(
            msg.sender == owner || msg.sender == address(cvgControlTower.cloneFactory()),
            "NOT_OWNER_OR_CLONE_FACTORY"
        );
        buffer = _buffer;
    }

    function setPoolEthInfo(IStakingServiceBase.PoolEthInfo calldata _poolEthInfo) public onlyOwner {
        if (
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.UNIV2 ||
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.DEACTIVATED
        ) {
            require(_poolEthInfo.fee == 0, "FEE_FOR_UNIV3");
            require(_poolEthInfo.indexEth == 0, "INDEX_FOR_CURVE");
            require(address(_poolEthInfo.poolCurve) == address(0), "POOL_FOR_CURVE");
        } else if (_poolEthInfo.poolType == IStakingServiceBase.PoolType.UNIV3) {
            require(_poolEthInfo.indexEth == 0, "INDEX_FOR_CURVE");
            require(address(_poolEthInfo.poolCurve) == address(0), "POOL_FOR_CURVE");
        } else if (
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.CURVE_DUO ||
            _poolEthInfo.poolType == IStakingServiceBase.PoolType.CURVE_TRI
        ) {
            require(_poolEthInfo.fee == 0, "FEE_FOR_UNIV3");
            require(ICrvPool(_poolEthInfo.poolCurve).coins(_poolEthInfo.indexEth) == WETH, "WRONG_INDEX_ETH");
            require(
                ICrvPool(_poolEthInfo.poolCurve).coins(_poolEthInfo.indexAsset) == address(asset),
                "WRONG_INDEX_ASSET"
            );
        }
        if (_poolEthInfo.poolType == IStakingServiceBase.PoolType.DEACTIVATED) {
            delete poolEthInfo;
        } else {
            require(_poolEthInfo.token == address(asset), "WRONG TOKEN");
            poolEthInfo = _poolEthInfo;
        }
    }

    function _tstore(bytes32 location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tload(bytes32 location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            ERC20
       =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.

     */
    function _transfer(address from, address to, uint256 amount) internal {
        revert("Transfers blocked before audit");

        emit Transfer(from, to, amount);
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        revert("Approve blocked before audit");

        emit Approval(tokenOwner, spender, amount);
    }

    /**
     *  @notice Retrieves the total amount staked for a Staking Position.
     *  @dev    Uses the array of all Staking/Withdraw history to retrieve the last staking value updated in case a user doesn't stake/withdraw at each cycle.
     *  @param account  Id of the Staking position.
     *  @return The total amount staked on this position.
     */
    function balanceOf(address account) public view returns (uint256) {
        /// @dev Retrieve the amount of cycle with action on it
        uint256 _cycleLength = stakingHistoryByAccount[account].length;
        /// @dev If 0, means that no action has ever been made on this account
        if (_cycleLength == 0) return 0;

        /// @dev Retrieves the last cycle where an action occured
        /// @dev Fetches the amount staked on this cycle in tokenInfoByCycle
        return accountInfoByCycle[stakingHistoryByAccount[account][_cycleLength - 1]][account].amountStaked;
    }

    /**
     *  @notice Retrieves the total amount staked for a Staking Position.
     *  @dev    Uses the array of all Staking/Withdraw history to retrieve the last staking value updated in case a user doesn't stake/withdraw at each cycle.
     *  @return The total amount staked on this position.
     */
    function totalSupply() public view returns (uint256) {
        /// @dev Retrieve the totalStaked on the nextCycle
        return cycleInfo[stakingCycle + 1].totalStaked;
    }
    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNABLE
       =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() external {
        require(pendingOwner == msg.sender, "Caller is not the new owner");
        delete pendingOwner;
        address oldOwner = owner;
        owner = msg.sender;
        emit OwnershipTransferred(oldOwner, msg.sender);
    }
}
