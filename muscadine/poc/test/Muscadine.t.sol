// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title Muscadine (Base) — live-extractability boundary tests (read-only, fork only)
/// @notice Verifies at a Base fork that an external unprivileged attacker CANNOT extract value from
///         the Muscadine VaultV2 vaults (USDC/cbBTC/WETH Prime + USDC Frontier), and quantifies the
///         holder-only (H-O) exit paths, the permissionless forceDeallocate unstick path, and the
///         pending timelocked governance actions. No transactions are sent to mainnet.

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IVaultV2 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
    function previewDeposit(uint256) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function redeem(uint256, address, address) external returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function withdraw(uint256, address, address) external returns (uint256);
    function forceDeallocate(address, bytes memory, uint256, address) external returns (uint256);
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
    function adapters(uint256) external view returns (address);
    function canSendShares(address) external view returns (bool);
    function canReceiveAssets(address) external view returns (bool);
    function canSendAssets(address) external view returns (bool);
    function forceDeallocatePenalty(address) external view returns (uint256);
    function executableAt(bytes memory) external view returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address) external view returns (bool);
    function setSendAssetsGate(address) external;
}

interface IAdapter {
    function marketIdsLength() external view returns (uint256);
    function marketIds(uint256) external view returns (bytes32);
    function realAssets() external view returns (uint256);
    function expectedSupplyAssets(bytes32) external view returns (uint256);
}

interface IMorpho {
    function idToMarketParams(bytes32) external view returns (address, address, address, address, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IChainlinkFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IWhitelistGate {
    function canSendAssets(address) external view returns (bool);
    function isWhitelisted(address) external view returns (bool);
    function roleSetter() external view returns (address);
}

contract MuscadineTest is Test {
    // ---- live addresses (Base mainnet, verified 2026-10-11) ----
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address constant USDC_PRIME = 0x89712980Cb434eF5aE4AB29349419eb976B0b496;
    address constant WETH_PRIME = 0xD6DCAd2f7Da91FBb27BdA471540d9770c97a5a43;
    address constant CBBTC_PRIME = 0x99dcd0D75822BA398F13B2A8852B07c7e137EC70;
    address constant USDC_FRONTIER = 0x314fD07319ef645bA7D548915CCd91F4788A1839;

    address constant USDC_V1 = 0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F;
    address constant GATE = 0xB7F2598Ac79A3C6406ddDb81EdCc60ea72A134b9;

    // largest live holders (from full Transfer-history reconstruction)
    address constant H_9E28 = 0x9e284c8Aa44132C911140950D93e44f027199CC5;
    address constant H_6280 = 0x628037c2D25F5e5f6F90415CFf6d7e8860f41C08;
    address constant H_E11E = 0xE11EF8eE62a4b395Fd1163036e5412EDa7db0918;
    address constant H_48DB = 0x48db1f53eA51e37fFE10e59f1df7dC38E52be80e;

    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", vm.envOr("FORK_RPC_URL", string("https://mainnet.base.org"))));
    }

    function _mkParams(bytes32 id) internal view returns (MarketParams memory p) {
        (address l, address c, address o, address i, uint256 ll) = IMorpho(MORPHO).idToMarketParams(id);
        p = MarketParams(l, c, o, i, ll);
    }

    function _marketLiquidity(bytes32 id) internal view returns (uint256) {
        (uint128 tsa,, uint128 tba,,,) = IMorpho(MORPHO).market(id);
        return uint256(tsa) - uint256(tba);
    }

    // ---------------------------------------------------------------- 1
    /// @notice live state snapshot
    function test_1_live_state() public {
        emit log_named_uint("fork block", block.number);
        address[4] memory vs = [USDC_PRIME, WETH_PRIME, CBBTC_PRIME, USDC_FRONTIER];
        string[4] memory names = ["usdc_prime", "weth_prime", "cbbtc_prime", "usdc_frontier"];
        for (uint256 i; i < 4; ++i) {
            emit log_named_string("vault", names[i]);
            emit log_named_uint("  totalAssets", IVaultV2(vs[i]).totalAssets());
            emit log_named_uint("  totalSupply", IVaultV2(vs[i]).totalSupply());
            emit log_named_uint("  holder 9E28", IVaultV2(vs[i]).balanceOf(H_9E28));
            emit log_named_uint("  holder 6280", IVaultV2(vs[i]).balanceOf(H_6280));
            emit log_named_uint("  holder E11E", IVaultV2(vs[i]).balanceOf(H_E11E));
            emit log_named_uint("  holder 48DB", IVaultV2(vs[i]).balanceOf(H_48DB));
        }
    }

    // ---------------------------------------------------------------- 2
    /// @notice attacker cannot deposit: sendAssetsGate whitelist blocks non-whitelisted depositors
    function test_2_attacker_cannot_deposit() public {
        assertFalse(IWhitelistGate(GATE).isWhitelisted(attacker), "attacker unexpectedly whitelisted");
        assertFalse(IVaultV2(USDC_PRIME).canSendAssets(attacker), "gate should reject attacker");

        vm.startPrank(attacker);
        IERC20(USDC).approve(USDC_PRIME, type(uint256).max);
        vm.expectRevert();
        IVaultV2(USDC_PRIME).deposit(1000e6, attacker);
        vm.stopPrank();

        // and on cbBTC / WETH / frontier vaults
        vm.startPrank(attacker);
        IERC20(CBBTC).approve(CBBTC_PRIME, type(uint256).max);
        vm.expectRevert();
        IVaultV2(CBBTC_PRIME).deposit(0.01e8, attacker);

        IERC20(WETH).approve(WETH_PRIME, type(uint256).max);
        vm.expectRevert();
        IVaultV2(WETH_PRIME).deposit(1 ether, attacker);

        IERC20(USDC).approve(USDC_FRONTIER, type(uint256).max);
        vm.expectRevert();
        IVaultV2(USDC_FRONTIER).deposit(1000e6, attacker);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- 3
    /// @notice attacker cannot redeem/burn shares of any holder without allowance
    function test_3_attacker_cannot_redeem_others() public {
        address[4] memory vs = [USDC_PRIME, WETH_PRIME, CBBTC_PRIME, USDC_FRONTIER];
        for (uint256 i; i < 4; ++i) {
            uint256 bal = IVaultV2(vs[i]).balanceOf(H_9E28);
            assertGt(bal, 0, "holder has no shares");
            assertEq(IERC20(vs[i]).allowance(H_9E28, attacker), 0, "unexpected allowance");
            vm.prank(attacker);
            vm.expectRevert();
            IVaultV2(vs[i]).redeem(bal, attacker, H_9E28);
        }
    }

    // ---------------------------------------------------------------- 4
    /// @notice attacker's donation to the vault increases share price for holders; attacker gains nothing
    function test_4_donation_no_gain() public {
        deal(USDC, attacker, 20_000e6);
        uint256 preAttacker = IERC20(USDC).balanceOf(attacker);
        uint256 preAssets = IVaultV2(USDC_PRIME).totalAssets();
        uint256 prePrice = IVaultV2(USDC_PRIME).convertToAssets(1e18);

        vm.prank(attacker);
        IERC20(USDC).transfer(USDC_PRIME, 10_000e6);

        assertEq(IERC20(USDC).balanceOf(attacker), preAttacker - 10_000e6);
        assertGt(IVaultV2(USDC_PRIME).totalAssets(), preAssets, "donation not recognised");
        assertEq(IVaultV2(USDC_PRIME).balanceOf(attacker), 0, "attacker must hold no shares");
        // share price went UP for holders; attacker cannot claim any of it
        assertGt(IVaultV2(USDC_PRIME).convertToAssets(1e18), prePrice, "share price must not fall");
    }

    // ---------------------------------------------------------------- 5
    /// @notice forceDeallocate is permissionless, penalty is 0, and it cannot send funds anywhere but the vault
    function test_5_forceDeallocate_permissionless_no_theft() public {
        address adapter = IVaultV2(USDC_PRIME).liquidityAdapter();
        assertEq(IVaultV2(USDC_PRIME).forceDeallocatePenalty(adapter), 0, "penalty != 0");
        bytes memory data = IVaultV2(USDC_PRIME).liquidityData();

        uint256 preAttacker = IERC20(USDC).balanceOf(attacker);
        uint256 preVaultIdle = IERC20(USDC).balanceOf(USDC_PRIME);
        uint256 preVaultAssets = IVaultV2(USDC_PRIME).totalAssets();

        vm.prank(attacker);
        IVaultV2(USDC_PRIME).forceDeallocate(adapter, data, 1_000e6, attacker);

        assertEq(IERC20(USDC).balanceOf(attacker), preAttacker, "attacker must not receive assets");
        assertEq(IERC20(USDC).balanceOf(USDC_PRIME), preVaultIdle + 1_000e6, "assets must land in the vault");
        assertApproxEqAbs(IVaultV2(USDC_PRIME).totalAssets(), preVaultAssets, 5, "totalAssets must be ~unchanged");
    }

    // ---------------------------------------------------------------- 6
    /// @notice every live holder can exit (H-O): direct redeem, or forceDeallocate-to-idle + redeem
    function test_6_holders_can_exit() public {
        _tryExit(USDC_PRIME, H_9E28, "usdc_prime");
        _tryExit(WETH_PRIME, H_6280, "weth_prime");
        _tryExit(CBBTC_PRIME, H_9E28, "cbbtc_prime");
        _tryExit(USDC_FRONTIER, H_6280, "usdc_frontier");
    }

    function _tryExit(address vault, address holder, string memory name) internal {
        uint256 shares = IVaultV2(vault).balanceOf(holder);
        if (shares == 0) return;
        uint256 quoted = IVaultV2(vault).previewRedeem(shares);
        emit log_named_string("exit", name);
        emit log_named_uint("  shares", shares);
        emit log_named_uint("  quoted assets", quoted);

        vm.prank(holder);
        try IVaultV2(vault).redeem(shares, holder, holder) returns (uint256 got) {
            emit log_named_uint("  direct redeem OK, assets", got);
            return;
        } catch {
            emit log_string("  direct redeem reverted (liquidity); using forceDeallocate unstick");
        }

        // permissionless unstick: pull enough liquidity from adapter markets to the vault idle balance
        address adapter = IVaultV2(vault).liquidityAdapter();
        uint256 needed = quoted + quoted / 1000; // 0.1% buffer against accrual between calls
        uint256 idx;
        uint256 guard;
        while (needed > 0 && guard++ < 8) {
            uint256 n = IAdapter(adapter).marketIdsLength();
            if (idx >= n) break;
            bytes32 id = IAdapter(adapter).marketIds(idx);
            uint256 avail = IAdapter(adapter).expectedSupplyAssets(id);
            uint256 liq = _marketLiquidity(id);
            uint256 take = avail < needed ? avail : needed;
            if (take > liq) take = liq;
            if (take == 0) { idx++; continue; }
            MarketParams memory p = _mkParams(id);
            // anyone (attacker) can push liquidity to the vault idle balance
            vm.prank(attacker);
            IVaultV2(vault).forceDeallocate(adapter, abi.encode(p), take, holder);
            needed -= take;
        }
        uint256 bal2 = IVaultV2(vault).balanceOf(holder);
        vm.prank(holder);
        uint256 got2 = IVaultV2(vault).redeem(bal2, holder, holder);
        emit log_named_uint("  redeem after unstick, assets", got2);
        assertEq(IVaultV2(vault).balanceOf(holder), 0, "holder should be fully exited");
    }

    // ---------------------------------------------------------------- 7
    /// @notice V1 MetaMorpho vaults: skim is blocked (skimRecipient == 0); balances are 99%+ burned
    function test_7_v1_skim_blocked_and_burned() public {
        (bool ok, ) = USDC_V1.call(abi.encodeWithSignature("skim(address)", USDC));
        assertFalse(ok, "skim must revert (skimRecipient == 0)");
        // most supply burned
        uint256 dead = IERC20(USDC_V1).balanceOf(0x000000000000000000000000000000000000dEaD);
        uint256 supply = IERC20(USDC_V1).totalSupply();
        assertGt(dead * 100 / supply, 90, "usdc_v1 should be mostly burned");
    }

    // ---------------------------------------------------------------- 8
    /// @notice main oracles are Chainlink push feeds (not spot-manipulable)
    function test_8_oracles_are_chainlink() public {
        // MorphoChainlinkOracleV2 wrapper for USDC/cbBTC on USDC Prime
        address oracle = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
        // its base feed (Chainlink cbBTC/USD aggregator on Base)
        address feed = 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F;
        (uint80 roundId, int256 answer,, uint256 updatedAt,) = IChainlinkFeed(feed).latestRoundData();
        assertGt(roundId, 0, "roundId");
        assertGt(answer, 0, "answer");
        assertGt(updatedAt, 0, "updatedAt");
        assertGt(feed.code.length, 0, "feed must be a contract");
        emit log_named_int("cbBTC/USD feed answer", answer);
        emit log_named_uint("cbBTC/USD updatedAt", updatedAt);
        // oracle wrapper is also a contract and reports a price
        (bool ok, bytes memory ret) = oracle.staticcall(abi.encodeWithSignature("price()"));
        assertTrue(ok, "oracle.price() must succeed");
        assertGt(abi.decode(ret, (uint256)), 0);
    }

    // ---------------------------------------------------------------- 9
    /// @notice pending timelocked actions: read and (on fork) show that execution is permissionless post-timelock
    function test_9_pending_actions() public {
        // setSendAssetsGate(address(0)) calldata submitted by curator (blk 52230943)
        bytes memory data = abi.encodeWithSignature("setSendAssetsGate(address)", address(0));
        uint256 execAt = IVaultV2(USDC_PRIME).executableAt(data);
        emit log_named_uint("setSendAssetsGate(0) executableAt", execAt);
        emit log_named_uint("now", block.timestamp);
        if (execAt != 0) {
            assertGt(execAt, block.timestamp, "should still be timelocked");
            // permissionless execution after the timelock (attacker == arbitrary caller)
            vm.warp(execAt);
            vm.prank(attacker);
            IVaultV2(USDC_PRIME).setSendAssetsGate(address(0)); // succeeds -> deposit gate removed
            assertTrue(IVaultV2(USDC_PRIME).canSendAssets(attacker), "deposits open after execution");
        }
        // setForceDeallocatePenalty(adapter, 1e13) also pending (blk 52231106)
        address adapter = IVaultV2(USDC_PRIME).liquidityAdapter();
        bytes memory data2 = abi.encodeWithSignature("setForceDeallocatePenalty(address,uint256)", adapter, 1e13);
        uint256 execAt2 = IVaultV2(USDC_PRIME).executableAt(data2);
        emit log_named_uint("setForceDeallocatePenalty(1e13) executableAt", execAt2);
        if (execAt2 != 0) assertGt(execAt2, block.timestamp, "penalty change should be timelocked");
    }
}
