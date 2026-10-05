// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface ILido is IERC20 {
    function submit(address _referral) external payable returns (uint256);
    function getCurrentStakeLimit() external view returns (uint256);
}

interface IPriceFeed {
    function fetchPrice() external returns (uint256);
}

interface ILybra is IERC20 {
    function depositedEther(address) external view returns (uint256);
    function getBorrowedOf(address) external view returns (uint256);
    function totalDepositedEther() external view returns (uint256);
    function totalEUSDCirculation() external view returns (uint256);
    function getTotalShares() external view returns (uint256);
    function safeCollateralRate() external view returns (uint256);
    function keeperRate() external view returns (uint8);
    function depositStETHToMint(address onBehalfOf, uint256 stETHamount, uint256 mintAmount) external;
    function depositEtherToMint(address onBehalfOf, uint256 mintAmount) external payable;
    function mint(address onBehalfOf, uint256 amount) external;
    function withdraw(address onBehalfOf, uint256 amount) external;
    function liquidation(address provider, address onBehalfOf, uint256 etherAmount) external;
    function superLiquidation(address provider, address onBehalfOf, uint256 etherAmount) external;
    function excessIncomeDistribution(uint256 payAmount) external;
}

interface ICurveStableSwap {
    // coins(0) = eUSD, coins(1) = USDC
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
}
