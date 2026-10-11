import json, sn
def sn_keccak(s):
    return int.from_bytes(sn.keccak256(s.encode()), "big") & ((1<<250)-1)
FACT = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
stj = json.load(open("pair_state.json"))
pairs = [p["pair"] for p in stj["pairs"]]
locked_addr = hex(sn_keccak("_locked")); fac_addr = hex(sn_keccak("_factory"))
locked_bad = []; fac_bad = []
for i, p in enumerate(pairs):
    lv = sn.rpc("starknet_getStorageAt", [p, locked_addr, "latest"])
    fv = sn.rpc("starknet_getStorageAt", [p, fac_addr, "latest"])
    if int(lv,16) != 0: locked_bad.append((p, lv))
    if int(fv,16) != int(FACT,16): fac_bad.append((p, fv))
    if i % 200 == 0: print("checked", i, flush=True)
print("locked_bad:", len(locked_bad), locked_bad[:10])
print("fac_bad:", len(fac_bad), fac_bad[:10])
json.dump({"locked_bad": locked_bad, "fac_bad": fac_bad}, open("storage_check.json","w"), indent=1)
print("DONE")
