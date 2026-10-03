// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.11;

import { UUPSUpgradeable, AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20Upgradeable, IERC20Upgradeable as IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IClayMain } from "./interfaces/IClayMain.sol";
import { ICSToken } from "./interfaces/ICSToken.sol";
import { IRoleManager } from "./interfaces/IRoleManager.sol";
import { IMaticValidator as Validator } from "./matic/IMaticValidator.sol";
import { IMaticStakeManager as StakeManager } from "./matic/IMaticStakeManager.sol";

/*
Implementation based on requirements for validator
https://github.com/maticnetwork/contracts/blob/9564ece3a0647b0da18a1a2a51baffb5f661893f/contracts/staking/validatorShare/ValidatorShare.sol#L63
*/

/**
 * @title ClayMatic
 * @author ClayStack
 * @dev ClayStack protocol uses a main contract for users to transfer supported ERC20 tokens, and in return get a secondary ERC20 token "csToken". The contract will in turn stake/unstake into validating nodes. The csToken will appreciate in value vs the underlying token as rewards from the validators are recognized.
 */
contract ClayMatic is UUPSUpgradeable, IClayMain, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20;

    //==========// Events //==========//
    /**
     * @notice Event for new deposit.
     *
     * @param user : Address of depositor.
     * @param amount : Amount of Token deposited.
     * @param amountCs : Amount of csToken minted.
     * @param fee : Fee paid by user on deposit in Token
     */
    event LogDeposit(address indexed user, uint256 amount, uint256 amountCs, uint256 fee);

    /**
     * @notice Event for new withdraw request.
     *
     * @param user : Address of user withdrawing.
     * @param orderId : Withdraw order id.
     * @param amountCs : Amount of csToken burned.
     * @param amount : Amount of Token withdrawn.
     * @param fee : Fee percentage to be paid by the user
     * @param epoch : Epoch at the moment of request
     */
    event LogWithdraw(
        address indexed user,
        uint256 orderId,
        uint256 amountCs,
        uint256 amount,
        uint256 fee,
        uint256 epoch
    );

    /**
     * @notice Event for instant withdraw.
     *
     * @param user : Address of the user
     * @param amountCs : Amount of csToken burned.
     * @param amount : Amount of Token withdrawn.
     * @param fee : Fee paid by user on instant withdraw in Token
     */
    event LogInstantWithdraw(address indexed user, uint256 amountCs, uint256 amount, uint256 fee);

    /**
     * @notice Event for withdraw claims by user.
     *
     * @param user : Address of user.
     * @param orderId : Withdraw order id.
     * @param amount : Amount of Token unstaked in order.
     * @param received : Amount of Token received in order.
     * @param fee : Fee paid by user.
     */
    event LogClaim(address indexed user, uint256 orderId, uint256 amount, uint256 received, uint256 fee);

    /**
     * @notice Event for stake.
     *
     * @param nodeId : Node id to which tokens are staked.
     * @param amount : Amount of Token staked.
     * @param staked : Nodes current staked amount.
     */
    event LogStake(uint256 nodeId, uint256 amount, uint256 staked);

    /**
     * @notice Event for unstake.
     *
     * @param nodeId : Node id from which tokens are unstaked.
     * @param amount : Amount of Token unstaked.
     * @param staked : Nodes current staked amount.
     */
    event LogUnstake(uint256 nodeId, uint256 amount, uint256 staked);

    /**
     * @notice Event for unstake claim.
     *
     * @param nodeId : Nodes id from which tokens are claimed.
     * @param amount : Amount of Token claimed.
     */
    event LogUnstakeClaim(uint256 nodeId, uint256 amount);

    /**
     * @notice Event for rewards recognized.
     *
     * @param rewards : Amount of rewards recognized.
     * @param fee : ClayStack fee amount on rewards.
     */
    event LogRewards(uint256 rewards, uint256 fee);

    /**
     * @notice Event for transfer of ClayStack's fee.
     *
     * @param vault : Address of Vault manager.
     * @param fee : Amount transfer to vault.
     */
    event LogTransferVault(address vault, uint256 fee);

    /**
     * @notice Event for Slashing
     *
     * @param nodeId : Slashed nodes id.
     * @param slashing : Slashed amount.
     */
    event LogSlashing(uint256 nodeId, uint256 slashing);

    /**
     * @notice Event for donation.
     * i.e. Token sent to contract directly without minting csToken
     * @param amount : Amount of Token donated.
     */
    event LogDonation(uint256 amount);

    /**
     * @notice Event for migration of delegation from one node to another.
     *
     * @param from : Address of node from which delegation is migrated.
     * @param to : Address of node to which delegation is migrated.
     * @param amount : Amount of Token migrated.
     */
    event LogDelegationMigration(address indexed from, address indexed to, uint256 amount);

    /// @notice ClayStack's default list of access-control roles.
    bytes32 private constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 private constant TIMELOCK_UPGRADES_ROLE = keccak256("TIMELOCK_UPGRADES_ROLE");
    bytes32 private constant CS_SERVICE_ROLE = keccak256("CS_SERVICE_ROLE");

    uint256 internal constant MAX_DECIMALS = 1e18;
    uint256 private constant PERCENTAGE_BASE = 10000;

    /**
     * @notice Fee struct
     *
     * @param depositFee : Fee percent on deposit.
     * @param withdrawFee : Fee percent on withdraw.
     * @param instantWithdrawFee : Fee percentage on instant withdraw.
     * @param rewardFee : Fee percent on accrued rewards.
     */
    struct Fees {
        uint256 depositFee;
        uint256 withdrawFee;
        uint256 instantWithdrawFee;
        uint256 rewardFee;
    }

    /**
     * @notice WithdrawOrder struct
     *
     * @param amount : Total amount unstaked from validators.
     * @param fee :  Fee percentage to be paid by the user
     * @param orderIds : List of order ids from the validators
     * @param nodeIds : List of corresponding nodeIds
     */
    struct WithdrawOrder {
        uint128 amount;
        uint128 fee;
        uint256[] orderIds;
        uint256[] nodeIds;
    }

    /**
     * @notice StakingNode struct
     *
     * @param id : Validator node Id.
     * @param validatorAddress : Validator address.
     * @param points : Points allocated to validator.
     * @param staked : Total amount of stake on validator
     */
    struct StakingNode {
        uint256 id;
        address validatorAddress;
        uint256 points;
        uint256 staked;
    }

    /**
     * @notice Funds struct
     *
     * @param currentDeposit : Total funds deposited by users
     * @param stakedDeposit : Total tokens currently on nodes
     * @param accruedFees : Total fees accrued by ClayStack
     */
    struct Funds {
        uint256 currentDeposit;
        uint256 stakedDeposit;
        uint256 accruedFees;
    }

    // @notice Token instance.
    IERC20 public underlyingToken;

    /// @notice csToken instance.
    ICSToken public csToken;

    /// @notice RoleManager instance.
    IRoleManager private roleManager;

    /// @notice Stake Manager instance.
    StakeManager private stakeManager;

    /// @notice Stores all funds info.
    Funds public funds;

    /// @notice Stores all fee info.
    Fees public fees;

    /// @notice Array of all active node ids.
    uint256[] public activeNodes;

    // @notice Mapping of all staking nodes info.
    mapping(uint256 => StakingNode) public stakingNodes;

    /// @notice Mapping of all unstaking withdraw order by users.
    mapping(address => mapping(uint256 => WithdrawOrder)) public withdrawOrders;

    /// @notice Address of ClayStack's vault manager.
    address private vaultManager;

    /// @notice Flag to enable/disable slashing handling in the contract.
    bool public slashingEnabled;

    /// @notice Id of last node for staking
    uint256 public activeStakingNode;

    /// @notice Id of last node for unstaking
    uint256 public activeUnstakingNode;

    /// @notice Max allowed exchange rate change limit
    uint256 public changeLimitExchangeRate;

    /// @notice Last recorded Token balance of the contract.
    uint256 public contractBalance;

    /// @notice Counter for Staking nodes
    uint256 public countStakingNodes;

    /// @notice Default liquidity percentage.
    uint256 public defaultLiquidity;

    /// @notice Max allowed deposit limit.
    uint256 public depositLimit;

    /// @notice Current Token to csToken exchange rate.
    uint256 public exchangeRate;

    /// @notice Max number nodes allowed to unstake per withdraw request.
    uint256 public maxNodesToWithdraw;

    /// @notice Max allowed unstake percentage per node.
    uint256 public maxWithdrawNodePercentage;

    /// @notice Linear incremental order nonce. Increases by one after each withdraw request.
    uint256 public orderNonce;

    /// @notice Max allowed threshold for over-stake per node.
    uint256 public overStakingThreshold;

    /// @notice Sum of points allocated to each node.
    uint256 public totalPoints;

    /// @notice Default limit values for fees
    uint256 private constant MAX_DEPOSIT_FEE = 500;
    uint256 private constant MAX_WITHDRAW_FEE = 500;
    uint256 private constant MAX_INSTANT_WITHDRAW_FEE = 2000;
    uint256 private constant MAX_REWARD_FEE = 2000;

    /// @notice Limit of max overstake on staking transaction
    uint256 private constant MAX_OVER_STAKING_THRESHOLD = 2000;

    //==========// Modifiers //==========//
    /**
     * @notice Check if the msg.sender has permission.
     * @param roleName_ : bytes32 hash of the role.
     */
    modifier onlyRole(bytes32 roleName_) {
        _onlyRole(roleName_);
        _;
    }

    /**
     * @notice enforces balance check and update.
     */
    modifier enforceAndUpdateBalance() {
        _updateBalance();
        _;
        _balanced();
    }

    //==========// Initializer //==========//

    /**
     * @dev Initializes the contract's state vars.
     *
     * Requirements:
     * - `_csToken`, `_underlyingToken`, `_vaultManager`, `_roleManager` and `_stakeManager`
     * cannot be the zero address.
     *
     * @param csToken_ : Address of ClayStack's erc20 complaint synthetic token.
     * @param underlyingToken_ : Address of Token.
     * @param vaultManager_ : Address of ClayStack's vault manager.
     * @param roleManager_ : Address of ClayStack's role manager contract.
     * @param stakeManager_ : Address of Stake Manager contract
     * @param instantWithdrawFee_ : Fee percent for instant withdraw.
     * @param withdrawFee_ : Fee percent for withdraw of tokens.
     * @param depositFee_ : Fee percent for deposit of tokens.
     * @param rewardFee_ : Fee percent on rewards.
     */
    function initialize(
        address csToken_,
        address underlyingToken_,
        address vaultManager_,
        address roleManager_,
        address stakeManager_,
        uint256 instantWithdrawFee_,
        uint256 withdrawFee_,
        uint256 depositFee_,
        uint256 rewardFee_
    ) external initializer onlyProxy {
        require(csToken_ != address(0), "CO01");
        require(underlyingToken_ != address(0), "CO02");
        require(vaultManager_ != address(0), "CO03");
        require(roleManager_ != address(0), "CO04");
        require(stakeManager_ != address(0), "CO05");
        require(instantWithdrawFee_ < PERCENTAGE_BASE, "CO06");
        require(withdrawFee_ < PERCENTAGE_BASE, "CO06");
        require(depositFee_ < PERCENTAGE_BASE, "CO06");
        require(rewardFee_ < PERCENTAGE_BASE, "CO06");

        __Pausable_init();
        __ReentrancyGuard_init();

        roleManager = IRoleManager(roleManager_);
        stakeManager = StakeManager(stakeManager_);
        csToken = ICSToken(csToken_);
        underlyingToken = IERC20(underlyingToken_);
        vaultManager = vaultManager_;

        // Default settings
        fees.instantWithdrawFee = instantWithdrawFee_;
        fees.withdrawFee = withdrawFee_;
        fees.depositFee = depositFee_;
        fees.rewardFee = rewardFee_;
        defaultLiquidity = 1000;
        changeLimitExchangeRate = 500;
        maxWithdrawNodePercentage = 5000;
        maxNodesToWithdraw = 5;
        overStakingThreshold = 500;
    }

    /** USER OPERATIONS **/

    /**
     * @dev Sends Token to contract and mints csToken to msg.sender.
     *
     * Requirements:
     * - `msg.sender must have approved `amountToken` of Token to this contract.
     *
     * @param amountToken - Amount of Token sent from msg.sender to this contract
     * @return Bool confirmation of transaction
     */
    function deposit(uint256 amountToken) external override whenNotPaused nonReentrant returns (bool) {
        return _deposit(amountToken, msg.sender);
    }

    /**
     * @dev Sends Token to contract contract and mints csToken to `_delegatedTo`.
     *
     * Requirements:
     * - `msg.sender must have approved `_amountToken` of Token to this contract.
     *
     * @param amountToken : Amount of Token sent from msg.sender to this contract.
     * @param delegator : Address of entity receiving csToken.
     * @return Bool confirmation of transaction.
     */
    function depositDelegate(uint256 amountToken, address delegator)
        external
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        require(delegator != address(0x0), "CD04");
        return _deposit(amountToken, delegator);
    }

    /**
     * @dev Main function that facilitates deposit to the contract.
     * Emits an {LogDeposit} event.
     *
     * Requirements:
     * - `_depositAmount` cannot be zero.
     * - if `depositLimit` is active then deposit amount cannot exceed it.
     *
     * @param depositAmount : Amount of Token sent from msg.sender to this contract
     * @param delegator : Address of entity receiving csToken.
     * @return Bool confirmation of transaction
     */
    function _deposit(uint256 depositAmount, address delegator) internal enforceAndUpdateBalance returns (bool) {
        require(depositAmount != 0, "CD01");

        if (depositLimit != 0) {
            require((funds.currentDeposit + depositAmount) <= depositLimit, "CD02");
        }

        // Update state
        uint256 payableFee = _getPercentValue(fees.depositFee, depositAmount);
        uint256 amountToken = depositAmount - payableFee;
        uint256 amountToMint = _exchangeToken(amountToken, funds.currentDeposit);
        funds.currentDeposit += amountToken;
        funds.accruedFees += payableFee;

        // Transfer token to contract
        underlyingToken.safeTransferFrom(msg.sender, address(this), depositAmount);
        require(csToken.mint(delegator, amountToMint), "CD03");
        emit LogDeposit(delegator, amountToken, amountToMint, payableFee);
        return true;
    }

    /**
     * @dev Burns csToken from user and unstake respective amounts of Token from nodes.
     * Unstake information is stored in `withdrawOrders` and mapped to user address.
     * Amount of Token is calculated dynamically, according to current exchange rate.
     * It `_sequentiallyUnStake` the amounts of Token from the validator nodes.
     * Emits an {LogWithdraw} event.
     *
     * Requirements:
     * - `amountCs` cannot be zero.
     * - Amount of Token to be withdrawn cannot be more than `_getMaxWithdrawAmount()`.
     *
     * @param amountCs : Amount of csToken to be withdrawn.
     * @return Returns withdraw id.
     */
    function withdraw(uint256 amountCs)
        external
        override
        whenNotPaused
        nonReentrant
        enforceAndUpdateBalance
        returns (uint256)
    {
        require(amountCs != 0, "CW01");
        require(csToken.balanceOf(msg.sender) >= amountCs, "CW02");
        if (slashingEnabled) _updatedStaked(false);

        // Calculate and sanity check amount of token to withdraw is held by Clay at any stage
        uint256 amountTokenWithdraw = _exchangeCsToken(amountCs, funds.currentDeposit);
        require(amountTokenWithdraw != 0 && _getMaxWithdrawAmount() >= amountTokenWithdraw, "CW03");

        // Update funds
        funds.currentDeposit -= amountTokenWithdraw;

        // Burn csToken
        require(csToken.burn(msg.sender, amountCs), "CW04");

        // Sequentially Unstake
        (uint256[] memory orderIds, uint256[] memory nodeIds) = _sequentiallyUnStake(amountTokenWithdraw);

        uint256 id = ++orderNonce;
        withdrawOrders[msg.sender][id] = WithdrawOrder({
            amount: uint128(amountTokenWithdraw),
            fee: uint128(fees.withdrawFee),
            orderIds: orderIds,
            nodeIds: nodeIds
        });

        emit LogWithdraw(
            msg.sender,
            id,
            amountCs,
            amountTokenWithdraw,
            uint128(fees.withdrawFee),
            stakeManager.epoch()
        );
        return id;
    }

    /**
     * @dev Allows the user to claim several orders at once. It will check the validity of the order
     * and claims from the corresponding validators nodes.
     * Multiple unstake claims (to nodes) are attached to a single order
     * and share a common withdrawal request epoch.
     * Thus the full transaction will fail if the first claim reverts at Validator on
     * unstakeClaimTokens_new with "Incomplete withdrawal period".
     * Emits {LogClaim, LogUnstakeClaim} events.
     *
     * Requirements:
     * All orderIds must have fulfilled the unbonding period for the full transaction to succeed.
     *
     * @param orderIds - array of number of ids issued at withdraw()
     * @return Bool confirmation of transaction
     */
    function claim(uint256[] calldata orderIds)
        external
        override
        whenNotPaused
        nonReentrant
        enforceAndUpdateBalance
        returns (bool)
    {
        uint256 ordersAmount = 0;
        uint256 userAmount = 0;
        uint256 payableFee = 0;
        mapping(uint256 => WithdrawOrder) storage userOrders = withdrawOrders[msg.sender];
        for (uint256 i = 0; i < orderIds.length; i++) {
            WithdrawOrder storage order = userOrders[orderIds[i]];
            require(order.amount != 0, "CC01");

            // Claim from validator
            uint256 receivedAmount = 0;
            for (uint256 j = 0; j < order.nodeIds.length; j++) {
                StakingNode storage node = stakingNodes[order.nodeIds[j]];
                uint256 balanceBefore = underlyingToken.balanceOf(address(this));
                Validator validator = Validator(node.validatorAddress);
                validator.unstakeClaimTokens_new(order.orderIds[j]);
                uint256 claimAmount = underlyingToken.balanceOf(address(this)) - balanceBefore;
                receivedAmount += claimAmount;
                emit LogUnstakeClaim(node.id, claimAmount);
            }

            // Calculate and check amount is available in the contract
            uint256 orderFee = _getPercentValue(uint256(order.fee), receivedAmount);
            ordersAmount += order.amount;
            userAmount += receivedAmount - orderFee;
            payableFee += orderFee;
            emit LogClaim(msg.sender, orderIds[i], order.amount, receivedAmount, orderFee);
            delete userOrders[orderIds[i]];
        }

        if (ordersAmount != 0) {
            funds.accruedFees += payableFee;
            if (userAmount != 0) underlyingToken.safeTransfer(msg.sender, userAmount);
        }

        return true;
    }

    /**
     * @dev Burns csToken from user and instantly returns Token to user,
     * According to current exchange rate.
     * Token will come from the contract liquidity vs staked tokens in nodes
     * Emits an {LogInstantWithdraw} event.
     *
     * Requirements:
     * - `amountCs` cannot be zero.
     * - `defaultLiquidity` should not be zero aka Instant Withdraw enabled
     * - user csToken can not be less than `amountCs`.
     * - amount of Token to withdraw cannot be zero and should be less or equal to `_getLiquidityToken()`.
     *
     * @param amountCs - Amount of csToken to be withdrawn.
     * @return Bool confirmation of transaction
     */
    function instantWithdraw(uint256 amountCs)
        external
        override
        whenNotPaused
        nonReentrant
        enforceAndUpdateBalance
        returns (bool)
    {
        require(amountCs != 0, "CI01");
        require(defaultLiquidity != 0, "CI02");
        require(csToken.balanceOf(msg.sender) >= amountCs, "CI03");
        if (slashingEnabled) _updatedStaked(false);

        // Update funds
        uint256 amountTokenWithdraw = _exchangeCsToken(amountCs, funds.currentDeposit);
        require(amountTokenWithdraw != 0 && _getLiquidityToken() >= amountTokenWithdraw, "CI04");
        funds.currentDeposit -= amountTokenWithdraw;

        // Transfer fee
        uint256 payableFee = 0;
        if (fees.instantWithdrawFee != 0) {
            payableFee = _getPercentValue(fees.instantWithdrawFee, amountTokenWithdraw);

            // Portion goes into the vault
            uint256 vaultPortion = _getPercentValue(fees.rewardFee, payableFee);
            funds.currentDeposit += payableFee - vaultPortion;
            funds.accruedFees += vaultPortion;
        }

        // Burn csToken
        require(csToken.burn(msg.sender, amountCs), "CI05");

        // Transfer token to user
        uint256 amountTokenWithdrawToUser = amountTokenWithdraw - payableFee;
        underlyingToken.safeTransfer(msg.sender, amountTokenWithdrawToUser);
        emit LogInstantWithdraw(msg.sender, amountCs, amountTokenWithdrawToUser, payableFee);

        return true;
    }

    /** PUBLIC VIEWS **/

    /**
     * @dev Returns the current exchange rate accounting for any slashing or donations.
     *
     * @notice Autobalancer to be run when slashing happens.
     *
     * @return Exchange Rate csToken to Token, Slashing occurred.
     */
    function getExchangeRate() external view returns (uint256, bool) {
        (uint256 deposits, bool slashed) = _calculatedCurrentDeposits();
        return (_exchangeCsToken(MAX_DECIMALS, deposits), slashed);
    }

    /// @dev Returns information about all nodes.
    function getNodes() external view returns (StakingNode[] memory, uint256[] memory) {
        uint256 n = activeNodes.length;
        (, uint256[] memory stakedNodes) = _getTotalStaked();
        StakingNode[] memory nodes = new StakingNode[](n);
        for (uint256 i = 0; i < n; i++) {
            nodes[i] = stakingNodes[activeNodes[i]];
        }
        return (nodes, stakedNodes);
    }

    /// @dev Returns total liquidity of csToken available.
    function getLiquidityCsToken() external view returns (uint256) {
        (uint256 deposits, ) = _calculatedCurrentDeposits();
        uint256 amount = _getLiquidityToken();
        return amount != 0 ? _exchangeToken(amount, deposits) : 0;
    }

    /// @dev Calculates and returns max amount of csToken that can be withdrawn in a given transaction
    function getMaxWithdrawAmountCs() external view returns (uint256) {
        (, uint256[] memory stakedNodes) = _getTotalStaked();
        (uint256 deposits, ) = _calculatedCurrentDeposits();
        uint256 amount = 0;
        uint256 n = activeNodes.length;
        uint256 startingNode = activeUnstakingNode;
        uint256 count = 0;
        uint256 maxNodesToWithdraw_ = maxNodesToWithdraw;
        uint256 maxWithdrawNodePercentage_ = maxWithdrawNodePercentage;
        for (uint256 i = n; i > 0; i--) {
            if (count >= maxNodesToWithdraw_) break;
            uint256 position = (startingNode + i) % n;
            if (stakedNodes[position] != 0) {
                amount += _getPercentValue(maxWithdrawNodePercentage_, stakedNodes[position]);
                count++;
            }
        }
        return amount != 0 ? _exchangeToken(amount, deposits) : 0;
    }

    /// @dev return stakemanger epoc and withdraw delay.
    function getEpoch() external view returns (uint256, uint256) {
        return (stakeManager.epoch(), stakeManager.withdrawalDelay());
    }

    /** CLAYSTACK STAKING **/

    /**
     * @dev Claims rewards, transfers fees to vault and stakes in nodes
     * Calls `_sequentiallyStake` internally.
     *
     * @return Bool confirmation of transaction
     * Emits {LogTransferVault} events.
     */
    function autoBalance() external override whenNotPaused nonReentrant enforceAndUpdateBalance returns (bool) {
        _updatedStaked(true);

        // Claim rewards above minAmount on all nodes
        uint256 rewards = 0;
        uint256 n = activeNodes.length;
        for (uint256 i = 0; i < n; i++) {
            StakingNode storage node = stakingNodes[activeNodes[i]];
            if (node.staked != 0) {
                rewards += _withdrawRewards(node);
            }
        }
        _updateRewards(rewards);

        // Transfer fees to vault
        if (funds.accruedFees != 0) {
            uint256 accruedFees = funds.accruedFees;
            funds.accruedFees = 0;
            underlyingToken.safeTransfer(vaultManager, accruedFees);
            emit LogTransferVault(vaultManager, accruedFees);
        }

        // Reset decimal difference for balancing accuracy
        uint256 currentBalance = underlyingToken.balanceOf(address(this));
        funds.currentDeposit = currentBalance + funds.stakedDeposit;

        // Determine net staking/unstaking needed
        uint256 targetLiquidity = _getPercentValue(defaultLiquidity, funds.currentDeposit);
        uint256 targetStake = funds.currentDeposit - targetLiquidity;

        /** STAKING **/
        if (targetStake > funds.stakedDeposit) {
            uint256 availableToStake = _positiveSub(currentBalance, targetLiquidity);
            uint256 toStake = _min(targetStake - funds.stakedDeposit, availableToStake);
            if (toStake != 0) _sequentiallyStake(toStake, targetStake);
        }

        return true;
    }

    /**
     * @dev Migrates staked `amount` from `fromNodeId` to `toNodeId` node.
     * Emits an {LogDelegationMigration} event.
     *
     * @notice only `CS_SERVICE_ROLE` callable.
     *
     * Requirements:
     * - `amount` cannot be zero.
     * - `toNodeId` cannot be foundation node. thus `toNodeId` should be more than 7.
     * - `toValidator` cannot be locked and should have active delegation state.
     * - `fromNodeId` stake amount cannot be less than `amount`.
     *
     * @param fromNodeId : Id of node from which amounts is migrated.
     * @param toNodeId : Id of node to which amount is migrated to.
     * @param amount : Amount of tokens to be migrated
     */
    function migrateDelegation(
        uint256 fromNodeId,
        uint256 toNodeId,
        uint256 amount
    ) external onlyRole(CS_SERVICE_ROLE) nonReentrant whenNotPaused enforceAndUpdateBalance returns (bool) {
        require(amount != 0, "CM01");
        if (slashingEnabled) _updatedStaked(false);

        StakingNode storage fromValidatorNode = stakingNodes[fromNodeId];
        StakingNode storage toValidatorNode = stakingNodes[toNodeId];

        Validator fromValidator = Validator(fromValidatorNode.validatorAddress);
        Validator toValidator = Validator(toValidatorNode.validatorAddress);

        require(toValidator.validatorId() > 7, "CM02");
        require(!toValidator.locked() && toValidator.delegation(), "CM03");
        require(fromValidatorNode.staked >= amount, "CM04");

        fromValidatorNode.staked -= amount;
        toValidatorNode.staked += amount;

        uint256 contractBefore = underlyingToken.balanceOf(address(this));
        stakeManager.migrateDelegation(fromValidator.validatorId(), toValidator.validatorId(), amount);
        uint256 rewards = underlyingToken.balanceOf(address(this)) - contractBefore;
        _updateRewards(rewards);

        emit LogDelegationMigration(fromValidatorNode.validatorAddress, toValidatorNode.validatorAddress, amount);
        return true;
    }

    /**
     * @dev Sequentially stakes the given amount `toStake` across nodes.
     * Emits an {LogStake} event.
     *
     * @param toStake : Amount to be staked.
     * @param targetStake : Desired total target stake.
     */
    function _sequentiallyStake(uint256 toStake, uint256 targetStake) internal {
        IERC20 underlyingToken_ = underlyingToken;
        require(underlyingToken_.balanceOf(address(this)) >= toStake, "CS01");

        uint256 totalPoints_ = totalPoints;
        uint256 overStakingThreshold_ = overStakingThreshold;
        address stakeManagerAddress = address(stakeManager);
        uint256 stakedDeposit = 0;
        uint256 position = 0;
        uint256 n = activeNodes.length;
        uint256 startingNode = activeStakingNode;
        for (uint256 i = 0; i < n; i++) {
            position = (startingNode + i) % n;

            // If all staked, stop loop
            if (toStake == 0) break;

            // Pass if node is not active to the next node
            StakingNode storage node = stakingNodes[activeNodes[position]];
            if (node.points == 0) continue;

            // Pass if Token check if not locked or stopped delegation
            if (Validator(node.validatorAddress).locked() || !Validator(node.validatorAddress).delegation()) continue;

            uint256 toStakeNode;
            {
                uint256 targetNode = (targetStake * node.points) / totalPoints_;
                toStakeNode = _min(toStake, _positiveSub(targetNode, node.staked));
            }

            // If leftover amount is less than threshold (%), then stake all in one node
            if (toStake - toStakeNode < _getPercentValue(overStakingThreshold_, targetStake)) {
                toStakeNode = toStake;
            }

            if (toStakeNode != 0) {
                // Stake
                _updateRewards(Validator(node.validatorAddress).getLiquidRewards(address(this)));
                require(underlyingToken_.approve(stakeManagerAddress, toStakeNode), "CS02");
                uint256 contractStaked = Validator(node.validatorAddress).buyVoucher(toStakeNode, 0);

                node.staked += contractStaked;
                toStake -= contractStaked;
                stakedDeposit += contractStaked;

                emit LogStake(node.id, contractStaked, node.staked);
            }
        }
        activeStakingNode = (position + 1) % n;
        funds.stakedDeposit += stakedDeposit;
    }

    /**
     * @dev Sequentially unstakes the given amount `toUnStake`.
     * Emits an {LogUnstake} event.
     *
     * @param toUnStake : Amount to be unstaked.
     */
    function _sequentiallyUnStake(uint256 toUnStake) internal returns (uint256[] memory, uint256[] memory) {
        uint256 n = activeNodes.length;
        uint256[] memory orderIdsFull = new uint256[](n);
        uint256[] memory nodesIdsFull = new uint256[](n);
        uint256 countNodesUnstaked = 0;
        uint256 totalUnstaked = 0;
        uint256 maxWithdrawNodePercentage_ = maxWithdrawNodePercentage;

        // Start in the previous active staking node
        uint256 position = 0;
        uint256 startingNode = activeUnstakingNode;
        for (uint256 i = n; i > 0; i--) {
            position = (startingNode + i) % n;
            if (toUnStake == 0 || countNodesUnstaked >= maxNodesToWithdraw) break;

            StakingNode storage node = stakingNodes[activeNodes[position]];
            if (node.staked == 0) continue;

            uint256 toUnstakeNode = _min(_getPercentValue(maxWithdrawNodePercentage_, node.staked), toUnStake);
            if (toUnstakeNode == 0) continue;

            totalUnstaked += toUnstakeNode;
            Validator validator = Validator(node.validatorAddress);
            _updateRewards(validator.getLiquidRewards(address(this)));
            validator.sellVoucher_new(toUnstakeNode, type(uint256).max);

            countNodesUnstaked++;
            orderIdsFull[position] = validator.unbondNonces(address(this));
            nodesIdsFull[position] = node.id;
            toUnStake -= toUnstakeNode;
            node.staked -= toUnstakeNode;

            emit LogUnstake(node.id, toUnstakeNode, node.staked);
        }
        funds.stakedDeposit -= totalUnstaked;
        activeUnstakingNode = position;

        // Create output arrays
        uint256[] memory orderIds = new uint256[](countNodesUnstaked);
        uint256[] memory nodeIds = new uint256[](countNodesUnstaked);
        uint256 j = 0;
        for (uint256 i = 0; i < n; i++) {
            if (orderIdsFull[i] != 0) {
                orderIds[j] = orderIdsFull[i];
                nodeIds[j] = nodesIdsFull[i];
                j++;
            }
        }

        return (orderIds, nodeIds);
    }

    /**
     * @dev Helper function to withdraw rewards from validator node.
     *
     * @param node : Node from which rewards needs to be withdrawn.
     * @return Amounts of rewards withdrawn.
     */
    function _withdrawRewards(StakingNode memory node) internal returns (uint256) {
        Validator validator = Validator(node.validatorAddress);
        uint256 rewards = validator.getLiquidRewards(address(this));
        if (rewards != 0 && rewards >= validator.minAmount()) {
            validator.withdrawRewards();
        } else {
            // As no rewards were withdrawn, ensures partial are not counted
            rewards = 0;
        }
        return rewards;
    }

    /**
     * @dev Helper function to account for accrued `rewards`.
     * Emits an {LogRewards} event.
     *
     * @param rewards : Amounts of reward accrued.
     */
    function _updateRewards(uint256 rewards) internal {
        if (rewards != 0) {
            uint256 currentDeposit = funds.currentDeposit + rewards;
            uint256 payableFee = _getPercentValue(fees.rewardFee, rewards);
            currentDeposit -= payableFee;
            funds.currentDeposit = currentDeposit;
            funds.accruedFees += payableFee;
            emit LogRewards(rewards, payableFee);
        }
    }

    /**
     * @dev Updates exchange rate on cases where tokens are sent to the contract,
     * this function will update the accounting thereby increasing the exchange rate
     * and ensuring the contract is balanced.
     * Emits an {LogDonation} event.
     */
    function _updateBalance() internal {
        uint256 currentBalance = underlyingToken.balanceOf(address(this));
        if (contractBalance != currentBalance) {
            uint256 donation = currentBalance - contractBalance;
            uint256 payableFee = _getPercentValue(fees.rewardFee, donation);
            funds.currentDeposit += donation - payableFee;
            funds.accruedFees += payableFee;
            exchangeRate = exchangeRate != 0 ? _getExchangeRate(funds.currentDeposit) : 0;
            emit LogDonation(donation);
        }
    }

    /**
     * @dev Updates the staked account in cases where  a change (slashing) has occurred
     * and thereby updates the exchange rate (through update to currentDeposit)
     * while update the node.staked used subsequently in staking/unstaking
     *
     * @param checkExtra : Boolean flag to perform sanity check or not.
     * Emits an {LogSlashing} event.
     */
    function _updatedStaked(bool checkExtra) internal {
        (uint256 totalStaked, uint256[] memory stakeNodes) = _getTotalStaked();

        // Adds the difference to current (slashing)
        if (totalStaked < funds.stakedDeposit || (checkExtra && totalStaked != funds.stakedDeposit)) {
            funds.currentDeposit -= _positiveSub(funds.stakedDeposit, totalStaked);
            funds.stakedDeposit = totalStaked;
            exchangeRate = exchangeRate != 0 ? _getExchangeRate(funds.currentDeposit) : 0;

            // Update node.staked
            uint256 n = activeNodes.length;
            for (uint256 i = 0; i < n; i++) {
                StakingNode storage node = stakingNodes[activeNodes[i]];
                if (node.staked != stakeNodes[i]) {
                    emit LogSlashing(node.id, _positiveSub(stakeNodes[i], node.staked));
                    node.staked = stakeNodes[i];
                }
            }
        }
    }

    /// @dev Returns Total amounts staked and each node's staking amount respectively.
    function _getTotalStaked() internal view returns (uint256, uint256[] memory) {
        uint256 n = activeNodes.length;
        uint256 totalStaked = 0;
        uint256[] memory nodeStake = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            address validatorAddress = stakingNodes[activeNodes[i]].validatorAddress;
            (uint256 stake, ) = Validator(validatorAddress).getTotalStake(address(this));
            totalStaked += stake;
            nodeStake[i] = stake;
        }
        return (totalStaked, nodeStake);
    }

    /// @dev Calculates current deposit based on updated staked amount and checks if slashing occurred
    function _calculatedCurrentDeposits() internal view returns (uint256, bool) {
        (uint256 totalStaked, ) = _getTotalStaked();
        uint256 currentBalance = underlyingToken.balanceOf(address(this));
        uint256 deposits = funds.currentDeposit;
        bool slashed = false;
        if (currentBalance != 0 && contractBalance != currentBalance) {
            uint256 donation = currentBalance - contractBalance;
            uint256 payableFee = _getPercentValue(fees.rewardFee, donation);
            deposits += donation - payableFee;
        }

        if (totalStaked < funds.stakedDeposit) {
            deposits -= funds.stakedDeposit - totalStaked;
            slashed = true;
        }
        return (deposits, slashed);
    }

    /**
     * @dev Returns amount of csTokens for given `amountToken`.
     * Returns `amountToken` if ,
     * `currentDeposits` is zero
     * `totalCsToken` is zero
     * `totalCsToken` is same as `currentDeposits`
     *
     * @param amountToken : Amount of Token.
     * @param currentDeposits : total current deposit in the contract.
     */
    function _exchangeToken(uint256 amountToken, uint256 currentDeposits) internal view returns (uint256) {
        uint256 totalCsToken = csToken.totalSupply();
        if (totalCsToken != currentDeposits && currentDeposits != 0 && totalCsToken != 0) {
            return (amountToken * totalCsToken) / currentDeposits;
        } else {
            return amountToken;
        }
    }

    /**
     * @dev Returns amount of Token for given `amountCs`.
     * Returns `amountCs` if ,
     * `currentDeposits` is zero
     * `totalCsToken` is zero
     * `totalCsToken` is same as `currentDeposits`
     *
     * @param amountCs : Amount of csToken.
     * @param currentDeposits : total current deposit in the contract.
     */
    function _exchangeCsToken(uint256 amountCs, uint256 currentDeposits) internal view returns (uint256) {
        uint256 totalCsToken = csToken.totalSupply();
        if (totalCsToken != currentDeposits && totalCsToken != 0 && currentDeposits != 0) {
            return (amountCs * currentDeposits) / totalCsToken;
        } else {
            return amountCs;
        }
    }

    /// @dev Returns current exchange rate i.e. csToken to 1 unit of Token
    function _getExchangeRate(uint256 deposits) public view returns (uint256) {
        return _exchangeCsToken(MAX_DECIMALS, deposits);
    }

    /// @dev Returns liquidity of Token
    function _getLiquidityToken() internal view returns (uint256) {
        return underlyingToken.balanceOf(address(this)) - funds.accruedFees;
    }

    /// @dev Returns maximum allowed amount available for unstaking.
    function _getMaxWithdrawAmount() internal view returns (uint256) {
        uint256 amount = 0;
        uint256 n = activeNodes.length;
        uint256 startingNode = activeUnstakingNode;
        uint256 count = 0;
        uint256 maxWithdrawNodePercentage_ = maxWithdrawNodePercentage;
        uint256 maxNodesToWithdraw_ = maxNodesToWithdraw;
        for (uint256 i = n; i > 0; i--) {
            if (count >= maxNodesToWithdraw_) break;
            uint256 position = (startingNode + i) % n;
            StakingNode storage node = stakingNodes[activeNodes[position]];
            if (node.staked != 0) {
                amount += _getPercentValue(maxWithdrawNodePercentage_, node.staked);
                count++;
            }
        }
        return amount;
    }

    // @dev Assures contract state remains balanced by comparing user flows deposits vs staking flows.
    function _balanced() internal {
        uint256 userFlow = (funds.currentDeposit + funds.accruedFees) / 1e16;
        if (userFlow != 0) {
            uint256 contractBalance_ = underlyingToken.balanceOf(address(this));
            uint256 stakingFlow = (contractBalance_ + funds.stakedDeposit) / 1e16;
            require(stakingFlow <= userFlow + 1 && userFlow <= stakingFlow + 1, "CB01");
            contractBalance = contractBalance_;
            uint256 newExchange = _getExchangeRate(funds.currentDeposit);
            if (exchangeRate != 0) {
                require(
                    _positiveSub(newExchange, exchangeRate) <= _getPercentValue(changeLimitExchangeRate, exchangeRate),
                    "CB02"
                );
            }
            exchangeRate = newExchange;
        }
    }

    /** CLAYSTACK OPERATIONS **/

    /**
     * @dev Used to add new Validators creating a new StakingNode entry.
     * @notice Allows to add same validator multiple times, thus ensures complies with protocol rules.
     *
     * Requirements:
     * - `validators` length should be equal to `points` length.
     * - `validators` cannot be zero address.
     * - `validators` should be valid & cannot be locked.
     *
     * @param validators : list of validator addresses.
     * @param points : New points for given `validators`
     */
    function addNodes(address[] calldata validators, uint256[] calldata points) external onlyRole(TIMELOCK_ROLE) {
        require(validators.length == points.length, "CO08");
        uint256 newPoints = 0;
        uint256 newCountNodes = countStakingNodes;
        StakeManager stakeManager_ = stakeManager;
        for (uint256 i = 0; i < validators.length; i++) {
            address validator = validators[i];
            require(address(validator) != address(0x0), "CO09");

            // Checks it's a valid node
            Validator val = Validator(validator);
            require(stakeManager_.getValidatorContract(val.validatorId()) == validator && !val.locked(), "CO10");

            newPoints += points[i];
            activeNodes.push(newCountNodes);
            stakingNodes[newCountNodes] = StakingNode(newCountNodes, validator, points[i], 0);
            newCountNodes++;
        }
        totalPoints += newPoints;
        countStakingNodes = newCountNodes;
    }

    /**
     * @dev Actives an existing node adding it to the active list.
     * Updates points for existing node.
     *
     * @notice Only `TIMELOCK_ROLE` callable.
     *
     * Requirements:
     * - `nodesId` length should be equal to `points` length.
     *
     * @param nodesId : Id of node whose points needs to updated.
     * @param points : New points for given `_nodeId`.
     */
    function updateNodes(uint256[] calldata nodesId, uint256[] calldata points) external onlyRole(TIMELOCK_ROLE) {
        require(nodesId.length == points.length, "CO11");
        for (uint256 i = 0; i < nodesId.length; i++) {
            uint256 nodeId = nodesId[i];
            StakingNode storage node = stakingNodes[nodeId];
            node.points = points[i];
            if (!_isNodeActive(nodeId)) activeNodes.push(nodeId);
        }
        _updateNodePoints();
    }

    /**
     * @dev Used to deactivate a node from the active list
     * Requirements:
     * - Node must have been fully unstaked before deactivating
     * - Node must be currently in the active list
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * @param nodeId : Id of node, that needs to be deactivated.
     */
    function deactivateNode(uint256 nodeId) external onlyRole(CS_SERVICE_ROLE) {
        // Ensure provided node is not actively staking
        StakingNode storage node = stakingNodes[nodeId];
        require(node.staked == 0, "CO12");
        node.points = 0;

        bool status = false;
        uint256 n = activeNodes.length;
        uint256 lastNodeId = activeNodes[n - 1];
        for (uint256 i = 0; i < n; i++) {
            if (activeNodes[i] == nodeId) {
                if (i != n - 1) {
                    activeNodes[i] = lastNodeId;
                }
                activeNodes.pop();
                status = true;
                break;
            }
        }
        require(status, "CO13");
        _updateNodePoints();
    }

    /// @dev Returns boolean if given `_nodeId` is in active list or not.
    function _isNodeActive(uint256 nodeId) internal view returns (bool) {
        uint256 n = activeNodes.length;
        for (uint256 i = 0; i < n; i++) {
            if (activeNodes[i] == nodeId) {
                return true;
            }
        }
        return false;
    }

    /// @dev Update `totalPoints` by adding total points from each node.
    function _updateNodePoints() internal {
        uint256 newTotalPoints = 0;
        uint256 n = activeNodes.length;
        for (uint256 i = 0; i < n; i++) {
            StakingNode storage node = stakingNodes[activeNodes[i]];
            newTotalPoints += node.points;
        }
        totalPoints = newTotalPoints;
    }

    /**
     * @dev Sets new `defaultLiquidity` percent to `value`.
     *
     * Requirements:
     * - `value` should be less than `PERCENTAGE_BASE`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * @param value : new default liquidity percentage to be maintained in contract.
     */
    function setDefaultLiquidity(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        require(value < PERCENTAGE_BASE, "CO06");
        defaultLiquidity = value;
    }

    /**
     * @dev Sets new `depositLimit` to `value`.
     * If deposit limit is zero , then no limit is applied over deposit.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * @param value : new maximum deposit limit.
     */
    function setDepositLimit(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        depositLimit = value;
    }

    /**
     * @dev Sets new fee percent for given `feeType_` to `fee_`.
     *
     * Requirements:
     * - `fee_` should be less than `PERCENTAGE_BASE`
     * - `fee_` should be less or equal to the max limit per fee type
     *
     * @notice Only `TIMELOCK_ROLE` callable.
     *
     * @param feeType_ : Index of `feeType` to be updated. See {IClayMain-SetFee}.
     * @param fee_ : New fee percent.
     */
    function setFee(SetFee feeType_, uint256 fee_) external onlyRole(TIMELOCK_ROLE) {
        require(fee_ < PERCENTAGE_BASE, "CO06");
        if (feeType_ == SetFee.DepositFee) {
            require(fee_ <= MAX_DEPOSIT_FEE, "CO16");
            fees.depositFee = fee_;
        } else if (feeType_ == SetFee.WithdrawFee) {
            require(fee_ <= MAX_WITHDRAW_FEE, "CO17");
            fees.withdrawFee = fee_;
        } else if (feeType_ == SetFee.InstantWithdrawFee) {
            require(fee_ <= MAX_INSTANT_WITHDRAW_FEE, "CO18");
            fees.instantWithdrawFee = fee_;
        } else if (feeType_ == SetFee.RewardFee) {
            require(fee_ <= MAX_REWARD_FEE, "CO19");
            fees.rewardFee = fee_;
        } else {
            revert("CO07");
        }
    }

    /**
     * @dev Sets new `changeLimitExchangeRate` to `value`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * Requirements:
     * - `value` should be less than `PERCENTAGE_BASE`.
     *
     * @param value : new exchange rate change threshold.
     */
    function setChangeLimitExchangeRate(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        require(value < PERCENTAGE_BASE, "CO06");
        changeLimitExchangeRate = value;
    }

    /**
     * @dev Sets new `maxWithdrawNodePercentage` to `value`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * Requirements:
     * - `value` can not be zero.
     *
     * @param value : new max percentage limit per node.
     */
    function setMaxWithdrawNodePercentage(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        require(value != 0 && value <= PERCENTAGE_BASE, "CO06");
        maxWithdrawNodePercentage = value;
    }

    /**
     * @dev Sets new `maxNodesToWithdraw` limit to `value`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * Requirements:
     * - `value` can not be zero.
     *
     * @param value : new max limit.
     */
    function setMaxNodesToWithdraw(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        require(value != 0, "CO14");
        maxNodesToWithdraw = value;
    }

    /**
     * @dev Sets `vaultManager` contract address to `vaultAddress`.
     *
     * @notice Only `TIMELOCK_UPGRADES_ROLE` callable.
     *
     * Requirements:
     * - `vaultAddress` can not be zero address.
     *
     * @param vaultAddress : Address of new vault manager contract.
     */
    function setVaultManager(address vaultAddress) external onlyRole(TIMELOCK_UPGRADES_ROLE) {
        require(vaultAddress != address(0), "CO03");
        vaultManager = vaultAddress;
    }

    /**
     * @dev Sets `slashingEnabled` to `value`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * @param value : Boolean value for enabling/disabling slashing handling.
     */
    function setSlashingEnabled(bool value) external onlyRole(CS_SERVICE_ROLE) {
        slashingEnabled = value;
    }

    /**
     * @dev Sets `overStakingThreshold` to `value`.
     *
     * @notice Only `CS_SERVICE_ROLE` callable.
     *
     * Requirements:
     * - `overStakingThreshold` should be less than MAX_OVER_STAKING_THRESHOLD.
     *
     * @param value : new threshold value.
     */
    function setOverStakingThreshold(uint256 value) external onlyRole(CS_SERVICE_ROLE) {
        require(value <= MAX_OVER_STAKING_THRESHOLD, "CO15");
        overStakingThreshold = value;
    }

    /** SUPPORT **/

    /**
     * @dev Calculate & returns `percent` value on given `amount_`
     * uses `PERCENTAGE_BASE` for 2 decimal precision (i.e, 100.00)
     *
     * @param percent : Percentage with 2 point decimal precision.
     * @param amount_ : Amount on which `_percent` needs to be calculated.
     */
    function _getPercentValue(uint256 percent, uint256 amount_) internal pure returns (uint256) {
        return (amount_ * percent) / PERCENTAGE_BASE;
    }

    /**
     * @dev Returns minimum value between given `x` & `y`
     * Equivalent to min(x,y)
     *
     * @param x : First value for minimum.
     * @param y : Second value for minimum.
     */
    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x < y) {
            return x;
        } else {
            return y;
        }
    }

    /**
     * @dev Returns the positive difference  between x & y
     * Equivalent to max(0, x - y)
     *
     * @param x : minuend.
     * @param y : subtrahend.
     */
    function _positiveSub(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x < y) {
            return 0;
        } else {
            return x - y;
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * @notice Only `CS_SERVICE_ROLE` callable
     *
     * Requirements:
     * - The contract must not be paused.
     */
    function pause() external onlyRole(CS_SERVICE_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * @notice Only `CS_SERVICE_ROLE` callable
     *
     * Requirements:
     * - The contract must be paused.
     */
    function unpause() external onlyRole(CS_SERVICE_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @dev Checks caller has the given `_roleName` or not.
     * Calls RoleManager contract.
     */
    function _onlyRole(bytes32 roleName_) internal view {
        require(roleManager.checkRole(roleName_, msg.sender), "CO00");
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation_`.
     * Emits an {Upgraded} event.
     *
     * @notice Only `TIMELOCK_UPGRADES_ROLE` callable.
     *
     * @param newImplementation_ : Address of new implementation of the contract
     */
    function upgradeTo(address newImplementation_)
        external
        virtual
        override
        onlyRole(TIMELOCK_UPGRADES_ROLE)
        onlyProxy
    {
        _authorizeUpgrade(newImplementation_);
        _upgradeTo(newImplementation_);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract or
     * `newImplementation_` is not contract.
     *
     * @param newImplementation_ : Address of new implementation of the contract.
     */
    function _authorizeUpgrade(address newImplementation_) internal virtual override onlyRole(TIMELOCK_UPGRADES_ROLE) {
        require(AddressUpgradeable.isContract(newImplementation_), "!contract");
    }
}
