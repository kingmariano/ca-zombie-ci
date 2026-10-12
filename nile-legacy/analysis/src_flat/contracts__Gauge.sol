// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IGauge.sol";

/// @notice Gauges are used to incentivize pools, they emit reward tokens over 7 days for staked LP tokens
contract Gauge is IGauge, Initializable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    address public stake; /// @notice the LP token that needs to be staked for rewards
    address public ve; /// @notice the ve token used for gauges
    address public feeDistributor;
    address public voter;
    EnumerableSetUpgradeable.AddressSet rewards;
    address[] public initialRewards; /// @notice emissionsToken and xToken as initial reward tokens

    uint256 public totalSupply;
    uint256 internal constant DURATION = 7 days; /// @notice rewards are released over 7 days
    uint256 internal constant PRECISION = 10 ** 18;
    uint256 internal _unlocked;

    bool isForPair;

    mapping(address => EnumerableSetUpgradeable.AddressSet) registeredRewards; /// @notice rewards user wants to receive
    mapping(address => uint256) public derivedSupplyPerReward;
    mapping(address => uint256) public tokenIds;
    mapping(address => uint256) public derivedBalances;
    mapping(address => uint256) public balanceOf;
    mapping(address => Reward) internal _rewardData;
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenStored;
    mapping(address => mapping(address => uint256)) public storedRewardsPerUser;

    event Deposit(address indexed from, uint256 tokenId, uint256 amount);
    event Withdraw(address indexed from, uint256 tokenId, uint256 amount);
    event NotifyReward(
        address indexed from,
        address indexed reward,
        uint256 amount
    );
    event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
    event ClaimRewards(
        address indexed from,
        address indexed reward,
        uint256 amount
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stake,
        address _feeDist,
        address _ve,
        address _voter,
        bool _forPair,
        address[] calldata _initialRewards
    ) external initializer {
        stake = _stake;
        feeDistributor = _feeDist;
        ve = _ve;
        voter = _voter;
        isForPair = _forPair;

        initialRewards = _initialRewards;
        for (uint256 i; i < _initialRewards.length; i++) {
            rewards.add(_initialRewards[i]);
        }

        _unlocked = 1;
    }

    /// @notice simple re-entrancy check
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    modifier updateReward(address account) {
        address[] memory _rewards = registeredRewards[account].values();
        uint256 len = _rewards.length;
        for (uint256 i; i < len; ) {
            address token = _rewards[i];
            _rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            _rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                storedRewardsPerUser[account][token] = _earned(token, account);
                userRewardPerTokenStored[account][token] = _rewardData[token]
                    .rewardPerTokenStored;
            }

            unchecked {
                i++;
            }
        }
        _;
    }

    function claimFees()
        external
        lock
        returns (uint256 claimed0, uint256 claimed1)
    {
        return _claimFees();
    }

    /// @notice claim fees from the V1 pair
    function _claimFees()
        internal
        returns (uint256 claimed0, uint256 claimed1)
    {
        if (!isForPair) {
            return (0, 0);
        }

        (claimed0, claimed1) = IPair(stake).claimFees();

        emit ClaimFees(msg.sender, claimed0, claimed1);
    }

    function rewardsList() external view returns (address[] memory _rewards) {
        _rewards = rewards.values();
    }

    function rewardsListLength() external view returns (uint256 _length) {
        _length = rewards.length();
    }

    /// @notice returns rewards a user has registered to receive
    function getRegisteredRewards(
        address user
    ) external view returns (address[] memory _rewards) {
        _rewards = registeredRewards[user].values();
    }

    /// @notice returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(
        address token
    ) public view returns (uint256) {
        return
            MathUpgradeable.min(
                block.timestamp,
                _rewardData[token].periodFinish
            );
    }

    function rewardData(
        address token
    ) external view override returns (Reward memory data) {
        data = _rewardData[token];
    }

    /**
     * @dev earned was split in two so we don't need to do an extra SLOAD to check if user is registered
     * @dev other functions that call the internal _earned() already checks registeredRewards beforehand
     */
    function earned(
        address token,
        address account
    ) external view returns (uint256 _reward) {
        if (registeredRewards[account].contains(token)) {
            _reward = _earned(token, account);
        } else {
            _reward = storedRewardsPerUser[account][token];
        }
    }

    function _earned(
        address token,
        address account
    ) internal view returns (uint256 _reward) {
        _reward =
            ((derivedBalances[account] *
                (rewardPerToken(token) -
                    userRewardPerTokenStored[account][token])) / PRECISION) +
            storedRewardsPerUser[account][token];
    }

    function getReward(
        address account,
        address[] calldata tokens
    ) public updateReward(account) lock {
        require(msg.sender == account || msg.sender == voter);
        _unlocked = 1;
        /// @notice call distribute in case the emissions have not been sent from the voter yet
        IVoter(voter).distribute(address(this));
        _unlocked = 2;

        for (uint256 i; i < tokens.length; ) {
            uint256 _reward = storedRewardsPerUser[account][tokens[i]];
            if (_reward > 0) {
                storedRewardsPerUser[account][tokens[i]] = 0;
                _safeTransfer(tokens[i], account, _reward);
                emit ClaimRewards(account, tokens[i], _reward);
            }
            unchecked {
                i++;
            }
        }

        address[] memory _rewards = registeredRewards[account].values();
        uint256 len = _rewards.length;

        uint256 _derivedBalanceBefore = derivedBalances[account];
        uint256 _derivedBalanceAfter = derivedBalance(account);
        derivedBalances[account] = _derivedBalanceAfter;

        for (uint256 i; i < len; ) {
            derivedSupplyPerReward[_rewards[i]] -= _derivedBalanceBefore;
            derivedSupplyPerReward[_rewards[i]] += _derivedBalanceAfter;

            unchecked {
                i++;
            }
        }
    }

    function rewardPerToken(address token) public view returns (uint256) {
        if (derivedSupplyPerReward[token] == 0) {
            return _rewardData[token].rewardPerTokenStored;
        }
        return
            _rewardData[token].rewardPerTokenStored +
            ((lastTimeRewardApplicable(token) -
                _rewardData[token].lastUpdateTime) *
                _rewardData[token].rewardRate *
                PRECISION) /
            derivedSupplyPerReward[token];
    }

    /// @notice return current balance of an account
    function derivedBalance(address account) public view returns (uint256) {
        return balanceOf[account];
    }

    function depositAll(uint256 tokenId) external {
        deposit(IERC20(stake).balanceOf(msg.sender), tokenId, initialRewards);
    }

    /**
     * @notice deposit without manually specifying requestedRewards
     */
    function deposit(uint256 amount, uint256 tokenId) external {
        deposit(amount, tokenId, initialRewards);
    }

    /**
     * @notice stake tokens
     * @param requestedRewards array of reward tokens user wants to receive
     */
    function deposit(
        uint256 amount,
        uint256 tokenId,
        address[] memory requestedRewards
    ) public updateReward(msg.sender) lock {
        require(amount > 0);

        _safeTransferFrom(stake, msg.sender, address(this), amount);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        if (tokenId > 0) {
            require(IVotingEscrow(ve).ownerOf(tokenId) == msg.sender, "!owner");
            if (tokenIds[msg.sender] == 0) {
                tokenIds[msg.sender] = tokenId;
                IVoter(voter).attachTokenToGauge(tokenId, msg.sender);
            }
            require(tokenIds[msg.sender] == tokenId);
        } else {
            tokenId = tokenIds[msg.sender];
        }

        uint256 _derivedBalanceBefore = derivedBalances[msg.sender];
        uint256 _derivedBalanceAfter = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalanceAfter;

        /// @dev update all derivedSupplyPerReward for user
        address[] memory _stakes = registeredRewards[msg.sender].values();
        uint256 len = _stakes.length;
        for (uint256 i; i < len; ) {
            derivedSupplyPerReward[_stakes[i]] -= _derivedBalanceBefore;
            derivedSupplyPerReward[_stakes[i]] += _derivedBalanceAfter;

            unchecked {
                i++;
            }
        }

        for (uint256 i; i < requestedRewards.length; ) {
            bool newlyJoined = registeredRewards[msg.sender].add(
                requestedRewards[i]
            );

            /// @dev only update if the user has not joined the pool yet
            if (newlyJoined) {
                _rewardData[requestedRewards[i]]
                    .rewardPerTokenStored = rewardPerToken(requestedRewards[i]);
                _rewardData[requestedRewards[i]]
                    .lastUpdateTime = lastTimeRewardApplicable(
                    requestedRewards[i]
                );

                userRewardPerTokenStored[msg.sender][
                    requestedRewards[i]
                ] = _rewardData[requestedRewards[i]].rewardPerTokenStored;

                derivedSupplyPerReward[
                    requestedRewards[i]
                ] += _derivedBalanceAfter;
            }

            unchecked {
                i++;
            }
        }

        IVoter(voter).emitDeposit(tokenId, msg.sender, amount);
        emit Deposit(msg.sender, tokenId, amount);
    }

    /// @notice withdraws all fungible LP tokens from V1 gauges
    function withdrawAll() external {
        withdraw(balanceOf[msg.sender]);
    }

    function withdraw(uint256 amount) public {
        uint256 tokenId;
        if (amount == balanceOf[msg.sender]) {
            tokenId = tokenIds[msg.sender];
        }
        withdrawToken(amount, tokenId);
    }

    function withdrawToken(
        uint256 amount,
        uint256 tokenId
    ) internal updateReward(msg.sender) lock {
        require(amount > 0, "Can't withdraw 0!");

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        _safeTransfer(stake, msg.sender, amount);

        if (tokenId > 0) {
            require(tokenId == tokenIds[msg.sender]);
            tokenIds[msg.sender] = 0;
            IVoter(voter).detachTokenFromGauge(tokenId, msg.sender);
        } else {
            tokenId = tokenIds[msg.sender];
        }

        address[] memory _rewards = registeredRewards[msg.sender].values();
        uint256 len = _rewards.length;
        uint256 _derivedBalanceBefore = derivedBalances[msg.sender];
        uint256 _derivedBalanceAfter = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalanceAfter;
        for (uint256 i; i < len; ) {
            derivedSupplyPerReward[_rewards[i]] -= _derivedBalanceBefore;
            derivedSupplyPerReward[_rewards[i]] += _derivedBalanceAfter;

            unchecked {
                i++;
            }
        }

        IVoter(voter).emitWithdraw(tokenId, msg.sender, amount);
        emit Withdraw(msg.sender, tokenId, amount);
    }

    /**
     * @notice join to receive newly notified rewards
     * @notice users will not receive new rewards that they haven't already opted into
     */
    function joinRewardPool(address token) external updateReward(msg.sender) {
        address[] memory _rewards = registeredRewards[msg.sender].values();
        uint256 len = _rewards.length;

        uint256 _derivedBalanceBefore = derivedBalances[msg.sender];
        uint256 _derivedBalanceAfter = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalanceAfter;

        for (uint256 i; i < len; ) {
            // update user's derivedSupplyPerReward
            derivedSupplyPerReward[_rewards[i]] -= _derivedBalanceBefore;
            derivedSupplyPerReward[_rewards[i]] += _derivedBalanceAfter;

            unchecked {
                i++;
            }
        }

        bool newlyJoined = registeredRewards[msg.sender].add(token); // if it already exists it won't get added

        if (newlyJoined) {
            _rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            _rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);

            userRewardPerTokenStored[msg.sender][token] = _rewardData[token]
                .rewardPerTokenStored;

            derivedSupplyPerReward[token] += _derivedBalanceAfter;
        }
    }

    /// @notice exit reward pool to stop receiving a given reward
    function exitRewardPool(address token) external updateReward(msg.sender) {
        address[] memory _rewards = registeredRewards[msg.sender].values();
        uint256 len = _rewards.length;
        uint256 _derivedBalanceBefore = derivedBalances[msg.sender];
        uint256 _derivedBalanceAfter = derivedBalance(msg.sender);
        derivedBalances[msg.sender] = _derivedBalanceAfter;
        for (uint256 i; i < len; ) {
            derivedSupplyPerReward[_rewards[i]] -= _derivedBalanceBefore;
            derivedSupplyPerReward[_rewards[i]] += _derivedBalanceAfter;

            unchecked {
                i++;
            }
        }

        bool newlyRemoved = registeredRewards[msg.sender].remove(token);

        if (newlyRemoved) {
            derivedSupplyPerReward[token] -= _derivedBalanceAfter;
        }
    }

    function left(address token) public view returns (uint256) {
        if (block.timestamp >= _rewardData[token].periodFinish) return 0;
        uint256 _remaining = _rewardData[token].periodFinish - block.timestamp;
        return _remaining * _rewardData[token].rewardRate;
    }

    /**
     * @notice amount must be greater than left() for the token, this is to prevent greifing attacks
     * @notice notifying rewards is completely permissionless
     * @notice if nobody registers for a newly added reward for the period it will remain in the contract indefinitely
     */
    function notifyRewardAmount(
        address token,
        uint256 amount
    ) external updateReward(address(0)) lock {
        require(token != stake);
        require(amount > 0);
        _claimFees();

        _rewardData[token].rewardPerTokenStored = rewardPerToken(token);

        rewards.add(token);
        // Check actual amount transferred for compatibility with fee on transfer tokens.
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        amount = balanceAfter - balanceBefore;

        if (block.timestamp >= _rewardData[token].periodFinish) {
            _rewardData[token].rewardRate = amount / DURATION;
        } else {
            uint256 remaining = _rewardData[token].periodFinish -
                block.timestamp;
            uint256 _left = remaining * _rewardData[token].rewardRate;
            require(amount > _left);
            _rewardData[token].rewardRate = (amount + _left) / DURATION;
        }

        _rewardData[token].lastUpdateTime = block.timestamp;
        _rewardData[token].periodFinish = block.timestamp + DURATION;

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(
            _rewardData[token].rewardRate <= balance / DURATION,
            "Provided reward too high"
        );

        emit NotifyReward(msg.sender, token, amount);
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

    function addInitialReward(address reward) external {
        require(msg.sender == voter);
        initialRewards.push(reward);
    }
}
