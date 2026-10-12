// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20, IUniV2Pair, IUniV2Factory, IDfynStakingRewards, IDfynVault} from "../src/Interfaces.sol";

/// @title Dfyn Network (Polygon/Fantom/OKC) — unprivileged-extraction PoC suite (fork only)
/// @notice Verifies live on a fork that no unprivileged extraction path exists:
///         no skim-able excess on any sampled pair, farms/vaults/chest are per-user,
///         swaps are lossy without a price edge. Documents the broken (deficit) pools.
contract DfynExtractionTest is Test {
    // Polygon addresses (checksummed; verified via factory reads + polygonscan)
    address constant FACTORY = 0xE7Fb3e833eFE5F9c441105EB65Ef8b261266423B;
    address constant DFYN = 0xC168E40227E4ebD8C1caE80F7a55a4F0e6D66C97;
    address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address constant FEE_TO = 0x74665b21461F8D9b23bAB7d599bfd7566a95fD70;

    // Top pools (all verified balance==reserve in Phase-2 scan)
    address constant P_DFYN_USDC = 0x4c38938E21cB9796932B0B0Cc3f8a088f07b49B0;
    address constant P_USDC_USDT = 0xBe40F7Fff5A2235aF9a8cb79A17373162eFeFA9C;
    address constant P_DAI_USDT = 0xdd228fdC8A41A02BDEa72060F53C1f88A2FD48B6;
    address constant P_USDC_WETH = 0x7D51bAd48d253dae37cC82cad07f73849286Deec;
    address constant P_USDC_DAI = 0xb7bd6d48C9b1aF7E126d0389C6970F157D974f33;
    address constant P_ROUTE_USDC = 0x40F0A05C8c7a86aD1491A3911c293e093fe92436;

    // eDAI/eUSDC "fake balance" pairs: balanceOf returns 96 bytes, first word == reserve
    address constant P_EDAI = 0x0B88A556F35C3582C201c085011a48524A95ceA1;

    // Broken pool: MONA side balance = 0 while reserve > 0 (token burned pair balance)
    address constant P_MONA_BROKEN = 0xfa284e6eB7eF307D71592966cBAAf37Dc1b6dd39;

    // Farm / vault contracts
    address constant FARM_DUAL_EMON = 0x0656Bd61A18Fd8E4bd48F90e41D043CdfEc96aE0;
    address constant VAULT_DFYN_4M = 0x07E3f04903aBd6506A6E41246Da7d39dA0D6a8CA;
    address constant DFYN_CHEST = 0x75455c3DE45dD32CBE9a5aD5E518D3D50823c976;

    address constant ATTACKER = address(0xA11CE);

    uint256 constant FORK_BLOCK = 95_381_964; // Phase-2 scan block (run 2)

    function setUp() public {
        // Pinned to the Phase-2 scan block; public drpc serves archive state for it in CI.
        try vm.createSelectFork("https://polygon.drpc.org", FORK_BLOCK) {
        } catch {
            try vm.createSelectFork(vm.envOr("POLYGON_RPC_URL", string("https://polygon-bor-rpc.publicnode.com"))) {
            } catch {
                vm.createSelectFork("https://polygon-bor-rpc.publicnode.com");
            }
        }
        vm.deal(ATTACKER, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
             1. PAIR IMPLEMENTATION UNIFORMITY (no custom pairs)
    //////////////////////////////////////////////////////////////*/

    function test_pair_code_uniformity() public {
        IUniV2Factory fac = IUniV2Factory(FACTORY);
        uint256 n = fac.allPairsLength();
        assertEq(n, 1788, "pair count changed");
        bytes32 h0 = keccak256(fac.allPairs(0).code);
        for (uint256 i = 1; i < 40; i++) {
            uint256 idx = (i * 47) % n;
            bytes32 h = keccak256(fac.allPairs(idx).code);
            assertEq(h, h0, "non-uniform pair bytecode found");
        }
        console.log("sampled 40/1788 pairs: all bytecode identical; hash=");
        console.logBytes32(h0);
    }

    function test_factory_state() public {
        IUniV2Factory fac = IUniV2Factory(FACTORY);
        assertEq(fac.feeTo(), FEE_TO, "feeTo changed");
        assertEq(fac.feeToSetter(), FEE_TO, "feeToSetter changed");
        assertEq(FEE_TO.code.length, 0, "feeTo is not an EOA");
        console.log("factory: 1788 pairs, feeTo EOA =", FEE_TO);
    }

    /*//////////////////////////////////////////////////////////////
        2. HEALTHY POOLS: balance == reserve, skim() extracts NOTHING
    //////////////////////////////////////////////////////////////*/

    function _checkPairNoExcess(address pair) internal {
        IUniV2Pair p = IUniV2Pair(pair);
        (uint112 r0, uint112 r1,) = p.getReserves();
        address t0 = p.token0();
        address t1 = p.token1();
        assertEq(IERC20(t0).balanceOf(pair), uint256(r0), "token0 excess exists!");
        assertEq(IERC20(t1).balanceOf(pair), uint256(r1), "token1 excess exists!");

        uint256 a0 = IERC20(t0).balanceOf(ATTACKER);
        uint256 a1 = IERC20(t1).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        p.skim(ATTACKER);
        assertEq(IERC20(t0).balanceOf(ATTACKER), a0, "skim extracted token0");
        assertEq(IERC20(t1).balanceOf(ATTACKER), a1, "skim extracted token1");
    }

    function test_top_pools_zero_excess_skim_noop() public {
        _checkPairNoExcess(P_DFYN_USDC);
        _checkPairNoExcess(P_USDC_USDT);
        _checkPairNoExcess(P_DAI_USDT);
        _checkPairNoExcess(P_USDC_WETH);
        _checkPairNoExcess(P_USDC_DAI);
        _checkPairNoExcess(P_ROUTE_USDC);
        console.log("all 6 top pools: skim() extracts $0 (balances == reserves)");
    }

    /// @notice Sample 50 pairs spread over the factory: excess must be junk-only (no value tokens).
    function test_sample_pairs_excess_only_junk() public {
        IUniV2Factory fac = IUniV2Factory(FACTORY);
        uint256 n = fac.allPairsLength();
        uint256 junkSides = 0;
        uint256 coreExcess = 0;
        for (uint256 i = 0; i < 50; i++) {
            uint256 idx = (i * 211) % n;
            address pair = fac.allPairs(idx);
            IUniV2Pair p = IUniV2Pair(pair);
            (uint112 r0, uint112 r1,) = p.getReserves();
            address t0 = p.token0();
            address t1 = p.token1();
            uint256 b0 = IERC20(t0).balanceOf(pair);
            uint256 b1 = IERC20(t1).balanceOf(pair);
            if (b0 > uint256(r0)) {
                uint256 e = b0 - uint256(r0);
                if (_isCoreToken(t0)) { coreExcess += e; } else { junkSides++; console.log("junk excess t0", t0, e); }
            }
            if (b1 > uint256(r1)) {
                uint256 e = b1 - uint256(r1);
                if (_isCoreToken(t1)) { coreExcess += e; } else { junkSides++; console.log("junk excess t1", t1, e); }
            }
        }
        // core-token excess in raw units must be dust (< 1e6 wei)
        assertLe(coreExcess, 1e6, "material core-token excess found");
        console.log("sample: junk excess sides =", junkSides, "core excess raw =", coreExcess);
    }

    function _isCoreToken(address t) internal pure returns (bool) {
        return t == USDC || t == USDT || t == DAI || t == WETH || t == WBTC
            || t == DFYN || t == 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270 // WMATIC
            || t == 0x16ECCfDbb4eE1A85A33f3A9B21175Cd7Ae753dB4;           // ROUTE
    }

    /*//////////////////////////////////////////////////////////////
      3. eDAI/eUSDC PAIRS: 96-byte balanceOf, first word == reserve, no excess
    //////////////////////////////////////////////////////////////*/

    function test_edai_pair_no_excess() public {
        IUniV2Pair p = IUniV2Pair(P_EDAI);
        (uint112 r0, uint112 r1,) = p.getReserves();
        address t0 = p.token0();
        address t1 = p.token1();
        assertEq(IERC20(t0).balanceOf(P_EDAI), uint256(r0), "t0 excess");
        assertEq(IERC20(t1).balanceOf(P_EDAI), uint256(r1), "t1 first-word excess");
        // skim must be a no-op
        uint256 a0 = IERC20(t0).balanceOf(ATTACKER);
        uint256 a1 = IERC20(t1).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        p.skim(ATTACKER);
        assertEq(IERC20(t0).balanceOf(ATTACKER), a0, "t0 extracted");
        assertEq(IERC20(t1).balanceOf(ATTACKER), a1, "t1 extracted");
        console.log("eDAI pair: no excess; 96-byte balanceOf first word == reserve");
    }

    /*//////////////////////////////////////////////////////////////
      4. BROKEN POOL: MONA burned out of pair; nothing extractable
    //////////////////////////////////////////////////////////////*/

    function test_broken_mona_pool() public {
        IUniV2Pair p = IUniV2Pair(P_MONA_BROKEN);
        (uint112 r0, uint112 r1,) = p.getReserves();
        address t0 = p.token0(); // MONA
        uint256 b0 = IERC20(t0).balanceOf(P_MONA_BROKEN);
        assertLt(b0, uint256(r0), "expected deficit on MONA side");
        assertEq(b0, 0, "MONA fully gone from pair");
        assertEq(IERC20(p.token1()).balanceOf(P_MONA_BROKEN), uint256(r1), "t1 balanced");
        // skim() reverts (balance - reserve underflows) -> nothing extractable
        uint256 a0 = IERC20(t0).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (bool ok,) = P_MONA_BROKEN.call(abi.encodeWithSignature("skim(address)", ATTACKER));
        assertFalse(ok, "skim unexpectedly succeeded on broken pool");
        assertEq(IERC20(t0).balanceOf(ATTACKER), a0, "extracted from broken pool");
        console.log("broken MONA pool: balance 0 < reserve, skim() reverts, $0 extractable");
    }

    /*//////////////////////////////////////////////////////////////
      5. FARMS: no unprivileged claim of others' stake/rewards
    //////////////////////////////////////////////////////////////*/

    function test_farm_no_free_rewards() public {
        IDfynStakingRewards farm = IDfynStakingRewards(FARM_DUAL_EMON);
        assertEq(farm.earned(ATTACKER, DFYN), 0, "attacker has earned rewards?");
        assertEq(farm.balanceOf(ATTACKER), 0, "attacker has stake?");
        assertGt(farm.totalSupply(), 0, "farm empty");

        uint256 balBefore = IERC20(DFYN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (bool ok,) = FARM_DUAL_EMON.call(abi.encodeWithSignature("getReward()"));
        assertTrue(ok, "getReward reverted");
        assertEq(IERC20(DFYN).balanceOf(ATTACKER), balBefore, "free rewards extracted");

        vm.prank(ATTACKER);
        (bool ok2,) = FARM_DUAL_EMON.call(abi.encodeWithSignature("withdraw(uint256)", 1));
        assertFalse(ok2, "withdraw of unowned stake succeeded");
        console.log("farm: getReward()=0, withdraw(1) reverts for zero-stake attacker");
    }

    /*//////////////////////////////////////////////////////////////
      6. VAULTS: claim() cannot touch other users' deposits
    //////////////////////////////////////////////////////////////*/

    function test_vault_claim_not_depositor() public {
        IDfynVault vault = IDfynVault(VAULT_DFYN_4M);
        assertEq(vault.balanceOf(ATTACKER), 0, "attacker has vault balance?");
        assertGt(vault.totalSupply(), 0, "vault empty");
        uint256 balBefore = IERC20(DFYN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (bool ok,) = VAULT_DFYN_4M.call(abi.encodeWithSignature("claim()"));
        assertTrue(ok, "claim reverted");
        assertEq(IERC20(DFYN).balanceOf(ATTACKER), balBefore, "vault funds extracted");
        console.log("vault: claim() by non-depositor yields nothing");
    }

    /// @notice vDFYN chest: leave() only returns pro-rata to share burners
    function test_dfyn_chest_no_free_value() public {
        uint256 shares = IERC20(DFYN_CHEST).balanceOf(ATTACKER);
        assertEq(shares, 0, "attacker has chest shares?");
        uint256 balBefore = IERC20(DFYN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        (bool ok,) = DFYN_CHEST.call(abi.encodeWithSignature("leave(uint256)", 0));
        // leave(0) succeeds with 0 transfer; any nonzero share requires owning shares
        assertEq(IERC20(DFYN).balanceOf(ATTACKER), balBefore, "chest funds extracted");
        assertTrue(ok, "leave(0) reverted unexpectedly");
        console.log("chest: leave() by non-holder yields nothing");
    }

    /*//////////////////////////////////////////////////////////////
      7. SWAP MATH: a plain swap cannot extract without giving value
    //////////////////////////////////////////////////////////////*/

    /// @notice Round trip through a healthy pool loses the 0.6% fees (no free lunch).
    function test_round_trip_swap_is_lossy() public {
        IUniV2Pair p = IUniV2Pair(P_USDC_USDT);
        (uint112 r0, uint112 r1,) = p.getReserves();

        uint256 amountIn = 10_000e6;
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * uint256(r1);
        uint256 denominator = uint256(r0) * 1000 + amountInWithFee;
        uint256 out1 = numerator / denominator;
        uint256 amountInWithFee2 = out1 * 997;
        uint256 numerator2 = amountInWithFee2 * (uint256(r0) + amountIn);
        uint256 denominator2 = (uint256(r1) - out1) * 1000 + amountInWithFee2;
        uint256 out0 = numerator2 / denominator2;
        assertLt(out0, amountIn, "round trip profitable without price edge");
        console.log("round-trip 10k USDC ->", out0, "back: loss (fees)");
    }
}
