pragma solidity ^0.5.16;

import "./RainMakerStorage.sol";
import "./RainMakerInterface.sol";
import "../../../Core/Math/ExponentialNoError.sol";
import "../IComptrollerPeripheral.sol";
import "../../../Core/LendingNetwork/OTokens/CToken.sol";

interface IMinistryForSingleAssetDynamicRainMaker {
    function isAssetSupported(address asset) external view returns (bool);
}

contract SingleAssetDynamicRainMaker is SingleAssetDynamicRainMakerStorage, SingleAssetRainMakerInterface, ExponentialNoError, IComptrollerPeripheral {
    bytes32 constant public SingleAssetDynamicRainMakerContractHash = keccak256("SingleAssetDynamicRainMaker");

    /// @notice The initial COMP index for a market
    uint224 public constant compInitialIndex = 1e36;

    /// @notice Emitted when an admin supports a market
    event MarketListed(CToken cToken);

    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Emitted when lnIncentiveTokenAddress is set by admin
    event LnIncentiveTokenUpdated(address lnIncentiveToken, uint blockNumber);

    /// @notice Emitted when a new COMP supply speed is calculated for a market
    event CompSupplySpeedUpdated(CToken indexed cToken, uint newSpeed);

    /// @notice Emitted when a new COMP borrow speed is calculated for a market
    event CompBorrowSpeedUpdated(CToken indexed cToken, uint newSpeed);

    /// @notice Emitted when COMP is distributed to a supplier
    event DistributedSupplierComp(CToken indexed cToken, address indexed supplier, uint compDelta, uint compSupplyIndex);

    /// @notice Emitted when COMP is distributed to a borrower
    event DistributedBorrowerComp(CToken indexed cToken, address indexed borrower, uint compDelta, uint compBorrowIndex);

    // V1.0
    uint public constant version = 100;

    /*** Constructor ***/
    constructor(address _comptroller, address _admin) public {
        admin = _admin;
        comptroller = ComptrollerInterface(_comptroller);
        contractNameHash = SingleAssetDynamicRainMakerContractHash;

        // Ensure supported markets are synced with the Comptroller
        CToken[] memory markets = comptroller.getAllMarkets();
        uint marketsCount = markets.length;
        for (uint i = 0; i < marketsCount; i++) {
            CToken market = markets[i];
            _supportMarketInternal(address(market));
        }
    }

    /**
     * @notice Return the address of the COMP token
     * @return The address of COMP
     */
    function getLnIncentiveTokenAddress() public view returns (address) {
        return lnIncentiveTokenAddress;
    }

    /*** Comp claiming ***/

    /**
     * @notice Claim all the comp accrued by holder in all markets
     * @param holder The address to claim COMP for
     */
    function claimComp(address holder) public {
        return claimComp(holder, allMarkets);
    }

    /**
     * @notice Claim all the comp accrued by holder in the specified markets
     * @param holder The address to claim COMP for
     * @param cTokens The list of markets to claim COMP in
     */
    function claimComp(address holder, CToken[] memory cTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimComp(holders, cTokens, true, true);
    }

    /**
     * @notice Claim all comp accrued by the holders
     * @param holders The addresses to claim COMP for
     * @param cTokens The list of markets to claim COMP in
     * @param borrowers Whether or not to claim COMP earned by borrowing
     * @param suppliers Whether or not to claim COMP earned by supplying
     */
    function claimComp(address[] memory holders, CToken[] memory cTokens, bool borrowers, bool suppliers) public {
        for (uint i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            require(isListed[address(cToken)], "market must be listed");
            if (borrowers == true) {
                Exp memory borrowIndex = Exp({mantissa: cToken.borrowIndex()});
                updateCompBorrowIndexInternal(address(cToken), borrowIndex);
                for (uint j = 0; j < holders.length; j++) {
                    distributeBorrowerCompInternal(address(cToken), holders[j], borrowIndex);
                }
            }
            if (suppliers == true) {
                updateCompSupplyIndexInternal(address(cToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierCompInternal(address(cToken), holders[j]);
                }
            }
        }

        for (uint j = 0; j < holders.length; j++) {
            compAccrued[holders[j]] = grantCompInternal(holders[j], compAccrued[holders[j]]);
        }
    }

    /*** Comp Distribution ***/
    function updateCompSupplyIndex(address cToken) external {
        require(isComptroller(), "Not comptroller");
        updateCompSupplyIndexInternal(cToken);
    }

    function updateCompBorrowIndex(address cToken, uint marketBorrowIndex_) external {
        require(isComptroller(), "Not comptroller");
        Exp memory marketBorrowIndex = Exp({mantissa: marketBorrowIndex_});
        updateCompBorrowIndexInternal(cToken, marketBorrowIndex);
    }

    function distributeSupplierComp(address cToken, address supplier) external {
        require(isComptroller(), "Not comptroller");
        distributeSupplierCompInternal(cToken, supplier);
    }

    function distributeBorrowerComp(address cToken, address borrower, uint marketBorrowIndex_) external {
        require(isComptroller(), "Not comptroller");
        Exp memory marketBorrowIndex = Exp({mantissa: marketBorrowIndex_});
        distributeBorrowerCompInternal(cToken, borrower, marketBorrowIndex);
    }

    /*** Comp Distribution internal ***/

    /**
     * @notice Accrue COMP to the market by updating the supply index
     * @param cToken The market whose supply index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateCompSupplyIndexInternal(address cToken) internal {
        if (isRetired) {
            return;
        }

        CompMarketState storage supplyState = compSupplyState[cToken];
        uint supplySpeed = compSupplySpeeds[cToken];
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");
        uint deltaBlocks = sub_(uint(blockNumber), uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = CToken(cToken).totalSupply();
            uint supplyCompAccrued = mul_(deltaBlocks, supplySpeed);
            uint baseUnit = baseUnits[cToken];
            Double memory ratio = supplyTokens > baseUnit ? fraction(supplyCompAccrued, supplyTokens) : Double({mantissa: 0});
            supplyState.index = safe224(add_(Double({mantissa: supplyState.index}), ratio).mantissa, "new index exceeds 224 bits");
            supplyState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            supplyState.block = blockNumber;
        }
    }

    /**
     * @notice Accrue COMP to the market by updating the borrow index
     * @param cToken The market whose borrow index to update
     * @dev Index is a cumulative sum of the COMP per cToken accrued.
     */
    function updateCompBorrowIndexInternal(address cToken, Exp memory marketBorrowIndex) internal {
        if (isRetired) {
            return;
        }

        CompMarketState storage borrowState = compBorrowState[cToken];
        uint borrowSpeed = compBorrowSpeeds[cToken];
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");
        uint deltaBlocks = sub_(uint(blockNumber), uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(CToken(cToken).totalBorrows(), marketBorrowIndex);
            uint borrowCompAccrued = mul_(deltaBlocks, borrowSpeed);
            uint baseUnit = baseUnits[cToken];
            Double memory ratio = borrowAmount > baseUnit ? fraction(borrowCompAccrued, borrowAmount) : Double({mantissa: 0});
            borrowState.index = safe224(add_(Double({mantissa: borrowState.index}), ratio).mantissa, "new index exceeds 224 bits");
            borrowState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            borrowState.block = blockNumber;
        }
    }

    /**
     * @notice Calculate COMP accrued by a supplier and possibly transfer it to them
     * @param cToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute COMP to
     */
    function distributeSupplierCompInternal(address cToken, address supplier) internal {
        CompMarketState storage supplyState = compSupplyState[cToken];
        uint supplyIndex = supplyState.index;
        uint supplierIndex = compSupplierIndex[cToken][supplier];

        // Update supplier's index to the current index since we are distributing accrued COMP
        compSupplierIndex[cToken][supplier] = supplyIndex;

        if (supplierIndex == 0 && supplyIndex >= compInitialIndex) {
            // Covers the case where users supplied tokens before the market's supply state index was set.
            // Rewards the user with COMP accrued from the start of when supplier rewards were first
            // set for the market.
            supplierIndex = isRetired ? supplyIndex : compInitialIndex;
        }

        // Calculate change in the cumulative sum of the COMP per cToken accrued
        Double memory deltaIndex = Double({mantissa: sub_(supplyIndex, supplierIndex)});

        uint supplierTokens = CToken(cToken).balanceOf(supplier);

        // Calculate COMP accrued: cTokenAmount * accruedPerCToken
        uint supplierDelta = mul_(supplierTokens, deltaIndex);

        uint supplierAccrued = add_(compAccrued[supplier], supplierDelta);
        compAccrued[supplier] = supplierAccrued;

        emit DistributedSupplierComp(CToken(cToken), supplier, supplierDelta, supplyIndex);
    }

    /**
     * @notice Calculate COMP accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param cToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute COMP to
     */
    function distributeBorrowerCompInternal(address cToken, address borrower, Exp memory marketBorrowIndex) internal {

        CompMarketState storage borrowState = compBorrowState[cToken];
        uint borrowIndex = borrowState.index;
        uint borrowerIndex = compBorrowerIndex[cToken][borrower];

        // Update borrowers's index to the current index since we are distributing accrued COMP
        compBorrowerIndex[cToken][borrower] = borrowIndex;

        if (borrowerIndex == 0 && borrowIndex >= compInitialIndex) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with COMP accrued from the start of when borrower rewards were first
            // set for the market.

            borrowerIndex = isRetired ? borrowIndex : compInitialIndex;
        }

        // Calculate change in the cumulative sum of the COMP per borrowed unit accrued
        Double memory deltaIndex = Double({mantissa: sub_(borrowIndex, borrowerIndex)});

        uint borrowerAmount = div_(CToken(cToken).borrowBalanceStored(borrower), marketBorrowIndex);

        // Calculate COMP accrued: cTokenAmount * accruedPerBorrowedUnit
        uint borrowerDelta = mul_(borrowerAmount, deltaIndex);

        uint borrowerAccrued = add_(compAccrued[borrower], borrowerDelta);
        compAccrued[borrower] = borrowerAccrued;

        emit DistributedBorrowerComp(CToken(cToken), borrower, borrowerDelta, borrowIndex);
    }

    /**
     * OLA_ADDITIONS : Changes from 'Comp' to the generic ERC20.
     * @notice Transfer COMP to the user
     * @dev Note: If there is not enough COMP, we do not perform the transfer all.
     * @param user The address of the user to transfer COMP to
     * @param amount The amount of COMP to (possibly) transfer
     * @return The amount of COMP which was NOT transferred to the user
     */
    function grantCompInternal(address user, uint amount) internal returns (uint) {
        EIP20Interface lnToken = EIP20Interface(getLnIncentiveTokenAddress());
        uint lnTokenRemaining = lnToken.balanceOf(address(this));
        if (amount > 0 && amount <= lnTokenRemaining) {
            lnToken.transfer(user, amount);
            return 0;
        }
        return amount;
    }

    /**
     * @notice Set COMP supply speed for a single market
     * @param cToken The market whose COMP speed to update
     * @param compSupplySpeed New COMP supply speed for market
     */
    function setCompSupplySpeedInternal(CToken cToken, uint compSupplySpeed) internal {
        uint currentCompSupplySpeed = compSupplySpeeds[address(cToken)];

        if (currentCompSupplySpeed != compSupplySpeed) {
            // Supply speed updated so let's update supply state to ensure that
            //  1. COMP accrued properly for the old speed, and
            //  2. COMP accrued at the new speed starts after this block.
            // note that COMP speed could be set to 0 to halt liquidity rewards for a market
            updateCompSupplyIndexInternal(address(cToken));

            compSupplySpeeds[address(cToken)] = compSupplySpeed;
            emit CompSupplySpeedUpdated(cToken, compSupplySpeed);
        }
    }

    /**
     * @notice Set COMP speed for a single market
     * @param cToken The market whose COMP speed to update

     * @param compBorrowSpeed New COMP borrow speed for market
     */
    function setCompBorrowSpeedInternal(CToken cToken, uint compBorrowSpeed) internal {
        uint currentCompBorrowSpeed = compBorrowSpeeds[address(cToken)];

        if (currentCompBorrowSpeed != compBorrowSpeed) {
            // Borrow speed updated so let's update borrow state to ensure that
            //  1. COMP accrued properly for the old speed, and
            //  2. COMP accrued at the new speed starts after this block.
            // note that COMP speed could be set to 0 to halt liquidity rewards for a market
            Exp memory borrowIndex = Exp({mantissa: cToken.borrowIndex()});
            updateCompBorrowIndexInternal(address(cToken), borrowIndex);

            compBorrowSpeeds[address(cToken)] = compBorrowSpeed;
            emit CompBorrowSpeedUpdated(cToken, compBorrowSpeed);
        }
    }

    /*** Comp Distribution Admin ***/

    /**
     * @notice Set COMP speeds for a multiple markets
     * @param _cTokens The markets whose COMP speeds to update
     * @param _compSupplySpeeds New COMP speed per market
     * @param _compBorrowSpeeds New COMP speed per market
     */
    function _setDynamicCompSpeeds(CToken[] calldata _cTokens, uint[] calldata _compSupplySpeeds, uint[] calldata _compBorrowSpeeds) external {
        require(_cTokens.length == _compSupplySpeeds.length, "markets and supply speeds should be 1:1");
        require(_cTokens.length == _compBorrowSpeeds.length, "markets and borrow speeds should be 1:1");
        require(isAdmin(), "only admin can set comp speed");

        for (uint i = 0; i < _cTokens.length; i++) {
            CToken cToken = _cTokens[i];
            require(isListed[address(cToken)], "market not listed");
            setCompSupplySpeedInternal(cToken, _compSupplySpeeds[i]);
            setCompBorrowSpeedInternal(cToken, _compBorrowSpeeds[i]);
        }
    }

    /**
     * @notice Set COMP speed for a single market
     * @param cToken The market whose COMP speed to update
     * @param compSupplySpeed New COMP supply speed for market
     * @param compBorrowSpeed New COMP borrow speed for market
     */
    function _setDynamicCompSpeed(CToken cToken, uint compSupplySpeed, uint compBorrowSpeed) public {
        require(isAdmin(), "only admin can set comp speed");
        require(isListed[address(cToken)], "market not listed");
        setCompSupplySpeedInternal(cToken, compSupplySpeed);
        setCompBorrowSpeedInternal(cToken, compBorrowSpeed);
    }

    /*** Comptroller Functions ***/
    function _supportMarket(address cToken) external  {
        require(isComptroller(), "Not comptroller");
        require(!isListed[cToken], "Already listed");

        _supportMarketInternal(address(cToken));
    }

    function _supportMarketInternal(address cToken) internal {
        CToken(cToken).isCToken(); // Sanity check to make sure its really a CToken

        allMarkets.push(CToken(cToken));
        isListed[cToken] = true;

        _initializeMarket(cToken);

        emit MarketListed(CToken(cToken));
    }

    /**
     * Should only be called once for market
     */
    function _initializeMarket(address cToken) internal {
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");

        address underlying = CToken(cToken).underlying();
        bool isForNativeCoin = underlying == CToken(cToken).nativeCoinUnderlying();

        // Set the base unit
        uint8 decimals = isForNativeCoin ? 18 : EIP20Interface(underlying).decimals();
        uint baseUnit = 10 ** decimals;
        baseUnits[cToken] = baseUnit;

        CompMarketState storage supplyState = compSupplyState[cToken];
        CompMarketState storage borrowState = compBorrowState[cToken];

        /*
         * Update market state indices
         */
        if (supplyState.index == 0) {
            // Initialize supply state index with default value
            supplyState.index = compInitialIndex;
            // Update market state block numbers
            supplyState.block = blockNumber;
        }

        if (borrowState.index == 0) {
            // Initialize borrow state index with default value
            borrowState.index = compInitialIndex;
            borrowState.block = blockNumber;
        }
    }

    /*** Admin Functions ***/


    /**
     * @notice Periphery hook. Does nothing at the moment.
     */
    function connect(bytes calldata params) external {
        // Shh -- currently unused
        params;
    }

    /**
     * @notice Periphery hook. Syncs for the last time for all supported markets and prevents this RainMaker from updating any more.
     */
    function retire(bytes calldata params) external {
        // Shh -- currently unused
        params;

        retireInternal();
    }

    /**
     * Legacy function
     */
    function retireRainMaker() external {
        retireInternal();
    }

    function retireInternal() internal {
        require(isComptroller(), "Not comptroller");

        for (uint i = 0; i < allMarkets.length; i ++) {
            CToken cToken = allMarkets[i];

            // Extra sanity
            if (isListed[address(cToken)]) {
                // Update supply incentive  index
                updateCompSupplyIndexInternal(address(cToken));

                // Update borrow incentive index
                uint borrowIndex = cToken.borrowIndex();
                Exp memory marketBorrowIndex = Exp({mantissa: borrowIndex});
                updateCompBorrowIndexInternal(address(cToken), marketBorrowIndex);
            }
        }

        // This basically locks the supply and borrow indexes to their current values
        // and by thus, stops the accumulating.
        isRetired = true;
    }

    /**
     * @notice A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (Timelock)
     * @param token The address of the ERC-20 token to sweep
     */
    function sweepToken(EIP20NonStandardInterface token) external {
        // Check caller = admin
        require(msg.sender == admin, "Not Admin");

        EIP20NonStandardInterface rainToken = EIP20NonStandardInterface(lnIncentiveTokenAddress);

        uint256 balance = EIP20NonStandardInterface(lnIncentiveTokenAddress).balanceOf(address(this));
        rainToken.transfer(admin, balance);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        // Check caller = admin
        require(msg.sender == admin, "Not Admin");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return 0;
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0), "Not the EXISTING pending admin");

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return 0;
    }

    /**
     * @notice Set lnTokenAddress.
     * @param incentiveTokenAddress The ERC20 compatible token to be used for incentivizing the system.
     */
    function _setLnIncentiveToken(address incentiveTokenAddress) public {
        require(isAdmin(), "only admin can set comp speed");
        require(incentiveTokenAddress != address(0), "LN incentive token must have a proper address");
        require(getLnIncentiveTokenAddress() == address(0), "Cannot change the LN incentive token once it is set");

        require(IMinistryForSingleAssetDynamicRainMaker(comptroller.getRegistry()).isAssetSupported(incentiveTokenAddress), "Token not supported");

        lnIncentiveTokenAddress = incentiveTokenAddress;
        emit LnIncentiveTokenUpdated(lnIncentiveTokenAddress, block.number);
    }

    /**
     * @notice Checks caller is Comptroller
     */
    function isComptroller() internal view returns (bool) {
        return msg.sender == address(comptroller);
    }

    /**
     * @notice Checks caller is admin
     */
    function isAdmin() internal view returns (bool) {
        return msg.sender == admin;
    }

    /*** Compound Lens Compatibility ***/

    /**
     * Keeping this to be somewhat compatible with the uniform rainmaker
     */
    function compSpeeds(address market) public view returns (uint) {
        return compSupplySpeeds[market];
    }

    /*** Utils ***/

    function getBlockNumber() public view returns (uint)
    {
        return block.number;
    }
}