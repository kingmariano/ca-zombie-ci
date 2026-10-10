// Sources flattened with hardhat v2.13.0 https://hardhat.org

// File contracts/connectors/loantoken/Pausable.sol

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

/**
 * @title Pausable contract.
 * @notice This contract code comes from bZx. bZx is a protocol for tokenized margin
 * trading and lending https://bzx.network similar to the dYdX protocol.
 *
 * The contract implements pausable functionality by reading on slots the
 * pause state of contract functions.
 * */
contract Pausable {
    /// keccak256("Pausable_FunctionPause")
    bytes32 internal constant Pausable_FunctionPause =
        0xa7143c84d793a15503da6f19bf9119a2dac94448ca45d77c8bf08f57b2e91047;

    modifier pausable(bytes4 sig) {
        require(!_isPaused(sig), "unauthorized");
        _;
    }

    /**
     * @notice Check whether a function is paused.
     *
     * @dev Used to read externally from the smart contract to see if a
     *   function is paused.
     *
     * @param sig The function ID, the selector on bytes4.
     *
     * @return isPaused Whether the function is paused: true or false.
     * */
    function _isPaused(bytes4 sig) internal view returns (bool isPaused) {
        bytes32 slot = keccak256(abi.encodePacked(sig, Pausable_FunctionPause));
        assembly {
            isPaused := sload(slot)
        }
    }
}


// File contracts/interfaces/IERC20.sol

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity >=0.5.0 <0.6.0;

contract IERC20 {
    string public name;
    uint8 public decimals;
    string public symbol;

    function totalSupply() external view returns (uint256);

    function balanceOf(address _who) external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function approve(address _spender, uint256 _value) external returns (bool);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File contracts/interfaces/IWrbtc.sol

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity >=0.5.0 <0.6.0;

interface IWrbtc {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}


// File contracts/interfaces/IWrbtcERC20.sol

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity >=0.5.0 <0.6.0;


contract IWrbtcERC20 is IWrbtc, IERC20 {}


// File contracts/openzeppelin/Address.sol

pragma solidity >=0.5.0 <0.6.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html
     *   #use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     *
     * _Available since v2.4.0._
     */
    function sendValue(address recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}


// File contracts/openzeppelin/Context.sol

pragma solidity >=0.5.0 <0.6.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}

    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File contracts/openzeppelin/Ownable.sol

pragma solidity >=0.5.0 <0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "unauthorized");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// File contracts/openzeppelin/ReentrancyGuard.sol

pragma solidity >=0.5.0 <0.6.0;

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev Constant for unlocked guard state - non-zero to prevent extra gas costs.
    /// See: https://github.com/OpenZeppelin/openzeppelin-solidity/issues/1056
    uint256 internal constant REENTRANCY_GUARD_FREE = 1;

    /// @dev Constant for locked guard state
    uint256 internal constant REENTRANCY_GUARD_LOCKED = 2;

    /**
     * @dev We use a single lock for the whole contract.
     */
    uint256 internal reentrancyLock = REENTRANCY_GUARD_FREE;

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * If you mark a function `nonReentrant`, you should also
     * mark it `external`. Calling one `nonReentrant` function from
     * another is not supported. Instead, you can implement a
     * `private` function doing the actual work, and an `external`
     * wrapper marked as `nonReentrant`.
     */
    modifier nonReentrant() {
        require(reentrancyLock == REENTRANCY_GUARD_FREE, "nonReentrant");
        reentrancyLock = REENTRANCY_GUARD_LOCKED;
        _;
        reentrancyLock = REENTRANCY_GUARD_FREE;
    }
}


// File contracts/openzeppelin/SafeMath.sol

pragma solidity >=0.5.0 <0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b != 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Integer division of two numbers, rounding up and truncating the quotient
     */
    function divCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        return divCeil(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Integer division of two numbers, rounding up and truncating the quotient
     */
    function divCeil(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b != 0, errorMessage);

        if (a == 0) {
            return 0;
        }
        uint256 c = ((a - 1) / b) + 1;

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function min256(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}


// File contracts/openzeppelin/SignedSafeMath.sol

pragma solidity >=0.5.0 <0.6.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 private constant _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}


// File contracts/reentrancy/Mutex.sol

pragma solidity ^0.5.17;

/*
 * @title Global Mutex contract
 *
 * @notice A mutex contract that allows only one function to be called at a time out
 * of a large set of functions. *Anyone* in the network can freely use any instance
 * of this contract to add a universal mutex to any function in any contract.
 */
contract Mutex {
    /*
     * We use an uint to store the mutex state.
     */
    uint256 public value;

    /*
     * @notice Increment the mutex state and return the new value.
     *
     * @dev This is the function that will be called by anyone to change the mutex
     * state. It is purposely not protected by any access control
     */
    function incrementAndGetValue() external returns (uint256) {
        /*
         * increment value using unsafe math. This is safe because we are
         * pretty certain no one will ever increment the value 2^256 times
         * in a single transaction.
         */
        return ++value;
    }
}


// File contracts/reentrancy/SharedReentrancyGuard.sol

pragma solidity ^0.5.17;

/*
 * @title Abstract contract for shared reentrancy guards
 *
 * @notice Exposes a single modifier `globallyNonReentrant` that can be used to ensure
 * that there's no reentrancy between *any* functions marked with the modifier.
 *
 * @dev The Mutex contract address is hardcoded because the address is deployed using a
 * special deployment method (similar to ERC1820Registry). This contract therefore has no
 * state and is thus safe to add to the inheritance chain of upgradeable contracts.
 */
contract SharedReentrancyGuard {
    /*
     * This is the address of the mutex contract that will be used as the
     * reentrancy guard.
     *
     * The address is hardcoded to avoid changing the memory layout of
     * derived contracts (possibly upgradable). Hardcoding the address is possible,
     * because the Mutex contract is always deployed to the same address, with the
     * same method used in the deployment of ERC1820Registry.
     */
    Mutex private constant MUTEX = Mutex(0xba10edD6ABC7696Eae685839217BdcC42139612b);

    /*
     * This is the modifier that will be used to protect functions from
     * reentrancy. It will call the mutex contract to increment the mutex
     * state and then revert if the mutex state was changed by another
     * nested call.
     */
    modifier globallyNonReentrant() {
        uint256 previous = MUTEX.incrementAndGetValue();

        _;

        /*
         * If the mutex state was changed by a nested function call, then
         * the value of the state variable will be different from the previous value.
         */
        require(previous == MUTEX.value(), "reentrancy violation");
    }
}


// File contracts/connectors/loantoken/LoanTokenBase.sol

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;








/**
 * @title Loan Token Base contract.
 * @notice This contract code comes from bZx. bZx is a protocol for tokenized margin
 * trading and lending https://bzx.network similar to the dYdX protocol.
 *
 * Specific loan related storage for iTokens.
 *
 * An loan token or iToken is a representation of a user funds in the pool and the
 * interest they've earned. The redemption value of iTokens continually increase
 * from the accretion of interest paid into the lending pool by borrowers. The user
 * can sell iTokens to exit its position. The user might potentially use them as
 * collateral wherever applicable.
 *
 * There are three main tokens in the bZx system, iTokens, pTokens, and BZRX tokens.
 * The bZx system of lending and borrowing depends on iTokens and pTokens, and when
 * users lend or borrow money on bZx, their crypto assets go into or come out of
 * global liquidity pools, which are pools of funds shared between many different
 * exchanges. When lenders supply funds into the global liquidity pools, they
 * automatically receive iTokens; When users borrow money to open margin trading
 * positions, they automatically receive pTokens. The system is also designed to
 * use the BZRX tokens, which are only used to pay fees on the network currently.
 * */
contract LoanTokenBase is ReentrancyGuard, SharedReentrancyGuard, Ownable, Pausable {
    uint256 internal constant WEI_PRECISION = 10**18;
    uint256 internal constant WEI_PERCENT_PRECISION = 10**20;

    int256 internal constant sWEI_PRECISION = 10**18;

    /// @notice Standard ERC-20 properties
    string public name;
    string public symbol;
    uint8 public decimals;

    /// @notice The address of the loan token (asset to lend) instance.
    address public loanTokenAddress;

    uint256 public baseRate;
    uint256 public rateMultiplier;
    uint256 public lowUtilBaseRate;
    uint256 public lowUtilRateMultiplier;

    uint256 public targetLevel;
    uint256 public kinkLevel;
    uint256 public maxScaleRate;

    uint256 internal _flTotalAssetSupply;
    uint256 public checkpointSupply;
    uint256 public initialPrice;

    /// uint88 for tight packing -> 8 + 88 + 160 = 256
    uint88 internal lastSettleTime_;

    /// Mapping of keccak256(collateralToken, isTorqueLoan) to loanParamsId.
    mapping(uint256 => bytes32) public loanParamsIds;

    /// Price of token at last user checkpoint.
    mapping(address => uint256) internal checkpointPrices_;

    // the maximum trading/borrowing/lending limit per token address
    mapping(address => uint256) public transactionLimit;
    // 0 -> no limit
}


// File contracts/connectors/loantoken/AdvancedTokenStorage.sol

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

/**
 * @title Advanced Token Storage contract.
 * @notice This contract code comes from bZx. bZx is a protocol for tokenized
 * margin trading and lending https://bzx.network similar to the dYdX protocol.
 *
 * AdvancedTokenStorage implements standard ERC-20 getters functionality:
 * totalSupply, balanceOf, allowance and some events.
 * iToken logic is divided into several contracts AdvancedToken,
 * AdvancedTokenStorage and LoanTokenBase.
 * */
contract AdvancedTokenStorage is LoanTokenBase {
    using SafeMath for uint256;

    /* Events */

    /// topic: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// topic: 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// topic: 0x628e75c63c1873bcd3885f7aee9f58ee36f60dc789b2a6b3a978c4189bc548ba
    event AllowanceUpdate(
        address indexed owner,
        address indexed spender,
        uint256 valueBefore,
        uint256 valueAfter
    );

    /// topic: 0xb4c03061fb5b7fed76389d5af8f2e0ddb09f8c70d1333abbb62582835e10accb
    event Mint(address indexed minter, uint256 tokenAmount, uint256 assetAmount, uint256 price);

    /// topic: 0x743033787f4738ff4d6a7225ce2bd0977ee5f86b91a902a58f5e4d0b297b4644
    event Burn(address indexed burner, uint256 tokenAmount, uint256 assetAmount, uint256 price);

    /// topic: 0xc688ff9bd4a1c369dd44c5cf64efa9db6652fb6b280aa765cd43f17d256b816e
    event FlashBorrow(address borrower, address target, address loanToken, uint256 loanAmount);

    /* Storage */

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowed;
    uint256 internal totalSupply_;

    /* Functions */

    /**
     * @notice Get the total supply of iTokens.
     * @return The total number of iTokens in existence as of now.
     * */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @notice Get the amount of iTokens owned by an account.
     * @param _owner The account owner of the iTokens.
     * @return The number of iTokens an account owns.
     * */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
     * @notice Get the amount of iTokens allowed to be spent by a
     *   given account on behalf of the owner.
     * @param _owner The account owner of the iTokens.
     * @param _spender The account allowed to send the iTokens.
     * @return The number of iTokens an account is allowing the spender
     *   to send on its behalf.
     * */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
}


// File contracts/openzeppelin/Initializable.sol

pragma solidity >=0.5.0 <0.6.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}


// File contracts/connectors/loantoken/LoanTokenLogicProxy.sol

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;


/**
 * @title Loan Token Logic Proxy contract.
 *
 * @notice This contract contains the proxy functionality and it will query the logic target from LoanTokenLogicBeacon
 * This contract will also has the pause/unpause functionality. The purpose of this pausability is so that we can pause/unpause from the loan token level.
 *
 */
contract LoanTokenLogicProxy is AdvancedTokenStorage {
    /**
     * @notice PLEASE DO NOT ADD ANY VARIABLES HERE UNLESS FOR SPESIFIC SLOT
     */

    /// ------------- MUST BE THE SAME AS IN LoanToken CONTRACT -------------------
    address public sovrynContractAddress;
    address public wrbtcTokenAddress;
    address public target_;
    address public admin;
    /// ------------- END MUST BE THE SAME AS IN LoanToken CONTRACT -------------------

    /**
     * @notice PLEASE DO NOT ADD ANY VARIABLES HERE UNLESS FOR SPESIFIC SLOT (CONSTANT / IMMUTABLE)
     */

    bytes32 internal constant LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT =
        keccak256("LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT");

    modifier onlyAdmin() {
        require(isOwner(), "LoanTokenLogicProxy:unauthorized");
        _;
    }

    /**
     * @notice Fallback function performs a logic implementation address query to LoanTokenLogicBeacon and then do delegate call to that query result address.
     * Returns whatever the implementation call returns.
     * */
    function() external payable {
        // query the logic target implementation address from the LoanTokenLogicBeacon
        address target = ILoanTokenLogicBeacon(_beaconAddress()).getTarget(msg.sig);
        require(target != address(0), "LoanTokenLogicProxy:target not active");

        bytes memory data = msg.data;
        assembly {
            let result := delegatecall(gas, target, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }

    /**
     * @dev Returns the current Loan Token logic Beacon.
     * @return Address of the current LoanTokenLogicBeacon.
     */
    function _beaconAddress() internal view returns (address beaconAddress) {
        bytes32 slot = LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT;
        assembly {
            beaconAddress := sload(slot)
        }
    }

    /**
     * @return The address of the current LoanTokenLogicBeacon.
     */
    function beaconAddress() external view returns (address) {
        return _beaconAddress();
    }

    /**
     * @dev Set/update the new beacon address.
     * @param _newBeaconAddress Address of the new LoanTokenLogicBeacon.
     */
    function _setBeaconAddress(address _newBeaconAddress) private {
        require(
            Address.isContract(_newBeaconAddress),
            "Cannot set beacon address to a non-contract address"
        );

        bytes32 slot = LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT;

        assembly {
            sstore(slot, _newBeaconAddress)
        }
    }

    /**
     * @dev External function to set the new LoanTokenLogicBeacon Address
     * @param _newBeaconAddress Address of the new LoanTokenLogicBeacon
     */
    function setBeaconAddress(address _newBeaconAddress) external onlyAdmin {
        _setBeaconAddress(_newBeaconAddress);
    }

    /**
     * @dev External function to return the LoanTokenLogicProxy of loan token (target of LoanToken contract).
     * Ideally this getter should be added in the LoanToken contract
     * but since LoanToken contract can't be changed, adding the getter in this contract will do
     * because it will use the context of LoanToken contract.
     *
     * @return target address of LoanToken contract
     */
    function getTarget() external view returns (address) {
        return target_;
    }
}

interface ILoanTokenLogicBeacon {
    function getTarget(bytes4 functionSignature)
        external
        view
        returns (address logicTargetAddress);
}
