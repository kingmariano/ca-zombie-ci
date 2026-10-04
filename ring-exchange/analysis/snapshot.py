#!/usr/bin/env python3
"""Pinned-block snapshot of Ring HyperEVM state. Read-only."""
import json, time, urllib.request
from rpc import batch_calls, keccak_sel, get_balance

RPC = "https://rpc.hyperliquid.xyz/evm"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["result"]

BLOCK = int(rpc("eth_blockNumber", []), 16)
print("pinned block", BLOCK, flush=True)

TOKENS = {
  "WHYPE":  ("0x5555555555555555555555555555555555555555", 18),
  "UETH":   ("0xBe6727B535545C67d5cAa73dEa54865B92CF7907", 18),
  "USDC":   ("0xb88339CB7199b77E23DB6E890353E22632Ba630f", 6),
  "USDT0":  ("0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb", 6),
  "USDH":   ("0x111111a1a0667d36bD57c0A9f569b98057111111", 6),
  "fwWHYPE":("0x9e1148bC3665a9f7C35F313d89c0432c34928AEf", 18),
  "fwUETH": ("0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397", 18),
  "fwUSDC": ("0xd2646b9B02859416D8cBc759F85f0676f6E19974", 6),
  "fwUSDT0":("0x7576dd9a2775bFd789616d9eA7A2af21d06782D0", 6),
  "fwUSDH": ("0x09D21E89EF332347eb3E1E496f1265a600e364C1", 6),
}
PAIRS = {
  "fwUETH/fwWHYPE": "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a",
  "fwUSDH/fwUSDC":  "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3",
  "fwUSDH/fwUSDT0": "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150",
  "fwUSDT0/fwUSDC": "0x8868a630dD13A954D3f8B186508EF6c733BE959F",
  "fwUSDT0/fwWHYPE":"0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17",
}
WRAPPERS = ["fwWHYPE","fwUETH","fwUSDC","fwUSDT0","fwUSDH"]
UNDERLYING = {"fwWHYPE":"WHYPE","fwUETH":"UETH","fwUSDC":"USDC","fwUSDT0":"USDT0","fwUSDH":"USDH"}
KEY_ADDRS = {
  "minterEOA": "0x9336D0C82299Da0ab178271792954ADFD6f10fD7",
  "LP_EOA":    "0x4f0aa5900b8292273b2f9a178d5468f8048bb9a9",
  "deployer":  "0xa3142fdc1050289a95858799aa921cb1d6ace65d",
  "timelock":  "0x03709dfd8145b618af0e06b48dd76258d8ef2e2f",
  "core":      "0x1cda28aD2915356EB618518b1bDD3f462aeF3803",
  "fewFactory":"0x6B65ed7315274eB9EF06A48132EB04D808700b86",
  "launchpadMinter":"0xc38f2fd561d748ce74a5f9ce09b89d2cf421fb56",
  "router":    "0x701D1d675415efA2d2429fB122ccC6dD4FCcA959",
  "universalRouter":"0xE65081EFa5ad4A196B1Df768716c337e6AB140E9",
  "fewEthWrapper":"0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F",
}

snap = {"block": BLOCK, "tokens": {}, "pairs": {}, "wrappers": {}, "balances": {}, "roles": {}}

# token supplies + underlying mapping
calls = []
for name,(addr,dec) in TOKENS.items():
    calls.append((addr, keccak_sel("totalSupply()")))
    calls.append((addr, keccak_sel("decimals()")))
res = batch_calls(calls, BLOCK)
i = 0
for name,(addr,dec) in TOKENS.items():
    ts = int(res[i],16) if isinstance(res[i],str) and res[i].startswith("0x") else None
    dec_r = int(res[i+1],16) if isinstance(res[i+1],str) and res[i+1].startswith("0x") else None
    snap["tokens"][name] = {"address":addr, "decimals":dec_r, "totalSupply":ts}
    i += 2

# wrapper collateral = underlying.balanceOf(wrapper)
calls = []
for w in WRAPPERS:
    u = TOKENS[UNDERLYING[w]][0]
    wa = TOKENS[w][0]
    calls.append((u, keccak_sel("balanceOf(address)") + wa[2:].rjust(64,"0")))
res = batch_calls(calls, BLOCK)
for w, r in zip(WRAPPERS, res):
    bal = int(r,16) if isinstance(r,str) and r.startswith("0x") else None
    u = UNDERLYING[w]
    ts = snap["tokens"][w]["totalSupply"]
    dec = snap["tokens"][w]["decimals"]
    snap["wrappers"][w] = {
        "wrapper": TOKENS[w][0], "underlying": u, "underlying_addr": TOKENS[u][0],
        "underlying_held": bal, "supply": ts,
        "unbacked_raw": (ts - bal) if (ts is not None and bal is not None) else None,
        "backing_ratio": (bal/ts if (ts and bal is not None and ts>0) else None),
        "decimals": dec,
    }

# pairs
calls = []
pair_list = list(PAIRS.items())
for pname,paddr in pair_list:
    calls.append((paddr, keccak_sel("getReserves()")))
    calls.append((paddr, keccak_sel("totalSupply()")))
    calls.append((paddr, keccak_sel("token0()")))
    calls.append((paddr, keccak_sel("token1()")))
res = batch_calls(calls, BLOCK)
for k,(pname,paddr) in enumerate(pair_list):
    r0 = res[k*4]; ts = res[k*4+1]; t0 = res[k*4+2]; t1 = res[k*4+3]
    def word(x, i): return int(x[2+i*64:2+(i+1)*64],16) if isinstance(x,str) else None
    snap["pairs"][pname] = {
        "address": paddr,
        "token0": "0x"+t0[2+24:] if isinstance(t0,str) else None,
        "token1": "0x"+t1[2+24:] if isinstance(t1,str) else None,
        "reserve0": word(r0,0), "reserve1": word(r0,1), "blockTimestampLast": word(r0,2),
        "lp_totalSupply": int(ts,16) if isinstance(ts,str) else None,
    }

# pair token balances (verify balances == reserves)
calls = []
for pname,paddr in pair_list:
    t0 = snap["pairs"][pname]["token0"]; t1 = snap["pairs"][pname]["token1"]
    calls.append((t0, keccak_sel("balanceOf(address)") + paddr[2:].rjust(64,"0")))
    calls.append((t1, keccak_sel("balanceOf(address)") + paddr[2:].rjust(64,"0")))
res = batch_calls(calls, BLOCK)
for k,(pname,paddr) in enumerate(pair_list):
    b0 = int(res[k*2],16) if isinstance(res[k*2],str) else None
    b1 = int(res[k*2+1],16) if isinstance(res[k*2+1],str) else None
    snap["pairs"][pname]["bal0"] = b0; snap["pairs"][pname]["bal1"] = b1
    snap["pairs"][pname]["excess0"] = (b0 - snap["pairs"][pname]["reserve0"]) if b0 is not None else None
    snap["pairs"][pname]["excess1"] = (b1 - snap["pairs"][pname]["reserve1"]) if b1 is not None else None

# LP balances for key addrs + key addr fw balances
calls = []
for aname,a in KEY_ADDRS.items():
    for pname,paddr in pair_list:
        calls.append((paddr, keccak_sel("balanceOf(address)") + a[2:].rjust(64,"0")))
    for w in WRAPPERS:
        calls.append((TOKENS[w][0], keccak_sel("balanceOf(address)") + a[2:].rjust(64,"0")))
res = batch_calls(calls, BLOCK)
i = 0
for aname,a in KEY_ADDRS.items():
    snap["balances"][aname] = {"address": a, "lp": {}, "fw": {}}
    for pname,paddr in pair_list:
        v = res[i]; i+=1
        snap["balances"][aname]["lp"][pname] = int(v,16) if isinstance(v,str) else None
    for w in WRAPPERS:
        v = res[i]; i+=1
        snap["balances"][aname]["fw"][w] = int(v,16) if isinstance(v,str) else None

# native balances
nb = get_balance(list(KEY_ADDRS.values()), BLOCK)
for aname, b in zip(KEY_ADDRS.keys(), nb):
    snap["balances"][aname]["native"] = int(b,16) if b else None

# Core roles
CORE = KEY_ADDRS["core"]
calls = []
for aname,a in KEY_ADDRS.items():
    calls.append((CORE, keccak_sel("isGovernor(address)") + a[2:].rjust(64,"0")))
    calls.append((CORE, keccak_sel("isMinter(address)") + a[2:].rjust(64,"0")))
    calls.append((CORE, keccak_sel("isBurner(address)") + a[2:].rjust(64,"0")))
res = batch_calls(calls, BLOCK)
i = 0
for aname,a in KEY_ADDRS.items():
    snap["roles"][aname] = {
        "isGovernor": res[i] and int(res[i],16)==1,
        "isMinter": res[i+1] and int(res[i+1],16)==1,
        "isBurner": res[i+2] and int(res[i+2],16)==1,
    }
    i += 3

# factory + fewFactory state
calls = [
  (KEY_ADDRS["fewFactory"], keccak_sel("paused()")),
  (KEY_ADDRS["fewFactory"], keccak_sel("allWrappedTokensLength()")),
  (KEY_ADDRS["router"], keccak_sel("factory()")),
  (KEY_ADDRS["router"], keccak_sel("fewFactory()")),
  (KEY_ADDRS["router"], keccak_sel("fwWETH()")),
  (KEY_ADDRS["router"], keccak_sel("WETH()")),
]
res = batch_calls(calls, BLOCK)
snap["factory"] = {
  "fewFactory_paused": res[0] and int(res[0],16)==1,
  "fewFactory_count": res[1] and int(res[1],16),
  "router_factory": res[2] and "0x"+res[2][2+24:],
  "router_fewFactory": res[3] and "0x"+res[3][2+24:],
  "router_fwWETH": res[4] and "0x"+res[4][2+24:],
  "router_WETH": res[5] and "0x"+res[5][2+24:],
}

# DefiLlama prices
try:
    addrlist = ",".join(f"hyperevm:{TOKENS[t][0]}" for t in ["WHYPE","UETH","USDC","USDT0","USDH"])
    with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/{addrlist}", timeout=60) as r:
        snap["prices"] = json.loads(r.read())["coins"]
except Exception as e:
    snap["prices"] = {"error": str(e)}

# derived USD values
px = {}
for k,v in snap.get("prices",{}).items():
    if isinstance(v,dict): px[v["symbol"]] = v["price"]
snap["prices_simple"] = px
for w,info in snap["wrappers"].items():
    u = UNDERLYING[w]; p = px.get(u)
    if p and info["underlying_held"] is not None:
        info["collateral_usd"] = info["underlying_held"]/10**TOKENS[u][1]*p
        info["nominal_supply_usd"] = info["supply"]/10**TOKENS[w][1]*p
for pname,info in snap["pairs"].items():
    t0 = info["token0"]; t1 = info["token1"]
    # map token addr -> name
    rev = {TOKENS[t][0].lower(): t for t in TOKENS}
    n0 = rev.get((t0 or "").lower()); n1 = rev.get((t1 or "").lower())
    info["symbol0"]=n0; info["symbol1"]=n1
    def usd(name, raw):
        if name is None or raw is None: return None
        base = name[2:] if name.startswith("fw") else name
        p = px.get(base)
        if not p: return None
        dec = TOKENS[name][1] if name in TOKENS else 18
        return raw/10**dec*p
    info["reserve0_usd"] = usd(n0, info["reserve0"])
    info["reserve1_usd"] = usd(n1, info["reserve1"])
    info["tvl_usd_nominal"] = (info["reserve0_usd"] or 0)+(info["reserve1_usd"] or 0)

out = f"snapshot_{BLOCK}.json"
open(out,"w").write(json.dumps(snap, indent=2))
print("wrote", out)
print(json.dumps({k: snap[k] for k in ["block","prices_simple","factory"]}, indent=2))
