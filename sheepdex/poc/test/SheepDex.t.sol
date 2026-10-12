// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ArbBot, IERC20, ISpePool, IPancakeRouter02} from "../src/ArbBot.sol";

/// @title SheepDex (BSC) live-extraction PoC — fork tests
/// @notice Read-only research: these tests run on a local fork only. No mainnet transactions.
contract SheepDexArbTest is Test {
    // tokens
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address constant ALPACA = 0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;
    address constant ETERNAL = 0xD44FD09d74cd13838F137B590497595d6b3FEeA4;
    address constant SPC = 0xc67a54D5E08e59FB70DD29D81350C6Ff4562D544;
    address constant WOO = 0x4691937a7508860F876c9c0a2a617E7d9E945D4B;

    // SheepDex pools (t0, t1 as on-chain)
    address constant P_ETH_BUSD = 0x5DE4c0980BcF4f78b3912eB9Ef2e3bE6c61fB7E5;   // ETH/BUSD
    address constant P_ETH_WBNB = 0xdF09748cD0248E2Db3F206E15044539058614393;   // ETH/WBNB
    address constant P_WBNB_BUSD = 0x8C583754cE22ab3e7647122C01cDb854C861def9;  // WBNB/BUSD
    address constant P_BTCB_BUSD = 0x197880438436C426392570cb4782432EC9135f62;  // BTCB/BUSD
    address constant P_BTCB_WBNB = 0x2f649c45C62CC7fb76D4D5b8CD20A8cCAC95235E;  // BTCB/WBNB
    address constant P_ETH_BTCB = 0xfF7B81Fe69b9b280b30C91fb1a9e9a6dE85761E5;   // ETH/BTCB
    address constant P_CAKE_WBNB = 0xbBd4871C23EB06F0113B397c5E54d1B755903B87;  // CAKE/WBNB
    address constant P_XVS_WBNB = 0x5f7213E3E96C6d0d413211B318Af4181a6D7C8c7;   // WBNB/XVS
    address constant P_ETERNAL_WBNB = 0x73A7e63521FcFd924B19C88A1558c34eBFc8E3b8; // WBNB/ETERNAL
    address constant P_ALPACA_HI = 0xB4AC4757ac74B8Ad1d836E978c42c1e008FEb8ee;  // ALPACA/WBNB (hi)
    address constant P_ALPACA_LO = 0xD51924D192315429A124a6680515cf23d39a754d;  // ALPACA/WBNB (lo)
    address constant P_SPC_HI = 0x8Ca725904B1214CCE4B6A7Fa077EA4a3c7687eb8;     // SPC/BUSD (hi)
    address constant P_SPC_LO = 0xADef64E2B8AbF5De69F6634A588DAF150C6ee5c5;     // SPC/BUSD (lo)
    address constant P_WBNB_SPC = 0xB140C180f40Ddb3401f66BBD3788246Ce8B800eA;   // WBNB/SPC
    address constant P_WOO_WBNB = 0x1D007FD035af27D96D75B0AFDd7b954A8CE6c436;   // WOO/WBNB

    IPancakeRouter02 constant ROUTER = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    ArbBot bot;
    uint256 forkBlock;

    function setUp() public {
        string memory local = vm.envOr("LOCAL_FORK_URL", string(""));
        if (bytes(local).length > 0) {
            // stable local anvil snapshot
            vm.createSelectFork(local);
        } else {
            // fallback: use the CI RPC, pinned ~100 blocks back to dodge lagging replicas
            string memory url = vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com"));
            vm.createSelectFork(url);
            uint256 b = block.number;
            if (b > 200) vm.createSelectFork(url, b - 100);
        }
        forkBlock = block.number;
        bot = new ArbBot();
        console.log("fork block", forkBlock);
    }

    // ---------------------------------------------------------------- helpers

    function _route(address p1, bool z1, address p2, bool z2) internal pure returns (address[] memory pools, bool[] memory zs) {
        pools = new address[](2);
        zs = new bool[](2);
        pools[0] = p1; zs[0] = z1;
        pools[1] = p2; zs[1] = z2;
    }

    function _route3(address p1, bool z1, address p2, bool z2, address p3, bool z3)
        internal pure returns (address[] memory pools, bool[] memory zs)
    {
        pools = new address[](3);
        zs = new bool[](3);
        pools[0] = p1; zs[0] = z1;
        pools[1] = p2; zs[1] = z2;
        pools[2] = p3; zs[2] = z3;
    }

    function _bal(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(bot));
    }

    function _logProfit(string memory label, uint256 inAmt, int256 profit) internal pure {
        console.log(label, inAmt);
        console.logInt(profit);
    }

    // ---------------------------------------------------------------- internal routes

    /// BUSD -> ETH (ETH/BUSD) -> WBNB (ETH/WBNB) -> BUSD (WBNB/BUSD)
    function test_internal_eth_triangle() public {
        uint256[9] memory sizes =
            [uint256(1e18), 5e18, 20e18, 50e18, 100e18, 300e18, 1000e18, 3000e18, 10000e18];
        int256 best = 0;
        uint256 bestIn = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(BUSD, address(bot), inAmt);
            (address[] memory pools, bool[] memory zs) =
                _route3(P_ETH_BUSD, false, P_ETH_WBNB, true, P_WBNB_BUSD, true);
            bot.runRoute(pools, zs);
            int256 profit = int256(_bal(BUSD)) - int256(inAmt);
            _logProfit("ETH triangle in(BUSD wei):", inAmt, profit);
            if (profit > best) { best = profit; bestIn = inAmt; }
        }
        console.log("BEST ETH triangle in(BUSD wei):", bestIn);
        console.logInt(best);
    }

    /// WBNB -> ALPACA (cheap pool) -> WBNB (expensive pool)
    function test_internal_alpaca() public {
        uint256[7] memory sizes =
            [uint256(1e12), 1e13, 1e14, 1e15, 5e15, 1e16, 5e16];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(WBNB, address(bot), inAmt);
            (address[] memory pools, bool[] memory zs) = _route(P_ALPACA_LO, false, P_ALPACA_HI, true);
            bot.runRoute(pools, zs);
            int256 profit = int256(_bal(WBNB)) - int256(inAmt);
            _logProfit("ALPACA in(WBNB wei):", inAmt, profit);
            if (profit > best) best = profit;
        }
        console.logInt(best);
    }

    /// BUSD -> SPC (cheap pool) -> BUSD (expensive pool)
    function test_internal_spc() public {
        uint256[5] memory sizes = [uint256(1e12), 1e14, 1e16, 0.1e18, 1e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(BUSD, address(bot), inAmt);
            (address[] memory pools, bool[] memory zs) = _route(P_SPC_LO, false, P_SPC_HI, true);
            bot.runRoute(pools, zs);
            int256 profit = int256(_bal(BUSD)) - int256(inAmt);
            _logProfit("SPC in(BUSD wei):", inAmt, profit);
            if (profit > best) best = profit;
        }
        console.logInt(best);
    }

    // ---------------------------------------------------------------- external routes

    function _routerSwap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 out) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        out = bot.routerSwap(address(ROUTER), path, amountIn);
    }

    function _routerSwap3(address t0, address t1, address t2, uint256 amountIn) internal returns (uint256 out) {
        address[] memory path = new address[](3);
        path[0] = t0;
        path[1] = t1;
        path[2] = t2;
        out = bot.routerSwap(address(ROUTER), path, amountIn);
    }

    /// Buy ETERNAL on PancakeSwap, sell into SheepDex WBNB/ETERNAL pool (micro -> normal sizes)
    function test_external_eternal() public {
        uint256[6] memory sizes = [uint256(1e6), 1e8, 1e10, 1e12, 5e14, 0.001e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(WBNB, address(bot), inAmt);
            _routerSwap(WBNB, ETERNAL, inAmt);
            address[] memory pools = new address[](1);
            bool[] memory zs = new bool[](1);
            pools[0] = P_ETERNAL_WBNB; zs[0] = false; // sell ETERNAL (token1)
            try bot.runRoute(pools, zs) {
                int256 profit = int256(_bal(WBNB)) - int256(inAmt);
                _logProfit("ETERNAL in(WBNB wei):", inAmt, profit);
                if (profit > best) best = profit;
            } catch {
                console.log("ETERNAL pool swap reverted (price limit) at in:", inAmt);
            }
        }
        console.logInt(best);
    }

    /// Buy CAKE on PancakeSwap, sell into SheepDex CAKE/WBNB pool (micro -> normal sizes)
    function test_external_cake() public {
        uint256[6] memory sizes = [uint256(1e6), 1e8, 1e10, 1e12, 1e15, 0.001e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(WBNB, address(bot), inAmt);
            _routerSwap(WBNB, CAKE, inAmt);
            address[] memory pools = new address[](1);
            bool[] memory zs = new bool[](1);
            pools[0] = P_CAKE_WBNB; zs[0] = true; // sell CAKE (token0)
            try bot.runRoute(pools, zs) {
                int256 profit = int256(_bal(WBNB)) - int256(inAmt);
                _logProfit("CAKE in(WBNB wei):", inAmt, profit);
                if (profit > best) best = profit;
            } catch {
                console.log("CAKE pool swap reverted (price limit) at in:", inAmt);
            }
        }
        console.logInt(best);
    }

    /// Buy XVS on PancakeSwap, sell into SheepDex WBNB/XVS pool
    function test_external_xvs() public {
        uint256[5] memory sizes = [uint256(0.001e18), 0.005e18, 0.02e18, 0.05e18, 0.1e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(WBNB, address(bot), inAmt);
            _routerSwap(WBNB, XVS, inAmt);
            address[] memory pools = new address[](1);
            bool[] memory zs = new bool[](1);
            pools[0] = P_XVS_WBNB; zs[0] = false; // sell XVS (token1)
            bot.runRoute(pools, zs);
            int256 profit = int256(_bal(WBNB)) - int256(inAmt);
            _logProfit("XVS in(WBNB wei):", inAmt, profit);
            if (profit > best) best = profit;
        }
        console.logInt(best);
    }

    /// BUSD -> ETH on SheepDex, ETH -> BUSD on PancakeSwap (router path ETH->WBNB->BUSD)
    function test_external_eth_vs_pancake() public {
        uint256[6] memory sizes = [uint256(100e18), 500e18, 1000e18, 3000e18, 8000e18, 16000e18];
        int256 best = 0;
        uint256 bestIn = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(BUSD, address(bot), inAmt);
            bot.swapIn(P_ETH_BUSD, false, inAmt); // buy ETH on SheepDex
            uint256 ethBal = _bal(ETH);
            _routerSwap3(ETH, WBNB, BUSD, ethBal);
            int256 profit = int256(_bal(BUSD)) - int256(inAmt);
            _logProfit("ETH-vs-PCS in(BUSD wei):", inAmt, profit);
            if (profit > best) { best = profit; bestIn = inAmt; }
        }
        console.log("BEST ETH-vs-PCS in(BUSD wei):", bestIn);
        console.logInt(best);
    }

    /// BTCB: sell into SheepDex BTCB/BUSD, buy back on PancakeSwap (round trip BTCB)
    function test_external_btcb() public {
        uint256[5] memory sizes = [uint256(0.001e18), 0.005e18, 0.01e18, 0.05e18, 0.1e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 inAmt = sizes[i];
            deal(BTCB, address(bot), inAmt);
            bot.swapIn(P_BTCB_BUSD, true, inAmt); // sell BTCB into SheepDex
            uint256 busdBal = _bal(BUSD);
            _routerSwap3(BUSD, WBNB, BTCB, busdBal);
            int256 profit = int256(_bal(BTCB)) - int256(inAmt);
            _logProfit("BTCB in(BTCB wei):", inAmt, profit);
            if (profit > best) best = profit;
        }
        console.logInt(best);
    }

    // ---------------------------------------------------------------- self-contained flash route

    /// Flash-borrow BUSD from the SheepDex WBNB/BUSD pool (token1) and run the ETH triangle.
    function test_flash_selfcontained() public {
        uint256[5] memory sizes = [uint256(10e18), 50e18, 100e18, 300e18, 1000e18];
        int256 best = 0;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 borrow = sizes[i];
            (address[] memory pools, bool[] memory zs) =
                _route3(P_ETH_BUSD, false, P_ETH_WBNB, true, P_WBNB_BUSD, true);
            uint256 before = _bal(BUSD);
            try bot.flashArb(P_WBNB_BUSD, 0, borrow, pools, zs) {
                int256 profit = int256(_bal(BUSD)) - int256(before);
                _logProfit("FLASH borrow(BUSD wei):", borrow, profit);
                if (profit > best) best = profit;
            } catch {
                console.log("FLASH reverted (repay not covered) for borrow:", borrow);
            }
        }
        console.logInt(best);
    }

    // ---------------------------------------------------------------- access gates (negative tests)

    /// Prove the privileged paths revert for an unprivileged attacker.
    function test_access_gates() public {
        address attacker = address(0xA11CE);
        vm.startPrank(attacker);
        // 1) pool.collectProtocol (arbitrary-token sweep) is operator-only
        (bool ok1,) = address(P_ETH_BUSD).call(abi.encodeWithSignature("collectProtocol(address)", BUSD));
        console.log("collectProtocol from attacker succeeded?", ok1);
        // 2) factory.setFee (custom fee override) is operator-only
        (bool ok2,) = address(0x571521f8c16f3c4eD5f2490f19187bA7A5A3CBDf).call(
            abi.encodeWithSignature("setFee(address,uint24)", attacker, 1)
        );
        console.log("factory.setFee from attacker succeeded?", ok2);
        // 3) SwapDirector.setOperator is owner-only
        (bool ok3,) = address(0x82c0C5c2722D511205D1A290490ebAf9940941E5).call(
            abi.encodeWithSignature("setOperator(address)", attacker)
        );
        console.log("director.setOperator from attacker succeeded?", ok3);
        // 4) pool.setFeeProtocol is operator-only
        (bool ok4,) = address(P_ETH_BUSD).call(abi.encodeWithSignature("setFeeProtocol(uint8,uint8)", 10, 10));
        console.log("pool.setFeeProtocol from attacker succeeded?", ok4);
        vm.stopPrank();
        require(!ok1 && !ok2 && !ok3 && !ok4, "an unprivileged path is open!");
    }

    /// Confirm no custom swap fees are active for sampled addresses (swapFee returns original fee).
    function test_swap_fee_default() public {
        address f = 0x571521f8c16f3c4eD5f2490f19187bA7A5A3CBDf;
        (bool ok, bytes memory ret) = f.staticcall(abi.encodeWithSignature("swapFee(address,uint24)", address(bot), uint24(2000)));
        require(ok, "swapFee call failed");
        uint24 fee = abi.decode(ret, (uint24));
        console.log("swapFee(bot, 2000) =", fee);
        require(fee == 2000, "custom fee unexpectedly set");
    }

    // ---------------------------------------------------------------- negative control

    /// WOO/WBNB vs PancakeSwap — expect no profit (prices in line)
    function test_negative_woo() public {
        uint256 inAmt = 0.01e18;
        deal(WBNB, address(bot), inAmt);
        _routerSwap(WBNB, WOO, inAmt);
        address[] memory pools = new address[](1);
        bool[] memory zs = new bool[](1);
        pools[0] = P_WOO_WBNB; zs[0] = true; // WOO/WBNB, sell WOO (token0)
        bot.runRoute(pools, zs);
        int256 profit = int256(_bal(WBNB)) - int256(inAmt);
        console.logInt(profit);
    }
}
