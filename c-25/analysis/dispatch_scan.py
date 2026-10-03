#!/usr/bin/env python3
"""Locate dispatch targets for given selectors and check bodies for token-transfer primitives."""
import sys, re, os

def load(path):
    c = open(path).read().strip()
    return bytes.fromhex(c[2:] if c.startswith("0x") else c)

def find_targets(b, sel):
    """Find PUSH2 targets near comparisons of the selector."""
    pat = bytes.fromhex("63" + sel)
    out = []
    for m in re.finditer(re.escape(pat), b):
        i = m.start()
        ctx = b[i:i+14]
        # look for PUSH2 xxxx + JUMPI within next 12 bytes
        for j in range(5, min(len(ctx) - 2, 13)):
            if 0x61 == ctx[j] and j + 3 < len(ctx) and ctx[j+3] == 0x57:
                out.append(int.from_bytes(ctx[j+1:j+3], "big"))
        if len(out) == 0:
            # maybe last in chain: fallthrough
            pass
    return out

def body(b, start, maxlen=0x250):
    end = min(len(b), start + maxlen)
    return b[start:end].hex()

def has(b, sel_hex):
    return sel_hex in b.hex()

if __name__ == "__main__":
    impls = {
        "impl_A_5142": ("./implA_5142.hex", ["e2a7c86f", "1770400e", "171a2517", "78a9f28b"]),
        "impl_D_c971": ("./implD_c971.hex", ["5b4a250f"]),
        "impl_B_1dfc": ("./implB_1dfc.hex", ["4d54cdb6","287b071b","f028e9be","87c96419","56ce180a","9f1ec78b","415565b0","8aa6539b"]),
        "impl_C_1be2": ("./implC_1be2.hex", ["f35b4733","77725df6","7a1eb1b9","5161b966","9a2967d2","0f3b31b2"]),
    }
    for name, (path, sels) in impls.items():
        if not os.path.exists(path):
            print(f"{name}: MISSING {path}")
            continue
        b = load(path)
        print(f"=== {name} size={len(b)} transferFrom={has(b,'23b872dd')} approve={has(b,'095ea7b3')}")
        for s in sels:
            t = find_targets(b, s)
            print(f"  0x{s} targets={[hex(x) for x in t]}")
