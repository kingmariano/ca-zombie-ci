// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Alephium Bridge (AlphBridge) — Phase-2 unprivileged-extraction PoC
//
// All tests are READ-ONLY against live state via mainnet forks (no tx sent).
// They prove:
//   1. The live custody (ETH + BSC TokenBridge contracts) and configuration.
//   2. The trust gate on every value-moving path: guardian-signed VAAs only.
//   3. A forged VAA (attacker key, real emitter, real token, attacker payee)
//      is rejected: no unprivileged path to move the bridge funds.
//   4. Replay protection is live (historical/attack VAAs are consumed).
//   5. The May-30 attack VAAs and the June-2 recovery VAA were signed by the
//      SAME 3-of-4 guardian set (index 0) that is still in place today.
//   6. wALPH mint/burn is bridge-only; upgrade/registerChain need governance VAAs.
// ---------------------------------------------------------------------------

interface ICore {
    struct GuardianSet {
        address[] keys;
        uint32 expirationTime;
    }
    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 guardianIndex;
    }
    struct VM {
        uint8 version;
        uint32 timestamp;
        uint32 nonce;
        uint16 emitterChainId;
        uint16 targetChainId;
        bytes32 emitterAddress;
        uint64 sequence;
        uint8 consistencyLevel;
        bytes payload;
        uint32 guardianSetIndex;
        Signature[] signatures;
        bytes32 hash;
    }
    function getGuardianSet(uint32 index) external view returns (GuardianSet memory);
    function getCurrentGuardianSetIndex() external view returns (uint32);
    function parseAndVerifyVM(bytes calldata encodedVM)
        external
        returns (VM memory vm, bool valid, string memory reason);
    function chainId() external view returns (uint16);
}

interface IBridge {
    function chainId() external view returns (uint16);
    function wormhole() external view returns (address);
    function isTransferCompleted(bytes32 hash) external view returns (bool);
    function completeTransfer(bytes calldata encodedVm) external;
    function completeTransferAndUnwrapETH(bytes calldata encodedVm) external;
    function upgrade(bytes calldata encodedVm) external;
    function registerChain(bytes calldata encodedVm) external;
    function bridgeContracts(uint16 chainId_) external view returns (bytes32);
    function tokenImplementation() external view returns (address);
    function governanceChainId() external view returns (uint16);
    function governanceContract() external view returns (bytes32);
}

interface IERC20x {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function owner() external view returns (address);
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

contract AlephiumBridgePoC is Test {
    // ---- live addresses (2026-10-12) ----
    address constant ETH_BRIDGE = 0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43;
    address constant ETH_CORE = 0x01e82b67367dE9f805E55de730D5007a752912A8;
    address constant ETH_IMPL = 0x0F843945075DF4EA9C8a21f0e0CcFD5eB073eEAb;
    address constant WALPH = 0x590F820444fA3638e022776752c5eEF34E2F89A6;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant BSC_BRIDGE = 0x2971F580C34d3D584e0342741c6a622f69424dD8;
    address constant BSC_CORE = 0xE674e61111ecE5988113DA56f0b2Cc3CB22D5304;
    address constant BSC_IMPL = 0xfba7c899FFa8f8503b7a9690C45A63c5BCb4fB78;
    address constant BSC_WALPH = 0x8683BA2F8b0f69b2105f26f488bADe1d3AB4dec8;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BSC_USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant BSC_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // chain-255 emitter id of the Alephium bridge (custody contract)
    bytes32 constant ALPH_BRIDGE_ID =
        0x7F42F8e21128E70c7A30098A32C5c388dE7EB4fFc6ef7dd86f72e8e11acc4800;
    bytes32 constant GOV_CONTRACT =
        0x0000000000000000000000000000000000000000000000000000000000000004;
    address constant RECOVERY_IMPL = 0x9CC524Ca1Be15c7f02C67d45163e1f5BD896511a;

    address constant GUARDIAN_0 = 0x214f15D574A4D7895EEd709F80F7B49E5fE5Ad29;
    address constant GUARDIAN_1 = 0x78C7B8dD49CEdd6311f03357bBD7299B4d747852;
    address constant GUARDIAN_2 = 0x4B2CbEa0E19473D90e41581d4F39FA44b5fb88fB;
    address constant GUARDIAN_3 = 0x9eFb0cd728D59bA13EAbe2f17ceBF9f3AB6989A1;

    address constant ATTACKER = 0x6681ebC82551fE52fDB48E65872e85a3ae06921d;

    // keccak256(runtime code) — verified byte-identical on ETH (0x0f84..) and BSC (0xfba7..)
    bytes32 constant IMPL_CODEHASH =
        0x015189b82E3B437a2e8Fc0E98535f8B7D6314f27d3bf7b39a549768e4b3c5757;

    bytes32 constant IMPL_SLOT =
        0x360894a13BA1A3210667c828492Db98dcA3e2076cc3735a920a3ca505d382bbc;

    // ---- real VAAs extracted from actual transaction calldata ----
    // May-30 attack VAA: 200,967.309973 USDT -> attacker (tx 0x928e369e...)
    bytes internal ATTACK_VAA = hex"0100000000030040537d0eeaaa29a526b2b88cc26dd834e3b25e7c590efdbc4132211824c287997ea9d0d2eed5938163d47f99dd359618cd9abcfe1b16407ba6b191143d0ead290101d51d42f90de3d2958a7b29869986e9b729c32706db2d57998eab9f8912142d682a8ca551865530406ec02c817f3c24786c521865709351a29bb887729c8ebbdf0103910816407f4a4f971a61ee5e3fffb80e4b5ce32d5a5d0be6d496a46dd16b3fef5102fac7f707a8a3a9b40f8968bc021c91732d4631b6481e228809948e1885a0016a1a9ce3dbb0584d00ff00027f42f8e21128e70c7a30098a32c5c388de7eb4ffc6ef7dd86f72e8e11acc480000000000000f4237cd010000000000000000000000000000000000000000000000000000002eca95ca95000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000200146681ebc82551fe52fdb48e65872e85a3ae06921d0000000000000000000000000000000000000000000000000000000000000000";
    // June-2 recovery VAA: TokenBridge UpgradeContract -> 0x9cc524ca... (tx 0xade2846a...)
    bytes internal GOV_VAA = hex"0100000000030092b0a2c31caeb8d56863471386835c6d226a1e3fb1ce58f71dbf7de6d44061f7009ad83963800f0270bdf2e3d491411ac095c2f68c1a0a2fdf55e08e64823c510001b1e10cd01fb4a1f2c29c1bb1b5ffd9a3d16b59c8e926ec413cb0a4080c4efa9055d983788bf1db7eeb0a513f0f5c68876fff0a894388eb7dd6c76b9c3f4b3b4e00034cc3ff3a0fd4d2335f9f9fb7bea45eb4425271d2c7934391d6bf498441ce15b771ac3972a555c90f93ad9623b6ed6f11b8c0d7fca331d2d34e0b16918891cf9a0100000000403c44ea000000020000000000000000000000000000000000000000000000000000000000000004000000000000000020000000000000000000000000000000000000000000546f6b656e427269646765020000000000000000000000009cc524ca1be15c7f02c67d45163e1f5bd896511a";
    // Oct-12 live bridge-out VAA: 5.1792 USDC -> 0x3ae9... (tx 0x94874cf8...)
    bytes internal TODAY_VAA = hex"010000000003009a1ed972a27d8ab6743a33b279c7c2d35efd3911b1ad5e0156038df260356b115dc86c629ba30ae6f1521ccf1d884f923a133d359ae42df7a116f722623f416600014a1a62a30be2673f69719a226d32f823441e66ae9ea20f130e1d3b9c2217419f580a878bf8559344f6ac30258fb8803abc94d4c995bee41d146ab0926633e5800102d5b7cdddec02f348c2303794007017ab4b66f46d0cf99160543228570df89578325c4550ae9bc3376474b8ac64d49685b8c612c025a6d0c2281e155553203ac0006acc8875d629010000ff00027f42f8e21128e70c7a30098a32c5c388de7eb4ffc6ef7dd86f72e8e11acc4800000000000000201bcd0100000000000000000000000000000000000000000000000000000000004f0740000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000200143ae9c7e831f7d171d16177bbf49f2f7a31a6bf450000000000000000000000000000000000000000000000000000000000000000";

    string internal ethRpc;
    string internal bscRpc;

    function setUp() public {
        ethRpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        bscRpc = vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com"));
    }

    // Robust fork selection: try several RPCs (paid CI secrets first, then public
    // fallbacks) so a flaky/rate-limited endpoint cannot fail the whole suite.
    function _selectFork(string[6] memory urls) internal {
        for (uint256 i = 0; i < urls.length; i++) {
            if (bytes(urls[i]).length == 0) continue;
            try vm.createSelectFork(urls[i]) returns (uint256) {
                return;
            } catch {}
        }
        revert("no working fork RPC");
    }

    function _ethFork() internal {
        _selectFork([
            ethRpc,
            "https://eth.drpc.org",
            "https://ethereum-rpc.publicnode.com",
            "https://eth.llamarpc.com",
            vm.envOr("RPC_URL", string("")),
            vm.envOr("NODEREAL_ETH_RPC_URL", string(""))
        ]);
    }

    function _bscFork() internal {
        _selectFork([
            bscRpc,
            "https://bsc-rpc.publicnode.com",
            "https://bsc.drpc.org",
            "",
            "",
            ""
        ]);
    }

    function _impl(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPL_SLOT))));
    }

    function _word(bytes memory b, uint256 off) internal pure returns (uint256 x) {
        assembly {
            x := mload(add(add(b, 32), off))
        }
    }

    // ---------------------------------------------------------------
    // 1. ETH live state: custody, config, guardians, code
    // ---------------------------------------------------------------
    function test_eth_live_state() public {
        _ethFork();
        IBridge br = IBridge(ETH_BRIDGE);

        assertEq(br.chainId(), 2, "ETH chainId");
        assertEq(address(br.wormhole()), ETH_CORE, "core");
        assertEq(br.governanceChainId(), 0, "gov chain");
        assertEq(br.governanceContract(), GOV_CONTRACT, "gov contract");
        assertEq(br.bridgeContracts(255), ALPH_BRIDGE_ID, "registered Alephium emitter");
        assertEq(
            br.bridgeContracts(4),
            bytes32(uint256(uint160(BSC_BRIDGE))),
            "registered BSC emitter"
        );

        ICore.GuardianSet memory gs = ICore(ETH_CORE).getGuardianSet(0);
        assertEq(gs.keys.length, 4, "guardian count");
        assertEq(ICore(ETH_CORE).getCurrentGuardianSetIndex(), 0, "guardian set index");

        // live custody floors (measured 2026-10-12: 171,129 USDT / 15,290 USDC / 0.268 WBTC / 4.872 WETH)
        assertGe(IERC20x(USDT).balanceOf(ETH_BRIDGE), 80_000e6, "USDT custody");
        assertGe(IERC20x(USDC).balanceOf(ETH_BRIDGE), 7_000e6, "USDC custody");
        assertGe(IERC20x(WBTC).balanceOf(ETH_BRIDGE), 0.1e8, "WBTC custody");
        assertGe(IERC20x(WETH).balanceOf(ETH_BRIDGE), 2e18, "WETH custody");

        // wALPH token: supply + stuck self-balances (nobody can move these)
        assertGe(IERC20x(WALPH).totalSupply(), 10_000_000e18, "wALPH supply");
        assertGe(IERC20x(WALPH).balanceOf(WALPH), 70_000e18, "wALPH stuck at token");
        assertGe(IERC20x(USDT).balanceOf(WALPH), 500e6, "USDT stuck at token");
        assertEq(IERC20x(WALPH).owner(), ETH_BRIDGE, "token owner = bridge");

        // implementation is the standard BridgeImplementation, same code as BSC
        assertEq(_impl(ETH_BRIDGE), ETH_IMPL, "impl");
        assertEq(ETH_IMPL.codehash, IMPL_CODEHASH, "impl codehash");

        emit log_named_uint("ETH fork block", block.number);
        emit log_named_uint("USDT custody", IERC20x(USDT).balanceOf(ETH_BRIDGE));
        emit log_named_uint("WBTC custody", IERC20x(WBTC).balanceOf(ETH_BRIDGE));
        emit log_named_uint("WETH custody", IERC20x(WETH).balanceOf(ETH_BRIDGE));
        emit log_named_uint("wALPH supply", IERC20x(WALPH).totalSupply());
    }

    // ---------------------------------------------------------------
    // 2. BSC live state: same guardian set, same implementation code
    // ---------------------------------------------------------------
    function test_bsc_live_state() public {
        _bscFork();
        IBridge br = IBridge(BSC_BRIDGE);

        assertEq(br.chainId(), 4, "BSC chainId");
        assertEq(address(br.wormhole()), BSC_CORE, "core");
        assertEq(br.bridgeContracts(255), ALPH_BRIDGE_ID, "registered Alephium emitter");
        assertEq(
            br.bridgeContracts(2),
            bytes32(uint256(uint160(ETH_BRIDGE))),
            "registered ETH emitter"
        );

        ICore.GuardianSet memory gs = ICore(BSC_CORE).getGuardianSet(0);
        assertEq(gs.keys.length, 4, "guardian count");
        assertEq(gs.keys[0], GUARDIAN_0);
        assertEq(gs.keys[1], GUARDIAN_1);
        assertEq(gs.keys[2], GUARDIAN_2);
        assertEq(gs.keys[3], GUARDIAN_3);
        assertEq(ICore(BSC_CORE).getCurrentGuardianSetIndex(), 0, "guardian set index");

        assertGe(IERC20x(WBNB).balanceOf(BSC_BRIDGE), 10e18, "WBNB custody");
        assertGe(IERC20x(BSC_USDT).balanceOf(BSC_BRIDGE), 3_000e18, "USDT custody");
        assertGe(IERC20x(BSC_USDC).balanceOf(BSC_BRIDGE), 100e18, "USDC custody");
        assertGe(IERC20x(BSC_WALPH).totalSupply(), 100_000e18, "wALPH BSC supply");
        assertEq(IERC20x(BSC_WALPH).owner(), BSC_BRIDGE, "BSC wALPH owner");

        assertEq(_impl(BSC_BRIDGE), BSC_IMPL, "impl");
        assertEq(BSC_IMPL.codehash, IMPL_CODEHASH, "BSC impl codehash == ETH impl codehash");

        emit log_named_uint("BSC fork block", block.number);
        emit log_named_uint("WBNB custody", IERC20x(WBNB).balanceOf(BSC_BRIDGE));
        emit log_named_uint("BSC USDT custody", IERC20x(BSC_USDT).balanceOf(BSC_BRIDGE));
    }

    // ---------------------------------------------------------------
    // 3. Forged VAA (attacker-signed) is rejected end-to-end
    // ---------------------------------------------------------------
    function _fakeVAA(uint8 nSigs) internal view returns (bytes memory) {
        bytes memory payload = abi.encodePacked(
            uint8(1), // Transfer payload id
            uint256(150_000e6), // 150,000 USDT
            bytes32(uint256(uint160(USDT))),
            uint16(2), // tokenChain = ETH
            uint16(20), // recipient length
            ATTACKER, // recipient = attacker
            uint256(0) // fee
        );
        bytes memory sigs;
        if (nSigs > 0) {
            sigs = abi.encodePacked(
                uint8(0), keccak256("fake-r0"), keccak256("fake-s0"), uint8(27),
                uint8(1), keccak256("fake-r1"), keccak256("fake-s1"), uint8(28),
                uint8(3), keccak256("fake-r2"), keccak256("fake-s2"), uint8(27)
            );
        }
        return abi.encodePacked(
            uint8(1), // version
            uint32(0), // guardianSetIndex 0 (real set, wrong signatures)
            nSigs,
            sigs,
            uint32(0), // timestamp
            uint32(0), // nonce
            uint16(255), // emitterChain = Alephium
            uint16(2), // targetChain = ETH
            ALPH_BRIDGE_ID, // spoof the real bridge emitter
            uint64(1), // sequence
            uint8(15), // consistency
            payload
        );
    }

    function test_forged_vaa_rejected_and_no_funds_move() public {
        _ethFork();
        bytes memory vaa = _fakeVAA(4);

        (, bool valid, string memory reason) =
            ICore(ETH_CORE).parseAndVerifyVM(vaa);
        assertFalse(valid, "forged VAA must not verify");
        emit log_named_string("core rejection reason", reason);

        uint256 before = IERC20x(USDT).balanceOf(ETH_BRIDGE);
        vm.expectRevert();
        IBridge(ETH_BRIDGE).completeTransfer(vaa);
        assertEq(IERC20x(USDT).balanceOf(ETH_BRIDGE), before, "custody unchanged");
    }

    function test_unsigned_vaa_rejected() public {
        _ethFork();
        bytes memory vaa = _fakeVAA(0);
        try ICore(ETH_CORE).parseAndVerifyVM(vaa) returns (
            ICore.VM memory, bool valid, string memory
        ) {
            assertFalse(valid, "0-signature VAA must not verify");
        } catch {
            // revert on malformed/unsigned VAA is also a rejection
        }
    }

    // ---------------------------------------------------------------
    // 4. Historical attack + recovery VAAs verify: 3-of-4 guardian set,
    //    still the same set (index 0), replay protection live
    // ---------------------------------------------------------------
    function test_attack_vaa_guardian_signed_and_replay_blocked() public {
        _ethFork();
        (ICore.VM memory parsed, bool valid, ) =
            ICore(ETH_CORE).parseAndVerifyVM(ATTACK_VAA);
        assertTrue(valid, "attack VAA was guardian-signed (no key compromise)");
        assertEq(parsed.emitterChainId, 255);
        assertEq(parsed.emitterAddress, ALPH_BRIDGE_ID);
        assertEq(parsed.targetChainId, 2);
        assertEq(parsed.guardianSetIndex, 0, "same guardian set as today");
        assertEq(parsed.signatures.length, 3, "3-of-4 quorum");
        assertEq(parsed.signatures[0].guardianIndex, 0);
        assertEq(parsed.signatures[1].guardianIndex, 1);
        assertEq(parsed.signatures[2].guardianIndex, 3);
        // forged content: USDT transfer to the attacker that was never deposited
        assertEq(uint8(parsed.payload[0]), 1);
        assertEq(_word(parsed.payload, 1), 200_967_309_973, "attack amount");
        assertEq(
            address(uint160(_word(parsed.payload, 33))), USDT, "attack token"
        );
        assertEq(
            address(uint160(_word(parsed.payload, 69) >> 96)), ATTACKER, "attack recipient"
        );
        assertEq(_word(parsed.payload, 89), 0, "fee zero");

        // replay protection: consumed
        assertTrue(IBridge(ETH_BRIDGE).isTransferCompleted(parsed.hash), "consumed");
        vm.expectRevert(bytes("transfer already completed"));
        IBridge(ETH_BRIDGE).completeTransfer(ATTACK_VAA);
    }

    function test_recovery_governance_vaa_guardian_signed() public {
        _ethFork();
        (ICore.VM memory parsed, bool valid, ) =
            ICore(ETH_CORE).parseAndVerifyVM(GOV_VAA);
        assertTrue(valid, "recovery VAA guardian-signed");
        assertEq(parsed.emitterChainId, 0, "governance chain");
        assertEq(parsed.emitterAddress, GOV_CONTRACT, "governance emitter");
        assertEq(parsed.signatures.length, 3, "3-of-4 quorum");
        // payload: module "TokenBridge", action 2 = UpgradeContract
        assertEq(_word(parsed.payload, 0), uint256(0x546f6b656e427269646765));
        assertEq(uint8(parsed.payload[32]), 2);
        assertEq(_word(parsed.payload, 33), uint256(uint160(RECOVERY_IMPL)));
        // after the burn the bridge was reverted to the standard implementation
        assertEq(_impl(ETH_BRIDGE), ETH_IMPL);
    }

    function test_today_live_transfer_vaa_replay_blocked() public {
        _ethFork();
        (ICore.VM memory parsed, bool valid, ) =
            ICore(ETH_CORE).parseAndVerifyVM(TODAY_VAA);
        assertTrue(valid, "live bridge-out VAA (bridge is operating)");
        assertEq(parsed.emitterChainId, 255);
        assertEq(_word(parsed.payload, 1), 5_179_200, "5.1792 USDC");
        assertTrue(IBridge(ETH_BRIDGE).isTransferCompleted(parsed.hash));
        vm.expectRevert(bytes("transfer already completed"));
        IBridge(ETH_BRIDGE).completeTransfer(TODAY_VAA);
    }

    // ---------------------------------------------------------------
    // 5. Token mint/burn is bridge-only; governance entrypoints revert
    // ---------------------------------------------------------------
    function test_walph_mint_burn_bridge_only() public {
        _ethFork();
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("caller is not the owner"));
        IERC20x(WALPH).mint(ATTACKER, 1e24);
        vm.expectRevert(bytes("caller is not the owner"));
        IERC20x(WALPH).burn(ATTACKER, 1e18);
        vm.stopPrank();
    }

    function test_governance_entrypoints_reject_junk() public {
        _ethFork();
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IBridge(ETH_BRIDGE).upgrade(hex"00");
        vm.expectRevert();
        IBridge(ETH_BRIDGE).registerChain(hex"00");
        vm.expectRevert();
        IBridge(ETH_BRIDGE).completeTransfer(hex"00");
        vm.stopPrank();
    }
}
