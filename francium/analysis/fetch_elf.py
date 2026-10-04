#!/usr/bin/env python3
"""Fetch Francium program ELFs (read-only) from ProgramData accounts and extract strings."""
import json, base64, sys, os, subprocess, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import rpc_call

OUT = os.path.dirname(os.path.abspath(__file__))

PROGS = {
    "lending": ("FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj", "E6dUGy62mYgGDZiLzpKsgWsnaMLQ3cwyvMLTBWzT3oV5"),
    "reward": ("3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6", "9kfc7ZBxcBKo9FVvXcrUw8vsD6qNLEFZ4XLQSkB6hDcQ"),
    "lyfRaydium": ("2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N", "BnNbkVTyvN5cgUS2bepK9pdN35bzScBNnwWwGhzdtVnk"),
    "lyfOrca": ("DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP", "GLBmZWvvRB9qCX4QVe1iyydTxo25Zg1T9DMZvmk1H5jG"),
}

def main():
    for name, (prog, pdata) in PROGS.items():
        path = os.path.join(OUT, f"elf_{name}.bin")
        if not os.path.exists(path):
            info = rpc_call("getAccountInfo", [pdata, {"encoding": "base64"}])
            raw = base64.b64decode(info["value"]["data"][0])
            # ProgramData: 4 state + 32 authority + 8 slot + elf
            elf = raw[44:]
            open(path, "wb").write(elf)
            print(f"{name}: programdata {len(raw)} bytes, elf {len(elf)} bytes, magic={elf[:4]}")
        # strings
        try:
            out = subprocess.run(["strings", "-n", "6", path], capture_output=True, text=True).stdout
            open(os.path.join(OUT, f"strings_{name}.txt"), "w").write(out)
            print(f"  strings: {len(out.splitlines())}")
        except Exception as e:
            print("  strings failed", e)

if __name__ == "__main__":
    main()
