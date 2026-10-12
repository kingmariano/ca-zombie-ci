// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IBank.sol";
import "./interfaces/IDistributionToDelegators.sol";
import "./interfaces/IFlareContractRegistry.sol";
import "./interfaces/IRewardManager.sol";
import "./interfaces/IWNat.sol";

/// @custom:oz-upgrades-from src/Bank.sol:Bank
contract Bank is IBank, Initializable, AccessControlUpgradeable {
    bytes32 public constant BANK_ADMIN = keccak256("BANK_ADMIN");
    bytes32 public constant AMBASSADOR = keccak256("AMBASSADOR");
    IFlareContractRegistry public constant flareContractRegistry =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IWNat internal immutable wnat;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bool internal immutable IS_CHAIN_WITH_MONTHLY_REWARDS;
    string public constant VERSION = "0.1.3";

    address payable public teamAddress;
    address payable public feeReceiverAddress;

    uint8 public constant decimals = 18;
    /**
        @dev From each operation for buy/sell/transfer 1% fee will be charged and
        distibuted for dividends, team fees, and fee receiver
     */
    uint256 constant TRANSFER_FEE = 1_00; // 1%
    uint256 constant DIVIDEND_FEE = 10_00; // 1%
    uint256 constant FEE_RECEIVER_FEE_SHARE = 5_00; // 5%
    uint256 constant TEAM_FEE_SHARE = 15_00; // 15%
    uint256 constant REFERRAL_SHARE = 30_00; // 30%
    uint256 constant MAX_BIPS = 100_00; // 10%
    uint256 internal constant TOKEN_PRICE_INITIAL = 1 ether;
    uint256 internal constant TOKEN_PRICE_INCREMENTAL = 0.01 ether;
    uint256 internal constant ETHER_INCEREMENT = 10000 ether;

    uint256 internal _tokenSupply;
    /**
        @dev BANK token balances
     */
    mapping(address => uint256) _balances;
    /**
        @dev Eth bonus for referral program
     */
    mapping(address => uint256) _refferralBalance;
    /**
        @dev Eth amount possible to withdraw or reinvest
     */
    mapping(address => uint256) _payouts;
    mapping(address => uint256) internal _ambassadorAccumulatedQuota;

    string public name;
    string public symbol;

    uint256 public unclaimedTeamFees;
    uint256 public unclaimedFeeReceiverFees;

    uint256 internal constant MAX_BUY = 50001 ether;

    // ambassador program
    uint256 internal constant AMBASSADOR_MAX_PURCHASE = 1000000 ether;
    uint256 internal constant AMBASSADOR_QUOTA = 2000000 ether;

    // when this is set to true, only ambassadors can purchase tokens (this prevents a whale premine, it ensures a fairly distributed upper pyramid)
    bool public onlyAmbassadors;

    /**
        @notice Earned dividends per token
     */
    uint256 public dividendGrowthX64;
    /**
        @notice Total unclaimed dividend, for price accounting
     */
    uint256 public unclaimedDividendTotal;
    /**
        @notice Last value of dividendGrowthX64 for token holder
     */
    mapping(address => uint256) public userDividendGrowthX64Last;

    ITsoRewardsClaimer public delegator;
    bool public autoClaimTsoRewards;
    uint24 public nextClaimEpoch;
    uint256 public nextClaimMonth;

    mapping(address => mapping(address => uint256)) private _allowances;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        wnat = IWNat(flareContractRegistry.getContractAddressByName("WNat"));
        uint256 chainId = block.chainid;
        IS_CHAIN_WITH_MONTHLY_REWARDS = chainId == 14 || chainId == 114;
    }

    function initialize(
        address _owner,
        address _teamAddress,
        address _feeReceiverAddress,
        address _delegator,
        address[] memory _delegates,
        uint256[] memory _bips
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(BANK_ADMIN, msg.sender);
        _grantRole(AMBASSADOR, msg.sender);

        feeReceiverAddress = payable(_feeReceiverAddress);
        teamAddress = payable(_teamAddress);

        name = "FLRBank";
        symbol = "BANK";
        onlyAmbassadors = true;

        delegator = ITsoRewardsClaimer(_delegator);
        autoClaimTsoRewards = true;
        address rewardManagerAddress = _getRewardManagerAddress();
        if (rewardManagerAddress != address(0)) {
            nextClaimEpoch =
                IRewardManager(rewardManagerAddress).getCurrentRewardEpochId() +
                1;
        }
        _delegate(_delegates, _bips);
        if (IS_CHAIN_WITH_MONTHLY_REWARDS) {
            nextClaimMonth = _getDistributionToDelegators().getCurrentMonth();
        }
    }

    /**
     * Receive function to handle ethereum that was send straight to the contract
     * Unfortunately we cannot use a referral address this way.
     * TSO rewards are sent in form of Wnat tokens and not native token
     */
    receive() external payable {
        buy(address(0));
    }

    modifier onlyBagholders() {
        require(balanceOf(msg.sender) > 0, "No tokens owned");
        _;
    }

    modifier onlyStronghands() {
        require(dividendsOf(msg.sender, true) > 0, "No dividends");
        _;
    }

    modifier antiEarlyWhale(uint256 _amountOfEthereum) {
        address _customerAddress = msg.sender;
        if (onlyAmbassadors) {
            if (wnat.balanceOf(address(this)) <= AMBASSADOR_QUOTA) {
                require(
                    hasRole(AMBASSADOR, _customerAddress) &&
                        (_ambassadorAccumulatedQuota[_customerAddress] +
                            _amountOfEthereum) <=
                        AMBASSADOR_MAX_PURCHASE,
                    "Early whale protection"
                );
                _ambassadorAccumulatedQuota[
                    _customerAddress
                ] += _amountOfEthereum;
            } else {
                onlyAmbassadors = false;
            }
        }
        _;
    }

    function setAdministrator(address _newAdmin, bool _status)
        external
        onlyRole(BANK_ADMIN)
    {
        require(_newAdmin != address(0), "Invalid fee receiver address");
        if (_status) {
            _grantRole(BANK_ADMIN, _newAdmin);
        } else {
            _revokeRole(BANK_ADMIN, _newAdmin);
        }
    }

    function setDelegator(address _delegator) external onlyRole(BANK_ADMIN) {
        require(address(_delegator) != address(0), "Invalid delegator");
        require(address(delegator) != _delegator, "Same delegator");
        delegator = ITsoRewardsClaimer(_delegator);
        emit DelegatorChanged(_delegator);
    }

    function setTeamAddress(address payable _teamAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_teamAddress != address(0), "Invalid team address");
        teamAddress = _teamAddress;
        emit TeamAddressChanged(_teamAddress);
    }

    function setFeeReceiverAddress(address payable _feeReceiverAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _feeReceiverAddress != address(0),
            "Invalid fee receiver address"
        );
        feeReceiverAddress = _feeReceiverAddress;
        emit FeeReceiverChanged(_feeReceiverAddress);
    }

    function addAmbassador(address _identifier) external onlyRole(BANK_ADMIN) {
        require(_identifier != address(0), "Invalid ambassador");
        _grantRole(AMBASSADOR, _identifier);
        emit AmbassadorAdded(_identifier);
    }

    function removeAmbassador(address _identifier)
        external
        onlyRole(BANK_ADMIN)
    {
        require(_identifier != address(0), "Invalid ambassador");
        _revokeRole(AMBASSADOR, _identifier);
        emit AmbassadorRemoved(_identifier);
    }

    function claimTeamFees() external onlyRole(BANK_ADMIN) {
        require(unclaimedTeamFees > 0, "No unclaimed team fees");
        wnat.transfer(teamAddress, unclaimedTeamFees);
        unclaimedTeamFees = 0;
    }

    function claimFeeReceiverFees() external onlyRole(BANK_ADMIN) {
        require(unclaimedFeeReceiverFees > 0, "No unclaimed fee receiver fees");
        wnat.transfer(feeReceiverAddress, unclaimedFeeReceiverFees);
        unclaimedFeeReceiverFees = 0;
    }

    function disableInitialStage() external onlyRole(BANK_ADMIN) {
        onlyAmbassadors = false;
    }

    function setName(string memory _name) external onlyRole(BANK_ADMIN) {
        name = _name;
    }

    function setSymbol(string memory _symbol) external onlyRole(BANK_ADMIN) {
        symbol = _symbol;
    }

    function toggleAutoClaimTsoRewards() external onlyRole(BANK_ADMIN) {
        autoClaimTsoRewards = !autoClaimTsoRewards;
    }

    function delegate(address[] memory _delegates, uint256[] memory _bips)
        external
        onlyRole(BANK_ADMIN)
    {
        _delegate(_delegates, _bips);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenSupply;
    }

    function buy(address referredBy) public payable override returns (uint256) {
        require(msg.value > 0, "You need to send some Ether");
        require(
            msg.value < MAX_BUY,
            "Exceeded maximum buy amount of 50000 NAT"
        );

        uint256 tokens = purchaseTokens(msg.value, referredBy);

        wnat.deposit{ value: msg.value }();
        emit TokenPurchase(msg.sender, referredBy, msg.value, tokens);

        return tokens;
    }

    function buy(uint256 amount, address referredBy)
        external
        override
        returns (uint256)
    {
        require(amount < MAX_BUY, "Exceeded maximum buy amount of 50000 NAT");

        uint256 tokens = purchaseTokens(amount, referredBy);

        wnat.transferFrom(msg.sender, address(this), amount);
        emit TokenPurchase(msg.sender, referredBy, amount, tokens);

        return tokens;
    }

    // Lambo delivery service
    function withdraw() public onlyStronghands {
        address customer = msg.sender;
        _withdraw(customer);
    }

    function _withdraw(address withdrawer) internal {
        uint256 _div = _dividendsEarnedLast(withdrawer);
        uint256 pendingPayout = _payouts[withdrawer];
        uint256 payment = _div + pendingPayout + _refferralBalance[withdrawer];

        _refferralBalance[withdrawer] = 0;
        _payouts[withdrawer] -= pendingPayout;
        userDividendGrowthX64Last[withdrawer] = dividendGrowthX64;

        unclaimedDividendTotal -= payment;
        tryClaimAllTsoRewards();

        wnat.transfer(withdrawer, payment);
        emit Withdraw(withdrawer, payment);
    }

    /**
        @inheritdoc  IBank
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
        @inheritdoc  IBank
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
        @inheritdoc  IBank
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
        @inheritdoc  IBank
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < amount) {
                require(
                    currentAllowance >= amount,
                    "ERC20: insufficient allowance"
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _transfer(
        address from,
        address toAddress,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(toAddress != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: Insufficient balance");

        // First withdraw sender's existing dividends before any state changes
        bool hasFromDividends = dividendsOf(from, true) > 0;
        uint256 totalWithdrawal = 0;

        if (hasFromDividends) {
            uint256 senderDividends = _dividendsEarnedLast(from);
            uint256 senderReferralBalance = _refferralBalance[from];
            uint256 senderPendingPayout = _payouts[from];
            totalWithdrawal =
                senderDividends +
                senderReferralBalance +
                senderPendingPayout;

            _refferralBalance[from] = 0;
            _payouts[from] = 0;
            userDividendGrowthX64Last[from] = dividendGrowthX64;
            unclaimedDividendTotal -= totalWithdrawal;
        }

        uint256 tokenFees = (amount * TRANSFER_FEE) / MAX_BIPS;
        uint256 taxedTokens = amount - tokenFees;
        uint256 totalEth = _tokensToEthereum(amount);
        uint256 dividendsFromTransfer = (totalEth * TRANSFER_FEE) / MAX_BIPS;

        uint256 receiverFees = (dividendsFromTransfer *
            FEE_RECEIVER_FEE_SHARE) / MAX_BIPS;
        uint256 teamFees = (dividendsFromTransfer * TEAM_FEE_SHARE) / MAX_BIPS;
        uint256 publicDividends = dividendsFromTransfer -
            receiverFees -
            teamFees;

        unclaimedFeeReceiverFees += receiverFees;
        unclaimedTeamFees += teamFees;

        _tokenSupply -= tokenFees;

        dividendGrowthX64 += (publicDividends * 2**64) / _tokenSupply;
        unclaimedDividendTotal += publicDividends;

        _payouts[toAddress] += (((dividendGrowthX64 -
            userDividendGrowthX64Last[toAddress]) * _balances[toAddress]) /
            2**64);

        userDividendGrowthX64Last[toAddress] = dividendGrowthX64;

        _balances[from] -= amount;
        _balances[toAddress] += taxedTokens;

        _tryClaimWNatRewards();

        // Send withdrawal to sender if they had dividends
        if (hasFromDividends) {
            wnat.transfer(from, totalWithdrawal);
            emit Withdraw(from, totalWithdrawal);
        }

        emit Transfer(from, toAddress, taxedTokens);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function sell(uint256 amount) public onlyBagholders returns (uint256) {
        require(_balances[msg.sender] >= amount);

        uint256 eth = _tokensToEthereum(amount);
        uint256 toBeDistributed = (eth * DIVIDEND_FEE) / MAX_BIPS;
        uint256 taxedEth = eth - toBeDistributed;

        uint256 receiverFees = (toBeDistributed * FEE_RECEIVER_FEE_SHARE) /
            MAX_BIPS;
        uint256 teamFees = (toBeDistributed * TEAM_FEE_SHARE) / MAX_BIPS;
        uint256 publicDividends = toBeDistributed - receiverFees - teamFees;

        require(taxedEth < MAX_BUY, "Sold over the transaction limit");
        unclaimedFeeReceiverFees += receiverFees;
        unclaimedTeamFees += teamFees;

        _tokenSupply -= amount;

        // include dividends in payout
        uint256 accumulatedDividends = (((dividendGrowthX64 -
            userDividendGrowthX64Last[msg.sender]) * _balances[msg.sender]) /
            2**64);

        _payouts[msg.sender] += accumulatedDividends + taxedEth;

        unclaimedDividendTotal += publicDividends + taxedEth;

        _balances[msg.sender] -= amount;
        userDividendGrowthX64Last[msg.sender] = dividendGrowthX64;

        if (_tokenSupply > 0) {
            dividendGrowthX64 += (publicDividends * 2**64) / _tokenSupply;
        } else {
            // if there is no token supply, that was probably our last user so he can have rest
            _payouts[msg.sender] += publicDividends;
        }

        tryClaimAllTsoRewards();
        emit TokenSell(msg.sender, amount, taxedEth);

        return taxedEth;
    }

    function reinvest() external onlyStronghands {
        address customer = msg.sender;
        uint256 _div = _dividendsEarnedLast(customer);
        userDividendGrowthX64Last[msg.sender] = dividendGrowthX64;
        uint256 tokens = purchaseTokens(_div, address(0x0));

        emit Reinvestment(msg.sender, _div, tokens);
    }

    function exit() external {
        uint256 _userBalance = _balances[msg.sender];

        if (_userBalance > 0) {
            sell(_userBalance);
        }

        withdraw();
    }

    function dividends() public view returns (uint256) {
        return dividendsOf(msg.sender, true);
    }

    function dividendsOf(address user, bool referal)
        public
        view
        returns (uint256)
    {
        uint256 _dividends = _dividendsEarnedLast(user);

        if (referal) {
            _dividends += _refferralBalance[user];
        }

        // include withdrawn balance
        _dividends += _payouts[user];

        return _dividends;
    }

    function calculateTokensReceived(uint256 _ethereumToSpend)
        external
        view
        returns (uint256)
    {
        uint256 _dividends = (_ethereumToSpend * DIVIDEND_FEE) / MAX_BIPS;
        uint256 _taxedEthereum = _ethereumToSpend - _dividends;
        uint256 _amountOfTokens = _ethereumToTokens(_taxedEthereum);

        return _amountOfTokens;
    }

    function calculateEthereumReceived(uint256 _tokensToSell)
        external
        view
        returns (uint256)
    {
        require(_tokensToSell <= _tokenSupply);
        uint256 _ethereum = _tokensToEthereum(_tokensToSell);
        uint256 _dividends = (_ethereum * DIVIDEND_FEE) / MAX_BIPS;
        uint256 _taxedEthereum = _ethereum - _dividends;
        return _taxedEthereum;
    }

    function balanceOf(address _customerAddress) public view returns (uint256) {
        return _balances[_customerAddress];
    }

    function sellPrice() external view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (_tokenSupply == 0) {
            return TOKEN_PRICE_INITIAL;
        } else {
            return _ethereumToTokens(1e18);
        }
    }

    function buyPrice() external view returns (uint256) {
        // our calculation relies on the token supply, so we need supply. Doh.
        if (_tokenSupply == 0) {
            return TOKEN_PRICE_INITIAL;
        } else {
            return _tokensToEthereum(1e18);
        }
    }

    function _getRewardManagerAddress() internal view returns (address) {
        return flareContractRegistry.getContractAddressByName("RewardManager");
    }

    function _delegate(address[] memory _delegates, uint256[] memory _bips)
        internal
    {
        require(
            _delegates.length > 0 && _delegates.length < 3,
            "Invalid number of delegates"
        );
        require(_delegates.length == _bips.length, "Array length mismatch");
        wnat.undelegateAll();
        for (uint256 i; i < _delegates.length; i++) {
            wnat.delegate(_delegates[i], _bips[i]);
        }
    }

    function purchaseTokens(uint256 eth, address referredBy)
        private
        antiEarlyWhale(eth)
        returns (uint256)
    {
        /**
            incoming etherum
            90% - goes into tokens
            10% - taxes
                15% - team fees
                5% - fee receiver
                80% - public dividends
                    30% goes to referral bonus
         */

        uint256 toBeDistributed = (eth * DIVIDEND_FEE) / MAX_BIPS;
        uint256 taxedEth = eth - toBeDistributed;

        uint256 receiverFees = (toBeDistributed * FEE_RECEIVER_FEE_SHARE) /
            MAX_BIPS;
        uint256 teamFees = (toBeDistributed * TEAM_FEE_SHARE) / MAX_BIPS;
        uint256 publicDividends = toBeDistributed - receiverFees - teamFees;
        uint256 referralBonus = 0;

        if (referredBy != address(0x0)) {
            referralBonus = (publicDividends * REFERRAL_SHARE) / MAX_BIPS;
            publicDividends -= referralBonus;
        }

        uint256 boughtTokens = _ethereumToTokens(taxedEth);

        // save existing dividends, using previous balance
        _payouts[msg.sender] += (((dividendGrowthX64 -
            userDividendGrowthX64Last[msg.sender]) * _balances[msg.sender]) /
            2**64);
        userDividendGrowthX64Last[msg.sender] = dividendGrowthX64;

        _balances[msg.sender] += boughtTokens;
        _refferralBalance[referredBy] += referralBonus;
        _tokenSupply += boughtTokens;

        dividendGrowthX64 += (publicDividends * 2**64) / _tokenSupply;
        unclaimedDividendTotal += publicDividends + referralBonus;

        unclaimedFeeReceiverFees += receiverFees;
        unclaimedTeamFees += teamFees;

        tryClaimAllTsoRewards();

        return boughtTokens;
    }

    function claimWNatRewards(uint24 latestClaimRewardEpoch) external {
        address rewardManagerAddress = _getRewardManagerAddress();
        if (rewardManagerAddress == address(0)) {
            return;
        }
        _tryClaimWNatRewards(
            latestClaimRewardEpoch,
            IRewardManager(rewardManagerAddress)
        );

        if (address(delegator) != address(0)) {
            delegator.claimWNatRewards(latestClaimRewardEpoch);
        }
    }

    function claimFlareDrops(uint256 latestClaimMonth) external {
        if (IS_CHAIN_WITH_MONTHLY_REWARDS) {
            IDistributionToDelegators distributionToDelegators = _getDistributionToDelegators();
            _tryClaimMonthlyRewards(
                0,
                latestClaimMonth,
                distributionToDelegators
            );
        }

        if (address(delegator) != address(0)) {
            delegator.claimFlareDrops(latestClaimMonth);
        }
    }

    function tryClaimAllTsoRewards() public {
        if (!autoClaimTsoRewards) {
            return;
        }

        _tryClaimWNatRewards();
        if (IS_CHAIN_WITH_MONTHLY_REWARDS) {
            _tryClaimMonthlyRewards();
        }

        if (address(delegator) != address(0)) {
            delegator.tryClaimAllTsoRewards();
        }
    }

    function _tryClaimWNatRewards() internal {
        address rewardManagerAddress = _getRewardManagerAddress();
        if (rewardManagerAddress == address(0)) {
            return;
        }
        IRewardManager rewardManager = IRewardManager(rewardManagerAddress);

        uint24 latestAvailableRewardEpoch;
        try rewardManager.getRewardEpochIdsWithClaimableRewards() returns (
            uint24,
            uint24 _latestAvailableRewardEpoch
        ) {
            latestAvailableRewardEpoch = _latestAvailableRewardEpoch;
        } catch {
            emit WNatRewardClaimingFailed(nextClaimEpoch);
            return;
        }
        _tryClaimWNatRewards(latestAvailableRewardEpoch, rewardManager);
    }

    function _tryClaimWNatRewards(
        uint24 latestClaimRewardEpoch,
        IRewardManager rewardManager
    ) internal {
        if (nextClaimEpoch == 0) {
            nextClaimEpoch = rewardManager.getCurrentRewardEpochId() + 1;
            return;
        }

        if (latestClaimRewardEpoch >= nextClaimEpoch) {
            for (
                uint24 epoch = nextClaimEpoch;
                epoch <= latestClaimRewardEpoch;
                epoch++
            ) {
                rewardManager.claim(
                    address(this),
                    payable(address(this)),
                    epoch,
                    true,
                    new IRewardManager.RewardClaimWithProof[](0)
                );
            }

            nextClaimEpoch = ++latestClaimRewardEpoch;
            emit WNatRewardClaimingSucceeded(nextClaimEpoch);
        }
    }

    function _tryClaimMonthlyRewards() internal {
        IDistributionToDelegators distributionToDelegators = _getDistributionToDelegators();
        uint256 startMonth;
        uint256 endMonth;

        try distributionToDelegators.getClaimableMonths() returns (
            uint256 _startMonth,
            uint256 _endMonth
        ) {
            startMonth = _startMonth;
            endMonth = _endMonth;
        } catch {
            emit FlareDropsRewardClaimingFailed(nextClaimMonth);
            return;
        }
        _tryClaimMonthlyRewards(startMonth, endMonth, distributionToDelegators);
    }

    function _tryClaimMonthlyRewards(
        uint256 startMonth,
        uint256 latestClaimMonth,
        IDistributionToDelegators distributionToDelegators
    ) internal {
        if (startMonth == 0) {
            try distributionToDelegators.getClaimableMonths() returns (
                uint256 _startMonth,
                uint256
            ) {
                startMonth = _startMonth;
                emit FlareDropsRewardClaimingSucceeded(nextClaimMonth);
            } catch {
                emit FlareDropsRewardClaimingFailed(nextClaimMonth);
                return;
            }
        }

        uint256 _nextClaimMonth = nextClaimMonth; //cache
        if (latestClaimMonth >= _nextClaimMonth) {
            for (
                uint256 month = startMonth > _nextClaimMonth
                    ? startMonth
                    : _nextClaimMonth;
                month <= latestClaimMonth;
                month++
            ) {
                distributionToDelegators.claim(
                    address(this),
                    payable(address(this)),
                    month,
                    true
                );
            }

            nextClaimMonth = ++latestClaimMonth;
        }
    }

    /**
        @dev Dividends earned since last payout 
     */
    function _dividendsEarnedLast(address user) private view returns (uint256) {
        return ((
            ((dividendGrowthX64 - userDividendGrowthX64Last[user]) *
                _balances[user])
        ) / 2**64);
    }

    function _getDistributionToDelegators()
        internal
        view
        returns (IDistributionToDelegators)
    {
        return
            IDistributionToDelegators(
                flareContractRegistry.getContractAddressByName(
                    "DistributionToDelegators"
                )
            );
    }

    function _ethereumToTokens(uint256 _ethereum)
        internal
        view
        returns (uint256)
    {
        uint256 _tokenPrice = _calculateTokenPrice(_ethereum, true);
        return (_ethereum * 1e18) / _tokenPrice;
    }

    function _tokensToEthereum(uint256 _tokens)
        internal
        view
        returns (uint256)
    {
        require(_tokens > 0, "Must sell more than 0 tokens");

        uint256 initialEthBalance = wnat.balanceOf(address(this));
        uint256 taxedEth = initialEthBalance -
            unclaimedDividendTotal -
            unclaimedFeeReceiverFees -
            unclaimedTeamFees;

        // Estimate final ETH balance after removing equivalent ETH for tokens
        uint256 estimatedEthOut = ((taxedEth * _tokens)) / _tokenSupply;

        // Get the worst price (price after all tokens are sold)
        uint256 worstTokenPrice = _calculateTokenPrice(estimatedEthOut, false);

        // Convert all tokens to ETH at the worst price (final price after sale)
        return (_tokens * worstTokenPrice) / 1e18;
    }

    function _calculateTokenPrice(uint256 additionalNat, bool isBuy)
        internal
        view
        returns (uint256)
    {
        if (_tokenSupply == 0) {
            return TOKEN_PRICE_INITIAL;
        }

        uint256 balanceGross;
        if (isBuy) {
            balanceGross = wnat.balanceOf(address(this)) + additionalNat;
        } else {
            balanceGross = wnat.balanceOf(address(this)) > additionalNat
                ? wnat.balanceOf(address(this)) - additionalNat
                : 0;
        }

        if (
            balanceGross <
            (unclaimedFeeReceiverFees +
                unclaimedTeamFees +
                unclaimedDividendTotal)
        ) {
            return TOKEN_PRICE_INITIAL;
        }

        uint256 netWNatBalance = balanceGross -
            unclaimedFeeReceiverFees -
            unclaimedTeamFees -
            unclaimedDividendTotal;

        uint256 increments = netWNatBalance / ETHER_INCEREMENT;
        uint256 adjustedPrice = TOKEN_PRICE_INITIAL +
            (increments * TOKEN_PRICE_INCREMENTAL);

        return adjustedPrice;
    }
}
