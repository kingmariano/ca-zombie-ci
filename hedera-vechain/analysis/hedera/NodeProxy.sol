// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NodeProxy Contract
 * @author Stader Labs
 * @notice Node Proxy Contract Stake Hbar to a Node
 */
contract NodeProxy is Ownable {
    address payable public stakerAddress = payable(address(0));

    /// @notice event emitted while transferFund function triggered
    event TransferredFunds(address indexed to, address from, uint256 amount);

    /// @notice event emits after receiving Hbars from staking contract
    event ReceivedFunds(address indexed to, uint256 amount);

    /**
     * @notice modifier
     * @dev check for zero address
     */
    modifier checkZeroAddress(address _address) {
        require(_address != address(0), "Address cannot be zero");
        _;
    }

    /**
     * @notice modifier
     * @dev check for the owner of the contract
     * staking manager is the manager of this contract
     */
    modifier onlyStakingContract() {
        require(
            msg.sender == stakerAddress,
            "Staking Manager is the only Owner"
        );
        _;
    }

    /**
     * @notice receive funds from staking contract for protocol staking
     * @dev only staking contract can call it
     */
    function receiveFunds() external payable onlyStakingContract {
        emit ReceivedFunds(msg.sender, msg.value);
    }

    /**
     * @notice transfer nodeProxyContract balance to staking contract
     * @dev only stakingContract can call it
     */
    function transferFund() external onlyStakingContract {
        uint256 balanceToSend = address(this).balance;
        Address.sendValue(payable(stakerAddress), address(this).balance);
        emit TransferredFunds(stakerAddress, address(this), balanceToSend);
    }

    /**
     * @notice set the stakingContractId as owner for rest all methods
     * @dev can call only one time
     * @param _stakerAddress staking contractId
     */
    function lockStakingContract(address payable _stakerAddress)
        external
        checkZeroAddress(_stakerAddress)
        onlyOwner
    {
        require(stakerAddress == address(0), "stakingContractId already set");
        stakerAddress = _stakerAddress;
    }
}
