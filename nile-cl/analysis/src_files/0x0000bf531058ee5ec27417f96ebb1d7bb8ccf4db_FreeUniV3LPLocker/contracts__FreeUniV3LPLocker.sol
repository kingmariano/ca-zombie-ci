// SPDX-License-Identifier: GPL-3.0-or-later

// ██╗      ██████╗  ██████╗██╗  ██╗███████╗██████╗     ██╗███╗   ██╗
// ██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ██║████╗  ██║
// ██║     ██║   ██║██║     █████╔╝ █████╗  ██║  ██║    ██║██╔██╗ ██║
// ██║     ██║   ██║██║     ██╔═██╗ ██╔══╝  ██║  ██║    ██║██║╚██╗██║
// ███████╗╚██████╔╝╚██████╗██║  ██╗███████╗██████╔╝    ██║██║ ╚████║
// ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═════╝     ╚═╝╚═╝  ╚═══╝

// Website: https://freelplocker.com
// Twitter: https://x.com/vezuresxyz

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
  IERC721,
  IERC721Receiver,
  IFreeUniV3LPLocker,
  INonfungiblePositionManager
} from "contracts/interfaces/IFreeUniV3LPLocker.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";

/// @title FreeUniV3LPLocker
/// @notice A free and open source contract for locking Uniswap V3 LP positions
/// @dev Implements the IFreeUniV3LPLocker interface
contract FreeUniV3LPLocker is IFreeUniV3LPLocker, ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.UintSet;
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 public nextLockId = 1;

  /// lock details
  mapping(uint256 lockId => LockInfo) public locks;

  /// List of allowed position managers
  EnumerableSet.AddressSet private positionManagers;

  /// List of lock ids for user
  mapping(address => EnumerableSet.UintSet) private userLocks;

  /// @notice Modifier to check if the caller is the owner of a lock
  /// @param lockId The ID of the lock to check
  modifier validLockOwner(uint256 lockId) {
    require(lockId < nextLockId, "Invalid lockId");
    require(locks[lockId].owner == _msgSender(), "Not lock owner");
    _;
  }

  constructor(address who) Ownable(who) {}

  /// @notice Adds a position manager to the allowed list
  /// @param positionManager_ The address of the position manager to add
  function addAllowedPositionManager(address positionManager_) external onlyOwner {
    positionManagers.add(positionManager_);
    emit OnAddAllowedPositionManager(positionManager_);
  }

  /// @notice Adds multiple position managers to the allowed list
  /// @param positionManagers_ The addresses of the position managers to add
  function addAllowedPositionManagers(address[] calldata positionManagers_) external onlyOwner {
    for (uint256 i = 0; i < positionManagers_.length; i++) {
      positionManagers.add(positionManagers_[i]);
      emit OnAddAllowedPositionManager(positionManagers_[i]);
    }
  }

  /// @notice Checks if a position manager is allowed
  /// @param positionManager_ The address of the position manager
  /// @return isAllowed True if the position manager is allowed, false otherwise
  function isAllowedPositionManager(address positionManager_) public view returns (bool) {
    return positionManagers.contains(positionManager_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function transferLock(uint256 lockId_, address newOwner_) external validLockOwner(lockId_) {
    locks[lockId_].pendingOwner = newOwner_;
    emit OnLockPendingTransfer(lockId_, _msgSender(), newOwner_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function acceptLock(uint256 lockId_) external {
    require(lockId_ < nextLockId, "Invalid lockId");
    address newOwner = _msgSender();
    /// check new owner
    require(newOwner == locks[lockId_].pendingOwner, "Not pendingOwner");
    /// emit event
    emit OnLockTransferred(lockId_, locks[lockId_].owner, newOwner);
    /// remove lockId from owner
    userLocks[locks[lockId_].owner].remove(lockId_);
    /// add lockId to new owner
    userLocks[newOwner].add(lockId_);
    /// set owner
    locks[lockId_].pendingOwner = address(0);
    locks[lockId_].owner = newOwner;
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function unlock(uint256 lockId_) external validLockOwner(lockId_) {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.endTime < block.timestamp, "Not yet");

    _collect(lockId_, userLock.owner, type(uint128).max, type(uint128).max);

    userLock.nftPositionManager.safeTransferFrom(address(this), userLock.owner, userLock.nftId);
    userLocks[userLock.owner].remove(lockId_);

    emit OnUnlock(lockId_, userLock.owner, userLock.nftId, block.timestamp);

    delete locks[lockId_]; // clear the state for this lock (reset all values to zero)
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function relock(uint256 lockId_, uint256 endTime_) external validLockOwner(lockId_) nonReentrant {
    LockInfo storage userLock = locks[lockId_];
    require(endTime_ > userLock.endTime, "EndTime <= currentEndTiem");
    require(endTime_ > block.timestamp, "EndTime <= now");
    userLock.endTime = endTime_;
    emit OnRelock(lockId_, userLock.endTime);
  }

  /// @notice Internal function to lock an NFT position
  /// @param nftManager_ The NFT position manager contract
  /// @param nftId_ The ID of the NFT position
  /// @param owner_ The owner of the lock
  /// @param collector_ The collector of the lock
  /// @param endTime_ The end time of the lock
  /// @return lockId The ID of the lock
  function _lock(IERC721 nftManager_, uint256 nftId_, address owner_, address collector_, uint256 endTime_)
    internal
    nonReentrant
    returns (uint256 lockId)
  {
    require(collector_ != address(0), "CollectAddress invalid");
    require(endTime_ > block.timestamp, "EndTime <= currentTime");

    LockInfo memory newLock = LockInfo({
      lockId: nextLockId,
      nftPositionManager: INonfungiblePositionManager(address(nftManager_)),
      pendingOwner: address(0),
      owner: owner_,
      collector: collector_,
      nftId: nftId_,
      startTime: block.timestamp,
      endTime: endTime_
    });
    locks[newLock.lockId] = newLock;
    userLocks[owner_].add(newLock.lockId);
    nextLockId++;

    emit OnLock(newLock.lockId, address(nftManager_), owner_, nftId_, endTime_);
    return newLock.lockId;
  }

  /// @notice Private collect function, wrap this in re-entrancy guard calls
  /// @param lockId_ The ID of the lock
  /// @param recipient_ The address to receive the fees
  /// @param amount0Max_ The maximum amount of token0 to collect
  /// @param amount1Max_ The maximum amount of token1 to collect
  /// @return amount0 The amount of token0 collected
  /// @return amount1 The amount of token1 collected
  function _collect(uint256 lockId_, address recipient_, uint128 amount0Max_, uint128 amount1Max_)
    private
    returns (uint256 amount0, uint256 amount1)
  {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.owner == _msgSender() || userLock.collector == _msgSender(), "Not owner");
    (amount0, amount1) = userLock.nftPositionManager.collect(
      INonfungiblePositionManager.CollectParams(userLock.nftId, recipient_, amount0Max_, amount1Max_)
    );
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function collect(uint256 lockId_, address recipient_, uint128 amount0Max_, uint128 amount1Max_)
    external
    nonReentrant
    returns (uint256 amount0, uint256 amount1)
  {
    (amount0, amount1) = _collect(lockId_, recipient_, amount0Max_, amount1Max_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function setCollectAddress(uint256 lockId_, address collector_) external validLockOwner(lockId_) nonReentrant {
    require(collector_ != address(0), "COLLECT_ADDR");
    LockInfo storage userLock = locks[lockId_];
    userLock.collector = collector_;
    emit OnSetCollector(lockId_, collector_);
  }

  /// @inheritdoc IERC721Receiver
  function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
    external
    override
    returns (bytes4)
  {
    require(isAllowedPositionManager(msg.sender), "Not allowed");
    if (data.length > 0) {
      (address collector, uint256 endTime) = abi.decode(data, (address, uint256));
      _lock(INonfungiblePositionManager(msg.sender), tokenId, from, collector, endTime);
    } else {
      // max lock the nft forever if it is received by the locker contract without any data
      _lock(INonfungiblePositionManager(msg.sender), tokenId, from, from, type(uint256).max);
    }
    return IERC721Receiver.onERC721Received.selector;
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function getUserLocks(address user) external view returns (uint256[] memory lockIds) {
    return userLocks[user].values();
  }
}
