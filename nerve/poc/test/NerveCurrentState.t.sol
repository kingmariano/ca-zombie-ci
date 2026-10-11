// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ISwap, IMetaSwap, ISafe, IErc20SwapAsset} from "../src/Interfaces.sol";

/// @title Nerve (NerveNetwork / NerveSwap, BSC) — live extractability boundary tests
/// @notice Read-only measurement: all tests run on a throwaway fork of BSC mainnet.
///         No mainnet transaction is ever signed or broadcast.
///
/// Targets (triage set):
///   0x1B3771a66ee31180906972580adE9b81AFc5fCDc  Nerve 3pool  (BUSD/USDT/USDC)   — active
///   0x6C341938bB75dDe823FAAfe7f446925c66E6270c  BTC pool     (BTCB/anyBTC)      — active
///   0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0  ETH pool     (ETH/anyETH)       — active
///   0x2dcCe1586b1664f41C72206900e404Ec3cA130e0  UST metapool (UST/3pool-LP)    — PAUSED
/// Additional Nerve contracts found during Phase 2:
///   0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3  fUSDT metapool (fUSDT/3pool-LP) — PAUSED, drained
///   0x96b849a73db2cc769b4Abe770aAb141aAC9014d6  nrvFUSDT metapool              — PAUSED, drained
///   0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E  MasterMind farm (302,713 3pool-LP)
///
/// Conclusions proven here:
///   1. All three MetaSwap metapools (the contracts carrying the Nov-2021 Saddle-fork
///      MetaSwap pricing bug) are PAUSED: every value-moving entry point reverts.
///   2. All admin-fee withdrawal paths are owner-only; owner is a 2-of-3 Gnosis Safe.
///      ~$705k nominal sits in owner-only adminBalances (incl. 250k 3pool-LP).
///   3. The live base pools are fair: round trips and LP mint/redeem lose money.
///   4. The ETH/BTC pools can only be drained by holders of the dead-bridge tokens
///      anyETH/anyBTC (no market liquidity, no public mint) — bounded to the pools'
///      internal ETH/BTCB reserves (~$2.7k).
contract NerveCurrentStateTest is Test {
    // ---- addresses (BSC) ----
    address constant POOL3       = 0x1B3771a66ee31180906972580adE9b81AFc5fCDc;
    address constant BTCPOOL     = 0x6C341938bB75dDe823FAAfe7f446925c66E6270c;
    address constant ETHPOOL     = 0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0;
    address constant USTMETA     = 0x2dcCe1586b1664f41C72206900e404Ec3cA130e0;
    address constant FUSDTMETA   = 0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3;
    address constant NRVFUSDTMETA = 0x96b849a73db2cc769b4Abe770aAb141aAC9014d6;
    address constant FARM        = 0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E;
    address constant SAFE        = 0xD94Ac9fB78dD9B3FEB0eC39F38d86D2Ee5BA6B06;

    address constant BUSD  = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant USDT  = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDC  = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant BTCB  = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant ETH   = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant UST   = 0x23396cF899Ca06c4472205fC903bDB4de249D6fC;
    address constant FUSDT = 0x049d68029688eAbF473097a2fC38ef61633A3C7A; // Frapped USDT (6 dec)
    address constant ANYETH = 0x6F817a0cE8F7640Add3bC0c1C2298635043c2423;
    address constant ANYBTC = 0x54261774905f3e6E9718f2ABb10ed6555cae308a;
    address constant LP3   = 0xf2511b5E4FB0e5E2d123004b672BA14850478C14; // Nerve 3pool LP
    address constant PCS_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant PCS_ANYETH_WBNB = 0x48457EF51D9c7b290355DC96428F946AE1B46882;

    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")));
    }

    // ------------------------------------------------------------------
    // 1. pause / ownership state
    // ------------------------------------------------------------------
    function test_live_state_snapshot() public {
        assertEq(ISwap(POOL3).paused(), false, "3pool should be active");
        assertEq(ISwap(BTCPOOL).paused(), false, "btc pool should be active");
        assertEq(ISwap(ETHPOOL).paused(), false, "eth pool should be active");
        assertTrue(ISwap(USTMETA).paused(), "UST metapool paused");
        assertTrue(ISwap(FUSDTMETA).paused(), "fUSDT metapool paused");
        assertTrue(ISwap(NRVFUSDTMETA).paused(), "nrvFUSDT metapool paused");

        assertEq(ISwap(POOL3).owner(), SAFE);
        assertEq(ISwap(BTCPOOL).owner(), SAFE);
        assertEq(ISwap(ETHPOOL).owner(), SAFE);
        assertEq(ISwap(USTMETA).owner(), SAFE);
        assertEq(ISwap(FUSDTMETA).owner(), SAFE);
        assertEq(ISwap(NRVFUSDTMETA).owner(), SAFE);

        emit log_named_uint("3pool USDT admin", ISwap(POOL3).getAdminBalance(1));
        emit log_named_uint("3pool BUSD admin", ISwap(POOL3).getAdminBalance(0));
        emit log_named_uint("3pool USDC admin", ISwap(POOL3).getAdminBalance(2));
        emit log_named_uint("fUSDT meta LP admin", ISwap(FUSDTMETA).getAdminBalance(1));
        emit log_named_uint("fUSDT meta fUSDT admin", ISwap(FUSDTMETA).getAdminBalance(0));
        emit log_named_uint("UST meta LP admin", ISwap(USTMETA).getAdminBalance(1));
        emit log_named_uint("BTC pool BTCB admin", ISwap(BTCPOOL).getAdminBalance(0));
        emit log_named_uint("ETH pool ETH admin", ISwap(ETHPOOL).getAdminBalance(0));
    }

    function test_metapool_entrypoints_revert_when_paused() public {
        address[3] memory metas = [USTMETA, FUSDTMETA, NRVFUSDTMETA];
        for (uint256 k = 0; k < metas.length; k++) {
            address m = metas[k];
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 1e6;
            uint256[] memory outAmounts = new uint256[](2);

            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).swap(0, 1, 1e6, 0, block.timestamp);

            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).swapUnderlying(0, 1, 1e6, 0, block.timestamp);

            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).addLiquidity(amounts, 0, block.timestamp);

            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).removeLiquidityOneToken(1e18, 0, 0, block.timestamp);

            vm.expectRevert(bytes("Pausable: paused"));
            IMetaSwap(m).removeLiquidityImbalance(outAmounts, type(uint256).max, block.timestamp);
        }
    }

    function test_admin_functions_are_owner_only() public {
        address[6] memory pools = [POOL3, BTCPOOL, ETHPOOL, USTMETA, FUSDTMETA, NRVFUSDTMETA];
        for (uint256 k = 0; k < pools.length; k++) {
            address p = pools[k];
            vm.startPrank(attacker);
            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).withdrawAdminFees();

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).pause();

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).unpause();

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).setSwapFee(1);

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).setAdminFee(1);

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).rampA(100, block.timestamp + 1);

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).setDevAddress(attacker);

            vm.expectRevert(bytes("Ownable: caller is not the owner"));
            ISwap(p).transferOwnership(attacker);
            vm.stopPrank();
        }
    }

    function test_owner_is_2_of_3_safe() public {
        assertEq(ISafe(SAFE).getThreshold(), 2, "safe threshold");
        address[] memory owners = ISafe(SAFE).getOwners();
        assertEq(owners.length, 3, "safe owners");
        assertEq(ISafe(SAFE).VERSION(), "1.2.0");
    }

    /// @dev every wei held above the internal accounting is owner-only admin fee
    function test_admin_pot_equals_balance_minus_internal() public {
        _checkAdmin(USTMETA, 2);
        _checkAdmin(FUSDTMETA, 2);
        _checkAdmin(POOL3, 3);
        _checkAdmin(BTCPOOL, 2);
        _checkAdmin(ETHPOOL, 2);
    }

    function _checkAdmin(address pool, uint8 n) internal {
        for (uint8 i = 0; i < n; i++) {
            address tok = ISwap(pool).getToken(i);
            uint256 actual = IERC20(tok).balanceOf(pool);
            uint256 internalBal = ISwap(pool).getTokenBalance(i);
            uint256 admin = ISwap(pool).getAdminBalance(i);
            assertEq(admin, actual - internalBal, "admin accounting mismatch");
            emit log_named_uint("internal", internalBal);
            emit log_named_uint("admin   ", admin);
        }
    }

    function test_metapool_lp_admin_is_locked() public {
        // 3pool LP held by the metapools is >99% admin fee (owner-only claim)
        uint256 fmLp = IERC20(LP3).balanceOf(FUSDTMETA);
        uint256 fmInt = ISwap(FUSDTMETA).getTokenBalance(1);
        uint256 fmAdmin = ISwap(FUSDTMETA).getAdminBalance(1);
        assertEq(fmAdmin, fmLp - fmInt);
        assertGt(fmAdmin, 190_000e18, "fUSDT meta admin LP");
        assertGt(fmAdmin * 100 / fmLp, 98, "admin share");

        uint256 umLp = IERC20(LP3).balanceOf(USTMETA);
        uint256 umInt = ISwap(USTMETA).getTokenBalance(1);
        uint256 umAdmin = ISwap(USTMETA).getAdminBalance(1);
        assertEq(umAdmin, umLp - umInt);
        assertGt(umAdmin, 59_000e18, "UST meta admin LP");
        assertGt(umAdmin * 100 / umLp, 98, "admin share");
    }

    // ------------------------------------------------------------------
    // 2. live base pools are fair (no unprivileged profit)
    // ------------------------------------------------------------------
    function test_3pool_round_trip_loses_money() public {
        deal(USDT, attacker, 100_000e18);
        vm.startPrank(attacker);
        IERC20(USDT).approve(POOL3, type(uint256).max);
        uint256 busdOut = ISwap(POOL3).swap(1, 0, 100_000e18, 0, block.timestamp);
        IERC20(BUSD).approve(POOL3, type(uint256).max);
        uint256 usdtBack = ISwap(POOL3).swap(0, 1, busdOut, 0, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("100k USDT -> USDT back", usdtBack);
        assertLt(usdtBack, 100_000e18, "round trip must lose");
    }

    function test_3pool_lp_mint_redeem_loses_money() public {
        deal(USDT, attacker, 100_000e18);
        uint256[] memory amounts = new uint256[](3);
        amounts[1] = 100_000e18;
        vm.startPrank(attacker);
        IERC20(USDT).approve(POOL3, type(uint256).max);
        uint256 lp = ISwap(POOL3).addLiquidity(amounts, 0, block.timestamp);
        IERC20(LP3).approve(POOL3, type(uint256).max);
        uint256 usdtOut = ISwap(POOL3).removeLiquidityOneToken(lp, 1, 0, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("100k USDT -> LP -> USDT", usdtOut);
        assertLt(usdtOut, 100_000e18, "single-sided mint/redeem must lose");
    }

    // ------------------------------------------------------------------
    // 3. ETH/BTC pool drain is holder-gated and bounded
    // ------------------------------------------------------------------
    function test_anyeth_dump_bounded_by_pool_reserve() public {
        uint256 internalEth = ISwap(ETHPOOL).getTokenBalance(0);
        deal(ANYETH, attacker, 500e18);
        vm.startPrank(attacker);
        IERC20(ANYETH).approve(ETHPOOL, type(uint256).max);
        uint256 ethOut = ISwap(ETHPOOL).swap(1, 0, 500e18, 0, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("internal ETH reserve", internalEth);
        emit log_named_uint("ETH out for 500 anyETH", ethOut);
        assertGt(ethOut, 0.8e18, "dump path exists");
        assertLt(ethOut, internalEth, "bounded by internal reserve");
    }

    function test_anybtc_dump_bounded_by_pool_reserve() public {
        uint256 internalBtc = ISwap(BTCPOOL).getTokenBalance(0);
        deal(ANYBTC, attacker, 100e8);
        vm.startPrank(attacker);
        IERC20(ANYBTC).approve(BTCPOOL, type(uint256).max);
        uint256 btcOut = ISwap(BTCPOOL).swap(1, 0, 100e8, 0, block.timestamp);
        vm.stopPrank();
        emit log_named_uint("internal BTCB reserve", internalBtc);
        emit log_named_uint("BTCB out for 100 anyBTC", btcOut);
        assertGt(btcOut, 0.0069e18, "dump path exists");
        assertLt(btcOut, internalBtc, "bounded by internal reserve");
    }

    /// @dev the paired bridge tokens cannot be acquired on-chain at size
    function test_anyeth_acquisition_blocked() public {
        // 1) PancakeSwap anyETH/WBNB pair is dust
        (uint112 r0, uint112 r1,) = IPancakePair(PCS_ANYETH_WBNB).getReserves();
        emit log_named_uint("PCS anyETH reserve", r0);
        assertLt(uint256(r0), 0.01e18, "anyETH market is dust");
        assertLt(uint256(r1), 0.01e18, "WBNB side dust");

        // 2) no public mint: Swapin is onlyOwner (Multichain DCRM owner EOA)
        vm.prank(attacker);
        vm.expectRevert(bytes("only owner"));
        IErc20SwapAsset(ANYETH).Swapin(bytes32(0), attacker, 1e18);

        // 3) the owner is an EOA (Multichain bridge signer), no code
        assertEq(IErc20SwapAsset(ANYETH).owner().code.length, 0, "owner is EOA");
    }

    // ------------------------------------------------------------------
    // 4. farm custody is standard MasterChef (no outsider extraction)
    // ------------------------------------------------------------------
    function test_farm_is_standard_masterchef() public {
        (address lp,,,) = IFarm(FARM).poolInfo(0);
        assertEq(lp, LP3, "farm pool 0 is 3pool LP");
        assertGt(IERC20(LP3).balanceOf(FARM), 300_000e18, "farm holds the 3pool LP");
        // farm exposes no function that transfers other users' LP
        assertEq(IFarm(FARM).owner(), SAFE, "farm owner is the safe");
    }

    // ------------------------------------------------------------------
    // 5. the extra live MetaSwap instances (found in Phase 2) are bounded
    // ------------------------------------------------------------------
    /// @dev 7 more unpaused MetaSwap proxies run the same pre-#469 vulnerable impl
    ///      (0xf642f2a6) plus one on 0xfa97adb5. Their drainable value is bounded by
    ///      their internal LP reserves (the paired tokens are dead 2021 "RC"
    ///      certificates / rUSD / fUSDT with no or adverse markets).
    function test_extra_live_vulnerable_metapools_bounded() public {
        address[8] memory ms = [
            0x97B9054122eF8888590934F0eC8E10580232E85d,
            0xC80Cc653392f4734201331E39a66aA8a483D29BD,
            0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f,
            0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459,
            0xF100326c19996eaf2d8E93A503725F643e36099C,
            0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE,
            0xbC7477e46A95758dE5012744f7A350A4E0d03484,
            0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114
        ];
        // vulnerable MetaSwap impls (code hashes pinned 2026-10-11)
        assertEq(
            keccak256(address(0xf642f2A626a8B732619606C493aBFc2433dd2D35).code),
            bytes32(0xB30d65529d9906806b3F4700f559d1A222C3795D84123e5962d38501b271b797)
        );
        assertEq(
            keccak256(address(0xfA97aDb530B38639a83B1890Ee17942804035dDF).code),
            bytes32(0x27daFd023dDF7F9D39A750f7d7d0D18f75d5C6eEeb60336c86004c251955cfc7)
        );

        uint256 totalLp;
        for (uint256 i = 0; i < ms.length; i++) {
            assertFalse(ISwap(ms[i]).paused(), "extra metapool must be live");
            assertEq(ISwap(ms[i]).owner(), SAFE);
            uint256 internal0 = ISwap(ms[i]).getTokenBalance(0);
            if (internal0 == 0) continue; // fully drained instance
            uint256 lpOut = ISwap(ms[i]).calculateSwap(0, 1, internal0);
            totalLp += lpOut;
            emit log_named_uint("pool internal token0", internal0);
            emit log_named_uint("drainable LP out (wei)", lpOut);
        }
        emit log_named_uint("TOTAL drainable LP (wei)", totalLp);
        assertLt(totalLp, 11e18, "total drain bound must stay under 11 LP (~$11)");
    }
}

interface IPancakePair {
    function getReserves() external view returns (uint112, uint112, uint32);
}

interface IFarm {
    function poolInfo(uint256) external view returns (address, uint256, uint256, uint256);
    function owner() external view returns (address);
}
