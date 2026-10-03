// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/* ============ Minimal interfaces (live Polygon contracts) ============ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface ISphereToken is IERC20 {
    function owner() external view returns (address);
    function rescueToken(address) external;
    function clearStuckBalance(address) external;
    function totalSupply() external view returns (uint256);
    function settings() external view returns (address);
}

interface ISphereTokenV1 is IERC20 {
    function owner() external view returns (address);
    function rescueToken(address, uint256) external;
    function clearStuckBalance(address) external;
    function manualSwapBack() external;
    function manualRebase() external;
}

interface IylSphere {
    struct LockedBalance { uint112 amount; uint32 unlockTime; }
    struct EarnedData { address token; uint256 amount; }
    function owner() external view returns (address);
    function lockedSupply() external view returns (uint256);
    function kickRewardPerEpoch() external view returns (uint256);
    function kickRewardEpochDelay() external view returns (uint256);
    function isShutdown() external view returns (bool);
    function stakingToken() external view returns (address);
    function lockedBalances(address) external view returns (uint256, uint256, uint256, LockedBalance[] memory);
    function userLocksLen(address) external view returns (uint256);
    function userLocks(address, uint256) external view returns (uint112, uint32);
    function balances(address) external view returns (uint112, uint32);
    function claimableRewards(address) external view returns (EarnedData[] memory);
    function kickExpiredLocks(address) external;
    function processExpiredLocks(bool) external;
    function getReward(address) external;
    function recoverERC20(address, uint256) external;
    function lock(address, uint256) external;
    function rewardTokensList() external view returns (address[] memory);
}

interface IBondDepo {
    function owner() external view returns (address);
    function rewardToken() external view returns (address);
    function principle() external view returns (address);
    function treasury() external view returns (address);
    function availableDebt() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function deposit(uint256, uint256, address) external returns (uint256);
    function redeem(address) external returns (uint256);
    function pendingPayoutFor(address) external view returns (uint256);
    function recoverLostToken(address, uint256) external;
    function bondPrice() external view returns (uint256);
    function payoutFor(uint256) external view returns (uint256);
    function valueOfToken(uint256) external view returns (uint256);
}

interface ISphereFairLaunch {
    function owner() external view returns (address);
    function saleEnabled() external view returns (bool);
    function redeemEnabled() external view returns (bool);
    function claimRedeemable() external;
    function approveWithdraw() external;
    function invest(uint256) external;
}

interface IFairLaunchPool {
    function owner() external view returns (address);
    function redeemEnabled() external view returns (bool);
    function redeem() external;
    function invest(uint256) external;
}

interface ITimelock {
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32, address) external view returns (bool);
    function schedule(address, uint256, bytes calldata, bytes32, bytes32, uint256) external;
    function execute(address, uint256, bytes calldata, bytes32, bytes32) external payable;
    function PROPOSER_ROLE() external view returns (bytes32);
    function EXECUTOR_ROLE() external view returns (bytes32);
}

interface IProxyAdmin {
    function owner() external view returns (address);
    function upgrade(address, address) external;
}

interface IBondSwapper {
    function owner() external view returns (address);
    function swapBack() external;
    function withdrawToken(address) external;
    function withdrawNativeToken() external;
    function liquidityReceiver() external view returns (address);
}

interface IOvernightStrategy {
    function owner() external view returns (address);
    function swapBack() external;
    function withdrawToken(address) external;
    function fundsReceiver() external view returns (address);
}

interface ISphereTreasury {
    function owner() external view returns (address);
    function retrieveTokens(address, uint256) external;
    function claimTokens(address, uint256, address) external;
    function retrieveMATIC(uint256) external;
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function execTransaction(address, uint256, bytes calldata, uint8, uint256, uint256, uint256,
        address, address, bytes calldata) external returns (bool);
}

contract SphereFinanceTest is Test {
    /* ============ live addresses (Polygon mainnet) ============ */
    address constant SPHERE   = 0x62F594339830b90AE4C084aE7D223fFAFd9658A7;
    address constant SPHERE_V1= 0x8D546026012bF75073d8A586f24A5d5ff75b9716;
    address constant YLSPHERE = 0x4Af613f297ab00361D516454E5E46bc895889653;
    address constant BONDDEPO = 0xd7Dc984Cf5F799D5AF4e3A56c2635e5379623fD6;
    address constant BONDSWAP = 0xb61Bd49A1C5258A3Ca00A9A7B4df823CBF057891;
    address constant OVERNIGHT= 0x2d980268f7A3366F6fa0C36982c597359e358615;
    address constant TREASURY = 0xC747dB6EBD5DFC93c7D2f4aF208A9618beec46A3;
    address constant TIMELOCK = 0xA0dccb94bC35576Ab9820c2DDa9d6fc0042d6d72;
    address constant SPHERE_PROXYADMIN = 0xF27522d4A48B9A5fE53F69E343B15926b540f0aB;
    address constant SPHERE_SETTINGS = 0xC49be67AAa0a2476E5132AD77216521971643857;
    address constant SPHEREFAIRLAUNCH = 0x7E96BbeB1C13978f7fE5C50Ae1e332148Bb14277;
    address constant FAIRLAUNCH1 = 0x1712412a7C4556BfB5FfEE753b112960df6348f3;
    address constant INV_TREASURY_SAFE = 0x20D61737f972EEcB0aF5f0a85ab358Cd083Dd56a;
    address constant LP_TREASURY_SAFE  = 0x1a2Ce410A034424B784D4b228f167A061B94CFf4;
    address constant RFV_TREASURY_SAFE = 0x826b8d2d523E7af40888754E3De64348C00B99f4;
    address constant USDC_E = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // user with expired, unprocessed ylSPHERE locks (2023-2025 locks, all expired)
    address constant EXPIRED_LOCK_USER = 0x42dcc796fF5B5d8D11928448a3eb62127b52BF5D;
    // user whose remaining locks are still unexpired (control)
    address constant UNEXPIRED_LOCK_USER = 0x4CC431744644FBd9D4E63789284B77a50f79e5d1;

    address attacker = address(0xA11CE);

    function setUp() public {
        // NOTE: CI's FORK_RPC_URL is an *Ethereum* RPC — never use it for Polygon.
        string memory rpc = vm.envOr("POLYGON_RPC_URL", string("https://polygon-bor-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        vm.deal(attacker, 100 ether);
    }

    /* ------------------------------------------------------------------ */
    /* POSITIVE: permissionless kick of expired ylSPHERE locks pays caller */
    /* ------------------------------------------------------------------ */
    function test_kickExpiredLocks_profitable() public {
        (uint256 total, uint256 unlockable, uint256 locked,) = IylSphere(YLSPHERE).lockedBalances(EXPIRED_LOCK_USER);
        emit log_named_decimal_uint("user total locked", total, 18);
        emit log_named_decimal_uint("user unlockable (expired)", unlockable, 18);
        emit log_named_decimal_uint("user still locked", locked, 18);
        assertGt(unlockable, 0, "expected expired locks");

        uint256 before = IERC20(SPHERE).balanceOf(attacker);
        vm.prank(attacker);
        IylSphere(YLSPHERE).kickExpiredLocks(EXPIRED_LOCK_USER);
        uint256 gained = IERC20(SPHERE).balanceOf(attacker) - before;

        emit log_named_decimal_uint("attacker SPHERE gained (kick reward)", gained, 18);
        assertGt(gained, 0, "kick should pay the caller");

        // after kick the victim's locks are gone (forced withdrawal)
        (uint256 total2,,,) = IylSphere(YLSPHERE).lockedBalances(EXPIRED_LOCK_USER);
        assertEq(total2, 0, "victim locks should be consumed");
    }

    /* NEGATIVE CONTROL: cannot kick locks that are not expired */
    function test_kickUnexpiredLocks_reverts() public {
        (, uint256 unlockable,,) = IylSphere(YLSPHERE).lockedBalances(UNEXPIRED_LOCK_USER);
        assertEq(unlockable, 0, "control user should have no expired locks");
        vm.prank(attacker);
        vm.expectRevert(bytes("no exp locks"));
        IylSphere(YLSPHERE).kickExpiredLocks(UNEXPIRED_LOCK_USER);
    }

    /* NEGATIVE: attacker has no rewards to claim */
    function test_getReward_attackerHasNothing() public {
        IylSphere.EarnedData[] memory e = IylSphere(YLSPHERE).claimableRewards(attacker);
        for (uint256 i; i < e.length; i++) {
            assertEq(e[i].amount, 0, "attacker should have no claimable rewards");
        }
        vm.prank(attacker);
        IylSphere(YLSPHERE).getReward(attacker); // pays attacker 0
        assertEq(IERC20(WMATIC).balanceOf(attacker), 0);
    }

    /* NEGATIVE: locker owner-only recovery */
    function test_ylsphere_recoverERC20_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IylSphere(YLSPHERE).recoverERC20(WMATIC, 1e18);
    }

    /* NEGATIVE: cannot lock without tokens / allow gate */
    function test_ylsphere_lock_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IylSphere(YLSPHERE).lock(attacker, 1e18);
    }

    /* ------------------------------------------------------------------ */
    /* BondDepo: deposit is capped by availableDebt (7.88 SPHERE)          */
    /* ------------------------------------------------------------------ */
    function test_bonddepo_deposit_capped_and_unprofitable() public {
        uint256 avail = IBondDepo(BONDDEPO).availableDebt();
        emit log_named_decimal_uint("BondDepo.availableDebt (SPHERE)", avail, 18);
        assertLt(avail, 100e18, "availableDebt should be dust");

        // small deposit that fits under availableDebt: 0.04 USDC.e (40,000 raw units)
        uint256 amount = 40_000;
        uint256 expected = IBondDepo(BONDDEPO).payoutFor(IBondDepo(BONDDEPO).valueOfToken(amount));
        emit log_named_decimal_uint("expected payout (SPHERE)", expected, 18);
        assertLe(expected, avail, "expected payout under availableDebt");

        deal(USDC_E, attacker, amount);
        vm.startPrank(attacker);
        IERC20(USDC_E).approve(BONDDEPO, amount);
        uint256 got = IBondDepo(BONDDEPO).deposit(amount, type(uint256).max, attacker);
        vm.stopPrank();
        emit log_named_decimal_uint("payout received (SPHERE)", got, 18);
        assertEq(got, expected);
        assertLt(got, 100e18, "attacker got dust SPHERE");
        assertEq(IERC20(USDC_E).balanceOf(attacker), 0);

        // a meaningful deposit (10,000 USDC) cannot extract anything: reverts on reserves/size
        deal(USDC_E, attacker, 10_000e6);
        vm.startPrank(attacker);
        IERC20(USDC_E).approve(BONDDEPO, 10_000e6);
        vm.expectRevert();
        IBondDepo(BONDDEPO).deposit(10_000e6, type(uint256).max, attacker);
        vm.stopPrank();
    }

    /* NEGATIVE: redeem for a non-bond-holder reverts (underflow in vesting math) */
    function test_bonddepo_redeem_attacker_zero() public {
        uint256 before = IERC20(SPHERE).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(bytes("SafeMath: subtraction overflow"));
        IBondDepo(BONDDEPO).redeem(attacker);
        assertEq(IERC20(SPHERE).balanceOf(attacker), before);
    }

    /* NEGATIVE: BondDepo owner-only recovery of the 259k SPHERE */
    function test_bonddepo_recover_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IBondDepo(BONDDEPO).recoverLostToken(SPHERE, 1e18);
    }

    /* ------------------------------------------------------------------ */
    /* SPHERE token: owner-only rescue; proxy upgrade bricked              */
    /* ------------------------------------------------------------------ */
    function test_sphere_rescue_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ISphereToken(SPHERE).rescueToken(SPHERE);
    }

    function test_sphere_v1_rescue_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISphereTokenV1(SPHERE_V1).rescueToken(SPHERE, 1e18);
        vm.prank(attacker);
        vm.expectRevert();
        ISphereTokenV1(SPHERE_V1).manualSwapBack();
    }

    function test_proxyadmin_upgrade_reverts() public {
        assertEq(IProxyAdmin(SPHERE_PROXYADMIN).owner(), TIMELOCK);
        vm.prank(attacker);
        vm.expectRevert();
        IProxyAdmin(SPHERE_PROXYADMIN).upgrade(SPHERE, attacker);
    }

    /* ------------------------------------------------------------------ */
    /* Timelock has no roles at all -> cannot execute anything             */
    /* ------------------------------------------------------------------ */
    function test_timelock_roles_all_zero() public {
        bytes32 proposer = ITimelock(TIMELOCK).PROPOSER_ROLE();
        bytes32 executor = ITimelock(TIMELOCK).EXECUTOR_ROLE();
        assertFalse(ITimelock(TIMELOCK).hasRole(proposer, attacker));
        assertFalse(ITimelock(TIMELOCK).hasRole(executor, attacker));
        assertFalse(ITimelock(TIMELOCK).hasRole(proposer, address(0)));
        assertFalse(ITimelock(TIMELOCK).hasRole(executor, address(0)));
        // no proposer at all -> schedule impossible
        vm.prank(attacker);
        vm.expectRevert();
        ITimelock(TIMELOCK).schedule(attacker, 0, "", bytes32(0), bytes32(0), 0);
        // direct execute reverts (no executor role)
        vm.prank(attacker);
        vm.expectRevert();
        ITimelock(TIMELOCK).execute(attacker, 0, "", bytes32(0), bytes32(0));
    }

    /* ------------------------------------------------------------------ */
    /* Bond swapper / overnight strategy: swapBack is role-gated           */
    /* ------------------------------------------------------------------ */
    function test_bondswapper_swapback_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("not allowed to swap back"));
        IBondSwapper(BONDSWAP).swapBack();
        vm.prank(attacker);
        vm.expectRevert();
        IBondSwapper(BONDSWAP).withdrawToken(SPHERE);
    }

    function test_overnight_swapback_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("not allowed to swap back"));
        IOvernightStrategy(OVERNIGHT).swapBack();
        vm.prank(attacker);
        vm.expectRevert();
        IOvernightStrategy(OVERNIGHT).withdrawToken(USDC_E);
    }

    /* ------------------------------------------------------------------ */
    /* SphereTreasury: owner-only                                          */
    /* ------------------------------------------------------------------ */
    function test_sphere_treasury_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        ISphereTreasury(TREASURY).retrieveTokens(SPHERE, 1e18);
        vm.prank(attacker);
        vm.expectRevert();
        ISphereTreasury(TREASURY).retrieveMATIC(1);
    }

    /* ------------------------------------------------------------------ */
    /* Fair launch claims: investor-only                                   */
    /* ------------------------------------------------------------------ */
    function test_spherefairlaunch_claim_noninvestor_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(bytes("No investment made"));
        ISphereFairLaunch(SPHEREFAIRLAUNCH).claimRedeemable();
        // approveWithdraw for a non-investor approves 0 -> cannot pull contract funds
        vm.prank(attacker);
        ISphereFairLaunch(SPHEREFAIRLAUNCH).approveWithdraw();
        assertEq(IERC20(SPHERE).allowance(SPHEREFAIRLAUNCH, attacker), 0);
    }

    function test_fairlaunchpool_redeem_noninvestor_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IFairLaunchPool(FAIRLAUNCH1).redeem();
    }

    /* ------------------------------------------------------------------ */
    /* Safes: 4-of-8 EOA multisig, unprivileged execution impossible       */
    /* ------------------------------------------------------------------ */
    function test_safes_are_multisig() public {
        address[3] memory safes = [INV_TREASURY_SAFE, LP_TREASURY_SAFE, RFV_TREASURY_SAFE];
        for (uint256 i; i < 3; i++) {
            assertEq(ISafe(safes[i]).getThreshold(), 4);
            assertEq(ISafe(safes[i]).getOwners().length, 8);
        }
        // attacker cannot exec a transfer out of the Safe
        vm.prank(attacker);
        vm.expectRevert();
        ISafe(INV_TREASURY_SAFE).execTransaction(attacker, 1, "", 0, 0, 0, 0,
            address(0), address(0), "");
    }

    /* ------------------------------------------------------------------ */
    /* Live value snapshot assertions (proves where the money is)          */
    /* ------------------------------------------------------------------ */
    function test_live_value_snapshot() public {
        emit log_named_decimal_uint("SPHERE_TUP native (MATIC)", SPHERE.balance, 18);
        emit log_named_decimal_uint("INV_TREASURY_SAFE native (MATIC)", INV_TREASURY_SAFE.balance, 18);
        emit log_named_decimal_uint("INV_TREASURY_SAFE USDC", IERC20(USDC_E).balanceOf(INV_TREASURY_SAFE), 6);
        emit log_named_decimal_uint("ylSPHERE SPHERE locked", IylSphere(YLSPHERE).lockedSupply(), 18);
        emit log_named_decimal_uint("ylSPHERE WMATIC rewards held", IERC20(WMATIC).balanceOf(YLSPHERE), 18);
        emit log_named_decimal_uint("BondDepo SPHERE held", IERC20(SPHERE).balanceOf(BONDDEPO), 18);
        emit log_named_decimal_uint("SphereFairLaunch SPHERE held", IERC20(SPHERE).balanceOf(SPHEREFAIRLAUNCH), 18);
        emit log_named_decimal_uint("SPHERE_v1 USDC.e held", IERC20(USDC_E).balanceOf(SPHERE_V1), 6);
        assertGt(INV_TREASURY_SAFE.balance, 100_000 ether, "Investment Safe holds >100k MATIC");
        assertGt(IylSphere(YLSPHERE).lockedSupply(), 1_000_000_000e18, ">1B SPHERE locked");
        assertGt(IERC20(WMATIC).balanceOf(YLSPHERE), 100_000e18, ">100k WMATIC rewards in locker");
    }
}
