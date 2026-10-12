#!/usr/bin/env python3
"""Dump NarwhalRewardV2 farm states + external market checks."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bsc import rpc_batch, rpc, word, b32_to_addr, dec_str, hexint

HERE = os.path.dirname(os.path.abspath(__file__))
FARMS = {
    "farm_1D22": "0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f",
    "farm_6dA9": "0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B",
}
S = {
    "lpToken": "0x5fcbd285", "nar": "0x86c2ef68", "rnlp": "0x4c738a5e",
    "teamWallet": "0x59927044", "_hasStart": "0xe45a98dd", "_emergencyStop": "0x68612782",
    "_startTime": "0xfa1acb5c", "_periodFinish": "0x1407c664", "_lastUpdateTime": "0x6adafab5",
    "_rewardRate": "0x68fd25cd", "_initReward": "0xffd832c1", "_governance": "0x1c2f3e3d",
    "_powerStrategy": "0xee631881", "_baseRate": "0x927b26b9", "_teamRewardRate": "0xed6525c4",
    "_initBuffrate": "0x1fa12479",
}
UINT = {"_startTime", "_periodFinish", "_lastUpdateTime", "_rewardRate", "_initReward",
        "_baseRate", "_teamRewardRate", "_initBuffrate"}
ADDR = {"lpToken", "nar", "rnlp", "teamWallet", "_governance", "_powerStrategy"}
BOOL = {"_hasStart", "_emergencyStop"}

def main():
    out = {}
    blk = int(rpc("eth_blockNumber", []), 16)
    out["block"] = blk
    print("block", blk)
    for name, farm in FARMS.items():
        print(f"== {name} {farm}")
        f = {}
        calls = [("eth_call", [{"to": farm, "data": sel}, "latest"]) for sel in S.values()]
        # batching order: keys in S
        keys = list(S.keys())
        res = rpc_batch(calls, timeout=60)
        for k, r in zip(keys, res):
            if r is None:
                f[k] = None
                continue
            if k in UINT: f[k] = hexint(r)
            elif k in BOOL: f[k] = hexint(r) != 0
            else: f[k] = b32_to_addr(r)
        for k, v in f.items():
            print(f"  {k} = {v}")
        # balances
        if f.get("nar"):
            r = rpc("eth_call", [{"to": f["nar"], "data": "0x70a08231" + word(farm)}, "latest"])
            f["nar_balance"] = hexint(r); print("  nar.balanceOf(farm) =", f["nar_balance"])
        if f.get("rnlp"):
            code = rpc("eth_getCode", [f["rnlp"], "latest"])
            f["rnlp_code_len"] = (len(code) - 2) // 2
            r = rpc("eth_call", [{"to": f["rnlp"], "data": "0x18160ddd"}, "latest"])
            f["rnlp_totalSupply"] = hexint(r)
            print("  rnlp code bytes:", f["rnlp_code_len"], "totalSupply:", f["rnlp_totalSupply"])
        if f.get("lpToken"):
            r = rpc("eth_call", [{"to": f["lpToken"], "data": "0x18160ddd"}, "latest"])
            f["lp_totalSupply"] = hexint(r)
            r2 = rpc("eth_call", [{"to": f["lpToken"], "data": "0x70a08231" + word(farm)}, "latest"])
            f["lp_held"] = hexint(r2)
            print("  lpToken totalSupply:", f["lp_totalSupply"], "farm holds:", f["lp_held"])
            # token0/token1
            t0 = b32_to_addr(rpc("eth_call", [{"to": f["lpToken"], "data": "0x0dfe1681"}, "latest"]))
            t1 = b32_to_addr(rpc("eth_call", [{"to": f["lpToken"], "data": "0xd21220a7"}, "latest"]))
            f["lp_tokens"] = [t0, t1]
            print("  lp pair tokens:", t0, t1)
        f["bnb"] = int(rpc("eth_getBalance", [farm, "latest"]), 16)
        out[name] = f
    json.dump(out, open(os.path.join(HERE, "farms-state.json"), "w"), indent=1)
    print("wrote farms-state.json")

if __name__ == "__main__":
    main()
