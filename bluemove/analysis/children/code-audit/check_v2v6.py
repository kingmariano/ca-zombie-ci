#!/usr/bin/env python3
"""Disassemble swap module of v2..v6 and check inventory + store model."""
import json, sys, base64, subprocess, pathlib
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql

PKGS = {
    "v2":  "0xdc8437d021efc026249b796ce5375ce60433a5dd9c05cf6aee8668dc2191a8ad",
    "v3":  "0xdf87af8c63ce5991058fdd45fa4d79c9952f8191030a9737884afec79dab76cc",
    "v4":  "0xb574a776a50fb2f867ea1a35f37f3362a30aa2f6768cc72035c69d5624e5e3a4",
    "v5":  "0x941f5ee6d336545a2ae00ef763725ce826168bbc914d00ba95a87af076af0b7a",
    "v6":  "0xa00faab58ff6876dce096d5e0591200b84a14f4033319d27c48b781a37aa2ed7",
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
for name, pkg in PKGS.items():
    d = gql(q, {"addr": pkg})
    mp = ((d.get("object") or {}).get("asMovePackage")) or {}
    b = base64.b64decode(mp["moduleBcs"])
    n, i = uleb(b, 0)
    mods = {}
    for _ in range(n):
        ln, i = uleb(b, i); nm = b[i:i+ln].decode(); i += ln
        vl, i = uleb(b, i); mods[nm] = b[i:i+vl]; i += vl
    p = outdir / f"{name}_swap.mv"
    p.write_bytes(mods["swap"])
    r = subprocess.run(["/tmp/opencode/sui-cli/sui", "move", "disassemble", str(p)],
                       capture_output=True, text=True, timeout=60)
    txt = r.stdout
    if not txt:
        print(name, "DISASM FAIL", r.stderr[:200]); continue
    (outdir / f"{name}_swap.disasm").write_text(txt)
    fns = []
    for line in txt.splitlines():
        line = line.strip()
        if any(line.startswith(pre) for pre in ("entry public ", "public(friend) ", "public ")) and "(" in line and line.endswith("{"):
            fns.append(line.split("(")[0].replace("entry public ", "").replace("public(friend) ", "").replace("public ", ""))
    flags = {
        "assert_version_contract": "assert_version_contract" in txt,
        "EscownCoins": "EscownCoins" in txt,
        "EscrowCoinsV2": "EscrowCoinsV2" in txt,
        "struct Pool": "struct Pool" in txt,
        "reserve_x": "reserve_x" in txt,
        "k_last": "k_last" in txt,
        "migrate_contract_version": "migrate_contract_version" in txt,
    }
    print(name, pkg[:10], json.dumps(flags))
    print("   fns:", ",".join(fns)[:500])
