// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./ProtocolWhitelist.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IVoter.sol";
import "../v2/interfaces/IClPool.sol";
import "../interfaces/IXToken.sol";
import "../interfaces/IPair.sol";

interface IProtocolWhitelist {
    function syncAndCheckIsWhitelisted(address sender) external returns (bool);
}

library TickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(
        int24 tick
    ) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0
            ? uint256(-int256(tick))
            : uint256(int256(tick));
        require(absTick <= uint256(uint24(MAX_TICK)), "T");

        uint256 ratio = absTick & 0x1 != 0
            ? 0xfffcb933bd6fad37aa2d162d1a594001
            : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0)
            ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0)
            ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0)
            ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0)
            ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0)
            ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0)
            ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0)
            ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0)
            ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0)
            ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0)
            ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0)
            ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0)
            ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0)
            ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0)
            ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0)
            ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0)
            ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0)
            ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0)
            ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0)
            ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        sqrtPriceX96 = uint160(
            (ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1)
        );
    }
}

contract XToken is ERC20Upgradeable, IXToken {
    // constants and immutables
    uint256 public constant PRECISION = 100;
    uint256 public constant MAXTIME = 4 * 365 days;
    uint32 public duration;
    address public emissionsToken;
    address public votingEscrow;
    address public voter;

    // addresses
    address public timelock;
    address public multisig;
    address public whitelistOperator;
    address public _pool;
    address public outToken;

    mapping(address => bool) public isWhitelisted;

    ///@dev ratio of earned emissionsToken via exit penalty. 50% means they earn 50% of the emissionsToken value
    uint256 public exitRatio;
    uint256 public veExitRatio;
    uint256 public minVest; /// @notice the initial minimum vesting period is 7 days (one week)
    uint256 public veMaxVest; /// @notice the initial maximum vesting period for vote escrowed exits is 30 days (1 month)
    uint256 public maxVest; /// @notice the initial maximum vesting period is 90 days (3 months)

    struct VestPosition {
        uint256 amount; // amount of xTokens
        uint256 start; // start unix timestamp
        uint256 maxEnd; // start + maxVest (end timestamp)
        uint256 vestID; // vest identifier (starting from 0)
    }

    mapping(address user => VestPosition[]) public vestInfo;

    // Partner/Modular whitelists
    address public protocolWhitelist;

    bool public optionEnabled;
    bool public paused;
    bool public usingLegacyPair;

    modifier onlyTimelock() {
        require(msg.sender == timelock, "xToken: !Auth");
        _;
    }

    modifier onlyWhitelistOperator() {
        require(
            msg.sender == whitelistOperator,
            "xToken: Only the operator can call this function"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "P");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _emissionsToken,
        address _votingEscrow,
        address _voter,
        address _timelock,
        address _multisig,
        address _whitelistOperator,
        address _protocolWhitelist
    ) external initializer {
        __ERC20_init("Escrowed NILE Token", "xNILE");
        // set addresses
        emissionsToken = _emissionsToken;
        votingEscrow = _votingEscrow;
        voter = _voter;
        timelock = _timelock;
        multisig = _multisig;
        whitelistOperator = _whitelistOperator;
        protocolWhitelist = _protocolWhitelist;

        // set initial parameters
        exitRatio = 75; // 75%
        veExitRatio = 100; // 1:1
        minVest = 14 days; /// @notice the initial minimum vesting period is 14 days (two weeks)
        veMaxVest = 30 days; /// @notice the initial maximum vesting period for vote escrowed exits is 30 days (1 month)
        maxVest = 120 days; /// @notice the initial maximum vesting period is 120 days (4 months)

        // approve emissionsToken to ve
        IERC20Upgradeable(emissionsToken).approve(
            votingEscrow,
            type(uint256).max
        );

        // whitelist address(0), for minting
        _updateWhitelist(address(0), true);

        // whitelist self, voter, and multisig
        _updateWhitelist(address(this), true);
        _updateWhitelist(address(voter), true);
        _updateWhitelist(multisig, true);
    }

    /*****************************************************************/
    // ERC20 Overrides
    /*****************************************************************/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 //amount
    ) internal override whenNotPaused {
        if (to != address(0)) {
            require(syncAndCheckIsWhitelisted(from), "xToken: !WL");
        }
    }

    /*****************************************************************/
    // General use functions
    /*****************************************************************/

    ///@dev mints xTokens for each emissionsToken.
    function convertEmissionsToken(uint256 _amount) external whenNotPaused {
        // restricted to whitelisted contracts
        // to prevent users from minting xTokens and can't convert back without penalty
        require(syncAndCheckIsWhitelisted(msg.sender), "xToken: !AUTH");
        require(_amount > 0, "xToken: ! > 0");
        IERC20Upgradeable(emissionsToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        _mint(msg.sender, _amount);
        emit Converted(msg.sender, _amount);
    }

    ///@dev convert xTokens to ve at veExitRatio (new veNFT form)
    function xTokenConvertToNft(
        uint256 _amount
    ) external whenNotPaused returns (uint256 veTokenId) {
        require(_amount > 0, "xToken: ! > 0");
        _burn(msg.sender, _amount);
        uint256 _adjustedAmount = ((veExitRatio * _amount) / PRECISION);
        _mint(multisig, (_amount - _adjustedAmount));
        veTokenId = IVotingEscrow(votingEscrow).createLockFor(
            _adjustedAmount,
            MAXTIME,
            msg.sender
        );
        emit XTokensRedeemed(msg.sender, _amount);
        return veTokenId;
    }

    ///@dev convert xTokens to ve at a 1:1 ratio (increase existing veNFT)
    function xTokenIncreaseNft(
        uint256 _amount,
        uint256 _tokenID
    ) external whenNotPaused {
        require(_amount > 0, "xToken: ! > 0");
        _burn(msg.sender, _amount);

        // ensure the msg.sender is approved to modify the ve
        require(
            IVotingEscrow(votingEscrow).isApprovedOrOwner(msg.sender, _tokenID),
            "xToken: You are not approved to extend this ve position"
        );

        // ensure the xToken contract is approved to increase the amount of this ve
        // this is to ensure extending lock time will work
        require(
            IVotingEscrow(votingEscrow).isApprovedOrOwner(
                address(this),
                _tokenID
            ),
            "xToken: The contract has not been given approval to your ve position"
        );

        uint256 _adjustedAmount = ((veExitRatio * _amount) / PRECISION);

        // mint the exit penalty to the multisig
        _mint(multisig, (_amount - _adjustedAmount));

        // ensures that the ve is 4 year locked
        uint256 maxUnlock = ((block.timestamp + MAXTIME) / 1 weeks) * 1 weeks;
        (, uint256 unlockTime) = IVotingEscrow(votingEscrow).locked(_tokenID);
        if (maxUnlock > unlockTime) {
            IVotingEscrow(votingEscrow).increaseUnlockTime(_tokenID, MAXTIME);
        }

        IVotingEscrow(votingEscrow).increaseAmount(_tokenID, _adjustedAmount);
        emit XTokensRedeemed(msg.sender, _amount);
    }

    /**
     * @dev exit instantly with a penalty
     * @param _amount amount of xTokens to exit
     * @param maxPayAmount maximum amount of collateral user is willing to pay
     */
    function instantExit(
        uint256 _amount,
        uint256 maxPayAmount
    ) external whenNotPaused {
        require(_amount > 0, "xToken: ! > 0");
        uint256 exitAmount = ((exitRatio * _amount) / PRECISION);

        _burn(msg.sender, _amount);

        if (optionEnabled) {
            uint256 amountToPay = (_amount * (100 - exitRatio)) / 100;
            amountToPay = quotePrice(amountToPay);
            require(amountToPay <= maxPayAmount, "SLIPPAGE");

            IERC20Upgradeable(outToken).transferFrom(
                msg.sender,
                multisig,
                amountToPay
            );
            exitAmount = _amount;
        } else {
            // mint the exit penalty to the multisig
            uint256 haircut = _amount - exitAmount;
            _mint(multisig, haircut);
        }

        IERC20Upgradeable(emissionsToken).transfer(msg.sender, exitAmount);
        emit InstantExit(msg.sender, _amount);
    }

    ///@dev vesting xTokens --> emissionToken functionality
    function createVest(uint256 _amount) external {
        require(_amount > 0, "xToken: ! > 0");
        _burn(msg.sender, _amount);
        uint256 vestLength = vestInfo[msg.sender].length;
        vestInfo[msg.sender].push(
            VestPosition(
                _amount,
                block.timestamp,
                block.timestamp + maxVest,
                vestLength
            )
        );
        emit NewVest(msg.sender, vestLength, _amount);
    }

    ///@dev handles all situations regarding exiting vests
    function exitVest(
        uint256 _vestID,
        bool _ve
    ) external whenNotPaused returns (bool) {
        uint256 vestCount = vestInfo[msg.sender].length;
        require(
            vestCount != 0 && _vestID <= vestCount - 1,
            "xToken: Vest does not exist"
        );
        VestPosition storage _vest = vestInfo[msg.sender][_vestID];
        require(
            _vest.amount != 0 && _vest.vestID == _vestID,
            "xToken: Vest not active"
        );
        uint256 _amount = _vest.amount;
        uint256 _start = _vest.start;
        _vest.amount = 0;

        // case: vest has not crossed the minimum vesting threshold
        if (block.timestamp < _start + minVest) {
            _mint(msg.sender, _amount);
            emit CancelVesting(msg.sender, _vestID, _amount);
            return true;
        }

        ///@dev if it is not a ve exit
        if (!_ve) {
            // case: vest is complete
            if (_vest.maxEnd <= block.timestamp) {
                IERC20Upgradeable(emissionsToken).transfer(msg.sender, _amount);
                emit ExitVesting(msg.sender, _vestID, _amount);
                return true;
            }
            // case: vest is in progress
            else {
                uint256 base = (_amount * exitRatio) / PRECISION;
                uint256 vestEarned = ((_amount *
                    (PRECISION - exitRatio) *
                    (block.timestamp - _start)) / maxVest) / PRECISION;

                uint256 exitedAmount = base + vestEarned;

                _mint(multisig, (_amount - exitedAmount));
                IERC20Upgradeable(emissionsToken).transfer(
                    msg.sender,
                    exitedAmount
                );
                emit ExitVesting(msg.sender, _vestID, _amount);
                return true;
            }
        }
        // exit to ve
        else {
            uint256 veMaxEnd = _start + veMaxVest;
            // case: vest is complete for vote escrow threshold
            if (veMaxEnd <= block.timestamp) {
                IVotingEscrow(votingEscrow).createLockFor(
                    _amount,
                    MAXTIME,
                    msg.sender
                );
                emit ExitVesting(msg.sender, _vestID, _amount);
                return true;
            }
            // case: vest is in progress for vote escrow exit
            else {
                uint256 base = (_amount * veExitRatio) / PRECISION;
                uint256 vestEarned = ((_amount *
                    (PRECISION - veExitRatio) *
                    (block.timestamp - _start)) / veMaxVest) / PRECISION;

                uint256 exitedAmount = base + vestEarned;

                _mint(multisig, (_amount - exitedAmount));
                IVotingEscrow(votingEscrow).createLockFor(
                    exitedAmount,
                    MAXTIME,
                    msg.sender
                );
                emit ExitVesting(msg.sender, _vestID, _amount);
                return true;
            }
        }
    }

    /*****************************************************************/
    // Permissioned functions, timelock/operator gated
    /*****************************************************************/

    ///@dev allows the multisig to redeem collected xTokens
    function multisigRedeem(uint256 _amount) external {
        require(msg.sender == multisig, "xToken: !AUTH");
        _burn(msg.sender, _amount);

        IERC20Upgradeable(emissionsToken).transfer(msg.sender, _amount);
    }

    ///@dev timelock only: alter the parameters for exiting
    function alterExitRatios(
        uint256 _newExitRatio,
        uint256 _newVeExitRatio
    ) external onlyWhitelistOperator {
        exitRatio = _newExitRatio;
        veExitRatio = _newVeExitRatio;
        emit NewExitRatios(_newExitRatio, _newVeExitRatio);
    }

    ///@dev allows the timelock to rescue any trapped tokens
    function rescueTrappedTokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyTimelock {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            IERC20Upgradeable(_tokens[i]).transfer(multisig, _amounts[i]);
        }
    }

    ///@dev change the minimum and maximum vest durations
    function reinitializeVestingParameters(
        uint256 _min,
        uint256 _max,
        uint256 _veMax
    ) external onlyWhitelistOperator {
        (minVest, maxVest, veMaxVest) = (_min, _max, _veMax);

        emit NewVestingTimes(_min, _max, _veMax);
    }

    ///@dev change minimum vesting parameter
    function changeMinimumVestingLength(
        uint256 _minVest
    ) external onlyWhitelistOperator {
        minVest = _minVest;

        emit NewVestingTimes(_minVest, maxVest, veMaxVest);
    }

    ///@dev change maximum vesting parameter
    function changeMaximumVestingLength(
        uint256 _maxVest
    ) external onlyWhitelistOperator {
        maxVest = _maxVest;

        emit NewVestingTimes(minVest, _maxVest, veMaxVest);
    }

    ///@dev change vote escrow maximum vesting parameter
    function changeVeMaximumVestingLength(
        uint256 _veMax
    ) external onlyWhitelistOperator {
        veMaxVest = _veMax;

        emit NewVestingTimes(minVest, maxVest, _veMax);
    }

    ///@dev migrates the timelock to another contract
    function migrateTimelock(address _timelock) external onlyTimelock {
        timelock = _timelock;
    }

    ///@dev migrates the multisig to another contract
    function migrateMultisig(address _multisig) external onlyTimelock {
        multisig = _multisig;
    }

    ///@dev migrates L2 whitelist
    function migrateProtocolWhitelist(
        address _protocolWhitelist
    ) external onlyWhitelistOperator {
        protocolWhitelist = _protocolWhitelist;
    }

    ///@dev only callable by the whitelistOperator contract
    function adjustWhitelist(
        address[] calldata _candidates,
        bool[] calldata _status
    ) external onlyWhitelistOperator {
        for (uint256 i = 0; i < _candidates.length; ++i) {
            _updateWhitelist(_candidates[i], _status[i]);
        }
    }

    ///@notice allows the whitelist operator to add an address to the xToken whitelist
    function addWhitelist(address _whitelistee) external onlyWhitelistOperator {
        _updateWhitelist(_whitelistee, true);
    }

    ///@notice allows the whitelist operator to remove an address from the xToken whitelist
    function removeWhitelist(
        address _whitelistee
    ) external onlyWhitelistOperator {
        _updateWhitelist(_whitelistee, false);
    }

    function _updateWhitelist(address _whitelistee, bool _status) internal {
        isWhitelisted[_whitelistee] = _status;

        emit WhitelistStatus(_whitelistee, _status);
    }

    ///@dev timelock can change the operator contract
    function changeWhitelistOperator(
        address _newOperator
    ) external onlyTimelock {
        whitelistOperator = _newOperator;
    }

    function setOptionsEnabled(bool isEnabled) external {
        require(msg.sender == multisig, "!MSIG");

        optionEnabled = isEnabled;
    }

    function setPool(address newPool) external onlyWhitelistOperator {
        _pool = newPool;
        address token0 = IClPool(_pool).token0();
        outToken = token0 == address(emissionsToken)
            ? IClPool(_pool).token1()
            : token0;
    }

    /// @notice set twap interval, 3600 for 1 hour twap
    function setSecondsAgo(uint32 _duration) external {
        require(msg.sender == multisig, "!MSIG");

        duration = _duration;
    }

    function setPaused(bool _paused) external {
        require(msg.sender == multisig, "!MSIG");
        paused = _paused;
    }

    function useLegacyPair(bool legacy) external onlyWhitelistOperator {
        usingLegacyPair = legacy;
    }

    /*****************************************************************/
    // Getter functions
    /*****************************************************************/

    ///@dev return the amount of emissionsToken within the contract
    function getBalanceResiding() public view returns (uint256) {
        return IERC20Upgradeable(emissionsToken).balanceOf(address(this));
    }

    /// @notice Potentially writes new whitelsited pools to storage then return if an address is whitelisted to transfer xTokens
    /// @param _address The address of the sender
    function syncAndCheckIsWhitelisted(address _address) public returns (bool) {
        if (isWhitelisted[_address]) {
            return true;
        }

        // automatically whitelist gauges
        if (IVoter(voter).isGauge(_address)) {
            _updateWhitelist(_address, true);
            return true;
        }

        // automatically whitelist L2 addresses
        if (
            IProtocolWhitelist(protocolWhitelist).syncAndCheckIsWhitelisted(
                _address
            )
        ) {
            _updateWhitelist(_address, true);
            return true;
        }

        return false;
    }

    ///@dev returns the total number of individual vests the user has
    function usersTotalVests(address _user) public view returns (uint256) {
        return vestInfo[_user].length;
    }

    function quotePayment(
        uint256 amount
    ) public view returns (uint256 payAmount) {
        uint256 amountToPay = (amount * (100 - exitRatio)) / 100;
        payAmount = quotePrice(amountToPay);
    }

    function quotePrice(
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        if (usingLegacyPair) {
            amountOut = IPair(_pool).current(address(emissionsToken), amountIn);
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = duration;
            secondsAgos[1] = 0;

            (int56[] memory tickCumulatives, , ) = IClPool(_pool).observe(
                secondsAgos
            );

            int56 tickCumulativesDelta = tickCumulatives[1] -
                tickCumulatives[0];

            int24 tick = int24(tickCumulativesDelta / int56(int32(duration)));
            if (
                tickCumulativesDelta < 0 &&
                (tickCumulativesDelta % int56(int32(duration)) != 0)
            ) {
                tick--;
            }

            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
            if (sqrtRatioX96 <= type(uint128).max) {
                uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
                amountOut = address(emissionsToken) < outToken
                    ? Math.mulDiv(ratioX192, amountIn, 1 << 192)
                    : Math.mulDiv(1 << 192, amountIn, ratioX192);
            } else {
                uint256 ratioX128 = Math.mulDiv(
                    sqrtRatioX96,
                    sqrtRatioX96,
                    1 << 64
                );
                amountOut = address(emissionsToken) < outToken
                    ? Math.mulDiv(ratioX128, amountIn, 1 << 128)
                    : Math.mulDiv(1 << 128, amountIn, ratioX128);
            }
        }
    }
}
