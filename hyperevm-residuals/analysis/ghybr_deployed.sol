// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IBribe.sol";
import "./interfaces/IRewardsDistributor.sol";
import "./interfaces/IGaugeManager.sol";
import "./interfaces/ISwapper.sol";
import {HybraTimeLibrary} from "./libraries/HybraTimeLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title GovernanceHYBR (gHYBR)
 * @notice Auto-compounding staking token that locks HYBR as veHYBR and compounds rewards
 * @dev Implements transfer restrictions for new deposits and automatic reward compounding
 */
contract GrowthHYBR is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // Lock period for new deposits (configurable between 12-24 hours)
    uint256 public transferLockPeriod = 24 hours;
    uint256 public constant MIN_LOCK_PERIOD = 1 hours;
    uint256 public constant MAX_LOCK_PERIOD = 168 hours;
    uint256 public head_not_withdraw_time = 1 days;
    uint256 public tail_not_withdraw_time = 1 days;
  
    // Withdraw fee configuration (basis points, 10000 = 100%)
    uint256 public withdrawFee = 100; // 1% default fee
    uint256 public constant MIN_WITHDRAW_FEE = 10; // 0.1% minimum
    uint256 public constant MAX_WITHDRAW_FEE = 1000; // 10% maximum
    uint256 public constant BASIS = 10000;
    address public Team; // Address to receive fees
    uint256 public rebase;
    uint256 public penalty;
    uint256 public votingYield;
    address public rHYBR;
    uint256 public maxLocks = 1500;
    // User deposit tracking for transfer locks
    struct UserLock {
        uint256 amount;
        uint256 unlockTime;
    }
    
    mapping(address => UserLock[]) public userLocks;
    mapping(address => uint256) public lockedBalance;
    
    // Core contracts
    address public immutable HYBR;
    address public immutable votingEscrow;
    address public voter;
    address public rewardsDistributor;
    address public gaugeManager;
    uint256 public veTokenId; // The veNFT owned by this contract
    
    // Auto-voting strategy
    address public operator; // Address that can manage voting strategy
    uint256 public lastVoteEpoch; // Last epoch when we voted
    
    // Reward tracking
    uint256 public lastRebaseTime;
    uint256 public lastCompoundTime;

    // Swap module
    ISwapper public swapper;

    // Errors
    error NOT_AUTHORIZED();
    
    // Events
    event Deposit(address indexed user, uint256 hybrAmount, uint256 sharesReceived);
    event Withdraw(address indexed user, uint256 shares, uint256 hybrAmount, uint256 fee);
    event Compound(uint256 rewards, uint256 newTotalLocked);
    event PenaltyRewardReceived(uint256 amount);
    event TransferLockPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event SwapperUpdated(address indexed oldSwapper, address indexed newSwapper);
    event VoterSet(address voter);
    event EmergencyUnlock(address indexed user);
    event AutoVotingEnabled(bool enabled);
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);
    event DefaultVotingStrategyUpdated(address[] pools, uint256[] weights);
    event AutoVoteExecuted(uint256 epoch, address[] pools, uint256[] weights);

    constructor(
        address _HYBR,
        address _votingEscrow
    ) ERC20("Growth HYBR", "gHYBR") {
        require(_HYBR != address(0), "Invalid HYBR");
        require(_votingEscrow != address(0), "Invalid VE");
        
        HYBR = _HYBR;
        votingEscrow = _votingEscrow;
        lastRebaseTime = block.timestamp;
        lastCompoundTime = block.timestamp;
        operator = msg.sender; // Initially set deployer as operator
    }
    
    function setRHYBR(address _rHYBR) external onlyOwner {
        require(_rHYBR != address(0), "Invalid rHYBR");
        rHYBR = _rHYBR;
    }
    function setRewardsDistributor(address _rewardsDistributor) external onlyOwner {
        require(_rewardsDistributor != address(0), "Invalid rewards distributor");
        rewardsDistributor = _rewardsDistributor;
    }
    
    function setGaugeManager(address _gaugeManager) external onlyOwner {
        require(_gaugeManager != address(0), "Invalid gauge manager");
        gaugeManager = _gaugeManager;
    }

    
      /**
     * @notice Modifier to check authorization (owner or operator)
     */
    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NOT_AUTHORIZED();
        }
        _;
    }

    function setMaxLocks(uint256 _maxLocks) external onlyOwner {
        require(_maxLocks < 1900, "Invalid max locks");
        maxLocks = _maxLocks;
    }


    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        _deposit_for(amount, msg.sender);
    }
    /**
     * @notice Deposit HYBR and receive gHYBR shares
     * @param amount Amount of HYBR to deposit
     * @param recipient Recipient of gHYBR shares
     */
    function deposit_for(uint256 amount, address recipient) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(msg.sender == rHYBR, "Invalid caller");
        require(recipient != address(0), "Invalid recipient");
        _deposit_for(amount, recipient);
       
    }

    function _deposit_for(uint256 amount, address recipient) internal {
        uint256 shares = calculateShares(amount);
        require(shares > 0, "ZERO_SHARES");
        // Transfer HYBR from user first
        IERC20(HYBR).transferFrom(msg.sender, address(this), amount);
            
        // Initialize veNFT on first deposit
        if (veTokenId == 0) {
            _initializeVeNFT(amount);
        } else {
            // Add to existing veNFT
            IERC20(HYBR).approve(votingEscrow, amount);
            IVotingEscrow(votingEscrow).deposit_for(veTokenId, amount);

            // Extend lock to maximum duration
            _extendLockToMax();
        }
        
        // Calculate shares to mint based on current totalAssets
        
        // Mint gHYBR shares
        _mint(recipient, shares);
        
        // Add transfer lock for recipient
        _addTransferLock(recipient, shares);
        
        emit Deposit(recipient, amount, shares);
    }

    /**
     * @notice Withdraw gHYBR shares and receive a new veNFT with proportional HYBR
     * @dev Creates new veNFT using multiSplit to maintain proportional ownership
     * @param shares Amount of gHYBR shares to burn
     * @return userTokenId The ID of the new veNFT created for the user
     */
    function withdraw(uint256 shares) external nonReentrant returns (uint256 userTokenId) {
        require(shares > 0, "Zero shares");
        require(balanceOf(msg.sender) >= shares, "Insufficient balance");
        require(veTokenId != 0, "No veNFT initialized");
        require(IVotingEscrow(votingEscrow).voted(veTokenId) == false, "Cannot withdraw yet");
        
        uint256 epochStart = HybraTimeLibrary.epochStart(block.timestamp);
        uint256 epochNext = HybraTimeLibrary.epochNext(block.timestamp);

        require(block.timestamp >= epochStart + head_not_withdraw_time && block.timestamp < epochNext - tail_not_withdraw_time, "Cannot withdraw yet");

        // Calculate proportional HYBR amount from veNFT
        uint256 hybrAmount = calculateAssets(shares);
        require(hybrAmount > 0, "No assets to withdraw");

        // Calculate fee amount (from the HYBR amount, not shares)
        uint256 feeAmount = 0;
        if (withdrawFee > 0) {
            feeAmount = (hybrAmount * withdrawFee) / BASIS;
        }

        // User receives amount minus fee
        uint256 userAmount = hybrAmount - feeAmount;
        require(userAmount > 0, "Amount too small after fee");

        // Get actual HYBR locked amount (not voting power)
        uint256 veBalance = totalAssets();
        require(hybrAmount <= veBalance, "Insufficient veNFT balance");

        uint256 remainingAmount = veBalance - userAmount - feeAmount;  
        require(remainingAmount >= 0, "Cannot withdraw entire veNFT");

        // Burn gHYBR shares (full amount)
        _burn(msg.sender, shares);

        // Use multiSplit to create two NFTs: one for user, one for contract
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = remainingAmount; // Amount staying with gHYBR 
        amounts[1] = userAmount;      // Amount going to user (after fee)
        amounts[2] = feeAmount;      // Amount going to fee recipient


        uint256[] memory newTokenIds = IVotingEscrow(votingEscrow).multiSplit(veTokenId, amounts);
    
        // Update contract's veTokenId to the first new token
        veTokenId = newTokenIds[0];
        userTokenId = newTokenIds[1];
        uint256 feeTokenId = newTokenIds[2];
        // Note: userTokenId is transferred to user, they can manage their own lock time
        IVotingEscrow(votingEscrow).safeTransferFrom(address(this), msg.sender, userTokenId);
        IVotingEscrow(votingEscrow).safeTransferFrom(address(this), Team, feeTokenId);
        emit Withdraw(msg.sender, shares, userAmount, feeAmount);
    }


    /**
     * @notice Internal function to initialize veNFT on first deposit
     */
    function _initializeVeNFT(uint256 initialAmount) internal {
        // Create max lock with the initial deposit amount
        IERC20(HYBR).approve(votingEscrow, type(uint256).max);
        uint256 lockTime = HybraTimeLibrary.MAX_LOCK_DURATION;
        
        // Create lock with initial amount
        veTokenId = IVotingEscrow(votingEscrow).create_lock_for(initialAmount, lockTime, address(this));
        
    }
    
    /**
     * @notice Calculate shares to mint based on deposit amount
     */
    function calculateShares(uint256 amount) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        uint256 _totalAssets = totalAssets();
        if (_totalSupply == 0 || _totalAssets == 0) {
            return amount;
        }
        return (amount * _totalSupply) / _totalAssets;
    }
    
    /**
     * @notice Calculate HYBR value of shares
     */
    function calculateAssets(uint256 shares) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            return shares;
        }
        return (shares * totalAssets()) / _totalSupply;
    }

    
    /**
     * @notice Get total assets (HYBR) locked in veNFT
     * @dev Returns actual HYBR amount, not voting power
     */
    function totalAssets() public view returns (uint256) {
        if (veTokenId == 0) {
            return 0;
        }
        // Get actual locked HYBR amount, not voting power
        IVotingEscrow.LockedBalance memory locked = IVotingEscrow(votingEscrow).locked(veTokenId);
        return uint256(int256(locked.amount));
    }
    
    /**
     * @notice Add transfer lock for new deposits
     */
    function _addTransferLock(address user, uint256 amount) internal {
        uint256 len = userLocks[user].length;
        // gas optimization
        require(len < maxLocks, "too many locks");
        
        uint256 unlockTime = block.timestamp + transferLockPeriod;
        userLocks[user].push(UserLock({
            amount: amount,
            unlockTime: unlockTime
        }));
        lockedBalance[user] += amount;
    }
    


    /**
     * @notice Preview available balance (total - currently locked)
     * @param user The user address to check
     * @return available The current available balance for transfer
     */
    function previewAvailable(address user) external view returns (uint256 available) {
        uint256 totalBalance = balanceOf(user);
        uint256 currentLocked = 0;
        
        UserLock[] storage arr = userLocks[user];
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i].unlockTime > block.timestamp) {
                currentLocked += arr[i].amount;
            }
        }
        
        return totalBalance > currentLocked ? totalBalance - currentLocked : 0;
    }
    /**
     * @notice Clean expired locks and update locked balance
     * @param user The user address to clean locks for
     * @return freed The amount of tokens freed from expired locks
     */
    function _cleanExpired(address user) internal returns (uint256 freed) {
        UserLock[] storage arr = userLocks[user];
        uint256 len = arr.length;
        if (len == 0) return 0;

        uint256 write = 0;
        unchecked {
            for (uint256 i = 0; i < len; i++) {
                UserLock memory L = arr[i];
                if (L.unlockTime <= block.timestamp) {
                    freed += L.amount;
                } else {
                    if (write != i) arr[write] = L;
                    write++;
                }
            }
            if (freed > 0) {
                lockedBalance[user] -= freed;
            }
            while (arr.length > write) {
                arr.pop();
            }
        }
    }
    
    
    /**
     * @notice Override transfer to implement lock mechanism
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        
        if (from != address(0) && to != address(0)) { // Not mint or burn
            uint256 totalBalance = balanceOf(from);
            
            // Step 1: Check current available balance using cached lockedBalance
            uint256 currentAvailable = totalBalance > lockedBalance[from] ? totalBalance - lockedBalance[from] : 0;
            
            // Step 2: If current available >= amount, pass directly
            if (currentAvailable >= amount) {
                return;
            }
            
            // Step 3: Not enough, clean expired locks and recalculate
            _cleanExpired(from);
            uint256 finalAvailable = totalBalance > lockedBalance[from] ? totalBalance - lockedBalance[from] : 0;
            
            // Step 4: Check final available balance
            require(finalAvailable >= amount, "Tokens locked");
        }
    }
    
    /**
     * @notice Claim all rewards from voting and rebase
     */
    function claimRewards() external onlyOperator {
        require(voter != address(0), "Voter not set");
        require(rewardsDistributor != address(0), "Distributor not set");
              
        // Claim rebase rewards from RewardsDistributor
        uint256  rebaseAmount = IRewardsDistributor(rewardsDistributor).claim(veTokenId);
        rebase += rebaseAmount;
        // Claim bribes from voted pools
        address[] memory votedPools = IVoter(voter).getPoolVotes(veTokenId);
        
        for (uint256 i = 0; i < votedPools.length; i++) {
            if (votedPools[i] != address(0)) {
                address gauge = IGaugeManager(gaugeManager).gauges(votedPools[i]);
                
                if (gauge != address(0)) {
                    // Prepare arrays for single bribe claim
                    address[] memory bribes = new address[](1);
                    address[][] memory tokens = new address[][](1);
                    
                    // Claim internal bribe (trading fees)
                    address internalBribe = IGaugeManager(gaugeManager).internal_bribes(gauge);
                    if (internalBribe != address(0)) {
                        uint256 tokenCount = IBribe(internalBribe).rewardsListLength();
                        if (tokenCount > 0) {
                            address[] memory bribeTokens = new address[](tokenCount);
                            for (uint256 j = 0; j < tokenCount; j++) {
                                bribeTokens[j] = IBribe(internalBribe).bribeTokens(j);
                            }
                            bribes[0] = internalBribe;
                            tokens[0] = bribeTokens;
                            // Call claimBribes for this single bribe
                            IGaugeManager(gaugeManager).claimBribes(bribes, tokens, veTokenId);
                        }
                    }
                    
                    // Claim external bribe
                    address externalBribe = IGaugeManager(gaugeManager).external_bribes(gauge);
                    if (externalBribe != address(0)) {
                        uint256 tokenCount = IBribe(externalBribe).rewardsListLength();
                        if (tokenCount > 0) {
                            address[] memory bribeTokens = new address[](tokenCount);
                            for (uint256 j = 0; j < tokenCount; j++) {
                                bribeTokens[j] = IBribe(externalBribe).bribeTokens(j);
                            }
                            bribes[0] = externalBribe;
                            tokens[0] = bribeTokens;
                            // Call claimBribes for this single bribe
                            IGaugeManager(gaugeManager).claimBribes(bribes, tokens, veTokenId);
                        }
                    }
                }
            }
        }
    }
    
 

    /**
     * @notice Execute swap through the configured swapper module
     * @param _params Swap parameters for the swapper module
     */
    function executeSwap(ISwapper.SwapParams calldata _params) external nonReentrant onlyOperator {
        require(address(swapper) != address(0), "Swapper not set");

        // Get token balance before swap
        uint256 tokenBalance = IERC20(_params.tokenIn).balanceOf(address(this));
        require(tokenBalance >= _params.amountIn, "Insufficient token balance");

        // Approve swapper to spend tokens
        IERC20(_params.tokenIn).safeApprove(address(swapper), _params.amountIn);

        // Execute swap through swapper module
        uint256 hybrReceived = swapper.swapToHYBR(_params);

        // Reset approval for safety
        IERC20(_params.tokenIn).safeApprove(address(swapper), 0);

        // HYBR is now in this contract, ready for compounding
        votingYield += hybrReceived;
    }
    
    /**
     * @notice Compound HYBR balance into veNFT (restricted to authorized users)
     */
    function compound() external onlyOperator {
        
        // Get current HYBR balance
        uint256 hybrBalance = IERC20(HYBR).balanceOf(address(this));
        
        if (hybrBalance > 0) {
            // Lock all HYBR to existing veNFT  
            IERC20(HYBR).safeApprove(votingEscrow, hybrBalance);
            IVotingEscrow(votingEscrow).deposit_for(veTokenId, hybrBalance);

            // Extend lock to maximum duration
            _extendLockToMax();

            lastCompoundTime = block.timestamp;

            emit Compound(hybrBalance, totalAssets());
        }
    }
    
    /**
     * @notice Vote for gauges using the veNFT
     * @param _poolVote Array of pools to vote for
     * @param _weights Array of weights for each pool
     */
    function vote(address[] calldata _poolVote, uint256[] calldata _weights) external {
        require(msg.sender == owner() || msg.sender == operator, "Not authorized");
        require(voter != address(0), "Voter not set");
        
        IVoter(voter).vote(veTokenId, _poolVote, _weights);
        lastVoteEpoch = HybraTimeLibrary.epochStart(block.timestamp);
        
    }
    
    /**
     * @notice Reset votes
     */
    function reset() external {
        require(msg.sender == owner() || msg.sender == operator, "Not authorized");
        require(voter != address(0), "Voter not set");
        
        IVoter(voter).reset(veTokenId);
    }
    
    /**
     * @notice Receive penalty rewards from rHYBR conversions
     */
    function receivePenaltyReward(uint256 amount) external {
        
        // Auto-compound penalty rewards to existing veNFT
        if (amount > 0) {
            IERC20(HYBR).approve(votingEscrow, amount);

            if(veTokenId == 0){
                _initializeVeNFT(amount);
            } else{
                IVotingEscrow(votingEscrow).deposit_for(veTokenId, amount);

                // Extend lock to maximum duration
                _extendLockToMax();
            }
        }
        penalty += amount;
        emit PenaltyRewardReceived(amount);
    }
       
    /**
     * @notice Set the voter contract
     */
    function setVoter(address _voter) external onlyOwner {
        require(_voter != address(0), "Invalid voter");  
        voter = _voter;
        emit VoterSet(_voter);
    }
    
    /**
     * @notice Update transfer lock period
     */
    function setTransferLockPeriod(uint256 _period) external onlyOwner {
        require(_period >= MIN_LOCK_PERIOD && _period <= MAX_LOCK_PERIOD, "Invalid period");
        uint256 oldPeriod = transferLockPeriod;
        transferLockPeriod = _period;
        emit TransferLockPeriodUpdated(oldPeriod, _period);
    }

    /**
     * @notice Set withdraw fee (in basis points)
     * @param _fee Fee amount (10-30 basis points)
     */
    function setWithdrawFee(uint256 _fee) external onlyOwner {
        require(_fee >= MIN_WITHDRAW_FEE && _fee <= MAX_WITHDRAW_FEE, "Invalid fee");
        withdrawFee = _fee;
    }


    function setHeadNotWithdrawTime(uint256 _time) external onlyOwner {
        head_not_withdraw_time = _time;
    }

    function setTailNotWithdrawTime(uint256 _time) external onlyOwner {
        tail_not_withdraw_time = _time;
    }
    
    /**
     * @notice Set the swapper module
     * @param _swapper Address of the swapper module
     */
    function setSwapper(address _swapper) external onlyOwner {
        require(_swapper != address(0), "Invalid swapper");
        address oldSwapper = address(swapper);
        swapper = ISwapper(_swapper);
        emit SwapperUpdated(oldSwapper, _swapper);
    }
    
    /**
     * @notice Set the team address
     */
    function setTeam(address _team) external onlyOwner {
        require(_team != address(0), "Invalid team");
        Team = _team;
    }
    
    /**
     * @notice Emergency unlock for a user (owner only)
     */
    function emergencyUnlock(address user) external onlyOperator {
        delete userLocks[user];
        lockedBalance[user] = 0;
        emit EmergencyUnlock(user);
    }

    /**
     * @notice Get user's locks info
     */
    function getUserLocks(address user) external view returns (UserLock[] memory) {
        return userLocks[user];
    }
    
    
 
    
  
    
    /**
     * @notice Set operator address
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Invalid operator");
        address oldOperator = operator;
        operator = _operator;
        emit OperatorUpdated(oldOperator, _operator);
    }
    



    
    /**
     * @notice Get veNFT lock end time
     */
    function getLockEndTime() external view returns (uint256) {
        if (veTokenId == 0) {
            return 0;
        }
        IVotingEscrow.LockedBalance memory locked = IVotingEscrow(votingEscrow).locked(veTokenId);
        return uint256(locked.end);
    }

    /**
     * @notice Internal helper to safely extend lock to maximum duration
     * @dev Calculates exact duration needed to reach max allowed unlock time
     */
    function _extendLockToMax() internal {
        if (veTokenId == 0) return;

        IVotingEscrow.LockedBalance memory locked = IVotingEscrow(votingEscrow).locked(veTokenId);
        if (locked.isPermanent || locked.end <= block.timestamp) return;

        uint256 maxUnlockTime = ((block.timestamp + HybraTimeLibrary.MAX_LOCK_DURATION) / HybraTimeLibrary.WEEK) * HybraTimeLibrary.WEEK;

        // Only extend if difference is more than 2 hours
        if (maxUnlockTime > locked.end + 2 hours) {
            try IVotingEscrow(votingEscrow).increase_unlock_time(veTokenId, HybraTimeLibrary.MAX_LOCK_DURATION) {
                // Extension successful
            } catch {
                // Extension failed, continue without error
                // This can happen if already at max possible time or other constraints
            }
        }
    }

}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVotingEscrow {

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
        uint256 permanent;
    }

    struct LockedBalance {
        int128 amount;
        uint end;
        bool isPermanent;
    }

    function create_lock_for(uint _value, uint _lock_duration, address _to) external returns (uint);

    function locked(uint id) external view returns(LockedBalance memory);
    function tokenOfOwnerByIndex(address _owner, uint _tokenIndex) external view returns (uint);

    function token() external view returns (address);
    function team() external returns (address);
    function epoch() external view returns (uint);
    function point_history(uint loc) external view returns (Point memory);
    function user_point_history(uint tokenId, uint loc) external view returns (Point memory);
    function permanentLockBalance() external view returns (uint256);
    function user_point_epoch(uint tokenId) external view returns (uint);

    function ownerOf(uint) external view returns (address);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function transferFrom(address, address, uint) external;

    function voted(uint) external view returns (bool);
    function attachments(uint) external view returns (uint);
    function voting(uint tokenId) external;
    function abstain(uint tokenId) external;
    function attach(uint tokenId) external;
    function detach(uint tokenId) external;
    function approve(address _approved, uint _tokenId) external;

    function checkpoint() external;
    function deposit_for(uint tokenId, uint value) external;

    function balanceOfNFT(uint _id) external view returns (uint);
    function balanceOfNFTAt(uint _tokenId, uint _t) external view returns (uint);
    function balanceOf(address _owner) external view returns (uint);
    function totalSupply() external view returns (uint);
    function totalSupplyAtT(uint256 _t) external view returns (uint);
    function supply() external view returns (uint);

    function avm() external view returns (address);

    function decimals() external view returns(uint8);


    function lockPermanent(uint _tokenId) external;

    function unlockPermanent(uint _tokenId) external;


    function increase_unlock_time(uint _tokenId, uint _lock_duration) external;

    function multiSplit(uint _tokenId, uint[] memory _amounts) external returns (uint[] memory);

    function safeTransferFrom(address _from, address _to, uint _tokenId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoter {

    function _ve() external view returns (address);
    function factories() external view returns(address[] memory);
    function usedWeights(uint id) external view returns(uint);
    function lastVoted(uint id) external view returns(uint);
    function poolVote(uint id, uint _index) external view returns(address _pair);
    function votes(uint id, address _pool) external view returns(uint votes);
    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;
    function poolVoteLength(uint tokenId) external view returns(uint);
    function lastVotedTimestamp(uint id) external view returns(uint);
    function length() external view returns (uint);
    function weights(address _pool) external view returns(uint);
    function poke(uint256 _tokenId) external;
    function getEpochGovernor() external view returns (address);
    function setEpochGovernor(address _epochGovernor) external;
    function reset(uint256 _tokenId) external;
    function totalWeight() external returns (uint256);
    function getPoolVotes(uint tokenId) external view returns(address[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IBribe {
    function deposit(uint amount, uint tokenId) external;
    function withdraw(uint amount, uint tokenId) external;
    function getRewardForAddress(address _owner, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint amount) external;
    function left(address token) external view returns (uint);
    function getReward(uint tokenId, address[] memory tokens) external;
    function bribeTokens(uint256 i) external view returns(address); 
    function rewardsListLength() external view returns (uint256);
    function tokenRewardsPerEpoch(address _token, uint256 epochStart) external view returns(uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRewardsDistributor {
    function checkpoint_token() external;
    function voting_escrow() external view returns(address);
    function claimable(uint _tokenId) external view returns (uint);
    function claim(uint _tokenId) external returns (uint);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGaugeManager {
    
    struct FarmingParam {
        address farmingCenter;
        address algebraEternalFarming;
        address nfpm;
    }

    function fetchInternalBribeFromPool(address _pool) external returns (address);
    function fetchExternalBribeFromPool(address _pool) external returns (address);
    function isGaugeAliveForPool(address _pool) external returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distributeAll() external;
    function distributeFees() external;
    function minter() external view returns(address);
    function createGauge(address _pool, uint256 _gaugeType) external returns (address _gauge, address _internal_bribe, address _external_bribe);
    function gauges(address _pair) external view returns (address);
    function isGauge(address _gauge) external view returns (bool);
    function poolForGauge(address _gauge) external view returns (address);
    function internal_bribes(address _gauge) external view returns (address);
    function external_bribes(address _gauge) external view returns (address);
    function pools(uint256 i) external view returns(address);
    function pools() external view returns(address[] memory);
    function getHybraGovernor() external view returns (address);
    function setHybraGovernor(address _blackGovernor) external;
    function acceptAlgebraFeeChangeProposal (uint16 newAlgebraFee) external;
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external;
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @title ISwapper
 * @notice Interface for modular swap functionality
 * @dev Allows GovernanceHYBR to use different swap implementations
 */
interface ISwapper {
    /**
     * @notice Swap parameters for aggregator calls
     */
    struct SwapParams {
        address aggregator;     // Aggregator contract address
        address tokenIn;        // Input token address
        uint256 amountIn;       // Input token amount
        uint256 minAmountOut;   // Minimum HYBR expected
        bytes callData;         // Aggregator call data
    }

    /**
     * @notice Event emitted when aggregator whitelist is updated
     */
    event AggregatorWhitelisted(address indexed aggregator, bool whitelisted);

    /**
     * @notice Event emitted when a swap is executed
     */
    event SwappedToHYBR(
        address indexed executor,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 hybrOut
    );

    /**
     * @notice Event emitted when authorized caller is updated
     */
    event AuthorizedCallerUpdated(address indexed oldCaller, address indexed newCaller);

    /**
     * @notice Swap tokens to HYBR via aggregator with slippage protection
     * @param params Swap parameters including aggregator and calldata
     * @return hybrReceived Amount of HYBR received
     */
    function swapToHYBR(SwapParams calldata params) external returns (uint256 hybrReceived);

    /**
     * @notice Set aggregator whitelist status
     * @param aggregator Aggregator contract address
     * @param whitelisted Whether to whitelist or not
     */
    function setAggregatorWhitelist(address aggregator, bool whitelisted) external;

    /**
     * @notice Check if an aggregator is whitelisted
     * @param aggregator Aggregator address to check
     * @return whitelisted Whether the aggregator is whitelisted
     */
    function isWhitelistedAggregator(address aggregator) external view returns (bool whitelisted);

    /**
     * @notice Get the HYBR token address
     * @return hybr The HYBR token address
     */
    function HYBR() external view returns (address hybr);




    /**
     * @notice Emergency withdraw stuck tokens
     * @param token Token address to withdraw
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external;
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

library HybraTimeLibrary {

    // for testnet
    uint256 internal constant WEEK = 1 weeks;
    uint internal constant NO_VOTING_WINDOW = 3600;
    uint256 internal constant MAX_LOCK_DURATION = 86400 * 365 * 2;
    uint256 internal constant GENESIS_STAKING_MATURITY_TIME = 2 * 86400;
    uint256 internal constant NO_GENESIS_DEPOSIT_WINDOW = 600;

    // uint256 internal constant WEEK = 7 * 86400;
    // uint internal constant NO_VOTING_WINDOW = 3600;
    // uint256 internal constant MAX_LOCK_DURATION = 86400 * 365 * 4;
    // uint256 internal constant GENESIS_STAKING_MATURITY_TIME = 180 * 86400;
    // uint256 internal constant NO_GENESIS_DEPOSIT_WINDOW = 3 * 3600;

    /// @dev Returns start of epoch based on current timestamp
    function epochStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK);
        }
    }

    /// @dev Returns start of next epoch / end of current epoch
    function epochNext(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK;
        }
    }

    /// @dev Returns start of voting window
    function epochVoteStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + NO_VOTING_WINDOW;
        }
    }

    /// @dev Returns end of voting window / beginning of unrestricted voting window
    function epochVoteEnd(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK - NO_VOTING_WINDOW;
        }
    }

    /// @dev Returns the status if it is the last hour of the epoch
    function isLastHour(uint256 timestamp) internal pure returns (bool) {
        // return block.timestamp % 7 days >= 6 days + 23 hours;
        return timestamp >= HybraTimeLibrary.epochVoteEnd(timestamp) 
        && timestamp < HybraTimeLibrary.epochNext(timestamp);
    }

    /// @dev Returns duration in multiples of epoch
    function epochMultiples(uint256 duration) internal pure returns (uint256) {
        unchecked {
            return (duration / WEEK) * WEEK;
        }
    }

    /// @dev Returns duration in multiples of epoch
    function isLastEpoch(uint256 timestamp, uint256 endTime) internal pure returns (bool) {
        unchecked {
            return  endTime - WEEK <= timestamp && timestamp < endTime;
        }
    }

    /// @dev Returns duration in multiples of epoch
    function prevPreEpoch(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return  epochStart(timestamp) - NO_GENESIS_DEPOSIT_WINDOW;
        }
    }

    /// @dev Returns duration in multiples of epoch
    function currPreEpoch(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return  epochNext(timestamp) - NO_GENESIS_DEPOSIT_WINDOW;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}
