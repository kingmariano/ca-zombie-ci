"""Probe the historical mySwap V1 AMM address: class hash, entry points, try known selectors."""
import json
from starknet_lib import rpc, call, call_sel, sel, norm, block_number, u256, hexint
from eth_utils import keccak

AMM = 0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28

print("block", block_number())
ch = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": norm(AMM)})
print("class hash:", ch)

cls = rpc("starknet_getClassAt", {"block_id": "latest", "contract_address": norm(AMM)})
print("class keys:", list(cls.keys()))
eps = cls.get("entry_points_by_type", {})
for typ, lst in eps.items():
    print(typ, len(lst))
    for e in lst:
        print("   ", e)
