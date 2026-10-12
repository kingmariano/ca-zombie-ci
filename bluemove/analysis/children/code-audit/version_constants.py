#!/usr/bin/env python3
import json, sys, base64, subprocess, pathlib
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

PKGS = {
    "v2":  "0xdc8437d021efc026249b796ce5375ce60433a5dd9c05cf6aee8668dc2191a8ad",
    "v3":  "0xdf87af8c63ce5991058fdd45fa4d79c9952f8191030a9737884afec79dab76cc",
    "v4":  "0xb574a776a50fb2f867ea1a35f37f3362a30aa2f6768cc72035c69d5624e5e3a4",
    "v5":  "0x941f5ee6d336545a2ae00ef763725ce826168bbc914d00ba95a87af076af0b7a",
    "v6":  "0xa00faab58ff6876dce096d5e0591200b84a14f4033319d27c48b781a37aa2ed7",
    "v10": "0xc396a92a74917ae414dee481c74f4a013ab88ce11aae48c337ac4e6dc95f513b",
}
q = """query($addr: SuiAddress!) {
  object(address: $addr) { asMovePackage { moduleBcs modules(first: 50) { nodes { name functions(first: 50) { nodes { name } } } } } }
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
for name, pkg in PKGS.items():
    d = gql(q, {"addr": pkg})
    mp = ((d.get("object") or {}).get("asMovePackage")) or {}
    b = base64.b64decode(mp["moduleBcs"])
    n, i = uleb(b, 0)
    mods = {}
    for _ in range(n):
        ln, i = uleb(b, i); nm = b[i:i+ln].decode(); i += ln
        vl, i = uleb(b, i); mods[nm] = b[i:i+vl]; i += vl
    (outdir / f"{name}_utils.mv").write_bytes(mods["utils"])
    r = subprocess.run(["/tmp/opencode/sui-cli/sui", "move", "disassemble", str(outdir / f"{name}_utils.mv")],
                       capture_output=True, text=True, timeout=60)
    txt = r.stdout
    idx = txt.find("get_contract_version")
    snippet = txt[idx:idx+120].replace("\n", " | ") if idx >= 0 else ("NO FUNCTION")
    mods_list = [(m["name"], [f["name"] for f in (m.get("functions") or {}).get("nodes") or []]) for m in (mp.get("modules") or {}).get("nodes") or []]
    swapfns = next((fns for nm2, fns in mods_list if nm2 == "swap"), [])
    print(name, "-> get_contract_version:", snippet)
    print("   swap has sync_pool:", "sync_pool" in swapfns, "| skim_pool:", "skim_pool" in swapfns,
          "| migrate_escrow_coins:", "migrate_escrow_coins" in swapfns,
          "| create_and_freeze_pool:", "create_and_freeze_pool" in swapfns)
