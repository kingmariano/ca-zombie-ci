#!/usr/bin/env python3
"""Extract a `case 0xSELECTOR { ... }` block from heimdall yul output."""
import sys, re

def extract(path, selector):
    data = open(path).read()
    idx = data.find("case " + selector)
    if idx == -1:
        print("SELECTOR NOT FOUND")
        return
    # find opening brace after case
    i = data.find("{", idx)
    depth = 0
    start = i
    while i < len(data):
        c = data[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    print(data[idx:i+1])

if __name__ == "__main__":
    extract(sys.argv[1], sys.argv[2])
