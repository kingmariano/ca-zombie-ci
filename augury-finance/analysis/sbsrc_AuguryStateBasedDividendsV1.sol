// SPDX-License-Identifier: Augury Finance
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright Augury Finance, 2021. Do not re-use without permission.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

pragma solidity ^0.6.12;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol';

import './libs/IDividendCalculator.sol';
import './Operators.sol';
import './AuguryStateRepositoryV1.sol';

contract AuguryStateBasedDividendsV1 is Ownable, ReentrancyGuard, Operators, IDividendCalculator {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserState {
      uint256 lastCollectedPeriod;
    }

    struct PeriodState {
      uint256 distributable;
    }

    uint256 public epochsPerPeriod;
    uint256 public epochOffset;
    address public communityWallet;
    uint256 public poolId;

    IERC20 public dividendToken;
    AuguryStateRepositoryV1 public state;

    // [_userAddress] => UserState
    mapping(address => UserState) public users;

    // [_period] => PeriodState
    mapping(uint256 => PeriodState) public periods;
    uint256 public lastReadyPeriod;

    event DividendsCollected(address indexed user, uint256 amount);

    constructor(IERC20 _dividendToken, AuguryStateRepositoryV1 _state, address _communityWallet, uint256 _poolId) public {
        dividendToken = _dividendToken;
        state = _state;
        communityWallet = _communityWallet;
        poolId = _poolId;

        epochsPerPeriod = 7;
        epochOffset = 0;
        lastReadyPeriod = currentPeriod() - 1;
    }

    function epochToPeriod(uint256 _epoch) public view returns (uint256) {
      require(_epoch >= epochOffset, 'expected epoch to be after the epoch offset.');

      return _epoch.sub(epochOffset).div(epochsPerPeriod);
    }
    function periodToFirstEpoch(uint256 _period) public view returns(uint256) {

      return _period.mul(epochsPerPeriod).add(epochOffset);
    }

    function currentPeriod() public view returns (uint256) {
      return epochToPeriod(state.currentEpoch());
    }

    function calculateUserDistribution(uint256 _periodDistributableAmount, uint256 _poolPeriodTvl, uint256 _userPeriodTvl) public pure returns (uint256) {
        if(_poolPeriodTvl == 0 || _userPeriodTvl == 0) {
            return 0;
        }

        uint256 _numerator = _periodDistributableAmount.mul(_userPeriodTvl).mul(1e18);
        uint256 _denominator = _poolPeriodTvl;

        return _numerator.div(_denominator).div(1e18);
    }

    function calculateTvlsForPeriod(address _userAddress, uint256 _period) public view returns (uint256, uint256) {
      uint256 _poolTvl = 0;
      uint256 _userTvl = 0;

      uint256 _epoch = periodToFirstEpoch(_period);
      uint256 _nextPeriodFirstEpoch = periodToFirstEpoch(_period + 1);
      while(_epoch < _nextPeriodFirstEpoch) {

        _poolTvl = _poolTvl + state.getPoolTvlAtEpoch(poolId, _epoch);
        _userTvl = _userTvl + state.getUserTvlAtEpoch(poolId, _userAddress, _epoch);

        _epoch = _epoch + 1;
      }

      return (_poolTvl, _userTvl);
    }

    function preparePeriod(uint256 _period, uint256 _amount) public onlyOperator {
      require(_period == lastReadyPeriod + 1, 'expected period to be lastReadyPeriod + 1');
      require(_period < currentPeriod(), 'expected period to not be active.');

      periods[_period].distributable = _amount;
      lastReadyPeriod = _period;
    }

    function emergencyReturnCommunityFunds() public onlyOperator {
      uint256 _amount = dividendToken.balanceOf(address(this));
      if(_amount == 0) {
        return;
      }

      dividendToken.safeTransfer(communityWallet, _amount);
    }

    function calculateUnclaimedDividends(address _userAddress) public override view returns (uint256) {
      
      uint256 _period = users[_userAddress].lastCollectedPeriod + 1;
      uint256 _total = 0;

      while(_period <= lastReadyPeriod) {

        uint256 _periodDividends = periods[_period].distributable;

        (uint256 _poolTvl, uint256 _userTvl) = calculateTvlsForPeriod(_userAddress, _period);
        _total = _total + calculateUserDistribution(_periodDividends, _poolTvl, _userTvl);

        _period = _period + 1;
      }

      return _total;
    }
  
    function collectDividends() public override {
      uint256 _amount = calculateUnclaimedDividends(msg.sender);

      users[msg.sender].lastCollectedPeriod = lastReadyPeriod;
      if(_amount > 0) {
        dividendToken.safeTransfer(msg.sender, _amount);
        emit DividendsCollected(msg.sender, _amount);
      }
    }

    function calculateUnclaimedDividendsToPeriod(address _userAddress, uint256 _maxPeriod) public view returns (uint256) {
      
      uint256 _period = users[_userAddress].lastCollectedPeriod + 1;
      uint256 _total = 0;

      while(_period <= _maxPeriod) {

        uint256 _periodDividends = periods[_period].distributable;

        (uint256 _poolTvl, uint256 _userTvl) = calculateTvlsForPeriod(_userAddress, _period);
        _total = _total + calculateUserDistribution(_periodDividends, _poolTvl, _userTvl);

        _period = _period + 1;
      }

      return _total;
    }

    function collectDividendsToPeriod(uint256 _period) public {

      if(_period > lastReadyPeriod) {
        _period = lastReadyPeriod;
      }

      uint256 _amount = calculateUnclaimedDividendsToPeriod(msg.sender, _period);

      users[msg.sender].lastCollectedPeriod = _period;
      if(_amount > 0) {
        dividendToken.safeTransfer(msg.sender, _amount);
        emit DividendsCollected(msg.sender, _amount);
      }
    }
}
