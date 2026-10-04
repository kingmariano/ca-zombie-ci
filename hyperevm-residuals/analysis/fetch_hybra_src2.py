#!/usr/bin/env python3
"""Fetch verified deployed sources for Hybra (HyperEVM chainid 999) into hybra_src2/.

Read-only. API key read from /home/heisenberg/CA/.env (never printed).
Saves raw Etherscan V2 JSONs and extracted .sol files.
"""
import json, os, re, sys, time, urllib.request, urllib.parse

ENV = "/home/heisenberg/CA/.env"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hybra_src2")
os.makedirs(OUT, exist_ok=True)
EXTRACT = os.path.join(OUT, "extracted")
os.makedirs(EXTRACT, exist_ok=True)

def get_api_key():
    with open(ENV) as f:
        for line in f:
            line = line.strip()
            if line.startswith("ETHERSCANV2_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("no ETHERSCANV2_API_KEY in .env")

KEY = get_api_key()

# name -> (address, note)
TARGETS = {
    "gaugemanager_proxy":   ("0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e", "GaugeManager EIP-1967 proxy"),
    "gaugemanager_impl":    ("0xcd5f4e4cf2dcd7d9d72ef997ebd5f57bc0443988", "GaugeManager implementation"),
    "voter_proxy":          ("0x5623f012d15eb828c12fe32e46d40adc2a9e4fa3", "Voter EIP-1967 proxy"),
    "voter_impl":           ("0xcd9599ff0b72d2cc5246b15bc6d6836581920576", "Voter implementation"),
    "votingescrow":         ("0xd7ed7792f71f3920dba01c544639fd546d87f4fd", "VotingEscrow (direct)"),
    "minter_proxy":         ("0xa8265e40e4cdf6db345861f4fcb75f9cc63e149b", "Minter EIP-1967 proxy"),
    "minter_impl":          ("0x8a89c7f32f0ed4d186eb73d458354fda68e01d2f", "Minter implementation"),
    "ghybr":                ("0x348b11cbb801fab12834e66691b7f25fe72b8aa5", "GrowthHYBR / gHYBR"),
    "clfactory":            ("0x32b9da73215255d50d84feb51540b75acc1324c2", "CLFactory"),
    "clpool_impl":          ("0xa421f7aada7d11eb6002bc53090fb8d5409552ab", "CLPool implementation"),
    "gauge_sample":         ("0x382e5db8ec64e8506879b94568b41d159d64577f", "GaugeCL sample (pool 0xc22fad66...)"),
    "gauge_impl_candidate": ("0x1c0ebc5cf683e20d427d08d9e0920b07f9abdd09", "GaugeCL implementation candidate"),
}

def fetch(addr):
    q = urllib.parse.urlencode({
        "chainid": "999", "module": "contract", "action": "getsourcecode",
        "address": addr, "apikey": KEY,
    })
    url = "https://api.etherscan.io/v2/api?" + q
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == 4:
                raise
            time.sleep(2 * (attempt + 1))

def extract(name, sc, cname, cfile):
    """Write source(s) for a contract. Returns (#files, format)."""
    wrote = 0
    if not sc:
        return 0, "none"
    s = sc
    if s.startswith("{{"):
        try:
            j = json.loads(s[1:-1])
        except Exception:
            try:
                j = json.loads(s)
            except Exception:
                # store raw
                p = os.path.join(EXTRACT, name)
                os.makedirs(p, exist_ok=True)
                with open(os.path.join(p, "raw_source.txt"), "w") as f:
                    f.write(s)
                return 0, "unparsed-json"
        d = os.path.join(EXTRACT, name)
        for path, body in (j.get("sources") or {}).items():
            content = body.get("content") if isinstance(body, dict) else None
            if content is None:
                continue
            fp = os.path.join(d, path)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, "w") as f:
                f.write(content)
            wrote += 1
        return wrote, "standard-json"
    else:
        d = os.path.join(EXTRACT, name)
        os.makedirs(d, exist_ok=True)
        fn = re.sub(r"[^A-Za-z0-9_.\-/]", "_", cfile or (cname or name) + ".sol")
        fp = os.path.join(d, fn)
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        with open(fp, "w") as f:
            f.write(s)
        return 1, "single-file"

summary = {}
for name, (addr, note) in TARGETS.items():
    try:
        d = fetch(addr)
    except Exception as e:
        print(f"{name}: FETCH-ERROR {e}")
        summary[name] = {"address": addr, "error": str(e)}
        continue
    with open(os.path.join(OUT, f"raw_{name}.json"), "w") as f:
        json.dump(d, f, indent=1)
    res = (d.get("result") or [{}])
    r = res[0] if isinstance(res, list) and res else {}
    sc = r.get("SourceCode") or ""
    nfiles, fmt = extract(name, sc, r.get("ContractName"), r.get("ContractFileName"))
    rec = {
        "address": addr, "note": note, "status": d.get("status"), "message": d.get("message"),
        "contract_name": r.get("ContractName"), "file": r.get("ContractFileName"),
        "compiler": r.get("CompilerVersion"), "optimizer": r.get("OptimizationUsed"),
        "runs": r.get("Runs"), "evm": r.get("EVMVersion"), "license": r.get("LicenseType"),
        "proxy": r.get("Proxy"), "implementation": r.get("Implementation"),
        "source_len": len(sc), "files_written": nfiles, "format": fmt, "abi_len": len(r.get("ABI") or ""),
    }
    summary[name] = rec
    print(f"{name}: {r.get('ContractName') or '(unverified)'} | src={len(sc)} | files={nfiles} ({fmt}) | compiler={r.get('CompilerVersion')} | proxy={r.get('Proxy')} impl={r.get('Implementation')}")

with open(os.path.join(OUT, "fetch_summary.json"), "w") as f:
    json.dump(summary, f, indent=1)
print("saved:", os.path.join(OUT, "fetch_summary.json"))
