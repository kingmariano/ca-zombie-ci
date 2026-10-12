//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract JayDerivFeeSplitter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;

    address public TEAM_WALLET;
    address public LP_WALLET;
    address public NFT_WALLET;
    address public JAY_WALLET;

    uint256 public immutable MIN;

    constructor(address _rewardToken) {
        require(_rewardToken != address(0x0), "cannot set to 0x0 address");
        rewardToken = IERC20(_rewardToken);
        MIN = 1 * 10 ** (IERC20Metadata(_rewardToken).decimals() - 3);
    }

    /*
     * Name: splitFees
     * Purpose: Tranfer ETH to staking contracts and team
     * Parameters: n/a
     * Return: n/a
     */
    function splitFees() external nonReentrant {
        uint256 eth = rewardToken.balanceOf(address(this)) / (4);
        if (eth > MIN) {
            sendEth(TEAM_WALLET, eth);
            sendEth(LP_WALLET, eth);
            sendEth(NFT_WALLET, eth);
            sendEth(JAY_WALLET, eth);
        }
    }

    function setTEAMWallet(address _address) external onlyOwner {
        require(_address != address(0x0), "cannot set to 0x0 address");
        TEAM_WALLET = _address;
    }

    function setJAYWallet(address _address) external onlyOwner {
        require(_address != address(0x0), "cannot set to 0x0 address");
        JAY_WALLET = _address;
    }
    function setNFTWallet(address _address) external onlyOwner {
        require(_address != address(0x0), "cannot set to 0x0 address");
        NFT_WALLET = _address;
    }

    function setLPWallet(address _address) external onlyOwner {
        require(_address != address(0x0), "cannot set to 0x0 address");
        LP_WALLET = _address;
    }

    /*
     * Name: sendEth
     * Purpose: Tranfer ETH tokens
     * Parameters:
     *    - @param 1: Address
     *    - @param 2: Value
     * Return: n/a
     */
    function sendEth(address _address, uint256 _value) internal {
        rewardToken.safeTransfer(_address, _value);
    }
}
