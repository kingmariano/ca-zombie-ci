#!/usr/bin/env python3
"""Read live state of all SheepDex pools at the latest block. Writes pools-state.json.
Uses keyed RPC from env BSC_RPC (never written to disk)."""
import json, os, urllib.request, time

RPC = os.environ["BSC_RPC"]
pools = json.load(open("pools.json"))

def batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.load(r)
            break
        except Exception as e:
            print("retry", attempt, e)
            time.sleep(2)
    else:
        raise RuntimeError("batch failed")
    out = {}
    for item in d:
        out[item["id"]] = item.get("result") if "error" not in item else ("ERR:" + str(item["error"])[:80])
    return [out[i] for i in range(len(calls))]

def word(x):
    return x[2:] if x.startswith("0x") else x

SEL_BAL = "0x70a08231"          # balanceOf(address)
SEL_LIQ = "0x1a686502"          # liquidity()
SEL_SLOT0 = "0x3850c7bd"        # slot0()
SEL_PFEES = "0x1ad8b03b"        # protocolFees()
SEL_TOKEN0 = "0x0dfe1681"
SEL_TOKEN1 = "0xd21220a7"
SEL_FEE = "0xddca3f43"

# build call list: for each pool read token0,token1,fee,liquidity,slot0,protocolFees, balances
calls = []
meta = []
for p in pools["pools"]:
    pool = p["pool"]
    calls += [(pool, SEL_TOKEN0), (pool, SEL_TOKEN1), (pool, SEL_FEE),
              (pool, SEL_LIQ), (pool, SEL_SLOT0), (pool, SEL_PFEES)]
    meta += [("token0", p), ("token1", p), ("fee", p), ("liquidity", p), ("slot0", p), ("protocolFees", p)]

results = {}
for i in range(0, len(calls), 60):
    chunk = calls[i:i+60]
    mchunk = meta[i:i+60]
    res = batch(chunk)
    for (kind, p), r in zip(mchunk, res):
        results.setdefault(p["pool"], {})[kind] = r
    print("chunk", i, "done")

# now balances: token0.balanceOf(pool), token1.balanceOf(pool)
bal_calls = []
bal_meta = []
for p in pools["pools"]:
    pool = p["pool"]
    t0 = p["token0"]
    t1 = p["token1"]
    bal_calls += [(t0, SEL_BAL + pool[2:].rjust(64, "0")), (t1, SEL_BAL + pool[2:].rjust(64, "0"))]
    bal_meta += [("bal0", p), ("bal1", p)]

for i in range(0, len(bal_calls), 60):
    chunk = bal_calls[i:i+60]
    mchunk = bal_meta[i:i+60]
    res = batch(chunk)
    for (kind, p), r in zip(mchunk, res):
        results.setdefault(p["pool"], {})[kind] = r
    print("bal chunk", i, "done")

def dec_addr(x):
    if not isinstance(x, str) or not x.startswith("0x") or len(x) < 42: return None
    return "0x" + x[-40:]

def dec_u(x):
    if not isinstance(x, str) or not x.startswith("0x"): return None
    h = x[2:]
    # Some legacy contracts (e.g. Venus vBUSD) return >32 bytes for uint256 getters;
    # the ABI value is the FIRST 32-byte word. Take the first word only.
    return int(h[:64], 16) if len(h) >= 64 else int(h, 16)

out = []
for p in pools["pools"]:
    r = results.get(p["pool"], {})
    slot0 = r.get("slot0")
    s0 = {}
    if isinstance(slot0, str) and len(slot0) >= 2 + 64 * 7:
        h = word(slot0)
        s0 = {"sqrtPriceX96": int(h[0:64], 16), "tick": int(h[64:128], 16),
              "observationIndex": int(h[128:192], 16), "observationCardinality": int(h[192:256], 16),
              "observationCardinalityNext": int(h[256:320], 16), "feeProtocol": int(h[320:384], 16),
              "unlocked": int(h[384:448], 16) == 1}
    pf = r.get("protocolFees")
    pfd = {}
    if isinstance(pf, str) and len(pf) >= 2 + 64 * 2:
        h = word(pf)
        pfd = {"token0": int(h[0:64], 16), "token1": int(h[64:128], 16)}
    out.append({**p,
                "onchain_token0": dec_addr(r.get("token0")), "onchain_token1": dec_addr(r.get("token1")),
                "onchain_fee": dec_u(r.get("fee")),
                "liquidity": dec_u(r.get("liquidity")), "slot0": s0, "protocolFees": pfd,
                "bal0": dec_u(r.get("bal0")), "bal1": dec_u(r.get("bal1"))})

json.dump({"latest_block": pools["latest_block"], "pools": out}, open("pools-state.json", "w"), indent=1)
print("wrote pools-state.json")

# summary
tot_liq = sum(1 for p in out if (p["liquidity"] or 0) > 0)
tot_pf = sum(1 for p in out if (p["protocolFees"] or {}).get("token0", 0) > 0 or (p["protocolFees"] or {}).get("token1", 0) > 0)
print("pools with liquidity>0:", tot_liq, "/", len(out))
print("pools with protocolFees>0:", tot_pf)
for p in out:
    if (p["liquidity"] or 0) > 0 or (p["bal0"] or 0) > 0 or (p["bal1"] or 0) > 0:
        print(p["pool"], "liq", p["liquidity"], "bal0", p["bal0"], "bal1", p["bal1"],
              "feeProtocol", p["slot0"].get("feeProtocol"), "pf", p["protocolFees"])
