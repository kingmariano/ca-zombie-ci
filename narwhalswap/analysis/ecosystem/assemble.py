#!/usr/bin/env python3
"""Assemble ecosystem.json + ecosystem.md deliverables."""
import json, sys, os
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")

BASE = "/home/heisenberg/CA/narwhalswap/analysis/ecosystem"
def L(f): return json.load(open(os.path.join(BASE, f)))

recon = L("recon1_raw.json")
block = 127201628
holders = L("lp_holders.json")
farmfam = L("farm_family.json")
strat = L("strategy_value.json")
wallets = L("wallet_balances.json")
grand = L("grand_enum.json")
minters = L("nar_minters.json")

TEAM = "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5"

contracts = []
def C(name, addr, ctype, code_size=None, verified=None, deployer=None, deploy_block=None, holds=None, risky=None, verdict=""):
    contracts.append({
        "name": name, "address": addr, "type": ctype, "code_size": code_size,
        "verified_source": verified, "deployer": deployer, "deploy_block": deploy_block,
        "holds_value": holds or {}, "risky_functions": risky or [], "verdict": verdict,
    })

# ---------- core ----------
C("NarwhalswapFactory", "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1", "factory core",
  deployer="0xc76827CcE55338Cbd6B399f45a75dF0CD5Da2749", deploy_block=847345, verified="NarwhalswapFactory.sol",
  holds={"pairs": 96},
  risky=["setFeeTo(address) onlyGovernance(feeToSetter=0xb104 EOA)", "setFeeToSetter(address)"],
  verdict="Live factory, 96 pairs. feeTo=Collecter. feeToSetter is the team EOA (single-key). Owner-controlled fee switch; no user funds custodied.")
C("NarwhalswapRouter", "0xe85c6ab56a3422e7bafd71e81eb7d0f290646078", "router core",
  code_size=17780, verified="NarwhalswapRouter.sol", deployer="0xc76827CcE55338Cbd6B399f45a75dF0CD5Da2749", deploy_block=847446,
  holds={}, risky=["stateless UniswapV2-router fork (no owner funds)"],
  verdict="Stateless router (factory()=Narwhal factory). Holds no funds; swap path is permissionless by design.")
C("NarToken (NAR)", "0xa1303e6199b319a891b79685f0537d289af1fc83", "token",
  code_size=12406, verified="NarToken.sol", deployer=TEAM, deploy_block=1270934,
  holds={"totalSupply": "13862957.889563149 NAR (~66% of 21M cap)", "burned": "6852210.066 NAR", "teamEoaBal": "563.445698367 NAR", "teamWallet507bBal": "87117.031250697 NAR"},
  risky=["mint(address,uint256) by minters (2 V2 farms + team EOA)", "addMinter(address)/removeMinter(address) onlyGovernance",
         "setGovernance(address)/setRewardPool(address)/setTeamWallet(address)/setRate(uint256,uint256) onlyGovernance",
         "transfer() takes 2.5% burn + 2.5% rewardPool"],
  verdict="Team EOA is governance AND a minter: can mint remaining ~7.1M NAR (up to 21M cap) and change burn/reward rate. Minter set currently = farm1, farm2, team EOA.")
C("NarwhalCollecter (feeTo)", "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9", "fee collector (factory feeTo)",
  code_size=9116, verified="NarwhalCollecter.sol", deployer=TEAM, deploy_block=2807852,
  holds={"WBNB": "0.055228638", "LP_NAR_WBNB": "0.0014013048", "LP_WBNB_THUGS": "0.0001144504", "LP_WBNB_BUSD": "0.0000088806"},
  risky=["convert(address,address) PUBLIC/permissionless - burns collector-held fee-LP, converts to WBNB, builds NAR/WBNB LP that is locked in the collector forever (no payout to caller)",
         "setThreshold(uint256) onlyOwner", "transferOwnership(address) onlyOwner (owner=0xb104 EOA)"],
  verdict="Permissionless convert() only moves the collector's own fee dust; cannot be abused to pay out to caller. New LP stays in collector (locked). Low value today.")
C("NarwhalPower (V2-era)", "0x1d791eaa684a21de92618dedea7bf373e2486956", "game/power accounting",
  code_size=9064, verified="NarwhalPower.sol", deployer=TEAM, deploy_block=1479573,
  holds={}, risky=["lpIn(address,uint256)/lpOut(address,uint256) callable only by set caller (farm1)", "setCaller(address)/setGovernance(address) onlyGovernance (0xb104)"],
  verdict="Accounting-only (segments/power). Holds no tokens. Caller = farm 0x1D22.")
C("NarwhalPower (V1-era, farm2 caller)", "0xa1992a9777c3c11c466f44a4b9c7530719a22ea2", "game/power accounting",
  code_size=9064, verified="NarwhalPower.sol", deployer=TEAM, deploy_block=1479632,
  holds={}, risky=["same as above (caller = farm 0x6dA9)"],
  verdict="Second Power instance; no value.")

# ---------- farms ----------
farm_common_risky = [
 "withdraw(uint256)/exit(uint256)/getReward()/emergencyWithdraw() - caller only receives own stake/rewards (per-msg.sender accounting)",
 "stake(uint256) - user deposit",
 "seize(address,uint256) onlyGovernance - governance (team EOA 0xb104) can sweep ANY token except lpToken",
 "setGovernance(address)/setEmergencyStop(bool[,uint256])/setTeamRewardRate/setGrowthBuffRate/setInitBuffrate/setPowerStragegy onlyGovernance",
 "buffRateReporter(address) PUBLIC - changes target's buff-rate accounting, no token payout",
]
C("NarwhalReward (V1) - NAR/WBNB LP", "0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835", "farm v1",
  code_size=17616, verified="NarwhalReward.sol", deployer=TEAM, deploy_block=1394048,
  holds={"LP_NAR_WBNB": "297.156674 (of 25004.55 supply)", "receiptTotalSupply": "296.155674"},
  risky=farm_common_risky, verdict="LIVE VALUE ~297 NAR/WBNB LP. Oldest farm; users can withdraw; team can seize non-LP tokens only.")
C("NarwhalReward (V1) - WBNB/BUSD LP", "0xbb38f7551025a433f36590be85271110212655de", "farm v1",
  code_size=17616, verified="NarwhalReward.sol", deployer=TEAM, deploy_block=1394263,
  holds={"LP_WBNB_BUSD": "231.532210 (of 285.47 supply = 81%)", "receiptTotalSupply": "231.532210"},
  risky=farm_common_risky, verdict="LIVE VALUE ~231.5 WBNB/BUSD LP (~81% of that pool). V1 farm still custodies users' LP.")
C("NarwhalRewardV2 - NAR/WBNB LP + reward minter", "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f", "farm v2",
  code_size=24401, verified="NarwhalRewardV2.sol", deployer=TEAM, deploy_block=1477899,
  holds={"LP_NAR_WBNB": "2243.792235", "NAR": "204706.947405969 NAR", "receipt(rNLP 0x6451...).totalSupply": "439651.9397908202"},
  risky=farm_common_risky + ["NAR minter - mints NAR rewards"],
  verdict="LIVE VALUE. Stakes NAR/WBNB LP + holds 204.7k NAR. Team governance can seize non-LP tokens and rewrite rate params.")
C("NarwhalRewardV2 - WBNB/BUSD LP + reward minter", "0x6da9ee0c0571b63e38950d1e12e835d5343f601b", "farm v2",
  code_size=24401, verified="NarwhalRewardV2.sol", deployer=TEAM, deploy_block=1478142,
  holds={"LP_WBNB_BUSD": "11.943791", "NAR": "46039.7613084826 NAR", "receipt(rNLP 0x1f7d...).totalSupply": "2807043.5318985"},
  risky=farm_common_risky + ["NAR minter"],
  verdict="LIVE VALUE (smaller).")
C("rNLP token (farm1 receipt)", "0x6451571cb5bee9fd575ad98506e96f3d09c66f91", "receipt token",
  code_size=7197, verified="Rnlp.sol", deployer=TEAM, deploy_block=1477893,
  holds={}, risky=["mint(address,uint256) onlyMinter (farm1)", "setMinter(address) onlyOwner (team EOA)"],
  verdict="ERC20 receipt token; mint rights with team. No value outside farm.")
C("rNLP token (farm2 receipt)", "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a", "receipt token",
  code_size=7197, verified="Rnlp.sol",
  holds={}, risky=["same pattern"], verdict="ERC20 receipt token; team-controlled minter.")
C("NarwhalRewardV3 - NAR/WBNB LP", "0xbe85812237741d75f81aebf1d9af52d544542168", "farm v3",
  code_size=24298, verified="NarwhalRewardV3.sol", deployer=TEAM, deploy_block=3484860,
  holds={"LP_NAR_WBNB": "1291.976394", "receiptTotalSupply": "1291.976394"},
  risky=farm_common_risky + ["setNft(address,address)/setRune(uint256)/removeRune(uint256) - NarCard integration (currently 0x0/unset, inert)",
                              "NAR minter? no (V3 farms are not in NAR.minter list)"],
  verdict="LIVE VALUE ~1292 LP. Successor farm for NAR/WBNB after V2; both still custody LP.")
C("NarwhalRewardV3 - BTCB/NAR LP", "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d", "farm v3",
  code_size=24298, verified="NarwhalRewardV3.sol", deployer=TEAM, deploy_block=3117399,
  holds={"LP_BTCB_NAR": "36.834545 (of 44.36 supply)", "NAR": "5176.734966", "receipt(rNLP 0x46d6...).totalSupply": "1827.889"},
  risky=farm_common_risky + ["router()=0xe85c6ab5 (Narwhal router)"],
  verdict="LIVE VALUE ~83% of the BTCB/NAR pool LP + 5.2k NAR. emergencyStop=false, periodFinish 2023-08-08 (emissions over).")
C("rNLP token (V3 BTCB/NAR receipt)", "0x46d603e2b9c709454316ebd244b99a8abe3bd243", "receipt token",
  code_size=7197, verified=None, deployer=TEAM,
  holds={}, risky=["minter()=farm 0x268a", "owner=team EOA"],
  verdict="Receipt token for V3 BTCB/NAR farm.")
C("NarwhalRewardSmallV2 (BTCB/NAR LP, tier 'Small')", "0xc3a471421bb1364d74b8f384cd73fe34d2ce1773", "farm size-tier",
  code_size=21820, verified="NarwhalRewardSmallV2.sol", deployer=TEAM, deploy_block=1653158,
  holds={"NAR": "1 wei", "LP": "0"}, risky=farm_common_risky, verdict="Empty size-tier farm (rnlp 0x6702ea92). No value.")
C("NarwhalRewardSmallV2 #2", "0x3dfb186e8ce513f321232098dd551e22886c1051", "farm size-tier",
  code_size=21285, verified="NarwhalRewardSmallV2.sol", deployer=TEAM, deploy_block=1678605,
  holds={"NAR": "8113.726204506 NAR", "LP_BTCB_NAR": "0.024067 (of 44.36)", "receipt": "rnlp 0x205d52f8"},
  risky=farm_common_risky, verdict="Holds ~8.1k NAR + small BTCB/NAR LP stub.")
C("PancakeSwap V1 pair: NAR/WBNB (second market)", "0x4ed7fd4f2ca11a5af9cd4519187d468d2577798b", "pair/LP (PCS)",
  deployer="(PancakeSwap factory)", holds={"reserves": "1289.6345 NAR + 0.042633 WBNB", "factory": "0xbcfccbde45ce874adcb698cc183debcf17952812 (PancakeSwap V1)"},
  risky=["standard PCS pair"], verdict="NAR also trades on PancakeSwap V2; pair holds part of NAR float. Not a Narwhal contract.")
C("NarwhalRewardMediumV2", "0x7f0414886ebf34cce32148ba0cf64dd8ec88a274", "farm size-tier",
  code_size=23463, verified="NarwhalRewardMediumV2.sol", deployer=TEAM, deploy_block=1653467,
  holds={"LP": "0", "NAR": "0"}, risky=farm_common_risky, verdict="Empty (rnlp 0xd7c7ee65).")
C("NarwhalRewardMediumV2 #2", "0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a", "farm size-tier",
  code_size=22757, verified="NarwhalRewardMediumV2.sol", deployer=TEAM, deploy_block=1678466,
  holds={"NAR": "3769.505802 NAR"}, risky=farm_common_risky, verdict="Small NAR balance only (rnlp 0x3321adb0).")
C("NarwhalRewardHugeV2", "0x657ba421cc8b1be5891aa9ac7aa2b936e5d08b65", "farm size-tier",
  code_size=23252, verified="NarwhalRewardHugeV2.sol", deployer=TEAM, deploy_block=1653576,
  holds={"LP": "0", "NAR": "0"}, risky=farm_common_risky, verdict="Empty (rnlp 0x7825d4c6).")
C("NarwhalRewardHugeV2 #2", "0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107", "farm size-tier",
  code_size=22517, verified="NarwhalRewardHugeV2.sol", deployer=TEAM, deploy_block=1678199,
  holds={"NAR": "73665.161429398"}, risky=farm_common_risky, verdict="Holds ~73.7k NAR (~$1.8k). (rnlp 0x162ece88).")
C("NarwhalRewardDividendV2 (NAR staking/dividends)", "0xb85a8c269cfc6ec4bd44e7dbd312b233a38eea0d", "dividend/staking",
  code_size=23885, verified="NarwhalRewardDividendV2.sol", deployer=TEAM, deploy_block=1795601,
  holds={"shareSupply": "2105700.210319169", "NAR": "0"}, risky=farm_common_risky,
  verdict="xNAR-style NAR staking/dividend contract. Share supply ~2.1M; currently holds no NAR.")
C("NarwhalRewardDividendV3", "0xc8e70639ad7d91d4d4bcf5d5ab8e2264abb7b25e", "dividend/staking",
  code_size=23346, verified="NarwhalRewardDividendV3.sol", deployer=TEAM, deploy_block=1822358,
  holds={"shareSupply": "2865188.899075", "NAR": "0"}, risky=farm_common_risky, verdict="xNAR-style staking contract.")
C("NarwhalRewardDividendV3 #2", "0xf7a36c87c3a8909949638120f23cd721bf572032", "dividend/staking",
  code_size=23244, verified="NarwhalRewardDividendV3.sol", deployer=TEAM, deploy_block=2081662,
  holds={"shareSupply": "987740.708364", "NAR": "1333817.135951 NAR"},
  risky=farm_common_risky + ["setUser(address,uint256,uint256,uint256,uint256,uint256,uint256) onlyGovernance - can rewrite any user's accounting",
                              "setDividendPool(address)/setFee(uint256,uint256)/setCaller(address)/setInitValue onlyGovernance","setStake(uint256,address)"],
  verdict="LIVE VALUE: holds ~1.33M NAR (largest NAR pile found in a contract). Governance (team EOA) can rewrite user records; user withdrawals are per-account.")
C("SmartChef (external NAR farm)", "0x2368bab38a79827f49fc768bf1b6d04226704d35", "third-party staking",
  code_size=5953, verified="SmartChef.sol", deployer="0x0F9399FC81DaC77908A2Dde54Bb87Ee2D17a3373 (EOA, external)", deploy_block=1871744,
  holds={"NAR": "634.063906568"},
  risky=["migrate(uint256) - currently migrator=0x0; owner can setMigrator(address) and then that migrator can pull staked LP",
         "setMigrator(address)/transferOwnership(address) onlyOwner (external EOA 0x0F9399FC...)"],
  verdict="Pancake-style SmartChef, NOT deployed by Narwhal team; owner is external EOA. If it still has stakers, owner+migrator can pull stake via migrate().")

# ---------- NFTs / game ----------
C("NarCardToken (ERC721)", "0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e", "NFT",
  code_size=16838, verified="NarCardToken.sol", deployer=TEAM, deploy_block=2078922,
  holds={"totalSupply": 9218, "team is minter": True},
  risky=["mint(address,uint256)/safeMint - minters only; team EOA is a minter", "addMinter/removeMinter/setGovernance onlyGovernance(team EOA)",
         "burn(uint256) - burns caller's own token"],
  verdict="NarCard game NFT (9,218 minted). Team holds minter+governance keys. Farm integration (_narcardToken) is NOT set on any farm -> game boost path dead.")
C("NarNft (ERC721)", "0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2", "NFT",
  code_size=9532, verified="NarNft.sol", deployer=TEAM, deploy_block=12591942,
  holds={"totalSupply": 49, "teamEOABal": 12},
  risky=["mint(uint256,address,string) - minters only", "addMinter/removeMinter onlyOwner (team EOA)"],
  verdict="Narwhalswap NFT collection (49 units, team holds 12). No value accrual path; team controls minting.")
C("NarCard dispenser/factory (unverified)", "0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1", "game/NFT dispenser",
  code_size=4422, verified=None, deployer=TEAM,
  holds={"BNB": "0", "funded_lifetime": "14.5 BNB"},
  risky=["randomCards(uint256) - card dispensing entry (mint path)", "seizeBnb() - owner rescue of BNB", "mint(uint256,address,string)", "setPrice(uint256)/setURI-ish admin setters", "pause()/unpause() owner"],
  verdict="Card dispenser linked to NarNft (nftToken()=0xce7a099a). Funded with 14.5 BNB lifetime; now holds 0. Owner=team EOA. No current value.")

# ---------- aggregator ----------
C("NarwhalSwap (meta-aggregator/swapper)", "0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4", "aggregator",
  code_size=14393, verified="NarwhalSwap.sol", deployer="0x512D86161AdE81A3e01B6b2dE8a994778F75f8cB (dev3)", deploy_block=8226086,
  holds={"BNB": "23 wei", "NAR": "95 wei", "USDT": "0.081 USDT", "WBNB": "3 wei", "BUSD": "77 wei"},
  risky=["collectRemainingEther(uint256)/collectRemainingToken(address,uint256) onlyOwner - sweep dust to owner",
         "trade(uint256,address,uint256,address,uint256,uint256)/splitTrades(...) payable public - swap entry, funds flow to msg.sender",
         "updateNarToken(address)/updatePartner(...)/addTradingRoute(...) onlyOwner"],
  verdict="Team-built swap aggregator used by the deployer EOA (110 interactions). Currently holds only dust; owner (dev3 EOA 0x512d8616) can sweep.")

# ---------- THUGS ----------
C("THUGS token (ThugsToken)", "0xe10e9822a5de22f8761919310dda35cd997d63c0", "partner token",
  code_size=15071, verified="ThugsToken.sol", deployer="0x54af6dd5b2fe9D9E50Ef56EBB7697B1ff05fd70c (external)", deploy_block=965215,
  holds={"totalSupply context": "WBNB/THUGS narwhal pair holds 84.53 WBNB + 4302.49 THUGS", "tokenContract": "0.77 BUSD + 98.79 THUGS"},
  risky=["setMinDeltaTwap(uint256)/setWhitelistedSender(address,bool)/_initializePair()/setPairAddr(address)/setWBNB(address) onlyOwner (deployer EOA 0x54af6dd5)",
         "unpause()/initializeTwap() onlyInitialDistributionAddress (0x3009c9c0...)",
         "TokenTimelock.release(IERC20) at 0x586acb4b - PUBLIC trigger, pays fixed beneficiary (burnReserves 0xfd98d6de); vault now holds only 0.0023 THUGS"],
  verdict="Partner project token (Oct 2020), paired with WBNB on the Narwhal factory. Its 273.57-LP WBNB/THUGS pool is 93% held by an EOA (see holders), not by any contract.")

# ---------- Grand Banks ----------
C("GrandBank (The Grand Banks V1 farm)", "0x08f886b14af4fc75e49d6475f46d041f5f257ce1", "TGB farm v1",
  code_size=12776, verified="GrandBank.sol", deployer="0x18527a351dB2435Fa21Db88cB87d4155188b62b0", deploy_block=6644396,
  holds={"BNB": "0", "pools": 12},
  risky=["inCaseTokensGetStuck(address,uint256) onlyOwner (owner=Timelock 0xd68415...)",
         "migrateToGrandV2(uint256) PUBLIC 1:1 V1->V2 mint but require(block.number < 7076050) -> DEAD (past deadline)",
         "deposit/withdraw variants user-scoped"],
  verdict="V1 farm of the team's second protocol; owner is TimelockController (24h delay). All 12 pools have allocPoint 0; strategies may hold用户 LP (see strategy scan).")
C("TheGrandBanks (TGB V2 farm)", "0x3d8fd880976a3ea0f53cad02463867013d331107", "TGB farm v2",
  code_size=14591, verified="TheGrandBanks.sol", deployer="0xab3921C5De7e3459CE07f7015B3FDF0EBEC927EF (dev2)", deploy_block=6872911,
  holds={"CatoToken(GRANDV2)": "1448.012458 CATO", "USDT": "31.122768 USDT", "pools": 80},
  risky=["inCaseTokensGetStuck(address,uint256) onlyOwner - drain any token except GrandV2 from farm (owner=dev2 EOA 0xab3921)",
         "inCaseBNBGetStuck(uint256) onlyOwner",
         "migrateToGrandV2(uint256) - deadline check (dead)",
         "add/set/pool management onlyOwner"],
  verdict="V2 farm with 80 pools and per-pool strategies; owner is a single dev EOA (not timelock). Can sweep non-GRAND tokens from the farm shell; user principal sits in strategies.")
C("Grand (GRAND v1 token)", "0xd37ebaeb28c0a6c9a62d5c5c0119d464e28b367e", "TGB token",
  code_size=None, verified="Grand.sol", deployer="0x18527a351dB2435Fa21Db88cB87d4155188b62b0", deploy_block=6644323,
  holds={"totalSupply": "776.0226764568765 GRAND"},
  risky=["mint(address,uint256) onlyOwner (owner=GrandBank V1 0x08f886, which is timelock-owned)"],
  verdict="Dead v1 token superseded by V2 (migrate path closed).")
C("CatoToken (GRAND V2 / 'CatoToken')", "0xee814f5b2bf700d2e843dc56835d28d095161dd9", "TGB token",
  code_size=None, verified="CatoToken.sol (minted to farm as GrandV2)", deployer="0xab3921C5De7e3459CE07f7015B3FDF0EBEC927EF", deploy_block=6872790,
  holds={"totalSupply": "30075.410746743"},
  risky=["mint(address,uint256) - GrandToken interface used by the farm (owner controls)"],
  verdict="GRAND v2 emission token; emissions capped/over. Farm holds 1448 CATO pending.")
C("TimelockController (TGB V1)", "0xd68415507d4beb355aeec2f0d52938800c7b62e0", "timelock",
  code_size=None, verified="TimelockController.sol", deployer="0x18527a351dB2435Fa21Db88cB87d4155188b62b0", deploy_block=6677102,
  holds={}, risky=["minDelay=86400s", "PROPOSER/EXECUTOR = devWallet 0x18527a", "devWalletAddress hardcoded 0x18527a..."],
  verdict="Owns GrandBank V1 (and many strategies are gov=timelock/EOAs). Team can queue+execute drains after delay; users have no veto (admin role with team EOA).")
C("StrategyCake instances (x~92)", "see strategy_scan.json (strat addresses per pool)", "leveraged strategies",
  verified="StrategyCake.sol (spot-verified)", deployer="(team dev wallets)",
  holds={"aggregate": "user LP inside strategies; live (nonzero wantLockedTotal) strategies hold modest balances; biggest single ≈1.7 LP-equivalent"},
  risky=["deposit(address,uint256)/withdraw(address,uint256) onlyOwner(=farm)","earn() public whenNotPaused (if onlyGov=false anyone can compound; fees to gov)",
         "pause()/unpause()/setGov/setControllerFee/setbuyBackRate/setEntranceFeeFactor govAddress only",
         "inCaseTokensGetStuck(address,uint256,address) govAddress only - cannot take want/earned",
         "rebalance/deleverageOnce/wrapBNB - timelock-gated in later deployments (interface IStrategy)"],
  verdict="User funds sit in ~92 strategy contracts (leveraged Pancake/Venus positions). Strategy owner = farm; gov = team/timelock. No permissionless drain found; rescue functions exclude want/earned.")
C("FryingDutchMan Landing/Sailing servicers (x~20)", "see strategy_value.json fry[]", "liquidity servicers",
  verified="FryingDutchManLanding.sol / Sailing.sol", deployer="(team dev wallets)",
  holds={"BNB": "0 (all instances)"},
  risky=["execute(address,address,address,uint256,bool) external payable NON-PROTECTED - sends proceeds of any residual balances it holds to msg.sender (drains only stray funds, not user principal)",
         "recover(address,address,uint256) onlyOwner"],
  verdict="Stateless helpers by design ('should not hold ERC20'). Currently empty. execute() is a permissionless msg.sender payout path for any leftovers.")

# ---------- LP pairs ----------
C("Narwhalswap pair: NAR/WBNB LP", "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2", "pair/LP",
  code_size=8701, deployer="(factory)", deploy_block=1281282,
  holds={"reserves": "5,444,067.4186 NAR + 181.4527 WBNB", "totalSupply": "25004.5519 LP", "topHolders": "farm1 2243.79; be8581(V3 farm) 1291.98; 186be2(V1 farm) 297.16; 236 EOAs (largest ~81.9 LP)"},
  risky=["public swap/mint/burn (permissionless by design)"], verdict="Live pair; LP largely held by farms + 236 EOA wallets.")
C("Narwhalswap pair: WBNB/THUGS LP", "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957", "pair/LP",
  code_size=8701, deployer="(factory)", deploy_block=1552822,
  holds={"reserves": "84.5312 WBNB + 4302.495 THUGS", "totalSupply": "273.56821 LP", "topHolders": "EOA 0x4d710603... = 254.40 LP (93%); EOA 0xe99140fc... = 18.10 LP; contract 0xb752f0cb (OriginalGangster, THUGS-deployer project) = 1.0587 LP; collecter dust"},
  risky=["pair is itself token0 of a wrapped dust pair 0x8b1bbfaf (created post-20M block window)"],
  verdict="HIGHEST-VALUE pool touched by the ecosystem (~84.5 WBNB ≈ $63k). 93% of LP held by a single EOA (inactive); no contract payout path. Any LP holder can burn for their share.")
C("Narwhalswap pair: WBNB/BUSD LP", "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3", "pair/LP",
  code_size=8701, deployer="(factory)", deploy_block=900224,
  holds={"reserves": "13.4437 WBNB + 10090.778 BUSD", "totalSupply": "285.4709 LP", "topHolders": "V1 farm bb38f755 = 231.53 LP (81%); EOA a9d5f138 = 33.68 LP; farm2 = 11.94 LP; 105 addresses"},
  risky=["public pair functions"], verdict="81% of LP custodied by the V1 farm; rest by EOAs/claims.")
C("Wrapped dust pairs (LP-in-LP)", "0x00eda48b..., 0x8b1bbfaf..., 0x6166911e...", "dust pairs",
  deployer="(random users, after block 20M)", holds={"reserves": "~2.7e12 LP-wei / ~1.26e9 WBNB-wei etc. (dust)"},
  risky=[], verdict="Fan-created 'LP-in-LP' pairs wrapping already-issued LPs with WBNB; economically empty (created post-2022). DEAD END.")

# ---------- dead ends / negative findings ----------
dead_ends = [
 "NarCard integration on farms is NOT configured: _narcardFactory()/_narcardToken() = 0x0 on V2 and V3 farms -> setRune/removeRune revert (checkSetNFT). NarCardToken (9218) and NarNft (49) exist but no farm accepts them.",
 "No 'NarwhalRewardV1-size' Small/Medium/Huge tier found beyond the V2-named instances; any V1 predecessor tiers were not located via NAR flows (scans partial).",
 "migrateToGrandV2(uint256) - the only Narwhal-team 'migration' found - is dead: require(block.number < 7076050), current block ~127.2M.",
 "SmartChef.migrate(uint256) exists but migrator=0x0, owner=external EOA 0x0F9399FC...; not a Narwhal-held contract.",
 "TokenTimelock.release(IERC20) for THUGS (vault 0x586acb4be6cc93aa5c399888b255c7e864ea508e) is permissionless but already drained (holds only 0.0023 THUGS).",
 "BscScan live scraping via firecrawl/webfetch was blocked (Cloudflare; keyless firecrawl quota); used Wayback Machine snapshot (2024-09-12) instead.",
 "Blockscout has no BSC instance; public BSC RPCs cap eth_getLogs at 25-50 blocks (bsc-rpc.publicnode.com, 1rpc, dataseeds); scans used a public NodeReal demo endpoint (50k-block range) transiently, not persisted.",
 "EIP-1167 23-byte proxy clones dominate NAR reward recipients (286 of 5,206 recipient addresses) - user smart wallets, not ecosystem contracts.",
]
contracts = [c for c in contracts if c.get("holds_value") is not None]

out = {
  "block": block,
  "block_note": "All balances read at ~block %d (2026-10-12). Scans: factory PairCreated 800k-20M; LP+rNLP Transfer logs 1.30M-20M; NAR filtered flows 1.27M-~7.5M (partial, checkpointed)." % block,
  "team": {
    "feeToSetter_teamEOA": {"address": TEAM, "bnb": "0.7774474727630566", "NAR": "563.445698367", "WBNB": "0.001380023", "CATO": "39.9985224337", "role": "deployer (BscScan label 'Narwhalswap: Deployer'), feeToSetter, governance of all Narwhal contracts, one of 3 NAR minters"},
    "teamWallet_507b": {"address": "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9", "bnb": "0.0867037424", "NAR": "87117.031250697", "role": "teamWallet in farms"},
    "nar_rewardPool": {"address": "0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960", "bnb": "1.4657232575783", "NAR": "2530.351564646", "role": "NAR._rewardPool + V3 farm teamWallet"},
    "nar_teamWallet_var": {"address": "0x00470220dd82d5429379c8d9f679774b0e6e651d", "balances": "0 (checked tokens)", "role": "NAR._teamWallet"},
    "factory_deployer_c76827": {"address": "0xc76827cce55338cbd6b399f45a75df0cd5da2749", "bnb": "0", "dust": "1571 wei NAR + 0.0053 LP_WBNBBUSD"},
    "dev1_grandbanks_18527a": {"address": "0x18527a351db2435fa21db88cbb87d4155188b62b0", "bnb": "0", "role": "deployed Grand/GrandBank V1/Timelock; timelock proposer/executor"},
    "dev2_grandbanks_ab3921": {"address": "0xab3921c5de7e3459ce07f7015b3fdf0ebec927ef", "bnb": "0.2770573757", "BUSD": "77.363905251", "CATO": "1965.705098659", "role": "owner of TheGrandBanks V2 + CatoToken"},
    "dev3_narwhalswap_512d86": {"address": "0x512d86161ade81a3e01b6b2de8a994778f75f8cb", "bnb": "0", "role": "deployer/owner of NarwhalSwap aggregator; strategy gov"},
    "dev4_6abfae83": {"address": "0x6abfae833ca1a4e9a9d482dfeebcc5ecec635e90", "bnb": "0.000077597359872", "role": "strategy gov"},
  },
  "thugs_project_wallets": {
    "deployer": "0x54af6dd5b2fe9d9e50ef56ebb7697b1ff05fd70c (0.302967928 BNB)",
    "initialDistribution": "0x3009c9c09a467aaea1c8d8cd6ebd18bfb4339b9b",
    "burnReserves": "0xfd98d6dedc7ed8556ba61dc7902799c9815a5722",
    "team": "0x6e65f24a9c7230c3bfbe90f39924ac8384f6152f (0.00818813442 BNB, 17.923796276 THUGS)",
    "dev": "0x4e43397417c6938f60b108650d832390dbd4c4fd",
    "marketing": "0x481f0079bb59d8feb2426b6e08a2af01d7b49500 (0.000798 BNB)",
    "tokenTimelock": "0x586acb4be6cc93aa5c399888b255c7e864ea508e (0.0023138045717401 THUGS left)",
  },
  "factory_stats": {"pairs": 96, "first_pair_block": 847884, "last_pair_block": ">20M (2 pairs created after block 20M; all pairs to 14.68M are 2020-2022 era)"},
  "pairs_scanned": "paircreated.json (94 pairs <= 20M)",
  "contracts": contracts,
  "lp_holders": {
    "LP_WBNB_THUGS": holders["holders"].get("LP_WBNB_THUGS"),
    "LP_NAR_WBNB_top20": (holders["holders"].get("LP_NAR_WBNB") or [])[:20],
    "LP_WBNB_BUSD_top20": (holders["holders"].get("LP_WBNB_BUSD") or [])[:20],
    "notes": "Full holder lists in lp_holders.json. Sum of current balances matches LP supply (verified for WBNB/THUGS: 273.56805 vs 273.56821 incl. 1e-15 locked minimum).",
  },
  "grand_banks_value": {
    "farm_v1_pools": 12, "farm_v2_pools": 80,
    "strategies_with_nonzero_state": len(strat.get("live", [])),
    "live_strategies_sample": strat.get("live", [])[:25],
    "fry_servicers": strat.get("fry", []),
  },
  "nar_minters": minters.get("nar_minters"),
  "dead_ends": dead_ends,
}
json.dump(out, open(os.path.join(BASE, "ecosystem.json"), "w"), indent=1, default=str)
print("wrote ecosystem.json:", len(contracts), "contracts; block", block)
