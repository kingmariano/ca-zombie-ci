// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

// Moonlander diamond (Cronos 25) — read at block 99,057,951
address constant DIAMOND = 0xE6F6351fb66f3a35313fEEFF9116698665FBEeC9;
address constant USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
address constant MLP = 0xb4c70008528227e0545Db5BA4836d1466727DF13;
address constant SMLP_TRACKER = 0x071788084370497ED1Ac19C6711bd1d4Af0E9034;
address constant TRACKER_IMPL = 0x8724f28fd3669B11717c4FEA9b0360d8E424902c;
address constant DISTRIBUTOR = 0x8Dbebe40e6bE35cF1bE07b22Aa5fa11f4768917E;
address constant REWARD_ROUTER = 0xfaa85B6A55AF5623F5cE63Db2c7048B088b44B15;
address constant MSIG = 0x7F404D40c9F5Bf8aE559900e8f4Dd99CD130E7e1;
address constant SIGNER = 0x06feafDB2F337067EBB3458408AF3611c4Ec213e;
address constant REVENUE_ADDRESS = 0xe978246A8E92bd202Af2Fef7DCb41feB2D405248;
address constant ETH_PAIR = 0x898B3560AFFd6D955b1574D87EE09e46669c60eA; // ETH/USD pairBase per api.moonlander.trade
address constant CM = 0x5449239f7F6992D7d13fc4E02829aC90B2bEa6D1;

// selectors used in tests (verified live against the 23-facet diamond)
library S {
    bytes4 constant diamondCut          = 0x1f931c1c;
    bytes4 constant initMlpManager      = 0x4d9fb1f1; // initMlpManagerFacet(address,address)
    bytes4 constant initBrokerManager   = 0xe53c4567; // initBrokerManagerFacet(uint24,address,string,string)
    bytes4 constant initFeeManager      = 0x6203b749; // initFeeManagerFacet(address,address)
    bytes4 constant initTradingConfig   = 0xab32d26f; // initTradingConfigFacet(uint256,uint256,uint24,uint256)
    bytes4 constant setPythOracle       = 0x622bd118;
    bytes4 constant addPythConfig       = 0x9ecfce31; // (address,bytes32)
    bytes4 constant removePythConfig    = 0x8526b99b;
    bytes4 constant setSigner           = 0x6c19e783;
    bytes4 constant setRewardRouter     = 0x977b91d7;
    bytes4 constant setCoolingDuration  = 0xfc666b73;
    bytes4 constant batchReqPriceCbV1   = 0x47055e1c; // batchRequestPriceCallback((bytes32,uint128)[])
    bytes4 constant batchReqPriceCbV2   = 0xc5c90efc; // batchRequestPriceCallback((bytes32,bytes32,bool,uint128)[],bytes[])
    bytes4 constant executeLimitOrder   = 0x55356a00; // KEEPER_ROLE
    bytes4 constant executeLimitOrderV2 = 0xcee79cee; // KEEPER_ROLE
    bytes4 constant marketTradeCb       = 0x8e580c9c; // marketTradeCallback(bytes32,uint256,uint256)
    bytes4 constant closeTradeCb        = 0xf76f69cb; // closeTradeCallback(bytes32,uint256,uint256)
    bytes4 constant batchExecOpen       = 0x0f20f800; // batchExecuteOpenMarketOrders(SignedOpenOrder[],PriceData)
    bytes4 constant batchExecClose      = 0x91a79f2c; // batchExecuteCloseMarketOrders(SignedCloseOrder[],PriceData)
    bytes4 constant withdrawRevenue     = 0xe6e83661;
    bytes4 constant withdrawCommission  = 0x5b304adf;
    bytes4 constant setTradingDelegator = 0x64317306;
    bytes4 constant getTradingDelegator = 0xbeb95ad9;
    bytes4 constant queueTransaction    = 0xbabf5cd1;
    bytes4 constant executeTransaction  = 0xc69ed5f2;
    bytes4 constant cancelTransaction   = 0x70ba3339;
    bytes4 constant mintMlp             = 0xf305f3da; // mintMlp(address,uint256,uint256,bool)
    bytes4 constant burnMlp             = 0x39228e9b; // burnMlp(address,uint256,uint256,address)
    bytes4 constant mintMlpWithSig      = 0x1474c15a;
    bytes4 constant burnMlpWithSig      = 0x58e74391;
    bytes4 constant unstakeAndBurnMlp   = 0x6d3544f9; // (address,uint256,uint256,address)
    bytes4 constant mlpPrice            = 0x79127cba;
    bytes4 constant addMarginPoolBalance= 0xb2331266;
    bytes4 constant addMargin           = 0x29d9ddce; // addMargin(bytes32,uint96)
    bytes4 constant closeTrade          = 0x5177fd3b;
    bytes4 constant batchCloseTrade     = 0xd8eb6e91;
    bytes4 constant openMarketTrade     = 0x046a0888; // openMarketTrade(OpenDataInput)
    bytes4 constant openMarketTradeETH  = 0x714351df;
    bytes4 constant openMarketTradePyth = 0x1d451be5;
    bytes4 constant openMarketTradePythFee = 0x16d48137;
    bytes4 constant openLimitOrder      = 0x9c5185e7;
    bytes4 constant limitOrderDeal      = 0x859ad347;
    bytes4 constant settleLpFundingFee  = 0x04eeaae9;
    bytes4 constant batchCancelLimit    = 0x54688625;
}
