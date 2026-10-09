// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {AToken} from "lib/yei-contracts/contracts/protocol/tokenization/AToken.sol";
import {IPool} from "lib/yei-contracts/contracts/interfaces/IPool.sol";

/// @title ATokenV3
/// @notice AToken implementation with revision 0x3 for the rounding fix upgrade
/// @dev Inherits the patched AToken which uses rayMulFloor in balanceOf/totalSupply
///      and rayDivFloor/rayDivCeil in _mintScaled/_burnScaled
contract ATokenV3 is AToken {
    constructor(IPool pool) AToken(pool) {}

    function getRevision() internal pure override returns (uint256) {
        return 0x3;
    }
}
