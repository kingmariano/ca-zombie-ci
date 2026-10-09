#!/usr/bin/env python3
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
"""Sweep every module currently enabled by any Safe (from the GoldRush census) for the
Makina/DFS-family fingerprint, then verify live state for hits."""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

def _env(name):
    v = os.environ.get(name)
    if v:
        v = v.strip().strip('"').strip("'")
        if v:
            return v
    try:
        for line in open("/home/heisenberg/CA/.env"):
            if line.startswith(name + "="):
                return line.strip().split("=", 1)[1].strip('"').strip("'")
    except FileNotFoundError:
        pass
    return None

RPC = _env("NODEREAL_ETH_RPC_URL") or _env("FORK_RPC_URL") or _env("RPC_URL")

def rpc_batch(calls):
    body = json.dumps([{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.load(r)
            by = {}
            for item in out:
                by[item["id"]] = item
            return [by.get(i) for i in range(len(calls))]
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(2)

def code_of(mods):
    import time as _t
    deadline = _t.time() + 12 * 60
    res = {}
    CH = 40
    chunks = [mods[i:i + CH] for i in range(0, len(mods), CH)]
    def work(ch):
        if _t.time() > deadline:
            return [(m, None) for m in ch]
        try:
            calls = [("eth_getCode", [m, "latest"]) for m in ch]
            out = rpc_batch(calls)
            return list(zip(ch, out))
        except Exception as e:
            print("chunk failed:", type(e).__name__, flush=True)
            return [(m, None) for m in ch]
    with ThreadPoolExecutor(max_workers=4) as ex:
        for pairs in ex.map(work, chunks):
            for m, item in pairs:
                res[m] = (item or {}).get("result", "0x")
    return res

def main():
    cur = json.load(open("census_current_set.json"))
    mods = sorted({c["module"] for c in cur})
    print("unique modules:", len(mods))
    codes = code_of(mods)
    print("codes fetched")
    hits = []
    for m in mods:
        c = codes.get(m, "0x")
        if not c or c == "0x":
            continue
        fam_big = ("5229073f" in c) and ("de792d5f" in c)
        fam_beacon = "a3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50" in c
        fam_minproxy = c.startswith("0x363d3d373d3d3d363d73") and "be4c422be989ff60e744e9f7ad05af43d82803e9" in c
        if fam_big or fam_beacon or fam_minproxy:
            kind = "big" if fam_big else ("beacon-proxy" if fam_beacon else "minimal-proxy-MakinaX")
            hits.append({"module": m, "kind": kind, "safes": [x["safe"] for x in cur if x["module"] == m]})
    print("family-fingerprint hits:", len(hits))
    json.dump(hits, open("family_sweep_hits.json", "w"), indent=1)
    # live verify isModuleEnabled + target/funds
    ver = []
    for h in hits:
        for s in h["safes"]:
            item = rpc_batch([("eth_call", [{"to": s, "data": "0x2d9ad53d" + h["module"][2:].rjust(64, "0")}, "latest"]),
                              ("eth_call", [{"to": h["module"], "data": "0x0000004f"}, "latest"]),
                              ("eth_call", [{"to": h["module"], "data": "0x00000083"}, "latest"]),
                              ("eth_call", [{"to": "0x2d62109243b87c4ba3ee7ba1d91b0dd0a074d7b1", "data": "0x70a08231" + s[2:].rjust(64, "0")}, "latest"]),
                              ("eth_call", [{"to": "0xa1290d69c65a6fe4df752f95823fae25cb99e5a7", "data": "0x70a08231" + s[2:].rjust(64, "0")}, "latest"])])
            en = item[0] and item[0].get("result", "0x0")
            ver.append({"module": h["module"], "safe": s, "kind": h["kind"],
                        "enabled": en.endswith("1"), "callers_raw": (item[1] or {}).get("result", ""),
                        "paused_raw": (item[2] or {}).get("result", ""),
                        "aEthrsETH": int((item[3] or {}).get("result", "0x0"), 16) if item[3] and item[3].get("result") else 0,
                        "rsETH": int((item[4] or {}).get("result", "0x0"), 16) if item[4] and item[4].get("result") else 0})
    json.dump(ver, open("family_sweep_live.json", "w"), indent=1)
    for v in ver:
        print(v["kind"], v["module"], "on", v["safe"], "enabled", v["enabled"], "aEthrsETH", v["aEthrsETH"], "rsETH", v["rsETH"])
    print("DONE")

if __name__ == "__main__":
    main()
