// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------
   Blueberry QC-4 — adversarial re-audit of the ETHEREUM remnants.
   Compares against the prior claim: bank positions not liquidatable,
   compound-fork markets solvent, no unprivileged drain path.

   Read-only fork simulation. NO mainnet transactions, no keys.
------------------------------------------------------------------- */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IUnitroller {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function comptrollerImplementation() external view returns (address);
    function pendingComptrollerImplementation() external view returns (address);
}

interface ICtoken {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function getCash() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function reserveFactorMantissa() external view returns (uint256);
    function comptroller() external view returns (address);
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

contract BlueberryEthQcTest is Test {
    address constant BANK = 0xa34F59F634d48E2c3606048f2367326c46a4B5fA;
    address constant UNITROLLER = 0xcb0D9Ff5BDD34521c6f8CDbeAf15e1A76Fa4dd5D;
    address constant SAFE = 0x72d19f7c71a2bD5E61871B1D3dF7a45ae5Ec9582;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ATTACKER = address(0xdeadbeef03);

    // 13 bToken markets (from prior eth-compound-markets.json)
    address[13] MARKETS = [
        0x045Cb2fFea4c2cef4e9a754Bd02bD6Bb9E0DF841, // bWBTC
        0xb5A7D8c7f85BB48fcF10AD5C3EFB090a3fE40069, // bUSDC
        0xfB8Ddd624E340204F32905692C3fD7da59335E81, // bOHM
        0xdeBd5D482C2B0feeA5527f9B832F7F894c8303eB, // bCRV
        0x643d448CEa0D3616F0b32E3718F563b164e7eDd2, // bWETH
        0x864aDa7223542Ec6eF92789ae524263D7fE9fD96,
        0xc5435051ccc67b4BB8DB8D27f9641C3309b320CC,
        0x65cf55f03e2040D214883f6039FC65fd224E6A47,
        0x23388Cca2BdFC994D75999667E09cc0F5fF1cc88,
        0x9BdeCce77c6351b1941a827e25b5FdC73d69b622,
        0xA51406abFc4658c542b69c2f5a8BAbe61e21B416,
        0xB387fd973358d2DfdE4F3795Bc9d2CCeE6449A40,
        0x141629971a768dE13A33F464E8A40747b01Dfe0a
    ];

    function setUp() public {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc); // latest block
        console2.log("ETH fork block", block.number);
    }

    /* --- Unitroller / comptroller upgrade surface ---------------- */
    function test_qc10_unitroller_admin_closed() public {
        assertEq(IUnitroller(UNITROLLER).admin(), SAFE, "unitroller admin = mgmt Safe");
        assertEq(IUnitroller(UNITROLLER).pendingAdmin(), address(0), "no pending admin");

        // attacker tries to set a pending implementation
        vm.prank(ATTACKER);
        (bool ok, bytes memory ret) = UNITROLLER.call(
            abi.encodeWithSignature("_setPendingImplementation(address)", ATTACKER)
        );
        // Compound-style Unitroller returns error codes; 1 == UNAUTHORIZED
        if (ok) {
            uint256 code = abi.decode(ret, (uint256));
            console2.log("_setPendingImplementation returned code", code);
            assertEq(code, 1, "must be UNAUTHORIZED(1), not NO_ERROR(0)");
        }
        // and the attacker's address was NOT recorded as pending impl
        // NOTE (QC 2026-10-13): the admin has queued a real upgrade at
        // 0x327e45b3444cca9ce1559780cfd44181a175e83c (22,129 bytes); the
        // attacker's call must not alter or claim it.
        address pend = IUnitroller(UNITROLLER).pendingComptrollerImplementation();
        console2.log("pending comptroller impl (admin-queued)", pend);
        assertTrue(pend != ATTACKER, "attacker cannot become pending impl");

        vm.prank(ATTACKER);
        (bool ok2,) = UNITROLLER.call(abi.encodeWithSignature("_acceptImplementation()"));
        if (ok2) {
            assertEq(
                IUnitroller(UNITROLLER).comptrollerImplementation(),
                0xfFadB0bbA4379dFAbFB20CA6823F6EC439429ec2,
                "impl unchanged"
            );
        }
    }

    /* --- cToken admin surface ----------------------------------- */
    function test_qc11_ctoken_admins_closed() public {
        for (uint256 i; i < MARKETS.length; ++i) {
            address m = MARKETS[i];
            address adm = ICtoken(m).admin();
            assertTrue(adm != address(0) && adm != ATTACKER, "market has real admin");
            assertEq(ICtoken(m).pendingAdmin(), address(0), "no pending admin");

            // attacker cannot reduce reserves (admin-only in Compound forks)
            vm.prank(ATTACKER);
            (bool ok, bytes memory ret) = m.call(
                abi.encodeWithSignature("_reduceReserves(uint256)", uint256(1))
            );
            if (ok) {
                // some forks return an error code instead of reverting
                uint256 code = abi.decode(ret, (uint256));
                assertTrue(code != 0, "attacker _reduceReserves not allowed");
            }
        }
        console2.log("13/13 markets: admin set, pending 0, attacker cannot reduce reserves");
    }

    /* --- bank liquidation / ownership guards -------------------- */
    function test_qc12_bank_guards() public {
        assertEq(IBank(BANK).owner(), SAFE, "bank owner = mgmt Safe");
        assertEq(IBank(BANK).getBankStatus(), 15, "all flows open");
        assertGe(IBank(BANK).getNextPositionId(), 40, "positions 0..39+");

        for (uint256 id = 38; id <= 39; ++id) {
            bool liq = IBank(BANK).isLiquidatable(id);
            uint256 risk = IBank(BANK).getPositionRisk(id);
            uint256 val = IBank(BANK).getPositionValue(id);
            console2.log("position", id);
            console2.log("   value", val);
            console2.log("   risk", risk);
            console2.log("   liquidatable", liq);
            assertFalse(liq, "position not liquidatable");
            assertEq(risk, 0, "risk 0");
        }

        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IBank(BANK).liquidate(38, USDC, 1e6);
        vm.expectRevert();
        IBank(BANK).liquidate(39, WETH, 1e15);

        // execute with an unwhitelisted spell must revert (and position 38 is not ours anyway)
        (bool ok,) = BANK.call(
            abi.encodeWithSignature("execute(uint256,address,bytes)", uint256(38), ATTACKER, bytes(""))
        );
        assertFalse(ok, "execute by attacker reverts");
        vm.stopPrank();

        // bank holds no free tokens an attacker could reach
        assertEq(IERC20(USDC).balanceOf(BANK), 0, "bank USDC 0");
        assertEq(IERC20(USDT).balanceOf(BANK), 0, "bank USDT 0");
        assertEq(IERC20(WETH).balanceOf(BANK), 0, "bank WETH 0");
    }

    /* --- compound-fork solvency sanity -------------------------- */
    function test_qc13_market_solvency() public {
        uint256 totalCash;
        for (uint256 i; i < MARKETS.length; ++i) {
            address m = MARKETS[i];
            uint256 cash = ICtoken(m).getCash();
            uint256 borrows = ICtoken(m).totalBorrows();
            uint256 res = ICtoken(m).totalReserves();
            totalCash += cash + borrows - res;
            assertEq(ICtoken(m).comptroller(), UNITROLLER, "market bound to unitroller");
        }
        console2.log("13-market total assets (raw sum, mixed decimals):", totalCash);
        assertGt(totalCash, 0, "markets still hold value");
    }
}
