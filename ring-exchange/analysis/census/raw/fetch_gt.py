#!/usr/bin/env python3
"""Robust GeckoTerminal fetcher with retry/backoff. Read-only. Saves raw JSON."""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
GT = "https://api.geckoterminal.com/api/v2"
UA = "research/1.0 (read-only census)"

TOK = {
 "fwWHYPE": "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf",
 "fwUETH":  "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397",
 "fwUSDC":  "0xd2646b9B02859416D8cBc759F85f0676f6E19974",
 "fwUSDT0": "0x7576dd9a2775bFd789616d9eA7A2af21d06782D0",
 "fwUSDH":  "0x09D21E89EF332347eb3E1E496f1265a600e364C1",
}
PAIR = {
 "p1_fwUETH_fwWHYPE": "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a",
 "p2_fwUSDH_fwUSDC":  "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3",
 "p3_fwUSDH_fwUSDT0": "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150",
 "p4_fwUSDT0_fwUSDC": "0x8868a630dD13A954D3f8B186508EF6c733BE959F",
 "p5_fwUSDT0_fwWHYPE":"0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17",
}

def fetch(url, out, tries=6):
    path = os.path.join(HERE, out)
    if os.path.exists(path):
        try:
            d = json.load(open(path))
            if not (isinstance(d, dict) and d.get("status")):
                print("skip (exists ok):", out); return
        except Exception:
            pass
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read()
            d = json.loads(body)
            if isinstance(d, dict) and isinstance(d.get("status"), dict):
                wait = 15 * (i + 1)
                print(f"429 on {out}, wait {wait}s"); time.sleep(wait); continue
            open(path, "wb").write(body)
            print("ok:", out, len(body), "bytes")
            return
        except Exception as e:
            print("err", out, e); time.sleep(8 * (i + 1))
    print("FAILED:", out)

# token pools + info
for name, addr in TOK.items():
    fetch(f"{GT}/networks/hyperevm/tokens/{addr}/pools?page=1", f"gt_{name}_pools_p1.json")
    time.sleep(6)
    fetch(f"{GT}/networks/hyperevm/tokens/{addr}/pools?page=2", f"gt_{name}_pools_p2.json")
    time.sleep(6)
    fetch(f"{GT}/networks/hyperevm/tokens/{addr}/info", f"gt_{name}_info.json")
    time.sleep(6)

# known pools
for name, addr in PAIR.items():
    fetch(f"{GT}/networks/hyperevm/pools/{addr}", f"gt_pool_{name}.json")
    time.sleep(6)

# search by address + name
for name, addr in TOK.items():
    fetch(f"{GT}/search/pools?query={addr}&network=hyperevm", f"gt_search_{name}.json")
    time.sleep(6)

fetch(f"{GT}/search/pools?query=fw&network=hyperevm", "gt_search_name_fw.json")
time.sleep(6)
fetch(f"{GT}/networks/hyperevm/dexes", "gt_hyperevm_dexes.json")
print("DONE")
