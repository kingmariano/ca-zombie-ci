// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.30;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {DynamicSet} from "@solarity/solidity-lib/libs/data-structures/DynamicSet.sol";

import {Permissions} from "./libs/Permissions.sol";

import {IPermissionsManager} from "./interfaces/IPermissionsManager.sol";
import {IBaseModule} from "./interfaces/modules/IBaseModule.sol";

contract PermissionsManager is IPermissionsManager {
    using EnumerableSet for *;
    using DynamicSet for DynamicSet.StringSet;
    using ERC165Checker for address;

    mapping(address => AccountData) internal _accountsData;

    /// @inheritdoc IPermissionsManager
    function grantPermissions(address delegate, PermissionEntry[] calldata permissions) external {
        require(delegate != address(0), ZeroAddress());

        if (!hasDelegate(msg.sender, delegate)) {
            _accountsData[msg.sender].delegators.add(delegate);

            emit DelegateAdded(msg.sender, delegate);
        }

        for (uint256 i = 0; i < permissions.length; ++i) {
            _grantPermission(msg.sender, delegate, permissions[i]);
        }
    }

    /// @inheritdoc IPermissionsManager
    function revokePermissions(address delegate, PermissionEntry[] calldata permissions) external {
        for (uint256 i = 0; i < permissions.length; ++i) {
            _revokePermission(msg.sender, delegate, permissions[i]);
        }

        if (_getDelegateData(msg.sender, delegate).modules.length() == 0) {
            _accountsData[msg.sender].delegators.remove(delegate);

            emit DelegateRemoved(msg.sender, delegate);
        }
    }

    /// @inheritdoc IPermissionsManager
    function getAccountDelegatorsInfo(
        address account
    ) external view returns (DelegateInfo[] memory delegatorsInfo) {
        EnumerableSet.AddressSet storage delegators = _accountsData[account].delegators;

        uint256 delegatorsCount = delegators.length();

        delegatorsInfo = new DelegateInfo[](delegatorsCount);

        for (uint256 i = 0; i < delegatorsCount; ++i) {
            address currentDelegate = delegators.at(i);

            delegatorsInfo[i] = DelegateInfo({
                delegate: currentDelegate,
                modulesInfo: getModulesPermissionsInfo(account, currentDelegate)
            });
        }
    }

    /// @inheritdoc IPermissionsManager
    function getModulesPermissionsInfo(
        address account,
        address delegate
    ) public view returns (ModulePermissionsInfo[] memory modulesInfo) {
        DelegatePermissionsData storage delegateData = _getDelegateData(account, delegate);

        uint256 modulesCount = delegateData.modules.length();

        modulesInfo = new ModulePermissionsInfo[](modulesCount);

        for (uint256 i = 0; i < modulesCount; ++i) {
            address currentModule = delegateData.modules.at(i);

            modulesInfo[i] = ModulePermissionsInfo({
                module: currentModule,
                permissions: _getDelegateData(account, delegate)
                    .modulePermissions[currentModule]
                    .values()
            });
        }
    }

    /// @inheritdoc IPermissionsManager
    function hasPermission(
        address account,
        address delegate,
        PermissionEntry calldata permission
    ) external view returns (bool) {
        DynamicSet.StringSet storage modulePermissions = _getDelegateData(account, delegate)
            .modulePermissions[permission.moduleAddr];

        return
            modulePermissions.contains(permission.permission) ||
            modulePermissions.contains(Permissions.ALL_PERMISSION);
    }

    /// @inheritdoc IPermissionsManager
    function hasDelegate(address account, address delegate) public view returns (bool) {
        return _accountsData[account].delegators.contains(delegate);
    }

    /// @inheritdoc IPermissionsManager
    function hasModulePermission(
        address account,
        address delegate,
        address module
    ) public view returns (bool) {
        return _getDelegateData(account, delegate).modules.contains(module);
    }

    function _grantPermission(
        address account,
        address delegate,
        PermissionEntry calldata permission
    ) internal {
        DelegatePermissionsData storage delegateData = _getDelegateData(account, delegate);

        if (!hasModulePermission(account, delegate, permission.moduleAddr)) {
            require(
                permission.moduleAddr.supportsInterface(type(IBaseModule).interfaceId),
                NotAModule(permission.moduleAddr)
            );

            delegateData.modules.add(permission.moduleAddr);
        }

        require(
            delegateData.modulePermissions[permission.moduleAddr].add(permission.permission),
            PermissionAlreadyGranted(
                account,
                delegate,
                permission.moduleAddr,
                permission.permission
            )
        );

        emit PermissionGranted(account, delegate, permission.moduleAddr, permission.permission);
    }

    function _revokePermission(
        address account,
        address delegate,
        PermissionEntry calldata permission
    ) internal {
        DelegatePermissionsData storage delegateData = _getDelegateData(account, delegate);

        require(
            delegateData.modulePermissions[permission.moduleAddr].remove(permission.permission),
            PermissionDoesNotExist(account, delegate, permission.moduleAddr, permission.permission)
        );

        if (delegateData.modulePermissions[permission.moduleAddr].length() == 0) {
            delegateData.modules.remove(permission.moduleAddr);
        }

        emit PermissionRevoked(account, delegate, permission.moduleAddr, permission.permission);
    }

    function _getDelegateData(
        address account,
        address delegate
    ) private view returns (DelegatePermissionsData storage) {
        return _accountsData[account].delegatorsData[delegate];
    }
}
