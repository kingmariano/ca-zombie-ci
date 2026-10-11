#!/usr/bin/env python3
"""Fetch top BPT holders for all value-bearing Aequinox pools via Ankr advanced API.
Env: ANKR_API_KEY (never written to output). Output: analysis/bpt_holders.json
"""
import json, os, urllib.request, time

KEY = os.environ.get("ANKR_API_KEY")
HERE = os.path.dirname(os.path.abspath(__file__))

POOLS = [
    "0xb3a07a9cef918b2ccec4bc85c6f2a7975c5e83f9",
    "0x0256c70b89b3c0ed888b7b7d7767a701b2a67bea",
    "0x5ba2bc395b511ecf3f7c7f4f6c5de3c5586239ae",
    "0x74154c70f113c2b603aa49899371d05eeedd1e8c",
    "0x9aa867870d5775a3c155325db0cb0b116bbf4b6a",
    "0x7a09ddf458fda6e324a97d1a8e4304856fb3e702",
    "0xe53896c872b39fa3254262d18157447504b211de",
    "0x48d250b5c8bcb44c3d7f53acaf1ab101609f7a8a",
    "0xe263e513395ee7d9b0228ad22824f1a860ff85cc",
    "0x835ff599b9388e4f733c165a15a93e736ebf91d3",
    "0x301c7496447bc38e03bb726e596c85db39690c73",
    "0x016fcb8c8cb43bd0afb0be7486aadee49783487c",
    "0x7d0463c2deec2b6159b9ff56b0e6b98e88290d06",
    "0x7de5d717696ed640c9af3f2dbb069d71bf874bee",
    "0x950667ef678bae44ef037c721e564c365fc8303e",
    "0x9562b8bc2ff2f3993137827f2da79b23c7a10b42",
    "0x7c8bfc3986c47754af9a2c0591573fc1423ad64c",
    "0x090b21e811dae70c0a83cbcea04553e9df2d1511",
    "0xf31ff14f9cbe7f8ba148f3a85a6ece96335a08a8",
    "0xd203730861d8e4be87a439934c9416c819240344",
]

def ankr(method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(f"https://rpc.ankr.com/multichain/{KEY}", data=body,
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read())
            return d.get("result")
        except Exception as e:
            if a == retries - 1:
                return {"error": str(e)}
            time.sleep(1.5)

out = {}
for p in POOLS:
    r = ankr("ankr_getTokenHolders", {"blockchain": "bsc", "contractAddress": p, "pageSize": 12})
    out[p] = r
    holders = (r or {}).get("holders", []) if isinstance(r, dict) else []
    print(p, "holders:", len(holders), "top:", holders[0]["holderAddress"] if holders else None,
          holders[0]["balance"] if holders else None, flush=True)

json.dump(out, open(os.path.join(HERE, "bpt_holders.json"), "w"), indent=1)
print("written")
