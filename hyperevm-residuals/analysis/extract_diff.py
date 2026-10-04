#!/usr/bin/env python3
"""Extract Etherscan multi-file source JSON and diff files against the C4 repo."""
import json, os, re, sys, hashlib, subprocess

ANALYSIS = os.path.dirname(os.path.abspath(__file__))
C4 = "/tmp/opencode/hybra-c4"

def extract(src_json_path, outdir):
    d = json.load(open(src_json_path))
    r = d["result"][0]
    sc = r["SourceCode"]
    if sc.startswith("{{"):
        sc = sc[1:-1]
    obj = json.loads(sc)
    sources = obj.get("sources") or {}
    os.makedirs(outdir, exist_ok=True)
    written = []
    for path, v in sources.items():
        content = v.get("content")
        if content is None:
            continue
        p = os.path.join(outdir, path)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "w").write(content)
        written.append(path)
    # save settings too
    with open(os.path.join(outdir, "_settings.json"), "w") as f:
        json.dump({k: v for k, v in obj.items() if k != "sources"}, f, indent=1)
    return written, r

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]

if __name__ == "__main__":
    name = sys.argv[1]              # e.g. clfactory
    srcf = os.path.join(ANALYSIS, f"src_{name}.json")
    outdir = sys.argv[2] if len(sys.argv) > 2 else f"/tmp/opencode/deployed_{name}"
    written, r = extract(srcf, outdir)
    print(f"=== deployed {name}: {r.get('ContractName')} {r.get('CompilerVersion')} runs={r.get('Runs')} opt={r.get('OptimizationUsed')} evm={r.get('EVMVersion')} ===")
    for p in written:
        print("  ", p)
    # try to match against C4 repo
    for p in written:
        cand = None
        for prefix in ("cl/", "ve33/"):
            c = os.path.join(C4, prefix + p)
            if os.path.exists(c):
                cand = c
                break
        if cand is None:
            cand = os.path.join(C4, p)
        if os.path.exists(cand):
            s1, s2 = sha(os.path.join(outdir, p)), sha(cand)
            tag = "SAME" if s1 == s2 else "DIFF"
            print(f"  [{tag}] {p} deployed={s1} repo={s2} ({cand.replace(C4+'/','')})")
        else:
            # try basename match in repo
            base = os.path.basename(p)
            hits = subprocess.run(["find", C4, "-name", base, "-not", "-path", "*/lib/*"], capture_output=True, text=True).stdout.strip().split("\n")
            hits = [h for h in hits if h]
            print(f"  [NOPATH] {p} -> repo candidates: {hits}")
