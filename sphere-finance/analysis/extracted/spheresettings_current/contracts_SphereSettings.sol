// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/ISphereSettings.sol";
import "./interfaces/IOwnable.sol";

import "./lib/SlotsLib.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SphereSettings is Initializable, OwnableUpgradeable, ISphereSettings {
  using SlotsLib for bytes32;
  // *** CONSTANTS ***

  /// @notice Version of the contract
  /// @dev Should be incremented when contract changed
  string public constant SPHERE_SETTINGS_VERSION = "1.0.0";
  uint256 private constant MAX_TAX_BRACKET_FEE_RATE = 50;
  uint256 private constant MAX_TOTAL_BUY_FEE_RATE = 250;
  uint256 private constant MAX_TOTAL_SELL_FEE_RATE = 250;
  uint256 private constant MAX_PARTY_ARRAY = 491;

  bytes32 internal constant _SPHERE_SLOT = bytes32(uint256(keccak256("sphere_settings_sphere")) - 1);
  bytes32 internal constant _FEE_REVISION_SLOT = bytes32(uint256(keccak256("sphere_settings_fee_revision")) - 1);

  mapping(uint => Fees) public fees;

  function init(address _sphere) external initializer {
    require(_sphere != address(0), "Zero sphere");
    __Ownable_init();
    _SPHERE_SLOT.set(_sphere);
    _setInitialFees();
  }

  // *** MODIFIERS ***

  modifier onlySphereOwner() {
    require(msg.sender == IOwnable(_SPHERE_SLOT.getAddress()).owner(), "Not owner");
    _;
  }

  function _setInitialFees() internal {
    require(_FEE_REVISION_SLOT.getUint() == 0, "Fees already inited");

    uint256 burnFee = 0;
    uint256 buyGalaxyBondFee = 0;
    uint256 liquidityFee = 50;
    uint256 realFeePartyArray = 490;
    uint256 riskFreeValueFee = 50;
    uint256 sellBurnFee = 0;
    uint256 sellFeeRFVAdded = 50;
    uint256 sellFeeTreasuryAdded = 20;
    uint256 sellGalaxyBond = 0;
    uint256 treasuryFee = 30;
    uint256 totalBuyFee = liquidityFee + (treasuryFee) + (riskFreeValueFee);
    uint256 totalSellFee = totalBuyFee + (sellFeeTreasuryAdded) + (sellFeeRFVAdded);
    bool isTaxBracketEnabledInMoveFee = false;

    uint256 gameFees;
    gameFees  = uint256(10); // sphere taxes on stake / unstake in sphere game (1%)
    gameFees |= 200<<16;     // amount of buy / sell fees to add to game prize pool (20% of total fees)

    fees[0] = Fees({
      burnFee : burnFee,
      buyGalaxyBondFee : buyGalaxyBondFee,
      liquidityFee : liquidityFee,
      realFeePartyArray : realFeePartyArray,
      riskFreeValueFee : riskFreeValueFee,
      sellBurnFee : sellBurnFee,
      sellFeeRFVAdded : sellFeeRFVAdded,
      sellFeeTreasuryAdded : sellFeeTreasuryAdded,
      sellGalaxyBond : sellGalaxyBond,
      treasuryFee : treasuryFee,
      totalBuyFee : totalBuyFee,
      totalSellFee : totalSellFee,
      isTaxBracketEnabledInMoveFee : isTaxBracketEnabledInMoveFee,
      gameFees: gameFees
    });
  }

  // *** VIEW ***

  function sphere() external view returns (address) {
    return _SPHERE_SLOT.getAddress();
  }

  function feeRevision() external view returns (uint) {
    return _FEE_REVISION_SLOT.getUint();
  }

  function currentFees() external view override returns (Fees memory) {
    return fees[_FEE_REVISION_SLOT.getUint()];
  }

  // *** OWNER ACTIONS ***

  function setFees(Fees memory _fees) external onlySphereOwner {

    uint256 maxTotalBuyFee;
    uint256 maxTotalSellFee;

    _fees.totalBuyFee = _fees.liquidityFee +
    _fees.treasuryFee +
    _fees.burnFee +
    _fees.buyGalaxyBondFee +
    _fees.riskFreeValueFee;

    _fees.totalSellFee = maxTotalBuyFee +
    _fees.sellFeeTreasuryAdded +
    _fees.sellFeeRFVAdded +
    _fees.sellBurnFee +
    _fees.sellGalaxyBond;

    require(_fees.totalBuyFee < MAX_TOTAL_BUY_FEE_RATE, "max buy fees");
    require(_fees.totalSellFee < MAX_TOTAL_SELL_FEE_RATE, "max sell fees");
    require(_fees.realFeePartyArray < MAX_PARTY_ARRAY, "max party fees");

    uint revision = _FEE_REVISION_SLOT.getUint();

    fees[revision] = _fees;

    _FEE_REVISION_SLOT.set(revision + 1);

    emit SetFees(_fees);
  }


}
