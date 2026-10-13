// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, IAToken, ILendingPool, IAaveOracle} from "../src/Interfaces.sol";

/// @title Granary Finance — other-chain gates: Base paused, Fantom dead oracle, OP sUSD retired token.
contract GranaryOtherChainsTest is Test {
    // Base
    ILendingPool constant basePool = ILendingPool(0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3);
    IERC20 constant baseUSDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    // Fantom
    ILendingPool constant ftmPool = ILendingPool(0x65FA36Fe0a7C0d346Dd02b7217Fdd6E6C5aaA269);
    IAaveOracle constant ftmOracle = IAaveOracle(0x59DeA1331503C8FB92F5f68df2a7F97a801A4EA9);
    IERC20 constant ftmUSDC = IERC20(0x28a92dde19D9989F39A49905d7C9C2FAc7799bDf);

    // Optimism
    IERC20 constant opSUSD = IERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    IAaveOracle constant opOracle = IAaveOracle(0x9aEeFef549323511E027D70562f0C7EdcDEB294C);

    function _fork(string memory envKey, string memory fallback_) internal {
        // CI secrets may point at dead endpoints (e.g. fantom-rpc.publicnode.com is 404);
        // try the env URL first, then the known-good fallback.
        string memory primary = vm.envOr(envKey, fallback_);
        try vm.createSelectFork(primary) {} catch {
            vm.createSelectFork(fallback_);
        }
    }

    function test_base_pool_paused_blocks_everything() public {
        _fork("BASE_RPC_URL", "https://base-rpc.publicnode.com");
        assertTrue(basePool.paused(), "base pool not paused");
        // any state-changing path reverts with '64' (LP_IS_PAUSED); check deposit
        vm.deal(address(this), 100 ether);
        vm.expectRevert(bytes("64"));
        basePool.deposit(address(baseUSDC), 1e6, address(this), 0);
    }

    function test_fantom_oracle_dead_blocks_all_price_dependent_ops() public {
        _fork("FANTOM_RPC_URL", "https://rpcapi.fantom.network");
        assertFalse(ftmPool.paused(), "ftm pool paused");
        // all feeds are dead -> getAssetPrice reverts -> withdrawals/liquidations/borrows revert
        bool reverted;
        try ftmOracle.getAssetPrice(address(ftmUSDC)) returns (uint256) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "ftm oracle unexpectedly alive");
    }

    function test_op_susd_is_retired_token_nobody_can_acquire() public {
        _fork("OP_RPC_URL", "https://mainnet.optimism.io");
        // "Synth sUSD (retired)" — totalSupply 0: no tokens exist to deposit/repay with
        assertEq(opSUSD.totalSupply(), 0, "sUSD has supply");
        // the Chainlink feed it reads is live but irrelevant (0.3987 USD at audit time)
        uint256 px = opOracle.getAssetPrice(address(opSUSD));
        emit log_named_uint("sUSD oracle price (8dec)", px);
        assertGt(px, 0);
        // an aToken holder cannot redeem: the reserve holds 0 sUSD
        IAToken aSUSD = IAToken(0x8AaA9d29305D331aE67AD65495B9e22cf98f9035); // aToken for sUSD reserve on OP
        assertEq(opSUSD.balanceOf(address(aSUSD)), 0, "sUSD cash exists");
    }
}
