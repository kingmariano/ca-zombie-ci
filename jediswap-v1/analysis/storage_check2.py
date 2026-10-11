import json, sn
from concurrent.futures import ThreadPoolExecutor
def sn_keccak(s):
    return int.from_bytes(sn.keccak256(s.encode()), "big") & ((1<<250)-1)
FACT = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
pairs = [p["pair"] for p in json.load(open("pair_state.json"))["pairs"]]
la = hex(sn_keccak("_locked")); fa = hex(sn_keccak("_factory"))
def chk(p):
    try:
        lv = sn.rpc("starknet_getStorageAt", [p, la, "latest"])
        fv = sn.rpc("starknet_getStorageAt", [p, fa, "latest"])
        return p, int(lv,16), int(fv,16)
    except Exception as e:
        return p, -1, -1
locked_bad=[]; fac_bad=[]
with ThreadPoolExecutor(max_workers=10) as ex:
    for p, lv, fv in ex.map(chk, pairs):
        if lv != 0: locked_bad.append([p, hex(lv)])
        if fv != int(FACT,16): fac_bad.append([p, hex(fv)])
print("locked_bad:", len(locked_bad), locked_bad[:5])
print("fac_bad:", len(fac_bad), fac_bad[:5])
json.dump({"locked_bad": locked_bad, "fac_bad": fac_bad}, open("storage_check.json","w"), indent=1)
print("DONE")
