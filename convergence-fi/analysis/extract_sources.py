#!/usr/bin/env python3
"""Extract Etherscan multi-file sources into analysis/src/<name>/ trees."""
import json, os, re, sys

def load(a):
    fs = [f for f in os.listdir("sources") if f.lower().startswith(a.lower())]
    return json.load(open(f"sources/{fs[0]}"))["result"][0]

def extract(a, label):
    r = load(a)
    sc = r.get("SourceCode") or ""
    outdir = f"src/{label}"
    os.makedirs(outdir, exist_ok=True)
    meta = {"address": a, "name": r.get("ContractName"), "proxy": r.get("Proxy"),
            "impl": r.get("Implementation"), "compiler": r.get("CompilerVersion"),
            "abi": json.loads(r.get("ABI") or "[]")}
    json.dump(meta, open(f"{outdir}/_meta.json","w"), indent=1)
    if sc.startswith("{{"):
        sc = sc[1:-1]
        try:
            d = json.loads(sc)
            for fname, content in d.get("sources", {}).items():
                p = os.path.join(outdir, fname)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                open(p, "w").write(content["content"])
            print(f"{label}: extracted {len(d.get('sources',{}))} files")
        except Exception as e:
            print(f"{label}: parse fail {e}")
            open(f"{outdir}/source.txt","w").write(sc)
    else:
        open(f"{outdir}/source.txt","w").write(sc)
        print(f"{label}: single file ({len(sc)} bytes)")

if __name__ == "__main__":
    jobs = [
        ("0xbdbddc4bf67e9bc02706e4ce53bc14d6ce3038f1","tower_impl"),
        ("0xa3a8cda21f50b6737385e46fc9495a9998b05ff0","viewer"),
        ("0x2717c6a0029d63e90eb12283507e06bf77a9754d","cvgSdt_impl_vyper"),
        ("0xdba75359b323cc61e02975760d89178f79dcf799","sdt_staking_position_service"),
        ("0xe789b78f66886d3ec9e393fb495ea726c5b371af","stkcvg_impl"),
        ("0x33dbaa43aabd534664aae56490c3b0aa26f06bac","cvgcvx_impl"),
        ("0x97effb790f2fbb701d88f89db4521348a2b77be8","cvg_token"),
        ("0xb0afc8363b8f36e0cce5d54251e20720ffaeaee7","tower_proxy"),
    ]
    for a,label in jobs:
        try:
            extract(a,label)
        except Exception as e:
            print(f"{label}: FAIL {e}")
