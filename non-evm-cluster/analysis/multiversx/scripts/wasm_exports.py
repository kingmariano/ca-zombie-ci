#!/usr/bin/env python3
"""Extract exported function names from WASM hex code stored in candidate_balances.json
(and community delegation account dump). Pure-python minimal parser (export section).
Outputs raw/wasm_exports.json and prints a table.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")

def leb128(data, off):
    res = 0; shift = 0
    while True:
        b = data[off]; off += 1
        res |= (b & 0x7f) << shift
        if not (b & 0x80): break
        shift += 7
    return res, off

def parse_exports(code_hex):
    data = bytes.fromhex(code_hex) if isinstance(code_hex, str) else code_hex
    if data[:4] != b"\x00asm":
        return None, "not wasm"
    off = 8
    exports = []
    while off < len(data):
        sid = data[off]; off += 1
        size, off = leb128(data, off)
        sec_end = off + size
        if sid == 7:  # export section
            n, p = leb128(data, off)
            for _ in range(n):
                ln, p = leb128(data, p)
                name = data[p:p+ln].decode("utf-8", "replace"); p += ln
                kind = data[p]; p += 1
                idx, p = leb128(data, p)
                exports.append({"name": name, "kind": ["func","table","mem","global"][kind] if kind < 4 else f"k{kind}", "idx": idx})
            break
        off = sec_end
    funcs = sorted(e["name"] for e in exports if e["kind"] == "func")
    return funcs, None

def main():
    out = {}
    bal = json.load(open(os.path.join(RAW, "candidate_balances.json")))
    for addr, rec in bal.items():
        code = rec["account"].get("code")
        if code:
            funcs, err = parse_exports(code)
            out[addr] = {"name": rec["name"], "category": rec["category"], "functions": funcs or [], "error": err}
    # community delegation extra
    cd = json.load(open(os.path.join(RAW, "community_delegation_account.json")))
    if cd.get("code"):
        funcs, err = parse_exports(cd["code"])
        out[cd["address"]] = {"name": "community_delegation", "category": "legacy_delegation", "functions": funcs or [], "error": err}
    json.dump(out, open(os.path.join(RAW, "wasm_exports.json"), "w"), indent=1)
    # print key targets
    interesting = ["proxy_dex_v1_legacy","metabonding_staking_legacy","distribution_legacy","locked_asset_factory_legacy",
                   "simple_lock_legacy_0","simple_lock_legacy_1","simple_lock_legacy_2","community_delegation",
                   "farm_v1.2_2","farm_v1.3_lockedRewards_2","farm_v2_deprecated_0","price_discovery_0","farm_v1.2_0"]
    for addr, rec in out.items():
        if rec["name"] in interesting:
            print(f"== {rec['name']} ({addr[:20]}...) ==")
            print("   funcs:", ", ".join(rec["functions"]))
    print("\nwrote raw/wasm_exports.json", "with", len(out), "contracts")

if __name__ == "__main__":
    main()
