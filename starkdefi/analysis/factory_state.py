#!/usr/bin/env python3
"""Read StarkDeFi factory live state + pair class hashes (read-only)."""
import json, urllib.request, os, sys
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]
FACTORY = "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"
SEL = {
    "fee_handler": "0x2ded64caa8ae4aba3291cc1f172d4b8fda206d4d1b5660c7565e7461c727929",
    "fee_to": "0x845a08a51fd77880cb14b0e33c63bb1b6d98e77c57673f0aa3e31a9fd2ca64",
    "paused": "0x235723ac350a69d2a92d3703f17439cbaadf2f093a21ba5bf5f1a53eb2a14d9",
    "protocol_fee_on": "0x6c7bb53f67c381aeb32b8b40102cb0fccca59e58819b09d755a39ddec1696a",
    "get_fees": "0xbbcc6aa129954e737439820919ccf54fab31fe3ad3f0a83b6dc174f56595d4",
    "class_hash_for_pair_contract": "0x3056e2757efc73e49a6b99b9b8f82248373a21038be36c8824e8d17c4da8026",
    "all_pairs_length": "0x2c6939cccde3eabcd09b5d7f3058a107295886c21c517bfc1770178b1c361d6",
    "fee_vault": "0x2427f2934af378524e7fbad30ab36e6f01473e3ab24a8cf44716048e92f50e6",
}

def rpc(method, params, timeout=45, retries=4):
    last = None
    for i in range(retries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last = out
        except Exception as e:
            last = repr(e)
    raise RuntimeError(f"{method}: {last}")

def call(addr, sel, cd=None, block="latest"):
    return rpc("starknet_call", [{"contract_address": addr, "entry_point_selector": sel, "calldata": cd or []}, block])

if __name__ == "__main__":
    block = rpc("starknet_blockNumber", [])
    out = {"block": block, "factory": FACTORY}
    for name, sel in SEL.items():
        try:
            out[name] = call(FACTORY, sel, block={"block_number": block})
        except Exception as e:
            out[name] = f"ERR {e}"
    out["factory_class_hash"] = rpc("starknet_getClassHashAt", ["latest", FACTORY])
    pairs = [json.loads(l) for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "pairs_raw.jsonl"))]
    pair_addrs = [p["pair"] for p in pairs]

    def fetch(a):
        ch = rpc("starknet_getClassHashAt", [{"block_number": block}, a])
        try:
            v = call(a, SEL["fee_vault"], block={"block_number": block})
        except Exception as e:
            v = None
        return a, ch, v

    chs, vaults = {}, {}
    with ThreadPoolExecutor(max_workers=8) as ex:
        for f in as_completed({ex.submit(fetch, a): a for a in pair_addrs}):
            try:
                a, ch, v = f.result()
                chs[a] = ch; vaults[a] = v
            except Exception as e:
                print("err", f.result if False else e)
    from collections import Counter
    print("pair class hash distribution:", Counter(chs.values()))
    out["pair_class_hashes"] = chs
    out["vaults"] = vaults
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "factory_state.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print(json.dumps({k: v for k, v in out.items() if k not in ("pair_class_hashes","vaults")}, indent=1))
