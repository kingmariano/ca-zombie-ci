// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal interfaces for the Nile CL (Linea) closure tests.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IClPoolMin {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function protocolFees() external view returns (uint128, uint128);
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128, uint128);
    function collect(
        address recipient,
        uint256 index,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128, uint128);
    function initialize(uint160 sqrtPriceX96) external;
    function setFeeProtocol() external;
}

interface IClFactoryMin {
    function owner() external view returns (address);
    function feeCollector() external view returns (address);
    function feeSetter() external view returns (address);
    function implementation() external view returns (address);
    function nfpManager() external view returns (address);
    function voter() external view returns (address);
    function feeProtocol() external view returns (uint8);
    function poolFeeProtocol(address pool) external view returns (uint8);
    function getPool(address, address, uint24) external view returns (address);
    function setImplementation(address) external;
    function setOwner(address) external;
    function enableFeeAmount(uint24, int24) external;
    function initializePool(address, address, uint24, uint160) external returns (address);
}

interface IProxyAdminMin {
    function owner() external view returns (address);
    function upgrade(address proxy, address implementation) external;
    function upgradeAndCall(address proxy, address implementation, bytes calldata data)
        external
        payable;
}

interface INonfungiblePositionManagerMin {
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
        uint256 deadline;
    }

    function ownerOf(uint256) external view returns (address);
    function positions(uint256)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256, uint256);
    function collect(CollectParams calldata params) external payable returns (uint256, uint256);
}

interface IFeeCollectorMin {
    function treasury() external view returns (address);
    function treasuryFees() external view returns (uint256);
    function voter() external view returns (address);
    function collectProtocolFees(address pool) external;
}

interface IGaugeV2Min {
    function feeCollector() external view returns (address);
    function voter() external view returns (address);
    function pool() external view returns (address);
    function nfpManager() external view returns (address);
    function retrieveLeftovers(address[] calldata tokens, uint256[] calldata periods) external;
    function getReward(uint256 tokenId, address[] calldata tokens) external;
    function getRewardForOwner(uint256 tokenId, address[] calldata tokens) external;
}

interface IFeeDistributorMin {
    function voter() external view returns (address);
    function getReward(uint256 tokenId, address[] memory tokens) external;
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) external;
    function getPeriodReward(uint256 period, uint256 tokenId, address token) external;
    function earned(address token, uint256 tokenId) external view returns (uint256);
    function votes(uint256 period) external view returns (uint256);
    function userVotes(uint256 period, uint256 tokenId) external view returns (uint256);
    function userClaimed(uint256 period, uint256 tokenId, address token)
        external
        view
        returns (uint256);
    function rewardSupply(uint256 period, address token) external view returns (uint256);
}

interface IVoterMin {
    function gauges(address pool) external view returns (address);
    function isAlive(address gauge) external view returns (bool);
    function feeDistributors(address gauge) external view returns (address);
    function governor() external view returns (address);
    function _ve() external view returns (address);
    function minter() external view returns (address);
}

interface ITimelockMin {
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IBribeHolderMin {
    function owner() external view returns (address);
    function fetch(address[] calldata tokens) external;
}
