#!/usr/bin/env python3
"""Fresh state verification for Aurigami at latest Aurora block."""
import json, urllib.request, sys

RPC = "https://mainnet.aurora.dev"
UNIT = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
ORACLE = "0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE"
MARKETS = [
    "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
    "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
    "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
    "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
    "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
    "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
    "0x3195949f267702723bc614cAE037cdc8D1E94786",
    "0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
    "0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
    "0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
    "0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
    "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
    "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
    "0xdDfd0407220026c6566979B5be6A4983d1247a3E",
]

def rpc(method, params):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(RPC, data=payload, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for _ in range(3):
        try:
            out = json.load(urllib.request.urlopen(req, timeout=60))
            if "error" in out: return {"error": out["error"].get("message")}
            return out.get("result")
        except Exception as e:
            err = str(e)
    return {"error": err}

def call(to, data, tag="latest"):
    r = rpc("eth_call",[{"to":to,"data":data},tag])
    return r

SIG = {n: "0x"+__import__("hashlib").sha3_256(b"").hexdigest()[:0] for n in []}

def sel(sig):
    import hashlib
    k = hashlib.new("sha3_256")
    return None

# use cast for selectors instead
def cast_sel(sig):
    import subprocess
    return subprocess.check_output(["cast","sig",sig],text=True).strip()

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_u(v): return format(v, "064x")

def word(res):
    if not isinstance(res,str) or len(res)<66: return None
    return int(res,16)

def words(res):
    if not isinstance(res,str): return None
    b = res[2:]
    return [int(b[i:i+64],16) for i in range(0,len(b),64)]

s_dec = cast_sel("decimals()")
s_name = cast_sel("name()")
s_und = cast_sel("underlying()")
s_ts = cast_sel("totalSupply()")
s_tb = cast_sel("totalBorrows()")
s_tr = cast_sel("totalReserves()")
s_er = cast_sel("exchangeRateStored()")
s_cash = cast_sel("getCash()")
s_bcap = cast_sel("borrowCaps(address)")
s_mcap = cast_sel("mintCaps(address)")
s_markets = cast_sel("markets(address)")
s_price = cast_sel("getUnderlyingPrice(address)")
s_prices = cast_sel("getUnderlyingPrices(address[])")
s_admin = cast_sel("admin()")
s_pshare = cast_sel("protocolSeizeShareMantissa()")
s_rf = cast_sel("reserveFactorMantissa()")
s_borrowidx = cast_sel("borrowIndex()")
s_cf = cast_sel("collateralFactorMantissa()")

print("block:", int(rpc("eth_blockNumber",[]),16))
print()
for m in MARKETS:
    out = {}
    for name,data,target in [("dec",s_dec,m),("und",s_und,m),("ts",s_ts,m),("tb",s_tb,m),("tr",s_tr,m),
                             ("er",s_er,m),("cash",s_cash,m),("bcap",s_bcap,UNIT),("mcap",s_mcap,UNIT),
                             ("pshare",s_pshare,m),("rf",s_rf,m),("bIdx",s_borrowidx,m),
                             ("mkt",s_markets,UNIT),("price",s_price,ORACLE)]:
        if name in ("bcap","mcap","mkt"):
            data = data + enc_addr(m)
        if name == "price":
            data = data + enc_addr(m)
        r = call(target, data)
        if isinstance(r, dict): out[name]=r
        else:
            w = words(r)
            out[name] = w if w else r
    # underlying decimals if ERC20
    und = out.get("und")
    undec = None
    if isinstance(und, list):
        undec = word(call(und[0] if isinstance(und,list) else "0x"+format(und[0],'064x'), s_dec))
    print(m)
    print("  raw:", json.dumps({k:(v if not isinstance(v,list) or k!='mkt' else v[:2]) for k,v in out.items() if k!='mkt'}))
    if isinstance(out.get("mkt"), list):
        print("  listed/cf:", out["mkt"][0], out["mkt"][1]/1e18)
