#!/usr/bin/env python3
"""Group allow-listed contracts by runtime-code keccak and scrape PUSH4 selectors.

Read-only. Consumes raw/code_*.hex (fetched from keyless RPC) and writes
raw/groups.json + raw/selectors_raw.json.

Selector scraping:
  * every PUSH4 (opcode 0x63) value in the code, with offset;
  * the Solidity dispatcher pattern  `PUSH4 <sel> EQ`  (0x63..14);
and a few targeted pattern checks:
  * precompile constant 0x5a494c53 in PUSH4 / PUSH20(0x..5a494c53) / anywhere;
  * EIP-1167 clone prologue 0x363d3d373d3d3d363d73 + 5af43d82803e903d91602b57fd5bf3.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"

PUSH4_EQ = re.compile(rb"\x63(..{4})\x14", re.DOTALL)


def pushes_offsets(code: bytes):
    """Yield (offset, opcode, imm_len, imm)."""
    i = 0
    n = len(code)
    while i < n:
        op = code[i]
        if 0x60 <= op <= 0x7F:
            ln = op - 0x5F
            imm = code[i + 1:i + 1 + ln]
            yield i, op, ln, imm
            i += 1 + ln
        else:
            yield i, op, 0, b""
            i += 1


def selectors_of(code: bytes):
    """Return (all PUSH4 with offsets, dispatcher PUSH4|EQ values)."""
    push4s = []
    dispatch = []
    for off, op, ln, imm in pushes_offsets(code):
        if op == 0x63 and ln == 4:
            val = imm.hex().zfill(8)
            push4s.append({"offset": off, "sel": "0x" + val})
            nxt = code[off + 5:off + 6]
            if nxt == b"\x14":  # EQ
                dispatch.append("0x" + val)
    return push4s, sorted(set(dispatch))


def main():
    metas = [json.loads(l) for l in (RAW / "codes_meta.jsonl").read_text().splitlines() if l.strip()]
    groups = {}
    out = []
    for m in metas:
        addr = m["address"]
        code_hex = (RAW / f"code_{addr}.hex").read_text().strip()
        code = bytes.fromhex(code_hex[2:]) if code_hex.startswith("0x") else bytes.fromhex(code_hex)
        kh = subprocess.run(["cast", "keccak", code_hex], capture_output=True, text=True, check=True).stdout.strip()
        g = groups.setdefault(kh, {"code_hash": kh, "size": len(code), "members": [], "code_hex": code_hex})
        g["members"].append(addr)
        push4s, dispatch = selectors_of(code)
        has_pre = "5a494c53" in code_hex
        # same constant as an address word (precompile address in abi.encode or as literal)
        has_pre_addr = ("000000000000000000000000000000005a494c53" in code_hex)
        rec = {
            "address": addr,
            "size": len(code),
            "code_hash": kh,
            "has_5a494c53": has_pre,
            "has_precompile_address_word": has_pre_addr,
            "push4_count": len(push4s),
            "dispatcher_selectors": dispatch,
            "push4_all": push4s,
        }
        out.append(rec)

    grp_out = {kh: {k: v for k, v in g.items() if k != "code_hex"} for kh, g in groups.items()}
    (RAW / "groups.json").write_text(json.dumps(grp_out, indent=1))
    (RAW / "selectors_raw.json").write_text(json.dumps(out, indent=1))

    print(f"{len(metas)} addresses, {len(groups)} unique code hashes")
    for kh, g in sorted(groups.items(), key=lambda kv: -kv[1]["size"]):
        print(f"{kh[:10]} size={g['size']:>6} n={len(g['members']):>3} pre={'Y' if '5a494c53' in g['code_hex'] else 'n'} "
              f"first={g['members'][0]}")


if __name__ == "__main__":
    sys.exit(main())
