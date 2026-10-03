// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBounceBitToken} from "../interfaces/IBounceBitToken.sol";
import {IBlacklist} from "../interfaces/IBlacklist.sol";

abstract contract BounceBitToken is ERC20Upgradeable, OwnableUpgradeable, IBounceBitToken {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _minters;
    EnumerableSet.AddressSet private _burners;
    address public blacklist;

    event MinterAdded(address indexed owner, address indexed minter);
    event MinterRemoved(address indexed owner, address indexed minter);
    event BurnerAdded(address indexed owner, address indexed burner);
    event BurnerRemoved(address indexed owner, address indexed burner);
    event BlacklistSet(address indexed owner, address indexed blacklist);

    error Blacklisted();
    error FailedToExec();
    error NotBurner();
    error NotMinter();
    error ZeroAddress();

    // solhint-disable-next-line func-name-mixedcase
    function __BounceBitToken_init(
        string memory _name,
        string memory _symbol,
        address _initialOwner,
        address _blacklist,
        address[] memory _minterList,
        address[] memory _burnerList
    ) internal onlyInitializing {
        __ERC20_init(_name, _symbol);
        __Ownable_init(_initialOwner);
        _setBlacklist(_blacklist);
        for (uint256 i = 0; i < _minterList.length; i++) {
            _addMinter(_minterList[i]);
        }
        for (uint256 i = 0; i < _burnerList.length; i++) {
            _addBurner(_burnerList[i]);
        }
    }

    function transfer(address to, uint256 value) public override notBlacklisted(msg.sender) returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override notBlacklisted(from) returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function burnFor(address to, uint256 amount) external override onlyBurner {
        _burn(to, amount);
    }

    function addMinter(address minter) external onlyOwner {
        _addMinter(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        bool success = _minters.remove(minter);
        if (!success) revert FailedToExec();

        emit MinterRemoved(msg.sender, minter);
    }

    function addBurner(address burner) external onlyOwner {
        _addBurner(burner);
    }

    function removeBurner(address burner) external onlyOwner {
        bool success = _burners.remove(burner);
        if (!success) revert FailedToExec();

        emit BurnerRemoved(msg.sender, burner);
    }

    function setBlacklist(address _blacklist) external onlyOwner {
        _setBlacklist(_blacklist);
    }

    function getMinters() public view returns (address[] memory) {
        return _minters.values();
    }

    function getBurners() public view returns (address[] memory) {
        return _burners.values();
    }

    function _addMinter(address minter) private {
        bool success = _minters.add(minter);
        if (!success) revert FailedToExec();

        emit MinterAdded(msg.sender, minter);
    }

    function _addBurner(address burner) private {
        bool success = _burners.add(burner);
        if (!success) revert FailedToExec();

        emit BurnerAdded(msg.sender, burner);
    }

    function _setBlacklist(address _blacklist) private {
        if (_blacklist == address(0)) revert ZeroAddress();
        blacklist = _blacklist;

        emit BlacklistSet(msg.sender, _blacklist);
    }

    modifier onlyMinter() {
        if (!_minters.contains(msg.sender)) revert NotMinter();
        _;
    }

    modifier onlyBurner() {
        if (!_burners.contains(msg.sender)) revert NotBurner();
        _;
    }

    modifier notBlacklisted(address account) {
        if (address(blacklist) != address(0) && IBlacklist(blacklist).isBlacklisted(account)) revert Blacklisted();
        _;
    }
}
