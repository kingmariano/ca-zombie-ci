#!/usr/bin/env python3
"""Starknet helpers: sn_keccak selectors, pedersen storage keys, RPC read-only calls."""
import json, subprocess, sys
from Crypto.Hash import keccak

RPC = "https://starknet-rpc.publicnode.com"
MASK = (1 << 250) - 1

def keccak256(data: bytes) -> bytes:
    h = keccak.new(digest_bits=256); h.update(data); return h.digest()

def sn_keccak(s: str) -> int:
    return int.from_bytes(keccak256(s.encode()), "big") & MASK

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    out = subprocess.run(["curl", "-s", "-m", "40", "-X", "POST", "-H", "Content-Type: application/json",
                          "-d", body, RPC], capture_output=True, text=True).stdout
    return json.loads(out)

def call(to, selector_name, calldata=None):
    return rpc("starknet_call", [{
        "contract_address": to,
        "entry_point_selector": hex(sn_keccak(selector_name)),
        "calldata": calldata or []
    }, "latest"])

def storage_at(addr, key):
    return rpc("starknet_getStorageAt", [addr, hex(key), "latest"])

if __name__ == "__main__":
    # sanity check: known selector for balanceOf
    print("balanceOf selector:", hex(sn_keccak("balanceOf")))
    print("is_paused selector:", hex(sn_keccak("is_paused")))
    print("owner selector:", hex(sn_keccak("owner")))
