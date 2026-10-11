#!/usr/bin/env python3
"""Recon 3: probe pair `initialize` re-callability (read-only starknet_call; state discarded).
Also probe factory getPair for the same token set and other admin surfaces."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
FACTORY = "0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2"

def main():
    r1 = json.load(open(os.path.join(D, "recon1.json")))
    pairs = r1["pairs"]
    out = {"block": sn.rpc("starknet_blockNumber", []), "tests": []}

    sel_init = sn.selector("initialize")
    print("initialize selector:", sel_init)

    # dummy addresses: use USDT and WBTC as alternate tokens (both exist)
    USDT = 0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8
    WBTC = 0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac

    for p in pairs:
        t0 = r1["pair_state"][p]["token0"][0]
        t1 = r1["pair_state"][p]["token1"][0]
        # try re-initialize with (USDT, WBTC) — deliberately different from stored tokens
        for tag, a, b in [("usdt_wbtc", USDT, WBTC), ("same", t0, t1), ("zero", 0, 0)]:
            try:
                r = sn.call_sel(p, sel_init, [a, b])
                res = {"pair": p, "tag": tag, "result": r, "reverted": False}
                print(f"INIT-OK  {p[:14]} {tag} -> {r}")
            except Exception as e:
                res = {"pair": p, "tag": tag, "error": str(e)[:200], "reverted": True}
                print(f"INIT-REV {p[:14]} {tag} -> {str(e)[:140]}")
            out["tests"].append(res)

    with open(os.path.join(D, "recon3.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote recon3.json")

if __name__ == "__main__":
    main()
