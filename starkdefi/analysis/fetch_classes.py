#!/usr/bin/env python3
"""Fetch deployed class ABIs (factory + 4 pair classes) and fingerprint entry points."""
import json, urllib.request, os

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]

def rpc(method, params, timeout=60, retries=4):
    last=None
    for i in range(retries):
        url=ENDPOINTS[i%len(ENDPOINTS)]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
    raise RuntimeError(f"{method}: {last}")

CLASSES = {
  "factory": "0x6c77d54bfca18537162f6a2c67db81783c6c414edb68a1117b56b1e48b9ec8",
  "pair_192": "0x30ca57592ec02e083d3fefd0245b2c10ca15a3d7f1c88e6675db051f94c2e9f",
  "pair_96":  "0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9",
  "pair_22":  "0x4a56a2e38b5d525a6d441e8d40d8546f6599442f1f8b8e466e45063592872b1",
  "pair_2":   "0x63c46ccdc3f160cc701e34179c6066949d6465693b7464ed4e643262513c05c",
}
out={}
for name, ch in CLASSES.items():
    try:
        cls = rpc("starknet_getClass", ["latest", ch])
    except Exception as e:
        print(name, "ERR", e); continue
    abi = cls.get("abi")
    if isinstance(abi, str):
        try: abi = json.loads(abi)
        except Exception: pass
    eps = cls.get("entry_points_by_type", {})
    ext = [e.get("name") for e in eps.get("EXTERNAL", [])]
    if abi is None:
        ext_names = ext
    else:
        ext_names = []
        for item in abi:
            if item.get("type")=="function":
                ext_names.append(item["name"]+"("+",".join(i["type"].split("::")[-1] for i in item.get("inputs",[]))+")")
    rec = {"class_hash": ch, "contract_class_version": cls.get("contract_class_version"),
           "n_external": len(eps.get("EXTERNAL",[])),
           "external": ext_names if abi else ext,
           "sierra_program_len": len(cls.get("sierra_program",[]))}
    out[name]=rec
    print(name, ch[:14], "ver:", cls.get("contract_class_version"), "n_ext:", len(eps.get("EXTERNAL",[])), "sierra:", rec["sierra_program_len"])
    print("   ", sorted(ext_names)[:40])
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","analysis"),exist_ok=True)
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","analysis","class_abis.json"),"w") as fh:
    json.dump(out, fh, indent=1)
