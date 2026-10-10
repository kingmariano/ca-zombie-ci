#!/usr/bin/env python3
"""Test starknet_simulateTransactions SKIP_VALIDATE support on public endpoints (read-only)."""
import json, urllib.request, sys

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]

def rpc(url, method, params, timeout=60):
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def main():
    sender = "0x283b6df5330e5ba0c9ffc4a5c80de4227bdab78b6a155654ae78f220d6bdf53"
    # fee_handler account: class + nonce
    for url in ENDPOINTS:
        try:
            ch = rpc(url, "starknet_getClassHashAt", ["latest", sender])
            nonce = rpc(url, "starknet_getNonce", ["latest", sender])
            print(url, "class:", ch.get("result"), "nonce:", nonce.get("result"))
        except Exception as e:
            print(url, "ERR", e)
    # build a dummy invoke tx calling factory.assert_not_paused()
    tx = {
        "type": "INVOKE",
        "version": "0x1",
        "sender_address": sender,
        "calldata": [
            "0x1",  # calls len
            "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e",  # to factory
            "0x8232b1ab5b3d8707961764035663a30b8be74a1cf3cc9f441ac55a0405a5f0",  # assert_not_paused
            "0x0",  # calldata len
        ],
        "signature": [],
        "nonce": "0x0",
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x100000", "max_price_per_unit": "0x10000000000"},
            "l2_gas": {"max_amount": "0x100000000", "max_price_per_unit": "0x10000000000"},
        },
        "tip": "0x0",
        "paymaster_data": [],
        "account_deployment_data": [],
        "nonce_data_availability_mode": "L1",
        "fee_data_availability_mode": "L1",
    }
    for url in ENDPOINTS:
        for flags in (["SKIP_VALIDATE"], []):
            try:
                out = rpc(url, "starknet_simulateTransactions", ["latest", [tx], flags])
                print("==", url, flags, "->", json.dumps(out)[:300])
            except urllib.error.HTTPError as e:
                body = e.read().decode()[:300]
                print("==", url, flags, "HTTP", e.code, body)
            except Exception as e:
                print("==", url, flags, "ERR", repr(e)[:200])

if __name__ == "__main__":
    main()
