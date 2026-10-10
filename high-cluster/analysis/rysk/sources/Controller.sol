/**
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity =0.6.10;

pragma experimental ABIEncoderV2;

import {OwnableUpgradeSafe} from "../packages/oz/upgradeability/OwnableUpgradeSafe.sol";
import {ReentrancyGuardUpgradeSafe} from "../packages/oz/upgradeability/ReentrancyGuardUpgradeSafe.sol";
import {Initializable} from "../packages/oz/upgradeability/Initializable.sol";
import {SafeMath} from "../packages/oz/SafeMath.sol";
import {MarginVault} from "../libs/MarginVault.sol";
import {Actions} from "../libs/Actions.sol";
import {AddressBookInterface} from "../interfaces/AddressBookInterface.sol";
import {OtokenInterface} from "../interfaces/OtokenInterface.sol";
import {MarginCalculatorInterface} from "../interfaces/MarginCalculatorInterface.sol";
import {OracleInterface} from "../interfaces/OracleInterface.sol";
import {WhitelistInterface} from "../interfaces/WhitelistInterface.sol";
import {MarginPoolInterface} from "../interfaces/MarginPoolInterface.sol";
import {ControllerLogicInterface} from "../interfaces/ControllerLogicInterface.sol";

/**
 * Controller Error Codes (deprecated codes are removed for space, but can be found in previous commits)
 * C1: sender is not full pauser
 * C2: sender is not partial pauser
 * C4: system is partially paused
 * C5: system is fully paused
 * C6: msg.sender is not authorized to run action
 * C7: invalid addressbook address
 * C8: invalid owner address
 * C9: invalid input
 * C12: can not run actions for different owners
 * C13: can not run actions on different vaults
 * C14: invalid final vault state
 * C15: can not run actions on inexistent vault
 * C16: cannot deposit long otoken from this address
 * C17: otoken is not whitelisted to be used as collateral
 * C18: otoken used as collateral is already expired
 * C19: can not withdraw an expired otoken
 * C20: cannot deposit collateral from this address
 * C21: asset is not whitelisted to be used as collateral
 * C22: can not withdraw collateral from a vault with an expired short otoken
 * C23: otoken is not whitelisted to be minted
 * C24: can not mint expired otoken
 * C25: cannot burn from this address
 * C26: can not burn expired otoken
 * C27: otoken is not whitelisted to be redeemed
 * C28: can not redeem un-expired otoken
 * C29: asset prices not finalized yet
 * C30: can't settle vault with no otoken
 * C31: can not settle vault with un-expired otoken
 * C32: can not settle undercollateralized vault
 * C35: invalid vault id
 * C38: Redeem time period must be greater than zero
 * C39: Redeem time period has expired
 * C40: Vault settlement type does not match oToken settlement type.
 * C41: Redeem time period has not expired
 * C42: Caller is not ControllerLogic
 * C43: Cannot have physically settled otokens with non physically settled vault, vice versa
 * C45: cannot redeem OTM physically settled option
 * C46: oToken amount would truncate when converted to collateral decimals
 */

/**
 * @title Controller
 * @author Opyn Team
 * @notice Contract that controls the Gamma Protocol and the interaction of all sub contracts
 */
contract Controller is Initializable, OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe {
    using MarginVault for MarginVault.Vault;
    using SafeMath for uint256;

    AddressBookInterface public addressbook;
    WhitelistInterface public whitelist;
    OracleInterface public oracle;
    MarginCalculatorInterface public calculator;
    MarginPoolInterface public pool;
    ControllerLogicInterface public controllerLogic;

    /// @dev DEPRECATED — replaced by authorizedCallers mapping
    address public _DEPRECATED_manager;

    /// @notice address that has permission to partially pause the system, where system functionality is paused
    /// except redeem and settleVault
    address public partialPauser;

    /// @notice address that has permission to fully pause the system, where all system functionality is paused
    address public fullPauser;

    /// @notice True if all system functionality is paused other than redeem and settle vault
    bool public systemPartiallyPaused;

    /// @notice True if all system functionality is paused
    bool public systemFullyPaused;

    /// @dev DEPRECATED — replaced by authorizedCallers mapping
    bool public _DEPRECATED_operatorsEnabled;

    /// @dev mapping between an owner address and the number of owner address vaults
    mapping(address => uint256) internal accountVaultCounter;
    /// @dev mapping between an owner address and a specific vault using a vault id
    mapping(address => mapping(uint256 => MarginVault.Vault)) internal vaults;
    /// @notice mapping of addresses authorized to call operate() and act on any vault
    mapping(address => bool) public authorizedCallers;

    /******************************************************************** V2.0.0 storage upgrade ******************************************************/

    /// @dev mapping to map vault by each vault type, naked margin vault should be set to 1 (DEPRECATED), spread/max loss vault should be set to 0, physically settled set to 2
    mapping(address => mapping(uint256 => uint256)) internal vaultType;
    /// @dev mapping to store the timestamp at which the vault was last updated, will be updated in every action that changes the vault state or when calling sync()
    mapping(address => mapping(uint256 => uint256)) internal vaultLatestUpdate;

    /// @dev reserved slot 1
    uint256 internal _RESERVED1;

    /// @dev reserved slot 2
    uint256 internal _RESERVED2;

    ///@dev reserved slot 3
    uint256 internal _RESERVED3;

    /// @notice emits an event when an authorized caller is updated
    event AuthorizedCallerUpdated(address indexed caller, bool isAuthorized);
    /// @notice emits an event when a new vault is opened
    event VaultOpened(address indexed accountOwner, uint256 vaultId, uint256 indexed vaultType);
    /// @notice emits an event when the system partial paused status changes
    event SystemPartiallyPaused(bool isPaused);
    /// @notice emits an event when the system fully paused status changes
    event SystemFullyPaused(bool isPaused);
    /// @notice emits an event when the full pauser is updated
    event FullPauserUpdated(address indexed previousFullPauser, address indexed newFullPauser);
    /// @notice emits an event when the partial pauser is updated
    event PartialPauserUpdated(address indexed previousPartialPauser, address indexed newPartialPauser);
    /// @notice emits an event when the configuration is refreshed
    event ConfigurationRefreshed();

    /**
     * @notice modifier to check if the system is not partially paused, where only redeem and settleVault is allowed
     */
    modifier notPartiallyPaused() {
        _isNotPartiallyPaused();

        _;
    }

    /**
     * @notice modifier to check if the system is not fully paused, where no functionality is allowed
     */
    modifier notFullyPaused() {
        _isNotFullyPaused();

        _;
    }

    /**
     * @notice modifier to check if sender is the fullPauser address
     */
    modifier onlyFullPauser() {
        require(msg.sender == fullPauser, "C1");

        _;
    }

    /**
     * @notice modifier to check if the sender is the partialPauser address
     */
    modifier onlyPartialPauser() {
        require(msg.sender == partialPauser, "C2");

        _;
    }

    /**
     * @dev check if the system is not in a partiallyPaused state
     */
    function _isNotPartiallyPaused() internal view {
        require(!systemPartiallyPaused, "C4");
    }

    /**
     * @dev check if the system is not in an fullyPaused state
     */
    function _isNotFullyPaused() internal view {
        require(!systemFullyPaused, "C5");
    }

    /**
     * @dev check if the sender is an authorized caller
     */
    function _revertIfNotAuthorized() internal view {
        require(authorizedCallers[msg.sender], "C6");
    }

    /**
     * @notice initalize the deployed contract
     * @param _addressBook addressbook module
     * @param _owner account owner address
     */
    function initialize(
        address _addressBook,
        address _owner,
        address _authorizedCaller
    ) external initializer {
        require(_addressBook != address(0), "C7");
        require(_owner != address(0), "C8");

        __Ownable_init(_owner);
        __ReentrancyGuard_init_unchained();
        authorizedCallers[_authorizedCaller] = true;
        addressbook = AddressBookInterface(_addressBook);
        _refreshConfigInternal();
    }

    /**
     * @notice send asset amount to margin pool
     * @dev use donate() instead of direct transfer() to store the balance in assetBalance
     * @param _asset asset address
     * @param _amount amount to donate to pool
     */
    function donate(address _asset, uint256 _amount) external onlyOwner {
        pool.transferToPool(_asset, msg.sender, _amount);
    }

    /**
     * @notice allows the partialPauser to toggle the systemPartiallyPaused variable and partially pause or partially unpause the system
     * @dev can only be called by the partialPauser
     * @param _partiallyPaused new boolean value to set systemPartiallyPaused to
     */
    function setSystemPartiallyPaused(bool _partiallyPaused) external onlyPartialPauser {
        require(systemPartiallyPaused != _partiallyPaused, "C9");

        systemPartiallyPaused = _partiallyPaused;

        emit SystemPartiallyPaused(_partiallyPaused);
    }

    /**
     * @notice allows the fullPauser to toggle the systemFullyPaused variable and fully pause or fully unpause the system
     * @dev can only be called by the fullyPauser
     * @param _fullyPaused new boolean value to set systemFullyPaused to
     */
    function setSystemFullyPaused(bool _fullyPaused) external onlyFullPauser {
        require(systemFullyPaused != _fullyPaused, "C9");

        systemFullyPaused = _fullyPaused;

        emit SystemFullyPaused(_fullyPaused);
    }

    /**
     * @notice allows the owner to authorize or unauthorize a caller for the operate function
     * @param _caller address to authorize or unauthorize
     * @param _isAuthorized whether the caller is authorized
     */
    function setAuthorizedCaller(address _caller, bool _isAuthorized) external onlyOwner {
        require(_caller != address(0), "C9");
        require(authorizedCallers[_caller] != _isAuthorized, "C9");
        authorizedCallers[_caller] = _isAuthorized;
        emit AuthorizedCallerUpdated(_caller, _isAuthorized);
    }

    /**
     * @notice allows the owner to set the fullPauser address
     * @dev can only be called by the owner
     * @param _fullPauser new fullPauser address
     */
    function setFullPauser(address _fullPauser) external onlyOwner {
        require(_fullPauser != address(0), "C9");
        emit FullPauserUpdated(fullPauser, _fullPauser);
        fullPauser = _fullPauser;
    }

    /**
     * @notice allows the owner to set the partialPauser address
     * @dev can only be called by the owner
     * @param _partialPauser new partialPauser address
     */
    function setPartialPauser(address _partialPauser) external onlyOwner {
        require(_partialPauser != address(0), "C9");
        emit PartialPauserUpdated(partialPauser, _partialPauser);
        partialPauser = _partialPauser;
    }

    /**
     * @dev updates the configuration of the controller. can only be called by the owner
     */
    function refreshConfiguration() external onlyOwner {
        _refreshConfigInternal();
        emit ConfigurationRefreshed();
    }

    /**
     * @notice execute a number of actions on specific vaults
     * @dev can only be called when the system is not fully paused
     * @param _actions array of actions arguments
     */
    function operate(Actions.ActionArgs[] memory _actions) external nonReentrant notFullyPaused {
        _revertIfNotAuthorized();
        (bool vaultUpdated, address vaultOwner, uint256 vaultId) = _runActions(_actions);
        if (vaultUpdated) {
            _verifyFinalState(vaultOwner, vaultId);
            vaultLatestUpdate[vaultOwner][vaultId] = now;
        }
    }

    /**
     * @notice returns the current controller configuration
     * @return whitelist, the address of the whitelist module
     * @return oracle, the address of the oracle module
     * @return calculator, the address of the calculator module
     * @return pool, the address of the pool module
     * @return controllerLogic, the address of the controller logic module
     */
    function getConfiguration()
        external
        view
        returns (
            address,
            address,
            address,
            address,
            address
        )
    {
        return (address(whitelist), address(oracle), address(calculator), address(pool), address(controllerLogic));
    }

    /**
     * @notice return the amount of excess collateral that can be withdrawn from a vault
     * @dev for type 0 (cash-settled) vaults post-expiry, this is the writer's full settlement payout.
     * for type 2 (physically settled) vaults, this is only the overcollateralization amount —
     * the writer's full settlement payout also includes their share of the redemptionBalances pool,
     * which is calculated separately during handleSettle().
     * @param _owner account owner of the vault
     * @param _vaultId vaultId to return balances for
     * @return amount of excess collateral, or 0 if the vault is undercollateralized
     */
    function getProceed(address _owner, uint256 _vaultId) external view returns (uint256) {
        (MarginVault.Vault memory vault, uint256 typeVault, ) = getVaultWithDetails(_owner, _vaultId);

        (uint256 netValue, bool isExcess) = calculator.getExcessCollateral(vault, typeVault);

        if (!isExcess) return 0;

        return netValue;
    }

    /**
     * @dev return if an expired oToken is ready to be settled, only true when price for underlying,
     * strike and collateral assets at this specific expiry is available in our Oracle module
     * @param _otoken oToken
     */
    function isSettlementAllowed(address _otoken) external view returns (bool) {
        (address collateral, address underlying, address strike, uint256 expiry) = _getOtokenDetails(_otoken);
        return _canSettleAssets(underlying, strike, collateral, expiry);
    }

    /**
     * @dev return if underlying, strike, collateral are all allowed to be settled
     * @param _underlying oToken underlying asset
     * @param _strike oToken strike asset
     * @param _collateral oToken collateral asset
     * @param _expiry otoken expiry timestamp
     * @return True if the oToken has expired AND all oracle prices at the expiry timestamp have been finalized, False if not
     */
    function canSettleAssets(
        address _underlying,
        address _strike,
        address _collateral,
        uint256 _expiry
    ) external view returns (bool) {
        return _canSettleAssets(_underlying, _strike, _collateral, _expiry);
    }

    /**
     * @notice get the number of vaults for a specified account owner
     * @param _accountOwner account owner address
     * @return number of vaults
     */
    function getAccountVaultCounter(address _accountOwner) external view returns (uint256) {
        return accountVaultCounter[_accountOwner];
    }

    /**
     * @notice check if an oToken has expired
     * @param _otoken oToken address
     * @return True if the otoken has expired, False if not
     */
    function hasExpired(address _otoken) external view returns (bool) {
        return now >= OtokenInterface(_otoken).expiryTimestamp();
    }

    /**
     * @notice return a specific vault
     * @param _owner account owner
     * @param _vaultId vault id of vault to return
     * @return Vault struct that corresponds to the _vaultId of _owner
     */
    function getVault(address _owner, uint256 _vaultId) external view returns (MarginVault.Vault memory) {
        return (vaults[_owner][_vaultId]);
    }

    /**
     * @notice return a specific vault
     * @param _owner account owner
     * @param _vaultId vault id of vault to return
     * @return Vault struct that corresponds to the _vaultId of _owner, vault type and the latest timestamp when the vault was updated
     */
    function getVaultWithDetails(address _owner, uint256 _vaultId)
        public
        view
        returns (
            MarginVault.Vault memory,
            uint256,
            uint256
        )
    {
        return (vaults[_owner][_vaultId], vaultType[_owner][_vaultId], vaultLatestUpdate[_owner][_vaultId]);
    }

    /**
     * @notice execute a variety of actions
     * @dev for each action in the action array, execute the corresponding action, only one vault can be modified
     * for all actions except SettleVault and Redeem
     * @param _actions array of type Actions.ActionArgs[], which expresses which actions the user wants to execute
     * @return vaultUpdated, indicates if a vault has changed
     * @return owner, the vault owner if a vault has changed
     * @return vaultId, the vault Id if a vault has changed
     */
    function _runActions(Actions.ActionArgs[] memory _actions)
        internal
        returns (
            bool,
            address,
            uint256
        )
    {
        address vaultOwner;
        uint256 vaultId;
        bool vaultUpdated;

        for (uint256 i = 0; i < _actions.length; i++) {
            Actions.ActionArgs memory action = _actions[i];
            Actions.ActionType actionType = action.actionType;

            // actions except Settle and Redeem are "Vault-updating actinos"
            // only allow update 1 vault in each operate call
            if (
                (actionType != Actions.ActionType.SettleVault) &&
                (actionType != Actions.ActionType.Redeem)
            ) {
                // check if this action is manipulating the same vault as all other actions, if a vault has already been updated
                if (vaultUpdated) {
                    require(vaultOwner == action.owner, "C12");
                    require(vaultId == action.vaultId, "C13");
                } else {
                    vaultUpdated = true;
                    vaultId = action.vaultId;
                    vaultOwner = action.owner;
                }
            }

            if (actionType == Actions.ActionType.OpenVault) {
                _openVault(Actions._parseOpenVaultArgs(action));
            } else if (actionType == Actions.ActionType.DepositLongOption) {
                _depositLong(Actions._parseDepositArgs(action));
            } else if (actionType == Actions.ActionType.WithdrawLongOption) {
                _withdrawLong(Actions._parseWithdrawArgs(action));
            } else if (actionType == Actions.ActionType.DepositCollateral) {
                _depositCollateral(Actions._parseDepositArgs(action));
            } else if (actionType == Actions.ActionType.WithdrawCollateral) {
                _withdrawCollateral(Actions._parseWithdrawArgs(action));
            } else if (actionType == Actions.ActionType.MintShortOption) {
                _mintOtoken(Actions._parseMintArgs(action));
            } else if (actionType == Actions.ActionType.BurnShortOption) {
                _burnOtoken(Actions._parseBurnArgs(action));
            } else if (actionType == Actions.ActionType.Redeem) {
                _redeem(Actions._parseRedeemArgs(action));
            } else if (actionType == Actions.ActionType.SettleVault) {
                _settleVault(Actions._parseSettleVaultArgs(action));
            }
        }

        return (vaultUpdated, vaultOwner, vaultId);
    }

    /**
     * @notice verify the vault final state after executing all actions
     * @param _owner account owner address
     * @param _vaultId vault id of the final vault
     */
    function _verifyFinalState(address _owner, uint256 _vaultId) internal view {
        (MarginVault.Vault memory vault, uint256 typeVault, ) = getVaultWithDetails(_owner, _vaultId);
        (, bool isValidVault) = calculator.getExcessCollateral(vault, typeVault);
        require(isValidVault, "C14");
    }

    /**
     * @notice open a new vault inside an account
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args OpenVaultArgs structure
     */
    function _openVault(Actions.OpenVaultArgs memory _args)
        internal
        notPartiallyPaused
    {
        uint256 vaultId = accountVaultCounter[_args.owner].add(1);

        require(_args.vaultId == vaultId, "C15");

        // store new vault
        accountVaultCounter[_args.owner] = vaultId;
        vaultType[_args.owner][vaultId] = _args.vaultType;

        emit VaultOpened(_args.owner, vaultId, _args.vaultType);
    }

    /**
     * @notice deposit a long oToken into a vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args DepositArgs structure
     */
    function _depositLong(Actions.DepositArgs memory _args)
        internal
        notPartiallyPaused
    {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");
        // only allow vault owner or authorized caller to deposit long otoken
        require((_args.from == msg.sender) || (_args.from == _args.owner), "C16");

        controllerLogic.handleDepositLong(_args);
    }

    /**
     * @notice withdraw a long oToken from a vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args WithdrawArgs structure
     */
    function _withdrawLong(Actions.WithdrawArgs memory _args)
        internal
        notPartiallyPaused
    {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");

        controllerLogic.handleWithdrawLong(_args);
    }

    /**
     * @notice deposit a collateral asset into a vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args DepositArgs structure
     */
    function _depositCollateral(Actions.DepositArgs memory _args)
        internal
        notPartiallyPaused
    {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");
        // only allow vault owner or authorized caller to deposit collateral
        require((_args.from == msg.sender) || (_args.from == _args.owner), "C20");

        controllerLogic.handleDepositCollateral(_args);
    }

    /**
     * @notice withdraw a collateral asset from a vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args WithdrawArgs structure
     */
    function _withdrawCollateral(Actions.WithdrawArgs memory _args)
        internal
        notPartiallyPaused
    {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");

        controllerLogic.handleWithdrawCollateral(_args);
    }

    /**
     * @notice mint short oTokens from a vault which creates an obligation that is recorded in the vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args MintArgs structure
     */
    function _mintOtoken(Actions.MintArgs memory _args)
        internal
        notPartiallyPaused
    {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");

        controllerLogic.handleMintOtoken(_args, vaultType[_args.owner][_args.vaultId]);
    }

    /**
     * @notice burn oTokens to reduce or remove the minted oToken obligation recorded in a vault
     * @dev cannot be called when system is partiallyPaused or fullyPaused
     * @param _args MintArgs structure
     */
    function _burnOtoken(Actions.BurnArgs memory _args)
        internal
        notPartiallyPaused
    {
        // check that vault id is valid for this vault owner
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");
        // only allow vault owner or authorized caller to burn otoken
        require((_args.from == msg.sender) || (_args.from == _args.owner), "C25");

        controllerLogic.handleBurnOtoken(_args, vaultType[_args.owner][_args.vaultId]);
    }

    /**
     * @notice redeem an oToken after expiry, receiving the payout of the oToken in the collateral asset
     * @dev cannot be called when system is fullyPaused
     * @param _args RedeemArgs structure
     */
    function _redeem(Actions.RedeemArgs memory _args) internal {
        controllerLogic.handleRedeem(_args, msg.sender);
    }

    /**
     * @notice settle a vault after expiry, removing the net proceeds/collateral after both long and short oToken payouts have settled
     * @dev deletes a vault of vaultId after net proceeds/collateral is removed, cannot be called when system is fullyPaused
     * @param _args SettleVaultArgs structure
     */
    function _settleVault(Actions.SettleVaultArgs memory _args) internal {
        require(_checkVaultId(_args.owner, _args.vaultId), "C35");

        controllerLogic.handleSettle(_args);
    }

    /**
     * @notice check if a vault id is valid for a given account owner address
     * @param _accountOwner account owner address
     * @param _vaultId vault id to check
     * @return True if the _vaultId is valid, False if not
     */
    function _checkVaultId(address _accountOwner, uint256 _vaultId) internal view returns (bool) {
        return ((_vaultId > 0) && (_vaultId <= accountVaultCounter[_accountOwner]));
    }

    function _isNotEmpty(address[] memory _array) internal pure returns (bool) {
        return (_array.length > 0) && (_array[0] != address(0));
    }

    /**
     * @dev get otoken details
     */
    function _getOtokenDetails(address _otoken)
        internal
        view
        returns (
            address,
            address,
            address,
            uint256
        )
    {
        OtokenInterface otoken = OtokenInterface(_otoken);
        (address collateral, address underlying, address strike, , uint256 expiry, , ) = otoken.getOtokenDetails();
        return (collateral, underlying, strike, expiry);
    }

    /**
     * @dev return if an expired oToken is ready to be settled, only true when price for underlying,
     * strike and collateral assets at this specific expiry is available in our Oracle module
     * @return True if the oToken has expired AND all oracle prices at the expiry timestamp have been finalized, False if not
     */
    function _canSettleAssets(
        address _underlying,
        address _strike,
        address _collateral,
        uint256 _expiry
    ) internal view returns (bool) {
        return
            oracle.isDisputePeriodOver(_underlying, _expiry) &&
            oracle.isDisputePeriodOver(_strike, _expiry) &&
            oracle.isDisputePeriodOver(_collateral, _expiry);
    }

    /**
     * @dev updates the internal configuration of the controller
     */
    function _refreshConfigInternal() internal {
        whitelist = WhitelistInterface(addressbook.getWhitelist());
        oracle = OracleInterface(addressbook.getOracle());
        calculator = MarginCalculatorInterface(addressbook.getMarginCalculator());
        pool = MarginPoolInterface(addressbook.getMarginPool());
        controllerLogic = ControllerLogicInterface(addressbook.getControllerLogic());
    }

    enum VaultActions {
        AddShort,
        RemoveShort,
        AddLong,
        RemoveLong,
        AddCollateral,
        RemoveCollateral,
        Delete
    }

    function updateVault(
        VaultActions _action,
        address _owner,
        uint256 _vaultId,
        address _asset,
        uint256 _amount
    ) external {
        require(msg.sender == addressbook.getControllerLogic(), "C42");

        if (_action == VaultActions.AddShort) {
            vaults[_owner][_vaultId].addShort(_asset, _amount, 0); // _asset is otoken
        }
        if (_action == VaultActions.RemoveShort) {
            vaults[_owner][_vaultId].removeShort(_asset, _amount, 0); // _asset is otoken
        }
        if (_action == VaultActions.AddLong) {
            vaults[_owner][_vaultId].addLong(_asset, _amount, 0);
        }
        if (_action == VaultActions.RemoveLong) {
            vaults[_owner][_vaultId].removeLong(_asset, _amount, 0);
        }
        if (_action == VaultActions.AddCollateral) {
            vaults[_owner][_vaultId].addCollateral(_asset, _amount, 0);
        }
        if (_action == VaultActions.RemoveCollateral) {
            vaults[_owner][_vaultId].removeCollateral(_asset, _amount, 0);
        }
        if (_action == VaultActions.Delete) {
            delete vaults[_owner][_vaultId];
        }
    }
}
