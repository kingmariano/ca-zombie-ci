// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../../../Core/LendingNetwork/Comptroller/ComptrollerInterface.sol";

contract RainMakerAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Comptroller for this contract
    */
    ComptrollerInterface public comptroller;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;
}

contract SingleAssetRainMakerStorage is RainMakerAdminStorage {
    /**
    * @notice If true - stops updating supply and borrow indexes
    */
    bool public isRetired;

    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    CToken[] public allMarkets;

    /// @notice OToken => is market listed by Comptroller
    mapping(address => bool) public isListed;

    /// @notice The amount of incentive tokens each side (supply and borrow) receives per block.
    mapping(address => uint) public compSpeeds;

    /// @notice The COMP market supply state for each market
    mapping(address => CompMarketState) public compSupplyState;

    /// @notice The COMP market borrow state for each market
    mapping(address => CompMarketState) public compBorrowState;

    /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compSupplierIndex;

    /// @notice The COMP borrow index for each market for each borrower as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compBorrowerIndex;

    /// @notice The COMP accrued but not yet transferred to each user
    mapping(address => uint) public compAccrued;

    /// @notice The address of the erc20 token used by the network for participation incentive.
    address public lnIncentiveTokenAddress;
}

contract SingleAssetDynamicRainMakerStorage is RainMakerAdminStorage {
    /**
    * @notice If true - stops updating supply and borrow indexes
    */
    bool public isRetired;

    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    CToken[] public allMarkets;

    /// @notice OToken => is market listed by Comptroller
    mapping(address => bool) public isListed;

    /// @notice The amount of incentive tokens the whole supply side receives per block.
    mapping(address => uint) public compSupplySpeeds;

    /// @notice The amount of incentive tokens the whole borrow side receives per block.
    mapping(address => uint) public compBorrowSpeeds;

    /// @notice The COMP market supply state for each market
    mapping(address => CompMarketState) public compSupplyState;

    /// @notice The COMP market borrow state for each market
    mapping(address => CompMarketState) public compBorrowState;

    /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compSupplierIndex;

    /// @notice The COMP borrow index for each market for each borrower as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compBorrowerIndex;

    /// @notice The COMP accrued but not yet transferred to each user
    mapping(address => uint) public compAccrued;

    /// @notice The address of the erc20 token used by the network for participation incentive.
    address public lnIncentiveTokenAddress;

    /// @notice (market => base unit) The base unit (1 of) for this market underlying
    mapping(address => uint) public baseUnits;
}