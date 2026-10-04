#!/usr/bin/env python3
"""Dump sample full accounts for each size bucket of a program."""
import json, sys, time
sys.path.insert(0, "/home/heisenberg/CA/francium/analysis")
from rpc import rpc_call

PROGRAMS = {
    "lending": "FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj",
    "reward": "3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6",
    "lyfRaydium": "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N",
    "lyfOrca": "DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP",
}

def main():
    prog = PROGRAMS[sys.argv[1]]
    res = rpc_call("getProgramAccounts", [prog, {"encoding": "base64", "dataSlice": {"offset": 0, "length": 0}}])
    by_size = {}
    for a in res:
        by_size.setdefault(a["account"]["space"], []).append(a["pubkey"])
    out = {"program": prog, "count": len(res), "buckets": {}}
    for size, keys in sorted(by_size.items()):
        sample = keys[:3]
        accts = rpc_call("getMultipleAccounts", [sample, {"encoding": "base64"}])
        out["buckets"][size] = {
            "count": len(keys),
            "sample_keys": keys[:10],
            "samples": [{"pubkey": k, "data": v["data"][0], "lamports": v["lamports"], "owner": v["owner"]} for k, v in zip(sample, accts["value"])],
        }
        time.sleep(0.3)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
