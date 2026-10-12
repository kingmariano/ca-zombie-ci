// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {SignedInt} from "../lib/SignedInt.sol";
import {Position} from "../pool/PoolStorage.sol";
import {Side} from "./IPool.sol";


interface IPoolForOrderManager {
    function increasePosition(
        address _account,
        address _indexToken,
        address _collateralToken,
        uint256 _sizeChanged,
        Side _side
    ) external;

    function decreasePosition(
        address _account,
        address _indexToken,
        address _collateralToken,
        uint256 _desiredCollateralReduce,
        uint256 _sizeChanged,
        Side _side,
        address _receiver
    ) external;

    function validateToken(address indexToken, address collateralToken, Side side, bool isIncrease)
        external
        view
        returns (bool);

    function swap(address _tokenIn, address _tokenOut, uint256 _minOut, address _to, bytes calldata extradata)
        external;

    function getPositionKey(address _owner, address _indexToken, address _collateralToken, Side _side)
    external
    pure
    returns (bytes32);
    
    function positions(bytes32) external view returns (Position memory);

    function isListed(address) external returns (bool);
    function isAsset(address) external returns (bool);
}
