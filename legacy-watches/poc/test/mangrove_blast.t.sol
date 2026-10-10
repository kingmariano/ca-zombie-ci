// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMangrove {
    struct OLKey {
        address outbound_tkn;
        address inbound_tkn;
        uint256 tickSpacing;
    }

    function marketOrderByTickCustom(OLKey calldata olKey, int256 maxTick, uint256 fillVolume, bool fillWants, uint256 maxGasreqForFailingOffers)
        external
        returns (uint256 takerGot, uint256 takerGave, uint256 bounty, uint256 feePaid);
}

/// @title H2-09 Mangrove (Blast) — are the live offers funded / takeable?
/// @notice DefiLlama reports ~$4.24M "TVL" on Blast = sum of live offer `gives`.
///         Mangrove v3 takes pull the outbound token FROM THE MAKER during the take.
///         These tests measure the true deliverable/profitable amount on a pinned fork.
///         No storage manipulation: takers are real on-chain accounts (impersonated).
///
/// Market prices used (2026-10-10, on-chain Thruster V3 pools):
///   mwstETH20 = 1.3925 WETH (pool 0x4e0e7d3b…); mwstETH40 = 0.0500 WETH (pool 0x9649ab08…)
///   BLAST = $0.0000622; WETH = $2492.75.
contract MangroveBlastTest is Test {
    address constant MGV = 0xb1a49C54192Ea59B233200eA38aB56650Dfb448C;
    address constant WETH = 0x4300000000000000000000000000000000000004;
    address constant USDB = 0x4300000000000000000000000000000000000003;
    address constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address constant BLAST = 0xb1a5700fA2358173Fe465e6eA4Ff52E36e88E2ad;
    address constant MWSTETH20 = 0x9a50953716bA58e3d6719Ea5c437452ac578705F;
    address constant MWSTETH40 = 0x999f220296B5843b2909Cc5f8b4204AacA5341D8;

    address constant MAKER_WETH_BLAST = 0xaC1cE7F65c2312b828260d959d2B95b7f5fF480E; // WETH/BLAST + USDe/USDB offers
    address constant MAKER_MWST40 = 0x26E47DC22C7ffaA1e2E9278584B496a0923c69e0; // WETH + mwstETH40 offers
    address constant MAKER_MWST20 = 0x67270AeE9A7f2393f4CA6fBd49519E5fc05A0843; // WETH + mwstETH20 offers

    // Real accounts used as takers (no vm.store):
    address constant TAKER_BLAST_HOLDER = 0xE1C3A806983EDC1fb8035eE2D3c712c8ef6355FC; // BlastKandel: 33,973 BLAST + 0.048 WETH
    address constant TAKER_MW40_HOLDER = 0xf9f77bB34fEDaAc86FcE6789187C737d6f846A27; // SmartKandel: 0.0643 mwstETH40

    uint256 constant FORK_BLOCK = 41_411_145;

    function setUp() public {
        string[3] memory urls = [
            vm.envOr("BLAST_RPC_URL", string("https://rpc.blast.io")),
            string("https://blast-rpc.publicnode.com"),
            string("https://blast.drpc.org")
        ];
        for (uint256 i = 0; i < urls.length; i++) {
            try vm.createSelectFork(urls[i], FORK_BLOCK) {
                return;
            } catch {}
        }
        revert("no working Blast fork RPC");
    }

    /// The big WETH/BLAST asks are unfunded: the maker's makerExecute reverts
    /// (it tries to buy WETH on a V3 pool with the BLAST it receives and fails).
    /// Restrict maxTick to the cheapest ask (133069) so the taker only needs ~30,046 BLAST.
    function test_weth_blast_offer_maker_reverts() public {
        address taker = TAKER_BLAST_HOLDER;
        vm.startPrank(taker);
        IERC20(BLAST).approve(MGV, type(uint256).max);
        uint256 wBefore = IERC20(WETH).balanceOf(taker);
        uint256 bBefore = IERC20(BLAST).balanceOf(taker);
        IMangrove.OLKey memory olKey = IMangrove.OLKey(WETH, BLAST, 1);
        (uint256 got, uint256 gave, uint256 bounty,) = IMangrove(MGV)
            .marketOrderByTickCustom(olKey, 133_069, 0.05e18, true, 20_000_000);
        vm.stopPrank();
        emit log_named_uint("takerGot WETH wei", got);
        emit log_named_uint("takerGave BLAST wei", gave);
        emit log_named_uint("bounty wei", bounty);
        assertEq(got, 0, "unfunded offer must deliver nothing");
        assertEq(IERC20(WETH).balanceOf(taker), wBefore, "no WETH gained");
        assertEq(IERC20(BLAST).balanceOf(taker), bBefore, "no BLAST spent");
    }

    /// mwstETH40 direction (maker delivers, but the price is stale-BAD at market):
    /// taker pays 0.446 WETH per mwstETH40 while the market is 0.05 WETH -> a loss.
    /// This is a control showing the maker DOES deliver when the direction is a loss.
    function test_mwsteth40_offer_delivers_at_loss() public {
        address taker = TAKER_BLAST_HOLDER;
        vm.startPrank(taker);
        IERC20(WETH).approve(MGV, type(uint256).max);
        uint256 wBefore = IERC20(WETH).balanceOf(taker);
        IMangrove.OLKey memory olKey = IMangrove.OLKey(MWSTETH40, WETH, 1);
        (uint256 got, uint256 gave,,) = IMangrove(MGV)
            .marketOrderByTickCustom(olKey, 0, 0.003e18, true, 20_000_000);
        vm.stopPrank();
        emit log_named_uint("mwstETH40 got", got);
        emit log_named_uint("WETH gave", gave);
        emit log_named_uint("WETH spent", wBefore - IERC20(WETH).balanceOf(taker));
    }

    /// The PROFITABLE direction: market 2:0 gives WETH and wants 2.26 mwstETH40 per WETH.
    /// At the on-chain market price (0.05 WETH per mwstETH40) the taker pays ~0.113 WETH
    /// of value per 1 WETH received. Bounded by the maker's 0.0019 WETH dust.
    function test_weth_for_mwsteth40_profit_dust() public {
        address taker = TAKER_MW40_HOLDER; // holds 0.0643 mwstETH40
        vm.startPrank(taker);
        IERC20(MWSTETH40).approve(MGV, type(uint256).max);
        uint256 wBefore = IERC20(WETH).balanceOf(taker);
        uint256 mBefore = IERC20(MWSTETH40).balanceOf(taker);
        IMangrove.OLKey memory olKey = IMangrove.OLKey(WETH, MWSTETH40, 1);
        (uint256 got, uint256 gave,,) = IMangrove(MGV)
            .marketOrderByTickCustom(olKey, 8_135, 0.0018e18, true, 20_000_000);
        vm.stopPrank();
        uint256 wAfter = IERC20(WETH).balanceOf(taker);
        uint256 mAfter = IERC20(MWSTETH40).balanceOf(taker);
        emit log_named_uint("WETH got", wAfter - wBefore);
        emit log_named_uint("mwstETH40 gave", mBefore - mAfter);
        emit log_named_uint("takerGot", got);
        emit log_named_uint("takerGave", gave);
    }

    /// The other profitable direction: market 1:1 gives mwstETH20 (market 1.3925 WETH)
    /// and wants 1.1302 WETH per unit. Bounded by the maker's 0.00643 mwstETH20 dust.
    function test_mwsteth20_for_weth_profit_dust() public {
        address taker = TAKER_BLAST_HOLDER; // holds 0.048 WETH
        vm.startPrank(taker);
        IERC20(WETH).approve(MGV, type(uint256).max);
        uint256 wBefore = IERC20(WETH).balanceOf(taker);
        uint256 mBefore = IERC20(MWSTETH20).balanceOf(taker);
        IMangrove.OLKey memory olKey = IMangrove.OLKey(MWSTETH20, WETH, 1);
        (uint256 got, uint256 gave,,) = IMangrove(MGV)
            .marketOrderByTickCustom(olKey, 1_240, 0.006e18, true, 20_000_000);
        vm.stopPrank();
        uint256 wAfter = IERC20(WETH).balanceOf(taker);
        uint256 mAfter = IERC20(MWSTETH20).balanceOf(taker);
        emit log_named_uint("mwstETH20 got", mAfter - mBefore);
        emit log_named_uint("WETH gave", wBefore - wAfter);
        emit log_named_uint("takerGot", got);
        emit log_named_uint("takerGave", gave);
    }

    /// Sanity: maker balances at the pinned fork block.
    function test_maker_balances() public {
        emit log_named_uint("maker WETH", IERC20(WETH).balanceOf(MAKER_WETH_BLAST));
        emit log_named_uint("maker USDE", IERC20(USDE).balanceOf(MAKER_WETH_BLAST));
        emit log_named_uint("maker USDB", IERC20(USDB).balanceOf(MAKER_WETH_BLAST));
        emit log_named_uint("maker mwst40", IERC20(MWSTETH40).balanceOf(MAKER_MWST40));
        emit log_named_uint("maker mwst20", IERC20(MWSTETH20).balanceOf(MAKER_MWST20));
        assertLt(IERC20(WETH).balanceOf(MAKER_WETH_BLAST), 0.01e18, "maker dust only");
        assertLt(IERC20(MWSTETH40).balanceOf(MAKER_MWST40), 0.01e18, "maker dust only");
    }
}
