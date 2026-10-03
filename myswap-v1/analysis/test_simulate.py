"""Retry simulateTransactions with valid felt sender/max_fee."""
import json, requests
from eth_utils import keccak

MASK = (1 << 250) - 1
def s(name): return hex(int.from_bytes(keccak(name.encode()), "big") & MASK)

LEGACY = "0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28"
TOKEN = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"

def post(url, method, params):
    r = requests.post(url, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=60)
    try:
        return r.json()
    except Exception:
        return r.text[:400]

# valid-ish small address (< 2^251)
sender = "0x0123456789abcdef"
sel_dist = s("distribute_tokens")
cd = [TOKEN, "0x0"]  # empty ledger
invoke = {
    "type": "INVOKE",
    "version": "0x1",
    "sender_address": sender,
    "calldata": ["0x1", LEGACY, sel_dist, "0x2"] + cd,
    "signature": [],
    "nonce": "0x0",
    "max_fee": "0x1000000000000000000000000000000",
}
tx = invoke

for name, url in [("cartridge","https://api.cartridge.gg/x/starknet/mainnet"),
                  ("publicnode","https://starknet-rpc.publicnode.com")]:
    print("=====", name)
    for label, params in [
        ("obj", {"block_id": "latest", "transactions": [tx], "simulation_flags": ["SKIP_VALIDATE"]}),
        ("pos", ["latest", [tx], ["SKIP_VALIDATE"]]),
        ("obj-fee", {"block_id": "latest", "transactions": [tx], "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]}),
    ]:
        res = post(url, "starknet_simulateTransactions", params)
        print(label, "->", json.dumps(res)[:400])
