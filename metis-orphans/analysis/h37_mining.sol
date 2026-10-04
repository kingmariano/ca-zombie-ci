
// File: contracts/interfaces/IDistributor.sol


pragma solidity 0.6.12;

interface IDistributor {
    function distribute(address _to, uint256 _amount) external returns (uint256);
}

// File: contracts/interfaces/IDACRecorder.sol


pragma solidity 0.6.12;

interface IDACRecorder {
    enum Role { Creator, Member, None }
    enum DACState{ Active, Inactive }

    function checkUserInfo(address _user) 
        external 
        view 
        returns (Role userRole, uint256 accPower, uint256 amount);
    function checkDACInfo(uint256 _dacId) 
        external 
        view 
        returns (DACState state, uint256 userCount, uint256 accMetisPerShare, address creator, uint256 initialDACPower);
    function isCreator(address _user) external view returns (bool);
    function getUserAccPower(address _user) external view returns (uint256);
    function addCreator(address _user) external returns (bool);
    function removeCreator(address _user) external returns (bool);
    function addMember(uint256 _dacId, address _member) external returns (bool);
    function delMember(uint256 _dacId, address _member) external returns (bool);
    function updateCreatorInfo(
        address _user,
        uint256 _dacId,
        uint256 _amount,
        uint256 _accMetisPerShare,
        bool _withdrawAll
    ) external returns (bool);
    function updateMemberInfo(
        address _user,
        uint256 _dacId,
        uint256 _amount,
        bool _withdrawAll,
        bool _isDeposit
    ) external returns (bool);
    function creatorOf(address _member) external returns (address);
    function setCreatorOf(address _creator, address _user) external;
    function totalWeight() external view returns (uint256);
    function userWeight(address _user) external view returns (uint256);
    function MIN_MEMBER_COUNT() external view returns (uint256);
    function DAO_OPEN() external view returns (bool);
    function stakedMetis() external view returns (uint256);
    function sendRewardToVault(address _user, uint256 _amount) external returns (bool);
}

// File: contracts/interfaces/IDAC.sol


pragma solidity 0.6.12;

interface IDAC {
    function memberLeaveDAC(uint256 dacId, address member) external returns(bool);
    function dismissDAC(uint256 dacId, address creator) external returns(bool);
    function userToDAC(address user) external view returns(uint256);
    function queryInitialPower(address user) external view returns(uint256 initialPower);
    function getDACMemberCount(uint256 dacId) external view returns(uint256);
}

// File: contracts/interfaces/IMetisToken.sol


pragma solidity 0.6.12;

interface IMetisToken {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// File: contracts/interfaces/IMining.sol


pragma solidity 0.6.12;

interface IMining {
    function deposit(
        address _creator,
        address _user, 
        uint256 _pid, 
        uint256 _amount,
        uint256 _dacId
    ) external returns (bool);

    function withdraw(address _creator, uint256 _pid, uint256 _amount) external returns (bool);

    function dismissDAC(uint256 _dacId, uint256 _pid, address _creator) external returns (bool);

    function tokenToPid(address _token) external view returns (uint256);
}

// File: contracts/common/Context.sol


pragma solidity ^0.6.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: contracts/common/Ownable.sol


pragma solidity ^0.6.0;


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
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/common/Address.sol


pragma solidity ^0.6.2;

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
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
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
    }
}

// File: contracts/common/SafeMath.sol


pragma solidity ^0.6.0;

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
     *
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
     *
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/common/IERC20.sol


pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// File: contracts/common/SafeERC20.sol


pragma solidity ^0.6.0;




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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

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
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: contracts/Mining.sol


pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;










contract Mining is Ownable, IMining {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided.
        uint256 rewardDebt; // Reward debt
    }

    // Info of each pool.
    struct PoolInfo {
        address token; // Address of staked token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Metis to distribute per 3min.
        uint256 lastRewardTimestamp; // Last block timestamp that Metis distribution occurs.
        uint256 accMetisPerShare; // Accumulated Metis per share, times 1e18. See below.
    }

    // The Metis TOKEN!
    IMetisToken public Metis;
    // DAC
    IDAC public DAC;
    // DACRecorder
    IDACRecorder public DACRecorder;
    // Metis distributor
    IDistributor public distributor;
    // Dev address.
    address public teamAddr;
    address private setter;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // mapping of token to pool id
    mapping(address => uint) public override tokenToPid;
    // Info of each user that stakes staked tokens.
    mapping(uint => mapping(address => UserInfo)) public userInfo;
    // Metis tokens created per second.
    uint256 public MetisPerSecond;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block timestamp when Metis mining starts.
    uint256 public startTimestamp;
    uint256 public MIN_DEPOSIT = 10 * 1e18;
    uint256 public MAX_DEPOSIT = 2000 * 1e18;
    bool public paused = false;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMetisToken _Metis,
        IDACRecorder _DACRecorder,
        IDistributor _distributor,
        uint256 _MetisPerSecond,
        uint256 _startTimestamp
    ) public {
        Metis = _Metis;
        DACRecorder = _DACRecorder;
        distributor = _distributor;
        MetisPerSecond = _MetisPerSecond;
        startTimestamp = _startTimestamp;
        setter = msg.sender;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function calcMetisReward(
        uint256 currentTime,
        uint256 lastRewardTime, 
        uint256 allocPoint 
    ) public view returns (uint256 accTime, uint256 MetisReward) {
        if (totalAllocPoint > 0) {
            accTime = currentTime.sub(lastRewardTime);
            MetisReward = MetisPerSecond.mul(accTime).mul(allocPoint).div(totalAllocPoint);
        }
    }

    // View function to see pending Metis on frontend.
    function pendingMetis(uint256 _currentTime, uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 _dacId = DAC.userToDAC(_user);
        (IDACRecorder.DACState dacState,, uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        uint256 share = pool.accMetisPerShare;
        if (dacState == IDACRecorder.DACState.Inactive) {
            share = accMetisPerShare;
        }
        uint256 totalWeight = DACRecorder.totalWeight();
        if (dacState == IDACRecorder.DACState.Active && _currentTime > pool.lastRewardTimestamp && totalWeight != 0) {
            (,uint256 MetisReward) = calcMetisReward(_currentTime, pool.lastRewardTimestamp, pool.allocPoint);
            if(Metis.balanceOf(address(distributor)) < MetisReward) {
                MetisReward = Metis.balanceOf(address(distributor));
            }
            share = share.add(MetisReward.mul(1e18).div(totalWeight));
        }
        uint256 _userWeight = DACRecorder.userWeight(_user);
        return _userWeight.mul(share).div(1e18).sub(user.rewardDebt);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 totalWeight = DACRecorder.totalWeight();
        if (totalWeight == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        (,uint256 MetisReward) = calcMetisReward(block.timestamp, pool.lastRewardTimestamp, pool.allocPoint);
        if (teamAddr != address(0)) {
            distributor.distribute(teamAddr, MetisReward.div(9));
        }
        uint256 realReward = distributor.distribute(address(DACRecorder), MetisReward);
        emit Mint(realReward);
        pool.accMetisPerShare = pool.accMetisPerShare.add(
            realReward.mul(1e18).div(totalWeight)
        );
        pool.lastRewardTimestamp = block.timestamp;
    }

    function deposit(
        address _creator,
        address _user, 
        uint256 _pid, 
        uint256 _amount,
        uint256 _dacId
    ) onlyDAC notPaused external override returns (bool) {
        bool isCreator = _creator == address(0);
        address existedCreator = DACRecorder.creatorOf(_user);
        (IDACRecorder.DACState dacState,,uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (isCreator) {
            require(DACRecorder.creatorOf(_user) == address(0), "existed member");
            if (!DACRecorder.isCreator(_user)) {
                DACRecorder.addCreator(_user);
            } 
        } else {
            if (existedCreator != address(0)) {
                // old member
                require(_creator == existedCreator, "wrong creator");
            } else {
                // new member, send pending rewards to creator
                _sendPending(_pid, _creator, dacState, accMetisPerShare);
                DACRecorder.setCreatorOf(_creator, _user);
                DACRecorder.addMember(_dacId, _user);
            }
        }
        if (user.amount > 0) {
            _sendPending(_pid, _user, dacState, accMetisPerShare);
        }
        if (_amount > 0 && dacState == IDACRecorder.DACState.Active) {
            uint256 remainingAmount = user.amount.add(_amount);
            require(remainingAmount >= MIN_DEPOSIT && remainingAmount <= MAX_DEPOSIT, "amount is invalid");
            if (isCreator) {
                DACRecorder.updateCreatorInfo(_user, _dacId, remainingAmount, 0, false);
            } else {
                DACRecorder.updateMemberInfo(_user, _dacId, remainingAmount, false, true);
                if (user.amount == 0) {
                    // new member, update creator rewardDebt
                    _updateCreatorRewardDebt(_pid, _creator);
                }
            }
            user.amount = remainingAmount;
            IERC20(pool.token).safeTransferFrom(_user, address(this), _amount);
        }
        uint256 _userWeight = DACRecorder.userWeight(_user);
        uint256 share = pool.accMetisPerShare;
        if (dacState == IDACRecorder.DACState.Inactive) {
            share = accMetisPerShare;
        } 
        user.rewardDebt = _userWeight.mul(share).div(1e18);
        emit Deposit(_creator, _user, _pid, _amount, _dacId);
        return true;
    }

    function withdraw(
        address _creator, 
        uint256 _pid, 
        uint256 _amount
    ) notPaused external override returns (bool) {
        uint256 _dacId = DAC.userToDAC(msg.sender);
        bool isCreator = _creator == address(0);
        if (!isCreator) {
            require(!DACRecorder.isCreator(msg.sender), "sender is a creator");
            require(_creator == DACRecorder.creatorOf(msg.sender), "wrong creator");
        } else {
            require(DACRecorder.isCreator(msg.sender), "sender is not a creator ");
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        (IDACRecorder.DACState dacState,uint256 userCount,uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        _sendPending(_pid, msg.sender, dacState, accMetisPerShare);
        if(_amount > 0) {
            uint256 remainingAmount = user.amount.sub(_amount);
            if (isCreator) {
                if (userCount > DACRecorder.MIN_MEMBER_COUNT() || DACRecorder.DAO_OPEN()) {
                    require(
                        remainingAmount >= MIN_DEPOSIT, 
                        "not allowed"
                    );
                }
                // means that the creator dismiss DAC without DAO opening
                if (remainingAmount == 0) {
                    DAC.dismissDAC(_dacId, msg.sender);
                    DACRecorder.updateCreatorInfo(msg.sender, _dacId, remainingAmount, pool.accMetisPerShare, true);
                    DACRecorder.removeCreator(msg.sender);
                } else {
                    DACRecorder.updateCreatorInfo(msg.sender, _dacId, remainingAmount, 0, false);
                }
            } else {
                require(
                    remainingAmount == 0 || remainingAmount >= MIN_DEPOSIT, 
                    "not allowed"
                );
                // means that the member leave a specific DAC
                if (remainingAmount == 0) {
                    if (dacState == IDACRecorder.DACState.Active) {
                        _sendPending(_pid, _creator, dacState, accMetisPerShare);
                    }
                    DAC.memberLeaveDAC(_dacId, msg.sender);
                    DACRecorder.updateMemberInfo(msg.sender, _dacId, remainingAmount, true, false);
                    DACRecorder.delMember(_dacId, msg.sender);
                    // member leave, update creator rewardDebt
                    _updateCreatorRewardDebt(_pid, _creator);
                } else {
                    DACRecorder.updateMemberInfo(msg.sender, _dacId, remainingAmount, false, false);
                }
            }
            user.amount = remainingAmount;
            IERC20(pool.token).safeTransfer(address(msg.sender), _amount);
        }
        uint256 _userWeight = DACRecorder.userWeight(msg.sender);
        uint256 share = pool.accMetisPerShare;
        if (dacState == IDACRecorder.DACState.Inactive) {
            share = accMetisPerShare;
        } 
        user.rewardDebt = _userWeight.mul(share).div(1e18);
        emit Withdraw(_creator, msg.sender, _pid, _amount, _dacId);
        return true;
    }

    function dismissDAC(uint256 _dacId, uint256 _pid, address _creator) onlyDAC notPaused external override returns (bool) {
        require(DACRecorder.DAO_OPEN(), "DAO is not opened");
        require(DACRecorder.isCreator(_creator), "not a creator");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage creator = userInfo[_pid][_creator];
        updatePool(_pid);
        (IDACRecorder.DACState dacState,,uint256 accMetisPerShare,,) = DACRecorder.checkDACInfo(_dacId);
        _sendPending(_pid, _creator, dacState, accMetisPerShare);
        DACRecorder.updateCreatorInfo(_creator, _dacId, 0, pool.accMetisPerShare, true);
        DACRecorder.removeCreator(_creator);
        IERC20(pool.token).safeTransfer(_creator, creator.amount);
        creator.amount = 0;
        return true;
    }

    // Withdraw without caring about rewards and DAC data when paused. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(paused, 'not paused');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        IERC20(pool.token).safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _sendPending(uint256 _pid, address _user, IDACRecorder.DACState dacState, uint256 accMetisPerShare) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 share = pool.accMetisPerShare;
        if (dacState == IDACRecorder.DACState.Inactive) {
            share = accMetisPerShare;
        }
        uint256 _userWeight = DACRecorder.userWeight(_user);
        uint256 pending = _userWeight.mul(share).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            DACRecorder.sendRewardToVault(_user, pending);
        }
    }

    function _updateCreatorRewardDebt(uint256 _pid, address _creator) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage creator = userInfo[_pid][_creator];
        if (creator.amount > 0) {
            uint256 _creatorWeight = DACRecorder.userWeight(_creator);
            creator.rewardDebt = _creatorWeight.mul(pool.accMetisPerShare).div(1e18);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Add a new staked token to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _token, bool _withUpdate) external onlySetter {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                token: _token,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accMetisPerShare: 0
            })
        );
        tokenToPid[_token] = poolInfo.length - 1;
    }

    // Update the given pool's Metis allocation point. Can only be called by the owner.
    // In our case there will be only one pool, this is just in case of multi pool extension
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlySetter {
        if (_withUpdate) {
            massUpdatePools();
        } else {
            updatePool(_pid);
        }
        if (poolInfo[_pid].allocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        }
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setMetisPerSecond(uint256 _MetisPerSecond) external onlySetter {
        massUpdatePools();
        MetisPerSecond = _MetisPerSecond;
        emit MetisPerSecondChanged(_MetisPerSecond);
    }

    function setMetisToken(IMetisToken _metis) external onlyOwner {
        Metis = _metis;
    }

    function setDAC(IDAC _DAC) external onlyOwner {
        DAC = _DAC;
    }

    function setDACRecorder(IDACRecorder _DACRecorder) external onlyOwner {
        DACRecorder = _DACRecorder;
    }

    function setDistributor(IDistributor _distributor) external onlyOwner {
        distributor = _distributor;
    }

    function setMinDeposit(uint256 _minDeposit) external onlySetter {
        MIN_DEPOSIT = _minDeposit;
        emit MinDepositChanged(_minDeposit);
    }

    function setMaxDeposit(uint256 _maxDeposit) external onlySetter {
        MAX_DEPOSIT = _maxDeposit;
        emit MaxDepositChanged(_maxDeposit);
    }

    function setStartTimestamp(uint256 _startTimestamp) external onlySetter {
        require(block.timestamp < _startTimestamp, "started");
        startTimestamp = _startTimestamp;
        // reinitialize lastRewardTimestamp of all existing pools (if any)
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTimestamp = _startTimestamp;
        }
        emit StartTimestampChanged(_startTimestamp);
    }

    function setTeamAddr(address _teamAddr) external onlyOwner {
        teamAddr = _teamAddr;
        emit TeamAddrChanged(_teamAddr);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyDAC() {
        require(msg.sender == address(DAC), "not DAC");
        _;
    }

    modifier onlySetter() {
        require(msg.sender == setter, "not setter");
        _;
    }

    modifier notPaused() {
        require(!paused, 'paused');
        _;
    }

    /* ========== EVENTS ========== */

    event Deposit(address indexed creator, address indexed user, uint256 pid, uint256 amount, uint256 dacId);
    event Withdraw(address indexed creator, address indexed user, uint256 pid, uint256 amount, uint256 dacId);
    event Mint(uint256 amount);
    event TeamAddrChanged(address indexed team);
    event StartTimestampChanged(uint256 newStartTime);
    event MinDepositChanged(uint256 newMin);
    event MaxDepositChanged(uint256 newMax);
    event MetisPerSecondChanged(uint256 newPerSecond);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
}
