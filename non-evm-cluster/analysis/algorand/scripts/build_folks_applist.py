"""Build the master Folks app list from known IDs + deployer enumerations."""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # .../algorand
RAW = os.path.join(BASE, "folks", "raw")

v1_pools = {
    686498781: "v1_pool_ALGO",
    794055220: "v1_pool_gALGO",
    686500029: "v1_pool_USDC",
    686500844: "v1_pool_USDt",
    686501760: "v1_pool_goBTC",
    694405065: "v1_pool_goETH",
    694464549: "v1_pool_gALGO3",
    805843312: "v1_pool_TMP11_USDCgALGO",
    805846536: "v1_pool_PLP_ALGOgALGO",
    743679535: "v1_pool_TMP11_ALGOgALGO3",
    743685742: "v1_pool_PLP_ALGOgALGO3",
    747237154: "v1_pool_TMP11_ALGOUSDC",
    747239433: "v1_pool_PLP_ALGOUSDC",
    776179559: "v1_pool_TMP11_USDCUSDt",
    776176449: "v1_pool_PLP_USDCUSDt",
    751285119: "v1_pool_Planets",
    818026112: "v1_pool_PLP_goBTCgALGO",
    818028354: "v1_pool_PLP_goETHgALGO",
}
v1_aux = {
    956833333: "v1_oracle",
    751277258: "v1_oracle_adapter",
}
v1_creators_pool_only = {
    686498781: "v1_pool_ALGO",
}
v2_pools = {
    971368268: "v2_pool_ALGO",
    971370097: "v2_pool_gALGO",
    2611131944: "v2_pool_xALGO",
    3073474613: "v2_pool_tALGO",
    971372237: "v2_pool_USDC",
    971372700: "v2_pool_USDt",
    1060585819: "v2_pool_GARD",
    1247053569: "v2_pool_EURS",
    971373361: "v2_pool_goBTC",
    971373611: "v2_pool_goETH",
    1067289273: "v2_pool_WBTC_old",
    1067289481: "v2_pool_WETH_old",
    1166977433: "v2_pool_WAVAX",
    1166980669: "v2_pool_WSOL",
    1216434571: "v2_pool_WLINK",
    1258515734: "v2_pool_GOLD",
    1258524099: "v2_pool_SILVER",
    1044267181: "v2_pool_OPUL",
    1166982094: "v2_pool_WMPL",
    3184317016: "v2_pool_ECO_ALGO",
    3184324594: "v2_pool_ECO_USDC",
    3184325123: "v2_pool_ECO_TINY",
    3343137163: "v2_pool_ECO_FOLKS",
    3514794123: "v2_pool_WBTC_NTT",
    3514795114: "v2_pool_WETH_NTT",
}
v2_aux = {
    971350278: "v2_pool_manager",
    971353536: "v2_deposits",
    1093729103: "v2_deposit_staking",
    971388781: "v2_loan_general",
    971388977: "v2_loan_stablecoin_eff",
    971389489: "v2_loan_algo_eff",
    1202382736: "v2_loan_ultraswap_up",
    1202382829: "v2_loan_ultraswap_down",
    3184333108: "v2_loan_algo_ecosystem",
    1040271396: "v2_oracle0",
    971323141: "v2_oracle1",
    971333964: "v2_oracle_adapter",
    1167143153: "v2_opup_caller",
    971335616: "v2_opup_base",
}
xalgo = {
    1134695678: "xalgo_consensus_1134695678",
    2633147490: "xalgo_stake_and_deposit",
}
galgo = {
    793119194: "galgo_dispenser",
    793119270: "galgo_govdist4",
    887391617: "galgo_govdist5a",
    902731930: "galgo_govdist5b",
    991196662: "galgo_govdist6",
    1073098885: "galgo_govdist7",
    1136393919: "galgo_govdist8",
    1200551652: "galgo_govdist9",
    1282254855: "galgo_govdist10",
    1702641473: "galgo_govdist11",
    2057814942: "galgo_govdist12",
    2330032485: "galgo_govdist13",
    2629511242: "galgo_govdist14",
}

# deprecated/aux apps from deployer sweeps (not already labelled)
apps = {}
for d in (v1_pools, v1_aux, v2_pools, v2_aux, xalgo, galgo):
    apps.update(d)

deployer_file = os.path.join(RAW, "folks_deployer_apps.json")
dep = json.load(open(deployer_file))
for creator, lst in dep.items():
    for a in lst:
        apps.setdefault(a["id"], f"deployer_{creator[:6]}_app")

with open(os.path.join(RAW, "folks_app_list.json"), "w") as f:
    json.dump({str(k): v for k, v in sorted(apps.items())}, f, indent=1)
print("total apps:", len(apps))
from collections import Counter
print(Counter(v.split("_")[0] for v in apps.values()))
