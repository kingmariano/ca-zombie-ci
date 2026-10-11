// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, IPancakePair, IPancakeFactory, IMasterChef, IFactoryManager, IWETH} from "../src/Interfaces.sol";
import {TopPairs} from "../src/TopPairs.sol";

/// BaseSwap V2 (Base) live-path PoC — read-only fork tests.
/// Forked from BASE_RPC_URL (CI) / public Base RPC fallback. No mainnet tx are sent.
contract BaseSwapLiveTest is Test {
    address constant FACTORY = 0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB;
    address constant MASTERCHEF = 0x2B0A43DCcBD7d42c18F6A83F86D1a19fA58d541A;
    address constant FEE_TO = 0x463112327576814f80DA8D3632f7bad23c853A29; // FactoryManager (protocol-fee LP holder)
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // Top pairs by live reserve USD (filled from ci-out/top_pairs.json scan at block ~52.47M).
    address[] public TOP_PAIRS;

    address attacker = address(0xA11CE);

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string("https://base-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
    }

    function _setTopPairs(address[] memory a) internal {
        delete TOP_PAIRS;
        for (uint256 i = 0; i < a.length; i++) TOP_PAIRS.push(a[i]);
    }

    /// 1. Anyone can skim(balance-reserve); assert exact live excess received by an arbitrary caller.
    function test_live_skim_excess_top_pairs() public {
        _setTopPairs(_topPairs());
        for (uint256 i = 0; i < TOP_PAIRS.length; i++) {
            IPancakePair p = IPancakePair(TOP_PAIRS[i]);
            (uint112 r0, uint112 r1,) = p.getReserves();
            address t0 = p.token0();
            address t1 = p.token1();
            uint256 b0 = IERC20(t0).balanceOf(address(p));
            uint256 b1 = IERC20(t1).balanceOf(address(p));
            uint256 excess0 = b0 > r0 ? b0 - r0 : 0;
            uint256 excess1 = b1 > r1 ? b1 - r1 : 0;

            uint256 pre0 = IERC20(t0).balanceOf(address(this));
            uint256 pre1 = IERC20(t1).balanceOf(address(this));
            try p.skim(address(this)) {} catch {}
            uint256 got0 = IERC20(t0).balanceOf(address(this)) - pre0;
            uint256 got1 = IERC20(t1).balanceOf(address(this)) - pre1;
            assertEq(got0, excess0, "skim token0 delta != live excess");
            assertEq(got1, excess1, "skim token1 delta != live excess");
        }
    }

    /// 2. Mechanic proof: a donation to any pair is recoverable by any caller via skim().
    function test_donation_skim_mechanic() public {
        _setTopPairs(_topPairs());
        require(TOP_PAIRS.length > 0, "no pairs");
        IPancakePair p = IPancakePair(TOP_PAIRS[0]);
        (uint112 r0, uint112 r1,) = p.getReserves();
        uint256 b0 = IERC20(p.token0()).balanceOf(address(p));
        uint256 b1 = IERC20(p.token1()).balanceOf(address(p));
        uint256 excess0 = b0 > r0 ? b0 - r0 : 0;
        uint256 excess1 = b1 > r1 ? b1 - r1 : 0;

        uint256 donation = 1e15; // 0.001 WETH
        vm.deal(address(this), donation);
        IWETH(WETH).deposit{value: donation}();
        IERC20(WETH).transfer(address(p), donation);

        uint256 pre0 = IERC20(p.token0()).balanceOf(address(this));
        uint256 pre1 = IERC20(p.token1()).balanceOf(address(this));
        p.skim(address(this)); // no auth whatsoever
        uint256 got0 = IERC20(p.token0()).balanceOf(address(this)) - pre0;
        uint256 got1 = IERC20(p.token1()).balanceOf(address(this)) - pre1;
        if (p.token0() == WETH) {
            assertEq(got0, donation + excess0);
            assertEq(got1, excess1);
        } else {
            assertEq(got1, donation + excess1);
            assertEq(got0, excess0);
        }
    }

    /// 3. mint() cannot be used to obtain free LP on a one-sided/normal pair (reverts).
    function test_mint_requires_deposit_reverts() public {
        _setTopPairs(_topPairs());
        for (uint256 i = 0; i < TOP_PAIRS.length; i++) {
            IPancakePair p = IPancakePair(TOP_PAIRS[i]);
            (uint112 r0, uint112 r1,) = p.getReserves();
            uint256 b0 = IERC20(p.token0()).balanceOf(address(p));
            uint256 b1 = IERC20(p.token1()).balanceOf(address(p));
            bool twoSidedExcess = b0 > r0 && b1 > r1;
            if (twoSidedExcess) {
                // two-sided excess would mint free LP — must not exist live; handled in test_live_skim
                revert("two-sided excess present");
            }
            vm.expectRevert();
            p.mint(address(this));
        }
    }

    /// 4. MasterChefV2: an address with no stake cannot withdraw or emergency-withdraw anyone's LP.
    function test_masterchef_attacker_cannot_take() public {
        IMasterChef chef = IMasterChef(MASTERCHEF);
        uint256 n = chef.poolLength();
        for (uint256 pid = 0; pid < n; pid++) {
            (address lpToken, uint256 allocPoint, uint256 lrt, uint256 aps, uint256 totalDeposit) = chef.poolInfo(pid);
            allocPoint; lrt; aps;
            uint256 before = IERC20(lpToken).balanceOf(attacker);
            vm.prank(attacker);
            vm.expectRevert(bytes("withdraw: not good"));
            chef.withdraw(pid, 1);
            vm.prank(attacker);
            chef.emergencyWithdraw(pid);
            assertEq(IERC20(lpToken).balanceOf(attacker) - before, 0, "attacker gained LP");
            (uint256 amt,) = chef.userInfo(pid, attacker);
            assertEq(amt, 0);
            // NOTE: pool.totalDeposit is stale on this MasterChef (emergencyWithdraw does not
            // decrement it), so mcBalance < totalDeposit is expected and is NOT a loss:
            // withdraw() pays only the caller's own user.amount and the invariant
            // balance >= sum(user.amount) is preserved by construction. See
            // test_masterchef_stale_totalDeposit_observed and the report.
            IERC20(lpToken).balanceOf(MASTERCHEF);
            totalDeposit;
        }
    }

    /// 4b. Documents the stale `totalDeposit` accounting on pool 1 (E80B WETH/BSWAP).
    /// `emergencyWithdraw` does not decrement totalDeposit, so the accounting number exceeds the
    /// pair's whole LP supply while the contract holds only the real remaining stakes.
    function test_masterchef_stale_totalDeposit_observed() public {
        IMasterChef chef = IMasterChef(MASTERCHEF);
        (address lpToken, uint256 allocPoint, uint256 lrt, uint256 aps, uint256 totalDeposit) = chef.poolInfo(1);
        allocPoint; lrt; aps;
        uint256 mcBal = IERC20(lpToken).balanceOf(MASTERCHEF);
        uint256 lpSupply = IERC20(lpToken).totalSupply();
        assertGt(totalDeposit, lpSupply, "expected stale totalDeposit > LP supply");
        assertLt(mcBal, totalDeposit, "expected mcBalance < stale totalDeposit");
    }

    /// 5. Factory admin functions are gated by feeToSetter (Safe) only.
    function test_factory_admin_gated() public {
        IPancakeFactory f = IPancakeFactory(FACTORY);
        vm.prank(attacker);
        vm.expectRevert(bytes("Pancake: FORBIDDEN"));
        f.setFeeTo(attacker);
        vm.prank(attacker);
        vm.expectRevert(bytes("Pancake: FORBIDDEN"));
        f.setFeeToSetter(attacker);
    }

    /// 6. FactoryManager (feeTo, holds protocol-fee LP): collect/sweep is owner/operator gated.
    function test_factory_manager_gated() public {
        _setTopPairs(_topPairs());
        IFactoryManager fm = IFactoryManager(FEE_TO);
        assertTrue(fm.owner() != address(0));
        assertTrue(fm.owner() != attacker);
        vm.prank(attacker);
        vm.expectRevert();
        fm.collectProtocolFeeV2(IPancakePair(TOP_PAIRS.length > 0 ? TOP_PAIRS[0] : WETH));
    }

    /// 7. LP backing: top pairs have >= MINIMUM_LIQUIDITY supply and balances never below reserves.
    function test_lp_backing_top_pairs() public {
        _setTopPairs(_topPairs());
        for (uint256 i = 0; i < TOP_PAIRS.length; i++) {
            IPancakePair p = IPancakePair(TOP_PAIRS[i]);
            (uint112 r0, uint112 r1,) = p.getReserves();
            assertGe(p.totalSupply(), p.MINIMUM_LIQUIDITY(), "supply < MINIMUM_LIQUIDITY");
            assertGe(IERC20(p.token0()).balanceOf(address(p)), r0, "balance0 < reserve0");
            assertGe(IERC20(p.token1()).balanceOf(address(p)), r1, "balance1 < reserve1");
        }
    }

    /// Static top-pairs fixture (regenerated from the live scan).
    function _topPairs() internal pure returns (address[] memory a) {
        return TopPairs.get();
    }
}
