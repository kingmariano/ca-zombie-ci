// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function sync() external;
    function initialize(address, address) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function kLast() external view returns (uint256);
}

interface IFactory {
    function allPairsLength() external view returns (uint256);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

/// @title LFGSwap EthereumPoW (chainid 10001) — read-only fork verification
/// @notice Run on a local fork only (no mainnet transactions). Public keyless RPC default.
contract LfgEthwTest is Test {
    address constant FACTORY = 0xf66cef53c518659bFA0A9a4Aa07445AF08bf9B3a;
    address constant WETHW = 0x7Bf88d2c0e32dE92CdaF2D43CcDc23e8Edfd5990;
    address constant WETHCP = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // forked mainnet WETH, live on ETHW
    address constant PEPE = 0x5F87dE9A604a3CDa5FEfC5789944ad9527224081;
    address constant USDT = 0x2AD7868CA212135C6119FD7AD1Ce51CFc5702892;
    address constant USDC = 0x25DE68ef588cb0c2c8F3537861E828Ae699CD0DB;
    address constant LFG = 0xFd483e333cBe8fE7A418D9398d6BB81CC2B8e07B;

    address constant PAIR_PEPE_WETHW = 0x3B18525B17C9B83dc6a34bbfd60A5C680960926f;
    address constant PAIR_USDT_PEPE = 0x1098da21515468f33b43b14533203F14c0B52B5b;
    address constant PAIR_USDT_LFG = 0x75e43c101688ba4fb53E5F52876A3f3C995787f9;
    address constant PAIR_USDC_USDT = 0x03eba1aEb1b114ce767C65275f150dc23d6E84E2;
    address constant PAIR_USDC_WETHW = 0xB23396bF2191B300d1F296d1Af2DE20C10195a8a;

    address constant SAFE_SETTER = 0x67deFBFa85289E9a767D29ef9682a9B80Bd11A38; // feeToSetter (Gnosis-Safe proxy)

    function setUp() public {
        bool ok;
        // Prefer a local anvil fork (started by ci/run.sh) which retries/caches upstream RPC;
        // fall back to the public ETHW RPC when no local fork is available.
        try vm.createSelectFork("http://127.0.0.1:8545") {
            ok = true;
        } catch {
            ok = false;
        }
        if (!ok || block.chainid != 10001) {
            string memory url = vm.envOr("ETHW_RPC_URL", string("https://mainnet.ethereumpow.org"));
            vm.createSelectFork(url);
        }
        require(block.chainid == 10001, "not ETHW fork");
        console2.log("fork block", block.number);
    }

    // ------------------------------------------------ helpers
    function _getAmountOut(uint256 amountIn, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        uint256 a = amountIn * 997;
        return (a * rOut) / (rIn * 1000 + a);
    }

    function _swapExactIn(address pair, address tokenIn, uint256 amountIn, address to) internal returns (uint256 out) {
        address t0 = IPair(pair).token0();
        (uint112 r0, uint112 r1,) = IPair(pair).getReserves();
        bool in0 = (tokenIn == t0);
        uint256 rIn = in0 ? uint256(r0) : uint256(r1);
        uint256 rOut = in0 ? uint256(r1) : uint256(r0);
        uint256 balBefore = IERC20(tokenIn).balanceOf(pair);
        require(IERC20(tokenIn).transfer(pair, amountIn), "transfer in failed");
        uint256 received = IERC20(tokenIn).balanceOf(pair) - balBefore; // robust to transfer-tax tokens
        out = _getAmountOut(received, rIn, rOut);
        require(out > 0, "zero out");
        if (in0) {
            IPair(pair).swap(0, out, to, "");
        } else {
            IPair(pair).swap(out, 0, to, "");
        }
    }

    // ------------------------------------------------ 1. pair math invariants
    /// @notice Attempt a k-violating drain of the Pepe/WETHW pair: pay 0.001 WETHW, try to take 90% of the Pepe reserve.
    ///         Canonical UniV2 semantics => must revert (k check). If it executed, the whole factory would be drainable.
    function test_01_kInvariantEnforced() public {
        vm.deal(address(this), 1 ether);
        IERC20(WETHW).deposit{value: 0.001 ether}();
        (uint112 r0, uint112 r1,) = IPair(PAIR_PEPE_WETHW).getReserves();
        uint256 out90 = uint256(r0) * 9 / 10;
        require(IERC20(WETHW).transfer(PAIR_PEPE_WETHW, 0.001 ether), "in failed");
        bool reverted;
        try IPair(PAIR_PEPE_WETHW).swap(out90, 0, address(this), "") {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "K CHECK MISSING: 90% drain swap did not revert");
        (uint112 nr0, uint112 nr1,) = IPair(PAIR_PEPE_WETHW).getReserves();
        assertEq(uint256(nr0), uint256(r0), "reserve0 changed");
        assertEq(uint256(nr1), uint256(r1), "reserve1 changed");
        console2.log("k-check enforced; pepe reserve", r0, "wethw reserve", r1);
    }

    /// @notice initialize(address,address) must be closed on deployed pairs (else tokens could be re-pointed).
    function test_02_initializeClosed() public {
        bool reverted;
        try IPair(PAIR_PEPE_WETHW).initialize(address(0xdead), address(0xbeef)) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "initialize() re-callable on live pair!");
        console2.log("initialize() closed on pair", PAIR_PEPE_WETHW);
    }

    /// @notice Factory admin: feeToSetter() is a contract (Gnosis-Safe proxy); setFeeTo by an arbitrary EOA must revert.
    function test_03_feeToAdminGated() public {
        address setter = IFactory(FACTORY).feeToSetter();
        console2.log("feeToSetter", setter);
        assertEq(setter, SAFE_SETTER, "feeToSetter changed");
        assertTrue(setter.code.length > 0, "feeToSetter not a contract");
        address feeTo = IFactory(FACTORY).feeTo();
        console2.log("feeTo", feeTo);
        bool reverted;
        try IFactory(FACTORY).setFeeTo(address(this)) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "setFeeTo callable by unprivileged EOA!");
        bool reverted2;
        try IFactory(FACTORY).setFeeToSetter(address(this)) {
            reverted2 = false;
        } catch {
            reverted2 = true;
        }
        assertTrue(reverted2, "setFeeToSetter callable by unprivileged EOA!");
        console2.log("setFeeTo / setFeeToSetter correctly gated");
    }

    /// @notice No excess: for sampled live pairs, pair token balances == reserves exactly (nothing skimmable).
    function test_04_noSkimmableExcessSample() public view {
        address[5] memory ps = [PAIR_PEPE_WETHW, PAIR_USDT_PEPE, PAIR_USDT_LFG, PAIR_USDC_USDT, PAIR_USDC_WETHW];
        for (uint256 i = 0; i < ps.length; i++) {
            address p = ps[i];
            (uint112 r0, uint112 r1,) = IPair(p).getReserves();
            address t0 = IPair(p).token0();
            address t1 = IPair(p).token1();
            assertEq(IERC20(t0).balanceOf(p), uint256(r0), "excess0 != 0");
            assertEq(IERC20(t1).balanceOf(p), uint256(r1), "excess1 != 0");
        }
        console2.log("no excess on 5 sampled pairs (balances == reserves)");
    }

    // ------------------------------------------------ 2. cross-pool arbitrage execution
    /// @notice Executes the best live cross-pool path found in the scan: WETHW -> Pepe (pool A) -> USDT (pool B).
    ///         Reports realized output. (USDT is a chain-local token; see README for exit-value caveats.)
    function test_05_pepePathExecutes() public {
        vm.deal(address(this), 100 ether);
        IERC20(WETHW).deposit{value: 20 ether}();
        uint256 wIn = 20 ether;
        uint256 pepeOut = _swapExactIn(PAIR_PEPE_WETHW, WETHW, wIn, address(this));
        uint256 usdtOut = _swapExactIn(PAIR_USDT_PEPE, PEPE, pepeOut, address(this));
        console2.log("wethw_in_raw", wIn);
        console2.log("pepe_out_raw", pepeOut);
        console2.log("usdt_out_raw", usdtOut);
        console2.log("usdt_out_face_usd_x1e6", usdtOut);
        // 20 WETHW at the DefiLlama WETHW price ($0.2726) ~= $5.45 in; expect >= ~$15 USDT face (observed ~18)
        assertGt(usdtOut, 15e6, "path output below expectation");
    }

    /// @notice Negative result: closing the cycle WETHW->Pepe->USDT->USDC->WETHW today is a NET LOSS
    ///         (USDC is scarce + the USDT/USDC pool is dislocated). Proves the round trip is not extractable.
    function test_06_closedCycleIsLoss() public {
        vm.deal(address(this), 100 ether);
        IERC20(WETHW).deposit{value: 20 ether}();
        uint256 wIn = 20 ether;
        uint256 pepeOut = _swapExactIn(PAIR_PEPE_WETHW, WETHW, wIn, address(this));
        uint256 usdtOut = _swapExactIn(PAIR_USDT_PEPE, PEPE, pepeOut, address(this));
        uint256 usdcOut = _swapExactIn(PAIR_USDC_USDT, USDT, usdtOut, address(this));
        uint256 wOut = _swapExactIn(PAIR_USDC_WETHW, USDC, usdcOut, address(this));
        console2.log("wethw_in_raw", wIn);
        console2.log("pepe_out_raw", pepeOut);
        console2.log("usdt_out_raw", usdtOut);
        console2.log("usdc_out_raw", usdcOut);
        console2.log("wethw_out_raw", wOut);
        assertLt(wOut, wIn, "cycle unexpectedly profitable - re-examine");
    }

    /// @notice Context: the forked mainnet WETH at 0xc02a... is a live ETHW wrapper (deposit works),
    ///         i.e. ghost copies of mainnet contracts carry real ETHW value on this chain.
    function test_07_wethCopyIsLiveWrapper() public {
        vm.deal(address(this), 1 ether);
        uint256 before = IERC20(WETHCP).balanceOf(address(this));
        IERC20(WETHCP).deposit{value: 0.01 ether}();
        uint256 afterBal = IERC20(WETHCP).balanceOf(address(this));
        assertEq(afterBal, before + 0.01 ether, "ghost WETH deposit did not mint 1:1");
        console2.log("ghost WETH (0xc02a...) wraps ETHW 1:1; balance", afterBal);
    }

    /// @notice Largest face-value play found: WETHW ->(pool E) USDC -> (pool F) USDT.
    ///         Pool E is the only USDC venue on the chain (23.2 USDC); pool F is dislocated 15.5:1.
    ///         Executes today; USD "profit" only materialises if the chain-local USDT is redeemable
    ///         at ~par (see README caveats) - otherwise the round trip is a loss (see test_06).
    function test_08_usdcSoakPathFaceValue() public {
        vm.deal(address(this), 1000 ether);
        IERC20(WETHW).deposit{value: 250 ether}();
        uint256 wIn = 226.4 ether;
        uint256 usdcOut = _swapExactIn(PAIR_USDC_WETHW, WETHW, wIn, address(this));
        uint256 usdtOut = _swapExactIn(PAIR_USDC_USDT, USDC, usdcOut, address(this));
        console2.log("wethw_in_raw", wIn);
        console2.log("usdc_out_raw", usdcOut);
        console2.log("usdt_out_raw", usdtOut);
        // expected ~15 USDC => ~193 USDT face for ~226.4 WETHW (~$61.7 at $0.2726)
        assertGt(usdcOut, 10e6, "USDC out below expectation");
        assertGt(usdtOut, 100e6, "USDT out below expectation");
    }
}
