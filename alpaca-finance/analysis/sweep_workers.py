#!/usr/bin/env python3
"""Sweep Alpaca LYF workers, FairLaunch, liquidator whitelist on BSC (read-only)."""
import json, urllib.request, time, os

RPC = os.environ.get("BSC_RPC", "https://bsc-rpc.publicnode.com")
BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "worker_fairlaunch_sweep.json")

SEL = {
    "lpToken": "0x5fcbd285", "totalShare": "0x026c4207", "masterChef": "0x575a86b2",
    "balanceOf": "0x70a08231", "userInfo": "0x93f1a40b", "pid": "0xf1068454",
    "operator": "0x570ca735", "baseToken": "0xc55dae63",
    "totalAllocPoint": "0x17caf6f1", "alpacaPerBlock": "0x20f33d59",
    "poolInfo": "0x1526fe27", "pendingAlpaca": "0x94443b73",
    "whitelistedLiquidators": "0xd9ed3def", "vaultDebtShare": "0x76c46b7b",
    "totalToken": "0x626be567", "totalSupply": "0x18160ddd", "token": "0xfc0c546a",
    "reservePool": "0x0266f044", "vaultDebtVal": "0x0a355d7d",
}

def pad(x):
    return x.lower().replace("0x", "").rjust(64, "0")

def rpc_batch(calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [c, "latest"]} for j, c in enumerate(part)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        for a in range(4):
            try:
                res = json.loads(urllib.request.urlopen(req, timeout=60).read()); break
            except Exception:
                if a == 3: raise
                time.sleep(2)
        byid = {r["id"]: r for r in (res if isinstance(res, list) else [res])}
        out += [byid.get(j, {}).get("result") for j in range(len(part))]
    return out

mainnet = json.load(open("/tmp/opencode/alpaca/mainnet.json"))
fl = mainnet["FairLaunch"]["address"]
result = {"rpc": RPC, "fairlaunch": fl, "workers": [], "vaults": {}, "whitelist": {}}

# --- latest block
req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
result["block"] = int(json.loads(urllib.request.urlopen(req, timeout=30).read())["result"], 16)

# --- worker sweep: lpToken, masterChef, pid, totalShare, operator
calls, meta = [], []
for v in mainnet["Vaults"]:
    for w in v["workers"]:
        for k in ["lpToken", "masterChef", "pid", "totalShare", "operator", "baseToken"]:
            calls.append({"to": w["address"], "data": SEL[k]}); meta.append((w["address"], k))
res = rpc_batch(calls, chunk=30)
wm = {}
for (a, k), r in zip(meta, res): wm.setdefault(a, {})[k] = r

# --- for each worker: lp balance, masterchef userInfo
calls, meta = [], []
for v in mainnet["Vaults"]:
    for w in v["workers"]:
        st = wm[w["address"]]
        if not st.get("lpToken") or not st.get("masterChef"):
            continue
        lp = "0x" + st["lpToken"][-40:]
        mc = "0x" + st["masterChef"][-40:]
        pid = int(st["pid"], 16) if st["pid"] else 0
        calls.append({"to": lp, "data": SEL["balanceOf"] + pad(w["address"])}); meta.append((w["address"], "lp_balance"))
        calls.append({"to": mc, "data": SEL["userInfo"] + pad("0x" + hex(pid)[2:].rjust(64, "0")) + pad(w["address"])}); meta.append((w["address"], "mc_userinfo"))
res = rpc_batch(calls, chunk=30)
for (a, k), r in zip(meta, res): wm.setdefault(a, {})[k] = r
for v in mainnet["Vaults"]:
    for w in v["workers"]:
        st = wm[w["address"]]; st["vault"] = v["symbol"]; st["name"] = w["name"]
        st["address"] = w["address"]
        result["workers"].append(st)

# --- vaults full state incl vaultDebtShare
for v in mainnet["Vaults"]:
    calls = [{"to": v["address"], "data": SEL[k]} for k in ["totalToken","totalSupply","vaultDebtVal","reservePool","vaultDebtShare","token"]]
    r = rpc_batch(calls)
    result["vaults"][v["symbol"]] = dict(zip(["totalToken","totalSupply","vaultDebtVal","reservePool","vaultDebtShare","token"], r))

# --- FairLaunch state
calls = [{"to": fl, "data": SEL["totalAllocPoint"]}, {"to": fl, "data": SEL["alpacaPerBlock"]}]
r = rpc_batch(calls)
result["fairlaunch_state"] = {"totalAllocPoint": r[0], "alpacaPerBlock": r[1]}
# pool count: use known max pid from vaults
maxpid = 0
for v in mainnet["Vaults"]:
    pid_hex = None
    # from earlier read
for v in mainnet["Vaults"]:
    pass
# read poolInfo for pids 0..30
calls = [{"to": fl, "data": SEL["poolInfo"] + pad(hex(i))} for i in range(31)]
r = rpc_batch(calls)
result["fairlaunch_pools"] = [{"pid": i, "raw": x} for i, x in enumerate(r)]
# ALPACA balance of fairlaunch
alpaca = mainnet["Tokens"]["ALPACA"]
calls = [{"to": alpaca, "data": SEL["balanceOf"] + pad(fl)}]
r = rpc_batch(calls)
result["fairlaunch_alpaca_balance"] = r[0]

# --- whitelisted liquidators per vault
for v in mainnet["Vaults"]:
    cfg = v["config"]
    # candidate liquidators: check a set of known addresses? can't enumerate mapping; check zero + known deployer + treasury
    cands = ["0x0000000000000000000000000000000000000000", "0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51",
             "0x2D5408f2287BF9F9B05404794459a846651D0a59"]
    calls = [{"to": v["address"], "data": SEL["whitelistedLiquidators"] + pad(c)} for c in cands]
    r = rpc_batch(calls)
    result["whitelist"][v["symbol"]] = dict(zip(cands, r))

with open(OUT, "w") as f: json.dump(result, f, indent=1)

# summary
tot_lp = {}
for w in result["workers"]:
    try:
        lb = int(w["lp_balance"], 16) if w.get("lp_balance") else 0
        mc = w.get("mc_userinfo")
        mc_amt = int(mc[:66], 16) if mc and len(mc) >= 66 else 0
        if lb or mc_amt:
            tot_lp[w["address"]] = (w["name"], lb, mc_amt, w["vault"])
    except Exception as e:
        pass
print("block", result["block"])
print("workers with residual LP (raw):", len(tot_lp))
for a, (n, lb, mc, v) in sorted(tot_lp.items(), key=lambda x: -(x[1][1]+x[1][2]))[:25]:
    print(f"  {n:55s} lpBal={lb/1e18:.6f} mcStaked={mc/1e18:.6f} {v}")
print("FairLaunch ALPACA:", int(result["fairlaunch_alpaca_balance"],16)/1e18 if result["fairlaunch_alpaca_balance"] else 0)
print("totalAllocPoint", int(result["fairlaunch_state"]["totalAllocPoint"],16) if result["fairlaunch_state"]["totalAllocPoint"] else None)
print("saved", OUT)
