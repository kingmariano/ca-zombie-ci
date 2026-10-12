//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./aspects/WithOperators.sol";

import { DividendPeriod } from "./utils/DividendPeriod.sol";
import { Math } from "./utils/Math.sol";

import "./IDividends.sol";

contract DividendsV3 is IDividends, ReentrancyGuard, WithOperators {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  struct UserState {
    bool tracked;

    uint256 paidDividends;
    uint256 unpaidDividends;
  }

  struct PoolState {
    bool tracked;

    uint256 lastUpdatedAt;

    uint256 totalShares;
  }

  struct PeriodState {
    bool prepared;

    uint256 totalAllocationPoints;
    
    uint256 accumulatedDividends;
    uint256 dividendsPerSecond;
    uint256 totalDividends;
  }

  struct PoolPeriodState {
    uint256 allocationPoints;

    uint256 accumulatedDividendsPerShare;
  }

  struct UserPoolState {
    uint256 shares;

    uint256 rewardDebt;

    uint256 lastUpdatedAt;
  }

  uint256 public constant periodDurationSeconds = 1 weeks;
  // Fri May 28 2021 14:00:00 GMT
  uint256 public constant firstPeriodStartSeconds = 1622210400;

  IERC20 public dividendToken;

  mapping(uint256 => PeriodState) public periods;

  uint256[] public poolIds;
  mapping(uint256 => PoolState) public pools;
  
  address[] public userIds;
  mapping(address => UserState) public users;
  
  mapping(uint256 => mapping(uint256 => PoolPeriodState)) public poolPeriods;
  mapping(uint256 => mapping(address => UserPoolState)) public poolUsers;

  address public communityWallet;

  constructor(IERC20 _dividendToken, address _communityWallet) {
      dividendToken = _dividendToken;
      communityWallet = _communityWallet;
  }

  function getCurrentPeriod() external view returns (uint256) {
    return DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds);
  }

  function poolCount() external view returns (uint256) {
    return poolIds.length;
  }

  function userCount() external view returns (uint256) {
    return userIds.length;
  }

  function setPoolPeriodAllocation(uint256 _pid, uint256 _period, uint256 _points) public onlyOperator {
    require(!periods[_period].prepared, "expected period to not be ready.");
    
    if(!pools[_pid].tracked) {
      poolIds.push(_pid);
      pools[_pid].lastUpdatedAt = DividendPeriod.firstSecond(DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds), firstPeriodStartSeconds, periodDurationSeconds);
      pools[_pid].tracked = true;
    }

    poolPeriods[_pid][_period].allocationPoints = _points;
  }

  function preparePeriod(uint256 _period, uint256 _totalDividends) public onlyOperator {

    uint256 totalPoints = 0;
    for(uint256 i = 0; i < poolIds.length; i++) {
      uint256 pid = poolIds[i];

      totalPoints = totalPoints.add(poolPeriods[pid][_period].allocationPoints);
    }

    periods[_period].prepared = true;
    periods[_period].totalAllocationPoints = totalPoints;
    periods[_period].totalDividends = _totalDividends;
    periods[_period].dividendsPerSecond = _totalDividends.div(periodDurationSeconds);
  }

  function calculatePeriodMultiplier(uint256 _period, uint256 _pid, uint256 _from, uint256 _to) public view returns (uint256) {
      
      require(_from <= _to, "calculatePeriodMultiplier: expected _from to be less than _to.");
      if(!pools[_pid].tracked) {
        return 0;
      }

      PeriodState storage period = periods[_period];
      if(period.accumulatedDividends >= period.totalDividends) {
        return 0;
      }

      uint256 firstSecond = DividendPeriod.firstSecond(_period, firstPeriodStartSeconds, periodDurationSeconds);
      uint256 lastSecond = DividendPeriod.lastSecond(_period, firstPeriodStartSeconds, periodDurationSeconds);
      _from = Math.clamp(_from, firstSecond, lastSecond);
      _to = Math.clamp(_to, firstSecond, lastSecond);

      return _to.sub(_from);
  }

  function calcateUserPoolPeriodDividends(uint256 _period, uint256 _pid, address _userAddress) private view returns (uint256) {
      
      PeriodState storage period = periods[_period];
      if(!period.prepared) {
        return 0;
      }

      PoolState storage pool = pools[_pid];
      PoolPeriodState storage poolPeriod = poolPeriods[_pid][_period];
      UserPoolState storage user = poolUsers[_pid][_userAddress];

      uint256 lastSecond = Math.min(block.timestamp, DividendPeriod.lastSecond(_period, firstPeriodStartSeconds, periodDurationSeconds));
      uint256 accDividendPerShare = poolPeriod.accumulatedDividendsPerShare;
      if(pool.totalShares > 0 && pool.lastUpdatedAt < lastSecond) {
          uint256 multiplier = calculatePeriodMultiplier(_period, _pid, pool.lastUpdatedAt, lastSecond);
          uint256 dividendReward = multiplier.mul(period.dividendsPerSecond).mul(poolPeriod.allocationPoints).div(period.totalAllocationPoints);
          accDividendPerShare = accDividendPerShare.add(dividendReward.mul(1e36).div(pool.totalShares));
      }

      return user.shares.mul(accDividendPerShare);
  }

  function calculateRawUserReward(uint256 _pid, address _userAddress, uint256 _maxPeriod) private view returns (uint256) {
      UserPoolState storage user = poolUsers[_pid][_userAddress];

      uint256 updatedAt = user.lastUpdatedAt == 0 ? _maxPeriod
        : DividendPeriod.fromSeconds(user.lastUpdatedAt, firstPeriodStartSeconds, periodDurationSeconds);
      
      uint256 total = 0;
      for(uint256 i = updatedAt; i <= _maxPeriod; i++) {
        uint256 _inc = calcateUserPoolPeriodDividends(i, _pid, _userAddress);

        total = total.add(_inc);
      }

      return total;
  }

  function calculatePoolUserPendingDividends(uint256 _pid, address _userAddress, uint256 _maxPeriod) public view returns (uint256) {

      uint256 rawDividends = calculateRawUserReward(_pid, _userAddress, _maxPeriod);
      uint256 rewardDebt = poolUsers[_pid][_userAddress].rewardDebt;

      return (rawDividends - rewardDebt) / 1e36;
  }

  function updatePoolPeriod(uint256 _period, uint256 _pid) private returns (bool) {

      PeriodState storage period = periods[_period];
      if(!period.prepared) {
        return false;
      }

      PoolState storage pool = pools[_pid];
      if (block.timestamp <= pool.lastUpdatedAt) {
        return false;
      }

      if (pool.totalShares == 0) {
        return false;
      }

      uint256 previousLastUpdatedSeconds = Math.max(pool.lastUpdatedAt, DividendPeriod.firstSecond(_period, firstPeriodStartSeconds, periodDurationSeconds));
      pool.lastUpdatedAt = Math.min(block.timestamp, DividendPeriod.lastSecond(_period, firstPeriodStartSeconds, periodDurationSeconds));

      PoolPeriodState storage poolPeriod = poolPeriods[_pid][_period];
      if(poolPeriod.allocationPoints == 0) {
        return true;
      }

      uint256 multiplier = calculatePeriodMultiplier(_period, _pid, previousLastUpdatedSeconds, pool.lastUpdatedAt);
      uint256 dividendReward = multiplier.mul(period.dividendsPerSecond).mul(poolPeriod.allocationPoints).div(period.totalAllocationPoints);
      period.accumulatedDividends = period.accumulatedDividends.add(dividendReward);
      poolPeriod.accumulatedDividendsPerShare = poolPeriod.accumulatedDividendsPerShare.add(dividendReward.mul(1e36).div(pool.totalShares));
      
      return true;
  }

  function updatePool(uint256 _pid) private {
  
    PoolState storage pool = pools[_pid];
    if(!pool.tracked) {
      poolIds.push(_pid);
      pools[_pid].lastUpdatedAt = DividendPeriod.firstSecond(DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds), firstPeriodStartSeconds, periodDurationSeconds);
      pool.tracked = true;
    }

    uint256 updatedPeriod = DividendPeriod.fromSeconds(pool.lastUpdatedAt, firstPeriodStartSeconds, periodDurationSeconds);
    uint256 currentPeriod = DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds);
    for(uint256 i = updatedPeriod; i <= currentPeriod; i++) {
      bool didUpdate = updatePoolPeriod(i, _pid);
      if(!didUpdate) {
        break;
      }
    }
  }
  function updateUser(uint256 _pid, address _userAddress, uint256 _maxPeriod) private {
    
    if(!users[_userAddress].tracked) {
      userIds.push(_userAddress);
      users[_userAddress].tracked = true;
    }

    uint256 unpaidDividends = calculatePoolUserPendingDividends(_pid, _userAddress, _maxPeriod);
    UserPoolState storage user = poolUsers[_pid][_userAddress];
    user.lastUpdatedAt = Math.min(block.timestamp, DividendPeriod.lastSecond(_maxPeriod, firstPeriodStartSeconds, periodDurationSeconds));
    users[_userAddress].unpaidDividends = users[_userAddress].unpaidDividends.add(unpaidDividends);
  }

  function operatorUpdateUser(uint256 _pid, address _userAddress, uint256 _maxPeriod) external onlyOperator {
    
    uint256 currentPeriod = DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds);
    require(_maxPeriod < currentPeriod, "expected period to be in the past.");

    updateUser(_pid, _userAddress, _maxPeriod);
    poolUsers[_pid][_userAddress].rewardDebt = calculateRawUserReward(_pid, _userAddress, _maxPeriod);
  }

  function _setUserStakedAmount(uint256 _pid, address _userAddress, uint256 _userShares) private {
    
    updatePool(_pid);
    updateUser(_pid, _userAddress, DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds));

    UserPoolState storage user = poolUsers[_pid][_userAddress];
    PoolState storage pool = pools[_pid];
    if(user.shares > _userShares) {
      // withdrawal
      pool.totalShares = pool.totalShares.sub(user.shares.sub(_userShares));
    } else {
      // deposit
      pool.totalShares = pool.totalShares.add(_userShares.sub(user.shares));
    }

    user.shares = _userShares;
    user.rewardDebt = calculateRawUserReward(_pid, _userAddress, DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds));
  }

  function setUserStakedAmount(uint256 _pid, address _userAddress, uint256 _userShares) external override nonReentrant onlyOwner {
    _setUserStakedAmount(_pid, _userAddress, _userShares);
  }

  function calculateUnclaimedDividends(address _userAddress) public override view returns (uint256) {

    uint256 totalUnpaid = users[_userAddress].unpaidDividends.sub(users[_userAddress].paidDividends);
    for(uint256 i = 0; i < poolIds.length; i++) {
      uint256 _pid = poolIds[i];

      uint256 owed = calculatePoolUserPendingDividends(_pid, _userAddress, DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds));

      totalUnpaid = totalUnpaid.add(owed);
    }

    return totalUnpaid;
  }
  
  function collectDividends() external override nonReentrant {

    for(uint256 i = 0; i < poolIds.length; i++) {
      uint256 _pid = poolIds[i];

      updatePool(_pid);
      updateUser(_pid, msg.sender, DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds));

      poolUsers[_pid][msg.sender].rewardDebt = calculateRawUserReward(_pid, msg.sender, DividendPeriod.currentPeriod(firstPeriodStartSeconds, periodDurationSeconds));
    }

    uint256 totalUnpaid = users[msg.sender].unpaidDividends.sub(users[msg.sender].paidDividends);
    users[msg.sender].paidDividends = users[msg.sender].unpaidDividends;

    dividendToken.safeTransfer(msg.sender, totalUnpaid);
  }

  function returnFundsToCommunityWallet(uint256 _amount) external {
    require(msg.sender == communityWallet, "expected community wallet to initiate transfer");

    dividendToken.safeTransfer(communityWallet, _amount);
  }

  function migrateUsers(DividendsV3 dividends, address[] calldata _users, uint256[] calldata _pools) external onlyOperator {

    for(uint256 poolI = 0; poolI < _pools.length; poolI++) {
      uint256 pid = _pools[poolI];

      for(uint256 userI = 0; userI < _users.length; userI++) {
        address user = _users[userI];

        // when the user has already been migrated, we skip them!
        if(poolUsers[pid][user].lastUpdatedAt > 0) {
          continue;
        }

        (uint256 shares,,uint256 lastUpdatedAt) = dividends.poolUsers(pid, user);
        if(lastUpdatedAt == 0 || shares == 0) {
          continue;
        }

        _setUserStakedAmount(pid, user, shares);
      }
    }
  }
}
