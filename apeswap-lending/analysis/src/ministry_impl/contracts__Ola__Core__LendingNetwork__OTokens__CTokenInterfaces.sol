// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../Comptroller/ComptrollerInterface.sol";
import "../../OlaPlatform/InterestRateModels/InterestRateModel.sol";
import "../../Interfaces/EIP20NonStandardInterface.sol";

/**
 * OLA_ADDITIONS : This base admin storage.
 */
contract CTokenAdminStorage {
    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address payable public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Implementation address for this contract
     */
    address public implementation;

    // OLA_ADDITIONS : Contract hash name
    bytes32 public contractNameHash;
}

/**
 * @notice DO NOT ADD ANY MORE STORAGE VARIABLES HERE (add them to their respective type storage)
 */
contract CTokenStorage is CTokenAdminStorage {
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

    /**
     * @notice Underlying asset for this CToken
     */
    address public underlying;

    // @notice Indicates if the calculations should be blocks or time based
    bool public blocksBased;

    /**
     * @notice Model which tells what the current interest rate should be
     */
    InterestRateModel public interestRateModel;

    /**
     * @notice Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
     */
    uint internal initialExchangeRateMantissa;

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint public reserveFactorMantissa;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockNumber;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockTimestamp;

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    uint public borrowIndex;

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    uint public totalBorrows;

    /**
     * OLA_ADDITIONS : Removed option to 'add reserves' as it makes no sense when reducing reserves
     *                 sends a part to Ola Bank.
     * @notice Total amount of reserves of the underlying held in this market
     */
    uint public totalReserves;

    /**
     * @notice Total number of tokens in circulation
     */
    uint public totalSupply;

    /**
     * @notice Official record of token balances for each account
     */
    mapping (address => uint) internal accountTokens;

    /**
     * @notice Approved token transfer amounts on behalf of others
     */
    mapping (address => mapping (address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    /**
     * @notice Mapping of account addresses to outstanding borrow balances
     */
    mapping(address => BorrowSnapshot) internal accountBorrows;

    // IMPORTANT : DO NOT ADD ANY MORE STORAGE VARIABLES HERE (add them to their respective type storage)
}

contract CTokenDelegatorInterface {

    /*** Implementation Events ***/

    /**
     * @notice Emitted when implementation is changed
     */
    event NewImplementation(address indexed oldImplementation, address indexed newImplementation);

    /**
     * @notice Emitted when implementation is not changed under a system version update
     */
    event ImplementationDidNotChange(address indexed implementation);


    /*** Implementation functions ***/

    // OLA_ADDITIONS : Update implementation from the Registry
    function updateImplementationFromRegistry(bool allowResign, bytes calldata becomeImplementationData) external returns (bool);
}

contract CTokenInterface {
    // OLA_ADDITIONS : "Underlying field"
    address constant public nativeCoinUnderlying = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /**
     * OLA_ADDITIONS : This field
     * @notice This value is hard coded to 0.5 (50% for the Ola ecosystem and the LeN owner each)
     */
    uint constant public olaReserveFactorMantissa = 0.5e18;

    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    bool public constant isCToken = true;

    /**
     * @notice Maximum borrow rate that can ever be applied (.0005% / block)
     */
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    /**
     * @notice Maximum fraction of interest that can be set aside for reserves
     */
    uint internal constant reserveFactorMaxMantissa = 0.3e18;

    /**
     * OLA_ADDITIONS : This value
     * @notice Minimum fraction of interest that can be set aside for reserves
     */
    uint internal constant reserveFactorMinMantissa = 0.05e18;

    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint mintAmount, uint mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);


    /*** Admin Events ***/

    /**
     * @notice Event emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @notice Event emitted when Comptroller is changed
     */
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);

    /**
     * @notice Event emitted when interestRateModel is changed
     */
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(address admin, uint adminPart, address olaBank, uint olaPart, uint newTotalReserves);

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);

    /**
     * @notice Failure event
     */
    event Failure(uint error, uint info, uint detail);

    /*** User Interface ***/

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowBalanceStored(address account) public view returns (uint);
    function exchangeRateStored() public view returns (uint);
    function getAccrualBlockNumber() external view returns (uint);
    function accrueInterest() public returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);

    /*** Admin Functions ***/

    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint);
    function _acceptAdmin() external returns (uint);
    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _reduceReserves(uint reduceAmount) external returns (uint);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) public returns (uint);
}

/**
 * View functions that are not used by the core contracts.
 */
contract CTokenViewInterface {
    /*** View Interface ***/
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);

    /**
     * @notice Used by the Maximilion
     */
    function borrowBalanceCurrent(address account) external returns (uint);
    function exchangeRateCurrent() public returns (uint);
    function getCash() external view returns (uint);
}

contract CErc20Interface {
    /*** User Interface ***/

    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint);
    function sweepToken(EIP20NonStandardInterface token) external;
}

contract CErc20StorageV0_01 {}

contract CErc20StorageV0_02 is CErc20StorageV0_01 {}

contract ONativeInterface {
    /*** User Interface ***/

    function mint() external payable;
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow() external payable;
    function repayBorrowBehalf(address borrower) external payable;
    function liquidateBorrow(address borrower, CTokenInterface cTokenCollateral) external payable;
    function sweepToken(EIP20NonStandardInterface token) external;
}

contract CEtherStorageV0_01 {}

contract CEtherStorageV0_02 is CEtherStorageV0_01 {}

contract CDelegateInterface {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) public;

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() public;
}

contract UnborrowableStakeableOTokenStorage {
    address public interestAsset;
    address public stakingTarget;
}

contract CompoundingStakeableOTokenStorage {

}

// TODO : Remove ?
contract OTokenCompoundingDepositStorage {

}

// TODO : Remove ?
contract OTokenCompoundingDepositStorageV0_05 is OTokenCompoundingDepositStorage {

}

contract OMasterStakerStorageV0_05 {

}

contract CLPStakingStorageV0_05 {

    /**
     * @notice The token that is distributed via the farm
     */
    address public rewardToken;

    /**
     * @notice The farm contract
     */
    address public farmAddress;

    /**
     * @notice The pool id in the farm
     */
    uint public pid;

    /**
     * @notice The market's last updated staking index
     */
    uint public marketStakingIndex;

    /// @notice The Reward Token index for each supplier as of the last time they accrued rewards
    mapping(address => uint) public supplierStakingIndex;

    /// @notice The Reward Token accrued but not yet transferred to each supplier
    mapping(address => uint) public rewardsAccrued;
}

contract CLPStakingInterfaceV0_05 {
    /**
     * @notice Event emitted when rewards-interest is accrued
     */
    event AccrueRewardsInterest(uint oldStakingIndex, uint newStakingIndex, uint oldReserves, uint newReserves);

    event DistributeSupplierRewards(address supplier, uint supplierDelta, uint marketStakignIndex);
}