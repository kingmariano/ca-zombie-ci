// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/*
 * H2-02 / altura — NavVault (HyperEVM chain 999) fork tests.
 *
 * Purpose: prove, on a fork of live HyperEVM state pinned at block 48,164,864,
 * that an external unprivileged attacker cannot extract value from NavVault,
 * and record the exact gates that block every candidate path.
 *
 * ALL tests are read-only against the real chain: they run on a local fork via forge.
 * No mainnet transactions are ever signed or sent.
 *
 * Live state anchored at fork block 48,164,864 (2026-10-10):
 *   vault  = 0xd0Ee0CF300DFB598270cd7F4D0c6E0D8F6e13f29
 *   oracle = 0x314A79618d86309e91aa972CAfd143ffca80AE8F
 *   asset  = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb (USD₮0, 6 decimals)
 *   totalAssets = 32,437,234.873245 USD₮0 ; totalSupply = 29,636,794,853,910 raw shares
 *   oracle pps  = 1.094492929356520704e18 ; vault USD₮0 balance = 8 (micro-units)
 *   exitFeeBps = 10 ; maxAllowedStaleness = 86,400 ; epochSeconds = 259,200
 *
 * Amount model (verified on-chain):
 *   convertToShares(1e6 atoms = $1) = floor(1e12 / 1,094,492) = 913,666 raw shares
 *   convertToAssets(escrow)         = escrow * 1,094,492 / 1e6 atoms
 */

interface INavVault {
    function asset() external view returns (address);
    function name() external view returns (string memory);
    function navOracle() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function queueWithdrawal(uint256 shares, address receiver) external returns (uint256);
    function claimWithdrawal(uint256 id) external;
    function cancelWithdrawal(uint256 id) external;
    function fundLiquidity(uint256 assets) external;
    function moveAssets(uint256 assets_) external;
    function sweepExitFees(address to, uint256 amountAssets) external;
    function rescueToken(address token, address to, uint256 amount) external;
    function pause() external;
    function unpause() external;
    function setExitFeeBps(uint16 bps) external;
    function setMaxAllowedStaleness(uint256 secs) external;
    function setEpochSeconds(uint256 secs) external;
    function setLiquidityRecipient(address newRecipient) external;
    function queueOracleUpdate(address newOracle) external;
    function executeOracleUpdate() external;
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function exitFeeBps() external view returns (uint16);
    function accruedExitFeesAssets() external view returns (uint256);
    function maxAllowedStaleness() external view returns (uint256);
    function epochSeconds() external view returns (uint256);
    function paused() external view returns (bool);
    function nextRequestId() external view returns (uint256);
    function liquidityRecipient() external view returns (address);
    function pendingOracle() external view returns (address);
    function requests(uint256 id)
        external
        view
        returns (address owner, address receiver, uint128 sharesEscrow, uint64 requestedAt, uint64 claimableAt, bool closed);
}

interface INavOracle {
    function pricePerShare() external view returns (uint256, uint256);
    function isValid() external view returns (bool);
    function maxOracleStaleness() external view returns (uint256);
    function maxPpsMoveBps() external view returns (uint256);
    function paused() external view returns (bool);
    function reportNav(uint256 pps1e18, uint256 ts) external;
    function pause() external;
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function VERSION() external view returns (string memory);
}

contract NavVaultTest is Test {
    // ---- live addresses (HyperEVM, chain 999) ----
    address constant VAULT = 0xd0Ee0CF300DFB598270cd7F4D0c6E0D8F6e13f29;
    address constant ORACLE = 0x314A79618d86309e91aa972CAfd143ffca80AE8F;
    address constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address constant SAFE = 0x2Ae5173dcd5B5c29DcEAC77ee767f01D2bF0F832; // DEFAULT_ADMIN vault+oracle (2/3 Safe)
    address constant OPS = 0x03987D5FA639023904378614537aC4FAFE1f8813; // OPERATOR vault / GUARDIAN oracle (EOA)
    address constant GUARDIAN = 0xfF0C2fBA221cBC1011b294e3803851EE9dF009ef; // GUARDIAN vault (EOA)
    address constant REPORTER = 0xc55e3De9085732317eFcfd729d254B8bff7f7Ad2; // REPORTER oracle (EOA)
    address constant FUNDER = 0xFA9573D1B2e5db5BC9588f71D27832BcdD027271; // observed JIT liquidity EOA

    uint256 constant FORK_BLOCK = 48_164_864;
    uint256 constant PPS = 1_094_492_929_356_520_704; // oracle pps at fork block
    uint256 constant TOTAL_ASSETS = 32_437_234_873_245;
    uint256 constant TOTAL_SUPPLY = 29_636_794_853_910;

    // USD₮0 proxy: ERC20Upgradeable `_balances` mapping (OZ v4 layout) lives at storage slot 51
    // (verified by probing keccak256(abi.encode(addr, slot)) against balanceOf at the fork block).
    uint256 constant USDT0_BALANCES_SLOT = 51;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    INavVault vault;
    INavOracle oracle;
    IERC20 usdt;
    address player;
    address player2;

    function setUp() public {
        string memory rpc = vm.envOr("HYPEREVM_RPC_URL", string("https://rpc.hyperliquid.xyz/evm"));
        vm.createSelectFork(rpc, FORK_BLOCK);
        vault = INavVault(VAULT);
        oracle = INavOracle(ORACLE);
        usdt = IERC20(USDT0);
        player = makeAddr("player");
        player2 = makeAddr("player2");
        vm.deal(player, 10 ether);
        vm.deal(player2, 10 ether);

        // The live JIT-funding EOA only holds ~$2.55 at the pinned block (the vault's on-chain
        // liquidity really is dust). Give it working capital on the FORK ONLY so tests can move
        // meaningful amounts; this is a cheatcode-local state change, never sent anywhere.
        vm.store(
            USDT0,
            keccak256(abi.encode(FUNDER, USDT0_BALANCES_SLOT)),
            bytes32(uint256(20_000_000e6))
        );
        assertEq(usdt.balanceOf(FUNDER), 20_000_000e6, "fork funding setup");
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    /// USD₮0 source: the EOA seen JIT-funding exits on-chain (topped up on the fork in setUp).
    function _fund(address to, uint256 amount) internal {
        vm.prank(FUNDER);
        usdt.transfer(to, amount);
    }

    /// Refresh the oracle at the current (possibly warped) timestamp, impersonating the live reporter.
    function _refreshOracle() internal {
        (uint256 pps,) = oracle.pricePerShare();
        vm.prank(REPORTER);
        oracle.reportNav(pps, block.timestamp);
    }

    /// Deposit `amount` USD₮0 as `who` and return minted shares.
    function _deposit(address who, uint256 amount) internal returns (uint256 shares) {
        _fund(who, amount);
        vm.prank(who);
        usdt.approve(VAULT, type(uint256).max);
        vm.prank(who);
        shares = vault.deposit(amount, who);
    }

    // ------------------------------------------------------------------
    // A. live-state snapshot (fork = ground truth)
    // ------------------------------------------------------------------

    function test_A_liveState_snapshot() public {
        assertEq(vault.asset(), USDT0, "asset");
        assertEq(vault.navOracle(), ORACLE, "oracle");
        assertEq(vault.name(), "Altura Vault Tokens", "name");
        assertEq(vault.totalAssets(), TOTAL_ASSETS, "totalAssets");
        assertEq(vault.totalSupply(), TOTAL_SUPPLY, "totalSupply");
        (uint256 pps,) = oracle.pricePerShare();
        assertEq(pps, PPS, "pps");
        assertEq(vault.exitFeeBps(), 10, "exitFeeBps");
        assertEq(vault.maxAllowedStaleness(), 86_400, "maxAllowedStaleness");
        assertEq(vault.epochSeconds(), 259_200, "epochSeconds");
        assertEq(vault.paused(), false, "paused");
        assertEq(oracle.paused(), false, "oraclePaused");
        assertEq(oracle.maxPpsMoveBps(), 0, "no oracle move cap");
        assertEq(vault.pendingOracle(), address(0), "no pending oracle");

        uint256 vaultBal = usdt.balanceOf(VAULT);
        emit log_named_uint("vault USDt0 balance (micro)", vaultBal);
        assertEq(vaultBal, 8, "vault holds 8 micro-USDT0");

        // not a proxy: no EIP-1967 impl/admin/beacon slots
        assertEq(uint256(vm.load(VAULT, 0x360894A13BA1A3210667C828492db98DCA3e2076cc3735a920a3ca505d382bbc)), 0, "impl slot");
        assertEq(uint256(vm.load(VAULT, 0xB53127684A568b3173ae13B9F8A6016e243E63B6e8ee1178d6a717850b5d6103)), 0, "admin slot");
        assertEq(uint256(vm.load(VAULT, 0xa3F0aD74e5423AEBfD80D3eF4346578335a9A72aeaee59ff6cb3582b35133d50)), 0, "beacon slot");

        // roles
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, SAFE));
        assertFalse(vault.hasRole(DEFAULT_ADMIN_ROLE, player));
        assertTrue(vault.hasRole(OPERATOR_ROLE, OPS));
        assertTrue(vault.hasRole(OPERATOR_ROLE, SAFE));
        assertTrue(vault.hasRole(GUARDIAN_ROLE, GUARDIAN));
        assertFalse(vault.hasRole(OPERATOR_ROLE, player));
        assertTrue(oracle.hasRole(DEFAULT_ADMIN_ROLE, SAFE));
        assertTrue(oracle.hasRole(REPORTER_ROLE, REPORTER));
        assertFalse(oracle.hasRole(REPORTER_ROLE, player));

        // admin is a 2-of-3 Gnosis Safe v1.3.0
        assertEq(ISafe(SAFE).getThreshold(), 2, "safe threshold");
        assertEq(ISafe(SAFE).getOwners().length, 3, "safe owners");
        assertEq(ISafe(SAFE).VERSION(), "1.3.0", "safe version");

        emit log_named_uint("totalAssets", vault.totalAssets());
        emit log_named_uint("totalSupply", vault.totalSupply());
        emit log_named_uint("convertToAssets(1e18 shares)", vault.convertToAssets(1e18));
        emit log_named_uint("convertToShares(1e6 = $1)", vault.convertToShares(1e6));
        emit log_named_uint("accruedExitFeesAssets", vault.accruedExitFeesAssets());
        emit log_named_uint("nextRequestId", vault.nextRequestId());
        emit log_named_uint("escrowed shares (AVLT held by vault)", IERC20(VAULT).balanceOf(VAULT));
    }

    // ------------------------------------------------------------------
    // B. instant withdraw/redeem: hard-capped by the vault's USD₮0 balance
    // ------------------------------------------------------------------

    function test_B1_freshAttacker_roundTrip_isNetNegative() public {
        uint256 b0 = usdt.balanceOf(VAULT);
        assertEq(b0, 8, "pinned block vault balance");

        // attacker deposits the smallest amount that mints shares: 9 atoms -> 8 shares
        _fund(player, 9);
        vm.prank(player);
        usdt.approve(VAULT, type(uint256).max);
        vm.prank(player);
        uint256 shares = vault.deposit(9, player);
        assertEq(shares, 8, "floor(9e6/ppsScaled)=8 shares");
        assertEq(usdt.balanceOf(player), 0, "attacker spent all capital");

        // extract: 7 atoms is the max single net payout against gross<=balance (fee=1)
        vm.prank(player);
        uint256 burned = vault.withdraw(7, player, player);
        assertEq(burned, 8, "burns 8 shares");
        assertEq(usdt.balanceOf(player), 7, "attacker received 7 atoms");
        assertEq(usdt.balanceOf(VAULT), 10, "vault balance b0+9-7");

        // fresh-attacker round trip is strictly value-destructive: 9 in, 7 out
        assertLt(usdt.balanceOf(player), 9, "net negative for unprivileged attacker");
        emit log_named_uint("attacker result micro (spent 9, got)", usdt.balanceOf(player));
    }

    function test_B2_vaultCannotBeFullyDrained_feeRounding() public {
        uint256 b0 = usdt.balanceOf(VAULT);
        uint256 d = 1_001_000e6;
        _deposit(player, d);
        uint256 ba = usdt.balanceOf(VAULT); // d + b0

        // withdrawing MORE than the vault holds is impossible (gross = net + ceil(fee))
        vm.prank(player);
        vm.expectRevert();
        vault.withdraw(ba, player, player);

        // max net the fee math allows for a holder of `d` assets (safety margin for ceil rounding)
        uint256 netMax = (d * 9_990) / 10_000;
        if (netMax > 20) netMax -= 10;
        uint256 before = usdt.balanceOf(player);
        vm.prank(player);
        vault.withdraw(netMax, player, player);
        assertEq(usdt.balanceOf(player) - before, netMax, "pays exactly netMax");
        assertGe(usdt.balanceOf(VAULT), b0 + 1, "vault never fully drained (fees/residue stay)");
        emit log_named_uint("withdrew (micro)", netMax);
        emit log_named_uint("vault after (micro)", usdt.balanceOf(VAULT));
    }

    function test_B3_redeem_boundedByVaultLiquidity_afterOperatorMovesFunds() public {
        uint256 shares = _deposit(player, 1_000_000e6);
        // operator moves the deposits out to the liquidity recipient (as observed live),
        // keeping only the booked accrued fees + dust in the vault
        uint256 accrued = vault.accruedExitFeesAssets();
        uint256 mov = usdt.balanceOf(VAULT) - accrued;
        vm.prank(OPS);
        vault.moveAssets(mov);

        uint256 b0 = usdt.balanceOf(VAULT);
        uint256 want = vault.convertToAssets(shares); // ~1,000,000e6 >> b0
        assertGt(want, b0, "claim exceeds live liquidity");
        vm.prank(player);
        vm.expectRevert();
        vault.redeem(shares, player, player);
        emit log_named_uint("nominal redeem value (micro)", want);
        emit log_named_uint("live vault liquidity (micro)", b0);
    }

    // ------------------------------------------------------------------
    // C. queue -> claim: gate is operator-funded liquidity (+oracle freshness)
    // ------------------------------------------------------------------

    /// Real open request #5255 on the fork: owner 0xc427..., escrow 92,484,180 raw shares (~$101).
    function test_C_realQueuedRequest_cannotClaim_untilFunded() public {
        (address owner,, uint128 escrow,, uint64 claimableAt, bool closed) = vault.requests(5255);
        assertEq(owner, 0xc42786E4E2eC75E50A442036842318052E848e7D);
        assertGt(uint256(escrow), 0);
        assertFalse(closed);
        assertLe(claimableAt, block.timestamp, "already past claimableAt");

        uint256 fullAssets = vault.convertToAssets(escrow);
        uint256 live = usdt.balanceOf(VAULT);
        assertGt(fullAssets, live, "claim value >> live liquidity");
        emit log_named_uint("request 5255 claim value (micro)", fullAssets);
        emit log_named_uint("vault live liquidity (micro)", live);

        // 1) claim reverts: vault holds ~8 micro-USD₮0
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLiquidity()"));
        vault.claimWithdrawal(5255);

        // 2) operator funds liquidity just-in-time (as observed on-chain)...
        _fund(VAULT, fullAssets + 1e6);

        // 3) ...then the holder's claim succeeds at full NAV, NO exit fee on the queue path
        uint256 before = usdt.balanceOf(owner);
        vm.prank(owner);
        vault.claimWithdrawal(5255);
        uint256 got = usdt.balanceOf(owner) - before;
        assertEq(got, fullAssets, "queue path pays full NAV (no fee)");
        (,,,,, closed) = vault.requests(5255);
        assertTrue(closed);
        emit log_named_uint("claim paid (micro)", got);
    }

    function test_C2_claim_revertsWhenOracleStale() public {
        uint256 shares = _deposit(player, 2_000e6);
        vm.prank(player);
        IERC20(VAULT).approve(VAULT, type(uint256).max);
        vm.prank(player);
        uint256 id = vault.queueWithdrawal(shares, player);
        (,,,, uint64 claimableAt,) = vault.requests(id);

        _fund(VAULT, 2_000_000e6); // liquidity present

        vm.warp(claimableAt + 2 days); // no report for >1 day -> oracle stale
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OracleStale()"));
        vault.claimWithdrawal(id);
    }

    // ------------------------------------------------------------------
    // D. escrow theft / foreign-claim paths — closed
    // ------------------------------------------------------------------

    function test_D_stealEscrowShares_isClosed() public {
        // player queues shares -> escrow sits at the vault contract
        uint256 shares = _deposit(player, 1_000e6);
        vm.prank(player);
        IERC20(VAULT).approve(VAULT, type(uint256).max);
        vm.prank(player);
        vault.queueWithdrawal(shares, player);

        // attacker tries to burn the vault's escrowed shares via owner=vault
        _deposit(player2, 1_000e6);

        vm.prank(player2);
        vm.expectRevert(); // no allowance(vault -> attacker)
        vault.withdraw(100e6, player2, VAULT);

        vm.prank(player2);
        vm.expectRevert();
        vault.redeem(100e18, player2, VAULT);
    }

    function test_D2_claimForeignRequest_reverts() public {
        // request #5255 exists at fork block, owned by 0xc42786E4E2eC75E50A442036842318052E848e7D
        (address owner,, uint128 escrow,,, bool closed) = vault.requests(5255);
        assertEq(owner, 0xc42786E4E2eC75E50A442036842318052E848e7D);
        assertGt(uint256(escrow), 0);
        assertFalse(closed);
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("NotOwner()"));
        vault.claimWithdrawal(5255);
    }

    function test_D3_queueCancel_roundTrip_neutral() public {
        uint256 shares = _deposit(player, 1_000e6);
        vm.prank(player);
        IERC20(VAULT).approve(VAULT, type(uint256).max);
        vm.prank(player);
        uint256 id = vault.queueWithdrawal(shares, player);
        assertEq(IERC20(VAULT).balanceOf(player), 0);

        vm.prank(player);
        vault.cancelWithdrawal(id);
        assertEq(IERC20(VAULT).balanceOf(player), shares, "exactly the escrowed shares returned");
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("RequestClosed()"));
        vault.cancelWithdrawal(id);
    }

    // ------------------------------------------------------------------
    // E. donation cannot inflate NAV (oracle-based accounting)
    // ------------------------------------------------------------------

    function test_E_donation_doesNotInflateNAV() public {
        uint256 ta0 = vault.totalAssets();
        uint256 cts0 = vault.convertToShares(1_000e6);
        uint256 cta0 = vault.convertToAssets(1e18);
        uint256 bal0 = usdt.balanceOf(VAULT);

        // unprivileged donation via fundLiquidity
        _fund(player, 3_000e6);
        vm.prank(player);
        usdt.approve(VAULT, type(uint256).max);
        vm.prank(player);
        vault.fundLiquidity(2_000e6);

        assertEq(vault.totalAssets(), ta0, "NAV unchanged by donation");
        assertEq(vault.convertToShares(1_000e6), cts0, "share price unchanged");
        assertEq(vault.convertToAssets(1e18), cta0, "asset value unchanged");
        assertEq(usdt.balanceOf(VAULT), bal0 + 2_000e6, "only raw liquidity increases");

        // no first-depositor / donation inflation vector: totalAssets is oracle-driven,
        // never balance-driven, so shares can never be bought below NAV via donation games.
        uint256 shares = vault.convertToShares(1_000e6);
        vm.prank(player);
        uint256 minted = vault.deposit(1_000e6, player);
        assertEq(minted, shares, "deposit gets exactly the pre-donation quote");
    }

    // ------------------------------------------------------------------
    // F. rounding always favours the vault
    // ------------------------------------------------------------------

    function test_F_rounding_directions() public {
        uint256 ppsScaled = PPS / 1e12; // 1,094,492 asset atoms per 1e18 shares
        uint256 gross1e18 = (1e18 * ppsScaled) / 1e6;

        // convertToAssets(convertToShares(x)) <= x  (floor-floor never creates assets)
        assertLe(vault.convertToAssets(vault.convertToShares(1_234_567)), 1_234_567);
        // redeem payout floors and pays fee: strictly below gross NAV
        assertLt(vault.previewRedeem(1e18), gross1e18);
        assertGt(vault.previewRedeem(1e18), (gross1e18 * 99) / 100);
        // withdraw needs ceil shares: shares are worth at least the requested amount
        uint256 sharesForWithdraw = vault.previewWithdraw(1_000_000);
        assertGe((sharesForWithdraw * ppsScaled) / 1e6, 1_000_000);
    }

    // ------------------------------------------------------------------
    // G. every privileged / value-moving entrypoint reverts for an attacker
    // ------------------------------------------------------------------

    function test_G_allPrivilegedEntrypoints_revertForAttacker() public {
        vm.startPrank(player);

        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, OPERATOR_ROLE));
        vault.moveAssets(1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.sweepExitFees(player, 1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.rescueToken(USDT0, player, 1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, GUARDIAN_ROLE));
        vault.pause();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, GUARDIAN_ROLE));
        vault.unpause();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, OPERATOR_ROLE));
        vault.setExitFeeBps(0);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, OPERATOR_ROLE));
        vault.setMaxAllowedStaleness(1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.setEpochSeconds(1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.setLiquidityRecipient(player);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.queueOracleUpdate(player);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.executeOracleUpdate();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, DEFAULT_ADMIN_ROLE));
        vault.grantRole(OPERATOR_ROLE, player);

        vm.stopPrank();

        // oracle paths
        vm.prank(player);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, REPORTER_ROLE)
        );
        oracle.reportNav(2e18, block.timestamp);

        vm.prank(player);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", player, GUARDIAN_ROLE)
        );
        oracle.pause();
    }

    // ------------------------------------------------------------------
    // H. privileged ops are capped/timelocked; even admin cannot mint value
    //    from the empty vault
    // ------------------------------------------------------------------

    function test_H1_adminCaps_andOracleTimelock() public {
        // operator cannot raise staleness window beyond oracle's cap
        vm.prank(OPS);
        vm.expectRevert(abi.encodeWithSignature("OracleStale()"));
        vault.setMaxAllowedStaleness(200_000);

        vm.prank(OPS);
        vault.setMaxAllowedStaleness(43_200);
        assertEq(vault.maxAllowedStaleness(), 43_200);
        vm.prank(OPS);
        vault.setMaxAllowedStaleness(86_400);

        // operator cannot set exit fee above 200 bps
        vm.prank(OPS);
        vm.expectRevert("fee:too_high");
        vault.setExitFeeBps(201);

        // oracle swap is admin (2/3 Safe) AND 1-day timelocked
        vm.prank(SAFE);
        vault.queueOracleUpdate(address(0xBEEF));
        assertEq(vault.pendingOracle(), address(0xBEEF));
        vm.prank(SAFE);
        vm.expectRevert("Oracle update timelocked");
        vault.executeOracleUpdate();
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(SAFE);
        vault.executeOracleUpdate();
        assertEq(vault.navOracle(), address(0xBEEF));
    }

    function test_H2_adminSweepAndMoveAssets_blockedByLiquidity() public {
        // accrued fees (26,911e6) exceed the vault's balance (8 micro): even admin cannot sweep
        assertGt(vault.accruedExitFeesAssets(), usdt.balanceOf(VAULT));
        vm.prank(SAFE);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLiquidity()"));
        vault.sweepExitFees(SAFE, 1_000e6);

        // operator cannot move liquidity the vault does not have
        vm.prank(OPS);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLiquidity()"));
        vault.moveAssets(1_000e6);
    }

    // ------------------------------------------------------------------
    // I. stale oracle blocks deposits/withdrawals/redeems (liveness gate)
    // ------------------------------------------------------------------

    function test_I_staleOracle_blocksMoneyFlows_butEscrowSurvives() public {
        uint256 shares = _deposit(player, 1_000e6);
        vm.prank(player);
        IERC20(VAULT).approve(VAULT, type(uint256).max);

        vm.warp(block.timestamp + 2 days); // no NavReported for > maxAllowedStaleness

        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OracleStale()"));
        vault.withdraw(1, player, player);

        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OracleStale()"));
        vault.redeem(shares, player, player);

        _fund(player, 1_000e6);
        vm.prank(player);
        usdt.approve(VAULT, type(uint256).max);
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSignature("OracleStale()"));
        vault.deposit(1_000e6, player);

        // queue/cancel need no oracle: escrow is not bricked
        vm.prank(player);
        uint256 id = vault.queueWithdrawal(shares, player);
        vm.prank(player);
        vault.cancelWithdrawal(id);
        assertEq(IERC20(VAULT).balanceOf(player), shares);
    }

    // ------------------------------------------------------------------
    // J. conditional JIT yield-sniping demo (fork accounting only; NOT a live path)
    // ------------------------------------------------------------------

    /*
     * Demonstrates what WOULD happen if an attacker could (a) acquire shares just
     * before a NavReported() pps increase and (b) exit immediately after through
     * operator-funded liquidity. On the live chain today: (b) is impossible (vault
     * holds 8 micro-USD₮0) and (a) requires the private REPORTER key's tx visibility.
     * Included to quantify the accounting, not as an exploit.
     */
    function test_J_conditional_JITyieldSniping_requiresReporterAndLiquidity() public {
        uint256 shares = _deposit(player, 100_000e6);

        // simulate the reporter pushing pps +1% (impersonation — key required in reality)
        vm.prank(REPORTER);
        oracle.reportNav((PPS * 101) / 100, block.timestamp);

        // simulate operator funding liquidity
        _fund(VAULT, 200_000e6);

        uint256 before = usdt.balanceOf(player);
        vm.prank(player);
        vault.redeem(shares, player, player);
        uint256 got = usdt.balanceOf(player) - before;
        emit log_named_uint("JIT payout for 100k deposit after +1% report (micro)", got);
        assertGt(got, 100_000e6, "captured the +1% report (minus 10bps exit fee)");
        assertLt(got, (100_000e6 * 101) / 100, "<= +1%");
    }

    // ------------------------------------------------------------------
    // K. deposit dust floor (vault-favouring, no free shares)
    // ------------------------------------------------------------------

    function test_K_dust_deposits_mintZeroShares() public {
        _fund(player, 2);
        vm.prank(player);
        usdt.approve(VAULT, type(uint256).max);
        vm.prank(player);
        uint256 s1 = vault.deposit(1, player); // 1*1e6/1,094,492 = 0.91 -> 0 shares
        vm.prank(player);
        uint256 s2 = vault.deposit(1, player); // again 0 (floor per-call)
        assertEq(s1, 0);
        assertEq(s2, 0);
        assertEq(IERC20(VAULT).balanceOf(player), 0, "no free shares from dust");
    }
}
