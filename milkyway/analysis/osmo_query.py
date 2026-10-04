#!/usr/bin/env python3
"""Query the MilkyWay TIA staking contract on Osmosis (read-only)."""
import base64, json, sys, urllib.request, urllib.parse

LCD = "https://osmosis-api.polkachu.com"
CONTRACT = "osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def smart(msg, contract=CONTRACT):
    q = base64.b64encode(json.dumps(msg).encode()).decode()
    url = f"{LCD}/cosmwasm/wasm/v1/contract/{contract}/smart/{q}"
    return get(url)

def bank(addr, limit=200):
    return get(f"{LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit={limit}")

def supply(denom):
    return get(f"{LCD}/cosmos/bank/v1beta1/supply/by_denom?denom={urllib.parse.quote(denom, safe='')}")

if __name__ == "__main__":
    out = {}
    for name, msg in [
        ("config", {"config": {}}),
        ("state", {"state": {}}),
        ("admin", {"admin": {}}),
        ("pending_batch", {"pending_batch": {}}),
        ("ibc_queue", {"ibc_queue": {"limit": 50}}),
        ("reply_queue", {"reply_queue": {"limit": 50}}),
        ("batches_asc", {"batches": {"limit": 100}}),
    ]:
        try:
            out[name] = smart(msg)
        except Exception as e:
            out[name] = {"error": str(e)}
    try:
        out["milkTIA_supply"] = supply("factory/osmo1f5vfcph2dvfeqcqkhetwv75fda69z7e5c2dldm3kvgj23crkv6wqcn47a0/umilkTIA")
    except Exception as e:
        out["milkTIA_supply"] = {"error": str(e)}
    out["contract_bank"] = bank(CONTRACT)
    print(json.dumps(out, indent=2))
