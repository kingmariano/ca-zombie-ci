"""Minimal Starknet JSON-RPC helper (read-only) for the mySwap V1 audit.

No keys, no signing, no transactions. Uses public Cartridge RPC by default;
falls back to other public endpoints. Selector = starknet_keccak(name) = keccak(name) & (2^250-1).
"""
import json, time
import requests
from eth_utils import keccak

RPC_URLS = [
    "https://api.cartridge.gg/x/starknet/mainnet",
]

MASK = (1 << 250) - 1


def sel(name: str) -> str:
    return hex(int.from_bytes(keccak(name.encode()), "big") & MASK)


def felt(x):
    if isinstance(x, int):
        return hex(x)
    return x


def rpc(method, params, rpc_url=None, retries=4):
    urls = [rpc_url] if rpc_url else RPC_URLS
    last = None
    for attempt in range(retries):
        for url in urls:
            try:
                r = requests.post(
                    url,
                    json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
                    timeout=60,
                )
                j = r.json()
                if "error" in j:
                    last = RuntimeError(f"{method}: {j['error']}")
                    continue
                return j["result"]
            except Exception as e:  # noqa
                last = e
                time.sleep(1 + attempt)
    raise last


def call(contract, fn, calldata=None, block="latest"):
    """Call a Cairo0 entrypoint by function name. Returns list of felt hex strings."""
    return rpc(
        "starknet_call",
        {
            "request": {
                "contract_address": felt(contract),
                "entry_point_selector": sel(fn),
                "calldata": [felt(c) for c in (calldata or [])],
            },
            "block_id": block,
        },
    )


def call_sel(contract, selector_hex, calldata=None, block="latest"):
    return rpc(
        "starknet_call",
        {
            "request": {
                "contract_address": felt(contract),
                "entry_point_selector": selector_hex,
                "calldata": [felt(c) for c in (calldata or [])],
            },
            "block_id": block,
        },
    )


def u256(parts, offset=0):
    """Combine (low, high) felts into int."""
    lo = int(parts[offset], 16)
    hi = int(parts[offset + 1], 16)
    return lo + (hi << 128)


def to_u256_parts(x):
    return [x & ((1 << 128) - 1), x >> 128]


def hexint(x):
    return int(x, 16) if isinstance(x, str) else int(x)


def norm(addr):
    return "0x" + format(hexint(addr), "064x")


def block_number():
    return rpc("starknet_blockNumber", [])


if __name__ == "__main__":
    print("block:", block_number())
    amm = 0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28
    n = call(amm, "get_total_number_of_pools")
    print("total pools:", [int(x, 16) for x in n])
