// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.22;

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { BBMath } from "./libraries/BBMath.sol";
import { UniversalERC20, IERC20 } from "./libraries/UniversalERC20.sol";

import { ERC1155NaiveReceiver } from "./utils/ERC1155NaiveReceiver.sol";
import "./utils/BlueberryConst.sol" as Constants;
import "./utils/BlueberryErrors.sol" as Errors;

import { IBank } from "./interfaces/IBank.sol";
import { IBErc20 } from "./interfaces/money-market/IBErc20.sol";
import { ICoreOracle } from "./interfaces/ICoreOracle.sol";
import { IERC20Wrapper } from "./interfaces/IERC20Wrapper.sol";
import { IFeeManager } from "./interfaces/IFeeManager.sol";
import { IHardVault } from "./interfaces/IHardVault.sol";
import { IProtocolConfig } from "./interfaces/IProtocolConfig.sol";
import { ISoftVault } from "./interfaces/ISoftVault.sol";

/**
 * @title BlueberryBank
 * @author BlueberryProtocol
 * @notice Blueberry Bank is the main contract that stores user's positions and track the borrowing of tokens
 */
contract BlueberryBank is IBank, Ownable2StepUpgradeable, ERC1155NaiveReceiver {
    using BBMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using UniversalERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                     STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NO_ID = type(uint256).max;
    address private constant _NO_ADDRESS = address(1);

    /* solhint-disable var-name-mixedcase */
    uint256 private _GENERAL_LOCK; /// @dev TEMPORARY: re-entrancy lock guard.
    uint256 private _IN_EXEC_LOCK; /// @dev TEMPORARY: exec lock guard.
    uint256 private _POSITION_ID; /// @dev TEMPORARY: position ID currently under execution.
    address private _SPELL; /// @dev TEMPORARY: spell currently under execution.
    /* solhint-enable var-name-mixedcase */

    IProtocolConfig private _config; /// @dev The protocol _config address.
    ICoreOracle private _oracle; /// @dev The main _oracle address.

    uint256 internal _nextPositionId; /// @dev Next available position ID, starting from 1 (see initialize).
    uint256 internal _bankStatus; /// @dev Each bit stores certain bank status, e.g. borrow allowed, repay allowed
    uint256 internal _repayResumedTimestamp; /// @dev Timestamp that repay is allowed or resumed

    address[] internal _allBanks; /// @dev The list of all listed banks.
    mapping(address => Bank) internal _banks; /// @dev Mapping from token to bank data.
    mapping(address => bool) internal _bTokenInBank; /// @dev Mapping from bToken to its existence in bank.
    mapping(uint256 => Position) internal _positions; /// @dev Mapping from position ID to position data.

    mapping(address => bool) private _whitelistedTokens; /// @dev Mapping from token to whitelist status
    mapping(address => bool) private _whitelistedWrappedTokens; /// @dev Mapping from token to whitelist status
    mapping(address => bool) private _whitelistedSpells; /// @dev Mapping from spell to whitelist status

    /*//////////////////////////////////////////////////////////////////////////
                                      MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Ensure that the token is already whitelisted
    modifier onlyWhitelistedToken(address token) {
        if (!_whitelistedTokens[token]) revert Errors.TOKEN_NOT_WHITELISTED(token);
        _;
    }

    /// @dev Ensure that the wrapped ERC1155 is already whitelisted
    modifier onlyWhitelistedERC1155(address token) {
        if (!_whitelistedWrappedTokens[token]) revert Errors.TOKEN_NOT_WHITELISTED(token);
        _;
    }

    /// @dev Reentrancy lock guard.
    modifier lock() {
        if (_GENERAL_LOCK != _NOT_ENTERED) revert Errors.LOCKED();
        _GENERAL_LOCK = _ENTERED;
        _;
        _GENERAL_LOCK = _NOT_ENTERED;
    }

    /// @dev Ensure that the function is called from within the execution scope.
    modifier inExec() {
        if (_POSITION_ID == _NO_ID) revert Errors.NOT_IN_EXEC();
        if (_SPELL != msg.sender) revert Errors.NOT_FROM_SPELL(msg.sender);
        if (_IN_EXEC_LOCK != _NOT_ENTERED) revert Errors.LOCKED();
        _IN_EXEC_LOCK = _ENTERED;
        _;
        _IN_EXEC_LOCK = _NOT_ENTERED;
    }

    /// @dev Ensure that the interest rate of the given token is accrued.
    modifier poke(address token) {
        accrue(token);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the Blueberry Bank contract.
     * @param oracle The address of the Core Oracle contract.
     * @param config The address of the config contract.
     * @param owner The address of the owner.
     */
    function initialize(ICoreOracle oracle, IProtocolConfig config, address owner) external initializer {
        __Ownable2Step_init();
        _transferOwnership(owner);
        if (address(oracle) == address(0) || address(config) == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }
        _GENERAL_LOCK = _NOT_ENTERED;
        _IN_EXEC_LOCK = _NOT_ENTERED;
        _POSITION_ID = _NO_ID;
        _SPELL = _NO_ADDRESS;

        _config = config;
        _oracle = oracle;

        _nextPositionId = 1;
        _bankStatus = 15; // 0x1111: allow borrow, repay, lend, withdrawLend as default

        emit SetOracle(address(oracle));
    }

    /// @inheritdoc IBank
    function liquidate(
        uint256 positionId,
        address debtToken,
        uint256 amountCall
    ) external override lock poke(debtToken) {
        /// Ensures repayments are allowed at the moment of calling this function.
        if (!isRepayAllowed()) revert Errors.REPAY_NOT_ALLOWED();
        /// Ensures a non-zero repayment amount is specified.
        if (amountCall == 0) revert Errors.ZERO_AMOUNT();
        /// Ensures the position is liquidatable.
        if (!isLiquidatable(positionId)) revert Errors.NOT_LIQUIDATABLE(positionId);

        /// Retrieve the position and associated bank data.
        Position storage pos = _positions[positionId];
        Bank memory bank = _banks[pos.underlyingToken];
        /// Ensure the position has valid collateral.
        if (pos.collToken == address(0)) revert Errors.BAD_COLLATERAL(positionId);

        /// Revert liquidation if the repayment hasn't been warmed up
        /// following the last state where repayments were paused.
        if (block.timestamp < _repayResumedTimestamp + Constants.LIQUIDATION_REPAY_WARM_UP_PERIOD) {
            revert Errors.REPAY_ALLOW_NOT_WARMED_UP();
        }

        /// Repay the debt and get details of repayment.
        uint256 oldShare = pos.debtShare;
        (uint256 amountPaid, uint256 share) = _repay(positionId, debtToken, amountCall);

        /// Calculate the size of collateral and underlying vault share that the liquidator will get.
        uint256 liqSize = (pos.collateralSize * share) / oldShare;
        uint256 uVaultShare = (pos.underlyingVaultShare * share) / oldShare;

        /// Adjust the position's debt and collateral after liquidation.
        pos.collateralSize -= liqSize;
        pos.underlyingVaultShare -= uVaultShare;

        /// Transfer the liquidated collateral (Wrapped LP Tokens) to the liquidator.
        IERC1155Upgradeable(pos.collToken).safeTransferFrom(address(this), msg.sender, pos.collId, liqSize, "");
        /// Transfer underlying collaterals(vault share tokens) to liquidator
        if (_isSoftVault(pos.underlyingToken)) {
            IERC20Upgradeable(bank.softVault).safeTransfer(msg.sender, uVaultShare);
        } else {
            IERC1155Upgradeable(bank.hardVault).safeTransferFrom(
                address(this),
                msg.sender,
                uint256(uint160(pos.underlyingToken)),
                uVaultShare,
                ""
            );
        }

        /// Emit an event capturing details of the liquidation process.
        emit Liquidate(positionId, msg.sender, debtToken, amountPaid, share, liqSize, uVaultShare);
    }

    /// @inheritdoc IBank
    function execute(uint256 positionId, address spell, bytes memory data) external lock returns (uint256) {
        if (!_whitelistedSpells[spell]) revert Errors.SPELL_NOT_WHITELISTED(spell);
        if (positionId == 0) {
            positionId = _nextPositionId++;
            _positions[positionId].owner = msg.sender;
        } else {
            if (positionId >= _nextPositionId) revert Errors.BAD_POSITION(positionId);
            if (msg.sender != _positions[positionId].owner) revert Errors.NOT_FROM_OWNER(positionId, msg.sender);
        }
        _POSITION_ID = positionId;
        _SPELL = spell;

        (bool ok, bytes memory returndata) = spell.call(data);
        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("bad cast call");
            }
        }

        accrue(_positions[positionId].underlyingToken);
        if (isLiquidatable(positionId)) revert Errors.INSUFFICIENT_COLLATERAL();

        _POSITION_ID = _NO_ID;
        _SPELL = _NO_ADDRESS;

        emit Execute(positionId, msg.sender);

        return positionId;
    }

    /// @inheritdoc IBank
    function lend(address token, uint256 amount) external override inExec poke(token) onlyWhitelistedToken(token) {
        if (!isLendAllowed()) revert Errors.LEND_NOT_ALLOWED();

        Position storage pos = _positions[_POSITION_ID];
        Bank storage bank = _banks[token];
        if (pos.underlyingToken != address(0)) {
            /// already have isolated collateral, allow same isolated collateral
            if (pos.underlyingToken != token) revert Errors.INCORRECT_UNDERLYING(token);
        } else {
            pos.underlyingToken = token;
        }

        IFeeManager feeManager = getFeeManager();

        IERC20Upgradeable(token).safeTransferFrom(pos.owner, address(this), amount);
        IERC20(token).universalApprove(address(feeManager), amount);
        amount = feeManager.doCutDepositFee(token, amount);

        if (_isSoftVault(token)) {
            IERC20(token).universalApprove(bank.softVault, amount);
            pos.underlyingVaultShare += ISoftVault(bank.softVault).deposit(amount);
        } else {
            IERC20(token).universalApprove(bank.hardVault, amount);
            pos.underlyingVaultShare += IHardVault(bank.hardVault).deposit(token, amount);
        }

        emit Lend(_POSITION_ID, msg.sender, token, amount);
    }

    /// @inheritdoc IBank
    function withdrawLend(address token, uint256 shareAmount) external override inExec poke(token) {
        if (!isWithdrawLendAllowed()) revert Errors.WITHDRAW_LEND_NOT_ALLOWED();
        Position storage pos = _positions[_POSITION_ID];
        Bank memory bank = _banks[token];
        if (token != pos.underlyingToken) revert Errors.INVALID_UTOKEN(token);
        if (shareAmount == type(uint256).max) {
            shareAmount = pos.underlyingVaultShare;
        }
        uint256 wAmount;
        if (_isSoftVault(token)) {
            IERC20(bank.softVault).universalApprove(bank.softVault, shareAmount);
            wAmount = ISoftVault(bank.softVault).withdraw(shareAmount);
        } else {
            wAmount = IHardVault(bank.hardVault).withdraw(token, shareAmount);
        }

        IFeeManager feeManager = getFeeManager();

        pos.underlyingVaultShare -= shareAmount;
        IERC20(token).universalApprove(address(feeManager), wAmount);
        wAmount = feeManager.doCutWithdrawFee(token, wAmount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, wAmount);
        emit WithdrawLend(_POSITION_ID, msg.sender, token, wAmount);
    }

    /// @inheritdoc IBank
    function borrow(
        address token,
        uint256 amount
    ) external override inExec poke(token) onlyWhitelistedToken(token) returns (uint256 borrowedAmount) {
        if (!isBorrowAllowed()) revert Errors.BORROW_NOT_ALLOWED();
        Bank storage bank = _banks[token];
        Position storage pos = _positions[_POSITION_ID];
        if (pos.debtToken != address(0)) {
            /// already have some debts, allow same debt token
            if (pos.debtToken != token) revert Errors.INCORRECT_DEBT(token);
        } else {
            pos.debtToken = token;
        }

        uint256 totalShare = bank.totalShare;
        uint256 totalDebt = _borrowBalanceStored(token);
        uint256 share = totalShare == 0 ? amount : (amount * totalShare).divCeil(totalDebt);
        if (share == 0) revert Errors.BORROW_ZERO_SHARE(amount);
        bank.totalShare += share;
        pos.debtShare += share;

        borrowedAmount = _doBorrow(token, amount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, borrowedAmount);

        emit Borrow(_POSITION_ID, msg.sender, token, amount, share);
    }

    /// @inheritdoc IBank
    function repay(address token, uint256 amountCall) external override inExec poke(token) onlyWhitelistedToken(token) {
        if (!isRepayAllowed()) revert Errors.REPAY_NOT_ALLOWED();
        (uint256 amount, uint256 share) = _repay(_POSITION_ID, token, amountCall);
        emit Repay(_POSITION_ID, msg.sender, token, amount, share);
    }

    /// @inheritdoc IBank
    function putCollateral(
        address collToken,
        uint256 collId,
        uint256 amountCall
    ) external override inExec onlyWhitelistedERC1155(collToken) {
        Position storage pos = _positions[_POSITION_ID];
        if (pos.collToken != collToken || pos.collId != collId) {
            if (!_oracle.isWrappedTokenSupported(collToken, collId)) {
                revert Errors.ORACLE_NOT_SUPPORT_WTOKEN(collToken);
            }

            if (pos.collateralSize > 0) revert Errors.DIFF_COL_EXIST(pos.collToken);

            pos.collToken = collToken;
            pos.collId = collId;
        }
        uint256 amount = _doERC1155TransferIn(collToken, collId, amountCall);
        pos.collateralSize += amount;
        emit PutCollateral(_POSITION_ID, pos.owner, msg.sender, collToken, collId, amount);
    }

    /// @inheritdoc IBank
    function takeCollateral(uint256 amount) external override inExec returns (uint256) {
        Position storage pos = _positions[_POSITION_ID];

        if (amount == type(uint256).max) {
            amount = pos.collateralSize;
        }

        pos.collateralSize -= amount;
        IERC1155Upgradeable(pos.collToken).safeTransferFrom(address(this), msg.sender, pos.collId, amount, "");

        emit TakeCollateral(_POSITION_ID, msg.sender, pos.collToken, pos.collId, amount);
        return amount;
    }

    /// @inheritdoc IBank
    function currentPositionDebt(
        uint256 positionId
    ) external override poke(_positions[positionId].debtToken) returns (uint256) {
        return getPositionDebt(positionId);
    }

    /// @inheritdoc IBank
    function accrue(address token) public override {
        Bank storage bank = _banks[token];
        if (!bank.isListed) revert Errors.BANK_NOT_LISTED(token);
        IBErc20(bank.bToken).borrowBalanceCurrent(address(this));
    }

    /// @inheritdoc IBank
    function accrueAll(address[] memory tokens) external {
        for (uint256 i = 0; i < tokens.length; ++i) {
            accrue(tokens[i]);
        }
    }

    function whitelistSpells(address[] calldata spells, bool[] calldata statuses) external onlyOwner {
        if (spells.length != statuses.length) {
            revert Errors.INPUT_ARRAY_MISMATCH();
        }
        for (uint256 i = 0; i < spells.length; ++i) {
            if (spells[i] == address(0)) {
                revert Errors.ZERO_ADDRESS();
            }
            _whitelistedSpells[spells[i]] = statuses[i];
        }
    }

    function whitelistTokens(address[] calldata tokens, bool[] calldata statuses) external onlyOwner {
        if (tokens.length != statuses.length) {
            revert Errors.INPUT_ARRAY_MISMATCH();
        }
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (statuses[i] && !_oracle.isTokenSupported(tokens[i])) revert Errors.ORACLE_NOT_SUPPORT(tokens[i]);
            _whitelistedTokens[tokens[i]] = statuses[i];
            emit SetWhitelistToken(tokens[i], statuses[i]);
        }
    }

    function whitelistERC1155(address[] memory tokens, bool ok) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            if (token == address(0)) revert Errors.ZERO_ADDRESS();
            _whitelistedWrappedTokens[token] = ok;
            emit SetWhitelistERC1155(token, ok);
        }
    }

    function addBank(
        address token,
        address softVault,
        address hardVault,
        uint256 liqThreshold
    ) external onlyOwner onlyWhitelistedToken(token) {
        if (softVault == address(0) || hardVault == address(0)) revert Errors.ZERO_ADDRESS();
        if (liqThreshold > Constants.DENOMINATOR) revert Errors.LIQ_THRESHOLD_TOO_HIGH(liqThreshold);
        if (liqThreshold < Constants.MIN_LIQ_THRESHOLD) revert Errors.LIQ_THRESHOLD_TOO_LOW(liqThreshold);

        Bank storage bank = _banks[token];
        address bToken = address(ISoftVault(softVault).getBToken());

        if (_bTokenInBank[bToken]) revert Errors.BTOKEN_ALREADY_ADDED();
        if (bank.isListed) revert Errors.BANK_ALREADY_LISTED();

        uint256 _allBanksLength = _allBanks.length;

        if (_allBanksLength >= 256) revert Errors.BANK_LIMIT();

        _bTokenInBank[bToken] = true;
        bank.isListed = true;
        bank.index = uint8(_allBanksLength);
        bank.bToken = bToken;
        bank.softVault = softVault;
        bank.hardVault = hardVault;
        bank.liqThreshold = liqThreshold;

        IHardVault(hardVault).setApprovalForAll(hardVault, true);
        _allBanks.push(token);

        emit AddBank(token, bToken, softVault, hardVault);
    }

    function modifyBank(
        uint8 bankIndex,
        address token,
        address softVault,
        address hardVault,
        uint256 liqThreshold
    ) external onlyOwner onlyWhitelistedToken(token) {
        if (softVault == address(0) || hardVault == address(0)) revert Errors.ZERO_ADDRESS();
        if (liqThreshold > Constants.DENOMINATOR) revert Errors.LIQ_THRESHOLD_TOO_HIGH(liqThreshold);
        if (liqThreshold < Constants.MIN_LIQ_THRESHOLD) revert Errors.LIQ_THRESHOLD_TOO_LOW(liqThreshold);
        if (bankIndex >= _allBanks.length) revert Errors.BANK_NOT_EXIST(bankIndex);

        address bankToken = _allBanks[bankIndex];
        Bank storage bank = _banks[bankToken];
        address bToken = address(ISoftVault(softVault).getBToken());

        bank.bToken = bToken;
        bank.softVault = softVault;
        bank.hardVault = hardVault;
        bank.liqThreshold = liqThreshold;

        IHardVault(hardVault).setApprovalForAll(hardVault, true);

        emit ModifyBank(token, bToken, softVault, hardVault);
    }

    function setBankStatus(uint256 bankStatus) external onlyOwner {
        bool repayAllowedStatusBefore = isRepayAllowed();
        _bankStatus = bankStatus;
        bool repayAllowedStatusAfter = isRepayAllowed();

        /// If the repayAllowed status changes from "off" to "on", update the timestamp.
        if (!repayAllowedStatusBefore && repayAllowedStatusAfter) {
            _repayResumedTimestamp = block.timestamp;
        }
    }

    /// @inheritdoc IBank
    function isBorrowAllowed() public view override returns (bool) {
        return (_bankStatus & 0x01) > 0;
    }

    /// @inheritdoc IBank
    function isRepayAllowed() public view override returns (bool) {
        return (_bankStatus & 0x02) > 0;
    }

    /// @inheritdoc IBank
    function isLendAllowed() public view override returns (bool) {
        return (_bankStatus & 0x04) > 0;
    }

    /// @inheritdoc IBank
    function isWithdrawLendAllowed() public view override returns (bool) {
        return (_bankStatus & 0x08) > 0;
    }

    /// @inheritdoc IBank
    function getFeeManager() public view override returns (IFeeManager) {
        return _config.getFeeManager();
    }

    /// @inheritdoc IBank
    function getBankStatus() external view returns (uint256) {
        return _bankStatus;
    }

    /// @inheritdoc IBank
    function getRepayResumedTimestamp() external view returns (uint256) {
        return _repayResumedTimestamp;
    }

    /// @inheritdoc IBank
    function isTokenWhitelisted(address token) external view returns (bool) {
        return _whitelistedTokens[token];
    }

    /// @inheritdoc IBank
    function isWrappedTokenWhitelisted(address token) external view returns (bool) {
        return _whitelistedWrappedTokens[token];
    }

    /// @inheritdoc IBank
    function isSpellWhitelisted(address spell) external view returns (bool) {
        return _whitelistedSpells[spell];
    }

    /// @inheritdoc IBank
    function getNextPositionId() external view override returns (uint256) {
        return _nextPositionId;
    }

    /// @inheritdoc IBank
    function getConfig() external view override returns (IProtocolConfig) {
        return _config;
    }

    /// @inheritdoc IBank
    function getOracle() external view override returns (ICoreOracle) {
        return _oracle;
    }

    /// @inheritdoc IBank
    function getAllBanks() external view override returns (address[] memory) {
        return _allBanks;
    }

    /// @inheritdoc IBank
    function getPositionDebt(uint256 positionId) public view override returns (uint256 debt) {
        Position memory pos = _positions[positionId];
        Bank memory bank = _banks[pos.debtToken];
        if (pos.debtShare == 0 || bank.totalShare == 0) {
            return 0;
        }
        debt = (pos.debtShare * _borrowBalanceStored(pos.debtToken)).divCeil(bank.totalShare);
    }

    /// @inheritdoc IBank
    function getBankInfo(address token) external view override returns (Bank memory bank) {
        bank = _banks[token];
    }

    /// @inheritdoc IBank
    function getPositionInfo(uint256 positionId) external view override returns (Position memory) {
        return _positions[positionId];
    }

    /// @inheritdoc IBank
    function getCurrentPositionInfo() external view override returns (Position memory) {
        if (_POSITION_ID == _NO_ID) revert Errors.BAD_POSITION(_POSITION_ID);
        return _positions[_POSITION_ID];
    }

    /// @inheritdoc IBank
    function getPositionValue(uint256 positionId) public view override returns (uint256 positionValue) {
        Position memory pos = _positions[positionId];
        if (pos.collateralSize == 0) {
            return 0;
        } else {
            if (pos.collToken == address(0)) revert Errors.BAD_COLLATERAL(positionId);
            uint256 collValue = _oracle.getWrappedTokenValue(pos.collToken, pos.collId, pos.collateralSize);

            uint256 rewardsValue;
            (address[] memory tokens, uint256[] memory rewards) = IERC20Wrapper(pos.collToken).pendingRewards(
                pos.collId,
                pos.collateralSize
            );

            for (uint256 i; i < tokens.length; ++i) {
                if (_oracle.isTokenSupported(tokens[i])) {
                    rewardsValue += _oracle.getTokenValue(tokens[i], rewards[i]);
                }
            }

            return collValue + rewardsValue;
        }
    }

    /// @inheritdoc IBank
    function getDebtValue(uint256 positionId) public view override returns (uint256 debtValue) {
        Position memory pos = _positions[positionId];
        uint256 debt = getPositionDebt(positionId);
        debtValue = _oracle.getTokenValue(pos.debtToken, debt);
    }

    /// @inheritdoc IBank
    function getIsolatedCollateralValue(uint256 positionId) public view override returns (uint256 icollValue) {
        Position memory pos = _positions[positionId];
        /// NOTE: exchangeRateStored has 18 decimals.
        uint256 underlyingAmount;
        if (_isSoftVault(pos.underlyingToken)) {
            underlyingAmount =
                (IBErc20(_banks[pos.underlyingToken].bToken).exchangeRateStored() * pos.underlyingVaultShare) /
                Constants.PRICE_PRECISION;
        } else {
            underlyingAmount = pos.underlyingVaultShare;
        }
        icollValue = _oracle.getTokenValue(pos.underlyingToken, underlyingAmount);
    }

    /// @inheritdoc IBank
    function getPositionRisk(uint256 positionId) public view override returns (uint256 risk) {
        uint256 pv = getPositionValue(positionId);
        uint256 ov = getDebtValue(positionId);
        uint256 cv = getIsolatedCollateralValue(positionId);

        if (
            (cv == 0 && pv == 0 && ov == 0) || pv >= ov /// Closed position or Overcollateralized position
        ) {
            risk = 0;
        } else if (cv == 0) {
            /// Sth bad happened to isolated underlying token
            risk = Constants.DENOMINATOR;
        } else {
            risk = ((ov - pv) * Constants.DENOMINATOR) / cv;
        }
    }

    /// @inheritdoc IBank
    function isLiquidatable(uint256 positionId) public view override returns (bool) {
        return getPositionRisk(positionId) >= _banks[_positions[positionId].underlyingToken].liqThreshold;
    }

    /**
     * @notice Internal function that handles the logic for repaying tokens.
     * @param positionId The position ID which determines the debt to be repaid.
     * @param token The bank token used to repay the debt.
     * @param amountCall The amount specified by the caller to repay by calling `transferFrom`, or -1 for debt size.
     * @return Returns the actual repaid amount and the reduced debt share.
     */
    function _repay(uint256 positionId, address token, uint256 amountCall) internal returns (uint256, uint256) {
        Bank storage bank = _banks[token];
        Position storage pos = _positions[positionId];

        if (pos.debtToken != token) revert Errors.INCORRECT_DEBT(token);

        uint256 totalShare = bank.totalShare;
        uint256 totalDebt = _borrowBalanceStored(token);
        uint256 oldShare = pos.debtShare;
        uint256 oldDebt = (oldShare * totalDebt).divCeil(totalShare);

        if (amountCall > oldDebt) {
            amountCall = oldDebt;
        }

        amountCall = _doERC20TransferIn(token, amountCall);
        uint256 paid = _doRepay(token, amountCall);

        if (paid > oldDebt) revert Errors.REPAY_EXCEEDS_DEBT(paid, oldDebt); /// prevent share overflow attack

        uint256 lessShare = paid == oldDebt ? oldShare : (paid * totalShare) / totalDebt;
        bank.totalShare -= lessShare;
        pos.debtShare -= lessShare;

        return (paid, lessShare);
    }

    /**
     * @dev Internal function to return the current borrow balance of the given token.
     * @param token The token address to query for borrow balance.
     */
    function _borrowBalanceStored(address token) internal view returns (uint256) {
        return IBErc20(_banks[token].bToken).borrowBalanceStored(address(this));
    }

    /**
     * @notice Internal function that handles the borrowing logic.
     * @dev Borrows the specified amount of tokens and returns the actual borrowed amount.
     * NOTE: Caller must ensure that bToken interest was already accrued up to this block.
     * @param token The token to borrow.
     * @param amountCall The amount of tokens to be borrowed.
     * @return borrowAmount The actual amount borrowed.
     */
    function _doBorrow(address token, uint256 amountCall) internal returns (uint256 borrowAmount) {
        address bToken = _banks[token].bToken;

        IERC20Upgradeable uToken = IERC20Upgradeable(token);
        uint256 uBalanceBefore = uToken.balanceOf(address(this));
        if (IBErc20(bToken).borrow(amountCall) != 0) revert Errors.BORROW_FAILED(amountCall);
        uint256 uBalanceAfter = uToken.balanceOf(address(this));

        borrowAmount = uBalanceAfter - uBalanceBefore;
    }

    /**
     * @dev Internal function to handle repayment to the bank. Returns the actual repaid amount.
     * @param token The token used for the repayment.
     * @param amountCall The specified amount for the repay action.
     * NOTE: The caller should ensure that the bToken's interest is updated up to the current block.
     */
    function _doRepay(address token, uint256 amountCall) internal returns (uint256 repaidAmount) {
        address bToken = _banks[token].bToken;

        IERC20(token).universalApprove(bToken, amountCall);
        uint256 beforeDebt = _borrowBalanceStored(token);

        if (IBErc20(bToken).repayBorrow(amountCall) != 0) {
            revert Errors.REPAY_FAILED(amountCall);
        }

        uint256 newDebt = _borrowBalanceStored(token);
        repaidAmount = beforeDebt - newDebt;
    }

    /**
     * @dev Internal function to handle the transfer of ERC20 tokens into the contract.
     * @param token The ERC20 token to perform transferFrom action.
     * @param amountCall The amount use in the transferFrom call.
     * @return The actual received amount.
     */
    function _doERC20TransferIn(address token, uint256 amountCall) internal returns (uint256) {
        uint256 balanceBefore = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amountCall);
        uint256 balanceAfter = IERC20Upgradeable(token).balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    /**
     * @dev Internal function to handle the transfer of ERC1155 tokens into the contract.
     * @param token The ERC1155 token contract address.
     * @param id The specific token ID to be transferred within the ERC1155 contract.
     * @param amountCall The expected amount of the specific token ID to be transferred.
     * @return The amount of tokens received.
     */
    function _doERC1155TransferIn(address token, uint256 id, uint256 amountCall) internal returns (uint256) {
        uint256 balanceBefore = IERC1155Upgradeable(token).balanceOf(address(this), id);
        IERC1155Upgradeable(token).safeTransferFrom(msg.sender, address(this), id, amountCall, "");
        uint256 balanceAfter = IERC1155Upgradeable(token).balanceOf(address(this), id);

        return balanceAfter - balanceBefore;
    }

    /**
     * @dev Internal function to check if the given vault token is a soft vault or hard vault.
     * @param token The underlying token of the vault to be checked.
     * @return True if it's a Soft Vault, False if it's a Hard Vault.
     */
    function _isSoftVault(address token) internal view returns (bool) {
        return address(ISoftVault(_banks[token].softVault).getUnderlyingToken()) == token;
    }

    /* solhint-disable func-name-mixedcase */
    /// @inheritdoc IBank
    function EXECUTOR() external view returns (address) {
        uint256 positionId = _POSITION_ID;
        if (positionId == _NO_ID) {
            revert Errors.NOT_UNDER_EXECUTION();
        }
        return _positions[positionId].owner;
    }

    /// @inheritdoc IBank
    function POSITION_ID() external view returns (uint256) {
        return _POSITION_ID;
    }

    /// @inheritdoc IBank
    function SPELL() external view returns (address) {
        return _SPELL;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     *      variables without shifting down storage in the inheritance chain.
     *      See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[30] private __gap;
    /* solhint-enable func-name-mixedcase */
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && AddressUpgradeable.isContract(address(token));
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.0;

import "./OwnableUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function __Ownable2Step_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.22;
/**
 * @title BBMath
 * @author BlueberryProtocol
 * @dev The BBMath library provides functions for calculating common mathematical operations.
    */
library BBMath {
    /// @notice Rounds up the result of division between two numbers.
    /// @param a Numerator.
    /// @param b Denominator.
    /// @return The result of the division, rounded up.
    function divCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b - 1) / b;
    }

    /// @notice Calculates the square root of a number using the Babylonian method.
    /// @dev This function uses bit manipulation to efficiently estimate square roots.
    ///      The function iteratively refines the approximation, and after seven iterations,
    ///      the result is very close to the actual square root.
    /// @param x The number to compute the square root of.
    /// @return The estimated square root of x.
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 xx = x;
        uint256 r = 1;

        /// Bitwise operations to determine the magnitude of the input
        /// and position our initial approximation (r) near the actual square root.
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }

        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }

        /// Refinement using Babylonian method
        /// This iterative approach refines our approximation with every iteration.
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; /// Seven iterations should be enough

        /// Determine the closest approximation by comparing r and r1.
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniversalERC20
 * @dev UniversalERC20 is a helper contract that allows to work around ERC20
 *      limitations when dealing with missing return values.
 *      UniversalERC20 executes a low level call to the token contract.
 *      If it fails, it assumes that the token does not implement the method.
 *      If it succeeds, it returns the value returned by the method.
 *      Also supports if the token address is native ETH.
 */
library UniversalERC20 {
    using SafeERC20 for IERC20;

    address private constant _ZERO_ADDRESS = address(0);
    address private constant _ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /// @notice UniversalERC20's safeTransfer function that is similar to ERC20's transfer function.
    /// @dev Works around non-standard ERC20's that throw on 0 transfer and supports Native ETH.
    function universalTransfer(IERC20 token, address to, uint256 amount) internal returns (bool) {
        if (amount == 0) {
            return true;
        }
        if (isETH(token)) {
            (bool success, ) = to.call{ value: amount }("");
            require(success, "ETH transfer failed");
            return true;
        } else {
            token.safeTransfer(to, amount);
            return true;
        }
    }

    /// @notice UniversalERC20's safeTransferFrom function that is similar to ERC20's transferFrom function.
    /// @dev Works around non-standard ERC20's that throw on 0 transfer and supports native ETH.
    function universalTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (isETH(token)) {
            require(from == msg.sender && msg.value == amount, "Wrong useage of ETH.universalTransferFrom()");
            if (to != address(this)) {
                (bool success, ) = to.call{ value: amount }("");
                require(success, "ETH transfer failed");
            }
        } else {
            token.safeTransferFrom(from, to, amount);
        }
    }

    function universalApprove(IERC20 token, address to, uint256 amount) internal {
        if (!isETH(token)) {
            token.forceApprove(to, amount);
        }
    }

    /// @notice UniversalBalanceOf returns the balance of a token for an address.
    /// @dev Is able to tell the balance of a token or natie ETH.
    function universalBalanceOf(IERC20 token, address who) internal view returns (uint256) {
        if (isETH(token)) {
            return who.balance;
        } else {
            return token.balanceOf(who);
        }
    }

    /// @notice returns if the token is ETH or not.
    function isETH(IERC20 token) internal pure returns (bool) {
        return (address(token) == address(_ZERO_ADDRESS) || address(token) == address(_ETH_ADDRESS));
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.22;

import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/**
 * @title ERC1155NaiveReceiver
 * @author BlueberryProtocol
 * @notice A receiver contract that naively accepts all ERC1155 transfers.
 */
contract ERC1155NaiveReceiver is IERC1155Receiver {
    /// @notice Handle the receipt of a single ERC1155 token type.
    /// @dev This function is called at the end of a
    /// `safeTransferFrom` after the balance has been updated.
    function onERC1155Received(
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @notice Handle the receipt of multiple ERC1155 token types.
    /// @dev This function is called at the end of a
    /// `safeBatchTransferFrom` after the balances have been updated.
    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /// @notice Checks if the contract supports a given interface.
    /// @dev Returns true if the interfaceId is 0x01ffc9a7 (IERC1155Receiver).
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

/**
 * @title BlueberryErrors
 * @author BlueberryProtocol
 * @notice This contract contains the error messages for Blueberry Protocol.
 */
pragma solidity 0.8.22;

/// @dev Common denominator for percentage-based calculations.
uint256 constant DENOMINATOR = 10000;

/// @dev Minimum threshold for liquidity operations, represented as a fraction of the DENOMINATOR.
uint256 constant MIN_LIQ_THRESHOLD = 8000; // represent 80%

/// @dev Precision factor to maintain price accuracy.
uint256 constant PRICE_PRECISION = 1e18;

/// @dev Maximum allowed price deviation, represented as a fraction of the DENOMINATOR.
uint256 constant MAX_PRICE_DEVIATION = 1000; // represent 10%

/// @dev Minimum time interval for specific time-dependent operations.
uint32 constant MIN_TIME_GAP = 3 minutes;

/// @dev Maximum time interval for specific time-dependent operations.
uint32 constant MAX_TIME_GAP = 2 days;

/// @dev Maximum allowed fee rate, represented as a fraction of the DENOMINATOR.
uint256 constant MAX_FEE_RATE = 2000; // represent 20%

/// @dev Maximum allowed time for vault withdrawal fee calculations.
uint256 constant MAX_WITHDRAW_VAULT_FEE_WINDOW = 60 days;

/// @dev Maximum delay permitted for swap operations.
uint32 constant MAX_DELAY_ON_SWAP = 2 hours;

/// @dev Allowed grace period time for sequencer operations.
uint32 constant SEQUENCER_GRACE_PERIOD_TIME = 3600;

/// @dev Precision factor for Chainlink price feed values.
uint256 constant CHAINLINK_PRICE_FEED_PRECISION = 1e8;

/// @dev Warm-up period before a liquidation repayment can be initiated.
uint256 constant LIQUIDATION_REPAY_WARM_UP_PERIOD = 4 hours;


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/
/**
 * @title BlueberryErrors
 * @author BlueberryProtocol
 * @notice containing all errors used in Blueberry protocol
 */
/// title BlueberryErrors
/// @notice containing all errors used in Blueberry protocol
pragma solidity 0.8.22;

/*//////////////////////////////////////////////////////////////////////////
                                COMMON ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when an action involves zero amount of tokens.
error ZERO_AMOUNT();

/// @notice Thrown when the address provided is the zero address.
error ZERO_ADDRESS();

/// @notice Thrown when the lengths of input arrays do not match.
error INPUT_ARRAY_MISMATCH();

/// @notice Thrown when the caller is not authorized to call the function.
error UNAUTHORIZED();

/*//////////////////////////////////////////////////////////////////////////
                                ORACLE ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the delay time exceeds allowed limits.
error TOO_LONG_DELAY(uint256 delayTime);

/// @notice Thrown when there's no maximum delay set for a token.
error NO_MAX_DELAY(address token);

/// @notice Thrown when the price information for a token is outdated.
error PRICE_OUTDATED(address token);

/// @notice Thrown when the price obtained is negative.
error PRICE_NEGATIVE(address token);

/// @notice Thrown when the sequencer is offline
error SEQUENCER_DOWN(address sequencer);

/// @notice Thrown when the grace period for a sequencer is not over yet.
error SEQUENCER_GRACE_PERIOD_NOT_OVER(address sequencer);

/// @notice Thrown when the price deviation exceeds allowed limits.
error OUT_OF_DEVIATION_CAP(uint256 deviation);

/// @notice Thrown when the number of sources exceeds the allowed length.
error EXCEED_SOURCE_LEN(uint256 length);

/// @notice Thrown when no primary source is available for the token.
error NO_PRIMARY_SOURCE(address token);

/// @notice Thrown when no valid price source is available for the token.
error NO_VALID_SOURCE(address token);

/// @notice Thrown when the deviation value exceeds the threshold.
error EXCEED_DEVIATION();

/// @notice Thrown when the mean price is below the acceptable threshold.
error TOO_LOW_MEAN(uint256 mean);

/// @notice Thrown when no mean price is set for the token.
error NO_MEAN(address token);

/// @notice Thrown when no stable pool exists for the token.
error NO_STABLEPOOL(address token);

/// @notice Thrown when the price fetch process fails for a token.
error PRICE_FAILED(address token);

/// @notice Thrown when the liquidation threshold is set too high.
error LIQ_THRESHOLD_TOO_HIGH(uint256 threshold);

/// @notice Thrown when the liquidation threshold is set too low.
error LIQ_THRESHOLD_TOO_LOW(uint256 threshold);

/// @notice Thrown when the oracle doesn't support a specific token.
error ORACLE_NOT_SUPPORT(address token);

/// @notice Thrown when the oracle doesn't support a specific LP pair token.
error ORACLE_NOT_SUPPORT_LP(address lp);

/// @notice Thrown when the oracle doesn't support a specific wToken.
error ORACLE_NOT_SUPPORT_WTOKEN(address wToken);

/// @notice Thrown when there is no route to fetch data for the oracle
error NO_ORACLE_ROUTE(address token);

/// @notice Thrown when a value is out of an acceptable range.
error VALUE_OUT_OF_RANGE();

/// @notice Thrown when specified limits are incorrect.
error INCORRECT_LIMITS();

/// @notice Thrown when Curve LP is already registered.
error CRV_LP_ALREADY_REGISTERED(address lp);

/// @notice Thrown when a pool is subject to read-only reentrancy manipulation.
error REENTRANCY_RISK(address pool);

/*//////////////////////////////////////////////////////////////////////////
                            GENERAL SPELL ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the caller isn't recognized as a bank.
error NOT_BANK(address caller);

/// @notice Thrown when the collateral doesn't exist for a strategy.
error COLLATERAL_NOT_EXIST(uint256 strategyId, address colToken);

/// @notice Thrown when the strategy ID doesn't correspond to an existing strategy.
error STRATEGY_NOT_EXIST(address spell, uint256 strategyId);

/// @notice Thrown when the position size exceeds maximum limits.
error EXCEED_MAX_POS_SIZE(uint256 strategyId);

/// @notice Thrown when the user has not deposited enough isolated collateral for a strategy.
error BELOW_MIN_ISOLATED_COLLATERAL(uint256 strategyId);

/// @notice Thrown when the loan-to-value ratio exceeds allowed maximum.
error EXCEED_MAX_LTV();

/// @notice Thrown when the strategy ID provided is incorrect.
error INCORRECT_STRATEGY_ID(uint256 strategyId);

/// @notice Thrown when the position size is invalid.
error INVALID_POS_SIZE();

/// @notice Thrown when an incorrect liquidity pool token is provided.
error INCORRECT_LP(address lpToken);

/// @notice Thrown when an incorrect pool ID is provided.
error INCORRECT_PID(uint256 pid);

/// @notice Thrown when an incorrect collateral token is provided.
error INCORRECT_COLTOKEN(address colToken);

/// @notice Thrown when an incorrect underlying token is provided.
error INCORRECT_UNDERLYING(address uToken);

/// @notice Thrown when an incorrect debt token is provided.
error INCORRECT_DEBT(address debtToken);

/// @notice Thrown when a swap fails.
error SWAP_FAILED(address swapToken);

/*//////////////////////////////////////////////////////////////////////////
                                VAULT ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when borrowing from the vault fails.
error BORROW_FAILED(uint256 amount);

/// @notice Thrown when repaying to the vault fails.
error REPAY_FAILED(uint256 amount);

/// @notice Thrown when lending to the vault fails.
error LEND_FAILED(uint256 amount);

/// @notice Thrown when redeeming from the vault fails.
error REDEEM_FAILED(uint256 amount);

/*//////////////////////////////////////////////////////////////////////////
                                WRAPPER ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when a duplicate tokenId is added.
error DUPLICATE_TOKEN_ID(uint256 tokenId);

/// @notice Thrown when an invalid token ID is provided.
error INVALID_TOKEN_ID(uint256 tokenId);

/// @notice Thrown when an incorrect pool ID is provided.
error BAD_PID(uint256 pid);

/// @notice Thrown when a mismatch in reward per share is detected.
error BAD_REWARD_PER_SHARE(uint256 rewardPerShare);

/*//////////////////////////////////////////////////////////////////////////
                                BANK ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when a function is called without a required execution flag.
error NOT_UNDER_EXECUTION();

/// @notice Thrown when a transaction isn't initiated by the expected spell.
error NOT_FROM_SPELL(address from);

/// @notice Thrown when the sender is not the owner of a given position ID.
error NOT_FROM_OWNER(uint256 positionId, address sender);

/// @notice Thrown when a spell address isn't whitelisted.
error SPELL_NOT_WHITELISTED(address spell);

/// @notice Thrown when a token isn't whitelisted.
error TOKEN_NOT_WHITELISTED(address token);

/// @notice Thrown when a bank isn't listed for a given token.
error BANK_NOT_LISTED(address token);

/// @notice Thrown when a bank doesn't exist for an index.
error BANK_NOT_EXIST(uint8 index);

/// @notice Thrown when a bank is already listed for a given token.
error BANK_ALREADY_LISTED();

/// @notice Thrown when the bank limit is reached.
error BANK_LIMIT();

/// @notice Thrown when the BTOKEN is already added.
error BTOKEN_ALREADY_ADDED();

/// @notice Thrown when the lending action isn't allowed.
error LEND_NOT_ALLOWED();

/// @notice Thrown when the borrowing action isn't allowed.
error BORROW_NOT_ALLOWED();

/// @notice Thrown when the repaying action isn't allowed.
error REPAY_NOT_ALLOWED();

/// @notice Thrown when the redeeming action isn't allowed.
error WITHDRAW_LEND_NOT_ALLOWED();

/// @notice Thrown when certain actions are locked.
error LOCKED();

/// @notice Thrown when an action isn't executed.
error NOT_IN_EXEC();

/// @notice Thrown when the repayment allowance hasn't been warmed up.
error REPAY_ALLOW_NOT_WARMED_UP();

/// @notice Thrown when a different collateral type exists.
error DIFF_COL_EXIST(address collToken);

/// @notice Thrown when a position is not eligible for liquidation.
error NOT_LIQUIDATABLE(uint256 positionId);

/// @notice Thrown when a position is flagged as bad or invalid.
error BAD_POSITION(uint256 posId);

/// @notice Thrown when collateral for a specific position is flagged as bad or invalid.
error BAD_COLLATERAL(uint256 positionId);

/// @notice Thrown when there's insufficient collateral for an operation.
error INSUFFICIENT_COLLATERAL();

/// @notice Thrown when an attempted repayment exceeds the actual debt.
error REPAY_EXCEEDS_DEBT(uint256 repay, uint256 debt);

/// @notice Thrown when an invalid utility token is provided.
error INVALID_UTOKEN(address uToken);

/// @notice Thrown when a borrow operation results in zero shares.
error BORROW_ZERO_SHARE(uint256 borrowAmount);

/*//////////////////////////////////////////////////////////////////////////
                            CONFIGURATION ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when a certain ratio is too high for an operation.
error RATIO_TOO_HIGH(uint256 ratio);

/// @notice Thrown when an invalid fee distribution is detected.
error INVALID_FEE_DISTRIBUTION();

/// @notice Thrown when no treasury is set for fee distribution.
error NO_TREASURY_SET();

/// @notice Thrown when a fee window has already started.
error FEE_WINDOW_ALREADY_STARTED();

/// @notice Thrown when a fee window duration is too long.
error FEE_WINDOW_TOO_LONG(uint256 windowTime);

/*//////////////////////////////////////////////////////////////////////////
                                UTILITY ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when an operation has surpassed its deadline.
error EXPIRED(uint256 deadline);


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import { IProtocolConfig } from "./IProtocolConfig.sol";
import { IFeeManager } from "./IFeeManager.sol";
import { ICoreOracle } from "./ICoreOracle.sol";

/**
 * @title IBank
 * @notice Interface for the bank operations, including lending, borrowing, and management of collateral positions.
 */
interface IBank {
    /*//////////////////////////////////////////////////////////////////////////
                                       STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Represents the configuration and current state of a bank.
    struct Bank {
        bool isListed; /// @dev Indicates if this bank is active.
        uint8 index; /// @dev Index for reverse lookups.
        address hardVault; /// @dev Address of the hard vault.
        address softVault; /// @dev Address of the soft vault.
        address bToken; /// @dev Address of the bToken associated with the bank.
        uint256 totalShare; /// @dev Total shares of debt across all open positions.
        uint256 liqThreshold; /// @dev Liquidation threshold (e.g., 85% for volatile tokens,
        /// 90% for stablecoins). Base: 1e4
    }

    /// @notice Represents a position in the bank, including both debt and collateral.
    struct Position {
        address owner; /// @dev Address of the position's owner.
        address collToken; /// @dev Address of the ERC1155 token used as collateral.
        address underlyingToken; /// @dev Address of the isolated underlying collateral token.
        address debtToken; /// @dev Address of the debt token.
        uint256 underlyingVaultShare; /// @dev Amount of vault share for isolated underlying collateral.
        uint256 collId; /// @dev Token ID of the ERC1155 collateral.
        uint256 collateralSize; /// @dev Amount of wrapped token used as collateral.
        uint256 debtShare; /// @dev Debt share of the given debt token for the bank.
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new bank is added by the owner.
    event AddBank(
        address token, /// @dev The primary token associated with the bank.
        address bToken, /// @dev The corresponding bToken for the bank.
        address softVault, /// @dev Address of the soft vault.
        address hardVault /// @dev Address of the hard vault.
    );

    /// @notice Emitted when a bank is modified by the owner.
    event ModifyBank(
        address token, /// @dev The primary token associated with the bank.
        address bToken, /// @dev The corresponding bToken for the bank.
        address softVault, /// @dev Address of the soft vault.
        address hardVault /// @dev Address of the hard vault.
    );

    /// @notice Emitted when the oracle's address is updated by the owner.
    event SetOracle(address oracle); /// New address of the oracle.

    /// @notice Emitted when a Wrapped ERC1155 token is whitelisted or removed by the owner.
    event SetWhitelistERC1155(
        address indexed token, /// Address of the Wrapped ERC1155 token.
        bool isWhitelisted /// True if whitelisted, false otherwise.
    );

    /// @notice Emitted when a token is whitelisted or removed by the owner.
    event SetWhitelistToken(
        address indexed token, /// Address of the token.
        bool isWhitelisted /// True if whitelisted, false otherwise.
    );

    /// @notice Emitted when tokens are lent to the bank.
    event Lend(
        uint256 positionId, /// Position ID associated with the lending.
        address caller, /// Address of the spell caller.
        address token, /// Address of the lent token.
        uint256 amount /// Amount of tokens lent.
    );

    /// @notice Emitted when lent tokens are withdrawn from the bank.
    event WithdrawLend(
        uint256 positionId, /// Position ID associated with the withdrawal.
        address caller, /// Address of the spell caller.
        address token, ///Address of the token being withdrawn.
        uint256 amount /// Amount of tokens withdrawn.
    );

    /// @notice Emitted when a user borrows tokens from a bank.
    event Borrow(
        uint256 positionId, /// Position ID associated with the borrowing.
        address caller, /// Address of the spell caller that initiates the borrowing.
        address token, /// Token being borrowed.
        uint256 amount, /// Amount of tokens borrowed.
        uint256 share /// Debt share associated with the borrowed amount.
    );

    /// @notice Emitted when a user repays borrowed tokens to a bank.
    event Repay(
        uint256 positionId, /// Position ID associated with the repayment.
        address caller, /// Address of the spell caller initiating the repayment.
        address token, /// Token being repaid.
        uint256 amount, /// Amount of tokens repaid.
        uint256 share /// Debt share associated with the repaid amount.
    );

    /// @notice Emitted when a user adds tokens as collateral.
    event PutCollateral(
        uint256 positionId, /// Position ID associated with the collateral.
        address owner, /// Owner of the collateral position.
        address caller, /// Address of the spell caller adding the collateral.
        address token, /// Token used as collateral.
        uint256 id, /// ID of the wrapped token.
        uint256 amount /// Amount of tokens put as collateral.
    );

    /// @notice Emitted when a user retrieves tokens from their collateral.
    event TakeCollateral(
        uint256 positionId, /// Position ID associated with the collateral.
        address caller, /// Address of the spell caller retrieving the collateral.
        address token, /// Token taken from the collateral.
        uint256 id, /// ID of the wrapped token.
        uint256 amount /// Amount of tokens taken from collateral.
    );

    /// @notice Emitted when a position is liquidated.
    event Liquidate(
        uint256 positionId, /// Position ID being liquidated.
        address liquidator, /// Address of the user performing the liquidation.
        address debtToken, /// Debt token associated with the position.
        uint256 amount, /// Amount used for liquidation.
        uint256 share, /// Debt share associated with the liquidation.
        uint256 positionSize, /// Size of the position being liquidated.
        uint256 underlyingVaultSize /// Vault size underlying the liquidated position.
    );

    /// @notice Emitted when a position is executed.
    event Execute(
        uint256 positionId, /// Position ID being executed.
        address owner /// Owner of the position.
    );

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the next available position ID.
     * @return Next position ID.
     */
    function getNextPositionId() external view returns (uint256);

    /// @notice Provides the protocol configuration settings.
    function getConfig() external view returns (IProtocolConfig);

    /// @notice Provides the current oracle responsible for price feeds.
    function getOracle() external view returns (ICoreOracle);

    /// @notice Provides all banks in the Blueberry Bank.
    function getAllBanks() external view returns (address[] memory);

    /**
     * @dev Get the current FeeManager interface from the configuration.
     * @return An interface representing the current FeeManager.
     */
    function getFeeManager() external view returns (IFeeManager);

    /**
     * @notice Returns whitelist status of a given token.
     * @param token Address of the token.
     */
    function isTokenWhitelisted(address token) external view returns (bool);

    /**
     * @notice Returns whitelist status of a given wrapped token.
     * @param token Address of the wrapped token.
     */
    function isWrappedTokenWhitelisted(address token) external view returns (bool);

    /**
     * @notice Returns whitelist status of a given spell.
     * @param spell Address of the spell.
     */
    function isSpellWhitelisted(address spell) external view returns (bool);

    /**
     * @dev Determine if lending is currently allowed based on the bank's status flags.
     * @notice Check the third-to-last bit of _bankStatus.
     * @return A boolean indicating whether lending is permitted.
     */
    function isLendAllowed() external view returns (bool);

    /**
     * @dev Determine if withdrawing from lending is currently allowed based on the bank's status flags.
     * @notice Check the fourth-to-last bit of _bankStatus.
     * @return A boolean indicating whether withdrawing from lending is permitted.
     */
    function isWithdrawLendAllowed() external view returns (bool);

    /**
     * @dev Determine if repayments are currently allowed based on the bank's status flags.
     * @notice Check the second-to-last bit of _bankStatus.
     * @return A boolean indicating whether repayments are permitted.
     */
    function isRepayAllowed() external view returns (bool);

    /**
     * @dev Determine if borrowing is currently allowed based on the bank's status flags.
     * @notice Check the last bit of _bankStatus.
     * @return A boolean indicating whether borrowing is permitted.
     */
    function isBorrowAllowed() external view returns (bool);

    /// @notice Fetches details of a bank given its token.
    function getBankInfo(address token) external view returns (Bank memory bank);

    /**
     * @notice Gets the status of the bank
     * @return The status of the bank
     * @dev 1: Borrow is allowed
     *      2: Repay is allowed
     *      4: Lend is allowed
     *      8: WithdrawLend is allowed
     */
    function getBankStatus() external view returns (uint256);

    /**
     * @dev Computes the total USD value of the debt of a given position.
     * @notice Ensure to call `accrue` beforehand to account for any interest changes.
     * @param positionId ID of the position to compute the debt value for.
     * @return debtValue Total USD value of the position's debt.
     */
    function getDebtValue(uint256 positionId) external view returns (uint256 debtValue);

    /**
     * @notice Gets the repay resumed timestamp of the bank
     * @return The timestamp when repay is resumed
     */
    function getRepayResumedTimestamp() external view returns (uint256);

    /**
     * @dev Computes the risk ratio of a specified position.
     * @notice A higher risk ratio implies greater risk associated with the position.
     * @dev    when:  riskRatio = (ov - pv) / cv
     *         where: riskRatio = (debt - positionValue) / isolatedCollateralValue
     * @param positionId ID of the position to assess risk for.
     * @return risk The risk ratio of the position (based on a scale of 1e4).
     */
    function getPositionRisk(uint256 positionId) external view returns (uint256 risk);

    /**
     * @notice Retrieve the debt of a given position, considering the stored debt interest.
     * @dev Should call accrue first to obtain the current debt.
     * @param positionId The ID of the position to query.
     */
    function getPositionDebt(uint256 positionId) external view returns (uint256 debt);

    /**
     * @notice Determines if a given position can be liquidated based on its risk ratio.
     * @param positionId ID of the position to check.
     * @return True if the position can be liquidated; otherwise, false.
     */
    function isLiquidatable(uint256 positionId) external view returns (bool);

    /**
     * @notice Computes the total USD value of the collateral of a given position.
     * @dev The returned value includes both the collateral and any pending rewards.
     * @param positionId ID of the position to compute the value for.
     * @return positionValue Total USD value of the collateral and pending rewards.
     */
    function getPositionValue(uint256 positionId) external view returns (uint256);

    /**
     * @notice Computes the isolated collateral value for a particular position.
     * @dev Should call accrue first to get current debt.
     * @param positionId The unique ID of the position.
     * @return icollValue The value of the isolated collateral in USD.
     */
    function getIsolatedCollateralValue(uint256 positionId) external view returns (uint256 icollValue);

    /**
     * @notice Provides comprehensive details about a position using its ID.
     * @param positionId The unique ID of the position.
     * @return A Position struct containing details of the position.
     */
    function getPositionInfo(uint256 positionId) external view returns (Position memory);

    /**
     * @notice Fetches information about the currently active position.
     * @return A Position struct with details of the current position.
     */
    function getCurrentPositionInfo() external view returns (Position memory);

    /**
     * @notice Triggers interest accumulation and fetches the updated borrow balance.
     * @param positionId The unique ID of the position.
     * @return The updated debt balance after accruing interest.
     */
    function currentPositionDebt(uint256 positionId) external returns (uint256);

    /**
     * @dev Lend tokens to the bank as isolated collateral.
     * @dev Emit a {Lend} event.
     * @notice The tokens lent will be used as collateral in the bank and might earn interest or other rewards.
     * @param token The address of the token to lend.
     * @param amount The number of tokens to lend.
     */
    function lend(address token, uint256 amount) external;

    /**
     * @dev Withdraw isolated collateral tokens previously lent to the bank.
     * @dev Emit a {WithdrawLend} event.
     * @notice This will reduce the isolated collateral and might also reduce the position's overall health.
     * @param token The address of the isolated collateral token to withdraw.
     * @param shareAmount The number of vault share tokens to withdraw.
     */
    function withdrawLend(address token, uint256 shareAmount) external;

    /**
     * @notice Allows users to borrow tokens from the specified bank.
     * @dev This function must only be called from a spell while under execution.
     * @dev Emit a {Borrow} event.
     * @param token The token to borrow from the bank.
     * @param amount The amount of tokens the user wishes to borrow.
     * @return borrowedAmount Returns the actual amount borrowed from the bank.
     */
    function borrow(address token, uint256 amount) external returns (uint256);

    /**
     * @dev Executes a specific action on a position.
     * @dev Emit an {Execute} event.
     * @notice This can be used for various operations like adjusting collateral, repaying debt, etc.
     * @param positionId Unique identifier of the position, or zero for a new position.
     * @param spell Address of the contract ("spell") that contains the logic for the action to be executed.
     * @param data Data payload to pass to the spell for execution.
     */
    function execute(uint256 positionId, address spell, bytes memory data) external returns (uint256);

    /**
     * @notice Allows users to repay their borrowed tokens to the bank.
     * @dev This function must only be called while under execution.
     * @dev Emit a {Repay} event.
     * @param token The token to repay to the bank.
     * @param amountCall The amount of tokens to be repaid.
     */
    function repay(address token, uint256 amountCall) external;

    /**
     * @notice Allows users to provide additional collateral.
     * @dev Must only be called during execution.
     * @param collToken The ERC1155 token wrapped for collateral (i.e., Wrapped token of LP).
     * @param collId The token ID for collateral (i.e., uint256 format of LP address).
     * @param amountCall The amount of tokens to add as collateral.
     */
    function putCollateral(address collToken, uint256 collId, uint256 amountCall) external;

    /**
     * @notice Allows users to withdraw a portion of their collateral.
     * @dev Must only be called during execution.
     * @param amount The amount of tokens to be withdrawn as collateral.
     * @return Returns the amount of collateral withdrawn.
     */
    function takeCollateral(uint256 amount) external returns (uint256);

    /**
     * @dev Liquidates a position by repaying its debt and taking the collateral.
     * @dev Emit a {Liquidate} event.
     * @notice Liquidation can only be triggered if the position is deemed liquidatable
     *         and other conditions are met.
     * @param positionId The unique identifier of the position to liquidate.
     * @param debtToken The token in which the debt is denominated.
     * @param amountCall The amount of debt to be repaid when calling transferFrom.
     */
    function liquidate(uint256 positionId, address debtToken, uint256 amountCall) external;

    /**
     * @notice Accrues interest for a given token.
     * @param token Address of the token to accrue interest for.
     */
    function accrue(address token) external;

    /**
     * @notice Accrues interest for a given list of tokens.
     * @param tokens An array of token addresses to accrue interest for.
     */
    function accrueAll(address[] memory tokens) external;

    /* solhint-disable func-name-mixedcase */

    /**
     * @notice Returns the current executor's address, which is the owner of the current position.
     * @return Address of the current executor.
     */
    function EXECUTOR() external view returns (address);

    /**
     * @notice Returns the ID of the currently executed position.
     * @return Current position ID.
     */
    function POSITION_ID() external view returns (uint256);

    /**
     * @notice Returns the address of the currently executed bank.
     * @return Current bank address.
     */
    function SPELL() external view returns (address);

    /* solhint-enable func-name-mixedcase */
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

interface IBErc20 {
    function decimals() external view returns (uint8);

    function underlying() external view returns (address);

    function balanceOf(address user) external view returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function exchangeRateCurrent() external returns (uint256);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import { IBaseOracle } from "./IBaseOracle.sol";

/**
 *  @title ICoreOracle
 *  @notice Interface for the CoreOracle contract which provides price feed data for assets in the Blueberry protocol.
 */
interface ICoreOracle is IBaseOracle {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when the owner sets a new oracle route for a given token.
     * @param token The ERC20 token for which the oracle route is set.
     * @param route The address of the oracle route.
     */
    event SetRoute(address indexed token, address route);

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if the given ERC20 token is supported by the oracle.
     * @param token The ERC20 token to check support for.
     * @return A boolean indicating whether the token is supported or not.
     */
    function isTokenSupported(address token) external view returns (bool);

    /**
     * @notice Check if the oracle supports the underlying token of a given ERC1155 wrapper.
     * @dev Only meant to validate wrappers of the Blueberry protocol, such as WERC20.
     * @param token ERC1155 token address to check support for.
     * @param tokenId ERC1155 token id to check support for.
     * @return A boolean indicating whether the wrapped token is supported or not.
     */
    function isWrappedTokenSupported(address token, uint256 tokenId) external view returns (bool);

    /**
     * @notice Returns the USD value of a specific wrapped ERC1155 token.
     * @param token ERC1155 token address.
     * @param id ERC1155 token id.
     * @param amount Amount of the token for which to get the USD value, normalized to 1e18 decimals.
     * @return The USD value of the given wrapped token amount.
     */
    function getWrappedTokenValue(address token, uint256 id, uint256 amount) external view returns (uint256);

    /**
     * @notice Returns the USD value of a given amount of a specific ERC20 token.
     * @param token ERC20 token address.
     * @param amount Amount of the ERC20 token for which to get the USD value.
     * @return The USD value of the given token amount.
     */
    function getTokenValue(address token, uint256 amount) external view returns (uint256);

    /**
     * @notice Fetches the oracle route for the given token.
     * @param token Address of the token to get the route for.
     * @return The address of the oracle route for the given token.
     */
    function getRoute(address token) external view returns (address);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

/**
 * @title IERC20Wrapper
 * @author BlueberryProtocol
 * @notice Interface for the ERC20Wrapper contract which allows the wrapping
 *         of ERC-20 tokens with associated ERC-1155 token IDs.
 */
interface IERC20Wrapper {
    /**
     * @notice Fetches the underlying ERC-20 token address associated with the provided ERC-1155 token ID.
     * @param tokenId The ERC-1155 token ID for which the underlying ERC-20 token address is to be fetched.
     * @return The address of the underlying ERC-20 token.
     */
    function getUnderlyingToken(uint256 tokenId) external view returns (address);

    /**
     * @notice Fetches pending rewards for a particular ERC-1155 token ID and given amount.
     * @param id The ERC-1155 token ID for which the pending rewards are to be fetched.
     * @param amount The amount for which pending rewards are to be calculated.
     * @return tokens A list of addresses representing reward tokens.
     * @return amounts A list of amounts corresponding to each reward token in the `tokens` list.
     */
    function pendingRewards(uint256 id, uint256 amount) external view returns (address[] memory, uint256[] memory);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IProtocolConfig } from "./IProtocolConfig.sol";

/**
 * @title IFeeManager
 * @notice Interface for FeeManager, the central fee management contract in the Blueberry Protocol.
 * @dev FeeManager is responsible for cutting various fees in the protocol and sending them to the treasury.
 */
interface IFeeManager {
    /**
     * @notice Calculates and deducts the deposit fee when lending
     *         isolated underlying assets to Blueberry Money Market.
     * @param token The address of the underlying token for which the deposit fee is to be calculated.
     * @param amount The gross deposit amount before fees.
     * @return The net deposit amount after the fee deduction.
     */
    function doCutDepositFee(address token, uint256 amount) external returns (uint256);

    /**
     * @notice Calculates and deducts the withdrawal fee when redeeming
     *         isolated underlying tokens from Blueberry Money Market.
     * @param token The address of the underlying token for which the withdrawal fee is to be calculated.
     * @param amount The gross withdrawal amount before fees.
     * @return The net withdrawal amount after the fee deduction.
     */
    function doCutWithdrawFee(address token, uint256 amount) external returns (uint256);

    /**
     * @notice Calculates and deducts the performance fee from the
     *         rewards generated due to the leveraged position.
     * @param token The address of the reward token for which the reward fee is to be calculated.
     * @param amount The gross reward amount before fees.
     * @return The net reward amount after the fee deduction.
     */
    function doCutRewardsFee(address token, uint256 amount) external returns (uint256);

    /**
     * @notice Calculates and deducts the vault withdrawal fee if
     *         the withdrawal occurs within the specified fee window in the Blueberry Money Market.
     * @param token The address of the underlying token for which the vault withdrawal fee is to be calculated.
     * @param amount The gross vault withdrawal amount before fees.
     * @return The net vault withdrawal amount after the fee deduction.
     */
    function doCutVaultWithdrawFee(address token, uint256 amount) external returns (uint256);

    /**
     * @notice Gets the protocol config contract address.
     */
    function getConfig() external view returns (IProtocolConfig);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import { IERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

import { IProtocolConfig } from "./IProtocolConfig.sol";

/**
 * @title IHardVault
 * @notice Interface for the HardVault, which integrates ERC1155 tokens with the protocol's underlying assets.
 * @dev This interface facilitates the conversion between underlying ERC-20
 *      tokens and corresponding ERC-1155 representations within the protocol.
 */
interface IHardVault is IERC1155Upgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a user deposits ERC20 tokens into the vault.
     * @param account Address of the user.
     * @param amount Amount of ERC20 tokens deposited.
     * @param shareAmount Amount of ERC1155 tokens minted.
     */
    event Deposited(address indexed account, uint256 amount, uint256 shareAmount);

    /**
     * @dev Emitted when a user withdraws ERC20 tokens from the vault.
     * @param account Address of the user.
     * @param amount Amount of ERC20 tokens withdrawn.
     * @param shareAmount Amount of ERC1155 tokens burned.
     */
    event Withdrawn(address indexed account, uint256 amount, uint256 shareAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves the underlying ERC-20 token address corresponding to a specific ERC-1155 token ID.
     * @param tokenId The ERC-1155 token ID to fetch the underlying ERC-20 token for.
     * @return Address of the underlying ERC-20 token associated with the provided token ID.
     */
    function getUnderlyingToken(uint256 tokenId) external view returns (address);

    /**
     * @notice Returns the balance of the underlying ERC-20 token for a specific user.
     * @param uToken Address of the ERC-20 token to query.
     * @param user Address of the user to query the balance for.
     * @return Balance of the underlying ERC-20 token for the given user.
     */
    function balanceOfToken(address uToken, address user) external view returns (uint256);

    /**
     * @notice Deposit a certain amount of ERC-20 tokens to receive an equivalent amount of ERC-1155 representations.
     * @param uToken The address of the ERC-20 token to be deposited.
     * @param amount The quantity of ERC-20 tokens to be deposited.
     * @return shareAmount The amount of ERC-1155 tokens minted in exchange for the deposited ERC-20 tokens.
     */
    function deposit(address uToken, uint256 amount) external returns (uint256 shareAmount);

    /**
     * @notice Withdraw a certain amount of ERC-1155 tokens to
     *         receive an equivalent amount of underlying ERC-20 tokens.
     * @param uToken The address of the underlying ERC-20 token to be withdrawn.
     * @param shareAmount The quantity of ERC-1155 tokens to be withdrawn.
     * @return withdrawAmount The amount of ERC-20 tokens returned in exchange for the withdrawn ERC-1155 tokens.
     */
    function withdraw(address uToken, uint256 shareAmount) external returns (uint256 withdrawAmount);

    /**
     * @notice Retrieves the protocol configuration for this vault.
     * @return Address of the protocol configuration.
     */
    function getConfig() external view returns (IProtocolConfig);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import { IFeeManager } from "./IFeeManager.sol";

/**
 * @title IProtocolConfig
 * @author BlueberryProtocol
 * @notice Interface for the Protocol Configuration,
 *         encapsulating various fees and related configuration parameters.
 * @dev This interface defines methods to retrieve fees
 *      and related parameters that govern the behavior of the protocol.
 */
interface IProtocolConfig {
    /**
     * @notice Retrieve the deposit fee rate applied when users deposit into the protocol.
     * @return The deposit fee rate.
     */
    function getDepositFee() external view returns (uint256);

    /**
     * @notice Retrieve the withdrawal fee rate applied when users withdraw from the protocol.
     * @return The withdrawal fee rate.
     */
    function getWithdrawFee() external view returns (uint256);

    /**
     * @notice Retrieve the reward fee rate applied when users claim rewards from the protocol.
     * @return The reward fee rate.
     */
    function getRewardFee() external view returns (uint256);

    /**
     * @notice Get the address where protocol's collected fees are stored and managed.
     * @return The treasury address of the protocol.
     */
    function getTreasury() external view returns (address);

    /**
     * @notice Retrieve the fee rate applied for withdrawals from vaults.
     * @return The fee rate for vault withdrawals.
     */
    function getTreasuryFeeRate() external view returns (uint256);

    /**
     * @notice Retrieve the fee rate applied for withdrawals from vaults.
     * @return The fee rate for vault withdrawals.
     */
    function getWithdrawVaultFee() external view returns (uint256);

    /**
     * @notice Retrieve the window of time where the vault withdrawal fee is applied.
     * @return The window of time where the vault withdrawal fee is applied.
     */
    function getWithdrawVaultFeeWindow() external view returns (uint256);

    /**
     * @notice Retrieve the start time of the window of time where the vault withdrawal fee is applied.
     * @return The start time of the window of time where the vault withdrawal fee is applied.
     */
    function getWithdrawVaultFeeWindowStartTime() external view returns (uint256);

    /**
     * @notice Get the fee manager that handles fee calculations and distributions.
     * @return An instance of the IFeeManager interface that manages fees within the protocol.
     */
    function getFeeManager() external view returns (IFeeManager);

    /**
     * @notice Get the address of the $BLB-ICHI vault.
     * @return The address of the $BLB-ICHI vault.
     */
    function getBlbUsdcIchiVault() external view returns (address);

    /**
     * @notice Get the address of the $BLB stability pool.
     * @return The address of the $BLB stability pool.
     */
    function getBlbStabilityPool() external view returns (address);

    /**
     * @notice Get the fee rate applied for withdrawals from the $BLB-ICHI vault.
     * @return The fee rate for $BLB-ICHI vault withdrawals.
     */
    function getBlbIchiVaultFeeRate() external view returns (uint256);

    /**
     * @notice Get the fee rate applied for withdrawals from the $BLB-ICHI vault.
     * @return The fee rate for $BLB-ICHI vault withdrawals.
     */
    function getBlbStablePoolFeeRate() external view returns (uint256);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IBErc20 } from "./money-market/IBErc20.sol";

import { IProtocolConfig } from "./IProtocolConfig.sol";

/**
 * @title ISoftVault
 * @notice Interface for the SoftVault, allowing deposits and withdrawals of assets.
 * @dev The SoftVault is responsible for handling user deposits,
 *      withdrawals, and interactions with underlying Blueberry Money Market bTokens.
 */
interface ISoftVault is IERC20Upgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when an account deposits assets.
     * @param account Address of the account that deposited.
     * @param amount The amount of underlying assets deposited.
     * @param shareAmount The corresponding amount of vault shares minted.
     */
    event Deposited(address indexed account, uint256 amount, uint256 shareAmount);

    /**
     * @notice Event emitted when an account withdraws assets.
     * @param account Address of the account that withdrew.
     * @param amount The amount of underlying assets withdrawn.
     * @param shareAmount The corresponding amount of vault shares burned.
     */
    event Withdrawn(address indexed account, uint256 amount, uint256 shareAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the corresponding Blueberry Money Market bToken for this vault.
     * @return A Blueberry Money Market bToken interface.
     */
    function getBToken() external view returns (IBErc20);

    /**
     * @notice Get the underlying ERC20 token for this vault.
     * @return An ERC20 interface of the underlying token.
     */
    function getUnderlyingToken() external view returns (IERC20Upgradeable);

    /**
     * @notice Retrieves the protocol configuration for this vault.
     * @return Address of the protocol configuration.
     */
    function getConfig() external view returns (IProtocolConfig);

    /**
     * @notice Deposit a specified amount of the underlying asset into the vault.
     * @dev This function will convert the deposited assets into the corresponding bToken.
     * @param amount The amount of the underlying asset to deposit.
     * @return shareAmount The amount of vault shares minted for the deposit.
     */
    function deposit(uint256 amount) external returns (uint256 shareAmount);

    /**
     * @notice Withdraw a specified amount of the underlying asset from the vault.
     * @dev This function will convert the corresponding bToken back into the underlying asset.
     * @param amount The amount of vault shares to redeem.
     * @return withdrawAmount The amount of the underlying asset withdrawn.
     */
    function withdraw(uint256 amount) external returns (uint256 withdrawAmount);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
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


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

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
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
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
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
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

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Interface that must be implemented by smart contracts in order to receive
 * ERC-1155 token transfers.
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC-1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC-1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

/**
 * @title IBaseOracle
 * @author BlueberryProtocol
 * @notice Interface for a basic oracle that provides price data for assets.
 */
interface IBaseOracle {
    /**
     * @notice Event emitted when a new LP token is registered within its respective implementation.
     * @param token Address of the LP token being registered
     */
    event RegisterLpToken(address token);

    /**
     * @notice Fetches the price of the given token in USD with 18 decimals precision.
     * @param token Address of the ERC-20 token for which the price is requested.
     * @return The USD price of the given token, multiplied by 10**18.
     */
    function getPrice(address token) external view returns (uint256);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

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
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";


// ==== FILE: ? ====
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../utils/introspection/IERC165.sol";


