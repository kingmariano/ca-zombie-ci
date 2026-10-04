#!/usr/bin/env python3
"""Check whether locally-built Heliobond WASMs exist as ContractCode entries
on Stellar mainnet / testnet. Read-only Soroban RPC getLedgerEntries.

Usage: check_wasm_on_chain.py [--json] name=path/to.wasm [name2=path2.wasm ...]
"""
import base64
import hashlib
import json
import struct
import sys
import time
import urllib.request

NETWORKS = {
    "mainnet": ["https://mainnet.sorobanrpc.com", "https://soroban-rpc.mainnet.stellar.gateway.fm"],
    "testnet": ["https://soroban-testnet.stellar.org"],
}
UA = "Mozilla/5.0 (X11; Linux x86_64) heliobond-readonly-research/1.0"


def rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(
                url, data=body, headers={"Content-Type": "application/json", "User-Agent": UA}
            )
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(2 * (i + 1))
    raise last


def contract_code_key(wasm_hash_hex):
    h = bytes.fromhex(wasm_hash_hex)
    assert len(h) == 32
    return base64.b64encode(struct.pack(">i", 7) + h).decode()


def main():
    as_json = "--json" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--json"]
    results = {}
    for arg in args:
        name, path = arg.split("=", 1)
        data = open(path, "rb").read()
        h = hashlib.sha256(data).hexdigest()
        results[name] = {"path": path, "size": len(data), "sha256": h, "networks": {}}
        key = contract_code_key(h)
        for net, urls in NETWORKS.items():
            for url in urls:
                try:
                    resp = rpc(url, "getLedgerEntries", {"keys": [key]})
                    entries = (resp.get("result") or {}).get("entries") or []
                    results[name]["networks"][net] = {
                        "rpc": url,
                        "found": bool(entries),
                        "live_until": entries[0].get("liveUntilLedgerSeq") if entries else None,
                        "latest_ledger": (resp.get("result") or {}).get("latestLedger"),
                    }
                    break
                except Exception as e:
                    results[name]["networks"][net] = {"rpc": url, "error": str(e)}

    if as_json:
        print(json.dumps(results, indent=2))
    else:
        for name, r in results.items():
            print(f"{name}: {r['path']} size={r['size']} sha256={r['sha256']}")
            for net, info in r["networks"].items():
                if "error" in info:
                    print(f"  {net}: ERROR {info['error']}")
                else:
                    print(
                        f"  {net}: contract_code_present={info['found']} "
                        f"(live_until={info['live_until']}, latest={info['latest_ledger']})"
                    )


if __name__ == "__main__":
    main()
