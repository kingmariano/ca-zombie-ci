// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SphereMath, SphereMath32, SphereMath112, SphereMath224} from "../lib/SphereMath.sol";

interface IRewardStaking {
  function stakeFor(address, uint256) external;
}

interface IAutocompounder {
  function autocompound(
    address _account,
    address _token,
    bytes calldata _data,
    address _oneInchRouter
  ) external;
}

/**
 * @title   SphereLocker
 * @author  Sphere Finance
 * @notice  Effectively allows for rolling 16 week lockups of Sphere, and provides balances available
 *          at each epoch (1 week).
 * @dev     Invdividual and delegatee vote power lookups both use independent accounting mechanisms.
 */
contract SphereLocker is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
  using SphereMath for uint256;
  using SphereMath224 for uint224;
  using SphereMath112 for uint112;
  using SphereMath32 for uint32;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /* ==========     STRUCTS     ========== */

  struct RewardData {
    /// Timestamp for current period finish
    uint32 periodFinish;
    /// Last time any user took action
    uint32 lastUpdateTime;
    /// RewardRate for the rest of the period
    uint96 rewardRate;
    /// Ever increasing rewardPerToken rate, based on % of total supply
    uint96 rewardPerTokenStored;
  }

  struct UserData {
    uint128 rewardPerTokenPaid;
    uint128 rewards;
  }

  struct EarnedData {
    address token;
    uint256 amount;
  }

  struct Balances {
    uint112 locked;
    uint32 nextUnlockIndex;
  }

  struct LockedBalance {
    uint112 amount;
    uint32 unlockTime;
  }

  struct Epoch {
    uint224 supply;
    uint32 date; //epoch start date
  }

  struct DelegateeCheckpoint {
    uint224 votes;
    uint32 epochStart;
  }

  /* ========== STATE VARIABLES ========== */

  // Rewards
  address[] public rewardTokens;
  mapping(address => uint256) public queuedRewards;
  uint256 public constant NEW_REWARD_RATIO = 830;
  //     Core reward data
  mapping(address => RewardData) public rewardData;
  //     Reward token -> distributor -> is approved to add rewards
  mapping(address => mapping(address => bool)) public rewardDistributors;
  //     User -> reward token -> amount
  mapping(address => mapping(address => UserData)) public userData;
  //     Duration that rewards are streamed over
  uint256 public constant REWARDS_DURATION = 86400 * 7;
  //     Duration of lock/earned penalty period
  uint256 public constant LOCK_DURATION = REWARDS_DURATION * 17;

  // Balances
  //     Supplies and historic supply
  uint256 public lockedSupply;
  //     Epochs contains only the tokens that were locked at that epoch, not a cumulative supply
  Epoch[] public epochs;
  //     Mappings for balance data
  mapping(address => Balances) public balances;
  mapping(address => LockedBalance[]) public userLocks;

  address public penaltyReceiver;

  // Voting
  //     Stored delegations
  mapping(address => address) private _delegates;
  //     Checkpointed votes
  mapping(address => DelegateeCheckpoint[]) private _checkpointedVotes;
  //     Delegatee balances (user -> unlock timestamp -> amount)
  mapping(address => mapping(uint256 => uint256)) public delegateeUnlocks;

  // Config
  //     Blacklisted smart contract interactions
  mapping(address => bool) public blacklist;
  //     Tokens
  IERC20Upgradeable public stakingToken;
  //     Denom for calcs
  uint256 public constant DENOMINATOR = 10000;
  //     Incentives
  uint256 public kickRewardPerEpoch;
  uint256 public kickRewardEpochDelay;
  //     Shutdown
  bool public isShutdown;
  //     Cap
  uint256 public cappedSupply;

  // Basic token data
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  mapping(address => bool) public whitelist;
  mapping(address => Balances) public ragequitBalances;
  bool allow;
  address public matic;
  address public autocompound;

  /* ========== EVENTS ========== */

  event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
  event DelegateCheckpointed(address indexed delegate);

  event Recovered(address _token, uint256 _amount);
  event RewardPaid(address indexed _user, address indexed _rewardsToken, uint256 _reward);
  event Staked(address indexed _user, uint256 _paidAmount, uint256 _lockedAmount);
  event Withdrawn(address indexed _user, uint256 _amount, bool _relocked);
  event WithdrawnWithPenalty(address indexed _user, uint256 _amount);
  event KickReward(address indexed _user, address indexed _kicked, uint256 _reward);
  event RewardAdded(address indexed _token, uint256 _reward);

  event BlacklistModified(address account, bool blacklisted);
  event KickIncentiveSet(uint256 rate, uint256 delay);
  event Shutdown();
  event PenaltyReceiverUpdated(address indexed _penaltyReceiver);

  event AddReward(address indexed rewardsToken, address indexed distributor);
  event ApproveRewardDistributor(address indexed rewardsToken, address indexed distributor, bool approved);
  event CappedSupplyUpdated(uint256 _newCap);
  event WhitelistModified(address account, bool whitelisted);

  /***************************************
                    CONSTRUCTOR
    ****************************************/

  /**
   * @dev Initializes the contract.
   * @param _nameArg The name of the token.
   * @param _symbolArg The symbol of the token.
   * @param _stakingToken The address of the staking token.
   * @param _penaltyReceiver The address to receive penalties.
   */
  function __SphereLocker_init(
    string memory _nameArg,
    string memory _symbolArg,
    address _stakingToken,
    address _penaltyReceiver
  ) internal initializer {
    __Ownable_init_unchained();
    _name = _nameArg;
    _symbol = _symbolArg;
    _decimals = 18;
    kickRewardPerEpoch = 100;
    kickRewardEpochDelay = 3;
    penaltyReceiver = _penaltyReceiver;
    cappedSupply = 1e6 * 1e18;
    whitelist[msg.sender] = true;

    stakingToken = IERC20Upgradeable(_stakingToken);

    // Determine the current epoch and create the first epoch with a supply of zero
    uint256 currentEpoch = block.timestamp.div(REWARDS_DURATION).mul(REWARDS_DURATION);
    epochs.push(Epoch({supply: 0, date: uint32(currentEpoch)}));
  }

  /***************************************
                    MODIFIER
    ****************************************/

  /**
   * @dev Updates the reward data for the given account.
   * @param _account Account to update the reward data for.
   */
  modifier updateReward(address _account) {
    {
      // Get the balance data for the user
      Balances storage userBalance = balances[_account];
      // Iterate through the reward tokens
      uint256 rewardTokensLength = rewardTokens.length;
      for (uint256 i = 0; i < rewardTokensLength; i++) {
        address token = rewardTokens[i];
        // Update the reward per token and last update time for the reward token
        uint256 newRewardPerToken = _rewardPerToken(token);
        rewardData[token].rewardPerTokenStored = newRewardPerToken.to96();
        rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(rewardData[token].periodFinish).to32();
        // If the user is not the zero address, update the user's reward data
        if (_account != address(0)) {
          userData[_account][token] = UserData({
            rewardPerTokenPaid: newRewardPerToken.to128(),
            rewards: _earned(_account, token, userBalance.locked).to128()
          });
        }
      }
    }
    _;
  }

  /**
   * @dev Ensures that the sender and receiver are not blacklisted.
   * @param _sender Sender of the message.
   * @param _receiver Receiver of the message.
   */
  modifier notBlacklisted(address _sender, address _receiver) {
    // Ensure that the sender is not blacklisted
    require(!blacklist[_sender], "blacklisted");

    // If the sender and receiver are different addresses, ensure that the receiver is not blacklisted
    if (_sender != _receiver) {
      require(!blacklist[_receiver], "blacklisted");
    }

    _;
  }

  /***************************************
                    ADMIN
    ****************************************/

  /**
   * @notice Modifies the blacklist status of the given account.
   * @param _account Account to modify the blacklist status for.
   * @param _blacklisted Whether the account should be blacklisted or not.
   * @dev Can only be called by the contract owner. The account must be a contract.
   * @dev Modifies the blacklist status of the account and emits the BlacklistModified event.
   */
  function modifyBlacklist(address _account, bool _blacklisted) external onlyOwner {
    // Ensure that the account is a contract
    uint256 cs;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      cs := extcodesize(_account)
    }
    require(cs != 0, "Must be contract");

    // Modify the blacklist status of the account
    blacklist[_account] = _blacklisted;
    // Emit the BlacklistModified event
    emit BlacklistModified(_account, _blacklisted);
  }

  function updateKickRewardPerEpoch(uint256 _kickRewardPerEpoch) external onlyOwner {
    kickRewardPerEpoch = _kickRewardPerEpoch;
  }

  /**
   * @notice Adds a new reward token and allows the given distributor to add rewards for it.
   * @param _rewardsToken Address of the reward token to add.
   * @param _distributor Address of the distributor that will be able to add rewards for the token.
   * @dev Only the contract owner can call this function. _rewardsToken cannot be the staking token.
   * @dev The number of reward tokens must be less than 100. _rewardsToken must not already have reward data.
   * @dev Adds _rewardsToken to the list of reward tokens, initializes the reward data,
   * and allows the given distributor to add rewards. Emits the AddReward event.
   */
  function addReward(address _rewardsToken, address _distributor) external onlyOwner {
    // Ensure that the reward token does not already have reward data
    require(rewardData[_rewardsToken].lastUpdateTime == 0, "Reward already exists");
    // Ensure that the reward token is not the staking token
    require(_rewardsToken != address(stakingToken), "Cannot add StakingToken as reward");
    // Ensure that the number of reward tokens is less than 100
    require(rewardTokens.length < 100, "Max rewards length");

    // Add the reward token to the list of reward tokens and initialize the reward data
    rewardTokens.push(_rewardsToken);
    rewardData[_rewardsToken].lastUpdateTime = uint32(block.timestamp);
    rewardData[_rewardsToken].periodFinish = uint32(block.timestamp);
    // Allow the distributor to add rewards for the reward token
    rewardDistributors[_rewardsToken][_distributor] = true;

    // Emit the AddReward event
    emit AddReward(_rewardsToken, _distributor);
  }

  /**
   * @notice Modifies the approval for an address to call `notifyRewardAmount`.
   * @param _rewardsToken Address of the reward token.
   * @param _distributor Address to modify the approval for.
   * @param _approved True to approve, false to unapprove.
   * @dev Only the contract owner can call this function. _rewardsToken must have reward data.
   * @dev Modifies the approval for the given address to call `notifyRewardAmount` for the given reward token.
   * Emits the ApproveRewardDistributor event.
   */
  function approveRewardDistributor(
    address _rewardsToken,
    address _distributor,
    bool _approved
  ) external onlyOwner {
    // Ensure that the reward token has reward data
    require(rewardData[_rewardsToken].lastUpdateTime > 0, "Reward does not exist");
    // Modify the approval for the distributor
    rewardDistributors[_rewardsToken][_distributor] = _approved;
    // Emit the ApproveRewardDistributor event
    emit ApproveRewardDistributor(_rewardsToken, _distributor, _approved);
  }

  /**
   * @notice Sets the kick incentive rate and delay.
   * @param _rate Incentive rate to set. Must be less than or equal to 500 (5% per epoch).
   * @param _delay Incentive delay to set. Must be greater than or equal to 2 (2 epochs of grace).
   * @dev Only the contract owner can call this function.
   * @dev Sets the kick incentive rate and delay. Emits the KickIncentiveSet event.
   */
  function setKickIncentive(uint256 _rate, uint256 _delay) external onlyOwner {
    // Ensure that the rate is less than or equal to 500 (5% per epoch)
    require(_rate <= 500, "over max rate");
    // Ensure that the delay is greater than or equal to 2 (2 epochs of grace)
    require(_delay >= 2, "min delay");
    // Set the kick incentive rate and delay
    kickRewardPerEpoch = _rate;
    kickRewardEpochDelay = _delay;
    // Emit the KickIncentiveSet event
    emit KickIncentiveSet(_rate, _delay);
  }

  /**
   * @notice Shuts down the contract.
   * @dev Only the contract owner can call this function. Sets the `isShutdown` state variable to
   * true and emits the Shutdown event.
   */
  function shutdown() external onlyOwner {
    // Set the isShutdown state variable to true
    isShutdown = true;
    // Emit the Shutdown event
    emit Shutdown();
  }

  function setAutocompoundData(address _matic, address _autocompound) external onlyOwner {
    // Set the matic token address
    matic = _matic;
    autocompound = _autocompound;
  }

  /**
   * @notice Recovers ERC20 tokens from the contract.
   * @param _tokenAddress Address of the ERC20 token to recover.
   * @param _tokenAmount Amount of the ERC20 token to recover.
   * @dev Only the contract owner can call this function. _tokenAddress cannot be the staking token or a reward token.
   * @dev Recovers the specified amount of the ERC20 token from the contract. Emits the Recovered event.
   */
  function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
    // Ensure that the token address is not the staking token
    require(_tokenAddress != address(stakingToken), "Cannot withdraw staking token");
    // Ensure that the token address is not a reward token
    require(rewardData[_tokenAddress].lastUpdateTime == 0, "Cannot withdraw reward token");
    // Recover the ERC20 token from the contract
    IERC20Upgradeable(_tokenAddress).safeTransfer(owner(), _tokenAmount);
    // Emit the Recovered event
    emit Recovered(_tokenAddress, _tokenAmount);
  }

  /***************************************
                    ACTIONS
    ****************************************/

  /**
   * @notice Locks tokens to receive staking rewards.
   * @param _account Address to lock tokens for.
   * @param _amount Amount of tokens to lock.
   * @dev Transfers the specified amount of tokens from the caller to the contract,
   * then locks the tokens for the given account.
   * @dev Calls the `_lock` function, which is marked as internal and non-reentrant.
   * @dev Calls the `updateReward` modifier for the given account.
   */
  function lock(address _account, uint256 _amount) external nonReentrant updateReward(_account) {
    // Transfer the specified amount of tokens from the caller to the contract
    stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    // Lock the tokens for the given account
    _lock(_account, _amount);
  }

  function lockFromAutocompound(address _account, uint256 _amount) external updateReward(_account) {
    require(msg.sender == address(autocompound), "only autocompound");
    // Transfer the specified amount of tokens from the caller to the contract
    stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    // Lock the tokens for the given account
    _lock(_account, _amount);
  }

  /**
   * @notice Locks all the caller's staking tokens in the contract.
   * @dev The caller's staking token balance is transferred to the contract and locked.
   * The caller's reward data is updated. Non-reentrant.
   */
  function lockAll() external nonReentrant updateReward(msg.sender) {
    // Get the caller's staking token balance
    uint256 balance = stakingToken.balanceOf(msg.sender);
    // Transfer the balance to the contract
    stakingToken.safeTransferFrom(msg.sender, address(this), balance);
    // Lock the balance in the contract for the caller
    _lock(msg.sender, balance);
  }

  /**
   * @notice Locks all the caller's staking tokens in the contract for the given account.
   * @param _account Account to lock the tokens for.
   * @dev The caller's staking token balance is transferred to the contract and locked for the given account.
   * The given account's reward data is updated. Non-reentrant.
   */
  function lockAllFor(address _account) external nonReentrant updateReward(_account) {
    // Get the caller's staking token balance
    uint256 balance = stakingToken.balanceOf(msg.sender);
    // Transfer the balance to the contract
    stakingToken.safeTransferFrom(msg.sender, address(this), balance);
    // Lock the balance in the contract for the given account
    _lock(_account, balance);
  }

  /**
   * @notice Locks a specific amount of tokens.
   * @param _account Address of the account to lock the tokens from.
   * @param _amount Amount of tokens to lock.
   * @dev Must not be shutdown. _account and msg.sender must not be blacklisted.
   * @dev Checkpoints the epoch and adds the lock to the user's balance and to the epoch's supply.
   * @dev If the user is a delegate, also updates the delegate's balance. Emits the Staked event.
   */
  function _lock(address _account, uint256 _amount) internal notBlacklisted(msg.sender, _account) {
    // Ensure that the amount to lock is greater than zero
    require(_amount > 0, "Cannot stake 0");
    // Ensure that the contract is not in the shutdown state
    require(!isShutdown, "shutdown");
    require(allow, "not yet");

    // Get the balance data for the user
    Balances storage bal = balances[_account];

    // Checkpoint the epoch to ensure that the delegate's vote power is properly accounted for
    _checkpointEpoch();

    // Add the locked amount to the user's balance
    uint112 lockAmount = _amount.to112();
    bal.locked = bal.locked + (lockAmount);

    // Add the locked amount to the total locked supply
    lockedSupply = lockedSupply + (_amount);

    // Determine the current epoch and the unlock time for the locked tokens
    uint256 currentEpoch = (block.timestamp / (REWARDS_DURATION)) * (REWARDS_DURATION);
    uint256 unlockTime = currentEpoch + (LOCK_DURATION);

    // If the user has no existing locks or the unlock time for their most recent lock is earlier
    // than the current unlock time, add a new lock record for the user
    uint256 idx = userLocks[_account].length;
    if (idx == 0 || userLocks[_account][idx - 1].unlockTime < unlockTime) {
      userLocks[_account].push(LockedBalance({amount: lockAmount, unlockTime: uint32(unlockTime)}));
    } else {
      // Otherwise, add the locked amount to the user's most recent lock record
      LockedBalance storage userL = userLocks[_account][idx - 1];
      userL.amount = userL.amount + (lockAmount);
    }

    //    // If the user is a delegate, update the delegate's balance and checkpoint the delegate's vote power
    //    address delegatee = delegates(_account);
    //    if (delegatee != address(0)) {
    //      delegateeUnlocks[delegatee][unlockTime] += lockAmount;
    //      _checkpointDelegate(delegatee, lockAmount, 0);
    //    }

    // Add the locked amount to the current epoch's supply
    Epoch storage e = epochs[epochs.length - 1];
    e.supply = e.supply + (lockAmount);

    // Emit the Staked event
    emit Staked(_account, lockAmount, lockAmount);
  }

  function getReward(address _account) external {
    getReward(_account, false, false, "", address(0), address(0));
  }

  function getRewardAndAutoCompound(
    address _account,
    bool _autocompound,
    bytes calldata _data,
    address _oneInchRouter,
    address _autocompounder
  ) external {
    getReward(_account, false, _autocompound, _data, _oneInchRouter, _autocompounder);
  }

  /**
   * @notice Claims all pending rewards for the given account.
   * @param _account Address to claim rewards for.
   * @dev Calls the `updateReward` modifier for the given account.
   * @dev Iterates over the reward tokens and claims any pending rewards for the given account.
   * @dev Emits the RewardPaid event.
   */
  function getReward(
    address _account,
    bool _stake,
    bool _autocompound,
    bytes memory _data,
    address _oneInchRouter,
    address _autocompounder
  ) public nonReentrant updateReward(_account) {
    // Get the number of reward tokens
    uint256 rewardTokensLength = rewardTokens.length;
    // Iterate over the reward tokens
    for (uint256 i; i < rewardTokensLength; i++) {
      // Get the current reward token
      address _rewardsToken = rewardTokens[i];
      // Get the pending rewards for the given account for the current reward token
      uint256 reward = userData[_account][_rewardsToken].rewards;
      // If there are pending rewards
      if (reward > 0) {
        userData[_account][_rewardsToken].rewards = 0;
        // Checks if the reward token is the Sphere token and if the user is staking
        if (_rewardsToken == address(stakingToken) && _stake && _account == msg.sender) {
          // Lock the rewards for the given account
          _lock(_account, reward);
        } else if (_rewardsToken == matic && _autocompound == true && _account == msg.sender) {
          IERC20Upgradeable(_rewardsToken).safeTransfer(_autocompounder, reward);
          IAutocompounder(_autocompounder).autocompound(_account, matic, _data, _oneInchRouter);
        } else {
          // Transfer the rewards to the given account
          IERC20Upgradeable(_rewardsToken).safeTransfer(_account, reward);
        }
        // Emit the RewardPaid event
        emit RewardPaid(_account, _rewardsToken, reward);
      }
    }
  }

  /**
   * @notice Claims rewards for the given account, skipping specified reward tokens.
   * @param _account Address to claim rewards for.
   * @param _skipIdx Array of booleans indicating which reward tokens to skip.
   * @dev This function is marked as non-reentrant and calls the `updateReward` modifier for the given account.
   * @dev Iterates over the reward tokens, skipping any specified in the `_skipIdx` array.
   * If the reward amount for the current reward token is greater than 0,
   * it is transferred to the given account and the `RewardPaid` event is emitted.
   */
  function getReward(address _account, bool[] calldata _skipIdx) external nonReentrant updateReward(_account) {
    // Get the length of the reward tokens array
    uint256 rewardTokensLength = rewardTokens.length;
    // Require that the length of the _skipIdx array is the same as the length of the reward tokens array
    require(_skipIdx.length == rewardTokensLength, "!arr");
    // Iterate over the reward tokens
    for (uint256 i; i < rewardTokensLength; i++) {
      // If the current reward token should be skipped, skip it
      if (_skipIdx[i]) continue;
      // Get the address of the current reward token
      address _rewardsToken = rewardTokens[i];
      // Get the reward amount for the current reward token and the given account
      uint256 reward = userData[_account][_rewardsToken].rewards;
      // If the reward amount is greater than 0
      if (reward > 0) {
        // Set the reward amount to 0
        userData[_account][_rewardsToken].rewards = 0;
        // Transfer the reward amount to the given account
        IERC20Upgradeable(_rewardsToken).safeTransfer(_account, reward);
        // Emit the RewardPaid event
        emit RewardPaid(_account, _rewardsToken, reward);
      }
    }
  }

  /**
   * @notice Checkpoints the current epoch, storing the votes of each delegatee and their current epoch start date.
   * @dev Calls the `_checkpointEpoch` function, which is marked as internal.
   */
  function checkpointEpoch() external {
    _checkpointEpoch();
  }

  /**
   * @dev Inserts a new epoch if needed, filling in any gaps.
   * @dev The `currentEpoch` is calculated by dividing the current block timestamp by the rewards duration,
   * then multiplying by the rewards duration. If the `nextEpochDate` is less than the `currentEpoch`,
   * a loop is entered that adds the rewards duration to the `nextEpochDate` and pushes a new `Epoch` struct
   * with a supply of 0 and the `nextEpochDate` as the date to the `epochs` array
   * until the `nextEpochDate` is equal to the `currentEpoch`.
   */
  function _checkpointEpoch() internal {
    // Calculate the current epoch
    uint256 currentEpoch = block.timestamp.div(REWARDS_DURATION).mul(REWARDS_DURATION);
    // Get the date of the next epoch
    uint256 nextEpochDate = uint256(epochs[epochs.length - 1].date);
    // If the next epoch date is less than the current epoch
    if (nextEpochDate < currentEpoch) {
      // Enter a loop
      while (nextEpochDate != currentEpoch) {
        // Add the rewards duration to the next epoch date
        nextEpochDate = nextEpochDate + (REWARDS_DURATION);
        // Push a new Epoch struct with a supply of 0 and the next epoch date as the date to the epochs array
        epochs.push(Epoch({supply: 0, date: uint32(nextEpochDate)}));
      }
    }
  }

  /**
   * @notice Withdraws all currently locked tokens without checkpointing or accruing any rewards,
   * providing the system is shutdown.
   * @dev Requires that the system is shutdown. Sets the locked balance of the caller to 0,
   * the next unlock index of the caller to the length of the user's lock history,
   * and decreases the locked supply by the amount withdrawn. Transfers the withdrawn tokens to the caller.
   */
  function emergencyWithdraw() external nonReentrant {
    require(isShutdown, "Must be shutdown");

    LockedBalance[] memory locks = userLocks[msg.sender];
    Balances storage userBalance = balances[msg.sender];

    uint256 amt = userBalance.locked;
    require(amt > 0, "Nothing locked");

    userBalance.locked = 0;
    userBalance.nextUnlockIndex = locks.length.to32();
    lockedSupply -= amt;

    emit Withdrawn(msg.sender, amt, false);

    stakingToken.safeTransfer(msg.sender, amt);
  }

  /**
   * @notice Withdraws all currently locked tokens where the unlock time has passed.
   * @param _relock Whether to relock the withdrawn tokens.
   */
  function processExpiredLocks(bool _relock) external nonReentrant {
    _processExpiredLocks(msg.sender, _relock, msg.sender, 0);
  }

  /**
   * @notice Kicks the expired locks for the given account and distributes the kicked tokens to the kicker.
   * @param _account Address to kick expired locks for.
   */
  function kickExpiredLocks(address _account) external nonReentrant {
    //allow kick after grace period of 'kickRewardEpochDelay'
    _processExpiredLocks(_account, false, msg.sender, REWARDS_DURATION.mul(kickRewardEpochDelay));
  }

  // Withdraw all currently locked tokens where the unlock time has passed
  function _processExpiredLocks(
    address _account,
    bool _relock,
    address _rewardAddress,
    uint256 _checkDelay
  ) internal updateReward(_account) {
    LockedBalance[] storage locks = userLocks[_account];
    Balances storage userBalance = balances[_account];
    uint112 locked;
    uint256 length = locks.length;
    uint256 reward = 0;
    uint256 expiryTime = _checkDelay == 0 && _relock
      ? block.timestamp + (REWARDS_DURATION)
      : block.timestamp - (_checkDelay);
    require(length > 0, "no locks");
    // e.g. now = 16
    // if contract is shutdown OR latest lock unlock time (e.g. 17) <= now - (1)
    // e.g. 17 <= (16 + 1)
    if (isShutdown || locks[length - 1].unlockTime <= expiryTime) {
      //if time is beyond last lock, can just bundle everything together
      locked = userBalance.locked;

      //dont delete, just set next index
      userBalance.nextUnlockIndex = length.to32();

      //check for kick reward
      //this wont have the exact reward rate that you would get if looped through
      //but this section is supposed to be for quick and easy low gas processing of all locks
      //we'll assume that if the reward was good enough someone would have processed at an earlier epoch
      if (_checkDelay > 0) {
        uint256 currentEpoch = block.timestamp.sub(_checkDelay).div(REWARDS_DURATION).mul(REWARDS_DURATION);
        uint256 epochsover = currentEpoch.sub(uint256(locks[length - 1].unlockTime)).div(REWARDS_DURATION);
        uint256 rRate = SphereMath.min(kickRewardPerEpoch.mul(epochsover + 1), DENOMINATOR);
        reward = uint256(locked).mul(rRate).div(DENOMINATOR);
      }
    } else {
      //use a processed index(nextUnlockIndex) to not loop as much
      //deleting does not change array length
      uint32 nextUnlockIndex = userBalance.nextUnlockIndex;
      for (uint256 i = nextUnlockIndex; i < length; i++) {
        //unlock time must be less or equal to time
        if (locks[i].unlockTime > expiryTime) break;

        //add to cumulative amounts
        locked = locked + (locks[i].amount);

        //check for kick reward
        //each epoch over due increases reward
        if (_checkDelay > 0) {
          uint256 currentEpoch = block.timestamp.sub(_checkDelay).div(REWARDS_DURATION).mul(REWARDS_DURATION);
          uint256 epochsover = currentEpoch.sub(uint256(locks[i].unlockTime)).div(REWARDS_DURATION);
          uint256 rRate = SphereMath.min(kickRewardPerEpoch.mul(epochsover + 1), DENOMINATOR);
          reward = reward.add(uint256(locks[i].amount).mul(rRate).div(DENOMINATOR));
        }
        //set next unlock index
        nextUnlockIndex++;
      }
      //update next unlock index
      userBalance.nextUnlockIndex = nextUnlockIndex;
    }
    require(locked > 0, "no exp locks");

    //update user balances and total supplies
    userBalance.locked = userBalance.locked - (locked);
    lockedSupply = lockedSupply - (locked);

    //checkpoint the delegatee
    //    _checkpointDelegate(delegates(_account), 0, 0);

    emit Withdrawn(_account, locked, _relock);

    //send process incentive
    if (reward > 0) {
      //reduce return amount by the kick reward
      locked = locked - (reward.to112());

      //transfer reward
      stakingToken.safeTransfer(_rewardAddress, reward);
      emit KickReward(_rewardAddress, _account, reward);
    }

    //relock or return to user
    if (_relock) {
      _lock(_account, locked);
    } else {
      stakingToken.safeTransfer(_account, locked);
    }
  }

  function isLocked(address _account) external view returns (bool) {
    LockedBalance[] memory locks = userLocks[_account];
    return locks.length > 0 && locks[locks.length - 1].unlockTime > block.timestamp;
  }

  /**
   * @dev Retrieve the `totalSupply` at the end of `timestamp`. Note, this value is the sum of all balances.
   * It is but NOT the sum of all the delegated votes!
   */
  function getPastTotalSupply(uint256 timestamp) external view returns (uint256) {
    require(timestamp < block.timestamp, "ERC20Votes: block not yet mined");
    return totalSupplyAtEpoch(findEpochId(timestamp));
  }

  /**
   * @dev Lookup a value in a list of (sorted) checkpoints.
   *      Copied from oz/ERC20Votes.sol
   */
  function _checkpointsLookup(DelegateeCheckpoint[] storage ckpts, uint256 epochStart)
  private
  view
  returns (DelegateeCheckpoint memory)
  {
    uint256 high = ckpts.length;
    uint256 low = 0;
    while (low < high) {
      uint256 mid = SphereMath.average(low, high);
      if (ckpts[mid].epochStart > epochStart) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    return high == 0 ? DelegateeCheckpoint(0, 0) : ckpts[high - 1];
  }

  /***************************************
                VIEWS - BALANCES
    ****************************************/

  // Balance of an account which only includes properly locked tokens as of the most recent eligible epoch
  function balanceOf(address _user) external view returns (uint256 amount) {
    return balanceAtEpochOf(findEpochId(block.timestamp), _user);
  }

  // Balance of an account which only includes properly locked tokens at the given epoch
  function balanceAtEpochOf(uint256 _epoch, address _user) public view returns (uint256 amount) {
    uint256 epochStart = uint256(epochs[0].date).add(uint256(_epoch).mul(REWARDS_DURATION));
    require(epochStart < block.timestamp, "Epoch is in the future");

    uint256 cutoffEpoch = epochStart - (LOCK_DURATION);

    LockedBalance[] storage locks = userLocks[_user];

    //need to add up since the range could be in the middle somewhere
    //traverse inversely to make more current queries more gas efficient
    uint256 locksLength = locks.length;
    for (uint256 i = locksLength; i > 0; i--) {
      uint256 lockEpoch = uint256(locks[i - 1].unlockTime) - (LOCK_DURATION);
      //lock epoch must be less or equal to the epoch we're basing from.
      //also not include the current epoch
      if (lockEpoch < epochStart) {
        if (lockEpoch > cutoffEpoch) {
          amount = amount + (locks[i - 1].amount);
        } else {
          //stop now as no futher checks matter
          break;
        }
      }
    }

    return amount;
  }

  // Information on a user's locked balances
  function lockedBalances(address _user)
  external
  view
  returns (
    uint256 total,
    uint256 unlockable,
    uint256 locked,
    LockedBalance[] memory lockData
  )
  {
    LockedBalance[] storage locks = userLocks[_user];
    Balances storage userBalance = balances[_user];
    uint256 nextUnlockIndex = userBalance.nextUnlockIndex;
    uint256 idx;
    for (uint256 i = nextUnlockIndex; i < locks.length; i++) {
      if (locks[i].unlockTime > block.timestamp) {
        if (idx == 0) {
          lockData = new LockedBalance[](locks.length - i);
        }
        lockData[idx] = locks[i];
        idx++;
        locked = locked + (locks[i].amount);
      } else {
        unlockable = unlockable + (locks[i].amount);
      }
    }
    return (userBalance.locked, unlockable, locked, lockData);
  }

  // Supply of all properly locked balances at most recent eligible epoch
  function totalSupply() external view returns (uint256 supply) {
    return totalSupplyAtEpoch(findEpochId(block.timestamp));
  }

  // Supply of all properly locked balances at the given epoch
  function totalSupplyAtEpoch(uint256 _epoch) public view returns (uint256 supply) {
    uint256 epochStart = uint256(epochs[0].date).add(uint256(_epoch).mul(REWARDS_DURATION));
    require(epochStart < block.timestamp, "Epoch is in the future");

    uint256 cutoffEpoch = epochStart.sub(LOCK_DURATION);
    uint256 lastIndex = epochs.length - 1;

    uint256 epochIndex = _epoch > lastIndex ? lastIndex : _epoch;

    for (uint256 i = epochIndex + 1; i > 0; i--) {
      Epoch memory e = epochs[i - 1];
      if (e.date == epochStart) {
        continue;
      } else if (e.date <= cutoffEpoch) {
        break;
      } else {
        supply += e.supply;
      }
    }
  }

  // Get an epoch index based on timestamp
  function findEpochId(uint256 _time) public view returns (uint256 epoch) {
    return _time.sub(epochs[0].date).div(REWARDS_DURATION);
  }

  /***************************************
                VIEWS - GENERAL
    ****************************************/

  // Number of epochs
  function epochCount() external view returns (uint256) {
    return epochs.length;
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  /***************************************
                VIEWS - REWARDS
    ****************************************/

  // Address and claimable amount of all reward tokens for the given account
  function claimableRewards(address _account) external view returns (EarnedData[] memory userRewards) {
    userRewards = new EarnedData[](rewardTokens.length);
    Balances storage userBalance = balances[_account];
    uint256 userRewardsLength = userRewards.length;
    for (uint256 i = 0; i < userRewardsLength; i++) {
      address token = rewardTokens[i];
      userRewards[i].token = token;
      userRewards[i].amount = _earned(_account, token, userBalance.locked);
    }
    return userRewards;
  }

  function lastTimeRewardApplicable(address _rewardsToken) external view returns (uint256) {
    return _lastTimeRewardApplicable(rewardData[_rewardsToken].periodFinish);
  }

  function rewardPerToken(address _rewardsToken) external view returns (uint256) {
    return _rewardPerToken(_rewardsToken);
  }

  function _earned(
    address _user,
    address _rewardsToken,
    uint256 _balance
  ) internal view returns (uint256) {
    UserData memory data = userData[_user][_rewardsToken];
    return _balance.mul(_rewardPerToken(_rewardsToken).sub(data.rewardPerTokenPaid)).div(1e18).add(data.rewards);
  }

  function _lastTimeRewardApplicable(uint256 _finishTime) internal view returns (uint256) {
    return SphereMath.min(block.timestamp, _finishTime);
  }

  function _rewardPerToken(address _rewardsToken) internal view returns (uint256) {
    if (lockedSupply == 0) {
      return rewardData[_rewardsToken].rewardPerTokenStored;
    }
    return
    uint256(rewardData[_rewardsToken].rewardPerTokenStored).add(
      _lastTimeRewardApplicable(rewardData[_rewardsToken].periodFinish)
      .sub(rewardData[_rewardsToken].lastUpdateTime)
      .mul(rewardData[_rewardsToken].rewardRate)
      .mul(1e18)
      .div(lockedSupply)
    );
  }

  /***************************************
                REWARD FUNDING
    ****************************************/

  function queueNewRewards(address _rewardsToken, uint256 _rewards) internal {
    require(rewardDistributors[_rewardsToken][msg.sender], "!authorized");
    require(_rewards > 0, "No reward");

    RewardData storage rdata = rewardData[_rewardsToken];

    uint256 balanceBefore = IERC20Upgradeable(_rewardsToken).balanceOf(address(this));
    IERC20Upgradeable(_rewardsToken).safeTransferFrom(msg.sender, address(this), _rewards);

    _rewards = IERC20Upgradeable(_rewardsToken).balanceOf(address(this)).sub(balanceBefore);

    _rewards = _rewards.add(queuedRewards[_rewardsToken]);
    require(_rewards < 1e25, "!rewards");

    if (block.timestamp >= rdata.periodFinish) {
      _notifyReward(_rewardsToken, _rewards);
      queuedRewards[_rewardsToken] = 0;
      return;
    }

    //et = now - (finish-duration)
    uint256 elapsedTime = block.timestamp.sub(rdata.periodFinish.sub(REWARDS_DURATION.to32()));
    //current at now: rewardRate * elapsedTime
    uint256 currentAtNow = rdata.rewardRate * elapsedTime;
    uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);
    if (queuedRatio < NEW_REWARD_RATIO) {
      _notifyReward(_rewardsToken, _rewards);
      queuedRewards[_rewardsToken] = 0;
    } else {
      queuedRewards[_rewardsToken] = _rewards;
    }
  }

  function queueNewRewardsSingle(address _rewardsToken, uint256 _rewards) external nonReentrant {
    queueNewRewards(_rewardsToken, _rewards);
  }

  function queueMultisigNewRewards() external nonReentrant {
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];
      uint256 balance = IERC20Upgradeable(token).balanceOf(msg.sender);
      if (balance > 0) {
        if (rewardDistributors[token][msg.sender]) {
          queueNewRewards(token, balance);
        }
      }
    }
  }

  function _notifyReward(address _rewardsToken, uint256 _reward) internal updateReward(address(0)) {
    RewardData storage rdata = rewardData[_rewardsToken];

    if (block.timestamp >= rdata.periodFinish) {
      rdata.rewardRate = _reward.div(REWARDS_DURATION).to96();
    } else {
      uint256 remaining = uint256(rdata.periodFinish).sub(block.timestamp);
      uint256 leftover = remaining.mul(rdata.rewardRate);
      rdata.rewardRate = _reward.add(leftover).div(REWARDS_DURATION).to96();
    }

    // Equivalent to 10 million tokens over a weeks duration
    require(rdata.rewardRate < 1e20, "!rewardRate");
    require(lockedSupply >= 1e20, "!balance");

    rdata.lastUpdateTime = block.timestamp.to32();
    rdata.periodFinish = block.timestamp.add(REWARDS_DURATION).to32();

    emit RewardAdded(_rewardsToken, _reward);
  }

  function userLocksLen(address _account) external view returns (uint256) {
    return userLocks[_account].length;
  }

  function rewardTokensLen() external view returns (uint256) {
    return rewardTokens.length;
  }

  function rewardTokensList() external view returns (address[] memory) {
    return rewardTokens;
  }
}