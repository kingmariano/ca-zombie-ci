// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// Minimal Gnosis Safe v1.3.0 interface (canonical singleton 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552).
interface ISafe {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function VERSION() external view returns (string memory);
    function masterCopy() external view returns (address);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

/// H-24 ExinPool boundary tests — Ethereum "ETH 2.0 node" Safe.
///
/// ExinPool (Mixin bot 7000101761 / app c48136b1-c5ab-437a-a079-9df1dc748f1b) publishes this
/// address as its Ethereum node account (ExinOne/exinpoolsupport docs/Verify.md).
///
/// Purpose of these tests is to prove the *negative*: the only ExinPool-controlled EVM contract
/// (a canonical Gnosis Safe) is a 3-of-5 with no modules, no guard, and no external call path —
/// i.e. an unprivileged attacker cannot move its funds. These tests fork Ethereum mainnet
/// (read-only) and send no transactions.
contract ExinPoolSafeTest is Test {
    ISafe internal constant SAFE = ISafe(0xDFCE3CB1cbd896B96578005e14aDb81eC26DF923);
    address internal constant CANONICAL_SAFE_130 = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        string memory rpc = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(rpc);
    }

    /// Live config: canonical v1.3.0 singleton, 5 owners, threshold 3.
    function test_safe_configuration_3of5_canonical() public {
        address[] memory owners = SAFE.getOwners();
        assertEq(owners.length, 5, "expected 5 owners");
        assertEq(SAFE.getThreshold(), 3, "expected 3-of-5 threshold");
        assertEq(SAFE.masterCopy(), CANONICAL_SAFE_130, "canonical Safe v1.3.0 singleton");
        assertEq(SAFE.VERSION(), "1.3.0", "version");
        // print owners for the record
        for (uint256 i = 0; i < owners.length; i++) {
            emit log_named_address("owner", owners[i]);
        }
    }

    /// No modules are enabled -> no delegatecall extension can move funds.
    function test_no_modules_enabled() public view {
        (address[] memory mods, address next) = SAFE.getModulesPaginated(address(0x1), 10);
        assertEq(mods.length, 0, "no modules enabled");
        assertEq(next, address(0x1), "module list terminates at sentinel");
    }

    /// No guard is installed (guard storage slot == 0).
    function test_no_guard_installed() public view {
        bytes32 guardSlot = keccak256("guard_manager.guard.address");
        bytes32 g = vm.load(address(SAFE), guardSlot);
        assertEq(uint256(g), 0, "no guard");
    }

    /// The Safe's value is ETH only (no meaningful ERC20 residue that could be swept).
    function test_value_is_eth_only() public {
        emit log_named_uint("safe_eth_balance_wei", address(SAFE).balance);
        assertGt(address(SAFE).balance, 0, "safe holds ETH");
        assertEq(IERC20(USDT).balanceOf(address(SAFE)), 0, "no USDT");
        assertEq(IERC20(USDC).balanceOf(address(SAFE)), 0, "no USDC");
        // observed dust: 1e11 wei WETH (0.0000001) — not economically meaningful
        assertLt(IERC20(WETH).balanceOf(address(SAFE)), 1e12, "no meaningful WETH");
    }

    /// A well-formed ECDSA signature from a non-owner is rejected (GS026 path).
    function test_forged_non_owner_signature_reverts() public {
        uint256 pk = 0xA11CE;
        address attacker = vm.addr(pk);
        bytes32 txHash = SAFE.getTransactionHash(
            attacker, 1, "", 0, 0, 0, 0, address(0), address(0), SAFE.nonce()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory sigs = abi.encodePacked(r, s, v);

        vm.expectRevert(); // GS026 Invalid owner provided
        SAFE.execTransaction(attacker, 1, "", 0, 0, 0, 0, address(0), address(0), sigs);
    }

    /// Zero signatures revert (below threshold).
    function test_zero_signatures_reverts() public {
        vm.expectRevert(); // GS020: signatures length < threshold
        SAFE.execTransaction(address(this), 0, "", 0, 0, 0, 0, address(0), address(0), "");
    }

    /// A single forged signature (1 of the required 3) reverts even with valid ECDSA encoding.
    function test_single_signature_below_threshold_reverts() public {
        uint256 pk = 0xB0B;
        address attacker = vm.addr(pk);
        bytes32 txHash = SAFE.getTransactionHash(
            attacker, 0, "", 0, 0, 0, 0, address(0), address(0), SAFE.nonce()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, txHash);
        bytes memory sigs = abi.encodePacked(r, s, v);

        vm.expectRevert();
        SAFE.execTransaction(attacker, 0, "", 0, 0, 0, 0, address(0), address(0), sigs);
    }
}
