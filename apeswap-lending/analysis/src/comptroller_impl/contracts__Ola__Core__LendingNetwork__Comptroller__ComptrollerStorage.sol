// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "../OTokens/CToken.sol";
import "../PriceOracle/PriceOracle.sol";

contract UnitrollerAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Registry address
    */
    address public registry;

    address public implementation;

    // OLA_ADDITIONS : This contract name hash
    bytes32 constant public unitrollerContractHash = keccak256("Unitroller");
}

contract ComptrollerV1Storage is UnitrollerAdminStorage {
    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint public closeFactorMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    uint public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => CToken[]) public accountAssets;

}

contract ComptrollerV2Storage is ComptrollerV1Storage {
    struct Market {
        /// @notice Whether or not this market is listed
        bool isListed;

        /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 0.9 to allow borrowing 90% of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint collateralFactorMantissa;

        /**
         * OLA_ADDITIONS : Added the field liquidationFactorMantissa.
         * @notice Multiplier representing the borrow to collateral ratio from which liquidations can occur in this market.
         *  For instance, 0.9 indicates that liquidations can occur when the borrowed value reaches 90% (or more) of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         *  Must be greater or equal to 'collateralFactorMantissa'.
         */
        uint liquidationFactorMantissa;

        /**
         * @notice Multiplier representing the discount on collateral that a liquidator receives
         * OLA_ADDITIONS : Now supports incentives per market (Added this)
         */
        uint liquidationIncentiveMantissa;

        /// @notice Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;

        // OLA_ADDITIONS : Fields after this line

        // @notice Active collateral caps enforced by  for each cToken address. Defaults to zero which corresponds to unlimited active collateral.
        uint activeCollateralUSDCap;

        // @notice Amount of cTokens actively used as collateral.
        uint activeCollateralCTokenUsage;
    }

    /**
     * @notice Official mapping of cTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;


    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;

    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
    /// @notice A list of all markets
    CToken[] public allMarkets;
}

contract ComptrollerV4Storage is ComptrollerV3Storage {
    // @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
    address public borrowCapGuardian;

    // @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint) public borrowCaps;
}

contract ComptrollerV5Storage is ComptrollerV4Storage {

}

contract ComptrollerStorageOlaV0_01 is ComptrollerV5Storage {
    /// @notice Borrow requests for less than this USD amount will not be approved.
    uint public minBorrowAmountUsd;

    // @notice an address to turn to in order to distribute tokens for participation
    address public rainMaker;
}

contract ComptrollerStorageOlaV0_02 is ComptrollerStorageOlaV0_01 {
    // The address to send the 'Admin Part' when reducing reserves.
    address payable public adminBankAddress;

    // Underlying asset -> contractNameHash -> deployed oTokens
    mapping(address => mapping(bytes32 => address)) public existingMarketTypes;

    // @notice An address to turn to in order to check if an account is approved for specific actions.
    address public bouncer;

    // If on, supplying will be limited only to approved accounts
    bool public limitMinting;
    // If on, borrowing will be limited only to approved accounts
    bool public limitBorrowing;
}

contract ComptrollerStorageOlaV0_05 is ComptrollerStorageOlaV0_02 {
    uint public _latestVersionSynced;

    /// @dev Guard variable for pool-wide/cross-asset re-entrancy checks
    bool internal _notEntered;

    // underlying => custom oracle
    mapping(address => address) public customOracles;
}

/// @notice Time period (in seconds) in which liquidation is to be limited (e.g: 60 for one minute)
//    uint public freshLiquidationLimitedPeriod;

/// @notice The liquidators that are allowed to liquidate while still in the 'freshLiquidationLimitedPeriod'
//    mapping(address => bool) whitelistedLiquidators;
