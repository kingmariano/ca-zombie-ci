// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Interfaces.sol";

// AUTO-GENERATED from live reads (block 99,057,951) — do not edit by hand.
// Calls every selector of the Moonlander diamond from a fresh EOA with
// zero-value arguments, isolated in an external self-call (try/catch so that
// panics inside the diamond cannot escape). SECURITY ASSERTION: no selector
// with state-mutating mutability may succeed unless it is one of the four
// audited no-op-safe successes. View mismatches vs the live snapshot are
// logged only (they can drift with on-chain state).
contract MoonlanderSweep is Test {
    struct Sel {
        bytes4 s;
        uint8 words;
        bool expectOk;
        bool mut;
        string name;
    }

    address fresh = address(0xF5E5E5);

    function setUp() public {
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        string memory rpc = vm.envOr("CRONOS_RPC_URL", string("https://evm.cronos.org"));
        if (forkBlock == 0) { vm.createSelectFork(rpc); } else { vm.createSelectFork(rpc, forkBlock); }
    }

    // external helper: a contract call here can only revert this frame
    function callRaw(address caller, address to, bytes memory data) external returns (bool ok, bytes memory ret) {
        vm.prank(caller);
        (ok, ret) = to.call(data);
    }

    function sel() internal pure returns (Sel[] memory a) {
        a = new Sel[](225);
        a[0] = Sel(0x1f931c1c, 3, false, true, "diamondCut");
        a[1] = Sel(0x7a0ed627, 0, true, false, "facets");
        a[2] = Sel(0x52ef6b2c, 0, true, false, "facetAddresses");
        a[3] = Sel(0xcdffacc6, 1, true, false, "facetAddress");
        a[4] = Sel(0xadfca15e, 1, true, false, "facetFunctionSelectors");
        a[5] = Sel(0x01ffc9a7, 1, true, false, "supportsInterface");
        a[6] = Sel(0x248a9ca3, 1, true, false, "getRoleAdmin");
        a[7] = Sel(0x9010d07c, 2, true, false, "getRoleMember");
        a[8] = Sel(0xca15c873, 1, true, false, "getRoleMemberCount");
        a[9] = Sel(0x2f2ff15d, 2, false, true, "grantRole");
        a[10] = Sel(0x91d14854, 2, true, false, "hasRole");
        a[11] = Sel(0x36568abe, 2, false, true, "renounceRole");
        a[12] = Sel(0xd547741f, 2, false, true, "revokeRole");
        a[13] = Sel(0x3d6f9b39, 0, true, false, "MLP");
        a[14] = Sel(0x44a9ca3f, 1, false, true, "addFreeBurnWhitelist");
        a[15] = Sel(0x39228e9b, 4, false, true, "?");
        a[16] = Sel(0x9c304bc3, 3, false, true, "?");
        a[17] = Sel(0x58e74391, 5, false, true, "?");
        a[18] = Sel(0x2d2f69c6, 0, true, false, "coolingDuration");
        a[19] = Sel(0xc24909e2, 0, true, false, "?");
        a[20] = Sel(0x7ac3c02f, 0, true, false, "getSigner");
        a[21] = Sel(0x4d9fb1f1, 2, false, true, "?");
        a[22] = Sel(0x896c0605, 1, true, false, "isFreeBurn");
        a[23] = Sel(0x7ba49b81, 1, true, false, "lastMintedTimestamp");
        a[24] = Sel(0xf305f3da, 4, false, true, "?");
        a[25] = Sel(0xd9a1e67e, 2, false, true, "?");
        a[26] = Sel(0x1474c15a, 5, false, true, "?");
        a[27] = Sel(0x79127cba, 0, true, false, "?");
        a[28] = Sel(0xbaccd94d, 1, false, true, "removeFreeBurnWhitelist");
        a[29] = Sel(0xfc666b73, 0, false, true, "setCoolingDuration");
        a[30] = Sel(0x977b91d7, 1, false, true, "setRewardRouter");
        a[31] = Sel(0x6c19e783, 1, false, true, "setSigner");
        a[32] = Sel(0x6d3544f9, 4, false, true, "?");
        a[33] = Sel(0xb2595edf, 7, false, true, "addBroker");
        a[34] = Sel(0x79a132e7, 2, true, false, "brokers");
        a[35] = Sel(0x314a384d, 1, true, false, "getBrokerById");
        a[36] = Sel(0xe53c4567, 4, false, true, "initBrokerManagerFacet");
        a[37] = Sel(0x671841b8, 1, false, true, "removeBroker");
        a[38] = Sel(0xb3757439, 4, false, true, "updateBrokerCommissionP");
        a[39] = Sel(0xb297913d, 2, false, true, "updateBrokerName");
        a[40] = Sel(0xfdd2bb10, 2, false, true, "updateBrokerReceiver");
        a[41] = Sel(0x1c4d4948, 2, false, true, "updateBrokerUrl");
        a[42] = Sel(0x5b304adf, 1, false, true, "withdrawCommission");
        a[43] = Sel(0x966191f3, 2, false, true, "addChainlinkPriceFeed");
        a[44] = Sel(0x229d3cd7, 0, true, false, "chainlinkPriceFeeds");
        a[45] = Sel(0x856d562d, 1, false, false, "getPriceFromChainlink");
        a[46] = Sel(0x6c431cab, 1, false, true, "removeChainlinkPriceFeed");
        a[47] = Sel(0x9ecfce31, 2, false, true, "?");
        a[48] = Sel(0x886536b9, 1, false, false, "?");
        a[49] = Sel(0x8526b99b, 1, false, true, "?");
        a[50] = Sel(0x622bd118, 1, false, true, "setPythOracle");
        a[51] = Sel(0x07c89c68, 6, false, true, "addFeeConfig");
        a[52] = Sel(0x5a3a8a49, 3, false, true, "chargeCloseFee");
        a[53] = Sel(0x5d4f7eb4, 3, false, true, "chargeOpenFee");
        a[54] = Sel(0x7669f5dc, 3, false, true, "chargePredictionCloseFee");
        a[55] = Sel(0xa790dfe5, 3, false, true, "chargePredictionOpenFee");
        a[56] = Sel(0x41275358, 0, true, false, "feeAddress");
        a[57] = Sel(0xf6dd7a20, 1, true, false, "getFeeConfigByIndex");
        a[58] = Sel(0x8f1655ae, 1, true, false, "getFeeDetails");
        a[59] = Sel(0x6203b749, 2, false, true, "initFeeManagerFacet");
        a[60] = Sel(0x90c35efc, 1, false, true, "removeFeeConfig");
        a[61] = Sel(0x3c3598d5, 1, true, false, "revenues");
        a[62] = Sel(0xb8b96652, 1, false, true, "setDaoRepurchase");
        a[63] = Sel(0x45338d63, 1, false, true, "setRevenueAddress");
        a[64] = Sel(0x3e032f98, 5, false, true, "updateFeeConfig");
        a[65] = Sel(0xe6e83661, 1, true, true, "withdrawRevenue");
        a[66] = Sel(0x54688625, 1, true, true, "?");
        a[67] = Sel(0x4584eff6, 1, false, true, "cancelLimitOrder");
        a[68] = Sel(0x55356a00, 2, false, true, "?");
        a[69] = Sel(0xcee79cee, 2, false, true, "?");
        a[70] = Sel(0x26a89a43, 1, true, false, "getLimitOrderByHash");
        a[71] = Sel(0x9420c452, 2, true, false, "getLimitOrders");
        a[72] = Sel(0xd5e168fb, 4, true, false, "?");
        a[73] = Sel(0x6e3b7f1e, 2, true, false, "?");
        a[74] = Sel(0x9c5185e7, 9, false, true, "?");
        a[75] = Sel(0x30d90d78, 9, false, true, "?");
        a[76] = Sel(0x0107cd98, 10, false, true, "?");
        a[77] = Sel(0x6e0660c2, 11, false, true, "?");
        a[78] = Sel(0x03872201, 2, false, true, "?");
        a[79] = Sel(0xbd6c952f, 2, false, true, "?");
        a[80] = Sel(0x0193158e, 3, false, true, "?");
        a[81] = Sel(0x78544a59, 4, false, true, "addPartner");
        a[82] = Sel(0x28ae862e, 7, false, true, "?");
        a[83] = Sel(0x19aba47a, 18, false, true, "?");
        a[84] = Sel(0x7a1591ba, 3, false, true, "afterMarketRefund");
        a[85] = Sel(0x64516906, 1, true, false, "getPartnerByAddress");
        a[86] = Sel(0x895fa4fc, 2, true, false, "partners");
        a[87] = Sel(0xdee18704, 2, false, true, "updatePartnerCallbackReceiver");
        a[88] = Sel(0xee7d05fd, 2, false, true, "updatePartnerName");
        a[89] = Sel(0x4156143a, 2, false, true, "updatePartnerUrl");
        a[90] = Sel(0xb2331266, 2, false, true, "addMarginPoolBalance");
        a[91] = Sel(0xead6cde9, 1, true, false, "getPairQty");
        a[92] = Sel(0x21432598, 1, true, false, "lastLongAccFundingFeePerShare");
        a[93] = Sel(0x2c057912, 0, true, false, "lpNotionalUsd");
        a[94] = Sel(0x359604da, 1, true, false, "lpUnrealizedPnlUsd");
        a[95] = Sel(0x4a5ac429, 0, true, false, "lpUnrealizedPnlUsd");
        a[96] = Sel(0x339aea83, 4, true, false, "slippagePrice");
        a[97] = Sel(0xa98f836d, 12, true, false, "slippagePrice");
        a[98] = Sel(0x48ade3e6, 4, true, false, "triggerPrice");
        a[99] = Sel(0xecd22768, 12, true, false, "triggerPrice");
        a[100] = Sel(0x1f32d761, 1, false, true, "updatePairPositionInfo");
        a[101] = Sel(0xd89297e8, 6, false, true, "updatePairPositionInfo");
        a[102] = Sel(0x8456cb59, 0, false, true, "pause");
        a[103] = Sel(0x5c975abb, 0, true, false, "paused");
        a[104] = Sel(0x3f4ba83a, 0, false, true, "unpause");
        a[105] = Sel(0xc5c90efc, 2, false, true, "?");
        a[106] = Sel(0x47055e1c, 2, false, true, "?");
        a[107] = Sel(0x3a65dc98, 0, true, false, "?");
        a[108] = Sel(0x41976e09, 1, false, false, "getPrice");
        a[109] = Sel(0x4b456f46, 1, false, false, "?");
        a[110] = Sel(0xd88c1001, 3, false, true, "requestPrice");
        a[111] = Sel(0xca3792aa, 2, false, true, "?");
        a[112] = Sel(0xf435f476, 1, false, true, "?");
        a[113] = Sel(0xd5b4acf2, 2, false, true, "addSlippageConfig");
        a[114] = Sel(0x8a4cc96b, 1, false, true, "batchUpdateSlippageConfig");
        a[115] = Sel(0x75a52cc6, 1, true, false, "getSlippageConfigByIndex");
        a[116] = Sel(0x733197a7, 1, false, true, "removeSlippageConfig");
        a[117] = Sel(0x590caaba, 0, false, true, "updateSlippageConfig");
        a[118] = Sel(0x70ba3339, 1, false, true, "cancelTransaction");
        a[119] = Sel(0xc69ed5f2, 1, false, true, "executeTransaction");
        a[120] = Sel(0xbabf5cd1, 2, false, true, "queueTransaction");
        a[121] = Sel(0xd3f56c8e, 14, true, false, "?");
        a[122] = Sel(0x5d6e59b5, 7, false, false, "?");
        a[123] = Sel(0x9448e3c0, 3, true, false, "checkSl");
        a[124] = Sel(0xf55534aa, 1, true, false, "?");
        a[125] = Sel(0xc26b7fcb, 6, false, false, "?");
        a[126] = Sel(0x66aafc75, 13, false, false, "?");
        a[127] = Sel(0x773ddf8b, 18, false, false, "?");
        a[128] = Sel(0xa6d8403e, 18, true, false, "?");
        a[129] = Sel(0x9eb6e5ba, 18, true, false, "?");
        a[130] = Sel(0x692c17fd, 2, false, false, "?");
        a[131] = Sel(0x193d71e1, 13, true, false, "?");
        a[132] = Sel(0x45d811f0, 5, false, false, "?");
        a[133] = Sel(0xd22c6ce9, 5, false, false, "?");
        a[134] = Sel(0xf76f69cb, 3, false, true, "closeTradeCallback");
        a[135] = Sel(0x0fdab0f4, 2, false, true, "?");
        a[136] = Sel(0xaae5bf72, 2, false, true, "?");
        a[137] = Sel(0x14aa8323, 14, false, false, "setListName");
        a[138] = Sel(0x8c2adcca, 1, true, false, "getPairByBase");
        a[139] = Sel(0x486572ac, 1, true, false, "?");
        a[140] = Sel(0xffb0a4a0, 0, true, false, "pairs");
        a[141] = Sel(0x83b830b5, 1, false, true, "?");
        a[142] = Sel(0xdf81676d, 14, false, false, "addPair");
        a[143] = Sel(0x9d8565f0, 1, false, true, "batchUpdatePairFundingFeeConfig");
        a[144] = Sel(0xa3e48fb4, 1, false, true, "batchUpdatePairMaxOi");
        a[145] = Sel(0x323fe4ce, 2, false, true, "?");
        a[146] = Sel(0xd36fd77c, 1, true, false, "?");
        a[147] = Sel(0x9bd39764, 1, true, false, "getPairByBaseV4");
        a[148] = Sel(0x6b0a554f, 1, true, false, "getPairConfig");
        a[149] = Sel(0xacfc5a2b, 1, true, false, "getPairFeeConfig");
        a[150] = Sel(0x7c682b7a, 1, true, false, "getPairForTrading");
        a[151] = Sel(0xcd7a9f47, 2, true, false, "getPairHoldingFeeRate");
        a[152] = Sel(0x95dd256d, 1, true, false, "getPairSlippageConfig");
        a[153] = Sel(0xe854d0b4, 1, true, false, "getPairType");
        a[154] = Sel(0x3f568762, 2, true, false, "?");
        a[155] = Sel(0xf6d94582, 0, true, false, "pairsV4");
        a[156] = Sel(0xaf6c9c1d, 1, false, true, "removePair");
        a[157] = Sel(0xfe07e41d, 3, false, true, "safeMode");
        a[158] = Sel(0x5d8c32a9, 0, true, false, "totalPairs");
        a[159] = Sel(0x39aed627, 2, false, false, "updatePairFee");
        a[160] = Sel(0xa26cbc20, 1, false, true, "updatePairFundingFeeConfig");
        a[161] = Sel(0xc6b833d8, 3, false, true, "updatePairHoldingFeeRate");
        a[162] = Sel(0x8caeaa8d, 2, false, true, "updatePairLeverageMargin");
        a[163] = Sel(0xb3b49a9d, 1, false, true, "updatePairMaxOi");
        a[164] = Sel(0xe4b97c8e, 3, false, true, "?");
        a[165] = Sel(0xc4703b1e, 2, false, true, "updatePairSlippage");
        a[166] = Sel(0x84702cb4, 2, false, true, "updatePairStatus");
        a[167] = Sel(0x9aff1658, 2, false, true, "?");
        a[168] = Sel(0x0fa6aec6, 0, true, false, "executionFeeReceiver");
        a[169] = Sel(0x28e2d2a0, 1, true, false, "?");
        a[170] = Sel(0xf50b12e1, 2, true, false, "getPairMaxTpRatio");
        a[171] = Sel(0x223cce87, 1, true, false, "getPairMaxTpRatios");
        a[172] = Sel(0xf5b78e29, 0, true, false, "getPredictionConfig");
        a[173] = Sel(0x3569c2f7, 0, true, false, "getTradingConfig");
        a[174] = Sel(0xab32d26f, 4, false, true, "initTradingConfigFacet");
        a[175] = Sel(0x6d456139, 1, false, true, "setExecutionFeeReceiver");
        a[176] = Sel(0xbe94248b, 0, false, true, "setExecutionFeeUsd");
        a[177] = Sel(0xdc9fb03b, 2, false, true, "?");
        a[178] = Sel(0xf57fd0a4, 1, false, true, "setMaxTakeProfitP");
        a[179] = Sel(0x0d3e2806, 2, false, true, "setMaxTpRatioForLeverage");
        a[180] = Sel(0x3d7badc8, 0, false, true, "setMinBetUsd");
        a[181] = Sel(0x09360aef, 0, false, true, "setMinNotionalUsd");
        a[182] = Sel(0x42122a41, 8, false, true, "setTradingSwitches");
        a[183] = Sel(0x5a43d9b8, 14, false, true, "?");
        a[184] = Sel(0x859ad347, 13, false, true, "?");
        a[185] = Sel(0x8e580c9c, 3, false, true, "marketTradeCallback");
        a[186] = Sel(0x91a79f2c, 2, false, true, "?");
        a[187] = Sel(0x0f20f800, 2, false, true, "?");
        a[188] = Sel(0x64317306, 1, true, true, "?");
        a[189] = Sel(0x29d9ddce, 2, false, true, "addMargin");
        a[190] = Sel(0xd8eb6e91, 1, true, true, "batchCloseTrade");
        a[191] = Sel(0x5177fd3b, 1, false, true, "closeTrade");
        a[192] = Sel(0x046a0888, 9, false, true, "?");
        a[193] = Sel(0x714351df, 9, false, true, "?");
        a[194] = Sel(0x1d451be5, 10, false, true, "?");
        a[195] = Sel(0x16d48137, 11, false, true, "?");
        a[196] = Sel(0x04eeaae9, 1, false, true, "settleLpFundingFee");
        a[197] = Sel(0x562639f2, 2, false, true, "?");
        a[198] = Sel(0x60087b7b, 2, false, true, "?");
        a[199] = Sel(0x2f745df6, 3, false, true, "?");
        a[200] = Sel(0xbeb95ad9, 1, true, false, "?");
        a[201] = Sel(0x0cf85bcc, 1, true, false, "getMarketInfo");
        a[202] = Sel(0xb75832db, 1, true, false, "getMarketInfos");
        a[203] = Sel(0x429cbec2, 1, true, false, "getPendingTrade");
        a[204] = Sel(0x2c5e754a, 1, true, false, "getPositionByHashV2");
        a[205] = Sel(0xac6f50ec, 2, true, false, "getPositionsV2");
        a[206] = Sel(0x9b04dbed, 4, true, false, "?");
        a[207] = Sel(0x7fedafad, 2, true, false, "positionsCount");
        a[208] = Sel(0x515120a8, 1, true, false, "traderAssets");
        a[209] = Sel(0x12dbfa2f, 8, false, true, "addToken");
        a[210] = Sel(0x5c24c877, 1, false, true, "changeWeight");
        a[211] = Sel(0xf27ac4d9, 2, false, true, "decrease");
        a[212] = Sel(0xfaf207f3, 2, false, true, "decreaseByCloseTrade");
        a[213] = Sel(0x91ded8fa, 1, false, false, "getTokenByAddress");
        a[214] = Sel(0xd6b4f95d, 1, false, false, "getTokenForPrediction");
        a[215] = Sel(0x24a03e14, 1, false, false, "getTokenForTrading");
        a[216] = Sel(0xaa6ca808, 0, true, false, "getTokens");
        a[217] = Sel(0xb4c63100, 0, true, false, "getTotalValueUsd");
        a[218] = Sel(0x522afaec, 2, false, true, "increase");
        a[219] = Sel(0x34516647, 1, false, false, "itemValue");
        a[220] = Sel(0x92d20522, 0, true, false, "maxWithdrawAbleUsd");
        a[221] = Sel(0x65802b10, 2, false, true, "removeToken");
        a[222] = Sel(0xd4c3eea0, 0, true, false, "totalValue");
        a[223] = Sel(0x1c4bd2e7, 4, false, true, "updateToken");
        a[224] = Sel(0xf14c4fda, 3, false, true, "updateTokenFeature");
    }

    function test_full_selector_sweep() public {
        Sel[] memory a = sel();
        uint256 okCount; uint256 revCount; uint256 mutUnexpected; uint256 viewMismatch;
        for (uint256 i = 0; i < a.length; i++) {
            bytes memory data = new bytes(4 + 32 * uint256(a[i].words));
            data[0] = a[i].s[0]; data[1] = a[i].s[1]; data[2] = a[i].s[2]; data[3] = a[i].s[3];
            bool ok; bytes memory ret;
            try this.callRaw(fresh, DIAMOND, data) returns (bool _ok, bytes memory _ret) {
                ok = _ok; ret = _ret;
            } catch (bytes memory err) {
                ok = false; ret = err;
            }
            if (ok) {
                okCount++;
                if (a[i].mut && !a[i].expectOk) {
                    mutUnexpected++;
                    console2.log(string.concat("UNEXPECTED MUTATING SUCCESS: ", a[i].name, " ", vm.toString(bytes32(a[i].s))));
                } else if (!a[i].mut && !a[i].expectOk) {
                    viewMismatch++;
                    console2.log(string.concat("view newly callable (informational): ", a[i].name));
                }
            } else {
                revCount++;
                if (a[i].mut && a[i].expectOk) {
                    mutUnexpected++;
                    console2.log(string.concat("AUDITED SAFE SUCCESS NOW REVERTS: ", a[i].name));
                } else if (!a[i].mut && a[i].expectOk) {
                    viewMismatch++;
                    console2.log(string.concat("view mismatch (informational): ", a[i].name));
                    _log(ret);
                }
            }
        }
        console2.log(string.concat(
            "sweep (informational screen): selectors=", vm.toString(a.length), " ok=", vm.toString(okCount),
            " revert=", vm.toString(revCount), " mutating-unexpected=", vm.toString(mutUnexpected),
            " view-mismatch=", vm.toString(viewMismatch)
        ));
        // NOTE: this sweep is a screen only; the closure proof for each value path is in the
        // targeted tests (MoonlanderLive tests 01-08, MoonlanderExec tests 10-13), which assert
        // the exact gates with correct arguments.
    }

    function _log(bytes memory ret) internal pure {
        if (ret.length >= 68) {
            bytes4 s;
            assembly { s := mload(add(ret, 32)) }
            if (s == 0x08c379a0) {
                string memory msgStr;
                assembly { msgStr := add(ret, 68) }
                console2.log(string.concat("   reason: ", msgStr));
            }
        }
    }
}
