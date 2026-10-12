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
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol';

import './libs/IDividends.sol';
import './Operators.sol';

contract AuguryStateRepositoryV1 is Ownable, ReentrancyGuard, Operators, IDividends {
    using SafeMath for uint256;

    struct PoolUserState {
        uint256 tvl;
        uint256 lastPositiveStakedTime;
        uint256 lastZeroStakedTime;
    }

    struct UserState {
        uint256 lastInteractedAt;
    }

    struct PoolUserSnapshot {
        uint256 tvl;
    }

    struct PoolSnapshot {
        uint256 tvl;
    }

    struct PoolState {
        uint256 lastInteractedAt;
        uint256 tvl;
    }

    uint256 public constant MAX_UINT_256 = uint256(-1);
    uint256 public epochOffsetSeconds;
    uint256 public epochDurationSeconds;
    uint256 public lastCapturedEpoch;

    ///////////
    // Users //
    ///////////

    address[] public userAddresses;
    // [_pid][_userAddress] => PoolUserState
    mapping(uint256 => mapping(address => PoolUserState)) public poolUsers;
    // [_pid][_userAddress][_epoch] => PoolUserSnapshot
    mapping(uint256 => mapping(address => mapping(uint256 => PoolUserSnapshot))) public poolUserSnapshots;
    // [_userAddress] => UserState
    mapping(address => UserState) public users;

    ///////////
    // Pools //
    ///////////

    uint256[] public poolIds;
    // [_pid] => PoolState
    mapping(uint256 => PoolState) public pools;
    // [_pid][_epoch] => PoolSnapshot
    mapping(uint256 => mapping(uint256 => PoolSnapshot)) public poolSnapshots;

    constructor() public {
        // 1 day
        epochDurationSeconds = 1 days;
        // Fri May 28 2021 09:00:00 GMT-0500 (Central Daylight Time)
        epochOffsetSeconds = 1622210400;

        require((now - 2 * epochDurationSeconds) > epochOffsetSeconds, 'epochDurationSecondsOffset must be at least two epochs in the past.');

        lastCapturedEpoch = secondsToEpoch(getNow()) - 1;
    }

    function getNow() public virtual view returns (uint256) {
        return now;
    }

    function getUserLastStakedTime(uint _pid, address _user) public view returns (uint256) {
        uint256 positiveStakeTime = poolUsers[_pid][_user].lastPositiveStakedTime;
        uint256 zeroStakeTime = poolUsers[_pid][_user].lastZeroStakedTime;

        return positiveStakeTime > zeroStakeTime ? positiveStakeTime
            : zeroStakeTime;
    }

    function hasUserInteracted(address _user) public view returns (bool) {
        return users[_user].lastInteractedAt > 0;
    }

    function hasPoolInteracted(uint256 _pid) public view returns (bool) {
        return pools[_pid].lastInteractedAt > 0;
    }

    function secondsToEpoch(uint256 _seconds) public view returns (uint256) {
        return (_seconds - epochOffsetSeconds).div(epochDurationSeconds);
    }

    function currentEpoch() public view returns (uint256) {
        return secondsToEpoch(getNow());
    }

    // user state
    function _setUserStakedAmount(uint256 _pid, address _userAddress, uint256 _newTvl) private nonReentrant {
        uint256 _currentEpoch = currentEpoch();
        uint256 _now = getNow();

        PoolState storage _pool = pools[_pid];
        PoolSnapshot storage _poolSnapshot = poolSnapshots[_pid][_currentEpoch];

        PoolUserState storage _poolUser = poolUsers[_pid][_userAddress];
        PoolUserSnapshot storage _userSnapshot = poolUserSnapshots[_pid][_userAddress][_currentEpoch];

        if(!hasUserInteracted(_userAddress)) {
            userAddresses.push(_userAddress);
        }
        users[_userAddress].lastInteractedAt = _now;

        if(!hasPoolInteracted(_pid)) {
            poolIds.push(_pid);
        }
        _pool.lastInteractedAt = _now;

        // when the user removes stake
        if(_poolUser.tvl > _newTvl) {
            uint256 _decrementTotalBy = _poolUser.tvl.sub(_newTvl);
            _pool.tvl = _pool.tvl.sub(_decrementTotalBy);
        }

        // when the user adds stake
        if (_poolUser.tvl < _newTvl) {
            uint256 _incrementTotalBy = _newTvl.sub(_poolUser.tvl);
            _pool.tvl = _pool.tvl.add(_incrementTotalBy);
        }

        if(_pool.tvl == 0) {
            _poolSnapshot.tvl = MAX_UINT_256;
        } else {
            _poolSnapshot.tvl = _pool.tvl;
        }

        _poolUser.tvl = _newTvl;
        if(_newTvl == 0) {
            _userSnapshot.tvl = MAX_UINT_256;
            _poolUser.lastZeroStakedTime = getNow();
        } else {
            _userSnapshot.tvl = _newTvl;
            _poolUser.lastPositiveStakedTime = getNow();
        }
    }
    function setUserStakedAmount(uint256 _pid, address _userAddress, uint256 _newTvl) public override onlyOwner {
        _setUserStakedAmount(_pid, _userAddress, _newTvl);
    }

    function getUserTvlAtEpoch(uint256 _pid, address _userAddress, uint256 _epoch) public view returns (uint256) {

        require(_epoch > 0, 'expected a positive epoch.');
        require(_epoch < currentEpoch(), 'expected a previous epoch.');
        
        if(!hasUserInteracted(_userAddress)) {
            return 0;
        }

        // 0 means that the user did not interact with during the epoch
        // we should never get to the 0th epoch, since that would mean the user was not interacted with ever
        uint256 _snapshotTvl = poolUserSnapshots[_pid][_userAddress][_epoch].tvl;
        while(_snapshotTvl == 0 && _epoch > 1) {
            _epoch = _epoch - 1;
            _snapshotTvl = poolUserSnapshots[_pid][_userAddress][_epoch].tvl;
        }

        return _snapshotTvl == MAX_UINT_256 ? 0
            : _snapshotTvl;
    }

    function getPoolTvlAtEpoch(uint256 _pid, uint256 _epoch) public view returns (uint256) {
    
        require(_epoch > 0, 'expected a positive epoch.');
        require(_epoch < currentEpoch(), 'expected a previous epoch.');
        
        if(!hasPoolInteracted(_pid)) {
            return 0;
        }

        // 0 means the pool did not receive any interactions duing the epoch
        // we should never get to the 0th epoch, since that would mean that the pool was not interacted with ever
        uint256 _snapshotTvl = poolSnapshots[_pid][_epoch].tvl;
        while(_snapshotTvl == 0 && _epoch > 1) {
            _epoch = _epoch - 1;
            _snapshotTvl = poolSnapshots[_pid][_epoch].tvl;
        }

        return _snapshotTvl == MAX_UINT_256 ? 0
            : _snapshotTvl;
    }
}
