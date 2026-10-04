// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./IPermissions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Core Interface
/// @author Fei Protocol
interface ICore is IPermissions {
    function init() external;
}
