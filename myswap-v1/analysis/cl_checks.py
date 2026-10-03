"""CL sibling checks: class hash pre/post hack, owner/migrator state, trace support."""
import json
from starknet_nodep import rpc, call, call_sel, sel, norm, block_number, u256, hexint

CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
ATTACK_TX = "0x1c15c4064cb3d72df27a35dfcd2da17c108abfb8e671428cb9d457f698f588"
HACK_BLOCK = 10951100

print("latest", block_number())
for b in [10950000, 10951100, 11000000, 15000000, "latest"]:
    bid = "latest" if b == "latest" else {"block_number": b}
    try:
        ch = rpc("starknet_getClassHashAt", {"block_id": bid, "contract_address": norm(CL)})
        print("CL class @", b, "=", ch)
    except Exception as e:
        print("CL class @", b, "ERR", str(e)[:120])

for fn in ["owner", "migrator", "get_storage_version"]:
    try:
        r = call(CL, fn)
        print(fn, "=", r)
    except Exception as e:
        print(fn, "ERR", str(e)[:150])

# trace support
for name, url in [("cartridge", "https://api.cartridge.gg/x/starknet/mainnet"),
                  ("publicnode", "https://starknet-rpc.publicnode.com")]:
    try:
        t = rpc("starknet_traceTransaction", [ATTACK_TX], rpc_url=url)
        print(name, "trace OK, keys:", list(t.keys()))
        with open("cl_attack_trace.json", "w") as f:
            json.dump(t, f)
        break
    except Exception as e:
        print(name, "trace ERR", str(e)[:200])
