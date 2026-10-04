#!/usr/bin/env python3
"""Extract PUSH4 selectors from deployed bytecode and compare with repo function selectors."""
import json, re, subprocess, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h

def selectors_in_bytecode(code_hex):
    b = bytes.fromhex(code_hex[2:]) if code_hex.startswith("0x") else bytes.fromhex(code_hex)
    sels = set()
    i = 0
    while i < len(b):
        op = b[i]
        if 0x60 <= op <= 0x7f:  # PUSH1..PUSH32
            n = op - 0x5f
            if op == 0x63 and i + 4 < len(b):  # PUSH4
                sels.add(b[i+1:i+5].hex())
            i += 1 + n
        else:
            i += 1
    return sels

def sig_sel(sig):
    out = subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()
    return out[2:] if out.startswith("0x") else out

def repo_sigs(path):
    src = open(path).read()
    sigs = set()
    # function name(args)  (rough, excludes internal/private? we keep all, mark separately)
    for m in re.finditer(r'function\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)', src):
        name, args = m.group(1), m.group(2)
        args = re.sub(r'\s+', ' ', args.strip())
        args = re.sub(r'\b(memory|calldata|storage|payable)\b', '', args)
        args = re.sub(r'\s+', ' ', args)
        args = args.replace(' ,', ',').replace(', ', ',').strip()
        if not args:
            sig = f"{name}()"
        else:
            parts = []
            for a in args.split(','):
                toks = a.strip().split(' ')
                if not toks or toks[0] in ('', 'uint256[]', 'address[]'):
                    parts = None
                    break
                parts.append(toks[0])
            if parts is None:
                continue
            sig = f"{name}({','.join(parts)})"
        try:
            sigs.add((sig, sig_sel(sig)))
        except Exception:
            pass
    return sigs

if __name__ == "__main__":
    addr = sys.argv[1]
    repofile = sys.argv[2]
    code = h.get_code(addr)
    print("codesize", len(code)//2 - 1, "addr", addr)
    live = selectors_in_bytecode(code)
    rep = repo_sigs(repofile)
    repo_by_sel = {s: sig for sig, s in rep}
    found = sorted([(repo_by_sel[s], s) for s in live if s in repo_by_sel])
    missing = sorted([(sig, s) for sig, s in rep if s not in live])
    unknown = sorted([s for s in live if s not in repo_by_sel])
    print(f"== repo functions found on-chain ({len(found)}):")
    for sig, s in found: print("  ", sig)
    print(f"== repo functions NOT found ({len(missing)}):")
    for sig, s in missing: print("  ", sig)
    print(f"== on-chain selectors not in repo ({len(unknown)}):")
    print("  ", " ".join(unknown))
    json.dump({"found": [f[0] for f in found], "missing": [m[0] for m in missing], "unknown": unknown},
              open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gm_selectors.json"), "w"), indent=1)
