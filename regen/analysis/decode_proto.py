#!/usr/bin/env python3
"""Decode protobuf wire format; print fields with nested messages. Robust version."""
import base64, json, sys, struct

def read_varint(b, i):
    shift = 0; val = 0
    while True:
        x = b[i]; i += 1
        val |= (x & 0x7f) << shift
        if not (x & 0x80): break
        shift += 7
    return val, i

def parse(b):
    out = []
    i = 0
    while i < len(b):
        tag, i = read_varint(b, i)
        field, wire = tag >> 3, tag & 7
        if wire == 0:
            v, i = read_varint(b, i); out.append((field, "varint", v))
        elif wire == 2:
            ln, i = read_varint(b, i); out.append((field, "bytes", b[i:i+ln])); i += ln
        elif wire == 5:
            out.append((field, "fixed32", struct.unpack("<I", b[i:i+4])[0])); i += 4
        elif wire == 1:
            out.append((field, "fixed64", struct.unpack("<Q", b[i:i+8])[0])); i += 8
        else:
            out.append((field, f"wire{wire}", None)); break
    return out

def show(fields, indent=0):
    pad = "  " * indent
    for name, typ, v in fields:
        if typ == "bytes":
            try:
                s = v.decode("utf-8")
                printable = len(s) > 0 and all(32 <= ord(c) < 127 for c in s)
            except Exception:
                printable = False
            if printable:
                print(f"{pad}{name}: str({s!r})")
            else:
                print(f"{pad}{name}: bytes[{len(v)}] hex={v.hex()[:100]}")
                try:
                    sub = parse(v)
                    if sub:
                        show(sub, indent + 1)
                except Exception as e:
                    print(f"{pad}  (nested parse failed: {e})")
        else:
            print(f"{pad}{name}: {typ} {v}")

raw = json.load(open(sys.argv[1]))["result"]["response"]["value"]
b = base64.b64decode(raw)
print(f"total bytes: {len(b)}")
show(parse(b))
