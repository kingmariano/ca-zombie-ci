pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../../Core/LendingNetwork/OTokens/CToken.sol";
import "../../Core/LendingNetwork/PriceOracle/PriceOracle.sol";
import "../../Core/Interfaces/EIP20Interface.sol";

interface CErc20ForUniswapConfigOlaLens {
    function underlying() external view returns (address);
}

interface DynamicRainMakerForOlaLens {
    function compSpeeds(address cToken) external view returns (uint);

    function compSupplySpeeds(address cToken) external view returns (uint);

    function compBorrowSpeeds(address cToken) external view returns (uint);

    function claimComp(address holder) external;

    function compAccrued(address holder) external view returns (uint);

    function lnIncentiveTokenAddress() external view returns (EIP20Interface);
}

interface MinistryOlaLensInterface {
    function getOracleForAsset(address asset) external view returns (PriceOracle);

    function getPriceForAsset(address asset) external view returns (uint256);
}

interface ComptrollerOlaLensInterface {
    // isListed, collateralFactorMantissa, liquidationFactorMantissa, liquidationIncentiveMantissa
    function markets(address) external view returns (bool, uint, uint, uint);
    // function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    // OLA_ADDITIONS : liquidity by factor
    function getAccountLiquidityByLiquidationFactor(address) external view returns (uint, uint, uint);

    function getAssetsIn(address) external view returns (CToken[] memory);

    function getAllMarkets() external view returns (CToken[] memory);
    // function claimComp(address) external;
    // function compAccrued(address) external view returns (uint);
    // function compSpeeds(address) external view returns (uint);

    function getRegistry() external view returns (MinistryOlaLensInterface);

    // NOTE : For now assuming only one type of RainMaker
    function rainMaker() external view returns (DynamicRainMakerForOlaLens);

    function hasRainMaker() view external returns (bool);
}

// IMPORTANT : We currently assume that the native coin has 18 decimals.

contract OlaLens {
    struct RainBalances {
        uint balance;
        uint allocated;
    }

    function calculateActiveRainBalances(ComptrollerOlaLensInterface comptroller, address account) external returns (RainBalances memory) {
        uint balance;
        uint allocated;

        if (comptroller.hasRainMaker()) {
            return calculateRainBalancesInternal(comptroller.rainMaker(), account);
        } else {
            return RainBalances({
            balance : 0,
            allocated : 0
            });
        }
    }

    function calculateRainBalances(DynamicRainMakerForOlaLens rainMaker, address account) external returns (RainBalances memory) {
        return calculateRainBalancesInternal(rainMaker, account);
    }

    function calculateRainBalancesInternal(DynamicRainMakerForOlaLens rainMaker, address account) internal returns (RainBalances memory) {
        EIP20Interface rainyToken = rainMaker.lnIncentiveTokenAddress();

        uint balance = rainyToken.balanceOf(account);

        rainMaker.claimComp(account);

        uint newBalance = rainyToken.balanceOf(account);
        uint accrued = 0;

        accrued = rainMaker.compAccrued(account);

        uint total = add(accrued, newBalance, "sum comp total");
        uint allocated = sub(total, balance, "sub allocated");

        return RainBalances({
        balance : balance,
        allocated : allocated
        });
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
}
