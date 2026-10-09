#!/usr/bin/env python3
"""Fetch all Nolus protocol contracts (created by the Admin contract) + their bank
balances from the public LCD, writing ci-out/raw/contracts_all.json in the shape
analysis/model.py expects. Read-only, keyless endpoints only."""
import json, subprocess, concurrent.futures, sys, os, urllib.parse

OUT = sys.argv[1] if len(sys.argv) > 1 else "ci-out/raw"
os.makedirs(OUT, exist_ok=True)
LCDS = ["https://lcd.nolus.network", "https://nolus.api.liveraven.net", "https://nolus-api.polkachu.com"]
ADMIN = "nolus1gurgpv8savnfw66lckwzn4zk7fp394lpe667dhu7aw48u40lj6jsqxf8nd"

def get(path, tries=3):
    for base in LCDS:
        for _ in range(tries):
            r = subprocess.run(["curl", "-sf", "--max-time", "30", "-H", "User-Agent: zombie-research/1.0",
                                base + path], capture_output=True, text=True)
            if r.returncode == 0:
                try:
                    return json.loads(r.stdout)
                except Exception:
                    continue
    return {}

def fetch_one(addr):
    info = get(f"/cosmwasm/wasm/v1/contract/{addr}")
    bal = get(f"/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")
    return addr, {"info": info, "balances": bal}

def main():
    cc = get(f"/cosmwasm/wasm/v1/contracts/creator/{ADMIN}?pagination.limit=500")
    addrs = cc.get("contract_addresses", [])
    if not addrs:
        print("WARN: no contracts fetched (endpoint unavailable)")
        return
    out = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
        for addr, v in ex.map(fetch_one, addrs):
            out[addr] = v
    with open(os.path.join(OUT, "contracts_all.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"contracts fetched: {len(out)}")

if __name__ == "__main__":
    main()
