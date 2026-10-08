#!/usr/bin/env python3
"""Extract Etherscan V2 sources (flattened or JSON-standard) into files."""
import json, os, sys, re

def main(srcjson, outdir):
    d = json.load(open(srcjson))
    r = d.get("result")
    if isinstance(r, list):
        r = r[0] if r else {}
    src = r.get("SourceCode", "")
    os.makedirs(outdir, exist_ok=True)
    if src.strip().startswith("{"):
        # could be {"language":..., "sources": {...}} or {"file.sol": {"content": ...}}
        try:
            j = json.loads(src)
        except Exception:
            # Etherscan sometimes wraps with {{ }}
            j = json.loads(src[1:-1])
        if "sources" in j:
            files = j["sources"]
        else:
            files = j
        n = 0
        for name, val in files.items():
            content = val["content"] if isinstance(val, dict) else val
            safe = name.replace("/", "__")
            open(os.path.join(outdir, safe), "w").write(content)
            n += 1
        print(f"extracted {n} files -> {outdir}")
    else:
        open(os.path.join(outdir, "flat.sol"), "w").write(src)
        print("flattened source written")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
