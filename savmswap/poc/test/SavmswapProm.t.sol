// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IUniV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function skim(address) external;
    function swap(uint256, uint256, address, bytes calldata) external;
    function sync() external;
    function kLast() external view returns (uint256);
    function factory() external view returns (address);
}

interface IUniV2Factory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IVault {
    function retrieve(uint256 amount, address token) external;
}

/// @title savmSwap on Prom - unprivileged-attacker PoC (read-only fork; no mainnet txs)
/// @notice Fork of Prom mainnet. The test contract plays an external, unprivileged
///         attacker (no roles, no insider token positions, own capital only).
contract SavmswapPromPoCTest is Test {
    // ---- live addresses (verified on-chain read-only, source-verified on promscan.io) ----
    address constant FACTORY = 0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9;
    address constant MAIN = 0x1DdBf7113E3711ae9918f2dC14eFB6B302B1E0D2; // WPROM/USDT
    address constant WPROM = 0x04A21a38D5E275d6023B27504beB3095dC43B0C0;
    address constant USDT = 0x7e942605B5028E3B751dBB5Ef8afC5CF85a5A7eD;
    address constant USDC = 0xd9c95e2ad330E11D7Dfa58f18504049f625E955e;
    address constant FEETO = 0x55594E57F80b2deCd63608A4F2802F8003633aD2;
    address constant USER_LP = 0x2bA8968C1AE5984f049F28085f50D7Df4aD1a01e; // 99.85% main LP

    address constant GYRO = 0x05b86B7908E29bab68795fa9Fdf52A78f3962D58;
    address constant GYRO_POOL = 0x679e6f7240A807327d63c12E7214833be5555C9c;
    address constant GYRO_OWNER = 0x036A2e8815E62F59F89958cC387B95E548578c02;
    address constant FKS = 0x0CC7E61842D09e8e7a0B1B177FE05c64d24D3D79;
    address constant BOB = 0xC7A17a1037DE590EA1570c112eC42E85157D6C36;
    address constant FKS_POOL = 0x59f90Cb51493D04f96FE5Ae22833CbDC7f676D77;
    address constant RKT_POOL = 0x6A2a261829a98eDc6da8621b2b01CECE6C821608;
    address constant BRUV_POOL = 0x91751D831F201eE8f982cD0fB2925b8244Cb77cF;
    address constant USTC_POOL = 0x5a47A049ae3A223420953DFFa6064c53BC59C7DA;
    address constant BEEBEE_POOL = 0xe89C03037DB0748324c3937aa5275de71c3d6f6C;
    address constant BAAI_POOL = 0x68D1424c4dFaCA05f4712132Fe587E4FA9Ee8A31;
    address constant USDC_POOL = 0xBcdbF1A7CC1eee60929707347F0a8eCE68f82D5D;
    address constant VAULT = 0x6Eda4EB3D0D79AA581e7Bb4bFb4E993489e7212C;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 constant PROM_USD = 5.254945355604462e18; // DefiLlama/CoinGecko PROM price at screen time

    uint256 forkBlock;

    function setUp() public {
        forkBlock = vm.createSelectFork(vm.envOr("PROM_RPC_URL", string("https://rpc.prom.io")));
        emit log_named_uint("prom fork block", forkBlock);
        emit log_named_uint("prom chainid", block.chainid);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal pure returns (uint256)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "reserves");
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function sel(string memory sig) internal pure returns (bytes4 s) {
        // minimal: only the two selectors used below
        if (keccak256(bytes(sig)) == keccak256(bytes("transferFrom(address,address,uint256)"))) return 0x23b872dd;
        if (keccak256(bytes(sig)) == keccak256(bytes("mint(address,uint256)"))) return 0x40c10f19;
        revert("sel");
    }

    // ------------------------------------------------------------------
    // T1: live state / custody snapshot
    // ------------------------------------------------------------------
    function test_T1_live_state() public {
        uint256 n = IUniV2Factory(FACTORY).allPairsLength();
        emit log_named_uint("factory pairs", n);
        assertGe(n, 90);
        assertEq(IUniV2Factory(FACTORY).feeTo(), FEETO);
        assertEq(IUniV2Factory(FACTORY).feeToSetter(), FEETO);
        assertEq(IUniV2Pair(MAIN).factory(), FACTORY);

        (uint112 r0, uint112 r1,) = IUniV2Pair(MAIN).getReserves();
        emit log_named_uint("main WPROM reserve", r0);
        emit log_named_uint("main USDT reserve", r1);
        emit log_named_uint("main pool price, USDT per WPROM x1e6", (uint256(r1) * 1e18) / r0);
        emit log_named_uint("market PROM price x1e6", PROM_USD / 1e12);

        uint256 ts = IUniV2Pair(MAIN).totalSupply();
        uint256 userLP = IUniV2Pair(MAIN).balanceOf(USER_LP);
        emit log_named_uint("main LP totalSupply", ts);
        emit log_named_uint("main LP held by single EOA 0x2bA8..", userLP);
        emit log_named_uint("main LP ratio, userLP x1e6 / ts", (userLP * 1e6) / ts);
        emit log_named_uint("main feeTo minted LP", IUniV2Pair(MAIN).balanceOf(FEETO));
        emit log_named_uint("main kLast", IUniV2Pair(MAIN).kLast());
        emit log_named_uint("main k", uint256(r0) * uint256(r1));
    }

    // ------------------------------------------------------------------
    // T2: skim() yields zero on every pool holding material value
    // ------------------------------------------------------------------
    function test_T2_skim_no_excess() public {
        address[9] memory pools =
            [MAIN, GYRO_POOL, FKS_POOL, RKT_POOL, BRUV_POOL, USTC_POOL, BEEBEE_POOL, BAAI_POOL, USDC_POOL];
        for (uint256 i = 0; i < pools.length; i++) {
            address p = pools[i];
            address t0 = IUniV2Pair(p).token0();
            address t1 = IUniV2Pair(p).token1();
            (uint112 r0, uint112 r1,) = IUniV2Pair(p).getReserves();
            assertEq(IERC20(t0).balanceOf(p), r0, "excess t0 present");
            assertEq(IERC20(t1).balanceOf(p), r1, "excess t1 present");
            uint256 a0 = IERC20(t0).balanceOf(address(this));
            uint256 a1 = IERC20(t1).balanceOf(address(this));
            IUniV2Pair(p).skim(address(this)); // no-op at zero excess
            assertEq(IERC20(t0).balanceOf(address(this)), a0, "skim t0 leaked");
            assertEq(IERC20(t1).balanceOf(address(this)), a1, "skim t1 leaked");
            emit log_named_address("skim-zero verified for pool", p);
        }
    }

    // ------------------------------------------------------------------
    // T3: factory admin functions are gated
    // ------------------------------------------------------------------
    function test_T3_factory_admin_gated() public {
        vm.expectRevert();
        IUniV2Factory(FACTORY).setFeeTo(address(this));
        vm.expectRevert();
        IUniV2Factory(FACTORY).setFeeToSetter(address(this));
    }

    // ------------------------------------------------------------------
    // T4: no public mint on real-value or top meme tokens
    // ------------------------------------------------------------------
    function test_T4_no_public_mint() public {
        (bool ok,) = FKS.call(abi.encodeWithSelector(sel("mint(address,uint256)"), address(this), uint256(1e24)));
        assertFalse(ok, "FKS mint succeeded for outsider");
        (ok,) = BOB.call(abi.encodeWithSelector(sel("mint(address,uint256)"), address(this), uint256(1e24)));
        assertFalse(ok, "BOB mint succeeded for outsider");
        (ok,) = USDT.call(abi.encodeWithSelector(sel("mint(address,uint256)"), address(this), uint256(1e18)));
        assertFalse(ok, "USDT mint succeeded for outsider");
        // WPROM is a WETH9-style wrapper: unknown selector hits payable fallback (deposit(0)), mints nothing
        uint256 before_ = IERC20(WPROM).balanceOf(address(this));
        WPROM.call(abi.encodeWithSelector(sel("mint(address,uint256)"), address(this), uint256(1e18)));
        assertEq(IERC20(WPROM).balanceOf(address(this)), before_, "WPROM minted");
    }

    // ------------------------------------------------------------------
    // T5: launchpad vault retrieve() is owner-gated (not public)
    // ------------------------------------------------------------------
    function test_T5_vault_retrieve_owner_gated() public {
        uint256 bal = IERC20(GYRO).balanceOf(VAULT);
        emit log_named_uint("vault gyro balance", bal);
        assertGt(bal, 0);
        vm.expectRevert();
        IVault(VAULT).retrieve(bal, GYRO); // outsider: token.owner() != msg.sender
        // gate key: caller must equal the token's owner()
        assertEq(GYRO_OWNER, 0x036A2e8815E62F59F89958cC387B95E548578c02);
        uint256 ownerBefore = IERC20(GYRO).balanceOf(GYRO_OWNER);
        vm.prank(GYRO_OWNER);
        IVault(VAULT).retrieve(bal, GYRO);
        emit log_named_uint("gyro owner gained (wei)", IERC20(GYRO).balanceOf(GYRO_OWNER) - ownerBefore);
    }

    // ------------------------------------------------------------------
    // T6: main-pool arb vs market is inside fee/cost bounds; the same-pool
    //     round-trip is always a loss (~0.6% of notional)
    // ------------------------------------------------------------------
    function test_T6_main_pool_arb_not_extractable() public {
        (uint112 rw, uint112 ru,) = IUniV2Pair(MAIN).getReserves();
        uint256 usdtIn = 10_000e6;
        uint256 wOut = getAmountOut(usdtIn, ru, rw);
        uint256 marketUsd = (wOut * PROM_USD) / 1e36; // whole USD
        int256 edgeUsd = int256(marketUsd) - int256(usdtIn / 1e6);
        emit log_named_int("gross edge USD on 10k USDT buy (before exit costs)", edgeUsd);
        assertTrue(edgeUsd < 400, "unexpectedly large edge");
        uint256 usdtBack = getAmountOut(wOut, rw - wOut, ru + usdtIn);
        emit log_named_uint("USDT back after same-pool round trip", usdtBack);
        assertLt(usdtBack, usdtIn - (usdtIn * 5) / 1000);
    }

    // ------------------------------------------------------------------
    // T7: stale micro-pool quote - optimum extraction is dust (<$5)
    // ------------------------------------------------------------------
    function test_T7_stale_usdc_pool_dust() public {
        (uint112 r0, uint112 r1,) = IUniV2Pair(USDC_POOL).getReserves(); // WPROM / USDC
        emit log_named_uint("usdc-pool WPROM reserve", r0);
        emit log_named_uint("usdc-pool USDC reserve", r1);
        emit log_named_uint("implied USDC per WPROM x1e6", (uint256(r1) * 1e18) / r0);
        (uint112 rw, uint112 ru,) = IUniV2Pair(MAIN).getReserves();
        uint256 best = 0;
        uint256 bestX = 0;
        // attacker buys x WPROM on the main pool, dumps into the stale USDC pool
        for (uint256 x = 1e16; x <= uint256(r0); x += 1e16) {
            uint256 usdtCost = (x * 1000 * ru) / ((rw - x) * 997) + 1; // buy x on main pool
            uint256 outUsdc = getAmountOut(x, r0, r1); // dump x into stale USDC pool
            if (outUsdc > usdtCost) {
                uint256 profit = outUsdc - usdtCost;
                if (profit > best) {
                    best = profit;
                    bestX = x;
                }
            }
        }
        emit log_named_uint("max dust profit (USDC units)", best);
        emit log_named_uint("optimal dump size (WPROM wei)", bestX);
        assertLt(best, 5e6, "dust edge larger than expected");
    }

    // ------------------------------------------------------------------
    // T8: burned-LP pool = LP locked; payload reachable only by holders of
    //     the paired memecoin (conditional insider position, not E-U)
    // ------------------------------------------------------------------
    function test_T8_burned_lp_locked_and_conditional_dump() public {
        uint256 ts = IUniV2Pair(GYRO_POOL).totalSupply();
        uint256 deadLP = IUniV2Pair(GYRO_POOL).balanceOf(DEAD);
        emit log_named_uint("gyro pool LP totalSupply", ts);
        emit log_named_uint("gyro pool LP at 0xdEaD", deadLP);
        assertGt(deadLP * 1000, ts * 999); // >= 99.9% burned

        // attacker holds no LP: cannot burn/withdraw the position
        (bool ok,) = GYRO_POOL.call(abi.encodeWithSelector(sel("transferFrom(address,address,uint256)"), address(this), address(this), uint256(1)));
        assertFalse(ok, "attacker moved LP");

        (uint112 rw, uint112 rg,) = IUniV2Pair(GYRO_POOL).getReserves(); // token0=WPROM, token1=gyro
        emit log_named_uint("gyro pool WPROM reserve", rw);
        emit log_named_uint("gyro pool gyro reserve", rg);

        // conditional path: the memecoin owner dumps their entire stack
        uint256 dump = 540_300_000e18;
        deal(GYRO, GYRO_OWNER, dump);
        uint256 wBefore = IERC20(WPROM).balanceOf(GYRO_OWNER);
        // output computed from PRE-transfer reserves
        uint256 outW = getAmountOut(dump, rg, rw);
        vm.startPrank(GYRO_OWNER);
        IERC20(GYRO).transfer(GYRO_POOL, dump);
        IUniV2Pair(GYRO_POOL).swap(outW, 0, GYRO_OWNER, "");
        vm.stopPrank();
        uint256 gained = IERC20(WPROM).balanceOf(GYRO_OWNER) - wBefore;
        emit log_named_uint("WPROM extracted by full memecoin-supply holder", gained);
        emit log_named_uint("USD value of that extraction", (gained * PROM_USD) / 1e36);
        assertGt(gained, 0);
        assertLt(gained, rw); // CPMM depth: cannot take the whole pool
    }
}
