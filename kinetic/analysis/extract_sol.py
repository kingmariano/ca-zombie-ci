#!/usr/bin/env python3
"""Extract .sol sources from the Blockscout v2 JSON dumps into analysis/sol/."""
import json, os, re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "src")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "sol")
os.makedirs(OUT, exist_ok=True)

FILES = {
    "0x15f69897e6aebe0463401345543c26d1fd994abb.json": "Unitroller_proxy1",
    "0x8041680fb73e1fe5f851e76233dcdfa0f2d2d7c8.json": "Unitroller_proxy2",
    "0x35aff580e53d9834a3a0e21a50f97b942aba8866.json": "ComptrollerV2_impl1",
    "0x2e7c09c84dbb4d08e103bd00199d2d9424c9734a.json": "ComptrollerV2_impl2",
    "0xf114620fff7cae11be8a352e6dee25386547a333.json": "CErc20Delegate",
    "0x31e7fa682312807d27d94c91563f284bf6281f02.json": "CNativeDelegate",
    "0x61f77ef0064736ffa68c31d960e55baf67f79a4b.json": "ProtocolFTSOV3Oracle",
}

for fn, label in FILES.items():
    p = os.path.join(SRC, fn)
    d = json.load(open(p))
    sc = d.get("source_code") or ""
    name = (d.get("name") or label).replace(" ", "_")
    if sc.startswith("{"):
        # standard json
        try:
            j = json.loads(sc)
            sources = j.get("sources", {})
            n = 0
            for path, obj in sources.items():
                base = os.path.basename(path)
                with open(os.path.join(OUT, f"{label}__{base}"), "w") as f:
                    f.write(obj.get("content", ""))
                n += 1
            print(fn, "->", label, "std-json", n, "files")
        except Exception as e:
            print(fn, "std-json parse fail", e)
    else:
        with open(os.path.join(OUT, f"{label}__{name}.sol"), "w") as f:
            f.write(sc)
        print(fn, "->", os.path.join(OUT, f"{label}__{name}.sol"), len(sc), "bytes")
    # also dump additional sources (imports)
    for k in ("additional_sources", "additional_sources_abi"):
        pass
    add = d.get("additional_sources") or []
    for a in add:
        ap = a.get("file_path") or a.get("filename") or "unknown"
        an = os.path.basename(ap)
        with open(os.path.join(OUT, f"{label}__{an}"), "w") as f:
            f.write(a.get("source_code", ""))
