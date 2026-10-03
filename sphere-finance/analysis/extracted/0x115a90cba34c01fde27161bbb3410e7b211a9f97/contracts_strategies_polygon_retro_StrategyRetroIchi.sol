// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../interfaces/common/ISolidlyPair.sol";
import "./interfaces/IRetroStaker.sol";
import "../../../interfaces/common/IERC20Extended.sol";
import "../../../common/StratManagerUpgradeable.sol";
import "../../../common/DynamicFeeManager.sol";
import "../../utils/UniV3Actions.sol";
import "../../utils/UniswapV3Utils.sol";
import "./interfaces/IGammaUniProxy.sol";
import "./interfaces/IUniV3Interfaces.sol";
import "./interfaces/IMerklClaimer.sol";
import "./ichi/interfaces/IIchiVault.sol";

interface IOToken {
  function exercise(uint256 _amount, uint256 _maxPaymentAmount, address _recipient) external returns (uint256);

  function getDiscountedPrice(uint256 _amount) external view returns (uint256 amount);

  function discount() external view returns (uint256);
}

contract StrategyRetroIchi is StratManagerUpgradeable, DynamicFeeManager {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // Tokens used
  address public native;
  address public cash;
  address public output;
  address public want;
  address public lpToken;
  address public oRetro;
  address public merklClaimer;

  // Third party contracts
  IUniV3Quoter public quoter;

  address[] public rewards;

  struct Flash {
    address pool;
    bytes outputToCash;
    bytes cashToNative;
    bool token0;
    bool flashEntered;
  }

  Flash public flash;

  bool public isFastQuote;
  bool public flashQuote;
  bool public harvestOnDeposit;
  bool public spiritHarvest;
  uint256 public lastHarvest;
  uint256 public feeOnProfits;

  bytes public outputToNativePath;
  bytes public nativeToLpPath;
  bytes public oRetroToRetroPath;

  event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
  event Deposit(uint256 tvl);
  event Withdraw(uint256 tvl);
  event ChargedFees(uint256 callFees, uint256 beefyFees, uint256 strategistFees);

  error NotPair();
  error InvalidFlash();

  function initialize(
    address _want,
    bytes calldata _outputToNativePath,
    bytes calldata _nativeToLpPath,
    Flash calldata _flash,
    address[] memory _addresses
  ) public virtual initializer {
    __Ownable_init_unchained();
    __Pausable_init_unchained();
    __DynamicFeeManager_init();
    __StratManager_init_unchained(_addresses[0], _addresses[1], _addresses[2], _addresses[3], _addresses[4]);
    want = _want;
    feeOnProfits = 200;

    if (IIchiVault(want).allowToken0()) {
      lpToken = ISolidlyPair(want).token0();
    } else {
      lpToken = ISolidlyPair(want).token1();
    }

    flash = _flash;
    flash.flashEntered = false;
    flashQuote = true;

    uint24[] memory fee = new uint24[](1);
    fee[0] = 10000;
    oRetro = 0x3A29CAb2E124919d14a6F735b6033a3AaD2B260F;
    native = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    output = 0xBFA35599c7AEbb0dAcE9b5aa3ca5f2a79624D8Eb;
    cash = 0x5D066D022EDE10eFa2717eD3D79f22F949F8C175;
    merklClaimer = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    quoter = IUniV3Quoter(0xddc9Ef56c6bf83F7116Fad5Fbc41272B07ac70C1);
    feeRecipient2 = 0x9304e0C089699d3883f112491fDB61F1c845b150;

    setNativeToLp(_nativeToLpPath);
    setOutputToNative(_outputToNativePath);

    address[] memory path = new address[](2);
    path[0] = oRetro;
    path[1] = output;

    oRetroToRetroPath = UniswapV3Utils.routeToPath(path, fee);

    _giveAllowances();
  }

  function claim(address[] calldata _tokens, uint256[] calldata _amounts, bytes32[][] calldata _proofs) public {
    address[] memory users = new address[](_tokens.length);

    for(uint i = 0; i < _tokens.length; i++) {
        users[i] = address(this);
    }

    IMerklClaimer(merklClaimer).claim(users, _tokens, _amounts, _proofs);
  }

  // puts the funds to work
  function deposit() public whenNotPaused {
    uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));

    if (wantBal > 0) {
      emit Deposit(balanceOf());
    }
  }

  function withdraw(uint256 _amount) external {
    require(msg.sender == vault, "!vault");

    if (tx.origin != owner() && !paused()) {
      uint256 withdrawalFeeAmount = (_amount * withdrawalFee) / WITHDRAWAL_MAX;
      _amount = _amount - withdrawalFeeAmount;
    }

    IERC20Upgradeable(want).safeTransfer(vault, _amount);

    emit Withdraw(balanceOf());
  }

  function beforeDeposit() external virtual override {
    if (harvestOnDeposit) {
      require(msg.sender == vault, "!vault");
      _harvest();
    }
  }

  function harvest(
    address[] calldata _tokens,
    uint256[] calldata _amounts,
    bytes32[][] calldata _proofs
  ) external {
    claim(_tokens, _amounts, _proofs);
    _harvest();
  }

  function harvest() external virtual {
    _harvest();
  }

  function managerHarvest() external onlyManager {
    _harvest();
  }

  // compounds earnings and charges performance fee
  function _harvest() internal whenNotPaused virtual {
    uint256 outputBal = IERC20Upgradeable(oRetro).balanceOf(address(this));
    if (outputBal > 0) {
      swapRewardsToNative();
      chargeFees();
      addLiquidity();
      uint256 wantHarvested = balanceOfWant();
      deposit();

      lastHarvest = block.timestamp;
      emit StratHarvest(msg.sender, wantHarvested, balanceOf());
    }
  }

  /**
   * @dev Charges performance fees.
   */
  function chargeFees() internal virtual {
    uint256 generalFeeOnProfits = (IERC20Upgradeable(native).balanceOf(address(this)) * feeOnProfits) / 1000;

    // Calculating the Fee to be distributed
    uint256 feeAmount1 = (generalFeeOnProfits * fee1) / MAX_FEE;
    uint256 feeAmount2 = (generalFeeOnProfits * fee2) / MAX_FEE;
    uint256 strategistFeeAmount = (generalFeeOnProfits * strategistFee) / MAX_FEE;

    // Transfer fees to recipients
    if (feeAmount1 > 0) {
      IERC20Upgradeable(native).safeTransfer(feeRecipient1, feeAmount1);
    }
    if (feeAmount2 > 0) {
      IERC20Upgradeable(native).safeTransfer(feeRecipient2, feeAmount2);
    }
    if (strategistFeeAmount > 0) {
      IERC20Upgradeable(native).safeTransfer(strategist, strategistFeeAmount);
    }
  }

  function swapRewardsToNative() internal {
    uint bal = IERC20Upgradeable(oRetro).balanceOf(address(this));
    if (flashQuote) {
      uint256 discount = 100 - IOToken(oRetro).discount();
      uint expectedRetro = (bal * discount) / 100;
      uint256 swappedRetro = quoter.quoteExactInput(oRetroToRetroPath, bal);

      if (swappedRetro > expectedRetro) {
        UniV3Actions.swapV3WithDeadline(dystRouter, oRetroToRetroPath, bal);
        UniV3Actions.swapV3WithDeadline(
          dystRouter,
          outputToNativePath,
          IERC20Upgradeable(output).balanceOf(address(this))
        );
      } else flashExercise(bal);
    } else flashExercise(bal);
  }

  function flashExercise(uint256 _amount) internal {
    uint256 amountNeeded = IOToken(oRetro).getDiscountedPrice(_amount);
    uint256 token0Amt = flash.token0 ? amountNeeded : 0;
    uint256 token1Amt = flash.token0 ? 0 : amountNeeded;
    flash.flashEntered = true;
    IUniV3Pool(flash.pool).flash(address(this), token0Amt, token1Amt, "");
  }

  function uniswapV3FlashCallback(uint256 _fee0, uint256 _fee1, bytes calldata) external virtual {
    if (msg.sender != flash.pool) revert NotPair();
    if (!flash.flashEntered) revert InvalidFlash();

    uint256 cashAmount = IERC20Upgradeable(cash).balanceOf(address(this));
    uint256 oRetroAmt = IERC20Upgradeable(oRetro).balanceOf(address(this));
    IOToken(oRetro).exercise(oRetroAmt, cashAmount, address(this));

    UniV3Actions.swapV3WithDeadline(dystRouter, flash.outputToCash, IERC20Upgradeable(output).balanceOf(address(this)));

    uint256 fee = flash.token0 ? _fee0 : _fee1;
    uint256 pairDebt = cashAmount + fee;
    IERC20Upgradeable(cash).transfer(flash.pool, pairDebt);
    UniV3Actions.swapV3WithDeadline(dystRouter, flash.cashToNative, IERC20Upgradeable(cash).balanceOf(address(this)));
    flash.flashEntered = false;
  }

  // Adds liquidity to AMM and gets more LP tokens.
  function addLiquidity() internal virtual {
    uint256 nativeBal = IERC20Upgradeable(native).balanceOf(address(this));

    if (lpToken != native) {
      UniV3Actions.swapV3WithDeadline(dystRouter, nativeToLpPath, nativeBal);
    }

    uint256 liquidityBal = IERC20Upgradeable(lpToken).balanceOf(address(this));

    if (IIchiVault(want).allowToken0()) {
      IIchiVault(want).deposit(liquidityBal, 0, address(this));
    } else {
      IIchiVault(want).deposit(0, liquidityBal, address(this));
    }
  }

  // calculate the total underlaying 'want' held by the strat.
  function balanceOf() public view returns (uint256) {
    return balanceOfWant() + balanceOfPool();
  }

  // it calculates how much 'want' this contract holds.
  function balanceOfWant() public view returns (uint256) {
    return IERC20Upgradeable(want).balanceOf(address(this));
  }

  // it calculates how much 'want' the strategy has working in the farm.
  function balanceOfPool() public view returns (uint256) {
    return 0;
  }

  // returns rewards unharvested
  function rewardsAvailable() public view returns (uint256) {
    return 0;
  }

  function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
    harvestOnDeposit = _harvestOnDeposit;

    if (harvestOnDeposit) {
      setWithdrawalFee(0);
    } else {
      setWithdrawalFee(10);
    }
  }

  function setFastQuote(bool _isFastQuote) external onlyManager {
    isFastQuote = _isFastQuote;
  }

  function setFlashQuote(bool _flashQuote) external onlyManager {
    flashQuote = _flashQuote;
  }

  // called as part of strat migration. Sends all the available funds back to the vault.
  function retireStrat() external {
    require(msg.sender == vault, "!vault");

    uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
    IERC20Upgradeable(want).transfer(vault, wantBal);
  }

  // pauses deposits and withdraws all funds from third party systems.
  function panic() public onlyManager {
    pause();
  }

  function setMerklClaimer(address _merklClaimer) public onlyManager {
    merklClaimer = _merklClaimer;
  }

  function pause() public onlyManager {
    _pause();

    _removeAllowances();
  }

  function unpause() public onlyManager {
    _unpause();

    _giveAllowances();

    deposit();
  }

  function _giveAllowances() internal {
    IERC20Upgradeable(output).approve(dystRouter, type(uint).max);
    IERC20Upgradeable(oRetro).approve(dystRouter, type(uint).max);
    IERC20Upgradeable(native).approve(dystRouter, type(uint).max);
    IERC20Upgradeable(cash).approve(dystRouter, type(uint).max);
    IERC20Upgradeable(cash).approve(oRetro, type(uint).max);
    IERC20Upgradeable(lpToken).approve(want, 0);
    IERC20Upgradeable(lpToken).approve(want, type(uint).max);
  }

  function _removeAllowances() internal {
    IERC20Upgradeable(output).approve(dystRouter, 0);
    IERC20Upgradeable(oRetro).approve(dystRouter, 0);
    IERC20Upgradeable(native).approve(dystRouter, 0);
    IERC20Upgradeable(cash).approve(dystRouter, 0);
    IERC20Upgradeable(cash).approve(oRetro, 0);
    IERC20Upgradeable(lpToken).approve(want, 0);
  }

  function setOutputToNative(bytes calldata _outputToNativePath) public onlyOwner {
    if (_outputToNativePath.length > 0) {
      address[] memory route = UniswapV3Utils.pathToRoute(_outputToNativePath);
      require(route[0] == output, "!output");
    }
    outputToNativePath = _outputToNativePath;
  }

  function setNativeToLp(bytes calldata _nativeToLpPath) public onlyOwner {
    if (_nativeToLpPath.length > 0) {
      address[] memory route = UniswapV3Utils.pathToRoute(_nativeToLpPath);
      require(route[0] == native, "!native");
      require(route[route.length - 1] == lpToken, "!lp");
    }
    nativeToLpPath = _nativeToLpPath;
  }

  function outputToNative() external view returns (address[] memory) {
    return UniswapV3Utils.pathToRoute(outputToNativePath);
  }

  function nativeToLp() external view returns (address[] memory) {
    return UniswapV3Utils.pathToRoute(nativeToLpPath);
  }
}
