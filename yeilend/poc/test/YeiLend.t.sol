// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IPool {
    function getUserAccountData(address user)
        external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function getUserConfiguration(address user) external view returns (uint256);
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function getReservesList() external view returns (address[] memory);
    function getReserveData(address asset) external view returns (
        uint256, uint128, uint128, uint128, uint128, uint128, uint40, uint16,
        address, address, address, address, uint128, uint128, uint128);
    function getConfiguration(address asset) external view returns (uint256);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function isInForcedLiquidationWhitelist(address user) external view returns (bool);
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address, uint256) external returns (bool);
}

interface IOracle {
    function getAssetPrice(address) external view returns (uint256);
    function getSourceOfAsset(address) external view returns (address);
}

/// @title YeiLend (Sei) live-surface PoC — read-only checks + fork simulations.
/// Fork of Sei mainnet at latest block; no mainnet transactions.
contract YeiLendTest is Test {
    IPool constant pool1 = IPool(0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638);
    IPool constant pool2 = IPool(0x7b5b1A719d54664657451db7600FD5C3ca0fa136);
    IOracle constant oracle1 = IOracle(0xA1ce28cEbaB91d8dF346D19970E4Ee69A6989734);
    IOracle constant oracle2 = IOracle(0xbDecf329328CD5A8b0035697163b61d7268887AE);

    address constant WSEI = 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7;
    address constant USDC = 0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392;
    address constant USDT = 0xB75D0B03c06A926e488e2659DF1A861F860bD3d1;
    address constant USDCn = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;
    address constant iSEI = 0x5Cf6826140C1C56Ff49C808A1A75407Cd1DF9423;
    address constant fastUSD = 0x37a4dD9CED2b19Cfe8FAC251cd727b5787E45269;
    address constant temporaryOracle = 0x824F04f2CD6d57071bf33a86BBFC5b266fD44b72;
    address constant whitelistedKeeper = 0x419D4C44bB5cefdE526CCE6Ea47B0C25818facfC;
    address constant timelockOwner = 0x02135EA9bc6481f7296852c9C3c24e8f9Ef10bE7;

    address attacker = address(0xA11CE);

    function setUp() public {
        vm.createSelectFork(vm.envOr("SEI_RPC_URL", string("https://evm-rpc.sei-apis.com")));
        vm.deal(attacker, 100 ether);
    }

    // ---------------------------------------------------------------- helpers
    function aTokenOf(address asset) internal view returns (address a) {
        (,,,,,,,, a,,,,,,) = pool1.getReserveData(asset);
    }

    function debtTokenOf(address asset) internal view returns (address v) {
        (,,,,,,,,,, v,,,,) = pool1.getReserveData(asset);
    }

    function forcedEnabled(uint256 cfg) internal pure returns (bool) {
        return ((cfg >> 252) & 1) == 1;
    }

    function readCount(string memory path) internal view returns (uint256) {
        if (!vm.exists(path)) return 0;
        string memory s = vm.readFile(path);
        if (bytes(s).length < 10) return 0;
        return vm.parseJsonUint(s, ".count");
    }

    function readUser(string memory path, uint256 i) internal view returns (address) {
        string memory s = vm.readFile(path);
        return vm.parseJsonAddress(s, string.concat(".items[", vm.toString(i), "].user"));
    }

    // ---------------------------------------------------------------- live state
    function test_live_reserves_and_forced_flags() public view {
        address[] memory r1 = pool1.getReservesList();
        address[] memory r2 = pool2.getReservesList();
        assertEq(r1.length, 19, "pool1 reserve count");
        assertEq(r2.length, 2, "pool2 reserve count");
        assertTrue(forcedEnabled(pool1.getConfiguration(USDCn)), "USDC.n forced");
        assertTrue(forcedEnabled(pool1.getConfiguration(USDT)), "USDT forced");
        assertTrue(forcedEnabled(pool1.getConfiguration(iSEI)), "iSEI forced");
        assertFalse(forcedEnabled(pool1.getConfiguration(WSEI)), "WSEI not forced");
        assertFalse(forcedEnabled(pool1.getConfiguration(USDC)), "USDC not forced");
    }

    function test_oracle_live_and_fastusd_zero() public view {
        uint256 wsei = oracle1.getAssetPrice(WSEI);
        assertGt(wsei, 0.02e8);
        assertLt(wsei, 0.20e8);
        // fastUSD/sfastUSD are served by the "temporaryOracle" and priced at 1e-8 USD
        assertEq(oracle1.getAssetPrice(fastUSD), 1, "fastUSD oracle price == 1");
        assertEq(oracle1.getSourceOfAsset(fastUSD), temporaryOracle, "fastUSD source");
        (bool ok, bytes memory ret) = temporaryOracle.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok, "owner()");
        assertEq(abi.decode(ret, (address)), timelockOwner, "oracle owner");
    }

    function test_whitelist_state() public view {
        assertTrue(pool1.isInForcedLiquidationWhitelist(whitelistedKeeper), "keeper whitelisted");
        assertFalse(pool1.isInForcedLiquidationWhitelist(attacker), "attacker not whitelisted");
    }

    // ---------------------------------------------------------------- blocked paths
    function test_frozen_fastusd_borrow_reverts() public {
        deal(WSEI, attacker, 100e18);
        vm.startPrank(attacker);
        IERC20(WSEI).approve(address(pool1), type(uint256).max);
        pool1.supply(WSEI, 100e18, attacker, 0);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "28")); // RESERVE_FROZEN
        pool1.borrow(fastUSD, 1e18, 2, 0, attacker);
        vm.stopPrank();
    }

    function test_frozen_fastusd_supply_reverts() public {
        deal(fastUSD, attacker, 10e18);
        vm.startPrank(attacker);
        IERC20(fastUSD).approve(address(pool1), type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "28")); // RESERVE_FROZEN
        pool1.supply(fastUSD, 10e18, attacker, 0);
        vm.stopPrank();
    }

    function test_self_liquidation_blocked() public {
        address user = 0xca9556d1c3D116e8234d18dB33F3fba680CD06CF; // historical borrower
        uint256 count = readCount("../ci-out/top_debtors_pool1.json");
        if (count > 0) user = readUser("../ci-out/top_debtors_pool1.json", 0);
        (uint256 cb, uint256 db,,,, ) = pool1.getUserAccountData(user);
        vm.assume(db > 0 || cb > 0);
        // self-liquidation is explicitly blocked in the deployed fork (error '130')
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "130"));
        pool1.liquidationCall(WSEI, USDC, user, 1, false);
    }

    /// Credit delegation: borrowing on behalf of another account requires an explicit
    /// debt-token allowance; an unprivileged attacker's attempt reverts with '129'.
    function test_borrow_on_behalf_requires_allowance() public {
        address victim = 0xca9556d1c3D116e8234d18dB33F3fba680CD06CF;
        (uint256 cb, uint256 db, uint256 ab,,,) = pool1.getUserAccountData(victim);
        vm.assume(ab > 0 && cb > 0);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "129")); // INSUFFICIENT_ALLOWANCE
        pool1.borrow(WSEI, 1e6, 2, 0, victim);
        // control: borrowing on behalf of self passes the allowance gate
        deal(WSEI, attacker, 100e18);
        vm.startPrank(attacker);
        IERC20(WSEI).approve(address(pool1), type(uint256).max);
        pool1.supply(WSEI, 100e18, attacker, 0);
        pool1.borrow(USDC, 1e6, 2, 0, attacker);
        vm.stopPrank();
    }

    /// A healthy position with non-forced debt cannot be liquidated by anyone (error '45').
    function test_healthy_liquidation_reverts() public {
        // top debtor from the local probes (HF > 1, WSEI collateral, WSEI/USDC debt)
        address user = 0x000000e28fAA823d5B53ff6C2922c28335840375;
        (uint256 cb, uint256 db,,,, uint256 hf) = pool1.getUserAccountData(user);
        vm.assume(db > 0 && hf > 1e18 && cb > 0);
        (address collAsset, address debtAsset, uint256 debtBal) = biggestDebtAndCollateral(user);
        vm.assume(debtAsset != address(0) && collAsset != address(0));
        vm.assume(!forcedEnabled(pool1.getConfiguration(debtAsset)));
        deal(debtAsset, attacker, debtBal > 0 ? debtBal : 1);
        vm.startPrank(attacker);
        IERC20(debtAsset).approve(address(pool1), type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "45")); // HEALTH_FACTOR_NOT_BELOW_THRESHOLD
        pool1.liquidationCall(collAsset, debtAsset, user, debtBal > 0 ? debtBal : 1, false);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- adaptive liquidation probe
    /// If the CI scan found an unhealthy (HF<1) position, liquidate it on the fork and
    /// report the net USD profit. If none, passes with a log (market clean).
    function test_worst_unhealthy_liquidation_net_profit() public {
        uint256 count = readCount("../ci-out/unhealthy_pool1.json");
        if (count == 0) {
            emit log_string("no HF<1 position found by the full borrower scan; market clean at fork block");
            return;
        }
        uint256 limit = count > 20 ? 20 : count;
        uint256 successes;
        for (uint256 i = 0; i < limit; i++) {
            address user = readUser("../ci-out/unhealthy_pool1.json", i);
            (bool okU, uint256 collBase, uint256 debtBase, uint256 hf) = safeUserData(user);
            if (!okU || debtBase == 0 || hf >= 1e18) continue;
            (address collAsset, address debtAsset, uint256 debtBal) = biggestDebtAndCollateral(user);
            if (debtAsset == address(0) || collAsset == address(0)) continue;
            if (forcedEnabled(pool1.getConfiguration(debtAsset))) {
                emit log_named_address("forced-reserve debtor (whitelist-only, not E-U)", user);
                continue;
            }
            deal(debtAsset, attacker, debtBal);
            uint256 collBefore = IERC20(collAsset).balanceOf(attacker);
            uint256 debtBefore = IERC20(debtAsset).balanceOf(attacker);
            vm.startPrank(attacker);
            IERC20(debtAsset).approve(address(pool1), type(uint256).max);
            try pool1.liquidationCall(collAsset, debtAsset, user, debtBal, false) {
                vm.stopPrank();
            } catch {
                vm.stopPrank();
                emit log_named_address("liquidation reverted for", user);
                continue;
            }
            uint256 collGained = IERC20(collAsset).balanceOf(attacker) - collBefore;
            uint256 debtSpent = debtBefore - IERC20(debtAsset).balanceOf(attacker);
            uint256 collPrice = oracle1.getAssetPrice(collAsset);
            uint256 debtPrice = oracle1.getAssetPrice(debtAsset);
            uint8 cd = IERC20(collAsset).decimals();
            uint8 dd = IERC20(debtAsset).decimals();
            int256 profitUsd1e8 = int256(collGained * collPrice / (10 ** cd))
                - int256(debtSpent * debtPrice / (10 ** dd));
            emit log_named_address("liquidated user", user);
            emit log_named_uint("collateral seized (raw)", collGained);
            emit log_named_uint("debt repaid (raw)", debtSpent);
            emit log_named_int("net profit (USD, 1e8)", profitUsd1e8);
            assertGe(profitUsd1e8, 0, "liquidation should not lose money (or is dust)");
            successes++;
            if (successes == 3) return;
        }
        if (successes == 0) emit log_string("no open unhealthy non-forced position found at fork block");
    }

    /// oracle price read that tolerates fork gaps (Sei precompile-backed feeds may revert off-chain)
    function safePrice(address asset) internal view returns (uint256) {
        (bool ok, bytes memory ret) = address(oracle1).staticcall(abi.encodeWithSelector(IOracle.getAssetPrice.selector, asset));
        if (!ok || ret.length < 32) return 0;
        return abi.decode(ret, (uint256));
    }

    /// getUserAccountData that tolerates fork gaps (iSEI precompile-backed feed)
    function safeUserData(address user)
        internal view returns (bool ok, uint256 coll, uint256 debt, uint256 hf)
    {
        bytes memory ret;
        (ok, ret) = address(pool1).staticcall(abi.encodeWithSelector(IPool.getUserAccountData.selector, user));
        if (!ok || ret.length < 6 * 32) return (false, 0, 0, 0);
        (coll, debt, , , , hf) = abi.decode(ret, (uint256, uint256, uint256, uint256, uint256, uint256));
        ok = true;
    }

    /// pick largest current debt reserve and largest collateral reserve of `user`
    function biggestDebtAndCollateral(address user) internal view returns (address coll, address debt, uint256 debtBal) {
        address[] memory r = pool1.getReservesList();
        uint256 bestCollUsd;
        uint256 bestDebtUsd;
        for (uint256 i = 0; i < r.length; i++) {
            uint256 ab = IERC20(aTokenOf(r[i])).balanceOf(user);
            uint256 vb = IERC20(debtTokenOf(r[i])).balanceOf(user);
            uint256 price = safePrice(r[i]);
            if (price == 0) continue;
            uint8 dec = IERC20(r[i]).decimals();
            if (ab > 0) {
                uint256 usd = ab * price / (10 ** dec);
                if (usd > bestCollUsd) { bestCollUsd = usd; coll = r[i]; }
            }
            if (vb > 0) {
                uint256 usd = vb * price / (10 ** dec);
                if (usd > bestDebtUsd) { bestDebtUsd = usd; debt = r[i]; debtBal = vb; }
            }
        }
    }

    /// low-level ERC20 reads that tolerate Sei precompile-backed native wrappers
    function safeBal(address token, address who) internal view returns (bool ok, uint256 v) {
        bytes memory ret;
        (ok, ret) = token.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, who));
        if (ok && ret.length >= 32) v = abi.decode(ret, (uint256));
        else ok = false;
    }

    function safeTotal(address token) internal view returns (bool ok, uint256 v) {
        bytes memory ret;
        (ok, ret) = token.staticcall(abi.encodeWithSelector(IERC20.totalSupply.selector));
        if (ok && ret.length >= 32) v = abi.decode(ret, (uint256));
        else ok = false;
    }

    /// Summarise how much an attacker could actually borrow (available liquidity, capped).
    function test_borrowable_liquidity_headroom() public {
        address[] memory r = pool1.getReservesList();
        for (uint256 i = 0; i < r.length; i++) {
            uint256 cfg = pool1.getConfiguration(r[i]);
            bool borrowingEnabled = ((cfg >> 58) & 1) == 1;
            if (!borrowingEnabled) continue;
            uint256 cap = (cfg >> 80) & ((1 << 36) - 1);
            address aTok = aTokenOf(r[i]);
            address vTok = debtTokenOf(r[i]);
            (bool okA, uint256 avail) = safeBal(r[i], aTok);
            if (!okA) {
                // Sei native-bank wrapper (precompile 0x1001) not emulated on forks
                emit log_named_address("skipped precompile-backed reserve", r[i]);
                continue;
            }
            (bool okD, uint256 debt) = safeTotal(vTok);
            uint256 price = safePrice(r[i]);
            uint8 dec = IERC20(r[i]).decimals();
            emit log_named_address("asset", r[i]);
            emit log_named_uint("available raw", avail);
            emit log_named_uint("debt raw", okD ? debt : 0);
            emit log_named_uint("borrowCap", cap);
            emit log_named_uint("price 1e8", price);
            emit log_named_uint("available USD 1e8", price > 0 ? avail * price / (10 ** dec) : 0);
        }
    }
}
