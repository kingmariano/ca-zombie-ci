#!/usr/bin/env python3
"""Read-only BSC state collector for DeFIL analysis. Public RPC only, no secrets.
Usage: python3 collect.py <rpc> <block>
Writes raw/state_<block>.json
"""
import json, subprocess, sys, os

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://bsc.publicnode.com"
BLOCK = sys.argv[2] if len(sys.argv) > 2 else "latest"

def call(addr, sig, *args, block=BLOCK):
    cmd = ["cast", "call", "--rpc-url", RPC, "--block", str(block), addr, sig, *args]
    for attempt in range(3):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
            out = r.stdout.strip()
            if out:
                return out
            err = r.stderr or ""
            if "429" in err or "rate" in err.lower() or "502" in err or "500" in err:
                import time as _t; _t.sleep(1.0 + attempt)
                continue
            # genuine revert / missing function -> record short error
            line = err.strip().split("\n")[0][:120] if err.strip() else None
            return f"REVERT:{line}" if line else None
        except Exception as e:
            return f"ERR:{e}"
    return "RATELIMIT"

FILST = "0x899e2a220CBC6eb1Ab154211353EDED74BC1e266"
DFL   = "0x6ded0F2c886568Fb4Bb6F04f179093D3D167c9D7"
EFIL  = "0x22B475f3e93390b7E523873ad7073337f4E56C2c"
USDT  = "0x55d398326f99059fF775485246999027B3197955"
WBNB  = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
BUSD  = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
LP1   = "0xecf6aA34b19e31311eB92768888bdDd25aa72933"   # FILST/USDT per task
LP2   = "0x3ce2669C9aAF8E717c739B1E9100FA792AD23835"   # FILST/EFIL per task
LP3   = "0x3558c47c0f2309197857689d84cb620405e2c54d"   # pool2?

S_LP1  = "0xde6239b3138910c68f318e799b3d332925e9929f"
S_LP2  = "0x6b9ee349810e660dda9e3557c7a7412e5424ea39"
S_FILST= "0x6c753ca90bad578504314699580c8b01e067a765"
S_DFL  = "0x272257bb03a2b99978a1e6badeba7ccba444d285"
S_P2   = "0x6b6811a710f07b8ac430f6e172833e87c4bd8716"

SUP1 = "0xFA6bF5bE237570Cf326CeEeC2b467A38b4FCCAa0"
SUP2 = "0x2426da4e8FCEA0e39aDa3EA671767a236AD39e09"
SUP3 = "0xe0F23BeE9c884Bf28eBC75Ee59FD12377E59A327"

POSTER      = "0x81dA506420364b3d960229dFc8B9315acEF22dC5"
FILST_OWNER = "0x557EdaaFD875569F0bd6AbaE1185c17fD5A30Ba0"
DFL_OWNER   = "0xa4bBE553CE1E77ebd7415f8ab873DC7E127238fb"
PANCAKE_FACTORY = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"

tokens = {"FILST": FILST, "DFL": DFL, "EFIL": EFIL, "USDT": USDT,
          "WBNB": WBNB, "BUSD": BUSD, "LP1": LP1, "LP2": LP2, "LP3": LP3}
contracts = {"S_LP1": S_LP1, "S_LP2": S_LP2, "S_FILST": S_FILST, "S_DFL": S_DFL,
             "S_P2": S_P2, "SUP1": SUP1, "SUP2": SUP2, "SUP3": SUP3,
             "POSTER": POSTER, "FILST_OWNER": FILST_OWNER, "DFL_OWNER": DFL_OWNER}
all_addrs = {**tokens, **contracts}

out = {"rpc": RPC, "block": None, "tokens": {}, "balances": {}, "staking": {}, "lp": {}, "poster": {}, "factory_pairs": {}}

# block echo
out["block"] = call("0x0000000000000000000000000000000000000000", "block.number()(uint256)", "latest") or BLOCK
# simple: read block.number at pinned block is the pin itself; use cast block-number separately if needed

for name, addr in tokens.items():
    d = {}
    for sig, key in [("name()(string)", "name"), ("symbol()(string)", "symbol"),
                     ("decimals()(uint8)", "decimals"), ("totalSupply()(uint256)", "totalSupply"),
                     ("owner()(address)", "owner"), ("poster()(address)", "poster")]:
        v = call(addr, sig)
        d[key] = v
    out["tokens"][name] = d

# balances of each token at each contract
for tname, taddr in tokens.items():
    out["balances"][tname] = {}
    for cname, caddr in contracts.items():
        v = call(taddr, "balanceOf(address)(uint256)", caddr)
        out["balances"][tname][cname] = v

for name, addr in {"S_LP1": S_LP1, "S_LP2": S_LP2, "S_FILST": S_FILST, "S_DFL": S_DFL, "S_P2": S_P2}.items():
    d = {}
    for sig, key in [("property()(address)", "property"), ("superior()(address)", "superior"),
                     ("totalDeposits()(uint256)", "totalDeposits"), ("asset()(address)", "asset"),
                     ("accrualBlockNumber()(uint256)", "accrualBlockNumber"),
                     ("globalAccruedIndex()(uint256)", "globalAccruedIndex"),
                     ("superiorAccruedAmount()(uint256)", "superiorAccruedAmount"),
                     ("totalShares()(uint256)", "totalShares")]:
        d[key] = call(addr, sig)
    out["staking"][name] = d

for name, addr in {"SUP1": SUP1, "SUP2": SUP2, "SUP3": SUP3}.items():
    d = {}
    for sig, key in [("superior()(address)", "superior"), ("asset()(address)", "asset"),
                     ("accrualBlockNumber()(uint256)", "accrualBlockNumber"),
                     ("globalAccruedIndex()(uint256)", "globalAccruedIndex"),
                     ("superiorAccruedAmount()(uint256)", "superiorAccruedAmount"),
                     ("owner()(address)", "owner")]:
        d[key] = call(addr, sig)
    out["staking"][name] = d

for name, addr in {"LP1": LP1, "LP2": LP2, "LP3": LP3}.items():
    d = {}
    for sig, key in [("token0()(address)", "token0"), ("token1()(address)", "token1"),
                     ("getReserves()(uint112,uint112,uint32)", "getReserves"),
                     ("totalSupply()(uint256)", "totalSupply"),
                     ("factory()(address)", "factory")]:
        d[key] = call(addr, sig)
    out["lp"][name] = d

# poster selectors (FILSTManage-like + Ownable)
poster_calls = [
    ("owner()(address)", "owner"),
    ("filst()(address)", "filst"),
    ("dfl()(address)", "dfl"),
    ("usdtToken()(address)", "usdtToken"),
    ("miningNFT()(address)", "miningNFT"),
    ("miningNFTManage()(address)", "miningNFTManage"),
    ("filstPool()(address)", "filstPool"),
    ("priceConverter()(address)", "priceConverter"),
    ("mintFeeRatio()(uint256)", "mintFeeRatio"),
    ("MINT_FEE_DENOMINATOR()(uint256)", "MINT_FEE_DENOMINATOR"),
    ("cumulatedFee()(uint256)", "cumulatedFee"),
    ("totalStakedMiningNftAmount()(uint256)", "totalStakedMiningNftAmount"),
    ("getTotalMintedAmount()(uint256)", "getTotalMintedAmount"),
    ("getMintedMinerList()(string[])", "mintedMinerList"),
    ("getMintFee(uint256)(uint256)", "getMintFee_1e18", ["1000000000000000000"]),
    ("poster()(address)", "poster"),
]
for item in poster_calls:
    if len(item) == 3:
        sig, key, args = item
        out["poster"][key] = call(POSTER, sig, *args)
    else:
        sig, key = item
        out["poster"][key] = call(POSTER, sig)

# factory pairs
combos = [("FILST","DFL",FILST,DFL),("FILST","USDT",FILST,USDT),("FILST","WBNB",FILST,WBNB),
          ("FILST","BUSD",FILST,BUSD),("FILST","EFIL",FILST,EFIL),("DFL","USDT",DFL,USDT),
          ("DFL","WBNB",DFL,WBNB),("DFL","BUSD",DFL,BUSD),("DFL","EFIL",DFL,EFIL),
          ("EFIL","USDT",EFIL,USDT),("EFIL","WBNB",EFIL,WBNB),("EFIL","BUSD",EFIL,BUSD)]
for an, bn, a, b in combos:
    v = call(PANCAKE_FACTORY, "getPair(address,address)(address)", a, b)
    out["factory_pairs"][f"{an}/{bn}"] = v

os.makedirs("raw", exist_ok=True)
with open(f"raw/state_{BLOCK}.json", "w") as f:
    json.dump(out, f, indent=2)
print(f"wrote raw/state_{BLOCK}.json")
print("block:", out["block"])
print("token meta:", json.dumps(out["tokens"], indent=1)[:1500])
print("staking:", json.dumps(out["staking"], indent=1)[:2000])
