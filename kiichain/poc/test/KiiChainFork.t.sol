// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// @title KiiChain live-fork checks for GHSA-7g4w-cg88-2cq2 residual extractability
/// @notice Read-only assertions against the live KiiChain EVM state (chain id 1783).
///         The vulnerability itself lives in the Cosmos node's Go code (StateDB
///         balance accounting + staking precompile), so it cannot be reproduced in
///         an anvil fork; these tests verify the deployed-state half of the
///         assessment (exploit contracts still deployed, all balances zeroed).
///         The node-level gates (underflow guard panic, incident-address blocklist)
///         are probed directly over JSON-RPC in kiichain/ci/live_probes.py.
contract KiiChainForkTest is Test {
    // The 19 attacker vesting/helper addresses recovered from the incident
    // (each was a delayed-vesting account with a helper contract deployed on it).
    address[19] internal helpers = [
        0x0C45B9FB7a300eA94FBADe5F509faE5fad5e56CA,
        0x177629125877deDCCA4C195e358dcB598ca15e01,
        0x17c0d9FbCfD189BF023656DBFCF50Fe0253Bb0eE,
        0x1e6f344D19382719A202757a73192Ab01dBeE17a,
        0x21F6F013159C76F1baa3C37C0983b795e23F04bC,
        0x3C6Fe188A1A8cFdf48E05746d98F1E0a1d3904B2,
        0x407dd1d6EDF826bFd016c8F7499F6935C16cA37e,
        0x424BD2CA539b0e088b033dB0233c74AaA82c2501,
        0x5F90295ea880f1C224D133619dbe98BFF804c3b5,
        0x77308955C6CBc4cdEf2e53DeFc7D78a007f29739,
        0x8132bfDE87A5bfa23297da7F74e6FFEd079F7495,
        0x87A4Ea252044933a91C65A1608cEE14626fa0947,
        0x8Cdab0fa359AC467C80C19dE3fee5a543E258365,
        0x8F37701914d60CeE95CcAa39AF959561045CF9E8,
        0xa6B260f4df26F94e5F21CA9B7d57D82FF9587cc1,
        0xb1d8431da51f157B46ca7F831e88f5365B230948,
        0xD2C75516Cc9E726026B25aF99e671bf502Bc53f1,
        0xddAEDdB516fC21646102168a598AFd4f58abDB3d,
        0xED191cf73DE21b78b2D4F4ff7380e6c73c2ae9Cf
    ];

    address internal constant ATTACKER = 0x0E7A96227fcf09F53D644Ba6462d8c73993eF246;

    function setUp() public {
        string memory url = vm.envOr("KII_RPC_URL", string("https://json-rpc.kiivalidator.com"));
        vm.createSelectFork(url);
    }

    function test_chainId() public view {
        require(block.chainid == 1783, "not KiiChain mainnet");
    }

    function test_helperContractsStillDeployed() public view {
        for (uint256 i = 0; i < helpers.length; i++) {
            bytes memory code = helpers[i].code;
            require(code.length > 0, "helper contract missing");
        }
    }

    function test_allExploitAddressesHaveZeroBalance() public view {
        require(ATTACKER.balance == 0, "attacker has funds");
        for (uint256 i = 0; i < helpers.length; i++) {
            require(helpers[i].balance == 0, "helper has funds");
        }
    }

    function test_attackerIsNotAContract() public view {
        require(ATTACKER.code.length == 0, "attacker address unexpectedly has code");
    }
}
