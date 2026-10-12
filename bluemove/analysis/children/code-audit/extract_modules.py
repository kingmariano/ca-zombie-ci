#!/usr/bin/env python3
"""Parse ModuleMap BCS (uleb-prefixed strings/byte arrays), extract utils module bytes, disassemble via sui CLI."""
import json, sys, base64, subprocess, os, pathlib
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

PKGS = {
    "v1":  "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9",
    "v7":  "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f",
    "v8":  "0x0cdcbc6a7c5b8d10c265a715d6d007dceadd561c41a3e038ef9aaeae419d79b7",
    "v9":  "0x7be61b62d902f3fe78d0a5e20b81b4715a47ff06cae292db8991dfea422cf57e",
    "v10": "0xc396a92a74917ae414dee481c74f4a013ab88ce11aae48c337ac4e6dc95f513b",
    "v11": "0xf72bd3b3277929f315b793b669774580baa1e1a32af4740dc797a1c5f5bfd656",
    "v12": "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7",
}
q = """query($addr: SuiAddress!) {
  object(address: $addr) { asMovePackage { moduleBcs } }
}"""

def uleb(b, i):
    x = 0; s = 0
    while True:
        c = b[i]; i += 1
        x |= (c & 0x7f) << s
        if not (c & 0x80): break
        s += 7
    return x, i

outdir = pathlib.Path("/home/heisenberg/CA/bluemove/analysis/children/code-audit/modules")
outdir.mkdir(exist_ok=True)

for name, pkg in PKGS.items():
    try:
        d = gql(q, {"addr": pkg})
        b64 = (((d.get("object") or {}).get("asMovePackage")) or {}).get("moduleBcs")
        b = base64.b64decode(b64)
        n, i = uleb(b, 0)
        mods = {}
        for _ in range(n):
            ln, i = uleb(b, i)
            nm = b[i:i+ln].decode(); i += ln
            vl, i = uleb(b, i)
            mb = b[i:i+vl]; i += vl
            mods[nm] = mb
        (outdir / f"{name}_utils.mv").write_bytes(mods["utils"])
        (outdir / f"{name}_swap.mv").write_bytes(mods["swap"])
        print(name, "parsed modules:", len(mods), "utils len:", len(mods["utils"]), "swap len:", len(mods["swap"]))
    except Exception as e:
        print(name, "ERR", str(e)[:300])
print("done")
