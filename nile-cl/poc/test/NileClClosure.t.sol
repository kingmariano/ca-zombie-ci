// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    IERC20,
    IClPoolMin,
    IClFactoryMin,
    IProxyAdminMin,
    INonfungiblePositionManagerMin,
    IFeeCollectorMin,
    IGaugeV2Min,
    IFeeDistributorMin,
    IVoterMin,
    ITimelockMin,
    IBribeHolderMin
} from "../src/Ifaces.sol";

/// @notice Nile CL (Linea) — unprivileged-attacker closure tests.
/// Read-only + fork-local state changes only. No mainnet transactions.
/// Fork RPC: keyless public endpoints only (never keyed URLs in files/logs).
contract NileClClosureTest is Test {
    // ---- chain constants (Linea mainnet, verified 2026-10-13) ----
    address constant FACTORY = 0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42; // ClPoolFactory proxy
    address constant FACTORY_ADMIN = 0x8e01fc0d89b93a6447D6c6Eca6fBd30e6E4a1ce3; // ProxyAdmin
    address constant TIMELOCK = 0xbabe7a170A764C8367bFFB35EbDe8E97AA72c3aA;
    address constant GOVERNOR_SAFE = 0x44376f8F52407ed66E6D3356535410A7DCd4652B;
    address constant VOTER = 0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869;
    address constant NFP = 0xAAA78E8C4241990B4ce159E105dA08129345946A;
    address constant FEE_COLLECTOR = 0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f;
    address constant BRIBE_HOLDER = 0xF7a8b3770f661059F4eA0D79aD7Fe8d642F9ea9b;
    address constant WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address constant ATTACKER = address(0xBEEF);

    // top pools by live value
    address constant POOL_TOP = 0xCE6f03C4f2D1F23ED1996c85b6FF047FB049B61f; // ~20.9 WETH
    address constant POOL_USDC_WETH = 0x64bCcad8e7302E81b09894f56F6BBa85ae82CD03; // alive gauge
    address constant POOL_ALIVE_GAUGE = 0x64bCcad8e7302E81b09894f56F6BBa85ae82CD03;
    address constant FEE_DIST_ALIVE = 0x8E73cF029Befd464f54C6E1499006686961530Ff;
    address constant GAUGE_ALIVE = 0x4d0Af1EA1b84A9249d60e3eE824784829bc332E1;

    IClFactoryMin factory = IClFactoryMin(FACTORY);
    IClPoolMin poolTop = IClPoolMin(POOL_TOP);
    IERC20 weth = IERC20(WETH);
    IERC20 usdc = IERC20(USDC);

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = "https://rpc.linea.build";
        try vm.createSelectFork(rpc) {
            forkBlock = block.number;
        } catch {
            vm.createSelectFork("https://linea-rpc.publicnode.com");
            forkBlock = block.number;
        }
    }

    // ---------------------------------------------------------------
    // helpers
    // ---------------------------------------------------------------

    function _word(bytes memory data, uint256 idx) internal pure returns (bytes32 w) {
        assembly {
            w := mload(add(add(data, 32), mul(idx, 32)))
        }
    }

    function _findLivePosition() internal view returns (uint256 id, bool found) {
        for (uint256 i = 1; i <= 40; ++i) {
            (bool ok, bytes memory data) =
                NFP.staticcall(abi.encodeWithSelector(INonfungiblePositionManagerMin.positions.selector, i));
            if (!ok || data.length < 32 * 12) continue;
            uint128 liquidity = uint128(uint256(_word(data, 7)));
            if (liquidity == 0) continue;
            (bool ok2, bytes memory d2) =
                NFP.staticcall(abi.encodeWithSelector(INonfungiblePositionManagerMin.ownerOf.selector, i));
            if (ok2 && d2.length >= 32) {
                address o = address(uint160(uint256(bytes32(d2))));
                if (o != address(0)) return (i, true);
            }
        }
        return (0, false);
    }

    // ---------------------------------------------------------------
    // S01 — live state: top pool is funded
    // ---------------------------------------------------------------
    function test_S01_top_pool_funded_live() public view {
        (uint160 sqrtPriceX96,,,,,, bool unlocked) = poolTop.slot0();
        assertGt(sqrtPriceX96, 0, "top pool initialized");
        assertTrue(unlocked, "top pool unlocked");
        assertGt(poolTop.liquidity(), 0, "top pool has liquidity");
        assertGt(weth.balanceOf(POOL_TOP), 5 ether, "top pool holds WETH");
        assertEq(poolTop.factory(), FACTORY, "pool factory is Nile CL factory");
    }

    // ---------------------------------------------------------------
    // S02 — collectProtocol is gated to the factory feeCollector only
    // ---------------------------------------------------------------
    function test_S02_collectProtocol_only_feeCollector() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        poolTop.collectProtocol(ATTACKER, type(uint128).max, type(uint128).max);

        // even the factory owner cannot pull directly; only the feeCollector contract can
        vm.prank(factory.owner());
        vm.expectRevert();
        poolTop.collectProtocol(ATTACKER, type(uint128).max, type(uint128).max);
    }

    // ---------------------------------------------------------------
    // S03 — pool-level collect only reaches the caller's own position
    // ---------------------------------------------------------------
    function test_S03_pool_collect_cannot_touch_victim_position() public {
        (uint256 id, bool found) = _findLivePosition();
        if (!found) return; // no live position in scanned range; nothing to prove

        (int24 lower, int24 upper) = _pos(id);

        uint256 a0 = weth.balanceOf(ATTACKER);
        uint256 a1 = usdc.balanceOf(ATTACKER);
        uint256 p0 = weth.balanceOf(POOL_TOP);
        uint256 p1 = usdc.balanceOf(POOL_TOP);

        vm.prank(ATTACKER);
        (uint128 c0, uint128 c1) =
            poolTop.collect(ATTACKER, id, lower, upper, type(uint128).max, type(uint128).max);

        assertEq(c0, 0, "attacker cannot collect victim token0");
        assertEq(c1, 0, "attacker cannot collect victim token1");
        assertEq(weth.balanceOf(ATTACKER), a0, "attacker WETH unchanged");
        assertEq(usdc.balanceOf(ATTACKER), a1, "attacker USDC unchanged");
        assertEq(weth.balanceOf(POOL_TOP), p0, "pool WETH unchanged");
        assertEq(usdc.balanceOf(POOL_TOP), p1, "pool USDC unchanged");
    }

    function _pos(uint256 id) internal view returns (int24 lower, int24 upper) {
        (bool ok, bytes memory data) =
            NFP.staticcall(abi.encodeWithSelector(INonfungiblePositionManagerMin.positions.selector, id));
        require(ok && data.length >= 32 * 7, "pos read failed");
        lower = int24(int256(uint256(_word(data, 5))));
        upper = int24(int256(uint256(_word(data, 6))));
    }

    // ---------------------------------------------------------------
    // S04/S05 — NFP manager owner gates on principal extraction
    // ---------------------------------------------------------------
    function test_S04_decreaseLiquidity_requires_owner() public {
        (uint256 id, bool found) = _findLivePosition();
        if (!found) return;
        INonfungiblePositionManagerMin npm = INonfungiblePositionManagerMin(NFP);
        assertFalse(npm.isApprovedOrOwner(ATTACKER, id), "attacker is not owner/approved");

        vm.prank(ATTACKER);
        vm.expectRevert();
        npm.decreaseLiquidity(
            INonfungiblePositionManagerMin.DecreaseLiquidityParams({
                tokenId: id,
                liquidity: 1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 1000
            })
        );
    }

    function test_S05_collect_requires_owner() public {
        (uint256 id, bool found) = _findLivePosition();
        if (!found) return;
        INonfungiblePositionManagerMin npm = INonfungiblePositionManagerMin(NFP);

        vm.prank(ATTACKER);
        vm.expectRevert();
        npm.collect(
            INonfungiblePositionManagerMin.CollectParams({
                tokenId: id,
                recipient: ATTACKER,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                deadline: block.timestamp + 1000
            })
        );
    }

    // ---------------------------------------------------------------
    // S06 — fake pool cannot trick the FeeCollector into paying attacker
    // ---------------------------------------------------------------
    function test_S06_feeCollector_fakePool_no_theft() public {
        FakePool fake = new FakePool();
        IFeeCollectorMin fc = IFeeCollectorMin(FEE_COLLECTOR);

        uint256 fcWeth = weth.balanceOf(FEE_COLLECTOR);
        uint256 fcUsdc = usdc.balanceOf(FEE_COLLECTOR);
        uint256 atkWeth = weth.balanceOf(ATTACKER);
        uint256 treWeth = weth.balanceOf(fc.treasury());

        vm.prank(ATTACKER);
        fc.collectProtocolFees(address(fake));

        // fake pool's "collectProtocol" was invoked but no real value moved anywhere
        assertTrue(fake.called(), "fake collectProtocol invoked");
        assertEq(weth.balanceOf(FEE_COLLECTOR), fcWeth, "feeCollector WETH unchanged");
        assertEq(usdc.balanceOf(FEE_COLLECTOR), fcUsdc, "feeCollector USDC unchanged");
        assertEq(weth.balanceOf(ATTACKER), atkWeth, "attacker WETH unchanged");
        assertEq(weth.balanceOf(fc.treasury()), treWeth, "treasury WETH unchanged");
    }

    // ---------------------------------------------------------------
    // S07 — permissionless collectProtocolFees can only push fees to
    //       treasury / feeDistributor, never to the caller
    // ---------------------------------------------------------------
    function test_S07_real_pool_sweep_never_pays_caller() public {
        IFeeCollectorMin fc = IFeeCollectorMin(FEE_COLLECTOR);
        IVoterMin voter = IVoterMin(VOTER);

        address gauge = voter.gauges(POOL_USDC_WETH);
        address fd = voter.feeDistributors(gauge);

        uint256 tre0 = weth.balanceOf(fc.treasury());
        uint256 tre1 = usdc.balanceOf(fc.treasury());
        uint256 fd0 = fd == address(0) ? 0 : weth.balanceOf(fd);
        uint256 fd1 = fd == address(0) ? 0 : usdc.balanceOf(fd);
        uint256 atk0 = weth.balanceOf(ATTACKER);
        uint256 atk1 = usdc.balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        fc.collectProtocolFees(POOL_USDC_WETH);

        uint256 dTre0 = weth.balanceOf(fc.treasury()) - tre0;
        uint256 dTre1 = usdc.balanceOf(fc.treasury()) - tre1;
        uint256 dFd0 = (fd == address(0)) ? 0 : weth.balanceOf(fd) - fd0;
        uint256 dFd1 = (fd == address(0)) ? 0 : usdc.balanceOf(fd) - fd1;

        assertEq(weth.balanceOf(ATTACKER), atk0, "attacker WETH unchanged");
        assertEq(usdc.balanceOf(ATTACKER), atk1, "attacker USDC unchanged");
        assertGt(dTre0 + dTre1 + dFd0 + dFd1, 0, "fees moved to treasury/feeDistributor");
    }

    // ---------------------------------------------------------------
    // S08 — gauge leftovers go to feeCollector.treasury(); and the
    //       leftovers path is period-capped (bricked for periods > 2830)
    // ---------------------------------------------------------------
    function test_S08_gauge_leftovers_receiver_is_treasury() public {
        IFeeCollectorMin fc = IFeeCollectorMin(FEE_COLLECTOR);
        IGaugeV2Min gauge = IGaugeV2Min(GAUGE_ALIVE);

        assertEq(gauge.feeCollector(), FEE_COLLECTOR, "gauge feeCollector wired");
        assertEq(fc.treasury(), BRIBE_HOLDER, "treasury is BribeHolder");
        assertEq(IBribeHolderMin(BRIBE_HOLDER).owner(), 0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7, "BribeHolder owner is ETHEREX safe");

        // current period is way past 2830: leftover retrieval for any live period reverts
        uint256 currentPeriod = block.timestamp / 1 weeks;
        assertGt(currentPeriod, 2830, "current period > cap");
        address[] memory toks = new address[](0);
        uint256[] memory periods = new uint256[](0);
        vm.prank(ATTACKER);
        gauge.retrieveLeftovers(toks, periods); // empty call is a harmless no-op

        address[] memory toks2 = new address[](1);
        toks2[0] = WETH;
        uint256[] memory periods2 = new uint256[](1);
        periods2[0] = currentPeriod;
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Nope"));
        gauge.retrieveLeftovers(toks2, periods2);
    }

    // ---------------------------------------------------------------
    // S09 — fee distributor claims require the veNFT / voter
    // ---------------------------------------------------------------
    function test_S09_feeDistributor_claims_are_owner_gated() public {
        IFeeDistributorMin fd = IFeeDistributorMin(FEE_DIST_ALIVE);
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;

        vm.prank(ATTACKER);
        vm.expectRevert();
        fd.getRewardForOwner(1, tokens);

        vm.prank(ATTACKER);
        vm.expectRevert();
        fd.getReward(1, tokens);

        vm.prank(ATTACKER);
        vm.expectRevert();
        fd.getPeriodReward(block.timestamp / 1 weeks, 1, WETH);
    }

    // ---------------------------------------------------------------
    // S10 — fee distributor share accounting conserves (Σ userVotes ≤ votes)
    // ---------------------------------------------------------------
    function test_S10_feeDistributor_share_conservation() public view {
        IFeeDistributorMin fd = IFeeDistributorMin(FEE_DIST_ALIVE);
        uint256 currentPeriod = (block.timestamp / 1 weeks) * 1 weeks;

        // find the most recent period with votes
        uint256 p = 0;
        for (uint256 i = 0; i < 12; ++i) {
            uint256 c = currentPeriod - i * 1 weeks;
            if (fd.votes(c) > 0) {
                p = c;
                break;
            }
        }
        if (p == 0) return; // no votes in the last 12 periods; nothing to check

        uint256 total = fd.votes(p);
        uint256 sum;
        for (uint256 id = 1; id <= 60; ++id) {
            sum += fd.userVotes(p, id);
            assertLe(fd.userVotes(p, id), total, "no single voter can exceed total votes");
        }
        assertLe(sum, total, "sampled userVotes sum <= votes (conservation)");
        // claimed rewards can never exceed each voter's pro-rata share
        for (uint256 id = 1; id <= 60; ++id) {
            uint256 share = (fd.rewardSupply(p, WETH) * fd.userVotes(p, id)) / total;
            assertLe(fd.userClaimed(p, id, WETH), share, "claimed <= share");
        }
    }

    // ---------------------------------------------------------------
    // S11 — factory + proxy admin gates
    // ---------------------------------------------------------------
    function test_S11_factory_admin_gates() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        factory.setImplementation(ATTACKER);
        vm.expectRevert();
        factory.setOwner(ATTACKER);
        vm.expectRevert();
        factory.enableFeeAmount(12345, 1);
        vm.stopPrank();

        IProxyAdminMin pa = IProxyAdminMin(FACTORY_ADMIN);
        vm.prank(ATTACKER);
        vm.expectRevert();
        pa.upgrade(FACTORY, ATTACKER);
        assertEq(pa.owner(), TIMELOCK, "proxy admin owned by timelock");
    }

    // ---------------------------------------------------------------
    // S12 — timelock roles are not open
    // ---------------------------------------------------------------
    function test_S12_timelock_roles_closed() public view {
        ITimelockMin tl = ITimelockMin(TIMELOCK);
        assertEq(tl.getMinDelay(), 86400, "24h delay");
        bytes32 proposer = keccak256("PROPOSER_ROLE");
        bytes32 executor = keccak256("EXECUTOR_ROLE");
        assertFalse(tl.hasRole(proposer, address(0)), "proposer not open");
        assertFalse(tl.hasRole(proposer, ATTACKER), "attacker not proposer");
        assertFalse(tl.hasRole(executor, address(0)), "executor not open");
        assertFalse(tl.hasRole(executor, ATTACKER), "attacker not executor");
        assertTrue(tl.hasRole(proposer, GOVERNOR_SAFE), "safe is proposer");
        assertTrue(tl.hasRole(executor, GOVERNOR_SAFE), "safe is executor");
    }

    // ---------------------------------------------------------------
    // S13 — BribeHolder treasury is safe-owned
    // ---------------------------------------------------------------
    function test_S13_bribeHolder_owner_gated() public {
        address[] memory toks = new address[](1);
        toks[0] = WETH;
        vm.prank(ATTACKER);
        vm.expectRevert();
        IBribeHolderMin(BRIBE_HOLDER).fetch(toks);
    }

    // ---------------------------------------------------------------
    // S14 — pool price cannot be re-initialized; factory initializePool is a no-op
    // ---------------------------------------------------------------
    function test_S14_price_reinit_blocked() public {
        (uint160 before,,,,,,) = poolTop.slot0();
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("AI"));
        poolTop.initialize(1);

        address t0 = poolTop.token0();
        address t1 = poolTop.token1();
        vm.prank(ATTACKER);
        factory.initializePool(t0, t1, poolTop.fee(), 1);
        (uint160 afterPrice,,,,,,) = poolTop.slot0();
        assertEq(afterPrice, before, "slot0 price unchanged after initializePool attempt");
    }

    // ---------------------------------------------------------------
    // S15 — protocol fee is 100% of swap fees (LP fee = 0) and anyone can sync it
    // ---------------------------------------------------------------
    function test_S15_protocol_fee_100pct_permissionless_sync() public {
        assertEq(factory.feeProtocol(), 100, "factory feeProtocol == 100 (percent)");
        assertEq(factory.poolFeeProtocol(POOL_TOP), 100, "pool feeProtocol defaults to 100");
        // anyone can sync a pool's slot0.feeProtocol to the factory value
        vm.prank(ATTACKER);
        poolTop.setFeeProtocol();
        (,,,,, uint8 fp,) = poolTop.slot0();
        assertEq(fp, 100, "pool protocol fee synced to 100%");
    }
}

/// @dev fake pool used to probe FeeCollector.collectProtocolFees
contract FakePool {
    bool public called;

    function token0() external view returns (address) {
        return 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // WETH
    }

    function token1() external view returns (address) {
        return 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; // USDC
    }

    function collectProtocol(address, uint128, uint128) external returns (uint128, uint128) {
        called = true;
        return (0, 0);
    }
}
