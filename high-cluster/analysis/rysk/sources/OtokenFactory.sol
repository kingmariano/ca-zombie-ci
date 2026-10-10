pragma solidity =0.6.10;

import {OtokenSpawner} from "./OtokenSpawner.sol";
import {SafeMath} from "../packages/oz/SafeMath.sol";
import {AddressBookInterface} from "../interfaces/AddressBookInterface.sol";
import {OtokenInterface} from "../interfaces/OtokenInterface.sol";
import {WhitelistInterface} from "../interfaces/WhitelistInterface.sol";

/**
 * SPDX-License-Identifier: UNLICENSED
 * @title A factory to create Opyn oTokens
 * @author Opyn Team
 * @notice Create new oTokens and keep track of all created tokens
 * @dev Calculate contract address before each creation with CREATE2
 * and deploy eip-1167 minimal proxies for oToken logic contract
 */
contract OtokenFactory is OtokenSpawner {
    using SafeMath for uint256;
    /// @notice Opyn AddressBook contract that records the address of the Whitelist module and the Otoken impl address.
    address public addressBook;

    /// @notice array of all created otokens
    address[] public otokens;

    /// @dev mapping from parameters hash to its deployed address
    mapping(bytes32 => address) private idToAddress;

    /// @dev max expiry that BokkyPooBahsDateTimeLibrary can handle. (2345/12/31)
    uint256 private constant MAX_EXPIRY = 11865398400;

    constructor(address _addressBook) public {
        addressBook = _addressBook;
    }

    /// @notice address of the previous factory to migrate from
    address public oldFactory;
    /// @notice index of the next oToken to migrate from the old factory
    uint256 public migrationIndex;
    /// @notice true after endMigration() is called — locks migration and enables oToken creation
    bool public migrated;

    /**
     * @notice migrate oTokens from a previous factory deployment
     * @dev call repeatedly until migrationIndex == old factory's getOtokensLength().
     *      automatically stops with ~100k gas remaining to ensure the tx lands.
     *      can only be called before endMigration(). reverts if an id already exists.
     * @dev should be used AFTER new OtokenFactory is set on AddressBook to prevent new oTokens from being created before migration is complete.
     * @param _oldFactory address of the previous factory (only used on first call, ignored after)
     */
    function migrateOtokens(address _oldFactory) external {
        require(!migrated, "OtokenFactory: migration already finalized");
        require(msg.sender == AddressBookInterface(addressBook).owner(), "OtokenFactory: sender is not owner");

        if (oldFactory == address(0)) {
            require(_oldFactory != address(0), "OtokenFactory: invalid old factory");
            oldFactory = _oldFactory;
        }

        OtokenFactory old = OtokenFactory(oldFactory);
        uint256 total = old.getOtokensLength();

        while (migrationIndex < total && gasleft() > 100000) {
            address otokenAddr = old.otokens(migrationIndex);

            // Single external call to get all oToken parameters
            (
                address collateral,
                address underlying,
                address strike,
                uint256 strikePrice,
                uint256 expiryTimestamp,
                bool isPut,
                bool isPhysicallySettled
            ) = OtokenInterface(otokenAddr).getOtokenDetails();

            bytes32 id = _getOptionId(underlying, strike, collateral, strikePrice, expiryTimestamp, isPut, isPhysicallySettled);

            require(idToAddress[id] == address(0), "OtokenFactory: id already exists");

            idToAddress[id] = otokenAddr;
            otokens.push(otokenAddr);
            migrationIndex++;
        }
    }

    /**
     * @notice finalize migration — permanently locks migrateOtokens() and enables createOtoken()
     * @dev call after all migration passes are complete (migrationIndex == old factory length)
     */
    function endMigration() external {
        require(msg.sender == AddressBookInterface(addressBook).owner(), "OtokenFactory: sender is not owner");
        require(!migrated, "OtokenFactory: already finalized");

        migrated = true;
    }

    /// @notice emitted when the factory creates a new Option
    event OtokenCreated(
        address tokenAddress,
        address creator,
        address indexed underlying,
        address indexed strike,
        address indexed collateral,
        uint256 strikePrice,
        uint256 expiry,
        bool isPut,
        bool isPhysicallySettled
    );

    /**
     * @notice create new oTokens
     * @dev deploy an eip-1167 minimal proxy with CREATE2 and register it to the whitelist module
     * @param _underlyingAsset asset that the option references
     * @param _strikeAsset asset that the strike price is denominated in
     * @param _collateralAsset asset that is held as collateral against short/written options
     * @param _strikePrice strike price with decimals = 8
     * @param _expiry expiration timestamp as a unix timestamp
     * @param _isPut True if a put option, False if a call option
     * @param _isPhysicallySettled True if a physically settled, false if cash settled
     * @return newOtoken address of the newly created option
     */
    function createOtoken(
        address _underlyingAsset,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut,
        bool _isPhysicallySettled
    ) external returns (address) {
        require(migrated, "OtokenFactory: migration not finalized");
        require(_expiry > now, "OtokenFactory: Can't create expired option");
        require(_expiry < MAX_EXPIRY, "OtokenFactory: Can't create option with expiry > 2345/12/31");
        bytes32 id = _getOptionId(
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            _isPut,
            _isPhysicallySettled
        );
        require(idToAddress[id] == address(0), "OtokenFactory: Option already created");

        address whitelist = AddressBookInterface(addressBook).getWhitelist();
        require(
            WhitelistInterface(whitelist).isWhitelistedProduct(
                _underlyingAsset,
                _strikeAsset,
                _collateralAsset,
                _isPut
            ),
            "OtokenFactory: Unsupported Product"
        );

        require(!_isPut || _strikePrice > 0, "OtokenFactory: Can't create a $0 strike put option");

        address otokenImpl = AddressBookInterface(addressBook).getOtokenImpl();

        bytes memory initializationCalldata = abi.encodeWithSelector(
            OtokenInterface(otokenImpl).init.selector,
            addressBook,
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            _isPut,
            _isPhysicallySettled
        );

        address newOtoken = _spawn(otokenImpl, initializationCalldata);

        idToAddress[id] = newOtoken;
        otokens.push(newOtoken);
        WhitelistInterface(whitelist).whitelistOtoken(newOtoken);

        emit OtokenCreated(
            newOtoken,
            msg.sender,
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            _isPut,
            _isPhysicallySettled
        );

        return newOtoken;
    }

    /**
     * @notice get the total oTokens created by the factory
     * @return length of the oTokens array
     */
    function getOtokensLength() external view returns (uint256) {
        return otokens.length;
    }

    /**
     * @notice get the oToken address for an already created oToken, if no oToken has been created with these parameters, it will return address(0)
     * @param _underlyingAsset asset that the option references
     * @param _strikeAsset asset that the strike price is denominated in
     * @param _collateralAsset asset that is held as collateral against short/written options
     * @param _strikePrice strike price with decimals = 18
     * @param _expiry expiration timestamp as a unix timestamp
     * @param _isPut True if a put option, False if a call option
     * @param _isPhysicallySettled True if a physically settled, false if cash settled
     * @return the address of target otoken.
     */
    function getOtoken(
        address _underlyingAsset,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut,
        bool _isPhysicallySettled
    ) external view returns (address) {
        bytes32 id = _getOptionId(
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            _isPut,
            _isPhysicallySettled
        );
        return idToAddress[id];
    }

    /**
     * @notice get the address at which a new oToken with these parameters would be deployed
     * @dev return the exact address that will be deployed at with _computeAddress
     * @param _underlyingAsset asset that the option references
     * @param _strikeAsset asset that the strike price is denominated in
     * @param _collateralAsset asset that is held as collateral against short/written options
     * @param _strikePrice strike price with decimals = 18
     * @param _expiry expiration timestamp as a unix timestamp
     * @param _isPut True if a put option, False if a call option
     * @param _isPhysicallySettled True if a physically settled, false if cash settled
     * @return targetAddress the address this oToken would be deployed at
     */
    function getTargetOtokenAddress(
        address _underlyingAsset,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut,
        bool _isPhysicallySettled
    ) external view returns (address) {
        address otokenImpl = AddressBookInterface(addressBook).getOtokenImpl();

        bytes memory initializationCalldata = abi.encodeWithSelector(
            OtokenInterface(otokenImpl).init.selector,
            addressBook,
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            _isPut,
            _isPhysicallySettled
        );
        return _computeAddress(otokenImpl, initializationCalldata);
    }

    /**
     * @dev hash oToken parameters and return a unique option id
     * @param _underlyingAsset asset that the option references
     * @param _strikeAsset asset that the strike price is denominated in
     * @param _collateralAsset asset that is held as collateral against short/written options
     * @param _strikePrice strike price with decimals = 18
     * @param _expiry expiration timestamp as a unix timestamp
     * @param _isPut True if a put option, False if a call option
     * @param _isPhysicallySettled True if a physically settled, false if cash settled
     * @return id the unique id of an oToken
     */
    function _getOptionId(
        address _underlyingAsset,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut,
        bool _isPhysicallySettled
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _underlyingAsset,
                    _strikeAsset,
                    _collateralAsset,
                    _strikePrice,
                    _expiry,
                    _isPut,
                    _isPhysicallySettled
                )
            );
    }
}
