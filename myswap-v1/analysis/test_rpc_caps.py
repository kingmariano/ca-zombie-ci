"""Test RPC capabilities: historical calls, simulateTransactions, events. Robust to param-format variants."""
import json, requests
from eth_utils import keccak

MASK = (1 << 250) - 1
def s(name): return hex(int.from_bytes(keccak(name.encode()), "big") & MASK)

LEGACY = "0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28"
GET_N = "0x105b90925282800807177a6067e409237de3431ff129a80067088d890f2d9d3"

def post(url, method, params):
    r = requests.post(url, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=40)
    return r.status_code, r.text[:400]

urls = {
 "cartridge": "https://api.cartridge.gg/x/starknet/mainnet",
 "publicnode": "https://starknet-rpc.publicnode.com",
}

req = {"contract_address": LEGACY, "entry_point_selector": GET_N, "calldata": []}
block = {"block_number": 1397398}

for name, url in urls.items():
    print("=====", name)
    # format A: single object {request, block_id}
    print("A:", post(url, "starknet_call", {"request": req, "block_id": block})[1][:200])
    # format B: positional [req, block_id]
    print("B:", post(url, "starknet_call", [req, block])[1][:200])
    # latest sanity
    print("latest:", post(url, "starknet_blockNumber", [])[1][:120])

print()
print("===== simulate support test (cartridge)")
# impersonated invoke v1 calling distribute_tokens with empty ledger from random sender
sender = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
sel_dist = s("distribute_tokens")
# calldata: token_address, ledger_len, then entries
token = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
cd = [token, "0x0"]
invoke = {
    "type": "INVOKE",
    "version": "0x1",
    "sender_address": sender,
    "calldata": [ "0x1", LEGACY, sel_dist, "0x2" ] + cd,
    "signature": [],
    "nonce": "0x0",
    "max_fee": "0x0",
}
tx = invoke
params_variants = [
    {"block_id": "latest", "transactions": [tx], "simulation_flags": ["SKIP_VALIDATE"]},
    ["latest", [tx], ["SKIP_VALIDATE"]],
    ["latest", [tx], ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]],
]
for i, p in enumerate(params_variants):
    st, txt = post("https://api.cartridge.gg/x/starknet/mainnet", "starknet_simulateTransactions", p)
    print(f"cartridge simulate variant {i}: {st} {txt[:300]}")
for i, p in enumerate(params_variants):
    st, txt = post("https://starknet-rpc.publicnode.com", "starknet_simulateTransactions", p)
    print(f"publicnode simulate variant {i}: {st} {txt[:300]}")
