// SPDX-License-Identifier: MIT
/**
 _____
/  __ \
| /  \/ ___  _ ____   _____ _ __ __ _  ___ _ __   ___ ___
| |    / _ \| '_ \ \ / / _ \ '__/ _` |/ _ \ '_ \ / __/ _ \
| \__/\ (_) | | | \ V /  __/ | | (_| |  __/ | | | (_|  __/
 \____/\___/|_| |_|\_/ \___|_|  \__, |\___|_| |_|\___\___|
                                 __/ |
                                |___/
 */

/// @title Cvg-Finance - CvxAssetStakingService
/// @notice Specific deposits & withdraw functions designed for Convex liquid wrapper staking.
/// @dev Inherits from StakingServiceBase
pragma solidity ^0.8.0;

import "../StakingServiceBase.sol";

import "../../../interfaces/ICvgControlTowerV2.sol";
import "../../../interfaces/ICrvPoolPlain.sol";
import "../../../interfaces/ICommonStruct.sol";
import "../../../interfaces/Convex/ICvxAssetStakerBuffer.sol";
import "../../../interfaces/Convex/ICvxAssetWrapper.sol";
import "../../../interfaces/Convex/IAssetDepositor.sol";
import "../../../interfaces/Convex/ICvxAssetStakingService.sol";

contract CvxAssetStakingService is StakingServiceBase {
    /// @dev Used to calculate the percentage of fees
    uint256 private constant DENOMINATOR = 100_000;

    /// @dev Convex liquid locker of the base asset. i.e. cvxCRV
    IERC20 public cvxAsset;

    /// @dev Staker & Wrapper of the associated cvxAsset. i.e. stkCvxCrv
    ICvxAssetWrapper public cvxAssetWrapper;

    /// @dev Curve Stable Pool address of cvxAsset/Asset
    ICrvPoolPlain public curvePool;

    /// @dev Contract in charge to lock asset in cvxAsset.
    IAssetDepositor public assetDepositor;

    /// @dev Percentage of fee taken on a staking when the user doesn't propagate the staking on Convex.
    uint256 public depositFeeNoStakingPercentage;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      CONSTRUCTOR & INIT
  =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize function of the staking contract, can only be called once
     */
    function initialize(
        IERC20 _asset,
        IERC20 _cvxAsset,
        ICvxAssetWrapper _cvxAssetWrapper,
        ICrvPoolPlain _curvePool,
        IAssetDepositor _assetDepositor,
        ICvxRewardDistributor _cvxRewardDistributor,
        string memory _name,
        string memory _symbol,
        IStakingServiceBase.PoolEthInfo memory _poolEthInfo
    ) external initializer {
        name = _name;
        symbol = _symbol;

        asset = _asset;

        cvxAsset = _cvxAsset;

        curvePool = _curvePool;

        cvxAssetWrapper = _cvxAssetWrapper;

        assetDepositor = _assetDepositor;

        poolEthInfo = _poolEthInfo;

        decimals = 18;

        /// @dev Initialize internal cycle with the cycle from the control tower
        stakingCycle = cvgControlTower.cvgCycle();

        /// @dev To prevent the claim of CVX on the first Cycle of deployment.
        ///      Staked asset must be staked during a FULL cycle to be eligible to rewards
        cycleInfo[stakingCycle].isCvxProcessed = true;

        require(address(_cvxRewardDistributor) != address(0), "CVX_REWARD_DISTRIBUTOR");
        cvxRewardDistributor = _cvxRewardDistributor;

        address _treasuryDao = cvgControlTower.treasuryDao();
        require(_treasuryDao != address(0), "TREASURY_DAO_ZERO");
        owner = _treasuryDao;

        depositFeeNoStakingPercentage = 250;

        /// @dev Allows to stake cvxAsset from this contract on the stkCvxAsset of Convex
        _cvxAsset.approve(address(cvxAssetWrapper), type(uint256).max);

        /// @dev Allows to swap some Asset to cvxAsset on the stable pool
        _asset.approve(address(_curvePool), type(uint256).max);

        /// @dev Allows to swap some Asset to cvxAsset on the asset depositor of Convex
        _asset.approve(address(_assetDepositor), type(uint256).max);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER EXTERNAL
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Deposit an amount of asset in the Staking contract. The underlying is always the stkCvxAsset.
     *         Accepts staking with :
     *          - Asset       :  Call Convex Depositor or swap in the stable LP (regarding the peg) to convert asset into cvxAsset & Send it to the StakerBuffer.
     *          - cvxAsset    :  Send the cvxAsset directly to the StakerBuffer.
     *          - stkCvxAsset :  Send already stakedAsset to the StakerBuffer.
     * @dev Staking at cycle N implies that first rewards will be claimable at the beginning of cycle N+2, then every cycle.
     * @param amountIn              Amount of asset to process for staking
     * @param inTokenType           Type of the asset to input for staking
     * @param minCvxAssetAmountOut  Minimum of cvxAsset to get in the case we swap Asset for cvxAsset in the Stable LP
     * @param minAssetAmountOut     Minimum of asset to get in the case we swap ETH for asset in the ETH/Asset LP.
     * @param isLock                If true, Assets deposited will be automatically locked.
     * @param isStake               If true, stakes all cvxAssets of the contract in stkCvxAsset.
     */
    function deposit(
        uint256 amountIn,
        ICvxAssetStakingService.IN_TOKEN_TYPE inTokenType,
        uint256 minCvxAssetAmountOut,
        uint256 minAssetAmountOut,
        bool isLock,
        bool isStake
    ) external payable lockReentrancy {
        /// @dev Verify if deposits are paused
        require(!depositPaused, "DEPOSIT_PAUSED");

        /// @dev Memorize storage data
        ICvxAssetStakerBuffer _stakerBuffer = ICvxAssetStakerBuffer(address(buffer));
        uint256 cvxAssetStakedAmount;
        uint256 feeAmount;

        if (inTokenType == ICvxAssetStakingService.IN_TOKEN_TYPE.ETH) {
            require(msg.value != 0, "NO_ETH_AMOUNT");

            (cvxAssetStakedAmount, feeAmount) = _feeCalculator(
                _swapAssetToCvxAsset(
                    _convertEthToAsset(msg.value, minAssetAmountOut),
                    minCvxAssetAmountOut,
                    address(_stakerBuffer),
                    isLock
                ),
                isStake
            );
        }
        /// @dev Staking with asset => We need to convert it to cvxAsset
        else if (inTokenType == ICvxAssetStakingService.IN_TOKEN_TYPE.ASSET) {
            asset.transferFrom(msg.sender, address(this), amountIn);
            (cvxAssetStakedAmount, feeAmount) = _feeCalculator(
                _swapAssetToCvxAsset(amountIn, minCvxAssetAmountOut, address(_stakerBuffer), isLock),
                isStake
            );
        }
        /// @dev Staking with cvxAsset
        else if (inTokenType == ICvxAssetStakingService.IN_TOKEN_TYPE.CVX_ASSET) {
            cvxAsset.transferFrom(msg.sender, address(_stakerBuffer), amountIn);
            (cvxAssetStakedAmount, feeAmount) = _feeCalculator(amountIn, isStake);
        }
        /// @dev Staking with stkCvxCrv
        else {
            cvxAssetWrapper.transferFrom(msg.sender, address(_stakerBuffer), amountIn);
            cvxAssetStakedAmount = amountIn;
        }

        uint256 _cvgStakingCycle = stakingCycle;

        /// @dev Verify if the staked amount is > 0
        require(cvxAssetStakedAmount != 0, "DEPOSIT_LTE_0");

        /// @dev Update the CycleInfo & the TokenInfo for the next cycle
        _updateAmountStakedDeposit(cvxAssetStakedAmount, _cvgStakingCycle + 1);

        if (inTokenType != ICvxAssetStakingService.IN_TOKEN_TYPE.STK_CVX_ASSET) {
            _stakerBuffer.postStaking(feeAmount, isStake);
        }

        emit Deposit(msg.sender, _cvgStakingCycle, cvxAssetStakedAmount);
    }

    /**
     * @dev Swaps an amount of asset in cvxAsset either through a swap in the liquid pool or through the Convex Liquid Locker.
     * @param assetInAmount           Amount of asset to convert to cvxAsset.
     * @param minCvxAssetAmountOut    Minimum amount of asset to get through the swap on the stable pool. If it's 0, it'll pass directly through the Convex function, else through the stable pool from Curve.
     * @param receiver                Address of the receiver of the cvxAssets.
     * @param isLock                  Usefull only when we convert through the Convex function. Locks all Asset that are pending on Convex.
     * @return The amount of cvxAsset obtained through the conversion.
     */
    function _swapAssetToCvxAsset(
        uint256 assetInAmount,
        uint256 minCvxAssetAmountOut,
        address receiver,
        bool isLock
    ) internal returns (uint256) {
        uint256 cvxAssetAmountObtained;
        /// @dev Swaps asset to cvxAsset in the Curve LP
        if (minCvxAssetAmountOut != 0) {
            cvxAssetAmountObtained = curvePool.exchange(0, 1, assetInAmount, minCvxAssetAmountOut, receiver);
        }
        /// @dev Deposit through asset depositor, is not always 1:1 so better to do the delta with balance to guess the cvxAmount minted
        else {
            IERC20 _cvxAsset = cvxAsset;
            cvxAssetAmountObtained = _cvxAsset.balanceOf(address(this));
            assetDepositor.deposit(assetInAmount, isLock);
            cvxAssetAmountObtained = _cvxAsset.balanceOf(address(this)) - cvxAssetAmountObtained;
            _cvxAsset.transfer(receiver, cvxAssetAmountObtained);
        }

        return cvxAssetAmountObtained;
    }

    /**
     * @dev Computes and send fees to the convex treasury in the case the user is not staking his cvxAssets.
     * @param cvxAssetAmountWithoutFees   Amount of cvxAsset to potentially stake
     * @param isStake                     If true, no fees are taken, else a fee is taken and sent to the Convex Treasury.
     */
    function _feeCalculator(uint256 cvxAssetAmountWithoutFees, bool isStake) internal view returns (uint256, uint256) {
        if (!isStake) {
            uint256 feeAmount = (cvxAssetAmountWithoutFees * depositFeeNoStakingPercentage) / DENOMINATOR;
            return (cvxAssetAmountWithoutFees - feeAmount, feeAmount);
        }
        return (cvxAssetAmountWithoutFees, 0);
    }

    /**
     * @notice Withdraw stakingAsset (stkCvxAsset or cvxAsset) from the contract and convert it to the asset input by the user.
     *         Removing rewards before the end of a cycle leads to the loss of all accumulated rewards during this cycle.
     * @dev Withdrawing always removes first from the staked amount not yet eligible to rewards.
     * @param amount            Amount of stakingAsset to withdraw
     * @param outTokenType      Determines if the withdrawn asset is a staked asset (stkCvxAsset), cvxAsset or an Asset
     * @param minAssetAmountOut Used only if asset returned selectionned is asset. It's the minimum amount accepted during the swap cvxAsset => Asset.
     */
    function withdraw(
        uint256 amount,
        ICvxAssetStakingService.OUT_TOKEN_TYPE outTokenType,
        uint256 minAssetAmountOut
    ) external {
        require(amount != 0, "WITHDRAW_LTE_0");

        uint256 _cvgStakingCycle = stakingCycle;

        /// @dev Update the CycleInfo & the TokenInfo for the current & next cycle
        _updateAmountStakedWithdraw(amount, _cvgStakingCycle);

        ICvxAssetStakerBuffer(address(buffer)).withdraw(amount, outTokenType, msg.sender, minAssetAmountOut);

        emit Withdraw(msg.sender, _cvgStakingCycle, amount);
    }

    /**
     * @notice Update the percentage fee taken when a user is staking cvxAsset on Convergence without propagating the staking on Convex.
     * @param newPercentage New fee percentage
     */
    function updateNoStakingFeePercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage <= 2_000, "PERCENTAGE_FEE_TOO_HIGH");
        depositFeeNoStakingPercentage = newPercentage;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEW
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Fetches all data needed for the NFT logo being displayed
     *  @param account of the position to get informations
     */
    function stakingInfo(address account) public view returns (ICvxStakingPositionService.StakingInfo memory) {
        uint256 pending = accountInfoByCycle[stakingCycle + 1][account].pendingStaked;
        (uint256 _cvgClaimable, ICommonStruct.TokenAmount[] memory _cvxRewardsClaimable) = getAllClaimableAmounts(
            account
        );
        return (
            ICvxStakingPositionService.StakingInfo({
                account: account,
                symbol: symbol,
                pending: pending,
                totalStaked: balanceOf(account) - pending,
                cvgClaimable: _cvgClaimable,
                cvxClaimable: _cvxRewardsClaimable
            })
        );
    }
}
