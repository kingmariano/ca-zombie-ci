// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title XrplEvmGatesTest
/// @notice Read-only fork tests against XRPL EVM mainnet (chain id 1440000).
///
///         SCOPE / LIMITATION — read this before trusting the suite:
///         a vanilla anvil fork replays *state* (accounts, code, balances) but
///         does NOT emulate cosmos/evm custom precompiles. On the fork, every
///         address in 0x100/0x400/0x800..0x806 behaves as an empty account —
///         including the precompiles that ARE active on the live chain
///         (0x400 bech32, 0x804 bank, 0x805 gov). Therefore this suite can NOT
///         prove precompile (in)activity. That proof is made against the live
///         RPC in analysis/verify_live.py (ci/run.sh), which probes each
///         address with eth_call and records the responses.
///
///         What this suite does prove on a real fork snapshot:
///           - the fork is XRPL EVM mainnet and the chain is live;
///           - no contract code is deployed at the precompile addresses
///             (state-level fact, true for all precompiles);
///           - the harness limitation above is real (documented test).
///
///         No transaction is signed or broadcast: anvil forks the public RPC.
///         The fork is selected from XRPL_EVM_RPC (default: https://rpc.xrplevm.org).
import {Test} from "forge-std/Test.sol";

contract XrplEvmGatesTest is Test {
    uint256 internal constant XRPL_EVM_CHAIN_ID = 1440000;

    // Address map from xrplevm/evm v0.6.3-xrplevm.1 x/vm/types/precompiles.go
    address internal constant P256 = 0x0000000000000000000000000000000000000100;
    address internal constant BECH32 = 0x0000000000000000000000000000000000000400;
    address internal constant STAKING = 0x0000000000000000000000000000000000000800;
    address internal constant DISTRIBUTION = 0x0000000000000000000000000000000000000801;
    address internal constant ICS20 = 0x0000000000000000000000000000000000000802;
    address internal constant VESTING = 0x0000000000000000000000000000000000000803;
    address internal constant BANK = 0x0000000000000000000000000000000000000804;
    address internal constant GOV = 0x0000000000000000000000000000000000000805;
    address internal constant SLASHING = 0x0000000000000000000000000000000000000806;

    function setUp() public {
        string memory rpc = vm.envOr("XRPL_EVM_RPC", string("https://rpc.xrplevm.org"));
        vm.createSelectFork(rpc);
    }

    /// Chain identity and liveness (fork snapshot must be a live mainnet block).
    function test_chainIdAndLiveness() public view {
        assertEq(block.chainid, XRPL_EVM_CHAIN_ID, "not XRPL EVM mainnet");
        assertGt(block.number, 7_900_000, "fork block unexpectedly old");
    }

    /// Precompiles are not deployed contracts: eth_getCode is empty even for
    /// the active ones. Recorded so the absence argument never rests on code.
    function test_precompileAddressesHaveNoCode() public view {
        address[9] memory addrs = [P256, BECH32, STAKING, DISTRIBUTION, ICS20,
                                   VESTING, BANK, GOV, SLASHING];
        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(addrs[i].code.length, 0, "precompile address unexpectedly has code");
        }
    }

    /// Documents the harness limitation: anvil returns success + empty data for
    /// BOTH the absent staking precompile (0x800) and the live-active bank
    /// precompile (0x804). This test would fail on a harness that emulates
    /// cosmos/evm precompiles (0x804 would revert with 'no method with id'),
    /// which is exactly why the authoritative callability probe runs against
    /// the live RPC instead of a fork.
    function test_forkHarnessDoesNotEmulateCosmosPrecompiles() public view {
        (bool ok800, bytes memory d800) = STAKING.staticcall(hex"0d0e0e5a");
        (bool ok804, bytes memory d804) = BANK.staticcall(hex"0d0e0e5a");
        assertTrue(ok800, "anvil: empty-account call succeeds");
        assertTrue(ok804, "anvil: active precompile is NOT emulated (expected)");
        assertEq(d800.length, 0);
        assertEq(d804.length, 0);
    }

    /// On XRPL EVM the native denom marker 0xeeee... is NOT a pseudo-address:
    /// the x/erc20 module has deployed a real wrapper contract there (registered
    /// token pair for denom "axrp", owner OWNER_MODULE). Recorded as a state
    /// fact; it is not part of the exploit path (no permissionless registration,
    /// v0.6.3 atomic-commit fix deployed).
    function test_nativeDenomMarkerHasWrapperCode() public view {
        assertGt(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE).code.length, 0,
            "expected the x/erc20 native wrapper to be deployed");
    }
}
