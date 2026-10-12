// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IRewardsDistributor.sol";
import "contracts/interfaces/IEmissionsToken.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";

/// @notice codifies the minting rules as per ve(3,3)

contract Minter is IMinter, Initializable {
    uint256 internal constant WEEK = 86400 * 7; /// @notice allows minting once per week (reset every Thursday 00:00 UTC)
    uint256 internal flation;
    uint256 internal constant PRECISION = 1000;
    uint256 internal growth; // 50%
    uint256 internal incentivesSize;
    uint256 public weekly;
    uint256 public activePeriod;
    uint256 public firstPeriod;

    address public timelock;
    address public msig;
    address public commandCenter;
    IEmissionsToken public emissionsToken; /// @notice this is the token emitted by the protocol weekly
    IVoter public voter;
    IVotingEscrow public ve;
    IRewardsDistributor public rewardsDistributor;

    event SetVeDist(address _value);
    event SetVoter(address _value);
    event Mint(address indexed sender, uint256 weekly, uint256 growth);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "!TL");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _voter, // the voting & distribution system
        address _ve, // the ve(3,3) system that will be locked into
        address _rewardsDistributor, // the distribution system that ensures users aren't diluted
        uint256 initialSupply, // preminted supply from epoch 0
        address _msig, // Multisig
        address _timelock, // Timelock contract
        address _commandCenter, // IncentivesController contract
        uint256 _incentivesSize // Growth variable of the weekly share from IncentivesController
    ) external initializer {
        emissionsToken = IEmissionsToken(IVotingEscrow(_ve).emissionsToken());
        voter = IVoter(_voter);
        ve = IVotingEscrow(_ve);
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        msig = _msig;
        timelock = _timelock;
        commandCenter = _commandCenter;
        emit SetVeDist(_rewardsDistributor);
        emit SetVoter(_voter);

        if (initialSupply > 0) {
            emissionsToken.mint(_msig, initialSupply);
        }

        weekly = 1_000 * 1e18; // represents a starting weekly emission of 1,000
        incentivesSize = _incentivesSize;
        flation = 990;
        growth = 250;

        activePeriod = type(uint256).max / 2;
    }

    function reinitializeCommandCenter(
        address _commandCenter
    ) external reinitializer(2) {
        commandCenter = _commandCenter;
    }

    /// @notice weekly emissions based on flation (mutable value via timelock)
    function weeklyEmission() public view returns (uint256) {
        return (weekly * flation) / PRECISION;
    }

    /// @notice calculate inflation and adjust ve balances accordingly
    /// @notice takes the minimum of rate (increases weekly) and the growth variable (max rebase)
    function calculateGrowth(uint256 _minted) public view returns (uint256) {
        uint256 rate = (activePeriod / WEEK - firstPeriod / WEEK + 25) * 10;
        return (MathUpgradeable.min(rate, growth) * _minted) / PRECISION;
    }

    /// @notice starts emissions for the first time (epoch 0)
    // can only be called once while firstPeriod is 0
    function initiateEpochZero() external {
        require(msg.sender == msig, "!MSIG");
        require(firstPeriod == 0, "STARTED");

        activePeriod = (block.timestamp / WEEK) * WEEK + WEEK;
        firstPeriod = activePeriod;
        emissionsToken.mint(msig, weekly);

        rewardsDistributor.checkpointToken();
        rewardsDistributor.checkpointTotalSupply();

        emit Mint(msg.sender, weekly, 0);
    }

    /// @notice update period can only be called once per epoch (1 week)
    function updatePeriod() external returns (uint256) {
        uint256 _period = activePeriod;
        /// @dev > instead of >= period timestamp, to ensure ve balance cannot change anymore
        if (block.timestamp > _period + WEEK) {
            /// @dev only trigger if it's a new week (epoch)
            _period = (block.timestamp / WEEK) * WEEK;
            activePeriod = _period;
            weekly = weeklyEmission();

            uint256 _growth = calculateGrowth(weekly);
            uint256 _required = _growth + weekly;
            uint256 _balanceOf = emissionsToken.balanceOf(address(this));
            if (_balanceOf < _required) {
                emissionsToken.mint(address(this), _required - _balanceOf); // Minted emissions
                emissionsToken.mint(commandCenter, incentivesSize); /// @dev Mint equivalent in growth to the incentivesController contract
            }

            require(
                emissionsToken.transfer(address(rewardsDistributor), _growth)
            );
            rewardsDistributor.checkpointToken(); // checkpoint token balance that was just minted in rewards distributor
            rewardsDistributor.checkpointTotalSupply(); // checkpoint supply

            emissionsToken.approve(address(voter), weekly);
            voter.notifyRewardAmount(weekly); // notify the weekly emissions to the voter for distribution

            emit Mint(msg.sender, weekly, _growth);
        }
        return _period;
    }

    /// @notice updates in/de flation for the following epoch
    function updateFlation(uint256 _flation) external {
        require(msg.sender == commandCenter, "!commandCenter");
        flation = _flation;
    }

    /// @notice update the rebase cap
    function updateGrowthCap(uint256 _newGrowthCap) external {
        require(msg.sender == commandCenter, "!commandCenter");
        growth = _newGrowthCap;
    }

    /// @notice update the incentivesController's weekly growth in nominal value
    function updateIncentivesSize(uint256 _incentivesSize) external {
        require(msg.sender == commandCenter, "!commandCenter");
        incentivesSize = _incentivesSize;
    }

    /// @notice change the incentivesController's address if a new deployment is necessary
    function updateCommandCenter(
        address _newCommandCenter
    ) external onlyTimelock {
        commandCenter = _newCommandCenter;
    }

    function updateTimelock(address _timelock) external onlyTimelock {
        timelock = _timelock;
    }
}
