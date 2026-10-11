//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../interfaces/IHordETHStakingManager.sol";
import "../interfaces/IStakingConfiguration.sol";
import "../interfaces/IHordCongress.sol";
import "../interfaces/IHordCongressMembersRegistry.sol";
import "../interfaces/ISDK.sol";
import "../system/HordUpgradable.sol";
import "../libraries/SafeMath.sol";

/**
 * HordETHStakingWithdrawalManager contract.
 * @author Srdjan Simonovic
 * Date created: 28.03.23.
 * Github: s2imonovic
 */
contract HordETHStakingWithdrawalManager is ReentrancyGuardUpgradeable, PausableUpgradeable, HordUpgradable {
    using SafeMath for uint256;

    // Represent user withdrawal struct
    struct UserWithdrawal {
        address requestOwner;
        uint256 withdrawalNonce;
        uint256 currHETHRedeemed;
        uint256 currETHToWithdraw;
        uint256 pendingDebt;
        uint256 unlockingTime;
        uint256 requestTime;
        uint256 finalizedTime;
        uint256 totalETHWithdrawn;
        uint256 totalHETHRedeemed;
    }

    // Represent amount of ETH in buffer
    uint256 public unAllocatedBuffer;
    // Represent assured claims balance
    uint256 public assuredClaimsBalance;
    // Represent total withdrawal debt
    uint256 public totalPendingDebt;
    // Amount taken from buffer
    uint256 public amountTakenFromBuffer;
    // Organization funds put in the buffer
    uint256 public totalAmountAddedByOrgForBuffer;
    // Funds that are returned to organization
    uint256 public totalAmountReturnedToOrg;
    // Map user address to his withdrawal information
    mapping(address => UserWithdrawal) public usersWithdrawals;
    // Represent array of withdrawals which have pending debt
    address [] private withdrawalDebts;

    // Represent instance of HordStakingManager contract
    IHordETHStakingManager public hordETHStakingManager;
    // Represent instance of StakingConfiguration contract
    IStakingConfiguration public stakingConfiguration;

    //Events
    event EtherReceivedForBufferReserves(address account, uint256 amountETH);
    event ReceivedETHInAssuredBalance(uint256 amountETH);
    event NewUserWithdrawalRequest(
        address user,
        uint256 withdrawalNonce,
        uint256 currHETHRedeemed,
        uint256 currETHToWithdraw,
        uint256 pendingDebt,
        uint256 unlockingTime,
        uint256 totalETHInReserves
    );
    event UserWithdrawalCompleted(
        address user,
        uint256 withdrawalNonce,
        uint256 currHETHRedeemed,
        uint256 totalETHBeforeChargedFee,
        uint256 totalETHAfterChargedFee,
        uint256 totalETHWithdrawn,
        uint256 totalHETHRedeemed
    );
    event PayBackUserFromValidatorFunds(
        address user,
        uint256 withdrawalNonce,
        uint256 pendingDebtAfter,
        uint256 amountOfDebtClosed
    );
    event PayUserPendingDebtFromUnallocatedBuffer(
        address user,
        uint256 withdrawalNonce,
        uint256 pendingDebtAfter,
        uint256 amountOfDebtClosed
    );
    event FundsWithdrawnByOrganization(address financeAddress, uint256 amountToWithdraw);
    event WithdrawalRequestCorrected(
        address user,
        uint256 withdrawalNonce,
        uint256 oldETHToWithdraw,
        uint256 newETHToWithdraw,
        uint256 reduction
    );


    /**
         * @notice          Modifier checks is function call is initiated by HordETHStakingManager contract.
     */
    modifier onlyHordETHStakingManager() {
        require(address(hordETHStakingManager) == msg.sender, "Restricted only to hordETHStakingManager.");
        _;
    }

    /**
         * @notice          Modifier checks is the call direct.
     */
    modifier isDirectCall() {
        require(msg.sender == tx.origin, "Only direct calls.");
        _;
    }

    /**
         * @notice          Initializer function, can be called only once, replacing constructor
         * @param           _hordCongress is the address of HordCongress contract
         * @param           _maintainersRegistry is the address of the MaintainersRegistry contract
         * @param           _stakingConfiguration is the address of the StakingConfiguration contract
         * @param           _hordETHStakingManager is the address of the HordETHStakingManager contract
     */
    function initialize(
        address _hordCongress,
        address _maintainersRegistry,
        address _stakingConfiguration,
        address _hordETHStakingManager
    )
    external
    initializer
    {
        require(_stakingConfiguration != address(0), "StakingConfiguration can not be 0x0 address");
        require(_hordETHStakingManager != address(0), "HordETHStakingManager can not be 0x0 address");

        setCongressAndMaintainers(_hordCongress, _maintainersRegistry);
        stakingConfiguration = IStakingConfiguration(_stakingConfiguration);
        hordETHStakingManager = IHordETHStakingManager(_hordETHStakingManager);

        __ReentrancyGuard_init();
        __Pausable_init_unchained();
    }

    /**
         * @notice Receives some amount of ETH and add that amount to unAllocatedBuffer
     */
    receive() external payable {
        totalAmountAddedByOrgForBuffer = totalAmountAddedByOrgForBuffer.add(msg.value);
        unAllocatedBuffer = unAllocatedBuffer.add(msg.value);
        emit EtherReceivedForBufferReserves(msg.sender, msg.value);
    }

    /**
        * @notice  Function allowing congress to pause the smart-contract
        * @dev     Can be only called by HordCongress or maintainer
     */
    function pause()
    external
    {
        require(
            IHordCongressMembersRegistry(IHordCongress(hordCongress).getMembersRegistry()).isMember(msg.sender)
            || maintainersRegistry.isMaintainer(msg.sender),
            "Only members with permission"
        );
        _pause();
    }

    /**
        * @notice  Function allowing congress to unpause the smart-contract
        * @dev     Can be only called by HordCongress member
     */
    function unpause()
    external
    onlyHordCongress
    {
        _unpause();
    }

    /**
        * @notice  Receives amount from HordETHStakingManager and add that amount to the assuredClaimsBalance
        * @dev     Can be only called by HordETHStakingManager contract
     */
    function receiveETHInAssuredBalance()
    payable
    external
    whenNotPaused
    onlyHordETHStakingManager
    {
        assuredClaimsBalance = assuredClaimsBalance.add(msg.value);
        emit ReceivedETHInAssuredBalance(msg.value);
    }

    /**
         * @notice   Creates UserWithdrawalObject, burn this(amountHETHToRedeem) amount of HETH.
         * @param    amountHETHToRedeem represents amount of HETH tokens which user wants to swap.
         * @dev      Doesn't have any callable modifier
     */
    function requestWithdraw(
        uint256 amountHETHToRedeem
    )
    isDirectCall
    nonReentrant
    external
    whenNotPaused
    {
        // Check is user wants correct amount
        require(
            hordETHStakingManager.balanceOf(msg.sender) >= amountHETHToRedeem,
            "User wants to withdraw more than he has."
        );

        // Create a withdrawal object for specific user
        UserWithdrawal storage userWithdrawal = usersWithdrawals[msg.sender];

        // Check is user withdrawal object is not active (because user can have only one active request object)
        require(
            userWithdrawal.currHETHRedeemed == 0 &&
            userWithdrawal.currETHToWithdraw == 0 &&
            userWithdrawal.pendingDebt == 0 &&
            userWithdrawal.requestTime == 0 &&
            userWithdrawal.unlockingTime == 0,
            "User already has active request."
        );

        uint256 one = 1e18;
        // Getting HETH/ETH ratio
        uint256 hETHToETHRatio = hordETHStakingManager.getAmountOfHETHforETH(one, false, 0);
        // Calculates how much ETH worth amountHETHToRedeem
        uint256 amountETHToWithdraw = one.mul(amountHETHToRedeem).div(hETHToETHRatio); // HETH / (HETH/ETH) = (HETH/HETH)*ETH = ETH
        // Get how much ETH are in total reserves
        uint256 totalETHReserves = totalETHReservesForPayingDebt();

        // Burn amount of HETH which user wants to redeem
        hordETHStakingManager.burn(msg.sender, amountHETHToRedeem);

        // Set user withdrawal data
        userWithdrawal.requestOwner = msg.sender;
        userWithdrawal.withdrawalNonce = userWithdrawal.withdrawalNonce.add(1);
        userWithdrawal.currHETHRedeemed = amountHETHToRedeem;
        userWithdrawal.currETHToWithdraw = amountETHToWithdraw;
        userWithdrawal.requestTime = block.timestamp;
        userWithdrawal.finalizedTime = 0;

        // Check if we have enough ETH in reserves to pay the user immediately (shortCoolDownPeriod), or later (longCoolDownPeriod)
        if (amountETHToWithdraw > totalETHReserves) {
            userWithdrawal.unlockingTime = block.timestamp.add(stakingConfiguration.longCoolDownPeriod());
            userWithdrawal.pendingDebt = amountETHToWithdraw.sub(totalETHReserves);

            // increase total pending debt to user
            totalPendingDebt = totalPendingDebt.add(userWithdrawal.pendingDebt);
            // push user address to withdrawal debts array
            withdrawalDebts.push(userWithdrawal.requestOwner);

            // move all eth that we have on eth staking manager contract to close some part of current request
            hordETHStakingManager.moveETHToAssuredBalance(address(hordETHStakingManager).balance);

            // update assuredClaimsBalance with the amount currently insured for the beneficiary
            assuredClaimsBalance = assuredClaimsBalance.add(unAllocatedBuffer);
            // update amountTakenFromBuffer with the amount which we took from buffer (organization funds)
            amountTakenFromBuffer = amountTakenFromBuffer.add(unAllocatedBuffer);

            unAllocatedBuffer = 0;
        } else {
            userWithdrawal.unlockingTime = block.timestamp.add(stakingConfiguration.shortCoolDownPeriod());

            // calculate how much eth we need from hordETHStakingManager contract in order to pay out current request
            uint256 amountNeededFromManagerContract = calculateAmountETHNeeded(amountETHToWithdraw);

            if (amountNeededFromManagerContract > 0) {
                assuredClaimsBalance = assuredClaimsBalance.add(unAllocatedBuffer);
                unAllocatedBuffer = 0;
                hordETHStakingManager.moveETHToAssuredBalance(amountNeededFromManagerContract);
            } else {
                unAllocatedBuffer = unAllocatedBuffer.sub(amountETHToWithdraw);
                assuredClaimsBalance = assuredClaimsBalance.add(amountETHToWithdraw);
            }

            //each time we take ETH from buffer to facilitate withdraw,
            //we are burning hETH but not really taking out ETH from the active depositor balances,
            //so we must count it to make sure ratio of heth to eth doesn't get skewed to show more eth than needed
            //due to not using the actual eth from validators, but that from the buffer
            amountTakenFromBuffer = amountTakenFromBuffer.add(amountETHToWithdraw.sub(amountNeededFromManagerContract));
        }

        emit NewUserWithdrawalRequest(
            msg.sender,
            userWithdrawal.withdrawalNonce,
            userWithdrawal.currHETHRedeemed,
            userWithdrawal.currETHToWithdraw,
            userWithdrawal.pendingDebt,
            userWithdrawal.unlockingTime,
            totalETHReserves
        );
    }

    /**
         * @notice   Closes user active withdrawalRequest and pay back user.
         * @dev      Doesn't have any callable modifier
     */
    function withdraw()
    isDirectCall
    nonReentrant
    external
    whenNotPaused
    {
        UserWithdrawal storage userWithdrawal = usersWithdrawals[msg.sender];

        require(userWithdrawal.unlockingTime <= block.timestamp, "tokens are not unlock yet");
        require(userWithdrawal.currETHToWithdraw > 0, "user didnt make withdrawal request");
        require(userWithdrawal.pendingDebt == 0, "dont have enough funds yet");

        uint256 protocolFee = 0;
        uint256 totalETHBeforeChargedFee = userWithdrawal.currETHToWithdraw;

        if (stakingConfiguration.percentFeeFromWithdrawal() != 0 &&
            stakingConfiguration.percentFeeFromWithdrawalMicroTx() != 0) {
            if (totalETHBeforeChargedFee < stakingConfiguration.ethWithdrawalMicroTxThreshold()) {
                protocolFee = totalETHBeforeChargedFee
                    .mul(stakingConfiguration.percentFeeFromWithdrawalMicroTx())
                    .div(stakingConfiguration.percentPrecision());
            } else {
                protocolFee = totalETHBeforeChargedFee
                    .mul(stakingConfiguration.percentFeeFromWithdrawal())
                    .div(stakingConfiguration.percentPrecision());
            }
        }

        uint256 totalETHAfterChargedFee = totalETHBeforeChargedFee.sub(protocolFee);

        // update total stater per user
        userWithdrawal.totalETHWithdrawn = userWithdrawal.totalETHWithdrawn.add(totalETHAfterChargedFee);
        userWithdrawal.totalHETHRedeemed = userWithdrawal.totalHETHRedeemed.add(userWithdrawal.currHETHRedeemed);

        emit UserWithdrawalCompleted(
            msg.sender,
            userWithdrawal.withdrawalNonce,
            userWithdrawal.currHETHRedeemed,
            totalETHBeforeChargedFee,
            totalETHAfterChargedFee,
            userWithdrawal.totalETHWithdrawn,
            userWithdrawal.totalHETHRedeemed
        );

        // update userWithdrawal information
        userWithdrawal.currHETHRedeemed = 0;
        userWithdrawal.currETHToWithdraw = 0;
        userWithdrawal.pendingDebt = 0;
        userWithdrawal.unlockingTime = 0;
        userWithdrawal.requestTime = 0;
        userWithdrawal.finalizedTime = block.timestamp;

        // update assuredClaimsBalance accordingly
        assuredClaimsBalance = assuredClaimsBalance.sub(totalETHBeforeChargedFee);
        // sending eth to user
        AddressUpgradeable.sendValue(payable(msg.sender), totalETHAfterChargedFee);
        // sending fees to fee recipient address
        AddressUpgradeable.sendValue(payable(stakingConfiguration.feeRecipient()), protocolFee);
    }

    /**
         * @notice   Closes user active withdrawalRequest and pay back user from unAllocatedBuffer funds.
         *           This is in the case when users already create requests and we didn't have enough funds in that moment,
         *           but after we added some eth in unAllocatedBuffer and we have to call this function in order to close
         *           debts to users that already created requests.
         * @dev      Can be only called by maintainer.
     */
    function payOfDebtFromOrganization(
        uint256 amountOfETHToPayDebt,
        uint256 startIndex,
        uint256 endIndex
    )
    external
    onlyMaintainer
    {
        require(unAllocatedBuffer >= amountOfETHToPayDebt, "Not enough funds.");
        require(totalPendingDebt >= amountOfETHToPayDebt, "Wrong amount to close debts.");

        uint256 remainingAmountOfETHToPayDebt = amountOfETHToPayDebt;

        for (uint256 i = startIndex; i < endIndex; i++) {
            address user = withdrawalDebts[i];
            UserWithdrawal storage userWithdrawal = usersWithdrawals[user];

            uint256 pendingDebtToUser = userWithdrawal.pendingDebt;

            if (remainingAmountOfETHToPayDebt >= pendingDebtToUser) {
                remainingAmountOfETHToPayDebt = remainingAmountOfETHToPayDebt.sub(pendingDebtToUser);
                userWithdrawal.pendingDebt = 0;
                removeUserFromWithdrawalDebts(i);
                i--;
                endIndex--;

                emit PayUserPendingDebtFromUnallocatedBuffer(
                    user,
                    userWithdrawal.withdrawalNonce,
                    userWithdrawal.pendingDebt,
                    pendingDebtToUser.sub(userWithdrawal.pendingDebt)
                );

            } else {
                userWithdrawal.pendingDebt = userWithdrawal.pendingDebt.sub(remainingAmountOfETHToPayDebt);
                remainingAmountOfETHToPayDebt = 0;

                emit PayUserPendingDebtFromUnallocatedBuffer(
                    user,
                    userWithdrawal.withdrawalNonce,
                    userWithdrawal.pendingDebt,
                    pendingDebtToUser.sub(userWithdrawal.pendingDebt)
                );
                break;
            }
        }

        totalPendingDebt = totalPendingDebt.sub(amountOfETHToPayDebt);
        unAllocatedBuffer = unAllocatedBuffer.sub(amountOfETHToPayDebt);
        amountTakenFromBuffer = amountTakenFromBuffer.add(amountOfETHToPayDebt);
        assuredClaimsBalance = assuredClaimsBalance.add(amountOfETHToPayDebt);
    }

    /**
         * @notice   Closes user active withdrawalRequest and pay back user from validator funds.
         * @dev      Can be only called by maintainer.
     */
    function payOfDebtFromValidatorsFunds(uint256 startIndex, uint256 endIndex)
    whenNotPaused
    payable
    external
    onlyHordETHStakingManager
    {
        require(msg.value <= totalPendingDebt.add(amountTakenFromBuffer), "wrong msg.value");

        uint256 availableAmount = msg.value;

        for (uint256 i = startIndex; i < endIndex; i++) {
            address user = withdrawalDebts[i];
            UserWithdrawal storage userWithdrawal = usersWithdrawals[user];

            uint256 pendingDebtToUser = userWithdrawal.pendingDebt;

            if (availableAmount >= pendingDebtToUser) {
                availableAmount = availableAmount.sub(pendingDebtToUser);
                userWithdrawal.pendingDebt = 0;
                removeUserFromWithdrawalDebts(i);
                i--;
                endIndex--;
            } else {
                userWithdrawal.pendingDebt = userWithdrawal.pendingDebt.sub(availableAmount);
                availableAmount = 0;

                emit PayBackUserFromValidatorFunds(
                    userWithdrawal.requestOwner,
                    userWithdrawal.withdrawalNonce,
                    userWithdrawal.pendingDebt,
                    pendingDebtToUser.sub(userWithdrawal.pendingDebt)
                );
                break;
            }

            emit PayBackUserFromValidatorFunds(
                userWithdrawal.requestOwner,
                userWithdrawal.withdrawalNonce,
                userWithdrawal.pendingDebt,
                pendingDebtToUser.sub(userWithdrawal.pendingDebt)
            );
        }

        if (msg.value >= totalPendingDebt) {
            totalPendingDebt = 0;
        } else {
            totalPendingDebt = totalPendingDebt.sub(msg.value);
        }

        //in case msg.value was greater than totalPendingDebt, in the end of the loop, some availableAmount should
        //remain, which goes to the buffer for next withdrawals
        if (availableAmount > 0) {
            require(amountTakenFromBuffer >= availableAmount, "Something went wrong with available amount.");
            unAllocatedBuffer = unAllocatedBuffer.add(availableAmount);
            amountTakenFromBuffer = amountTakenFromBuffer.sub(availableAmount);
        }

        assuredClaimsBalance = assuredClaimsBalance.add(msg.value).sub(availableAmount);
    }

    /**
         * @notice   Returns this amount (amountToWithdraw) of eth to organization (finance address)
         * @dev      Can be only called by maintainer.
     */
    function withdrawOrganizationFunds(
        uint256 amountToWithdraw
    )
    external
    onlyMaintainer
    {
        require(amountToWithdraw <= unAllocatedBuffer, "Wrong amount to withdraw.");

        address financeAddress = stakingConfiguration.financeAddress();

        // update states accordingly
        unAllocatedBuffer = unAllocatedBuffer.sub(amountToWithdraw);
        totalAmountReturnedToOrg = totalAmountReturnedToOrg.add(amountToWithdraw);

        // sending eth to finance address
        AddressUpgradeable.sendValue(payable(financeAddress), amountToWithdraw);

        emit FundsWithdrawnByOrganization(financeAddress, amountToWithdraw);
    }

    /**
     * @notice   Transfers all ETH held by the contract to the organization finance address.
     * @dev      Can be only called by maintainer while the contract is paused.
     */
    function transferETHtoFinance()
    external
    onlyMaintainer
    whenPaused
    nonReentrant
    {
        uint256 amountToWithdraw = address(this).balance;

        require(amountToWithdraw > 0, "Wrong amount to withdraw.");

        address financeAddress = stakingConfiguration.financeAddress();

        unAllocatedBuffer = 0;
        assuredClaimsBalance = 0;
        totalAmountReturnedToOrg = totalAmountReturnedToOrg.add(amountToWithdraw);

        AddressUpgradeable.sendValue(payable(financeAddress), amountToWithdraw);
    }

    //temp for fixing bad withdrawals
    /**
     * @notice  Corrects 5 withdrawal requests that were created with incorrect hETH to ETH rates.
     *          Uses the correct rate of 2.7558 ETH per hETH (same as user 0x13e382...).
     *          This function can only be called once - subsequent calls will fail
     *          because currETHToWithdraw will no longer be greater than the new amount.
     * @dev     Can only be called by HordCongress.
     */
    function correctWithdrawalRequests()
        external
        onlyHordCongress
    {
        // Correct rate: 2.7558 ETH per hETH
        // Each correction: hETH amount × 2.7558 = correct ETH amount
        _correctWithdrawal(0x62F9ce3a054Ea4b828E4a66241919101519855D7, 937835411430600000);  // 0.340313307 hETH × 2.7558. tx hash 0x5727e006a682fe9eaf81dcf2aede631185d30e78850ad1c23226214794728d8b
        _correctWithdrawal(0x80DB446734c9e172dEE325725e73331F7889B0E1, 2755800000000000);    // 0.001 hETH × 2.7558. tx hash 0xe68e4c01e49ebdf04fd3299de1cb48e12ff5ae7cd27cca580b447bd433a2f40c
        _correctWithdrawal(0xC7640068f0977F4DA290e100318985d1Dab50E19, 101904845988600000);  // 0.036978317 hETH × 2.7558. tx hash 0x2865cebe8fba14cb97c459784774ba2d38ed321d26f61055505ccab62f15ac2c
        _correctWithdrawal(0x1Ee968BACe448623eD50BfeB80e3Bb5A35aaE066, 1060087365000000);    // 0.000384675 hETH × 2.7558. tx hash 0x943108824c1d46363ec5b40187ed7d9b66984a13e97fd28fa19a731b153daa0b
        _correctWithdrawal(0xb330E1f427E7046417345881D3FEcD7C80D987BA, 306728942434200000);  // 0.111303049 hETH × 2.7558. tx hash 0x772e259ab3206ead11019736898ecbc8ae0e8d5a034c21b6e38c0cd9e70d440b
    }

    /**
     * @notice  Internal function to correct a single withdrawal request.
     * @param   user The address of the user whose withdrawal needs correction.
     * @param   newETHAmount The corrected ETH amount the user should receive.
     * @dev     All 5 broken requests have 100% pending debt. Contract is paused,
     *          so state cannot change before correction is applied.
     */
    function _correctWithdrawal(address user, uint256 newETHAmount) internal {
        UserWithdrawal storage userWithdrawal = usersWithdrawals[user];

        require(userWithdrawal.currETHToWithdraw > newETHAmount, "Invalid correction");

        uint256 oldETHToWithdraw = userWithdrawal.currETHToWithdraw;
        uint256 reduction = oldETHToWithdraw.sub(newETHAmount);

        // Update currETHToWithdraw and pendingDebt to the corrected amount
        userWithdrawal.currETHToWithdraw = newETHAmount;
        userWithdrawal.pendingDebt = newETHAmount;
        totalPendingDebt = totalPendingDebt.sub(reduction);

        emit WithdrawalRequestCorrected(
            user,
            userWithdrawal.withdrawalNonce,
            oldETHToWithdraw,
            newETHAmount,
            reduction
        );
    }

    function removeUserFromWithdrawalDebts(uint256 index) internal {
        require(index < withdrawalDebts.length, "Wrong index.");

        for (uint256 i = index; i < withdrawalDebts.length.sub(1); i++) {
            withdrawalDebts[i] = withdrawalDebts[i + 1];
        }

        withdrawalDebts.pop();
    }

    /**
         * @notice   Calculates how much ETH HordETHStakingWithdrawal contract needs in order to pay back user.
     */
    function calculateAmountETHNeeded(uint256 amountETHNeeded) internal view returns(uint256) {
        uint256 amountNeededFromManagerContract = 0;

        if (amountETHNeeded > unAllocatedBuffer) {
            amountNeededFromManagerContract = amountETHNeeded.sub(unAllocatedBuffer);
        }

        return amountNeededFromManagerContract;
    }

    /**
         * @notice   Returns length of withdrawalDebts array.
     */
    function withdrawalDebtsLength() public view returns(uint256) {
        return withdrawalDebts.length;
    }

    /**
         * @notice  Returns total balance in reserves
     */
    function totalETHReservesForPayingDebt() public view returns(uint256) {
        return unAllocatedBuffer.add(address(hordETHStakingManager).balance);
    }

    /**
         * @notice   Returns whole withdrawal debts array between start/end index boundaries
     */
    function getWithdrawalDebts(
        uint256 startIndex,
        uint256 endIndex
    )
    external
    view
    returns (address[] memory)
    {
        require(startIndex <= endIndex, "Wrong input.");
        require(endIndex <= withdrawalDebts.length, "overflow");

        address[] memory result = new address[](endIndex - startIndex);
        uint256 counter;

        for (uint256 i = startIndex; i < endIndex; i++) {
            result[counter] = withdrawalDebts[i];
            counter++;
        }

        return result;
    }

}
