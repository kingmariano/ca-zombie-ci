#!/usr/bin/env python3
"""Read-only batched state dump of Bastion (Aurora) + Aurigami oracle. No transactions."""
import json, sys, time
import requests

RPC = "https://mainnet.aurora.dev"
BLOCK = sys.argv[1] if len(sys.argv) > 1 else "latest"
if BLOCK != "latest":
    BLOCK = hex(int(BLOCK))

MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}
UNITROLLER = "0x6De54724e128274520606f038591A00C5E94a1F6"   # Bastion Unitroller
ORACLE     = "0xCa3F5f5a16ec993f933C9dCc40b929a26ef9Ce0d"   # BastionAuriOracle
AURI_COMP  = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"   # Aurigami Unitroller
REPORTERS = {
    "cETH":  "0xca9511b610ba5fc7e311fdef9ce16050ee4449e9",
    "cNEAR": "0xae4fac24dcdae0132c6d04f564dcf059616e9423",
    "cUSDC": "0x4f0d864b1abf4b701799a0b30b57a22dfeb5917b",
    "cUSDT": "0xad5a2437ff55ed7a8cad3b797b3ec7c5a19b1c54",
    "cWBTC": "0xcfb6b0498cb7555e7e21502e0f449bf28760adbb",
}
UNDERLYING = {  # from oracle configs
    "cETH":  "0x0000000000000000000000000000000000000000",
    "cNEAR": "0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d",
    "cUSDC": "0xB12BFcA5A55806AaF64E99521918A4bf0fC40802",
    "cUSDT": "0x4988a896b1227218e4A686fdE5EabdcAbd91571f",
    "cWBTC": "0xF4eB217Ba2454613b15dBdea6e5f22276410e89e",
}

# minimal ABIs (signature -> output decode)
def enc_call(sig):
    # keccak via eth_hash? use cast-free: sel = keccak(sig)[:4]
    from hashlib import sha3_256  # placeholder, replaced below
    raise NotImplementedError

SELS = {
    # name: (selector, arg types, output type)
    "markets(address)": ("0x8e8f4f82", ["address"], "(bool,uint256,uint256)"),
}

def sel(sig):
    from Crypto.Hash import keccak
    k = keccak.new(digest_bits=256); k.update(sig.encode()); return "0x"+k.hexdigest()[:8]

CALLS = []  # (label, to, sig, args)
def add(label, to, sig, *args):
    CALLS.append((label, to, sig, args))

# --- Bastion comptroller
for name, sig in [("admin","admin()"),("pauseGuardian","pauseGuardian()"),("oracle","oracle()"),
                  ("closeFactor","closeFactorMantissa()"),("liqIncentive","liquidationIncentiveMantissa()"),
                  ("borrowCapGuardian","borrowCapGuardian()"),
                  ("comptrollerImpl","comptrollerImplementation()"),
                  ("transferPaused","transferGuardianPaused()"),("seizePaused","seizeGuardianPaused()"),
                  ("rewardDistributor","rewardDistributor()"),("maxAssets","maxAssets()")]:
    add("comptroller."+name, UNITROLLER, sig)

# --- Bastion markets
for mn, addr in MARKETS.items():
    for lbl, sig in [("accrualBlockTimestamp","accrualBlockTimestamp()"),
                     ("exchangeRateStored","exchangeRateStored()"),
                     ("totalSupply","totalSupply()"),("totalBorrows","totalBorrows()"),
                     ("totalReserves","totalReserves()"),("cash","getCash()"),
                     ("reserveFactor","reserveFactorMantissa()"),("borrowIndex","borrowIndex()"),
                     ("protocolSeizeShare","protocolSeizeShareMantissa()"),
                     ("interestRateModel","interestRateModel()"),("admin","admin()"),
                     ("decimals","decimals()")]:
        add(f"{mn}.{lbl}", addr, sig)
    add(f"{mn}.mintPaused", UNITROLLER, "mintGuardianPaused(address)", addr)
    add(f"{mn}.borrowPaused", UNITROLLER, "borrowGuardianPaused(address)", addr)
    add(f"{mn}.borrowCap", UNITROLLER, "borrowCaps(address)", addr)
    add(f"{mn}.markets", UNITROLLER, "markets(address)", addr)
    add(f"{mn}.oraclePrice", ORACLE, "getUnderlyingPrice(address)", addr)
    add(f"{mn}.auriPrice", ORACLE, "getUnderlyingPrice(address)", addr)

# --- Bastion oracle misc
add("oracle.owner", ORACLE, "owner()")
add("oracle.numTokens", ORACLE, "numTokens()")
add("oracle.anchorPeriod", ORACLE, "anchorPeriod()")
add("oracle.lowerBound", ORACLE, "lowerBoundAnchorRatio()")
add("oracle.upperBound", ORACLE, "upperBoundAnchorRatio()")
for mn, addr in MARKETS.items():
    add(f"oracle.prices.{mn}", ORACLE, "prices(bytes32)")  # placeholder needs hash
# replace price placeholders with proper symbolHash from configs
cfg = json.load(open("oracle_configs.json"))
for c in cfg:
    if c["cToken"].lower() in [m.lower() for m in MARKETS.values()]:
        mn = [k for k,v in MARKETS.items() if v.lower()==c["cToken"].lower()][0]
        CALLS = [x for x in CALLS if x[0]!=f"oracle.prices.{mn}"]
        add(f"oracle.prices.{mn}", ORACLE, "prices(bytes32)", c["symbolHash"])

# --- Aurigami comptroller + oracle
add("auri.oracle", AURI_COMP, "oracle()")
add("auri.admin", AURI_COMP, "admin()")
for mn, rep in REPORTERS.items():
    add(f"auri.markets.{mn}", AURI_COMP, "markets(address)", rep)

# --- underlying token decimals/symbol
for mn, u in UNDERLYING.items():
    if u == "0x" + "0"*40: continue
    add(f"underlying.{mn}.decimals", u, "decimals()")
    add(f"underlying.{mn}.symbol", u, "symbol()")
    add(f"underlying.{mn}.balanceOfMarket", u, "balanceOf(address)", MARKETS[mn])

# --- execute in batches of 10
out = {}
def do_batch(batch):
    payload = []
    for i,(label,to,sig,args) in enumerate(batch):
        data = sel(sig)
        for a in args:
            if isinstance(a,int): data += f"{a:064x}"
            else: data += a[2:].lower().rjust(64,"0")
        payload.append({"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data}, BLOCK]})
    r = requests.post(RPC, json=payload, timeout=60)
    res = r.json()
    if isinstance(res, dict): res = [res]
    byid = {x.get("id"):x for x in res}
    for i,(label,to,sig,args) in enumerate(batch):
        x = byid.get(i, {})
        out[label] = x.get("result") or {"error": x.get("error")}

t0=time.time()
for i in range(0, len(CALLS), 10):
    do_batch(CALLS[i:i+10])
print(f"fetched {len(CALLS)} calls in {time.time()-t0:.1f}s")

# block number
r = requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=30).json()
out["_block"] = int(r["result"],16)
json.dump(out, open(f"state_dump_{out['_block']}.json","w"), indent=1)
print("block", out["_block"])
# quick human summary
def u(x): return int(x,16) if isinstance(x,str) else None
for mn in MARKETS:
    print(mn,
          "mintPaused=", u(out[f"{mn}.mintPaused"]),
          "borrowPaused=", u(out[f"{mn}.borrowPaused"]),
          "cash=", u(out[f"{mn}.cash"]),
          "borrows=", u(out[f"{mn}.totalBorrows"]),
          "supply=", u(out[f"{mn}.totalSupply"]),
          "xrate=", u(out[f"{mn}.exchangeRateStored"]),
          "oraclePrice=", u(out[f"{mn}.oraclePrice"]))
print("auri.oracle=", out["auri.oracle"])
