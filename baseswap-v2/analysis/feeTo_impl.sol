// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IFactoryManager} from "./interfaces/IFactoryManager.sol";
import {IPancakeFactory} from "./interfaces/IPancakeFactory.sol";
import {IPancakeRouter02} from "./interfaces/IPancakeRouter02.sol";
import {IPancakePair} from "./interfaces/IPancakePair.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";

/// @title FactoryManager
/// @author BaseSwap
/// @notice Used to automate and simplify fee collection alongside factory management across V2 and V3 protocols
/// @dev Various checks are kept to a minimum as inputs are correctly handled off-chain to save gas
contract FactoryManager is IFactoryManager, UUPSUpgradeable, OwnableUpgradeable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         LIBRARIES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Safe library for the ERC20Upgradeable interface
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Constant for the max uint128 value
    uint128 private constant MAX_UINT128 = type(uint128).max;

    /// @notice Constant for the max uint256 value
    uint256 private constant MAX_UINT256 = type(uint256).max;

    /// @notice Maximum amount of claims that can be processed in a single transaction
    uint256 private constant BATCH_SIZE_LIMIT = 25;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      STATE VARIABLES                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Address of the treasury
    address public treasury;

    /// @notice Address of the operator
    address public operator;

    /// @notice Address of the swap aggregator
    address public aggregator;

    /// @notice Interface for the V2 factory contract
    IPancakeFactory public factoryV2;

    /// @notice Interface for the V2 router contract
    IPancakeRouter02 public routerV2;

    /// @notice Interface for the V3 factory contract
    IUniswapV3Factory public factoryV3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Restricts a function to only be called by the owner or the operator addresses
    /// @dev Reverts if the function caller is not the owner or the operator
    modifier onlyOwnerOrOperator() {
        if (msg.sender != owner() && msg.sender != operator) {
            revert OnlyOwnerOrOperator();
        }
        _;
    }

    /// @notice Checks whether the FactoryManager is feeToSetter
    /// @dev Reverts if the result is false
    modifier verifyFeeToSetter() {
        if (address(this) != factoryV2.feeToSetter()) {
            revert FactoryManagerNotFeeToSetter();
        }
        _;
    }

    /// @notice Checks whether the FactoryManager is the V3 factory owner
    /// @dev Reverts if the result is false
    modifier verifyFactoryOwner() {
        if (address(this) != factoryV3.owner()) {
            revert FactoryManagerNotFactoryOwner();
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        INITIALIZERS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the FactoryManager contract and sets critical state variables
    /// @param _treasury Address of the treasury multisig
    /// @param _operator Address of the operator
    /// @param _routerV2 Address of the V2 router contract
    /// @param _factoryV2 Address of the V2 factory contract
    /// @param _factoryV3 Address of the V3 factory contract
    /// @param _aggregator Address of the aggregator used for swapping proceeds
    function initialize(
        address _treasury,
        address _operator,
        address _routerV2,
        address _factoryV2,
        address _factoryV3,
        address _aggregator
    ) external initializer {
        _checkZeroAddress(_treasury);
        _checkZeroAddress(_operator);
        _checkZeroAddress(_routerV2);
        _checkZeroAddress(_factoryV2);
        _checkZeroAddress(_factoryV3);
        _checkZeroAddress(_aggregator);

        __Ownable_init();
        __UUPSUpgradeable_init();

        treasury = _treasury;
        operator = _operator;
        routerV2 = IPancakeRouter02(_routerV2);
        factoryV2 = IPancakeFactory(_factoryV2);
        factoryV3 = IUniswapV3Factory(_factoryV3);
        aggregator = _aggregator;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      SETTER FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function setTreasury(address _treasury) external onlyOwner {
        _requireValidAddress(_treasury, treasury, InvalidTreasuryAddress.selector);
        treasury = _treasury;
    }

    /// @inheritdoc IFactoryManager
    function setOperator(address _operator) external onlyOwner {
        _requireValidAddress(_operator, operator, InvalidOperatorAddress.selector);
        operator = _operator;
    }

    /// @inheritdoc IFactoryManager
    function setAggregator(address _aggregator) external onlyOwner {
        _requireValidAddress(_aggregator, aggregator, InvalidAggregatorAddress.selector);
        aggregator = _aggregator;
    }

    /// @inheritdoc IFactoryManager
    function setFactoryV2(address _factory) external onlyOwnerOrOperator {
        _requireValidAddress(_factory, address(factoryV2), InvalidV2FactoryAddress.selector);
        factoryV2 = IPancakeFactory(_factory);
    }

    /// @inheritdoc IFactoryManager
    function setRouterV2(address _router) external onlyOwnerOrOperator {
        _requireValidAddress(_router, address(routerV2), InvalidRouterAddress.selector);
        routerV2 = IPancakeRouter02(_router);
    }

    /// @inheritdoc IFactoryManager
    function setFactoryV2FeeTo(address _address) external onlyOwner verifyFeeToSetter {
        _requireValidAddress(_address, factoryV2.feeTo(), InvalidFactoryFeeToAddress.selector);
        factoryV2.setFeeTo(_address);
    }

    /// @inheritdoc IFactoryManager
    function setFactoryV2FeeToSetter(address _address) external onlyOwner verifyFeeToSetter {
        _requireValidAddress(_address, factoryV2.feeToSetter(), InvalidFactoryFeeToSetterAddress.selector);
        factoryV2.setFeeToSetter(_address);
    }

    /// @inheritdoc IFactoryManager
    function setFactoryV3(address _factory) external onlyOwnerOrOperator {
        _requireValidAddress(_factory, address(factoryV3), InvalidV3FactoryAddress.selector);
        factoryV3 = IUniswapV3Factory(_factory);
    }

    /// @inheritdoc IFactoryManager
    function setFactoryV3Owner(address _address) external onlyOwner verifyFactoryOwner {
        _requireValidAddress(_address, factoryV3.owner(), InvalidFactoryOwner.selector);
        factoryV3.setOwner(_address);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  TOKEN APPROVAL FUNCTIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function approveToken(address token, address spender, uint256 amount) external onlyOwnerOrOperator {
        _approve(token, spender, amount);
    }

    /// @inheritdoc IFactoryManager
    function batchApproveTokens(address[] calldata tokens, address spender, uint256[] calldata amounts)
        external
        onlyOwnerOrOperator
    {
        uint256 tokenCount = tokens.length;
        if (tokenCount == 0) revert EmptyArray();
        if (amounts.length != tokenCount) revert LengthMismatch();
        for (uint256 i = 0; i < tokenCount;) {
            _approve(tokens[i], spender, amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function for approving an ERC20 token to be spent by a specified address
    /// @param token Address of the token to approve for spending
    /// @param amount Amount of tokens to approve for use
    /// @param spender Address of the spender
    function _approve(address token, address spender, uint256 amount) internal {
        IERC20Upgradeable(token).safeApprove(spender, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  TOKEN TRANSFER FUNCTIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function transferTokenToTreasury(address token, uint256 amount) external onlyOwnerOrOperator {
        _transferToTreasury(token, amount);
    }

    /// @inheritdoc IFactoryManager
    function batchTransferTokensToTreasury(address[] calldata tokens, uint256[] calldata amounts)
        external
        onlyOwnerOrOperator
    {
        uint256 tokenCount = tokens.length;
        if (tokenCount == 0) revert EmptyArray();
        if (amounts.length != tokenCount) revert LengthMismatch();
        for (uint256 i = 0; i < tokenCount;) {
            _transferToTreasury(tokens[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function for transferring tokens to the treasury
    /// @param token Address of the token to transfer
    /// @param amount Amount of tokens to transfer
    function _transferToTreasury(address token, uint256 amount) internal {
        IERC20Upgradeable(token).safeTransfer(treasury, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   V3 FEE SETTER FUNCTIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function enableFeeTier(uint24 fee, int24 tickSpacing) external onlyOwnerOrOperator verifyFactoryOwner {
        if (factoryV3.feeAmountTickSpacing(fee) == tickSpacing) revert FeeTierExists();
        factoryV3.enableFeeAmount(fee, tickSpacing);
    }

    /// @inheritdoc IFactoryManager
    function setProtocolFee(address pool, uint8 feeToken0, uint8 feeToken1)
        external
        onlyOwnerOrOperator
        verifyFactoryOwner
    {
        _setProtocolFee(pool, feeToken0, feeToken1);
    }

    /// @inheritdoc IFactoryManager
    function setProtocolFees(address[] calldata pools, uint8[] calldata feesToken0, uint8[] calldata feesToken1)
        external
        onlyOwnerOrOperator
        verifyFactoryOwner
    {
        uint256 poolCount = pools.length;
        if (poolCount == 0) revert EmptyArray();
        if (feesToken0.length != poolCount || feesToken1.length != poolCount) revert LengthMismatch();
        for (uint256 i = 0; i < poolCount;) {
            _setProtocolFee(pools[i], feesToken0[i], feesToken1[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function for setting the protocol fee for a V3 pool
    /// @param pool Address of the pool
    /// @param feeToken0 Token0 fee
    /// @param feeToken1 Token1 fee
    function _setProtocolFee(address pool, uint8 feeToken0, uint8 feeToken1) internal {
        IUniswapV3Pool(pool).setFeeProtocol(feeToken0, feeToken1);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       SWAP FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function swap(bytes calldata swapData) external onlyOwnerOrOperator {
        (bool success,) = aggregator.call{value: 0}(swapData);
        if (!success) revert InvalidSwap();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*            V2 PROTOCOL FEE COLLECTION FUNCTIONS            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function collectProtocolFeeV2(IPancakePair pool) external onlyOwnerOrOperator {
        _removeV2Liquidity(pool.token0(), pool.token1(), address(pool), pool.balanceOf(address(this)));
    }

    /// @inheritdoc IFactoryManager
    function collectProtocolFeesV2(IPancakePair[] calldata pools) external onlyOwnerOrOperator {
        uint256 poolCount = pools.length;
        if (poolCount == 0) revert EmptyArray();
        if (poolCount > BATCH_SIZE_LIMIT) revert BatchLimitExceeded();
        for (uint256 i = 0; i < poolCount;) {
            IPancakePair pool = pools[i];
            _removeV2Liquidity(pool.token0(), pool.token1(), address(pool), pool.balanceOf(address(this)));
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Removes liquidity from a pool and transfers tokens to this address
    /// @dev Adjusts allowance if necessary
    /// @param tokenA Address of the first token in the pool
    /// @param tokenB Address of second token in the pool
    /// @param pool Address of the liquidity pool
    /// @param liquidity Amount of liquidity to remove
    function _removeV2Liquidity(address tokenA, address tokenB, address pool, uint256 liquidity) internal {
        address router = address(routerV2);

        if (IERC20Upgradeable(pool).allowance(address(this), router) == 0) {
            _approve(pool, router, MAX_UINT256);
        }

        try routerV2.removeLiquidity(tokenA, tokenB, liquidity, 0, 0, address(this), block.timestamp) {}
        catch {
            revert InvalidLiquidityWithdrawal();
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*            V3 PROTOCOL FEE COLLECTION FUNCTIONS            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IFactoryManager
    function collectProtocolFeeV3(IUniswapV3Pool pool) external onlyOwnerOrOperator verifyFactoryOwner {
        _collectProtocolFeeV3(pool);
    }

    /// @inheritdoc IFactoryManager
    function collectProtocolFeesV3(IUniswapV3Pool[] calldata pools) external onlyOwnerOrOperator verifyFactoryOwner {
        uint256 poolCount = pools.length;
        if (poolCount == 0) revert EmptyArray();
        if (poolCount > BATCH_SIZE_LIMIT) revert BatchLimitExceeded();
        for (uint256 i = 0; i < poolCount;) {
            _collectProtocolFeeV3(pools[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function for collecting protocol fees from a single V3 pool
    /// @param pool Address of the pool to collect protocol fees from
    function _collectProtocolFeeV3(IUniswapV3Pool pool) internal {
        pool.collectProtocol(address(this), MAX_UINT128, MAX_UINT128);
    }
    
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      HELPER FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks whether an address is a zero address or already assigned
    /// @dev Reverts if either of the checks fail
    /// @param toCheck Address to check (new)
    /// @param against Address to check against (current)
    /// @param selector Custom error selector for revert
    function _requireValidAddress(address toCheck, address against, bytes4 selector) internal pure {
        _checkZeroAddress(toCheck);
        _checkValidAddress(against, toCheck, selector);
    }

    /// @notice Checks whether an address is a zero address
    /// @dev Reverts when the input address is a zero address
    /// @param _address Address to check
    function _checkZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert ZeroAddress();
    }

    /// @notice Checks whether a new address is different from the initial
    /// @dev Reverts with a custom error if both addresses match
    /// @param currentAddress Current address being checked against
    /// @param newAddress New address
    /// @param selector Custom error selector for revert
    function _checkValidAddress(address currentAddress, address newAddress, bytes4 selector) internal pure {
        if (currentAddress == newAddress) {
            assembly {
                mstore(0x0, selector)
                revert(0x0, 0x4)
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UUPS PROXY FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Public implementation of the _authorizeUpgrade() function
    function authorizeUpgrade(address newImplementation) public {
        _authorizeUpgrade(newImplementation);
    }

    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
