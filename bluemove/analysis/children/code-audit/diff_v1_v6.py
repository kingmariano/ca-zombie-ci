#!/usr/bin/env python3
"""Function-level normalized diff of v1(pkg) vs v2..v6 swap modules (CLI disasm)."""
import re, pathlib, subprocess

base = pathlib.Path("/home/heisenberg/CA/bluemove/analysis/children/code-audit/modules")
# extract v1 via CLI for consistent formatting
import json, sys, base64
sys.path.insert(0, "/home/heisenberg/CA/bluemove/analysis")
from sui import gql
q = """query($addr: SuiAddress!) { object(address: $addr) { asMovePackage { moduleBcs } } }"""
def uleb(b, i):
    x = 0; s = 0
    while True:
        c = b[i]; i += 1
        x |= (c & 0x7f) << s
        if not (c & 0x80): break
        s += 7
    return x, i
d = gql(q, {"addr": "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"})
b = base64.b64decode(((d["object"]["asMovePackage"]) or {})["moduleBcs"])
n, i = uleb(b, 0)
mods = {}
for _ in range(n):
    ln, i = uleb(b, i); nm = b[i:i+ln].decode(); i += ln
    vl, i = uleb(b, i); mods[nm] = b[i:i+vl]; i += vl
p = base / "v1_swap.mv"; p.write_bytes(mods["swap"])
r = subprocess.run(["/tmp/opencode/sui-cli/sui", "move", "disassemble", str(p)], capture_output=True, text=True, timeout=60)
(base / "v1_swap.disasm").write_text(r.stdout)

def funcs(txt):
    out = {}
    lines = txt.splitlines()
    cur = None
    for line in lines:
        m = re.match(r"^\s*(?:entry public |public\(friend\) |public |entry )?([a-z_][A-Za-z0-9_]*)(<[^>]*>)?\(", line)
        if m and line.rstrip().endswith("{"):
            cur = m.group(1); out[cur] = []
        elif cur:
            out[cur].append(line)
            if line.strip() == "}":
                cur = None
    return out

ref = funcs((base / "v1_swap.disasm").read_text())
vers = {}
for v in ["v2", "v3", "v4", "v5", "v6"]:
    vers[v] = funcs((base / f"{v}_swap.disasm").read_text())

keys = ["initial_mint", "mint", "burn", "swap", "add_liquidity_direct", "update", "mint_fee", "withdraw_fee_", "withdraw_fee_direct"]
def norm(body):
    # strip offsets and line numbers, normalize operand indexes? keep names
    out = []
    for l in body:
        l = re.sub(r"^\s*\d+:\s*", "", l).strip()
        out.append(l)
    return out

for v in vers:
    print(f"########## {v} vs v1 ##########")
    for k in keys:
        a = ref.get(k); b2 = vers[v].get(k)
        if a is None and b2 is None: continue
        if a is None or b2 is None:
            print(f"  {k}: only in {'v1' if b2 is None else v}")
            continue
        na, nb = norm(a), norm(b2)
        if na == nb:
            print(f"  {k}: IDENTICAL")
        else:
            import difflib
            diff = list(difflib.unified_diff(na, nb, lineterm="", n=0))
            print(f"  {k}: DIFF ({len([d for d in diff if d.startswith(('+','-')) and not d.startswith(('+++','---'))])} changed lines)")
            for d in diff[2:12]:
                print("     ", d)
