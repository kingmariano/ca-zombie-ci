// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

/// Minimal CogPair (Vyper) interface — functions used by the PoC.
interface ICogPair {
    function asset() external view returns (address);
    function collateral() external view returns (address);
    function oracle() external view returns (address);
    function paused() external view returns (bool);
    function exchange_rate() external view returns (uint256);
    function total_asset() external view returns (uint128 elastic, uint128 base);
    function total_borrow() external view returns (uint128 elastic, uint128 base);
    function total_collateral_share() external view returns (uint256);
    function user_borrow_part(address) external view returns (uint256);
    function user_collateral_share(address) external view returns (uint256);
    function add_collateral(address to, uint256 amount) external;
    function borrow(uint256 amount, address _from, address to) external returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function liquidate(address user, uint256 max_borrow_parts, address to) external;
    function get_exchange_rate() external returns (bool updated, uint256 rate);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
