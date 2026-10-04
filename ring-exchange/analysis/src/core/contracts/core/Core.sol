// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.6.6;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "./Permissions.sol";
import "./ICore.sol";

/// @notice maintains roles, access control
contract Core is ICore, Permissions, Initializable {
    function init() external override initializer {
        _setupGovernor(msg.sender);
    }
}
