#!/usr/bin/env python3
"""Per-group resolved selector table -> raw/group_signatures.md"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"
sigs = json.loads((RAW / "selector_signatures.json").read_text())
raw = json.loads((RAW / "selectors_raw.json").read_text())

groups = {}
for r in raw:
    g = groups.setdefault(r["code_hash"], {"size": r["size"], "members": [], "dispatch": set(), "pre": r["has_5a494c53"], "preaddr": r["has_precompile_address_word"], "push4": None})
    g["members"].append(r["address"])
    g["dispatch"].update(r["dispatcher_selectors"])
    g["push4"] = r["push4_all"]

lines = ["# Allow-listed contracts: resolved selector tables", ""]
for kh, g in sorted(groups.items(), key=lambda kv: -kv[1]["size"]):
    lines.append(f"## {kh} size={g['size']} n={len(g['members'])} precompile_const={'Y' if g['pre'] else 'n'} precompile_addr_word={'Y' if g['preaddr'] else 'n'}")
    lines.append("- members: " + ", ".join(g["members"][:20]))
    lines.append("- dispatch selectors:")
    for s in sorted(g["dispatch"]):
        v = sigs.get(s) or ["<unresolved>"]
        lines.append(f"    {s}  {' | '.join(v)}")
    disp = set(g["dispatch"])
    others = sorted({p["sel"] for p in g["push4"]} - disp)
    lines.append(f"- other PUSH4 constants ({len(others)}): " + (" ".join(others[:40]) if others else "(none)"))
    lines.append("")
out = (RAW / "group_signatures.md")
out.write_text("\n".join(lines))
print("wrote", out, len(lines), "lines")

import re
SUS = re.compile(r"(call|exec|forward|delegate|multicall|batch|scilla|target|payload|prox)", re.I)
print("\n=== suspicious selectors across all groups ===")
for s, v in sorted(sigs.items()):
    for sig in v:
        if SUS.search(sig):
            print(f"{s} {sig}")
            break
