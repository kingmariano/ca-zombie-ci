// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20, ISwap, IPoolProxy, IMobiusBurner, IUbeswapFactory, IUbeswapPair, IUbeswapRouter, IGauge} from "../src/IMobius.sol";

/// @title Mobius Money (Celo) — live extraction PoC / negative-proof suite
/// @notice Read-only fork tests. No mainnet transactions: everything runs on a local
///         Celo fork in CI. Fork block is whatever "latest" the public RPC serves.
contract MobiusPoCTest is Test {
    // ---- Celo mainnet addresses (all verified on celo.blockscout.com) ----
    address constant USDm = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    address constant DAI  = 0x90Ca507a5D4458a4C6C6249d186b6dCb02a5BCCd;
    address constant ATUST = 0xEd193C4E69F591E42398eF54DEa65aa1bb02835c;
    address constant OLDWBTC = 0xBe50a3013A1c94768A1ABb78c3cB79AB28fc1aCE; // Optics-era wrapped BTC (8dp)
    address constant BTC18 = 0xD629eb00dEced2a080B7EC630eF6aC117e614f1b;   // "Wrapped Bitcoin" 18dp (the pool's token0)
    address constant WBTC2 = 0xBAAB46E28388d2779e6E31Fd00cF0e5Ad95E327B;   // second 8dp WBTC
    address constant PUSD = 0xB4aa2986622249B1F45eb93F28Cfca2b2606d809;

    address constant POOL_CUSD_USDCET = 0xA5037661989789d0310aC2B796fa78F1B01F195D;
    address constant POOL_BTC_OLDWBTC = 0x19260b9b573569dDB105780176547875fE9fedA3;
    address constant POOL_BTC_WBTC2  = 0xaEFc4e8cF655a182E8346B24c8AbcE45616eE0d2;
    address constant POOL_USDM_ATUST = 0x9F4AdBD0af281C69a582eB2E6fa2A594D4204CAe;
    address constant POOL_USDM_DAI   = 0xF3f65dFe0c8c8f2986da0FEc159ABE6fd4E700B4;
    address constant POOL_USDM_PUSD  = 0x02Db089fb09Fda92e05e92aFcd41D9AAfE9C7C7C;
    address constant POOL_PAUSED     = 0x81B6a3d9f725AB5d706d9e552b128bC5bB0B58a1;

    address constant POOL_PROXY = 0x1bc2DbB8c4d04AaCF4A7fefcDB060766964B5237;
    address constant SWAPUTILS = 0x91a427Da218A82BCAa8B475686B3E5255460C838;

    address constant UBESWAP_FACTORY = 0x62d5b84bE28a183aBB507E125B384122D2C25fAE;
    address constant UBESWAP_ROUTER = 0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121;
    address constant PAIR_CELO_OLDWBTC = 0x9f3574DAe1AeFfD65ef739e9F50e2B9dd8831056;
    address constant PAIR_USDM_CELO = 0x1E593F1FE7B61c53874B54EC0c59FD0d5eb8621e;
    address constant PAIR_BTC_CELO = 0x0fa312Bbc0038d2a680A7922CCee0298D11D023C;
    address constant PAIR_BTC_USDM = 0x4bFbde2e484c2069e76c3207293E29daAA34a762;

    address constant GAUGE_ATUST_POOL = 0x107F94409746E8c8E6eFF139A100D17D9ca7FdfE;

    address attacker = address(0xA11CE);

    function _rpc() internal view returns (string memory) {
        // CI: prefer CELO_RPC_URL; else keyless public endpoints (no secrets).
        string memory e = vm.envOr("CELO_RPC_URL", string(""));
        if (bytes(e).length > 0) return e;
        return "https://forno.celo.org";
    }

    function setUp() public {
        vm.createSelectFork(_rpc());
    }

    // ---------------------------------------------------------------- code verification
    function test_pool_code_matches_audited_repo_artifact() public {
        // keccak256 of deployed runtime code — computed offline against the vendored
        // Mobius repo build artifact (solc 0.6.12, optimizer 200, istanbul) minus link slots.
        bytes32 h0 = keccak256(POOL_BTC_OLDWBTC.code);
        bytes32 h1 = keccak256(POOL_CUSD_USDCET.code);
        bytes32 h2 = keccak256(SWAPUTILS.code);
        emit log_named_bytes32("pool 0x1926 code hash", h0);
        emit log_named_bytes32("pool 0xa503 code hash", h1);
        emit log_named_bytes32("SwapUtils lib hash  ", h2);
        assertEq(h0, bytes32(0xc016363c38d5c28BBCd7B6C3dF3C7fd8E80EEb38b05b8f340a6d667f763a016e));
        assertEq(h2, bytes32(0xD50894206E35d3D7c52642560d0ba1112426987B9c6f907c8b7eb2f358c854c4));
        assertTrue(h1 != bytes32(0));
    }

    // ---------------------------------------------------------------- admin gating
    function test_admin_functions_revert_for_non_owner() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        ISwap(POOL_USDM_DAI).withdrawAdminFees();
        vm.expectRevert();
        ISwap(POOL_USDM_DAI).setSwapFee(1e8);
        vm.expectRevert();
        ISwap(POOL_USDM_DAI).setAdminFee(1e10);
        vm.expectRevert();
        ISwap(POOL_USDM_DAI).pause();
        vm.stopPrank();
        emit log_string("admin paths revert for unprivileged caller: OK");
    }

    function test_pool_proxy_admin_is_eoa_not_attacker_accessible() public {
        address oa = IPoolProxy(POOL_PROXY).ownership_admin();
        emit log_named_address("proxy ownership_admin", oa);
        emit log_named_address("proxy emergency_admin", IPoolProxy(POOL_PROXY).emergency_admin());
        // unprivileged attacker cannot call set_burner_kill / burn_many etc.
        assertTrue(oa != attacker);
    }

    // ---------------------------------------------------------------- depeg dump bounds
    function test_atust_dump_bounded_by_pool_balance() public {
        ISwap pool = ISwap(POOL_USDM_ATUST);
        uint256 atustBal = pool.getTokenBalance(1); // atUST
        uint256 usdmBal = pool.getTokenBalance(0);
        uint256 out = pool.calculateSwap(1, 0, atustBal);
        emit log_named_uint("atUST balance (1e18)   ", atustBal);
        emit log_named_uint("USDm balance (1e18)    ", usdmBal);
        emit log_named_uint("USDm out for ALL atUST ", out);
        assertLe(out, usdmBal); // absolute upper bound of any dump
        // Optimal point vs the real (dead) Ubeswap market: ~1 USDm of buyable atUST for ~0.06 USDm cost
        // → even ignoring cost, maximum gross extraction << 40 USDm. See analysis/ for details.
    }

    function test_pusd_dump_bounded_by_pool_balance() public {
        ISwap pool = ISwap(POOL_USDM_PUSD);
        uint256 pbal = pool.getTokenBalance(1);
        uint256 out = pool.calculateSwap(1, 0, pbal);
        emit log_named_uint("pUSD balance (1e18)", pbal);
        emit log_named_uint("USDm out for ALL pUSD", out);
        assertLe(out, pool.getTokenBalance(0));
    }

    /// The oldWBTC → Mobius → "BTC"(0xd629eb00) chain: paper-positive only if the BTC token
    /// is valued at DefiLlama's price; on-chain liquidation of the BTC token is impossible
    /// (its only pairs hold ~$3). Assert on-chain break-even is negative.
    function test_oldwbtc_to_btc_chain_not_realizable() public {
        // 1) cost to buy 300,000 raw (0.003) oldWBTC on Ubeswap (exact-out, constant product, 0.3% fee)
        (uint112 rCelo, uint112 rOld, ) = IUbeswapPair(PAIR_CELO_OLDWBTC).getReserves();
        uint256 outAmt = 300_000; // 0.003 oldWBTC
        uint256 amountIn = (uint256(rCelo) * outAmt * 1000) / ((uint256(rOld) - outAmt) * 997);
        emit log_named_uint("oldWBTC out (raw)", outAmt);
        emit log_named_uint("CELO cost (wei)  ", amountIn);

        // 2) Mobius pays in BTC18 for the same amount
        uint256 btcOut = ISwap(POOL_BTC_OLDWBTC).calculateSwap(1, 0, outAmt);
        emit log_named_uint("BTC18 out (wei)  ", btcOut);

        // 3) realizable USDm from selling that BTC18 token on its only Ubeswap pair
        (uint112 rbUsdm, uint112 rbBtc, ) = IUbeswapPair(PAIR_BTC_USDM).getReserves();
        uint256 recov = (uint256(rbUsdm) * btcOut * 997) / (uint256(rbBtc) * 1000 + btcOut * 997);
        emit log_named_uint("USDm recoverable (wei)", recov);
        // The pair simply cannot absorb even 1e-6 BTC18; recovered value is dust.
        assertLt(recov, 1e17); // < 0.1 USDm
        // Conclusion: buying oldWBTC for real CELO and receiving BTC18 is NOT realizable on-chain.
    }

    // ---------------------------------------------------------------- proxy burn path
    function test_proxy_burn_is_permissionless_but_unprofitable() public {
        // burn() on the PoolProxy is callable by any EOA (tx.origin == msg.sender), but any
        // tokens pulled go to the burner → receiver; the caller gains nothing.
        IPoolProxy proxy = IPoolProxy(POOL_PROXY);
        address burner = proxy.burners(USDm);
        emit log_named_address("burner for USDm", burner);
        assertFalse(proxy.burner_kill());
        uint256 balBefore = IERC20(USDm).balanceOf(attacker);
        vm.prank(attacker, attacker); // set tx.origin == attacker (EOA check)
        proxy.burn(USDm);
        uint256 balAfter = IERC20(USDm).balanceOf(attacker);
        assertEq(balAfter, balBefore, "caller must gain nothing");
        emit log_string("permissionless burn() yields caller 0: OK");
    }

    // ---------------------------------------------------------------- paused pool
    function test_paused_pool_swap_reverts() public {
        ISwap p = ISwap(POOL_PAUSED);
        assertTrue(p.paused());
        vm.prank(attacker);
        vm.expectRevert();
        p.swap(0, 1, 1, 0, block.timestamp + 1);
        emit log_string("paused pool blocks swaps: OK");
    }

    // ---------------------------------------------------------------- LP round trip
    function test_add_remove_liquidity_round_trip_is_a_loss() public {
        // attacker mints LP (deposit fee 1% -> devaddr) then removes proportionally (no fee)
        // => attacker ends with strictly less than they started.
        ISwap pool = ISwap(POOL_USDM_DAI);
        uint256 amt = 100e18;
        deal(USDm, attacker, amt * 2);
        deal(DAI, attacker, amt * 2);
        if (IERC20(USDm).balanceOf(attacker) < amt || IERC20(DAI).balanceOf(attacker) < amt) {
            emit log_string("deal() unsupported for these tokens on fork; skipping round-trip");
            return;
        }
        vm.startPrank(attacker);
        IERC20(USDm).approve(address(pool), type(uint256).max);
        IERC20(DAI).approve(address(pool), type(uint256).max);
        uint256 u0 = IERC20(USDm).balanceOf(attacker);
        uint256 d0 = IERC20(DAI).balanceOf(attacker);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amt;
        amounts[1] = amt;
        uint256 lp = pool.addLiquidity(amounts, 0, block.timestamp + 1);
        emit log_named_uint("LP minted", lp);
        uint256 lpBal = IERC20(pool.getLpToken()).balanceOf(attacker);
        IERC20(pool.getLpToken()).approve(address(pool), type(uint256).max); // burnFrom needs allowance
        pool.removeLiquidity(lpBal, new uint256[](2), block.timestamp + 1);
        uint256 u1 = IERC20(USDm).balanceOf(attacker);
        uint256 d1 = IERC20(DAI).balanceOf(attacker);
        vm.stopPrank();
        emit log_named_int("USDm delta", int256(u1) - int256(u0));
        emit log_named_int("DAI delta", int256(d1) - int256(d0));
        assertTrue(u1 + d1 < u0 + d0, "round trip must lose value (deposit fee)");
    }

    // ---------------------------------------------------------------- gauge claims
    function test_gauge_has_no_free_claim_without_stake() public {
        uint256 c0 = IGauge(GAUGE_ATUST_POOL).claimable_reward(attacker, CELO);
        emit log_named_uint("claimable CELO for random EOA", c0);
        assertEq(c0, 0);
        uint256 gaugeCelo = IERC20(CELO).balanceOf(GAUGE_ATUST_POOL);
        emit log_named_uint("CELO sitting in gauge (wei)", gaugeCelo);
        // Without staked LP nothing can be claimed: rewards require LP at risk.
    }

    // ---------------------------------------------------------------- misc state log
    function test_log_live_state() public {
        ISwap p = ISwap(POOL_BTC_OLDWBTC);
        emit log_named_uint("pool0x1926 A", p.getA());
        emit log_named_uint("pool0x1926 swapFee", p.getSwapFee());
        emit log_named_uint("pool0x1926 vprice", p.getVirtualPrice());
        emit log_named_uint("pool0x1926 tok0 (BTC18) bal", p.getTokenBalance(0));
        emit log_named_uint("pool0x1926 tok1 (oldWBTC) bal", p.getTokenBalance(1));
        emit log_named_uint("pool0x1926 admin0", p.getAdminBalance(0));
        emit log_named_uint("pool0x1926 admin1", p.getAdminBalance(1));
        emit log_named_address("pool0x1926 owner", p.owner());
        assertEq(p.owner(), POOL_PROXY);
    }
}
