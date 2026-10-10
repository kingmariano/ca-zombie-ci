#!/usr/bin/env python3
"""Fetch /accounts/{addr}/verification for all candidates + extra addresses (keyless)."""
import json, os, time, urllib.request

BASE = "https://api.multiversx.com"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")

def get(path, retries=3, timeout=60):
    url = BASE + path
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                return {"__error__": str(e), "__path__": path}
            time.sleep(1.5 * (i + 1))

def main():
    addr_file = os.path.join(RAW, "verification_addresses.json")
    if os.path.exists(addr_file):
        addrs = json.load(open(addr_file))
    else:
        cands = json.load(open(os.path.join(RAW, "candidates.json")))
        addrs = {c["address"]: {"name": c["name"], "category": c["category"]} for c in cands["targets"]}
        addrs["erd1qqqqqqqqqqqqqpgqxwakt2g7u9atsnr03gqcgmhcv38pt7mkd94q6shuwt"] = {"name": "community_delegation", "category": "legacy_delegation"}
        addrs["erd1qqqqqqqqqqqqqpgq50dge6rrpcra4tp9hl57jl0893a4r2r72jpsk39rjj"] = {"name": "metabonding_api_legacy", "category": "legacy_metabonding"}
        json.dump(addrs, open(addr_file, "w"), indent=1)
    outdir = os.path.join(RAW, "verification")
    os.makedirs(outdir, exist_ok=True)
    summary = {}
    for addr, meta in addrs.items():
        outfile = os.path.join(outdir, addr + ".json")
        if os.path.exists(outfile):
            try:
                d = json.load(open(outfile))
            except Exception:
                pass
            else:
                pass
        d = get(f"/accounts/{addr}/verification")
        if isinstance(d, dict) and "__error__" not in d:
            json.dump(d, open(outfile, "w"))
        ok = isinstance(d, dict) and d.get("codeHash") and d.get("source")
        src = d.get("source") if isinstance(d, dict) else None
        files = list(src.get("source", {}).keys()) if isinstance(src, dict) and isinstance(src.get("source"), dict) else None
        summary[addr] = {"name": meta.get("name"), "verified": bool(ok), "files": files}
        print(f"{meta.get('name','?'):42s} verified={bool(ok)} files={files if files else '-'}", flush=True)
        time.sleep(0.15)
    json.dump(summary, open(os.path.join(RAW, "verification_summary.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
