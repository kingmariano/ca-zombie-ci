// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IACLManager, IPool, IPoolConfigurator, IPoolAddressesProvider, IERC20Like} from "../src/Interfaces.sol";

/// @title Purrlend (C2-21) live-state and access-control fork verification
/// @notice Read-only mainnet forks. No transaction is ever sent to a real chain:
///         every mutation below runs inside the local anvil fork created by vm.createSelectFork.
///         Public keyless RPCs only.
contract PurrlendForkTest is Test {
    // ------------------------------- HyperEVM (chain 999) -------------------------------
    string constant H_RPC = "https://rpc.hyperliquid.xyz/evm";
    address constant H_ACL = 0x507Bc877A27baEB12BE4Df42EfAA949A9A67703d;
    address constant H_PROVIDER = 0xf33e33B35163Ce2f46bf7150E1592839aC199124;
    address constant H_POOL = 0xb61218d3efE306f7579eE50D1a606d56bc222048;
    address constant H_CONFIG = 0x8cFaFcAc64a9a5CB52FC3482c3b8C855e9308767;
    address constant H_USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address constant H_SUSDP = 0x9B3a8f7CEC208e247d97dEE13313690977e24459;
    address constant H_AUSDC = 0x1A77d9f5E760586172F8dc2cE0e6c5ef7C5d4678;
    address constant H_ASUSDP = 0xD9ADD9cBF568BB82c2d0ECc08f657486dc6d6696;

    // ------------------------------- MegaETH (chain 4326) -------------------------------
    string constant M_RPC = "https://mainnet.megaeth.com/rpc";
    address constant M_ACL = 0x217214BbF25F02A8019d42EA315aB192540aDa13;
    address constant M_PROVIDER = 0x402D38C3415Ad92a0E766e1491Dc222871B1Df7a;
    address constant M_POOL = 0x81D5D25ea81b72E546fC71B5bAa8B059eF0dA702;
    address constant M_CONFIG = 0xB54407684B028ee75F012EF264644186e93e4E0E;
    address constant M_USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address constant M_GLV = 0x3782d91C5888dE31F627495e6aAAC3f09499fe72;
    address constant M_AUSDM = 0x1e7c2beC64062098A192118d1708DaD717C9C5fC;
    address constant M_AGLV = 0x95Da1Cd5A66D3758996356d7F6cEcA55bbBfb087;

    // ---------------------------------- Actors ------------------------------------------
    address constant SAFE = 0x4c2444d88AD61B0842Fba7CCdCb226260eBfA1bc; // 2-of-3 owners: 0x7312F0b2.., 0x2BceF069.., 0xB4837962..
    address constant ADMIN_EOA = 0x6056BE985DD4c50fECA34130FeDD0a35857099FD; // single EOA holding DEFAULT_ADMIN
    address constant ATTACKER = 0xd8010aca201f6113160200b8a521F35BE9f94C24; // Apr-25-2026 exploit address
    address constant DEPLOYER = 0xD730Ad413aDd59F72769B62c20Dc3aD308de5568;
    address constant FRESH = 0x000000000000000000000000000000000000F8e5; // fresh unprivileged attacker

    // known live state (read 2026-10-09; blocks 48,051,486 H / 28,723,353 M)
    uint256 constant H_ASUSDP_IDLE = 420054151257482857455; // 420.054151257482857455 sUSDp held by aSUSDp
    uint256 constant M_AGLV_IDLE = 175478672274128016422; // 175.478672274128016422 GLV held by aGLV

    function pausedFlag(uint256 cfg) internal pure returns (bool) {
        return (cfg & (uint256(1) << 60)) != 0;
    }

    function tryCall(address target, bytes memory data) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = target.call(data);
    }

    function assertReverts(address target, bytes memory data, string memory label) internal {
        (bool ok, bytes memory ret) = tryCall(target, data);
        if (ok) {
            emit log_named_string("UNEXPECTED SUCCESS", label);
            fail();
        }
        emit log_named_string("reverted as expected", label);
        emit log_bytes(ret);
    }

    // =====================================================================================
    // --------------------------------------- HyperEVM ------------------------------------
    // =====================================================================================

    function test_H_live_roles_no_bridge_holder() public {
        vm.createSelectFork(H_RPC);
        IACLManager acl = IACLManager(H_ACL);
        bytes32 BRIDGE = acl.BRIDGE_ROLE();
        // DEFAULT_ADMIN sits with the fresh single EOA; the old 2-of-3 Safe holds NO ACL role.
        assertTrue(acl.hasRole(acl.DEFAULT_ADMIN_ROLE(), ADMIN_EOA), "EOA DEFAULT_ADMIN");
        assertFalse(acl.hasRole(acl.DEFAULT_ADMIN_ROLE(), SAFE), "safe not DEFAULT_ADMIN H");
        // Nobody holds BRIDGE (the exploit holder was revoked on 2026-04-25).
        assertFalse(acl.hasRole(BRIDGE, ATTACKER), "attacker revoked");
        assertFalse(acl.hasRole(BRIDGE, ADMIN_EOA), "EOA not bridge");
        assertFalse(acl.hasRole(BRIDGE, SAFE), "safe not bridge");
        assertFalse(acl.hasRole(BRIDGE, DEPLOYER), "deployer not bridge");
        // BRIDGE role admin is DEFAULT_ADMIN.
        assertEq(acl.getRoleAdmin(BRIDGE), acl.DEFAULT_ADMIN_ROLE(), "role admin");
        emit log_named_address("HyperEVM DEFAULT_ADMIN", ADMIN_EOA);
    }

    function test_H_all_reserves_paused() public {
        vm.createSelectFork(H_RPC);
        address[] memory list = IPool(H_POOL).getReservesList();
        assertEq(list.length, 9, "reserve count");
        for (uint256 i; i < list.length; i++) {
            uint256 cfg = IPool(H_POOL).getConfiguration(list[i]);
            assertTrue(pausedFlag(cfg), "reserve paused");
        }
        emit log_named_uint("HyperEVM reserves paused", list.length);
    }

    function test_H_fresh_unprivileged_paths_all_revert() public {
        vm.createSelectFork(H_RPC);
        IACLManager acl = IACLManager(H_ACL);

        bytes32 bridge = acl.BRIDGE_ROLE();
        vm.prank(FRESH);
        assertReverts(H_ACL, abi.encodeWithSelector(IACLManager.grantRole.selector, bridge, FRESH), "H: fresh grantRole(BRIDGE)");

        vm.prank(FRESH);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.mintUnbacked.selector, H_USDC, 1_000_000e6, FRESH, uint16(0)), "H: fresh mintUnbacked");

        vm.prank(FRESH);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.supply.selector, H_USDC, 100e6, FRESH, uint16(0)), "H: fresh supply (paused 29)");

        // a fresh address has no balance, but the paused check is reached via the incident attacker who does hold aUSDC
        vm.prank(ATTACKER);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.withdraw.selector, H_USDC, 1e6, ATTACKER), "H: attacker withdraw still paused");

        vm.prank(FRESH);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.borrow.selector, H_USDC, 1e6, uint256(2), uint16(0), FRESH), "H: fresh borrow (paused 29)");

        vm.prank(FRESH);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.repay.selector, H_USDC, 1e6, uint256(2), FRESH), "H: fresh repay (paused 29)");

        address[] memory assets = new address[](1);
        assets[0] = H_USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        vm.prank(FRESH);
        assertReverts(
            H_POOL,
            abi.encodeWithSelector(IPool.flashLoan.selector, FRESH, assets, amounts, modes, FRESH, bytes(""), uint16(0)),
            "H: fresh flashLoan (paused 29)"
        );

        vm.prank(FRESH);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.liquidationCall.selector, H_USDC, H_USDC, ATTACKER, 1e6, false), "H: fresh liquidationCall (paused 29)");
    }

    function test_H_privileged_bound_is_idle_liquidity_only() public {
        vm.createSelectFork(H_RPC);
        IACLManager acl = IACLManager(H_ACL);
        IPool pool = IPool(H_POOL);
        IPoolConfigurator cfg = IPoolConfigurator(H_CONFIG);

        // DEFAULT_ADMIN EOA can promote itself to POOL_ADMIN and BRIDGE (single-key path).
        vm.startPrank(ADMIN_EOA);
        acl.grantRole(acl.POOL_ADMIN_ROLE(), ADMIN_EOA);
        acl.grantRole(acl.BRIDGE_ROLE(), ADMIN_EOA);
        // ... unpause and mint unbacked USDC.
        cfg.setReservePause(H_USDC, false);
        pool.mintUnbacked(H_USDC, 1_000_000e6, ADMIN_EOA, 0);
        vm.stopPrank();

        assertGt(IERC20Like(H_AUSDC).balanceOf(ADMIN_EOA), 0, "minted aUSDC");
        emit log_named_uint("aUSDC minted to admin", IERC20Like(H_AUSDC).balanceOf(ADMIN_EOA));

        // The minted claim cannot be cashed: the aToken holds 0 USDC.
        vm.prank(ADMIN_EOA);
        assertReverts(H_POOL, abi.encodeWithSelector(IPool.withdraw.selector, H_USDC, 1_000_000e6, ADMIN_EOA), "H: withdraw minted 1M USDC (no liquidity)");

        // The only cash the privileged roles can reach today:
        uint256 idleUSDC = IERC20Like(H_USDC).balanceOf(H_AUSDC);
        uint256 idleSUSDp = IERC20Like(H_SUSDP).balanceOf(H_ASUSDP);
        assertEq(idleUSDC, 0, "aUSDC idle is zero");
        assertEq(idleSUSDp, H_ASUSDP_IDLE, "aSUSDp idle");
        emit log_named_uint("HyperEVM idle aUSDC (raw)", idleUSDC);
        emit log_named_uint("HyperEVM idle aSUSDp (raw)", idleSUSDp);
    }

    function test_H_provider_owner_can_replace_acl_manager() public {
        vm.createSelectFork(H_RPC);
        IPoolAddressesProvider provider = IPoolAddressesProvider(H_PROVIDER);
        assertEq(provider.owner(), SAFE, "provider owner is the 2-of-3 Safe");
        // The Safe still owns the AddressesProvider even though it holds no ACL role:
        // it can swap the ACLManager (or the pool implementation) -> full privileged takeover.
        vm.prank(SAFE);
        provider.setACLManager(address(0xBEEF));
        assertEq(provider.getACLManager(), address(0xBEEF), "ACL manager swapped by owner");
        emit log_string("Safe (provider owner) CAN replace the ACLManager on HyperEVM");
    }

    // =====================================================================================
    // --------------------------------------- MegaETH -------------------------------------
    // =====================================================================================

    function test_M_live_roles_no_bridge_holder() public {
        vm.createSelectFork(M_RPC);
        IACLManager acl = IACLManager(M_ACL);
        bytes32 BRIDGE = acl.BRIDGE_ROLE();
        // DEFAULT_ADMIN is shared: the EOA AND the (stripped) 2-of-3 Safe.
        assertTrue(acl.hasRole(acl.DEFAULT_ADMIN_ROLE(), ADMIN_EOA), "EOA DEFAULT_ADMIN");
        assertTrue(acl.hasRole(acl.DEFAULT_ADMIN_ROLE(), SAFE), "safe DEFAULT_ADMIN");
        assertFalse(acl.hasRole(acl.POOL_ADMIN_ROLE(), SAFE), "safe no POOL_ADMIN");
        assertFalse(acl.hasRole(BRIDGE, ATTACKER), "attacker revoked");
        assertFalse(acl.hasRole(BRIDGE, ADMIN_EOA), "EOA not bridge");
        assertFalse(acl.hasRole(BRIDGE, SAFE), "safe not bridge");
        emit log_named_address("MegaETH DEFAULT_ADMIN (EOA)", ADMIN_EOA);
        emit log_named_address("MegaETH DEFAULT_ADMIN (Safe)", SAFE);
    }

    function test_M_all_reserves_paused() public {
        vm.createSelectFork(M_RPC);
        address[] memory list = IPool(M_POOL).getReservesList();
        assertEq(list.length, 4, "reserve count");
        for (uint256 i; i < list.length; i++) {
            uint256 cfg = IPool(M_POOL).getConfiguration(list[i]);
            assertTrue(pausedFlag(cfg), "reserve paused");
        }
        emit log_named_uint("MegaETH reserves paused", list.length);
    }

    function test_M_fresh_unprivileged_paths_all_revert() public {
        vm.createSelectFork(M_RPC);
        IACLManager acl = IACLManager(M_ACL);

        bytes32 bridge = acl.BRIDGE_ROLE();
        vm.prank(FRESH);
        assertReverts(M_ACL, abi.encodeWithSelector(IACLManager.grantRole.selector, bridge, FRESH), "M: fresh grantRole(BRIDGE)");

        vm.prank(FRESH);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.mintUnbacked.selector, M_USDM, 1_000_000e18, FRESH, uint16(0)), "M: fresh mintUnbacked");

        vm.prank(FRESH);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.supply.selector, M_USDM, 100e18, FRESH, uint16(0)), "M: fresh supply (paused 29)");

        vm.prank(ATTACKER);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.withdraw.selector, M_USDM, 1e18, ATTACKER), "M: attacker withdraw still paused");

        vm.prank(FRESH);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.borrow.selector, M_USDM, 1e18, uint256(2), uint16(0), FRESH), "M: fresh borrow (paused 29)");

        vm.prank(FRESH);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.repay.selector, M_USDM, 1e18, uint256(2), FRESH), "M: fresh repay (paused 29)");

        address[] memory assets = new address[](1);
        assets[0] = M_USDM;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        vm.prank(FRESH);
        assertReverts(
            M_POOL,
            abi.encodeWithSelector(IPool.flashLoan.selector, FRESH, assets, amounts, modes, FRESH, bytes(""), uint16(0)),
            "M: fresh flashLoan (paused 29)"
        );

        vm.prank(FRESH);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.liquidationCall.selector, M_GLV, M_USDM, ATTACKER, 1e18, false), "M: fresh liquidationCall (paused 29)");
    }

    function test_M_privileged_bound_is_idle_liquidity_only() public {
        vm.createSelectFork(M_RPC);
        IACLManager acl = IACLManager(M_ACL);
        IPool pool = IPool(M_POOL);
        IPoolConfigurator cfg = IPoolConfigurator(M_CONFIG);

        vm.startPrank(ADMIN_EOA);
        acl.grantRole(acl.POOL_ADMIN_ROLE(), ADMIN_EOA);
        acl.grantRole(acl.BRIDGE_ROLE(), ADMIN_EOA);
        cfg.setReservePause(M_USDM, false);
        pool.mintUnbacked(M_USDM, 100_000e18, ADMIN_EOA, 0);
        vm.stopPrank();

        assertGt(IERC20Like(M_AUSDM).balanceOf(ADMIN_EOA), 0, "minted aUSDm");
        vm.prank(ADMIN_EOA);
        assertReverts(M_POOL, abi.encodeWithSelector(IPool.withdraw.selector, M_USDM, 100_000e18, ADMIN_EOA), "M: withdraw minted USDm (no liquidity)");

        uint256 idleUSDm = IERC20Like(M_USDM).balanceOf(M_AUSDM);
        uint256 idleGLV = IERC20Like(M_GLV).balanceOf(M_AGLV);
        assertEq(idleUSDm, 0, "aUSDm idle is zero");
        assertEq(idleGLV, M_AGLV_IDLE, "aGLV idle");
        emit log_named_uint("MegaETH idle aUSDm (raw)", idleUSDm);
        emit log_named_uint("MegaETH idle aGLV (raw)", idleGLV);
    }

    function test_M_safe_default_admin_can_mint_bridge() public {
        vm.createSelectFork(M_RPC);
        IACLManager acl = IACLManager(M_ACL);
        // The old 2-of-3 Safe kept DEFAULT_ADMIN on MegaETH: any 2 of its 3 keys
        // can grant themselves BRIDGE (one key compromise away from mintUnbacked).
        bytes32 bridge = acl.BRIDGE_ROLE();
        vm.prank(SAFE);
        acl.grantRole(bridge, address(0xBEEF));
        assertTrue(acl.hasRole(bridge, address(0xBEEF)), "safe granted bridge");
        emit log_string("Safe (DEFAULT_ADMIN) CAN grant BRIDGE on MegaETH");
    }

    function test_phantom_claims_of_incident_attacker_are_unredeemable() public {
        vm.createSelectFork(H_RPC);
        // The Apr-2026 attacker still holds the unbacked aTokens (USDC 5.495M nominal)
        // but they are not cashable: the USDC reserve aToken holds zero USDC.
        uint256 bal = IERC20Like(H_AUSDC).balanceOf(ATTACKER);
        assertGt(bal, 5_000_000e6, "attacker phantom aUSDC");
        assertEq(IERC20Like(H_USDC).balanceOf(H_AUSDC), 0, "no USDC behind the claim");
        // Even if an admin unpauses the reserve, withdraw fails for lack of liquidity.
        vm.startPrank(ADMIN_EOA);
        IACLManager(H_ACL).grantRole(IACLManager(H_ACL).POOL_ADMIN_ROLE(), ADMIN_EOA);
        IPoolConfigurator(H_CONFIG).setReservePause(H_USDC, false);
        vm.stopPrank();
        vm.prank(ATTACKER);
        (bool ok, bytes memory ret) = tryCall(H_POOL, abi.encodeWithSelector(IPool.withdraw.selector, H_USDC, 1e6, ATTACKER));
        assertFalse(ok, "attacker cannot withdraw even unpaused");
        emit log_named_uint("attacker phantom aUSDC (raw)", bal);
        emit log_bytes(ret);
    }
}
