// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IHyperswapV3PoolImmutables.sol';
import './pool/IHyperswapV3PoolState.sol';
import './pool/IHyperswapV3PoolDerivedState.sol';
import './pool/IHyperswapV3PoolActions.sol';
import './pool/IHyperswapV3PoolOwnerActions.sol';
import './pool/IHyperswapV3PoolEvents.sol';

/// @dev The pool interface is broken up into many smaller pieces
interface IHyperswapV3Pool is
    IHyperswapV3PoolImmutables,
    IHyperswapV3PoolState,
    IHyperswapV3PoolDerivedState,
    IHyperswapV3PoolActions,
    IHyperswapV3PoolOwnerActions,
    IHyperswapV3PoolEvents
{

}
