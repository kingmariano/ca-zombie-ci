"""Round 2: CL create_pool (3-arg) tests on the patched class + Sierra program diff old/new."""
import json
from starknet_nodep import rpc, sel, norm, block_number

CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
OLD_CLASS = "0x8fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17"
NEW_CLASS = "0x40974d74561db5f6c5e66cb50989cfdfc0ec0d1a96b577f85f29695c769a7bd"
EVIL = "0x028c9acd8eb7dc1cd7e3da98da3997cb57beca3c39d425e90780195df3a9a49e"
DAI = "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3"
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
ATTACKER = "0x029f9de5cafb30f55e4a6f4f032e8774958520c1649b3a0441f1354c0b330518"
RPC = "https://api.cartridge.gg/x/starknet/mainnet"

# --- Sierra program diff ---
old = rpc("starknet_getClass", {"block_id": "latest", "class_hash": OLD_CLASS})
new = rpc("starknet_getClass", {"block_id": "latest", "class_hash": NEW_CLASS})
op, np_ = old.get("sierra_program", []), new.get("sierra_program", [])
print("sierra_program len old/new:", len(op), len(np_))
same_prefix = 0
for a, b in zip(op, np_):
    if a == b:
        same_prefix += 1
    else:
        break
print("common prefix felts:", same_prefix, f"({100*same_prefix/max(len(op),1):.1f}% of old)")
# entry points diff
oe, ne = old.get("entry_points_by_type", {}), new.get("entry_points_by_type", {})
for t in set(oe) | set(ne):
    o = {e["selector"]: e["function_idx"] for e in oe.get(t, [])}
    n = {e["selector"]: e["function_idx"] for e in ne.get(t, [])}
    changed = {k: (o.get(k), n.get(k)) for k in set(o) | set(n) if o.get(k) != n.get(k)}
    print(t, "selectors:", len(o), "->", len(n), "changed:", len(changed))
    if changed:
        for k, v in list(changed.items())[:10]:
            print("   ", k, v)

# --- create_pool tests (3-arg) ---
nonce = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": norm(ATTACKER)})
sel_create = sel("create_pool")

def sim(calls):
    cd = [hex(len(calls))]
    for to, s, data in calls:
        cd += [to, s, hex(len(data))] + data
    tx = {"type": "INVOKE", "version": "0x1", "sender_address": ATTACKER, "calldata": cd,
          "signature": [], "nonce": nonce, "max_fee": "0x0"}
    try:
        return {"ok": True, "res": rpc("starknet_simulateTransactions", {
            "block_id": "latest", "transactions": [tx],
            "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]}, rpc_url=RPC)}
    except Exception as e:
        return {"ok": False, "err": str(e)[:600]}

for label, t0, t1, fee in [
    ("EVIL/DAI 500", EVIL, DAI, "0x1f4"),
    ("EVIL/ETH 3000", EVIL, ETH, "0xbb8"),
    ("DAI/random-eoa 500", DAI, "0x1234", "0x1f4"),
]:
    r = sim([(CL, sel_create, [t0, t1, fee])])
    if r["ok"]:
        res = r["res"][0]["transaction_trace"]["execute_invocation"]
        rr = res.get("revert_reason")
        print(f"create_pool {label}: {'REVERT' if rr else 'SUCCESS'} {str(rr)[:220] if rr else ''}")
    else:
        print(f"create_pool {label}: ERR {r['err'][:220]}")
