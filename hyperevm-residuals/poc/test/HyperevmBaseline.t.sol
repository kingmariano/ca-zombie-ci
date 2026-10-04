// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface ICLFactory {
    function allPoolsLength() external view returns (uint256);
    function allPools(uint256) external view returns (address);
    function owner() external view returns (address);
    function gaugeManager() external view returns (address);
}

interface IVotingEscrow {
    function totalSupply() external view returns (uint256);
    function owner() external view returns (address);
}

interface IPairFactory {
    function allPairsLength() external view returns (uint256);
}

/// @title Baseline fork test: proves HyperEVM (chainid 999) forking works and pins core live state.
contract HyperevmBaselineTest is Test {
    // Nest
    address constant NEST = 0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035;
    address constant VENEST = 0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074;
    address constant NEST_ALGEBRA_FACTORY = 0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3;
    address constant NEST_PAIR_FACTORY = 0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5;
    // Hybra
    address constant HYBRA_CL_FACTORY = 0x32b9dA73215255d50D84FeB51540B75acC1324c2;
    address constant HYBR = 0x067b0C72aa4C6Bd3BFEFfF443c536DCd6a25a9C8;

    function _rpc() internal view returns (string memory) {
        // drpc by default: the official public RPC rate-limits parallel fork tests in CI.
        return vm.envOr("HYPERLIQUID_RPC_URL", string("https://hyperliquid.drpc.org"));
    }

    function setUp() public {
        vm.createSelectFork(_rpc());
    }

    function test_fork_chainid_and_core_state() public {
        assertEq(block.chainid, 999, "chainid must be 999 (HyperEVM)");
        uint256 bn = block.number;
        emit log_named_uint("fork block", bn);

        // --- Nest ---
        uint256 nestSupply = IERC20(NEST).totalSupply();
        assertGt(nestSupply, 0, "NEST supply");
        emit log_named_uint("NEST totalSupply", nestSupply);
        emit log_named_string("NEST symbol", IERC20(NEST).symbol());

        uint256 veLocked = IERC20(NEST).balanceOf(VENEST);
        assertGt(veLocked, 0, "NEST locked in veNEST");
        emit log_named_uint("NEST locked in veNEST", veLocked);
        emit log_named_uint("veNEST totalSupply (veNFT count)", IVotingEscrow(VENEST).totalSupply());

        uint256 pairs = IPairFactory(NEST_PAIR_FACTORY).allPairsLength();
        emit log_named_uint("Nest V2 allPairsLength", pairs);
        assertEq(pairs, 3, "3 V2 pairs at measurement time");

        // Algebra CL factory live + owner
        emit log_named_address("Nest Algebra factory owner", ICLFactory(NEST_ALGEBRA_FACTORY).owner());

        // --- Hybra ---
        uint256 hybraPools = ICLFactory(HYBRA_CL_FACTORY).allPoolsLength();
        assertGt(hybraPools, 100, "Hybra CL pools");
        emit log_named_uint("Hybra CL allPoolsLength", hybraPools);
        emit log_named_address("Hybra CLFactory owner", ICLFactory(HYBRA_CL_FACTORY).owner());
        emit log_named_address("Hybra gaugeManager", ICLFactory(HYBRA_CL_FACTORY).gaugeManager());

        uint256 hybrSupply = IERC20(HYBR).totalSupply();
        assertGt(hybrSupply, 0, "HYBR supply");
        emit log_named_uint("HYBR totalSupply", hybrSupply);
    }

    /// @notice Reads the balance of the largest measured Hybra pool (HYBR/WHYPE) for pinning.
    function test_hybra_largest_pool_pinned() public {
        address pool = 0x006418DcD73f6Da03A667ad161cCB9B39CeEEa60;
        (bool ok, bytes memory data) = pool.staticcall(abi.encodeWithSignature("token0()"));
        assertTrue(ok, "pool token0");
        address t0 = abi.decode(data, (address));
        emit log_named_address("pool token0", t0);
        emit log_named_uint("HYBR balance of largest pool", IERC20(HYBR).balanceOf(pool));
    }
}
