#!/usr/bin/env python3
"""Read live Alpaca LYF state on BSC (read-only). Outputs analysis/live_state_bsc.json"""
import json, urllib.request, sys, os

RPC = os.environ.get("BSC_RPC", "https://bsc-rpc.publicnode.com")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live_state_bsc.json")

SEL = {
    "totalToken": "0x626be567",
    "totalSupply": "0x18160ddd",
    "vaultDebtVal": "0x0a355d7d",
    "reservePool": "0x0266f044",
    "token": "0xfc0c546a",
    "balanceOf": "0x70a08231",
    "fairLaunchPoolId": "0x81a47ba9",
    "config": "0x79502c55",
    "debtToken": "0xf8d89898",
    "totalShare": "0x026c4207",
    "operator": "0x570ca735",
    "pid": "0xf1068454",
    "lpToken": "0x5fcbd285",
    "isWorker": "0xaa156645",
    "acceptDebt": "0x000237f0",
    "getOracle": "0x833b1fce",
    "getFairLaunchAddr": "0xbfbbd53f",
    "getKillBps": "0x28ae433e",
    "getKillTreasuryBps": "0x04df1f5e",
    "getTreasuryAddr": "0x044d6d6f",
    "minDebtSize": "0xe1ed4286",
    "totalAllocPoint": "0x17caf6f1",
    "alpacaPerBlock": "0x20f33d59",
    "poolInfo": "0x1526fe27",
    "userInfo": "0x93f1a40b",
    "getFloatingBalance": "0xc063e08b",
    "getGlobalDebtValueWithPendingInterest": "0x33604bc6",
    "totalStablecoinIssued": "0x6f3a3bfc",
    "supply": "0x047fc9aa",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
}

def addr_pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def call(to, sel, arg=None):
    data = sel + (addr_pad(arg) if arg else "")
    return {"to": to, "data": data}

def rpc_batch(calls, chunk=20):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [c, "latest"]} for j, c in enumerate(part)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        for attempt in range(4):
            try:
                res = json.loads(urllib.request.urlopen(req, timeout=60).read())
                break
            except Exception as e:
                if attempt == 3:
                    raise
                time.sleep(2)
        byid = {r["id"]: r for r in (res if isinstance(res, list) else [res])}
        for j in range(len(part)):
            r = byid.get(j, {})
            out.append(r.get("result"))
    return out

def main():
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "tmp", "x")) if False else open("/tmp/opencode/alpaca/mainnet.json") as f:
        mainnet = json.load(f)
    # latest block
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    block = int(json.loads(urllib.request.urlopen(req, timeout=30).read())["result"], 16)

    result = {"rpc": RPC, "block": block, "vaults": [], "workers": [], "configs": {}, "fairlaunch": {}}
    # ---- vaults
    calls, meta = [], []
    for v in mainnet["Vaults"]:
        for key in ["token", "totalToken", "totalSupply", "vaultDebtVal", "reservePool", "fairLaunchPoolId", "config", "debtToken"]:
            calls.append(call(v["address"], SEL[key]))
            meta.append((v["address"], key))
    res = rpc_batch(calls)
    vmap = {}
    for (a, k), r in zip(meta, res):
        vmap.setdefault(a, {})[k] = r
    for v in mainnet["Vaults"]:
        st = vmap[v["address"]]
        base = "0x" + st["token"][-40:]
        st["base_token"] = base
        st["symbol"] = v["symbol"]
        st["name"] = v["name"]
        # balance of base token held by vault
        calls2 = [call(base, SEL["balanceOf"], v["address"]), call(base, SEL["decimals"]), call(base, SEL["symbol"])]
        r2 = rpc_batch(calls2)
        st["base_balance"] = r2[0]
        st["base_decimals"] = int(r2[1], 16) if r2[1] and len(r2[1]) > 2 else None
        try:
            sym_hex = r2[2][2:] if r2[2] else ""
            ln = int(sym_hex[64:128], 16) if len(sym_hex) >= 128 else 0
            st["base_symbol"] = bytes.fromhex(sym_hex[128:128+ln*2]).decode(errors="ignore") if ln else None
        except Exception:
            st["base_symbol"] = None
        result["vaults"].append(st)
        result["configs"].setdefault(v["config"], {"vault": v["symbol"]})
    # ---- configs
    calls, meta = [], []
    for cfg in result["configs"]:
        for key in ["getOracle", "getFairLaunchAddr", "getKillBps", "getKillTreasuryBps", "getTreasuryAddr", "minDebtSize"]:
            calls.append(call(cfg, SEL[key]))
            meta.append((cfg, key))
    res = rpc_batch(calls)
    for (a, k), r in zip(meta, res):
        result["configs"][a][k] = r
    # ---- workers
    calls, meta = [], []
    wmeta = []
    for v in mainnet["Vaults"]:
        for w in v["workers"]:
            wmeta.append((v["symbol"], w))
            for key in ["lpToken", "totalShare", "operator", "pid", "baseToken"]:
                if key == "baseToken":
                    continue
                calls.append(call(w["address"], SEL[key]))
                meta.append((w["address"], key))
            calls.append(call(v["config"], SEL["isWorker"], w["address"]))
            meta.append((w["address"], "isWorker"))
            calls.append(call(v["config"], SEL["acceptDebt"], w["address"]))
            meta.append((w["address"], "acceptDebt"))
    res = rpc_batch(calls, chunk=30)
    wmap = {}
    for (a, k), r in zip(meta, res):
        wmap.setdefault(a, {})[k] = r
    for sym, w in wmeta:
        st = wmap.get(w["address"], {})
        st["vault"] = sym
        st["name"] = w["name"]
        result["workers"].append(st)
    # ---- FairLaunch
    fl = mainnet["FairLaunch"]["address"]
    calls = [call(fl, SEL["totalAllocPoint"]), call(fl, SEL["alpacaPerBlock"])]
    r = rpc_batch(calls)
    result["fairlaunch"] = {"address": fl, "totalAllocPoint": r[0], "alpacaPerBlock": r[1]}
    # per-pool info for the vaults' poolIds
    pool_ids = []
    for v in mainnet["Vaults"]:
        pid_hex = vmap[v["address"]]["fairLaunchPoolId"]
        if pid_hex and len(pid_hex) > 2:
            pid = int(pid_hex, 16)
            pool_ids.append((v["symbol"], pid))
            calls = [call(fl, SEL["poolInfo"], "0x" + hex(pid)[2:].rjust(64, "0"))]
            r = rpc_batch(calls)
            result["fairlaunch"].setdefault("pools", {})[v["symbol"]] = {"pid": pid, "poolInfo": r[0]}
    with open(OUT, "w") as f:
        json.dump(result, f, indent=1)
    print("block", block)
    for v in result["vaults"]:
        print(v["symbol"], "floating", v["base_balance"], "totalToken", v["totalToken"], "debt", v["vaultDebtVal"], "reserve", v["reservePool"], "poolId", v["fairLaunchPoolId"])
    print("workers:", len(result["workers"]), "isWorker true:", sum(1 for w in result["workers"] if w.get("isWorker") and int(w["isWorker"], 16) == 1),
          "acceptDebt true:", sum(1 for w in result["workers"] if w.get("acceptDebt") and int(w["acceptDebt"], 16) == 1))
    print("saved", OUT)

if __name__ == "__main__":
    main()
