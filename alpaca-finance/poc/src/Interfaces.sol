// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IVault {
    function deposit(uint256 amountToken) external payable;
    function withdraw(uint256 share) external;
    function totalToken() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function vaultDebtVal() external view returns (uint256);
    function vaultDebtShare() external view returns (uint256);
    function reservePool() external view returns (uint256);
    function token() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function work(
        uint256 id,
        address worker,
        uint256 principalAmount,
        uint256 borrowAmount,
        uint256 maxReturn,
        bytes calldata data
    ) external payable;
    function kill(uint256 id) external;
    function forceClose(uint256 id, bytes calldata data) external;
    function withdrawReserve(address to, uint256 value) external;
    function migrated() external view returns (bool);
    function newIbToken() external view returns (address);
}

interface IVaultConfig {
    function acceptDebt(address) external view returns (bool);
    function isWorker(address) external view returns (bool);
    function whitelistedLiquidators(address) external view returns (bool);
    function whitelistedCallers(address) external view returns (bool);
}

interface IWorker {
    function totalShare() external view returns (uint256);
    function lpToken() external view returns (address);
}
