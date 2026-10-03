// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/IBalanceOfSphere.sol";
import "./interfaces/IDEXPair.sol";
import "./interfaces/ISphereToken.sol";
import "./interfaces/ISphereSettings.sol";
// import "./SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SphereToken is ERC20Upgradeable, OwnableUpgradeable, ISphereToken {
  // using SafeERC20 for IERC20;

  // *** CONSTANTS ***

  address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address private constant ZERO = 0x0000000000000000000000000000000000000000;
  uint256 private constant DECIMALS = 18;
  uint256 private constant FEE_DENOMINATOR = 1000;
  uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 5 * 10 ** 9 * 10 ** DECIMALS;
  uint256 private constant MAX_INVEST_REMOVABLE_DELAY = 7200;
  uint256 private constant MAX_PARTY_LIST_DIVISOR_RATE = 75;
  uint256 private constant MAX_REBASE_FREQUENCY = 1800;
  uint256 private constant MAX_SUPPLY = type(uint128).max;
  uint256 private constant MAX_UINT256 = type(uint).max;
  uint256 private constant MIN_BUY_AMOUNT_RATE = 500000 * 10 ** 18;
  uint256 private constant MIN_INVEST_REMOVABLE_PER_PERIOD = 1500000 * 10 ** 18;
  uint256 private constant MIN_SELL_AMOUNT_RATE = 500000 * 10 ** 18;
  uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
  uint256 private constant MAX_BRACKET_TAX = 10; // max bracket is holding 10%
  uint256 private constant MAX_PARTY_ARRAY = 491;
  uint256 private constant MAX_TAX_BRACKET_FEE_RATE = 50;

  // *** VARIABLES ***

  ISphereSettings public settings;
  bool public initialDistributionFinished;// = false;
  bool private inSwap;
  uint256 private _totalSupply;
  uint256 public gonsPerFragment;




  // **************

  address[] public makerPairs;
  address[] public partyArray;
  address[] public sphereGamesContracts;
  address[] public subContracts;
  address[] public lpContracts;

  bool private feesOnNormalTransfers;// = true;

  bool public autoRebase;// = true;


  bool public isLiquidityEnabled;// = true;
  bool public isMoveBalance;// = false;
  bool public isSellHourlyLimit;// = true;
  bool public isTaxBracket;// = false;
  bool public isWall;// = false;
  bool public partyTime;// = true;
  bool public swapEnabled;// = true;
  bool public goDeflationary;// = false;

  mapping(address => InvestorInfo) public investorInfoMap;
  mapping(address => bool) public isBuyFeeExempt;
  mapping(address => bool) public isSellFeeExempt;
  mapping(address => bool) public isTotalFeeExempt;
  mapping(address => bool) public canRebase;
  mapping(address => bool) public canSetRewardYield;
  mapping(address => bool) public _disallowedToMove;
  mapping(address => bool) public automatedMarketMakerPairs;
  mapping(address => bool) public partyArrayCheck;
  mapping(address => bool) public sphereGamesCheck;
  mapping(address => bool) public subContractCheck;
  mapping(address => bool) public lpContractCheck;
  mapping(address => uint256) public partyArrayFee;
  mapping(address => mapping(address => uint256)) private _allowedFragments;
  mapping(address => uint256) private _gonBalances;

  uint256 public rewardYieldDenominator;// = 10000000000000000;

  uint256 public investRemovalDelay;// = 3600;
  uint256 public partyListDivisor;// = 50;
  uint256 public rebaseFrequency;// = 1800;
  uint256 public rewardYield;// = 3943560072416;

  uint256 public markerPairCount;//;
  uint256 public index;//;
  uint256 public maxBuyTransactionAmount;// = 500000 * 10 ** 18;
  uint256 public maxSellTransactionAmount;// = 500000 * 10 ** 18;
  uint256 public nextRebase;// = 1647385200;
  uint256 public rebaseEpoch;// = 0;
  uint256 public taxBracketMultiplier;// = 50;
  uint256 public wallDivisor;// = 2;

  address public liquidityReceiver;// = 0x1a2Ce410A034424B784D4b228f167A061B94CFf4;
  address public treasuryReceiver;// = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;
  address public riskFreeValueReceiver;// = 0x826b8d2d523E7af40888754E3De64348C00B99f4;
  address public galaxyBondReceiver;// = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;

  address public sphereSwapper;

  uint256 maxInvestRemovablePerPeriod;// = 1500000 * 10 ** 18;

  // **************



  // constructor() ERC20Detailed('Sphere Finance', 'SPHERE', uint8(DECIMALS)) {}

  // *** RESTRICTIONS ***

  modifier swapping() {
    inSwap = true;
    _;
    inSwap = false;
  }

  modifier validRecipient(address to) {
    require(to != address(0x0), 'recipient is not valid');
    _;
  }

  function init() public initializer {
    __Ownable_init();
    __ERC20_init('Sphere Finance', 'SPHERE');

    feesOnNormalTransfers = true;
    autoRebase = true;
    isLiquidityEnabled = true;
    isMoveBalance = false;
    isSellHourlyLimit = true;
    isTaxBracket = false;
    isWall = false;
    partyTime = true;
    swapEnabled = true;
    goDeflationary = false;
    rewardYieldDenominator = 10000000000000000;
    investRemovalDelay = 3600;
    partyListDivisor = 50;
    rebaseFrequency = 1800;
    rewardYield = 3943560072416;
    maxBuyTransactionAmount = 500000 * 10 ** 18;
    maxSellTransactionAmount = 500000 * 10 ** 18;
    nextRebase = 1647385200;
    rebaseEpoch = 0;
    taxBracketMultiplier = 50;
    wallDivisor = 2;
    liquidityReceiver = 0x1a2Ce410A034424B784D4b228f167A061B94CFf4;
    treasuryReceiver = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;
    riskFreeValueReceiver = 0x826b8d2d523E7af40888754E3De64348C00B99f4;
    galaxyBondReceiver = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;
    maxInvestRemovablePerPeriod = 1500000 * 10 ** 18;

    _allowedFragments[address(this)][address(this)] = type(uint256).max;

    _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
    _gonBalances[msg.sender] = TOTAL_GONS;
    gonsPerFragment = TOTAL_GONS / (_totalSupply);

    isTotalFeeExempt[treasuryReceiver] = true;
    isTotalFeeExempt[sphereSwapper] = true;
    isTotalFeeExempt[address(this)] = true;
    isTotalFeeExempt[msg.sender] = true;
    index = 1e18 * gonsPerFragment;

    setWhitelistSetters(msg.sender, true, 1);
    setWhitelistSetters(msg.sender, true, 2);

    emit Transfer(address(0x0), msg.sender, _totalSupply);
  }

  //***********************************************************
  //******************** ERC20 ********************************
  //***********************************************************

  //gets every token in circulation no matter where
  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  //how much a user is allowed to transfer from own address to another one
  function allowance(address owner_, address spender)
  public
  view
  override
  returns (uint256)
  {
    return _allowedFragments[owner_][spender];
  }

  //get balance of user
  function balanceOf(address who) public view override returns (uint256) {
    if (gonsPerFragment == 0) {
      return 0;
    }
    return _gonBalances[who] / (gonsPerFragment);
  }


  //transfer from one valid to another
  function transfer(address to, uint256 value)
  public
  override
  validRecipient(to)
  returns (bool)
  {
    _transferFrom(msg.sender, to, value);
    return true;
  }

  //basic transfer from one wallet to the other
  function _basicTransfer(
    address from,
    address to,
    uint256 amount
  ) internal returns (bool) {
    uint256 gonAmount = amount * (gonsPerFragment);
    _gonBalances[from] = _gonBalances[from] - (gonAmount);
    _gonBalances[to] = _gonBalances[to] + (gonAmount);

    emit Transfer(from, to, amount);

    return true;
  }

  //inherent transfer function that calculates the taxes and the limits
  //limits like sell per hour, party array check
  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    bool excludedAccount = isTotalFeeExempt[sender] ||
    isTotalFeeExempt[recipient];

    require(initialDistributionFinished || excludedAccount, 'Trade off');

    if (automatedMarketMakerPairs[recipient] && !excludedAccount) {
      require(amount <= maxSellTransactionAmount, 'Too much sell');
    }

    if (
      automatedMarketMakerPairs[recipient] &&
      !excludedAccount &&
      partyArrayCheck[sender] &&
      partyTime
    ) {
      require(
        amount <= (maxSellTransactionAmount / (partyListDivisor)),
        'party div'
      );
    }

    if (automatedMarketMakerPairs[sender] && !excludedAccount) {
      require(amount <= maxBuyTransactionAmount, 'too much buy');
    }

    if (
      automatedMarketMakerPairs[recipient] &&
      !excludedAccount &&
      isSellHourlyLimit
    ) {
      InvestorInfo storage investor = investorInfoMap[sender];
      //Make sure they can't withdraw too often.
      Withdrawal[] storage withdrawHistory = investor.withdrawHistory;
      uint256 authorizedWithdraw = (maxInvestRemovablePerPeriod -
      (getLastPeriodWithdrawals(sender)));
      require(amount <= authorizedWithdraw, 'max withdraw');
      withdrawHistory.push(
        Withdrawal({timestamp : block.timestamp, withdrawAmount : amount})
      );
    }

    if (inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    uint256 gonAmount = amount * (gonsPerFragment);

    _gonBalances[sender] = _gonBalances[sender] - (gonAmount);

    uint256 gonAmountReceived = _shouldTakeFee(sender, recipient)
    ? takeFee(sender, recipient, gonAmount)
    : gonAmount;
    _gonBalances[recipient] = _gonBalances[recipient] + (gonAmountReceived);

    if (
      nextRebase <= block.timestamp &&
      autoRebase &&
      !goDeflationary &&
      !automatedMarketMakerPairs[sender] &&
      !automatedMarketMakerPairs[recipient]
    ) {
      _rebase();
      manualSync();
    }

    emit Transfer(
      sender,
      recipient,
      gonAmountReceived / (gonsPerFragment)
    );

    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public override validRecipient(to) returns (bool) {
    if (_allowedFragments[from][msg.sender] != type(uint256).max) {
      _allowedFragments[from][msg.sender] =
      _allowedFragments[from][msg.sender] -
      (value);
    }

    _transferFrom(from, to, value);
    return true;
  }


  function decreaseAllowance(address spender, uint256 subtractedValue)
  public
  override
  returns (bool)
  {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      _allowedFragments[msg.sender][spender] = 0;
    } else {
      _allowedFragments[msg.sender][spender] =
      oldValue -
      (subtractedValue);
    }
    emit Approval(
      msg.sender,
      spender,
      _allowedFragments[msg.sender][spender]
    );
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue)
  public
  override
  returns (bool)
  {
    _allowedFragments[msg.sender][spender] =
    _allowedFragments[msg.sender][spender] -
    (addedValue);
    emit Approval(
      msg.sender,
      spender,
      _allowedFragments[msg.sender][spender]
    );
    return true;
  }

  function approve(address spender, uint256 value)
  public
  override
  returns (bool)
  {
    _allowedFragments[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  // check if the wallet should be taxed or not
  function _shouldTakeFee(address from, address to)
  internal
  view
  returns (bool)
  {
    if (isTotalFeeExempt[from] || isTotalFeeExempt[to]) {
      return false;
    } else if (feesOnNormalTransfers) {
      return true;
    } else {
      return (automatedMarketMakerPairs[from] ||
      automatedMarketMakerPairs[to]);
    }
  }

  //this function iterates through all other contracts that are being part of the Sphere ecosystem
  //we add a new contract like wSPHERE or sSPHERE, whales could technically abuse this
  //by swapping to these contracts and leave the dynamic tax bracket
  function getBalanceContracts(address sender) public view returns (uint256) {
    uint256 userTotal;

    for (uint256 i = 0; i < subContracts.length; i++) {
      userTotal += (IBalanceOfSphere(subContracts[i]).balanceOfSphere(sender));
    }
    for (uint256 i = 0; i < sphereGamesContracts.length; i++) {
      userTotal += (IERC20(sphereGamesContracts[i]).balanceOf(sender));
    }

    return userTotal;
  }

  //calculates circulating supply (dead and zero is not added due to them being phased out of circulation forrever)
  function getCirculatingSupply() external view returns (uint256) {
    return
    (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO] - _gonBalances[treasuryReceiver]) /
    gonsPerFragment;
  }

  function getCurrentTaxBracket(address _address)
  public
  view
  returns (uint256)
  {
    //gets the total balance of the user
    uint256 userTotal = getUserTotalOnDifferentContractsSphere(_address);

    //calculate the percentage
    uint256 totalCap = (userTotal * (100)) / (getTokensInLPCirculation());

    //calculate what is smaller, and use that
    uint256 _bracket = totalCap < MAX_BRACKET_TAX ? totalCap : MAX_BRACKET_TAX;

    //multiply the bracket with the multiplier
    _bracket *= taxBracketMultiplier;

    return _bracket;
  }

  function getTokensInLPCirculation() public view returns (uint256) {
    uint256 LPTotal;

    for (uint256 i = 0; i < lpContracts.length; i++) {
      LPTotal += balanceOf(lpContracts[i]);
    }

    return LPTotal;
  }

  //calculate the users total on different contracts
  function getUserTotalOnDifferentContractsSphere(address sender)
  public
  view
  returns (uint256)
  {
    uint256 userTotal = balanceOf(sender);

    //calculate the balance of different contracts on different wallets and sum them
    return userTotal + (getBalanceContracts(sender));
  }

  //sync every LP to make sure Theft-of-Liquidity can't be arbitraged
  function manualSync() public {
    for (uint256 i = 0; i < makerPairs.length; i++) {
      try IDEXPair(makerPairs[i]).sync() {} catch Error(string memory reason) {
        emit GenericErrorEvent(reason);
      } catch (bytes memory /*lowLevelData*/) {
        emit GenericErrorEvent('manualSync(): _makerPairs.sync() Failed');
      }
    }
  }

  /** @dev Returns the total amount withdrawn by the _address during the last hour **/

  function getLastPeriodWithdrawals(address _address)
  public
  view
  returns (uint256 totalWithdrawLastHour)
  {
    InvestorInfo storage investor = investorInfoMap[_address];

    Withdrawal[] storage withdrawHistory = investor.withdrawHistory;
    for (uint256 i = 0; i < withdrawHistory.length; i++) {
      Withdrawal memory withdraw = withdrawHistory[i];
      if (
        withdraw.timestamp >= (block.timestamp - (investRemovalDelay))
      ) {
        totalWithdrawLastHour =
        totalWithdrawLastHour +
        (withdrawHistory[i].withdrawAmount);
      }
    }

    return totalWithdrawLastHour;
  }

  function takeFee(
    address sender,
    address recipient,
    uint256 gonAmount
  ) internal returns (uint256) {
    ISphereSettings.Fees memory fees = settings.currentFees();
    uint256 _realFee = fees.totalBuyFee;

    if (isWall) {
      _realFee = fees.totalBuyFee / (wallDivisor);
    }

    if (isBuyFeeExempt[sender]) {
      _realFee = 0;
    }

    //check if it's a sell fee embedded
    if (automatedMarketMakerPairs[recipient]) {
      _realFee = fees.totalSellFee;

      //trying to join our party? Become the party maker :)
      if (partyArrayCheck[sender] && partyTime) {
        if (_realFee < partyArrayFee[sender])
          _realFee = partyArrayFee[sender];
      }

      if (isSellFeeExempt[sender]) {
        _realFee = 0;
      }
    }

    if (!automatedMarketMakerPairs[sender]) {
      //calculate Tax
      if (isTaxBracket) {
        _realFee += getCurrentTaxBracket(sender);
      }
    }

    uint256 feeAmount = (gonAmount * (_realFee)) / (FEE_DENOMINATOR);

    if (sphereSwapper != address(0x0)) {
      uint256 amount = feeAmount / gonsPerFragment;
      _gonBalances[sphereSwapper] += feeAmount;
      emit Transfer(sender, sphereSwapper, amount);
    } else {
      _gonBalances[address(this)] = _gonBalances[address(this)] + (feeAmount);
      emit Transfer(sender, address(this), (feeAmount / (gonsPerFragment)));
    }

    return gonAmount - (feeAmount);
  }

  //burn tokens to the dead wallet
  function _tokenBurner(uint256 _tokenAmount) private {
    _transferFrom(address(this), address(DEAD), _tokenAmount);
  }


  function _rebase() private {
    int256 supplyDelta;
    int256 i = 0;
    if (!inSwap) {
      do {
        supplyDelta = int256(
          (_totalSupply * (rewardYield)) / (rewardYieldDenominator)
        );
        _coreRebase(supplyDelta);
        i++;
      }
      while (nextRebase < block.timestamp && i < 100);
      manualSync();
    }
  }

  //rebase everyone
  function _coreRebase(int256 supplyDelta) private returns (uint256) {
    require(nextRebase <= block.timestamp, 'rebase too early');
    uint256 epoch = nextRebase;

    if (supplyDelta == 0) {
      emit LogRebase(epoch, _totalSupply);
      return _totalSupply;
    }

    if (supplyDelta < 0) {
      _totalSupply = _totalSupply - (uint256(- supplyDelta));
    } else {
      _totalSupply = _totalSupply + (uint256(supplyDelta));
    }

    if (_totalSupply > MAX_SUPPLY) {
      _totalSupply = MAX_SUPPLY;
    }

    gonsPerFragment = TOTAL_GONS / (_totalSupply);

    _updateRebaseIndex(epoch);

    emit LogRebase(epoch, _totalSupply);
    return _totalSupply;
  }

  function setSphereSettings(address _settings) external onlyOwner {
    require(_settings != address(0x0), "Zero settings");
    settings = ISphereSettings(_settings);
  }

  //set who is allowed to trigger the rebase or reward yield
  function setWhitelistSetters(
    address _addr,
    bool _value,
    uint256 _type
  ) public onlyOwner {
    if (_type == 1) {
      require(canRebase[_addr] != _value, 'Not changed');
      canRebase[_addr] = _value;
    } else if (_type == 2) {
      require(canSetRewardYield[_addr] != _value, 'Not changed');
      canSetRewardYield[_addr] = _value;
    }

    emit SetRebaseWhitelist(_addr, _value, _type);
  }

  //execute manual rebase
  function manualRebase() external {
    require(canRebase[msg.sender], 'can not rebase');
    require(!inSwap, 'Try again');
    require(nextRebase <= block.timestamp, 'Not in time');

    int256 supplyDelta;
    int256 i = 0;

    do {
      supplyDelta = int256(
        (_totalSupply * (rewardYield)) / (rewardYieldDenominator)
      );
      _coreRebase(supplyDelta);
      i++;
    }
    while (nextRebase < block.timestamp && i < 100);

    manualSync();
  }

  //move full balance without the tax
  function moveBalance(address _to)
  external
  validRecipient(_to)
  returns (bool)
  {
    require(isMoveBalance, 'can not move');
    require(initialDistributionFinished, 'Trade off');
    // Allow to move balance only once
    require(!_disallowedToMove[msg.sender], 'not allowed');
    require(balanceOf(msg.sender) > 0, 'No tokens');
    uint256 balanceOfAllSubContracts = 0;

    balanceOfAllSubContracts = getBalanceContracts(msg.sender);
    require(balanceOfAllSubContracts == 0, 'other balances');

    // Once an address received funds moved from another address it should
    // not be able to move its balance again
    _disallowedToMove[msg.sender] = true;
    uint256 gonAmount = _gonBalances[msg.sender];

    // reduce balance early
    _gonBalances[msg.sender] = _gonBalances[msg.sender] - (gonAmount);

    // Move the balance to the to address
    _gonBalances[_to] = _gonBalances[_to] + (gonAmount);

    emit Transfer(msg.sender, _to, (gonAmount / (gonsPerFragment)));
    emit MoveBalance(msg.sender, _to);
    return true;
  }

  function _updateRebaseIndex(uint256 epoch) private {
    // update the next Rebase time
    nextRebase = epoch + rebaseFrequency;

    //simply show how often we rebased since inception (how many epochs)
    rebaseEpoch += 1;
  }

  //add new subcontracts to the protocol so they can be calculated
  function addSubContracts(address _subContract, bool _value)
  external
  onlyOwner
  {
    require(subContractCheck[_subContract] != _value, 'Value already set');

    subContractCheck[_subContract] = _value;

    if (_value) {
      subContracts.push(_subContract);
    } else {
      for (uint256 i = 0; i < subContracts.length; i++) {
        if (subContracts[i] == _subContract) {
          subContracts[i] = subContracts[subContracts.length - 1];
          subContracts.pop();
          break;
        }
      }
    }

    emit SetSubContracts(_subContract, _value);
  }

  //add new lpContracts to the protocol so they can be calculated
  function addLPAddressesForDynamicTax(address _lpContract, bool _value)
  external
  onlyOwner
  {
    require(lpContractCheck[_lpContract] != _value, 'Value already set');

    lpContractCheck[_lpContract] = _value;

    if (_value) {
      lpContracts.push(_lpContract);
    } else {
      for (uint256 i = 0; i < lpContracts.length; i++) {
        if (lpContracts[i] == _lpContract) {
          lpContracts[i] = lpContracts[lpContracts.length - 1];
          lpContracts.pop();
          break;
        }
      }
    }

    emit SetLPContracts(_lpContract, _value);
  }

  //Add S.P.H.E.R.E. Games Contracts
  function addSphereGamesAddies(address _sphereGamesAddy, bool _value)
  external
  onlyOwner
  {
    require(
      sphereGamesCheck[_sphereGamesAddy] != _value,
      'Value already set'
    );

    sphereGamesCheck[_sphereGamesAddy] = _value;

    if (_value) {
      sphereGamesContracts.push(_sphereGamesAddy);
    } else {
      require(sphereGamesContracts.length > 1, 'Required 1 pair');
      for (uint256 i = 0; i < sphereGamesContracts.length; i++) {
        if (sphereGamesContracts[i] == _sphereGamesAddy) {
          sphereGamesContracts[i] = sphereGamesContracts[
          sphereGamesContracts.length - 1
          ];
          sphereGamesContracts.pop();
          break;
        }
      }
    }

    emit SetSphereGamesAddresses(_sphereGamesAddy, _value);
  }

  function addPartyAddies(
    address _partyAddy,
    bool _value,
    uint256 feeAmount
  ) external onlyOwner {

    partyArrayCheck[_partyAddy] = _value;
    require(feeAmount < MAX_PARTY_ARRAY, 'max party fees');
    partyArrayFee[_partyAddy] = feeAmount;

    if (_value) {
      partyArray.push(_partyAddy);
    } else {
      for (uint256 i = 0; i < partyArray.length; i++) {
        if (partyArray[i] == _partyAddy) {
          partyArray[i] = partyArray[partyArray.length - 1];
          partyArray.pop();
          break;
        }
      }
    }

    emit SetPartyAddresses(_partyAddy, _value);
  }

  function setAutomatedMarketMakerPair(address _pair, bool _value)
  public
  onlyOwner
  {
    require(automatedMarketMakerPairs[_pair] != _value, 'already set');

    automatedMarketMakerPairs[_pair] = _value;

    if (_value) {
      makerPairs.push(_pair);
      markerPairCount++;
    } else {
      require(makerPairs.length > 1, 'Required 1 pair');
      for (uint256 i = 0; i < makerPairs.length; i++) {
        if (makerPairs[i] == _pair) {
          makerPairs[i] = makerPairs[makerPairs.length - 1];
          makerPairs.pop();
          markerPairCount--;
          break;
        }
      }
    }

    emit SetAutomatedMarketMakerPair(_pair, _value);
  }

  function setInitialDistributionFinished(bool _value) external onlyOwner {
    initialDistributionFinished = _value;

    emit SetInitialDistribution(_value);
  }

  function setInvestRemovalDelay(uint256 _value) external onlyOwner {
    require(_value < MAX_INVEST_REMOVABLE_DELAY, 'over 2 hours');
    investRemovalDelay = _value;

    emit SetInvestRemovalDelay(_value);
  }

  function setMaxInvestRemovablePerPeriod(uint256 _value) external onlyOwner {
    require(_value > MIN_INVEST_REMOVABLE_PER_PERIOD, 'Below minimum');
    maxInvestRemovablePerPeriod = _value;

    emit SetMaxInvestRemovablePerPeriod(_value);
  }

  function setSellHourlyLimit(bool _value) external onlyOwner {
    isSellHourlyLimit = _value;

    emit SetHourlyLimit(_value);
  }

  function setPartyListDivisor(uint256 _value) external onlyOwner {
    require(_value <= MAX_PARTY_LIST_DIVISOR_RATE, 'max party');
    partyListDivisor = _value;

    emit SetPartyListDivisor(_value);
  }

  function setMoveBalance(bool _value) external onlyOwner {
    isMoveBalance = _value;

    emit SetMoveBalance(_value);
  }

  function setFeeTypeExempt(
    address _addr,
    bool _value,
    uint256 _type
  ) external onlyOwner {
    if (_type == 1) {
      require(isTotalFeeExempt[_addr] != _value, 'Not changed');
      isTotalFeeExempt[_addr] = _value;
      emit SetTotalFeeExempt(_addr, _value);
    } else if (_type == 2) {
      require(isBuyFeeExempt[_addr] != _value, 'Not changed');
      isBuyFeeExempt[_addr] = _value;
      emit SetBuyFeeExempt(_addr, _value);
    } else if (_type == 3) {
      require(isSellFeeExempt[_addr] != _value, 'Not changed');
      isSellFeeExempt[_addr] = _value;
      emit SetSellFeeExempt(_addr, _value);
    }
  }

  function setFeeReceivers(
    address _liquidityReceiver,
    address _treasuryReceiver,
    address _riskFreeValueReceiver,
    address _galaxyBondReceiver,
    address _sphereSwapper
  ) external onlyOwner {
    liquidityReceiver = _liquidityReceiver;
    treasuryReceiver = _treasuryReceiver;
    riskFreeValueReceiver = _riskFreeValueReceiver;
    galaxyBondReceiver = _galaxyBondReceiver;
    sphereSwapper = _sphereSwapper;
  }

  function setPartyTime(bool _value) external onlyOwner {
    partyTime = _value;
    emit SetPartyTime(_value, block.timestamp);
  }

  function setTaxBracketFeeMultiplier(
    uint256 _taxBracketFeeMultiplier,
    bool _isTaxBracketEnabled
  ) external onlyOwner {
    require(
      _taxBracketFeeMultiplier <= MAX_TAX_BRACKET_FEE_RATE,
      'max bracket fee exceeded'
    );
    taxBracketMultiplier = _taxBracketFeeMultiplier;
    isTaxBracket = _isTaxBracketEnabled;
    emit SetTaxBracketFeeMultiplier(
      _taxBracketFeeMultiplier,
      _isTaxBracketEnabled,
      block.timestamp
    );
  }

  function clearStuckBalance(address _receiver) external onlyOwner {
    uint256 balance = address(this).balance;
    payable(_receiver).transfer(balance);
    emit ClearStuckBalance(balance, _receiver, block.timestamp);
  }

  function rescueToken(address tokenAddress)
  external
  onlyOwner
  {
    uint256 tokens = IERC20(tokenAddress).balanceOf(address(this));
    emit RescueToken(tokenAddress, msg.sender, tokens, block.timestamp);
    IERC20(tokenAddress).transfer(msg.sender, tokens);
  }

  function setAutoRebase(bool _autoRebase) external onlyOwner {
    require(autoRebase != _autoRebase, 'already set');
    autoRebase = _autoRebase;
    emit SetAutoRebase(_autoRebase, block.timestamp);
  }

  function setGoDeflationary(bool _goDeflationary) external onlyOwner {
    require(goDeflationary != _goDeflationary, 'already set');
    goDeflationary = _goDeflationary;
    emit SetGoDeflationary(_goDeflationary, block.timestamp);
  }

  //set rebase frequency
  function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
    require(_rebaseFrequency <= MAX_REBASE_FREQUENCY, 'Too high');
    rebaseFrequency = _rebaseFrequency;
    emit SetRebaseFrequency(_rebaseFrequency, block.timestamp);
  }

  //set reward yield
  function setRewardYield(
    uint256 _rewardYield,
    uint256 _rewardYieldDenominator
  ) external {
    require(canSetRewardYield[msg.sender], 'Not allowed for reward yield');
    rewardYield = _rewardYield;
    rewardYieldDenominator = _rewardYieldDenominator;
    emit SetRewardYield(
      _rewardYield,
      _rewardYieldDenominator,
      block.timestamp,
      msg.sender
    );
  }

  //enable fees on normal transfer
  function setFeesOnNormalTransfers(bool _enabled) external onlyOwner {
    feesOnNormalTransfers = _enabled;
  }

  //set next rebase time
  function setNextRebase(uint256 _nextRebase) external onlyOwner {
    require(_nextRebase > block.timestamp, 'can not be in past');
    nextRebase = _nextRebase;
    emit SetNextRebase(_nextRebase, block.timestamp);
  }

  function setIsLiquidityEnabled(bool _value) external onlyOwner {
    isLiquidityEnabled = _value;
    emit SetIsLiquidityEnabled(_value);
  }

  function setMaxTransactionAmount(uint256 _maxSellTxn, uint256 _maxBuyTxn)
  external
  onlyOwner
  {
    require(
      _maxSellTxn > MIN_SELL_AMOUNT_RATE,
      'Below minimum sell amount'
    );
    require(_maxBuyTxn > MIN_BUY_AMOUNT_RATE, 'Below minimum buy amount');
    maxSellTransactionAmount = _maxSellTxn;
    maxBuyTransactionAmount = _maxBuyTxn;
    emit SetMaxTransactionAmount(_maxSellTxn, _maxBuyTxn, block.timestamp);
  }

  function setWallDivisor(uint256 _wallDivisor, bool _isWall)
  external
  onlyOwner
  {
    wallDivisor = _wallDivisor;
    isWall = _isWall;
    emit SetWallDivisor(_wallDivisor, _isWall);
  }


  receive() external payable {}

}
