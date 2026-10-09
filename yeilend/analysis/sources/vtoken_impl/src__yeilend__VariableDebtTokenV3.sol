// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {VariableDebtToken} from "lib/yei-contracts/contracts/protocol/tokenization/VariableDebtToken.sol";
import {IPool} from "lib/yei-contracts/contracts/interfaces/IPool.sol";

/// @title VariableDebtTokenV3
/// @notice VariableDebtToken implementation with revision 0x3 for the rounding fix upgrade
/// @dev Inherits the patched VariableDebtToken which uses rayDivFloor/rayDivCeil
///      in _mintScaled/_burnScaled via ScaledBalanceTokenBase
contract VariableDebtTokenV3 is VariableDebtToken {
    constructor(IPool pool) VariableDebtToken(pool) {}

    function getRevision() internal pure override returns (uint256) {
        return 0x3;
    }
}
