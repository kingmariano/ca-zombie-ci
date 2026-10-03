// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title C-35 — Old chain/contract resurgences: live unprivileged-extractability sweep
/// @notice Fork-only, read-only boundary tests. Nothing is signed or sent to mainnet.
///         Every call runs against a throwaway Foundry fork of Ethereum mainnet.
///
/// Targets (see c-35/README.md):
///   - HongCoin 2016 ICO 0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9 (whitehat unlock 2026-05-27)
///   - Liquality 2018 ICO + 7 atomic-swap HTLCs (whitehat rescue 2026-05-24)
///   - the top live-ETH legacy contracts from github_stuck_funds.md §1.1 / §6, and the
///     focus list (FoMo3D Ultra, CryptoCats, Transit, Zethr, Bingo4Beast dep2,
///     DailyDivs / ReadyPlayerONE, FEG fETH, F3D-family clones).
///
/// Tests assert that a fresh, unprivileged EOA gains 0 ETH from every candidate path,
/// and document exact live balances / reverts. Holder-only (H-O) paths are proven
/// separately (HongCoin holder refund; Liquality HTLC pays its hardcoded beneficiary).
contract C35SweepTest is Test {
    // ---------------------------------------------------------------- targets
    address constant HONG = 0x9Fa8fA61A10Ff892E4EBCeB7f4e0FC684C2ce0a9;
    address constant HONG_HOLDER = 0x30d1F87561AF86d5AB7b9ec04E65607fab61833D; // 0.07 ETH, unclaimed
    address constant LIQ_HTLC_1 = 0x65F8e16DA4c980983391b737c38f4483D8a7Cc63;
    address constant LIQ_HTLC_2 = 0x597f71dB673813AD3A88414b1c16CDB42815f27E;
    address constant LIQ_HTLC_3 = 0x623b7424cD449AfA11F30FCdb1d13b2A70BE3B7C;
    address constant LIQ_HTLC_4 = 0x491eF9D4f7dE298Bd211c18d7A814Db61E2fbC40;
    address constant LIQ_HTLC_5 = 0x6FEE36E265ccC282F2B27F384191121efBb05ca1;
    address constant LIQ_HTLC_6 = 0x8618C63A8Be97825851b1b4269AeB4C66300f6D2;
    address constant LIQ_HTLC_7 = 0xCE6E31f8FcB9d458861A8D1AC95f4D33a797C1b6;
    address constant LIQ_ICO_2018 = 0xf8602DfA933a34D513e6e1aAB3F3cc6861254D51;
    address constant LIQ_HTLC_1_BENEF = 0x3a712CC47aeb0F20A7C9dE157c05d74B11F172f5;
    address constant ULTRA = 0xAb83D96de35bAD6F234178FBb6507203488E9626;
    address constant F3D_LONG = 0xA62142888ABa8370742bE823c1782D17A0389Da1;
    address constant CRYPTOCATS = 0x9508008227b6b3391959334604677d60169EF540;
    address constant TRANSIT = 0xc213f258f4142f53d086f9eDb7A36E67eb347F63;
    address constant ZETHR = 0xD48B633045af65fF636F3c6edd744748351E020D;
    address constant ZETHR_CASINO = 0xb9ab8Eed48852DE901C13543042204c6C569B811;
    address constant DAILYDIVS = 0xd2bfCEeaB8FFa24cDF94FaA2683Df63DF4bCBdC8;
    address constant RPO = 0x6DB943251E4126F913e9733821031791e75dF713;
    address constant FEG = 0xf786c34106762Ab4Eeb45a51B42a62470E9D5332;
    address constant BINGO2 = 0x4Fb7D68E0116f35aDe131B6535B2DB1027BF7650;
    address constant ZKSYNC = 0x0a14B696350546110a0D8acDb86226983af9D2a0;
    address constant IDEX = 0x2a0c0DBEcC7E4D658f48E01e3fA353F44050c208;
    address constant ED2 = 0x8d12A197cB00D4747a1fe03395095ce2A5CC6819;
    address constant UNKNOWN_DEX = 0x4D55F76Ce2dBBAE7B48661bef9bD144Ce0C9091b;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    address constant ATK = 0x000000000000000000000000000000000000a11c;
    address constant ATK2 = 0x000000000000000000000000000000000000B0b2;

    string rpc;
    uint256 mainFork;

    function setUp() public {
        rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        mainFork = vm.createSelectFork(rpc);
        vm.deal(ATK, 1 ether);
        vm.deal(ATK2, 1 ether);
    }

    // ---------------------------------------------------------------- helpers
    function bal(address a) internal view returns (uint256) {
        return a.balance;
    }

    /// @dev Try every supplied selector from ATK with zero value; return total ETH gained by ATK.
    function shotgun(address target, bytes4[] memory sels) internal returns (int256 gained, uint256 successes) {
        uint256 before = bal(ATK);
        for (uint256 i = 0; i < sels.length; i++) {
            vm.prank(ATK);
            (bool ok,) = target.call{gas: 3_000_000}(abi.encodePacked(sels[i]));
            if (ok) successes++;
        }
        gained = int256(bal(ATK)) - int256(before);
        // abi-encodable logging
        emit log_named_int("attacker ETH delta (wei)", gained);
        emit log_named_uint("successful selectors", successes);
    }

    // ---------------------------------------------------------------- 1. snapshot
    function test_01_live_balances_snapshot() public {
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("HONG ETH", bal(HONG));
        emit log_named_uint("Ultra ETH", bal(ULTRA));
        emit log_named_uint("F3D Long ETH", bal(F3D_LONG));
        emit log_named_uint("zkSync distributor ETH", bal(ZKSYNC));
        emit log_named_uint("CryptoCats ETH", bal(CRYPTOCATS));
        emit log_named_uint("Transit ETH", bal(TRANSIT));
        emit log_named_uint("Zethr ETH", bal(ZETHR));
        emit log_named_uint("Bingo2 ETH", bal(BINGO2));
        emit log_named_uint("FEG ETH", bal(FEG));

        assertGt(bal(HONG), 600 ether);
        assertGt(bal(ULTRA), 400 ether);
        assertGt(bal(ZKSYNC), 9_000 ether);
        assertGt(bal(TRANSIT), 100 ether);
    }

    // ---------------------------------------------------------------- 2. HongCoin
    function test_02_hongcoin_attacker_paths_revert() public {
        vm.startPrank(ATK);
        (bool ok1,) = HONG.call(abi.encodeWithSignature("refundMyIcoInvestment()"));
        assertFalse(ok1, "fresh attacker refund must revert (noWeiGiven throw)");
        (bool ok2,) = HONG.call(abi.encodeWithSignature("mgmtIssueBountyToken(address,uint256)", ATK, 1));
        assertFalse(ok2, "mgmtIssueBountyToken must be onlyManagementBody");
        vm.stopPrank();
    }

    function test_03_hongcoin_holder_refund_open_HO() public {
        // The 2026-05 unlock reset eligible holders' token balances so refundMyIcoInvestment()
        // passes the `balances[sender] <= tokensCreated` check. Paying the caller's *own*
        // original weiGiven is H-O: an attacker with no ICO position gets nothing.
        uint256 holderBefore = bal(HONG_HOLDER);
        uint256 hongBefore = bal(HONG);
        vm.prank(HONG_HOLDER);
        (bool ok,) = HONG.call(abi.encodeWithSignature("refundMyIcoInvestment()"));
        assertTrue(ok, "eligible holder refund must succeed");
        uint256 gained = bal(HONG_HOLDER) - holderBefore;
        emit log_named_uint("holder refund gained (wei)", gained);
        assertApproxEqAbs(gained, 0.07 ether, 1e12); // ~0.07 ETH per rentry list
        assertLe(bal(HONG), hongBefore, "HONG balance must not increase");
    }

    // ---------------------------------------------------------------- 3. Liquality
    function test_04_liquality_htlc_permissionless_but_pays_beneficiary() public {
        // All seven live HTLCs are drained after the 2026-05-24 rescue (balance 0; verified in
        // scan). The runtime always pays the *hardcoded beneficiary* embedded at deploy time,
        // not the caller. Replicate HTLC_1's live runtime on the fork to prove that:
        address clone = 0x000000000000000000000000000000000000C10e;
        vm.etch(clone, LIQ_HTLC_1.code);
        vm.deal(clone, 6.674 ether);

        uint256 benefBefore = bal(LIQ_HTLC_1_BENEF);
        uint256 atkBefore = bal(ATK);
        vm.prank(ATK);
        (bool ok,) = clone.call("");
        assertTrue(ok, "permissionless trigger succeeds");
        assertEq(bal(LIQ_HTLC_1_BENEF) - benefBefore, 6.674 ether, "payout -> hardcoded beneficiary");
        assertEq(bal(ATK), atkBefore, "caller gains nothing");

        // and the live contracts are all empty now
        assertEq(LIQ_HTLC_1.balance, 0);
        assertEq(LIQ_HTLC_2.balance, 0);
        assertEq(LIQ_HTLC_3.balance, 0);
        assertEq(LIQ_HTLC_4.balance, 0);
        assertEq(LIQ_HTLC_5.balance, 0);
        assertEq(LIQ_HTLC_6.balance, 0);
        assertEq(LIQ_HTLC_7.balance, 0);
        assertEq(LIQ_ICO_2018.balance, 0);
    }

    // ---------------------------------------------------------------- 4. FoMo3D Ultra
    function test_05_ultra_fresh_attacker_no_gain() public {
        (uint256 pot, uint256 timeLeft) = _ultraViews();
        emit log_named_uint("Ultra airDropPot", pot);
        emit log_named_uint("Ultra timeLeft", timeLeft);

        bytes4[] memory sels = new bytes4[](8);
        sels[0] = 0x3ccfd60b; // withdraw()
        sels[1] = 0x3884d635; // airdrop()
        sels[2] = 0xed78cf4a; // potSwap()
        sels[3] = 0x0f15f4c0; // activate()
        sels[4] = 0x04a817c8; // unknown value-in (reverts "pocket lint")
        sels[5] = 0x07aace5f;
        sels[6] = 0x09502f90;
        sels[7] = 0x23ab750e;
        uint256 cBefore = bal(ULTRA);
        (int256 gained,) = shotgun(ULTRA, sels);
        assertEq(gained, 0, "fresh attacker must gain nothing");
        emit log_named_int("Ultra contract delta (wei)", int256(bal(ULTRA)) - int256(cBefore));
    }

    function _ultraViews() internal view returns (uint256 pot, uint256 timeLeft) {
        (bool ok1, bytes memory r1) = ULTRA.staticcall(abi.encodeWithSelector(0xd87574e0)); // airDropPot_
        if (ok1 && r1.length >= 32) pot = abi.decode(r1, (uint256));
        (bool ok2, bytes memory r2) = ULTRA.staticcall(abi.encodeWithSelector(0xc7e284b8)); // getTimeLeft
        if (ok2 && r2.length >= 32) timeLeft = abi.decode(r2, (uint256));
    }

    // ---------------------------------------------------------------- 5. F3D Long
    function test_06_fomo3d_long_fresh_attacker_no_gain() public {
        bytes4[] memory sels = new bytes4[](4);
        sels[0] = 0x3ccfd60b; // withdraw()
        sels[1] = 0x3884d635; // airdrop()
        sels[2] = 0xed78cf4a; // potSwap()
        sels[3] = 0x0f15f4c0; // activate()
        (int256 gained,) = shotgun(F3D_LONG, sels);
        assertEq(gained, 0, "fresh attacker must gain nothing");
    }

    // ---------------------------------------------------------------- 6. CryptoCats
    function test_07_cryptocats_pending_and_withdraw_zero() public {
        (bool ok, bytes memory r) = CRYPTOCATS.staticcall(abi.encodeWithSelector(0xf3f43703, ATK)); // pendingWithdrawals
        assertTrue(ok);
        assertEq(r.length, 32);
        assertEq(abi.decode(r, (uint256)), 0, "fresh attacker has no pending withdrawal");

        uint256 cBefore = bal(CRYPTOCATS);
        vm.prank(ATK);
        (bool ok2,) = CRYPTOCATS.call{gas: 1_000_000}(abi.encodeWithSelector(0x3ccfd60b)); // withdraw()
        emit log_named_string("cryptocats withdraw success", ok2 ? "yes" : "revert");
        assertEq(bal(ATK), 1 ether, "attacker balance unchanged");
        assertEq(bal(CRYPTOCATS), cBefore, "contract balance unchanged");
    }

    // ---------------------------------------------------------------- 7. Transit
    function test_08_transit_claims_paused_executor_gated() public {
        vm.prank(ATK);
        (bool ok,) = TRANSIT.call(abi.encodeWithSelector(0x4e71d92d)); // claim()
        // claim() selector is 0x4e71d92d
        assertFalse(ok, "claim while paused must revert");

        vm.prank(ATK);
        address[] memory toks = new address[](1);
        uint256[] memory amts = new uint256[](1);
        toks[0] = address(0);
        amts[0] = 1;
        (bool ok2,) = TRANSIT.call(abi.encodeWithSignature("emergencyWithdraw(address[],uint256[],address)", toks, amts, ATK));
        assertFalse(ok2, "emergencyWithdraw must be executor-gated");
    }

    // ---------------------------------------------------------------- 8. Zethr
    function test_09_zethr_fresh_attacker_no_gain() public {
        bytes4[] memory sels = new bytes4[](4);
        sels[0] = 0x3ccfd60b; // withdraw()? (Zethr uses withdraw(address)); keep no-arg check too
        sels[1] = 0x51cff8d9; // withdraw(address)
        sels[2] = 0xe9fad8ee; // exit()
        sels[3] = 0x2e1a7d4d; // withdraw(uint256) — not present; must revert
        uint256 cBefore = bal(ZETHR);
        (int256 gained,) = shotgun(ZETHR, sels);
        assertEq(gained, 0, "fresh attacker must gain nothing from Zethr");
        assertEq(bal(ZETHR), cBefore, "Zethr balance unchanged");

        uint256 cBefore2 = bal(ZETHR_CASINO);
        bytes4[] memory sels2 = new bytes4[](3);
        sels2[0] = 0x51cff8d9; // withdraw(address)
        sels2[1] = 0xe9fad8ee; // exit()
        sels2[2] = 0x3ccfd60b; // withdraw()
        (int256 gained2,) = shotgun(ZETHR_CASINO, sels2);
        assertEq(gained2, 0, "fresh attacker must gain nothing from Zethr Casino");
        assertEq(bal(ZETHR_CASINO), cBefore2, "Zethr Casino balance unchanged");
    }

    // ---------------------------------------------------------------- 9. DailyDivs / RPO
    function test_10_dailydivs_rpo_fresh_attacker_no_gain() public {
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = 0x3ccfd60b; // withdraw()
        uint256 dBefore = bal(DAILYDIVS);
        (int256 gained,) = shotgun(DAILYDIVS, sels);
        assertEq(gained, 0, "no gain from DailyDivs");
        assertEq(bal(DAILYDIVS), dBefore);

        uint256 rBefore = bal(RPO);
        bytes4[] memory sels2 = new bytes4[](3);
        sels2[0] = 0x3ccfd60b; // withdraw()
        sels2[1] = 0x3884d635; // airdrop()
        sels2[2] = 0xed78cf4a; // potSwap()
        (int256 gained2,) = shotgun(RPO, sels2);
        assertEq(gained2, 0, "no gain from ReadyPlayerONE");
        assertEq(bal(RPO), rBefore);
    }

    // ---------------------------------------------------------------- 10. FEG fETH
    function test_11_feg_no_market_and_self_only_withdraw() public {
        (bool ok, bytes memory r) = UNIV2_FACTORY.staticcall(
            abi.encodeWithSignature("getPair(address,address)", FEG, WETH)
        );
        assertTrue(ok);
        assertEq(abi.decode(r, (address)), address(0), "no Uniswap V2 fETH/WETH pair => no market path");

        vm.prank(ATK);
        (bool ok2,) = FEG.call(abi.encodeWithSignature("withdraw(uint256)", 1));
        assertFalse(ok2, "withdraw with zero balance reverts 'invalid amt'");
    }

    // ---------------------------------------------------------------- 11. Bingo4Beast deploy 2
    function test_12_bingo2_withdraw_reverts_for_fresh() public {
        uint256 cBefore = bal(BINGO2);
        vm.prank(ATK);
        (bool ok,) = BINGO2.call{gas: 1_000_000}(abi.encodeWithSelector(0x3ccfd60b)); // withdraw()
        assertFalse(ok, "withdraw() reverts for non-player");
        assertEq(bal(BINGO2), cBefore);
    }

    // ---------------------------------------------------------------- 12. zkSync Lite (authority re-check)
    function test_13_zksync_authority_state() public {
        (bool ok, bytes memory r) = ZKSYNC.staticcall(abi.encodeWithSignature("paused()"));
        assertTrue(ok);
        assertEq(abi.decode(r, (bool)), false, "distributor is not paused");
        (bool ok2, bytes memory r2) = ZKSYNC.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok2);
        address owner = abi.decode(r2, (address));
        assertGt(owner.code.length, 0, "owner is a contract (Gnosis Safe proxy)");
        emit log_named_address("zksync owner", owner);
        assertGt(bal(ZKSYNC), 9_000 ether);
    }

    // ---------------------------------------------------------------- 13. 2017 DEX friends (re-check)
    function test_14_legacy_dex_fresh_withdraw_no_gain() public {
        bytes4[] memory sels = new bytes4[](2);
        sels[0] = 0x2e1a7d4d; // withdraw(uint256)
        sels[1] = 0x3ccfd60b; // withdraw()
        uint256 iBefore = bal(IDEX);
        (int256 g1,) = shotgun(IDEX, sels);
        assertEq(g1, 0);
        assertEq(bal(IDEX), iBefore);

        uint256 eBefore = bal(ED2);
        (int256 g2,) = shotgun(ED2, sels);
        assertEq(g2, 0);
        assertEq(bal(ED2), eBefore);

        uint256 uBefore = bal(UNKNOWN_DEX);
        (int256 g3,) = shotgun(UNKNOWN_DEX, sels);
        assertEq(g3, 0);
        assertEq(bal(UNKNOWN_DEX), uBefore);
    }
}
