// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Pool} from "lib/yei-contracts/contracts/protocol/pool/Pool.sol";
import {IPoolAddressesProvider} from "lib/yei-contracts/contracts/interfaces/IPoolAddressesProvider.sol";

/// @title PoolV3
/// @notice Pool implementation with revision 0x3 for the rounding fix upgrade
/// @dev Inherits the patched Pool which uses directional rounding in SupplyLogic
contract PoolV3 is Pool {
    constructor(IPoolAddressesProvider provider) Pool(provider) {}

    function getRevision() internal pure override returns (uint256) {
        return 0x3;
    }
}
