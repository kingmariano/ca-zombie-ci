// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";

contract FeeDistributor is IFeeDistributor, Initializable {
    address public voter; // only voter can modify balances (since it only happens on vote())
    address public _ve;
    address public pairFees;

    uint256 internal _unlocked;
    uint256 public constant WEEK = 1 weeks;
    uint256 public firstPeriod;

    /// @notice token id => amount
    mapping(uint256 => uint256) public balanceOf;

    /// @notice total amount of votes per epoch
    mapping(uint256 => uint256) public votes; // epoch => amount

    /// @notice period => token id => amount
    mapping(uint256 => mapping(uint256 => uint256)) public userVotes;

    /// @notice period => token => total supply
    mapping(uint256 => mapping(address => uint256)) public rewardSupply;

    /// @notice period => token id => token => amount
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public userClaimed;

    /// @notice token => token id => period
    mapping(address => mapping(uint256 => uint256)) public lastClaimByToken;

    address[] public rewards;
    mapping(address => bool) public isReward;

    event Deposit(address indexed from, uint256 tokenId, uint256 amount);
    event Withdraw(address indexed from, uint256 tokenId, uint256 amount);
    event NotifyReward(
        address indexed from,
        address indexed reward,
        uint256 amount,
        uint256 period
    );
    event VotesIncentivized(
        address indexed from,
        address indexed reward,
        uint256 amount,
        uint256 period
    );
    event ClaimRewards(
        uint256 period,
        uint256 tokenId,
        address receiver,
        address reward,
        uint256 amount
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _voter,
        address _pairFees
    ) external initializer {
        _unlocked = 1;

        voter = _voter;
        _ve = IVoter(_voter)._ve();

        firstPeriod = getPeriod();
        pairFees = _pairFees;
    }

    function setPairFees() external reinitializer(2) {
        require(
            address(this) == 0x60DD85d0795316b07af5319859F4e7A876e209Bb ||
                address(this) == 0x692716fCA7DCB50b017601eB36cF642Fc08c17d9 ||
                address(this) == 0x741627fD7B0a2Bb3D28a6761078B953bd50a4fEb ||
                address(this) == 0x5B24fdd2bfD5830C527bFFBf63B16D7ED9cD2521
        );

        pairFees = 0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f;
    }

    /// @notice simple re-entrancy check
    modifier lock() {
        require(_unlocked == 1, "LOK");
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    function getRewardTokens() external view returns (address[] memory) {
        return rewards;
    }

    function _getReward(
        uint256 period,
        uint256 tokenId,
        address token,
        address receiver
    ) internal {
        require(period <= getPeriod(), "!FP");
        if (votes[period] != 0) {
            uint256 _reward = (rewardSupply[period][token] *
                userVotes[period][tokenId]) / votes[period];

            _reward -= userClaimed[period][tokenId][token];
            userClaimed[period][tokenId][token] += _reward;

            if (_reward > 0) {
                _safeTransfer(token, receiver, _reward);
                emit ClaimRewards(period, tokenId, receiver, token, _reward);
            }
        }
    }

    function _getAllRewards(
        uint256 tokenId,
        address[] memory tokens,
        address receiver
    ) internal {
        uint256 currentPeriod = getPeriod();
        uint256 lastClaim;
        for (uint256 i = 0; i < tokens.length; ++i) {
            lastClaim = MathUpgradeable.max(
                lastClaimByToken[tokens[i]][tokenId],
                firstPeriod
            );
            for (
                uint256 period = lastClaim;
                period <= currentPeriod;
                period += WEEK
            ) {
                _getReward(period, tokenId, tokens[i], receiver);
            }
            lastClaimByToken[tokens[i]][tokenId] = currentPeriod - WEEK;
        }
    }

    function getPeriodReward(
        uint256 period,
        uint256 tokenId,
        address token
    ) external lock {
        require(IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, tokenId));
        _getReward(period, tokenId, token, msg.sender);
    }

    function getReward(uint256 tokenId, address[] memory tokens) external lock {
        require(IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, tokenId));
        _getAllRewards(tokenId, tokens, msg.sender);
    }

    /// @dev used by Voter to allow batched reward claims
    function getRewardForOwner(
        uint256 tokenId,
        address[] memory tokens
    ) external lock {
        require(msg.sender == voter);
        address owner = IVotingEscrow(_ve).ownerOf(tokenId);
        _getAllRewards(tokenId, tokens, owner);
    }

    function earned(
        address token,
        uint256 tokenId
    ) external view returns (uint256 reward) {
        uint256 currentPeriod = getPeriod();
        uint256 lastClaim = MathUpgradeable.max(
            lastClaimByToken[token][tokenId],
            firstPeriod
        );
        for (
            uint256 period = lastClaim;
            period <= currentPeriod;
            period += WEEK
        ) {
            if (votes[period] != 0) {
                reward +=
                    (rewardSupply[period][token] * userVotes[period][tokenId]) /
                    votes[period];

                reward -= userClaimed[period][tokenId][token];
            }
        }
    }

    function getPeriod() public view returns (uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }

    /// @dev This is an external function, but internal notation is used since it can only be called "internally" from Voter
    function _deposit(uint256 amount, uint256 tokenId) external {
        require(msg.sender == voter);

        uint256 period = getPeriod() + WEEK;

        balanceOf[tokenId] += amount;
        votes[period] += amount;
        userVotes[period][tokenId] += amount;

        emit Deposit(msg.sender, tokenId, amount);
    }

    function _withdraw(uint256 amount, uint256 tokenId) external {
        require(msg.sender == voter);

        uint256 period = getPeriod() + WEEK;

        balanceOf[tokenId] -= amount;
        if (userVotes[period][tokenId] > 0) {
            userVotes[period][tokenId] -= amount;
            votes[period] -= amount;
        }

        emit Withdraw(msg.sender, tokenId, amount);
    }

    function notifyRewardAmount(address token, uint256 amount) external lock {
        require(msg.sender == pairFees, "!FEES");
        uint256 period = getPeriod();

        /// @notice there are no votes for the first period; distribute first period fees as vote incentives to second period voters
        if (votes[period] == 0) {
            period += WEEK;
        }

        if (!isReward[token]) {
            isReward[token] = true;
            rewards.push(token);
        }

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        amount = balanceAfter - balanceBefore;
        rewardSupply[period][token] += amount;
        emit NotifyReward(msg.sender, token, amount, period);
    }

    /// @dev record incentives amount for next period
    function incentivize(address token, uint256 amount) external lock {
        uint256 period = getPeriod() + WEEK;

        if (!isReward[token]) {
            isReward[token] = true;
            rewards.push(token);
        }

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        amount = balanceAfter - balanceBefore;
        rewardSupply[period][token] += amount;
        emit VotesIncentivized(msg.sender, token, amount, period);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            )
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
