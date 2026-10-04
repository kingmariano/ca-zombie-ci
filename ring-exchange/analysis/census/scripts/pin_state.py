#!/usr/bin/env python3
"""Pin live HyperEVM state at an explicit block: pair reserves/supply/tokens,
wrapper underlying balances vs fw supply. Read-only. Saves census/pinned_state.json"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RPC = "https://rpc.hyperliquid.xyz/evm"

PAIRS = {
    "pair1_fwUETH_fwWHYPE":  "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a",
    "pair2_fwUSDH_fwUSDC":   "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3",
    "pair3_fwUSDH_fwUSDT0":  "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150",
    "pair4_fwUSDT0_fwUSDC":  "0x8868a630dD13A954D3f8B186508EF6c733BE959F",
    "pair5_fwUSDT0_fwWHYPE": "0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17",
}
WRAPPERS = {
    "fwWHYPE": {"addr": "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf", "underlying": "0x5555555555555555555555555555555555555555", "decimals": 18},
    "fwUETH":  {"addr": "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397", "underlying": "0xBe6727B535545C67d5cAa73dEa54865B92CF7907", "decimals": 18},
    "fwUSDC":  {"addr": "0xd2646b9B02859416D8cBc759F85f0676f6E19974", "underlying": "0xb88339CB7199b77E23DB6E890353E22632Ba630f", "decimals": 6},
    "fwUSDT0": {"addr": "0x7576dd9a2775bFd789616d9eA7A2af21d06782D0", "underlying": "0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb", "decimals": 6},
    "fwUSDH":  {"addr": "0x09D21E89EF332347eb3E1E496f1265a600e364C1", "underlying": "0x111111a1a0667d36bD57c0A9f569b98057111111", "decimals": 6},
}
SEL = {"getReserves": "0x0902f1ac", "token0": "0x0dfe1681", "token1": "0xd21220a7",
       "totalSupply": "0x18160ddd", "balanceOf": "0x70a08231", "token": "0xfc0c546a"}

def rpc_batch(payload, retries=6):
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception:
            if i == retries - 1: raise
            time.sleep(2 * (i + 1))

def call_many(calls):
    out = []
    for i in range(0, len(calls), 20):
        chunk = calls[i:i + 20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": to, "data": d}, BLOCK_HEX]}
                   for j, (to, d) in enumerate(chunk)]
        res = rpc_batch(payload)
        by = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            r = by.get(j, {})
            out.append(r.get("result") if "error" not in r else {"error": r.get("error")})
        time.sleep(0.2)
    return out

res = rpc_batch([{"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber", "params": []}])
BLOCK = int(res[0]["result"], 16)
BLOCK_HEX = hex(BLOCK)
print("block", BLOCK)

out = {"block": BLOCK, "pairs": {}, "wrappers": {}}
for name, addr in PAIRS.items():
    r = call_many([(addr, SEL["getReserves"]), (addr, SEL["totalSupply"]), (addr, SEL["token0"]), (addr, SEL["token1"])])
    res0 = r[0] if isinstance(r[0], str) else None
    if res0 and len(res0) >= 194:
        res0 = res0[2:]
        r0 = int(res0[0:64], 16); r1 = int(res0[64:128], 16)
        ts = res0[128:192]
        b1 = int(ts, 16)
    else:
        print("  getReserves odd result for", name, ":", str(r[0])[:80])
        r0 = r1 = b1 = None
    out["pairs"][name] = {"addr": addr, "reserve0": str(r0), "reserve1": str(r1),
                          "blockTimestampLast": b1, "totalSupply": int(r[1], 16) if isinstance(r[1], str) else None,
                          "token0": "0x" + r[2][-40:] if isinstance(r[2], str) else None,
                          "token1": "0x" + r[3][-40:] if isinstance(r[3], str) else None}
    print(name, out["pairs"][name])

for name, w in WRAPPERS.items():
    a = w["addr"]
    r = call_many([(a, SEL["totalSupply"]), (w["underlying"], SEL["balanceOf"] + "0" * 24 + a[2:].lower()), (a, SEL["token"])])
    out["wrappers"][name] = {"fw": a, "underlying": w["underlying"], "decimals": w["decimals"],
                             "fw_supply": int(r[0], 16) if isinstance(r[0], str) else None,
                             "underlying_held": int(r[1], 16) if isinstance(r[1], str) else None,
                             "token_getter": "0x" + r[2][-40:] if isinstance(r[2], str) else None}
    print(name, out["wrappers"][name])

json.dump(out, open(os.path.join(CENSUS, "pinned_state.json"), "w"), indent=1)
print("WROTE pinned_state.json")
