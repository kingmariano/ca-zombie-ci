// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingServiceBase {
    struct PoolEthInfo {
        PoolType poolType;
        address poolCurve; //Curve
        uint88 fee; //UNIV3
        address token;
        uint48 indexEth; //Curve
        uint48 indexAsset; //Curve
    }

    enum PoolType {
        DEACTIVATED,
        UNIV2,
        UNIV3,
        CURVE_DUO,
        CURVE_TRI
    }

    function setBuffer(address _buffer) external;
}
