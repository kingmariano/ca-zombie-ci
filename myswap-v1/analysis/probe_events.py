"""Find upgrade events / admin of MySwapLegacy + match ABI selectors."""
import json
from starknet_lib import rpc, call, call_sel, sel, norm, block_number, hexint
from eth_utils import keccak

LEGACY = 0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28

MASK = (1 << 250) - 1
def s(name):
    return hex(int.from_bytes(keccak(name.encode()), "big") & MASK)

for n in ["upgrade", "distribute_tokens", "assert_admin", "Upgraded", "Transfer"]:
    print(f"{n:20s} {s(n)}")

print()
print("entry point selectors from class:")
for e in [
    "0x5dac7a4bf79fe9e5627ad9ff4cb2b1547e6f348c887f0c85052120baba1baa",
    "0xd246002fced6f89c3edc2d579780a37441b8f0ab0630cf522a880d27430090",
    "0xf2f7c15cbe06c8d94597cd91fd7f3369eae842359235712def5584f8d270cd",
]:
    print("  ", e)

# full revert of assert_admin
print()
try:
    print(call(LEGACY, "assert_admin"))
except Exception as e:
    print("assert_admin revert:", str(e)[:600])

# try to find Upgraded events emitted by legacy contract (address filter = emitter)
print()
try:
    ev = rpc("starknet_getEvents", {
        "filter": {
            "from_block": {"block_number": 0},
            "to_block": "latest",
            "address": norm(LEGACY),
            "keys": [[s("Upgraded")]],
            "chunk_size": 10,
        }
    })
    print(json.dumps(ev, indent=1)[:3000])
except Exception as e:
    print("getEvents err:", str(e)[:400])
