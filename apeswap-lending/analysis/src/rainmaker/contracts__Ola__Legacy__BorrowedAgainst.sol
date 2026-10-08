pragma solidity ^0.5.16;

import "../Core/LendingNetwork/PriceOracle/PriceOracle.sol";
import "../Core/LendingNetwork/OTokens/CTokenInterfaces.sol";
import "../Core/Math/Exponential.sol";
import "./BorrowedAgainstInterface.sol";

contract AdjustedComptrollerInterface {
    /// @notice The address (and interface) of the contract that checks the borrowedAgainst caps
    BorrowedAgainstInterface public borrowedAgainst;

    function markets(address) external view returns (bool);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function getAllMarkets() public view returns (CToken[] memory);
}



contract BorrowedAgainstErrorReporter {
    enum Error {
        NO_ERROR,
        SANITY,
        MATH_ERROR,
        PRICE_ERROR,
        UNAUTHORIZED,
        CANT_GET_CTOKENCOLLATERAL
    }

    enum FailureInfo {
        BORROWER_ASSETS_NOT_TWO,
        BORROWER_NOT_IN_CTOKEN,
        ACCRUAL_BLOCK_NUMBER_FROM_PAST,
        BORROW_BALANCE_TOO_SMALL,
        PRICE_RETURNED_ZERO,
        BORROW_ALLOWED_CALLER_CHECK,
        UPDATE_BORROWED_AGAINST_CALLER_CHECK,
        SET_PENDING_ADMIN_OWNER_CHECK,
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
        SET_PRICE_ORACLE_OWNER_CHECK,
        SET_BORROWED_AGAINST_OWNER_CHECK,
        BORROW_BALANCE_CALCULATION_FAILED,
        ADD_BORROW_BALANCE_AND_AMOUNT_FAILED,
        SUB_BORROW_BALANCE_AND_AMOUNT_FAILED
    }

    /**
      * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
      * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
      **/
    event Failure(uint error, uint info, uint detail);

    /**
      * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
      */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
      * @dev use this when reporting an opaque error from an upgradeable collaborator contract
      */
    function failOpaque(Error err, FailureInfo info, uint opaqueError) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}



contract BorrowedAgainst is Exponential, BorrowedAgainstErrorReporter {


    /*** Events ***/


    // TODO: add more events 
    
    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
      * @notice Emitted when price oracle is changed
      */
    event NewPriceOracle(PriceOracle oldPriceOracle, PriceOracle newPriceOracle);

    /**
      * @notice Emitted when a new usd cap is set for cTokenCollateral
      */
    event NewMaxAllowedBorrowedAgainst(address cTokenCollateral, uint oldUsdCap, uint newUsdCap);

    
    /*** State ***/


    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    AdjustedComptrollerInterface public comptroller;

    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice mapping from cTokenCollateral to the max allowed usd value that can be borrowed against that type of collateral 
     */
    mapping (address => uint) public maxAllowedBorrowedAgainst;

    // TODO: fix bug. doesn't recognize struct Borrowsnapshot defined in CTokenInterfaces.sol, so needed to redfine here
    struct NewBorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    /**
     * @notice mapping from cTokenCollateral and cTokenBorrow to the current amount of tokens that are borrowed against that type of collateral     
        struct BorrowSnapshot {
            uint principal;
            uint interestIndex;
        }
     */
    mapping (address => mapping (address => NewBorrowSnapshot)) public borrowedAgainstMap;


    /*** Logic Functions ***/


    constructor() public {
        admin = msg.sender;
    }

    // called from cTokenBorrow.borrow()
    function commitBorrowedAgainstBorrow(address borrower, uint borrowAmount) 
    external 
    // onlyCToken 
    returns (uint)
    {
        address cTokenBorrow = msg.sender;
        bool isListed = comptroller.markets(cTokenBorrow);
        if (!isListed) {
            return fail(Error.UNAUTHORIZED, FailureInfo.UPDATE_BORROWED_AGAINST_CALLER_CHECK);
        }

        address cTokenCollateral;
        uint err;
        (err, cTokenCollateral) = getCTokenCollateralInternal(borrower, cTokenBorrow);
        if (err != uint(Error.NO_ERROR)) {
            return err;
        }
        NewBorrowSnapshot storage borrowSnapshot = borrowedAgainstMap[cTokenCollateral][cTokenBorrow];

        if (CToken(cTokenBorrow).accrualBlockNumber() < block.number) {
            return fail(Error.SANITY, FailureInfo.ACCRUAL_BLOCK_NUMBER_FROM_PAST);
        }

        uint borrowBalance;
        MathError mErr;
        (mErr, borrowBalance) = borrowBalanceStoredInternal(cTokenCollateral, cTokenBorrow);
        if (mErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, FailureInfo.BORROW_BALANCE_CALCULATION_FAILED, uint(mErr));
        }
        if (borrowBalance < borrowSnapshot.principal) {
            return fail(Error.SANITY, FailureInfo.BORROW_BALANCE_TOO_SMALL);
        }

        uint borrowAmountAfter;
        (mErr, borrowAmountAfter) = addUInt(borrowBalance, borrowAmount);
        if (mErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, FailureInfo.ADD_BORROW_BALANCE_AND_AMOUNT_FAILED, uint(mErr));
        }

        // TODO: make sure this writes to storage 
        borrowSnapshot.principal = borrowAmountAfter;
        borrowSnapshot.interestIndex = CToken(cTokenBorrow).borrowIndex();
        return uint(Error.NO_ERROR);
    }

    // called from cTokenBorrow.repayBorrow()
    function commitBorrowedAgainstRepayBorrow(address borrower, uint repayBorrowAmount) 
    external
    // onlyCToken 
    returns (uint)
    {
        address cTokenBorrow = msg.sender;
        bool isListed = comptroller.markets(cTokenBorrow);
        if (!isListed) {
            return fail(Error.UNAUTHORIZED, FailureInfo.UPDATE_BORROWED_AGAINST_CALLER_CHECK);
        }
        
        address cTokenCollateral;
        uint err;
        (err, cTokenCollateral) = getCTokenCollateralInternal(borrower, cTokenBorrow);
        if (err != uint(Error.NO_ERROR)) {
            return err;
        }
        NewBorrowSnapshot storage borrowSnapshot = borrowedAgainstMap[cTokenCollateral][cTokenBorrow];

        if (CToken(cTokenBorrow).accrualBlockNumber() < block.number) {
            return fail(Error.SANITY, FailureInfo.ACCRUAL_BLOCK_NUMBER_FROM_PAST);
        }

        uint borrowBalance;
        MathError mErr;
        (mErr, borrowBalance) = borrowBalanceStoredInternal(cTokenCollateral, cTokenBorrow);
        if (mErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, FailureInfo.BORROW_BALANCE_CALCULATION_FAILED, uint(mErr));
        }
        if (borrowBalance < borrowSnapshot.principal) {
            return fail(Error.SANITY, FailureInfo.BORROW_BALANCE_TOO_SMALL);
        }

        uint borrowAmountAfter;
        (mErr, borrowAmountAfter) = subUInt(borrowBalance, repayBorrowAmount);
        if (mErr != MathError.NO_ERROR) {
            return failOpaque(Error.MATH_ERROR, FailureInfo.SUB_BORROW_BALANCE_AND_AMOUNT_FAILED, uint(mErr));
        }

        // TODO: make sure this writes to storage  
        borrowSnapshot.principal = borrowAmountAfter;
        borrowSnapshot.interestIndex = CToken(cTokenBorrow).borrowIndex();
        return uint(Error.NO_ERROR);
    }

    // called from Comptroller.borrowAllowed()
    function borrowAllowedBorrowedAgainst(address borrower, address cTokenBorrow, uint borrowAmountUsd)
    external
    // onlyComptroller
    returns (uint, bool)
    {
        if (msg.sender != address(comptroller)) {
            return (fail(Error.UNAUTHORIZED, FailureInfo.BORROW_ALLOWED_CALLER_CHECK), false);
        }

        address cTokenCollateral;
        uint err;
        (err, cTokenCollateral) = getCTokenCollateralInternal(borrower, cTokenBorrow);
        if (err != uint(Error.NO_ERROR)) {
            return (err, false);
        }

        if (maxAllowedBorrowedAgainst[cTokenCollateral] == 0) {
            return (uint(Error.NO_ERROR), true);
        }

        // get all cTokens
        CToken[] memory cTokenBorrows = comptroller.getAllMarkets();

        uint sumBorrowBalanceUsd;
        for (uint i = 0; i < cTokenBorrows.length; i++) {
            CToken cTokenBorrow = cTokenBorrows[i];

            // get the normalized price of the asset
            uint oraclePriceMantissa = oracle.getUnderlyingPrice(cTokenBorrow);
            if (oraclePriceMantissa == 0) {
                return (fail(Error.PRICE_ERROR, FailureInfo.PRICE_RETURNED_ZERO), false);
            }
            Exp memory oraclePrice = Exp({mantissa: oraclePriceMantissa});

            // note: we're using a borrowIndex from the past.. if we want absolute accuracy we need to accrue interest first in cTokenBorrow
            (MathError mErr, uint borrowBalance) = borrowBalanceStoredInternal(cTokenCollateral, address(cTokenBorrow));
            if (mErr != MathError.NO_ERROR) {
                return (failOpaque(Error.MATH_ERROR, FailureInfo.BORROW_BALANCE_CALCULATION_FAILED, uint(mErr)), false);
            }
            
            sumBorrowBalanceUsd = mul_ScalarTruncateAddUInt(oraclePrice, borrowBalance, sumBorrowBalanceUsd);
        }
        (MathError mErr, uint borrowBalanceTotalUsd) = addUInt(sumBorrowBalanceUsd, borrowAmountUsd);
        if (mErr != MathError.NO_ERROR) {
            return (failOpaque(Error.MATH_ERROR, FailureInfo.BORROW_BALANCE_CALCULATION_FAILED, uint(mErr)), false);
        }
 
        if (borrowBalanceTotalUsd > maxAllowedBorrowedAgainst[cTokenCollateral]) {
            return (uint(Error.NO_ERROR), false);
        }

        return (uint(Error.NO_ERROR), true);
    }

    function getCTokenCollateralInternal(address borrower, address cTokenBorrow) 
    internal 
    returns (uint, address)
    {
        CToken[] memory assets = comptroller.getAssetsIn(borrower);
        if (assets.length != 2) {
            return (fail(Error.CANT_GET_CTOKENCOLLATERAL, FailureInfo.BORROWER_ASSETS_NOT_TWO), address(0));
        }

        if (address(assets[0]) != cTokenBorrow) {
            if (address(assets[1]) == cTokenBorrow) {
                return (uint(Error.NO_ERROR), address(assets[0]));
            }
            // error: borrowerNotInCTokenBorrow
            return (fail(Error.CANT_GET_CTOKENCOLLATERAL, FailureInfo.BORROWER_NOT_IN_CTOKEN), address(0));
        }

        if (address(assets[1]) != cTokenBorrow) {
            return (uint(Error.NO_ERROR), address(assets[1]));
        }

        // note: cTokenCollateral == cTokenBorrow
        return (uint(Error.NO_ERROR), cTokenBorrow);
    }

    // /**
    //  * @dev passes only if invoked by a listed cToken.
    //  */
    // modifier onlyCToken() 
    // {
    //     // is this syntax ok? markets() returns a tuple 
    //     (bool isListed, ) = Comptroller.markets(msg.sender);
    //     require(isListed, "invoker must be listed as a mraket");
    //     _;
    // }

    // /**
    //  * @dev passes only if invoked by the Comptroller.
    //  */
    // modifier onlyComptroller() 
    // {
    //     require(msg.sender == address(Comptroller), "invoker must be the Comptroller");
    //     _;
    // }


    // from CToken.sol
    /**
     * @notice Return the total balance borrowed from cTokenBorrow whose collateral is cTokenCollateral 
     * @param cTokenCollateral cTokenCollateral
     * @param cTokenBorrow cTokenBorrow
     * @return (error code, the calculated balance or 0 if error code is non-zero)
     */
    function borrowBalanceStoredInternal(address cTokenCollateral, address cTokenBorrow) 
    internal
    view 
    returns (MathError, uint) 
    {
        /* Note: we do not assert that the market is up to date */
        MathError mathErr;
        uint principalTimesIndex;
        uint result;

        /* Get borrowBalance and borrowIndex */
        NewBorrowSnapshot storage borrowSnapshot = borrowedAgainstMap[cTokenCollateral][cTokenBorrow];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.principal == 0) {
            return (MathError.NO_ERROR, 0);
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */
        (mathErr, principalTimesIndex) = mulUInt(borrowSnapshot.principal, CToken(cTokenBorrow).borrowIndex());
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        (mathErr, result) = divUInt(principalTimesIndex, borrowSnapshot.interestIndex);
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        return (MathError.NO_ERROR, result);
    }


    /*** Admin Functions ***/


    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address newPendingAdmin) 
    public 
    returns (uint) 
    {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_ADMIN_OWNER_CHECK);
        }

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() 
    public 
    returns (uint) 
    {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
        }

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets a new price oracle for the Comptroller
      * @dev Admin function to set a new price oracle
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPriceOracle(PriceOracle newOracle) 
    public 
    returns (uint) 
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PRICE_ORACLE_OWNER_CHECK);
        }

        // Track the old oracle for the Comptroller
        PriceOracle oldOracle = oracle;

        // Set Comptroller's oracle to newOracle
        oracle = newOracle;

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(oldOracle, newOracle);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets a new price oracle for the Comptroller
      * @dev Admin function to set a new price oracle
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setMaxAllowedBorrowedAgainst(address cTokenCollateral, uint newUsdCap) 
    public 
    returns (uint) 
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_BORROWED_AGAINST_OWNER_CHECK);
        }

        // Track the old max for cTokenCollateral
        uint oldUsdCap = maxAllowedBorrowedAgainst[cTokenCollateral];

        // Set max for cTokenCollateral to newUsdCap
        maxAllowedBorrowedAgainst[cTokenCollateral] = newUsdCap;

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewMaxAllowedBorrowedAgainst(cTokenCollateral, oldUsdCap, newUsdCap);

        return uint(Error.NO_ERROR);
    }


}