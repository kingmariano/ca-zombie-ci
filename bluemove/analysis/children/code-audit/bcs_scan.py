#!/usr/bin/env python3
"""Fetch raw package module BCS for v7/v11/v12 (and v1) and diff to locate get_contract_version constants."""
import json, sys, base64
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

PKGS = {
    "v1":  "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9",
    "v7":  "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f",
    "v9":  "0x7be61b62d902f3fe78d0a5e20b81b4715a47ff06cae292db8991dfea422cf57e",
    "v11": "0xf72bd3b3277929f315b793b669774580baa1e1a32af4740dc797a1c5f5bfd656",
    "v12": "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7",
}
q = """query($addr: SuiAddress!) {
  object(address: $addr) {
    asMovePackage {
      moduleBcs
      modules(first: 50) { nodes { name } }
    }
  }
}"""
data = {}
for name, pkg in PKGS.items():
    try:
        d = gql(q, {"addr": pkg})
        b64 = (((d.get("object") or {}).get("asMovePackage")) or {}).get("moduleBcs")
        mods = [m["name"] for m in ((((d.get("object") or {}).get("asMovePackage")) or {}).get("modules") or {}).get("nodes") or []]
        data[name] = base64.b64decode(b64)
        print(name, pkg[:10], "len", len(data[name]), "modules", mods)
    except Exception as e:
        print(name, "ERR", str(e)[:200])

# find 'utils' module bytes within each moduleBcs by locating the module name string then parsing the Vec<u8> that follows:
# ModuleMap BCS = vec of (Identifier, CompiledModule-bytes). We'll locate b"utils" occurrences and take a window.
import binascii
for name, b in data.items():
    idxs = []
    start = 0
    while True:
        i = b.find(b"utils", start)
        if i < 0: break
        idxs.append(i); start = i+1
    print(name, "len", len(b), "'utils' offsets:", idxs[:6])
