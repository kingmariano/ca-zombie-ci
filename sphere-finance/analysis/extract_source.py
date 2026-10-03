#!/usr/bin/env python3
"""Extract verified source from an Etherscan getsourcecode JSON into a folder."""
import json, os, sys, re

src = sys.argv[1]
outdir = sys.argv[2]
r = json.load(open(src))
code = r.get("SourceCode", "")
os.makedirs(outdir, exist_ok=True)
if code.startswith("{{"):
    # double-braced standard-json
    obj = json.loads(code[1:-1])
    for name, item in obj.get("sources", {}).items():
        path = os.path.join(outdir, name.replace("/", "_"))
        with open(path, "w") as f:
            f.write(item.get("content", ""))
        print(path)
elif code.startswith("{"):
    try:
        obj = json.loads(code)
        if "sources" in obj:
            for name, item in obj["sources"].items():
                path = os.path.join(outdir, name.replace("/", "_"))
                with open(path, "w") as f:
                    f.write(item.get("content", ""))
                print(path)
        else:
            path = os.path.join(outdir, "flattened.sol")
            open(path, "w").write(code)
            print(path)
    except Exception:
        path = os.path.join(outdir, "flattened.sol")
        open(path, "w").write(code)
        print(path)
else:
    path = os.path.join(outdir, "flattened.sol")
    open(path, "w").write(code)
    print(path)
print("ContractName:", r.get("ContractName"))
