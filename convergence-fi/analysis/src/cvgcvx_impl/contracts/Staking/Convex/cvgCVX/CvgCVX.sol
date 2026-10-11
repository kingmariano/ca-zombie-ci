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
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../../../interfaces/ICvgControlTowerV2.sol";
import "../../../interfaces/Convex/ICvxLocker.sol";
import "../../../interfaces/Convex/IDelegateRegistry.sol";
import "../../../interfaces/Convex/ICVX1.sol";
import "../../../interfaces/ICrvPoolPlain.sol";
import "../../../interfaces/Convex/ICvxCrvRewards.sol";
import "../../../interfaces/Convex/ICvxAssetWrapper.sol";

/// @title Cvg Finance - CvgCVX
/// @notice Acts as an ERC20 for cvgCVX, Locker and Buffer
contract CvgCVX is ERC20Upgradeable, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev Convergence control tower
    ICvgControlTowerV2 public constant cvgControlTower = ICvgControlTowerV2(0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7);

    /// @dev Convergence Rewards
    ICvgRewards public constant cvgRewards = ICvgRewards(0xa044fd2E8254eC5DE93B15b8B27d005899579109);

    /// @dev Locking Service
    ILockingPositionService public constant lockingPositionService =
        ILockingPositionService(0xc8a6480ed7C7B1C401061f8d96bE7De6f94D3E60);

    /// @dev Convergence token
    ICvg public constant CVG = ICvg(0x97efFB790f2fbB701D88f89DB4521348A2B77be8);

    /// @dev Convex token
    IERC20 public constant CVX = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    /// @dev Curve token
    IERC20 public constant CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

    /// @dev FraxShare token
    IERC20 public constant FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);

    /// @dev Convex locker contract
    ICvxLocker public constant CVX_LOCKER = ICvxLocker(0x72a19342e8F1838460eBFCCEf09F6585e32db86E);

    /// @dev CvxCRV Wrapper contract
    ICvxCrvRewards public constant CVX_CRV_REWARDS = ICvxCrvRewards(0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e);

    uint256 private constant DENOMINATOR = 100000;

    /// @notice Receiver of all Convex rewards.
    ICvxRewardDistributor public cvxRewardDistributor;

    /// @notice cvgCVX/CVX1 stable pool contract on Curve
    ICrvPoolPlain public poolCvgCvxCvx1;

    /// @dev Convex delegate registry contract
    IDelegateRegistry public cvxDelegateRegistry;

    /// @dev CVX1 token
    ICVX1 public cvx1;

    /// @dev Staking contract address
    address public cvxStakingPositionService;

    /// @dev Amount of CVX pending to be locked
    uint256 public cvxToLock;

    /// @dev Represents the fees taken when minting cvgCVX without locking
    uint256 public mintFees;

    /// @notice Contains all rewarded ERC20 and associated fees taken
    ICvxAssetStakerBuffer.CvxRewardConfig[] public rewardTokensConfigs;

    /// @dev Max amount of CvgCvx mintable
    uint256 public capCvgCvx;

    /// @dev Amount of CvgCvx minted through the Cvx Rush program
    uint256 public cvgCvxAlreadyMintedWithRush;

    /// @dev Cvx Rush Indexes Info
    CvxRushIndexInfo[] public capCVXRushForIndex;

    mapping(IERC20 => uint256) public withdrawableFees; // TokenAddress => amount of Fees

    mapping(address => bool) public isSpecialMinter;

    struct CvxRushIndexInfo {
        uint128 cap;
        uint128 ratio;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INIT
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(
        string memory _name,
        string memory _symbol,
        IDelegateRegistry _cvxDelegateRegistry,
        ICVX1 _cvx1,
        CvxRushIndexInfo[] calldata cvxRushIndexInfos
    ) external initializer {
        __ERC20_init(_name, _symbol);

        capCvgCvx = 1 ether;
        mintFees = 50; // 0.5%
        cvxDelegateRegistry = _cvxDelegateRegistry;
        cvx1 = _cvx1;

        CVX.approve(address(CVX_LOCKER), type(uint256).max);
        CVG.approve(address(lockingPositionService), type(uint256).max);

        address treasuryDao = cvgControlTower.treasuryDao();
        require(treasuryDao != address(0), "TREASURY_DAO");
        _transferOwnership(treasuryDao);

        _setIndexCvxRush(cvxRushIndexInfos);

        isSpecialMinter[address(_cvx1)] = true;

        rewardTokensConfigs.push(
            ICvxAssetStakerBuffer.CvxRewardConfig({
                token: IERC20(address(this)),
                processorFees: 1_000,
                convexTreasury: 0
            })
        );
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        USER FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *   @notice        Mint cvgCVX at ratio 1:1 in exchange of CVX. All CVX given will be locked for ever in vlCVX
     *   @param to      Receiver of the minted cvgCVX
     *   @param amount  Amount of CVX transferred that will be locked in vlCVX.
     *   @param isLock  Determines if received CVX will be automatically locked or not. When false, a fee is taken.
     **/
    function mint(address to, uint256 amount, bool isLock) public returns (uint256) {
        return _mintFrom(msg.sender, to, amount, isLock);
    }

    /**
     *   @notice        Special mint function only callable by a special minter
     *   @param from    Address from where we take the CVX, if address(0),
     *   @param to      Receiver of the minted cvgCVX
     *   @param amount  Amount of CVX transferred that will be locked in vlCVX.
     *   @param isLock  Determines if received CVX will be automatically locked or not. When false, a fee is taken.
     **/
    function mintFrom(address from, address to, uint256 amount, bool isLock) public returns (uint256) {
        require(isSpecialMinter[msg.sender], "CALLER_NOT_MINTER");
        return _mintFrom(from, to, amount, isLock);
    }

    /**
     *   @dev Mint an amount of cvgCVX to the account in exchange of the same amount in CVX.
     *           All CVX will be locked into vlCVX.
     *   @param from    Address from where we take the CVX
     *   @param to      Receiver of the minted cvgCVX
     *   @param amount  Amount of CVX to send from the msg.sender in exchange of cvgCVX.
     *   @param isLock  Determines if received CVX will be automatically locked or not. When false, a fee is taken.
     **/
    function _mintFrom(address from, address to, uint256 amount, bool isLock) internal returns (uint256) {
        uint256 amountToMint = amount;
        if (!isLock) {
            /// @dev Compute fees when not choosing to lock
            uint256 feesAmount = (amount * mintFees) / 10_000;
            /// @dev Removes the fees in CVX from the amount of cvgCVX to give to the account
            amountToMint -= feesAmount;
            /// @dev Increment the withdrawable fees in CVX
            withdrawableFees[CVX] += feesAmount;
        }
        /// @dev Verify that the new totalSupply of cvgCVX is not exceeding the cap
        require(totalSupply() + amountToMint <= capCvgCvx, "CAP_CVG_CVX_REACHED");

        if (from != address(0)) {
            /// @dev Transfer CVX from user to this contract
            CVX.transferFrom(from, address(this), amount);
        }

        /// @dev Update the amount of CVX to lock from this contract
        cvxToLock += amountToMint;

        /// @dev Locks all CVX of the contract in vlCVX contract
        if (isLock) {
            lockCvx();
        }

        _mint(to, amountToMint);

        return amountToMint;
    }

    /**
     * @notice Burns an amount of cvgCVX to the caller of this function.
     * @param amount to burn to the msg.sender
     **/
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Converts atomically an amount of cvgCVX into CVX passing through the stable LP cvgCVX/CVX1.
     * @param  receiver      Receiver of the CVX
     * @param  cvgCvxAmount  Amount of cvgCVX to exchange for CVX
     * @param  minCvxAmount  Minimum amount of CVX to receive
     **/
    function convertCvgCVXToCVX(address receiver, uint256 cvgCvxAmount, uint256 minCvxAmount) external {
        /// @dev Transfers the cvgCVX to prepare for the swap
        _transfer(msg.sender, address(this), cvgCvxAmount);

        /// @dev Exchange the cvgCVX against CVX1 & Burns the CVX1 and transfer the equivalent in CVX to the receiver
        cvx1.withdraw(poolCvgCvxCvx1.exchange(1, 0, cvgCvxAmount, minCvxAmount, address(this)), receiver);
    }

    /**
     * @notice Converts atomically an amount of CVX into cvgCVX passing through the stable LP cvgCVX/CVX1.
     * @param  receiver            Receiver of the cvgCVX
     * @param  cvxAmountIn         Amount of CVX to exchange for cvgCVX
     * @param  minCvgCvxAmountOut  Minimum amount of cvgCVX to receive
     **/
    function convertCvxToCvgCVXWithSwap(address receiver, uint256 cvxAmountIn, uint256 minCvgCvxAmountOut) external {
        /// @dev Transfers the CVX to prepare for the swap
        cvx1.mintFrom(msg.sender, address(this), cvxAmountIn);

        /// @dev Exchange the CVX1 against cvgCVX
        poolCvgCvxCvx1.exchange(0, 1, cvxAmountIn, minCvgCvxAmountOut, receiver);
    }

    /**
     * @notice Mint cvgCVX in exchange of CVX with an incentivization in veCVG/mgCVG.
     * @param tokenId     Id of the locking position, if 0 => We mint the lockingPosition
     * @param cvxAmount   Amount of CVX to give in exchange of cvgCVX.
     * @param to          Receiver of the cvgCVX
     * @param cvgLockReceiver    Receiver of the lockingPosition
     * @param isLock      Determines if received CVX will be automatically locked or not
     **/
    function mintCVXRush(
        uint256 tokenId,
        uint128 cvxAmount,
        address to,
        address cvgLockReceiver,
        bool isLock
    ) external returns (uint256) {
        /// @dev Mints cvgCVX to the to
        uint256 cvgCVXAmount = mint(to, cvxAmount, isLock);
        /// @dev Compute the amount of CVG in incentive to lock
        (uint128 cvgIncentive, uint256 cvgCvxAmountUsedForBonus) = _calculateCvgIncentive(cvgCVXAmount);
        /// @dev
        require(cvgCvxAmountUsedForBonus == 0, "CVX_NOT_FULLY_DISTRIB");
        require(cvgIncentive != 0, "NO_CVG_INCENTIVE");
        cvgCvxAlreadyMintedWithRush += cvgCVXAmount;

        uint256 cycle = cvgRewards.getCycleLocking(block.timestamp);
        /// @dev If the tokenId is 0, we create a new position
        if (tokenId == 0) {
            /// @dev Computation of the maximum lock duration
            uint256 lockDuration = (((96 + cycle) / 12) * 12) - cycle;
            lockingPositionService.mintPosition(uint24(lockDuration), cvgIncentive, 0, cvgLockReceiver, true);
        }
        /// @dev else, we are incrementing an already existing position
        else {
            ILockingPositionService.LockingPosition memory lockingPosition = lockingPositionService.lockingPositions(
                tokenId
            );
            /// @dev The position has to be :

            /// @dev - Full ve/mg
            require(lockingPosition.ysPercentage == 0, "NO_YS_POSITION");
            /// @dev - Dont be expired
            require(lockingPosition.lastEndCycle >= cycle, "LOCK_EXPIRED");
            /// @dev - Has a current duration >= 84 cycles
            require(lockingPosition.lastEndCycle - cycle >= 84, "LOCKING_TOO_SHORT");
            lockingPositionService.increaseLockAmount(tokenId, cvgIncentive, cvgLockReceiver);
        }

        return cvgCVXAmount;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        VIEW FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function getAllCapCVXRush() external view returns (CvxRushIndexInfo[] memory) {
        return capCVXRushForIndex;
    }

    function getCvxRushAmounts(uint256 amountCvx, bool isLock) external view returns (uint256, uint256) {
        if (!isLock) {
            /// @dev Compute fees when not choosing to lock
            amountCvx -= (amountCvx * mintFees) / 10_000;
        }
        (uint128 cvgIncentive, uint256 cvgCvxAmountUsedForBonus) = _calculateCvgIncentive(amountCvx);
        if (cvgCvxAmountUsedForBonus != 0) {
            return (0, 0);
        }

        return (cvgIncentive, amountCvx);
    }

    function _calculateCvgIncentive(uint256 _amountCvx) internal view returns (uint128, uint256) {
        uint256 _numberOfCvxRushIndex = capCVXRushForIndex.length;
        uint128 cvgIncentive;
        uint256 _cvgCvxAlreadyMintedWithRush = cvgCvxAlreadyMintedWithRush;
        uint256 cvgCvxAmountUsedForBonus = _amountCvx;
        /// @dev We iterate through all the index steps
        for (uint256 i; i < _numberOfCvxRushIndex; ) {
            /// @dev Retrieve the cap in cvgCVX
            uint256 currentCap = capCVXRushForIndex[i].cap;

            if (_cvgCvxAlreadyMintedWithRush < currentCap) {
                uint256 restToMintForIndex = currentCap - _cvgCvxAlreadyMintedWithRush;
                if (restToMintForIndex >= cvgCvxAmountUsedForBonus) {
                    cvgIncentive += uint128(cvgCvxAmountUsedForBonus * capCVXRushForIndex[i].ratio) / 1000;
                    _cvgCvxAlreadyMintedWithRush += cvgCvxAmountUsedForBonus;
                    delete cvgCvxAmountUsedForBonus;
                    break;
                } else {
                    cvgCvxAmountUsedForBonus -= restToMintForIndex;
                    cvgIncentive += uint128(restToMintForIndex * capCVXRushForIndex[i].ratio) / 1000;
                    _cvgCvxAlreadyMintedWithRush += restToMintForIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        return (cvgIncentive, cvgCvxAmountUsedForBonus);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        PROCESS FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Locks all balance of CVX received during the conversion of cvgCVX in vlCVX.
     * @dev    Callable by anyone.
     **/
    function lockCvx() public {
        CVX_LOCKER.lock(address(this), cvxToLock, 0);
        cvxToLock = 0;
    }

    /**
     * @notice Relock all unlockable CVX to vlCVX
     **/
    function relockUnlockableCVX() public onlyOwner {
        CVX_LOCKER.processExpiredLocks(true);
    }

    /**
     * @notice Only callable by the cvgCVX staking contract during the processCvxRewards, transfers ERC20 tokens to the reward distributor.
     *         This process is incentivized so that the user who initiated it receives a percentage of each reward token.
     * @param processor address of the processor
     * @return Array of TokenAmount, Values of this array are registered in the Staking contract and linked to the processed cycle
     */
    function pullRewards(address processor) external returns (ICommonStruct.TokenAmount[] memory) {
        require(msg.sender == cvxStakingPositionService, "NOT_CVG_CVX_STAKING");

        uint256 rewardLength = rewardTokensConfigs.length;
        address rewardReceiver = address(cvxRewardDistributor);

        ICommonStruct.TokenAmount[] memory cvxRewardAssets = new ICommonStruct.TokenAmount[](rewardLength);
        uint256 counterDelete;

        for (uint256 i; i < rewardLength; ) {
            ICvxAssetStakerBuffer.CvxRewardConfig memory rewardConfiguration = rewardTokensConfigs[i];
            uint256 withdrawableFeeAmount = withdrawableFees[rewardConfiguration.token];
            uint256 rewardsAvailable = rewardConfiguration.token.balanceOf(address(this)) - withdrawableFeeAmount;

            /// @dev if reward token is CVX, remove the amount of CVX to lock from the rewards
            if (rewardConfiguration.token == CVX) {
                rewardsAvailable = rewardsAvailable - cvxToLock;
            }

            uint256 processorFees = (rewardsAvailable * rewardConfiguration.processorFees) / DENOMINATOR;
            uint256 convexTreasury = (rewardsAvailable * rewardConfiguration.convexTreasury) / DENOMINATOR;
            uint256 amountToStakers = rewardsAvailable - convexTreasury - processorFees;

            if (amountToStakers != 0) {
                rewardConfiguration.token.safeTransfer(rewardReceiver, amountToStakers);
                cvxRewardAssets[i - counterDelete] = ICommonStruct.TokenAmount({
                    token: rewardConfiguration.token,
                    amount: amountToStakers
                });
            }

            if (processorFees != 0) {
                rewardConfiguration.token.safeTransfer(processor, processorFees);
            }

            if (convexTreasury != 0) {
                withdrawableFees[rewardConfiguration.token] = withdrawableFeeAmount + convexTreasury;
            }

            if (rewardsAvailable == 0) {
                unchecked {
                    ++counterDelete;
                }
            }

            unchecked {
                ++i;
            }
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(cvxRewardAssets, sub(mload(cvxRewardAssets), counterDelete))
        }

        return cvxRewardAssets;
    }

    function getRewardTokensConfig() external view returns (ICvxAssetStakerBuffer.CvxRewardConfig[] memory) {
        return rewardTokensConfigs;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER FUNCTIONS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Delegates vlCVX voting power to another address.
     * @param id Snapshot ID (cvx.eth)
     * @param account address of the delegatee
     **/
    function delegate(bytes32 id, address account) external onlyOwner {
        cvxDelegateRegistry.setDelegate(id, account);
    }

    /**
     * @notice Clear voting power delegation
     * @param id Snapshot ID (cvx.eth)
     **/
    function clearDelegate(bytes32 id) external onlyOwner {
        cvxDelegateRegistry.clearDelegate(id);
    }

    /**
     * @notice Method used to transfer tokens received on this contract.
     * @dev Callable by the owner only.
     * @param tokens Address of each token
     **/
    function recoverTokens(IERC20[] calldata tokens) external onlyOwner {
        uint256 rewardTokensConfigsLength = rewardTokensConfigs.length;
        address convexTreasury = cvgControlTower.convexTreasury();

        for (uint256 i; i < tokens.length; ) {
            IERC20 _token = tokens[i];
            require(address(_token) != address(this), "CVGCVX_CANT_BE_RECOVERED");

            for (uint256 j; j < rewardTokensConfigsLength; ) {
                require(address(_token) != address(rewardTokensConfigs[j].token), "REWARD_TOKEN_CANT_BE_RECOVERED");
                unchecked {
                    ++j;
                }
            }

            /// @dev Nominal case
            if (_token != CVX) {
                _token.transfer(convexTreasury, _token.balanceOf(address(this)));
            }
            /// @dev If the token to recover is CVX, we need to remove the withdrawableFees and the cvxToLock
            else {
                _token.transfer(convexTreasury, _token.balanceOf(address(this)) - withdrawableFees[CVX] - cvxToLock);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Method used to transfer tokens received on this contract.
     * @dev Callable by the owner only.
     * @param tokens Address of each token
     **/
    function withdrawFees(IERC20[] calldata tokens) external onlyOwner {
        address convexTreasury = cvgControlTower.convexTreasury();
        for (uint256 i; i < tokens.length; ) {
            /// @dev Gas saving by letting 1 here
            uint256 withdrawableFeeAmount = withdrawableFees[tokens[i]] - 1;
            require(withdrawableFeeAmount != 0, "NO_FEE_TO_WITHDRAW");

            tokens[i].transfer(convexTreasury, withdrawableFeeAmount);
            withdrawableFees[tokens[i]] = 1;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Update the max totalSupply of cvgCVX
     * @dev Callable by the owner only.
     * @param _capCvgCvx New cvgCVX max totalSupply
     **/
    function setCapCvgCvx(uint256 _capCvgCvx) external onlyOwner {
        capCvgCvx = _capCvgCvx;
    }

    /**
     * @notice Update the cvxRewardDistributor
     * @dev Callable by the owner only.
     * @param _cvxRewardDistributor New cvxRewardDistributor
     **/
    function setCvxRewardDistributor(ICvxRewardDistributor _cvxRewardDistributor) external onlyOwner {
        cvxRewardDistributor = _cvxRewardDistributor;
    }

    /**
     * @notice Update cvxRush indexes
     * @dev Callable by the owner only.
     * @param cvxRushIndexInfos New indexes for cvx rush
     **/
    function setIndexCvxRush(CvxRushIndexInfo[] calldata cvxRushIndexInfos) external onlyOwner {
        _setIndexCvxRush(cvxRushIndexInfos);
    }

    function _setIndexCvxRush(CvxRushIndexInfo[] calldata cvxRushIndexInfos) internal {
        //clean array before all
        delete capCVXRushForIndex;

        for (uint256 i; i < cvxRushIndexInfos.length; ) {
            capCVXRushForIndex.push(cvxRushIndexInfos[i]);
            if (i != 0) {
                require(cvxRushIndexInfos[i].cap > cvxRushIndexInfos[i - 1].cap, "WRONG_CAP");
                require(cvxRushIndexInfos[i].ratio < cvxRushIndexInfos[i - 1].ratio, "WRONG_RATIO");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Update the cvx delegate registry in case it changes
     * @dev Callable by the owner only.
     * @param delegateRegistry New vlCVX delegate registry
     **/
    function setCvxDelegateRegistry(IDelegateRegistry delegateRegistry) external onlyOwner {
        cvxDelegateRegistry = delegateRegistry;
    }

    /**
     * @notice Update the staking service of cvgCVX
     * @dev Callable by the owner only.
     * @param _cvxStakingPositionService New staking position service
     **/
    function setCvxStakingPositionService(address _cvxStakingPositionService) external onlyOwner {
        cvxStakingPositionService = _cvxStakingPositionService;
        isSpecialMinter[_cvxStakingPositionService] = true;
    }

    /**
     * @notice Set a new Convex reward pool.
     * @dev It removes the allowance of CVX to the previous contract.
     * @param _poolCvgCvxCvx1 Address of the new stable pool.
     */
    function setPoolCvgCvxCvx1AndApprove(ICrvPoolPlain _poolCvgCvxCvx1) external onlyOwner {
        if (address(poolCvgCvxCvx1) != address(0)) {
            cvx1.approve(address(poolCvgCvxCvx1), 0);
            _approve(address(this), address(poolCvgCvxCvx1), 0);
        }
        cvx1.approve(address(_poolCvgCvxCvx1), type(uint256).max);
        _approve(address(this), address(_poolCvgCvxCvx1), type(uint256).max);

        poolCvgCvxCvx1 = _poolCvgCvxCvx1;
    }

    /**
     * @notice Update mint fees that are taken when deposited CVX won't be directly locked.
     * @param _fees percentage of fees to send to Treasury Fees
     **/
    function setMintFees(uint256 _fees) external onlyOwner {
        /// @dev maximum allowed: 2%
        require(_fees <= 200, "FEES_TOO_BIG");
        mintFees = _fees;
    }

    /**
     * @notice Setup the list of rewards and fees from Convex that the contract distributes as reward
     * @dev Callable only by the contract owner.
     * @param _rewardTokensConfigs Reward config with token and percentages
     */
    function setRewardTokensConfigs(
        ICvxAssetStakerBuffer.CvxRewardConfig[] calldata _rewardTokensConfigs
    ) external onlyOwner {
        delete rewardTokensConfigs;

        for (uint256 i; i < _rewardTokensConfigs.length; ) {
            rewardTokensConfigs.push(_rewardTokensConfigs[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Add a new reward to token configuration
     * @dev Callable only by the contract owner.
     * @param _rewardTokenConfiguration New token configuration
     */
    function addRewardTokenConfig(
        ICvxAssetStakerBuffer.CvxRewardConfig calldata _rewardTokenConfiguration
    ) external onlyOwner {
        rewardTokensConfigs.push(_rewardTokenConfiguration);
    }

    /**
     * @notice Toggle an address to be special minter to be able to call the mintFrom function
     * @dev Callable only by the contract owner.
     * @param specialMinter Address that will be toggled as special minter
     */
    function toggleIsSpecialMinter(address specialMinter) external onlyOwner {
        isSpecialMinter[specialMinter] = !isSpecialMinter[specialMinter];
    }

    /**
     * @notice Withdraw cvxCRV staked on the cvxCRV staking rewards.
     * @dev Callable only by the contract owner.
     * @param amount Amount of cvxCRV to withdraw
     * @param claim  Claim rewards coming from the cvxCRV staking
     */
    function withdrawCvxCrv(uint256 amount, bool claim) external onlyOwner {
        if (amount != 0) {
            CVX_CRV_REWARDS.withdraw(amount, claim);
        } else {
            CVX_CRV_REWARDS.withdrawAll(claim);
        }
    }
}
