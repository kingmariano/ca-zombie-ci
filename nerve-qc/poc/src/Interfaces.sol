// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ISwap {
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function getVirtualPrice() external view returns (uint256);
    function getA() external view returns (uint256);
    function getAPrecise() external view returns (uint256);
    function getToken(uint8 i) external view returns (address);
    function getTokenBalance(uint8 i) external view returns (uint256);
    function getAdminBalance(uint256 i) external view returns (uint256);
    function calculateSwap(uint8 f, uint8 t, uint256 dx) external view returns (uint256);
    function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);
    function calculateRemoveLiquidityOneToken(address a, uint256 amt, uint8 idx) external view returns (uint256);
    function calculateTokenAmount(address a, uint256[] calldata amounts, bool deposit) external view returns (uint256);
    function swap(uint8 f, uint8 t, uint256 dx, uint256 minDy, uint256 deadline) external returns (uint256);
    function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external returns (uint256);
    function removeLiquidity(uint256 amount, uint256[] calldata minAmounts, uint256 deadline)
        external
        returns (uint256[] memory);
    function removeLiquidityOneToken(uint256 amt, uint8 idx, uint256 minAmount, uint256 deadline)
        external
        returns (uint256);
    function removeLiquidityImbalance(uint256[] calldata amounts, uint256 maxBurn, uint256 deadline)
        external
        returns (uint256);
    function withdrawAdminFees() external;
    function pause() external;
    function unpause() external;
    function setSwapFee(uint256) external;
    function setAdminFee(uint256) external;
    function rampA(uint256, uint256) external;
    function stopRampA() external;
    function setDevAddress(address) external;
    function transferOwnership(address) external;
    
}

interface IMetaSwap is ISwap {
    function swapUnderlying(uint8 f, uint8 t, uint256 dx, uint256 minDy, uint256 deadline)
        external
        returns (uint256);
    function metaSwapStorage() external view returns (address baseSwap, uint256 baseVirtualPrice, uint256 baseCacheLastUpdated);
    function initializeMetaSwap(
        IERC20[] calldata _pooledTokens,
        uint8[] calldata decimals,
        string calldata lpTokenName,
        string calldata lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        uint256 _depositFee,
        uint256 _withdrawFee,
        address _devaddr,
        ISwap baseSwap
    ) external;
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function VERSION() external view returns (string memory);
}

interface IFarm {
    function poolLength() external view returns (uint256);
    function poolInfo(uint256) external view returns (address, uint256, uint256, uint256);
    function userInfo(uint256, address) external view returns (uint256, uint256);
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function add(uint256, IERC20, bool) external;
    function set(uint256, uint256, bool) external;
    function owner() external view returns (address);
    function totalAllocPoint() external view returns (uint256);
    function nerve() external view returns (address);
}
