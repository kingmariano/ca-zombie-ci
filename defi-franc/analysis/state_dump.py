#!/usr/bin/env python3
"""DeFi Franc live-state dump — read-only eth_calls via public RPC. No secrets written."""
import json, os, urllib.request, time

RPC = os.environ.get("DF_RPC", "https://ethereum-rpc.publicnode.com")

SEL = {
    "balanceOf(address)": "0x70a08231",
    "totalSupply()": "0x18160ddd",
    "getTroveOwnersCount(address)": "0x40c315d2",
    "getTroveFromTroveOwnersArray(address,uint256)": "0x8424ce77",
    "getTrove(address,address)": "0x7e7227cd",
    "getTroveStatus(address,address)": "0x614d1209",
    "getTroveDebt(address,address)": "0xf3e2c608",
    "getTroveColl(address,address)": "0x305a5369",
    "getTroveStake(address,address)": "0xdc3fe76f",
    "getCurrentICR(address,address,uint256)": "0xb1eafaab",
    "getAssetBalance(address)": "0x5373433f",
    "getDCHFDebt(address)": "0xd1234da7",
    "deposits(address)": "0xfc7e286d",
    "getDepositorAssetGain(address)": "0xba22f7cb",
    "getTotalDCHFDeposits()": "0x2d42b52b",
    "getAssetBalance()": "0x183b3159",
    "P()": "0x8b8fbd92",
    "currentEpoch()": "0x76671808",
    "currentScale()": "0xa4e59ac8",
    "totalStakes()": "0xbf9befb1",
    "epochToScaleToSum(uint128,uint128)": "0x28a0a04d",
    "epochToScaleToG(uint128,uint128)": "0x82e0a574",
    "fetchPrice(address)": "0xace1798e",
    "totalMONStaked()": "0xdbcafee5",
    "paused()": "0x5c975abb",
    "treasury()": "0x61d027b3",
    "getLast(address)": "0x76082715",
    "getSize(address)": "0x504f1671",
    "getRedemptionRate(address)": "0xd201d328",
    "getRedemptionRateWithDecay(address)": "0x3d36cc95",
    "getTCR(address,uint256)": "0x49fe8858",
    "getEntireDebtAndColl(address,address)": "0x26f7a0d4",
    "getPendingAssetReward(address,address)": "0xbe16a096",
    "getPendingDCHFDebtReward(address,address)": "0xeaac27e5",
    "MCR(address)": "0x05f8cff9",
    "CCR(address)": "0x3ed4a4da",
    "priceFeed()": "0x741bef1a",
    "activePool()": "0x7f7dde4a",
    "defaultPool()": "0x3cc74225",
    "DCHF_GAS_COMPENSATION(address)": "0xbb55e656",
    "getDepositorMONGain(address)": "0x410381c4",
    "getCompoundedDCHFDeposit(address)": "0x7087d168",
    "communityIssuance()": "0x95fb16bb",
    "monToken()": "0x63eb9f90",
    "dchfToken()": "0x23019524",
    "stakes(address)": "0x16934fc4",
    "getPendingAssetGain(address,address)": "0x3522c6e8",
    "getPendingDCHFGain(address)": "0xb4b5e540",
    "asset()": "0x38d52e0f",
    "isRedemptionWhitelisted()": "0xf6c5d736",
    "redemptionWhitelist(address)": "0x23977b4d",
    "getDepositorAssetGain1e18(address)": "0x3f7f0b0b",  # placeholder, computed below
}

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_u256(n): return hex(n)[2:].rjust(64,"0")

def rpc(method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(RPC, body, {"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                d = json.load(r)
            if "result" in d: return d["result"]
            raise RuntimeError(d.get("error"))
        except Exception:
            if attempt == 3: raise
            time.sleep(1.5*(attempt+1))

def call(to, sel, args="", block=None):
    r = rpc("eth_call", [{"to":to,"data":sel+args}, hex(block) if block else "latest"])
    return int(r,16) if r and r != "0x" else 0

def call_addr(to, sel, args="", block=None):
    r = rpc("eth_call", [{"to":to,"data":sel+args}, hex(block) if block else "latest"])
    return "0x"+r[-40:] if r and r != "0x" else None

A = {
 "ActivePool":"0x77E034c8A1392d99a2C776A6C1593866fEE36a33",
 "DefaultPool":"0xC1f785B74a01dd9FAc0dE6070bC583fe9eaC7Ab5",
 "SP_ETH":"0x6a9f9d6F5D672a9784c5E560a9648de6cbe2c548",
 "SP_WBTC":"0x04556d845f12Ff7D8Ff04a37F40387Dd1B454c4b",
 "CollSurplusPool":"0xA622c3bdBFBE749B1984bc127bFB500e196F594b",
 "TroveManager":"0x99838142189adE67c1951f9c57c3333281334F7F",
 "TMHelpers":"0xaAACB8C39Bd5Acbb0A236112Df8d15411161e518",
 "BorrowerOps":"0x9eB2Ce1be2DD6947e4f5Aabe33106f48861DFD74",
 "DCHF":"0x045da4bFe02B320f4403674B3b7d121737727A36",
 "MON":"0x1EA48B9965bb5086F3b468E50ED93888a661fc17",
 "MONStaking":"0x8Bc3702c35D33E5DF7cb0F06cb72a0c34Ae0C56F",
 "CommunityIssuance":"0x0fa46e8cBCEff8468DB2Ec2fD77731D8a11d3D86",
 "SortedTroves":"0x1Dd69453a685C735f2ab43E2169b57e9Edf72286",
 "PriceFeed":"0x09AB3C0ce6Cb41C13343879A667a6bDAd65ee9DA",
}
WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
ZERO = "0x0000000000000000000000000000000000000000"

out = {"block": int(rpc("eth_blockNumber",[]),16), "rpc_host": "redacted" if os.environ.get("DF_REDACT_HOST","1")=="1" else RPC.split("//")[1].split("/")[0]}

out["balances"] = {}
for name, addr in A.items():
    out["balances"][name] = {
      "eth_wei": int(rpc("eth_getBalance",[addr,"latest"]),16),
      "DCHF": call(A["DCHF"], SEL["balanceOf(address)"], enc_addr(addr)),
      "MON": call(A["MON"], SEL["balanceOf(address)"], enc_addr(addr)),
      "WBTC": call(WBTC, SEL["balanceOf(address)"], enc_addr(addr)),
    }

price_eth = call(A["PriceFeed"], SEL["fetchPrice(address)"], enc_addr(ZERO))
price_wbtc = call(A["PriceFeed"], SEL["fetchPrice(address)"], enc_addr(WBTC))

out["troves"] = {}
for asset_name, asset in [("ETH", ZERO), ("WBTC", WBTC)]:
    n = call(A["TMHelpers"], SEL["getTroveOwnersCount(address)"], enc_addr(asset))
    lst = []
    for i in range(n):
        owner = call_addr(A["TMHelpers"], SEL["getTroveFromTroveOwnersArray(address,uint256)"], enc_addr(asset)+enc_u256(i))
        lst.append({
          "owner": owner,
          "debt": call(A["TMHelpers"], SEL["getTroveDebt(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "coll": call(A["TMHelpers"], SEL["getTroveColl(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "status": call(A["TMHelpers"], SEL["getTroveStatus(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "stake": call(A["TMHelpers"], SEL["getTroveStake(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "pendingAsset": call(A["TMHelpers"], SEL["getPendingAssetReward(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "pendingDebt": call(A["TMHelpers"], SEL["getPendingDCHFDebtReward(address,address)"], enc_addr(asset)+enc_addr(owner)),
          "icr": call(A["TMHelpers"], SEL["getCurrentICR(address,address,uint256)"], enc_addr(asset)+enc_addr(owner)+enc_u256(price_eth if asset==ZERO else price_wbtc)),
        })
    lst.sort(key=lambda t: t["icr"])
    out["troves"][asset_name] = lst

out["pools"] = {}
out["pools"]["ActivePool"] = {
  "assetBalance_ETH": call(A["ActivePool"], SEL["getAssetBalance(address)"], enc_addr(ZERO)),
  "assetBalance_WBTC": call(A["ActivePool"], SEL["getAssetBalance(address)"], enc_addr(WBTC)),
  "debt_ETH": call(A["ActivePool"], SEL["getDCHFDebt(address)"], enc_addr(ZERO)),
  "debt_WBTC": call(A["ActivePool"], SEL["getDCHFDebt(address)"], enc_addr(WBTC)),
}
out["pools"]["DefaultPool"] = {
  "assetBalance_ETH": call(A["DefaultPool"], SEL["getAssetBalance(address)"], enc_addr(ZERO)),
  "assetBalance_WBTC": call(A["DefaultPool"], SEL["getAssetBalance(address)"], enc_addr(WBTC)),
  "debt_ETH": call(A["DefaultPool"], SEL["getDCHFDebt(address)"], enc_addr(ZERO)),
  "debt_WBTC": call(A["DefaultPool"], SEL["getDCHFDebt(address)"], enc_addr(WBTC)),
}
for spn in ["SP_ETH","SP_WBTC"]:
    sp = A[spn]
    ce = call(sp, SEL["currentEpoch()"]); cs = call(sp, SEL["currentScale()"])
    out["pools"][spn] = {
      "assetBalance_18": call(sp, SEL["getAssetBalance()"]),
      "totalDCHFDeposits": call(sp, SEL["getTotalDCHFDeposits()"]),
      "P": call(sp, SEL["P()"]),
      "currentEpoch": ce, "currentScale": cs,
      "totalStakes": call(sp, SEL["totalStakes()"]),
      "S_cur": call(sp, SEL["epochToScaleToSum(uint128,uint128)"], enc_u256(ce)+enc_u256(cs)),
      "G_cur": call(sp, SEL["epochToScaleToG(uint128,uint128)"], enc_u256(ce)+enc_u256(cs)),
    }
# S in adjacent slots (epoch/scale neighbourhood) - useful to see leftovers
out["S_map"] = {}
for spn in ["SP_ETH","SP_WBTC"]:
    sp = A[spn]
    d = {}
    for e in range(0,4):
        for s in range(0,4):
            v = call(sp, SEL["epochToScaleToSum(uint128,uint128)"], enc_u256(e)+enc_u256(s))
            if v: d[f"{e}:{s}"] = v
    out["S_map"][spn] = d

out["tokens"] = {
  "DCHF_totalSupply": call(A["DCHF"], SEL["totalSupply()"]),
  "MON_totalSupply": call(A["MON"], SEL["totalSupply()"]),
}
out["MONStaking"] = {
  "totalMONStaked": call(A["MONStaking"], SEL["totalMONStaked()"]),
  "paused": call(A["MONStaking"], SEL["paused()"]),
  "treasury": call_addr(A["MONStaking"], SEL["treasury()"]),
}
out["prices"] = {"ETH_CHF_1e18": price_eth, "WBTC_CHF_1e18": price_wbtc}
out["redemption"] = {
  "isRedemptionWhitelisted": call(A["TroveManager"], SEL["isRedemptionWhitelisted()"]),
  "redemptionRate_ETH": call(A["TMHelpers"], SEL["getRedemptionRate(address)"], enc_addr(ZERO)),
  "redemptionRate_WBTC": call(A["TMHelpers"], SEL["getRedemptionRate(address)"], enc_addr(WBTC)),
  "TCR_ETH": call(A["TMHelpers"], SEL["getTCR(address,uint256)"], enc_addr(ZERO)+enc_u256(price_eth)),
  "TCR_WBTC": call(A["TMHelpers"], SEL["getTCR(address,uint256)"], enc_addr(WBTC)+enc_u256(price_wbtc)),
}
print(json.dumps(out, indent=1))
