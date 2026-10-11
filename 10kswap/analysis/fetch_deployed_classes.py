#!/usr/bin/env python3
"""Fetch the deployed 10KSwap pair/factory/router class definitions from public RPC and
save them gzipped into ci/inputs/ for the CI class-hash reproduction job.
Read-only; public data only."""
import json, sys, os, gzip
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(D, "..", "ci", "inputs")
os.makedirs(IN, exist_ok=True)

DEPLOYED = {
    "pair": "0x231adde42526bad434ca2eb983efdd64472638702f87f97e6e3c084f264e06f",
    "factory": "0x55373ed0e387ba6117b7bf65fa4a67af582f8de4e2a20cc75669d26ddb2df3",
    "router": "0x514718bb56ed2a8607554c7d393c2ffd73cbab971c120b00a2ce27cc58dd1c1",
}

def main():
    blk = sn.rpc("starknet_blockNumber", [])
    meta = {"block": blk, "classes": {}}
    for name, ch in DEPLOYED.items():
        cc = sn.get_class(ch)
        raw = json.dumps(cc, sort_keys=True)
        path = os.path.join(IN, f"{name}_class_deployed.json.gz")
        with gzip.open(path, "wt") as f:
            f.write(raw)
        meta["classes"][name] = {"class_hash": ch, "keys": sorted(cc.keys()),
                                 "gzip_bytes": os.path.getsize(path)}
        print(name, ch, "->", path, os.path.getsize(path), "bytes")
    with open(os.path.join(IN, "deployed_meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("block:", blk)

if __name__ == "__main__":
    main()
