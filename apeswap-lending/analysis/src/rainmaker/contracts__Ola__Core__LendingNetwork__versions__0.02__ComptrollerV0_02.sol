pragma solidity ^0.5.16;

import "../../OTokens/CToken.sol";
import "../../ErrorReporter/ErrorReporter.sol";
import "../../PriceOracle/PriceOracle.sol";
import "../../Comptroller/ComptrollerInterface.sol";
import "../../Comptroller/ComptrollerStorage.sol";
import "../../Comptroller/Unitroller.sol";
import "../../../../Peripheral/ComptrollerPeripherals/RainMaker/RainMakerInterface.sol";
import "../../../../Peripheral/ComptrollerPeripherals/Bouncer/IBouncer.sol";
import "../../../../Peripheral/ComptrollerPeripherals/IComptrollerPeripheral.sol";

interface RegistryForComptrollerV0_02 {
    function deployOToken(address underlying,
        bytes32 contractNameHash,
        bytes calldata params,
        address interestRateModel,
        address admin,
        bytes calldata becomeImplementationData) external returns (address);

    function deployPeripheralContract(bytes32 contractNameHash,
        bytes calldata params,
        address contractAdmin) external returns (address);

    function getPriceForUnderling(address cToken) external view returns (uint256);
}

interface IBouncerForComptroller {
    function isAccountApproved(address account) external view returns (bool);
}

/**
 * @title Ola's Comptroller Contract V0.02
 * @author Ola
 * -- Changes form V0.01 :
 * --- Setters&Events for new storage state.
 * --- Supports bouncer
 */
contract ComptrollerV0_02 is ComptrollerStorageOlaV0_02, ComptrollerInterface, ComptrollerErrorReporter, ExponentialNoError {
    /// @notice Emitted when an admin supports a market
    event MarketListed(CToken cToken);

    /// @notice Emitted when an account enters a market
    event MarketEntered(CToken cToken, address account);

    /// @notice Emitted when an account exits a market
    event MarketExited(CToken cToken, address account);

    /// @notice Emitted when a collateral factor is changed by admin
    event NewCollateralFactor(CToken cToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);

    /// @notice Emitted when a liquidation factor is changed by admin
    event NewLiquidationFactor(CToken cToken, uint oldLiquidationFactorMantissa, uint newLiquidationFactorMantissa);

    /// @notice Emitted when liquidation incentive is changed by admin
    /// OLA_ADDITIONS : Added 'cToken' to support 'liquidation incentive per market'
    event NewLiquidationIncentive(CToken ctoken, uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);

    // OLA_ADDITIONS : This event
    /// @notice Emitted when the Rain Maker is changed
    event NewRainMaker(address oldRainMaker, address newRainMaker);

    // OLA_ADDITIONS : This event
    /// @notice Emitted when the bouncer is changed
    event NewBouncer(address oldBouncer, address newBouncer);

    // OLA_ADDITIONS : This event
    /// @notice Emitted when the min borrow amount is changed
    event NewMinBorrowAmount(uint oldMinBorrowAmount, uint newMinBorrowAmount);

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    /// @notice Emitted when an action is paused globally
    event ActionPaused(string action, bool pauseState);

    /// @notice Emitted when an action is paused on a market
    event ActionPaused(CToken cToken, string action, bool pauseState);

    /// @notice Emitted when borrow cap for a cToken is changed
    event NewBorrowCap(CToken indexed cToken, uint newBorrowCap);

    /// @notice Emitted when borrow cap guardian is changed
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

    /// @notice Emitted when admin bank address is changed
    event NewAdminBankAddress(address oldAdminBankAddress, address newAdminBankAddress);

    /// @notice Emitted when active collateral cap for a cToken is changed
    event NewActiveCollateralCap(CToken indexed cToken, uint newActiveCollateralCap);

    /// @notice Emitted when active collateral usage for a cToken is changed
    event ActiveCollateralUsageChange(CToken indexed cToken, uint oldCollateralUsage, uint newCollateralUsage);

    // OLA_ADDITIONS : This event
    /// @notice Emitted when the 'Limit Minting' flag is changed
    event LimitMintingFlagChanged(bool newValue);

    // OLA_ADDITIONS : This event
    /// @notice Emitted when the 'Limit Borrowing' flag is changed
    event LimitBorrowingFlagChanged(bool newValue);

    // No collateralFactorMantissa may exceed this value
    uint internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9

    // No liquidationFactorMantissa may exceed this value
    uint internal constant liquidationFactorMaxMantissa = 0.9e18; // 0.9

    // liquidationIncentiveMantissa of any market must be strictly greater than this value
    // OLA_ADDITIONS: This field
    uint internal constant liquidationIncentiveMinMantissa = 1.05e18; // 1.05

    // liquidationIncentiveMantissa of any market must not exceed this value
    // OLA_ADDITIONS: This field
    uint internal constant liquidationIncentiveMaxMantissa = 1.3e18; // 1.3

    // Hard coded value to limit amount of asset in a single LN
    // OLA_ADDITIONS: This field
    uint internal constant maxAllowedAssets = 25;

    // Hard coded value for the liquidation close factor
    // OLA_ADDITIONS: This field
    uint internal constant fixedCloseFactorMantissa = 0.5e18;

    constructor() public {
        admin = msg.sender;
    }

    /*** Registry ***/

    function getRegistry() public view returns (address) {
        return address(registry);
    }

    /*** Assets You Are In ***/

    /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account) external view returns (CToken[] memory) {
        CToken[] memory assetsIn = accountAssets[account];

        return assetsIn;
    }

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param cToken The cToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, CToken cToken) external view returns (bool) {
        return markets[address(cToken)].accountMembership[account];
    }

    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param cTokens The list of addresses of the cToken markets to be enabled
     * @return Success indicator for whether each corresponding market was entered
     */
    function enterMarkets(address[] memory cTokens) public returns (uint[] memory) {
        uint len = cTokens.length;

        uint[] memory results = new uint[](len);
        for (uint i = 0; i < len; i++) {
            CToken cToken = CToken(cTokens[i]);

            // OLA_ADDITIONS : Emitting Failure events
            Error error = addToMarketInternal(cToken, msg.sender);
            if (error != Error.NO_ERROR) {
                fail(error, FailureInfo.ENTER_MARKET_NOT_ALLOWED);
            }

            results[i] = uint(error);
        }

        return results;
    }

    /**
     * @notice Checks if the account should be allowed to activate this additional amount of collateral.
     * @param cToken The cToken to verify the active collateral cap against
     * @param market The market to verify the active collateral cap against (assumes the given market is listed)
     * @param cTokensToActivate The amount of cTokens being activated as collateral
     * @return 0 if the activation is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function collateralActivationAllowed(CToken cToken, Market memory market, uint256 cTokensToActivate) internal view returns (uint) {
        uint256 activeCollateralUSDCap = market.activeCollateralUSDCap;
        uint256 activeCTokenUsage = market.activeCollateralCTokenUsage;

        // 0 Means "No Cap"
        if (activeCollateralUSDCap == 0) {
            return uint(Error.NO_ERROR);
        }

        // No amount ? no problem
        if (cTokensToActivate == 0) {
            return uint(Error.NO_ERROR);
        }

        // Calculate new usage USD value
        uint newCTokenUsage = add_(activeCTokenUsage, cTokensToActivate);

        uint exchangeRateMantissa = cToken.exchangeRateStored();

        Exp memory exchangeRate = Exp({mantissa: exchangeRateMantissa});

        // Get the normalized price of the asset
        uint oraclePriceMantissa = getUnderlyingPriceForCToken(address(cToken));

        if (oraclePriceMantissa == 0) {
            return uint(Error.PRICE_ERROR);
        }

        Exp memory oraclePrice = Exp({mantissa: oraclePriceMantissa});

        uint newUnderlyingUsage = mul_(newCTokenUsage, exchangeRate);
        uint newUsageValueInUsd = mul_(newUnderlyingUsage, oraclePrice);

        // Is it within the allowed cap ?
        if (newUsageValueInUsd <= activeCollateralUSDCap) {
            // All good here
            return uint(Error.NO_ERROR);
        } else {
            return uint(Error.TOO_MUCH_COLLATERAL_ACTIVATION);
        }
    }

    /**
     * @notice Increases the underlying actively used as collateral.
     */
    function increaseActiveCollateralUsed(Market storage market, uint256 cTokensActivated, CToken cToken) internal {
        uint oldCTokenUsage = market.activeCollateralCTokenUsage;
        uint newCTokenUsage = add_(oldCTokenUsage, cTokensActivated);
        market.activeCollateralCTokenUsage = newCTokenUsage;
        emit ActiveCollateralUsageChange(cToken, oldCTokenUsage, newCTokenUsage);
    }

    /**
     * @notice Reduces the underlying actively used as collateral.
    */
    function reduceActiveCollateralUsed(Market storage market, uint256 cTokensDeactivated, CToken cToken) internal {
        uint oldCTokenUsage = market.activeCollateralCTokenUsage;
        uint newCTokenUsage = sub_(oldCTokenUsage, cTokensDeactivated);
        market.activeCollateralCTokenUsage = newCTokenUsage;
        emit ActiveCollateralUsageChange(cToken, oldCTokenUsage, newCTokenUsage);
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param cToken The market to enter
     * @param borrower The address of the account to modify
     * @return Success indicator for whether the market was entered
     */
    function addToMarketInternal(CToken cToken, address borrower) internal returns (Error) {
        Market storage marketToJoin = markets[address(cToken)];

        if (!marketToJoin.isListed) {
            // market is not listed, cannot join
            return Error.MARKET_NOT_LISTED;
        }

        if (marketToJoin.accountMembership[borrower] == true) {
            // already joined
            return Error.NO_ERROR;
        }


        // NOTE : This function call will
        uint cTokensToBeActivatedAsCollateral = cToken.balanceOf(borrower);
        uint collateralActivationError = collateralActivationAllowed(cToken, marketToJoin, cTokensToBeActivatedAsCollateral);

        // OLA_ADDITIONS : This test
        if (collateralActivationError != uint(Error.NO_ERROR)) {
            return Error(collateralActivationError);
        }

        // Increase active collateral used
        increaseActiveCollateralUsed(marketToJoin, cTokensToBeActivatedAsCollateral, cToken);

        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(cToken);

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
    function exitMarket(address cTokenAddress) external returns (uint) {
        CToken cToken = CToken(cTokenAddress);
        /* Get sender tokensHeld and amountOwed underlying from the cToken */
        (uint oErr, uint tokensHeld, uint amountOwed, ) = cToken.getAccountSnapshot(msg.sender);
        require(oErr == 0, "Snapshot failed"); // semi-opaque error code

        /* Fail if the sender has a borrow balance */
        if (amountOwed != 0) {
            return fail(Error.NONZERO_BORROW_BALANCE, FailureInfo.EXIT_MARKET_BALANCE_OWED);
        }

        /* Fail if the sender is not permitted to redeem all of their tokens */
        uint allowed = redeemAllowedInternal(cTokenAddress, msg.sender, tokensHeld);
        if (allowed != 0) {
            return failOpaque(Error.REJECTION, FailureInfo.EXIT_MARKET_REJECTION, allowed);
        }

        Market storage marketToExit = markets[cTokenAddress];

        /* Return true if the sender is not already ‘in’ the market */
        if (marketToExit.accountMembership[msg.sender]) {
            uint err = exitMarketInternal(marketToExit, address(cToken), msg.sender);

            // If no err, reduce
            if (err != uint(Error.NO_ERROR)) {
                return err;
            }

            // Reduce the active collateral usage - Only if removal from market
            reduceActiveCollateralUsed(marketToExit, tokensHeld, cToken);
            return uint(Error.NO_ERROR);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account is done (no supply and no borrow at all) in the given market
     * and if so, exits the market for the user.
     * @dev .
     * @param cTokenAddress The address of the asset to be removed
     * @param account The account which would exit the market (if done with it)
     * @return If done - returns the result of 'exitMarketInternal' and if not done - "No error".
     */
    function exitMarketIfDone(address cTokenAddress, address account) internal returns (uint) {
        CToken cToken = CToken(cTokenAddress);
        (uint oErr, uint tokensHeld, uint amountOwed, ) = cToken.getAccountSnapshot(account);
        require(oErr == 0, "Snapshot failed"); // semi-opaque error code

        if (tokensHeld == 0 && amountOwed == 0) {
            Market storage marketToExit = markets[cTokenAddress];

            /* Return true if the sender is not already ‘in’ the market */
            if (marketToExit.accountMembership[account]) {
                return exitMarketInternal(marketToExit, cTokenAddress, account);
            } else {
                return uint(Error.NO_ERROR);
            }
        } else {
            return uint(Error.NO_ERROR);
        }
    }

    /**
      * @notice Performs the state change that Removes asset from sender's account liquidity calculation
      * @notice This function will revert if inconsistencies are found within the 'accountsAssets' mechanism
      * @dev This function should only be called after ensuring the user can exit the market (e.g no outstanding
      * debts or active collateral) AND only for users who are actually in the market.
      * @param cTokenAddress The address of the asset to be removed
      * @param account The account which would exit the market
      * @return Whether or not the account successfully exited the market
     */
    function exitMarketInternal(Market storage marketToExit, address cTokenAddress, address account) internal returns (uint) {
        /* Set cToken account membership to false */
        delete marketToExit.accountMembership[account];

        /* Delete cToken from the account’s list of assets */
        // load into memory for faster iteration
        CToken[] memory userAssetList = accountAssets[account];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == CToken(cTokenAddress)) {
                assetIndex = i;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        require(assetIndex < len);

        // copy last item in list to location of item to be removed, reduce length by 1
        CToken[] storage storedList = accountAssets[account];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.length--;

        emit MarketExited(CToken(cTokenAddress), account);

        return uint(Error.NO_ERROR);
    }

    /*** Policy Hooks ***/

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param cToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[cToken], "paused");

        // Shh - currently unused
        minter;
        mintAmount;

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // OLA_ADDITIONS : Can limit minting
        // If borrowing is limited the account has to be approved
        if (limitMinting && !isAccountApprovedInternal(minter)) {
            return uint (Error.NOT_APPROVED_TO_MINT);
        }

        // Keep the flywheel moving
        if (hasRainMaker()) {
            RainMakerInterface(rainMaker).updateCompSupplyIndex(cToken);
            RainMakerInterface(rainMaker).distributeSupplierComp(cToken, minter);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates mint and reverts on rejection. May emit logs.
     * @param cToken Asset being minted
     * @param minter The address minting the tokens
     * @param actualMintAmount The amount of the underlying asset being minted
     * @param mintTokens The number of tokens being minted
     */
    function mintVerify(address cToken, address minter, uint actualMintAmount, uint mintTokens) external {
        // OLA_ADDITIONS : All from here
        // only cTokens may call 'mintVerify'
        require(msg.sender == cToken, "!cToken");

        // Get market + safety
        Market storage marketToMintIn = markets[address(cToken)];
        require(marketToMintIn.isListed, "!listed");

        // We only care about active collateral caps if the minter is part of the market
        if (marketToMintIn.accountMembership[minter]) {
            // Is activating that much new collateral allowed ?
            uint collateralActivationError = collateralActivationAllowed(CToken(cToken), marketToMintIn, mintTokens);
            require(collateralActivationError == uint(Error.NO_ERROR), "activation not allowed");

            // All seems to be ok, increase the usage count
            increaseActiveCollateralUsed(marketToMintIn, mintTokens, CToken(cToken));
        }
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param cToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of cTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external returns (uint) {
        uint allowed = redeemAllowedInternal(cToken, redeemer, redeemTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        if (hasRainMaker()) {
            // Keep the flywheel moving
            RainMakerInterface(rainMaker).updateCompSupplyIndex(cToken);
            RainMakerInterface(rainMaker).distributeSupplierComp(cToken, redeemer);
        }

        return uint(Error.NO_ERROR);
    }

    function redeemAllowedInternal(address cToken, address redeemer, uint redeemTokens) internal view returns (uint) {
        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!markets[cToken].accountMembership[redeemer]) {
            return uint(Error.NO_ERROR);
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        // OLA_ADDITIONS : added 'true' to keep using the default 'collateralFactor'
        (Error err, , uint shortfall, ) = getHypotheticalAccountLiquidityInternal(redeemer, CToken(cToken), redeemTokens, 0, true);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param cToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) external {
        // Require tokens is zero or amount is also zero
        if (redeemTokens == 0 && redeemAmount > 0) {
            revert("redeemTokens zero");
        }

        // OLA_ADDITIONS : All from here
        // only cTokens may call 'redeemVerify'
        require(msg.sender == cToken, "!cToken");

        // Get market + safety
        Market storage marketToRedeemFrom = markets[address(cToken)];
        require(marketToRedeemFrom.isListed, "!listed");

        // We only care about active collateral caps if the minter is in the market
        if (marketToRedeemFrom.accountMembership[redeemer]) {
            // Some cleanups, if the user is done with this market
            require(exitMarketIfDone(cToken, redeemer) == uint(Error.NO_ERROR), "Exit failure");

            // The redeemer is reducing the collateral value in a market they are part of.
            // let's reduce the used active collateral.
            reduceActiveCollateralUsed(marketToRedeemFrom, redeemTokens, CToken(cToken));
        }
    }

    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param cToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!borrowGuardianPaused[cToken], "paused");


        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // OLA_ADDITIONS : Can limit borrow
        // If borrowing is limited the account has to be approved
        if (limitBorrowing && !isAccountApprovedInternal(borrower)) {
            return uint (Error.NOT_APPROVED_TO_BORROW);
        }

        if (!markets[cToken].accountMembership[borrower])
{
            // only cTokens may call borrowAllowed if borrower not in market
            require(msg.sender == cToken, "!cToken");

            // attempt to add borrower to the market
            Error err = addToMarketInternal(CToken(msg.sender), borrower);
            if (err != Error.NO_ERROR) {
                return uint(err);
            }

            // it should be impossible to break the important invariant
            assert(markets[cToken].accountMembership[borrower]);
        }

        if (getUnderlyingPriceForCToken(cToken) == 0) {
            return uint(Error.PRICE_ERROR);
        }

        uint borrowCap = borrowCaps[cToken];
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = CToken(cToken).totalBorrows();
            uint nextTotalBorrows = add_(totalBorrows, borrowAmount);
            require(nextTotalBorrows < borrowCap, "Borrow cap reached");
        }

        // OLA_ADDITIONS : added 'true' to keep using the default 'collateralFactor'
        (Error err, , uint shortfall, uint borrowAmountUsd) = getHypotheticalAccountLiquidityInternal(borrower, CToken(cToken), 0, borrowAmount, true);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        // OLA_ADDITIONS : Adds 'min borrow usd' requirement
        if (borrowAmountUsd < minBorrowAmountUsd) {
            return uint(Error.TOO_LITTLE_BORROW);
        }

        if (hasRainMaker()) {
            // Keep the flywheel moving
            uint borrowIndex = CToken(cToken).borrowIndex();
            RainMakerInterface(rainMaker).updateCompBorrowIndex(cToken, borrowIndex);
            RainMakerInterface(rainMaker).distributeBorrowerComp(cToken, borrower, borrowIndex);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates borrow and reverts on rejection. May emit logs.
     * @param cToken Asset whose underlying is being borrowed
     * @param borrower The address borrowing the underlying
     * @param borrowAmount The amount of the underlying asset requested to borrow
     */
    function borrowVerify(address cToken, address borrower, uint borrowAmount) external {
        // Shh - currently unused
        cToken;
        borrower;
        borrowAmount;

        // Uncomment if adding logic
        // Only cTokens may call 'borrowVerify'
        // require(msg.sender == cToken, "sender must be cToken");

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
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
        uint repayAmount) external returns (uint) {
        // Shh - currently unused
        payer;
        borrower;
        repayAmount;

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (hasRainMaker()) {
            // Keep the flywheel moving
            uint borrowIndex = CToken(cToken).borrowIndex();
            RainMakerInterface(rainMaker).updateCompBorrowIndex(cToken, borrowIndex);
            RainMakerInterface(rainMaker).distributeBorrowerComp(cToken, borrower, borrowIndex);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates repayBorrow and reverts on rejection. May emit logs.
     * @param cToken Asset being repaid
     * @param payer The address repaying the borrow
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function repayBorrowVerify(
        address cToken,
        address payer,
        address borrower,
        uint actualRepayAmount,
        uint borrowerIndex) external {

        // Only cTokens may call 'repayBorrowVerify'
        require(msg.sender == cToken, "!cToken");

        // Some cleanups, if the user is done with this market
        require(exitMarketIfDone(cToken, borrower) == uint(Error.NO_ERROR), "Exit failure");
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
        uint repayAmount) external returns (uint) {
        // Shh - currently unused
        liquidator;

        if (!markets[cTokenBorrowed].isListed || !markets[cTokenCollateral].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* The borrower must have shortfall in order to be liquidateable */
        // OLA_ADDITIONS : Use liquidation factor for liquidation calculation
        (Error err, , uint shortfall) = getAccountLiquidityInternal(borrower, false);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall == 0) {
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }

        /* The liquidator may not repay more than what is allowed by the closeFactor */
        uint borrowBalance = CToken(cTokenBorrowed).borrowBalanceStored(borrower);
        // OLA_ADDITIONS : Using the constant value instead of the storage one ('closeFactorMantissa')
        uint maxClose = mul_ScalarTruncate(Exp({mantissa: fixedCloseFactorMantissa}), borrowBalance);
        if (repayAmount > maxClose) {
            return uint(Error.TOO_MUCH_REPAY);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates liquidateBorrow and reverts on rejection. May emit logs.
     * @param cTokenBorrowed Asset which was borrowed by the borrower
     * @param cTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function liquidateBorrowVerify(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint actualRepayAmount,
        uint seizeTokens) external {
        // Shh - currently unused
        cTokenBorrowed;
        cTokenCollateral;
        liquidator;
        borrower;
        actualRepayAmount;
        seizeTokens;

        // Uncomment if adding logic
        // Only cTokens may call 'liquidateBorrowVerify'
        // require(msg.sender == cToken, "sender must be cToken");

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
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
        uint seizeTokens) external returns (uint) {
        // OLA_ADDITIONS : Preventing LN admin from stopping liquidations (By removing the setter for the flag)
        // Pausing is a very serious situation - we revert to sound the alarms
        // require(!seizeGuardianPaused, "seize is paused");

        // Shh - currently unused
        seizeTokens;

        if (!markets[cTokenCollateral].isListed || !markets[cTokenBorrowed].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (CToken(cTokenCollateral).comptroller() != CToken(cTokenBorrowed).comptroller()) {
            return uint(Error.COMPTROLLER_MISMATCH);
        }

        if (hasRainMaker()) {
            // Keep the flywheel moving
            RainMakerInterface(rainMaker).updateCompSupplyIndex(cTokenCollateral);
            RainMakerInterface(rainMaker).distributeSupplierComp(cTokenCollateral, borrower);
            RainMakerInterface(rainMaker).distributeSupplierComp(cTokenCollateral, liquidator);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates seize and reverts on rejection. May emit logs.
     * @param cTokenCollateral Asset which was used as collateral and will be seized
     * @param cTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeVerify(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external {
        // Shh - currently unused
        cTokenCollateral;
        cTokenBorrowed;
        liquidator;
        borrower;
        seizeTokens;

        // Uncomment if adding logic
        // Only cTokens may call 'seizeVerify'
        // require(msg.sender == cToken, "sender must be cToken");

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param cToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of cTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function transferAllowed(address cToken, address src, address dst, uint transferTokens) external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!transferGuardianPaused, "transfer paused");

        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        uint allowed = redeemAllowedInternal(cToken, src, transferTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        if (hasRainMaker()) {
            // Keep the flywheel moving
            RainMakerInterface(rainMaker).updateCompSupplyIndex(cToken);
            RainMakerInterface(rainMaker).distributeSupplierComp(cToken, src);
            RainMakerInterface(rainMaker).distributeSupplierComp(cToken, dst);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Validates transfer and reverts on rejection. May emit logs.
     * IMPORTANT : This function is also called from a cToken's 'seizeInternal', so, it is
     *             imperative to make sure that any change to this function is in line with
     *             the logic requirements of 'seizeInternal'.
     * @param cToken Asset being transferred
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of cTokens to transfer
     */
    function transferVerify(address cToken, address src, address dst, uint transferTokens) external {
        // OLA_ADDITIONS : All from here
        // only cTokens may call 'transferVerify'
        require(msg.sender == cToken, "!cToken");

        // Get market + safety
        Market storage marketToTransferIn = markets[address(cToken)];
        require(marketToTransferIn.isListed, "!listed");

        bool srcMembership = marketToTransferIn.accountMembership[src];
        bool dstMembership = marketToTransferIn.accountMembership[dst];

        // If no side is in the market, the active collateral is not changed.
        // If both of them are in the market, the active collateral stays the same.
        if (srcMembership == dstMembership) {
            return;
        } else if (srcMembership) {
            // This is an easy one, active collateral usage only decreases
            return reduceActiveCollateralUsed(marketToTransferIn, transferTokens, CToken(cToken));
        } else if (dstMembership) {
            // This is a complex one. The dst might not be able to receive the transferred cTokens if
            // it will exceed the allowed active collateral cap.
            // So, let's check whether activating that much new collateral is allowed.
            uint collateralActivationError = collateralActivationAllowed(CToken(cToken), marketToTransferIn, transferTokens);
            require(collateralActivationError == uint(Error.NO_ERROR), "Collateral activation is not allowed");

            // All seems to be ok, increase the usage count
            increaseActiveCollateralUsed(marketToTransferIn, transferTokens, CToken(cToken));
        }
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `cTokenBalance` is the number of cTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint cTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        // OLA_ADDITIONS : Renamed from 'collateralFactor' to 'collateralOrLiquidationFactor'
        Exp collateralOrLiquidationFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;

        // OLA_ADDITIONS : Added 'borrowAmountUsd' for "min borrow usd check"
        uint borrowAmountUsd;
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account) public view returns (uint, uint, uint) {
        // OLA_ADDITIONS : added 'true' to keep using the default 'collateralFactor'
        (Error err, uint liquidity, uint shortfall, ) = getHypotheticalAccountLiquidityInternal(account, CToken(0), 0, 0, true);

        return (uint(err), liquidity, shortfall);
    }

    /**
     * OLA ADDITIONS : This function
     * @notice Determine the current account liquidity wrt liquidation requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of liquidation requirements,
     *          account shortfall below liquidation requirements)
     */
    function getAccountLiquidityByLiquidationFactor(address account) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall, ) = getHypotheticalAccountLiquidityInternal(account, CToken(0), 0, 0, false);

        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code,
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidityInternal(address account, bool useCollateralFactor) internal view returns (Error, uint, uint) {
        // OLA_ADDITIONS : added 'useCollateralFactor' + changed from direct 'return' to 'de-construct and return'
        (Error err, uint liquidity, uint shortfall, ) = getHypotheticalAccountLiquidityInternal(account, CToken(0), 0, 0, useCollateralFactor);
        return (err, liquidity, shortfall);
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
        uint redeemTokens,
        uint borrowAmount) public view returns (uint, uint, uint) {
        // OLA_ADDITIONS : added 'true' to keep using the default 'collateralFactor'
        (Error err, uint liquidity, uint shortfall, ) = getHypotheticalAccountLiquidityInternal(account, CToken(cTokenModify), redeemTokens, borrowAmount, true);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * OLA_ADDITIONS : This function
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of liquidation requirements,
     *          hypothetical account shortfall below liquidation requirements)
     */
    function getHypotheticalAccountLiquidityByLiquidationFactor(
        address account,
        address cTokenModify,
        uint redeemTokens,
        uint borrowAmount) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall, ) = getHypotheticalAccountLiquidityInternal(account, CToken(cTokenModify), redeemTokens, borrowAmount, false);
        return (uint(err), liquidity, shortfall);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param cTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @param useCollateralFactor True - use the "default" 'collateralFactorMantissa', False - use 'liquidationFactorMantissa'
     * @dev Note that we calculate the exchangeRateStored for each collateral cToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements,
     *          USD value of the given borrowAmount)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        CToken cTokenModify,
        uint redeemTokens,
        uint borrowAmount,
        // OLA_ADDITIONS : added 'useCollateralFactor'
        bool useCollateralFactor) internal view returns (Error, uint, uint, uint) {

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint oErr;

        // For each asset the account is in
        CToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            CToken asset = assets[i];

            // Read the balances and exchange rate from the cToken
            (oErr, vars.cTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);
            if (oErr != 0) { // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
                return (Error.SNAPSHOT_ERROR, 0, 0, 0);
            }

            // OLA_ADDITIONS : Added the distinction between using collateralFactorMantissa and liquidationFactorMantissa
            if (useCollateralFactor) {
                vars.collateralOrLiquidationFactor = Exp({mantissa: markets[address(asset)].collateralFactorMantissa});
            } else {
                vars.collateralOrLiquidationFactor = Exp({mantissa: markets[address(asset)].liquidationFactorMantissa});
            }

            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = getUnderlyingPriceForCToken(address(asset));

            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            vars.tokensToDenom = mul_(mul_(vars.collateralOrLiquidationFactor, vars.exchangeRate), vars.oraclePrice);
            // sumCollateral += tokensToDenom * cTokenBalance
            vars.sumCollateral = mul_ScalarTruncateAddUInt(vars.tokensToDenom, vars.cTokenBalance, vars.sumCollateral);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);

            // Calculate effects of interacting with cTokenModify
            if (asset == cTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);

                // OLA_ADDITIONS : Assigning value to the newly added 'borrowAmountUsd'
                // This will only have a non-zero value when the calculation is made for a 'borrow' action.
                vars.borrowAmountUsd = mul_ScalarTruncate(vars.oraclePrice, borrowAmount);
            }
        }

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (Error.NO_ERROR, vars.sumCollateral - vars.sumBorrowPlusEffects, 0, vars.borrowAmountUsd);
        } else {
            return (Error.NO_ERROR, 0, vars.sumBorrowPlusEffects - vars.sumCollateral, vars.borrowAmountUsd);
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
    function liquidateCalculateSeizeTokens(address cTokenBorrowed, address cTokenCollateral, uint actualRepayAmount) external view returns (uint, uint) {
        /* Read oracle prices for borrowed and collateral markets */
        uint priceBorrowedMantissa = getUnderlyingPriceForCToken(cTokenBorrowed);
        uint priceCollateralMantissa = getUnderlyingPriceForCToken(cTokenCollateral);
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint(Error.PRICE_ERROR), 0);
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = CToken(cTokenCollateral).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;

        // OLA_ADDITIONS : Added a direct read for the market 'liquidationIncentiveMantissa'.
        // notice: will be 0 for unsupported 'cTokenCollateral'
        numerator = mul_(Exp({mantissa: markets[cTokenCollateral].liquidationIncentiveMantissa}), Exp({mantissa: priceBorrowedMantissa}));
        denominator = mul_(Exp({mantissa: priceCollateralMantissa}), Exp({mantissa: exchangeRateMantissa}));
        ratio = div_(numerator, denominator);

        seizeTokens = mul_ScalarTruncate(ratio, actualRepayAmount);

        return (uint(Error.NO_ERROR), seizeTokens);
    }

    /*** Admin Functions ***/

    /**
     * @notice Sets a new rain-maker for the Comptroller (
     *          Important : We assume that the 'RainMaker' handles the syncing of all of the markets
     *                      already supported by this contract.
     * @dev Admin function to set a new rain maker
     * @dev deployParams Dynamic parameters to be used for the contract deployment.
     * @dev retireParams Dynamic parameters to be used for the retire function of the existing rain maker.
     * @dev connectParams Dynamic parameters to be used for the connection of the new rain maker.
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setRainMaker(bytes32 contractNameHash, bytes calldata deployParams, bytes calldata retireParams, bytes calldata connectParams) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_RAIN_MAKER_OWNER_CHECK);
        }

        // Before saying goodbye, run all retirement logic (e.g. ensure all of the indexes are updated)
        if (hasRainMaker()) {
            IComptrollerPeripheral(rainMaker).retire(retireParams);
        }

        // Track the old rain maker for the Comptroller
        address oldRainMaker = rainMaker;

        address newRainMaker = address(0);

        if (contractNameHash != bytes32(0)) {
            // Ask the ministry to deploy a new RainMaker for us
            newRainMaker = RegistryForComptrollerV0_02(registry).deployPeripheralContract(contractNameHash, deployParams, admin);

            // Sanity, ensure a rainMaker was deployed
            require(RainMakerInterface(newRainMaker).isRainMaker());

            // Call initialization hook
            IComptrollerPeripheral(newRainMaker).connect(connectParams);
        }

        // Set Comptroller's RainMaker to newRainMaker
        rainMaker = newRainMaker;

        // Emit NewRainMaker(oldRainMaker, newRainMaker)
        emit NewRainMaker(oldRainMaker, newRainMaker);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Sets a new bouncer for the Comptroller (after asking the ministry to deploy one)
     * @dev deployParams Dynamic parameters to be used for the contract deployment.
     * @dev retireParams Dynamic parameters to be used for the retire function of the existing bouncer.
     * @dev connectParams Dynamic parameters to be used for the connection of the new bouncer.
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setBouncer(bytes32 contractNameHash, bytes calldata deployParams, bytes calldata retireParams, bytes calldata connectParams) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_BOUNCER_OWNER_CHECK);
        }

        // Track the bouncer for the Comptroller
        address oldBouncer = bouncer;
        address newBouncer = address(0);

        // Before saying goodbye, run all retirement logic
        if (hasBouncer()) {
            IComptrollerPeripheral(bouncer).retire(retireParams);
        }

        if (contractNameHash != bytes32(0)) {
            // Ask the ministry to deploy a new Bouncer for us
            newBouncer = RegistryForComptrollerV0_02(registry).deployPeripheralContract(contractNameHash, deployParams, admin);

            // Sanity, ensure a bouncer was deployed
            require(IBouncer(newBouncer).isBouncer());

            // Call initialization hook
            IComptrollerPeripheral(newBouncer).connect(connectParams);
        }

        // Set Comptroller's bouncer to newBouncer
        bouncer = newBouncer;

        emit NewBouncer(oldBouncer, bouncer);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Sets the 'limit supplying' flag to the given value (if they are different)
     * @dev Admin function to set value for 'limitSupplying'
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setLimitMinting(bool flagValue) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIMIT_MINTING_OWNER_CHECK);
        }

        if (limitMinting != flagValue) {
            limitMinting = flagValue;
            emit LimitMintingFlagChanged(flagValue);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Sets the 'limit borrowing' flag to the given value (if they are different)
     * @dev Admin function to set value for 'limitBorrowing'
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setLimitBorrowing(bool flagValue) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIMIT_BORROWING_OWNER_CHECK);
        }

        if (limitBorrowing != flagValue) {
            limitBorrowing = flagValue;
            emit LimitBorrowingFlagChanged(flagValue);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Sets the 'minBorrowAmountUsd' (scaled by 18)
     * @dev Admin function to set value for 'minBorrowAmountUsd'
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setMinBorrowAmountUsd(uint minBorrowAmountUsd_) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_MIN_BORROW_AMOUNT_USD_OWNER_CHECK);
        }

        uint oldMinBorrowAmount = minBorrowAmountUsd;
        minBorrowAmountUsd = minBorrowAmountUsd_;

        emit NewMinBorrowAmount(oldMinBorrowAmount, minBorrowAmountUsd);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets the collateralFactor for a market
      * @dev Admin function to set per-market collateralFactor
      * @param cToken The market to set the factor on
      * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setCollateralFactor(CToken cToken, uint newCollateralFactorMantissa) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_COLLATERAL_FACTOR_OWNER_CHECK);
        }

        // Verify market is listed
        Market storage market = markets[address(cToken)];
        if (!market.isListed) {
            return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS);
        }

        Exp memory newCollateralFactorExp = Exp({mantissa: newCollateralFactorMantissa});

        // Check collateral factor <= 0.9
        Exp memory highLimit = Exp({mantissa: collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION);
        }

        // Ensure liquidationFactor is greater or equal to the new collateralFactor
        uint marketLiquidationFactorMantissa = market.liquidationFactorMantissa;
        if (newCollateralFactorMantissa > marketLiquidationFactorMantissa) {
            return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_HIGHER_THAN_LIQUIDATION_FACTOR);
        }

        // If collateral factor != 0, fail if price == 0
        if (newCollateralFactorMantissa != 0 && getUnderlyingPriceForCToken(address(cToken)) == 0) {
            return fail(Error.PRICE_ERROR, FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE);
        }

        // Set market's collateral factor to new collateral factor, remember old value
        uint oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = newCollateralFactorMantissa;

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(cToken, oldCollateralFactorMantissa, newCollateralFactorMantissa);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets the liquidationFactor for a market.
      *         Important : In order to avoid the possibility of existing positions becoming liquidateable -
      *                     This value can only be increased.
      * @dev Admin function to set per-market liquidationFactor
      * @param cToken The market to set the factor on
      * @param newLiquidationFactorMantissa The new liquidation factor, scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setLiquidationFactor(CToken cToken, uint newLiquidationFactorMantissa) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIQUIDATION_FACTOR_OWNER_CHECK);
        }

        // Verify market is listed
        Market storage market = markets[address(cToken)];
        if (!market.isListed) {
            return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_LIQUIDATION_FACTOR_NO_EXISTS);
        }

        Exp memory newLiquidationFactorExp = Exp({mantissa: newLiquidationFactorMantissa});

        // Check liquidation factor <= 0.9
        Exp memory highLimit = Exp({mantissa: liquidationFactorMaxMantissa});
        if (lessThanExp(highLimit, newLiquidationFactorExp)) {
            return fail(Error.INVALID_LIQUIDATION_FACTOR, FailureInfo.SET_LIQUIDATION_FACTOR_VALIDATION);
        }

        // Ensure new liquidationFactor is greater or equal to the collateralFactor
        uint marketCollateralFactorMantissa = market.collateralFactorMantissa;
        if (newLiquidationFactorMantissa < marketCollateralFactorMantissa) {
            return fail(Error.INVALID_LIQUIDATION_FACTOR, FailureInfo.SET_LIQUIDATION_FACTOR_LOWER_THAN_COLLATERAL_FACTOR);
        }

        // Ensure new liquidation factor is strictly greater than the existing one
        uint oldLiquidationFactorMantissa = market.liquidationFactorMantissa;
        if (oldLiquidationFactorMantissa >= newLiquidationFactorMantissa) {
            return fail(Error.INVALID_LIQUIDATION_FACTOR, FailureInfo.SET_LIQUIDATION_FACTOR_LOWER_THAN_EXISTING_FACTOR);
        }

        // If liquidation factor != 0, fail if price == 0
        if (newLiquidationFactorMantissa != 0 && getUnderlyingPriceForCToken(address(cToken)) == 0) {
            return fail(Error.PRICE_ERROR, FailureInfo.SET_LIQUIDATION_FACTOR_WITHOUT_PRICE);
        }

        // Set market's liquidation factor to new liquidation factor, remember old value
        market.liquidationFactorMantissa = newLiquidationFactorMantissa;

        // Emit event with asset, old liquidation factor, and new liquidation factor
        emit NewCollateralFactor(cToken, oldLiquidationFactorMantissa, newLiquidationFactorMantissa);

        return uint(Error.NO_ERROR);
    }

    /**
      * OLA_ADDITIONS : Added 'cToken' to support 'incentive per market'
      * @notice Sets liquidationIncentive
      * @dev Admin function to set liquidationIncentive
      * @param cToken The market to set the factor on
      * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setLiquidationIncentive(CToken cToken, uint newLiquidationIncentiveMantissa) external returns (uint) {

        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK);
        }

        // Verify market is listed
        Market storage market = markets[address(cToken)];
        if (!market.isListed) {
            return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_LIQUIDATION_INCENTIVE_NO_EXISTS);
        }

        // OLA_ADDITIONS : All of the validations for 'newLiquidationIncentiveMantissa'
        Exp memory newLiquidationIncentiveExp = Exp({mantissa: newLiquidationIncentiveMantissa});

        // Check liquidation incentive <= 0.3 AND >= 0.05 [5,30]
        Exp memory highLimit = Exp({mantissa: liquidationIncentiveMaxMantissa});
        Exp memory lowLimit = Exp({mantissa: liquidationIncentiveMinMantissa});
        if (lessThanExp(highLimit, newLiquidationIncentiveExp) || lessThanExp(newLiquidationIncentiveExp, lowLimit)) {
            return fail(Error.INVALID_LIQUIDATION_INCENTIVE, FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION);
        }

        // If liquidation incentive != 0, fail if price == 0 (Extra safety check)
        if (newLiquidationIncentiveMantissa != 0 && getUnderlyingPriceForCToken(address(cToken)) == 0) {
            return fail(Error.PRICE_ERROR, FailureInfo.SET_LIQUIDATION_INCENTIVE_WITHOUT_PRICE);
        }

        // Save current value for use in log
        uint oldLiquidationIncentiveMantissa = market.liquidationIncentiveMantissa;

        // Set liquidation incentive to new incentive
        market.liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(cToken, oldLiquidationIncentiveMantissa, newLiquidationIncentiveMantissa);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Add the market to the markets mapping and set it as listed
     * @dev Admin function to deploy a new cTokens and then set isListed and add support for the market
     * @param underlying The address of the asset (token or native) to be used for the market
     * @return uint 0=success, otherwise a failure. (See enum Error for details)
     */
    function _supportNewMarket(address underlying,
        bytes32 contractNameHash,
        bytes calldata params,
        address interestRateModel,
        bytes calldata becomeImplementationData) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_NEW_MARKET_OWNER_CHECK);
        }

        // We allow one instance of the same underlying-contractName combination
        if (existingMarketTypes[underlying][contractNameHash] != address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_NEW_MARKET_COMBINATION_CHECK);
        }

        // IMPORTANT : No graceful failure after contract deployment !
        address deployedCToken = RegistryForComptrollerV0_02(registry).deployOToken(underlying, contractNameHash, params, interestRateModel, admin, becomeImplementationData);

        CToken(deployedCToken).isCToken(); // Sanity check to make sure its really a CToken

        // OLA_ADDITIONS : Changed to require
        // Legacy safety
        require(!markets[deployedCToken].isListed, "SUPPORT_MARKET_EXISTS");

        // Save asset - contract combination
        existingMarketTypes[underlying][contractNameHash] = deployedCToken;

        // OLA_ADDITIONS : Added 'liquidationFactorMantissa', 'liquidationIncentiveMantissa'
        markets[deployedCToken] = Market({isListed: true, collateralFactorMantissa: 0,
        liquidationFactorMantissa: 0, liquidationIncentiveMantissa: 0,
        activeCollateralUSDCap: 0, activeCollateralCTokenUsage: 0
        });

        _addMarketInternal(deployedCToken);

        emit MarketListed(CToken(deployedCToken));

        return uint(Error.NO_ERROR);
    }

    function _addMarketInternal(address cToken) internal {
        // OLA_ADDITIONS : Added this 'max assets' limitation
        require(allMarkets.length <= maxAllowedAssets, "Too many assets");

        for (uint i = 0; i < allMarkets.length; i ++) {
            require(allMarkets[i] != CToken(cToken), "Already added");
        }
        allMarkets.push(CToken(cToken));

        // OLA_ADDITIONS : Initializing the market at the RainMaker as well
        if (hasRainMaker()) {
            RainMakerInterface(rainMaker)._supportMarket(cToken);
        }
    }

    /**
      * OLA_ADDITIONS : This function
      * @notice Set the given active collateral caps (in USD) for the given cToken markets. Any action that brings total active collateral to or above borrow cap will revert.
      * @dev Admin function to set the active collateral caps. A active-collateral cap of 0 corresponds to unlimited active collateral.
      * @param cTokens The addresses of the markets (tokens) to change the active-collateral caps for
      * @param newActiveCollateralCaps The new active-collateral cap values in usd to be set. A value of 0 corresponds to unlimited borrowing.
      */
    function _setActiveCollateralCaps(CToken[] calldata cTokens, uint[] calldata newActiveCollateralCaps) external {
        require(msg.sender == admin, "!Admin");

        uint numMarkets = cTokens.length;
        uint numActiveCollateralCaps = newActiveCollateralCaps.length;

        require(numMarkets != 0 && numMarkets == numActiveCollateralCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            Market storage marketToJoin = markets[address(cTokens[i])];

            require(marketToJoin.isListed,"!listed");

            marketToJoin.activeCollateralUSDCap = newActiveCollateralCaps[i];

            emit NewActiveCollateralCap(cTokens[i], newActiveCollateralCaps[i]);
        }
    }

    /**
     * @notice Admin function to change the admin bank address
     * @param newAdminBankAddress The new admin bank address
     */
    function _setAdminBankAddress(address payable newAdminBankAddress) external {
        require(msg.sender == admin, "!admin");

        // Save current value for inclusion in log
        address oldAdminBankAddress = adminBankAddress;

        // Store adminBankAddress with value newAdminBankAddress
        adminBankAddress = newAdminBankAddress;

        // Emit NewAdminBankAddress(newAdminBankAddress, newAdminBankAddress)
        emit NewAdminBankAddress(oldAdminBankAddress, newAdminBankAddress);
    }

    /**
      * @notice Set the given borrow caps for the given cToken markets. Borrowing that brings total borrows to or above borrow cap will revert.
      * @dev Admin or borrowCapGuardian function to set the borrow caps. A borrow cap of 0 corresponds to unlimited borrowing.
      * @param cTokens The addresses of the markets (tokens) to change the borrow caps for
      * @param newBorrowCaps The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.
      */
    function _setMarketBorrowCaps(CToken[] calldata cTokens, uint[] calldata newBorrowCaps) external {
    	require(msg.sender == admin || msg.sender == borrowCapGuardian, "!admin||borrow cap guardian");

        uint numMarkets = cTokens.length;
        uint numBorrowCaps = newBorrowCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            borrowCaps[address(cTokens[i])] = newBorrowCaps[i];
            emit NewBorrowCap(cTokens[i], newBorrowCaps[i]);
        }
    }

    /**
     * @notice Admin function to change the Borrow Cap Guardian
     * @param newBorrowCapGuardian The address of the new Borrow Cap Guardian
     */
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external {
        require(msg.sender == admin, "!admin");

        // Save current value for inclusion in log
        address oldBorrowCapGuardian = borrowCapGuardian;

        // Store borrowCapGuardian with value newBorrowCapGuardian
        borrowCapGuardian = newBorrowCapGuardian;

        // Emit NewBorrowCapGuardian(OldBorrowCapGuardian, NewBorrowCapGuardian)
        emit NewBorrowCapGuardian(oldBorrowCapGuardian, newBorrowCapGuardian);
    }

    /**
     * @notice Admin function to change the Pause Guardian
     * @param newPauseGuardian The address of the new Pause Guardian
     * @return uint 0=success, otherwise a failure. (See enum Error for details)
     */
    function _setPauseGuardian(address newPauseGuardian) public returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PAUSE_GUARDIAN_OWNER_CHECK);
        }

        // Save current value for inclusion in log
        address oldPauseGuardian = pauseGuardian;

        // Store pauseGuardian with value newPauseGuardian
        pauseGuardian = newPauseGuardian;

        // Emit NewPauseGuardian(OldPauseGuardian, NewPauseGuardian)
        emit NewPauseGuardian(oldPauseGuardian, pauseGuardian);

        return uint(Error.NO_ERROR);
    }

    function _setMintPaused(CToken cToken, bool state) public returns (bool) {
        require(markets[address(cToken)].isListed, "!listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "!pause guardian||admin");
        require(msg.sender == admin || state == true, "!admin");

        mintGuardianPaused[address(cToken)] = state;
        emit ActionPaused(cToken, "Mint", state);
        return state;
    }

    function _setBorrowPaused(CToken cToken, bool state) public returns (bool) {
        require(markets[address(cToken)].isListed, "!listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "!pause guardian||admin");
        require(msg.sender == admin || state == true, "!admin");

        borrowGuardianPaused[address(cToken)] = state;
        emit ActionPaused(cToken, "Borrow", state);
        return state;
    }

    function _setTransferPaused(bool state) public returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "!pause guardian||admin");
        require(msg.sender == admin || state == true, "!admin");

        transferGuardianPaused = state;
        emit ActionPaused("Transfer", state);
        return state;
    }

    /**
     * @notice Checks caller is admin
     */
    function isAdmin() internal view returns (bool) {
        return msg.sender == admin;
    }

    /**
     * OLA_ADDITIONS : This function
     * @notice Ensures all markets are updating their implementation from the Registry
     */
    function updateDelegatedImplementations(bytes calldata becomeImplementationData) external {
        require(isAdmin(), "!admin");

        // Update all markets
        for (uint i = 0; i < allMarkets.length; i ++) {
            CToken oToken = allMarkets[i];
            require(CTokenDelegatorInterface(address(oToken)).updateImplementationFromRegistry(false, becomeImplementationData), "Update failed");
        }
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() public view returns (CToken[] memory) {
        return allMarkets;
    }


    /**
     * Fetches the underlying price from the ministry.
     * 0 means an error.
     */
    function getUnderlyingPriceForCToken(address cToken) internal view returns (uint256) {
        return RegistryForComptrollerV0_02(registry).getPriceForUnderling(cToken);
    }

    function hasRainMaker() view public returns (bool) {
        return address(rainMaker) != address(0);
    }

    function hasBouncer() view public returns (bool) {
        return address(bouncer) != address(0);
    }

    function isAccountApproved(address account) view external returns (bool) {
        return isAccountApprovedInternal(account);
    }

    /**
     * @notice This function assumes that any account not actively approved is denied
     *         and so, if no bouncer is set, the response is always false.
     */
    function isAccountApprovedInternal(address account) view internal returns (bool) {
        if (hasBouncer()) {
            return IBouncerForComptroller(bouncer).isAccountApproved(account);
        } else {
            return false;
        }
    }
}
