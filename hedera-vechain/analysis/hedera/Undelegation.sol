// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Undelegation is Ownable, Pausable, ReentrancyGuard {
    ///@notice when user unstakes, the corresponding staked amount can be withdrawn after the unbonding time
    ///@dev current undelegation time is 1 day
    uint256 public unbondingTime = 86400; //

    ///@notice address of staking contract
    address public stakingContractAddress = address(0);

    /// @notice information about amount unstaked along with the timestamp when the unstake was initiated
    struct Undelegate {
        uint256 timestamp;
        uint256 amount;
    }
    ///@notice mapping of user address to the array of Undelegate Object
    mapping(address => Undelegate[]) public undelegationsMap;

    /// @notice event emitted after call function undelegate
    event Undelegated(address indexed to, uint256 amount, uint256 index);
    /// @notice event emitted after call function withdraw
    event Withdrawn(address indexed from, uint256 amount);
    /// @notice event emitted on successful updating of unbonding time
    event NewUnbondingTime(uint256 amount);

    /************************************
     * Staking contract call functions *
     ************************************/

    /// @notice sets an entry in the user undelegations map
    function undelegate(address to) external payable returns (uint256) {
        require(msg.value > 0, "Undelegate amount must be greater than 0");
        require(
            stakingContractAddress != address(0),
            "Staking Address cannot be zero"
        );
        require(
            msg.sender == stakingContractAddress,
            "Only staking contract can undelegate"
        );
        uint256 index = undelegationsMap[to].length;
        undelegationsMap[to].push(Undelegate(block.timestamp, msg.value));
        emit Undelegated(to, msg.value, index);
        return msg.value;
    }

    /**********************
     * User functions      *
     **********************/

    /// @notice transfers the HBAR from the contract balance to the user account
    /// @param index the index of the user's undelegation data
    function withdraw(uint256 index) external whenNotPaused nonReentrant {
        Undelegate storage undelegateData = undelegationsMap[msg.sender][index];
        
        require(undelegateData.amount != 0,"Undelegation not found");
        require(undelegateData.timestamp != 0, "timestamp can not be zero");
        require(
            undelegateData.timestamp + unbondingTime <= block.timestamp,
            "Release time not reached"
        );

        uint256 amount = undelegateData.amount;
        delete undelegationsMap[msg.sender][index];
        // payable(msg.sender).transfer(amount);
        Address.sendValue(payable(msg.sender), amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**********************
     * Setter functions   *
     **********************/

    /// @notice Update Staking contract address for checking call sender for the undelegate function
    /// @dev the address of the staking contract can only be set once
    /// @param _stakingContractAddress new address of staking contract
    function setStakingContractAddress(address _stakingContractAddress)
        external
        onlyOwner
    {
        require(
            _stakingContractAddress != address(0),
            "Staking contract address cannot be 0"
        );
        require(
            stakingContractAddress == address(0),
            "Staking contract address already set"
        );
        stakingContractAddress = _stakingContractAddress;
    }

    /// @notice Update unbondingTime value
    /// @param _unbondingTime time in seconds
    function setUnbondingTime(uint256 _unbondingTime) external onlyOwner {
        unbondingTime = _unbondingTime;
        emit NewUnbondingTime(unbondingTime);
    }

    /// @notice Pauses the contract
    /// @dev The contract must be in the unpaused ot normal state
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract and returns it to the normal state
    /// @dev The contract must be in the paused state
    function unpause() external onlyOwner {
        _unpause();
    }
}
