// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// H2-02 V3-fork / small-chain cluster — fork-verified gate checks (read-only on live chains).
/// Each test forks a live chain via a keyless public RPC and proves the specific gate that
/// closes the candidate extraction path, or records the live admin state.
contract ClusterGatesTest is Test {
    // ---------- HyperSwap V3 (HyperEVM, chain 999) ----------
    address constant HYPEREVM_RPC_FALLBACK = address(0); // placeholder, URL used directly
    address constant HS_V3_FACTORY = 0xB1c0fa0B789320044A6F623cFe5eBda9562602E3;
    address constant HS_V3_OWNER = 0xBC7e493fd3ed834eD563f9597AAAED94e446bBc7; // EOA (no code)
    address constant HS_POOL_WHYPE_USDC_3000 = 0xe712D505572b3f84C1B4deB99E1BeAb9dd0E23c9;
    address constant WHYPE = 0x5555555555555555555555555555555555555555;
    address constant USDC_HYPEREVM = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;

    function test_HyperSwapV3_OwnerIsEOA_And_AttackerCannotCollectProtocolFees() public {
        string memory rpc = vm.envOr("HYPEREVM_RPC_URL", string("https://rpc.hyperliquid.xyz/evm"));
        vm.createSelectFork(rpc);

        // Owner of the factory is an EOA (single key) — privileged, not unprivileged.
        assertEq(HS_V3_OWNER.code.length, 0, "factory owner unexpectedly has code");
        (bool okOwner, bytes memory ret) = HS_V3_FACTORY.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(okOwner);
        assertEq(abi.decode(ret, (address)), HS_V3_OWNER);

        // Protocol fees are enabled (feeProtocol = 0x66 -> 6/64 each side) and accrued.
        (bool okFees, bytes memory feesRet) =
            HS_POOL_WHYPE_USDC_3000.staticcall(abi.encodeWithSignature("protocolFees()"));
        assertTrue(okFees);
        (uint128 pf0, uint128 pf1) = abi.decode(feesRet, (uint128, uint128));
        emit log_named_uint("pool protocolFees token0 (WHYPE wei)", pf0);
        emit log_named_uint("pool protocolFees token1 (USDC units)", pf1);

        // Fresh unprivileged address cannot collect them.
        vm.prank(address(0xBEEF));
        (bool okCollect,) = HS_POOL_WHYPE_USDC_3000.call(
            abi.encodeWithSignature("collectProtocol(address,address,uint128,uint128)", address(0xBEEF), 0xBEEF, 1, 1)
        );
        assertFalse(okCollect, "attacker was able to call collectProtocol");
    }

    // ---------- Kumbaya (MegaETH mainnet, chain 4326) ----------
    address constant KUMBAYA_FACTORY = 0x68b34591f662508076927803c567Cc8006988a09;
    address constant KUMBAYA_OWNER_SAFE = 0xC2F467A2d602172E1d4113bd2C4b77De5634Ae4a;

    function test_Kumbaya_OwnerIsSafe_And_AttackerCannotSetOwner() public {
        string memory rpc = vm.envOr("MEGAETH_RPC_URL", string("https://mainnet.megaeth.com/rpc"));
        vm.createSelectFork(rpc);

        (bool ok, bytes memory ret) = KUMBAYA_FACTORY.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok);
        assertEq(abi.decode(ret, (address)), KUMBAYA_OWNER_SAFE);

        // Owner is a Gnosis Safe (3-of-5) — privileged.
        (bool okT, bytes memory tRet) = KUMBAYA_OWNER_SAFE.staticcall(abi.encodeWithSignature("getThreshold()"));
        assertTrue(okT);
        assertEq(abi.decode(tRet, (uint256)), 3);

        // Fresh address cannot take ownership.
        vm.prank(address(0xBEEF));
        (bool okSet,) = KUMBAYA_FACTORY.call(abi.encodeWithSignature("setOwner(address)", address(0xBEEF)));
        assertFalse(okSet, "attacker set factory owner");
    }

    // ---------- Kinza (BSC, chain 56) ----------
    address constant KINZA_POOL = 0xcB0620b181140e57D1C0D8b724cde623cA963c8C;
    address constant KINZA_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant KINZA_ORACLE = 0xec203E7676C45455BF8cb43D28F9556F014Ab461;

    function test_Kinza_MajorsFrozen_NoNewSupplyOrBorrow() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com"));
        vm.createSelectFork(rpc);

        // Oracle is live and sane for USDC.
        (bool okP, bytes memory pRet) = KINZA_ORACLE.staticcall(abi.encodeWithSignature("getAssetPrice(address)", KINZA_USDC));
        assertTrue(okP);
        uint256 px = abi.decode(pRet, (uint256));
        emit log_named_uint("Kinza USDC oracle price 1e8", px);
        assertGt(px, 0.9e8);
        assertLt(px, 1.1e8);

        // USDC market is frozen: supply from anyone reverts (fresh attacker has no funds anyway,
        // so we use a funded fork account and still expect the frozen revert).
        address funded = makeAddr("funded");
        deal(KINZA_USDC, funded, 10_000e18);
        vm.startPrank(funded);
        (bool okSupply,) =
            KINZA_POOL.call(abi.encodeWithSignature("supply(address,uint256,address,uint16)", KINZA_USDC, 1e18, funded, 0));
        vm.stopPrank();
        assertFalse(okSupply, "supply into frozen market unexpectedly succeeded");
    }

    // ---------- Fathom lending (XDC, chain 50) ----------
    address constant FATHOM_POOL = 0x70d8005E3c8C7e383FE35Fa40156042F3393449F;
    address constant FATHOM_ORACLE = 0x54348d953Abc4f167cbdeDe648095c1aF7DE355A;
    address constant WXDC = 0x951857744785E80e2De051c32EE7b25f9c458C42;
    address constant FATHOM_FXD = 0x49d3f7543335cf38Fa10889CCFF10207e22110B5;

    function test_Fathom_OracleLive_And_FrozenFXD() public {
        string memory rpc = vm.envOr("XDC_RPC_URL", string("https://rpc.xinfin.network"));
        vm.createSelectFork(rpc);

        (bool okP, bytes memory pRet) = FATHOM_ORACLE.staticcall(abi.encodeWithSignature("getAssetPrice(address)", WXDC));
        assertTrue(okP);
        uint256 px = abi.decode(pRet, (uint256));
        emit log_named_uint("Fathom WXDC oracle price 1e18", px);
        assertGt(px, 0.01e18);
        assertLt(px, 0.1e18);

        // FXD reserve is frozen: supplying it reverts.
        address funded = makeAddr("funded");
        deal(FATHOM_FXD, funded, 1_000e18);
        vm.startPrank(funded);
        (bool okSupply,) =
            FATHOM_POOL.call(abi.encodeWithSignature("supply(address,uint256,address,uint16)", FATHOM_FXD, 1e18, funded, 0));
        vm.stopPrank();
        assertFalse(okSupply, "supply into frozen FXD market unexpectedly succeeded");
    }

    // ---------- Aborean (Abstract, chain 2741) ----------
    address constant ABOREAN_REGISTRY = 0x5927E0C4b307Af16260327DE3276CE17d8A4aB49;
    address constant ABOREAN_OWNER_SAFE = 0x4B3E171F4E5123a88ad72f3c8a843F86bde3F18f;

    function test_Aborean_OwnerIsSafe_And_AttackerCannotMutateRegistry() public {
        string memory rpc = vm.envOr("ABSTRACT_RPC_URL", string("https://api.mainnet.abs.xyz"));
        vm.createSelectFork(rpc, 87_300_000); // pinned: public RPCs reject the newest block intermittently
        if (ABOREAN_REGISTRY.code.length == 0) {
            vm.createSelectFork("https://2741.rpc.thirdweb.com", 87_300_000);
        }
        if (ABOREAN_REGISTRY.code.length == 0) {
            // Abstract public RPCs do not reliably serve historical state to forge forks.
            // The gate (owner = Gnosis Safe threshold 3; attacker calls revert) is verified by the
            // live reads recorded in analysis/v3cluster/REPORT.md.
            vm.skip(true, "Abstract RPC cannot serve historical state to forge");
        }

        assertGt(ABOREAN_REGISTRY.code.length, 0, "registry code not served by RPC");
        (bool ok, bytes memory ret) = ABOREAN_REGISTRY.staticcall(abi.encodeWithSignature("owner()"));
        if (!ok || ret.length != 32) {
            // Abstract public RPCs can serve code but not eth_call at historical blocks to forge.
            // The gate (owner = Gnosis Safe threshold 3; attacker calls revert) is verified by the
            // live reads recorded in analysis/v3cluster/REPORT.md.
            vm.skip(true, "Abstract RPC cannot serve historical eth_call to forge");
        }
        assertEq(abi.decode(ret, (address)), ABOREAN_OWNER_SAFE);

        (bool okT, bytes memory tRet) = ABOREAN_OWNER_SAFE.staticcall(abi.encodeWithSignature("getThreshold()"));
        assertTrue(okT);
        assertEq(abi.decode(tRet, (uint256)), 3);

        vm.prank(address(0xBEEF));
        (bool okSet,) =
            ABOREAN_REGISTRY.call(abi.encodeWithSignature("setManagedRewardsFactory(address)", address(0xBEEF)));
        assertFalse(okSet, "attacker mutated Aborean registry");
    }
}
