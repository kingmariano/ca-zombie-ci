pragma solidity 0.5.17;


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

/**
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

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
interface IWrbtc {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
contract IERC20 {
    string public name;
    uint8 public decimals;
    string public symbol;

    function totalSupply() public view returns (uint256);

    function balanceOf(address _who) public view returns (uint256);

    function allowance(address _owner, address _spender) public view returns (uint256);

    function approve(address _spender, uint256 _value) public returns (bool);

    function transfer(address _to, uint256 _value) public returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
contract IWrbtcERC20 is IWrbtc, IERC20 {}

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
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

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
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
contract LoanTokenBase is ReentrancyGuard, Ownable, Pausable {
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

/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
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

/**
 * @title Loan Token contract.
 * @notice This contract code comes from bZx. bZx is a protocol for tokenized
 * margin trading and lending https://bzx.network similar to the dYdX protocol.
 *
 * A loan token (iToken) is created as a proxy to an upgradable token contract.
 *
 * Examples of loan tokens on Sovryn are iRBTC, iDOC, iUSDT, iBPro,
 * iSOV (near future).
 *
 * Lenders receive iTokens that collect interest from the lending pool
 * which they can redeem by withdrawing them. The i in iToken stands for interest.
 *
 * Do not confuse iTokens with underlying tokens. iDOC is an iToken (loan token)
 * whilest DOC is the underlying token (currency).
 *
 * @dev TODO: can I change this proxy to EIP-1822 proxy standard, please.
 *   https://eips.ethereum.org/EIPS/eip-1822. It's really hard to work with this.
 * */
contract LoanToken is AdvancedTokenStorage {
    /// @dev It is important to maintain the variables order so the delegate
    /// calls can access sovrynContractAddress and wrbtcTokenAddress
    address public sovrynContractAddress;
    address public wrbtcTokenAddress;
    address internal target_;
    address public admin;

    /**
     * @notice Deploy loan token proxy.
     *   Sets ERC20 parameters of the token.
     *
     * @param _newOwner The address of the new owner.
     * @param _newTarget The address of the new target contract instance.
     * @param _sovrynContractAddress The address of the new sovrynContract instance.
     * @param _wrbtcTokenAddress The address of the new wrBTC instance.
     * */
    constructor(
        address _newOwner,
        address _newTarget,
        address _sovrynContractAddress,
        address _wrbtcTokenAddress
    ) public {
        transferOwnership(_newOwner);
        _setTarget(_newTarget);
        _setSovrynContractAddress(_sovrynContractAddress);
        _setWrbtcTokenAddress(_wrbtcTokenAddress);
    }

    /**
     * @notice Fallback function performs a delegate call
     * to the actual implementation address is pointing this proxy.
     * Returns whatever the implementation call returns.
     * */
    function() external payable {
        if (gasleft() <= 2300) {
            return;
        }

        address target = target_;
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
     * @notice Public owner setter for target address.
     * @dev Calls internal setter.
     * @param _newTarget The address of the new target contract instance.
     * */
    function setTarget(address _newTarget) public onlyOwner {
        _setTarget(_newTarget);
    }

    /**
     * @notice Internal setter for target address.
     * @param _newTarget The address of the new target contract instance.
     * */
    function _setTarget(address _newTarget) internal {
        require(Address.isContract(_newTarget), "target not a contract");
        target_ = _newTarget;
    }

    /**
     * @notice Internal setter for sovrynContract address.
     * @param _sovrynContractAddress The address of the new sovrynContract instance.
     * */
    function _setSovrynContractAddress(address _sovrynContractAddress) internal {
        require(Address.isContract(_sovrynContractAddress), "sovryn not a contract");
        sovrynContractAddress = _sovrynContractAddress;
    }

    /**
     * @notice Internal setter for wrBTC address.
     * @param _wrbtcTokenAddress The address of the new wrBTC instance.
     * */
    function _setWrbtcTokenAddress(address _wrbtcTokenAddress) internal {
        require(Address.isContract(_wrbtcTokenAddress), "wrbtc not a contract");
        wrbtcTokenAddress = _wrbtcTokenAddress;
    }

    /**
     * @notice Public owner cloner for pointed loan token.
     *   Sets ERC20 parameters of the token.
     *
     * @dev TODO: add check for double init.
     *   idk but init usually can be called only once.
     *
     * @param _loanTokenAddress The address of the pointed loan token instance.
     * @param _name The ERC20 token name.
     * @param _symbol The ERC20 token symbol.
     * */
    function initialize(
        address _loanTokenAddress,
        string memory _name,
        string memory _symbol
    ) public onlyOwner {
        loanTokenAddress = _loanTokenAddress;

        name = _name;
        symbol = _symbol;
        decimals = IERC20(loanTokenAddress).decimals();

        initialPrice = 10**18; /// starting price of 1
    }
}