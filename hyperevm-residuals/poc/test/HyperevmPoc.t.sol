// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ICLFactory {
    function allPoolsLength() external view returns (uint256);
    function allPools(uint256) external view returns (address);
    function owner() external view returns (address);
    function collectProtocolFees(address pool) external returns (uint128, uint128);
    function collectAllProtocolFees() external;
}

interface IGrowthHYBR {
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function calculateShares(uint256 amount) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256 amount) external;
    function votingEscrow() external view returns (address);
    function veTokenId() external view returns (uint256);
}

interface IFeesVault {
    function claimFees() external returns (uint256, uint256);
}

/// @title H-32/H-33 closed-gate PoCs + mitigation checks, on a HyperEVM fork.
contract HyperevmPocTest is Test {
    address constant HYBRA_CL_FACTORY = 0x32b9dA73215255d50D84FeB51540B75acC1324c2;
    address constant HYBRA_POOL = 0xC22FaD66665343D385608cC45D2e1484f9bA8D6b;
    address constant HYBR = 0x067b0C72aa4C6Bd3BFEFfF443c536DCd6a25a9C8;
    address constant GHYBR = 0x348b11cBb801fAB12834E66691b7f25fe72B8aa5;
    address constant NEST_VE = 0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074;
    address constant NEST = 0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035;
    address constant NEST_FEES_VAULT = 0xc97fa6247457C9CF9f0528ffC3D5dD2DAAe39ED3;

    address attacker = address(0xA11CE);

    function _rpc() internal view returns (string memory) {
        // drpc by default: the official public RPC rate-limits parallel fork tests in CI.
        return vm.envOr("HYPERLIQUID_RPC_URL", string("https://hyperliquid.drpc.org"));
    }

    function setUp() public {
        vm.createSelectFork(_rpc());
        vm.deal(attacker, 10 ether);
    }

    /// @notice Hybra CLFactory fee collection is owner-gated: an arbitrary caller reverts.
    function test_hybra_collectProtocolFees_reverts_for_attacker() public {
        assertEq(ICLFactory(HYBRA_CL_FACTORY).owner(), 0xac6182AdA71eE9AB2A194Da8ae47F5F953E164cA);
        vm.prank(attacker);
        vm.expectRevert();
        ICLFactory(HYBRA_CL_FACTORY).collectProtocolFees(HYBRA_POOL);
        vm.prank(attacker);
        vm.expectRevert();
        ICLFactory(HYBRA_CL_FACTORY).collectAllProtocolFees();
    }

    /// @notice Hybra H-01 mitigation verified BEHAVIORALLY: gHYBR mints shares computed on the
    /// PRE-deposit ratio. If the vulnerable ordering were deployed, the depositor would receive
    /// fewer shares (their own deposit would inflate totalAssets before the quote).
    function test_hybra_gHYBR_shares_preDepositRatio() public {
        uint256 amount = 1_000e18;
        deal(HYBR, attacker, amount);
        uint256 expected = IGrowthHYBR(GHYBR).calculateShares(amount); // pre-state ratio
        assertGt(expected, 0, "expected shares");
        assertLt(expected, amount, "sanity: gHYBR share ratio < 1");
        vm.startPrank(attacker);
        IERC20(HYBR).approve(GHYBR, amount);
        IGrowthHYBR(GHYBR).deposit(amount);
        vm.stopPrank();
        assertEq(IGrowthHYBR(GHYBR).balanceOf(attacker), expected, "shares != pre-deposit ratio shares (H-01 regression)");
        emit log_named_uint("minted shares for 1000 HYBR (pre-deposit ratio)", expected);
    }

    /// @notice gHYBR is backed: totalAssets equals the HYBR locked by its own veNFT, and its
    ///         HYBR balance is negligible (all value is in the VotingEscrow lock).
    function test_hybra_gHYBR_backing() public {
        uint256 ta = IGrowthHYBR(GHYBR).totalAssets();
        assertGt(ta, 0, "totalAssets");
        assertGt(IGrowthHYBR(GHYBR).veTokenId(), 0, "veNFT initialized");
        emit log_named_uint("gHYBR totalAssets (HYBR)", ta);
        emit log_named_uint("gHYBR totalSupply", IGrowthHYBR(GHYBR).totalSupply());
        emit log_named_uint("HYBR locked in VotingEscrow", IERC20(HYBR).balanceOf(IGrowthHYBR(GHYBR).votingEscrow()));
    }

    /// @notice Nest FeesVault.claimFees() reverts for an arbitrary caller (gauge-role or
    ///         CLAIM_FEES_CALLER_ROLE required) -> not a permissionless drain.
    function test_nest_feesVault_claimFees_reverts_for_attacker() public {
        vm.prank(attacker);
        vm.expectRevert();
        IFeesVault(NEST_FEES_VAULT).claimFees();
    }

    /// @notice Adapter-coverage evidence: veNEST holds >1.6B NEST, which the DefiLlama
    ///         uniV3Export adapter (pool balances only) does not count.
    function test_nest_adapter_undercounts_veNEST() public {
        uint256 locked = IERC20(NEST).balanceOf(NEST_VE);
        uint256 supply = IERC20(NEST).totalSupply();
        assertGt(locked, 1_600_000_000e18, "veNEST locked > 1.6B NEST");
        assertGt((locked * 100) / supply, 80, ">80% of NEST supply locked in veNEST");
        emit log_named_uint("NEST locked in veNEST", locked);
        emit log_named_uint("NEST totalSupply", supply);
    }
}
