#!/usr/bin/env python3
"""Extract multi-file verified sources and scan for suspicious modifications."""
import json, os, sys, re

def extract(addr, label):
    fn = f"raw/es_src_{addr}.json"
    j = json.load(open(fn))
    r = j["result"][0]
    src = r["SourceCode"]
    outdir = f"raw/src/{label}"
    os.makedirs(outdir, exist_ok=True)
    if src.startswith("{{"):
        # double-wrapped JSON
        src = src[1:-1] if src.endswith("}}") else src
        src = "{" + src[1:] if not src.startswith("{") else src
    try:
        obj = json.loads(src)
    except Exception as e:
        print(f"{label}: cannot parse SourceCode: {e}")
        open(f"{outdir}/_raw.txt","w").write(src)
        return None
    sources = obj.get("sources", {})
    paths = []
    for name, v in sources.items():
        p = os.path.join(outdir, name.replace("@"+"" if False else "", "").replace("/", "__"))
        content = v.get("content","")
        open(p,"w").write(content)
        paths.append(p)
    print(f"{label}: {len(paths)} files -> {outdir}")
    return paths

if __name__ == "__main__":
    for addr,label in [
        ("0xaa8cc9afe14f3a2b200ca25382e7c87cd883a527","AToken_impl"),
        ("0x0b1a51c5cbffc636d79a072b8aa5a763cec42ef2","VDT_impl"),
        ("0x06142ce7000d48d2aba20d64b896b98ac8e85d35","PoolConfigurator_impl"),
        ("0x41699c9ccdd70430e2c0349a58c6c6033820b633","Pool_impl"),
        ("0x97f91ca15ce342ef92b6ca9673f5d5b44528bfa1","ACLManager"),
    ]:
        extract(addr,label)
