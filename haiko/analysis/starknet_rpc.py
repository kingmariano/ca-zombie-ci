#!/usr/bin/env python3
"""Minimal Starknet JSON-RPC client (read-only) for the C2-49 Haiko audit.

Uses keyless public endpoints by default (no secrets in this file).
Endpoints tried in order; can override with STARKNET_RPC env var.
"""
import json
import os
import sys
import time
import urllib.request

ENDPOINTS = [
    os.environ.get("STARKNET_RPC", ""),
    "https://starknet-rpc.publicnode.com",
    "https://starknet.api.onfinality.io/public",
]
# optional keyed fallback (never written to disk/logs)
if os.environ.get("INFURA_API_KEY"):
    ENDPOINTS.append("https://starknet-mainnet.infura.io/v3/" + os.environ["INFURA_API_KEY"])
ENDPOINTS = [e for e in ENDPOINTS if e]

_id = 0


def rpc(method, params, endpoint=None):
    global _id
    _id += 1
    payload = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    urls = [endpoint] if endpoint else ENDPOINTS
    last = None
    for url in urls:
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    url, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
                )
                with urllib.request.urlopen(req, timeout=30) as r:
                    out = json.loads(r.read().decode())
                if "error" in out:
                    err = out["error"]
                    # retry on rate limit
                    if err.get("code") == 429 or "rate" in str(err).lower():
                        time.sleep(2 + attempt * 2)
                        last = out
                        continue
                    # other node-specific errors: try the next endpoint
                    last = out
                    break
                return out
                return out
            except Exception as e:  # noqa
                last = {"error": {"message": str(e)}}
                time.sleep(1 + attempt)
        # try next endpoint on transport errors
    return last


def block_number():
    out = rpc("starknet_blockNumber", [])
    return out.get("result")


def call(contract, selector, calldata=None, block="latest"):
    out = rpc("starknet_call", {"request": {
        "contract_address": contract,
        "entry_point_selector": selector,
        "calldata": calldata or [],
    }, "block_id": block})
    return out


def felt_to_int(x):
    return int(x, 16) if isinstance(x, str) and x.startswith("0x") else int(x)


def u256_from_felts(felts):
    """Starknet u256 = [low, high] felts."""
    low = felt_to_int(felts[0])
    high = felt_to_int(felts[1])
    return low + (high << 128)


def selector_from_name(name):
    """starknet_keccak(name) - sn_keccak: first 250 bits of keccak256."""
    h = None
    try:
        from Crypto.Hash import keccak  # pycryptodome
        k = keccak.new(digest_bits=256)
        k.update(name.encode())
        h = int.from_bytes(k.digest(), "big")
    except Exception:
        try:
            import sha3  # pysha3
            h = int.from_bytes(sha3.keccak_256(name.encode()).digest(), "big")
        except Exception:
            try:
                import eth_hash.auto as _eh  # eth-hash
                h = int.from_bytes(_eh.keccak(name.encode()), "big")
            except Exception:
                raise RuntimeError(
                    "no keccak256 implementation available (install pycryptodome); "
                    "cannot compute starknet selectors"
                )
    return hex(h & ((1 << 250) - 1))


if __name__ == "__main__":
    print("block:", block_number())
