#!/usr/bin/env python3
"""Dump full Pac Finance reserve state from Blast mainnet. Read-only."""
import json, sys, time
import requests
from eth_abi import encode as abi_encode, decode as abi_decode

RPC_URL = "https://blast-rpc.publicnode.com"
D = "0x742316f430002D067dC273469236D0F3670bE446"   # AaveProtocolDataProvider
POOL = "0xd2499b3c8611E36ca89A70Fda2A72C49eE19eAa8"
ORACLE = "0xAf77325317F109ee21459AFeEDE51b16C231e6b1"
PROVIDER = "0x688B5fd3C3E3724b4De08C4BCB3A755F9b579c9a"

from eth_utils import keccak
SIGS = {
    "getReserveConfigurationData": "getReserveConfigurationData(address)",
    "getReserveData": "getReserveData(address)",
    "getReserveTokensAddresses": "getReserveTokensAddresses(address)",
    "getReserveCaps": "getReserveCaps(address)",
    "getPaused": "getPaused(address)",
    "getInterestRateStrategyAddress": "getInterestRateStrategyAddress(address)",
    "getReserveEModeCategory": "getReserveEModeCategory(address)",
    "getSiloedBorrowing": "getSiloedBorrowing(address)",
    "getDebtCeiling": "getDebtCeiling(address)",
    "getFlashLoanEnabled": "getFlashLoanEnabled(address)",
    "getLiquidationProtocolFee": "getLiquidationProtocolFee(address)",
    "getUnbackedMintCap": "getUnbackedMintCap(address)",
    "getTotalDebt": "getTotalDebt(address)",
    "getATokenTotalSupply": "getATokenTotalSupply(address)",
    "getReservesList": "getReservesList()",
    "getReserveNormalizedIncome": "getReserveNormalizedIncome(address)",
    "getReserveNormalizedVariableDebt": "getReserveNormalizedVariableDebt(address)",
    "totalSupply": "totalSupply()",
    "scaledTotalSupply": "scaledTotalSupply()",
    "balanceOf": "balanceOf(address)",
    "scaledBalanceOf": "scaledBalanceOf(address)",
    "getAssetPrice": "getAssetPrice(address)",
    "getSourceOfAsset": "getSourceOfAsset(address)",
    "latestAnswer": "latestAnswer()",
    "latestTimestamp": "latestTimestamp()",
    "decimals": "decimals()",
    "description": "description()",
    "dapiName": "dapiName()",
    "dataFeedId": "dataFeedId()",
}
SEL = {k: "0x" + keccak(text=v).hex()[:8] for k, v in SIGS.items()}
CONFIG_TYPES = ["uint256","uint256","uint256","uint256","uint256","bool","bool","bool","bool","bool"]
RESERVE_TYPES = ["uint256","uint256","uint256","uint256","uint256","uint256","uint256","uint256","uint256","uint256","uint256","uint40"]

def addr_pad(a): return a.lower().replace("0x","").rjust(64,"0")
def u_pad(x): return hex(x)[2:].rjust(64,"0")

class RPC:
    def __init__(self, url):
        self.url = url; self.id = 0
        self.s = requests.Session()
        self.s.headers.update({"Content-Type":"application/json","User-Agent":"zombie-hunt/1.0"})
    def batch(self, calls):
        # calls: list of (to, data) -> returns list of (result, error)
        payload = []
        for to, data in calls:
            self.id += 1
            payload.append({"jsonrpc":"2.0","id":self.id,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
        for attempt in range(4):
            try:
                r = self.s.post(self.url, json=payload, timeout=60)
                js = r.json()
                if isinstance(js, dict): raise RuntimeError(js)
                out = {}
                for item in js:
                    out[item["id"]] = (item.get("result"), item.get("error"))
                return [out[p["id"]] for p in payload]
            except Exception as e:
                if attempt == 3: raise
                time.sleep(1.5*(attempt+1))

rpc = RPC(RPC_URL)
BLOCK = None
try:
    BLOCK = int(requests.post(RPC_URL, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=30).json()["result"],16)
except Exception:
    pass

reserves = requests.post(RPC_URL, json={"jsonrpc":"2.0","id":1,"method":"eth_call",
    "params":[{"to":POOL,"data":SEL["getReservesList"]},"latest"]}, timeout=30).json()["result"]
# decode address[]
raw = reserves[2:]
off = int(raw[:64],16)*2
n = int(raw[off:off+64],16)
addrs = ["0x"+raw[off+64+i*64+24:off+64+i*64+64] for i in range(n)]

def call1(to, sel, arg=None):
    data = sel + (addr_pad(arg) if arg else "")
    res, err = rpc.batch([(to, data)])[0]
    return res, err

out = {"rpc": RPC_URL, "block": BLOCK, "pool": POOL, "oracle": ORACLE, "provider": PROVIDER, "reserves": {}}
for a in addrs:
    a = a.lower()
    rec = {"asset": a}
    # symbol/decimals
    s,_ = call1(a, "0x95d89b41"); d,_ = call1(a, SEL["decimals"])
    try: rec["symbol"] = abi_decode(["string"], bytes.fromhex(s[2:]))[0]
    except Exception: rec["symbol"] = None
    try: rec["decimals"] = abi_decode(["uint8"], bytes.fromhex(d[2:]))[0]
    except Exception: rec["decimals"] = None
    # config
    s,e = call1(D, SEL["getReserveConfigurationData"], a)
    rec["config_raw"] = s if not e else {"error":e}
    if s and not e:
        v = abi_decode(CONFIG_TYPES, bytes.fromhex(s[2:]))
        rec["config"] = dict(zip(["decimals","ltv","liquidationThreshold","liquidationBonus","reserveFactor","usageAsCollateralEnabled","borrowingEnabled","stableBorrowRateEnabled","isActive","isFrozen"], v))
    # reserve data
    s,e = call1(D, SEL["getReserveData"], a)
    if s and not e:
        v = abi_decode(RESERVE_TYPES, bytes.fromhex(s[2:]))
        rec["data"] = dict(zip(["unbacked","accruedToTreasuryScaled","totalAToken","totalStableDebt","totalVariableDebt","liquidityRate","variableBorrowRate","stableBorrowRate","averageStableBorrowRate","liquidityIndex","variableBorrowIndex","lastUpdateTimestamp"], [str(x) for x in v]))
    else: rec["data"] = {"error": e}
    # tokens
    s,e = call1(D, SEL["getReserveTokensAddresses"], a)
    if s and not e:
        v = abi_decode(["address","address","address"], bytes.fromhex(s[2:]))
        rec["tokens"] = {"aToken": v[0].lower(), "stableDebt": v[1].lower(), "variableDebt": v[2].lower()}
    # caps / paused / irs / emode / siloed / debtceiling / flashloan / liq fee / unbackedcap
    for key in ["getReserveCaps","getPaused","getInterestRateStrategyAddress","getReserveEModeCategory","getSiloedBorrowing","getDebtCeiling","getFlashLoanEnabled","getLiquidationProtocolFee","getUnbackedMintCap"]:
        s,e = call1(D, SEL[key], a)
        rec[key] = {"raw": s, "error": e}
    # normalized income/debt from pool
    for key in ["getReserveNormalizedIncome","getReserveNormalizedVariableDebt"]:
        s,e = call1(POOL, SEL[key], a)
        rec[key] = {"raw": s, "error": e}
    # token reads
    if "tokens" in rec:
        at = rec["tokens"]["aToken"]; vt = rec["tokens"]["variableDebt"]
        reads = {}
        for label, to, sel, arg in [
            ("aToken.balanceOf(underlying)", at, SEL["balanceOf"], a),
            ("aToken.totalSupply", at, SEL["totalSupply"], None),
            ("aToken.scaledTotalSupply", at, SEL["scaledTotalSupply"], None),
            ("underlying.balanceOf(aToken)", a, SEL["balanceOf"], at),
            ("vToken.totalSupply", vt, SEL["totalSupply"], None),
            ("vToken.scaledTotalSupply", vt, SEL["scaledTotalSupply"], None),
        ]:
            s,e = call1(to, sel, arg)
            reads[label] = {"raw": s, "error": e}
        rec["tokenReads"] = reads
    # oracle
    s,e = call1(ORACLE, SEL["getAssetPrice"], a)
    rec["oraclePrice"] = {"raw": s, "error": e}
    s,e = call1(ORACLE, SEL["getSourceOfAsset"], a)
    rec["oracleSource"] = {"raw": s, "error": e}
    if s and not e:
        src = "0x"+s[-40:]
        rec["feed"] = {}
        for key in ["latestAnswer","latestTimestamp","decimals","description","dapiName","dataFeedId"]:
            rs,re_ = call1(src, SEL[key])
            rec["feed"][key] = {"raw": rs, "error": re_}
    out["reserves"][a] = rec
    print("done", rec.get("symbol"), a, file=sys.stderr)

out["reserve_list"] = addrs
json.dump(out, open("/home/heisenberg/CA/pac-finance/analysis/reserves_raw.json","w"), indent=1)
print(json.dumps({"block": BLOCK, "n": len(addrs), "symbols":[out["reserves"][a.lower()].get("symbol") for a in addrs]}))
