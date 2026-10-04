#!/usr/bin/env python3
"""Deep read-only state dump for Alpaca AUSD on BSC (block-pinned, eth_call only)."""
import json, os, sys, urllib.request

ENV = "/home/heisenberg/CA/.env"
KEY = os.environ.get("NODEREAL_API_KEY")
if not KEY and os.path.exists(ENV):
    for line in open(ENV):
        line = line.strip()
        if line.startswith("NODEREAL_API_KEY="):
            KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
RPC = f"https://bsc-mainnet.nodereal.io/v1/{KEY}"

BLOCK = int(sys.argv[1])
OUT = sys.argv[2] if len(sys.argv) > 2 else "deep_state.json"

AUSD = "0xDCEcf0664C33321CECA2effcE701E710A2D28A3F"
BK   = "0xD0AEcee1520B5F9925D952405F9A06Dcd8fd6e6C"
SDE  = "0xe09E20aB1F91D1f7EAa0e73446b0617d89501b0E"
SS   = "0x9b601FBAd19036D6E074caDAF61CD70ea2513318"
CPC  = "0x06D280abee1073B83A01fE778B6145e850e87162"
PM   = "0xABA0b03eaA3684EB84b51984add918290B41Ee19"
FMM  = "0xE7a49Ae5c9500d18481e0E0EFBFF1D5d0FF75DE3"
SSM  = "0xd16004424b9C3f0A7C74C4c8dcDa0D8C4D513fAC"
LE   = "0x51B893FF705b08784da29d9BAdE2d72dD353C".replace("51B893FF705b0", "51B893FF705b0")  # placeholder fixed below
LE   = "0x51B893FF705b08784da29d9BAdE2d72dD353C"
ACC  = "0x0780d461480a3386031498f264a91f3d473A181a"
SAD  = "0xD409DA25D32473EFB0A1714Ab3D0a6763bCe4749"
BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
ADAPTER_BUSD = "0x8fff07f961e75Dcced6f1620386D91E66109A9e9"
ADAPTERS_IB = {
    "ibBUSD": "0x4f56a92cA885bE50E705006876261e839b080E36",
    "ibUSDT": "0x2B356b9Cd4B00658faCC35f4d031DF528eE9778D",
    "ibWBNB": "0x4Bf04730C37fc395B5F780E6Ad3E397C031F6d39",
}
IBTOKEN = {
    "ibBUSD": "0x7C9e73d4C71dae564d41F78d56439bB4ba87592f",
    "ibUSDT": "0x158Da805682BdC8ee32d52833aD41E74bb951E59",
    "ibWBNB": "0xd7D069493685A581d27824Fc46EdA46B7EfC0063",
}
FEED_IBUSD = {
    "ibBUSD": "0x4a89F897AA97D096dBeA0f874a5854662996f8ae",
    "ibUSDT": "0xFB6A378b5e5bBc6F413DdDf07873076851a00fD1",
    "ibWBNB": "0x44b930F2e53231B3F85495229eA644724C93c617",
}
FEED_SUB = {
    "ibBUSD-BUSD": "0xEA4e46420065C7Df0B931424A75C150474d72AC7",
    "ibUSDT-USDT": "0xee1D99C9B85dCbbe4773767795EED23Fa8190731",
    "ibWBNB-WBNB": "0xF7E3B6C8AC5047c6aCf328C6c9c43EcDf15cD534",
    "BUSD-USD": "0x9F748f798C75EA44F86a5871045629a2aC9C0568",
    "USDT-USD": "0x2B9C18a7e2F067E006E4625a74174472E9F89559",
    "WBNB-USD": "0xdE375D37Be6399022D6583c954a011a9244a0b61",
}
STATIC_FEED = "0xD67286e5969ca0D2ad282EB4eDa4B51d60A9eB45"
SIMPLE_ORACLE = "0x166f56F2EDa9817cAB77118AE4FCAA0002A17eC7"
CHAINLINK_ORACLE = "0x634902128543b25265da350e2d961C7ff540fC71"
VAULT_ORACLE = "0xdb4A41CdaBd4CA7AB9AF3Db346106245CB3f7968"
FIXED_STRATEGY = "0x4633A11702a5751fB4836F5ecD3eDd8d86852eE9"
TIMELOCK = "0x2D5408f2287BF9F9B05404794459a846651D0a59"
MULTISIG = "0x18F59e8dDDef9e000863082a37fc56a2a5475D01"
STABILITY = "0x45040e48C00b52D9C0bd11b8F577f188991129e6"
PRICE_ORACLE = "0x4C7fb2214e6D782Dc0152ea39c39166F666cA367"
FLASH_LIQ = "0x7940E34ad993D14374C28d96AdB26f54b69B292c"
GETPOS = "0x878ef0130340B8375de06287A47A6C9c2bd26618"
PWF = "0x56F2d6FE1ACB1549A665ff3a6E7dc46753f4a116"
DEAD = "0x000000000000000000000000000000000000dEaD"

SEL = {
    "collateralToken": "f8be242c",
    "totalShare": "026c4207",
    "positions": "29d88594",
    "fairlaunch": "944eef42",
    "pid": "f1068454",
    "poolInfo": "1526fe27",
    "userInfo": "93f1a40b",
    "pendingAlpaca": "94443b73",
    "alpaca": "94faab23",
    "owner": "8da5cb5b",
    "balanceOf": "70a08231",
    "totalSupply": "18160ddd",
    "price": "a035b1fe",
    "lastUpdate": "c0463711",
    "priceLife": "5af639c3",
    "paused": "5c975abb",
    "peekPrice": "140d2720",
    "readPrice": "7e91400f",
    "peekNextPrice": "5bf851b7",
    "lastUpdateTimestamp": "14bcec9f",
    "timeDelay": "c9dec361",
    "getPrice2": "ac41865a",
    "hasRole": "91d14854",
    "authTokenAdapter": "e723b977",
    "stablecoinAdapter": "46a311d3",
    "systemDebtEngine": "28e49a42",
    "feeIn": "769a48d9",
    "feeOut": "0696819f",
    "collateralPoolId": "dca07dc5",
    "cageCoolDown": "3b4a5210",
    "cagePrice": "bfb934c4",
    "finalCashPrice": "f25e7ee5",
    "flashLendingEnabled": "df1a4b73",
    "stablecoinAccumulator": "001a0fda",
    "cagePrice": "bfb934c4",
    "finalCashPrice": "f25e7ee5",
    "live": "957aa58c",
    "debt": "0dca59c1",
    "stablecoin": None,
}

ROLES = {
    "OWNER": "0x" + "00" * 32,
    "GOV_ROLE": "0x0603f2636f0ca34ae3ea5a23bb826e2bd2ffd59fb1c01edc1ba10fba2899d1ba",
    "PRICE_ORACLE_ROLE": "0x1337d7d57528a8879766fdf2d0456253114c66c4fc263c97168bfdb007c64c66",
    "ADAPTER_ROLE": "0xdbeb657137b1822b3d5418bea6fd641226d964b4c3871ef23546db2622258871",
    "LIQUIDATION_ENGINE_ROLE": "0x73cc1824a5ac1764c2e141cf3615a9dcb73677c4e5be5154addc88d3e0cc1480",
    "STABILITY_FEE_COLLECTOR_ROLE": "0x515cd6857d3fa5ea767894c7605f2a1266baaf48168f41fb0ae14a219567d6a4",
    "SHOW_STOPPER_ROLE": "0xa5b93761cdcf4730aa6f4ed2fccea400435617d3fb902128f8d4cf7f6265b306",
    "POSITION_MANAGER_ROLE": "0x6af7a8f7f9ca95b722bc4d8832aeefb2b4e004a3a488a8f38b84605fa58e809b",
    "MINTABLE_ROLE": "0x79dc86561fc62d7eb9a727d180af689d208d86aa03e0931051e770b97b8f8fac",
    "BOOK_KEEPER_ROLE": "0x1cf2b81dce95f0e7b91e95903f9b70bc58c33207c55b6b0bc3ba3d0522942e31",
    "COLLATERAL_MANAGER_ROLE": "0x85e8f2d6819d6b24108062d87ea08f54651bcb8960d98062d3faf96e7873b8b9",
    "MINTER_ROLE": "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
}

POOLS = {n: "0x" + n.encode().hex().ljust(64, "0") for n in ["ibBUSD", "ibUSDT", "ibWBNB", "BUSD-STABLE"]}


def batch(calls, chunk=50):
    """calls: list of (to, data). Returns list of hex results."""
    out = []
    for i in range(0, len(calls), chunk):
        payload = [
            {"jsonrpc": "2.0", "id": i + j, "method": "eth_call",
             "params": [{"to": to, "data": data}, hex(BLOCK)]}
            for j, (to, data) in enumerate(calls[i:i + chunk])
        ]
        req = urllib.request.Request(RPC, json.dumps(payload).encode(), {"Content-Type": "application/json"})
        resp = json.load(urllib.request.urlopen(req))
        byid = {r["id"]: r for r in resp}
        for j in range(len(calls[i:i + chunk])):
            r = byid.get(i + j, {})
            out.append(r.get("result") if "result" in r else ("ERR:" + json.dumps(r.get("error", {}))[:120]))
    return out


def u(hexstr):
    if not hexstr or hexstr.startswith("ERR"):
        return hexstr
    return str(int(hexstr, 16))


def a(hexstr):
    if not hexstr or hexstr.startswith("ERR"):
        return hexstr
    return "0x" + hexstr[-40:]


def enc(u256):
    return hex(u256)[2:].rjust(64, "0")


def enc_addr(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")


state = {"block": BLOCK, "rpc": "nodereal", "calls": {}, "positions_free": {}}

pos_raw = json.load(open("positions_raw.json"))
posmap = pos_raw["positions"]

# 1. free collateral for every position
calls, ids = [], []
for pid, p in sorted(posmap.items(), key=lambda kv: int(kv[0])):
    pool = p["poolId"] or ("0x" + "00" * 32)
    calls.append((BK, "0x" + SEL["collateralToken"] + pool[2:].rjust(64, "0") + p["position"][2:].rjust(64, "0")))
    ids.append(pid)
res = batch(calls)
free_total = {}
for pid, r in zip(ids, res):
    v = u(r)
    state["positions_free"][pid] = v
    pool = posmap[pid]["poolId"]
    if isinstance(v, str) and not v.startswith("ERR") and int(v) > 0:
        free_total[pool] = free_total.get(pool, 0) + int(v)
state["free_collateral_total_by_pool"] = {k: str(v) for k, v in free_total.items()}

# 2. adapter basics
calls, labels = [], []
for name, ad in ADAPTERS_IB.items():
    calls += [(ad, "0x" + SEL["fairlaunch"]), (ad, "0x" + SEL["pid"]), (ad, "0x" + SEL["totalShare"]),
              (ad, "0x" + SEL["paused"]), (ad, "0x" + SEL["live"])]
    labels += [f"{name}.fairlaunch", f"{name}.pid", f"{name}.totalShare", f"{name}.paused", f"{name}.live"]
res = batch(calls)
ad_info = {}
for (name, ad) in ADAPTERS_IB.items():
    pass
ptr = 0
fairlaunch_addr = {}
for name, ad in ADAPTERS_IB.items():
    v = res[ptr:ptr + 5]; ptr += 5
    ad_info[name] = {"adapter": ad, "fairlaunch": a(v[0]), "pid": u(v[1]), "totalShare": u(v[2]),
                     "paused": u(v[3]), "live": u(v[4])}
    fairlaunch_addr[name] = a(v[0])
state["adapters_ib"] = ad_info

# 3. FairLaunch per adapter
calls, labels = [], []
for name, info in ad_info.items():
    fl = info["fairlaunch"]; pid = int(info["pid"]); ad = info["adapter"]
    calls += [(fl, "0x" + SEL["poolInfo"] + enc(pid)),
              (fl, "0x" + SEL["userInfo"] + enc(pid) + enc_addr(ad)),
              (fl, "0x" + SEL["pendingAlpaca"] + enc(pid) + enc_addr(ad))]
    labels += [f"{name}.poolInfo", f"{name}.userInfo", f"{name}.pendingAlpaca"]
fl_extra = batch([(fairlaunch_addr["ibBUSD"], "0x" + SEL["alpaca"]), (fairlaunch_addr["ibBUSD"], "0x" + SEL["owner"])])
state["fairlaunch_alpaca"] = a(fl_extra[0]); state["fairlaunch_owner"] = a(fl_extra[1])
res = batch(calls)
fl_info = {}
ptr = 0
for name in ad_info:
    pi, ui, pa = res[ptr:ptr + 3]; ptr += 3
    fl_info[name] = {"poolInfo_raw": pi, "userInfo_raw": ui, "pendingAlpaca": u(pa)}
    try:
        body = bytes.fromhex(pi[2:])
        fl_info[name]["poolInfo"] = {
            "stakeToken": "0x" + body[12:32].hex(), "allocPoint": u("0x" + body[32:64].hex()),
            "lastRewardBlock": u("0x" + body[64:96].hex()),
            "accAlpacaPerShare": u("0x" + body[96:128].hex()),
            "accAlpacaPerShareTilBonus": u("0x" + body[128:160].hex())}
    except Exception as e:
        fl_info[name]["poolInfo"] = f"decode-err {e}"
    try:
        body = bytes.fromhex(ui[2:])
        fl_info[name]["userInfo"] = {"amount": u("0x" + body[0:32].hex()), "rewardDebt": u("0x" + body[32:64].hex()),
                                     "bonusMultiplier": u("0x" + body[64:96].hex()),
                                     "bonusAlpaca": "0x" + body[108:128].hex()}
    except Exception as e:
        fl_info[name]["userInfo"] = f"decode-err {e}"
state["fairlaunch"] = fl_info

# 4. BUSD + SSM
calls = [
    (BUSD, "0x" + SEL["balanceOf"] + enc_addr(ADAPTER_BUSD)),
    (BUSD, "0x" + SEL["balanceOf"] + enc_addr(SSM)),
    (BUSD, "0x" + SEL["totalSupply"]),
    (SSM, "0x" + SEL["paused"]),
    (SSM, "0x" + SEL["positions"][:8] if False else "0x" + SEL["positions"] + POOLS["BUSD-STABLE"][2:].rjust(64, "0") + enc_addr(SSM)),
    (BK, "0x" + SEL["collateralToken"] + POOLS["BUSD-STABLE"][2:].rjust(64, "0") + enc_addr(SSM)),
    ("0x" + SEL["stablecoin"] if False else BK, "0x" + "29d88594" + POOLS["BUSD-STABLE"][2:].rjust(64, "0") + enc_addr(SSM)),
]
res = batch(calls)
state["busd"] = {
    "balanceOf_authAdapter": u(res[0]),
    "balanceOf_ssm": u(res[1]),
    "totalSupply": u(res[2]),
}
state["ssm"] = {"paused": u(res[3]), "bk_positions_raw": res[4], "bk_collateralToken_raw": res[5]}

# 5. SSM underlying config
calls = [
    (SSM, "0x" + SEL["authTokenAdapter"]), (SSM, "0x" + SEL["stablecoinAdapter"]),
    (SSM, "0x" + SEL["systemDebtEngine"]), (SSM, "0x" + SEL["feeIn"]), (SSM, "0x" + SEL["feeOut"]),
    (SSM, "0x" + SEL["collateralPoolId"]),
    (ADAPTER_BUSD, "0x" + SEL["paused"]), (ADAPTER_BUSD, "0x" + SEL["live"]),
]
res = batch(calls)
state["ssm_config"] = {
    "authTokenAdapter": a(res[0]), "stablecoinAdapter": a(res[1]), "systemDebtEngine": a(res[2]),
    "feeIn": u(res[3]), "feeOut": u(res[4]), "poolId": res[5],
    "adapter_busd_paused": u(res[6]), "adapter_busd_live": u(res[7]),
}

# 6. static feed
calls = [
    (STATIC_FEED, "0x" + SEL["price"]), (STATIC_FEED, "0x" + SEL["lastUpdate"]),
    (STATIC_FEED, "0x" + SEL["priceLife"]), (STATIC_FEED, "0x" + SEL["paused"]),
    (STATIC_FEED, "0x" + SEL["peekPrice"]), (STATIC_FEED, "0x" + SEL["readPrice"]),
]
res = batch(calls)
state["static_feed"] = {"price": u(res[0]), "lastUpdate": u(res[1]), "priceLife": u(res[2]), "paused": u(res[3]),
                        "peekPrice_raw": res[4], "readPrice": u(res[5])}

# 7. ib price feeds + sub feeds
for group, d in [("feed_ib", FEED_IBUSD), ("feed_sub", FEED_SUB)]:
    calls, labels = [], []
    for name, addr in d.items():
        for fn in ["readPrice", "peekPrice", "paused"]:
            calls.append((addr, "0x" + SEL[fn])); labels.append(f"{name}.{fn}")
    res = batch(calls)
    out = {}
    for i, lab in enumerate(labels):
        name, fn = lab.split(".")
        out.setdefault(name, {})[fn] = u(res[i]) if fn != "peekPrice" else res[i]
    state[group] = out
# ib feed extras
calls, labels = [], []
for name, addr in FEED_IBUSD.items():
    for fn in ["lastUpdateTimestamp", "timeDelay", "peekNextPrice"]:
        calls.append((addr, "0x" + SEL[fn])); labels.append(f"{name}.{fn}")
res = batch(calls)
for i, lab in enumerate(labels):
    name, fn = lab.split(".")
    state["feed_ib"][name][fn] = u(res[i]) if fn != "peekNextPrice" else res[i]

# 8. oracles
calls = [
    (SIMPLE_ORACLE, "0x" + SEL["getPrice2"] + enc_addr(IBTOKEN["ibBUSD"]) + enc_addr(BUSD)),
    (SIMPLE_ORACLE, "0x" + SEL["getPrice2"] + enc_addr(IBTOKEN["ibUSDT"]) + enc_addr("0x55d398326f99059fF775485246999027B3197955")),
    (SIMPLE_ORACLE, "0x" + SEL["getPrice2"] + enc_addr(IBTOKEN["ibWBNB"]) + enc_addr("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c")),
    (CHAINLINK_ORACLE, "0x" + SEL["getPrice2"] + enc_addr(BUSD) + enc_addr("0x115dffFFfffffffffFFFffffFFffFfFfFFFFfFff")),
    (VAULT_ORACLE, "0x" + SEL["getPrice2"] + enc_addr(IBTOKEN["ibBUSD"]) + enc_addr(BUSD)),
]
res = batch(calls)
state["oracles"] = {"simple_ibBUSD_BUSD": res[0], "simple_ibUSDT_USDT": res[1], "simple_ibWBNB_WBNB": res[2],
                    "chainlink_BUSD_USD": res[3], "vault_ibBUSD_BUSD": res[4]}

# 9. roles
addrs = {"BookKeeper": BK, "SystemDebtEngine": SDE, "ShowStopper": SS, "CollateralPoolConfig": CPC,
         "PositionManager": PM, "FlashMintModule": FMM, "StableSwapModule": SSM, "LiquidationEngine": LE,
         "StablecoinAdapter": SAD, "StabilityFeeCollector": STABILITY, "PriceOracle": PRICE_ORACLE,
         "FixedSpreadLiquidationStrategy": FIXED_STRATEGY, "Timelock": TIMELOCK, "OpMultiSig": MULTISIG,
         "PCSFlashLiquidator": FLASH_LIQ, "GetPositions": GETPOS, "ProxyWalletFactory": PWF, "DEAD": DEAD,
         "AuthTokenAdapter": ADAPTER_BUSD, "IbBUSDAdapter": ADAPTERS_IB["ibBUSD"],
         "IbUSDTAdapter": ADAPTERS_IB["ibUSDT"], "IbWBNBAdapter": ADAPTERS_IB["ibWBNB"],
         "PriceOracleContract": PRICE_ORACLE}
key_roles = ["OWNER", "GOV_ROLE", "LIQUIDATION_ENGINE_ROLE", "SHOW_STOPPER_ROLE", "POSITION_MANAGER_ROLE",
             "MINTABLE_ROLE", "COLLATERAL_MANAGER_ROLE", "STABILITY_FEE_COLLECTOR_ROLE", "ADAPTER_ROLE",
             "PRICE_ORACLE_ROLE", "BOOK_KEEPER_ROLE"]
calls, labels = [], []
for an, ad in addrs.items():
    for rn in key_roles:
        calls.append((ACC, "0x" + SEL["hasRole"] + ROLES[rn][2:].rjust(64, "0") + enc_addr(ad)))
        labels.append((an, rn))
# AUSD minter role checks
for an, ad in list(addrs.items()) + [("Zero", "0x" + "00" * 20)]:
    calls.append((AUSD, "0x" + SEL["hasRole"] + ROLES["MINTER_ROLE"][2:].rjust(64, "0") + enc_addr(ad)))
    labels.append((an, "AUSD_MINTER"))
res = batch(calls)
roles = {}
for (an, rn), r in zip(labels, res):
    if u(r) == "1":
        roles.setdefault(an, []).append(rn)
state["roles"] = roles

# 10. ShowStopper extras + LE strategy flags
calls = [
    (SS, "0x" + SEL["cageCoolDown"]), (SS, "0x" + SEL["live"]), (SS, "0x" + SEL["debt"]),
    (SS, "0x" + SEL["cagePrice"] + POOLS["ibBUSD"][2:]), (SS, "0x" + SEL["cagePrice"] + POOLS["ibUSDT"][2:]),
    (SS, "0x" + SEL["cagePrice"] + POOLS["ibWBNB"][2:]), (SS, "0x" + SEL["cagePrice"] + POOLS["BUSD-STABLE"][2:]),
    (SS, "0x" + SEL["finalCashPrice"] + POOLS["ibBUSD"][2:]), (SS, "0x" + SEL["finalCashPrice"] + POOLS["ibUSDT"][2:]),
    (SS, "0x" + SEL["finalCashPrice"] + POOLS["ibWBNB"][2:]), (SS, "0x" + SEL["finalCashPrice"] + POOLS["BUSD-STABLE"][2:]),
    (FIXED_STRATEGY, "0x" + SEL["flashLendingEnabled"]), (FIXED_STRATEGY, "0x" + SEL["paused"]),
    (LE, "0x" + SEL["live"]), (LE, "0x" + SEL["paused"]),
]
res = batch(calls)
state["showstopper"] = {"cageCoolDown": u(res[0]), "live": u(res[1]), "debt": u(res[2]),
                        "cagePrice": {"ibBUSD": u(res[3]), "ibUSDT": u(res[4]), "ibWBNB": u(res[5]), "BUSD-STABLE": u(res[6])},
                        "finalCashPrice": {"ibBUSD": u(res[7]), "ibUSDT": u(res[8]), "ibWBNB": u(res[9]), "BUSD-STABLE": u(res[10])}}
state["strategy"] = {"flashLendingEnabled": u(res[11]), "paused": u(res[12])}
state["liquidation_engine"] = {"live": u(res[13]), "paused": u(res[14])}

# 11. per-pool sums from enumerated data
sums = {}
for pid, p in posmap.items():
    pool = p["poolId"]
    lc = int(p.get("lockedCollateral") or 0)
    ds = int(p.get("debtShareBK") or 0)
    free = state["positions_free"].get(pid)
    if isinstance(free, str) and not free.startswith("ERR"):
        free = int(free)
    else:
        free = 0
    s = sums.setdefault(pool, {"locked": 0, "debt": 0, "free": 0, "positions": 0})
    s["locked"] += lc; s["debt"] += ds; s["free"] += free
    if lc or ds or free:
        s["positions"] += 1
state["pool_sums"] = sums

json.dump(state, open(OUT, "w"), indent=1)
print("saved", OUT)
print(json.dumps({k: state[k] for k in ["pool_sums", "adapters_ib", "ssm_config", "busd", "static_feed", "showstopper", "strategy", "liquidation_engine"]}, indent=1)[:4000])
