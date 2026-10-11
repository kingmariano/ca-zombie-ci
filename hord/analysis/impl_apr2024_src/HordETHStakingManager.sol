pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import "./IStakingConfiguration.sol";
import "./IHordCongressMembersRegistry.sol";
import "./IBeaconDeposit.sol";
import "./HETH.sol";
import "./IHordETHStakingWithdrawalManager.sol";
import "./IDubUniswapV3.sol";
import "./IWrappedToken.sol";
import "./AggregatorV3Interface.sol";
import "./IWstETH.sol";
import "./ISSVNetwork.sol";
import "./IHordRestakingManager.sol";

/**
 * HordETHStakingManager contract.
 * @author Srdjan Simonovic
 * Date created: 08.11.22.
 * Github: s2imonovic
 */
contract HordETHStakingManager is HETH {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ------------------------ DEPRECATED ------------------------
    uint256 public totalETHDeposited;
    // Represent amount of ETH in validators
    uint256 public totalBalanceETHInValidators;
    // Represent total rewards collected
    uint256 public totalRewardsCollected;
    // ------------------------ DEPRECATED ------------------------
    uint256 public totalHETHMinted;
    // ------------------------ DEPRECATED ------------------------
    uint256 public numberOfUsers;
    // Represent last rewards for fee calculation
    uint256 public lastRewardsForFeeCalc;
    // Represent total fees accounted in ETH
    uint256 public totalFeesAccountedInETH;
    // Represent total fees minted in HETH
    uint256 public totalFeesMintedInHETH;
    // represent last execLayerRewardsForFeeCalc;
    uint256 public lastExecLayerRewardsForFeeCalc;
    // state for total exec layer rewards;
    uint256 public totalExecLayerRewards;

    // Represent instance of HordCongressMembersRegistry contract
    IHordCongressMembersRegistry public hordCongressMembersRegistry;
    // Represent instance of BeaconDeposit contract
    IBeaconDeposit public beaconDeposit;
    // Represent instance of StakingConfiguration contract
    IStakingConfiguration public stakingConfiguration;
    // ------------------------ DEPRECATED ------------------------
    mapping(address => User) public users;
    // Represent user struct
    struct User {
        uint256 amountDeposited;
        // will be update later
        uint256 rewardsEarned;
    }

    // ---------------------- States before first upgrade ----------------------

    // Mapping pub-keys of validators to is initialized bool
    mapping(bytes => bool) public isValidatorInitialized;
    // Represent instance of HordETHStakingWithdrawal contract
    IHordETHStakingWithdrawalManager public hordETHStakingWithdrawalManager;

    // ---------------------- States before second upgrade ----------------------

    // Represent dub contract instance for uniswapV3 integration
    IDubUniswapV3 public dubUniswapV3;
    // Represent WETH token address
    address public WETH;
    // Represent LSD token struct
    struct LSDTokenInfo {
        bool isWhitelisted;
        uint256 totalTokenBalance;
        address poolAddress;
    }
    // Represent LSD token to totalBalance of that token in pool
    mapping(address => LSDTokenInfo) public lsdTokenToInfo;
    // Represent all LSD tokens array
    address [] private lsdTokens;
    // Represents uniswap v3 SwapRouter contract address
    address public swapRouter;
    // NOTE: in case of stETH, the poolAddress in the lsdTokenInfo will be actually the ChainLink price aggregator for stETH as we don't actually swap it, but wrap it
    // Represents stETH token address
    address public stETH;
    // Represents wstETH token address
    address public wstETH;
    // Represent instance of ssvNetwork contract
    ISSVNetwork public ssvNetwork;
    // Represent instance of ssvNetwork token
    IERC20 public ssvToken;
    // Represents time when stats were updated last time
    uint256 public lastTimeUpdatedStats;
    // Represent contract balance in the moment when the stats were updated last time
    uint256 public totalETHOnContractRecorded;
    // ETH deposited since stats were updated last time
    uint256 public amountETHDepositedInMeantime;
    // ETH used to paying debts in meantime
    uint256 public amountETHUsedToPayDebtInMeantime;
    // Mapping pub-keys of SSV validators to is initialized bool
    mapping(bytes => bool) public isSSVValidatorInitialized;
    // Represents instance of HordRestakingManager contract
    IHordRestakingManager public hordRestakingManager;

    //Events
    event Deposit(address account, uint256 amountDeposited);
    event LaunchNewValidator(address account, uint256 amountWithdrawn);
    event HETHMinted(address account, uint256 amountHETH);
    event FeeCollected(
        address account,
        uint256 amountHETH,
        uint256 amountETHForMintingCalc,
        uint256 diffExecLayerRewardsForFeelCalc
    );
    event StakingStatsUpdated(
        uint256 newRewardsAmount,
        uint256 newTotalETHBalanceInValidators,
        uint256 newTotalExecutionLayerRewards
    );
    event LSDTokenWhitelisted(address tokenAddress, address poolAddress);
    event LSDTokenDeposited(address account, address tokenAddress, uint256 amountDeposited, uint256 hethMinted);
    event LSDTokenSwap(address tokenIn, uint256 amountIn, uint256 amountOut);
    event LSDTokenRemoved(address tokenAddress, bool isFreezing);
    event StETHWrapped(uint256 amountReceived, address tokenAddress, uint256 amountWrapped);


    /**
         * @dev     Callable only by HordETHStakingWithdrawalManager contract
         * error-msg  ROH - Restricted only to hordETHStakingWithdrawalManager.
     */
    modifier onlyHordETHStakingWithdrawalManager {
        require(
            address(hordETHStakingWithdrawalManager) == msg.sender,
            "ROH"
        );
        _;
    }

    /**
         * @dev
         * error-msg  ODC - Only direct calls.
     */
    modifier onlyDirectCalls {
        require(msg.sender == tx.origin, "ODC");
        _;
    }

    /**
         * @notice          Fallback function to receive ETH
     */
    receive() external payable {}

    /**
        * @notice       Function sets restaking manager address.
        * @dev          Callable only by HordCongress.
     */
    function setRestakingManagerAddress(
        address _restakingManager
    )
    external
    onlyHordCongress
    {
        require(_restakingManager != address(0), "0x0");
        hordRestakingManager = IHordRestakingManager(_restakingManager);
    }

    /**
         * @notice          Burn function, is wrapper for burn function.
         * @dev             Callable only by HordETHStakingWithdrawalManager contract.
         * @param           account is address for which HETH tokens will be burned
         * @param           amount is number of HETH tokens which will be burned
     */
    function burn(
        address account,
        uint256 amount
    )
    external
    whenNotPaused
    onlyHordETHStakingWithdrawalManager
    {
        _burn(account, amount);
    }

    /**
         * @notice          AppropriateReservesToPayDebt function moves ETH from HordETHStakingManager contract to
                            HordETHStakingWithdrawalManager contract in order to close debt to users. This function
                            should be called only when ETH from closed validators are back.
         * @dev             Callable only by maintainer.
         * @param           amountETHToSend is ETH amount that should be sent to the HordETHStakingWithdrawalManager
                            contract and with which the users should be paid back.
         * error-msg        DHF - dont have enough funds.
     */
    function appropriateReservesToPayDebt(
        uint256 amountETHToSend,
        uint256 startIndex,
        uint256 endIndex
    )
    external
    onlyMaintainer
    {
        require(amountETHToSend <= address(this).balance, "DHF");

        amountETHUsedToPayDebtInMeantime = amountETHUsedToPayDebtInMeantime.add(amountETHToSend);

        hordETHStakingWithdrawalManager.payOfDebtFromValidatorsFunds{
                value: amountETHToSend
            }(startIndex, endIndex);
    }

    /**
         * @notice          MoveETHToAssuredBalance function moves ETH from HordETHStakingManager contract to assured
                            claims balance in HordETHStakingWithdrawalManager contract.
         * @dev             Callable only by HordETHStakingWithdrawalManager contract.
         * @param           amountETHToSend is ETH amount that should be sent to the HordETHStakingWithdrawalManager
                            contract and with which the assured claims balance will be increased.
     */
    function moveETHToAssuredBalance(
        uint256 amountETHToSend
    )
    external
    whenNotPaused
    onlyHordETHStakingWithdrawalManager
    {
        amountETHUsedToPayDebtInMeantime = amountETHUsedToPayDebtInMeantime.add(amountETHToSend);

        hordETHStakingWithdrawalManager.receiveETHInAssuredBalance{
                value: amountETHToSend
            }();
    }

    /**
        * @notice   Function allows address with permission to pause the contract.
        * @dev      Callable only by HordCongress member or maintainer.
        * error-msg OWP - Only members with permission.
     */
    function pause()
    external
    {
        require(
            hordCongressMembersRegistry.isMember(msg.sender) || maintainersRegistry.isMaintainer(msg.sender),
            "OWP"
        );
        _pause();
    }

    /**
        * @notice  Function allows multi-sig contract to unpause the contract.
        * @dev     Callable only by HordCongress multi-sig contract.
     */
    function unpause()
    external
    onlyHordCongress
    {
        _unpause();
    }

    /**
        * @notice       Function whitelist ERC-20 token address.
        * @dev          Callable only by HordCongress.
        * error-msg     0x0 - Address can not be 0.
        * error-msg     NWT - Non-whitelisted tokens.
        *** in case of stETH, the poolAddress in the lsdTokenInfo will be actually the chainlink price aggregator for stETH as we don't actually swap it, but wrap it
     */
    function whitelistLSDToken(
        address _tokenAddress,
        address _poolAddress
    )
    external
    onlyHordCongress
    {
        require(_tokenAddress != address(0), "0x0");

        LSDTokenInfo storage token = lsdTokenToInfo[_tokenAddress];

        if (token.poolAddress == address(0)) {//adding new token to whitelist
            require(_poolAddress != address(0), "0x0");
            token.poolAddress = _poolAddress;
            lsdTokens.push(_tokenAddress);
        } else { //simple unfreeze of prewhitelisted token
            require(token.isWhitelisted != true, "NWT");
            if (_poolAddress != address(0) && token.poolAddress != _poolAddress){
                token.poolAddress = _poolAddress;
            }
        }
        token.isWhitelisted = true;
        emit LSDTokenWhitelisted(_tokenAddress, token.poolAddress);
    }



    /**
        * @notice       Function removes whitelisted ERC-20 token address.
        * @dev          Callable only by HordCongress.
        * error-msg     OWT - Only whitelisted tokens.
        * error-msg     SAT - Should swap all tokens before removing.
     */
    function removeLSDToken(
        address _tokenAddress,
        bool isOnlyTokenFreeze
    )
    external
    onlyHordCongress
    {
        LSDTokenInfo storage token = lsdTokenToInfo[_tokenAddress];
        require(token.poolAddress != address(0), "OWT");

        // Set whitelisted property to false in both cases (removing / freezing)
        token.isWhitelisted = false;

        if (isOnlyTokenFreeze) {
            emit LSDTokenRemoved(_tokenAddress, isOnlyTokenFreeze);
            return;
        }

        require(IERC20(_tokenAddress).balanceOf(address(this)) == 0, "SAT");
        token.poolAddress = address(0);

        for (uint256 i = 0; i < lsdTokens.length; i++) {
            if (lsdTokens[i] == _tokenAddress) {
                lsdTokens[i] = lsdTokens[lsdTokens.length - 1];
                lsdTokens.pop();

                emit LSDTokenRemoved(_tokenAddress, isOnlyTokenFreeze);
                return;
            }
        }
    }

    /**
        * @notice  Function sets validators stats.
        * @dev     Callable only by maintainer.
        * newTotalETHBalanceInValidators -  received from beaconchain api, includes all ETH in the validators
                                            minus the 32 ETH in the pre-run validator (that no hETH was minted against)
                                            including the consensus layer rewards which are not arrived yet in contract
                                            balance via partial withdraw.
        * newRewardsAmount - all consensus layer rewards (without staked) + blockproposals + MEV rewards
        * newTotalExecutionLayerRewards - from DAPI: block_proposal_eth1_rewards+mev_eth1_rewards+partial_withdrawals
        * error-msg     NTP - not enough time has passed
        * error-msg     WA - Wrong amount.
     */
    function setValidatorStats(
        uint256 newRewardsAmount,
        uint256 newTotalETHBalanceInValidators,
        uint256 newTotalExecutionLayerRewards
    )
    external
    onlyMaintainer
    {
        bool isLiquidated = false;

        if (totalETHOnContractRecorded.add(amountETHDepositedInMeantime) < amountETHUsedToPayDebtInMeantime) {
            isLiquidated = true;
        } else {
            uint256 balanceSinceLastStatsUpdateWithL1ChangesOnly = totalETHOnContractRecorded //this is the expected l1 balance now if there were no "drops" like liquidated eth from l2 dropping into  l1
                .add(amountETHDepositedInMeantime)
                .sub(amountETHUsedToPayDebtInMeantime);

            if (address(this).balance > balanceSinceLastStatsUpdateWithL1ChangesOnly) { //this can happen if balance from L2 was dropped into the L1 contract
                uint256 diff = address(this).balance.sub(balanceSinceLastStatsUpdateWithL1ChangesOnly);
                if (diff >= stakingConfiguration.amountETHInValidator()) {
                    isLiquidated = true;
                }
            }
        }

        require(block.timestamp >= lastTimeUpdatedStats.add(stakingConfiguration.timeBetweenSetStatsCalls()) || isLiquidated,
            "NTP");

        if(!paused()) {
            require(newRewardsAmount >= totalRewardsCollected, "WA");
            require(newTotalExecutionLayerRewards >= totalExecLayerRewards, "WA");
        }

        uint256 rewardsBoundary = totalRewardsCollected
            .mul(stakingConfiguration.tolerancePercentageForRewards())
            .div(100);

        uint256 ethInValidatorsBoundary = totalBalanceETHInValidators
            .mul(stakingConfiguration.tolerancePercentageForRewards())
            .div(100);

        if (
            (totalRewardsCollected > 0 &&
                (newRewardsAmount > totalRewardsCollected.add(rewardsBoundary) ||
                    newRewardsAmount < totalRewardsCollected.sub(rewardsBoundary))) ||
            (totalBalanceETHInValidators > stakingConfiguration.amountETHInValidator() &&
                (newTotalETHBalanceInValidators > totalBalanceETHInValidators.add(ethInValidatorsBoundary) ||
                    newTotalETHBalanceInValidators < totalBalanceETHInValidators.sub(ethInValidatorsBoundary)))
        )
        {
            _pause();
        }

        totalRewardsCollected = newRewardsAmount;
        totalBalanceETHInValidators =  newTotalETHBalanceInValidators;
        totalExecLayerRewards = newTotalExecutionLayerRewards;
        lastTimeUpdatedStats = block.timestamp;
        totalETHOnContractRecorded = address(this).balance;
        amountETHDepositedInMeantime = 0;
        amountETHUsedToPayDebtInMeantime = 0;

        emit StakingStatsUpdated(totalRewardsCollected, totalBalanceETHInValidators, totalExecLayerRewards);
    }

    function mintProtocolFees() external onlyMaintainer {
        uint256 amountETHForMintingCalc = totalRewardsCollected
            .sub(lastRewardsForFeeCalc)
            .mul(stakingConfiguration.rewardFeePercentage())
            .div(100);
        uint256 diffExecLayerRewardsForFeelCalc = totalExecLayerRewards.sub(lastExecLayerRewardsForFeeCalc);
        uint256 amountHETHForMinting =
                        getAmountOfHETHforETH(amountETHForMintingCalc, false, diffExecLayerRewardsForFeelCalc);

        _mint(stakingConfiguration.feeRecipient(), amountHETHForMinting);

        lastRewardsForFeeCalc = totalRewardsCollected;
        lastExecLayerRewardsForFeeCalc = totalExecLayerRewards;
        totalFeesAccountedInETH = totalFeesAccountedInETH.add(amountETHForMintingCalc);
        totalFeesMintedInHETH = totalFeesMintedInHETH.add(amountHETHForMinting);

        emit FeeCollected(
            stakingConfiguration.feeRecipient(),
            amountHETHForMinting,
            amountETHForMintingCalc,
            diffExecLayerRewardsForFeelCalc
        );
    }

    /**
         * @notice          Withdraws funds for launching new validator. Sends funds to beaconchain deposit contract.
         * @dev             Callable only by maintainer.
         * @param           pubkey - The public key of the validator is the 48 byte (compressed) BLS public key.
         * @param           withdrawal_credentials is 32 bytes of 0x01 Eth1 credentials. Which represents address on
                            execution layer where funds from both partial and fully withdrawal will go.
         * @param           signature - The signature is a 96 Byte BLS signature. It is generated by signing the hash
                            tree root of a DepositMessage object (public_key, withdrawal_credentials, and
                            deposit_amount), with the validator's signing key.
         * @param           deposit_data_root - The deposit_data_root is the quantity (node) that will be inserted as a
                            new leaf in the Merkle tree and forms part of the verification of a deposit
                            on the consensus layer.
         * error-msg        VAI - Validator is already initialized.
         * error-msg        WC - Wrong conditions (conditions are not met).
     */
    function launchNewValidator(
        bool isEigenLayer,
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    )
    nonReentrant
    external
    whenNotPaused
    onlyMaintainer
    {
        require(isValidatorInitialized[pubkey] == false, "VAI");

        uint256 amountToWithdraw = stakingConfiguration.amountETHInValidator();

        require(address(this).balance >= amountToWithdraw, "WC");

        // Update pool information
        totalBalanceETHInValidators = totalBalanceETHInValidators.add(amountToWithdraw);
        isValidatorInitialized[pubkey] = true;

        if (isEigenLayer) {
            hordRestakingManager.launchNewValidatorWithEigenLayer{
                    value: amountToWithdraw
                }(pubkey, signature, deposit_data_root);
        } else {
            beaconDeposit.deposit{
                    value: amountToWithdraw
                }(pubkey, withdrawal_credentials, signature, deposit_data_root);
        }


        emit LaunchNewValidator(msg.sender, amountToWithdraw);
    }

    /**
         * @notice          Withdraws funds for launching new validator and register to ssv contract, callable only by address with permissions
         * error-msg        NET - not enough SSV tokens.
         * error-msg        VAI - Validator is already initialized.
         * error-msg        WL - params parameter length should be = 4.
     */
    function registerNewValidatorOnSSV(
        uint256 ssvAmount,
        bytes32 deposit_data_root,
        bytes[] calldata params, //0 - pubkey, 1 - withdrawal_credentials , 2 - signature, 3 - sharesEncrypted
        uint64[] calldata operatorIds,
        ISSVNetwork.Cluster memory cluster
    )
    nonReentrant
    external
    whenNotPaused
    onlyMaintainer
    {
        require(isSSVValidatorInitialized[params[0]] == false, "VAI");
        require(ssvToken.balanceOf(address(this)) >= ssvAmount, "NET");
        require(params.length == 4, "WL");

        ssvToken.approve(address(ssvNetwork), ssvAmount);

        isSSVValidatorInitialized[params[0]] = true;

        ssvNetwork.registerValidator(
            params[0], // pubkey
            operatorIds,
            params[3], // sharesEncrypted
            ssvAmount,
            cluster
        );
    }

    /**
         * @notice          Maintainer calls this function when he wants to remove a validator from ssv contract
         * error-msg        VNI - Validator is not initialized.
     */
    function removeValidatorFromSSV(
        bytes calldata pubkey,
        uint64[] memory operatorIds,
        ISSVNetwork.Cluster memory cluster
    )
    nonReentrant
    external
    whenNotPaused
    onlyMaintainer
    {
        require(isSSVValidatorInitialized[pubkey], "VNI");
        ssvNetwork.removeValidator(pubkey, operatorIds, cluster);
        isSSVValidatorInitialized[pubkey] = false;
    }

    /**
         * @notice          Wraps stETH to wstETH.
         * @dev             Callable only by maintainer.
         * @param           amountToWrap - amount of stETH token that should be wrapped
         * error-msg           NET - not enough stETH tokens
     */
    function wrapStETH(uint256 amountToWrap) external onlyMaintainer {
        // should check if contract has enough stETH to wrap
        require(amountToWrap <= IERC20(stETH).balanceOf(address(this)), "NET");

        // Contract should approve amountToWrap to wstETH contract (spender)
        IERC20(stETH).approve(wstETH, amountToWrap);

        // Executes wrap of provided amount of stETH tokens
        uint256 wstETHReceived = IWstETH(wstETH).wrap(amountToWrap);

        // Emits StETHWrapped event
        emit StETHWrapped(wstETHReceived, wstETH, amountToWrap);
    }

    /**
         * @notice          Swap X amount of LSD token to exact amount of WETH.
         * @dev             Callable only by maintainer.
         * @param           pool - address of uniswap v3 liquidity pool
         * @param           tokenIn - address of LSD token that should be swapped
         * @param           amountOut - amount of WETH token that should be received
         * @param           amountInMaximumFromMaintainer - optional param
         * error-msg        WLP - wrong liquidity pool address
         * error-msg        NET - dont have enough lsd tokens
         * error-msg        NRT - didnt receive total amountOut
         * error-msg        SMM - spent more than amountInMaximum
     */
    function swapLSDToExactAmountOfETH(
        address pool,
        address tokenIn,
        uint256 amountOut,
        uint256 amountInMaximumFromMaintainer
    )
    nonReentrant
    external
    whenNotPaused
    onlyMaintainer
    returns (uint256)
    {
        LSDTokenInfo storage lsdTokenInfo = lsdTokenToInfo[tokenIn];

        require(lsdTokenInfo.poolAddress == pool, "WLP");

        uint256 amountInMaximum = calculateAmountInMax(pool, amountOut, amountInMaximumFromMaintainer);

        uint256 wETHBalanceBefore = IWrappedToken(WETH).balanceOf(address(this));
        uint256 lsdBalanceBefore = IERC20(tokenIn).balanceOf(address(this));

        require(amountInMaximum <= lsdBalanceBefore, "NET");
        IERC20(tokenIn).safeIncreaseAllowance(address(dubUniswapV3), amountInMaximum);

        uint256 amountIn = dubUniswapV3.swapExactOutputSingle(
            swapRouter,
            pool,
            tokenIn,
            amountInMaximum,
            amountOut
        );

        uint256 wETHBalanceAfter = IWrappedToken(WETH).balanceOf(address(this));
        uint256 lsdBalanceAfter = IERC20(tokenIn).balanceOf(address(this));

        require(wETHBalanceAfter >= wETHBalanceBefore.add(amountOut), "NRT");
        require(lsdBalanceAfter >= lsdBalanceBefore.sub(amountInMaximum), "SMM");

        // Uniswap V3 contracts work only with WETH, so at the end of swap we will get WETH and in the next line we have
        // to swap that back into  native ETH in order to work with that (launch validators/pay out debts)
        IWrappedToken(WETH).withdraw(amountOut);

        amountETHDepositedInMeantime = amountETHDepositedInMeantime.add(amountOut);

        emit LSDTokenSwap(tokenIn, amountIn, amountOut);

        return amountIn;
    }

    /**
         * error-msg        WA - wrong amountInMaximumFromMaintainer
     */
    function calculateAmountInMax(address pool, uint256 amountOut, uint256 amountInMaximumFromMaintainer) private returns (uint256 amountInMaximum) {
        uint256 estimatedAmountIn = dubUniswapV3.estimateAmountOut(pool, address(WETH), uint128(amountOut));
        uint256 amountInBoundary = estimatedAmountIn.mul(stakingConfiguration.priceSlippageThreshold()).div(100);
        uint256 amountInMaximumCalc = estimatedAmountIn.add(amountInBoundary);

        if (amountInMaximumFromMaintainer > 0) {
            require(amountInMaximumFromMaintainer <= amountInMaximumCalc, "WA");
            amountInMaximum = amountInMaximumFromMaintainer;
        } else {
            amountInMaximum = amountInMaximumCalc;
        }
    }

    /**
         * @notice User calls this function when he wants to deposit ETH
         * error-msg        WA - msg value is not correct
         * error-msg        VLC - validator is launching/closing currently
     */
    function userDepositETH()
    payable
    external
    whenNotPaused
    onlyDirectCalls
    {
        require(msg.value > 0, "msg value is not correct");
        //if balance is above 32ETH, this means either debt closing or launchNewValidator() must be processed before new deposits should be processed
        require(
            address(this).balance.sub(msg.value) < stakingConfiguration.amountETHInValidator(),
            "VLC "
        );

        uint256 amountForMint = getAmountOfHETHforETH(msg.value, true, 0);
        amountETHDepositedInMeantime = amountETHDepositedInMeantime.add(msg.value);

        // Mint hETH for user
        _mint(msg.sender, amountForMint);

        emit HETHMinted(msg.sender, amountForMint);
        emit Deposit(msg.sender, msg.value);
    }

    /**
         * @notice User calls this function when he wants to deposit LSD token
         * error-msg        VLC - validator is launching/closing currently
         * error-msg        TNW - token is not whitelisted
     */
    function depositWithLSDToken(
        address tokenToDeposit,
        uint256 amountToDeposit
    )
    external
    whenNotPaused
    onlyDirectCalls
    {
        LSDTokenInfo storage lsdToken = lsdTokenToInfo[tokenToDeposit];

        // Checks is amountToDeposit whitelisted
        require(lsdToken.isWhitelisted, "TNW");
        //if balance is above 32ETH, this means either debt closing or launchNewValidator() must be processed before new deposits should be processed
        require(
            address(this).balance < stakingConfiguration.amountETHInValidator(),
            "VLC"
        );

        // Calculates how much LSD token is worth in ETH
        uint256 ethValueOfLSDToken;

        // Checks is token which user wants to deposit == stETH
        if (stETH == tokenToDeposit) {
            uint256 price = getLatestTokenPrice(lsdToken.poolAddress); //NOTE: in case of stETH we expect the ChainLink price aggregator to be in the poolAddress param of the lsdTokenInfo
            ethValueOfLSDToken = price.mul(amountToDeposit).div(stakingConfiguration.percentPrecision());
        } else {
            ethValueOfLSDToken = dubUniswapV3.estimateAmountOut(lsdToken.poolAddress, tokenToDeposit, uint128(amountToDeposit));
        }

        uint256 amountForMint = getAmountOfHETHforETH(ethValueOfLSDToken, false, 0);

        // Transfer LSD tokens to pool
        IERC20(tokenToDeposit).safeTransferFrom(msg.sender, address(this), amountToDeposit);

        // Mint hETH for user
        _mint(msg.sender, amountForMint);

        emit LSDTokenDeposited(msg.sender, tokenToDeposit, amountToDeposit, amountForMint);
    }

    /**
         * @notice          Calculates how much HETH worth some amount of ETH.
     */
    function getAmountOfHETHforETH(
        uint256 amountETH,
        bool isContractCall,
        uint256 diffExecLayerRewardsForFeelCalc
    )
    public
    view
    returns (uint256 result)
    {
        if(totalSupply() == 0) {
            return amountETH;
        }

        uint256 percentPrecision = stakingConfiguration.percentPrecision();
        uint256 lsdBalanceInETH = getLSDTokenBalanceInETH();
        uint256 totalETHInPossession;

        if(isContractCall) {
            /*
             heth to eth ratio represents total HETH minted amount / totalETHInPossession
             totalETHInPossession represents all eth that we have in the validators (in code totalBalanceETHInValidators) +
                + staking manager balance (deposits + partial withdrawals (validator rewards / consensus layer rewards) + execution layer rewards; in code address(this).balance)
             */
            totalETHInPossession = totalBalanceETHInValidators
                .add(address(this).balance)
                .add(lsdBalanceInETH)
                .sub(amountETH)
                .sub(hordETHStakingWithdrawalManager.amountTakenFromBuffer()) //amount of ETH that should have been returned to user from validator funds but instead taken from the buffer, so reduced to not count those eth
                .sub(hordETHStakingWithdrawalManager.totalPendingDebt()); //amount of ETH that should be returned to users, for which heth was already burnt, so we don't double count them
        } else {
            totalETHInPossession = totalBalanceETHInValidators
                .add(address(this).balance)
                .add(lsdBalanceInETH)
                .sub(diffExecLayerRewardsForFeelCalc)
                .sub(hordETHStakingWithdrawalManager.amountTakenFromBuffer())
                .sub(hordETHStakingWithdrawalManager.totalPendingDebt());
        }

        uint256 hethEthRatio = totalSupply().mul(percentPrecision).div(totalETHInPossession);

        result = amountETH.mul(hethEthRatio).div(percentPrecision);
    }

    function getLSDTokenBalanceInETH() public view returns (uint256) {
        uint256 totalBalance = 0;

        for (uint256 i = 0; i < lsdTokens.length; i++) {
            LSDTokenInfo memory token = lsdTokenToInfo[lsdTokens[i]];
            uint256 tokenBalance = IERC20(lsdTokens[i]).balanceOf(address(this));
            if (lsdTokens[i] == stETH) {
                uint256 price = getLatestTokenPrice(token.poolAddress);
                uint256 totalStETHBalanceInETH = price.mul(tokenBalance).div(stakingConfiguration.percentPrecision());
                totalBalance = totalBalance.add(totalStETHBalanceInETH);
            } else {
                totalBalance = totalBalance.add(dubUniswapV3.estimateAmountOut(token.poolAddress, lsdTokens[i], uint128(tokenBalance)));
            }
        }

        return totalBalance;
    }

    //this should use the chainLinkAggregator for the stETH price in ETH
    function getLatestTokenPrice(address chainLinkAggregator) internal view returns (uint256){
        (, int256 price, , , ) = AggregatorV3Interface(chainLinkAggregator).latestRoundData();
        return uint256(price);
    }

}
