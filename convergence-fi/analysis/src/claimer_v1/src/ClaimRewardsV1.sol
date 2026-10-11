// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";
import {IVeSDT} from "src/interfaces/IVeSDT.sol";
import {IDepositor} from "src/interfaces/IDepositor.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ILiquidityGauge} from "src/interfaces/ILiquidityGauge.sol";
import {IVeSDTFeeDistributor} from "src/interfaces/IVeSDTFeeDistributor.sol";

/// @notice Helper contract to claim rewards from gauges and lock them in depositors with a single transaction.
/// version 1.0
contract ClaimRewardsV1 is UUPSUpgradeable {
    /// @notice Struct to store the details of the lock.
    struct LockDetails {
        /// @notice Token to lock.
        address token;
        /// @notice Depositor contract to lock the token.
        address depositor;
        /// @notice Stake the receiptToken or not.
        bool stake;
        /// @notice Lock token in the locker.
        bool lock;
    }

    /// @notice Struct to store the status of the lock.
    struct LockStatus {
        /// @notice Array of lock details.
        LockDetails[] lockDetails;
        /// @notice If SDT is claimed, whether to lock it in veSDT or send it to the user.
        bool lockSDT;
        /// @notice If veSDT holder, whether to claim veSDT rewards.
        bool claimVeSDT;
    }

    /// @notice Maximum rewards that can be claimed from a gauge.
    /// @dev Old gauges haves 8 maximum rewards, new gauges have 11 maximum rewards because of
    /// Only Boost with 8 + SDT, CRV, CVX.
    uint256 private constant MAX_REWARDS = 11;

    /// @notice Address of the SDT token.
    address public immutable SDT;

    /// @notice Address of the veSDT token.
    address public immutable veSDT;

    /// @notice Address of the veSDT fee distributor.
    address public immutable veSDTFeeDistributor;

    /// @notice Address of the governance.
    address public governance;

    /// @notice Address of the future governance contract.
    address public futureGovernance;

    /// @notice Event emitted when the governance is changed.
    event GovernanceChanged(address newGovernance);

    error WRONG_LENGTH();
    error NOT_OWNER();
    error INITIALIZED();
    error GOVERNANCE();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert GOVERNANCE();
        _;
    }

    constructor(address _SDT, address _veSDT, address _veSDTFeeDistributor) {
        SDT = _SDT;
        veSDT = _veSDT;
        veSDTFeeDistributor = _veSDTFeeDistributor;
        governance = msg.sender;
    }

    function initialize(address _governance) public {
        if (governance != address(0)) revert GOVERNANCE();

        governance = _governance;

        if (SDT != address(0) && veSDT != address(0)) {
            SafeTransferLib.safeApprove(SDT, veSDT, type(uint256).max);
        }
    }

    /// @notice A function to claim rewards from all the gauges supplied
    /// @param _gauges Gauges from which rewards are to be claimed
    /// @param _claimVeSDT Claim veSDT rewards
    function claimRewards(address[] calldata _gauges, bool _claimVeSDT) external {
        uint256 gaugeLength = _gauges.length;
        for (uint256 index; index < gaugeLength; ++index) {
            ILiquidityGauge(_gauges[index]).claim_rewards_for(msg.sender, msg.sender);
        }
        if (_claimVeSDT) {
            IVeSDTFeeDistributor(veSDTFeeDistributor).claim(msg.sender);
        }
    }

    /// @notice A function to claim rewards from all the gauges supplied and lock them in the depositors
    /// @param _gauges Gauges from which rewards are to be claimed
    /// @param lockDetails Details of the lock
    /// @param _rewardCount Total number of rewards to claim
    /// @param startIndex Start index of the rewards to claim to skip unecessary rewards.
    function _claimAndLock(
        address[] calldata _gauges,
        LockDetails[] calldata lockDetails,
        uint256 _rewardCount,
        uint256 startIndex
    ) private {
        // List of the tokens claimed
        address[] memory tokens = new address[](_rewardCount);
        uint256 gaugeLength = _gauges.length;
        // Claim rewards token from gauges
        for (uint256 index; index < gaugeLength; ++index) {
            address gauge = _gauges[index];
            ILiquidityGauge(gauge).claim_rewards_for(msg.sender, address(this));
            // skip the first reward token, it is SDT for any LGV4
            // it loops at most until max rewards, it is hardcoded on LGV4
            for (uint256 i = startIndex; i < MAX_REWARDS; ++i) {
                address token = ILiquidityGauge(gauge).reward_tokens(i);
                if (token == address(0)) {
                    break;
                }
                // Add not already added tokens to the list
                if (ERC20(token).balanceOf(address(this)) != 0) {
                    for (uint256 j; j < _rewardCount; ++j) {
                        if (tokens[j] == token) break;
                        if (tokens[j] == address(0)) {
                            tokens[j] = token;
                            break;
                        }
                        if (j == _rewardCount - 1) revert WRONG_LENGTH();
                    }
                }
            }
        }

        for (uint256 i; i < lockDetails.length; ++i) {
            if (lockDetails[i].token == address(0)) break;

            address token = lockDetails[i].token;
            uint256 balance = ERC20(token).balanceOf(address(this));
            if (balance == 0) continue;

            IDepositor(lockDetails[i].depositor).deposit(balance, lockDetails[i].lock, lockDetails[i].stake, msg.sender);
        }

        for (uint256 i; i < _rewardCount; ++i) {
            address token = tokens[i];
            if (token == address(0)) break;
            uint256 balance = ERC20(token).balanceOf(address(this));

            if (balance == 0) continue;
            SafeTransferLib.safeTransfer(token, msg.sender, balance);
        }
    }

    /// @notice A function that allows the user to claim, lock and stake tokens retrieved from gauges
    /// @param _gauges Gauges from which rewards are to be claimed
    /// @param _lockStatus Status of locks for each reward token suppported by depositors and for SDT
    /// @param _rewardCount Total count of rewards for the claim, can be higher than real count but will unecessarly increase cas cost, reverts if lower
    function claimAndLock(address[] calldata _gauges, LockStatus calldata _lockStatus, uint256 _rewardCount) external {
        if (_lockStatus.lockSDT) {
            // Skip first token reward that is SDT on mainnet for relock
            _claimAndLock(_gauges, _lockStatus.lockDetails, _rewardCount, 1);

            // Lock SDT for veSDT or send to the user if any
            uint256 balanceBefore = ERC20(SDT).balanceOf(address(this));
            if (balanceBefore != 0) {
                if (IVeSDT(veSDT).balanceOf(msg.sender) > 0) {
                    IVeSDT(veSDT).deposit_for(msg.sender, balanceBefore);
                } else {
                    SafeTransferLib.safeTransfer(SDT, msg.sender, balanceBefore);
                }
            }
        } else {
            // Don't skip first token reward, manage it as any reward
            _claimAndLock(_gauges, _lockStatus.lockDetails, _rewardCount, 0);
        }

        // Claim veSDT rewards if added in the LockStatus
        if (_lockStatus.claimVeSDT) {
            IVeSDTFeeDistributor(veSDTFeeDistributor).claim(msg.sender);
        }
    }

    /// @notice A function to approve a depositor for a token
    /// @param token Token to approve
    /// @param spender Spender to approve
    function approveToken(address token, address spender) external onlyGovernance {
        SafeTransferLib.safeApproveWithRetry(token, spender, type(uint256).max);
    }

    /// @notice A function to revoke a depositor for a token
    /// @param token Token to revoke
    /// @param spender Spender to revoke
    function revokeToken(address token, address spender) external onlyGovernance {
        SafeTransferLib.safeApprove(token, spender, 0);
    }

    /// @notice Transfer the governance to a new address.
    /// @param _governance Address of the new governance.
    function transferGovernance(address _governance) external onlyGovernance {
        futureGovernance = _governance;
    }

    /// @notice Accept the governance transfer.
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert GOVERNANCE();

        governance = msg.sender;

        /// Reset the future governance.
        futureGovernance = address(0);

        emit GovernanceChanged(msg.sender);
    }

    /// UUPS Upgradeability.
    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}

    function getVersion() external pure returns (string memory) {
        return "1.0";
    }
}
