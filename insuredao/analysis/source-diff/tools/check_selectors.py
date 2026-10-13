#!/usr/bin/env python3
"""Generic selector-vs-bytecode check for a deployed contract."""
import json, subprocess, re, sys

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()[2:].lower()

def abi_sigs(meta_path):
    d = json.load(open(meta_path))
    abi = json.loads(d["ABI"])
    out = {}
    for e in abi:
        if e.get("type") == "function":
            ins = ",".join(i["type"] for i in e.get("inputs", []))
            sig = f"{e['name']}({ins})"
            out[sel(sig)] = sig
    return out

def find_dispatch(bc, s):
    if ('63' + s + '14') in bc: return 'PUSH4'
    if s.startswith('00') and ('62' + s[2:] + '14') in bc: return 'PUSH3'
    if s.startswith('0000') and ('61' + s[4:] + '14') in bc: return 'PUSH2'
    # also direct presence (shouldn't happen for dispatcher, keep as fallback signal)
    if s in bc: return 'RAW'
    return None

def main(name, meta, bytecode_hex):
    sels = abi_sigs(meta)
    bc = open(bytecode_hex).read().strip().lstrip('0x').lower()
    missing = []
    for s, sig in sels.items():
        if not find_dispatch(bc, s):
            missing.append((s, sig))
    disp4 = set(re.findall(r"63([0-9a-f]{8})14", bc))
    extra = sorted(h for h in disp4 if h not in sels)
    print(json.dumps({
        "contract": name,
        "abi_functions": len(sels),
        "dispatched": len(sels) - len(missing),
        "abi_selector_missing_from_bytecode": missing,
        "bytecode_push4_selectors_not_in_abi": extra,
    }, indent=1))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
