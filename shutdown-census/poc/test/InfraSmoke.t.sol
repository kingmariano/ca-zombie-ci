// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// @title H-5 shutdown census — CI smoke test
/// @notice Verifies the fork infrastructure and records live-state baseline reads for the
///         top H-5 targets. Read-only: no transactions are broadcast; all calls are on forks.
contract InfraSmoke is Test {
    function _fork(string memory envName, string memory fallbackUrl) internal returns (uint256) {
        string memory url = vm.envOr(envName, fallbackUrl);
        return vm.createSelectFork(url);
    }

    function test_eth_top_targets_live() public {
        uint256 blk = _fork("FORK_RPC_URL", "https://ethereum-rpc.publicnode.com");
        emit log_named_uint("ethereum block", blk);

        // Summer.fi automation (Ethereum)
        address sfV1 = 0x6E87a7A0A03E51A741075fDf4D1FCce39a4Df01b;
        address sfV2 = 0x5743b5606E94Fb534a31e1ceFB3242C8A9422e5E;
        // Seamless LeverageManager (Ethereum)
        address seamlessLM = 0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351;
        // Goldfinch SeniorPool
        address seniorPool = 0x8481a6EbAf5c7DABc3F7e09e44A89531fd31F822;
        // Angle Transmuter + StableMaster
        address transmuter = 0x00253582b2a3FE112feEC532221d9708c64cEFAb;
        address stableMaster = 0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87;
        // ODOS Router V2 (Ethereum) — verify address on-chain before relying on it
        address odosRouter = 0xCF5540ffFCdc3d510b18bfcA6b2Ca070B9DBD090;

        assertGt(sfV1.code.length, 0, "Summer AutomationV1 has no code");
        assertGt(sfV2.code.length, 0, "Summer AutomationBotV2 has no code");
        assertGt(seamlessLM.code.length, 0, "Seamless LeverageManager has no code");
        assertGt(seniorPool.code.length, 0, "Goldfinch SeniorPool has no code");
        assertGt(transmuter.code.length, 0, "Angle Transmuter has no code");
        assertGt(stableMaster.code.length, 0, "Angle StableMasterFront has no code");
        emit log_named_uint("odosRouter code length", odosRouter.code.length);
        emit log_named_uint("sfV1 eth balance", sfV1.balance);
        emit log_named_uint("sfV2 eth balance", sfV2.balance);
    }

    function test_base_targets_live() public {
        uint256 blk = _fork("BASE_RPC_URL", "https://mainnet.base.org");
        emit log_named_uint("base block", blk);
        address seamlessLMBase = 0x38Ba21C6Bf31dF1b1798FCEd07B4e9b07C5ec3a8;
        address sfV2Base = 0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8;
        assertGt(seamlessLMBase.code.length, 0, "Seamless LeverageManager (Base) has no code");
        assertGt(sfV2Base.code.length, 0, "Summer AutomationBotV2 (Base) has no code");
    }

    function test_arb_targets_live() public {
        uint256 blk = _fork("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc");
        emit log_named_uint("arbitrum block", blk);
        address sfV2Arb = 0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a;
        address velaVault = 0xC4ABADE3a15064F9E3596943c699032748b13352;
        assertGt(sfV2Arb.code.length, 0, "Summer AutomationBotV2 (Arb) has no code");
        emit log_named_uint("velaVault code length", velaVault.code.length);
    }

    function test_op_targets_live() public {
        uint256 blk = _fork("OP_RPC_URL", "https://mainnet.optimism.io");
        emit log_named_uint("optimism block", blk);
        address sfV2Op = 0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4;
        assertGt(sfV2Op.code.length, 0, "Summer AutomationBotV2 (OP) has no code");
    }
}
