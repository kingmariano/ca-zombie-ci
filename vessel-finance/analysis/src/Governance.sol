/*
Copyright 2024 Vessel Team.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import { StorageV2 } from "./StorageV2.sol";

contract Governance is StorageV2 {
    /**********
     * Events *
     **********/

    event AdminTransferred(address oldAdmin, address newAdmin);
    event LogOperatorAdded(address operator);
    event LogOperatorRemoved(address operator);
    event LogExitManagerAdded(address exitManager);
    event LogExitManagerRemoved(address exitManager);

    /**********************
     * Function Modifiers *
     **********************/

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    modifier onlyExitManager() {
        _checkExitManager();
        _;
    }

    /***************
     * Constructor *
     ***************/

    function initGovernance(address account) public initializer {
        require(admin == address(0), "Gov: initialized");
        operators[account] = true;
        admin = account;
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Returns the address of the current admin.
    function adminAddress() public view returns (address) {
        return admin;
    }

    /// @notice Returns if an account is an operator.
    function isOperator(address account) public view returns (bool) {
        return operators[account];
    }

    /// @notice Returns if an account is an exit manager.
    function isExitManager(address account) public view returns (bool) {
        return exitManagers[account];
    }

    /************************
     * Restricted Functions *
     ************************/
    
    /// @notice Transfers admin role of the contract to a new account (`newAdmin`).
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Gov: no zero address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    /// @notice Register a new operator.
    function registerOperator(address account) public onlyAdmin {
        operators[account] = true;
        emit LogOperatorAdded(account);
    }

    /// @notice Unregister an old operator.
    function unregisterOperator(address account) public onlyAdmin {
        operators[account] = false;
        emit LogOperatorRemoved(account);
    }

    /// @notice Register a new exit liquidity provider for fast withdraw.
    function registerExitManager(address account) public onlyAdmin {
        exitManagers[account] = true;
        emit LogExitManagerAdded(account);
    }

    /// @notice Unregister a new exit liquidity provider.
    function unregisterExitManager(address account) public onlyAdmin {
        exitManagers[account] = false;
        emit LogExitManagerRemoved(account);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev throws if the sender is not the admin.
    function _checkAdmin() internal view {
        require(adminAddress() == msg.sender, "Gov: caller is not the admin");
    }

    /// @dev Throws if the sender is not an operator.
    function _checkOperator() internal view {
        require(operators[msg.sender], "Gov: caller is not an operator");
    }

    // @dev Throws if the sender is not an exit manager.
    function _checkExitManager() internal view {
        require(exitManagers[msg.sender], "Gov: caller is not an exit manager.");
    }
}
