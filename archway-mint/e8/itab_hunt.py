#!/usr/bin/env python3
"""itab_hunt.py — locate `go:itab.Context,context.Context` in archwayd.

The itab for (github.com/cosmos/cosmos-sdk/types.Context -> context.Context) is a static
structure whose fun[] array holds the four interface-method wrappers in interface order:

    Deadline < Done < Err < Value

matching the pclntab addresses found in archwayd_functions.txt:
    0x109bbe0, 0x109bc20, 0x109bc60, 0x109d9a0

The itab layout (Go 1.21+): { inter *interfacetype (8), _type *_type (8), hash u32 (4),
pad (4), fun [4]uintptr } so fun[0] sits at itab_base + 0x18. A file-offset match of the
four-pointer pattern therefore gives the itab address directly.

Usage: itab_hunt.py /tmp/archwayd [outfile]
"""
import struct
import sys

FUN = [0x109BBE0, 0x109BC20, 0x109BC60, 0x109D9A0]


def file_off_to_vaddr(data, off):
    """Map a file offset to a virtual address via the ELF program headers."""
    if data[:4] != b"\x7fELF":
        return None
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]
    for j in range(e_phnum):
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from(
            "<IIQQQQQQ", data, e_phoff + j * e_phentsize)
        if p_type == 1 and p_offset <= off < p_offset + p_filesz:
            return p_vaddr + (off - p_offset)
    return None


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/archwayd"
    out = sys.argv[2] if len(sys.argv) > 2 else None
    data = open(path, "rb").read()
    pat = b"".join(struct.pack("<Q", a) for a in FUN)
    print(f"scanning {path} ({len(data)} bytes) for the 4-method itab pattern")
    lines = []
    i = data.find(pat)
    n = 0
    while i >= 0:
        n += 1
        va_fun0 = file_off_to_vaddr(data, i)
        if va_fun0 is not None:
            itab = va_fun0 - 0x18
            # peek at the inter and _type pointers preceding fun[0]
            inter = struct.unpack_from("<Q", data, i - 0x18)[0]
            typ = struct.unpack_from("<Q", data, i - 0x10)[0]
            hashv = struct.unpack_from("<I", data, i - 0x8)[0]
            line = (f"itab @0x{itab:x} (fun0 vaddr 0x{va_fun0:x}) inter=0x{inter:x} "
                    f"type=0x{typ:x} hash=0x{hashv:x}")
        else:
            line = f"pattern at file offset 0x{i:x} (vaddr unavailable)"
        print(line)
        lines.append(line)
        i = data.find(pat, i + 1)
    # also report single-method pointer hit counts (sanity)
    for a in FUN:
        p = struct.pack("<Q", a)
        cnt = data.count(p)
        print(f"  single ref 0x{a:x}: {cnt} occurrences")
    print(f"total itab candidates: {n}")
    if out:
        open(out, "w").write("\n".join(lines) + "\n")
        print("written", out)


if __name__ == "__main__":
    main()
