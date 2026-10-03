#!/usr/bin/env python3
import sys
sys.set_int_max_str_digits(200000)
"""C-37 native protocol measurement pass 2: SetV1 Vault, Index Coop DPI, PieDAO, PowerPool,
BasketDAO, Yam EMP, Indexed pools, Cook CLI. Light read-only calls."""
import json, sys, urllib.request, time, concurrent.futures as cf

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://eth.drpc.org"

def rpc(method, params):
    req = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    for a in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(
                    RPC, json.dumps(req).encode(),
                    {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}), timeout=20) as r:
                j = json.load(r)
            if "result" in j:
                return j["result"]
        except Exception:
            time.sleep(0.3 * (a + 1))
    return None

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def bal(token, who):
    r = call(token, "0x70a08231" + "0" * 24 + who[2:].lower())
    return int(r, 16) if r and r != "0x" else None

def u256(to, sel):
    r = call(to, sel)
    return int(r, 16) if r and r != "0x" else None

def addr(to, sel):
    r = call(to, sel)
    return "0x" + r[-40:] if r and len(r) >= 42 else None

TOKENS = {
 "WETH":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","WBTC":"0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
 "LINK":"0x514910771AF9Ca656af840dff83E8264EcF986CA","cUSDC":"0x39AA39c021dfbaE8faC545936693aC917d5E7563",
 "cDAI":"0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643","COMP":"0xc00e94Cb662C3520282E6f5717214004A7f26888",
 "USDC":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","DAI":"0x6B175474E89094C44Da98b954EedeAC495271d0F",
 "SAI":"0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359","MKR":"0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2",
 "UNI":"0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984","AAVE":"0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
 "LDO":"0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32","RPL":"0xD33526068D116cE69F19A9ee46F0bd304F21A51f",
 "PENDLE":"0x808507121B80c02388fAd14726482e061B8da827","ENA":"0x57e114B691Db790C35207b2e685D4A43181e6061",
 "SNX":"0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F","SUSHI":"0x6B3595068778DD592e39A122f4f5a5cF09C90fE2",
 "YFI":"0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e","BAL":"0xba100000625a3754423978a60c9317c58a424e3D",
 "LRC":"0xBBbbCA6A901c926F240b89EacB641d8Aec7AEafD","REN":"0x408e41876cCCDC0F92210600ef50372656052a38",
 "UMA":"0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828","MLN":"0xec67005c4E498Ec7f55E092bd1d35cbC47C91892",
 "PNT":"0x89Ab32156e46F46D02ade3FEcbe5Fc4243B9AAeD","CVP":"0x38e4adB44ef08F22F5B5b76A8f0c2d0dCbE7DcA1",
 "wNXM":"0x0d438F3b5175Bebc262bF23753C1E53d03432bDE","USTONKS":"0xEC58d3aefc9AAa2E0036FA65F70d569f49D9d1ED",
 "yvYFI":"0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1","cCOMP":"0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4",
 "yvSNX":"0xF29AE508698bDeF169B89834F76704C3B205aedf","xSUSHI":"0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272",
 "CREAM":"0x2ba592F78dB6436527729929AAf6c908497cB200","yvBOOST":"0x9d409a0A012CFbA9B15F6D4B36Ac57A46966Ab9a",
 "ZRX":"0xE41d2489571d322189246DaFA5ebDe1F4699F498","yvUNI":"0xFBEB78a723b8087fD2ea7Ef1afEc93d35E8Bed42",
 "yvCurveLINK":"0xf2db9a7c0ACd427A680D640F02d90f6186E71725","KNC":"0xdd974D5C2e2928deA5F71b9825b8b646686BD200",
}
def tb(owner, syms):
    out = {}
    for s in syms:
        v = bal(TOKENS[s], owner)
        if v: out[s] = v
    return out

res = {"block": int(rpc("eth_blockNumber", []), 16)}

# Set V1 Vault
VAULT = "0x5b67871c3a857de81a1ca0f9f7945e5670d986dc"
res["setv1_vault"] = {"owner": addr(VAULT, "0x8da5cb5b"), "balances": tb(VAULT, ["WETH","WBTC","LINK","cUSDC","cDAI","COMP","USDC","DAI","SAI","MKR"])}

# DPI
DPI = "0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b"
res["dpi"] = {"totalSupply": u256(DPI, "0x18160ddd"),
              "balances": tb(DPI, ["COMP","MKR","UNI","AAVE","LDO","RPL","PENDLE","ENA"])}

# PieDAO DEFI++
DEFIPP = "0x8D1ce361eb68e9E05573443C407D4A3Bed23B033"
res["defipp"] = {"totalSupply": u256(DEFIPP, "0x18160ddd"),
                 "balances": tb(DEFIPP, ["LINK","COMP","MKR","SNX","UNI","SUSHI","AAVE","YFI","BAL","LRC","REN","UMA","MLN","PNT"])}

# PowerPool PIPT
PIPT = "0x26607aC599266b21d13c7aCF7942c774B946ba37"
res["pipt"] = {"totalSupply": u256(PIPT, "0x18160ddd"),
               "balances": tb(PIPT, ["AAVE","YFI","SNX","CVP","COMP","wNXM","MKR","UNI"])}

# BasketDAO BDI
BDI = "0x0309c98B1bffA350bcb3F9fB9780970CA32a5060"
res["bdi"] = {"totalSupply": u256(BDI, "0x18160ddd"),
              "balances": tb(BDI, ["yvYFI","cCOMP","yvSNX","MKR","REN","xSUSHI","CREAM","yvCurveLINK","yvBOOST","ZRX","yvUNI","AAVE","BAL","LRC","KNC"])}

# Yam EMP
EMP = "0x4F1424Cef6AcE40c0ae4fc64d74B734f1eAF153C"
res["yam_emp"] = {
    "expirationTimestamp": u256(EMP, "0x9f43ddd2"),
    "collateralCurrency": addr(EMP, "0x0de15fd9"),
    "totalPositionCollateral": u256(EMP, "0x43e4771b"),
    "totalTokensOutstanding": u256(EMP, "0x0c9229ca"),
}
res["yam_emp"]["collateral_balance"] = bal(res["yam_emp"]["collateralCurrency"] or "0x0", EMP) if res["yam_emp"]["collateralCurrency"] else None
res["ustonks_supply"] = u256(TOKENS["USTONKS"], "0x18160ddd")

# Indexed Finance pools
for name, pool in {"DEFI5":"0xfa6de2697D59E9458c5FC42054DD0E6CAe17a07e",
                   "CC10":"0x17ac188e09A7890a1844e5E65471fE8b0cCfaDf3",
                   "DEGEN":"0x126c121f99e1E211dF2e5f8De2d96Fa36647c855"}.items():
    res[f"indexed_{name}"] = {"code": rpc("eth_getCode", [pool, "latest"]) not in (None, "0x"),
                              "totalSupply": u256(pool, "0x18160ddd"),
                              "balances": tb(pool, ["LINK","UNI","AAVE","MKR","COMP","SNX","YFI","SUSHI","BAL","UMA","REN","LRC","MLN","PNT","CVP","wNXM"])}

# Cook CLI
CLI = "0xA6156492fC79616035F644C71b01e3099819F8EC"
res["cook_cli"] = {"totalSupply": u256(CLI, "0x18160ddd"), "balances": tb(CLI, ["WBTC","WETH"])}

print(json.dumps(res, indent=1))
json.dump(res, open("/home/heisenberg/CA/c-37/analysis/native_scan2.json", "w"), indent=1)
