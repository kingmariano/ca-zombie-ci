// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {Hord, IERC20, IHordStakingManager, IHordWithdrawalManager, IEigenPod} from "../src/Hord.sol";

/// @title Hord (hETH) zombie assessment — fork PoC (read-only; no mainnet txs)
/// @notice Pins Ethereum mainnet block 26,170,355 (2026-10-11). Proves:
///         1. live state: all 101 beacon validators fully withdrawn, hETH paused, WM holds 12.695 ETH for 16 pending users;
///         2. every user-facing path is blocked by the pause;
///         3. every ETH-moving path is privileged (Congress / Maintainer);
///         4. even with the pause removed (only governance can do that), an unprivileged attacker extracts $0.
contract HordZombieTest is Test {
    struct Cluster {
        uint64 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    uint256 internal forkBlock;
    address internal attacker = address(0xA11CE);
    address internal attacker2 = address(0xB0B);

    // Canonical live values @ block 26,170,355
    uint256 constant SUPPLY = 281323492796481011183;
    uint256 constant WM_ETH = 12695109442239980950; // 12.695109442239980950
    uint256 constant SM_ETH = 53653161919910392; // 0.053653161919910392
    uint256 constant POD_ETH = 202938912; // 0.202938912
    uint256 constant POOL_HETH = 6319657972804532535;
    uint256 constant PENDING_USER_CLAIM = 12461378180425370983; // 0x7ff0ba5f...

    function setUp() public {
        // Canonical snapshot block is 26,170,355 (2026-10-11); the protocol state is frozen
        // (paused, no validators), so the default fork is "latest" for RPC robustness. The
        // pinned block is exercised by ci/run.sh when the archive RPC allows it.
        forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        string memory url = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        if (forkBlock == 0) {
            vm.createSelectFork(url);
            forkBlock = block.number;
        } else {
            vm.createSelectFork(url, forkBlock);
        }
        vm.deal(attacker, 1 ether);
    }

    // ---------------------------------------------------------------- live state
    function test_live_state() public {
        // hETH token / staking manager
        assertEq(IERC20(Hord.HETH).totalSupply(), SUPPLY, "hETH supply");
        assertTrue(IHordStakingManager(Hord.HETH).paused(), "SM paused");
        assertEq(Hord.HETH.balance, SM_ETH, "SM ETH balance");
        assertEq(IHordStakingManager(Hord.HETH).totalBalanceETHInValidators(), 0, "recorded validator ETH = 0");

        // Withdrawal manager: 12.695 ETH == assuredClaimsBalance (owed to pending users)
        assertTrue(IHordWithdrawalManager(Hord.WM).paused(), "WM paused");
        assertEq(Hord.WM.balance, WM_ETH, "WM ETH balance");
        assertEq(IHordWithdrawalManager(Hord.WM).assuredClaimsBalance(), WM_ETH, "assuredClaimsBalance");
        assertEq(IHordWithdrawalManager(Hord.WM).unAllocatedBuffer(), 0, "buffer");
        assertEq(IHordWithdrawalManager(Hord.WM).totalPendingDebt(), 0, "pending debt");
        assertEq(IHordWithdrawalManager(Hord.WM).withdrawalDebtsLength(), 0, "debts array");

        // Two known pending requests (16 in total): whale + largest claim
        (, , , uint256 whaleETH, , , , uint256 whaleFin, , ) =
            IHordWithdrawalManager(Hord.WM).usersWithdrawals(0x456cb202015E8D64B3Bd8E14fCf2Dd63720ae7AF);
        assertEq(whaleETH, 132914799513178, "whale claim");
        assertEq(whaleFin, 0, "whale not finalized");
        (, , , uint256 bigETH, uint256 bigDebt, , , uint256 bigFin, , ) =
            IHordWithdrawalManager(Hord.WM).usersWithdrawals(0x7ff0Ba5F2225450d4C6Bb655f7Ab88AeAc2856eC);
        assertEq(bigETH, PENDING_USER_CLAIM, "largest pending claim");
        assertEq(bigDebt, 0, "largest claim funded");
        assertEq(bigFin, 0, "largest claim not finalized");

        // Other Hord custody
        assertEq(Hord.POD.balance, POD_ETH, "EigenPod ETH");
        assertEq(Hord.RESTAKING_MGR.balance, 0, "restaking mgr ETH");
        assertEq(IERC20(Hord.HETH).balanceOf(Hord.HETH_WETH_POOL), POOL_HETH, "uni pool hETH");

        // Proxy wiring: Congress owns the ProxyAdmin of hETH; impls as recorded
        assertEq(_proxyAdminOwner(Hord.PROXY_ADMIN), Hord.CONGRESS, "proxy admin owner");
        assertEq(_implOf(Hord.HETH), Hord.HETH_IMPL, "hETH impl");
        assertEq(_implOf(Hord.WM), Hord.WM_IMPL, "WM impl");

        // The contract's own view of hETH value: ~8982 hETH per ETH
        uint256 ratio = IHordStakingManager(Hord.HETH).getAmountOfHETHforETH(1e18, false, 0);
        emit log_named_uint("getAmountOfHETHforETH(1e18) (hETH per ETH)", ratio);
        assertGt(ratio, 8000e18, "ratio broken >8000");
    }

    // --------------------------------------------------- attacker blocked by pause
    function test_attacker_paths_paused() public {
        vm.startPrank(attacker, attacker);
        vm.expectRevert("Pausable: paused");
        IERC20(Hord.HETH).transfer(attacker2, 1);

        // approve() is not pause-gated but is useless while transfers are frozen
        IERC20(Hord.HETH).approve(attacker2, 1);

        vm.expectRevert("Pausable: paused");
        IHordWithdrawalManager(Hord.WM).requestWithdraw(1e18);

        vm.expectRevert("Pausable: paused");
        IHordWithdrawalManager(Hord.WM).withdraw();

        vm.expectRevert("Pausable: paused");
        IHordStakingManager(Hord.HETH).userDepositETH{value: 0.001 ether}();

        vm.expectRevert("Pausable: paused");
        IHordStakingManager(Hord.HETH).burn(attacker, 1);

        // Feb-2026 SSV wrapper (0xf4f4b531) — whenNotPaused fires first
        vm.expectRevert("Pausable: paused");
        _callSsvWrapper();
        vm.stopPrank();
    }

    // --------------------------------------------- privileged gates while paused
    function test_privileged_gates() public {
        vm.startPrank(attacker, attacker);

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordWithdrawalManager(Hord.WM).transferETHtoFinance();

        vm.expectRevert("Hord: Restricted only to HordCongress");
        IHordWithdrawalManager(Hord.WM).unpause();

        vm.expectRevert("Hord: Restricted only to HordCongress");
        IHordWithdrawalManager(Hord.WM).correctWithdrawalRequests();

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordWithdrawalManager(Hord.WM).withdrawOrganizationFunds(1);

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordWithdrawalManager(Hord.WM).payOfDebtFromOrganization(1, 0, 0);

        // Feb-2026 congress-only ETH rescue (0xef300f40) — no pause gate
        vm.expectRevert("Hord: Restricted only to HordCongress");
        (bool ok,) = Hord.HETH.call(abi.encodeWithSelector(Hord.SEL_TRANSFER_ETH, attacker, 1));
        ok;

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordStakingManager(Hord.HETH).appropriateReservesToPayDebt(1, 0, 0);

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordStakingManager(Hord.HETH).mintProtocolFees();

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordStakingManager(Hord.HETH).setValidatorStats(0, 0, 0);

        vm.stopPrank();
    }

    // ----------------------- unpause simulation: attacker still extracts nothing
    function test_unpaused_simulation_no_extraction() public {
        // Only Congress can unpause; simulate that governance action on the fork.
        vm.store(Hord.HETH, bytes32(uint256(0x65)), 0);
        vm.store(Hord.WM, bytes32(uint256(0x65)), 0);
        assertFalse(IHordStakingManager(Hord.HETH).paused());
        assertFalse(IHordWithdrawalManager(Hord.WM).paused());

        uint256 wmBefore = Hord.WM.balance;

        vm.startPrank(attacker, attacker);

        // No claim -> no payment
        vm.expectRevert("user didnt make withdrawal request");
        IHordWithdrawalManager(Hord.WM).withdraw();

        // Cannot create a claim without hETH
        vm.expectRevert("User wants to withdraw more than he has.");
        IHordWithdrawalManager(Hord.WM).requestWithdraw(1);

        // Deposits still work when unpaused, but mint at the same (broken) ratio used by
        // redemptions (~8982 hETH per ETH): value-neutral, no profit.
        uint256 balBefore = attacker.balance;
        vm.stopPrank();
        vm.prank(attacker, attacker);
        IHordStakingManager(Hord.HETH).userDepositETH{value: 0.01 ether}();
        uint256 minted = IERC20(Hord.HETH).balanceOf(attacker);
        uint256 ratio = IHordStakingManager(Hord.HETH).getAmountOfHETHforETH(1e18, false, 0);
        uint256 mintedValue = minted * 1e18 / ratio; // ETH value of minted hETH at contract rate
        assertApproxEqRel(mintedValue, 0.01 ether, 0.02e18, "deposit value-neutral");
        assertEq(attacker.balance, balBefore - 0.01 ether, "attacker only paid deposit");
        emit log_named_uint("minted hETH for 0.01 ETH", minted);
        emit log_named_uint("ETH value of minted hETH", mintedValue);
        vm.startPrank(attacker, attacker);

        // Direct ETH rescue paths remain privileged
        vm.expectRevert("Hord: Restricted only to HordCongress");
        (bool ok,) = Hord.HETH.call(abi.encodeWithSelector(Hord.SEL_TRANSFER_ETH, attacker, Hord.HETH.balance));
        ok;

        vm.expectRevert("Hord: Restricted only to Maintainer");
        _callSsvWrapper();

        vm.expectRevert("Hord: Restricted only to Maintainer");
        IHordWithdrawalManager(Hord.WM).transferETHtoFinance();

        vm.stopPrank();

        assertEq(attacker.balance, balBefore - 0.01 ether, "attacker balance unchanged (net of value-neutral deposit)");
        assertEq(Hord.WM.balance, wmBefore, "WM balance unchanged");

        // Governance path (P): a maintainer can sweep the WM's 12.695 ETH to financeAddress
        // (requires the contract to be paused again — governance controls both flags).
        vm.store(Hord.WM, bytes32(uint256(0x65)), bytes32(uint256(1)));
        uint256 finBefore = Hord.FINANCE.balance;
        vm.prank(Hord.MAINTAINER_1, Hord.MAINTAINER_1);
        IHordWithdrawalManager(Hord.WM).transferETHtoFinance();
        assertEq(Hord.WM.balance, 0, "WM swept");
        assertEq(Hord.FINANCE.balance, finBefore + wmBefore, "finance received WM ETH");
    }

    // ------------------------------------------------------------------ helpers
    function _callSsvWrapper() internal {
        bytes memory cd = abi.encodeWithSelector(Hord.SEL_SSV_WITHDRAW, new uint64[](0), uint256(0), Cluster(0, 0, 0, false, 0));
        (bool ok,) = Hord.HETH.call(cd);
        ok;
    }

    function _implOf(address proxy) internal view returns (address impl) {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        impl = address(uint160(uint256(vm.load(proxy, slot))));
    }

    function _proxyAdminOwner(address admin) internal view returns (address) {
        (bool ok, bytes memory ret) = admin.staticcall(abi.encodeWithSignature("owner()"));
        require(ok, "owner() failed");
        return abi.decode(ret, (address));
    }
}
