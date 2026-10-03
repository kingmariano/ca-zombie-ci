// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10 >=0.8.0 ^0.8.0 ^0.8.1 ^0.8.2;

// contracts/compound/CarefulMath.sol

/**
 * @title Careful Math
 * @author Compound
 * @notice Derived from OpenZeppelin's SafeMath library
 *         https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
contract CarefulMath {
  /**
   * @dev Possible error codes that we can return
   */
  enum MathError {
    NO_ERROR,
    DIVISION_BY_ZERO,
    INTEGER_OVERFLOW,
    INTEGER_UNDERFLOW
  }

  /**
   * @dev Multiplies two numbers, returns an error on overflow.
   */
  function mulUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (a == 0) {
      return (MathError.NO_ERROR, 0);
    }

    uint256 c;
    unchecked {
      c = a * b;
    }

    if (c / a != b) {
      return (MathError.INTEGER_OVERFLOW, 0);
    } else {
      return (MathError.NO_ERROR, c);
    }
  }

  /**
   * @dev Integer division of two numbers, truncating the quotient.
   */
  function divUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b == 0) {
      return (MathError.DIVISION_BY_ZERO, 0);
    }

    return (MathError.NO_ERROR, a / b);
  }

  /**
   * @dev Subtracts two numbers, returns an error on overflow (i.e. if subtrahend is greater than minuend).
   */
  function subUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b <= a) {
      return (MathError.NO_ERROR, a - b);
    } else {
      return (MathError.INTEGER_UNDERFLOW, 0);
    }
  }

  /**
   * @dev Adds two numbers, returns an error on overflow.
   */
  function addUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    uint256 c;
    unchecked {
      c = a + b;
    }

    if (c >= a) {
      return (MathError.NO_ERROR, c);
    } else {
      return (MathError.INTEGER_OVERFLOW, 0);
    }
  }

  /**
   * @dev add a and b and then subtract c
   */
  function addThenSubUInt(uint256 a, uint256 b, uint256 c) internal pure returns (MathError, uint256) {
    (MathError err0, uint256 sum) = addUInt(a, b);

    if (err0 != MathError.NO_ERROR) {
      return (err0, 0);
    }

    return subUInt(sum, c);
  }
}

// contracts/compound/ErrorReporter.sol

contract ComptrollerErrorReporter {
  enum Error {
    NO_ERROR,
    UNAUTHORIZED,
    COMPTROLLER_MISMATCH,
    INSUFFICIENT_SHORTFALL,
    INSUFFICIENT_LIQUIDITY,
    INVALID_CLOSE_FACTOR,
    INVALID_COLLATERAL_FACTOR,
    INVALID_LIQUIDATION_INCENTIVE,
    MARKET_NOT_LISTED,
    MARKET_ALREADY_LISTED,
    MATH_ERROR,
    NONZERO_BORROW_BALANCE,
    PRICE_ERROR,
    REJECTION,
    SNAPSHOT_ERROR,
    TOO_MANY_ASSETS,
    TOO_MUCH_REPAY,
    SUPPLIER_NOT_WHITELISTED,
    BORROW_BELOW_MIN,
    SUPPLY_ABOVE_MAX,
    NONZERO_TOTAL_SUPPLY
  }

  enum FailureInfo {
    ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
    ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK,
    ADD_REWARDS_DISTRIBUTOR_OWNER_CHECK,
    EXIT_MARKET_BALANCE_OWED,
    EXIT_MARKET_REJECTION,
    TOGGLE_ADMIN_RIGHTS_OWNER_CHECK,
    TOGGLE_AUTO_IMPLEMENTATIONS_ENABLED_OWNER_CHECK,
    SET_CLOSE_FACTOR_OWNER_CHECK,
    SET_CLOSE_FACTOR_VALIDATION,
    SET_COLLATERAL_FACTOR_OWNER_CHECK,
    SET_COLLATERAL_FACTOR_NO_EXISTS,
    SET_COLLATERAL_FACTOR_VALIDATION,
    SET_COLLATERAL_FACTOR_WITHOUT_PRICE,
    SET_LIQUIDATION_INCENTIVE_OWNER_CHECK,
    SET_LIQUIDATION_INCENTIVE_VALIDATION,
    SET_PENDING_ADMIN_OWNER_CHECK,
    SET_PENDING_IMPLEMENTATION_CONTRACT_CHECK,
    SET_PENDING_IMPLEMENTATION_OWNER_CHECK,
    SET_PRICE_ORACLE_OWNER_CHECK,
    SET_WHITELIST_ENFORCEMENT_OWNER_CHECK,
    SET_WHITELIST_STATUS_OWNER_CHECK,
    SUPPORT_MARKET_EXISTS,
    SUPPORT_MARKET_OWNER_CHECK,
    SET_PAUSE_GUARDIAN_OWNER_CHECK,
    UNSUPPORT_MARKET_OWNER_CHECK,
    UNSUPPORT_MARKET_DOES_NOT_EXIST,
    UNSUPPORT_MARKET_IN_USE
  }

  /**
   * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
   * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
   **/
  event Failure(uint256 error, uint256 info, uint256 detail);

  /**
   * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
   */
  function fail(Error err, FailureInfo info) internal returns (uint256) {
    emit Failure(uint256(err), uint256(info), 0);

    return uint256(err);
  }

  /**
   * @dev use this when reporting an opaque error from an upgradeable collaborator contract
   */
  function failOpaque(Error err, FailureInfo info, uint256 opaqueError) internal returns (uint256) {
    emit Failure(uint256(err), uint256(info), opaqueError);

    return uint256(err);
  }
}

contract TokenErrorReporter {
  enum Error {
    NO_ERROR,
    UNAUTHORIZED,
    BAD_INPUT,
    COMPTROLLER_REJECTION,
    COMPTROLLER_CALCULATION_ERROR,
    INTEREST_RATE_MODEL_ERROR,
    INVALID_ACCOUNT_PAIR,
    INVALID_CLOSE_AMOUNT_REQUESTED,
    INVALID_COLLATERAL_FACTOR,
    MATH_ERROR,
    MARKET_NOT_FRESH,
    MARKET_NOT_LISTED,
    TOKEN_INSUFFICIENT_ALLOWANCE,
    TOKEN_INSUFFICIENT_BALANCE,
    TOKEN_INSUFFICIENT_CASH,
    TOKEN_TRANSFER_IN_FAILED,
    TOKEN_TRANSFER_OUT_FAILED,
    UTILIZATION_ABOVE_MAX
  }

  /*
   * Note: FailureInfo (but not Error) is kept in alphabetical order
   *       This is because FailureInfo grows significantly faster, and
   *       the order of Error has some meaning, while the order of FailureInfo
   *       is entirely arbitrary.
   */
  enum FailureInfo {
    ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
    ACCRUE_INTEREST_ACCUMULATED_INTEREST_CALCULATION_FAILED,
    ACCRUE_INTEREST_BORROW_RATE_CALCULATION_FAILED,
    ACCRUE_INTEREST_NEW_BORROW_INDEX_CALCULATION_FAILED,
    ACCRUE_INTEREST_NEW_TOTAL_BORROWS_CALCULATION_FAILED,
    ACCRUE_INTEREST_NEW_TOTAL_RESERVES_CALCULATION_FAILED,
    ACCRUE_INTEREST_NEW_TOTAL_IONIC_FEES_CALCULATION_FAILED,
    ACCRUE_INTEREST_NEW_TOTAL_ADMIN_FEES_CALCULATION_FAILED,
    ACCRUE_INTEREST_SIMPLE_INTEREST_FACTOR_CALCULATION_FAILED,
    BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED,
    BORROW_ACCRUE_INTEREST_FAILED,
    BORROW_CASH_NOT_AVAILABLE,
    BORROW_FRESHNESS_CHECK,
    BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED,
    BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED,
    BORROW_MARKET_NOT_LISTED,
    BORROW_COMPTROLLER_REJECTION,
    LIQUIDATE_ACCRUE_BORROW_INTEREST_FAILED,
    LIQUIDATE_ACCRUE_COLLATERAL_INTEREST_FAILED,
    LIQUIDATE_COLLATERAL_FRESHNESS_CHECK,
    LIQUIDATE_COMPTROLLER_REJECTION,
    LIQUIDATE_COMPTROLLER_CALCULATE_AMOUNT_SEIZE_FAILED,
    LIQUIDATE_CLOSE_AMOUNT_IS_UINT_MAX,
    LIQUIDATE_CLOSE_AMOUNT_IS_ZERO,
    LIQUIDATE_FRESHNESS_CHECK,
    LIQUIDATE_LIQUIDATOR_IS_BORROWER,
    LIQUIDATE_REPAY_BORROW_FRESH_FAILED,
    LIQUIDATE_SEIZE_BALANCE_INCREMENT_FAILED,
    LIQUIDATE_SEIZE_BALANCE_DECREMENT_FAILED,
    LIQUIDATE_SEIZE_COMPTROLLER_REJECTION,
    LIQUIDATE_SEIZE_LIQUIDATOR_IS_BORROWER,
    LIQUIDATE_SEIZE_TOO_MUCH,
    MINT_ACCRUE_INTEREST_FAILED,
    MINT_COMPTROLLER_REJECTION,
    MINT_EXCHANGE_CALCULATION_FAILED,
    MINT_EXCHANGE_RATE_READ_FAILED,
    MINT_FRESHNESS_CHECK,
    MINT_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED,
    MINT_NEW_TOTAL_SUPPLY_CALCULATION_FAILED,
    MINT_TRANSFER_IN_FAILED,
    MINT_TRANSFER_IN_NOT_POSSIBLE,
    NEW_UTILIZATION_RATE_ABOVE_MAX,
    REDEEM_ACCRUE_INTEREST_FAILED,
    REDEEM_COMPTROLLER_REJECTION,
    REDEEM_EXCHANGE_TOKENS_CALCULATION_FAILED,
    REDEEM_EXCHANGE_AMOUNT_CALCULATION_FAILED,
    REDEEM_EXCHANGE_RATE_READ_FAILED,
    REDEEM_FRESHNESS_CHECK,
    REDEEM_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED,
    REDEEM_NEW_TOTAL_SUPPLY_CALCULATION_FAILED,
    REDEEM_TRANSFER_OUT_NOT_POSSIBLE,
    WITHDRAW_IONIC_FEES_ACCRUE_INTEREST_FAILED,
    WITHDRAW_IONIC_FEES_CASH_NOT_AVAILABLE,
    WITHDRAW_IONIC_FEES_FRESH_CHECK,
    WITHDRAW_IONIC_FEES_VALIDATION,
    WITHDRAW_ADMIN_FEES_ACCRUE_INTEREST_FAILED,
    WITHDRAW_ADMIN_FEES_CASH_NOT_AVAILABLE,
    WITHDRAW_ADMIN_FEES_FRESH_CHECK,
    WITHDRAW_ADMIN_FEES_VALIDATION,
    REDUCE_RESERVES_ACCRUE_INTEREST_FAILED,
    REDUCE_RESERVES_ADMIN_CHECK,
    REDUCE_RESERVES_CASH_NOT_AVAILABLE,
    REDUCE_RESERVES_FRESH_CHECK,
    REDUCE_RESERVES_VALIDATION,
    REPAY_BEHALF_ACCRUE_INTEREST_FAILED,
    REPAY_BORROW_ACCRUE_INTEREST_FAILED,
    REPAY_BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED,
    REPAY_BORROW_COMPTROLLER_REJECTION,
    REPAY_BORROW_FRESHNESS_CHECK,
    REPAY_BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED,
    REPAY_BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED,
    REPAY_BORROW_TRANSFER_IN_NOT_POSSIBLE,
    SET_COLLATERAL_FACTOR_OWNER_CHECK,
    SET_COLLATERAL_FACTOR_VALIDATION,
    SET_COMPTROLLER_OWNER_CHECK,
    SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED,
    SET_INTEREST_RATE_MODEL_FRESH_CHECK,
    SET_INTEREST_RATE_MODEL_OWNER_CHECK,
    TOGGLE_ADMIN_RIGHTS_OWNER_CHECK,
    SET_PENDING_ADMIN_OWNER_CHECK,
    SET_ADMIN_FEE_ACCRUE_INTEREST_FAILED,
    SET_ADMIN_FEE_ADMIN_CHECK,
    SET_ADMIN_FEE_FRESH_CHECK,
    SET_ADMIN_FEE_BOUNDS_CHECK,
    SET_IONIC_FEE_ACCRUE_INTEREST_FAILED,
    SET_IONIC_FEE_FRESH_CHECK,
    SET_IONIC_FEE_BOUNDS_CHECK,
    SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED,
    SET_RESERVE_FACTOR_ADMIN_CHECK,
    SET_RESERVE_FACTOR_FRESH_CHECK,
    SET_RESERVE_FACTOR_BOUNDS_CHECK,
    TRANSFER_COMPTROLLER_REJECTION,
    TRANSFER_NOT_ALLOWED,
    TRANSFER_NOT_ENOUGH,
    TRANSFER_TOO_MUCH,
    ADD_RESERVES_ACCRUE_INTEREST_FAILED,
    ADD_RESERVES_FRESH_CHECK,
    ADD_RESERVES_TRANSFER_IN_NOT_POSSIBLE
  }

  /**
   * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
   * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
   **/
  event Failure(uint256 error, uint256 info, uint256 detail);

  /**
   * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
   */
  function fail(Error err, FailureInfo info) internal returns (uint256) {
    emit Failure(uint256(err), uint256(info), 0);

    return uint256(err);
  }

  /**
   * @dev use this when reporting an opaque error from an upgradeable collaborator contract
   */
  function failOpaque(Error err, FailureInfo info, uint256 opaqueError) internal returns (uint256) {
    emit Failure(uint256(err), uint256(info), opaqueError);

    return err == Error.COMPTROLLER_REJECTION ? 1000 + opaqueError : uint256(err);
  }
}

// contracts/compound/ExponentialNoError.sol

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract ExponentialNoError {
  uint256 constant expScale = 1e18;
  uint256 constant doubleScale = 1e36;
  uint256 constant halfExpScale = expScale / 2;
  uint256 constant mantissaOne = expScale;

  struct Exp {
    uint256 mantissa;
  }

  struct Double {
    uint256 mantissa;
  }

  /**
   * @dev Truncates the given exp to a whole number value.
   *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
   */
  function truncate(Exp memory exp) internal pure returns (uint256) {
    // Note: We are not using careful math here as we're performing a division that cannot fail
    return exp.mantissa / expScale;
  }

  /**
   * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
   */
  function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256) {
    Exp memory product = mul_(a, scalar);
    return truncate(product);
  }

  /**
   * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
   */
  function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) internal pure returns (uint256) {
    Exp memory product = mul_(a, scalar);
    return add_(truncate(product), addend);
  }

  /**
   * @dev Checks if first Exp is less than second Exp.
   */
  function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa < right.mantissa;
  }

  /**
   * @dev Checks if left Exp <= right Exp.
   */
  function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa <= right.mantissa;
  }

  /**
   * @dev Checks if left Exp > right Exp.
   */
  function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa > right.mantissa;
  }

  /**
   * @dev returns true if Exp is exactly zero
   */
  function isZeroExp(Exp memory value) internal pure returns (bool) {
    return value.mantissa == 0;
  }

  function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224) {
    require(n < 2 ** 224, errorMessage);
    return uint224(n);
  }

  function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
    require(n < 2 ** 32, errorMessage);
    return uint32(n);
  }

  function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({ mantissa: add_(a.mantissa, b.mantissa) });
  }

  function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({ mantissa: add_(a.mantissa, b.mantissa) });
  }

  function add_(uint256 a, uint256 b) internal pure returns (uint256) {
    return add_(a, b, "addition overflow");
  }

  function add_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, errorMessage);
    return c;
  }

  function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({ mantissa: sub_(a.mantissa, b.mantissa) });
  }

  function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({ mantissa: sub_(a.mantissa, b.mantissa) });
  }

  function sub_(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub_(a, b, "subtraction underflow");
  }

  function sub_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    return a - b;
  }

  function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({ mantissa: mul_(a.mantissa, b.mantissa) / expScale });
  }

  function mul_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
    return Exp({ mantissa: mul_(a.mantissa, b) });
  }

  function mul_(uint256 a, Exp memory b) internal pure returns (uint256) {
    return mul_(a, b.mantissa) / expScale;
  }

  function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({ mantissa: mul_(a.mantissa, b.mantissa) / doubleScale });
  }

  function mul_(Double memory a, uint256 b) internal pure returns (Double memory) {
    return Double({ mantissa: mul_(a.mantissa, b) });
  }

  function mul_(uint256 a, Double memory b) internal pure returns (uint256) {
    return mul_(a, b.mantissa) / doubleScale;
  }

  function mul_(uint256 a, uint256 b) internal pure returns (uint256) {
    return mul_(a, b, "multiplication overflow");
  }

  function mul_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b, errorMessage);
    return c;
  }

  function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({ mantissa: div_(mul_(a.mantissa, expScale), b.mantissa) });
  }

  function div_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
    return Exp({ mantissa: div_(a.mantissa, b) });
  }

  function div_(uint256 a, Exp memory b) internal pure returns (uint256) {
    return div_(mul_(a, expScale), b.mantissa);
  }

  function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({ mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa) });
  }

  function div_(Double memory a, uint256 b) internal pure returns (Double memory) {
    return Double({ mantissa: div_(a.mantissa, b) });
  }

  function div_(uint256 a, Double memory b) internal pure returns (uint256) {
    return div_(mul_(a, doubleScale), b.mantissa);
  }

  function div_(uint256 a, uint256 b) internal pure returns (uint256) {
    return div_(a, b, "divide by zero");
  }

  function div_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b > 0, errorMessage);
    return a / b;
  }

  function fraction(uint256 a, uint256 b) internal pure returns (Double memory) {
    return Double({ mantissa: div_(mul_(a, doubleScale), b) });
  }
}

// contracts/compound/InterestRateModel.sol

/**
 * @title Compound's InterestRateModel Interface
 * @author Compound
 */
abstract contract InterestRateModel {
  /// @notice Indicator that this is an InterestRateModel contract (for inspection)
  bool public constant isInterestRateModel = true;

  /**
   * @notice Calculates the current borrow interest rate per block
   * @param cash The total amount of cash the market has
   * @param borrows The total amount of borrows the market has outstanding
   * @param reserves The total amount of reserves the market has
   * @return The borrow rate per block (as a percentage, and scaled by 1e18)
   */
  function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view virtual returns (uint256);

  /**
   * @notice Calculates the current supply interest rate per block
   * @param cash The total amount of cash the market has
   * @param borrows The total amount of borrows the market has outstanding
   * @param reserves The total amount of reserves the market has
   * @param reserveFactorMantissa The current reserve factor the market has
   * @return The supply rate per block (as a percentage, and scaled by 1e18)
   */
  function getSupplyRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves,
    uint256 reserveFactorMantissa
  ) public view virtual returns (uint256);
}

// contracts/ionic/DiamondExtension.sol

/**
 * @notice a base contract for logic extensions that use the diamond pattern storage
 * to map the functions when looking up the extension contract to delegate to.
 */
abstract contract DiamondExtension {
  /**
   * @return a list of all the function selectors that this logic extension exposes
   */
  function _getExtensionFunctions() external pure virtual returns (bytes4[] memory);
}

// When no function exists for function called
error FunctionNotFound(bytes4 _functionSelector);

// When no extension exists for function called
error ExtensionNotFound(bytes4 _functionSelector);

// When the function is already added
error FunctionAlreadyAdded(bytes4 _functionSelector, address _currentImpl);

abstract contract DiamondBase {
  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external virtual;

  function _listExtensions() public view returns (address[] memory) {
    return LibDiamond.listExtensions();
  }

  fallback() external {
    address extension = LibDiamond.getExtensionForFunction(msg.sig);
    if (extension == address(0)) revert FunctionNotFound(msg.sig);
    // Execute external function from extension using delegatecall and return any value.
    assembly {
      // copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
      // execute function call using the extension
      let result := delegatecall(gas(), extension, 0, calldatasize(), 0, 0)
      // get any return value
      returndatacopy(0, 0, returndatasize())
      // return any return value or error back to the caller
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}

/**
 * @notice a library to use in a contract, whose logic is extended with diamond extension
 */
library LibDiamond {
  bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.extensions.diamond.storage");

  struct Function {
    address extension;
    bytes4 selector;
  }

  struct LogicStorage {
    Function[] functions;
    address[] extensions;
  }

  function getExtensionForFunction(bytes4 msgSig) internal view returns (address) {
    return getExtensionForSelector(msgSig, diamondStorage());
  }

  function diamondStorage() internal pure returns (LogicStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function listExtensions() internal view returns (address[] memory) {
    return diamondStorage().extensions;
  }

  function registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) internal {
    if (address(extensionToReplace) != address(0)) {
      removeExtension(extensionToReplace);
    }
    addExtension(extensionToAdd);
  }

  function removeExtension(DiamondExtension extension) internal {
    LogicStorage storage ds = diamondStorage();
    // remove all functions of the extension to replace
    removeExtensionFunctions(extension);
    for (uint8 i = 0; i < ds.extensions.length; i++) {
      if (ds.extensions[i] == address(extension)) {
        ds.extensions[i] = ds.extensions[ds.extensions.length - 1];
        ds.extensions.pop();
      }
    }
  }

  function addExtension(DiamondExtension extension) internal {
    LogicStorage storage ds = diamondStorage();
    for (uint8 i = 0; i < ds.extensions.length; i++) {
      require(ds.extensions[i] != address(extension), "extension already added");
    }
    addExtensionFunctions(extension);
    ds.extensions.push(address(extension));
  }

  function removeExtensionFunctions(DiamondExtension extension) internal {
    bytes4[] memory fnsToRemove = extension._getExtensionFunctions();
    LogicStorage storage ds = diamondStorage();
    for (uint16 i = 0; i < fnsToRemove.length; i++) {
      bytes4 selectorToRemove = fnsToRemove[i];
      // must never fail
      assert(address(extension) == getExtensionForSelector(selectorToRemove, ds));
      // swap with the last element in the selectorAtIndex array and remove the last element
      uint16 indexToKeep = getIndexForSelector(selectorToRemove, ds);
      ds.functions[indexToKeep] = ds.functions[ds.functions.length - 1];
      ds.functions.pop();
    }
  }

  function addExtensionFunctions(DiamondExtension extension) internal {
    bytes4[] memory fnsToAdd = extension._getExtensionFunctions();
    LogicStorage storage ds = diamondStorage();
    uint16 functionsCount = uint16(ds.functions.length);
    for (uint256 functionsIndex = 0; functionsIndex < fnsToAdd.length; functionsIndex++) {
      bytes4 selector = fnsToAdd[functionsIndex];
      address oldImplementation = getExtensionForSelector(selector, ds);
      if (oldImplementation != address(0)) revert FunctionAlreadyAdded(selector, oldImplementation);
      ds.functions.push(Function(address(extension), selector));
      functionsCount++;
    }
  }

  function getExtensionForSelector(bytes4 selector, LogicStorage storage ds) internal view returns (address) {
    uint256 fnsLen = ds.functions.length;
    for (uint256 i = 0; i < fnsLen; i++) {
      if (ds.functions[i].selector == selector) return ds.functions[i].extension;
    }

    return address(0);
  }

  function getIndexForSelector(bytes4 selector, LogicStorage storage ds) internal view returns (uint16) {
    uint16 fnsLen = uint16(ds.functions.length);
    for (uint16 i = 0; i < fnsLen; i++) {
      if (ds.functions[i].selector == selector) return i;
    }

    return type(uint16).max;
  }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
  /**
   * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
   * address.
   *
   * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
   * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
   * function revert if invoked through a proxy.
   */
  function proxiableUUID() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/proxy/Proxy.sol

// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
  /**
   * @dev Delegates the current call to `implementation`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _delegate(address implementation) internal virtual {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /**
   * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
   * and {_fallback} should delegate.
   */
  function _implementation() internal view virtual returns (address);

  /**
   * @dev Delegates the current call to the address returned by `_implementation()`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _fallback() internal virtual {
    _beforeFallback();
    _delegate(_implementation());
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
   * function in the contract matches the call data.
   */
  fallback() external payable virtual {
    _fallback();
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
   * is empty.
   */
  receive() external payable virtual {
    _fallback();
  }

  /**
   * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
   * call, or as part of the Solidity `fallback` or `receive` functions.
   *
   * If overridden should call `super._beforeFallback()`.
   */
  function _beforeFallback() internal virtual {}
}

// lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
  /**
   * @dev Must return an address that can be used as a delegate call target.
   *
   * {BeaconProxy} will check that this address is a contract.
   */
  function implementation() external view returns (address);
}

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
   * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
   */
  function sendValue(address payable recipient, uint256 amount) internal {
    require(address(this).balance >= amount, "Address: insufficient balance");

    (bool success, ) = recipient.call{ value: amount }("");
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
  function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    (bool success, bytes memory returndata) = target.call{ value: value }(data);
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

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
  struct AddressSlot {
    address value;
  }

  struct BooleanSlot {
    bool value;
  }

  struct Bytes32Slot {
    bytes32 value;
  }

  struct Uint256Slot {
    uint256 value;
  }

  /**
   * @dev Returns an `AddressSlot` with member `value` located at `slot`.
   */
  function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
    /// @solidity memory-safe-assembly
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
   */
  function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
    /// @solidity memory-safe-assembly
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
   */
  function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
    /// @solidity memory-safe-assembly
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
   */
  function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
    /// @solidity memory-safe-assembly
    assembly {
      r.slot := slot
    }
  }
}

// lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
  // To implement this library for multiple types with as little code
  // repetition as possible, we write it in terms of a generic Set type with
  // bytes32 values.
  // The Set implementation uses private functions, and user-facing
  // implementations (such as AddressSet) are just wrappers around the
  // underlying Set.
  // This means that we can only create new EnumerableSets for types that fit
  // in bytes32.

  struct Set {
    // Storage of set values
    bytes32[] _values;
    // Position of the value in the `values` array, plus 1 because index 0
    // means a value is not in the set.
    mapping(bytes32 => uint256) _indexes;
  }

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function _add(Set storage set, bytes32 value) private returns (bool) {
    if (!_contains(set, value)) {
      set._values.push(value);
      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      set._indexes[value] = set._values.length;
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function _remove(Set storage set, bytes32 value) private returns (bool) {
    // We read and store the value's index to prevent multiple reads from the same storage slot
    uint256 valueIndex = set._indexes[value];

    if (valueIndex != 0) {
      // Equivalent to contains(set, value)
      // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
      // the array, and then remove the last element (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.

      uint256 toDeleteIndex = valueIndex - 1;
      uint256 lastIndex = set._values.length - 1;

      if (lastIndex != toDeleteIndex) {
        bytes32 lastValue = set._values[lastIndex];

        // Move the last value to the index where the value to delete is
        set._values[toDeleteIndex] = lastValue;
        // Update the index for the moved value
        set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
      }

      // Delete the slot where the moved value was stored
      set._values.pop();

      // Delete the index for the deleted slot
      delete set._indexes[value];

      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function _contains(Set storage set, bytes32 value) private view returns (bool) {
    return set._indexes[value] != 0;
  }

  /**
   * @dev Returns the number of values on the set. O(1).
   */
  function _length(Set storage set) private view returns (uint256) {
    return set._values.length;
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function _at(Set storage set, uint256 index) private view returns (bytes32) {
    return set._values[index];
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function _values(Set storage set) private view returns (bytes32[] memory) {
    return set._values;
  }

  // Bytes32Set

  struct Bytes32Set {
    Set _inner;
  }

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
    return _add(set._inner, value);
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
    return _remove(set._inner, value);
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
    return _contains(set._inner, value);
  }

  /**
   * @dev Returns the number of values in the set. O(1).
   */
  function length(Bytes32Set storage set) internal view returns (uint256) {
    return _length(set._inner);
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
    return _at(set._inner, index);
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
    bytes32[] memory store = _values(set._inner);
    bytes32[] memory result;

    /// @solidity memory-safe-assembly
    assembly {
      result := store
    }

    return result;
  }

  // AddressSet

  struct AddressSet {
    Set _inner;
  }

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function add(AddressSet storage set, address value) internal returns (bool) {
    return _add(set._inner, bytes32(uint256(uint160(value))));
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function remove(AddressSet storage set, address value) internal returns (bool) {
    return _remove(set._inner, bytes32(uint256(uint160(value))));
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function contains(AddressSet storage set, address value) internal view returns (bool) {
    return _contains(set._inner, bytes32(uint256(uint160(value))));
  }

  /**
   * @dev Returns the number of values in the set. O(1).
   */
  function length(AddressSet storage set) internal view returns (uint256) {
    return _length(set._inner);
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(AddressSet storage set, uint256 index) internal view returns (address) {
    return address(uint160(uint256(_at(set._inner, index))));
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function values(AddressSet storage set) internal view returns (address[] memory) {
    bytes32[] memory store = _values(set._inner);
    address[] memory result;

    /// @solidity memory-safe-assembly
    assembly {
      result := store
    }

    return result;
  }

  // UintSet

  struct UintSet {
    Set _inner;
  }

  /**
   * @dev Add a value to a set. O(1).
   *
   * Returns true if the value was added to the set, that is if it was not
   * already present.
   */
  function add(UintSet storage set, uint256 value) internal returns (bool) {
    return _add(set._inner, bytes32(value));
  }

  /**
   * @dev Removes a value from a set. O(1).
   *
   * Returns true if the value was removed from the set, that is if it was
   * present.
   */
  function remove(UintSet storage set, uint256 value) internal returns (bool) {
    return _remove(set._inner, bytes32(value));
  }

  /**
   * @dev Returns true if the value is in the set. O(1).
   */
  function contains(UintSet storage set, uint256 value) internal view returns (bool) {
    return _contains(set._inner, bytes32(value));
  }

  /**
   * @dev Returns the number of values in the set. O(1).
   */
  function length(UintSet storage set) internal view returns (uint256) {
    return _length(set._inner);
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(UintSet storage set, uint256 index) internal view returns (uint256) {
    return uint256(_at(set._inner, index));
  }

  /**
   * @dev Return the entire set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function values(UintSet storage set) internal view returns (uint256[] memory) {
    bytes32[] memory store = _values(set._inner);
    uint256[] memory result;

    /// @solidity memory-safe-assembly
    assembly {
      result := store
    }

    return result;
  }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
   * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
   */
  function sendValue(address payable recipient, uint256 amount) internal {
    require(address(this).balance >= amount, "Address: insufficient balance");

    (bool success, ) = recipient.call{ value: amount }("");
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
  function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    (bool success, bytes memory returndata) = target.call{ value: value }(data);
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

// lib/solmate/src/auth/Auth.sol

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
  event OwnerUpdated(address indexed user, address indexed newOwner);

  event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

  address public owner;

  Authority public authority;

  constructor(address _owner, Authority _authority) {
    owner = _owner;
    authority = _authority;

    emit OwnerUpdated(msg.sender, _owner);
    emit AuthorityUpdated(msg.sender, _authority);
  }

  modifier requiresAuth() virtual {
    require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

    _;
  }

  function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
    Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

    // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
    // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
    return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
  }

  function setAuthority(Authority newAuthority) public virtual {
    // We check if the caller is the owner first because we want to ensure they can
    // always swap out the authority even if it's reverting or using up a lot of gas.
    require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

    authority = newAuthority;

    emit AuthorityUpdated(msg.sender, newAuthority);
  }

  function setOwner(address newOwner) public virtual requiresAuth {
    owner = newOwner;

    emit OwnerUpdated(msg.sender, newOwner);
  }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
  function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

// lib/solmate/src/tokens/ERC20.sol

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event Transfer(address indexed from, address indexed to, uint256 amount);

  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

  string public name;

  string public symbol;

  uint8 public immutable decimals;

  /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

  uint256 public totalSupply;

  mapping(address => uint256) public balanceOf;

  mapping(address => mapping(address => uint256)) public allowance;

  /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

  uint256 internal immutable INITIAL_CHAIN_ID;

  bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

  mapping(address => uint256) public nonces;

  /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(string memory _name, string memory _symbol, uint8 _decimals) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;

    INITIAL_CHAIN_ID = block.chainid;
    INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
  }

  /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

  function approve(address spender, uint256 amount) public virtual returns (bool) {
    allowance[msg.sender][spender] = amount;

    emit Approval(msg.sender, spender, amount);

    return true;
  }

  function transfer(address to, uint256 amount) public virtual returns (bool) {
    balanceOf[msg.sender] -= amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    unchecked {
      balanceOf[to] += amount;
    }

    emit Transfer(msg.sender, to, amount);

    return true;
  }

  function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
    uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

    if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

    balanceOf[from] -= amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    unchecked {
      balanceOf[to] += amount;
    }

    emit Transfer(from, to, amount);

    return true;
  }

  /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual {
    require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

    // Unchecked because the only math done is incrementing
    // the owner's nonce which cannot realistically overflow.
    unchecked {
      address recoveredAddress = ecrecover(
        keccak256(
          abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR(),
            keccak256(
              abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline
              )
            )
          )
        ),
        v,
        r,
        s
      );

      require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

      allowance[recoveredAddress][spender] = value;
    }

    emit Approval(owner, spender, value);
  }

  function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
  }

  function computeDomainSeparator() internal view virtual returns (bytes32) {
    return
      keccak256(
        abi.encode(
          keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
          keccak256(bytes(name)),
          keccak256("1"),
          block.chainid,
          address(this)
        )
      );
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

  function _mint(address to, uint256 amount) internal virtual {
    totalSupply += amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    unchecked {
      balanceOf[to] += amount;
    }

    emit Transfer(address(0), to, amount);
  }

  function _burn(address from, uint256 amount) internal virtual {
    balanceOf[from] -= amount;

    // Cannot underflow because a user's balance
    // will never be larger than the total supply.
    unchecked {
      totalSupply -= amount;
    }

    emit Transfer(from, address(0), amount);
  }
}

// contracts/ionic/strategies/flywheel/IIonicFlywheel.sol

interface IIonicFlywheel {
  function isRewardsDistributor() external returns (bool);

  function isFlywheel() external returns (bool);

  function flywheelPreSupplierAction(address market, address supplier) external;

  function flywheelPreBorrowerAction(address market, address borrower) external;

  function flywheelPreTransferAction(address market, address src, address dst) external;

  function compAccrued(address user) external view returns (uint256);

  function addMarketForRewards(ERC20 strategy) external;

  function marketState(ERC20 strategy) external view returns (uint224 index, uint32 lastUpdatedTimestamp);
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
  /**
   * @dev Indicates that the contract has been initialized.
   * @custom:oz-retyped-from bool
   */
  uint8 private _initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private _initializing;

  /**
   * @dev Triggered when the contract has been initialized or reinitialized.
   */
  event Initialized(uint8 version);

  /**
   * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
   * `onlyInitializing` functions can be used to initialize parent contracts.
   *
   * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
   * constructor.
   *
   * Emits an {Initialized} event.
   */
  modifier initializer() {
    bool isTopLevelCall = !_initializing;
    require(
      (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
      "Initializable: contract is already initialized"
    );
    _initialized = 1;
    if (isTopLevelCall) {
      _initializing = true;
    }
    _;
    if (isTopLevelCall) {
      _initializing = false;
      emit Initialized(1);
    }
  }

  /**
   * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
   * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
   * used to initialize parent contracts.
   *
   * A reinitializer may be used after the original initialization step. This is essential to configure modules that
   * are added through upgrades and that require initialization.
   *
   * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
   * cannot be nested. If one is invoked in the context of another, execution will revert.
   *
   * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
   * a contract, executing them in the right order is up to the developer or operator.
   *
   * WARNING: setting the version to 255 will prevent any future reinitialization.
   *
   * Emits an {Initialized} event.
   */
  modifier reinitializer(uint8 version) {
    require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
    _initialized = version;
    _initializing = true;
    _;
    _initializing = false;
    emit Initialized(version);
  }

  /**
   * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
   * {initializer} and {reinitializer} modifiers, directly or indirectly.
   */
  modifier onlyInitializing() {
    require(_initializing, "Initializable: contract is not initializing");
    _;
  }

  /**
   * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
   * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
   * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
   * through proxies.
   *
   * Emits an {Initialized} event the first time it is successfully executed.
   */
  function _disableInitializers() internal virtual {
    require(!_initializing, "Initializable: contract is initializing");
    if (_initialized < type(uint8).max) {
      _initialized = type(uint8).max;
      emit Initialized(type(uint8).max);
    }
  }

  /**
   * @dev Internal function that returns the initialized version. Returns `_initialized`
   */
  function _getInitializedVersion() internal view returns (uint8) {
    return _initialized;
  }

  /**
   * @dev Internal function that returns the initialized version. Returns `_initializing`
   */
  function _isInitializing() internal view returns (bool) {
    return _initializing;
  }
}

// lib/solmate/src/auth/authorities/RolesAuthority.sol

/// @notice Role based Authority that supports up to 256 roles.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/authorities/RolesAuthority.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-roles/blob/master/src/roles.sol)
contract RolesAuthority is Auth, Authority {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);

  event PublicCapabilityUpdated(address indexed target, bytes4 indexed functionSig, bool enabled);

  event RoleCapabilityUpdated(uint8 indexed role, address indexed target, bytes4 indexed functionSig, bool enabled);

  /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

  /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

  mapping(address => bytes32) public getUserRoles;

  mapping(address => mapping(bytes4 => bool)) public isCapabilityPublic;

  mapping(address => mapping(bytes4 => bytes32)) public getRolesWithCapability;

  function doesUserHaveRole(address user, uint8 role) public view virtual returns (bool) {
    return (uint256(getUserRoles[user]) >> role) & 1 != 0;
  }

  function doesRoleHaveCapability(uint8 role, address target, bytes4 functionSig) public view virtual returns (bool) {
    return (uint256(getRolesWithCapability[target][functionSig]) >> role) & 1 != 0;
  }

  /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

  function canCall(address user, address target, bytes4 functionSig) public view virtual override returns (bool) {
    return
      isCapabilityPublic[target][functionSig] ||
      bytes32(0) != getUserRoles[user] & getRolesWithCapability[target][functionSig];
  }

  /*//////////////////////////////////////////////////////////////
                   ROLE CAPABILITY CONFIGURATION LOGIC
    //////////////////////////////////////////////////////////////*/

  function setPublicCapability(address target, bytes4 functionSig, bool enabled) public virtual requiresAuth {
    isCapabilityPublic[target][functionSig] = enabled;

    emit PublicCapabilityUpdated(target, functionSig, enabled);
  }

  function setRoleCapability(uint8 role, address target, bytes4 functionSig, bool enabled) public virtual requiresAuth {
    if (enabled) {
      getRolesWithCapability[target][functionSig] |= bytes32(1 << role);
    } else {
      getRolesWithCapability[target][functionSig] &= ~bytes32(1 << role);
    }

    emit RoleCapabilityUpdated(role, target, functionSig, enabled);
  }

  /*//////////////////////////////////////////////////////////////
                       USER ROLE ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

  function setUserRole(address user, uint8 role, bool enabled) public virtual requiresAuth {
    if (enabled) {
      getUserRoles[user] |= bytes32(1 << role);
    } else {
      getUserRoles[user] &= ~bytes32(1 << role);
    }

    emit UserRoleUpdated(user, role, enabled);
  }
}

// contracts/compound/Exponential.sol

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @dev Legacy contract for compatibility reasons with existing contracts that still use MathError
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract Exponential is CarefulMath, ExponentialNoError {
  /**
   * @dev Creates an exponential from numerator and denominator values.
   *      Note: Returns an error if (`num` * 10e18) > MAX_INT,
   *            or if `denom` is zero.
   */
  function getExp(uint256 num, uint256 denom) internal pure returns (MathError, Exp memory) {
    (MathError err0, uint256 scaledNumerator) = mulUInt(num, expScale);
    if (err0 != MathError.NO_ERROR) {
      return (err0, Exp({ mantissa: 0 }));
    }

    (MathError err1, uint256 rational) = divUInt(scaledNumerator, denom);
    if (err1 != MathError.NO_ERROR) {
      return (err1, Exp({ mantissa: 0 }));
    }

    return (MathError.NO_ERROR, Exp({ mantissa: rational }));
  }

  /**
   * @dev Adds two exponentials, returning a new exponential.
   */
  function addExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
    (MathError error, uint256 result) = addUInt(a.mantissa, b.mantissa);

    return (error, Exp({ mantissa: result }));
  }

  /**
   * @dev Subtracts two exponentials, returning a new exponential.
   */
  function subExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
    (MathError error, uint256 result) = subUInt(a.mantissa, b.mantissa);

    return (error, Exp({ mantissa: result }));
  }

  /**
   * @dev Multiply an Exp by a scalar, returning a new Exp.
   */
  function mulScalar(Exp memory a, uint256 scalar) internal pure returns (MathError, Exp memory) {
    (MathError err0, uint256 scaledMantissa) = mulUInt(a.mantissa, scalar);
    if (err0 != MathError.NO_ERROR) {
      return (err0, Exp({ mantissa: 0 }));
    }

    return (MathError.NO_ERROR, Exp({ mantissa: scaledMantissa }));
  }

  /**
   * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
   */
  function mulScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (MathError, uint256) {
    (MathError err, Exp memory product) = mulScalar(a, scalar);
    if (err != MathError.NO_ERROR) {
      return (err, 0);
    }

    return (MathError.NO_ERROR, truncate(product));
  }

  /**
   * @dev Divide an Exp by a scalar, returning a new Exp.
   */
  function divScalar(Exp memory a, uint256 scalar) internal pure returns (MathError, Exp memory) {
    (MathError err0, uint256 descaledMantissa) = divUInt(a.mantissa, scalar);
    if (err0 != MathError.NO_ERROR) {
      return (err0, Exp({ mantissa: 0 }));
    }

    return (MathError.NO_ERROR, Exp({ mantissa: descaledMantissa }));
  }

  /**
   * @dev Divide a scalar by an Exp, returning a new Exp.
   */
  function divScalarByExp(uint256 scalar, Exp memory divisor) internal pure returns (MathError, Exp memory) {
    /*
          We are doing this as:
          getExp(mulUInt(expScale, scalar), divisor.mantissa)

          How it works:
          Exp = a / b;
          Scalar = s;
          `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
        */
    (MathError err0, uint256 numerator) = mulUInt(expScale, scalar);
    if (err0 != MathError.NO_ERROR) {
      return (err0, Exp({ mantissa: 0 }));
    }
    return getExp(numerator, divisor.mantissa);
  }

  /**
   * @dev Divide a scalar by an Exp, then truncate to return an unsigned integer.
   */
  function divScalarByExpTruncate(uint256 scalar, Exp memory divisor) internal pure returns (MathError, uint256) {
    (MathError err, Exp memory fraction) = divScalarByExp(scalar, divisor);
    if (err != MathError.NO_ERROR) {
      return (err, 0);
    }

    return (MathError.NO_ERROR, truncate(fraction));
  }

  /**
   * @dev Multiplies two exponentials, returning a new exponential.
   */
  function mulExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
    (MathError err0, uint256 doubleScaledProduct) = mulUInt(a.mantissa, b.mantissa);
    if (err0 != MathError.NO_ERROR) {
      return (err0, Exp({ mantissa: 0 }));
    }

    // We add half the scale before dividing so that we get rounding instead of truncation.
    //  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717
    // Without this change, a result like 6.6...e-19 will be truncated to 0 instead of being rounded to 1e-18.
    (MathError err1, uint256 doubleScaledProductWithHalfScale) = addUInt(halfExpScale, doubleScaledProduct);
    if (err1 != MathError.NO_ERROR) {
      return (err1, Exp({ mantissa: 0 }));
    }

    (MathError err2, uint256 product) = divUInt(doubleScaledProductWithHalfScale, expScale);
    // The only error `div` can return is MathError.DIVISION_BY_ZERO but we control `expScale` and it is not zero.
    assert(err2 == MathError.NO_ERROR);

    return (MathError.NO_ERROR, Exp({ mantissa: product }));
  }

  /**
   * @dev Multiplies two exponentials given their mantissas, returning a new exponential.
   */
  function mulExp(uint256 a, uint256 b) internal pure returns (MathError, Exp memory) {
    return mulExp(Exp({ mantissa: a }), Exp({ mantissa: b }));
  }

  /**
   * @dev Multiplies three exponentials, returning a new exponential.
   */
  function mulExp3(Exp memory a, Exp memory b, Exp memory c) internal pure returns (MathError, Exp memory) {
    (MathError err, Exp memory ab) = mulExp(a, b);
    if (err != MathError.NO_ERROR) {
      return (err, ab);
    }
    return mulExp(ab, c);
  }

  /**
   * @dev Divides two exponentials, returning a new exponential.
   *     (a/scale) / (b/scale) = (a/scale) * (scale/b) = a/b,
   *  which we can scale as an Exp by calling getExp(a.mantissa, b.mantissa)
   */
  function divExp(Exp memory a, Exp memory b) internal pure returns (MathError, Exp memory) {
    return getExp(a.mantissa, b.mantissa);
  }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
abstract contract ContextUpgradeable is Initializable {
  function __Context_init() internal onlyInitializing {}

  function __Context_init_unchained() internal onlyInitializing {}
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[50] private __gap;
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  function __Ownable_init() internal onlyInitializing {
    __Ownable_init_unchained();
  }

  function __Ownable_init_unchained() internal onlyInitializing {
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
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
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

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[49] private __gap;
}

// contracts/ionic/SafeOwnableUpgradeable.sol

/**
 * @dev Ownable extension that requires a two-step process of setting the pending owner and the owner accepting it.
 * @notice Existing OwnableUpgradeable contracts cannot be upgraded due to the extra storage variable
 * that will shift the other.
 */
abstract contract SafeOwnableUpgradeable is OwnableUpgradeable {
  /**
   * @notice Pending owner of this contract
   */
  address public pendingOwner;

  function __SafeOwnable_init(address owner_) internal onlyInitializing {
    __Ownable_init();
    _transferOwnership(owner_);
  }

  struct AddressSlot {
    address value;
  }

  modifier onlyOwnerOrAdmin() {
    bool isOwner = owner() == _msgSender();
    if (!isOwner) {
      address admin = _getProxyAdmin();
      bool isAdmin = admin == _msgSender();
      require(isAdmin, "Ownable: caller is neither the owner nor the admin");
    }
    _;
  }

  /**
   * @notice Emitted when pendingOwner is changed
   */
  event NewPendingOwner(address oldPendingOwner, address newPendingOwner);

  /**
   * @notice Emitted when pendingOwner is accepted, which means owner is updated
   */
  event NewOwner(address oldOwner, address newOwner);

  /**
   * @notice Begins transfer of owner rights. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
   * @dev Owner function to begin change of owner. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
   * @param newPendingOwner New pending owner.
   */
  function _setPendingOwner(address newPendingOwner) public onlyOwner {
    // Save current value, if any, for inclusion in log
    address oldPendingOwner = pendingOwner;

    // Store pendingOwner with value newPendingOwner
    pendingOwner = newPendingOwner;

    // Emit NewPendingOwner(oldPendingOwner, newPendingOwner)
    emit NewPendingOwner(oldPendingOwner, newPendingOwner);
  }

  /**
   * @notice Accepts transfer of owner rights. msg.sender must be pendingOwner
   * @dev Owner function for pending owner to accept role and update owner
   */
  function _acceptOwner() public {
    // Check caller is pendingOwner and pendingOwner ≠ address(0)
    require(msg.sender == pendingOwner, "not the pending owner");

    // Save current values for inclusion in log
    address oldOwner = owner();
    address oldPendingOwner = pendingOwner;

    // Store owner with value pendingOwner
    _transferOwnership(pendingOwner);

    // Clear the pending value
    pendingOwner = address(0);

    emit NewOwner(oldOwner, pendingOwner);
    emit NewPendingOwner(oldPendingOwner, pendingOwner);
  }

  function renounceOwnership() public override onlyOwner {
    // do not remove this overriding fn
    revert("not used anymore");
  }

  function transferOwnership(address newOwner) public override onlyOwner {
    emit NewPendingOwner(pendingOwner, newOwner);
    pendingOwner = newOwner;
  }

  function _getProxyAdmin() internal view returns (address admin) {
    bytes32 _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    AddressSlot storage adminSlot;
    assembly {
      adminSlot.slot := _ADMIN_SLOT
    }
    admin = adminSlot.value;
  }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol

// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
  // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
  bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);

  /**
   * @dev Returns the current implementation address.
   */
  function _getImplementation() internal view returns (address) {
    return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 implementation slot.
   */
  function _setImplementation(address newImplementation) private {
    require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
    StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
  }

  /**
   * @dev Perform implementation upgrade
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeTo(address newImplementation) internal {
    _setImplementation(newImplementation);
    emit Upgraded(newImplementation);
  }

  /**
   * @dev Perform implementation upgrade with additional setup call.
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
    _upgradeTo(newImplementation);
    if (data.length > 0 || forceCall) {
      Address.functionDelegateCall(newImplementation, data);
    }
  }

  /**
   * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
    // Upgrades from old implementations will perform a rollback test. This test requires the new
    // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
    // this special case will break upgrade paths from old UUPS implementation to new ones.
    if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
      _setImplementation(newImplementation);
    } else {
      try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
        require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
      } catch {
        revert("ERC1967Upgrade: new implementation is not UUPS");
      }
      _upgradeToAndCall(newImplementation, data, forceCall);
    }
  }

  /**
   * @dev Storage slot with the admin of the contract.
   * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /**
   * @dev Emitted when the admin account has changed.
   */
  event AdminChanged(address previousAdmin, address newAdmin);

  /**
   * @dev Returns the current admin.
   */
  function _getAdmin() internal view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 admin slot.
   */
  function _setAdmin(address newAdmin) private {
    require(newAdmin != address(0), "ERC1967: new admin is the zero address");
    StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
  }

  /**
   * @dev Changes the admin of the proxy.
   *
   * Emits an {AdminChanged} event.
   */
  function _changeAdmin(address newAdmin) internal {
    emit AdminChanged(_getAdmin(), newAdmin);
    _setAdmin(newAdmin);
  }

  /**
   * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
   * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
   */
  bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

  /**
   * @dev Emitted when the beacon is upgraded.
   */
  event BeaconUpgraded(address indexed beacon);

  /**
   * @dev Returns the current beacon.
   */
  function _getBeacon() internal view returns (address) {
    return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
  }

  /**
   * @dev Stores a new beacon in the EIP1967 beacon slot.
   */
  function _setBeacon(address newBeacon) private {
    require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
    require(
      Address.isContract(IBeacon(newBeacon).implementation()),
      "ERC1967: beacon implementation is not a contract"
    );
    StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
  }

  /**
   * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
   * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
   *
   * Emits a {BeaconUpgraded} event.
   */
  function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
    _setBeacon(newBeacon);
    emit BeaconUpgraded(newBeacon);
    if (data.length > 0 || forceCall) {
      Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
    }
  }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
  /**
   * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
   *
   * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
   * function call, and allows initializing the storage of the proxy like a Solidity constructor.
   */
  constructor(address _logic, bytes memory _data) payable {
    _upgradeToAndCall(_logic, _data, false);
  }

  /**
   * @dev Returns the current implementation address.
   */
  function _implementation() internal view virtual override returns (address impl) {
    return ERC1967Upgrade._getImplementation();
  }
}

// lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/transparent/TransparentUpgradeableProxy.sol)

/**
 * @dev This contract implements a proxy that is upgradeable by an admin.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches one of the admin functions exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the
 * implementation. If the admin tries to call a function on the implementation it will fail with an error that says
 * "admin cannot fallback to proxy target".
 *
 * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing
 * the admin, so it's best if it's a dedicated account that is not used for anything else. This will avoid headaches due
 * to sudden errors when trying to call a function from the proxy implementation.
 *
 * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,
 * you should think of the `ProxyAdmin` instance as the real administrative interface of your proxy.
 */
contract TransparentUpgradeableProxy is ERC1967Proxy {
  /**
   * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
   * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
   */
  constructor(address _logic, address admin_, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
    _changeAdmin(admin_);
  }

  /**
   * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
   */
  modifier ifAdmin() {
    if (msg.sender == _getAdmin()) {
      _;
    } else {
      _fallback();
    }
  }

  /**
   * @dev Returns the current admin.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
   */
  function admin() external ifAdmin returns (address admin_) {
    admin_ = _getAdmin();
  }

  /**
   * @dev Returns the current implementation.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
   */
  function implementation() external ifAdmin returns (address implementation_) {
    implementation_ = _implementation();
  }

  /**
   * @dev Changes the admin of the proxy.
   *
   * Emits an {AdminChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.
   */
  function changeAdmin(address newAdmin) external virtual ifAdmin {
    _changeAdmin(newAdmin);
  }

  /**
   * @dev Upgrade the implementation of the proxy.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.
   */
  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeToAndCall(newImplementation, bytes(""), false);
  }

  /**
   * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
   * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
   * proxied contract.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.
   */
  function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
    _upgradeToAndCall(newImplementation, data, true);
  }

  /**
   * @dev Returns the current admin.
   */
  function _admin() internal view virtual returns (address) {
    return _getAdmin();
  }

  /**
   * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.
   */
  function _beforeFallback() internal virtual override {
    require(msg.sender != _getAdmin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
    super._beforeFallback();
  }
}

// contracts/compound/CTokenInterfaces.sol

abstract contract CTokenAdminStorage {
  /*
   * Administrator for Ionic
   */
  address payable public ionicAdmin;
}

abstract contract CErc20Storage is CTokenAdminStorage {
  /**
   * @dev Guard variable for re-entrancy checks
   */
  bool internal _notEntered;

  /**
   * @notice EIP-20 token name for this token
   */
  string public name;

  /**
   * @notice EIP-20 token symbol for this token
   */
  string public symbol;

  /**
   * @notice EIP-20 token decimals for this token
   */
  uint8 public decimals;

  /*
   * Maximum borrow rate that can ever be applied (.0005% / block)
   */
  uint256 internal constant borrowRateMaxMantissa = 0.0005e16;

  /*
   * Maximum fraction of interest that can be set aside for reserves + fees
   */
  uint256 internal constant reserveFactorPlusFeesMaxMantissa = 1e18;

  /**
   * @notice Contract which oversees inter-cToken operations
   */
  IonicComptroller public comptroller;

  /**
   * @notice Model which tells what the current interest rate should be
   */
  InterestRateModel public interestRateModel;

  /*
   * Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
   */
  uint256 internal initialExchangeRateMantissa;

  /**
   * @notice Fraction of interest currently set aside for admin fees
   */
  uint256 public adminFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for Ionic fees
   */
  uint256 public ionicFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for reserves
   */
  uint256 public reserveFactorMantissa;

  /**
   * @notice Block number that interest was last accrued at
   */
  uint256 public accrualBlockNumber;

  /**
   * @notice Accumulator of the total earned interest rate since the opening of the market
   */
  uint256 public borrowIndex;

  /**
   * @notice Total amount of outstanding borrows of the underlying in this market
   */
  uint256 public totalBorrows;

  /**
   * @notice Total amount of reserves of the underlying held in this market
   */
  uint256 public totalReserves;

  /**
   * @notice Total amount of admin fees of the underlying held in this market
   */
  uint256 public totalAdminFees;

  /**
   * @notice Total amount of Ionic fees of the underlying held in this market
   */
  uint256 public totalIonicFees;

  /**
   * @notice Total number of tokens in circulation
   */
  uint256 public totalSupply;

  /*
   * Official record of token balances for each account
   */
  mapping(address => uint256) internal accountTokens;

  /*
   * Approved token transfer amounts on behalf of others
   */
  mapping(address => mapping(address => uint256)) internal transferAllowances;

  /**
   * @notice Container for borrow balance information
   * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
   * @member interestIndex Global borrowIndex as of the most recent balance-changing action
   */
  struct BorrowSnapshot {
    uint256 principal;
    uint256 interestIndex;
  }

  /*
   * Mapping of account addresses to outstanding borrow balances
   */
  mapping(address => BorrowSnapshot) internal accountBorrows;

  /*
   * Share of seized collateral that is added to reserves
   */
  uint256 public constant protocolSeizeShareMantissa = 2.8e16; //2.8%

  /*
   * Share of seized collateral taken as fees
   */
  uint256 public constant feeSeizeShareMantissa = 1e17; //10%

  /**
   * @notice Underlying asset for this CToken
   */
  address public underlying;
}

abstract contract CTokenBaseEvents {
  /* ERC20 */

  /**
   * @notice EIP20 Transfer event
   */
  event Transfer(address indexed from, address indexed to, uint256 amount);

  /*** Admin Events ***/

  /**
   * @notice Event emitted when interestRateModel is changed
   */
  event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

  /**
   * @notice Event emitted when the reserve factor is changed
   */
  event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);

  /**
   * @notice Event emitted when the admin fee is changed
   */
  event NewAdminFee(uint256 oldAdminFeeMantissa, uint256 newAdminFeeMantissa);

  /**
   * @notice Event emitted when the Ionic fee is changed
   */
  event NewIonicFee(uint256 oldIonicFeeMantissa, uint256 newIonicFeeMantissa);

  /**
   * @notice EIP20 Approval event
   */
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /**
   * @notice Event emitted when interest is accrued
   */
  event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
}

abstract contract CTokenFirstExtensionEvents is CTokenBaseEvents {
  event Flash(address receiver, uint256 amount);
}

abstract contract CTokenSecondExtensionEvents is CTokenBaseEvents {
  /*** Market Events ***/

  /**
   * @notice Event emitted when tokens are minted
   */
  event Mint(address minter, uint256 mintAmount, uint256 mintTokens);

  /**
   * @notice Event emitted when tokens are redeemed
   */
  event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);

  /**
   * @notice Event emitted when underlying is borrowed
   */
  event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is repaid
   */
  event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is liquidated
   */
  event LiquidateBorrow(
    address liquidator,
    address borrower,
    uint256 repayAmount,
    address cTokenCollateral,
    uint256 seizeTokens
  );

  /**
   * @notice Event emitted when the reserves are added
   */
  event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);

  /**
   * @notice Event emitted when the reserves are reduced
   */
  event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
}

interface CTokenFirstExtensionInterface {
  /*** User Interface ***/

  function transfer(address dst, uint256 amount) external returns (bool);

  function transferFrom(address src, address dst, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  /*** Admin Functions ***/

  function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

  function _setAdminFee(uint256 newAdminFeeMantissa) external returns (uint256);

  function _setInterestRateModel(InterestRateModel newInterestRateModel) external returns (uint256);

  function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

  function borrowRatePerBlock() external view returns (uint256);

  function supplyRatePerBlock() external view returns (uint256);

  function exchangeRateCurrent() external view returns (uint256);

  function accrueInterest() external returns (uint256);

  function totalBorrowsCurrent() external view returns (uint256);

  function borrowBalanceCurrent(address account) external view returns (uint256);

  function getTotalUnderlyingSupplied() external view returns (uint256);

  function balanceOfUnderlying(address owner) external view returns (uint256);

  function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

  function flash(uint256 amount, bytes calldata data) external;

  function supplyRatePerBlockAfterDeposit(uint256 mintAmount) external view returns (uint256);

  function supplyRatePerBlockAfterWithdraw(uint256 withdrawAmount) external view returns (uint256);

  function borrowRatePerBlockAfterBorrow(uint256 borrowAmount) external view returns (uint256);

  function registerInSFS() external returns (uint256);
}

interface CTokenSecondExtensionInterface {
  function mint(uint256 mintAmount) external returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

  function borrow(uint256 borrowAmount) external returns (uint256);

  function repayBorrow(uint256 repayAmount) external returns (uint256);

  function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

  function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);

  function getCash() external view returns (uint256);

  function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

  /*** Admin Functions ***/

  function _withdrawAdminFees(uint256 withdrawAmount) external returns (uint256);

  function _withdrawIonicFees(uint256 withdrawAmount) external returns (uint256);

  function selfTransferOut(address to, uint256 amount) external;

  function selfTransferIn(address from, uint256 amount) external returns (uint256);
}

interface CDelegatorInterface {
  function implementation() external view returns (address);

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(address implementation_, bytes calldata becomeImplementationData) external;

  /**
   * @dev upgrades the implementation if necessary
   */
  function _upgrade() external;
}

interface CDelegateInterface {
  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   * @dev Should revert if any issues arise which make it unfit for delegation
   * @param data The encoded bytes data for any initialization
   */
  function _becomeImplementation(bytes calldata data) external;

  function delegateType() external pure returns (uint8);

  function contractType() external pure returns (string memory);
}

abstract contract CErc20AdminBase is CErc20Storage {
  /**
   * @notice Returns a boolean indicating if the sender has admin rights
   */
  function hasAdminRights() internal view returns (bool) {
    ComptrollerV3Storage comptrollerStorage = ComptrollerV3Storage(address(comptroller));
    return
      (msg.sender == comptrollerStorage.admin() && comptrollerStorage.adminHasRights()) ||
      (msg.sender == address(ionicAdmin) && comptrollerStorage.ionicAdminHasRights());
  }
}

abstract contract CErc20FirstExtensionBase is
  CErc20AdminBase,
  CTokenFirstExtensionEvents,
  CTokenFirstExtensionInterface
{}

abstract contract CTokenSecondExtensionBase is
  CErc20AdminBase,
  CTokenSecondExtensionEvents,
  CTokenSecondExtensionInterface,
  CDelegateInterface
{}

abstract contract CErc20DelegatorBase is CErc20AdminBase, CTokenSecondExtensionEvents, CDelegatorInterface {}

interface CErc20StorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdmin() external view returns (address);

  function ionicAdminHasRights() external view returns (bool);

  function comptroller() external view returns (IonicComptroller);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function adminFeeMantissa() external view returns (uint256);

  function ionicFeeMantissa() external view returns (uint256);

  function reserveFactorMantissa() external view returns (uint256);

  function protocolSeizeShareMantissa() external view returns (uint256);

  function feeSeizeShareMantissa() external view returns (uint256);

  function totalReserves() external view returns (uint256);

  function totalAdminFees() external view returns (uint256);

  function totalIonicFees() external view returns (uint256);

  function totalBorrows() external view returns (uint256);

  function accrualBlockNumber() external view returns (uint256);

  function underlying() external view returns (address);

  function borrowIndex() external view returns (uint256);

  function interestRateModel() external view returns (address);
}

interface CErc20PluginStorageInterface is CErc20StorageInterface {
  function plugin() external view returns (address);
}

interface CErc20PluginRewardsInterface is CErc20PluginStorageInterface {
  function approve(address, address) external;
}

interface ICErc20 is
  CErc20StorageInterface,
  CTokenSecondExtensionInterface,
  CTokenFirstExtensionInterface,
  CDelegatorInterface,
  CDelegateInterface
{}

interface ICErc20Plugin is CErc20PluginStorageInterface, ICErc20 {
  function _updatePlugin(address _plugin) external;
}

interface ICErc20PluginRewards is CErc20PluginRewardsInterface, ICErc20 {}

// contracts/compound/ComptrollerInterface.sol

interface ComptrollerInterface {
  function isDeprecated(ICErc20 cToken) external view returns (bool);

  function _becomeImplementation() external;

  function _deployMarket(
    uint8 delegateType,
    bytes memory constructorData,
    bytes calldata becomeImplData,
    uint256 collateralFactorMantissa
  ) external returns (uint256);

  function getAssetsIn(address account) external view returns (ICErc20[] memory);

  function checkMembership(address account, ICErc20 cToken) external view returns (bool);

  function _setPriceOracle(BasePriceOracle newOracle) external returns (uint256);

  function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256);

  function _setCollateralFactor(ICErc20 market, uint256 newCollateralFactorMantissa) external returns (uint256);

  function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256);

  function _setWhitelistEnforcement(bool enforce) external returns (uint256);

  function _setWhitelistStatuses(address[] calldata _suppliers, bool[] calldata statuses) external returns (uint256);

  function _addRewardsDistributor(address distributor) external returns (uint256);

  function getHypotheticalAccountLiquidity(
    address account,
    address cTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount,
    uint256 repayAmount
  ) external view returns (uint256, uint256, uint256, uint256);

  function getMaxRedeemOrBorrow(address account, ICErc20 cToken, bool isBorrow) external view returns (uint256);

  /*** Assets You Are In ***/

  function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);

  function exitMarket(address cToken) external returns (uint256);

  /*** Policy Hooks ***/

  function mintAllowed(address cToken, address minter, uint256 mintAmount) external returns (uint256);

  function redeemAllowed(address cToken, address redeemer, uint256 redeemTokens) external returns (uint256);

  function redeemVerify(address cToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external;

  function borrowAllowed(address cToken, address borrower, uint256 borrowAmount) external returns (uint256);

  function borrowWithinLimits(address cToken, uint256 accountBorrowsNew) external view returns (uint256);

  function repayBorrowAllowed(
    address cToken,
    address payer,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function liquidateBorrowAllowed(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function seizeAllowed(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external returns (uint256);

  function transferAllowed(address cToken, address src, address dst, uint256 transferTokens) external returns (uint256);

  function mintVerify(address cToken, address minter, uint256 actualMintAmount, uint256 mintTokens) external;

  /*** Liquidity/Liquidation Calculations ***/

  function getAccountLiquidity(
    address account
  ) external view returns (uint256 error, uint256 collateralValue, uint256 liquidity, uint256 shortfall);

  function liquidateCalculateSeizeTokens(
    address cTokenBorrowed,
    address cTokenCollateral,
    uint256 repayAmount
  ) external view returns (uint256, uint256);

  /*** Pool-Wide/Cross-Asset Reentrancy Prevention ***/

  function _beforeNonReentrant() external;

  function _afterNonReentrant() external;
}

interface ComptrollerStorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdmin() external view returns (address);

  function ionicAdminHasRights() external view returns (bool);

  function pendingAdmin() external view returns (address);

  function oracle() external view returns (BasePriceOracle);

  function pauseGuardian() external view returns (address);

  function closeFactorMantissa() external view returns (uint256);

  function liquidationIncentiveMantissa() external view returns (uint256);

  function isUserOfPool(address user) external view returns (bool);

  function whitelist(address account) external view returns (bool);

  function enforceWhitelist() external view returns (bool);

  function borrowCapForCollateral(address borrowed, address collateral) external view returns (uint256);

  function borrowingAgainstCollateralBlacklist(address borrowed, address collateral) external view returns (bool);

  function suppliers(address account) external view returns (bool);

  function cTokensByUnderlying(address) external view returns (address);

  function supplyCaps(address cToken) external view returns (uint256);

  function borrowCaps(address cToken) external view returns (uint256);

  function markets(address cToken) external view returns (bool, uint256);

  function accountAssets(address, uint256) external view returns (address);

  function borrowGuardianPaused(address cToken) external view returns (bool);

  function mintGuardianPaused(address cToken) external view returns (bool);

  function rewardsDistributors(uint256) external view returns (address);
}

interface SFSRegister {
  function register(address _recipient) external returns (uint256 tokenId);
}

interface ComptrollerExtensionInterface {
  function getWhitelistedSuppliersSupply(address cToken) external view returns (uint256 supplied);

  function getWhitelistedBorrowersBorrows(address cToken) external view returns (uint256 borrowed);

  function getAllMarkets() external view returns (ICErc20[] memory);

  function getAllBorrowers() external view returns (address[] memory);

  function getAllBorrowersCount() external view returns (uint256);

  function getPaginatedBorrowers(
    uint256 page,
    uint256 pageSize
  ) external view returns (uint256 _totalPages, address[] memory _pageOfBorrowers);

  function getRewardsDistributors() external view returns (address[] memory);

  function getAccruingFlywheels() external view returns (address[] memory);

  function _supplyCapWhitelist(address cToken, address account, bool whitelisted) external;

  function _setBorrowCapForCollateral(address cTokenBorrow, address cTokenCollateral, uint256 borrowCap) external;

  function _setBorrowCapForCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBorrowCapForCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function _blacklistBorrowingAgainstCollateral(
    address cTokenBorrow,
    address cTokenCollateral,
    bool blacklisted
  ) external;

  function _blacklistBorrowingAgainstCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBlacklistBorrowingAgainstCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function isSupplyCapWhitelisted(address cToken, address account) external view returns (bool);

  function _borrowCapWhitelist(address cToken, address account, bool whitelisted) external;

  function isBorrowCapWhitelisted(address cToken, address account) external view returns (bool);

  function _removeFlywheel(address flywheelAddress) external returns (bool);

  function getWhitelist() external view returns (address[] memory);

  function addNonAccruingFlywheel(address flywheelAddress) external returns (bool);

  function _setMarketSupplyCaps(ICErc20[] calldata cTokens, uint256[] calldata newSupplyCaps) external;

  function _setMarketBorrowCaps(ICErc20[] calldata cTokens, uint256[] calldata newBorrowCaps) external;

  function _setBorrowCapGuardian(address newBorrowCapGuardian) external;

  function _setPauseGuardian(address newPauseGuardian) external returns (uint256);

  function _setMintPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setBorrowPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setTransferPaused(bool state) external returns (bool);

  function _setSeizePaused(bool state) external returns (bool);

  function _unsupportMarket(ICErc20 cToken) external returns (uint256);

  function getAssetAsCollateralValueCap(
    ICErc20 collateral,
    ICErc20 cTokenModify,
    bool redeeming,
    address account
  ) external view returns (uint256);

  function registerInSFS() external returns (uint256);
}

interface UnitrollerInterface {
  function comptrollerImplementation() external view returns (address);

  function _upgrade() external;

  function _acceptAdmin() external returns (uint256);

  function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

  function _toggleAdminRights(bool hasRights) external returns (uint256);
}

interface IComptrollerExtension is ComptrollerExtensionInterface, ComptrollerStorageInterface {}

//interface IComptrollerBase is ComptrollerInterface, ComptrollerStorageInterface {}

interface IonicComptroller is
  ComptrollerInterface,
  ComptrollerExtensionInterface,
  UnitrollerInterface,
  ComptrollerStorageInterface
{}

// contracts/compound/ComptrollerStorage.sol

contract UnitrollerAdminStorage {
  /*
   * Administrator for Ionic
   */
  address payable public ionicAdmin;

  /**
   * @notice Administrator for this contract
   */
  address public admin;

  /**
   * @notice Pending administrator for this contract
   */
  address public pendingAdmin;

  /**
   * @notice Whether or not the Ionic admin has admin rights
   */
  bool public ionicAdminHasRights = true;

  /**
   * @notice Whether or not the admin has admin rights
   */
  bool public adminHasRights = true;

  /**
   * @notice Returns a boolean indicating if the sender has admin rights
   */
  function hasAdminRights() internal view returns (bool) {
    return (msg.sender == admin && adminHasRights) || (msg.sender == address(ionicAdmin) && ionicAdminHasRights);
  }
}

contract ComptrollerV1Storage is UnitrollerAdminStorage {
  /**
   * @notice Oracle which gives the price of any given asset
   */
  BasePriceOracle public oracle;

  /**
   * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
   */
  uint256 public closeFactorMantissa;

  /**
   * @notice Multiplier representing the discount on collateral that a liquidator receives
   */
  uint256 public liquidationIncentiveMantissa;

  /*
   * UNUSED AFTER UPGRADE: Max number of assets a single account can participate in (borrow or use as collateral)
   */
  uint256 internal maxAssets;

  /**
   * @notice Per-account mapping of "assets you are in", capped by maxAssets
   */
  mapping(address => ICErc20[]) public accountAssets;
}

contract ComptrollerV2Storage is ComptrollerV1Storage {
  struct Market {
    // Whether or not this market is listed
    bool isListed;
    // Multiplier representing the most one can borrow against their collateral in this market.
    // For instance, 0.9 to allow borrowing 90% of collateral value.
    // Must be between 0 and 1, and stored as a mantissa.
    uint256 collateralFactorMantissa;
    // Per-market mapping of "accounts in this asset"
    mapping(address => bool) accountMembership;
  }

  /**
   * @notice Official mapping of cTokens -> Market metadata
   * @dev Used e.g. to determine if a market is supported
   */
  mapping(address => Market) public markets;

  /// @notice A list of all markets
  ICErc20[] public allMarkets;

  /**
   * @dev Maps borrowers to booleans indicating if they have entered any markets
   */
  mapping(address => bool) internal borrowers;

  /// @notice A list of all borrowers who have entered markets
  address[] public allBorrowers;

  // Indexes of borrower account addresses in the `allBorrowers` array
  mapping(address => uint256) internal borrowerIndexes;

  /**
   * @dev Maps suppliers to booleans indicating if they have ever supplied to any markets
   */
  mapping(address => bool) public suppliers;

  /// @notice All cTokens addresses mapped by their underlying token addresses
  mapping(address => ICErc20) public cTokensByUnderlying;

  /// @notice Whether or not the supplier whitelist is enforced
  bool public enforceWhitelist;

  /// @notice Maps addresses to booleans indicating if they are allowed to supply assets (i.e., mint cTokens)
  mapping(address => bool) public whitelist;

  /// @notice An array of all whitelisted accounts
  address[] public whitelistArray;

  // Indexes of account addresses in the `whitelistArray` array
  mapping(address => uint256) internal whitelistIndexes;

  /**
   * @notice The Pause Guardian can pause certain actions as a safety mechanism.
   *  Actions which allow users to remove their own assets cannot be paused.
   *  Liquidation / seizing / transfer can only be paused globally, not by market.
   */
  address public pauseGuardian;
  bool public _mintGuardianPaused;
  bool public _borrowGuardianPaused;
  bool public transferGuardianPaused;
  bool public seizeGuardianPaused;
  mapping(address => bool) public mintGuardianPaused;
  mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
  /// @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
  address public borrowCapGuardian;

  /// @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
  mapping(address => uint256) public borrowCaps;

  /// @notice Supply caps enforced by mintAllowed for each cToken address. Defaults to zero which corresponds to unlimited supplying.
  mapping(address => uint256) public supplyCaps;

  /// @notice RewardsDistributor contracts to notify of flywheel changes.
  address[] public rewardsDistributors;

  /// @dev Guard variable for pool-wide/cross-asset re-entrancy checks
  bool internal _notEntered;

  /// @dev Whether or not _notEntered has been initialized
  bool internal _notEnteredInitialized;

  /// @notice RewardsDistributor to list for claiming, but not to notify of flywheel changes.
  address[] public nonAccruingRewardsDistributors;

  /// @dev cap for each user's borrows against specific assets - denominated in the borrowed asset
  mapping(address => mapping(address => uint256)) public borrowCapForCollateral;

  /// @dev blacklist to disallow the borrowing of an asset against specific collateral
  mapping(address => mapping(address => bool)) public borrowingAgainstCollateralBlacklist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrowing against specific collateral cap
  mapping(address => mapping(address => EnumerableSet.AddressSet)) internal borrowCapForCollateralWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrow cap
  mapping(address => mapping(address => EnumerableSet.AddressSet))
    internal borrowingAgainstCollateralBlacklistWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the supply cap
  mapping(address => EnumerableSet.AddressSet) internal supplyCapWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrow cap
  mapping(address => EnumerableSet.AddressSet) internal borrowCapWhitelist;
}
abstract contract ComptrollerBase is ComptrollerV3Storage {
  /// @notice Indicator that this is a Comptroller contract (for inspection)
  bool public constant isComptroller = true;
}

// contracts/compound/IFeeDistributor.sol

interface IFeeDistributor {
  function minBorrowEth() external view returns (uint256);

  function maxUtilizationRate() external view returns (uint256);

  function interestFeeRate() external view returns (uint256);

  function latestComptrollerImplementation(address oldImplementation) external view returns (address);

  function latestCErc20Delegate(
    uint8 delegateType
  ) external view returns (address cErc20Delegate, bytes memory becomeImplementationData);

  function latestPluginImplementation(address oldImplementation) external view returns (address);

  function getComptrollerExtensions(address comptroller) external view returns (address[] memory);

  function getCErc20DelegateExtensions(address cErc20Delegate) external view returns (address[] memory);

  function deployCErc20(
    uint8 delegateType,
    bytes calldata constructorData,
    bytes calldata becomeImplData
  ) external returns (address);

  function canCall(address pool, address user, address target, bytes4 functionSig) external view returns (bool);

  function authoritiesRegistry() external view returns (AuthoritiesRegistry);

  fallback() external payable;

  receive() external payable;
}

// contracts/ionic/AuthoritiesRegistry.sol

contract AuthoritiesRegistry is SafeOwnableUpgradeable {
  mapping(address => PoolRolesAuthority) public poolsAuthorities;
  PoolRolesAuthority public poolAuthLogic;
  address public leveredPositionsFactory;
  bool public noAuthRequired;

  function initialize(address _leveredPositionsFactory) public initializer {
    __SafeOwnable_init(msg.sender);
    leveredPositionsFactory = _leveredPositionsFactory;
    poolAuthLogic = new PoolRolesAuthority();
  }

  function reinitialize(address _leveredPositionsFactory) public onlyOwnerOrAdmin {
    leveredPositionsFactory = _leveredPositionsFactory;
    poolAuthLogic = new PoolRolesAuthority();
    // for Neon the auth is not required
    noAuthRequired = block.chainid == 245022934;
  }

  function createPoolAuthority(address pool) public onlyOwner returns (PoolRolesAuthority auth) {
    require(address(poolsAuthorities[pool]) == address(0), "already created");

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(poolAuthLogic), _getProxyAdmin(), "");
    auth = PoolRolesAuthority(address(proxy));
    auth.initialize(address(this));
    poolsAuthorities[pool] = auth;

    auth.openPoolSupplierCapabilities(IonicComptroller(pool));
    auth.setUserRole(address(this), auth.REGISTRY_ROLE(), true);
    // sets the registry owner as the auth owner
    reconfigureAuthority(pool);
  }

  function reconfigureAuthority(address poolAddress) public {
    IonicComptroller pool = IonicComptroller(poolAddress);
    PoolRolesAuthority auth = poolsAuthorities[address(pool)];

    if (msg.sender != poolAddress || address(auth) != address(0)) {
      require(address(auth) != address(0), "no such authority");
      require(msg.sender == owner() || msg.sender == poolAddress, "not owner or pool");

      auth.configureRegistryCapabilities();
      auth.configurePoolSupplierCapabilities(pool);
      auth.configurePoolBorrowerCapabilities(pool);
      // everyone can be a liquidator
      auth.configureOpenPoolLiquidatorCapabilities(pool);
      auth.configureLeveredPositionCapabilities(pool);

      if (auth.owner() != owner()) {
        auth.setOwner(owner());
      }
    }
  }

  function canCall(address pool, address user, address target, bytes4 functionSig) external view returns (bool) {
    PoolRolesAuthority authorityForPool = poolsAuthorities[pool];
    if (address(authorityForPool) == address(0)) {
      return noAuthRequired;
    } else {
      // allow only if an auth exists and it allows the action
      return authorityForPool.canCall(user, target, functionSig);
    }
  }

  function setUserRole(address pool, address user, uint8 role, bool enabled) external {
    PoolRolesAuthority poolAuth = poolsAuthorities[pool];

    require(address(poolAuth) != address(0), "auth does not exist");
    require(msg.sender == owner() || msg.sender == leveredPositionsFactory, "not owner or factory");
    require(msg.sender != leveredPositionsFactory || role == poolAuth.LEVERED_POSITION_ROLE(), "only lev pos role");

    poolAuth.setUserRole(user, role, enabled);
  }
}

// contracts/ionic/PoolRolesAuthority.sol

contract PoolRolesAuthority is RolesAuthority, Initializable {
  constructor() RolesAuthority(address(0), Authority(address(0))) {
    _disableInitializers();
  }

  function initialize(address _owner) public initializer {
    owner = _owner;
    authority = this;
  }

  // up to 256 roles
  uint8 public constant REGISTRY_ROLE = 0;
  uint8 public constant SUPPLIER_ROLE = 1;
  uint8 public constant BORROWER_ROLE = 2;
  uint8 public constant LIQUIDATOR_ROLE = 3;
  uint8 public constant LEVERED_POSITION_ROLE = 4;

  function configureRegistryCapabilities() external requiresAuth {
    setRoleCapability(REGISTRY_ROLE, address(this), PoolRolesAuthority.configureRegistryCapabilities.selector, true);
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configurePoolSupplierCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configurePoolBorrowerCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureClosedPoolLiquidatorCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureOpenPoolLiquidatorCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureLeveredPositionCapabilities.selector,
      true
    );
    setRoleCapability(REGISTRY_ROLE, address(this), RolesAuthority.setUserRole.selector, true);
  }

  function openPoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolSupplierCapabilities(pool, true);
  }

  function closePoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolSupplierCapabilities(pool, false);
  }

  function _setPublicPoolSupplierCapabilities(IonicComptroller pool, bool setPublic) internal {
    setPublicCapability(address(pool), pool.enterMarkets.selector, setPublic);
    setPublicCapability(address(pool), pool.exitMarket.selector, setPublic);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      bytes4[] memory selectors = getSupplierMarketSelectors();
      for (uint256 j = 0; j < selectors.length; j++) {
        setPublicCapability(address(allMarkets[i]), selectors[j], setPublic);
      }
    }
  }

  function configurePoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _configurePoolSupplierCapabilities(pool, SUPPLIER_ROLE);
  }

  function getSupplierMarketSelectors() internal pure returns (bytes4[] memory selectors) {
    uint8 fnsCount = 6;
    selectors = new bytes4[](fnsCount);
    selectors[--fnsCount] = CTokenSecondExtensionInterface.mint.selector;
    selectors[--fnsCount] = CTokenSecondExtensionInterface.redeem.selector;
    selectors[--fnsCount] = CTokenSecondExtensionInterface.redeemUnderlying.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.transfer.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.transferFrom.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.approve.selector;

    require(fnsCount == 0, "use the correct array length");
    return selectors;
  }

  function _configurePoolSupplierCapabilities(IonicComptroller pool, uint8 role) internal {
    setRoleCapability(role, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(role, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      bytes4[] memory selectors = getSupplierMarketSelectors();
      for (uint256 j = 0; j < selectors.length; j++) {
        setRoleCapability(role, address(allMarkets[i]), selectors[j], true);
      }
    }
  }

  function openPoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolBorrowerCapabilities(pool, true);
  }

  function closePoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolBorrowerCapabilities(pool, false);
  }

  function _setPublicPoolBorrowerCapabilities(IonicComptroller pool, bool setPublic) internal {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].borrow.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].repayBorrow.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].repayBorrowBehalf.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].flash.selector, setPublic);
    }
  }

  function configurePoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    // borrowers have the SUPPLIER_ROLE capabilities by default
    _configurePoolSupplierCapabilities(pool, BORROWER_ROLE);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrowBehalf.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }

  function configureClosedPoolLiquidatorCapabilities(IonicComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, false);
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, true);
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
    }
  }

  function configureOpenPoolLiquidatorCapabilities(IonicComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, true);
      // TODO this leaves redeeming open for everyone
      setPublicCapability(address(allMarkets[i]), allMarkets[i].redeem.selector, true);
    }
  }

  function configureLeveredPositionCapabilities(IonicComptroller pool) external requiresAuth {
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].mint.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeemUnderlying.selector, true);

      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }
}

// contracts/oracles/BasePriceOracle.sol

/**
 * @title BasePriceOracle
 * @notice Returns prices of underlying tokens directly without the caller having to specify a cToken address.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
interface BasePriceOracle {
  /**
   * @notice Get the price of an underlying asset.
   * @param underlying The underlying asset to get the price of.
   * @return The underlying asset price in ETH as a mantissa (scaled by 1e18).
   * Zero means the price is unavailable.
   */
  function price(address underlying) external view returns (uint256);

  /**
   * @notice Get the underlying price of a cToken asset
   * @param cToken The cToken to get the underlying price of
   * @return The underlying asset price mantissa (scaled by 1e18).
   *  Zero means the price is unavailable.
   */
  function getUnderlyingPrice(ICErc20 cToken) external view returns (uint256);
}

// contracts/compound/Comptroller.sol

/**
 * @title Compound's Comptroller Contract
 * @author Compound
 * @dev This contract should not to be deployed alone; instead, deploy `Unitroller` (proxy contract) on top of this `Comptroller` (logic/implementation contract).
 */
contract Comptroller is ComptrollerBase, ComptrollerInterface, ComptrollerErrorReporter, Exponential, DiamondExtension {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @notice Emitted when an admin supports a market
  event MarketListed(ICErc20 cToken);

  /// @notice Emitted when an account enters a market
  event MarketEntered(ICErc20 cToken, address account);

  /// @notice Emitted when an account exits a market
  event MarketExited(ICErc20 cToken, address account);

  /// @notice Emitted when close factor is changed by admin
  event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);

  /// @notice Emitted when a collateral factor is changed by admin
  event NewCollateralFactor(ICErc20 cToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa);

  /// @notice Emitted when liquidation incentive is changed by admin
  event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);

  /// @notice Emitted when price oracle is changed
  event NewPriceOracle(BasePriceOracle oldPriceOracle, BasePriceOracle newPriceOracle);

  /// @notice Emitted when the whitelist enforcement is changed
  event WhitelistEnforcementChanged(bool enforce);

  /// @notice Emitted when a new RewardsDistributor contract is added to hooks
  event AddedRewardsDistributor(address rewardsDistributor);

  // closeFactorMantissa must be strictly greater than this value
  uint256 internal constant closeFactorMinMantissa = 0.05e18; // 0.05

  // closeFactorMantissa must not exceed this value
  uint256 internal constant closeFactorMaxMantissa = 0.9e18; // 0.9

  // No collateralFactorMantissa may exceed this value
  uint256 internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9

  // liquidationIncentiveMantissa must be no less than this value
  uint256 internal constant liquidationIncentiveMinMantissa = 1.0e18; // 1.0

  // liquidationIncentiveMantissa must be no greater than this value
  uint256 internal constant liquidationIncentiveMaxMantissa = 1.5e18; // 1.5

  modifier isAuthorized() {
    require(IFeeDistributor(ionicAdmin).canCall(address(this), msg.sender, address(this), msg.sig), "not authorized");
    _;
  }

  /*** Assets You Are In ***/

  /**
   * @notice Returns the assets an account has entered
   * @param account The address of the account to pull assets for
   * @return A dynamic list with the assets the account has entered
   */
  function getAssetsIn(address account) external view returns (ICErc20[] memory) {
    ICErc20[] memory assetsIn = accountAssets[account];

    return assetsIn;
  }

  /**
   * @notice Returns whether the given account is entered in the given asset
   * @param account The address of the account to check
   * @param cToken The cToken to check
   * @return True if the account is in the asset, otherwise false.
   */
  function checkMembership(address account, ICErc20 cToken) external view returns (bool) {
    return markets[address(cToken)].accountMembership[account];
  }

  /**
   * @notice Add assets to be included in account liquidity calculation
   * @param cTokens The list of addresses of the cToken markets to be enabled
   * @return Success indicator for whether each corresponding market was entered
   */
  function enterMarkets(address[] memory cTokens) public override isAuthorized returns (uint256[] memory) {
    uint256 len = cTokens.length;

    uint256[] memory results = new uint256[](len);
    for (uint256 i = 0; i < len; i++) {
      ICErc20 cToken = ICErc20(cTokens[i]);

      results[i] = uint256(addToMarketInternal(cToken, msg.sender));
    }

    return results;
  }

  /**
   * @notice Add the market to the borrower's "assets in" for liquidity calculations
   * @param cToken The market to enter
   * @param borrower The address of the account to modify
   * @return Success indicator for whether the market was entered
   */
  function addToMarketInternal(ICErc20 cToken, address borrower) internal returns (Error) {
    Market storage marketToJoin = markets[address(cToken)];

    if (!marketToJoin.isListed) {
      // market is not listed, cannot join
      return Error.MARKET_NOT_LISTED;
    }

    if (marketToJoin.accountMembership[borrower] == true) {
      // already joined
      return Error.NO_ERROR;
    }

    // survived the gauntlet, add to list
    // NOTE: we store these somewhat redundantly as a significant optimization
    //  this avoids having to iterate through the list for the most common use cases
    //  that is, only when we need to perform liquidity checks
    //  and not whenever we want to check if an account is in a particular market
    marketToJoin.accountMembership[borrower] = true;
    accountAssets[borrower].push(cToken);

    // Add to allBorrowers
    if (!borrowers[borrower]) {
      allBorrowers.push(borrower);
      borrowers[borrower] = true;
      borrowerIndexes[borrower] = allBorrowers.length - 1;
    }

    emit MarketEntered(cToken, borrower);

    return Error.NO_ERROR;
  }

  /**
   * @notice Removes asset from sender's account liquidity calculation
   * @dev Sender must not have an outstanding borrow balance in the asset,
   *  or be providing necessary collateral for an outstanding borrow.
   * @param cTokenAddress The address of the asset to be removed
   * @return Whether or not the account successfully exited the market
   */
  function exitMarket(address cTokenAddress) external override isAuthorized returns (uint256) {
    // TODO
    require(markets[cTokenAddress].isListed, "!Comptroller:exitMarket");

    ICErc20 cToken = ICErc20(cTokenAddress);
    /* Get sender tokensHeld and amountOwed underlying from the cToken */
    (uint256 oErr, uint256 tokensHeld, uint256 amountOwed, ) = cToken.getAccountSnapshot(msg.sender);
    require(oErr == 0, "!exitMarket"); // semi-opaque error code

    /* Fail if the sender has a borrow balance */
    if (amountOwed != 0) {
      return fail(Error.NONZERO_BORROW_BALANCE, FailureInfo.EXIT_MARKET_BALANCE_OWED);
    }

    /* Fail if the sender is not permitted to redeem all of their tokens */
    uint256 allowed = redeemAllowedInternal(cTokenAddress, msg.sender, tokensHeld);
    if (allowed != 0) {
      return failOpaque(Error.REJECTION, FailureInfo.EXIT_MARKET_REJECTION, allowed);
    }

    Market storage marketToExit = markets[cTokenAddress];

    /* Return true if the sender is not already ‘in’ the market */
    if (!marketToExit.accountMembership[msg.sender]) {
      return uint256(Error.NO_ERROR);
    }

    /* Set cToken account membership to false */
    delete marketToExit.accountMembership[msg.sender];

    /* Delete cToken from the account’s list of assets */
    // load into memory for faster iteration
    ICErc20[] memory userAssetList = accountAssets[msg.sender];
    uint256 len = userAssetList.length;
    uint256 assetIndex = len;
    for (uint256 i = 0; i < len; i++) {
      if (userAssetList[i] == ICErc20(cTokenAddress)) {
        assetIndex = i;
        break;
      }
    }

    // We *must* have found the asset in the list or our redundant data structure is broken
    assert(assetIndex < len);

    // copy last item in list to location of item to be removed, reduce length by 1
    ICErc20[] storage storedList = accountAssets[msg.sender];
    storedList[assetIndex] = storedList[storedList.length - 1];
    storedList.pop();

    // If the user has exited all markets, remove them from the `allBorrowers` array
    if (storedList.length == 0) {
      allBorrowers[borrowerIndexes[msg.sender]] = allBorrowers[allBorrowers.length - 1]; // Copy last item in list to location of item to be removed
      allBorrowers.pop(); // Reduce length by 1
      borrowerIndexes[allBorrowers[borrowerIndexes[msg.sender]]] = borrowerIndexes[msg.sender]; // Set borrower index of moved item to correct index
      borrowerIndexes[msg.sender] = 0; // Reset sender borrower index to 0 for a gas refund
      borrowers[msg.sender] = false; // Tell the contract that the sender is no longer a borrower (so it knows to add the borrower back if they enter a market in the future)
    }

    emit MarketExited(ICErc20(cTokenAddress), msg.sender);

    return uint256(Error.NO_ERROR);
  }

  /*** Policy Hooks ***/

  /**
   * @notice Checks if the account should be allowed to mint tokens in the given market
   * @param cTokenAddress The market to verify the mint against
   * @param minter The account which would get the minted tokens
   * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
   * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
   */
  function mintAllowed(address cTokenAddress, address minter, uint256 mintAmount) external override returns (uint256) {
    // Pausing is a very serious situation - we revert to sound the alarms
    require(!mintGuardianPaused[cTokenAddress], "!mint:paused");

    // Make sure market is listed
    if (!markets[cTokenAddress].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    // Make sure minter is whitelisted
    if (enforceWhitelist && !whitelist[minter]) {
      return uint256(Error.SUPPLIER_NOT_WHITELISTED);
    }

    // Check supply cap
    uint256 supplyCap = supplyCaps[cTokenAddress];
    // Supply cap of 0 corresponds to unlimited supplying
    if (supplyCap != 0 && !supplyCapWhitelist[cTokenAddress].contains(minter)) {
      uint256 totalUnderlyingSupply = ICErc20(cTokenAddress).getTotalUnderlyingSupplied();
      uint256 whitelistedSuppliersSupply = asComptrollerExtension().getWhitelistedSuppliersSupply(cTokenAddress);
      uint256 nonWhitelistedTotalSupply;
      if (whitelistedSuppliersSupply >= totalUnderlyingSupply) nonWhitelistedTotalSupply = 0;
      else nonWhitelistedTotalSupply = totalUnderlyingSupply - whitelistedSuppliersSupply;

      require(nonWhitelistedTotalSupply + mintAmount < supplyCap, "!supply cap");
    }

    // Keep the flywheel moving
    flywheelPreSupplierAction(cTokenAddress, minter);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the account should be allowed to redeem tokens in the given market
   * @param cToken The market to verify the redeem against
   * @param redeemer The account which would redeem the tokens
   * @param redeemTokens The number of cTokens to exchange for the underlying asset in the market
   * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
   */
  function redeemAllowed(address cToken, address redeemer, uint256 redeemTokens) external override returns (uint256) {
    uint256 allowed = redeemAllowedInternal(cToken, redeemer, redeemTokens);
    if (allowed != uint256(Error.NO_ERROR)) {
      return allowed;
    }

    // Keep the flywheel moving
    flywheelPreSupplierAction(cToken, redeemer);

    return uint256(Error.NO_ERROR);
  }

  function redeemAllowedInternal(
    address cToken,
    address redeemer,
    uint256 redeemTokens
  ) internal view returns (uint256) {
    if (!markets[cToken].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
    if (!markets[cToken].accountMembership[redeemer]) {
      return uint256(Error.NO_ERROR);
    }

    /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
    (Error err, , , uint256 shortfall) = getHypotheticalAccountLiquidityInternal(
      redeemer,
      ICErc20(cToken),
      redeemTokens,
      0,
      0
    );
    if (err != Error.NO_ERROR) {
      return uint256(err);
    }
    if (shortfall > 0) {
      return uint256(Error.INSUFFICIENT_LIQUIDITY);
    }

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Validates mint and reverts on rejection. May emit logs.
   * @param cToken Asset being minted
   * @param minter The address minting the tokens
   * @param actualMintAmount The amount of the underlying asset being minted
   * @param mintTokens The number of tokens being minted
   */
  function mintVerify(address cToken, address minter, uint256 actualMintAmount, uint256 mintTokens) external {
    // Add minter to suppliers mapping
    suppliers[minter] = true;
  }

  /**
   * @notice Validates redeem and reverts on rejection. May emit logs.
   * @param cToken Asset being redeemed
   * @param redeemer The address redeeming the tokens
   * @param redeemAmount The amount of the underlying asset being redeemed
   * @param redeemTokens The number of tokens being redeemed
   */
  function redeemVerify(
    address cToken,
    address redeemer,
    uint256 redeemAmount,
    uint256 redeemTokens
  ) external override {
    require(markets[msg.sender].isListed, "!market");

    // Require tokens is zero or amount is also zero
    if (redeemTokens == 0 && redeemAmount > 0) {
      revert("!zero");
    }
  }

  function getMaxRedeemOrBorrow(
    address account,
    ICErc20 cTokenModify,
    bool isBorrow
  ) external view override returns (uint256) {
    address cToken = address(cTokenModify);
    // Accrue interest
    uint256 balanceOfUnderlying = cTokenModify.balanceOfUnderlying(account);

    // Get account liquidity
    (Error err, , uint256 liquidity, uint256 shortfall) = getHypotheticalAccountLiquidityInternal(
      account,
      isBorrow ? cTokenModify : ICErc20(address(0)),
      0,
      0,
      0
    );
    require(err == Error.NO_ERROR, "!liquidity");
    if (shortfall > 0) return 0; // Shortfall, so no more borrow/redeem

    // Get max borrow/redeem
    uint256 maxBorrowOrRedeemAmount;

    if (!isBorrow && !markets[cToken].accountMembership[account]) {
      // Max redeem = balance of underlying if not used as collateral
      maxBorrowOrRedeemAmount = balanceOfUnderlying;
    } else {
      // Avoid "stack too deep" error by separating this logic
      maxBorrowOrRedeemAmount = _getMaxRedeemOrBorrow(liquidity, cTokenModify, isBorrow);

      // Redeem only: max out at underlying balance
      if (!isBorrow && balanceOfUnderlying < maxBorrowOrRedeemAmount) maxBorrowOrRedeemAmount = balanceOfUnderlying;
    }

    // Get max borrow or redeem considering cToken liquidity
    uint256 cTokenLiquidity = cTokenModify.getCash();

    // Return the minimum of the two maximums
    return maxBorrowOrRedeemAmount <= cTokenLiquidity ? maxBorrowOrRedeemAmount : cTokenLiquidity;
  }

  /**
   * @dev Portion of the logic in `getMaxRedeemOrBorrow` above separated to avoid "stack too deep" errors.
   */
  function _getMaxRedeemOrBorrow(
    uint256 liquidity,
    ICErc20 cTokenModify,
    bool isBorrow
  ) internal view returns (uint256) {
    if (liquidity == 0) return 0; // No available account liquidity, so no more borrow/redeem

    // Get the normalized price of the asset
    uint256 conversionFactor = oracle.getUnderlyingPrice(cTokenModify);
    require(conversionFactor > 0, "!oracle");

    // Pre-compute a conversion factor from tokens -> ether (normalized price value)
    if (!isBorrow) {
      uint256 collateralFactorMantissa = markets[address(cTokenModify)].collateralFactorMantissa;
      conversionFactor = (collateralFactorMantissa * conversionFactor) / 1e18;
    }

    // Get max borrow or redeem considering excess account liquidity
    return (liquidity * 1e18) / conversionFactor;
  }

  /**
   * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
   * @param cToken The market to verify the borrow against
   * @param borrower The account which would borrow the asset
   * @param borrowAmount The amount of underlying the account would borrow
   * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
   */
  function borrowAllowed(address cToken, address borrower, uint256 borrowAmount) external override returns (uint256) {
    // Pausing is a very serious situation - we revert to sound the alarms
    require(!borrowGuardianPaused[cToken], "!borrow:paused");

    // Make sure market is listed
    if (!markets[cToken].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    if (!markets[cToken].accountMembership[borrower]) {
      // only cTokens may call borrowAllowed if borrower not in market
      require(msg.sender == cToken, "!ctoken");

      // attempt to add borrower to the market
      Error err = addToMarketInternal(ICErc20(msg.sender), borrower);
      if (err != Error.NO_ERROR) {
        return uint256(err);
      }

      // it should be impossible to break the important invariant
      assert(markets[cToken].accountMembership[borrower]);
    }

    // Make sure oracle price is available
    if (oracle.getUnderlyingPrice(ICErc20(cToken)) == 0) {
      return uint256(Error.PRICE_ERROR);
    }

    // Make sure borrower is whitelisted
    if (enforceWhitelist && !whitelist[borrower]) {
      return uint256(Error.SUPPLIER_NOT_WHITELISTED);
    }

    // Check borrow cap
    uint256 borrowCap = borrowCaps[cToken];
    // Borrow cap of 0 corresponds to unlimited borrowing
    if (borrowCap != 0 && !borrowCapWhitelist[cToken].contains(borrower)) {
      uint256 totalBorrows = ICErc20(cToken).totalBorrowsCurrent();
      uint256 whitelistedBorrowersBorrows = asComptrollerExtension().getWhitelistedBorrowersBorrows(cToken);
      uint256 nonWhitelistedTotalBorrows;
      if (whitelistedBorrowersBorrows >= totalBorrows) nonWhitelistedTotalBorrows = 0;
      else nonWhitelistedTotalBorrows = totalBorrows - whitelistedBorrowersBorrows;

      require(nonWhitelistedTotalBorrows + borrowAmount < borrowCap, "!borrow:cap");
    }

    // Keep the flywheel moving
    flywheelPreBorrowerAction(cToken, borrower);

    // Perform a hypothetical liquidity check to guard against shortfall
    (uint256 err, , , uint256 shortfall) = this.getHypotheticalAccountLiquidity(borrower, cToken, 0, borrowAmount, 0);
    if (err != uint256(Error.NO_ERROR)) {
      return err;
    }
    if (shortfall > 0) {
      return uint256(Error.INSUFFICIENT_LIQUIDITY);
    }

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
   * @param cToken Asset whose underlying is being borrowed
   * @param accountBorrowsNew The user's new borrow balance of the underlying asset
   */
  function borrowWithinLimits(address cToken, uint256 accountBorrowsNew) external view override returns (uint256) {
    // Check if min borrow exists
    uint256 minBorrowEth = IFeeDistributor(ionicAdmin).minBorrowEth();

    if (minBorrowEth > 0) {
      // Get new underlying borrow balance of account for this cToken
      uint256 oraclePriceMantissa = oracle.getUnderlyingPrice(ICErc20(cToken));
      if (oraclePriceMantissa == 0) return uint256(Error.PRICE_ERROR);
      (MathError mathErr, uint256 borrowBalanceEth) = mulScalarTruncate(
        Exp({ mantissa: oraclePriceMantissa }),
        accountBorrowsNew
      );
      if (mathErr != MathError.NO_ERROR) return uint256(Error.MATH_ERROR);

      // Check against min borrow
      if (borrowBalanceEth < minBorrowEth) return uint256(Error.BORROW_BELOW_MIN);
    }

    // Return no error
    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the account should be allowed to repay a borrow in the given market
   * @param cToken The market to verify the repay against
   * @param payer The account which would repay the asset
   * @param borrower The account which would borrowed the asset
   * @param repayAmount The amount of the underlying asset the account would repay
   * @return 0 if the repay is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
   */
  function repayBorrowAllowed(
    address cToken,
    address payer,
    address borrower,
    uint256 repayAmount
  ) external override returns (uint256) {
    // Make sure market is listed
    if (!markets[cToken].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    // Keep the flywheel moving
    flywheelPreBorrowerAction(cToken, borrower);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the liquidation should be allowed to occur
   * @param cTokenBorrowed Asset which was borrowed by the borrower
   * @param cTokenCollateral Asset which was used as collateral and will be seized
   * @param liquidator The address repaying the borrow and seizing the collateral
   * @param borrower The address of the borrower
   * @param repayAmount The amount of underlying being repaid
   */
  function liquidateBorrowAllowed(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
  ) external override returns (uint256) {
    // Make sure markets are listed
    if (!markets[cTokenBorrowed].isListed || !markets[cTokenCollateral].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    // Get borrowers' underlying borrow balance
    uint256 borrowBalance = ICErc20(cTokenBorrowed).borrowBalanceCurrent(borrower);

    /* allow accounts to be liquidated if the market is deprecated */
    if (isDeprecated(ICErc20(cTokenBorrowed))) {
      require(borrowBalance >= repayAmount, "!borrow>repay");
    } else {
      /* The borrower must have shortfall in order to be liquidateable */
      (Error err, , , uint256 shortfall) = getHypotheticalAccountLiquidityInternal(
        borrower,
        ICErc20(address(0)),
        0,
        0,
        0
      );
      if (err != Error.NO_ERROR) {
        return uint256(err);
      }

      if (shortfall == 0) {
        return uint256(Error.INSUFFICIENT_SHORTFALL);
      }

      /* The liquidator may not repay more than what is allowed by the closeFactor */
      uint256 maxClose = mul_ScalarTruncate(Exp({ mantissa: closeFactorMantissa }), borrowBalance);
      if (repayAmount > maxClose) {
        return uint256(Error.TOO_MUCH_REPAY);
      }
    }

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the seizing of assets should be allowed to occur
   * @param cTokenCollateral Asset which was used as collateral and will be seized
   * @param cTokenBorrowed Asset which was borrowed by the borrower
   * @param liquidator The address repaying the borrow and seizing the collateral
   * @param borrower The address of the borrower
   * @param seizeTokens The number of collateral tokens to seize
   */
  function seizeAllowed(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external override returns (uint256) {
    // Pausing is a very serious situation - we revert to sound the alarms
    require(!seizeGuardianPaused, "!seize:paused");

    // Make sure markets are listed
    if (!markets[cTokenCollateral].isListed || !markets[cTokenBorrowed].isListed) {
      return uint256(Error.MARKET_NOT_LISTED);
    }

    // Make sure cToken Comptrollers are identical
    if (ICErc20(cTokenCollateral).comptroller() != ICErc20(cTokenBorrowed).comptroller()) {
      return uint256(Error.COMPTROLLER_MISMATCH);
    }

    // Keep the flywheel moving
    flywheelPreTransferAction(cTokenCollateral, borrower, liquidator);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Checks if the account should be allowed to transfer tokens in the given market
   * @param cToken The market to verify the transfer against
   * @param src The account which sources the tokens
   * @param dst The account which receives the tokens
   * @param transferTokens The number of cTokens to transfer
   * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
   */
  function transferAllowed(
    address cToken,
    address src,
    address dst,
    uint256 transferTokens
  ) external override returns (uint256) {
    // Pausing is a very serious situation - we revert to sound the alarms
    require(!transferGuardianPaused, "!transfer:paused");

    // Currently the only consideration is whether or not
    //  the src is allowed to redeem this many tokens
    uint256 allowed = redeemAllowedInternal(cToken, src, transferTokens);
    if (allowed != uint256(Error.NO_ERROR)) {
      return allowed;
    }

    // Keep the flywheel moving
    flywheelPreTransferAction(cToken, src, dst);

    return uint256(Error.NO_ERROR);
  }

  /*** Flywheel Hooks ***/

  /**
   * @notice Keeps the flywheel moving pre-mint and pre-redeem
   * @param cToken The relevant market
   * @param supplier The minter/redeemer
   */
  function flywheelPreSupplierAction(address cToken, address supplier) internal {
    for (uint256 i = 0; i < rewardsDistributors.length; i++)
      IIonicFlywheel(rewardsDistributors[i]).flywheelPreSupplierAction(cToken, supplier);
  }

  /**
   * @notice Keeps the flywheel moving pre-borrow and pre-repay
   * @param cToken The relevant market
   * @param borrower The borrower
   */
  function flywheelPreBorrowerAction(address cToken, address borrower) internal {
    for (uint256 i = 0; i < rewardsDistributors.length; i++)
      IIonicFlywheel(rewardsDistributors[i]).flywheelPreBorrowerAction(cToken, borrower);
  }

  /**
   * @notice Keeps the flywheel moving pre-transfer and pre-seize
   * @param cToken The relevant market
   * @param src The account which sources the tokens
   * @param dst The account which receives the tokens
   */
  function flywheelPreTransferAction(address cToken, address src, address dst) internal {
    for (uint256 i = 0; i < rewardsDistributors.length; i++)
      IIonicFlywheel(rewardsDistributors[i]).flywheelPreTransferAction(cToken, src, dst);
  }

  /*** Liquidity/Liquidation Calculations ***/

  /**
   * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
   *  Note that `cTokenBalance` is the number of cTokens the account owns in the market,
   *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
   */
  struct AccountLiquidityLocalVars {
    ICErc20 asset;
    uint256 sumCollateral;
    uint256 sumBorrowPlusEffects;
    uint256 cTokenBalance;
    uint256 borrowBalance;
    uint256 exchangeRateMantissa;
    uint256 oraclePriceMantissa;
    Exp collateralFactor;
    Exp exchangeRate;
    Exp oraclePrice;
    Exp tokensToDenom;
    uint256 borrowCapForCollateral;
    uint256 borrowedAssetPrice;
    uint256 assetAsCollateralValueCap;
  }

  function getAccountLiquidity(address account) public view override returns (uint256, uint256, uint256, uint256) {
    (
      Error err,
      uint256 collateralValue,
      uint256 liquidity,
      uint256 shortfall
    ) = getHypotheticalAccountLiquidityInternal(account, ICErc20(address(0)), 0, 0, 0);
    return (uint256(err), collateralValue, liquidity, shortfall);
  }

  /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
  function getHypotheticalAccountLiquidity(
    address account,
    address cTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount,
    uint256 repayAmount
  ) public view returns (uint256, uint256, uint256, uint256) {
    (
      Error err,
      uint256 collateralValue,
      uint256 liquidity,
      uint256 shortfall
    ) = getHypotheticalAccountLiquidityInternal(
        account,
        ICErc20(cTokenModify),
        redeemTokens,
        borrowAmount,
        repayAmount
      );
    return (uint256(err), collateralValue, liquidity, shortfall);
  }

  /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code,
                hypothetical account collateral value,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
  function getHypotheticalAccountLiquidityInternal(
    address account,
    ICErc20 cTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount,
    uint256 repayAmount
  ) internal view returns (Error, uint256, uint256, uint256) {
    AccountLiquidityLocalVars memory vars; // Holds all our calculation results

    if (address(cTokenModify) != address(0)) {
      vars.borrowedAssetPrice = oracle.getUnderlyingPrice(cTokenModify);
    }

    // For each asset the account is in
    for (uint256 i = 0; i < accountAssets[account].length; i++) {
      vars.asset = accountAssets[account][i];

      {
        // Read the balances and exchange rate from the cToken
        uint256 oErr;
        (oErr, vars.cTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = vars.asset.getAccountSnapshot(
          account
        );
        if (oErr != 0) {
          // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
          return (Error.SNAPSHOT_ERROR, 0, 0, 0);
        }
      }
      {
        vars.collateralFactor = Exp({ mantissa: markets[address(vars.asset)].collateralFactorMantissa });
        vars.exchangeRate = Exp({ mantissa: vars.exchangeRateMantissa });

        // Get the normalized price of the asset
        vars.oraclePriceMantissa = oracle.getUnderlyingPrice(vars.asset);
        if (vars.oraclePriceMantissa == 0) {
          return (Error.PRICE_ERROR, 0, 0, 0);
        }
        vars.oraclePrice = Exp({ mantissa: vars.oraclePriceMantissa });

        // Pre-compute a conversion factor from tokens -> ether (normalized price value)
        vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);
      }
      {
        // Exclude the asset-to-be-borrowed from the liquidity, except for when redeeming
        vars.assetAsCollateralValueCap = asComptrollerExtension().getAssetAsCollateralValueCap(
          vars.asset,
          cTokenModify,
          redeemTokens > 0,
          account
        );

        // accumulate the collateral value to sumCollateral
        uint256 assetCollateralValue = mul_ScalarTruncate(vars.tokensToDenom, vars.cTokenBalance);
        if (assetCollateralValue > vars.assetAsCollateralValueCap)
          assetCollateralValue = vars.assetAsCollateralValueCap;
        vars.sumCollateral += assetCollateralValue;
      }

      // sumBorrowPlusEffects += oraclePrice * borrowBalance
      vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(
        vars.oraclePrice,
        vars.borrowBalance,
        vars.sumBorrowPlusEffects
      );

      // Calculate effects of interacting with cTokenModify
      if (vars.asset == cTokenModify) {
        // redeem effect
        // sumBorrowPlusEffects += tokensToDenom * redeemTokens
        vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(
          vars.tokensToDenom,
          redeemTokens,
          vars.sumBorrowPlusEffects
        );

        // borrow effect
        // sumBorrowPlusEffects += oraclePrice * borrowAmount
        vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(
          vars.oraclePrice,
          borrowAmount,
          vars.sumBorrowPlusEffects
        );

        uint256 repayEffect = mul_ScalarTruncate(vars.oraclePrice, repayAmount);
        if (repayEffect >= vars.sumBorrowPlusEffects) {
          vars.sumBorrowPlusEffects = 0;
        } else {
          vars.sumBorrowPlusEffects -= repayEffect;
        }
      }
    }

    // These are safe, as the underflow condition is checked first
    if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
      return (Error.NO_ERROR, vars.sumCollateral, vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
    } else {
      return (Error.NO_ERROR, vars.sumCollateral, 0, vars.sumBorrowPlusEffects - vars.sumCollateral);
    }
  }

  /**
   * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
   * @dev Used in liquidation (called in cToken.liquidateBorrowFresh)
   * @param cTokenBorrowed The address of the borrowed cToken
   * @param cTokenCollateral The address of the collateral cToken
   * @param actualRepayAmount The amount of cTokenBorrowed underlying to convert into cTokenCollateral tokens
   * @return (errorCode, number of cTokenCollateral tokens to be seized in a liquidation)
   */
  function liquidateCalculateSeizeTokens(
    address cTokenBorrowed,
    address cTokenCollateral,
    uint256 actualRepayAmount
  ) external view override returns (uint256, uint256) {
    /* Read oracle prices for borrowed and collateral markets */
    uint256 priceBorrowedMantissa = oracle.getUnderlyingPrice(ICErc20(cTokenBorrowed));
    uint256 priceCollateralMantissa = oracle.getUnderlyingPrice(ICErc20(cTokenCollateral));
    if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
      return (uint256(Error.PRICE_ERROR), 0);
    }

    /*
     * Get the exchange rate and calculate the number of collateral tokens to seize:
     *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
     *  seizeTokens = seizeAmount / exchangeRate
     *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
     */
    ICErc20 collateralCToken = ICErc20(cTokenCollateral);
    uint256 exchangeRateMantissa = collateralCToken.exchangeRateCurrent();
    uint256 seizeTokens;
    Exp memory numerator;
    Exp memory denominator;
    Exp memory ratio;

    uint256 protocolSeizeShareMantissa = collateralCToken.protocolSeizeShareMantissa();
    uint256 feeSeizeShareMantissa = collateralCToken.feeSeizeShareMantissa();

    /*
     * The liquidation penalty includes
     * - the liquidator incentive
     * - the protocol fees (Ionic admin fees)
     * - the market fee
     */
    Exp memory totalPenaltyMantissa = add_(
      add_(Exp({ mantissa: liquidationIncentiveMantissa }), Exp({ mantissa: protocolSeizeShareMantissa })),
      Exp({ mantissa: feeSeizeShareMantissa })
    );

    numerator = mul_(totalPenaltyMantissa, Exp({ mantissa: priceBorrowedMantissa }));
    denominator = mul_(Exp({ mantissa: priceCollateralMantissa }), Exp({ mantissa: exchangeRateMantissa }));
    ratio = div_(numerator, denominator);

    seizeTokens = mul_ScalarTruncate(ratio, actualRepayAmount);
    return (uint256(Error.NO_ERROR), seizeTokens);
  }

  /*** Admin Functions ***/

  /**
   * @notice Add a RewardsDistributor contracts.
   * @dev Admin function to add a RewardsDistributor contract
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _addRewardsDistributor(address distributor) external returns (uint256) {
    require(hasAdminRights(), "!admin");

    // Check marker method
    require(IIonicFlywheel(distributor).isRewardsDistributor(), "!isRewardsDistributor");

    // Check for existing RewardsDistributor
    for (uint256 i = 0; i < rewardsDistributors.length; i++) require(distributor != rewardsDistributors[i], "!added");

    // Add RewardsDistributor to array
    rewardsDistributors.push(distributor);
    emit AddedRewardsDistributor(distributor);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets the whitelist enforcement for the comptroller
   * @dev Admin function to set a new whitelist enforcement boolean
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setWhitelistEnforcement(bool enforce) external returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_WHITELIST_ENFORCEMENT_OWNER_CHECK);
    }

    // Check if `enforceWhitelist` already equals `enforce`
    if (enforceWhitelist == enforce) {
      return uint256(Error.NO_ERROR);
    }

    // Set comptroller's `enforceWhitelist` to `enforce`
    enforceWhitelist = enforce;

    // Emit WhitelistEnforcementChanged(bool enforce);
    emit WhitelistEnforcementChanged(enforce);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets the whitelist `statuses` for `suppliers`
   * @dev Admin function to set the whitelist `statuses` for `suppliers`
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setWhitelistStatuses(address[] calldata suppliers, bool[] calldata statuses) external returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_WHITELIST_STATUS_OWNER_CHECK);
    }

    // Set whitelist statuses for suppliers
    for (uint256 i = 0; i < suppliers.length; i++) {
      address supplier = suppliers[i];

      if (statuses[i]) {
        // If not already whitelisted, add to whitelist
        if (!whitelist[supplier]) {
          whitelist[supplier] = true;
          whitelistArray.push(supplier);
          whitelistIndexes[supplier] = whitelistArray.length - 1;
        }
      } else {
        // If whitelisted, remove from whitelist
        if (whitelist[supplier]) {
          whitelistArray[whitelistIndexes[supplier]] = whitelistArray[whitelistArray.length - 1]; // Copy last item in list to location of item to be removed
          whitelistArray.pop(); // Reduce length by 1
          whitelistIndexes[whitelistArray[whitelistIndexes[supplier]]] = whitelistIndexes[supplier]; // Set whitelist index of moved item to correct index
          whitelistIndexes[supplier] = 0; // Reset supplier whitelist index to 0 for a gas refund
          whitelist[supplier] = false; // Tell the contract that the supplier is no longer whitelisted
        }
      }
    }

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets a new price oracle for the comptroller
   * @dev Admin function to set a new price oracle
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setPriceOracle(BasePriceOracle newOracle) public returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_PRICE_ORACLE_OWNER_CHECK);
    }

    // Track the old oracle for the comptroller
    BasePriceOracle oldOracle = oracle;

    // Set comptroller's oracle to newOracle
    oracle = newOracle;

    // Emit NewPriceOracle(oldOracle, newOracle)
    emit NewPriceOracle(oldOracle, newOracle);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets the closeFactor used when liquidating borrows
   * @dev Admin function to set closeFactor
   * @param newCloseFactorMantissa New close factor, scaled by 1e18
   * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
   */
  function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_CLOSE_FACTOR_OWNER_CHECK);
    }

    // Check limits
    Exp memory newCloseFactorExp = Exp({ mantissa: newCloseFactorMantissa });
    Exp memory lowLimit = Exp({ mantissa: closeFactorMinMantissa });
    if (lessThanOrEqualExp(newCloseFactorExp, lowLimit)) {
      return fail(Error.INVALID_CLOSE_FACTOR, FailureInfo.SET_CLOSE_FACTOR_VALIDATION);
    }

    Exp memory highLimit = Exp({ mantissa: closeFactorMaxMantissa });
    if (lessThanExp(highLimit, newCloseFactorExp)) {
      return fail(Error.INVALID_CLOSE_FACTOR, FailureInfo.SET_CLOSE_FACTOR_VALIDATION);
    }

    // Set pool close factor to new close factor, remember old value
    uint256 oldCloseFactorMantissa = closeFactorMantissa;
    closeFactorMantissa = newCloseFactorMantissa;

    // Emit event
    emit NewCloseFactor(oldCloseFactorMantissa, closeFactorMantissa);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets the collateralFactor for a market
   * @dev Admin function to set per-market collateralFactor
   * @param cToken The market to set the factor on
   * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
   * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
   */
  function _setCollateralFactor(ICErc20 cToken, uint256 newCollateralFactorMantissa) public returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_COLLATERAL_FACTOR_OWNER_CHECK);
    }

    // Verify market is listed
    Market storage market = markets[address(cToken)];
    if (!market.isListed) {
      return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS);
    }

    Exp memory newCollateralFactorExp = Exp({ mantissa: newCollateralFactorMantissa });

    // Check collateral factor <= 0.9
    Exp memory highLimit = Exp({ mantissa: collateralFactorMaxMantissa });
    if (lessThanExp(highLimit, newCollateralFactorExp)) {
      return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION);
    }

    // If collateral factor != 0, fail if price == 0
    if (newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(cToken) == 0) {
      return fail(Error.PRICE_ERROR, FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE);
    }

    // Set market's collateral factor to new collateral factor, remember old value
    uint256 oldCollateralFactorMantissa = market.collateralFactorMantissa;
    market.collateralFactorMantissa = newCollateralFactorMantissa;

    // Emit event with asset, old collateral factor, and new collateral factor
    emit NewCollateralFactor(cToken, oldCollateralFactorMantissa, newCollateralFactorMantissa);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Sets liquidationIncentive
   * @dev Admin function to set liquidationIncentive
   * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
   * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
   */
  function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK);
    }

    // Check de-scaled min <= newLiquidationIncentive <= max
    Exp memory newLiquidationIncentive = Exp({ mantissa: newLiquidationIncentiveMantissa });
    Exp memory minLiquidationIncentive = Exp({ mantissa: liquidationIncentiveMinMantissa });
    if (lessThanExp(newLiquidationIncentive, minLiquidationIncentive)) {
      return fail(Error.INVALID_LIQUIDATION_INCENTIVE, FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION);
    }

    Exp memory maxLiquidationIncentive = Exp({ mantissa: liquidationIncentiveMaxMantissa });
    if (lessThanExp(maxLiquidationIncentive, newLiquidationIncentive)) {
      return fail(Error.INVALID_LIQUIDATION_INCENTIVE, FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION);
    }

    // Save current value for use in log
    uint256 oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;

    // Set liquidation incentive to new incentive
    liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

    // Emit event with old incentive, new incentive
    emit NewLiquidationIncentive(oldLiquidationIncentiveMantissa, newLiquidationIncentiveMantissa);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Add the market to the markets mapping and set it as listed
   * @dev Admin function to set isListed and add support for the market
   * @param cToken The address of the market (token) to list
   * @return uint 0=success, otherwise a failure. (See enum Error for details)
   */
  function _supportMarket(ICErc20 cToken) internal returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_MARKET_OWNER_CHECK);
    }

    // Is market already listed?
    if (markets[address(cToken)].isListed) {
      return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
    }

    // Check cToken.comptroller == this
    require(address(cToken.comptroller()) == address(this), "!comptroller");

    // Make sure market is not already listed
    address underlying = ICErc20(address(cToken)).underlying();

    if (address(cTokensByUnderlying[underlying]) != address(0)) {
      return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
    }

    // List market and emit event
    Market storage market = markets[address(cToken)];
    market.isListed = true;
    market.collateralFactorMantissa = 0;
    allMarkets.push(cToken);
    cTokensByUnderlying[underlying] = cToken;
    emit MarketListed(cToken);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Deploy cToken, add the market to the markets mapping, and set it as listed and set the collateral factor
   * @dev Admin function to deploy cToken, set isListed, and add support for the market and set the collateral factor
   * @return uint 0=success, otherwise a failure. (See enum Error for details)
   */
  function _deployMarket(
    uint8 delegateType,
    bytes calldata constructorData,
    bytes calldata becomeImplData,
    uint256 collateralFactorMantissa
  ) external returns (uint256) {
    // Check caller is admin
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_MARKET_OWNER_CHECK);
    }

    // Temporarily enable Ionic admin rights for asset deployment (storing the original value)
    bool oldIonicAdminHasRights = ionicAdminHasRights;
    ionicAdminHasRights = true;

    // Deploy via Ionic admin
    ICErc20 cToken = ICErc20(IFeeDistributor(ionicAdmin).deployCErc20(delegateType, constructorData, becomeImplData));
    // Reset Ionic admin rights to the original value
    ionicAdminHasRights = oldIonicAdminHasRights;
    // Support market here in the Comptroller
    uint256 err = _supportMarket(cToken);

    IFeeDistributor(ionicAdmin).authoritiesRegistry().reconfigureAuthority(address(this));

    // Set collateral factor
    return err == uint256(Error.NO_ERROR) ? _setCollateralFactor(cToken, collateralFactorMantissa) : err;
  }

  function _becomeImplementation() external {
    require(msg.sender == address(this), "!self call");

    if (!_notEnteredInitialized) {
      _notEntered = true;
      _notEnteredInitialized = true;
    }
  }

  /*** Helper Functions ***/

  /**
   * @notice Returns true if the given cToken market has been deprecated
   * @dev All borrows in a deprecated cToken market can be immediately liquidated
   * @param cToken The market to check if deprecated
   */
  function isDeprecated(ICErc20 cToken) public view returns (bool) {
    return
      markets[address(cToken)].collateralFactorMantissa == 0 &&
      borrowGuardianPaused[address(cToken)] == true &&
      add_(add_(cToken.reserveFactorMantissa(), cToken.adminFeeMantissa()), cToken.ionicFeeMantissa()) == 1e18;
  }

  function asComptrollerExtension() internal view returns (ComptrollerExtensionInterface) {
    return ComptrollerExtensionInterface(address(this));
  }

  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory functionSelectors) {
    uint8 fnsCount = 30;

    functionSelectors = new bytes4[](fnsCount);

    functionSelectors[--fnsCount] = this.isDeprecated.selector;
    functionSelectors[--fnsCount] = this._deployMarket.selector;
    functionSelectors[--fnsCount] = this.getAssetsIn.selector;
    functionSelectors[--fnsCount] = this.checkMembership.selector;
    functionSelectors[--fnsCount] = this._setPriceOracle.selector;
    functionSelectors[--fnsCount] = this._setCloseFactor.selector;
    functionSelectors[--fnsCount] = this._setCollateralFactor.selector;
    functionSelectors[--fnsCount] = this._setLiquidationIncentive.selector;
    functionSelectors[--fnsCount] = this._setWhitelistEnforcement.selector;
    functionSelectors[--fnsCount] = this._setWhitelistStatuses.selector;
    functionSelectors[--fnsCount] = this._addRewardsDistributor.selector;
    functionSelectors[--fnsCount] = this.getHypotheticalAccountLiquidity.selector;
    functionSelectors[--fnsCount] = this.getMaxRedeemOrBorrow.selector;
    functionSelectors[--fnsCount] = this.enterMarkets.selector;
    functionSelectors[--fnsCount] = this.exitMarket.selector;
    functionSelectors[--fnsCount] = this.mintAllowed.selector;
    functionSelectors[--fnsCount] = this.redeemAllowed.selector;
    functionSelectors[--fnsCount] = this.redeemVerify.selector;
    functionSelectors[--fnsCount] = this.borrowAllowed.selector;
    functionSelectors[--fnsCount] = this.borrowWithinLimits.selector;
    functionSelectors[--fnsCount] = this.repayBorrowAllowed.selector;
    functionSelectors[--fnsCount] = this.liquidateBorrowAllowed.selector;
    functionSelectors[--fnsCount] = this.seizeAllowed.selector;
    functionSelectors[--fnsCount] = this.transferAllowed.selector;
    functionSelectors[--fnsCount] = this.mintVerify.selector;
    functionSelectors[--fnsCount] = this.getAccountLiquidity.selector;
    functionSelectors[--fnsCount] = this.liquidateCalculateSeizeTokens.selector;
    functionSelectors[--fnsCount] = this._beforeNonReentrant.selector;
    functionSelectors[--fnsCount] = this._afterNonReentrant.selector;
    functionSelectors[--fnsCount] = this._becomeImplementation.selector;

    require(fnsCount == 0, "use the correct array length");
  }

  /*** Pool-Wide/Cross-Asset Reentrancy Prevention ***/

  /**
   * @dev Called by cTokens before a non-reentrant function for pool-wide reentrancy prevention.
   * Prevents pool-wide/cross-asset reentrancy exploits like AMP on Cream.
   */
  function _beforeNonReentrant() external override {
    require(markets[msg.sender].isListed, "!Comptroller:_beforeNonReentrant");
    require(_notEntered, "!reentered");
    _notEntered = false;
  }

  /**
   * @dev Called by cTokens after a non-reentrant function for pool-wide reentrancy prevention.
   * Prevents pool-wide/cross-asset reentrancy exploits like AMP on Cream.
   */
  function _afterNonReentrant() external override {
    require(markets[msg.sender].isListed, "!Comptroller:_afterNonReentrant");
    _notEntered = true; // get a gas-refund post-Istanbul
  }
}

// contracts/compound/Unitroller.sol

/**
 * @title Unitroller
 * @dev Storage for the comptroller is at this address, while execution is delegated via the Diamond Extensions
 * CTokens should reference this contract as their comptroller.
 */
contract Unitroller is ComptrollerV3Storage, ComptrollerErrorReporter, DiamondBase {
  /**
   * @notice Event emitted when the admin rights are changed
   */
  event AdminRightsToggled(bool hasRights);

  /**
   * @notice Emitted when pendingAdmin is changed
   */
  event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

  /**
   * @notice Emitted when pendingAdmin is accepted, which means admin is updated
   */
  event NewAdmin(address oldAdmin, address newAdmin);

  constructor(address payable _ionicAdmin) {
    admin = msg.sender;
    ionicAdmin = _ionicAdmin;
  }

  /*** Admin Functions ***/

  /**
   * @notice Toggles admin rights.
   * @param hasRights Boolean indicating if the admin is to have rights.
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _toggleAdminRights(bool hasRights) external returns (uint256) {
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.TOGGLE_ADMIN_RIGHTS_OWNER_CHECK);
    }

    // Check that rights have not already been set to the desired value
    if (adminHasRights == hasRights) return uint256(Error.NO_ERROR);

    adminHasRights = hasRights;
    emit AdminRightsToggled(hasRights);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
   * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
   * @param newPendingAdmin New pending admin.
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setPendingAdmin(address newPendingAdmin) public returns (uint256) {
    if (!hasAdminRights()) {
      return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_ADMIN_OWNER_CHECK);
    }

    address oldPendingAdmin = pendingAdmin;
    pendingAdmin = newPendingAdmin;
    emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
   * @dev Admin function for pending admin to accept role and update admin
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _acceptAdmin() public returns (uint256) {
    // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
    if (msg.sender != pendingAdmin || msg.sender == address(0)) {
      return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
    }

    // Save current values for inclusion in log
    address oldAdmin = admin;
    address oldPendingAdmin = pendingAdmin;

    admin = pendingAdmin;
    pendingAdmin = address(0);

    emit NewAdmin(oldAdmin, admin);
    emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

    return uint256(Error.NO_ERROR);
  }

  function comptrollerImplementation() public view returns (address) {
    return LibDiamond.getExtensionForFunction(bytes4(keccak256(bytes("_deployMarket(uint8,bytes,bytes,uint256)"))));
  }

  /**
   * @dev upgrades the implementation if necessary
   */
  function _upgrade() external {
    require(msg.sender == address(this) || hasAdminRights(), "!self || !admin");

    address currentImplementation = comptrollerImplementation();
    address latestComptrollerImplementation = IFeeDistributor(ionicAdmin).latestComptrollerImplementation(
      currentImplementation
    );

    _updateExtensions(latestComptrollerImplementation);

    if (currentImplementation != latestComptrollerImplementation) {
      // reinitialize
      _functionCall(address(this), abi.encodeWithSignature("_becomeImplementation()"), "!become impl");
    }
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }

  function _updateExtensions(address currentComptroller) internal {
    address[] memory latestExtensions = IFeeDistributor(ionicAdmin).getComptrollerExtensions(currentComptroller);
    address[] memory currentExtensions = LibDiamond.listExtensions();

    // removed the current (old) extensions
    for (uint256 i = 0; i < currentExtensions.length; i++) {
      LibDiamond.removeExtension(DiamondExtension(currentExtensions[i]));
    }
    // add the new extensions
    for (uint256 i = 0; i < latestExtensions.length; i++) {
      LibDiamond.addExtension(DiamondExtension(latestExtensions[i]));
    }
  }

  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external override {
    require(hasAdminRights(), "!unauthorized");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }
}
