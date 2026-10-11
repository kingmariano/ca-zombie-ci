// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------
   Blueberry (Ethereum remnants) — read-only fork PoC.
   V1 bank + Compound-fork bToken markets. NO mainnet transactions.
------------------------------------------------------------------- */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IBank {
    function owner() external view returns (address);
    function getBankStatus() external view returns (uint256);
    function getNextPositionId() external view returns (uint256);
    function getPositionValue(uint256) external view returns (uint256);
    function getDebtValue(uint256) external view returns (uint256);
    function isLiquidatable(uint256) external view returns (bool);
    function getPositionRisk(uint256) external view returns (uint256);
    function liquidate(uint256, address, uint256) external;
}

interface IBToken {
    function getCash() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function underlying() external view returns (address);
    function redeem(uint256) external returns (uint256);
    function comptroller() external view returns (address);
}

contract BlueberryEthTest is Test {

    address constant BANK = 0xa34F59F634d48E2c3606048f2367326c46a4B5fA;
    address constant COMPTROLLER = 0xcb0D9Ff5BDD34521c6f8CDbeAf15e1A76Fa4dd5D;
    address constant BWBTC = 0x045Cb2fFea4c2cef4e9a754Bd02bD6Bb9E0DF841;
    address constant BUSDC = 0xb5A7D8c7f85BB48fcF10AD5C3EFB090a3fE40069;
    address constant BOHM = 0xfB8Ddd624E340204F32905692C3fD7da59335E81;
    address constant BCRV = 0xdeBd5D482C2B0feeA5527f9B832F7F894c8303eB;
    address constant BWETH = 0x643d448CEa0D3616F0b32E3718F563b164e7eDd2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ATTACKER = address(0xdeadbeef02);

    function setUp() public {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc); // latest block (state is static; avoids archive requirement)
        console2.log("ETH fork block", block.number);
    }

    function test_eth_bank_state_and_no_liquidation_path() public {
        console2.log("bank owner", IBank(BANK).owner());
        console2.log("bank status (15=all open)", IBank(BANK).getBankStatus());
        console2.log("nextPositionId", IBank(BANK).getNextPositionId());
        uint256 n = IBank(BANK).getNextPositionId();
        uint256 totalValue;
        for (uint256 i = 0; i < n; i++) {
            uint256 v = IBank(BANK).getPositionValue(i);
            totalValue += v;
            if (v > 0) {
                console2.log("position", i, "value(1e18 USD)", v);
                console2.log("   debt", IBank(BANK).getDebtValue(i));
                console2.log("   risk", IBank(BANK).getPositionRisk(i));
                console2.log("   liquidatable", IBank(BANK).isLiquidatable(i));
                assertFalse(IBank(BANK).isLiquidatable(i), "position not liquidatable");
            }
        }
        console2.log("total bank position value(1e18)", totalValue);

        // attacker liquidation attempt on position 38 must revert
        vm.prank(ATTACKER);
        vm.expectRevert();
        IBank(BANK).liquidate(38, USDC, 1e6);

        vm.prank(ATTACKER);
        vm.expectRevert();
        IBank(BANK).liquidate(39, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1e15);
    }

    function test_eth_compound_markets_liquidity() public {
        address[5] memory mkts = [BWBTC, BUSDC, BOHM, BCRV, BWETH];
        uint256 totalUsdcLike;
        for (uint256 i = 0; i < 5; i++) {
            uint256 cash = IBToken(mkts[i]).getCash();
            uint256 borrows = IBToken(mkts[i]).totalBorrows();
            uint256 reserves = IBToken(mkts[i]).totalReserves();
            console2.log("market", mkts[i]);
            console2.log("  cash", cash);
            console2.log("  borrows", borrows);
            console2.log("  reserves", reserves);
            if (mkts[i] == BUSDC) {
                assertGt(cash, 1_000e6, "bUSDC has >1k USDC cash -> redeemable");
                totalUsdcLike = cash + borrows - reserves;
            }
        }
        console2.log("bUSDC net assets", totalUsdcLike);
        assertEq(IBToken(BUSDC).comptroller(), COMPTROLLER, "market linked to fork comptroller");
    }
}
