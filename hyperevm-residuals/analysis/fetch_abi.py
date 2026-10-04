#!/usr/bin/env python3
"""Fetch verified source/ABI from Etherscan V2 (chainid overridable) for a list of addresses.
Writes analysis/abis/<addr>.json  (raw) and analysis/abis/<addr>.abi.json (ABI array).
Never prints API key. Read-only network access."""
import json, os, re, sys, urllib.request, urllib.parse

CHAIN = os.environ.get("CHAINID", "999")
ROOT = "/home/heisenberg/CA"
OUT = "/home/heisenberg/CA/hyperevm-residuals/analysis/abis"
os.makedirs(OUT, exist_ok=True)

def api_key():
    txt = open(os.path.join(ROOT, ".env")).read()
    m = re.search(r"^ETHERSCANV2_API_KEY=(.*)$", txt, re.M)
    if not m:
        raise SystemExit("no key")
    return m.group(1).strip().strip('"').strip("'")

KEY = api_key()

def get(params):
    params = dict(params)
    params["chainid"] = CHAIN
    params["apikey"] = KEY
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read())

def fetch(addr):
    addr = addr.lower()
    raw = get({"module": "contract", "action": "getsourcecode", "address": addr})
    try:
        json.dump(raw, open(f"{OUT}/{addr}.json", "w"))
    except Exception:
        pass
    res = (raw.get("result") or [{}])[0]
    abi = None
    if raw.get("status") == "1" and res.get("ABI") and res.get("ABI") not in ("Contract source code not verified",):
        try:
            abi = json.loads(res["ABI"])
        except Exception:
            pass
    if abi:
        json.dump(abi, open(f"{OUT}/{addr}.abi.json", "w"), indent=1)
    return {
        "address": addr,
        "name": res.get("ContractName", ""),
        "verified": bool(abi),
        "proxy": res.get("Proxy"),
        "impl": res.get("Implementation"),
        "compiler": res.get("CompilerVersion"),
        "source_len": len(res.get("SourceCode") or ""),
        "abi_len": len(abi or []),
    }

if __name__ == "__main__":
    out = []
    for a in sys.argv[1:]:
        try:
            out.append(fetch(a))
        except Exception as e:
            out.append({"address": a, "error": str(e)})
    print(json.dumps(out, indent=1))
