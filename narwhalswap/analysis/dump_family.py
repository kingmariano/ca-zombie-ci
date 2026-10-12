#!/usr/bin/env python3
"""Dump all Narwhalswap farm-family live state."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bsc import rpc_batch, rpc, word, b32_to_addr, hexint

HERE = os.path.dirname(os.path.abspath(__file__))
FARMS = {
    "V1_narwbnb":   "0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835",
    "V1_wbnb_busd": "0xbb38f7551025a433f36590be85271110212655de",
    "V2_narwbnb":   "0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f",
    "V2_wbnb_busd": "0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B",
    "V3_narwbnb":   "0xbe85812237741d75f81aebf1d9af52d544542168",
    "V3_btcb_nar":  "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d",
    "T_small":      "0xc3a471421bb1364d74b8f384cd73fe34d2ce1773",
    "T_small2":     "0x3dfb186e8ce513f321232098dd551e22886c1051",
    "T_med":        "0x7f0414886ebf34cce32148ba0cf64dd8ec88a274",
    "T_med2":       "0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a",
    "T_huge":       "0x657ba421cc8b1be5891aa9ac7aa2b936e5d08b65",
    "T_huge2":      "0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107",
    "DIV_v2":       "0xb85a8c269cfc6ec4bd44e7dbd312b233a38eea0d",
    "DIV_v3":       "0xc8e70639ad7d91d4d4bcf5d5ab8e2264abb7b25e",
    "DIV_v3_2":     "0xf7a36c87c3a8909949638120f23cd721bf572032",
    "SmartChef":    "0x2368bab38a79827f49fc768bf1b6d04226704d35",
}
S = {
    "lpToken": "0x5fcbd285", "nar": "0x86c2ef68", "rnlp": "0x4c738a5e",
    "_powerStrategy": "0xee631881", "_governance": "0x1c2f3e3d",
    "_hasStart": "0xe45a98dd", "_emergencyStop": "0x68612782",
    "_initReward": "0xffd832c1", "_periodFinish": "0x1407c664", "_rewardRate": "0x68fd25cd",
    "_lastUpdateTime": "0x6adafab5", "_startTime": "0xfa1acb5c",
    "totalSupply": "0x18160ddd", "owner": "0x8da5cb5b",
    "teamWallet": "0x59927044", "token": "0xfc0c546a", "stakingToken": "0x72f702f3",
}
ADDR = {"lpToken", "nar", "rnlp", "_powerStrategy", "_governance", "owner", "teamWallet", "token", "stakingToken"}
UINT = {"_initReward", "_periodFinish", "_rewardRate", "_lastUpdateTime", "_startTime", "totalSupply"}
BOOL = {"_hasStart", "_emergencyStop"}

def main():
    blk = int(rpc("eth_blockNumber", []), 16)
    out = {"block": blk, "farms": {}}
    for name, farm in FARMS.items():
        keys = list(S.keys())
        res = rpc_batch([("eth_call", [{"to": farm, "data": S[k]}, "latest"]) for k in keys], timeout=60)
        f = {}
        for k, r in zip(keys, res):
            if r is None:
                f[k] = None
            elif k in ADDR:
                f[k] = b32_to_addr(r)
            elif k in UINT:
                f[k] = hexint(r)
            elif k in BOOL:
                f[k] = hexint(r) != 0
        # balances
        try:
            if f.get("lpToken"):
                f["lp_totalSupply"] = hexint(rpc("eth_call", [{"to": f["lpToken"], "data": "0x18160ddd"}, "latest"]))
                f["lp_held"] = hexint(rpc("eth_call", [{"to": f["lpToken"], "data": "0x70a08231" + word(farm)}, "latest"]))
                t0 = b32_to_addr(rpc("eth_call", [{"to": f["lpToken"], "data": "0x0dfe1681"}, "latest"]))
                t1 = b32_to_addr(rpc("eth_call", [{"to": f["lpToken"], "data": "0xd21220a7"}, "latest"]))
                f["lp_tokens"] = [t0, t1]
            if f.get("nar"):
                f["nar_held"] = hexint(rpc("eth_call", [{"to": f["nar"], "data": "0x70a08231" + word(farm)}, "latest"]))
            if f.get("rnlp"):
                f["rnlp_totalSupply"] = hexint(rpc("eth_call", [{"to": f["rnlp"], "data": "0x18160ddd"}, "latest"]))
                f["rnlp_minter"] = b32_to_addr(rpc("eth_call", [{"to": f["rnlp"], "data": "0x075b1a09"}, "latest"]))
            f["bnb"] = int(rpc("eth_getBalance", [farm, "latest"]), 16)
        except Exception as e:
            f["err"] = str(e)[:80]
        out["farms"][name] = f
        print(f"== {name} {farm}")
        for k in ("lpToken", "lp_tokens", "lp_held", "lp_totalSupply", "nar", "nar_held", "rnlp",
                  "rnlp_minter", "rnlp_totalSupply", "_powerStrategy", "_governance", "_hasStart",
                  "_emergencyStop", "_initReward", "_rewardRate", "_periodFinish", "_lastUpdateTime", "totalSupply", "bnb", "owner", "err"):
            if f.get(k) is not None:
                print(f"   {k} = {f[k]}")
    json.dump(out, open(os.path.join(HERE, "farm-family-state.json"), "w"), indent=1)
    print("wrote farm-family-state.json")

if __name__ == "__main__":
    main()
