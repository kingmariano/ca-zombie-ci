// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

// tokens with no return value on approve/transfer (old Vyper / USDT-style)
interface IERC20NoRet {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}

interface IVaultV1 {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function balance() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function token() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function earn() external;
}

interface IWETH {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IIEarnVault {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function balance() external view returns (uint256);
    function calcPoolValueInToken() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function token() external view returns (address);
    function fulcrum() external view returns (address);
    function provider() external view returns (uint8);
    function balanceDydx() external view returns (uint256);
    function balanceAave() external view returns (uint256);
    function balanceCompoundInToken() external view returns (uint256);
    function balanceFulcrumInToken() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function rebalance() external;
}

// early iEarn prototype (ySUSD v1): invest/redeem instead of deposit/withdraw
interface IEarnV1Token {
    function invest(uint256) external;
    function redeem(uint256) external;
    function balanceOf(address) external view returns (uint256);
}

interface IFulcrum {
    function assetBalanceOf(address) external view returns (uint256);
    function loanTokenAddress() external view returns (address);
}

interface ICurveYPool {
    function exchange(int128, int128, uint256, uint256) external;
    function balances(int128) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface ICurveStableNG {
    function exchange(int128, int128, uint256, uint256) external;
    function balances(uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IYEthPool {
    function paused() external view returns (bool);
    function remove_liquidity(uint256, uint256[] calldata) external;
}

interface IStateView {
    function getSlot0(bytes32) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
    function getLiquidity(bytes32) external view returns (uint128 liquidity);
}

contract C31Test is Test {
    uint256 constant BLOCK = 26_108_888;

    address attacker;

    // tokens
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20NoRet constant USDT = IERC20NoRet(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant TUSD = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
    IERC20 constant SUSD = IERC20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
    IERC20 constant BUSD = IERC20(0x4Fabb145d64652a948d72533023f6E7A623C7C53);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant YETH = IERC20(0x1BED97CBC3c24A4fb5C069C6E311a967386131f7);

    // iEarn family
    IIEarnVault constant yTUSD = IIEarnVault(0x73a052500105205d34Daf004eAb301916DA8190f);
    IIEarnVault constant yUSDT_v1 = IIEarnVault(0xE6354ed5bC4b393a5Aad09f21c46E101e692d447);
    IIEarnVault constant yUSDT_v2 = IIEarnVault(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
    IIEarnVault constant yUSDT_v3 = IIEarnVault(0xa1787206d5b1bE0f432C4c4f96Dc4D1257A1Dd14);
    IIEarnVault constant yBUSD = IIEarnVault(0x04bC0Ab673d88aE9dbC9DA2380cB6B79C4BCa9aE);
    IIEarnVault constant yDAI_v1 = IIEarnVault(0x9D25057e62939D3408406975aD75Ffe834DA4cDd);
    IIEarnVault constant yDAI_v2 = IIEarnVault(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);
    IIEarnVault constant yDAI_v3 = IIEarnVault(0xC2cB1040220768554cf699b0d863A3cd4324ce32);
    IIEarnVault constant yUSDC_v1 = IIEarnVault(0x26EA744E5B887E5205727f55dFBE8685e3b21951);
    IIEarnVault constant yUSDC_v2 = IIEarnVault(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);
    IIEarnVault constant yUSDC_v3 = IIEarnVault(0xa2609B2b43AC0F5EbE27deB944d2a399C201E3dA);
    IEarnV1Token constant ySUSD_v1 = IEarnV1Token(0x36324b8168f960A12a8fD01406C9C78143d41380);
    IIEarnVault constant ySUSD_v2 = IIEarnVault(0xF61718057901F84C4eEC4339EF8f0D86D2B45600);

    // bZx iTokens
    IFulcrum constant iSUSD = IFulcrum(0x49f4592E641820e928F9919Ef4aBd92a719B4b49);
    IFulcrum constant iUSDC = IFulcrum(0xF013406A0B1d544238083DF0B93ad0d2cBE0f65f);

    // registry v1 vaults
    IVaultV1 constant yWETH = IVaultV1(0xe1237aA7f535b0CC33Fd973D66cBf830354D16c7);
    IVaultV1 constant yDAI_reg = IVaultV1(0xACd43E627e64355f1861cEC6d3a6688B31a6F952);
    IVaultV1 constant yUSDC_reg = IVaultV1(0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e);
    IVaultV1 constant dustVault = IVaultV1(0x39546945695DCb1c037C836925B355262f551f55); // yvhusd3CRV, ts=0, dust balance

    // Curve / yETH
    ICurveYPool constant yPool = ICurveYPool(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurveStableNG constant yethWethPool = ICurveStableNG(0x69ACcb968B19a53790f43e57558F5E443A91aF22);
    IYEthPool constant yethMainPool = IYEthPool(0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81);
    IERC20 constant stYETH = IERC20(0x583019fF0f430721aDa9cfb4fac8F06cA104d0B4);
    IStateView constant stateView = IStateView(0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227);
    bytes32 constant V4_YETH_USDC = 0x1391C343F74903f4929F34AfddF354Fa9De2C4ab311f1251d46a6efd41dd10f3;

    function setUp() public {
        // Prefer archive-capable RPCs (the pinned block ages past full-node retention).
        string memory rpc = vm.envOr(
            "NODEREAL_ETH_RPC_URL",
            vm.envOr(
                "BLOCKPI_RPC_URL",
                vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://eth.drpc.org")))
            )
        );
        try vm.createSelectFork(rpc, BLOCK) returns (uint256) {} catch {
            vm.createSelectFork(rpc);
        }
        attacker = vm.addr(0xA11CE);
        vm.label(attacker, "attacker");
    }

    /* ---------------------------------- state ---------------------------------- */

    function test_iEarn_family_live_state() public view {
        // yTUSD: underlying TUSD, fulcrum = iSUSD (sUSD) -> cross-asset config rot
        assertEq(yTUSD.token(), address(TUSD));
        assertEq(yTUSD.fulcrum(), address(iSUSD));
        assertEq(iSUSD.loanTokenAddress(), address(SUSD));
        assertEq(yTUSD.calcPoolValueInToken(), 449_999_492_364_569_403_096);
        assertEq(yTUSD.getPricePerFullShare(), 8546);
        assertEq(yTUSD.totalSupply(), 52_651_920_818_295_896_613_506_985_369_714_294);

        // yUSDT v1/v2/v3: underlying USDT, fulcrum = iUSDC -> cross-asset config rot
        assertEq(yUSDT_v1.token(), address(USDT));
        assertEq(yUSDT_v1.fulcrum(), address(iUSDC));
        assertEq(iUSDC.loanTokenAddress(), address(USDC));
        assertEq(yUSDT_v1.calcPoolValueInToken(), 11_339_655_467);
        assertEq(yUSDT_v1.getPricePerFullShare(), 298_222_623);

        assertEq(yUSDT_v2.calcPoolValueInToken(), 1_452_056_826);
        assertEq(yUSDT_v2.getPricePerFullShare(), 7_983_181);

        assertApproxEqRel(yUSDT_v3.calcPoolValueInToken(), 1_210_369, 1e16);

        // yBUSD: underlying BUSD, fulcrum = iUSDC -> cross-asset config rot
        assertEq(yBUSD.token(), address(BUSD));
        assertEq(yBUSD.fulcrum(), address(iUSDC));
        assertEq(yBUSD.calcPoolValueInToken(), 15_250_744_062_483_163_256_993);
        assertEq(yBUSD.balance(), 12_515_749_147_191_172_427_603);
        assertApproxEqRel(yBUSD.balanceAave(), 2_734_994_915_291_990_829_390, 1e16);

        // yDAI v2: all assets in dYdX Solo
        assertApproxEqRel(yDAI_v2.calcPoolValueInToken(), 390_573_859_866_555_538_256_588, 1e16);
        assertApproxEqRel(yDAI_v2.balanceDydx(), 390_573_859_866_555_538_256_588, 1e16);
        assertEq(yDAI_v2.balance(), 0);

        // yUSDC v2: 289,048.94 USDC in dYdX + 131.87 idle
        assertApproxEqRel(yUSDC_v2.calcPoolValueInToken(), 289_180_809_022, 1e16);
        assertApproxEqRel(yUSDC_v2.balanceDydx(), 289_048_941_647, 1e16);
        assertEq(yUSDC_v2.balance(), 131_867_375);

        // ySUSD v2: 48,484.24 sUSD in Aave v1
        assertApproxEqRel(ySUSD_v2.calcPoolValueInToken(), 48_484_237_103_182_343_385_743, 1e16);
        assertApproxEqRel(ySUSD_v2.balanceAave(), 48_484_237_103_182_343_385_743, 1e16);
    }

    function test_iToken_assetBalanceOf_reverts_donation_path_closed() public {
        // The 2025-12 yTUSD exploit credited iSUSD via assetBalanceOf.
        // Today assetBalanceOf reverts on every bZx iToken -> any iToken donation to a
        // vault makes calcPoolValueInToken() revert (DoS), it cannot mint value.
        (bool ok1,) = address(iSUSD).staticcall(abi.encodeWithSelector(IFulcrum.assetBalanceOf.selector, address(yTUSD)));
        assertFalse(ok1, "iSUSD.assetBalanceOf must revert today");
        (bool ok2,) = address(iUSDC).staticcall(abi.encodeWithSelector(IFulcrum.assetBalanceOf.selector, address(yUSDT_v1)));
        assertFalse(ok2, "iUSDC.assetBalanceOf must revert today");
        (bool ok3,) = address(iUSDC).staticcall(abi.encodeWithSelector(IFulcrum.assetBalanceOf.selector, address(yBUSD)));
        assertFalse(ok3, "iUSDC.assetBalanceOf must revert today");
    }

    /* ------------------------------- round trips ------------------------------- */

    function test_yTUSD_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e18;
        deal(address(TUSD), attacker, amount);
        vm.startPrank(attacker);
        TUSD.approve(address(yTUSD), amount);
        uint256 before = TUSD.balanceOf(attacker);
        yTUSD.deposit(amount);
        uint256 shares = yTUSD.balanceOf(attacker);
        yTUSD.withdraw(shares);
        uint256 afterBal = TUSD.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yTUSD deposit/withdraw: in", before);
        console2.log("out", afterBal);
        console2.log("shares", shares);
        assertLe(afterBal, before, "no profit from yTUSD round trip");
    }

    function test_yUSDT_v1_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e6;
        deal(address(USDT), attacker, amount);
        vm.startPrank(attacker);
        USDT.approve(address(yUSDT_v1), amount);
        uint256 before = USDT.balanceOf(attacker);
        yUSDT_v1.deposit(amount);
        uint256 shares = yUSDT_v1.balanceOf(attacker);
        yUSDT_v1.withdraw(shares);
        uint256 afterBal = USDT.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yUSDT_v1 round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before, "no profit from yUSDT v1 round trip");
    }

    function test_yUSDT_v2_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e6;
        deal(address(USDT), attacker, amount);
        vm.startPrank(attacker);
        USDT.approve(address(yUSDT_v2), amount);
        uint256 before = USDT.balanceOf(attacker);
        yUSDT_v2.deposit(amount);
        yUSDT_v2.withdraw(yUSDT_v2.balanceOf(attacker));
        uint256 afterBal = USDT.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yUSDT_v2 round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before);
    }

    function test_yBUSD_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e18;
        deal(address(BUSD), attacker, amount);
        vm.startPrank(attacker);
        BUSD.approve(address(yBUSD), amount);
        uint256 before = BUSD.balanceOf(attacker);
        yBUSD.deposit(amount);
        yBUSD.withdraw(yBUSD.balanceOf(attacker));
        uint256 afterBal = BUSD.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yBUSD round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before);
    }

    function test_yDAI_v2_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e18;
        deal(address(DAI), attacker, amount);
        vm.startPrank(attacker);
        DAI.approve(address(yDAI_v2), amount);
        uint256 before = DAI.balanceOf(attacker);
        yDAI_v2.deposit(amount);
        yDAI_v2.withdraw(yDAI_v2.balanceOf(attacker));
        uint256 afterBal = DAI.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yDAI_v2 round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before);
    }

    // Existing shares (acquired, not deposited) force the venue withdrawal path (dYdX Solo)
    function test_yDAI_v2_existingShares_withdraw_via_dydx() public {
        uint256 shares = 100e18;
        deal(address(yDAI_v2), attacker, shares);
        uint256 dydxBefore = yDAI_v2.balanceDydx();
        vm.prank(attacker);
        yDAI_v2.withdraw(shares);
        uint256 got = DAI.balanceOf(attacker);
        uint256 dydxAfter = yDAI_v2.balanceDydx();
        console2.log("yDAI_v2 existing shares withdraw: DAI out", got);
        console2.log("dydx before", dydxBefore);
        console2.log("after", dydxAfter);
        assertGt(got, 0, "dYdX withdrawal path must pay DAI");
        assertLt(dydxAfter, dydxBefore, "dYdX position must shrink");
    }

    // Aave v1 aToken redemption path (ySUSD v1, all assets in aSUSD; invest/redeem ABI).
    // Outcome is recorded: if Aave v1 sUSD has no liquidity the exit reverts (stuck).
    function test_ySUSD_v1_existingShares_redeem_via_aave() public {
        uint256 shares = 10e18;
        deal(address(ySUSD_v1), attacker, shares);
        uint256 poolBefore = IIEarnVault(address(ySUSD_v1)).calcPoolValueInToken();
        vm.prank(attacker);
        (bool ok, bytes memory ret) = address(ySUSD_v1).call(
            abi.encodeWithSignature("redeem(uint256)", shares)
        );
        uint256 got = SUSD.balanceOf(attacker);
        uint256 poolAfter = IIEarnVault(address(ySUSD_v1)).calcPoolValueInToken();
        console2.log("ySUSD_v1 redeem success", ok);
        console2.log("revert data len", ret.length);
        console2.log("sUSD out", got);
        console2.log("pool before", poolBefore);
        console2.log("pool after", poolAfter);
        if (ok) {
            assertGt(got, 0, "successful redeem must pay sUSD");
            assertLt(poolAfter, poolBefore, "pool must shrink");
        } else {
            assertEq(got, 0, "failed redeem pays nothing");
        }
    }

    /* ------------------------------ registry vaults ----------------------------- */

    function test_yWETH_deposit_withdraw_no_profit_and_earn() public {
        uint256 amount = 1 ether;
        vm.deal(attacker, amount);
        vm.startPrank(attacker);
        IWETH(address(WETH)).deposit{value: amount}();
        WETH.approve(address(yWETH), amount);
        uint256 before = WETH.balanceOf(attacker);
        yWETH.deposit(amount);
        yWETH.withdraw(yWETH.balanceOf(attacker));
        uint256 afterBal = WETH.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yWETH round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before, "no profit from yWETH round trip");

        // earn() is permissionless; log whether the (dead) strategy path still executes
        uint256 vaultBalBefore = WETH.balanceOf(address(yWETH));
        vm.prank(attacker);
        (bool ok,) = address(yWETH).call(abi.encodeWithSelector(IVaultV1.earn.selector));
        uint256 vaultBalAfter = WETH.balanceOf(address(yWETH));
        console2.log("yWETH.earn() success", ok);
        console2.log("vault WETH before", vaultBalBefore);
        console2.log("after", vaultBalAfter);
    }

    function test_yUSDC_reg_deposit_withdraw_no_profit() public {
        uint256 amount = 100e6;
        deal(address(USDC), attacker, amount);
        vm.startPrank(attacker);
        USDC.approve(address(yUSDC_reg), amount);
        uint256 before = USDC.balanceOf(attacker);
        yUSDC_reg.deposit(amount);
        yUSDC_reg.withdraw(yUSDC_reg.balanceOf(attacker));
        uint256 afterBal = USDC.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yUSDC_reg round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before);
    }

    function test_yDAI_reg_deposit_withdraw_no_profit() public {
        uint256 amount = 1_000e18;
        deal(address(DAI), attacker, amount);
        vm.startPrank(attacker);
        DAI.approve(address(yDAI_reg), amount);
        uint256 before = DAI.balanceOf(attacker);
        yDAI_reg.deposit(amount);
        yDAI_reg.withdraw(yDAI_reg.balanceOf(attacker));
        uint256 afterBal = DAI.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yDAI_reg round trip: in", before);
        console2.log("out", afterBal);
        assertLe(afterBal, before);
    }

    // A vault with totalSupply == 0 but a positive (dust) balance: this yVault variant
    // mints 1:1 shares whenever totalSupply == 0, so the first depositor captures the dust.
    function test_dust_vault_first_depositor_captures_dust() public {
        uint256 dust = dustVault.balance();
        assertGt(dust, 0, "dust vault must hold dust");
        assertEq(dustVault.totalSupply(), 0);
        address lp = dustVault.token();
        uint256 amount = 1e6;
        deal(lp, attacker, amount);
        vm.startPrank(attacker);
        (bool okApprove,) = lp.call(abi.encodeWithSelector(IERC20.approve.selector, address(dustVault), amount));
        assertTrue(okApprove, "approve must succeed");
        dustVault.deposit(amount);
        uint256 shares = dustVault.balanceOf(attacker);
        dustVault.withdraw(shares);
        uint256 out = IERC20(lp).balanceOf(attacker);
        vm.stopPrank();
        console2.log("dust vault: dust", dust);
        console2.log("deposit", amount);
        console2.log("shares", shares);
        console2.log("out", out);
        assertEq(shares, amount, "zero-supply vault mints 1:1");
        assertEq(out, amount + dust, "first depositor captures the dust");
    }

    // Same zero-supply capture on the second dust vault (yvpBTC/sbtcCRV, newer yVault variant).
    function test_dust_vault_vpBTC_first_depositor_captures_dust() public {
        address v = 0x123964EbE096A920dae00Fb795FFBfA0c9Ff4675;
        uint256 dust = IVaultV1(v).balance();
        assertGt(dust, 0, "dust vault must hold dust");
        assertEq(IVaultV1(v).totalSupply(), 0);
        address lp = IVaultV1(v).token();
        uint256 amount = 1e6;
        deal(lp, attacker, amount);
        vm.startPrank(attacker);
        (bool okApprove,) = lp.call(abi.encodeWithSelector(IERC20.approve.selector, v, amount));
        assertTrue(okApprove, "approve must succeed");
        IVaultV1(v).deposit(amount);
        uint256 shares = IVaultV1(v).balanceOf(attacker);
        IVaultV1(v).withdraw(shares);
        uint256 out = IERC20(lp).balanceOf(attacker);
        vm.stopPrank();
        console2.log("yvpBTC dust", dust);
        console2.log("deposit", amount);
        console2.log("shares", shares);
        console2.log("out", out);
        assertEq(shares, amount, "zero-supply vault mints 1:1");
        assertEq(out, amount + dust, "first depositor captures the dust");
    }

    // Probe the venue withdrawal path of every Aave v1 / Compound v1 backed vault.
    // Success with a positive payout = holders can exit (H-O); revert = venue liquidity missing (S).
    function test_venue_backed_vaults_exit_status() public {
        _probeExit(0x36324b8168f960A12a8fD01406C9C78143d41380, 10e18, "ySUSD_v1(aSUSD)", true);
        _probeExit(0xF61718057901F84C4eEC4339EF8f0D86D2B45600, 10e18, "ySUSD_v2(aSUSD)", false);
        _probeExit(0x9D25057e62939D3408406975aD75Ffe834DA4cDd, 10e18, "yDAI_v1(aDAI)", true);
        _probeExit(0xC2cB1040220768554cf699b0d863A3cd4324ce32, 7_855e18, "yDAI_v3(aDAI)", false);
        _probeExit(0x26EA744E5B887E5205727f55dFBE8685e3b21951, 8_500e6, "yUSDC_v1(aUSDC)", false);
        _probeExit(0xa2609B2b43AC0F5EbE27deB944d2a399C201E3dA, 2_000_000, "yUSDC_v3(aUSDC)", true);
        _probeExit(0xa1787206d5b1bE0f432C4c4f96Dc4D1257A1Dd14, 500_000, "yUSDT_v3(aUSDT)", true);
        _probeExit(0x04bC0Ab673d88aE9dbC9DA2380cB6B79C4BCa9aE, 9_800e18, "yBUSD(aBUSD)", false);
        _probeExit(0x04EF8121aD039ff41d10029c91EA1694432514e9, 10_000, "yBTC_v1(cWBTC)", true);
        _probeExit(0x04Aa51bbcB46541455cCF1B8bef2ebc5d3787EC9, 10_000_000, "yBTC_v2(cWBTC)", false);
    }

    function _probeExit(address vault, uint256 shares, string memory label, bool useRedeem) internal {
        deal(vault, attacker, shares);
        address tok = IVaultV1(vault).token();
        uint256 before = IERC20(tok).balanceOf(attacker);
        vm.prank(attacker);
        (bool ok, bytes memory ret) = vault.call(
            abi.encodeWithSignature(useRedeem ? "redeem(uint256)" : "withdraw(uint256)", shares)
        );
        uint256 paid = IERC20(tok).balanceOf(attacker) - before;
        console2.log(label, ok);
        console2.log("  paid", paid);
        if (!ok) {
            console2.log("  revert data len", ret.length);
        }
    }

    /* --------------------------------- yPool ---------------------------------- */

    function test_yPool_balances_and_pps() public view {
        assertEq(yPool.balances(0), 149_062_397_271_676_480_613);
        assertEq(yPool.balances(1), 107_784_528);
        assertEq(yPool.balances(2), 18_373_141_217_551_505_729);
        assertEq(yPool.balances(3), 45_840_035_635_735_039_481_745_846_009_829_159);
        assertApproxEqRel(IIEarnVault(address(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01)).getPricePerFullShare(), 1_143_253_938_259_335_448, 1e15);
        assertApproxEqRel(IIEarnVault(address(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e)).getPricePerFullShare(), 1_288_146_192_887_802_370, 1e15);
        assertEq(IIEarnVault(address(0x83f798e925BcD4017Eb265844FDDAbb448f1707D)).getPricePerFullShare(), 7_983_181);
        assertEq(IIEarnVault(address(0x73a052500105205d34Daf004eAb301916DA8190f)).getPricePerFullShare(), 8546);
    }

    // yUSDT is deeply devalued (PPS 7.98e6 wei). If the Curve pool overvalues it,
    // swapping yUSDT -> yDAI extracts real yDAI. Compare values via PPS.
    function test_yPool_yUSDT_in_no_value_extraction() public {
        uint256 dx = 1e18; // 1e18 yUSDT wei = 1e12 yUSDT tokens (6-dec)
        address yUSDT = 0x83f798e925BcD4017Eb265844FDDAbb448f1707D;
        address yDAIt = 0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01;
        deal(yUSDT, attacker, dx);
        uint256 ppsUSDT = IIEarnVault(yUSDT).getPricePerFullShare();
        uint256 ppsDAI = IIEarnVault(yDAIt).getPricePerFullShare();
        uint256 valueIn = (dx * ppsUSDT / 1e18) * 1e12; // normalise USDT 6-dec to 18-dec
        vm.startPrank(attacker);
        IERC20(yUSDT).approve(address(yPool), dx);
        uint256 before = IERC20(yDAIt).balanceOf(attacker);
        (bool ok,) = address(yPool).call(
            abi.encodeWithSelector(ICurveYPool.exchange.selector, int128(2), int128(0), dx, uint256(0))
        );
        uint256 out = IERC20(yDAIt).balanceOf(attacker) - before;
        vm.stopPrank();
        uint256 valueOut = out * ppsDAI / 1e18;
        console2.log("yPool yUSDT->yDAI: ok", ok);
        console2.log("dx", dx);
        console2.log("out yDAI", out);
        console2.log("valueIn (18dec)", valueIn);
        console2.log("valueOut (18dec)", valueOut);
        assertLe(valueOut, valueIn, "yUSDT swap must not extract value from yPool");
    }

    function test_yPool_yTUSD_in_no_value_extraction() public {
        uint256 dx = 1e30; // 1e12 yTUSD tokens
        address yTUSDt = 0x73a052500105205d34Daf004eAb301916DA8190f;
        address yDAIt = 0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01;
        deal(yTUSDt, attacker, dx);
        uint256 ppsTUSD = IIEarnVault(yTUSDt).getPricePerFullShare();
        uint256 ppsDAI = IIEarnVault(yDAIt).getPricePerFullShare();
        uint256 valueIn = dx * ppsTUSD / 1e18;
        vm.startPrank(attacker);
        IERC20(yTUSDt).approve(address(yPool), dx);
        uint256 before = IERC20(yDAIt).balanceOf(attacker);
        (bool ok,) = address(yPool).call(
            abi.encodeWithSelector(ICurveYPool.exchange.selector, int128(3), int128(0), dx, uint256(0))
        );
        uint256 out = IERC20(yDAIt).balanceOf(attacker) - before;
        vm.stopPrank();
        uint256 valueOut = out * ppsDAI / 1e18;
        console2.log("yPool yTUSD->yDAI: ok", ok);
        console2.log("dx", dx);
        console2.log("out yDAI", out);
        console2.log("valueIn", valueIn);
        console2.log("valueOut", valueOut);
        assertLe(valueOut, valueIn, "yTUSD swap must not extract value from yPool");
    }

    function test_yPool_yDAI_yUSDC_roundtrip() public {
        uint256 dx = 10e18;
        address yDAIt = 0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01;
        address yUSDCt = 0xd6aD7a6750A7593E092a9B218d66C0A814a3436e;
        deal(yDAIt, attacker, dx);
        vm.startPrank(attacker);
        IERC20(yDAIt).approve(address(yPool), dx);
        uint256 beforeUSDC = IERC20(yUSDCt).balanceOf(attacker);
        (bool ok1,) = address(yPool).call(
            abi.encodeWithSelector(ICurveYPool.exchange.selector, int128(0), int128(1), dx, uint256(0))
        );
        uint256 out = IERC20(yUSDCt).balanceOf(attacker) - beforeUSDC;
        IERC20(yUSDCt).approve(address(yPool), out);
        (bool ok2,) = address(yPool).call(
            abi.encodeWithSelector(ICurveYPool.exchange.selector, int128(1), int128(0), out, uint256(0))
        );
        uint256 back = IERC20(yDAIt).balanceOf(attacker);
        vm.stopPrank();
        console2.log("yPool yDAI->yUSDC->yDAI: ok1", ok1);
        console2.log("ok2", ok2);
        console2.log("in", dx);
        console2.log("back", back);
        assertLe(back, dx, "round trip must not profit");
    }

    /* --------------------------------- yETH ----------------------------------- */

    function test_yETH_main_pool_paused_and_dust() public {
        assertTrue(yethMainPool.paused(), "main yETH pool must be paused");
        uint256[] memory amounts = new uint256[](8);
        amounts[0] = 1e18;
        vm.prank(attacker);
        (bool ok,) = address(yethMainPool).call(
            abi.encodeWithSelector(IYEthPool.remove_liquidity.selector, 1e18, amounts)
        );
        assertFalse(ok, "remove_liquidity must revert on paused pool");
    }

    function test_curve_yeth_weth_pool_dust_roundtrip() public {
        uint256 wethBal = WETH.balanceOf(address(yethWethPool));
        uint256 yethBal = YETH.balanceOf(address(yethWethPool));
        console2.log("yETH/WETH pool WETH", wethBal);
        console2.log("yETH", yethBal);
        assertLt(wethBal, 1e15, "pool WETH residual is dust");

        uint256 dx = 0.001 ether;
        vm.deal(attacker, dx);
        vm.startPrank(attacker);
        IWETH(address(WETH)).deposit{value: dx}();
        WETH.approve(address(yethWethPool), dx);
        uint256 beforeYeth = YETH.balanceOf(attacker);
        (bool ok1,) = address(yethWethPool).call(
            abi.encodeWithSelector(ICurveStableNG.exchange.selector, int128(0), int128(1), dx, uint256(0))
        );
        uint256 yethOut = YETH.balanceOf(attacker) - beforeYeth;
        YETH.approve(address(yethWethPool), yethOut);
        (bool ok2,) = address(yethWethPool).call(
            abi.encodeWithSelector(ICurveStableNG.exchange.selector, int128(1), int128(0), yethOut, uint256(0))
        );
        uint256 wethBack = WETH.balanceOf(attacker);
        vm.stopPrank();
        console2.log("yETH/WETH roundtrip: in", dx);
        console2.log("yETH out", yethOut);
        console2.log("weth back", wethBack);
        console2.log("ok1", ok1);
        console2.log("ok2", ok2);
        assertLe(wethBack, dx, "no profit round-tripping the dust pool");
    }

    function test_styETH_holds_only_yETH() public view {
        assertApproxEqRel(YETH.balanceOf(address(stYETH)), 1_456_171_816_984_728_078_668_327_600_823_063, 1e15);
        // no LST backing
        assertEq(IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0).balanceOf(address(stYETH)), 0);
        assertEq(IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393).balanceOf(address(stYETH)), 0);
        assertEq(IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704).balanceOf(address(stYETH)), 0);
    }

    function test_v4_yeth_usdc_pool_state() public view {
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = stateView.getSlot0(V4_YETH_USDC);
        uint128 liq = stateView.getLiquidity(V4_YETH_USDC);
        console2.log("v4 yETH/USDC pool sqrtPriceX96", uint256(sqrtPriceX96));
        console2.log("tick", tick);
        console2.log("lpFee", uint256(lpFee));
        console2.log("protocolFee", uint256(protocolFee));
        console2.log("liquidity", uint256(liq));
        assertEq(uint256(lpFee), 870000, "pool fee is 87%");
    }
}
