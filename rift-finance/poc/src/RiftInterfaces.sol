// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces for the Rift Finance vault / core surface used by the PoCs.
interface IRiftVault {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function pair() external view returns (address);
    function core() external view returns (address);
    function epoch() external view returns (uint256);
    function epochDuration() external view returns (uint256);
    function lastEpochStart() external view returns (uint256);
    function paused() external view returns (bool);
    function depositsEnabled() external view returns (bool); // v2 only; reverts on v1
    function token0FloorNum() external view returns (uint256);
    function token1FloorNum() external view returns (uint256);
    function token0ValueLocked() external view returns (uint256);
    function token1ValueLocked() external view returns (uint256);
    function token0Data() external view returns (uint256, uint256, uint256, uint256, uint256);
    function token1Data() external view returns (uint256, uint256, uint256, uint256, uint256);
    function feesAccrued() external view returns (uint256, uint256);
    function token0Balance(address user) external view returns (uint256, uint256, uint256);
    function token1Balance(address user) external view returns (uint256, uint256, uint256);

    function depositToken0(uint256 amount) external payable;
    function depositToken1(uint256 amount) external;
    function withdrawToken0(uint256 amount) external;
    function withdrawToken1(uint256 amount) external;
    function claimToken0() external;
    function claimToken1() external;
    function nextEpoch(uint256 expectedPoolToken0, uint256 expectedPoolToken1) external;
    function collectFees() external;
    function rescueTokens(address[] calldata tokens, uint256[] calldata amounts) external;
    function unstakeLiquidity() external;
    function pause() external;
    function unpause() external;
    function setToken0Floor(uint256 v) external;
    function setToken1Floor(uint256 v) external;
    function setEpochDuration(uint256 v) external;
}

interface IRiftCore {
    function paused() external view returns (bool);
    function pausedVault() external view returns (bool);
    function protocolFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function whitelistDisabled() external view returns (bool);
    function isWhitelisted(address a) external view returns (bool);
    function GOVERN_ROLE() external view returns (bytes32);
    function STRATEGIST_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function pause() external;
    function unpause() external;
    function setProtocolFee(uint256 v) external;
    function setFeeTo(address a) external;
    function registerVaults(address[] calldata vaults) external;
}

interface IERC20 {
    function balanceOf(address a) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function approve(address s, uint256 v) external returns (bool);
}

interface IUniswapV2PairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address a) external view returns (uint256);
}
