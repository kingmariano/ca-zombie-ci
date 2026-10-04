// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title H-39 / H-40 Harmony orphan contracts — live-state and boundary tests (fork only)
/// @notice Read-only research: every test runs on a fork of Harmony mainnet (chainid 1666600000).
///         No mainnet transactions are ever sent. Assertions pin the exact live state observed
///         2026-10-04 (block ~93,624,315) so drift is loud, not silent.

interface INativeOFT {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function circulatingSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function owner() external view returns (address);
    function trustedRemoteLookup(uint16) external view returns (bytes memory);
    function useCustomAdapterParams() external view returns (bool);
    function deposit() external payable;
    function withdraw(uint256) external;
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _srcAddress) external;
    function isTrustedRemote(uint16, bytes calldata) external view returns (bool);
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function VERSION() external view returns (string memory);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory array, address next);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

contract HarmonyOrphansTest is Test {
    // ---- targets (Harmony mainnet, chainid 1666600000) ----
    address constant OFT_BSC = 0x5B18a4E73F9A4fe337A072516b317863Ad3046aA; // "ONE for BSC"
    address constant OFT_ETH = 0x905582f21fB9855c809d5b8933272a292dfbB138; // "ONE for Ethereum"
    address constant LZ_ENDPOINT = 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4;
    address constant OFT_OWNER = 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C; // single EOA owner of both OFTs

    address constant SAFE_A = 0x85049A5abed20A50d587C113F1Ef03d0Fd796453;
    address constant SAFE_B = 0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80;
    address constant SAFE_C = 0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf;
    address constant SAFE_D = 0x59f93F30fc4B1429E2016DB36346299d80927690;

    address constant SAFE_SINGLETON = 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA;
    address constant SAFE_FALLBACK_HANDLER = 0x017062a1dE2FE6b99BE3d9d37841FeD19F573804;

    // canonical bytecode hashes (verified against Ethereum mainnet deployments, 2026-10-04)
    bytes32 constant CANON_SAFEL2_CODEHASH = 0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f;
    bytes32 constant CANON_SAFEPROXY_CODEHASH = 0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000;
    bytes32 constant CANON_FBH_CODEHASH = 0x03e69f7ce809e81687c69b19a7d7cca45b6d551ffdec73d9bb87178476de1abf;

    // Safe v1.3.0 custom storage slots (keccak256("guard_manager.guard.address") / keccak256("fallback_manager.handler.address"))
    bytes32 constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 constant FBH_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    // exact live balances captured 2026-10-04 (wei)
    uint256 constant OFT_BSC_BAL = 62531259468551870330371539;
    uint256 constant OFT_ETH_BAL = 13101396431214960428021286;
    uint256 constant SAFE_A_BAL = 42654070000000000000000000;
    uint256 constant SAFE_B_BAL = 40421863773437000000000000;
    uint256 constant SAFE_C_BAL = 30990103000000000000000000;
    uint256 constant SAFE_D_BAL = 24000105000000000000000000;

    address internal attacker = 0x1111111111111111111111111111111111111111;

    function setUp() public {
        string memory rpc = vm.envOr("HARMONY_RPC_URL", string("https://api.harmony.one"));
        vm.createSelectFork(rpc);
        emit log_named_uint("fork block", block.number);
    }

    // ---------------------------------------------------------------- H-39

    function test_H39_live_state_one_for_bsc() public {
        INativeOFT oft = INativeOFT(OFT_BSC);
        assertEq(OFT_BSC.balance, OFT_BSC_BAL, "native balance drift");
        assertEq(oft.totalSupply(), OFT_BSC_BAL, "totalSupply != native balance");
        assertEq(oft.balanceOf(OFT_BSC), oft.totalSupply(), "contract does not hold all internal supply");
        assertEq(oft.circulatingSupply(), oft.totalSupply(), "circulatingSupply != totalSupply");
        assertEq(oft.owner(), OFT_OWNER, "owner drift");
        assertEq(oft.trustedRemoteLookup(101).length, 0, "trusted remote ETH set");
        assertEq(oft.trustedRemoteLookup(102).length, 0, "trusted remote BSC set");
        assertTrue(oft.useCustomAdapterParams(), "useCustomAdapterParams false");
        assertEq(keccak256(bytes(oft.name())), keccak256("ONE for BSC"), "name drift");
        emit log_named_uint("OFT_BSC balance", OFT_BSC.balance);
    }

    function test_H39_live_state_one_for_ethereum() public {
        INativeOFT oft = INativeOFT(OFT_ETH);
        assertEq(OFT_ETH.balance, OFT_ETH_BAL, "native balance drift");
        assertEq(oft.totalSupply(), OFT_ETH_BAL, "totalSupply != native balance");
        assertEq(oft.balanceOf(OFT_ETH), oft.totalSupply(), "contract does not hold all internal supply");
        assertEq(oft.owner(), OFT_OWNER, "owner drift");
        assertEq(oft.trustedRemoteLookup(101).length, 0, "trusted remote ETH set");
        assertEq(oft.trustedRemoteLookup(102).length, 0, "trusted remote BSC set");
        assertEq(keccak256(bytes(oft.name())), keccak256("ONE for Ethereum"), "name drift");
    }

    function test_H39_withdraw_is_holder_only() public {
        vm.prank(attacker);
        vm.expectRevert("NativeOFT: Insufficient balance.");
        INativeOFT(OFT_BSC).withdraw(1 ether);
    }

    function test_H39_lzReceive_non_endpoint_reverts() public {
        vm.prank(attacker);
        vm.expectRevert("LzApp: invalid endpoint caller");
        INativeOFT(OFT_BSC).lzReceive(102, abi.encodePacked(attacker, OFT_BSC), 1, "");
    }

    /// Even if the genuine LayerZero endpoint delivers a message, the OFT rejects it because
    /// the trusted remote was cleared on 2026-08-30 (setTrustedRemote(102, 0x) / (101, 0x)).
    function test_H39_lzReceive_real_endpoint_empty_trusted_remote_reverts() public {
        vm.prank(LZ_ENDPOINT);
        vm.expectRevert("LzApp: invalid source sending contract");
        INativeOFT(OFT_BSC).lzReceive(102, abi.encodePacked(attacker, OFT_BSC), 1, "");
    }

    /// The contract itself holds 100% of internal supply (locked escrow for outbound bridges).
    /// An outsider cannot move it: sendFrom(_from = OFT) requires an allowance the OFT never gave.
    function test_H39_locked_escrow_not_movable_by_outsider() public {
        vm.deal(attacker, 10 ether);
        vm.prank(attacker);
        vm.expectRevert("ERC20: insufficient allowance");
        INativeOFT(OFT_BSC).sendFrom{value: 1 ether}(
            OFT_BSC, 102, abi.encodePacked(attacker), 1 ether, payable(attacker), address(0), hex"0001000000000000000000000000000000000000000000000000000000000007a120"
        );
    }

    function test_H39_owner_functions_not_callable() public {
        vm.prank(attacker);
        vm.expectRevert("Ownable: caller is not the owner");
        INativeOFT(OFT_BSC).setTrustedRemote(102, abi.encodePacked(attacker, OFT_BSC));
    }

    function test_H39_historical_users_have_zero_internal_balance() public {
        INativeOFT oft = INativeOFT(OFT_BSC);
        assertEq(oft.balanceOf(0x047b5d324BA481a3025e60Ce4910758cCF582559), 0, "user1 balance");
        assertEq(oft.balanceOf(0x78C663566235C0a4aeC24D7FeB0b5d8024C70932), 0, "user2 balance");
        assertEq(oft.balanceOf(0x1F84833dCb4e7421Fe691Cb64369580C1e48b287), 0, "user3 balance");
        assertEq(oft.balanceOf(attacker), 0, "attacker balance");
    }

    /// Holder self-service path works mechanically (deposit -> withdraw), proving the escrow can
    /// pay out; it is only reachable with an internal balance, which no current holder has.
    function test_H39_deposit_withdraw_roundtrip_holder_path() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 10 ether);
        INativeOFT oft = INativeOFT(OFT_BSC);
        uint256 aliceBefore = alice.balance;
        uint256 contractBefore = OFT_BSC.balance;

        vm.prank(alice);
        oft.deposit{value: 2 ether}();
        assertEq(oft.balanceOf(alice), 2 ether, "deposit did not mint internal balance");
        assertEq(OFT_BSC.balance, contractBefore + 2 ether, "deposit did not back balance with native");
        assertEq(alice.balance, aliceBefore - 2 ether, "deposit did not spend alice native");

        vm.prank(alice);
        oft.withdraw(2 ether);
        assertEq(oft.balanceOf(alice), 0, "withdraw did not burn internal balance");
        assertEq(alice.balance, aliceBefore, "withdraw did not return native ONE");
        assertEq(OFT_BSC.balance, contractBefore, "contract balance not restored after roundtrip");
    }

    // ---------------------------------------------------------------- H-40

    function test_H40_safe_state_and_canonical_code() public {
        _assertSafe(SAFE_A, SAFE_A_BAL, 3, 13);
        _assertSafe(SAFE_B, SAFE_B_BAL, 2, 249);
        _assertSafe(SAFE_C, SAFE_C_BAL, 3, 11);
        _assertSafe(SAFE_D, SAFE_D_BAL, 3, 8);
        assertEq(keccak256(SAFE_SINGLETON.code), CANON_SAFEL2_CODEHASH, "singleton not canonical SafeL2 1.3.0");
        assertEq(keccak256(SAFE_FALLBACK_HANDLER.code), CANON_FBH_CODEHASH, "fallback handler not canonical");
    }

    function test_H40_execTransaction_requires_signatures() public {
        vm.prank(attacker);
        vm.expectRevert("GS020");
        ISafe(SAFE_A).execTransaction(
            attacker, 1 ether, "", 0, 0, 0, 0, address(0), payable(address(0)), ""
        );
    }

    function _assertSafe(address safe, uint256 bal, uint256 threshold, uint256 nonce_) internal {
        assertEq(safe.balance, bal, "safe balance drift");
        ISafe s = ISafe(safe);
        assertEq(s.getThreshold(), threshold, "threshold drift");
        assertEq(s.nonce(), nonce_, "nonce drift");
        assertEq(keccak256(bytes(s.VERSION())), keccak256("1.3.0"), "safe version drift");
        (address[] memory modules,) = s.getModulesPaginated(address(1), 100);
        assertEq(modules.length, 0, "modules not empty");
        assertEq(address(uint160(uint256(vm.load(safe, GUARD_SLOT)))), address(0), "guard set");
        assertEq(
            address(uint160(uint256(vm.load(safe, FBH_SLOT)))),
            SAFE_FALLBACK_HANDLER,
            "fallback handler drift"
        );
        assertEq(keccak256(safe.code), CANON_SAFEPROXY_CODEHASH, "proxy not canonical SafeProxy");
        emit log_named_uint("safe checked", uint160(safe));
    }
}
