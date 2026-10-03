// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title C-36 negative controls: prove a fresh unprivileged attacker cannot extract
///        from the largest forgotten-eth pots via the obvious permissionless entry points.
///        Read-only research: fork only, no mainnet transactions.
contract NegativeControlsTest is Test {
    address constant ATTACKER = address(0xA77ACC); // fresh EOA, no positions, no tokens

    // targets
    address constant WITHDRAW_DAO = 0xBf4eD7b27F1d666546E30D74d50d173d20bca754;
    address constant AUGUR_CASH = 0xd5524179cB7AE012f5B642C1D6D700Bbaa76B96b;
    address constant POWH3D = 0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe;
    address constant QUANTFURY = 0xd18475521245a127a933a4fCAF99E8c45a416F7e;
    address constant FETH_PROXY = 0x49128CF8ABE9071ee24540a296b5DED3F9D50443;
    address constant TRIBE_REDEEMER = 0x4d9629e80118082B939e3D59E69c82A2ec08b4d5;
    address constant ACID = 0x23Ea10CC1e6EBdB499D24E45369A35f43627062f;
    address constant HONG = 0x9Fa8fA61A10Ff892E4EBCeB7f4e0FC684C2ce0a9;
    address constant ARB_STAKING = 0x5EEe354E36Ac51E9D3f7283005cAB0C55F423b23;
    address constant X2Y2_FEE = 0xc8C3CC5be962b6D281E4a53DBcCe1359F76a1B85;
    address constant DELPHI = 0x899F9a0440fACe1397A1eE1e3F6bF3580a6633d1;
    address constant MOONCAT = 0x60cd862c9C687A9dE49aecdC3A99b74A4fc54aB6;
    address constant MONOLITH = 0x24F0bB6c9b2C3DB66603Fa0Ec07Ab0CF55cDd387;
    address constant METADROP = 0x1EcB59aEcF1fC5da695242C6E78C2007E775d40F;
    address constant R1EXCHANGE = 0xc7c9b856D33651cc2BCD9E0099eFA85F59F78302;
    address constant OLD_WETH = 0xECF8F87f810EcF450940c9f60066b4a7a501d6A7;
    address constant MAKER_WETH = 0x2956356cD2a2bf3202F771F50D3D14A367b48070;
    address constant BANCOR_ETH = 0xD76b5c2A23ef78368d8E34288B5b65D616B746aE;
    address constant NEUFUND_V2 = 0x0B7dc5A43Ce121b4EaaA41b0F4f43BBA47Bb8951;
    address constant AHOOLEE = 0x575cb87ab3C2329A0248C7d70e0ead8E57f3e3F7;
    address constant SPANKCHAIN = 0x4D1886daf2617cBD9e27abFd0f18a54F04f33c41;
    address constant NUCYPHER = 0xe9778E69a961e64d3cdBB34CF6778281d34667c2;
    address constant DIGIPULSE = 0x9AcA6aBFe63A5ae0Dc6258cefB65207eC990Aa4D;
    address constant QCO = 0x3A8A97123bcCd826228e5EB4144b48cce169517B;
    address constant ZEROTRAFFIC = 0xaf7aeA249098F2c2f50cc11d4000cCf798194373;
    address constant PRESALE48 = 0x48C128eAfC3b937Fb1f97889aD174Ac02b4952cB;

    struct Probe { string name; address target; bytes data; }

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))));
        vm.deal(ATTACKER, 0);
    }

    function _runProbe(Probe memory p) internal returns (bool ok, uint256 gain) {
        uint256 before = ATTACKER.balance;
        vm.prank(ATTACKER);
        (ok, ) = p.target.call{gas: 5_000_000}(p.data);
        gain = ATTACKER.balance > before ? ATTACKER.balance - before : 0;
        emit log_named_string("probe", p.name);
        emit log_named_string("  call_ok", ok ? "true" : "false(revert)");
        emit log_named_uint("  attacker_gain_wei", gain);
    }

    function test_negative_controls() public {
        Probe[] memory probes = new Probe[](28);
        probes[0] = Probe("WithdrawDAO.withdraw()", WITHDRAW_DAO, abi.encodeWithSelector(0x3ccfd60b));
        probes[1] = Probe("WithdrawDAO.trusteeWithdraw()", WITHDRAW_DAO, abi.encodeWithSelector(0x2e6e504a));
        probes[2] = Probe("AugurCash.withdrawEther(1e18)", AUGUR_CASH, abi.encodeWithSelector(0x3bed33ce, uint256(1e18)));
        probes[3] = Probe("PoWH3D.exit()", POWH3D, abi.encodeWithSelector(0xe9fad8ee));
        probes[4] = Probe("Quantfury.sellTokens(1e18)", QUANTFURY, abi.encodeWithSelector(0x6c11bcd3, uint256(1e18)));
        probes[5] = Probe("FETH.withdrawAvailableBalance()", FETH_PROXY, abi.encodeWithSelector(0xb1111359));
        probes[6] = Probe("TribeRedeemer.redeem(attacker,1e18)", TRIBE_REDEEMER, abi.encodeWithSelector(0x1e9a6950, ATTACKER, uint256(1e18)));
        probes[7] = Probe("Acid.burn(1e9)", ACID, abi.encodeWithSelector(0x42966c68, uint256(1e9)));
        probes[8] = Probe("HONG.refundMyIcoInvestment()", HONG, abi.encodeWithSelector(0xe84f7054));
        probes[9] = Probe("ArbStaking.withdrawAll()", ARB_STAKING, abi.encodeWithSelector(0x853828b6));
        probes[10] = Probe("X2Y2.harvest()", X2Y2_FEE, abi.encodeWithSelector(0x4641257d));
        probes[11] = Probe("Delphi.redeemTokens(1e18)", DELPHI, abi.encodeWithSelector(0xa6e158f8, uint256(1e18)));
        probes[12] = Probe("MoonCatRescue.withdraw()", MOONCAT, abi.encodeWithSelector(0x3ccfd60b));
        probes[13] = Probe("Monolith.burn(attacker,1e18)", MONOLITH, abi.encodeWithSelector(0x9dc29fac, ATTACKER, uint256(1e18)));
        probes[14] = Probe("Metadrop.claimRefund(1,[])", METADROP, abi.encodeWithSelector(0x211f0036, uint256(1), new bytes32[](0)));
        probes[15] = Probe("R1Exchange.withdrawNoLimit(0x0,1,0)", R1EXCHANGE, abi.encodeWithSelector(0x2c8668d4, address(0), uint256(1), uint256(0)));
        probes[16] = Probe("OldWETH.withdraw(1e18)", OLD_WETH, abi.encodeWithSelector(0x2e1a7d4d, uint256(1e18)));
        probes[17] = Probe("MakerWETH.withdraw(1e18)", MAKER_WETH, abi.encodeWithSelector(0x2e1a7d4d, uint256(1e18)));
        probes[18] = Probe("BancorETH.withdraw(1e18)", BANCOR_ETH, abi.encodeWithSelector(0x2e1a7d4d, uint256(1e18)));
        probes[19] = Probe("NeufundV2.withdraw(1e18)", NEUFUND_V2, abi.encodeWithSelector(0x2e1a7d4d, uint256(1e18)));
        probes[20] = Probe("Ahoolee.refund()", AHOOLEE, abi.encodeWithSelector(0x590e1ae3));
        probes[21] = Probe("SpankChain.withdraw()", SPANKCHAIN, abi.encodeWithSelector(0x3ccfd60b));
        probes[22] = Probe("NuCypher.refund()", NUCYPHER, abi.encodeWithSelector(0x590e1ae3));
        probes[23] = Probe("DigiPulse.refundEther()", DIGIPULSE, abi.encodeWithSelector(0x560ed6a1));
        probes[24] = Probe("QCO.requestRefund()", QCO, abi.encodeWithSelector(0xd5cef133));
        probes[25] = Probe("ZeroTraffic.endCrowdsale()", ZEROTRAFFIC, abi.encodeWithSelector(0x2095f2d4));
        probes[26] = Probe("Presale48.withdrawAll()", PRESALE48, abi.encodeWithSelector(0x853828b6));
        probes[27] = Probe("X2Y2.withdraw(1,false)", X2Y2_FEE, abi.encodeWithSelector(0x38d07436, uint256(1), false));

        uint256 totalGain = 0;
        for (uint256 i = 0; i < probes.length; i++) {
            (, uint256 g) = _runProbe(probes[i]);
            totalGain += g;
        }
        emit log_named_uint("TOTAL_ATTACKER_GAIN_WEI", totalGain);
        assertEq(totalGain, 0, "an unprivileged attacker extracted ETH");
    }

    /// @notice verify the pot balances are still live at test time
    function test_pots_live() public view {
        assertGt(WITHDRAW_DAO.balance, 80_000 ether, "WithdrawDAO drained");
        assertGt(AUGUR_CASH.balance, 700 ether, "Augur Cash drained");
        assertGt(POWH3D.balance, 1_900 ether, "PoWH3D drained");
        assertGt(QUANTFURY.balance, 290 ether, "Quantfury drained");
        assertGt(FETH_PROXY.balance, 260 ether, "FETH drained");
        // TribeRedeemer holds stETH/DAI, not ETH
        (bool ok, bytes memory ret) = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84)
            .staticcall(abi.encodeWithSelector(0x70a08231, TRIBE_REDEEMER));
        assertTrue(ok && ret.length == 32 && abi.decode(ret, (uint256)) > 0, "TribeRedeemer stETH empty");
    }
}
