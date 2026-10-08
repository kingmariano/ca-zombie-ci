pragma solidity ^0.5.16;

import "./RainMakerStorage.sol";
import "./RainMakerInterface.sol";
import "../../../Core/Math/ExponentialNoError.sol";
import "../IComptrollerPeripheral.sol";
import "../../../Core/LendingNetwork/OTokens/CToken.sol";

interface Erc20ForSingleAssetRainMaker {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
}

contract SingleAssetRainMaker is SingleAssetRainMakerStorage, SingleAssetRainMakerInterface, ExponentialNoError, IComptrollerPeripheral {
    bytes32 constant public SingleAssetRainMakerContractHash = keccak256("SingleAssetRainMaker");

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

    /// @notice Emitted when a new COMP speed is calculated for a market
    event CompSpeedUpdated(CToken indexed cToken, uint newSpeed);

    /// @notice Emitted when COMP is distributed to a supplier
    event DistributedSupplierComp(CToken indexed cToken, address indexed supplier, uint compDelta, uint compSupplyIndex);

    /// @notice Emitted when COMP is distributed to a borrower
    event DistributedBorrowerComp(CToken indexed cToken, address indexed borrower, uint compDelta, uint compBorrowIndex);

    /*** Constructor ***/
    constructor(address _comptroller, address _admin) public {
        admin = _admin;
        comptroller = ComptrollerInterface(_comptroller);
        contractNameHash = SingleAssetRainMakerContractHash;

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
                    compAccrued[holders[j]] = grantCompInternal(holders[j], compAccrued[holders[j]]);
                }
            }
            if (suppliers == true) {
                updateCompSupplyIndexInternal(address(cToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierCompInternal(address(cToken), holders[j]);
                    compAccrued[holders[j]] = grantCompInternal(holders[j], compAccrued[holders[j]]);
                }
            }
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
     */
    function updateCompSupplyIndexInternal(address cToken) internal {
        if (isRetired) {
            return;
        }

        CompMarketState storage supplyState = compSupplyState[cToken];
        uint supplySpeed = compSpeeds[cToken];
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = CToken(cToken).totalSupply();
            uint compAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(compAccrued, supplyTokens) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: supplyState.index}), ratio);
            compSupplyState[cToken] = CompMarketState({
            index: safe224(index.mantissa, "new index exceeds 224 bits"),
            block: safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            supplyState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Accrue COMP to the market by updating the borrow index
     * @param cToken The market whose borrow index to update
     */
    function updateCompBorrowIndexInternal(address cToken, Exp memory marketBorrowIndex) internal {
        if (isRetired) {
            return;
        }

        CompMarketState storage borrowState = compBorrowState[cToken];
        uint borrowSpeed = compSpeeds[cToken];
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(CToken(cToken).totalBorrows(), marketBorrowIndex);
            uint compAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(compAccrued, borrowAmount) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: borrowState.index}), ratio);
            compBorrowState[cToken] = CompMarketState({
            index: safe224(index.mantissa, "new index exceeds 224 bits"),
            block: safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            borrowState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Calculate COMP accrued by a supplier and possibly transfer it to them
     * @param cToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute COMP to
     */
    function distributeSupplierCompInternal(address cToken, address supplier) internal {
        CompMarketState storage supplyState = compSupplyState[cToken];
        Double memory supplyIndex = Double({mantissa: supplyState.index});
        Double memory supplierIndex = Double({mantissa: compSupplierIndex[cToken][supplier]});
        compSupplierIndex[cToken][supplier] = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = compInitialIndex;
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = CToken(cToken).balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        uint supplierAccrued = add_(compAccrued[supplier], supplierDelta);
        compAccrued[supplier] = supplierAccrued;
        emit DistributedSupplierComp(CToken(cToken), supplier, supplierDelta, supplyIndex.mantissa);
    }

    /**
     * @notice Calculate COMP accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param cToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute COMP to
     */
    function distributeBorrowerCompInternal(address cToken, address borrower, Exp memory marketBorrowIndex) internal {
        CompMarketState storage borrowState = compBorrowState[cToken];
        Double memory borrowIndex = Double({mantissa: borrowState.index});
        Double memory borrowerIndex = Double({mantissa: compBorrowerIndex[cToken][borrower]});
        compBorrowerIndex[cToken][borrower] = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(CToken(cToken).borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint borrowerAccrued = add_(compAccrued[borrower], borrowerDelta);
            compAccrued[borrower] = borrowerAccrued;
            emit DistributedBorrowerComp(CToken(cToken), borrower, borrowerDelta, borrowIndex.mantissa);
        }
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
        Erc20ForSingleAssetRainMaker lnToken = Erc20ForSingleAssetRainMaker(getLnIncentiveTokenAddress());
        uint lnTokenRemaining = lnToken.balanceOf(address(this));
        if (amount > 0 && amount <= lnTokenRemaining) {
            lnToken.transfer(user, amount);
            return 0;
        }
        return amount;
    }

    /**
     * @notice Set COMP speed for a single market
     * @param cToken The market whose COMP speed to update
     * @param compSpeed New COMP speed for market
     */
    function setCompSpeedInternal(CToken cToken, uint compSpeed) internal {
        uint currentCompSpeed = compSpeeds[address(cToken)];
        if (currentCompSpeed != 0) {
            // note that COMP speed could be set to 0 to halt liquidity rewards for a market
            Exp memory borrowIndex = Exp({mantissa: cToken.borrowIndex()});
            updateCompSupplyIndexInternal(address(cToken));
            updateCompBorrowIndexInternal(address(cToken), borrowIndex);
        } else if (compSpeed != 0) {
            // Add the COMP market
            require(isListed[address(cToken)] == true, "comp market is not listed");

            if (compSupplyState[address(cToken)].index == 0 && compSupplyState[address(cToken)].block == 0) {
                compSupplyState[address(cToken)] = CompMarketState({
                index: compInitialIndex,
                block: safe32(getBlockNumber(), "block number exceeds 32 bits")
                });
            }

            if (compBorrowState[address(cToken)].index == 0 && compBorrowState[address(cToken)].block == 0) {
                compBorrowState[address(cToken)] = CompMarketState({
                index: compInitialIndex,
                block: safe32(getBlockNumber(), "block number exceeds 32 bits")
                });
            }
        }

        if (currentCompSpeed != compSpeed) {
            compSpeeds[address(cToken)] = compSpeed;
            emit CompSpeedUpdated(cToken, compSpeed);
        }
    }

    /*** Comp Distribution Admin ***/

    /**
     * @notice Set COMP speeds for a multiple markets
     * @param _cTokens The markets whose COMP speeds to update
     * @param _compSpeeds New COMP speed per market
     */
    function _setCompSpeeds(CToken[] calldata _cTokens, uint[] calldata _compSpeeds) external {
        require(_cTokens.length == _compSpeeds.length, "markets and speeds should be 1:1");
        require(isAdmin(), "only admin can set comp speed");

        for (uint i = 0; i < _cTokens.length; i++) {
            setCompSpeedInternal(_cTokens[i], _compSpeeds[i]);
        }
    }

    /**
     * @notice Set COMP speed for a single market
     * @param cToken The market whose COMP speed to update
     * @param compSpeed New COMP speed for market
     */
    function _setCompSpeed(CToken cToken, uint compSpeed) public {
        require(isAdmin(), "only admin can set comp speed");
        setCompSpeedInternal(cToken, compSpeed);
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
        emit MarketListed(CToken(cToken));
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

    /*** Utils ***/

    function getBlockNumber() public view returns (uint)
    {
        return block.number;
    }
}