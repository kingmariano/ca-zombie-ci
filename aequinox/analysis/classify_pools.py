#!/usr/bin/env python3
"""Classify Aequinox pools (threaded). Env: AEQ_RPC. In: analysis/pools_state.json. Out: analysis/pools_classified.json"""
import json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = os.environ.get("AEQ_RPC", "https://bsc-rpc.publicnode.com")
HERE = os.path.dirname(os.path.abspath(__file__))

def rpc_one(method, params, retries=3):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers={
                "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (aequinox-audit)"})
            with urllib.request.urlopen(req, timeout=30) as r:
                resp = json.loads(r.read())
            if "error" in resp:
                return None
            return resp.get("result")
        except Exception:
            if attempt < retries - 1:
                time.sleep(1 + attempt)
    return None

def call(to, data, block):
    return rpc_one("eth_call", [{"to": to, "data": data}, hex(block)])

SELS = {
    "getPaused": "6805b84b", "inRecoveryMode": "b35056b8", "getSwapFeePercentage": "55c67628",
    "getNormalizedWeights": "f89f27ed", "getAmplificationParameter": "6daccffa",
    "getRateProviders": "238a2d59", "getScalingFactors": "1dd746ea", "getBptIndex": "82687a56",
    "getMainToken": "4de046d5", "getWrappedToken": "f174e241", "getWrappedTokenRate": "f5431aa8",
    "getRate": "679aefce", "getBpt": "42d2c83f", "getOwner": "893d20e8", "getVault": "8d928af8",
    "getTargets": "63fe3b56", "getSwapEnabled": "47bc4d92", "getEnabledTrading": "6ceffefb",
    "getPoolId": "38fff2d0", "getBptRate": "62623172", "getMainIndex": "4d64cd74",
    "getWrappedIndex": "16b8d6ff", "totalSupply": "18160ddd", "decimals": "313ce567",
}

def main():
    st = json.load(open(os.path.join(HERE, "pools_state.json")))
    block = st["block"]
    pools = st["pools"]
    addrs = sorted({p["pool"] for p in pools.values()})
    print("block", block, "pools", len(pools), "addrs", len(addrs), flush=True)

    with ThreadPoolExecutor(max_workers=8) as ex:
        code_res = list(ex.map(lambda a: rpc_one("eth_getCode", [a, hex(block)]), addrs))
    codes = dict(zip(addrs, code_res))
    print("codes fetched", flush=True)

    classified = {}
    for pool_id, p in pools.items():
        a = p["pool"]
        code = (codes.get(a) or "0x").lower()
        present = [name for name, sel in SELS.items() if sel in code]
        if "getNormalizedWeights" in present:
            typ = "WeightedPool"
        elif "getAmplificationParameter" in present and "getRateProviders" in present and "getBptIndex" in present:
            typ = "ComposableStablePool"
        elif "getAmplificationParameter" in present and "getRateProviders" not in present:
            typ = "StablePool"
        elif "getMainToken" in present and "getWrappedToken" in present:
            typ = "LinearPool"
        elif "getAmplificationParameter" in present:
            typ = "StablePool(?)"
        else:
            typ = "unknown"
        classified[pool_id] = {
            "pool": a, "type": typ, "codeSize": p.get("codeSize", 0),
            "selectorsPresent": present, "specialization": p["specialization"],
            "tokens": p.get("vaultTokens"), "balances": p.get("vaultBalances"),
            "regBlock": p["regBlock"],
        }

    jobs = [(a, fn) for a in addrs for fn in ["totalSupply", "decimals", "getPaused", "inRecoveryMode",
                                              "getSwapFeePercentage", "getVault", "getPoolId", "getBpt"]]
    with ThreadPoolExecutor(max_workers=8) as ex:
        meta_res = list(ex.map(lambda j: call(j[0], "0x" + SELS[j[1]], block), jobs))
    meta = {}
    for (a, fn), r in zip(jobs, meta_res):
        meta.setdefault(a, {})[fn] = r
    for pool_id, c in classified.items():
        m = meta.get(c["pool"], {})
        def num(k):
            v = m.get(k)
            return int(v, 16) if isinstance(v, str) and v != "0x" else None
        c["totalSupply"] = num("totalSupply")
        c["decimals"] = num("decimals")
        c["paused"] = m.get("getPaused") == "0x" + "0" * 63 + "1"
        c["recoveryMode"] = m.get("inRecoveryMode") == "0x" + "0" * 63 + "1"
        c["swapFee"] = num("getSwapFeePercentage")
        c["getVault"] = m.get("getVault")
        c["getPoolId"] = m.get("getPoolId")
        c["getBpt"] = m.get("getBpt")

    json.dump({"block": block, "classified": classified}, open(os.path.join(HERE, "pools_classified.json"), "w"), indent=1)

    from collections import Counter
    print(Counter(c["type"] for c in classified.values()))
    print("totalSupply==0:", sum(1 for c in classified.values() if c["totalSupply"] == 0))
    print("paused:", sum(1 for c in classified.values() if c["paused"]),
          "recovery:", sum(1 for c in classified.values() if c["recoveryMode"]))
    print("unknown:", [(c["pool"], c["codeSize"]) for c in classified.values() if c["type"] == "unknown"])
    # print per-pool line
    for pool_id, c in sorted(classified.items(), key=lambda kv: -sum(int(x) for x in (kv[1]["balances"] or [0]))):
        print(f'{c["type"]:20s} {c["pool"]} spec={c["specialization"]} code={c["codeSize"]:6d} '
              f'supply={c["totalSupply"]} paused={c["paused"]} rec={c["recoveryMode"]} fee={c["swapFee"]} ntok={len(c["tokens"] or [])}')
    print("done")

if __name__ == "__main__":
    main()
